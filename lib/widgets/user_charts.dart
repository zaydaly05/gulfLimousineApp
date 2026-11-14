import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/locale_service.dart';

const _accent = Color(0xFFFF8C00);
const _primary = Color(0xFF000000);

class UserAnalyticsSection extends StatelessWidget {
  final String userId;

  const UserAnalyticsSection({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: UserBookingStatusChart(userId: userId),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: UserMonthlyBookingsChart(userId: userId),
        ),
      ],
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  static const double height = 180;

  const _ChartCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SizedBox(height: height, child: child),
        ],
      ),
    );
  }
}

class UserBookingStatusChart extends StatelessWidget {
  final String userId;

  const UserBookingStatusChart({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _ChartCard(
            title: 'Booking Status',
            child: Center(child: CircularProgressIndicator(color: _accent, strokeWidth: 2)),
          );
        }

        final counts = <String, int>{};
        for (final doc in snapshot.data?.docs ?? []) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['status'] ?? 'pending').toString().toLowerCase();
          counts[status] = (counts[status] ?? 0) + 1;
        }

        if (counts.isEmpty) {
          return const _ChartCard(
            title: 'Booking Status',
            child: _EmptyChart(message: 'No bookings'),
          );
        }

        final entries = counts.entries.toList();
        final colors = [
          _accent,
          const Color(0xFF4CAF50),
          const Color(0xFF2196F3),
          const Color(0xFFE91E63),
        ];

        return _ChartCard(
          title: context.t('status'),
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 20,
              sections: entries.asMap().entries.map((e) {
                return PieChartSectionData(
                  color: colors[e.key % colors.length],
                  value: e.value.value.toDouble(),
                  title: '${e.value.value}',
                  radius: 35,
                  titleStyle: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

class UserMonthlyBookingsChart extends StatelessWidget {
  final String userId;

  const UserMonthlyBookingsChart({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _ChartCard(
            title: 'Monthly Activity',
            child: Center(child: CircularProgressIndicator(color: _accent, strokeWidth: 2)),
          );
        }

        final monthly = _lastFourMonths(snapshot.data?.docs ?? []);
        final maxY = monthly.values.isEmpty
            ? 1.0
            : monthly.values.reduce((a, b) => a > b ? a : b).toDouble() + 1;

        return _ChartCard(
          title: context.t('trip'),
          child: monthly.values.every((v) => v == 0)
              ? const _EmptyChart(message: 'No data')
              : BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxY,
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 20,
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            if (i < 0 || i >= monthly.keys.length) return const SizedBox.shrink();
                            return Text(
                              monthly.keys.elementAt(i),
                              style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: monthly.values.toList().asMap().entries.map((e) {
                      return BarChartGroupData(
                        x: e.key,
                        barRods: [
                          BarChartRodData(
                            toY: e.value.toDouble(),
                            color: _primary,
                            width: 12,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
        );
      },
    );
  }

  Map<String, int> _lastFourMonths(List<QueryDocumentSnapshot> docs) {
    final now = DateTime.now();
    final months = <String, int>{};
    for (var i = 3; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      months[DateFormat('MMM').format(d)] = 0;
    }

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final date = _parseDate(data['createdAt']) ??
          _parseDate(data['pickupDate']) ??
          _parseDate(data['startDate']);
      if (date == null) continue;

      final key = DateFormat('MMM').format(DateTime(date.year, date.month, 1));
      if (months.containsKey(key)) {
        months[key] = months[key]! + 1;
      }
    }
    return months;
  }
}

class _EmptyChart extends StatelessWidget {
  final String message;

  const _EmptyChart({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
      ),
    );
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
