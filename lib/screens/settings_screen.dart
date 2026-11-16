import 'package:flutter/material.dart';

import '../security.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';

/// Cài đặt: mật khẩu mở app, vân tay.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _canBio = false;

  @override
  void initState() {
    super.initState();
    Security.canBiometric().then((v) {
      if (mounted) setState(() => _canBio = v);
    });
  }

  Future<void> _togglePin(bool on) async {
    if (on) {
      final ok = await Navigator.push<bool>(
          context, MaterialPageRoute(builder: (_) => const PinSetupScreen()));
      if (ok == true && mounted) {
        showSnack(context, 'Đã bật mật khẩu. Hãy nhớ kỹ mã!');
        if (_canBio) {
          final bio = await confirm(context, 'Dùng vân tay?',
              'Mở app bằng vân tay cho nhanh (vẫn dùng được mã khi cần).',
              ok: 'Dùng vân tay');
          if (bio && await Security.authBiometric()) await Security.setUseBiometric(true);
        }
      }
    } else {
      final ok = await Navigator.push<bool>(
          context, MaterialPageRoute(builder: (_) => const PinVerifyScreen()));
      if (ok == true) {
        await Security.setPin(null);
        if (mounted) showSnack(context, 'Đã tắt mật khẩu');
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleBio(bool on) async {
    if (on) {
      final ok = await Security.authBiometric();
      if (ok) {
        await Security.setUseBiometric(true);
      } else if (mounted) {
        showSnack(context, 'Không xác thực được vân tay');
      }
    } else {
      await Security.setUseBiometric(false);
    }
    if (mounted) setState(() {});
  }

  Future<void> _changePin() async {
    final ok = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => const PinVerifyScreen()));
    if (ok != true || !mounted) return;
    final done = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => const PinSetupScreen()));
    if (done == true && mounted) showSnack(context, 'Đã đổi mã');
  }

  @override
  Widget build(BuildContext context) {
    final hasPin = Security.hasPin;
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          SectionCard(
            title: 'Bảo mật',
            icon: Icons.lock,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: hasPin,
                  onChanged: _togglePin,
                  title: const Text('Mật khẩu mở app (4 số)',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Hỏi mã khi mở app hoặc quay lại sau 2 phút'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: Security.useBiometric,
                  onChanged: hasPin && _canBio ? _toggleBio : null,
                  title: const Text('Mở khóa bằng vân tay',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  subtitle: Text(!_canBio
                      ? 'Máy chưa cài vân tay hoặc không hỗ trợ'
                      : (hasPin ? 'Chạm vân tay thay cho nhập mã' : 'Cần bật mật khẩu trước')),
                ),
                if (hasPin) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _changePin,
                    icon: const Icon(Icons.password),
                    label: const Text('Đổi mã'),
                  ),
                ],
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: kGoldLight, borderRadius: BorderRadius.circular(12)),
                  child: const Text(
                    'Lưu ý: Quên mã sẽ phải gỡ app và cài lại (mất dữ liệu). '
                    'Hãy sao lưu thường xuyên để có thể khôi phục.',
                    style: TextStyle(fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
          const SectionCard(
            title: 'Về app',
            icon: Icons.info,
            child: Text(
              'Quản Lý Khách BĐS - phiên bản 2.3\n'
              'Dữ liệu lưu offline trong điện thoại, không gửi đi đâu.',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
