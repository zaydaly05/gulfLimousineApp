import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/favorites_service.dart';
import '../widgets/rent_bottom_sheet.dart';
import '../l10n/locale_service.dart';
import '../utils/live_refresh.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t('favoritesTitle'))),
      body: RefreshIndicator(
        onRefresh: liveDataRefresh,
        child: StreamBuilder<QuerySnapshot>(
          stream: FavoritesService.watchFavorites(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: 400,
                    child: Center(child: Text(context.t('noFavorites'))),
                  ),
                ],
              );
            }
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final carId = docs[index].id;
                final price = (data['price_per_day'] as num?)?.toDouble() ?? 0;
                final car = {
                  'id': carId,
                  'name': data['name']?.toString() ?? context.t('cars'),
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
                      '${car['brand']} · EGP ${price.toStringAsFixed(0)}${context.t('perDay')}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.favorite, color: Colors.red),
                      onPressed: () => FavoritesService.toggle(carId, car),
                    ),
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                        ),
                        builder: (_) => RentBottomSheet(car: car),
                      );
                    },
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
