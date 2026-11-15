import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../services/cloudinary_service.dart';
import '../services/auth_navigation.dart';
import '../widgets/biometric_settings_tile.dart';
import '../widgets/language_picker.dart';
import '../l10n/locale_service.dart';

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
    _loadUserData();
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

      await _firestore.collection('users').doc(user.uid).update(updates);
      final biometricOk = await _biometricKey.currentState?.commit() ?? true;

      if (!mounted) return;
      if (!biometricOk) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t('profileSavedBioFailed')),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('changesSaved')),
          backgroundColor: Colors.green,
        ),
      );
      await AuthNavigation.goToRoleHome(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
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
      avatar = CachedNetworkImageProvider(_profileImageUrl!);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('myProfile')),
        backgroundColor: Colors.orange,
        actions: const [
          LanguageToggleButton(dark: true, showText: false),
          SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.orange,
                  backgroundImage: avatar,
                  child: avatar == null
                      ? const Icon(Icons.person, size: 60, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.t('tapChangePhoto'),
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              const SizedBox(height: 20),
              _input(context.t('fullName'), nameController),
              _input(context.t('email'), emailController, enabled: false),
              _input(context.t('phone'), phoneController),
              _input('National ID', nationalIdController),

              const SizedBox(height: 24),
              _sectionHeader(Icons.security, 'Security & Privacy'),
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
                      title: const Text('Change Password'),
                      subtitle: const Text('Send reset link to your email'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _sendPasswordReset,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              _sectionHeader(Icons.document_scanner, 'Verification Documents'),
              const SizedBox(height: 12),
              _imagePreviewTile(
                'National ID Photo',
                _nationalIdImage,
                _nationalIdImageUrl,
                () => _pickImageForField(true),
              ),
              const SizedBox(height: 14),
              _imagePreviewTile(
                'Driver License Photo',
                _licenseIdImage,
                _licenseIdImageUrl,
                () => _pickImageForField(false),
              ),
              const SizedBox(height: 24),
              _sectionHeader(Icons.language, 'Regional Settings'),
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

  Future<void> _sendPasswordReset() async {
    final email = _auth.currentUser?.email;
    if (email == null) return;

    try {
      await _auth.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password reset email sent to $email'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
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
        GestureDetector(
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
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          const Center(child: CircularProgressIndicator()),
                    ),
                  )
                : const Center(
                    child: Icon(Icons.add_a_photo, color: Colors.grey),
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
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
