import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/profile/profile_repository.dart';
import '../../models/user_profile_model.dart';

enum ProfileSaveState { idle, saving, saved, error }

class PersonalInformationViewModel extends ChangeNotifier {
  final ProfileRepository _repo;

  PersonalInformationViewModel({ProfileRepository? repository})
      : _repo = repository ?? ProfileRepository();

  // ── State ──────────────────────────────────────────────────────────────────
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _loadError;
  String? get loadError => _loadError;

  ProfileSaveState _saveState = ProfileSaveState.idle;
  ProfileSaveState get saveState => _saveState;

  String? _saveError;
  String? get saveError => _saveError;

  // ── Profile data ───────────────────────────────────────────────────────────
  UserProfileModel _profile = const UserProfileModel(
    firstName: '',
    lastName: '',
    email: '',
    phone: '',
    isPhoneVerified: false,
  );
  UserProfileModel get profile => _profile;

  // ── Editable form fields ───────────────────────────────────────────────────
  String editFirstName = '';
  String editLastName = '';
  String editGender = '';
  String editAddress = '';
  String editDob = '';

  // ── Avatar state ───────────────────────────────────────────────────────────
  String? _pendingAvatarPath;
  String? get pendingAvatarPath => _pendingAvatarPath;
  bool _removeAvatar = false;

  // ── Load ───────────────────────────────────────────────────────────────────
  Future<void> loadProfile() async {
    _isLoading = true;
    _loadError = null;
    notifyListeners();

    try {
      _profile = await _repo.fetchProfile();
      _syncEditFields();
    } catch (e) {
      _loadError = e.toString().replaceFirst('Exception: ', '');
      _syncEditFields();
    }

    _isLoading = false;
    notifyListeners();
  }

  void _syncEditFields() {
    editFirstName = _profile.firstName;
    editLastName = _profile.lastName;
    editGender = _profile.gender ?? '';
    editAddress = _profile.address ?? '';
    editDob = _profile.dateOfBirth ?? '';
  }

  // ── Avatar helpers ─────────────────────────────────────────────────────────
  void setPendingAvatar(String localPath) {
    _pendingAvatarPath = localPath;
    _removeAvatar = false;
    notifyListeners();
  }

  void markAvatarForRemoval() {
    _pendingAvatarPath = null;
    _removeAvatar = true;
    notifyListeners();
  }

  String? get displayAvatarUrl {
    if (_pendingAvatarPath != null) return _pendingAvatarPath;
    if (_removeAvatar) return null;
    final rel = _profile.profileImage;
    if (rel == null || rel.isEmpty) return null;
    return _repo.buildAvatarUrl(rel);
  }

  /// Pick an image from gallery or camera and set it as pending avatar.
  Future<void> pickAvatar({bool fromCamera = false}) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 85,
    );
    if (file != null) setPendingAvatar(file.path);
  }

  // ── Save ───────────────────────────────────────────────────────────────────
  Future<void> saveProfile(BuildContext context) async {
    _saveState = ProfileSaveState.saving;
    _saveError = null;
    notifyListeners();

    try {
      // Update profile text fields
      _profile = await _repo.updateProfile(
        firstName: editFirstName.trim(),
        lastName: editLastName.trim(),
        dateOfBirth: editDob.isEmpty ? null : editDob,
        gender: editGender.isEmpty ? null : editGender,
        address: editAddress.trim().isEmpty ? null : editAddress.trim(),
      );

      // Handle avatar changes
      if (_removeAvatar) {
        await _repo.deleteAvatar();
        _profile = _profile.copyWith(clearProfileImage: true);
        _removeAvatar = false;
      } else if (_pendingAvatarPath != null) {
        try {
          final relPath = await _repo.uploadAvatar(_pendingAvatarPath!);
          if (relPath.isNotEmpty) {
            _profile = _profile.copyWith(profileImage: relPath);
          }
        } catch (_) {
          // Avatar upload failure is non-fatal — text fields already saved
        }
        _pendingAvatarPath = null;
      }

      _syncEditFields();
      _saveState = ProfileSaveState.saved;
      notifyListeners();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile updated successfully'),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        Navigator.pop(context, _profile);
      }
    } catch (e) {
      _saveState = ProfileSaveState.error;
      _saveError = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_saveError ?? 'Update failed. Please try again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  // ── Convenience ────────────────────────────────────────────────────────────
  void updateFullName(String name) {
    final parts = name.trim().split(' ');
    editFirstName = parts.first;
    editLastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    notifyListeners();
  }

  Future<void> updateProfile(BuildContext context) => saveProfile(context);
}