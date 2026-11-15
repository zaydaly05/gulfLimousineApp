import 'package:flutter/material.dart';

// Form inputs for the admin screens' dark (black) forms.

/// Outlined input decoration: grey border, orange when focused.
InputDecoration darkInputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.white70),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.grey.shade700),
      borderRadius: BorderRadius.circular(10),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: Colors.orange),
      borderRadius: BorderRadius.circular(10),
    ),
  );
}

/// White-text form field with [darkInputDecoration]; validates non-empty
/// input unless [required] is false.
class DarkTextFormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType type;
  final bool required;

  const DarkTextFormField(
    this.controller,
    this.label, {
    super.key,
    this.type = TextInputType.text,
    this.required = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: type,
        style: const TextStyle(color: Colors.white),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
            : null,
        decoration: darkInputDecoration(label),
      ),
    );
  }
}
