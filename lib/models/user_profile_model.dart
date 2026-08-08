class UserProfileModel {
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final bool isPhoneVerified;
  final String? dateOfBirth;   // stored as "YYYY-MM-DD" from server, displayed formatted
  final String? gender;
  final String? address;
  final String? profileImage;  // relative path — client builds full URL
  final String membershipTier;
  final String? createdAt;
  // Server-assigned member ID (e.g. "MT1112"). Generated once at
  // registration time by the backend (utils/memberId.js) — the Flutter app
  // never generates or edits this value, only displays it. Existing users
  // created before this feature may have this as null.
  final String? memberId;

  const UserProfileModel({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.isPhoneVerified,
    this.dateOfBirth,
    this.gender,
    this.address,
    this.profileImage,
    this.membershipTier = 'Standard Member',
    this.createdAt,
    this.memberId,
  });

  String get fullName => '$firstName $lastName'.trim();

  UserProfileModel copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    bool? isPhoneVerified,
    String? dateOfBirth,
    String? gender,
    String? address,
    String? profileImage,
    String? membershipTier,
    String? createdAt,
    String? memberId,
    bool clearProfileImage = false,
  }) {
    return UserProfileModel(
      firstName:      firstName      ?? this.firstName,
      lastName:       lastName       ?? this.lastName,
      email:          email          ?? this.email,
      phone:          phone          ?? this.phone,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
      dateOfBirth:    dateOfBirth    ?? this.dateOfBirth,
      gender:         gender         ?? this.gender,
      address:        address        ?? this.address,
      profileImage:   clearProfileImage ? null : (profileImage ?? this.profileImage),
      membershipTier: membershipTier ?? this.membershipTier,
      createdAt:      createdAt      ?? this.createdAt,
      memberId:       memberId       ?? this.memberId,
    );
  }

  factory UserProfileModel.fromJson(Map<String, dynamic> j) {
    return UserProfileModel(
      firstName:      j['first_name']?.toString() ?? '',
      lastName:       j['last_name']?.toString()  ?? '',
      email:          j['email']?.toString()       ?? '',
      phone:          j['phone']?.toString()       ?? '',
      isPhoneVerified: j['phone_verified'] == true || j['phone_verified'] == 1,
      dateOfBirth:    j['date_of_birth']?.toString(),
      gender:         j['gender']?.toString(),
      address:        j['address']?.toString(),
      profileImage:   j['profile_image']?.toString(),
      membershipTier: 'Moneytries Member',
      createdAt:      j['created_at']?.toString(),
      memberId:       j['member_id']?.toString(),
    );
  }
}

// Keep AddressModel for any legacy reference
class AddressModel {
  final String type;
  final String fullAddress;
  const AddressModel({required this.type, required this.fullAddress});
}