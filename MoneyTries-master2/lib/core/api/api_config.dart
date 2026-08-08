/// Centralized API configuration for the entire app.
///
/// This is the SINGLE source of truth for the backend `baseUrl` and all
/// shared API constants. No other file should hardcode a scheme/host/port
/// (e.g. `http://192.168.0.17:3000` or a Railway URL) — everything should
/// reference [ApiConfig.baseUrl] (or the endpoint constants below) instead.
///
/// To point the app at a different backend, change [_defaultBaseUrl] below
/// — that's the only place that needs to change.
///
/// You can also override the base URL at build/run time without touching
/// source, e.g. when testing against a different LAN IP or a deployed
/// backend:
///
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.50:3000
///   flutter build apk --release --dart-define=API_BASE_URL=https://greenvault-backend-production.up.railway.app
///
/// Leaving `--dart-define=API_BASE_URL=...` off falls back to
/// [_defaultBaseUrl].
class ApiConfig {
  // Default backend base URL. Change this single value to repoint the
  // entire app at a different backend.
  static const String _defaultBaseUrl = 'http://192.168.0.17:3000';
  // static const String _defaultBaseUrl = 'https://greenvault-backend-production.up.railway.app';

  /// Base URL — resolves to `--dart-define=API_BASE_URL=...` if provided,
  /// otherwise falls back to [_defaultBaseUrl]. This is the ONLY constant
  /// that should be used for the backend host/port throughout the app.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _defaultBaseUrl,
  );

  /// Base URL for statically served files (uploaded images, avatars, KYC
  /// docs, etc.) served from the backend's `/uploads` directory.
  static const String uploadsBaseUrl = '$baseUrl/uploads';

  /// Resolves a possibly-relative image/file path returned by the backend
  /// into a fully-qualified URL. If [path] is already an absolute URL
  /// (starts with `http`), it is returned unchanged.
  static String resolveUploadUrl(String path) {
    return path.startsWith('http') ? path : '$uploadsBaseUrl/$path';
  }

  // Auth Endpoints
  static const String createAccount = '/users/createAccount';
  static const String login = '/users/login';
  static const String loginVerify = '/users/loginVerify';
  static const String sendEmailOtp = '/users/send_mail_otp_register';
  static const String sendMobileOtp = '/users/send_mob_otp_register';
  static const String verifyEmailOtp = '/users/verify_mail_otp_register';
  static const String verifyMobileOtp = '/users/verify_mobile_otp_register';

  // KYC Endpoints
  static const String uploadKycDetails = '/kyc/upload_kyc_details';
  static const String addBankDetails = '/kyc/addBankDetails';
  static const String getSingleKycDetail = '/kyc/getSingleKycDetail';
  static const String saveKycAndBankDetails = '/kyc/saveKycAndBankDetails';

  // Profile Endpoints
  static const String getProfile = '/api/profile';
  static const String updateProfile = '/api/profile/update';
  static const String uploadAvatar = '/api/profile/avatar';
  static const String deleteAvatar = '/api/profile/avatar';
  static const String getUserInfo = '/users/info';

  // Payment — matched to new Node.js backend routes
  static const String uploadImage = '/api/deposit/upload';
  static const String createOrder = '/api/deposit/submit';
  static const String userDepositList = '/api/deposit/list';

  // Withdrawal
  static const String requestMoveWalletAmount = '/users/requestMoveWalletAmount';
  static const String userWithdrawRequest = '/users/userWithdrawRequest';
  static const String userWithdrawList = '/users/userWithdrawList';

  // Transaction History
  static const String transactionHistory = '/users/transactionHistory';

  // Support Ticket Endpoints
  static const String createTicket = '/users/createTicket';
  static const String replyTicket = '/users/replyTicket';
  static const String userTicketList = '/users/userTicketList';
  static const String ticketDetails = '/users/ticketDetails';

  // Forgot / Change Password
  static const String forgotPassword = '/users/forgotPassword';
  static const String changePassword = '/api/auth/change-password';

  // Bank List
  static const String getBankList = '/kyc/getBankList';

  // Profile Image (legacy — prefer uploadAvatar above)
  static const String updateProfileImage = '/users/updateProfileImage';

  // Security PIN
  static const String updatePin = '/users/updatePin';

  // Referral
  static const String referralInfo = '/api/referral/info';

  // Support Contact Details
  static const String supportEmail = 'moneyminingindia@gmail.com';
  static const String supportPhone = '7449003060';
}