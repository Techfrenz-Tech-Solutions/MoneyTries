// ── Notification Models ───────────────────────────────────────────────────────

import '../../utils/date_time_utils.dart';

enum NotificationType {
  deposit,
  withdrawal,
  kyc,
  referral,
  roi,
  plan,
  system,
  unknown,
}

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final bool isRead;
  final DateTime? createdAt;
  final NotificationType type;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.isRead,
    this.createdAt,
    this.type = NotificationType.unknown,
  });

  NotificationItem copyWith({bool? isRead}) {
    return NotificationItem(
      id: id,
      title: title,
      message: message,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      type: type,
    );
  }

  // MySQL's TINYINT(1) columns (is_read) are serialized as JSON integers
  // (0 / 1) by the backend, not JSON booleans — so a direct `as bool?` cast
  // throws "type 'int' is not a subtype of type 'bool?'". This accepts
  // bool, int, or numeric/boolean string values safely.
  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.trim().toLowerCase();
      return v == '1' || v == 'true';
    }
    return false;
  }

  static NotificationType _typeFromString(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'deposit':
        return NotificationType.deposit;
      case 'withdrawal':
      case 'withdraw':
        return NotificationType.withdrawal;
      case 'kyc':
        return NotificationType.kyc;
      case 'referral':
        return NotificationType.referral;
      case 'roi':
      case 'interest':
        return NotificationType.roi;
      case 'plan':
      case 'investment':
        return NotificationType.plan;
      case 'system':
      case 'general':
        return NotificationType.system;
      default:
        return NotificationType.unknown;
    }
  }

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ??
          json['body']?.toString() ??
          json['description']?.toString() ??
          '',
      isRead: json['is_read'] != null
          ? _asBool(json['is_read'])
          : json['isRead'] != null
              ? _asBool(json['isRead'])
              : (json['read_at'] != null),
      createdAt: parseServerDateTime(json['created_at']),
      type: _typeFromString(json['type']?.toString()),
    );
  }
}

class NotificationListResponse {
  final int pageNo;
  final int pageSize;
  final int total;
  final int totalPages;
  final List<NotificationItem> data;
  final int unreadCount;

  const NotificationListResponse({
    required this.pageNo,
    required this.pageSize,
    required this.total,
    required this.totalPages,
    required this.data,
    required this.unreadCount,
  });

  factory NotificationListResponse.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'] as List<dynamic>? ?? [];
    final items = rawData
        .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return NotificationListResponse(
      pageNo: json['pageNo'] as int? ?? 1,
      pageSize: json['pageSize'] as int? ?? 20,
      total: json['total'] as int? ?? items.length,
      totalPages: json['totalPages'] as int? ?? 1,
      data: items,
      unreadCount: json['unread_count'] as int? ??
          items.where((n) => !n.isRead).length,
    );
  }
}