import 'package:flutter/material.dart';

import '../screens/video_viewer_screen.dart';

/// "Pickup Video" / "Return Video" chips that open a booking's condition
/// videos. Renders only the chips for videos the booking actually has.
class ConditionVideoChips extends StatelessWidget {
  final Map<String, dynamic> booking;
  final String carName;

  const ConditionVideoChips({
    super.key,
    required this.booking,
    required this.carName,
  });

  void _open(BuildContext context, String field, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoViewerScreen(
          url: booking[field]['url'],
          title: '$title - $carName',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPickup = booking['pickupVideo'] != null;
    final hasReturn = booking['returnVideo'] != null;
    return Row(
      children: [
        if (hasPickup)
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ActionChip(
              label: const Text('Pickup Video'),
              avatar: const Icon(Icons.play_circle_fill, size: 16),
              onPressed: () =>
                  _open(context, 'pickupVideo', 'Pickup Condition'),
            ),
          ),
        if (hasReturn)
          ActionChip(
            label: const Text('Return Video'),
            avatar: const Icon(Icons.play_circle_fill, size: 16),
            onPressed: () => _open(context, 'returnVideo', 'Return Condition'),
          ),
      ],
    );
  }
}
