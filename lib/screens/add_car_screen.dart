import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/cloudinary_service.dart';
import '../utils/image_decode.dart';
import '../models/fleet.dart';
import '../widgets/fleet_colors_editor.dart';
import '../l10n/locale_service.dart';
import '../widgets/app_feedback.dart';

class AddCarScreen extends StatefulWidget {
  const AddCarScreen({super.key});

  @override
  State<AddCarScreen> createState() => _AddCarScreenState();
}

class _AddCarScreenState extends State<AddCarScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController name = TextEditingController();
  final TextEditingController nameAr = TextEditingController();
  final TextEditingController brand = TextEditingController();
  final TextEditingController price = TextEditingController();
  final TextEditingController seats = TextEditingController();

  final CloudinaryService cloudinary = CloudinaryService();

  String fuelType = "Petrol";
  bool _isLoading = false;

  String? imageUrl;
  String? publicId;
  List<FleetColor> _colors = const [];

  @override
  void dispose() {
    name.dispose();
    nameAr.dispose();
    brand.dispose();
    price.dispose();
    seats.dispose();
    super.dispose();
  }

  /// Price per day: a positive number (a typo like "1,500" or "abc" used to
  /// reach double.parse and fail the save with a generic error).
  static String? _validatePrice(String? v) {
    final n = double.tryParse((v ?? '').trim());
    return n == null || n <= 0 ? tr('enterAValidPricePer') : null;
  }

  static String? _validateSeats(String? v) {
    final n = int.tryParse((v ?? '').trim());
    return n == null || n <= 0 ? tr('enterValidSeats') : null;
  }

  /// 🚗 ADD CAR
  Future<void> _addCar() async {
    if (!_formKey.currentState!.validate()) return;
    final colorProblem = Fleet.validate(_colors);
    if (colorProblem != null || _colors.isEmpty) {
      ScaffoldMessenger.of(context)
          .showInfo(colorProblem ?? tr('addOneColour'));
      return;
    }

    if (imageUrl == null) {
      ScaffoldMessenger.of(context).showError(tr('pleaseUploadACarImage'));
      return;
    }

    try {
      setState(() => _isLoading = true);

      await FirebaseFirestore.instance.collection('cars').add({
        'name': name.text.trim(),
        if (nameAr.text.trim().isNotEmpty) 'name_ar': nameAr.text.trim(),
        'brand': brand.text.trim(),
        'price_per_day': double.parse(price.text.trim()), // validated
        'seats': int.parse(seats.text.trim()), // validated
        'fuel_type': fuelType,
        'colors': [for (final c in _colors) c.toMap()],
        'image_url': imageUrl,
        'public_id': publicId,
        'available': true,
        'created_at': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);

      messenger.showSuccess(tr('carAddedSuccessfully'));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showError(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 📷 Upload image to Cloudinary
  Future<void> _uploadImage() async {
    if (_isLoading) return; // one upload at a time
    try {
      setState(() => _isLoading = true);

      final imageData = await cloudinary.uploadImage();

      if (imageData != null && mounted) {
        setState(() {
          imageUrl = imageData['secure_url'];
          publicId = imageData['public_id'];
        });

        ScaffoldMessenger.of(context)
            .showSuccess(tr('imageUploadedSuccessfully'));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showError(e, title: tr('uploadFailed'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(tr('addCarTitle')),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              /// 🖼 IMAGE UPLOAD
              Semantics(
                button: true,
                label: tr('uploadCarImage'),
                child: GestureDetector(
                  onTap: _uploadImage,
                  child: Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(16),
                      image: imageUrl != null
                          ? DecorationImage(
                              image: ResizeImage(
                                NetworkImage(imageUrl!),
                                width: screenDecodeWidth(context),
                              ),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: imageUrl == null
                        ? const Center(
                            child: Icon(
                              Icons.add_a_photo,
                              size: 50,
                              color: Colors.white70,
                            ),
                          )
                        : null,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              _input(tr('carName'), name),
              _input(tr('carNameArOptional'), nameAr, required: false),
              _input(tr('brand'), brand),
              _input(
                tr('pricePerDay'),
                price,
                type: const TextInputType.numberWithOptions(decimal: true),
                validator: _validatePrice,
              ),
              _input(
                tr('numberOfSeats'),
                seats,
                type: TextInputType.number,
                validator: _validateSeats,
              ),

              const SizedBox(height: 10),
              Text(tr('fuelType'), style: TextStyle(color: Colors.white)),
              const SizedBox(height: 5),

              DropdownButtonFormField<String>(
                initialValue: fuelType,
                dropdownColor: Colors.grey.shade900,
                items: ["Petrol", "Diesel", "Electric"]
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e, child: Text(fuelLabel(e))),
                    )
                    .toList(),
                onChanged: (val) => setState(() => fuelType = val!),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey.shade800,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              FleetColorsEditor(
                initial: const [],
                onChanged: (colors) => _colors = colors,
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.all(14),
                ),
                onPressed: _isLoading ? null : _addCar,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(tr('addCar')),
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
    bool required = true,
    String? Function(String?)? validator,
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
        validator:
            validator ??
            (v) => required && (v ?? '').trim().isEmpty ? tr('required') : null,
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
