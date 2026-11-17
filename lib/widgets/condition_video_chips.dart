import 'package:flutter/material.dart';

import '../screens/video_viewer_screen.dart';
import '../l10n/locale_service.dart';

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
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: ActionChip(
              label: Text(tr('pickupVideo')),
              avatar: const Icon(Icons.play_circle_fill, size: 16),
              onPressed: () =>
                  _open(context, 'pickupVideo', tr('pickupCondition')),
            ),
          ),
        if (hasReturn)
          ActionChip(
            label: Text(tr('returnVideo')),
            avatar: const Icon(Icons.play_circle_fill, size: 16),
            onPressed: () =>
                _open(context, 'returnVideo', tr('returnCondition')),
          ),
      ],
    );
  }
}
