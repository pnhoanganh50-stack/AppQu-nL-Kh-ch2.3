import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models.dart';

// ---------------- Thư mục ảnh ----------------

class AppPaths {
  static late String imagesDir;

  static Future<void> init() async {
    final docs = await getApplicationDocumentsDirectory();
    imagesDir = p.join(docs.path, 'images');
    await Directory(imagesDir).create(recursive: true);
  }

  static File imageFile(String name) => File(p.join(imagesDir, name));
}

// ---------------- Định dạng ngày giờ ----------------

String fmtDateTime(DateTime d) => DateFormat('HH:mm - dd/MM/yyyy', 'vi').format(d);
String fmtDate(DateTime d) => DateFormat('dd/MM/yyyy', 'vi').format(d);

String fmtFriendly(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = day.difference(today).inDays;
  final hour = DateFormat('HH:mm').format(d);
  if (diff == 0) return '$hour hôm nay';
  if (diff == 1) return '$hour ngày mai';
  if (diff == -1) return '$hour hôm qua';
  return '$hour - ${DateFormat('EEEE, dd/MM', 'vi').format(d)}';
}

String capFirst(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String fmtToday() => capFirst(DateFormat('EEEE, dd/MM/yyyy', 'vi').format(DateTime.now()));

// ---------------- Tiền (đơn vị: triệu đồng) ----------------

final NumberFormat _num = NumberFormat('#,##0.##', 'vi');

/// 2500 -> "2,5 tỷ" ; 350 -> "350 triệu"
String fmtMoney(double trieu) {
  if (trieu == 0) return '0';
  if (trieu.abs() >= 1000) return '${_num.format(trieu / 1000)} tỷ';
  return '${_num.format(trieu)} triệu';
}

/// Chuỗi người dùng gõ -> số (chấp nhận cả dấu phẩy và dấu chấm thập phân).
double parseMoney(String s) {
  var t = s.trim().replaceAll(' ', '');
  if (t.isEmpty) return 0;
  // "1.500,5" -> "1500.5" ; "2,5" -> "2.5"
  if (t.contains(',') && t.contains('.')) {
    t = t.replaceAll('.', '').replaceAll(',', '.');
  } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(t)) {
    t = t.replaceAll('.', ''); // "2.500" = hai nghìn năm trăm
  } else {
    t = t.replaceAll(',', '.');
  }
  return double.tryParse(t) ?? 0;
}

String moneyInput(double v) => v == 0 ? '' : _num.format(v).replaceAll('.', '');

// ---------------- Tìm kiếm tiếng Việt không dấu ----------------

const Map<String, String> _accentGroups = {
  'a': 'àáạảãâầấậẩẫăằắặẳẵ',
  'e': 'èéẹẻẽêềếệểễ',
  'i': 'ìíịỉĩ',
  'o': 'òóọỏõôồốộổỗơờớợởỡ',
  'u': 'ùúụủũưừứựửữ',
  'y': 'ỳýỵỷỹ',
  'd': 'đ',
};

final Map<int, String> _accentMap = () {
  final m = <int, String>{};
  _accentGroups.forEach((base, chars) {
    for (final r in chars.runes) {
      m[r] = base;
    }
  });
  return m;
}();

/// "Nguyễn Văn Đức" -> "nguyen van duc"
String normalize(String s) {
  final sb = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    if (r >= 0x0300 && r <= 0x036F) continue; // dấu tổ hợp
    sb.write(_accentMap[r] ?? String.fromCharCode(r));
  }
  return sb.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

String digitsOnly(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

/// Chuẩn hóa SĐT: bỏ ký tự lạ, +84 -> 0, thêm số 0 bị Excel làm mất.
String cleanPhone(String s) {
  var d = digitsOnly(s);
  if (d.startsWith('84') && d.length == 11) d = '0${d.substring(2)}';
  if (d.length == 9 && !d.startsWith('0')) d = '0$d';
  return d;
}

/// Tìm theo tên, SĐT, khu vực, dự án quan tâm.
bool matchCustomer(Customer c, String query, {String extra = ''}) {
  final q = normalize(query);
  if (q.isEmpty) return true;
  if (normalize('${c.name} ${c.area} $extra').contains(q)) return true;
  final qd = digitsOnly(query);
  if (qd.length >= 3 &&
      (digitsOnly(c.phone).contains(qd) || digitsOnly(c.zalo).contains(qd))) {
    return true;
  }
  return false;
}

// ---------------- Chọn ngày giờ ----------------

Future<DateTime?> pickDateTime(BuildContext context, {DateTime? initial}) async {
  final now = DateTime.now();
  final init = initial ?? now.add(const Duration(hours: 1));
  final date = await pickDate(context, initial: init.isBefore(now) ? now : init);
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(init),
    helpText: 'CHỌN GIỜ',
    cancelText: 'Hủy',
    confirmText: 'Xong',
    builder: (ctx, child) => MediaQuery(
      data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
      child: child!,
    ),
  );
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

Future<DateTime?> pickDate(BuildContext context, {DateTime? initial}) {
  final now = DateTime.now();
  return showDatePicker(
    context: context,
    initialDate: initial ?? now,
    firstDate: DateTime(now.year - 5),
    lastDate: DateTime(now.year + 5),
    helpText: 'CHỌN NGÀY',
    cancelText: 'Hủy',
    confirmText: 'Chọn',
  );
}

// ---------------- Mở cuộc gọi / Zalo / Facebook ----------------

Future<bool> _open(BuildContext context, Uri uri) async {
  bool ok = false;
  try {
    ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    ok = false;
  }
  if (!ok && context.mounted) {
    showSnack(context, 'Không mở được. Kiểm tra lại thông tin.');
  }
  return ok;
}

Future<bool> callPhone(BuildContext context, String phone) =>
    _open(context, Uri(scheme: 'tel', path: digitsOnly(phone)));

Future<bool> sendSms(BuildContext context, String phone) =>
    _open(context, Uri(scheme: 'sms', path: digitsOnly(phone)));

Future<bool> openZalo(BuildContext context, String phone) =>
    _open(context, Uri.parse('https://zalo.me/${digitsOnly(phone)}'));

Future<bool> openFacebook(BuildContext context, String fb) {
  final v = fb.trim();
  Uri uri;
  if (v.startsWith('http://') || v.startsWith('https://')) {
    uri = Uri.parse(v);
  } else if (v.contains('facebook.com') || v.contains('fb.com')) {
    uri = Uri.parse('https://$v');
  } else if (!v.contains(' ')) {
    uri = Uri.parse('https://www.facebook.com/$v');
  } else {
    uri = Uri.parse('https://www.facebook.com/search/top?q=${Uri.encodeComponent(v)}');
  }
  return _open(context, uri);
}

// ---------------- Hộp thoại, thông báo nhỏ ----------------

void showSnack(BuildContext context, String msg, {SnackBarAction? action}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 17)),
      action: action,
      duration: const Duration(seconds: 4),
    ));
}

Future<bool> confirm(BuildContext context, String title, String message,
    {String ok = 'Đồng ý', bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message, style: const TextStyle(fontSize: 17)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Không'),
        ),
        ElevatedButton(
          style: danger
              ? ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r ?? false;
}
