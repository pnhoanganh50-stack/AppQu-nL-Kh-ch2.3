import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../utils.dart';
import '../widgets.dart';
import 'customer_detail_screen.dart';
import 'customer_form_screen.dart';

/// Danh sách khách: tìm theo tên / SĐT / khu vực / dự án, lọc theo trạng thái.
/// [todayOnly] = true: chỉ hiện khách cần gọi hôm nay.
class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key, this.todayOnly = false});
  final bool todayOnly;

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final _search = TextEditingController();
  CustomerStatus? _status;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open(int id) => Navigator.push(context,
      MaterialPageRoute(builder: (_) => CustomerDetailScreen(customerId: id)));

  Future<void> _add() async {
    final id = await Navigator.push<int>(
        context, MaterialPageRoute(builder: (_) => const CustomerFormScreen()));
    if (id != null && mounted) _open(id);
  }

  @override
  Widget build(BuildContext context) {
    final store = Store.instance;
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.todayOnly ? 'Cần gọi hôm nay' : 'Danh sách khách')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.person_add_alt_1, size: 28),
        label: const Text('Thêm khách'),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([store, _search]),
        builder: (context, _) {
          final base = widget.todayOnly ? store.needCareToday : store.customers;
          final query = _search.text;
          final list = base.where((c) {
            if (_status != null && c.status != _status) return false;
            final projectNames = store.projectsOf(c.id!).map((p) => p.name).join(' ');
            return matchCustomer(c, query, extra: projectNames);
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: TextField(
                  controller: _search,
                  style: const TextStyle(fontSize: 18),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Tìm tên, SĐT, khu vực, dự án',
                    prefixIcon: const Icon(Icons.search, size: 28),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear), onPressed: _search.clear),
                  ),
                ),
              ),
              SizedBox(
                height: 58,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  children: [
                    _chip('Tất cả (${base.length})', _status == null, Colors.blueGrey,
                        () => setState(() => _status = null)),
                    for (final s in CustomerStatus.values)
                      if (base.any((c) => c.status == s) || _status == s)
                        _chip('${s.label} (${base.where((c) => c.status == s).length})',
                            _status == s, s.color, () => setState(() => _status = s)),
                  ],
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? EmptyView(
                        icon: widget.todayOnly ? Icons.celebration : Icons.person_search,
                        text: widget.todayOnly
                            ? 'Hôm nay không có lịch hẹn nào.\nMở 1 khách → "Đặt lịch hẹn" để được nhắc.'
                            : store.customers.isEmpty
                                ? 'Chưa có khách nào.\nBấm "Thêm khách" để bắt đầu.'
                                : 'Không tìm thấy khách phù hợp.')
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 100, top: 4),
                        itemCount: list.length,
                        itemBuilder: (_, i) => CustomerTile(
                            customer: list[i], onTap: () => _open(list[i].id!)),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _chip(String label, bool selected, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : color)),
        selected: selected,
        showCheckmark: false,
        selectedColor: color,
        backgroundColor: Colors.white,
        side: BorderSide(color: color),
        onSelected: (_) => onTap(),
      ),
    );
  }
}
