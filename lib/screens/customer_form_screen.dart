import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';

/// Thêm / Sửa khách hàng. Trả về id khách (Navigator.pop) sau khi lưu.
class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({super.key, this.customer});
  final Customer? customer;

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Customer _c;
  late final Set<int> _projectIds;
  late final TextEditingController _name, _phone, _zalo, _fb, _area, _budget, _note;
  bool _saving = false;

  bool get _isEdit => widget.customer != null;

  @override
  void initState() {
    super.initState();
    _c = widget.customer?.copy() ?? Customer(name: '');
    _projectIds = _c.id == null
        ? <int>{}
        : Set<int>.of(Store.instance.interestIds(_c.id!));
    _name = TextEditingController(text: _c.name);
    _phone = TextEditingController(text: _c.phone);
    _zalo = TextEditingController(text: _c.zalo);
    _fb = TextEditingController(text: _c.facebook);
    _area = TextEditingController(text: _c.area);
    _budget = TextEditingController(text: _c.budget);
    _note = TextEditingController(text: _c.note);
  }

  @override
  void dispose() {
    for (final t in [_name, _phone, _zalo, _fb, _area, _budget, _note]) {
      t.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    _formKey.currentState?.validate();
    if (_name.text.trim().isEmpty) {
      showSnack(context, 'Vui lòng nhập tên khách (ô đầu tiên)');
      return;
    }
    final phone = _phone.text.trim();

    // Cảnh báo trùng số điện thoại.
    final pd = cleanPhone(phone);
    if (pd.isNotEmpty) {
      final dup = Store.instance.customers
          .where((x) => x.id != _c.id && cleanPhone(x.phone) == pd)
          .toList();
      if (dup.isNotEmpty) {
        final go = await confirm(context, 'Số điện thoại đã có',
            'Số $phone đang thuộc khách "${dup.first.name}".\nVẫn lưu thêm?',
            ok: 'Vẫn lưu');
        if (!go) return;
      }
    }

    setState(() => _saving = true);
    final oldStatus = widget.customer?.status;
    _c
      ..name = _name.text.trim()
      ..phone = phone
      ..zalo = _zalo.text.trim()
      ..facebook = _fb.text.trim()
      ..area = _area.text.trim()
      ..budget = _budget.text.trim()
      ..note = _note.text.trim();

    final store = Store.instance;
    if (_isEdit && oldStatus != null && oldStatus != _c.status) {
      // Đổi trạng thái qua form cũng ghi vào lịch sử.
      final newStatus = _c.status;
      _c.status = oldStatus;
      await store.saveCustomer(_c, projectIds: _projectIds);
      await store.changeStatus(store.customer(_c.id!)!, newStatus);
    } else {
      await store.saveCustomer(_c, projectIds: _projectIds);
    }
    if (!mounted) return;
    showSnack(context, _isEdit ? 'Đã lưu thay đổi' : 'Đã thêm khách ${_c.name}');
    Navigator.pop(context, _c.id);
  }

  Future<void> _pickAppointment() async {
    final t = await pickDateTime(context, initial: _c.nextCall);
    if (t != null) setState(() => _c.nextCall = t);
  }

  @override
  Widget build(BuildContext context) {
    final projects = Store.instance.projects;
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Sửa thông tin khách' : 'Thêm khách mới')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
          children: [
            SectionCard(
              title: 'Liên hệ',
              icon: Icons.person,
              child: Column(children: [
                InputField(
                  controller: _name,
                  label: 'Tên khách hàng *',
                  icon: Icons.person,
                  capitalization: TextCapitalization.words,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên khách' : null,
                ),
                InputField(
                    controller: _phone,
                    label: 'Số điện thoại',
                    icon: Icons.phone,
                    keyboard: TextInputType.phone),
                InputField(
                    controller: _zalo,
                    label: 'Zalo (bỏ trống = dùng SĐT)',
                    icon: Icons.chat_bubble,
                    keyboard: TextInputType.phone),
                InputField(
                    controller: _fb,
                    label: 'Facebook (link hoặc tên)',
                    icon: Icons.facebook,
                    keyboard: TextInputType.url,
                    capitalization: TextCapitalization.none),
                const FieldLabel('Nguồn khách'),
                ChoiceGroup(
                  options: Opt.sources,
                  value: _c.source,
                  onChanged: (v) => setState(() => _c.source = v),
                ),
              ]),
            ),
            SectionCard(
              title: 'Nhu cầu',
              icon: Icons.home_work,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const FieldLabel('Khách muốn'),
                  ChoiceGroup(
                      options: Opt.needs,
                      value: _c.need,
                      onChanged: (v) => setState(() => _c.need = v)),
                  const FieldLabel('Loại BĐS'),
                  ChoiceGroup(
                      options: Opt.propertyTypes,
                      value: _c.propertyType,
                      onChanged: (v) => setState(() => _c.propertyType = v)),
                  const SizedBox(height: 14),
                  InputField(
                      controller: _area,
                      label: 'Khu vực',
                      icon: Icons.place,
                      hint: 'VD: Quận 9, Thủ Đức'),
                  InputField(
                      controller: _budget,
                      label: 'Ngân sách',
                      icon: Icons.account_balance_wallet,
                      hint: 'VD: 2 - 3 tỷ'),
                  const FieldLabel('Thời gian muốn mua'),
                  ChoiceGroup(
                      options: Opt.timelines,
                      value: _c.timeline,
                      onChanged: (v) => setState(() => _c.timeline = v)),
                ],
              ),
            ),
            SectionCard(
              title: 'Dự án khách quan tâm',
              icon: Icons.apartment,
              child: projects.isEmpty
                  ? const Text('Chưa có dự án nào. Thêm dự án ở mục "Dự án" trên trang chủ.',
                      style: TextStyle(fontSize: 16))
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final p in projects)
                          FilterChip(
                            label: Text(p.name,
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: _projectIds.contains(p.id) ? Colors.white : kNavy)),
                            selected: _projectIds.contains(p.id),
                            selectedColor: kNavy,
                            checkmarkColor: kGold,
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: kNavy),
                            onSelected: (v) => setState(() {
                              if (v) {
                                _projectIds.add(p.id!);
                              } else {
                                _projectIds.remove(p.id);
                              }
                            }),
                          ),
                      ],
                    ),
            ),
            SectionCard(
              title: 'Trạng thái chăm sóc',
              icon: Icons.flag,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in CustomerStatus.values)
                    ChoiceChip(
                      avatar: Icon(s.icon,
                          size: 20, color: _c.status == s ? Colors.white : s.color),
                      label: Text(s.label,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _c.status == s ? Colors.white : s.color)),
                      selected: _c.status == s,
                      showCheckmark: false,
                      selectedColor: s.color,
                      backgroundColor: Colors.white,
                      side: BorderSide(color: s.color),
                      onSelected: (_) => setState(() => _c.status = s),
                    ),
                ],
              ),
            ),
            SectionCard(
              title: 'Lịch hẹn',
              icon: Icons.alarm,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ChoiceGroup(
                    options: Opt.apptTypes,
                    value: _c.apptType,
                    allowEmpty: false,
                    onChanged: (v) => setState(() => _c.apptType = v),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _c.nextCall == null ? 'Chưa đặt lịch hẹn' : fmtDateTime(_c.nextCall!),
                    style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w700, color: kNavy),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickAppointment,
                          icon: const Icon(Icons.event),
                          label: Text(_c.nextCall == null ? 'Chọn ngày giờ' : 'Đổi'),
                        ),
                      ),
                      if (_c.nextCall != null) ...[
                        const SizedBox(width: 8),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red)),
                          onPressed: () => setState(() => _c.nextCall = null),
                          child: const Text('Bỏ hẹn'),
                        ),
                      ],
                    ],
                  ),
                  const FieldLabel('Báo trước'),
                  ChoiceGroup(
                    options: const ['30 phút', '1 tiếng'],
                    value: _c.remindMinutes >= 60 ? '1 tiếng' : '30 phút',
                    allowEmpty: false,
                    color: kGold,
                    onChanged: (v) =>
                        setState(() => _c.remindMinutes = v == '1 tiếng' ? 60 : 30),
                  ),
                ],
              ),
            ),
            SectionCard(
              title: 'Ghi chú',
              icon: Icons.sticky_note_2,
              child: InputField(
                  controller: _note, label: 'Ghi chú thêm về khách', maxLines: 4),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save, size: 26),
              label: Text(_isEdit ? 'LƯU THAY ĐỔI' : 'LƯU KHÁCH HÀNG'),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(62)),
            ),
          ],
        ),
      ),
    );
  }
}
