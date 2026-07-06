import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/profile/personal_information_viewmodel.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _bg         = Color(0xFFECEFF5);
const _white      = Color(0xFFFFFFFF);
const _green      = Color(0xFF3D9E6A);
const _greenLight = Color(0xFFE8F5E9);
const _titleDark  = Color(0xFF1A1A2E);
const _grey       = Color(0xFF9E9E9E);
const _borderClr  = Color(0xFFE5E7EB);

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
    _lastNameCtrl  = TextEditingController(text: vm.editLastName);
    _addressCtrl   = TextEditingController(text: vm.editAddress);
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
                  style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: _titleDark),
                ),
              ),
              body: vm.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: _green))
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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(vm.loadError ?? 'Failed to load profile',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 14, color: _grey)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: vm.loadProfile,
              style: ElevatedButton.styleFrom(backgroundColor: _green),
              child: Text('Retry',
                  style: GoogleFonts.poppins(color: _white)),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatarCard(context, vm),
          const SizedBox(height: 20),

          _sectionLabel('BASIC DETAILS'),
          const SizedBox(height: 10),
          _buildReadOnlyField(
            label: 'First Name',
            value: vm.profile.firstName.isEmpty ? '—' : vm.profile.firstName,
            icon: Icons.lock_outline,
          ),
          const SizedBox(height: 10),
          _buildReadOnlyField(
            label: 'Last Name',
            value: vm.profile.lastName.isEmpty ? '—' : vm.profile.lastName,
            icon: Icons.lock_outline,
          ),
          const SizedBox(height: 10),
          _buildReadOnlyField(
            label: 'Email Address',
            value: vm.profile.email,
            icon: Icons.lock_outline,
          ),
          const SizedBox(height: 10),
          _buildPhoneField(vm),
          const SizedBox(height: 20),

          _sectionLabel('PROFILE SPECS'),
          const SizedBox(height: 10),
          _buildDobField(context, vm),
          const SizedBox(height: 10),
          _buildGenderField(context, vm),
          const SizedBox(height: 20),

          _sectionLabel('ADDRESS'),
          const SizedBox(height: 10),
          _buildAddressField(vm),
          const SizedBox(height: 24),

          _buildEncryptionNote(),
          const SizedBox(height: 24),

          _buildSaveButton(context, vm),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Avatar card ───────────────────────────────────────────────────────────
  Widget _buildAvatarCard(BuildContext context, PersonalInformationViewModel vm) {
    final avatarUrl = vm.displayAvatarUrl;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _greenLight,
                  border: Border.all(color: _green.withOpacity(0.3), width: 2),
                ),
                child: ClipOval(
                  child: avatarUrl != null
                      ? _buildAvatarImage(avatarUrl)
                      : const Icon(Icons.person, size: 48, color: _green),
                ),
              ),
              GestureDetector(
                onTap: () => _showAvatarOptions(context, vm),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _green,
                    shape: BoxShape.circle,
                    border: Border.all(color: _white, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt, size: 14, color: _white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            vm.profile.fullName.isEmpty ? 'Your Name' : vm.profile.fullName,
            style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: _titleDark),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: _greenLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFA5D6A7)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.workspace_premium, color: _green, size: 14),
                const SizedBox(width: 5),
                Text(
                  vm.profile.membershipTier.toUpperCase(),
                  style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _green,
                      letterSpacing: 0.8),
                ),
              ],
            ),
          ),
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
          const Icon(Icons.person, size: 48, color: _green),
    );
  }

  void _showAvatarOptions(BuildContext context, PersonalInformationViewModel vm) {
    final hasAvatar = vm.displayAvatarUrl != null;

    showModalBottomSheet(
      context: context,
      backgroundColor: _white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: _borderClr,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              _sheetTile(Icons.photo_library_outlined, 'Choose from Gallery',
                  () async {
                Navigator.pop(ctx);
                await vm.pickAvatar(fromCamera: false);
              }),
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

  Widget _sheetTile(IconData icon, String label, VoidCallback onTap,
      {Color? color}) {
    final c = color ?? _titleDark;
    return ListTile(
      leading: Icon(icon, color: c, size: 22),
      title: Text(label,
          style: GoogleFonts.poppins(
              fontSize: 14, fontWeight: FontWeight.w500, color: c)),
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
          color: _white, borderRadius: BorderRadius.circular(12)),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: GoogleFonts.poppins(
            fontSize: 15, color: _titleDark, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(fontSize: 12, color: _grey),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _borderClr)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _borderClr)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _green, width: 1.5)),
          filled: true,
          fillColor: _white,
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(
      {required String label, required String value, IconData? icon}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderClr)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: _grey,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(value,
                    style: GoogleFonts.poppins(
                        fontSize: 15,
                        color: _grey,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          if (icon != null) Icon(icon, size: 16, color: _grey),
        ],
      ),
    );
  }

  Widget _buildPhoneField(PersonalInformationViewModel vm) {
    final phone = vm.profile.phone;
    final masked = phone.length >= 10
        ? '+91 ••••• ••${phone.substring(phone.length - 3)}'
        : phone.isNotEmpty ? '+91 $phone' : '—';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderClr)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Phone Number',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: _grey,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(masked,
                        style: GoogleFonts.poppins(
                            fontSize: 15,
                            color: _grey,
                            fontWeight: FontWeight.w500)),
                    if (vm.profile.isPhoneVerified) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          border: Border.all(color: _green),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('VERIFIED',
                            style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: _green,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.lock_outline, size: 16, color: _grey),
        ],
      ),
    );
  }

  Widget _buildDobField(BuildContext context, PersonalInformationViewModel vm) {
    final display = _formatDob(vm.editDob);
    return GestureDetector(
      onTap: () async {
        DateTime initial =
            DateTime.now().subtract(const Duration(days: 365 * 25));
        if (vm.editDob.isNotEmpty) {
          initial = DateTime.tryParse(vm.editDob) ?? initial;
        }
        final picked = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(primary: _green),
            ),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderClr)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Date of Birth',
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: _grey,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(
                    display.isEmpty ? 'Select date' : display,
                    style: GoogleFonts.poppins(
                        fontSize: 15,
                        color: display.isEmpty ? _grey : _titleDark,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const Icon(Icons.calendar_today_outlined, size: 16, color: _grey),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderField(
      BuildContext context, PersonalInformationViewModel vm) {
    const options = ['male', 'female', 'other', 'prefer_not_to_say'];
    const labels  = ['Male', 'Female', 'Other', 'Prefer not to say'];

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: _white,
          shape: const RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(20))),
          builder: (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: _borderClr,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Text('Select Gender',
                        style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _titleDark)),
                  ),
                  ...List.generate(
                    options.length,
                    (i) => ListTile(
                      leading: Icon(
                        vm.editGender == options[i]
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: _green,
                        size: 20,
                      ),
                      title: Text(labels[i],
                          style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500)),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderClr)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Gender',
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: _grey,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(
                    _genderLabel(vm.editGender),
                    style: GoogleFonts.poppins(
                        fontSize: 15,
                        color: vm.editGender.isEmpty ? _grey : _titleDark,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const Icon(Icons.expand_more, size: 20, color: _grey),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressField(PersonalInformationViewModel vm) {
    return Container(
      decoration: BoxDecoration(
          color: _white, borderRadius: BorderRadius.circular(12)),
      child: TextField(
        controller: _addressCtrl,
        maxLines: 3,
        onChanged: (v) => vm.editAddress = v,
        style: GoogleFonts.poppins(
            fontSize: 15, color: _titleDark, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: 'Residential Address',
          labelStyle: GoogleFonts.poppins(fontSize: 12, color: _grey),
          alignLabelWithHint: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _borderClr)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _borderClr)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _green, width: 1.5)),
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
            const Icon(Icons.lock_outline, size: 12, color: _grey),
            const SizedBox(width: 5),
            Text('END-TO-END ENCRYPTED',
                style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: _grey,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Your private data is secured with institutional-grade AES-256 protocols.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 10, color: _grey),
        ),
      ],
    );
  }

  Widget _buildSaveButton(BuildContext context, PersonalInformationViewModel vm) {
    final saving = vm.saveState == ProfileSaveState.saving;
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: saving ? null : () => vm.saveProfile(context),
        icon: saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: _white))
            : const Icon(Icons.save_outlined, color: _white, size: 20),
        label: Text(
          saving ? 'Saving...' : 'Update Profile Information',
          style: GoogleFonts.poppins(
              color: _white, fontSize: 15, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _green,
          disabledBackgroundColor: _green.withOpacity(0.6),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        label,
        style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _grey,
            letterSpacing: 1.2),
      ),
    );
  }

  String _formatDob(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month]} ${dt.year}';
  }

  String _genderLabel(String? raw) {
    switch (raw) {
      case 'male':              return 'Male';
      case 'female':            return 'Female';
      case 'other':             return 'Other';
      case 'prefer_not_to_say': return 'Prefer not to say';
      default:                  return 'Select gender';
    }
  }
}