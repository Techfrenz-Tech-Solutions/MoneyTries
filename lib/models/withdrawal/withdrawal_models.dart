// ── Withdrawal Models ─────────────────────────────────────────────────────────

import '../../utils/date_time_utils.dart';

/// KYC-sourced bank details auto-populated in the withdrawal form
class KycBankDetail {
  final String accountName;
  final String accountNumber; // full number
  final String ifsc;
  final String bankName;
  final String accountType;

  const KycBankDetail({
    required this.accountName,
    required this.accountNumber,
    required this.ifsc,
    required this.bankName,
    required this.accountType,
  });

  /// Last 4 digits for masked display: •••• 9821
  String get maskedNumber =>
      '•••• ${accountNumber.length >= 4 ? accountNumber.substring(accountNumber.length - 4) : accountNumber}';

  factory KycBankDetail.fromJson(Map<String, dynamic> json) {
    return KycBankDetail(
      accountName: json['account_name']?.toString() ??
          json['accountName']?.toString() ??
          '',
      accountNumber: json['account_number']?.toString() ??
          json['accountNumber']?.toString() ??
          '',
      ifsc: json['ifsc']?.toString() ?? json['ifsc_code']?.toString() ?? '',
      bankName: json['bank_name']?.toString() ?? json['bankName']?.toString() ?? '',
      accountType: json['account_type']?.toString() ?? 'Savings',
    );
  }
}

/// KYC status wrapper (fetched via GET /kyc/status or similar)
class KycStatus {
  final bool isVerified;
  final KycBankDetail? bankDetail;

  const KycStatus({required this.isVerified, this.bankDetail});

  factory KycStatus.fromJson(Map<String, dynamic> json) {
    final bankJson = json['bank_detail'] ?? json['bankDetail'];
    return KycStatus(
      isVerified: json['is_verified'] as bool? ??
          json['isVerified'] as bool? ??
          false,
      bankDetail: bankJson != null
          ? KycBankDetail.fromJson(bankJson as Map<String, dynamic>)
          : null,
    );
  }
}

/// Response from POST /users/userWithdrawRequest (wallet withdrawal)
class WalletWithdrawResponse {
  final String referenceId;
  final String message;

  const WalletWithdrawResponse({required this.referenceId, required this.message});

  factory WalletWithdrawResponse.fromJson(Map<String, dynamic> json) {
    return WalletWithdrawResponse(
      referenceId: json['reference_id']?.toString() ??
          json['referenceId']?.toString() ??
          '',
      message: json['message']?.toString() ?? 'Withdrawal processed successfully',
    );
  }
}

/// Response from POST /users/requestMoveWalletAmount (deposit/capital withdrawal)
class MoveWalletResponse {
  final String message;

  const MoveWalletResponse({required this.message});

  factory MoveWalletResponse.fromJson(Map<String, dynamic> json) {
    return MoveWalletResponse(
      message: json['message']?.toString() ?? 'Request submitted for admin review',
    );
  }
}

/// A single withdrawal history record
class WithdrawRecord {
  final String id;
  final double amount;
  final String status; // pending | approved | rejected
  final String referenceId;
  final String transactionId;
  final String proofImage;
  final String adminRemarks;
  final DateTime? createdAt;

  const WithdrawRecord({
    required this.id,
    required this.amount,
    required this.status,
    required this.referenceId,
    required this.transactionId,
    required this.proofImage,
    required this.adminRemarks,
    this.createdAt,
  });

  factory WithdrawRecord.fromJson(Map<String, dynamic> json) {
    return WithdrawRecord(
      id: json['id']?.toString() ?? '',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0,
      status: json['status']?.toString() ?? 'pending',
      referenceId: json['reference_id']?.toString() ?? '',
      transactionId: json['transaction_id']?.toString() ?? '',
      proofImage: json['proof_image']?.toString() ?? '',
      adminRemarks: json['admin_remarks']?.toString() ?? '',
      createdAt: parseServerDateTime(json['created_at']),
    );
  }
}

/// Paginated wrapper for withdrawal history
class WithdrawListResponse {
  final int pageNo;
  final int pageSize;
  final int totalRecords;
  final int totalPages;
  final List<WithdrawRecord> data;

  const WithdrawListResponse({
    required this.pageNo,
    required this.pageSize,
    required this.totalRecords,
    required this.totalPages,
    required this.data,
  });

  factory WithdrawListResponse.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'] as List<dynamic>? ?? [];
    return WithdrawListResponse(
      pageNo: json['pageNo'] as int? ?? 1,
      pageSize: json['pageSize'] as int? ?? 10,
      totalRecords: json['totalRecords'] as int? ?? 0,
      totalPages: json['totalPages'] as int? ?? 0,
      data: rawData
          .map((e) => WithdrawRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}