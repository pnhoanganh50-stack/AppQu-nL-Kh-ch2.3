import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'customer_form_screen.dart';
import 'deal_form_screen.dart';
import 'project_detail_screen.dart';

/// Chi tiết 1 khách: liên hệ nhanh, lịch hẹn, nhu cầu, dự án, giao dịch, lịch sử.
class CustomerDetailScreen extends StatefulWidget {
  const CustomerDetailScreen({super.key, required this.customerId});
  final int customerId;

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  final Store _store = Store.instance;
  List<CareLog> _logs = [];
  bool _loadingLogs = true;

  @override
  void initState() {
    super.initState();
    _store.addListener(_loadLogs);
    _loadLogs();
  }

  @override
  void dispose() {
    _store.removeListener(_loadLogs);
    super.dispose();
  }

  Future<void> _loadLogs() async {
    final logs = await _store.logsOf(widget.customerId);
    if (!mounted) return;
    setState(() {
      _logs = logs;
      _loadingLogs = false;
    });
  }

  // ======================= Hành động =======================

  Future<void> _edit(Customer c) => Navigator.push(
      context, MaterialPageRoute(builder: (_) => CustomerFormScreen(customer: c)));

  Future<void> _delete(Customer c) async {
    final ok = await confirm(context, 'Xóa khách hàng?',
        'Xóa "${c.name}" cùng lịch sử chăm sóc và giao dịch. Không thể khôi phục.',
        ok: 'Xóa', danger: true);
    if (!ok) return;
    await _store.deleteCustomer(c);
    if (!mounted) return;
    showSnack(context, 'Đã xóa khách ${c.name}');
    Navigator.pop(context);
  }

  Future<void> _changeStatus(Customer c) async {
    final s = await showModalBottomSheet<CustomerStatus>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text('Đổi trạng thái chăm sóc',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              for (final s in CustomerStatus.values)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                  leading: Icon(s.icon, color: s.color, size: 30),
                  title: Text(s.label,
                      style: TextStyle(
                          fontSize: 19, color: s.color, fontWeight: FontWeight.w700)),
                  trailing: c.status == s
                      ? Icon(Icons.check_circle, color: s.color, size: 28)
                      : null,
                  onTap: () => Navigator.pop(ctx, s),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (s == null || s == c.status) return;
    await _store.changeStatus(c, s);
    if (!mounted) return;
    showSnack(context, 'Đã chuyển sang "${s.label}"');

    // Cọc / chốt mà chưa có giao dịch -> mời nhập tiền luôn.
    if ((s == CustomerStatus.daCoc || s == CustomerStatus.daChot) &&
        _store.dealsOf(c.id!).isEmpty) {
      final go = await confirm(context, 'Nhập giao dịch?',
          'Nhập luôn giá chốt, tiền cọc và hoa hồng cho khách này?',
          ok: 'Nhập ngay');
      if (go && mounted) {
        _openDeal(c, null,
            stage: s == CustomerStatus.daChot ? DealStage.chot : DealStage.coc);
      }
    }
  }

  void _openDeal(Customer c, Deal? d, {String? stage}) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => DealFormScreen(customerId: c.id!, deal: d, initialStage: stage)));
  }

  Future<void> _setAppointment(Customer c) async {
    final r = await showModalBottomSheet<_ApptResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AppointmentSheet(customer: c),
    );
    if (r == null) return;
    await _store.setAppointment(c, r.time, type: r.type, remindMinutes: r.remind);
    if (mounted) {
      final before = r.remind >= 60 ? '1 tiếng' : '30 phút';
      showSnack(context, 'Đã hẹn ${r.type} ${fmtFriendly(r.time)}. Báo trước $before.');
    }
  }

  Future<void> _clearAppointment(Customer c) async {
    await _store.setAppointment(c, null);
    if (mounted) showSnack(context, 'Đã bỏ lịch hẹn');
  }

  Future<void> _editProjects(Customer c) async {
    final selected = Set<int>.of(_store.interestIds(c.id!));
    final r = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Dự án khách quan tâm',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final p in _store.projects)
                        CheckboxListTile(
                          value: selected.contains(p.id),
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(p.name, style: const TextStyle(fontSize: 18)),
                          subtitle: p.location.isEmpty ? null : Text(p.location),
                          onChanged: (v) => setS(() {
                            if (v == true) {
                              selected.add(p.id!);
                            } else {
                              selected.remove(p.id);
                            }
                          }),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, selected), child: const Text('LƯU')),
              ],
            ),
          ),
        ),
      ),
    );
    if (r != null) await _store.setInterests(c, r);
  }

  /// Sau khi bấm Gọi / Zalo / SMS: gợi ý ghi lại nội dung.
  void _afterContact(Customer c, String type, bool opened) {
    if (!opened || !mounted) return;
    showSnack(context, 'Nhớ ghi lại khách nói gì sau khi liên hệ!',
        action: SnackBarAction(label: 'GHI LẠI', onPressed: () => _addLog(c, type: type)));
  }

  Future<void> _addLog(Customer c, {String type = CareType.goiDien}) async {
    final result = await showModalBottomSheet<_LogResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddLogSheet(customer: c, initialType: type),
    );
    if (result == null) return;
    await _store.addLog(result.log, clearAppointment: result.clearAppointment);
    if (!mounted) return;
    showSnack(context, 'Đã ghi lịch sử chăm sóc');
    if (result.newStatus != null) {
      final fresh = _store.customer(c.id!);
      if (fresh != null) await _store.changeStatus(fresh, result.newStatus!);
    }
    if (result.scheduleNext && mounted) {
      final fresh = _store.customer(c.id!);
      if (fresh != null) await _setAppointment(fresh);
    }
  }

  Future<void> _deleteLog(CareLog log) async {
    final ok = await confirm(
        context, 'Xóa ghi chép này?', '${log.type} lúc ${fmtDateTime(log.time)}',
        ok: 'Xóa', danger: true);
    if (ok) await _store.deleteLog(log);
  }

  // ======================= Giao diện =======================

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final c = _store.customer(widget.customerId);
        if (c == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Khách hàng')),
            body: EmptyView(
                icon: Icons.person_off,
                text: _store.loaded ? 'Khách này không còn tồn tại.' : 'Đang tải...'),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('Chi tiết khách'),
            actions: [
              IconButton(
                  tooltip: 'Sửa', icon: const Icon(Icons.edit), onPressed: () => _edit(c)),
              IconButton(
                  tooltip: 'Xóa',
                  icon: const Icon(Icons.delete),
                  onPressed: () => _delete(c)),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _addLog(c),
            icon: const Icon(Icons.edit_note, size: 28),
            label: const Text('Ghi chăm sóc'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
            children: [
              _header(c),
              _quickActions(c),
              const SizedBox(height: 12),
              _appointmentCard(c),
              _needCard(c),
              _projectsCard(c),
              _dealsCard(c),
              _historySection(c),
            ],
          ),
        );
      },
    );
  }

  Widget _header(Customer c) {
    return SectionCard(
      child: Row(
        children: [
          CustomerAvatar(c, radius: 34),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.name,
                    style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
                if (c.phone.isNotEmpty)
                  SelectableText(c.phone,
                      style: TextStyle(fontSize: 18, color: Colors.grey.shade700)),
                const SizedBox(height: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _changeStatus(c),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StatusBadge(c.status, big: true),
                      const SizedBox(width: 6),
                      const Text('Đổi',
                          style: TextStyle(
                              color: kNavy,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActions(Customer c) {
    final hasPhone = c.phone.trim().isNotEmpty;
    return Row(
      children: [
        _actionBtn('Gọi', Icons.call, Colors.green.shade700, hasPhone, () async {
          final ok = await callPhone(context, c.phone);
          _afterContact(c, CareType.goiDien, ok);
        }),
        _actionBtn('SMS', Icons.sms, Colors.orange.shade800, hasPhone, () async {
          final ok = await sendSms(context, c.phone);
          _afterContact(c, CareType.nhanTin, ok);
        }),
        _actionBtn('Zalo', Icons.chat_bubble, const Color(0xFF0068FF), c.zaloNumber.isNotEmpty,
            () async {
          final ok = await openZalo(context, c.zaloNumber);
          _afterContact(c, CareType.zalo, ok);
        }),
        _actionBtn('Facebook', Icons.facebook, const Color(0xFF1877F2),
            c.facebook.trim().isNotEmpty, () async {
          final ok = await openFacebook(context, c.facebook);
          _afterContact(c, CareType.nhanTin, ok);
        }),
      ],
    );
  }

  Widget _actionBtn(
      String label, IconData icon, Color color, bool enabled, VoidCallback onTap) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Material(
          color: enabled ? color : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: enabled ? onTap : null,
            child: SizedBox(
              height: 76,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 30),
                  const SizedBox(height: 4),
                  FittedBox(
                    child: Text(label,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _appointmentCard(Customer c) {
    final t = c.nextCall;
    final overdue = t != null && t.isBefore(DateTime.now());
    return SectionCard(
      title: 'Lịch hẹn',
      icon: Icons.alarm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t == null
                ? 'Chưa có lịch hẹn'
                : '${overdue ? 'ĐÃ QUÁ HẸN - ' : ''}${c.apptType}: ${fmtFriendly(t)}',
            style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: t == null ? Colors.grey : (overdue ? Colors.red : kNavy)),
          ),
          if (t != null && !overdue)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                  'Báo trước ${c.remindMinutes >= 60 ? '1 tiếng' : '30 phút'}.',
                  style: const TextStyle(fontSize: 15)),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _setAppointment(c),
                  icon: const Icon(Icons.event),
                  label: Text(t == null ? 'Đặt lịch hẹn' : 'Đổi lịch hẹn'),
                ),
              ),
              if (t != null) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                  onPressed: () => _clearAppointment(c),
                  child: const Text('Bỏ hẹn'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _needCard(Customer c) {
    final empty = [c.need, c.propertyType, c.area, c.budget, c.timeline, c.source, c.zalo,
            c.facebook, c.note]
        .every((e) => e.trim().isEmpty);
    return SectionCard(
      title: 'Nhu cầu & thông tin',
      icon: Icons.home_work,
      trailing: TextButton(onPressed: () => _edit(c), child: const Text('Sửa')),
      child: empty
          ? const Text('Chưa có thông tin. Bấm "Sửa" để thêm nhu cầu của khách.',
              style: TextStyle(fontSize: 16))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InfoRow(Icons.shopping_cart, 'Nhu cầu', c.need),
                InfoRow(Icons.apartment, 'Loại BĐS', c.propertyType),
                InfoRow(Icons.place, 'Khu vực', c.area),
                InfoRow(Icons.account_balance_wallet, 'Ngân sách', c.budget),
                InfoRow(Icons.schedule, 'Thời gian muốn mua', c.timeline),
                InfoRow(Icons.campaign, 'Nguồn khách', c.source),
                InfoRow(Icons.chat_bubble, 'Zalo', c.zalo),
                InfoRow(Icons.facebook, 'Facebook', c.facebook),
                InfoRow(Icons.sticky_note_2, 'Ghi chú', c.note),
              ],
            ),
    );
  }

  Widget _projectsCard(Customer c) {
    final list = _store.projectsOf(c.id!);
    return SectionCard(
      title: 'Dự án quan tâm',
      icon: Icons.apartment,
      trailing: _store.projects.isEmpty
          ? null
          : TextButton(onPressed: () => _editProjects(c), child: const Text('Chọn')),
      child: list.isEmpty
          ? Text(
              _store.projects.isEmpty
                  ? 'Chưa có dự án. Thêm ở mục "Dự án" trên trang chủ.'
                  : 'Chưa gắn dự án. Bấm "Chọn".',
              style: const TextStyle(fontSize: 16))
          : Column(
              children: [
                for (final p in list)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: ProjectThumb(p, size: 52),
                    title: Text(p.name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    subtitle: Text(
                        [p.price, p.location].where((e) => e.isNotEmpty).join(' · '),
                        style: const TextStyle(fontSize: 15)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ProjectDetailScreen(projectId: p.id!))),
                  ),
              ],
            ),
    );
  }

  Widget _dealsCard(Customer c) {
    final list = _store.dealsOf(c.id!);
    return SectionCard(
      title: 'Tiền & Hoa hồng',
      icon: Icons.payments,
      trailing: TextButton.icon(
        onPressed: () => _openDeal(c, null),
        icon: const Icon(Icons.add),
        label: const Text('Thêm'),
      ),
      child: list.isEmpty
          ? const Text('Chưa có giao dịch. Khi khách cọc / chốt, bấm "Thêm".',
              style: TextStyle(fontSize: 16))
          : Column(children: [for (final d in list) DealTile(deal: d, onTap: () => _openDeal(c, d))]),
    );
  }

  Widget _historySection(Customer c) {
    return SectionCard(
      title: 'Lịch sử chăm sóc (${_logs.where((l) => l.type != CareType.capNhat).length})',
      icon: Icons.history,
      child: _loadingLogs
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()))
          : _logs.isEmpty
              ? const Text('Chưa có lần chăm sóc nào.\nBấm "Ghi chăm sóc" sau mỗi lần gọi / nhắn.',
                  style: TextStyle(fontSize: 16))
              : Column(
                  children: [for (final log in _logs) _logItem(log)],
                ),
    );
  }

  Widget _logItem(CareLog log) {
    final isAuto = log.type == CareType.capNhat;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 0, 10),
      decoration: BoxDecoration(
        color: isAuto ? Colors.grey.shade100 : kNavyLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(CareType.icon(log.type), color: isAuto ? Colors.grey : kNavy, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${log.type} · ${fmtDateTime(log.time)}',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isAuto ? Colors.grey.shade700 : kNavy)),
                if (log.content.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(log.content,
                        style: TextStyle(
                            fontSize: isAuto ? 15 : 17,
                            color: isAuto ? Colors.grey.shade700 : Colors.black87)),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Xóa',
            icon: Icon(Icons.delete_outline, color: Colors.grey.shade500),
            onPressed: () => _deleteLog(log),
          ),
        ],
      ),
    );
  }
}

/// Một dòng giao dịch (dùng chung ở nhiều màn hình).
class DealTile extends StatelessWidget {
  const DealTile({super.key, required this.deal, required this.onTap, this.showCustomer = false});
  final Deal deal;
  final VoidCallback onTap;
  final bool showCustomer;

  @override
  Widget build(BuildContext context) {
    final store = Store.instance;
    final d = deal;
    final project = store.project(d.projectId);
    final title = [
      if (showCustomer) store.customer(d.customerId)?.name ?? '',
      project?.name ?? '',
      d.unit,
    ].where((e) => e.isNotEmpty).join(' · ');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: d.isClosed ? const Color(0xFFE8F5E9) : kGoldLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: d.isClosed ? Colors.green.shade300 : kGold),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title.isEmpty ? 'Giao dịch' : title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Text(d.stage,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: d.isClosed ? Colors.green.shade800 : const Color(0xFF8A6D10))),
              ],
            ),
            const SizedBox(height: 4),
            Text('Ngày ${fmtDate(d.date)}', style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 4),
            Text(
                'Giá chốt: ${fmtMoney(d.price)}  ·  Cọc: ${fmtMoney(d.deposit)}  ·  Còn: ${fmtMoney(d.remaining)}',
                style: const TextStyle(fontSize: 16)),
            Text(
              'HH của tôi: ${fmtMoney(d.myCommission)} — ${d.received ? 'ĐÃ NHẬN' : 'CHƯA NHẬN'}',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: d.received ? Colors.green.shade800 : Colors.red.shade700),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================= Bảng đặt lịch hẹn =======================

class _ApptResult {
  _ApptResult(this.time, this.type, this.remind);
  final DateTime time;
  final String type;
  final int remind;
}

class _AppointmentSheet extends StatefulWidget {
  const _AppointmentSheet({required this.customer});
  final Customer customer;

  @override
  State<_AppointmentSheet> createState() => _AppointmentSheetState();
}

class _AppointmentSheetState extends State<_AppointmentSheet> {
  late String _type = widget.customer.apptType;
  late int _remind = widget.customer.remindMinutes;
  DateTime? _time;

  @override
  void initState() {
    super.initState();
    final t = widget.customer.nextCall;
    if (t != null && t.isAfter(DateTime.now())) _time = t;
  }

  void _quick(Duration d) {
    final now = DateTime.now().add(d);
    setState(() => _time = DateTime(now.year, now.month, now.day, now.hour, now.minute));
  }

  void _tomorrowAt(int hour) {
    final n = DateTime.now().add(const Duration(days: 1));
    setState(() => _time = DateTime(n.year, n.month, n.day, hour));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Đặt hẹn: ${widget.customer.name}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const FieldLabel('Loại hẹn'),
            ChoiceGroup(
              options: Opt.apptTypes,
              value: _type,
              allowEmpty: false,
              onChanged: (v) => setState(() => _type = v),
            ),
            const FieldLabel('Chọn nhanh'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                    label: const Text('Sau 2 tiếng', style: TextStyle(fontSize: 16)),
                    onPressed: () => _quick(const Duration(hours: 2))),
                ActionChip(
                    label: const Text('9h sáng mai', style: TextStyle(fontSize: 16)),
                    onPressed: () => _tomorrowAt(9)),
                ActionChip(
                    label: const Text('14h chiều mai', style: TextStyle(fontSize: 16)),
                    onPressed: () => _tomorrowAt(14)),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final t = await pickDateTime(context, initial: _time);
                if (t != null) setState(() => _time = t);
              },
              icon: const Icon(Icons.event),
              label: Text(_time == null ? 'Chọn ngày giờ khác' : fmtDateTime(_time!)),
            ),
            const FieldLabel('Báo trước'),
            ChoiceGroup(
              options: const ['30 phút', '1 tiếng'],
              value: _remind >= 60 ? '1 tiếng' : '30 phút',
              allowEmpty: false,
              color: kGold,
              onChanged: (v) => setState(() => _remind = v == '1 tiếng' ? 60 : 30),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                final t = _time;
                if (t == null || !t.isAfter(DateTime.now())) {
                  showSnack(context, 'Hãy chọn giờ hẹn ở tương lai');
                  return;
                }
                Navigator.pop(context, _ApptResult(t, _type, _remind));
              },
              icon: const Icon(Icons.alarm_add),
              label: Text(_time == null ? 'LƯU HẸN' : 'LƯU HẸN · ${fmtFriendly(_time!)}'),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(60)),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================= Bảng ghi lịch sử chăm sóc =======================

class _LogResult {
  _LogResult(this.log, this.clearAppointment, this.newStatus, this.scheduleNext);
  final CareLog log;
  final bool clearAppointment;
  final CustomerStatus? newStatus;
  final bool scheduleNext;
}

class _AddLogSheet extends StatefulWidget {
  const _AddLogSheet({required this.customer, required this.initialType});
  final Customer customer;
  final String initialType;

  @override
  State<_AddLogSheet> createState() => _AddLogSheetState();
}

class _AddLogSheetState extends State<_AddLogSheet> {
  late String _type = widget.initialType;
  DateTime _time = DateTime.now();
  final _content = TextEditingController();
  late bool _clear;
  bool _scheduleNext = false;
  CustomerStatus? _newStatus;

  @override
  void initState() {
    super.initState();
    final t = widget.customer.nextCall;
    _clear = t != null && t.isBefore(Store.endOfToday);
  }

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasAppt = widget.customer.nextCall != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Ghi chăm sóc: ${widget.customer.name}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ChoiceGroup(
              options: CareType.all,
              value: _type,
              allowEmpty: false,
              onChanged: (v) => setState(() => _type = v),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final t = await pickDateTime(context, initial: _time);
                if (t != null) setState(() => _time = t);
              },
              icon: const Icon(Icons.schedule),
              label: Text('Lúc: ${fmtDateTime(_time)}'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _content,
              autofocus: true,
              minLines: 3,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 18),
              decoration: const InputDecoration(
                labelText: 'Khách nói gì? Hẹn gì?',
                hintText: 'VD: Khách thích lô góc, tài chính 2 tỷ, cuối tuần đi xem',
                alignLabelWithHint: true,
              ),
            ),
            const FieldLabel('Cập nhật trạng thái (không bắt buộc)'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in CustomerStatus.values)
                  if (s != widget.customer.status)
                    ChoiceChip(
                      label: Text(s.label,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _newStatus == s ? Colors.white : s.color)),
                      selected: _newStatus == s,
                      showCheckmark: false,
                      selectedColor: s.color,
                      backgroundColor: Colors.white,
                      side: BorderSide(color: s.color),
                      onSelected: (_) =>
                          setState(() => _newStatus = _newStatus == s ? null : s),
                    ),
              ],
            ),
            if (hasAppt)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _clear,
                onChanged: (v) => setState(() => _clear = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Xong lịch hẹn cũ → bỏ hẹn', style: TextStyle(fontSize: 17)),
              ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _scheduleNext,
              onChanged: (v) => setState(() => _scheduleNext = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Đặt lịch hẹn tiếp theo', style: TextStyle(fontSize: 17)),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(
                  context,
                  _LogResult(
                    CareLog(
                      customerId: widget.customer.id!,
                      type: _type,
                      content: _content.text.trim(),
                      time: _time,
                    ),
                    hasAppt && _clear,
                    _newStatus,
                    _scheduleNext,
                  ),
                );
              },
              icon: const Icon(Icons.save, size: 26),
              label: const Text('LƯU'),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(60)),
            ),
          ],
        ),
      ),
    );
  }
}
