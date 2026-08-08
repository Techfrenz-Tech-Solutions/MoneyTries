import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/profile/personal_information_viewmodel.dart';
import '../../utils/responsive.dart';
import '../../widgets/profile_photo_viewer.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _bg = Color(0xFFF7F5F2);
const _white = Color(0xFFFFFFFF);
const _green = Color(0xFF1F6B45); // banner dark green
const _greenLight = Color(0xFFDCF3E5); // banner gradient start
const _titleDark = Color(0xFF1A1A2E);
const _grey = Color(0xFF9E9E9E);
const _borderClr = Color(0xFFE8E4DE);

// Hero tag connecting this screen's avatar to the full-screen photo viewer.
const String _kPersonalInfoAvatarHeroTag = 'personal-info-avatar-hero';

class PersonalInformationView extends StatelessWidget {
  const PersonalInformationView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PersonalInformationViewModel()..loadProfile(),
      child: const _PersonalInformationContent(),
    );
  }
}

class _PersonalInformationContent extends StatefulWidget {
  const _PersonalInformationContent();
  @override
  State<_PersonalInformationContent> createState() =>
      _PersonalInformationContentState();
}

class _PersonalInformationContentState
    extends State<_PersonalInformationContent> {
  late TextEditingController _firstNameCtrl;
  late TextEditingController _lastNameCtrl;
  late TextEditingController _addressCtrl;
  bool _controllersInit = false;

  @override
  void dispose() {
    if (_controllersInit) {
      _firstNameCtrl.dispose();
      _lastNameCtrl.dispose();
      _addressCtrl.dispose();
    }
    super.dispose();
  }

  void _initControllers(PersonalInformationViewModel vm) {
    if (_controllersInit) return;
    _firstNameCtrl = TextEditingController(text: vm.editFirstName);
    _lastNameCtrl = TextEditingController(text: vm.editLastName);
    _addressCtrl = TextEditingController(text: vm.editAddress);
    _controllersInit = true;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PersonalInformationViewModel>(
      builder: (context, vm, _) {
        if (!vm.isLoading && !_controllersInit) {
          _initControllers(vm);
        }

        return Theme(
          data: ThemeData(brightness: Brightness.light),
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.dark,
            child: Scaffold(
              backgroundColor: _bg,
              appBar: AppBar(
                backgroundColor: _white,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: _titleDark),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  'Personal Information',
                  style: TextStyle(
                    fontFamily: 'Times New Roman',
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: _titleDark,
                  ),
                ),
              ),
              body: vm.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: _green),
                    )
                  : vm.loadError != null
                  ? _buildError(vm)
                  : _buildBody(context, vm),
            ),
          ),
        );
      },
    );
  }

  // ── Error state ───────────────────────────────────────────────────────────
  Widget _buildError(PersonalInformationViewModel vm) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48.sp, color: Colors.red),
            SizedBox(height: 12.h),
            Text(
              vm.loadError ?? 'Failed to load profile',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Times New Roman',
                fontSize: 14.sp,
                color: _grey,
              ),
            ),
            SizedBox(height: 20.h),
            ElevatedButton(
              onPressed: vm.loadProfile,
              style: ElevatedButton.styleFrom(backgroundColor: _green),
              child: Text(
                'Retry',
                style: TextStyle(fontFamily: 'Times New Roman', color: _white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Main body ─────────────────────────────────────────────────────────────
  Widget _buildBody(BuildContext context, PersonalInformationViewModel vm) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatarCard(context, vm),
          SizedBox(height: 20.h),

          _sectionLabel('BASIC DETAILS'),
          SizedBox(height: 10.h),
          _buildReadOnlyField(
            label: 'First Name',
            value: vm.profile.firstName.isEmpty ? '—' : vm.profile.firstName,
            icon: Icons.lock_outline,
          ),
          SizedBox(height: 10.h),
          _buildReadOnlyField(
            label: 'Last Name',
            value: vm.profile.lastName.isEmpty ? '—' : vm.profile.lastName,
            icon: Icons.lock_outline,
          ),
          SizedBox(height: 10.h),
          _buildReadOnlyField(
            label: 'Email Address',
            value: vm.profile.email,
            icon: Icons.lock_outline,
          ),
          SizedBox(height: 10.h),
          _buildPhoneField(vm),
          SizedBox(height: 20.h),

          _sectionLabel('PROFILE SPECS'),
          SizedBox(height: 10.h),
          _buildDobField(context, vm),
          SizedBox(height: 10.h),
          _buildGenderField(context, vm),
          SizedBox(height: 20.h),

          _sectionLabel('ADDRESS'),
          SizedBox(height: 10.h),
          _buildAddressField(vm),
          SizedBox(height: 24.h),

          _buildEncryptionNote(),
          SizedBox(height: 24.h),

          _buildSaveButton(context, vm),
          SizedBox(height: 24.h),
        ],
      ),
    );
  }

  // ── Avatar card ───────────────────────────────────────────────────────────
  Widget _buildAvatarCard(
    BuildContext context,
    PersonalInformationViewModel vm,
  ) {
    final avatarUrl = vm.displayAvatarUrl;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 16.w),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: avatarUrl == null
                    ? null
                    : () => ProfilePhotoViewer.show(
                        context,
                        imageUrl: avatarUrl,
                        heroTag: _kPersonalInfoAvatarHeroTag,
                        userName: vm.profile.fullName,
                        sourceRadius: 45.r,
                      ),
                child: Hero(
                  tag: avatarUrl != null
                      ? _kPersonalInfoAvatarHeroTag
                      : '_no_personal_info_avatar_hero_',
                  child: Container(
                    width: 90.w,
                    height: 90.h,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _greenLight,
                      border: Border.all(
                        color: _green.withOpacity(0.3),
                        width: 2.r,
                      ),
                    ),
                    child: ClipOval(
                      child: avatarUrl != null
                          ? _buildAvatarImage(avatarUrl)
                          : Icon(Icons.person, size: 48.sp, color: _green),
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _showAvatarOptions(context, vm),
                child: Container(
                  width: 28.w,
                  height: 28.h,
                  decoration: BoxDecoration(
                    color: _green,
                    shape: BoxShape.circle,
                    border: Border.all(color: _white, width: 2.r),
                  ),
                  child: Icon(Icons.camera_alt, size: 14.sp, color: _white),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            vm.profile.fullName.isEmpty ? 'Your Name' : vm.profile.fullName,
            style: TextStyle(
              fontFamily: 'Times New Roman',
              fontSize: 20.sp,
              fontWeight: FontWeight.w600,
              color: _titleDark,
            ),
          ),
          SizedBox(height: 6.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 5.h),
            decoration: BoxDecoration(
              color: _greenLight,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: const Color(0xFF9FDAB9)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.workspace_premium, color: _green, size: 14.sp),
                SizedBox(width: 5.w),
                Text(
                  vm.profile.membershipTier.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'Times New Roman',
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: _green,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          if (vm.profile.memberId != null &&
              vm.profile.memberId!.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Text(
              'User ID: ${vm.profile.memberId}',
              style: TextStyle(
                fontFamily: 'Times New Roman',
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: _grey,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatarImage(String url) {
    if (!url.startsWith('http')) {
      return Image.file(File(url), fit: BoxFit.cover);
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) =>
          Icon(Icons.person, size: 48.sp, color: _green),
    );
  }

  void _showAvatarOptions(
    BuildContext context,
    PersonalInformationViewModel vm,
  ) {
    final hasAvatar = vm.displayAvatarUrl != null;

    showModalBottomSheet(
      context: context,
      backgroundColor: _white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: _borderClr,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SizedBox(height: 16.h),
              _sheetTile(
                Icons.photo_library_outlined,
                'Choose from Gallery',
                () async {
                  Navigator.pop(ctx);
                  await vm.pickAvatar(fromCamera: false);
                },
              ),
              _sheetTile(Icons.camera_alt_outlined, 'Take a Photo', () async {
                Navigator.pop(ctx);
                await vm.pickAvatar(fromCamera: true);
              }),
              if (hasAvatar)
                _sheetTile(Icons.delete_outline, 'Remove Photo', () {
                  Navigator.pop(ctx);
                  vm.markAvatarForRemoval();
                }, color: Colors.red),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetTile(
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color? color,
  }) {
    final c = color ?? _titleDark;
    return ListTile(
      leading: Icon(icon, color: c, size: 22.sp),
      title: Text(
        label,
        style: TextStyle(
          fontFamily: 'Times New Roman',
          fontSize: 14.sp,
          fontWeight: FontWeight.w500,
          color: c,
        ),
      ),
      onTap: onTap,
    );
  }

  // ── Field builders ────────────────────────────────────────────────────────
  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: TextStyle(
          fontFamily: 'Times New Roman',
          fontSize: 15.sp,
          color: _titleDark,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            fontFamily: 'Times New Roman',
            fontSize: 12.sp,
            color: _grey,
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 14.h,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: const BorderSide(color: _borderClr),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: const BorderSide(color: _borderClr),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide(color: _green, width: 1.5.r),
          ),
          filled: true,
          fillColor: _white,
        ),
      ),
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    IconData? icon,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: _borderClr),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Times New Roman',
                    fontSize: 12.sp,
                    color: _grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'Times New Roman',
                    fontSize: 15.sp,
                    color: _grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (icon != null) Icon(icon, size: 16.sp, color: _grey),
        ],
      ),
    );
  }

  Widget _buildPhoneField(PersonalInformationViewModel vm) {
    final phone = vm.profile.phone;
    final masked = phone.length >= 10
        ? '+91 ••••• ••${phone.substring(phone.length - 3)}'
        : phone.isNotEmpty
        ? '+91 $phone'
        : '—';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: _borderClr),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Phone Number',
                  style: TextStyle(
                    fontFamily: 'Times New Roman',
                    fontSize: 12.sp,
                    color: _grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Text(
                      masked,
                      style: TextStyle(
                        fontFamily: 'Times New Roman',
                        fontSize: 15.sp,
                        color: _grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (vm.profile.isPhoneVerified) ...[
                      SizedBox(width: 8.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: _green),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          'VERIFIED',
                          style: TextStyle(
                            fontFamily: 'Times New Roman',
                            fontSize: 10.sp,
                            color: _green,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.lock_outline, size: 16.sp, color: _grey),
        ],
      ),
    );
  }

  Widget _buildDobField(BuildContext context, PersonalInformationViewModel vm) {
    final display = _formatDob(vm.editDob);
    return GestureDetector(
      onTap: () async {
        DateTime initial = DateTime.now().subtract(
          const Duration(days: 365 * 25),
        );
        if (vm.editDob.isNotEmpty) {
          initial = DateTime.tryParse(vm.editDob) ?? initial;
        }
        final picked = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
          builder: (ctx, child) => Theme(
            data: Theme.of(
              ctx,
            ).copyWith(colorScheme: const ColorScheme.light(primary: _green)),
            child: child!,
          ),
        );
        if (picked != null) {
          vm.editDob =
              '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
          vm.notifyListeners();
        }
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: _borderClr),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Date of Birth',
                    style: TextStyle(
                      fontFamily: 'Times New Roman',
                      fontSize: 12.sp,
                      color: _grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    display.isEmpty ? 'Select date' : display,
                    style: TextStyle(
                      fontFamily: 'Times New Roman',
                      fontSize: 15.sp,
                      color: display.isEmpty ? _grey : _titleDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.calendar_today_outlined, size: 16.sp, color: _grey),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderField(
    BuildContext context,
    PersonalInformationViewModel vm,
  ) {
    const options = ['male', 'female', 'other', 'prefer_not_to_say'];
    const labels = ['Male', 'Female', 'Other', 'Prefer not to say'];

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: _white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          builder: (ctx) => SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: _borderClr,
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 8.h,
                    ),
                    child: Text(
                      'Select Gender',
                      style: TextStyle(
                        fontFamily: 'Times New Roman',
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: _titleDark,
                      ),
                    ),
                  ),
                  ...List.generate(
                    options.length,
                    (i) => ListTile(
                      leading: Icon(
                        vm.editGender == options[i]
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: _green,
                        size: 20.sp,
                      ),
                      title: Text(
                        labels[i],
                        style: TextStyle(
                          fontFamily: 'Times New Roman',
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                          color: _titleDark,
                        ),
                      ),
                      onTap: () {
                        vm.editGender = options[i];
                        vm.notifyListeners();
                        Navigator.pop(ctx);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: _borderClr),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gender',
                    style: TextStyle(
                      fontFamily: 'Times New Roman',
                      fontSize: 12.sp,
                      color: _grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    _genderLabel(vm.editGender),
                    style: TextStyle(
                      fontFamily: 'Times New Roman',
                      fontSize: 15.sp,
                      color: vm.editGender.isEmpty ? _grey : _titleDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.expand_more, size: 20.sp, color: _grey),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressField(PersonalInformationViewModel vm) {
    return Container(
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: TextField(
        controller: _addressCtrl,
        maxLines: 3,
        onChanged: (v) => vm.editAddress = v,
        style: TextStyle(
          fontFamily: 'Times New Roman',
          fontSize: 15.sp,
          color: _titleDark,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: 'Residential Address',
          labelStyle: TextStyle(
            fontFamily: 'Times New Roman',
            fontSize: 12.sp,
            color: _grey,
          ),
          alignLabelWithHint: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 14.h,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: const BorderSide(color: _borderClr),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: const BorderSide(color: _borderClr),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide(color: _green, width: 1.5.r),
          ),
          filled: true,
          fillColor: _white,
        ),
      ),
    );
  }

  Widget _buildEncryptionNote() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 12.sp, color: _grey),
            SizedBox(width: 5.w),
            Text(
              'END-TO-END ENCRYPTED',
              style: TextStyle(
                fontFamily: 'Times New Roman',
                fontSize: 10.sp,
                color: _grey,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        SizedBox(height: 4.h),
        Text(
          'Your private data is secured with institutional-grade AES-256 protocols.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Times New Roman',
            fontSize: 10.sp,
            color: _grey,
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton(
    BuildContext context,
    PersonalInformationViewModel vm,
  ) {
    final saving = vm.saveState == ProfileSaveState.saving;
    return SizedBox(
      width: double.infinity,
      height: 54.h,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFDCF3E5), Color(0xFF9AE0BC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: ElevatedButton.icon(
          onPressed: saving ? null : () => vm.saveProfile(context),
          icon: saving
              ? SizedBox(
                  width: 18.w,
                  height: 18.h,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _green,
                  ),
                )
              : Icon(Icons.save_outlined, color: _green, size: 20.sp),
          label: Text(
            saving ? 'Saving...' : 'Update Profile Information',
            style: TextStyle(
              fontFamily: 'Times New Roman',
              color: _green,
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14.r),
            ),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _sectionLabel(String label) {
    return Padding(
      padding: EdgeInsets.only(left: 2.w),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Times New Roman',
          fontSize: 11.sp,
          fontWeight: FontWeight.w700,
          color: _grey,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  String _formatDob(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${dt.day} ${months[dt.month]} ${dt.year}';
  }

  String _genderLabel(String? raw) {
    switch (raw) {
      case 'male':
        return 'Male';
      case 'female':
        return 'Female';
      case 'other':
        return 'Other';
      case 'prefer_not_to_say':
        return 'Prefer not to say';
      default:
        return 'Select gender';
    }
  }
}
