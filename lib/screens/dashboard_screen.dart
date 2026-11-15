import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'cars_screen.dart';
import 'contact_screen.dart';
import 'my_bookings_screen.dart';
import 'profile_screen.dart';
import 'chatbot_screen.dart';
import 'favorites_screen.dart';
import '../services/auth_navigation.dart';
import '../services/favorites_service.dart';
import 'notifications_inbox_screen.dart';
import 'my_traffic_violations_screen.dart';
import 'complete_profile_screen.dart';
import '../widgets/admin_charts.dart';
import '../services/notification_service.dart';
import '../services/traffic_violation_service.dart';
import '../widgets/language_picker.dart';
import '../widgets/user_charts.dart';
import '../l10n/locale_service.dart';
import '../theme/app_theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  String _userName = 'Guest';
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    NotificationService.instance.initialize();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final DocumentSnapshot<Map<String, dynamic>> doc;
    try {
      doc = await _firestore.collection('users').doc(user.uid).get();
    } catch (e) {
      debugPrint('Could not load profile: $e');
      return;
    }
    if (!mounted) return;

    final data = doc.data();
    if (data != null) {
      final role = data['role']?.toString() ?? 'user';
      final completed = data['profile_completed'] == true;

      if (role != 'admin' && !completed) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const CompleteProfileScreen()),
          (route) => false,
        );
        return;
      }
    }

    setState(() {
      _userName = doc.data()?['name'] ?? user.displayName ?? context.t('guest');
      _profileImageUrl = doc.data()?['profile_image_url'] as String?;
    });
  }

  Future<void> _openProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
    await _loadUserData();
  }

  Future<void> _openChatbot() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatbotScreen(userName: _userName)),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t('logout')),
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
    if (confirm != true || !mounted) return;
    await AuthNavigation.signOut(context);
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final email = user?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('appName')),
        actions: [
          // AppBar is black, so use the light-on-dark variant.
          const LanguageToggleButton(dark: true),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationsInboxScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: _openProfile,
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openChatbot,
        backgroundColor: AppTheme.accent,
        icon: const Icon(Icons.smart_toy_outlined),
        label: Text(context.t('askAi')),
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            88 + MediaQuery.viewPaddingOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _WelcomeBanner(name: _userName, email: email),
              const SizedBox(height: 24),
              Text(
                context.t('overview'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _UserStatsSection(
                firestore: _firestore,
                userId: user?.uid,
                email: email,
                onCarsTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CarsScreen()),
                ),
                onBookingsTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyBookingsScreen()),
                ),
              ),
              const SizedBox(height: 20),
              _UserTrafficTicketsBanner(userId: user?.uid, email: email),
              const SizedBox(height: 24),
              Text(
                context.t('bookings'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (user != null) UserAnalyticsSection(userId: user.uid),
              const SizedBox(height: 24),
              Text(
                context.t('recentActivity'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _RecentBookings(userId: user?.uid, email: email),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF000000), Color(0xFF1A1A1A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: UserAccountsDrawerHeader(
              margin: EdgeInsets.zero,
              accountName: Text(
                _userName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
              accountEmail: Text(
                _auth.currentUser?.email ?? '',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
              currentAccountPicture: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.accent, width: 2),
                ),
                child: CircleAvatar(
                  backgroundColor: const Color(0xFF333333),
                  backgroundImage:
                      _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                      ? CachedNetworkImageProvider(_profileImageUrl!)
                      : null,
                  child: _profileImageUrl == null || _profileImageUrl!.isEmpty
                      ? const Icon(Icons.person, color: Colors.white, size: 36)
                      : null,
                ),
              ),
              decoration: const BoxDecoration(color: Colors.transparent),
            ),
          ),
          const SizedBox(height: 8),
          const LanguagePicker(dark: false),
          const Divider(),
          _drawerTile(
            Icons.home,
            context.t('home'),
            () => Navigator.pop(context),
          ),
          _drawerTile(Icons.directions_car, context.t('browseCars'), () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CarsScreen()),
            );
          }),
          _drawerTile(Icons.calendar_today, context.t('myBookings'), () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyBookingsScreen()),
            );
          }),
          _drawerTile(Icons.gavel, context.t('trafficTickets'), () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const MyTrafficViolationsScreen(),
              ),
            );
          }),
          _drawerTile(Icons.favorite, context.t('favorites'), () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FavoritesScreen()),
            );
          }),
          _drawerTile(
            Icons.notifications_outlined,
            context.t('notifications'),
            () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationsInboxScreen(),
                ),
              );
            },
          ),
          _drawerTile(Icons.person, context.t('profile'), () {
            Navigator.pop(context);
            _openProfile();
          }),
          _drawerTile(Icons.phone, context.t('contact'), () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ContactScreen()),
            );
          }),
          _drawerTile(Icons.smart_toy_outlined, context.t('aiAssistant'), () {
            Navigator.pop(context);
            _openChatbot();
          }),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: Text(context.t('logout')),
            onTap: () {
              Navigator.pop(context);
              _logout();
            },
          ),
        ],
      ),
    );
  }

  ListTile _drawerTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.accent),
      title: Text(title),
      onTap: onTap,
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  final String name;
  final String email;

  const _WelcomeBanner({required this.name, required this.email});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF000000), Color(0xFF333333)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('welcomeBack'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (email.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              email,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            context.t('luxuryTagline'),
            style: const TextStyle(color: AppTheme.accent, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Bookings of the signed-in user, by uid when known, otherwise by email.
Stream<QuerySnapshot<Map<String, dynamic>>>? _userBookingsQuery(
  FirebaseFirestore firestore,
  String? userId,
  String email,
) {
  final bookings = firestore.collection('bookings');
  if (userId != null) {
    return bookings.where('userId', isEqualTo: userId).snapshots();
  }
  if (email.isNotEmpty) {
    return bookings.where('user_email', isEqualTo: email).snapshots();
  }
  return null;
}

class _UserStatsSection extends StatefulWidget {
  final FirebaseFirestore firestore;
  final String? userId;
  final String email;
  final VoidCallback onCarsTap;
  final VoidCallback onBookingsTap;

  const _UserStatsSection({
    required this.firestore,
    required this.userId,
    required this.email,
    required this.onCarsTap,
    required this.onBookingsTap,
  });

  @override
  State<_UserStatsSection> createState() => _UserStatsSectionState();
}

class _UserStatsSectionState extends State<_UserStatsSection> {
  // Created once so parent rebuilds (refresh, locale change) don't
  // re-subscribe and flash empty values.
  late final _bookingsStream = _userBookingsQuery(
    widget.firestore,
    widget.userId,
    widget.email,
  );
  late final _favoritesStream = FavoritesService.watchFavoriteIds();
  late final _availableCarsStream = widget.firestore
      .collection('cars')
      .where('available', isEqualTo: true)
      .snapshots();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _bookingsStream,
      builder: (context, bookingsSnapshot) {
        final bookingsCount = bookingsSnapshot.data?.docs.length ?? 0;

        return StreamBuilder<Set<String>>(
          stream: _favoritesStream,
          builder: (context, favsSnapshot) {
            final favoritesCount = favsSnapshot.data?.length ?? 0;

            return StreamBuilder<QuerySnapshot>(
              stream: _availableCarsStream,
              builder: (context, carsSnapshot) {
                final availableCarsCount = carsSnapshot.data?.docs.length ?? 0;

                return Row(
                  children: [
                    Expanded(
                      child: _UserStatCard(
                        title: context.t('bookings'),
                        icon: Icons.calendar_today_outlined,
                        accent: AppTheme.accent,
                        value: '$bookingsCount',
                        onTap: widget.onBookingsTap,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _UserStatCard(
                        title: context.t('favorites'),
                        icon: Icons.favorite_outline,
                        accent: Colors.black,
                        value: '$favoritesCount',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const FavoritesScreen(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _UserStatCard(
                        title: context.t('cars'),
                        icon: Icons.directions_car_outlined,
                        accent: AppTheme.accent,
                        value: '$availableCarsCount',
                        onTap: widget.onCarsTap,
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _UserStatCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final String value;
  final VoidCallback? onTap;

  const _UserStatCard({
    required this.title,
    required this.icon,
    required this.accent,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        elevation: onTap != null ? 2 : 0,
        shadowColor: accent.withValues(alpha: 0.2),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: accent.withValues(alpha: 0.1),
          highlightColor: accent.withValues(alpha: 0.05),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: onTap != null
                    ? accent.withValues(alpha: 0.4)
                    : Colors.grey.shade200,
                width: onTap != null ? 1.5 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Icon(icon, color: accent, size: 24),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(height: 8),
                  Icon(
                    Icons.arrow_forward,
                    size: 14,
                    color: accent.withValues(alpha: 0.5),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentBookings extends StatefulWidget {
  final String? userId;
  final String email;

  const _RecentBookings({required this.userId, required this.email});

  @override
  State<_RecentBookings> createState() => _RecentBookingsState();
}

class _RecentBookingsState extends State<_RecentBookings> {
  late final _stream = _userBookingsQuery(
    FirebaseFirestore.instance,
    widget.userId,
    widget.email,
  );

  /// Newest first. Sorted on the client because a server-side orderBy on
  /// another field would need a composite index.
  static List<QueryDocumentSnapshot<Map<String, dynamic>>> _latest(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final sorted = [...docs]
      ..sort((a, b) {
        final aDate = a.data()['createdAt'];
        final bDate = b.data()['createdAt'];
        if (aDate is! Timestamp && bDate is! Timestamp) return 0;
        if (aDate is! Timestamp) return 1;
        if (bDate is! Timestamp) return -1;
        return bDate.compareTo(aDate);
      });
    return sorted.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    final stream = _stream;
    if (stream == null) {
      return Text(context.t('signInBookings'));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = _latest(snapshot.data?.docs ?? []);
        if (docs.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              context.t('noRecentBookings'),
              textAlign: TextAlign.center,
            ),
          );
        }

        return Column(
          children: docs.map((doc) {
            final data = doc.data();
            final rawStatus = (data['status'] ?? 'pending').toString();
            final statusLabel = context.t(rawStatus.toLowerCase());
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.accent.withValues(alpha: 0.2),
                  child: const Icon(
                    Icons.directions_car,
                    color: AppTheme.accent,
                  ),
                ),
                title: Text(resolveBookingCar(data)),
                subtitle: Text(
                  '${resolveBookingDateLabel(data)} · $statusLabel',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyBookingsScreen()),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _UserTrafficTicketsBanner extends StatelessWidget {
  final String? userId;
  final String email;

  const _UserTrafficTicketsBanner({required this.userId, required this.email});

  @override
  Widget build(BuildContext context) {
    if (userId == null && email.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: userId == null
          ? Stream<QuerySnapshot<Map<String, dynamic>>>.empty()
          : TrafficViolationService.watchForUserId(userId!),
      builder: (context, byId) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: email.isEmpty
              ? Stream<QuerySnapshot<Map<String, dynamic>>>.empty()
              : TrafficViolationService.watchForEmail(email),
          builder: (context, byEmail) {
            final merged = <String, Map<String, dynamic>>{};
            for (final doc in [...?byId.data?.docs, ...?byEmail.data?.docs]) {
              merged[doc.id] = doc.data();
            }
            final pending = merged.values.where((data) {
              return TrafficViolationService.isPending(data) &&
                  (data['payment_method'] ?? '') != 'cash';
            }).toList();
            if (pending.isEmpty) return const SizedBox.shrink();
            final total = pending.fold<double>(
              0,
              (value, data) => value + TrafficViolationService.amountOf(data),
            );

            return Material(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MyTrafficViolationsScreen(),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.gavel, color: AppTheme.accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.t('trafficDue'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              context.t(
                                'unpaidTickets',
                                args: {
                                  'count': '${pending.length}',
                                  'amount': total.toStringAsFixed(0),
                                },
                              ),
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        context.t('pay'),
                        style: const TextStyle(
                          color: AppTheme.accent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppTheme.accent),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
