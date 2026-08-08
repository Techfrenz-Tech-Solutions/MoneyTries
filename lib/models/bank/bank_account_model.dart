// lib/models/bank/bank_account_model.dart

class BankAccount {
  final String id;
  final String bankName;
  final String accountNumber; // last 4 digits only
  final String ifscCode;
  final String accountType;   // 'Savings' | 'Current'
  final bool isPrimary;

  const BankAccount({
    required this.id,
    required this.bankName,
    required this.accountNumber,
    required this.ifscCode,
    required this.accountType,
    required this.isPrimary,
  });

  BankAccount copyWith({
    String? id,
    String? bankName,
    String? accountNumber,
    String? ifscCode,
    String? accountType,
    bool? isPrimary,
  }) {
    return BankAccount(
      id: id ?? this.id,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      ifscCode: ifscCode ?? this.ifscCode,
      accountType: accountType ?? this.accountType,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }
}