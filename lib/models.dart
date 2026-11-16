import 'dart:convert';

import 'package:flutter/material.dart';

/// Các danh sách lựa chọn cố định.
class Opt {
  static const sources = ['Zalo', 'Facebook', 'Người quen', 'Đi xem đất', 'Chạy ads'];
  static const needs = ['Mua', 'Thuê', 'Đầu tư'];
  static const propertyTypes = ['Đất nền', 'Chung cư', 'Nhà phố', 'Shophouse'];
  static const timelines = ['Ngay', '1-3 tháng', '3-6 tháng', 'Trên 6 tháng', 'Chưa rõ'];
  static const legals = ['Sổ đỏ', 'HĐMB', 'Khác'];
  static const apptTypes = ['Gọi lại', 'Dẫn đi xem', 'Gặp mặt'];
  static const remindOptions = [30, 60]; // phút
}

/// 9 trạng thái chăm sóc. Lưu vào database bằng tên (name), không phải số thứ tự.
enum CustomerStatus {
  moi('Mới', Color(0xFF1E88E5), Icons.fiber_new),
  daGoi('Đã gọi', Color(0xFF00897B), Icons.phone_callback),
  henGap('Đã hẹn gặp', Color(0xFF5E35B1), Icons.event_available),
  danXem('Đã dẫn đi xem', Color(0xFF0277BD), Icons.directions_car),
  damPhan('Đang đàm phán', Color(0xFFEF6C00), Icons.forum),
  daCoc('Đã cọc', Color(0xFFB8860B), Icons.savings),
  daChot('Đã chốt', Color(0xFF2E7D32), Icons.verified),
  khongNghe('Không nghe máy', Color(0xFFC62828), Icons.phone_missed),
  khongTiemNang('Không tiềm năng', Color(0xFF757575), Icons.block);

  const CustomerStatus(this.label, this.color, this.icon);
  final String label;
  final Color color;
  final IconData icon;

  static CustomerStatus fromName(String? n) {
    for (final s in values) {
      if (s.name == n) return s;
    }
    return moi;
  }

  /// Khách đã ngừng chăm (không cần nhắc hẹn).
  bool get inactive => this == khongTiemNang;
}

DateTime? _date(Object? v) =>
    v == null ? null : DateTime.fromMillisecondsSinceEpoch(v as int);

String _s(Object? v) => (v as String?) ?? '';

double _d(Object? v) => v == null ? 0 : (v as num).toDouble();

// ===================== KHÁCH HÀNG =====================

class Customer {
  int? id;
  String name;
  String phone;
  String zalo;
  String facebook;
  String source; // Nguồn khách
  String need; // Mua / Thuê / Đầu tư
  String propertyType; // Loại BĐS
  String area; // Khu vực
  String budget; // Ngân sách
  String timeline; // Thời gian muốn mua
  String note;
  CustomerStatus status;
  DateTime? nextCall; // Lịch hẹn
  String apptType; // Gọi lại / Dẫn đi xem / Gặp mặt
  int remindMinutes; // Báo trước 30 hoặc 60 phút
  DateTime createdAt;
  DateTime updatedAt;

  Customer({
    this.id,
    required this.name,
    this.phone = '',
    this.zalo = '',
    this.facebook = '',
    this.source = '',
    this.need = '',
    this.propertyType = '',
    this.area = '',
    this.budget = '',
    this.timeline = '',
    this.note = '',
    this.status = CustomerStatus.moi,
    this.nextCall,
    this.apptType = 'Gọi lại',
    this.remindMinutes = 30,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Customer copy() => Customer.fromMap(toMap());

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'zalo': zalo,
        'facebook': facebook,
        'source': source,
        'need': need,
        'ptype': propertyType,
        'area': area,
        'budget': budget,
        'timeline': timeline,
        'note': note,
        'status': status.name,
        'next_call': nextCall?.millisecondsSinceEpoch,
        'appt_type': apptType,
        'remind_min': remindMinutes,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  static Customer fromMap(Map<String, Object?> m) => Customer(
        id: m['id'] as int?,
        name: _s(m['name']),
        phone: _s(m['phone']),
        zalo: _s(m['zalo']),
        facebook: _s(m['facebook']),
        source: _s(m['source']),
        need: _s(m['need']),
        propertyType: _s(m['ptype']),
        area: _s(m['area']),
        budget: _s(m['budget']),
        timeline: _s(m['timeline']),
        note: _s(m['note']),
        status: CustomerStatus.fromName(m['status'] as String?),
        nextCall: _date(m['next_call']),
        apptType: _s(m['appt_type']).isEmpty ? 'Gọi lại' : _s(m['appt_type']),
        remindMinutes: (m['remind_min'] as int?) ?? 30,
        createdAt: _date(m['created_at']) ?? DateTime.now(),
        updatedAt: _date(m['updated_at']) ?? DateTime.now(),
      );

  String get zaloNumber => zalo.trim().isNotEmpty ? zalo.trim() : phone.trim();

  String get initial =>
      name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

  /// "Mua · Đất nền · Quận 9"
  String get needSummary =>
      [need, propertyType, area].where((e) => e.trim().isNotEmpty).join(' · ');
}

// ===================== LỊCH SỬ CHĂM SÓC =====================

class CareType {
  static const goiDien = 'Gọi điện';
  static const nhanTin = 'Nhắn tin';
  static const zalo = 'Zalo';
  static const gapMat = 'Gặp mặt';
  static const danXem = 'Dẫn đi xem';
  static const khac = 'Khác';
  static const capNhat = 'Cập nhật'; // tự động khi đổi trạng thái

  /// Các loại người dùng tự chọn khi ghi chăm sóc.
  static const all = [goiDien, nhanTin, zalo, gapMat, danXem, khac];

  static IconData icon(String type) {
    switch (type) {
      case goiDien:
        return Icons.call;
      case nhanTin:
        return Icons.sms;
      case zalo:
        return Icons.chat_bubble;
      case gapMat:
        return Icons.handshake;
      case danXem:
        return Icons.directions_car;
      case capNhat:
        return Icons.sync_alt;
      default:
        return Icons.edit_note;
    }
  }
}

class CareLog {
  int? id;
  int customerId;
  String type;
  String content;
  DateTime time;

  CareLog({
    this.id,
    required this.customerId,
    required this.type,
    this.content = '',
    required this.time,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'customer_id': customerId,
        'type': type,
        'content': content,
        'created_at': time.millisecondsSinceEpoch,
      };

  static CareLog fromMap(Map<String, Object?> m) => CareLog(
        id: m['id'] as int?,
        customerId: m['customer_id'] as int,
        type: _s(m['type']).isEmpty ? CareType.khac : _s(m['type']),
        content: _s(m['content']),
        time: _date(m['created_at']) ?? DateTime.now(),
      );
}

// ===================== DỰ ÁN / HÀNG HÓA =====================

class Project {
  int? id;
  String name;
  List<String> images; // tên file ảnh trong thư mục của app
  String location;
  String price; // vd "2,5 tỷ" hoặc "35 triệu/m²"
  String size; // Diện tích
  String legal; // Sổ đỏ / HĐMB / Khác
  String commission; // vd "2%" hoặc "50 triệu/căn"
  int totalUnits; // Tổng số căn / lô đang bán
  bool soldManual; // Tự đánh dấu "Đã bán hết"
  String note;
  DateTime createdAt;

  Project({
    this.id,
    required this.name,
    List<String>? images,
    this.location = '',
    this.price = '',
    this.size = '',
    this.legal = '',
    this.commission = '',
    this.totalUnits = 1,
    this.soldManual = false,
    this.note = '',
    DateTime? createdAt,
  })  : images = images ?? [],
        createdAt = createdAt ?? DateTime.now();

  Project copy() => Project.fromMap(toMap());

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'images': jsonEncode(images),
        'location': location,
        'price': price,
        'size': size,
        'legal': legal,
        'commission': commission,
        'total_units': totalUnits,
        'sold_manual': soldManual ? 1 : 0,
        'note': note,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  static Project fromMap(Map<String, Object?> m) {
    List<String> imgs = [];
    try {
      final raw = m['images'] as String?;
      if (raw != null && raw.isNotEmpty) {
        imgs = (jsonDecode(raw) as List).map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return Project(
      id: m['id'] as int?,
      name: _s(m['name']),
      images: imgs,
      location: _s(m['location']),
      price: _s(m['price']),
      size: _s(m['size']),
      legal: _s(m['legal']),
      commission: _s(m['commission']),
      totalUnits: (m['total_units'] as int?) ?? 1,
      soldManual: (m['sold_manual'] as int?) == 1,
      note: _s(m['note']),
      createdAt: _date(m['created_at']) ?? DateTime.now(),
    );
  }
}

// ===================== GIAO DỊCH (TIỀN + HOA HỒNG) =====================

class DealStage {
  static const coc = 'Đã cọc';
  static const chot = 'Đã chốt';
  static const all = [coc, chot];
}

/// Số tiền lưu theo đơn vị TRIỆU ĐỒNG (vd 2500 = 2,5 tỷ).
class Deal {
  int? id;
  int customerId;
  int? projectId;
  String unit; // Mã căn / lô
  String stage; // Đã cọc / Đã chốt
  double price; // Giá chốt
  double deposit; // Đã cọc
  double commission; // Tổng hoa hồng
  String sharedWith; // Chia cho ai
  double myCommission; // Phần mình nhận
  bool received; // Đã nhận hoa hồng chưa
  DateTime date; // Ngày cọc / chốt
  String note;
  DateTime createdAt;

  Deal({
    this.id,
    required this.customerId,
    this.projectId,
    this.unit = '',
    this.stage = DealStage.coc,
    this.price = 0,
    this.deposit = 0,
    this.commission = 0,
    this.sharedWith = '',
    this.myCommission = 0,
    this.received = false,
    DateTime? date,
    this.note = '',
    DateTime? createdAt,
  })  : date = date ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  double get remaining => (price - deposit) < 0 ? 0 : price - deposit;
  bool get isClosed => stage == DealStage.chot;

  Map<String, Object?> toMap() => {
        'id': id,
        'customer_id': customerId,
        'project_id': projectId,
        'unit': unit,
        'stage': stage,
        'price': price,
        'deposit': deposit,
        'commission': commission,
        'shared_with': sharedWith,
        'my_commission': myCommission,
        'received': received ? 1 : 0,
        'deal_date': date.millisecondsSinceEpoch,
        'note': note,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  static Deal fromMap(Map<String, Object?> m) => Deal(
        id: m['id'] as int?,
        customerId: m['customer_id'] as int,
        projectId: m['project_id'] as int?,
        unit: _s(m['unit']),
        stage: _s(m['stage']).isEmpty ? DealStage.coc : _s(m['stage']),
        price: _d(m['price']),
        deposit: _d(m['deposit']),
        commission: _d(m['commission']),
        sharedWith: _s(m['shared_with']),
        myCommission: _d(m['my_commission']),
        received: (m['received'] as int?) == 1,
        date: _date(m['deal_date']),
        note: _s(m['note']),
        createdAt: _date(m['created_at']),
      );
}
