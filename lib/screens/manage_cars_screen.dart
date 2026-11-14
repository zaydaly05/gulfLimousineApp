import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_car_screen.dart';
import 'edit_car_screen.dart';
import '../services/cloudinary_service.dart';
import '../l10n/locale_service.dart';
import '../widgets/language_picker.dart';

class ManageCarsScreen extends StatefulWidget {
  const ManageCarsScreen({super.key});

  @override
  State<ManageCarsScreen> createState() => _ManageCarsScreenState();
}

class _ManageCarsScreenState extends State<ManageCarsScreen> {
  final CloudinaryService cloudinary = CloudinaryService();
  bool isUploading = false;

  /// Delete car confirmation + delete image from Cloudinary
  Future<void> deleteCar(
      BuildContext context,
      String id,
      String? publicId,
      ) async {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: Text(context.t('delete'),
            style: const TextStyle(color: Colors.white)),
        content: Text(
          context.t('cannotBeUndone'),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            child: Text(context.t('cancel')),
            onPressed: () => Navigator.pop(dialogContext),
          ),
          TextButton(
            child: Text(context.t('delete'),
                style: const TextStyle(color: Colors.red)),
            onPressed: () async {
              if (publicId != null && publicId.isNotEmpty) {
                await cloudinary.deleteImage(publicId);
              }

              await FirebaseFirestore.instance
                  .collection('cars')
                  .doc(id)
                  .delete();

              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
          ),
        ],
      ),
    );
  }

  /// Pick image and upload to Cloudinary
  Future<void> pickAndUploadCarImage(String carId) async {
    try {
      setState(() => isUploading = true);

      final imageData = await cloudinary.uploadImage();

      if (imageData != null) {
        await FirebaseFirestore.instance
            .collection('cars')
            .doc(carId)
            .update({
          'image_url': imageData['secure_url'],
          'public_id': imageData['public_id'],
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('changesSaved'))),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload failed: $e")),
      );
    } finally {
      if (mounted) setState(() => isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(context.t('manageCars')),
        backgroundColor: Colors.black,
        actions: const [
          LanguageToggleButton(dark: true),
          SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddCarScreen(),
            ),
          );
        },
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              setState(() {});
              await Future<void>.delayed(const Duration(milliseconds: 600));
            },
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('cars')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator());
                }

                if (!snapshot.hasData ||
                    snapshot.data!.docs.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: 400,
                        child: Center(
                          child: Text(
                            context.t('noCars'),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final car =
                  doc.data() as Map<String, dynamic>;

                  return Card(
                    color: Colors.grey.shade900,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(16),
                    ),
                    margin:
                    const EdgeInsets.only(bottom: 16),
                    child: ListTile(
                      leading: car['image_url'] != null &&
                          car['image_url']
                              .toString()
                              .isNotEmpty
                          ? ClipRRect(
                        borderRadius:
                        BorderRadius.circular(8),
                        child: Image.network(
                          car['image_url'],
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (context, error,
                              stackTrace) =>
                          const Icon(
                            Icons.broken_image,
                            color: Colors.red,
                          ),
                        ),
                      )
                          : const Icon(
                        Icons.directions_car,
                        color: Colors.orange,
                        size: 40,
                      ),
                      title: Text(
                        car['name'] ?? 'No Name',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        "${car['brand'] ?? ''} • ${car['price_per_day'] ?? ''} EGP${context.t('perDay')}",
                        style: TextStyle(
                            color: Colors.grey.shade400),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.image,
                                color: Colors.orange),
                            tooltip: 'Upload Image',
                            onPressed: () =>
                                pickAndUploadCarImage(
                                    doc.id),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit,
                                color: Colors.blue),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      EditCarScreen(
                                        carId: doc.id,
                                        carData: car,
                                      ),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete,
                                color: Colors.red),
                            onPressed: () =>
                                deleteCar(
                                  context,
                                  doc.id,
                                  car['public_id'],
                                ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),

          if (isUploading)
            Container(
              color: Colors.black.withValues(alpha: 0.6),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.orange,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
