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