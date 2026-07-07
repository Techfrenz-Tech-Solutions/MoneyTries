// lib/models/kyc/kyc_model.dart

enum KycStep { aadhaar, pan, selfie, bank }

enum KycStatus { idle, loading, success, error }

class IfscBankInfo {
  final String bankName;
  final String branch;
  final String city;
  final String state;

  const IfscBankInfo({
    required this.bankName,
    required this.branch,
    required this.city,
    required this.state,
  });

  factory IfscBankInfo.fromJson(Map<String, dynamic> json) {
    return IfscBankInfo(
      bankName: json['BANK'] as String? ?? '',
      branch:   json['BRANCH'] as String? ?? '',
      city:     json['CITY'] as String? ?? '',
      state:    json['STATE'] as String? ?? '',
    );
  }
}

class KycFormData {
  // Aadhaar
  String? aadhaarFrontPath;
  String? aadhaarBackPath;

  // PAN
  String? panFrontPath;

  // Selfie
  String? selfiePath;

  // Bank
  String accountHolderName;
  String accountNumber;
  String ifscCode;
  IfscBankInfo? bankInfo;

  KycFormData({
    this.aadhaarFrontPath,
    this.aadhaarBackPath,
    this.panFrontPath,
    this.selfiePath,
    this.accountHolderName = '',
    this.accountNumber = '',
    this.ifscCode = '',
    this.bankInfo,
  });

  bool get aadhaarComplete =>
      aadhaarFrontPath != null && aadhaarBackPath != null;

  bool get panComplete => panFrontPath != null;

  bool get selfieComplete => selfiePath != null;

  bool get bankComplete =>
      accountHolderName.trim().isNotEmpty &&
      accountNumber.trim().length >= 9 &&
      ifscCode.trim().length == 11 &&
      bankInfo != null;
}

/// Full KYC submission record as returned by GET /api/kyc/status,
/// including uploaded document URLs and bank details. Used to display
/// the user's submitted KYC information (with images) once it has been
/// reviewed by an admin.
class KycSubmissionDetails {
  final String status; // 'pending' | 'approved' | 'rejected'
  final String? rejectionReason;

  final String? aadhaarFrontUrl;
  final String? aadhaarBackUrl;
  final String? panFrontUrl;
  final String? selfieUrl;

  final String accountHolderName;
  final String accountNumber;
  final String ifscCode;
  final String bankName;
  final String bankBranch;
  final String bankCity;
  final String bankState;

  final String? createdAt;
  final String? reviewedAt;

  const KycSubmissionDetails({
    required this.status,
    this.rejectionReason,
    this.aadhaarFrontUrl,
    this.aadhaarBackUrl,
    this.panFrontUrl,
    this.selfieUrl,
    this.accountHolderName = '',
    this.accountNumber = '',
    this.ifscCode = '',
    this.bankName = '',
    this.bankBranch = '',
    this.bankCity = '',
    this.bankState = '',
    this.createdAt,
    this.reviewedAt,
  });

  /// Masks all but the last 4 digits of the account number for display,
  /// e.g. "1234567890" -> "•••••• 7890".
  String get maskedAccountNumber {
    final digits = accountNumber.trim();
    if (digits.length <= 4) return digits;
    final last4 = digits.substring(digits.length - 4);
    return '${'•' * (digits.length - 4)} $last4';
  }

  /// Builds a [KycSubmissionDetails] from the JSON `data` object returned by
  /// GET /api/kyc/status. [baseUrl] is prepended to the server's relative
  /// `/uploads/...` paths so images can be loaded with Image.network.
  factory KycSubmissionDetails.fromJson(
    Map<String, dynamic> json, {
    required String baseUrl,
  }) {
    String? full(String? relative) {
      if (relative == null || relative.isEmpty) return null;
      return '$baseUrl$relative';
    }

    return KycSubmissionDetails(
      status: json['status'] as String? ?? 'pending',
      rejectionReason: json['rejection_reason'] as String?,
      aadhaarFrontUrl: full(json['aadhaar_front_url'] as String?),
      aadhaarBackUrl: full(json['aadhaar_back_url'] as String?),
      panFrontUrl: full(json['pan_front_url'] as String?),
      selfieUrl: full(json['selfie_url'] as String?),
      accountHolderName: json['account_holder_name'] as String? ?? '',
      accountNumber: json['account_number'] as String? ?? '',
      ifscCode: json['ifsc_code'] as String? ?? '',
      bankName: json['bank_name'] as String? ?? '',
      bankBranch: json['bank_branch'] as String? ?? '',
      bankCity: json['bank_city'] as String? ?? '',
      bankState: json['bank_state'] as String? ?? '',
      createdAt: json['created_at']?.toString(),
      reviewedAt: json['reviewed_at']?.toString(),
    );
  }
}