import 'package:flutter/material.dart';

import '../services/user_profile_service.dart';
import '../utils/safe_insets.dart';
import '../l10n/locale_service.dart';
import '../widgets/app_feedback.dart';

class EditUserScreen extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> userData;

  const EditUserScreen({
    super.key,
    required this.userId,
    required this.userData,
  });

  @override
  State<EditUserScreen> createState() => _EditUserScreenState();
}

class _EditUserScreenState extends State<EditUserScreen> {
  /// Roles the app understands. A free-text field allowed typos such as
  /// "Admin" that silently removed admin access.
  static const _roles = ['user', 'admin'];

  late final TextEditingController nameController;
  late final TextEditingController emailController;
  late final TextEditingController phoneController;
  late String _role;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final data = widget.userData;
    nameController = TextEditingController(text: data['name']?.toString());
    emailController = TextEditingController(text: data['email']?.toString());
    phoneController = TextEditingController(
      text: (data['phone_number'] ?? data['phone'])?.toString(),
    );
    final role = (data['role'] ?? 'user').toString().toLowerCase();
    _role = _roles.contains(role) ? role : 'user';
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> updateUser() async {
    setState(() => _saving = true);
    try {
      final phone = phoneController.text.trim();
      await UserProfileService.update(widget.userId, {
        'name': nameController.text.trim(),
        'email': emailController.text.trim(),
        'role': _role,
        // Both keys are read across the app.
        'phone': phone,
        'phone_number': phone,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(tr('editUserTitle')),
        backgroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16).withSafeBottom(context),
        child: Column(
          // Full-width button, like the other admin forms.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            buildField(nameController, tr('name')),
            buildField(emailController, tr('email'), ltr: true),
            buildField(phoneController, tr('phoneNumber'), ltr: true),
            DropdownButtonFormField<String>(
              initialValue: _role,
              dropdownColor: Colors.grey.shade900,
              style: const TextStyle(color: Colors.white),
              decoration: _decoration(tr('role')),
              items: _roles
                  .map(
                    (r) =>
                        DropdownMenuItem(value: r, child: Text(roleLabel(r))),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _role = v);
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saving ? null : updateUser,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(tr('updateUser')),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.grey.shade700),
      ),
    );
  }

  Widget buildField(
    TextEditingController controller,
    String label, {
    bool ltr = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        textDirection: ltr ? TextDirection.ltr : null,
        style: const TextStyle(color: Colors.white),
        decoration: _decoration(label),
      ),
    );
  }
}
