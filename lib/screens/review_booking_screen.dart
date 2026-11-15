import 'package:flutter/material.dart';

import '../services/review_service.dart';
import '../theme/app_theme.dart';

class ReviewBookingScreen extends StatefulWidget {
  final String bookingId;
  final Map<String, dynamic> bookingData;

  const ReviewBookingScreen({
    super.key,
    required this.bookingId,
    required this.bookingData,
  });

  @override
  State<ReviewBookingScreen> createState() => _ReviewBookingScreenState();
}

class _ReviewBookingScreenState extends State<ReviewBookingScreen> {
  int _rating = 5;
  final _comment = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ReviewService.submitReview(
        bookingId: widget.bookingId,
        booking: widget.bookingData,
        rating: _rating,
        comment: _comment.text,
      );

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Thanks for your review!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final car =
        (widget.bookingData['carName'] ??
                widget.bookingData['car_name'] ??
                'Car')
            .toString();

    return Scaffold(
      appBar: AppBar(title: const Text('Rate your trip')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              car,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('How was your experience?'),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (i) {
                final star = i + 1;
                return IconButton(
                  onPressed: () => setState(() => _rating = star),
                  icon: Icon(
                    star <= _rating ? Icons.star : Icons.star_border,
                    color: AppTheme.accent,
                    size: 36,
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _comment,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Comment (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit review'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
