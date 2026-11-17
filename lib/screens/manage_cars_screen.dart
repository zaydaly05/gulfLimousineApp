import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'add_car_screen.dart';
import 'edit_car_screen.dart';
import '../services/cloudinary_service.dart';
import '../l10n/locale_service.dart';
import '../widgets/language_picker.dart';
import '../utils/live_refresh.dart';
import '../utils/image_decode.dart';
import '../widgets/empty_state.dart';
import '../models/fleet.dart';
import '../utils/safe_insets.dart';
import '../widgets/app_feedback.dart';

class ManageCarsScreen extends StatefulWidget {
  const ManageCarsScreen({super.key});

  @override
  State<ManageCarsScreen> createState() => _ManageCarsScreenState();
}

class _ManageCarsScreenState extends State<ManageCarsScreen> {
  final CloudinaryService cloudinary = CloudinaryService();
  // Created once, not in build(): rebuilding it on every setState would
  // reopen the Firestore listener and flash the loading spinner.
  final _carsStream = FirebaseFirestore.instance.collection('cars').snapshots();
  bool isUploading = false;

  /// Delete car confirmation + delete image from Cloudinary
  Future<void> deleteCar(
    BuildContext context,
    String id,
    String? publicId,
  ) async {
    unawaited(
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: Colors.grey.shade900,
          title: Text(
            context.t('delete'),
            style: const TextStyle(color: Colors.white),
          ),
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
              child: Text(
                context.t('delete'),
                style: const TextStyle(color: Colors.red),
              ),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  // Remove the car first so it never points at a deleted image.
                  await FirebaseFirestore.instance
                      .collection('cars')
                      .doc(id)
                      .delete();
                } catch (e) {
                  messenger.showError(e);
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  return;
                }
                if (dialogContext.mounted) Navigator.pop(dialogContext);

                if (publicId != null && publicId.isNotEmpty) {
                  try {
                    await cloudinary.deleteAsset(publicId);
                  } catch (e) {
                    // The car is gone; only the stored file is left behind.
                    debugPrint('Car image delete failed: $e');
                    messenger.showInfo(tr('carDeletedButItsImage'));
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Pick image and upload to Cloudinary
  Future<void> pickAndUploadCarImage(String carId) async {
    try {
      setState(() => isUploading = true);

      final imageData = await cloudinary.uploadImage();

      if (imageData != null) {
        await FirebaseFirestore.instance.collection('cars').doc(carId).update({
          'image_url': imageData['secure_url'],
          'public_id': imageData['public_id'],
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showInfo(context.t('changesSaved'));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showError(e, title: tr('uploadFailed'));
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
          LanguageToggleButton(dark: true, showText: false),
          SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: context.t('addCar'),
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddCarScreen()),
          );
        },
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: liveDataRefresh,
            child: StreamBuilder<QuerySnapshot>(
              stream: _carsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return ErrorView(error: snapshot.error, dark: true);
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return EmptyState(
                    icon: Icons.directions_car_outlined,
                    message: context.t('noCars'),
                    dark: true,
                  );
                }

                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  // Bottom room so the + button never covers the last car.
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    88,
                  ).withSafeBottom(context),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final car = doc.data() as Map<String, dynamic>;

                    return Card(
                      color: Colors.grey.shade900,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 60,
                              height: 60,
                              child:
                                  car['image_url'] != null &&
                                      car['image_url'].toString().isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        car['image_url'],
                                        cacheWidth: decodeWidth(
                                          context,
                                          60 * 2,
                                        ),
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
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
                            ),
                            const SizedBox(width: 12),
                            // The name gets the card's full width; the
                            // actions sit beside the brand and price below it.
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    car['name'] ?? tr('noName'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          [
                                            car['brand'] ?? '',
                                            tr(
                                              'egpPerDay',
                                              args: {
                                                'amount':
                                                    '${car['price_per_day'] ?? ''}',
                                              },
                                            ),
                                            Fleet.summary(car),
                                          ].where((l) => l.isNotEmpty).join('\n'),
                                          style: TextStyle(
                                            color: Colors.grey.shade400,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.image,
                                          color: Colors.orange,
                                        ),
                                        tooltip: tr('uploadImage'),
                                        onPressed: () =>
                                            pickAndUploadCarImage(doc.id),
                                      ),
                                      IconButton(
                                        tooltip: context.t('edit'),
                                        icon: const Icon(
                                          Icons.edit,
                                          color: Colors.blue,
                                        ),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => EditCarScreen(
                                                carId: doc.id,
                                                carData: car,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      IconButton(
                                        tooltip: context.t('delete'),
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                        onPressed: () => deleteCar(
                                          context,
                                          doc.id,
                                          car['public_id'],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
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
                child: CircularProgressIndicator(color: Colors.orange),
              ),
            ),
        ],
      ),
    );
  }
}
