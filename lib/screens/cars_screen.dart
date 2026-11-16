import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../widgets/rent_bottom_sheet.dart';
import 'favorites_screen.dart';
import '../services/favorites_service.dart';
import '../l10n/locale_service.dart';
import '../widgets/language_picker.dart';
import '../utils/live_refresh.dart';
import '../theme/app_theme.dart';

class CarsScreen extends StatefulWidget {
  const CarsScreen({super.key});

  @override
  State<CarsScreen> createState() => _CarsScreenState();
}

class _CarsScreenState extends State<CarsScreen> {
  String selectedBrand = 'All';
  String searchQuery = '';
  Set<String> _favoriteIds = {};
  StreamSubscription<Set<String>>? _favoritesSub;

  // One live stream for both the brand chips and the list. Created once so
  // typing in the search box doesn't re-subscribe and flash a spinner.
  final Stream<QuerySnapshot<Map<String, dynamic>>> _carsStream =
      FirebaseFirestore.instance.collection('cars').snapshots();

  @override
  void initState() {
    super.initState();
    _favoritesSub = FavoritesService.watchFavoriteIds().listen((ids) {
      if (mounted) setState(() => _favoriteIds = ids);
    });
  }

  @override
  void dispose() {
    unawaited(_favoritesSub?.cancel());
    super.dispose();
  }

  static double _price(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('availableCars')),
        actions: [
          const LanguageToggleButton(dark: true),
          IconButton(
            icon: const Icon(Icons.favorite),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FavoritesScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: liveDataRefresh,
        color: AppTheme.accent,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: context.t('searchHint'),
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) => setState(() => searchQuery = value),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _carsStream,
                  builder: (context, snapshot) => Column(
                    children: [
                      _buildBrandChips(snapshot.data?.docs),
                      const SizedBox(height: 16),
                      Expanded(child: _buildCarList(snapshot)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrandChips(
    List<QueryDocumentSnapshot<Map<String, dynamic>>>? docs,
  ) {
    if (docs == null) return const SizedBox.shrink();

    final brands = <String>{'All'};
    for (final doc in docs) {
      final brand = doc.data()['brand']?.toString();
      if (brand != null && brand.isNotEmpty) brands.add(brand);
    }

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: brands.map((brand) {
          final selected = selectedBrand == brand;
          final displayLabel = brand == 'All' ? context.t('all') : brand;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(displayLabel),
              selected: selected,
              onSelected: (_) => setState(() => selectedBrand = brand),
              selectedColor: AppTheme.accent.withValues(alpha: 0.3),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCarList(
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 300,
            child: Center(child: Text(context.t('noCars'))),
          ),
        ],
      );
    }

    final cars = snapshot.data!.docs.map((doc) {
      final data = doc.data();
      final price = _price(data['price_per_day']);
      return {
        'id': doc.id,
        'name': (data['name'] ?? '').toString(),
        'brand': (data['brand'] ?? '').toString(),
        'fuel_type': (data['fuel_type'] ?? '').toString(),
        'seats': data['seats'],
        'pricePerDay': price,
        'price': 'EGP ${price.toStringAsFixed(0)} ${context.t('perDay')}',
        'imageUrl': data['image_url'],
        'available': data['available'] != false,
        'avgRating': data['avgRating'],
        'reviewCount': data['reviewCount'],
      };
    }).toList();

    final filtered = cars.where((car) {
      if (car['available'] != true) return false;
      final name = car['name'].toString().toLowerCase();
      final brand = car['brand'].toString().toLowerCase();
      final matchesBrand =
          selectedBrand == 'All' || car['brand'] == selectedBrand;
      final q = searchQuery.toLowerCase();
      final matchesSearch = q.isEmpty || name.contains(q) || brand.contains(q);
      return matchesBrand && matchesSearch;
    }).toList();

    if (filtered.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 300,
            child: Center(child: Text(context.t('noCarsMatch'))),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final car = filtered[index];
        final id = car['id'] as String;
        final isFav = _favoriteIds.contains(id);
        final avg = (car['avgRating'] as num?)?.toDouble();
        final count = (car['reviewCount'] as num?)?.toInt() ?? 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
          child: Column(
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child:
                        car['imageUrl'] != null &&
                            car['imageUrl'].toString().isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: car['imageUrl'],
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              height: 180,
                              color: Colors.grey.shade100,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                            errorWidget: (_, _, _) => _imageFallback(),
                          )
                        : _imageFallback(),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      child: IconButton(
                        icon: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          color: Colors.red,
                        ),
                        onPressed: () => FavoritesService.toggle(id, car),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            car['name'] as String,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${car['brand']} · ${car['fuel_type']} · ${car['seats'] ?? '-'} ${context.t('seats')}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                          if (avg != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              '★ ${avg.toStringAsFixed(1)} ($count)',
                              style: const TextStyle(
                                color: AppTheme.accent,
                                fontSize: 13,
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            car['price'] as String,
                            style: const TextStyle(
                              color: AppTheme.accent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        unawaited(
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(20),
                              ),
                            ),
                            builder: (_) => RentBottomSheet(car: car),
                          ),
                        );
                      },
                      child: Text(context.t('rent')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _imageFallback() {
    return Image.network(
      'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?auto=format&fit=crop&w=800&q=80',
      height: 180,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        height: 180,
        width: double.infinity,
        color: Colors.grey.shade900,
        child: const Center(
          child: Icon(Icons.directions_car, size: 80, color: Colors.orange),
        ),
      ),
    );
  }
}
