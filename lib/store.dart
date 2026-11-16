import 'package:flutter/foundation.dart';

import 'db.dart';
import 'models.dart';
import 'notifications.dart';

/// Giữ toàn bộ dữ liệu cho app. Màn hình nào cũng "nghe" Store
/// để tự cập nhật khi dữ liệu thay đổi.
class Store extends ChangeNotifier {
  Store._();
  static final Store instance = Store._();

  final AppDb _db = AppDb.instance;

  List<Customer> customers = [];
  List<Project> projects = [];
  List<Deal> deals = [];
  Map<int, Set<int>> interests = {}; // id khách -> các id dự án quan tâm
  int logsToday = 0;
  bool loaded = false;

  Future<void> load() async {
    customers = await _db.getCustomers();
    projects = await _db.getProjects();
    deals = await _db.getDeals();
    interests = await _db.getInterests();
    logsToday = await _db.countLogsToday();
    loaded = true;
    notifyListeners();
  }

  // ================== Tra cứu ==================

  Customer? customer(int id) {
    for (final c in customers) {
      if (c.id == id) return c;
    }
    return null;
  }

  Project? project(int? id) {
    if (id == null) return null;
    for (final p in projects) {
      if (p.id == id) return p;
    }
    return null;
  }

  Set<int> interestIds(int customerId) => interests[customerId] ?? <int>{};

  List<Project> projectsOf(int customerId) {
    final ids = interestIds(customerId);
    return projects.where((p) => ids.contains(p.id)).toList();
  }

  List<Customer> customersOfProject(int projectId) => customers
      .where((c) => interestIds(c.id!).contains(projectId))
      .toList();

  List<Deal> dealsOf(int customerId) =>
      deals.where((d) => d.customerId == customerId).toList();

  List<Deal> dealsOfProject(int projectId) =>
      deals.where((d) => d.projectId == projectId).toList();

  /// Số căn đã bán / đã cọc của dự án (dùng để "trừ hàng").
  int soldUnits(Project p) => deals.where((d) => d.projectId == p.id).length;

  int remainingUnits(Project p) {
    final r = p.totalUnits - soldUnits(p);
    return r < 0 ? 0 : r;
  }

  bool isSoldOut(Project p) => p.soldManual || remainingUnits(p) == 0;

  // ================== Khách hàng ==================

  /// Thêm mới hoặc cập nhật khách. Trả về id.
  Future<int> saveCustomer(Customer c, {Set<int>? projectIds}) async {
    c.updatedAt = DateTime.now();
    if (c.id == null) {
      c.id = await _db.insertCustomer(c);
    } else {
      await _db.updateCustomer(c);
    }
    if (projectIds != null) await _db.setInterests(c.id!, projectIds);
    try {
      await Noti.schedule(c);
    } catch (_) {}
    await load();
    return c.id!;
  }

  Future<void> deleteCustomer(Customer c) async {
    if (c.id == null) return;
    try {
      await Noti.cancel(c.id!);
    } catch (_) {}
    await _db.deleteCustomer(c.id!);
    await load();
  }

  /// Đổi trạng thái, đồng thời tự ghi 1 dòng vào lịch sử chăm sóc.
  Future<void> changeStatus(Customer c, CustomerStatus s) async {
    if (c.status == s) return;
    await _db.insertLog(CareLog(
      customerId: c.id!,
      type: CareType.capNhat,
      content: 'Đổi trạng thái: ${c.status.label} → ${s.label}',
      time: DateTime.now(),
    ));
    final copy = c.copy()..status = s;
    await saveCustomer(copy);
  }

  Future<void> setAppointment(Customer c, DateTime? t,
      {String? type, int? remindMinutes}) async {
    final copy = c.copy()..nextCall = t;
    if (type != null) copy.apptType = type;
    if (remindMinutes != null) copy.remindMinutes = remindMinutes;
    await saveCustomer(copy);
  }

  Future<void> setInterests(Customer c, Set<int> projectIds) async {
    await _db.setInterests(c.id!, projectIds);
    await load();
  }

  // ================== Lịch sử chăm sóc ==================

  Future<List<CareLog>> logsOf(int customerId) => _db.getLogs(customerId);

  Future<void> addLog(CareLog log, {bool clearAppointment = false}) async {
    await _db.insertLog(log);
    final c = customer(log.customerId);
    if (c != null) {
      final copy = c.copy();
      if (clearAppointment) copy.nextCall = null;
      await saveCustomer(copy); // đưa khách lên đầu danh sách
    } else {
      await load();
    }
  }

  Future<void> deleteLog(CareLog log) async {
    if (log.id == null) return;
    await _db.deleteLog(log.id!);
    await load();
  }

  // ================== Dự án ==================

  Future<int> saveProject(Project p) async {
    if (p.id == null) {
      p.id = await _db.insertProject(p);
    } else {
      await _db.updateProject(p);
    }
    await load();
    return p.id!;
  }

  Future<void> deleteProject(Project p) async {
    if (p.id == null) return;
    await _db.deleteProject(p.id!);
    await load();
  }

  // ================== Giao dịch ==================

  /// Lưu giao dịch, đồng thời cập nhật trạng thái khách (Đã cọc / Đã chốt)
  /// và tự gắn khách vào dự án.
  Future<void> saveDeal(Deal d) async {
    if (d.id == null) {
      d.id = await _db.insertDeal(d);
    } else {
      await _db.updateDeal(d);
    }
    final c = customer(d.customerId);
    if (c != null) {
      final target = d.isClosed ? CustomerStatus.daChot : CustomerStatus.daCoc;
      final shouldUpdate = c.status != CustomerStatus.daChot && c.status != target;
      if (d.projectId != null) {
        final ids = Set<int>.of(interestIds(c.id!))..add(d.projectId!);
        await _db.setInterests(c.id!, ids);
      }
      if (shouldUpdate) {
        await changeStatus(c, target);
        return;
      }
    }
    await load();
  }

  Future<void> deleteDeal(Deal d) async {
    if (d.id == null) return;
    await _db.deleteDeal(d.id!);
    await load();
  }

  // ================== Thống kê ==================

  static DateTime get endOfToday {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day).add(const Duration(days: 1));
  }

  /// Khách cần gọi hôm nay: có hẹn trong hôm nay hoặc đã quá hẹn.
  List<Customer> get needCareToday {
    final end = endOfToday;
    final list = customers
        .where((c) =>
            c.nextCall != null && c.nextCall!.isBefore(end) && !c.status.inactive)
        .toList();
    list.sort((a, b) => a.nextCall!.compareTo(b.nextCall!));
    return list;
  }

  int countStatus(CustomerStatus s) => customers.where((c) => c.status == s).length;

  /// Giao dịch "Đã chốt" trong tháng [month] (lấy năm + tháng).
  List<Deal> closedInMonth(DateTime month) => deals
      .where((d) =>
          d.isClosed && d.date.year == month.year && d.date.month == month.month)
      .toList();

  List<Deal> depositsInMonth(DateTime month) => deals
      .where((d) =>
          !d.isClosed && d.date.year == month.year && d.date.month == month.month)
      .toList();

  List<Deal> get unpaidCommissions =>
      deals.where((d) => !d.received && d.myCommission > 0).toList();
}
