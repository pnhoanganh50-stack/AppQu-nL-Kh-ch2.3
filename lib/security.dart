import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme.dart';

/// Mật khẩu (mã PIN 4 số) + vân tay, và vài cài đặt nhỏ.
class Security {
  static late SharedPreferences _p;
  static final LocalAuthentication _auth = LocalAuthentication();

  static const pinLength = 4;

  static Future<void> init() async {
    _p = await SharedPreferences.getInstance();
  }

  static String _hash(String pin) =>
      sha256.convert(utf8.encode('quanlykhach-bds::$pin')).toString();

  static bool get hasPin => (_p.getString('pin_hash') ?? '').isNotEmpty;

  static bool checkPin(String pin) => _p.getString('pin_hash') == _hash(pin);

  static Future<void> setPin(String? pin) async {
    if (pin == null) {
      await _p.remove('pin_hash');
      await _p.setBool('use_bio', false);
    } else {
      await _p.setString('pin_hash', _hash(pin));
    }
  }

  static bool get useBiometric => hasPin && (_p.getBool('use_bio') ?? false);

  static Future<void> setUseBiometric(bool v) => _p.setBool('use_bio', v);

  static Future<bool> canBiometric() async {
    try {
      return await _auth.canCheckBiometrics && await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authBiometric() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Mở khóa app Quản Lý Khách',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
    } catch (_) {
      return false;
    }
  }

  // ---- Lần sao lưu gần nhất ----
  static DateTime? get lastBackup {
    final v = _p.getInt('last_backup');
    return v == null ? null : DateTime.fromMillisecondsSinceEpoch(v);
  }

  static Future<void> markBackup() =>
      _p.setInt('last_backup', DateTime.now().millisecondsSinceEpoch);
}

// ======================= Bàn phím nhập mã PIN =======================

class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.title,
    required this.onCompleted,
    this.subtitle,
    this.showBiometric = false,
    this.onBiometric,
  });

  final String title;
  final String? subtitle;

  /// Trả về true nếu mã đúng / chấp nhận; false để báo sai và xóa.
  final Future<bool> Function(String pin) onCompleted;
  final bool showBiometric;
  final VoidCallback? onBiometric;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _pin = '';
  bool _error = false;

  Future<void> _press(String d) async {
    if (_pin.length >= Security.pinLength) return;
    setState(() {
      _pin += d;
      _error = false;
    });
    if (_pin.length == Security.pinLength) {
      final ok = await widget.onCompleted(_pin);
      if (!mounted) return;
      setState(() {
        if (!ok) _error = true;
        _pin = '';
      });
    }
  }

  void _back() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Widget _key(String d) => _PadButton(
        onTap: () => _press(d),
        child: Text(d,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w600, color: kNavy)),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(widget.title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kNavy)),
        const SizedBox(height: 6),
        Text(
          _error ? 'Mã không đúng, thử lại' : (widget.subtitle ?? ''),
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 16, color: _error ? Colors.red : Colors.grey.shade700),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < Security.pinLength; i++)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _pin.length ? kGold : Colors.transparent,
                  border: Border.all(color: _error ? Colors.red : kNavy, width: 2),
                ),
              ),
          ],
        ),
        const SizedBox(height: 28),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (final d in row) _key(d)]),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            widget.showBiometric
                ? _PadButton(
                    onTap: widget.onBiometric,
                    filled: false,
                    child: const Icon(Icons.fingerprint, size: 40, color: kGold))
                : const SizedBox(width: 100, height: 84),
            _key('0'),
            _PadButton(
                onTap: _back,
                filled: false,
                child: const Icon(Icons.backspace_outlined, size: 30, color: kNavy)),
          ],
        ),
      ],
    );
  }
}

class _PadButton extends StatelessWidget {
  const _PadButton({required this.child, this.onTap, this.filled = true});
  final Widget child;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Material(
        color: filled ? kNavyLight : Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 76, height: 72, child: Center(child: child)),
        ),
      ),
    );
  }
}

// ======================= Màn hình khóa =======================

/// Bọc toàn bộ app: khóa khi mở app và khi quay lại sau hơn 2 phút.
class LockGate extends StatefulWidget {
  const LockGate({super.key, required this.child});
  final Widget child;

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  static const lockAfter = Duration(minutes: 2);
  late bool _locked = Security.hasPin;
  DateTime? _pausedAt;
  bool _bioRunning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_locked) WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final p = _pausedAt;
      _pausedAt = null;
      if (!_locked &&
          Security.hasPin &&
          p != null &&
          DateTime.now().difference(p) > lockAfter) {
        setState(() => _locked = true);
        _tryBiometric();
      }
    }
  }

  Future<void> _tryBiometric() async {
    if (!Security.useBiometric || _bioRunning) return;
    _bioRunning = true;
    final ok = await Security.authBiometric();
    _bioRunning = false;
    if (ok && mounted) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_locked)
          Positioned.fill(
            child: Material(
              color: Colors.white,
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      children: [
                        const Icon(Icons.lock, size: 48, color: kGold),
                        const SizedBox(height: 12),
                        PinPad(
                          title: 'Nhập mã mở khóa',
                          subtitle: Security.useBiometric ? 'hoặc chạm vân tay' : null,
                          showBiometric: Security.useBiometric,
                          onBiometric: _tryBiometric,
                          onCompleted: (pin) async {
                            final ok = Security.checkPin(pin);
                            if (ok) setState(() => _locked = false);
                            return ok;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ======================= Đặt / kiểm tra mã =======================

/// Đặt mã mới (nhập 2 lần). Trả về true nếu đặt xong.
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String? _first;
  bool _mismatch = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đặt mã mở app')),
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          child: PinPad(
            key: ValueKey(_first == null),
            title: _first == null ? 'Nhập mã mới (4 số)' : 'Nhập lại mã để xác nhận',
            subtitle: _mismatch
                ? 'Hai lần nhập không khớp, nhập lại từ đầu'
                : 'Hãy nhớ kỹ mã này',
            onCompleted: (pin) async {
              if (_first == null) {
                setState(() {
                  _first = pin;
                  _mismatch = false;
                });
                return true;
              }
              if (pin == _first) {
                await Security.setPin(pin);
                if (mounted) Navigator.pop(context, true);
                return true;
              }
              setState(() {
                _first = null;
                _mismatch = true;
              });
              return false;
            },
          ),
        ),
      ),
    );
  }
}

/// Hỏi mã hiện tại. Trả về true nếu đúng.
class PinVerifyScreen extends StatelessWidget {
  const PinVerifyScreen({super.key, this.title = 'Nhập mã hiện tại'});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Xác nhận')),
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          child: PinPad(
            title: title,
            onCompleted: (pin) async {
              final ok = Security.checkPin(pin);
              if (ok) Navigator.pop(context, true);
              return ok;
            },
          ),
        ),
      ),
    );
  }
}
