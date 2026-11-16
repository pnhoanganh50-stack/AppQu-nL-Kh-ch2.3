import 'package:flutter/material.dart';

import '../main.dart';
import '../notifications.dart';
import '../security.dart';
import '../store.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'customer_detail_screen.dart';
import 'customer_form_screen.dart';
import 'customer_list_screen.dart';
import 'data_screen.dart';
import 'money_screen.dart';
import 'project_list_screen.dart';
import 'settings_screen.dart';

/// Trang chủ: chỉ 3 nút chính + 3 nút nhỏ phía dưới.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    Noti.onTap = _openCustomer;
    _start();
  }

  Future<void> _start() async {
    await Store.instance.load();
    try {
      await Noti.requestPermission();
      await Noti.rescheduleAll(Store.instance.customers);
    } catch (_) {}
    final launchId = Noti.launchCustomerId;
    if (launchId != null) {
      Noti.launchCustomerId = null;
      _openCustomer(launchId);
    }
  }

  void _openCustomer(int id) {
    navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => CustomerDetailScreen(customerId: id)));
  }

  void _go(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) setState(() {}); // cập nhật nhắc sao lưu
  }

  Future<void> _addCustomer() async {
    final id = await Navigator.push<int>(
        context, MaterialPageRoute(builder: (_) => const CustomerFormScreen()));
    if (id != null && mounted) _openCustomer(id);
  }

  @override
  Widget build(BuildContext context) {
    final store = Store.instance;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản Lý Khách BĐS'),
        actions: [
          IconButton(
            tooltip: 'Cài đặt',
            icon: const Icon(Icons.settings),
            onPressed: () => _go(const SettingsScreen()),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final today = store.needCareToday.length;
          final month = store.closedInMonth(DateTime.now());
          final myComm = month.fold<double>(0, (s, d) => s + d.myCommission);
          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Text(fmtToday(),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600, color: kNavy)),
                const SizedBox(height: 4),
                Text(
                  'Tháng này: chốt ${month.length} căn · Hoa hồng ${fmtMoney(myComm)}',
                  style: const TextStyle(
                      fontSize: 16, color: Color(0xFF8A6D10), fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                _BackupBanner(onTap: () => _go(const DataScreen())),
                BigHomeButton(
                  icon: Icons.person_add_alt_1,
                  label: 'THÊM KHÁCH',
                  subtitle: 'Nhập khách mới',
                  background: kGold,
                  foreground: kNavy,
                  onTap: _addCustomer,
                ),
                const SizedBox(height: 14),
                BigHomeButton(
                  icon: Icons.people_alt,
                  label: 'DANH SÁCH KHÁCH',
                  subtitle: '${store.customers.length} khách · tìm theo tên, SĐT, khu vực',
                  onTap: () => _go(const CustomerListScreen()),
                ),
                const SizedBox(height: 14),
                BigHomeButton(
                  icon: Icons.notifications_active,
                  label: 'CẦN GỌI HÔM NAY',
                  subtitle: today == 0 ? 'Không có lịch hẹn' : 'Gồm cả khách quá hẹn',
                  badge: today,
                  background: const Color(0xFF1C4A9E),
                  onTap: () => _go(const CustomerListScreen(todayOnly: true)),
                ),
                const SizedBox(height: 26),
                Row(
                  children: [
                    _SmallButton(
                      icon: Icons.apartment,
                      label: 'Dự án',
                      onTap: () => _go(const ProjectListScreen()),
                    ),
                    _SmallButton(
                      icon: Icons.payments,
                      label: 'Tiền & HH',
                      onTap: () => _go(const MoneyScreen()),
                    ),
                    _SmallButton(
                      icon: Icons.cloud_upload,
                      label: 'Sao lưu\nExcel',
                      onTap: () => _go(const DataScreen()),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: Colors.white,
          elevation: 1,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: SizedBox(
              height: 96,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 32, color: kGold),
                  const SizedBox(height: 4),
                  Text(label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700, color: kNavy)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Nhắc sao lưu nếu chưa sao lưu hơn 7 ngày.
class _BackupBanner extends StatelessWidget {
  const _BackupBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final store = Store.instance;
    if (store.customers.isEmpty) return const SizedBox.shrink();
    final last = Security.lastBackup;
    final days = last == null ? null : DateTime.now().difference(last).inDays;
    if (days != null && days < 7) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.deepOrange, size: 32),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    days == null
                        ? 'Bạn chưa sao lưu lần nào. Mất máy là mất khách!\nBấm để sao lưu ngay.'
                        : 'Đã $days ngày chưa sao lưu.\nBấm để sao lưu ngay.',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600, color: Colors.deepOrange),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
