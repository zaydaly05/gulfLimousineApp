import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../utils/booking_fields.dart';
import '../theme/app_theme.dart';

export '../utils/booking_fields.dart';
export 'status_colors.dart';

/// Month labels for the charts' x axes ("Jan", "Feb", ...).
final _monthFormat = DateFormat('MMM');

class AdminAnalyticsSection extends StatelessWidget {
  final FirebaseFirestore firestore;

  const AdminAnalyticsSection({super.key, required this.firestore});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Analytics',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        RepaintBoundary(child: RevenueTrendChart(firestore: firestore)),
        const SizedBox(height: 16),
        // Side-by-side cards share one height. Safe with IntrinsicHeight
        // because each chart sits in a fixed-height box.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: RepaintBoundary(
                  child: BookingStatusChart(firestore: firestore),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: RepaintBoundary(
                  child: FleetAvailabilityChart(firestore: firestore),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        RepaintBoundary(child: MonthlyBookingsChart(firestore: firestore)),
      ],
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final double height;

  const _ChartCard({
    required this.title,
    this.subtitle,
    required this.child,
    this.height = 220,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(height: height, child: child),
        ],
      ),
    );
  }
}

class RevenueTrendChart extends StatelessWidget {
  final FirebaseFirestore firestore;

  const RevenueTrendChart({super.key, required this.firestore});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: firestore.collection('payments').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _ChartCard(
            title: 'Revenue (Last 6 Months)',
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.accent),
            ),
          );
        }

        final monthly = _lastSixMonthsRevenue(snapshot.data?.docs ?? []);

        return _ChartCard(
          title: 'Revenue (Last 6 Months)',
          subtitle:
              'Total: EGP ${monthly.values.fold<double>(0, (a, b) => a + b).toStringAsFixed(0)}',
          height: 240,
          child: monthly.values.every((v) => v == 0)
              ? const _EmptyChart(message: 'No payment data yet')
              : LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) =>
                          FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, _) => Text(
                            value >= 1000
                                ? '${(value / 1000).toStringAsFixed(0)}k'
                                : value.toInt().toString(),
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            if (i < 0 || i >= monthly.keys.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                monthly.keys.elementAt(i),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: (monthly.length - 1).toDouble(),
                    lineBarsData: [
                      LineChartBarData(
                        spots: monthly.values
                            .toList()
                            .asMap()
                            .entries
                            .map((e) => FlSpot(e.key.toDouble(), e.value))
                            .toList(),
                        isCurved: true,
                        color: AppTheme.accent,
                        barWidth: 3,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: AppTheme.accent.withValues(alpha: 0.15),
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Map<String, double> _lastSixMonthsRevenue(List<QueryDocumentSnapshot> docs) {
    final now = DateTime.now();
    final months = <String, double>{};
    for (var i = 5; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      months[_monthFormat.format(d)] = 0;
    }

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final date = parseFirestoreDate(data['payment_date']);
      if (date == null) continue;

      final key = _monthFormat.format(DateTime(date.year, date.month, 1));
      if (months.containsKey(key)) {
        months[key] = months[key]! + (data['amount'] ?? 0).toDouble();
      }
    }
    return months;
  }
}

class BookingStatusChart extends StatelessWidget {
  final FirebaseFirestore firestore;

  const BookingStatusChart({super.key, required this.firestore});

  static const _colors = [
    AppTheme.accent,
    Color(0xFF4CAF50),
    Color(0xFF2196F3),
    Color(0xFFE91E63),
    Color(0xFF9C27B0),
    Color(0xFF607D8B),
  ];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: firestore.collection('bookings').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _ChartCard(
            title: 'Bookings by Status',
            height: 200,
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.accent),
            ),
          );
        }

        final counts = <String, int>{};
        for (final doc in snapshot.data?.docs ?? []) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['status'] ?? 'unknown').toString().toLowerCase();
          counts[status] = (counts[status] ?? 0) + 1;
        }

        if (counts.isEmpty) {
          return const _ChartCard(
            title: 'Bookings by Status',
            height: 200,
            child: _EmptyChart(message: 'No bookings'),
          );
        }

        final entries = counts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return _ChartCard(
          title: 'Bookings by Status',
          height: 200,
          child: Column(
            children: [
              Expanded(
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 32,
                    sections: entries.asMap().entries.map((e) {
                      final total = counts.values.fold<int>(0, (a, b) => a + b);
                      final pct = total > 0
                          ? (e.value.value / total * 100)
                          : 0.0;
                      return PieChartSectionData(
                        color: _colors[e.key % _colors.length],
                        value: e.value.value.toDouble(),
                        title: '${pct.toStringAsFixed(0)}%',
                        radius: 42,
                        titleStyle: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              _StatusLegend(
                items: entries
                    .asMap()
                    .entries
                    .map(
                      (e) => (
                        e.value.key,
                        e.value.value,
                        _colors[e.key % _colors.length],
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class FleetAvailabilityChart extends StatelessWidget {
  final FirebaseFirestore firestore;

  const FleetAvailabilityChart({super.key, required this.firestore});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: firestore.collection('cars').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _ChartCard(
            title: 'Fleet Availability',
            height: 200,
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.accent),
            ),
          );
        }

        var available = 0;
        var unavailable = 0;
        for (final doc in snapshot.data?.docs ?? []) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['available'] == true) {
            available++;
          } else {
            unavailable++;
          }
        }

        if (available + unavailable == 0) {
          return const _ChartCard(
            title: 'Fleet Availability',
            height: 200,
            child: _EmptyChart(message: 'No cars in fleet'),
          );
        }

        return _ChartCard(
          title: 'Fleet Availability',
          subtitle: '$available available · $unavailable unavailable',
          height: 200,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 36,
              sections: [
                PieChartSectionData(
                  color: const Color(0xFF4CAF50),
                  value: available.toDouble(),
                  title: '$available',
                  radius: 48,
                  titleStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                PieChartSectionData(
                  color: Colors.grey.shade400,
                  value: unavailable.toDouble(),
                  title: unavailable > 0 ? '$unavailable' : '',
                  radius: 48,
                  titleStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class MonthlyBookingsChart extends StatelessWidget {
  final FirebaseFirestore firestore;

  const MonthlyBookingsChart({super.key, required this.firestore});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: firestore.collection('bookings').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _ChartCard(
            title: 'Bookings per Month',
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.accent),
            ),
          );
        }

        final monthly = _lastSixMonthsBookings(snapshot.data?.docs ?? []);
        final maxY = monthly.values.isEmpty
            ? 1.0
            : monthly.values.reduce((a, b) => a > b ? a : b).toDouble() + 1;

        return _ChartCard(
          title: 'Bookings per Month',
          height: 220,
          child: monthly.values.every((v) => v == 0)
              ? const _EmptyChart(message: 'No bookings in the last 6 months')
              : BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxY,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) =>
                          FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (value, _) => Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            if (i < 0 || i >= monthly.keys.length) {
                              return const SizedBox.shrink();
                            }
                            return Text(
                              monthly.keys.elementAt(i),
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                              ),
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
                            color: e.key.isEven
                                ? AppTheme.accent
                                : AppTheme.primary,
                            width: 18,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
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

  Map<String, int> _lastSixMonthsBookings(List<QueryDocumentSnapshot> docs) {
    final now = DateTime.now();
    final months = <String, int>{};
    for (var i = 5; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      months[_monthFormat.format(d)] = 0;
    }

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final date =
          parseFirestoreDate(data['createdAt']) ??
          parseFirestoreDate(data['pickupDate']) ??
          parseFirestoreDate(data['startDate']);
      if (date == null) continue;

      final key = _monthFormat.format(DateTime(date.year, date.month, 1));
      if (months.containsKey(key)) {
        months[key] = months[key]! + 1;
      }
    }
    return months;
  }
}

class _StatusLegend extends StatelessWidget {
  final List<(String label, int count, Color color)> items;

  const _StatusLegend({required this.items});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: items.map((item) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: item.$3, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(
              '${item.$1} (${item.$2})',
              style: TextStyle(fontSize: 9, color: Colors.grey.shade700),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  final String message;

  const _EmptyChart({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.bar_chart, size: 40, color: Colors.grey),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
