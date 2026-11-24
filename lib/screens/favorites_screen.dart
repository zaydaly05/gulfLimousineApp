import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/favorites_service.dart';
import '../widgets/rent_bottom_sheet.dart';
import '../l10n/locale_service.dart';
import '../utils/live_refresh.dart';
import '../utils/image_decode.dart';
import '../widgets/empty_state.dart';
import '../utils/safe_insets.dart';
import '../l10n/content_labels.dart';
import '../widgets/app_feedback.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  // Streams are created once (late = on first use), not in build():
  // a rebuild (e.g. language change) would otherwise reopen the
  // Firestore listener and flash the loading spinner.
  final _favoritesStream = FavoritesService.watchFavorites();

  /// Car ids whose live details are loading, so a double tap opens one sheet.
  final _opening = <String>{};

  Future<void> _toggle(String carId, Map<String, dynamic> car) async {
    try {
      await FavoritesService.toggle(carId, car);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showError(e);
    }
  }

  /// Books from the car's current details (price, name, availability),
  /// not the copy saved with the favourite.
  Future<void> _openRentSheet(String carId) async {
    if (!_opening.add(carId)) return;
    try {
      final car = await FavoritesService.liveCar(carId);
      if (!mounted) return;
      if (car == null) {
        ScaffoldMessenger.of(context).showInfo(tr('carNoLongerAvailable'));
        return;
      }
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => RentBottomSheet(car: car),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showError(e);
    } finally {
      _opening.remove(carId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t('favoritesTitle'))),
      body: RefreshIndicator(
        onRefresh: liveDataRefresh,
        child: StreamBuilder<QuerySnapshot>(
          stream: _favoritesStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ErrorView(error: snapshot.error);
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return EmptyState(
                icon: Icons.favorite_border,
                message: context.t('noFavorites'),
              );
            }
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(16).withSafeBottom(context),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final carId = docs[index].id;
                final price = (data['price_per_day'] as num?)?.toDouble() ?? 0;
                final car = {
                  'id': carId,
                  'name': carNameOf(data, fallback: tr('carFallback')),
                  'brand': data['brand']?.toString() ?? '',
                  'pricePerDay': price,
                  'imageUrl': data['image_url'],
                  'available': true,
                };
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: data['image_url'] != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              cacheWidth: decodeWidth(context, 56 * 2),
                              data['image_url'],
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const Icon(Icons.directions_car),
                            ),
                          )
                        : const Icon(Icons.directions_car),
                    title: Text(car['name'] as String),
                    subtitle: Text(
                      '${car['brand']} · ${tr('egpPerDay', args: {'amount': price.toStringAsFixed(0)})}',
                    ),
                    trailing: IconButton(
                      tooltip: context.t('favorites'),
                      icon: const Icon(Icons.favorite, color: Colors.red),
                      onPressed: () => _toggle(carId, car),
                    ),
                    onTap: () => _openRentSheet(carId),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
