import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models.dart';

/// Cơ sở dữ liệu SQLite lưu ngay trên điện thoại (không cần mạng).
class AppDb {
  AppDb._();
  static final AppDb instance = AppDb._();

  /// Các bảng, theo thứ tự dùng khi sao lưu / khôi phục.
  static const tables = [
    'customers',
    'projects',
    'customer_projects',
    'care_logs',
    'deals',
  ];

  Database? _db;

  Future<Database> get db async => _db ??= await _open();

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), 'bds_crm.db');
    return openDatabase(path, version: 1, onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE customers(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          phone TEXT, zalo TEXT, facebook TEXT,
          source TEXT, need TEXT, ptype TEXT, area TEXT,
          budget TEXT, timeline TEXT, note TEXT,
          status TEXT NOT NULL DEFAULT 'moi',
          next_call INTEGER, appt_type TEXT, remind_min INTEGER,
          created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL
        )''');
      await db.execute('''
        CREATE TABLE projects(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          images TEXT, location TEXT, price TEXT, size TEXT,
          legal TEXT, commission TEXT,
          total_units INTEGER NOT NULL DEFAULT 1,
          sold_manual INTEGER NOT NULL DEFAULT 0,
          note TEXT, created_at INTEGER NOT NULL
        )''');
      await db.execute('''
        CREATE TABLE customer_projects(
          customer_id INTEGER NOT NULL,
          project_id INTEGER NOT NULL,
          PRIMARY KEY(customer_id, project_id)
        )''');
      await db.execute('''
        CREATE TABLE care_logs(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customer_id INTEGER NOT NULL,
          type TEXT NOT NULL, content TEXT,
          created_at INTEGER NOT NULL
        )''');
      await db.execute('''
        CREATE TABLE deals(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customer_id INTEGER NOT NULL,
          project_id INTEGER,
          unit TEXT, stage TEXT NOT NULL,
          price REAL, deposit REAL, commission REAL,
          shared_with TEXT, my_commission REAL,
          received INTEGER NOT NULL DEFAULT 0,
          deal_date INTEGER NOT NULL, note TEXT,
          created_at INTEGER NOT NULL
        )''');
      await db.execute('CREATE INDEX idx_logs_c ON care_logs(customer_id)');
      await db.execute('CREATE INDEX idx_deals_c ON deals(customer_id)');
    });
  }

  Map<String, Object?> _noId(Map<String, Object?> m) => Map.of(m)..remove('id');

  // ---------- Khách hàng ----------

  Future<List<Customer>> getCustomers() async {
    final rows = await (await db).query('customers', orderBy: 'updated_at DESC');
    return rows.map(Customer.fromMap).toList();
  }

  Future<int> insertCustomer(Customer c) async =>
      (await db).insert('customers', _noId(c.toMap()));

  Future<void> updateCustomer(Customer c) async {
    await (await db)
        .update('customers', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
  }

  Future<void> deleteCustomer(int id) async {
    final d = await db;
    await d.transaction((t) async {
      await t.delete('care_logs', where: 'customer_id = ?', whereArgs: [id]);
      await t.delete('customer_projects', where: 'customer_id = ?', whereArgs: [id]);
      await t.delete('deals', where: 'customer_id = ?', whereArgs: [id]);
      await t.delete('customers', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ---------- Khách quan tâm dự án ----------

  Future<Map<int, Set<int>>> getInterests() async {
    final rows = await (await db).query('customer_projects');
    final map = <int, Set<int>>{};
    for (final r in rows) {
      map.putIfAbsent(r['customer_id'] as int, () => <int>{}).add(r['project_id'] as int);
    }
    return map;
  }

  Future<void> setInterests(int customerId, Set<int> projectIds) async {
    final d = await db;
    await d.transaction((t) async {
      await t.delete('customer_projects',
          where: 'customer_id = ?', whereArgs: [customerId]);
      for (final pid in projectIds) {
        await t.insert('customer_projects',
            {'customer_id': customerId, 'project_id': pid},
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  // ---------- Lịch sử chăm sóc ----------

  Future<List<CareLog>> getLogs(int customerId) async {
    final rows = await (await db).query('care_logs',
        where: 'customer_id = ?', whereArgs: [customerId], orderBy: 'created_at DESC');
    return rows.map(CareLog.fromMap).toList();
  }

  Future<List<CareLog>> getAllLogs() async {
    final rows = await (await db).query('care_logs', orderBy: 'created_at DESC');
    return rows.map(CareLog.fromMap).toList();
  }

  Future<int> insertLog(CareLog log) async =>
      (await db).insert('care_logs', _noId(log.toMap()));

  Future<void> deleteLog(int id) async {
    await (await db).delete('care_logs', where: 'id = ?', whereArgs: [id]);
  }

  /// Số lần chăm sóc người dùng tự ghi trong hôm nay.
  Future<int> countLogsToday() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final r = await (await db).rawQuery(
        'SELECT COUNT(*) AS c FROM care_logs WHERE created_at >= ? AND created_at < ? AND type != ?',
        [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch, CareType.capNhat]);
    return (r.first['c'] as int?) ?? 0;
  }

  // ---------- Dự án ----------

  Future<List<Project>> getProjects() async {
    final rows = await (await db).query('projects', orderBy: 'created_at DESC');
    return rows.map(Project.fromMap).toList();
  }

  Future<int> insertProject(Project pr) async =>
      (await db).insert('projects', _noId(pr.toMap()));

  Future<void> updateProject(Project pr) async {
    await (await db)
        .update('projects', pr.toMap(), where: 'id = ?', whereArgs: [pr.id]);
  }

  Future<void> deleteProject(int id) async {
    final d = await db;
    await d.transaction((t) async {
      await t.delete('customer_projects', where: 'project_id = ?', whereArgs: [id]);
      await t.update('deals', {'project_id': null},
          where: 'project_id = ?', whereArgs: [id]);
      await t.delete('projects', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ---------- Giao dịch ----------

  Future<List<Deal>> getDeals() async {
    final rows = await (await db).query('deals', orderBy: 'deal_date DESC');
    return rows.map(Deal.fromMap).toList();
  }

  Future<int> insertDeal(Deal d) async =>
      (await db).insert('deals', _noId(d.toMap()));

  Future<void> updateDeal(Deal d) async {
    await (await db).update('deals', d.toMap(), where: 'id = ?', whereArgs: [d.id]);
  }

  Future<void> deleteDeal(int id) async {
    await (await db).delete('deals', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Sao lưu / khôi phục ----------

  /// Lấy toàn bộ dữ liệu thô của mọi bảng.
  Future<Map<String, List<Map<String, Object?>>>> dumpAll() async {
    final d = await db;
    final out = <String, List<Map<String, Object?>>>{};
    for (final t in tables) {
      out[t] = await d.query(t);
    }
    return out;
  }

  /// Xóa sạch và nạp lại dữ liệu từ bản sao lưu.
  Future<void> restoreAll(Map<String, List<Map<String, Object?>>> data) async {
    final d = await db;
    await d.transaction((t) async {
      for (final table in tables) {
        await t.delete(table);
      }
      for (final table in tables) {
        for (final row in data[table] ?? const <Map<String, Object?>>[]) {
          await t.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
  }
}
