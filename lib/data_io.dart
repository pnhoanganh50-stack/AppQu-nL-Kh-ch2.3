import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'db.dart';
import 'models.dart';
import 'notifications.dart';
import 'security.dart';
import 'store.dart';
import 'utils.dart';

/// Kết quả nhập file.
class ImportResult {
  int added = 0;
  int updated = 0;
  int skipped = 0;
  String? error;
}

/// Nhập / Xuất Excel, Sao lưu / Khôi phục.
class DataIO {
  static String _stamp() => DateFormat('yyyyMMdd_HHmm').format(DateTime.now());

  // ======================= LƯU / GỬI FILE =======================

  /// Mở hộp thoại "Lưu file" của Android (chọn Tải xuống, Google Drive...).
  /// Trả về true nếu lưu xong.
  static Future<bool> saveToDevice(Uint8List bytes, String fileName) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Chọn nơi lưu file',
      fileName: fileName,
      bytes: bytes,
    );
    return path != null;
  }

  /// Gửi file qua Zalo, Email, Drive...
  static Future<void> share(Uint8List bytes, String fileName) async {
    final dir = await getTemporaryDirectory();
    final f = File(p.join(dir.path, fileName));
    await f.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([XFile(f.path)], subject: fileName);
  }

  // ======================= XUẤT EXCEL =======================

  static const customerHeaders = [
    'STT', 'Tên', 'SĐT', 'Zalo', 'Facebook', 'Nguồn khách', 'Nhu cầu',
    'Loại BĐS', 'Khu vực', 'Ngân sách', 'Thời gian mua', 'Trạng thái',
    'Dự án quan tâm', 'Lịch hẹn', 'Ghi chú', 'Chăm sóc gần nhất', 'Ngày thêm',
  ];

  static CellValue _t(String s) => TextCellValue(s);
  static CellValue _n(double v) => DoubleCellValue(v);

  static Future<({Uint8List bytes, String fileName})> exportExcel() async {
    final store = Store.instance;
    final logs = await AppDb.instance.getAllLogs();
    final lastLog = <int, CareLog>{};
    for (final l in logs) {
      if (l.type == CareType.capNhat) continue;
      lastLog.putIfAbsent(l.customerId, () => l); // logs đã sắp xếp mới nhất trước
    }
    final names = {for (final c in store.customers) c.id: c.name};

    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();

    // --- Khách hàng ---
    final sc = excel['Khách hàng'];
    sc.appendRow(customerHeaders.map(_t).toList());
    var i = 0;
    for (final c in store.customers) {
      i++;
      final last = lastLog[c.id];
      sc.appendRow(<CellValue?>[
        _t('$i'),
        _t(c.name),
        _t(c.phone),
        _t(c.zalo),
        _t(c.facebook),
        _t(c.source),
        _t(c.need),
        _t(c.propertyType),
        _t(c.area),
        _t(c.budget),
        _t(c.timeline),
        _t(c.status.label),
        _t(store.projectsOf(c.id!).map((e) => e.name).join(', ')),
        _t(c.nextCall == null ? '' : '${c.apptType} ${fmtDateTime(c.nextCall!)}'),
        _t(c.note),
        _t(last == null ? '' : '${fmtDate(last.time)}: ${last.content}'),
        _t(fmtDate(c.createdAt)),
      ]);
    }

    // --- Lịch sử chăm sóc ---
    final sl = excel['Lịch sử chăm sóc'];
    sl.appendRow(['Khách', 'Thời gian', 'Loại', 'Nội dung'].map(_t).toList());
    for (final l in logs) {
      sl.appendRow(<CellValue?>[
        _t(names[l.customerId] ?? ''),
        _t(fmtDateTime(l.time)),
        _t(l.type),
        _t(l.content),
      ]);
    }

    // --- Dự án ---
    final sp = excel['Dự án'];
    sp.appendRow([
      'Tên dự án', 'Vị trí', 'Giá', 'Diện tích', 'Pháp lý', 'Hoa hồng',
      'Tổng số căn', 'Đã bán/cọc', 'Còn lại', 'Ghi chú'
    ].map(_t).toList());
    for (final pr in store.projects) {
      sp.appendRow(<CellValue?>[
        _t(pr.name),
        _t(pr.location),
        _t(pr.price),
        _t(pr.size),
        _t(pr.legal),
        _t(pr.commission),
        _n(pr.totalUnits.toDouble()),
        _n(store.soldUnits(pr).toDouble()),
        _t(store.isSoldOut(pr) ? 'Đã bán hết' : '${store.remainingUnits(pr)}'),
        _t(pr.note),
      ]);
    }

    // --- Giao dịch ---
    final sd = excel['Giao dịch'];
    sd.appendRow([
      'Ngày', 'Khách', 'Dự án', 'Mã căn', 'Tình trạng',
      'Giá chốt (triệu)', 'Đã cọc (triệu)', 'Còn lại (triệu)',
      'Tổng hoa hồng (triệu)', 'Chia cho', 'Tôi nhận (triệu)', 'Đã nhận HH', 'Ghi chú'
    ].map(_t).toList());
    for (final d in store.deals) {
      sd.appendRow(<CellValue?>[
        _t(fmtDate(d.date)),
        _t(names[d.customerId] ?? ''),
        _t(store.project(d.projectId)?.name ?? ''),
        _t(d.unit),
        _t(d.stage),
        _n(d.price),
        _n(d.deposit),
        _n(d.remaining),
        _n(d.commission),
        _t(d.sharedWith),
        _n(d.myCommission),
        _t(d.received ? 'Đã nhận' : 'Chưa nhận'),
        _t(d.note),
      ]);
    }

    if (defaultSheet != null && excel.tables.containsKey(defaultSheet)) {
      excel.delete(defaultSheet);
    }

    final bytes = excel.encode();
    if (bytes == null) throw Exception('Không tạo được file Excel');
    return (bytes: Uint8List.fromList(bytes), fileName: 'KhachHang_${_stamp()}.xlsx');
  }

  /// File mẫu để điền khách rồi nhập vào app.
  static Uint8List templateExcel() {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();
    final s = excel['Khách hàng'];
    s.appendRow([
      'Tên', 'SĐT', 'Zalo', 'Facebook', 'Nguồn khách', 'Nhu cầu', 'Loại BĐS',
      'Khu vực', 'Ngân sách', 'Thời gian mua', 'Trạng thái', 'Ghi chú'
    ].map(_t).toList());
    s.appendRow([
      'Nguyễn Văn A', '0901234567', '', '', 'Facebook', 'Mua', 'Đất nền',
      'Quận 9', '2-3 tỷ', '1-3 tháng', 'Mới', 'Khách xem tin trên Facebook'
    ].map(_t).toList());
    if (defaultSheet != null && excel.tables.containsKey(defaultSheet)) {
      excel.delete(defaultSheet);
    }
    return Uint8List.fromList(excel.encode() ?? <int>[]);
  }

  // ======================= NHẬP EXCEL / CSV =======================

  /// Tên cột chấp nhận được (đã bỏ dấu, viết thường).
  static const Map<String, List<String>> _aliases = {
    'name': ['ten', 'ho ten', 'ho va ten', 'ten khach', 'ten khach hang', 'khach hang', 'name'],
    'phone': ['sdt', 'so dien thoai', 'dien thoai', 'so dt', 'dt', 'phone', 'mobile'],
    'zalo': ['zalo'],
    'facebook': ['facebook', 'fb'],
    'source': ['nguon', 'nguon khach'],
    'need': ['nhu cau'],
    'ptype': ['loai bds', 'loai bat dong san', 'loai'],
    'area': ['khu vuc', 'vi tri', 'dia chi'],
    'budget': ['ngan sach', 'tai chinh'],
    'timeline': ['thoi gian', 'thoi gian mua', 'thoi gian muon mua'],
    'status': ['trang thai', 'tinh trang'],
    'note': ['ghi chu', 'note'],
  };

  /// Chọn file .xlsx hoặc .csv rồi nhập. Trả về null nếu người dùng hủy.
  static Future<ImportResult?> pickAndImport() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'csv'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return null;
    final f = res.files.single;
    Uint8List? bytes = f.bytes;
    if (bytes == null && f.path != null) bytes = await File(f.path!).readAsBytes();
    if (bytes == null) return ImportResult()..error = 'Không đọc được file.';

    List<List<String>> rows;
    try {
      rows = f.name.toLowerCase().endsWith('.csv') ? _readCsv(bytes) : _readXlsx(bytes);
    } catch (e) {
      return ImportResult()..error = 'File không đúng định dạng Excel (.xlsx) hoặc CSV.';
    }
    return importRows(rows);
  }

  static List<List<String>> _readXlsx(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    // Ưu tiên sheet có dòng tiêu đề hợp lệ.
    List<List<String>>? first;
    for (final name in excel.tables.keys) {
      final sheet = excel.tables[name];
      if (sheet == null) continue;
      final rows = sheet.rows.map((r) => r.map(_cellText).toList()).toList();
      first ??= rows;
      if (_findHeader(rows) != null) return rows;
    }
    return first ?? [];
  }

  static String _cellText(Data? d) {
    final v = d?.value;
    if (v == null) return '';
    if (v is IntCellValue) return v.value.toString();
    if (v is DoubleCellValue) {
      final x = v.value;
      return x == x.roundToDouble() ? x.toInt().toString() : x.toString();
    }
    if (v is TextCellValue) return _spanText(v.value).trim();
    return v.toString().trim();
  }

  /// Lấy chữ từ ô văn bản (hỗ trợ nhiều phiên bản thư viện excel).
  static String _spanText(dynamic s) {
    if (s == null) return '';
    if (s is String) return s;
    try {
      final sb = StringBuffer();
      final dynamic t = s.text;
      if (t != null) sb.write(t);
      final dynamic ch = s.children;
      if (ch is List) {
        for (final c in ch) {
          sb.write(_spanText(c));
        }
      }
      return sb.toString();
    } catch (_) {
      return s.toString();
    }
  }

  static List<List<String>> _readCsv(Uint8List bytes) {
    var text = utf8.decode(bytes, allowMalformed: true);
    if (text.startsWith('﻿')) text = text.substring(1);
    final firstLine = text.split('\n').first;
    String sep = ',';
    if (';'.allMatches(firstLine).length > ','.allMatches(firstLine).length) sep = ';';
    if ('\t'.allMatches(firstLine).length > sep.allMatches(firstLine).length) sep = '\t';

    final rows = <List<String>>[];
    var row = <String>[];
    final cell = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            cell.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          cell.write(ch);
        }
      } else if (ch == '"') {
        inQuotes = true;
      } else if (ch == sep) {
        row.add(cell.toString().trim());
        cell.clear();
      } else if (ch == '\n') {
        row.add(cell.toString().trim());
        cell.clear();
        rows.add(row);
        row = <String>[];
      } else if (ch != '\r') {
        cell.write(ch);
      }
    }
    if (cell.isNotEmpty || row.isNotEmpty) {
      row.add(cell.toString().trim());
      rows.add(row);
    }
    return rows;
  }

  /// Tìm dòng tiêu đề trong 10 dòng đầu. Trả về (vị trí dòng, cột -> trường).
  static ({int row, Map<String, int> cols})? _findHeader(List<List<String>> rows) {
    for (var r = 0; r < rows.length && r < 10; r++) {
      final cols = <String, int>{};
      for (var c = 0; c < rows[r].length; c++) {
        final h = normalize(rows[r][c]).replaceAll('bđs', 'bds');
        _aliases.forEach((field, names) {
          if (!cols.containsKey(field) && names.contains(h)) cols[field] = c;
        });
      }
      if (cols.containsKey('name') || cols.containsKey('phone')) {
        return (row: r, cols: cols);
      }
    }
    return null;
  }

  static String _pick(List<String> options, String raw) {
    final n = normalize(raw);
    if (n.isEmpty) return '';
    for (final o in options) {
      if (normalize(o) == n) return o;
    }
    return raw.trim();
  }

  static CustomerStatus? _status(String raw) {
    final n = normalize(raw);
    if (n.isEmpty) return null;
    for (final s in CustomerStatus.values) {
      if (normalize(s.label) == n) return s;
    }
    return null;
  }

  /// Nhập danh sách dòng. Trùng SĐT -> cập nhật khách cũ, không tạo trùng.
  static Future<ImportResult> importRows(List<List<String>> rows) async {
    final result = ImportResult();
    final header = _findHeader(rows);
    if (header == null) {
      result.error = 'Không tìm thấy cột "Tên" hoặc "SĐT" ở dòng tiêu đề.\n'
          'Hãy dùng file mẫu của app.';
      return result;
    }
    final store = Store.instance;
    final db = AppDb.instance;
    final byPhone = <String, Customer>{};
    for (final c in store.customers) {
      final ph = cleanPhone(c.phone);
      if (ph.isNotEmpty) byPhone[ph] = c;
    }

    String cell(List<String> row, String field) {
      final idx = header.cols[field];
      if (idx == null || idx >= row.length) return '';
      return row[idx].trim();
    }

    for (var r = header.row + 1; r < rows.length; r++) {
      final row = rows[r];
      final name = cell(row, 'name');
      final phone = cleanPhone(cell(row, 'phone'));
      if (name.isEmpty && phone.isEmpty) {
        result.skipped++;
        continue;
      }
      final fields = <String, String>{
        'zalo': cleanPhone(cell(row, 'zalo')).isNotEmpty ? cleanPhone(cell(row, 'zalo')) : cell(row, 'zalo'),
        'facebook': cell(row, 'facebook'),
        'source': _pick(Opt.sources, cell(row, 'source')),
        'need': _pick(Opt.needs, cell(row, 'need')),
        'ptype': _pick(Opt.propertyTypes, cell(row, 'ptype')),
        'area': cell(row, 'area'),
        'budget': cell(row, 'budget'),
        'timeline': _pick(Opt.timelines, cell(row, 'timeline')),
        'note': cell(row, 'note'),
      };
      final status = _status(cell(row, 'status'));

      final existing = phone.isEmpty ? null : byPhone[phone];
      final c = existing?.copy() ?? Customer(name: name.isEmpty ? phone : name, phone: phone);
      if (existing != null && name.isNotEmpty) c.name = name;
      void setIf(String key, void Function(String v) setter) {
        final v = fields[key] ?? '';
        if (v.isNotEmpty) setter(v);
      }

      setIf('zalo', (v) => c.zalo = v);
      setIf('facebook', (v) => c.facebook = v);
      setIf('source', (v) => c.source = v);
      setIf('need', (v) => c.need = v);
      setIf('ptype', (v) => c.propertyType = v);
      setIf('area', (v) => c.area = v);
      setIf('budget', (v) => c.budget = v);
      setIf('timeline', (v) => c.timeline = v);
      setIf('note', (v) => c.note = v);
      if (status != null) c.status = status;
      c.updatedAt = DateTime.now();

      if (existing != null) {
        await db.updateCustomer(c);
        result.updated++;
      } else {
        c.id = await db.insertCustomer(c);
        result.added++;
        if (phone.isNotEmpty) byPhone[phone] = c; // tránh trùng ngay trong file
      }
    }
    await store.load();
    return result;
  }

  // ======================= SAO LƯU / KHÔI PHỤC =======================

  static const _backupApp = 'QuanLyKhachBDS';

  /// Tạo file sao lưu (gồm cả ảnh dự án).
  static Future<({Uint8List bytes, String fileName})> createBackup() async {
    final data = await AppDb.instance.dumpAll();
    final images = <String, String>{};
    for (final pr in Store.instance.projects) {
      for (final img in pr.images) {
        final f = AppPaths.imageFile(img);
        if (await f.exists()) images[img] = base64Encode(await f.readAsBytes());
      }
    }
    final json = jsonEncode({
      'app': _backupApp,
      'version': 1,
      'created': DateTime.now().toIso8601String(),
      'tables': data,
      'images': images,
    });
    return (
      bytes: Uint8List.fromList(utf8.encode(json)),
      fileName: 'SaoLuu_QuanLyKhach_${_stamp()}.json',
    );
  }

  /// Chọn file sao lưu. Trả về nội dung đã kiểm tra, hoặc null nếu hủy.
  /// Ném lỗi (String) nếu file không hợp lệ.
  static Future<Map<String, dynamic>?> pickBackup() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
    if (res == null || res.files.isEmpty) return null;
    final f = res.files.single;
    Uint8List? bytes = f.bytes;
    if (bytes == null && f.path != null) bytes = await File(f.path!).readAsBytes();
    if (bytes == null) throw 'Không đọc được file.';
    try {
      final m = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if (m['app'] != _backupApp || m['tables'] is! Map) throw 'x';
      return m;
    } catch (_) {
      throw 'Đây không phải file sao lưu của app.';
    }
  }

  static int countCustomers(Map<String, dynamic> backup) =>
      ((backup['tables'] as Map)['customers'] as List?)?.length ?? 0;

  /// Thay toàn bộ dữ liệu hiện tại bằng bản sao lưu.
  static Future<void> restore(Map<String, dynamic> backup) async {
    final tables = <String, List<Map<String, Object?>>>{};
    (backup['tables'] as Map).forEach((k, v) {
      tables[k.toString()] = (v as List)
          .map((e) => Map<String, Object?>.from(e as Map))
          .toList();
    });
    await AppDb.instance.restoreAll(tables);

    final images = backup['images'];
    if (images is Map) {
      for (final e in images.entries) {
        try {
          await AppPaths.imageFile(e.key.toString())
              .writeAsBytes(base64Decode(e.value as String), flush: true);
        } catch (_) {}
      }
    }

    try {
      await Noti.cancelAll();
    } catch (_) {}
    await Store.instance.load();
    await Noti.rescheduleAll(Store.instance.customers);
  }

  static Future<void> afterBackupSaved() => Security.markBackup();
}
