import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ADMIN PAGES
import 'manage_cars_screen.dart';
import 'manage_users.dart';
import 'manage_bookings.dart';
import 'edit_booking_screen.dart';
import 'manage_chauffeurs_screen.dart';
import 'manage_reviews_screen.dart';
import 'complimentary_rentals_screen.dart';
import 'view_payments.dart';
import 'chatbot_screen.dart';
import 'traffic_violations_screen.dart';
import 'admin_security_hub.dart';
import '../widgets/admin_charts.dart';
import '../services/auth_navigation.dart';
import '../services/notification_service.dart';
import '../widgets/biometric_settings_tile.dart';
import '../services/traffic_violation_service.dart';
import '../widgets/language_picker.dart';
import '../l10n/locale_service.dart';
import '../utils/live_refresh.dart';
import '../services/complimentary_rental_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  // Streams are created once (not in build) so a rebuild never tears down
  // and re-opens the Firestore listeners behind every card.
  late final _carsStream = firestore.collection('cars').snapshots();
  late final _usersStream = firestore.collection('users').snapshots();
  late final _paymentsStream = firestore.collection('payments').snapshots();
  late final _giftsStream = firestore
      .collection('complimentary_rentals')
      .snapshots();
  late final _violationsStream = TrafficViolationService.watchAll();
  late final _recentBookingsStream = firestore
      .collection('bookings')
      .orderBy('createdAt', descending: true)
      .limit(5)
      .snapshots();
  // One bookings listener feeds the count card, both extra-km cards and the
  // pending extra-km section (see _bookingsOverview).
  late final _bookingsStream = firestore.collection('bookings').snapshots();

  @override
  void initState() {
    super.initState();
    unawaited(NotificationService.instance.initialize());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          context.t('adminTitle'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: const [
          LanguageToggleButton(dark: true, showText: false),
          SizedBox(width: 4),
        ],
        iconTheme: const IconThemeData(color: Colors.orange),
      ),

      /// 🔥 DRAWER
      drawer: Drawer(
        backgroundColor: Colors.black,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              padding: EdgeInsets.fromLTRB(
                16,
                MediaQuery.paddingOf(context).top + 16,
                16,
                16,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A),
                border: Border(
                  bottom: BorderSide(color: Colors.orange, width: 2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.orange,
                    radius: 30,
                    child: Icon(
                      Icons.admin_panel_settings,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.t('adminPanel'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'System Control Center',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const LanguagePicker(dark: true),
            const Divider(color: Colors.white24),
            const BiometricSettingsTile(dark: true),

            _drawerItem(
              context,
              Icons.directions_car,
              context.t('manageCars'),
              const ManageCarsScreen(),
            ),
            _drawerItem(
              context,
              Icons.people,
              context.t('users'),
              const ManageUsersScreen(),
            ),
            _drawerItem(
              context,
              Icons.calendar_today,
              context.t('bookings'),
              const ManageBookingsScreen(),
            ),
            _drawerItem(
              context,
              Icons.card_giftcard,
              context.t('complimentary'),
              const ComplimentaryRentalsScreen(),
            ),
            _drawerItem(
              context,
              Icons.badge,
              context.t('chauffeurs'),
              const ManageChauffeursScreen(),
            ),
            _drawerItem(
              context,
              Icons.star,
              context.t('reviews'),
              const ManageReviewsScreen(),
            ),
            _drawerItem(
              context,
              Icons.gavel,
              context.t('trafficViolations'),
              const TrafficViolationsScreen(),
            ),
            _drawerItem(
              context,
              Icons.security,
              'Security & GPS',
              const AdminSecurityHub(),
            ),
            _drawerItem(
              context,
              Icons.attach_money,
              context.t('payments'),
              const ViewPaymentsScreen(),
            ),
            _drawerItem(
              context,
              Icons.smart_toy,
              context.t('askAi'),
              const ChatbotScreen(userName: 'Admin', adminMode: true),
            ),

            const Divider(color: Colors.white54),

            /// 🔴 LOGOUT BUTTON
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: Text(
                context.t('logout'),
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                unawaited(_confirmLogout(context));
              },
            ),
          ],
        ),
      ),

      /// 🧠 BODY
      body: RefreshIndicator(
        onRefresh: liveDataRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            24 + MediaQuery.viewPaddingOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.t('dashboardOverview'),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              /// 📊 LIVE STATS
              _bookingsOverview(),

              const SizedBox(height: 16),
              _complimentarySection(),

              const SizedBox(height: 16),
              _trafficViolationsSection(),

              const SizedBox(height: 25),

              AdminAnalyticsSection(firestore: firestore),

              const SizedBox(height: 25),

              /// 🕒 RECENT BOOKINGS
              Text(
                context.t('recentBookings'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),

              StreamBuilder<QuerySnapshot>(
                stream: _recentBookingsStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return Column(
                    children: snapshot.data!.docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final extraLabel = bookingHasExtraKmCharge(data)
                          ? ' · ${extraKmPaymentStatusLabel(data)}'
                          : '';
                      return _bookingTile(
                        resolveBookingName(data),
                        resolveBookingCar(data),
                        resolveBookingDateLabel(data),
                        '${(data['status'] ?? 'pending').toString()}$extraLabel',
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 🔐 LOGOUT CONFIRMATION
  Future<void> _confirmLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t('confirmLogout')),
        content: Text(context.t('logoutConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.t('logout')),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    await AuthNavigation.signOut(context);
  }

  /// 🔢 STAT CARD
  Widget _statCard(String title, Stream<QuerySnapshot> stream, IconData icon) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        return DashboardCard(title: title, value: count.toString(), icon: icon);
      },
    );
  }

  /// 💰 REVENUE
  Widget _revenueCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: _paymentsStream,
      builder: (context, snapshot) {
        double total = 0;
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final amount = data['amount'];
            if ((data['status'] ?? '').toString() == 'paid' && amount is num) {
              total += amount.toDouble();
            }
          }
        }
        return DashboardCard(
          title: context.t('revenuePaid'),
          value: "EGP ${total.toStringAsFixed(0)}",
          icon: Icons.attach_money,
        );
      },
    );
  }

  /// Stat grid plus the pending extra-km section, all computed from one
  /// bookings snapshot so the extra-km stats are calculated once per change.
  Widget _bookingsOverview() {
    return StreamBuilder<QuerySnapshot>(
      stream: _bookingsStream,
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const <QueryDocumentSnapshot>[];
        final stats = computeExtraKmStats(docs);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.3,
              ),
              children: [
                _statCard(
                  context.t('totalCars'),
                  _carsStream,
                  Icons.directions_car,
                ),
                DashboardCard(
                  title: context.t('bookings'),
                  value: '${docs.length}',
                  icon: Icons.calendar_today,
                ),
                _statCard(context.t('users'), _usersStream, Icons.people),
                _revenueCard(),
                _extraKmPendingCard(stats),
                _extraKmCollectedCard(stats),
              ],
            ),
            const SizedBox(height: 16),
            _pendingExtraKmSection(docs, stats),
          ],
        );
      },
    );
  }

  Widget _extraKmPendingCard(ExtraKmDashboardStats stats) {
    return DashboardCard(
      title: context.t('pendingExtraKm'),
      value: stats.pendingCount.toString(),
      icon: Icons.pending_actions,
    );
  }

  Widget _extraKmCollectedCard(ExtraKmDashboardStats stats) {
    return DashboardCard(
      title: context.t('extraKmCollected'),
      value: "EGP ${stats.paidAmount.toStringAsFixed(0)}",
      icon: Icons.add_road,
    );
  }

  Widget _pendingExtraKmSection(
    List<QueryDocumentSnapshot> docs,
    ExtraKmDashboardStats stats,
  ) {
    final pending = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return bookingHasExtraKmCharge(data) &&
          (data['extraKmPaymentStatus'] ?? '') == 'pending';
    }).toList();

    if (pending.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.t('pendingExtraKmPayments'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ManageBookingsScreen(),
                  ),
                );
              },
              child: Text(context.t('manageAll')),
            ),
          ],
        ),
        Text(
          context.t(
            'pendingBookingsCount',
            args: {
              'count': '${stats.pendingCount}',
              'amount': stats.pendingAmount.toStringAsFixed(0),
            },
          ),
          style: TextStyle(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 8),
        ...pending.take(3).map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final km = parseKmAllowance(data);
          final charge = (km?['extraKmChargeEgp'] as num?)?.toDouble() ?? 0;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.orange,
                child: Icon(Icons.speed, color: Colors.white, size: 20),
              ),
              title: Text(resolveBookingName(data)),
              subtitle: Text(
                '${resolveBookingCar(data)} · '
                '${km?['extraKm'] ?? 0} extra km',
              ),
              trailing: Text(
                'EGP ${charge.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        EditBookingScreen(bookingId: doc.id, bookingData: data),
                  ),
                );
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _complimentarySection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _giftsStream,
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final now = DateTime.now();
        var monthTotal = 0.0;
        var yearTotal = 0.0;
        final active = <QueryDocumentSnapshot>[];

        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['status'] ?? '').toString();
          if (status == 'active') active.add(doc);
          if (status == 'cancelled') continue;
          final value = ComplimentaryRentalService.giftedValue(data);
          final date =
              timestampDate(data['startDate']) ??
              timestampDate(data['createdAt']);
          if (date == null || date.year != now.year) continue;
          yearTotal += value;
          if (date.month == now.month) monthTotal += value;
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF6EB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFE0B2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.card_giftcard, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.t('complimentaryGiftCars'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ComplimentaryRentalsScreen(),
                        ),
                      );
                    },
                    child: Text(context.t('manage')),
                  ),
                ],
              ),
              Text(
                '${context.t('thisMonthGifted')}: EGP ${monthTotal.toStringAsFixed(0)} · '
                '${context.t('thisYear')}: EGP ${yearTotal.toStringAsFixed(0)}'
                '${active.isEmpty ? '' : ' · ${active.length} car(s) out'}',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 8),
              if (active.isEmpty)
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.orange,
                      child: Icon(Icons.card_giftcard, color: Colors.white),
                    ),
                    title: Text(context.t('grantComplimentaryCar')),
                    subtitle: Text(context.t('chooseRecipientCarDuration')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddComplimentaryRentalScreen(),
                        ),
                      );
                    },
                  ),
                )
              else
                ...active.take(3).map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final car = resolveBookingCar(data);
                  final brand = (data['brand'] ?? '').toString();
                  final label = [if (brand.isNotEmpty) brand, car].join(' ');
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.orange,
                        child: Icon(
                          Icons.card_giftcard,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        data['recipientName']?.toString() ?? context.t('guest'),
                      ),
                      subtitle: Text(
                        '$label · until ${formatBookingDate(data['endDate'])}',
                      ),
                      trailing: Text(
                        'EGP ${ComplimentaryRentalService.giftedValue(data).toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ComplimentaryRentalsScreen(),
                          ),
                        );
                      },
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Widget _trafficViolationsSection() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _violationsStream,
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final pending = docs.where((doc) {
          return TrafficViolationService.isPending(doc.data());
        }).toList();
        final pendingAmount = TrafficViolationService.pendingTotal(docs);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF6EB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFE0B2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.gavel, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.t('trafficViolations'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TrafficViolationsScreen(),
                        ),
                      );
                    },
                    child: Text(context.t('manage')),
                  ),
                ],
              ),
              Text(
                pending.isEmpty
                    ? context.t('noPendingTickets')
                    : context.t(
                        'unpaidTickets',
                        args: {
                          'count': '${pending.length}',
                          'amount': pendingAmount.toStringAsFixed(0),
                        },
                      ),
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 8),
              if (pending.isEmpty)
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.orange,
                      child: Icon(Icons.gavel, color: Colors.white),
                    ),
                    title: Text(context.t('addTrafficViolation')),
                    subtitle: Text(context.t('adminOnlyCharge')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TrafficViolationsScreen(),
                        ),
                      );
                    },
                  ),
                )
              else
                ...pending.take(3).map((doc) {
                  final data = doc.data();
                  final isGift =
                      (data['sourceType'] ?? '') ==
                      TrafficViolationService.sourceGift;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.orange,
                        child: Icon(
                          isGift ? Icons.card_giftcard : Icons.gavel,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        data['customerName']?.toString() ??
                            context.t('customer'),
                      ),
                      subtitle: Text(
                        '${isGift ? context.t('gift') : context.t('rental')} · ${data['car_name'] ?? context.t('cars')}',
                      ),
                      trailing: Text(
                        'EGP ${TrafficViolationService.amountOf(data).toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TrafficViolationsScreen(),
                          ),
                        );
                      },
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  static Widget _drawerItem(
    BuildContext context,
    IconData icon,
    String title,
    Widget page,
  ) {
    return ListTile(
      leading: Icon(icon, color: Colors.orange),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      onTap: () {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));
      },
    );
  }

  static Widget _bookingTile(
    String name,
    String car,
    String date,
    String status,
  ) {
    Color statusColor = Colors.orange;
    if (status.toLowerCase().contains('paid') ||
        status.toLowerCase().contains('confirmed')) {
      statusColor = Colors.green;
    } else if (status.toLowerCase().contains('cancelled') ||
        status.toLowerCase().contains('failed')) {
      statusColor = Colors.red;
    }

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.orange,
          child: Icon(Icons.person, color: Colors.white),
        ),
        title: Text(name),
        subtitle: Text('$car · $status'),
        trailing: date.isNotEmpty
            ? Text(
                date,
                style: const TextStyle(color: Colors.orange, fontSize: 12),
              )
            : Chip(
                label: Text(
                  status,
                  style: TextStyle(fontSize: 11, color: statusColor),
                ),
                backgroundColor: statusColor.withValues(alpha: 0.12),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
      ),
    );
  }
}

class DashboardCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const DashboardCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.orange, size: 32),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(title, style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}
