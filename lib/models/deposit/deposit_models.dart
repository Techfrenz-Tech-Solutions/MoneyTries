// ── Deposit Models ────────────────────────────────────────────────────────────

import '../../utils/date_time_utils.dart';

/// Returned by POST /api/deposit/submit
class ManualOrderModel {
  final String orderId;
  final String message;

  const ManualOrderModel({required this.orderId, required this.message});

  factory ManualOrderModel.fromJson(Map<String, dynamic> json) {
    return ManualOrderModel(
      orderId: json['order_id']?.toString() ?? json['orderId']?.toString() ?? '',
      message: json['message']?.toString() ?? 'Order placed successfully',
    );
  }
}

/// Returned by POST /api/deposit/upload
class UploadResponse {
  final String proofImageUrl;

  const UploadResponse({required this.proofImageUrl});

  factory UploadResponse.fromJson(Map<String, dynamic> json) {
    return UploadResponse(
      proofImageUrl: json['proof_image']?.toString() ??
          json['url']?.toString() ??
          json['image_url']?.toString() ??
          '',
    );
  }
}

/// A single deposit history record
class DepositRecord {
  final String id;
  final double amount;
  final String currency;
  final String utrId;
  final String proofImage;
  final String orderStatus;
  final String? rejectionReason;
  final DateTime? createdAt;
  final DateTime? reviewedAt;

  const DepositRecord({
    required this.id,
    required this.amount,
    required this.currency,
    required this.utrId,
    required this.proofImage,
    required this.orderStatus,
    this.rejectionReason,
    this.createdAt,
    this.reviewedAt,
  });

  bool get isPending   => orderStatus == 'pending';
  bool get isApproved  => orderStatus == 'approved';
  bool get isRejected  => orderStatus == 'rejected';

  factory DepositRecord.fromJson(Map<String, dynamic> json) {
    return DepositRecord(
      id: json['id']?.toString() ?? '',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0,
      currency: json['currency']?.toString() ?? 'INR',
      utrId: json['utr_id']?.toString() ?? '',
      proofImage: json['proof_image']?.toString() ?? '',
      orderStatus: json['order_status']?.toString() ?? 'pending',
      rejectionReason: json['rejection_reason']?.toString(),
      createdAt: parseServerDateTime(json['created_at']),
      reviewedAt: parseServerDateTime(json['reviewed_at']),
    );
  }
}

/// Paginated wrapper for deposit history
class DepositListResponse {
  final int pageNo;
  final int pageSize;
  final int total;
  final int totalPages;
  final List<DepositRecord> data;

  const DepositListResponse({
    required this.pageNo,
    required this.pageSize,
    required this.total,
    required this.totalPages,
    required this.data,
  });

  factory DepositListResponse.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'] as List<dynamic>? ?? [];
    return DepositListResponse(
      pageNo: json['pageNo'] as int? ?? 1,
      pageSize: json['pageSize'] as int? ?? 10,
      total: json['total'] as int? ?? 0,
      totalPages: json['totalPages'] as int? ?? 0,
      data: rawData
          .map((e) => DepositRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}