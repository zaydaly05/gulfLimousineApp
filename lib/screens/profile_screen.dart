import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/account_deletion_service.dart';
import '../services/cloudinary_service.dart';
import '../services/auth_navigation.dart';
import '../widgets/biometric_settings_tile.dart';
import '../widgets/language_picker.dart';
import '../l10n/locale_service.dart';
import '../services/user_profile_service.dart';
import '../utils/image_decode.dart';
import '../utils/safe_insets.dart';
import '../widgets/app_feedback.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final nationalIdController = TextEditingController();

  // Picked images are kept as bytes (not dart:io File) so this screen also
  // works in the web build.
  Uint8List? _profileImage;
  String? _profileImageUrl;

  Uint8List? _nationalIdImage;
  String? _nationalIdImageUrl;
  Uint8List? _licenseIdImage;
  String? _licenseIdImageUrl;

  final ImagePicker _picker = ImagePicker();
  final _cloudinary = CloudinaryService();

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  bool _saving = false;
  final _biometricKey = GlobalKey<BiometricSettingsTileState>();

  @override
  void initState() {
    super.initState();
    unawaited(_loadUserData());
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    nationalIdController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final DocumentSnapshot<Map<String, dynamic>> doc;
    try {
      doc = await _firestore.collection('users').doc(user.uid).get();
    } catch (e) {
      debugPrint('Could not load profile: $e');
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    if (doc.exists) {
      final data = doc.data()!;
      nameController.text = data['name'] ?? '';
      emailController.text = data['email'] ?? user.email ?? '';
      phoneController.text = data['phone'] ?? data['phone_number'] ?? '';
      nationalIdController.text = data['national_id'] ?? '';
      _profileImageUrl = data['profile_image_url']?.toString();
      _nationalIdImageUrl = data['national_id_url']?.toString();
      _licenseIdImageUrl = data['license_id_url']?.toString();
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: Text(context.t('takePhoto')),
                onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text(context.t('chooseGallery')),
                onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
    // Close the sheet first, then open the picker: popping afterwards could
    // close the wrong route if the sheet was dismissed meanwhile.
    if (source == null) return;
    final XFile? image = await _picker.pickImage(source: source);
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (mounted) setState(() => _profileImage = bytes);
  }

  Future<void> _saveProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _saving = true);
    try {
      final updates = <String, dynamic>{
        'name': nameController.text.trim(),
        'phone': phoneController.text.trim(),
        'phone_number': phoneController.text.trim(),
        'national_id': nationalIdController.text.trim(),
      };

      if (_profileImage != null) {
        final bytes = _profileImage!;
        final uploaded = await _cloudinary.uploadBytes(
          bytes,
          filename: 'profile_${user.uid}.jpg',
        );
        if (uploaded != null) {
          updates['profile_image_url'] = uploaded['secure_url'];
          updates['profile_public_id'] = uploaded['public_id'];
          _profileImageUrl = uploaded['secure_url'] as String?;
        }
      }

      if (_nationalIdImage != null) {
        final uploaded = await _cloudinary.uploadBytes(
          _nationalIdImage!,
          filename: 'national_id_${user.uid}.jpg',
        );
        if (uploaded != null) {
          updates['national_id_url'] = uploaded['secure_url'];
          updates['national_id_public_id'] = uploaded['public_id'];
        }
      }

      if (_licenseIdImage != null) {
        final uploaded = await _cloudinary.uploadBytes(
          _licenseIdImage!,
          filename: 'license_id_${user.uid}.jpg',
        );
        if (uploaded != null) {
          updates['license_id_url'] = uploaded['secure_url'];
          updates['license_id_public_id'] = uploaded['public_id'];
        }
      }

      await UserProfileService.update(user.uid, updates);
      final biometricOk = await _biometricKey.currentState?.commit() ?? true;

      if (!mounted) return;
      if (!biometricOk) {
        ScaffoldMessenger.of(context)
            .showError(context.t('profileSavedBioFailed'));
        return;
      }

      ScaffoldMessenger.of(context).showSuccess(context.t('changesSaved'));
      await AuthNavigation.goToRoleHome(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    ImageProvider? avatar;
    if (_profileImage != null) {
      avatar = MemoryImage(_profileImage!);
    } else if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      // Avatar is 100 px across (radius 50).
      avatar = ResizeImage(
        CachedNetworkImageProvider(_profileImageUrl!),
        width: decodeWidth(context, 100),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('myProfile')),
        backgroundColor: Colors.orange,
        actions: const [
          LanguageToggleButton(
            dark: true,
            showText: false,
            iconColor: Colors.white,
          ),
          SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(20).withSafeBottom(context),
          child: Column(
            children: [
              Semantics(
                button: true,
                label: context.t('tapChangePhoto'),
                child: GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.orange,
                    backgroundImage: avatar,
                    child: avatar == null
                        ? const Icon(
                            Icons.person,
                            size: 60,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.t('tapChangePhoto'),
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              const SizedBox(height: 20),
              _input(context.t('fullName'), nameController),
              _input(
                context.t('email'),
                emailController,
                enabled: false,
                ltr: true,
              ),
              _input(context.t('phone'), phoneController, ltr: true),
              _input(tr('nationalId'), nationalIdController, ltr: true),

              const SizedBox(height: 24),
              _sectionHeader(Icons.security, tr('securityPrivacy')),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                color: Colors.grey.shade100,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    BiometricSettingsTile(
                      key: _biometricKey,
                      commitImmediately: false,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(
                        Icons.lock_reset,
                        color: Colors.orange,
                      ),
                      title: Text(tr('changePassword')),
                      subtitle: Text(tr('sendResetLinkToYour')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _sendPasswordReset,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(
                        Icons.privacy_tip_outlined,
                        color: Colors.orange,
                      ),
                      title: Text(tr('privacyPolicy')),
                      subtitle: Text(tr('whatWeCollectAndWhy')),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: _openPrivacyPolicy,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(
                        Icons.delete_forever_outlined,
                        color: Colors.red,
                      ),
                      title: Text(
                        tr('deleteAccount'),
                        style: TextStyle(color: Colors.red),
                      ),
                      subtitle: Text(tr('permanentlyRemoveYourProfileAnd')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _deleting ? null : _confirmDeleteAccount,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              _sectionHeader(
                Icons.document_scanner,
                tr('verificationDocuments'),
              ),
              const SizedBox(height: 12),
              _imagePreviewTile(
                tr('nationalIdPhoto'),
                _nationalIdImage,
                _nationalIdImageUrl,
                () => _pickImageForField(true),
              ),
              const SizedBox(height: 14),
              _imagePreviewTile(
                tr('driverLicensePhoto'),
                _licenseIdImage,
                _licenseIdImageUrl,
                () => _pickImageForField(false),
              ),
              const SizedBox(height: 24),
              _sectionHeader(Icons.language, tr('regionalSettings')),
              const SizedBox(height: 12),
              const LanguagePicker(),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _saving ? null : _saveProfile,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(context.t('saveChanges')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImageForField(bool isNationalId) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() {
      if (isNationalId) {
        _nationalIdImage = bytes;
      } else {
        _licenseIdImage = bytes;
      }
    });
  }

  static final _privacyPolicyUrl = Uri.parse(
    'https://gulf-limousine-travel-1d4c7.web.app/privacy.html',
  );

  void _openPrivacyPolicy() {
    unawaited(
      launchUrl(
        _privacyPolicyUrl,
        mode: LaunchMode.externalApplication,
      ).catchError((Object e) {
        debugPrint('Could not open privacy policy: $e');
        return false;
      }),
    );
  }

  bool _deleting = false;

  Future<void> _confirmDeleteAccount() async {
    final passwordController = TextEditingController();
    final needsPassword = AccountDeletionService.usesPassword;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('deleteYourAccount')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('thisPermanentlyDeletesYourProfile')),
              if (needsPassword) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: tr('enterYourPasswordToConfirm'),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(tr('delete')),
          ),
        ],
      ),
    );
    final password = passwordController.text;
    passwordController.dispose();
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _deleting = true);
    try {
      await AccountDeletionService.reauthenticate(password: password);
      await AccountDeletionService.deleteAccount();
      messenger.showInfo(tr('yourAccountHasBeenDeleted'));
      if (!mounted) return;
      await AuthNavigation.signOut(context, autoPromptBiometrics: false);
    } on AccountDeletionException catch (e) {
      messenger.showError(e);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _auth.currentUser?.email;
    if (email == null) return;

    try {
      await _auth.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSuccess(tr('passwordResetEmailSentTo', args: {'email': email}));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showError(e);
    }
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.orange),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _imagePreviewTile(
    String label,
    Uint8List? localFile,
    String? remoteUrl,
    VoidCallback onTap,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Semantics(
          button: true,
          label: label,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: localFile != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(localFile, fit: BoxFit.cover),
                    )
                  : (remoteUrl != null && remoteUrl.isNotEmpty)
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: remoteUrl,
                        memCacheWidth: screenDecodeWidth(context),
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            const Center(child: CircularProgressIndicator()),
                        // Without this a failed load spins forever.
                        errorWidget: (context, url, error) => const Center(
                          child: Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      ),
                    )
                  : const Center(
                      child: Icon(Icons.add_a_photo, color: Colors.grey),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _input(
    String label,
    TextEditingController controller, {
    bool enabled = true,
    bool ltr = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        enabled: enabled,
        // Emails, phone and ID numbers read left to right in Arabic too.
        textDirection: ltr ? TextDirection.ltr : null,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
