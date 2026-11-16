import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/cloudinary_service.dart';
import '../utils/image_decode.dart';

class EditCarScreen extends StatefulWidget {
  final String carId;
  final Map<String, dynamic> carData;

  const EditCarScreen({super.key, required this.carId, required this.carData});

  @override
  State<EditCarScreen> createState() => _EditCarScreenState();
}

class _EditCarScreenState extends State<EditCarScreen> {
  late TextEditingController nameController;
  late TextEditingController brandController;
  late TextEditingController priceController;

  final CloudinaryService cloudinary = CloudinaryService();

  String? imageUrl;
  String? publicId;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();

    final data = widget.carData;
    nameController = TextEditingController(text: data['name']?.toString());
    brandController = TextEditingController(text: data['brand']?.toString());
    priceController = TextEditingController(
      text: data['price_per_day']?.toString() ?? '',
    );

    imageUrl = data['image_url']?.toString();
    publicId = data['public_id']?.toString();
  }

  @override
  void dispose() {
    nameController.dispose();
    brandController.dispose();
    priceController.dispose();
    super.dispose();
  }

  Future<void> replaceImage() async {
    final imageData = await cloudinary.uploadImage();
    if (imageData == null || !mounted) return;
    // The old image is deleted only after the car is saved (updateCar), so
    // cancelling or a failed save never leaves the car with a missing image.

    setState(() {
      // uploadBytes returns 'secure_url'; reading 'url' wiped the image.
      imageUrl = imageData['secure_url']?.toString();
      publicId = imageData['public_id']?.toString();
    });
  }

  /// Removes the previous image from Cloudinary once the car points at the
  /// new one. Best effort: the car is already saved.
  Future<void> _deleteReplacedImage() async {
    final oldId = widget.carData['public_id']?.toString();
    if (oldId == null || oldId.isEmpty || oldId == publicId) return;
    try {
      await cloudinary.deleteAsset(oldId);
    } catch (e) {
      debugPrint('Old car image delete failed: $e');
    }
  }

  Future<void> updateCar() async {
    final price = double.tryParse(priceController.text.trim());
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid price per day')),
      );
      return;
    }
    try {
      setState(() => isLoading = true);

      await FirebaseFirestore.instance
          .collection('cars')
          .doc(widget.carId)
          .update({
            'name': nameController.text.trim(),
            'brand': brandController.text.trim(),
            'price_per_day': price,
            'image_url': imageUrl,
            'public_id': publicId,
          });

      await _deleteReplacedImage();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Edit Car"),
        backgroundColor: Colors.black,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                /// IMAGE PREVIEW
                if (imageUrl != null && imageUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl!,
                      cacheWidth: screenDecodeWidth(context),
                      height: 180,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.directions_car,
                      color: Colors.orange,
                      size: 80,
                    ),
                  ),

                const SizedBox(height: 12),

                ElevatedButton(
                  onPressed: replaceImage,
                  child: const Text("Replace Image"),
                ),

                const SizedBox(height: 20),

                buildTextField(nameController, "Car Name"),
                buildTextField(brandController, "Brand"),
                buildTextField(
                  priceController,
                  "Price Per Day",
                  isNumber: true,
                ),

                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: updateCar,
                  child: const Text("Update Car"),
                ),
              ],
            ),
          ),

          if (isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.6),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.orange),
              ),
            ),
        ],
      ),
    );
  }

  Widget buildTextField(
    TextEditingController controller,
    String label, {
    bool isNumber = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : null,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey.shade700),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.orange),
          ),
        ),
      ),
    );
  }
}
