import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';

/// Thêm / sửa giao dịch: giá chốt, cọc, còn lại, hoa hồng, chia ai, đã nhận chưa.
class DealFormScreen extends StatefulWidget {
  const DealFormScreen({super.key, required this.customerId, this.deal, this.initialStage});
  final int customerId;
  final Deal? deal;
  final String? initialStage;

  @override
  State<DealFormScreen> createState() => _DealFormScreenState();
}

class _DealFormScreenState extends State<DealFormScreen> {
  late final Deal _d;
  late final TextEditingController _unit, _price, _deposit, _comm, _shared, _myComm, _note;
  bool _myCommEdited = false;

  bool get _isEdit => widget.deal != null;

  @override
  void initState() {
    super.initState();
    final src = widget.deal;
    _d = src == null
        ? Deal(customerId: widget.customerId, stage: widget.initialStage ?? DealStage.coc)
        : Deal.fromMap(src.toMap());
    if (src == null) {
      // Gợi ý dự án đầu tiên khách quan tâm (còn hàng).
      final store = Store.instance;
      for (final p in store.projectsOf(widget.customerId)) {
        if (!store.isSoldOut(p)) {
          _d.projectId = p.id;
          break;
        }
      }
    }
    _unit = TextEditingController(text: _d.unit);
    _price = TextEditingController(text: moneyInput(_d.price));
    _deposit = TextEditingController(text: moneyInput(_d.deposit));
    _comm = TextEditingController(text: moneyInput(_d.commission));
    _shared = TextEditingController(text: _d.sharedWith);
    _myComm = TextEditingController(text: moneyInput(_d.myCommission));
    _note = TextEditingController(text: _d.note);
    _myCommEdited = _d.myCommission != 0 && _d.myCommission != _d.commission;
  }

  @override
  void dispose() {
    for (final t in [_unit, _price, _deposit, _comm, _shared, _myComm, _note]) {
      t.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    _d
      ..unit = _unit.text.trim()
      ..price = parseMoney(_price.text)
      ..deposit = parseMoney(_deposit.text)
      ..commission = parseMoney(_comm.text)
      ..sharedWith = _shared.text.trim()
      ..myCommission = parseMoney(_myComm.text)
      ..note = _note.text.trim();
    if (_d.myCommission == 0 && _d.commission > 0 && _d.sharedWith.isEmpty) {
      _d.myCommission = _d.commission;
    }
    await Store.instance.saveDeal(_d);
    if (!mounted) return;
    showSnack(context, 'Đã lưu giao dịch');
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await confirm(context, 'Xóa giao dịch?', 'Giao dịch này sẽ bị xóa.',
        ok: 'Xóa', danger: true);
    if (!ok) return;
    await Store.instance.deleteDeal(_d);
    if (mounted) Navigator.pop(context);
  }

  Widget _moneyField(TextEditingController c, String label, IconData icon,
      {ValueChanged<String>? onChanged}) {
    final v = parseMoney(c.text);
    return InputField(
      controller: c,
      label: '$label (triệu đồng)',
      icon: icon,
      keyboard: const TextInputType.numberWithOptions(decimal: true),
      hint: 'VD: 2500 = 2,5 tỷ',
      helper: v == 0 ? null : '= ${fmtMoney(v)}',
      onChanged: (s) {
        onChanged?.call(s);
        setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = Store.instance;
    final customer = store.customer(widget.customerId);
    final remaining = parseMoney(_price.text) - parseMoney(_deposit.text);
    // Dự án đang quan tâm lên đầu.
    final interested = store.interestIds(widget.customerId);
    final projects = [...store.projects]
      ..sort((a, b) => (interested.contains(b.id) ? 1 : 0) - (interested.contains(a.id) ? 1 : 0));

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Sửa giao dịch' : 'Thêm giao dịch'),
        actions: [
          if (_isEdit)
            IconButton(icon: const Icon(Icons.delete), tooltip: 'Xóa', onPressed: _delete),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        children: [
          if (customer != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10, left: 4),
              child: Text('Khách: ${customer.name}',
                  style: const TextStyle(
                      fontSize: 19, fontWeight: FontWeight.bold, color: kNavy)),
            ),
          SectionCard(
            title: 'Căn / lô',
            icon: Icons.apartment,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<int?>(
                  value: store.project(_d.projectId) == null ? null : _d.projectId,
                  isExpanded: true,
                  style: const TextStyle(fontSize: 18, color: Colors.black87),
                  decoration: const InputDecoration(
                      labelText: 'Dự án', prefixIcon: Icon(Icons.location_city)),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('— Không chọn —')),
                    for (final p in projects)
                      DropdownMenuItem<int?>(
                        value: p.id,
                        child: Text(
                          '${p.name}${store.isSoldOut(p) ? ' (hết hàng)' : ' (còn ${store.remainingUnits(p)})'}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _d.projectId = v),
                ),
                const SizedBox(height: 14),
                InputField(
                    controller: _unit,
                    label: 'Mã căn / lô',
                    icon: Icons.tag,
                    hint: 'VD: Lô A12, Căn 1508'),
                const FieldLabel('Tình trạng'),
                ChoiceGroup(
                  options: DealStage.all,
                  value: _d.stage,
                  allowEmpty: false,
                  color: kGold,
                  onChanged: (v) => setState(() => _d.stage = v),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final t = await pickDate(context, initial: _d.date);
                    if (t != null) setState(() => _d.date = t);
                  },
                  icon: const Icon(Icons.event),
                  label: Text('Ngày ${_d.stage == DealStage.chot ? 'chốt' : 'cọc'}: ${fmtDate(_d.date)}'),
                ),
              ],
            ),
          ),
          SectionCard(
            title: 'Tiền',
            icon: Icons.payments,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _moneyField(_price, 'Giá chốt', Icons.sell),
                _moneyField(_deposit, 'Đã cọc', Icons.savings),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: kNavyLight, borderRadius: BorderRadius.circular(12)),
                  child: Text('Còn lại: ${fmtMoney(remaining < 0 ? 0 : remaining)}',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold, color: kNavy)),
                ),
              ],
            ),
          ),
          SectionCard(
            title: 'Hoa hồng',
            icon: Icons.workspace_premium,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _moneyField(_comm, 'Tổng hoa hồng', Icons.monetization_on, onChanged: (s) {
                  if (!_myCommEdited) _myComm.text = s;
                }),
                InputField(
                    controller: _shared,
                    label: 'Chia cho ai',
                    icon: Icons.group,
                    hint: 'VD: Chia anh Hùng 30%'),
                _moneyField(_myComm, 'Tôi nhận', Icons.account_balance_wallet,
                    onChanged: (_) => _myCommEdited = true),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _d.received,
                  onChanged: (v) => setState(() => _d.received = v),
                  title: Text(_d.received ? 'ĐÃ NHẬN hoa hồng' : 'CHƯA NHẬN hoa hồng',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _d.received ? Colors.green.shade800 : Colors.red.shade700)),
                ),
              ],
            ),
          ),
          SectionCard(
            title: 'Ghi chú',
            icon: Icons.sticky_note_2,
            child: InputField(controller: _note, label: 'Ghi chú', maxLines: 3),
          ),
          ElevatedButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save, size: 26),
            label: const Text('LƯU GIAO DỊCH'),
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(62)),
          ),
        ],
      ),
    );
  }
}
