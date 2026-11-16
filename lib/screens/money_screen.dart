import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'customer_detail_screen.dart';
import 'deal_form_screen.dart';

/// Tiền & Hoa hồng: thống kê theo tháng + hoa hồng chưa nhận.
class MoneyScreen extends StatefulWidget {
  const MoneyScreen({super.key});

  @override
  State<MoneyScreen> createState() => _MoneyScreenState();
}

class _MoneyScreenState extends State<MoneyScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  void _shift(int m) => setState(() => _month = DateTime(_month.year, _month.month + m));

  void _openDeal(Deal d) => Navigator.push(context,
      MaterialPageRoute(builder: (_) => DealFormScreen(customerId: d.customerId, deal: d)));

  @override
  Widget build(BuildContext context) {
    final store = Store.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Tiền & Hoa hồng')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final closed = store.closedInMonth(_month);
          final deposits = store.depositsInMonth(_month);
          double sum(Iterable<Deal> l, double Function(Deal) f) =>
              l.fold<double>(0, (s, d) => s + f(d));
          final totalValue = sum(closed, (d) => d.price);
          final myComm = sum(closed, (d) => d.myCommission);
          final received = sum(closed.where((d) => d.received), (d) => d.myCommission);
          final unpaid = store.unpaidCommissions;
          final monthDeals = [...closed, ...deposits]..sort((a, b) => b.date.compareTo(a.date));

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
            children: [
              Row(
                children: [
                  IconButton.filledTonal(
                      iconSize: 30,
                      onPressed: () => _shift(-1),
                      icon: const Icon(Icons.chevron_left)),
                  Expanded(
                    child: Text('Tháng ${_month.month}/${_month.year}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold, color: kNavy)),
                  ),
                  IconButton.filledTonal(
                      iconSize: 30,
                      onPressed: () => _shift(1),
                      icon: const Icon(Icons.chevron_right)),
                ],
              ),
              const SizedBox(height: 8),
              Row(children: [
                _stat('Số căn chốt', '${closed.length}', Icons.verified, Colors.green.shade700),
                _stat('Đang cọc', '${deposits.length}', Icons.savings, const Color(0xFF8A6D10)),
              ]),
              Row(children: [
                _stat('Hoa hồng của tôi', fmtMoney(myComm), Icons.workspace_premium, kNavy),
                _stat('Tổng giá trị chốt', fmtMoney(totalValue), Icons.sell, Colors.teal.shade700),
              ]),
              Row(children: [
                _stat('Đã nhận', fmtMoney(received), Icons.check_circle, Colors.green.shade700),
                _stat('Chưa nhận', fmtMoney(myComm - received), Icons.hourglass_bottom,
                    Colors.red.shade700),
              ]),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Giao dịch trong tháng (${monthDeals.length})',
                icon: Icons.receipt_long,
                child: monthDeals.isEmpty
                    ? const Text('Chưa có giao dịch trong tháng này.\n'
                        'Thêm giao dịch trong trang chi tiết khách.',
                        style: TextStyle(fontSize: 16))
                    : Column(children: [
                        for (final d in monthDeals)
                          DealTile(deal: d, showCustomer: true, onTap: () => _openDeal(d))
                      ]),
              ),
              SectionCard(
                title: 'Hoa hồng chưa nhận - tất cả (${unpaid.length})',
                icon: Icons.notification_important,
                child: unpaid.isEmpty
                    ? const Text('Không có. Tuyệt vời!', style: TextStyle(fontSize: 16))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Tổng: ${fmtMoney(sum(unpaid, (d) => d.myCommission))}',
                              style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade700)),
                          const SizedBox(height: 8),
                          for (final d in unpaid)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(store.customer(d.customerId)?.name ?? '',
                                  style: const TextStyle(
                                      fontSize: 18, fontWeight: FontWeight.w700)),
                              subtitle: Text(
                                  '${store.project(d.projectId)?.name ?? ''} ${d.unit} · ${fmtDate(d.date)}',
                                  style: const TextStyle(fontSize: 15)),
                              trailing: Text(fmtMoney(d.myCommission),
                                  style: const TextStyle(
                                      fontSize: 17, fontWeight: FontWeight.bold)),
                              onTap: () => _openDeal(d),
                              onLongPress: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          CustomerDetailScreen(customerId: d.customerId))),
                            ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _stat(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        color: Colors.white,
        elevation: 1,
        margin: const EdgeInsets.all(4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
              ),
              Text(label, style: TextStyle(fontSize: 15, color: Colors.grey.shade800)),
            ],
          ),
        ),
      ),
    );
  }
}
