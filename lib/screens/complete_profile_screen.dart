import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/cloudinary_service.dart';
import '../services/auth_navigation.dart';
import '../services/user_profile_service.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nationalIdController = TextEditingController();
  final _phoneController = TextEditingController();

  // Picked images are kept as bytes (not dart:io File) so this screen also
  // works in the web build.
  Uint8List? _nationalIdImage;
  Uint8List? _licenseIdImage;
  bool _isLoading = false;

  final _picker = ImagePicker();
  final _cloudinary = CloudinaryService();

  @override
  void dispose() {
    _nationalIdController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isNationalId) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_nationalIdImage == null || _licenseIdImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload both ID and License images'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No user found');

      // Upload images to Cloudinary
      final nationalIdUpload = await _cloudinary.uploadBytes(
        _nationalIdImage!,
        filename: 'national_id_${user.uid}.jpg',
      );
      final licenseIdUpload = await _cloudinary.uploadBytes(
        _licenseIdImage!,
        filename: 'license_id_${user.uid}.jpg',
      );

      if (nationalIdUpload == null || licenseIdUpload == null) {
        throw Exception('Failed to upload images');
      }

      await UserProfileService.completeProfile(
        user.uid,
        nationalId: _nationalIdController.text.trim(),
        phone: _phoneController.text.trim(),
        nationalIdUpload: nationalIdUpload,
        licenseIdUpload: licenseIdUpload,
      );

      if (!mounted) return;
      await AuthNavigation.goToRoleHome(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Complete Your Profile'),
          automaticallyImplyLeading: false,
          backgroundColor: Colors.orange,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'We need a few more details to get you started.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: _inputDecoration('Phone Number', Icons.phone),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nationalIdController,
                  decoration: _inputDecoration(
                    'National ID Number',
                    Icons.badge,
                  ),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                _imagePickerTile(
                  'National ID Photo',
                  _nationalIdImage,
                  () => _pickImage(true),
                ),
                const SizedBox(height: 16),
                _imagePickerTile(
                  'Driver License Photo',
                  _licenseIdImage,
                  () => _pickImage(false),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Complete Registration',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => AuthNavigation.signOut(context),
                  child: const Text(
                    'Cancel & Logout',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.orange),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _imagePickerTile(String label, Uint8List? image, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 150,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade400),
            ),
            child: image != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      image,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  )
                : const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                        Text(
                          'Tap to upload image',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
