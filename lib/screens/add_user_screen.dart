import 'dart:math';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';
import '../services/user_profile_service.dart';
import '../l10n/locale_service.dart';
import '../widgets/app_feedback.dart';

class AddUserScreen extends StatefulWidget {
  const AddUserScreen({super.key});

  @override
  State<AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends State<AddUserScreen> {
  final _formKey = GlobalKey<FormState>();

  final name = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();

  String role = "user";
  bool _isLoading = false;

  static String _randomPassword() {
    const chars =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789!@#%*-_';
    final random = Random.secure();
    return List.generate(32, (_) => chars[random.nextInt(chars.length)]).join();
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) return;

    FirebaseApp? secondaryApp;

    try {
      setState(() => _isLoading = true);

      // Use a secondary Auth instance so the admin stays signed in.
      secondaryApp = await Firebase.initializeApp(
        name: 'SecondaryAuth_${DateTime.now().millisecondsSinceEpoch}',
        options: DefaultFirebaseOptions.currentPlatform,
      );
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      // Random throwaway password that nobody ever sees; the new user sets
      // their own through the reset email sent below.
      final UserCredential credential = await secondaryAuth
          .createUserWithEmailAndPassword(
            email: email.text.trim(),
            password: _randomPassword(),
          );

      final uid = credential.user!.uid;
      await secondaryAuth.sendPasswordResetEmail(email: email.text.trim());

      // Written by the signed-in admin: the rules only let admins assign a
      // role, so a new account can't make itself an admin.
      await UserProfileService.adminCreateUser(
        uid: uid,
        name: name.text.trim(),
        email: email.text.trim(),
        phone: phone.text.trim(),
        role: role,
      );

      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);

      messenger.showSuccess(tr('userCreatedALinkTo'));
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showError(e);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showError(e);
    } finally {
      if (secondaryApp != null) {
        await FirebaseAuth.instanceFor(app: secondaryApp).signOut();
        await secondaryApp.delete();
      }
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: Text(tr('addUser'))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _input(tr('fullName'), name),
              _input(tr('email'), email, type: TextInputType.emailAddress),
              _input(tr('phoneNumber'), phone, type: TextInputType.phone),

              const SizedBox(height: 10),

              Text(tr('userRole'), style: TextStyle(color: Colors.white)),
              const SizedBox(height: 5),

              DropdownButtonFormField<String>(
                initialValue: role,
                dropdownColor: Colors.grey.shade900,
                items: ["user", "admin"]
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e, child: Text(roleLabel(e))),
                    )
                    .toList(),
                onChanged: (val) => setState(() => role = val!),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey.shade800,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.all(14),
                ),
                onPressed: _isLoading ? null : _createUser,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(tr('createUser')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _input(
    String label,
    TextEditingController controller, {
    TextInputType type = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: type,
        // Phone numbers and emails read left to right in Arabic too.
        textDirection:
            type == TextInputType.phone || type == TextInputType.emailAddress
            ? TextDirection.ltr
            : null,
        validator: (v) => v == null || v.isEmpty ? tr('required') : null,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: Colors.grey.shade800,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.orange),
          ),
        ),
      ),
    );
  }
}
