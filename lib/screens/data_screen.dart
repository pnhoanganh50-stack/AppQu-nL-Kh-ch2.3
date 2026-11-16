import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data_io.dart';
import '../security.dart';
import '../store.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';

/// Sao lưu / Khôi phục, Xuất / Nhập Excel.
class DataScreen extends StatefulWidget {
  const DataScreen({super.key});

  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() job) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await job();
    } catch (e) {
      if (mounted) {
        showSnack(context, e is String ? e : 'Có lỗi xảy ra: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Hỏi lưu vào máy hay gửi đi.
  Future<bool> _deliver(Uint8List bytes, String fileName) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(fileName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx, 'share'),
                icon: const Icon(Icons.send),
                label: const Text('Gửi qua Zalo, Email, Drive…'),
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(60)),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(ctx, 'save'),
                icon: const Icon(Icons.save_alt),
                label: const Text('Lưu vào máy (thư mục Tải xuống…)'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(60)),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == 'share') {
      await DataIO.share(bytes, fileName);
      return true;
    }
    if (choice == 'save') {
      final ok = await DataIO.saveToDevice(bytes, fileName);
      if (ok && mounted) showSnack(context, 'Đã lưu file $fileName');
      return ok;
    }
    return false;
  }

  Future<void> _backup() => _run(() async {
        final b = await DataIO.createBackup();
        final ok = await _deliver(b.bytes, b.fileName);
        if (ok) {
          await DataIO.afterBackupSaved();
          if (mounted) setState(() {});
        }
      });

  Future<void> _restore() => _run(() async {
        final backup = await DataIO.pickBackup();
        if (backup == null || !mounted) return;
        final n = DataIO.countCustomers(backup);
        final created = backup['created']?.toString() ?? '';
        final ok = await confirm(
          context,
          'Khôi phục dữ liệu?',
          'File sao lưu có $n khách${created.length >= 10 ? ' (ngày ${created.substring(8, 10)}/${created.substring(5, 7)}/${created.substring(0, 4)})' : ''}.\n\n'
              'TOÀN BỘ dữ liệu hiện tại trong app sẽ bị THAY THẾ.',
          ok: 'Khôi phục',
          danger: true,
        );
        if (!ok) return;
        await DataIO.restore(backup);
        if (mounted) showSnack(context, 'Đã khôi phục $n khách hàng');
      });

  Future<void> _exportExcel() => _run(() async {
        final r = await DataIO.exportExcel();
        await _deliver(r.bytes, r.fileName);
      });

  Future<void> _template() => _run(() async {
        await _deliver(DataIO.templateExcel(), 'Mau_Nhap_Khach.xlsx');
      });

  Future<void> _import() => _run(() async {
        final r = await DataIO.pickAndImport();
        if (r == null || !mounted) return;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(r.error == null ? 'Nhập xong' : 'Không nhập được'),
            content: Text(
              r.error ??
                  'Thêm mới: ${r.added} khách\n'
                      'Cập nhật (trùng SĐT): ${r.updated} khách\n'
                      'Bỏ qua dòng trống: ${r.skipped}',
              style: const TextStyle(fontSize: 18),
            ),
            actions: [
              ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ],
          ),
        );
      });

  @override
  Widget build(BuildContext context) {
    final last = Security.lastBackup;
    final count = Store.instance.customers.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Sao lưu & Excel')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
            children: [
              SectionCard(
                title: 'Sao lưu / Khôi phục',
                icon: Icons.shield,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      last == null
                          ? 'Chưa sao lưu lần nào!'
                          : 'Lần sao lưu gần nhất: ${fmtDateTime(last)}',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: last == null ? Colors.red.shade700 : Colors.green.shade800),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'App lưu dữ liệu trong điện thoại. Mất máy hoặc xóa app là MẤT HẾT khách. '
                      'Hãy sao lưu mỗi tuần và gửi file lên Zalo "Cloud của tôi" hoặc Google Drive.',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _backup,
                      icon: const Icon(Icons.cloud_upload, size: 28),
                      label: Text('SAO LƯU NGAY ($count khách)'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: kGold,
                          foregroundColor: kNavy,
                          minimumSize: const Size.fromHeight(64)),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _restore,
                      icon: const Icon(Icons.restore),
                      label: const Text('Khôi phục từ file sao lưu'),
                    ),
                  ],
                ),
              ),
              SectionCard(
                title: 'Xuất Excel',
                icon: Icons.table_view,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                        'Xuất danh sách khách, lịch sử chăm sóc, dự án và giao dịch ra file Excel để gửi sếp / lưu trữ.',
                        style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _exportExcel,
                      icon: const Icon(Icons.download),
                      label: const Text('XUẤT RA EXCEL'),
                    ),
                  ],
                ),
              ),
              SectionCard(
                title: 'Nhập khách từ Excel / CSV',
                icon: Icons.upload_file,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                        'Dòng đầu tiên phải là tiêu đề cột (Tên, SĐT, Khu vực...). '
                        'Khách trùng SĐT sẽ được CẬP NHẬT, không tạo trùng.',
                        style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _import,
                      icon: const Icon(Icons.file_open),
                      label: const Text('CHỌN FILE ĐỂ NHẬP'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _template,
                      icon: const Icon(Icons.description),
                      label: const Text('Tải file mẫu'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_busy)
            const ColoredBox(
              color: Colors.black26,
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
