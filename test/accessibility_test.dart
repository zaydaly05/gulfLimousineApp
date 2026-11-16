import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gulflimousine_travel/theme/app_theme.dart';
import 'package:gulflimousine_travel/widgets/payment_method_tile.dart';
import 'package:gulflimousine_travel/widgets/status_pill.dart';

/// Flutter's accessibility guidelines on shared widgets: tap targets big
/// enough, tappable things labelled, text readable against its background.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: ListView(children: [child])),
      ),
    );
  }

  testWidgets(
    'PaymentMethodTile meets tap-target, label and contrast guidelines',
    (tester) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        PaymentMethodTile(
          icon: Icons.credit_card,
          title: 'Credit / Debit Card',
          subtitle: 'Pay when you collect the car',
          onTap: () {},
        ),
      );

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    },
  );

  testWidgets('StatusPill text is readable and announced', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, const StatusPill(label: 'CANCELLED', color: Colors.red));

    expect(find.bySemanticsLabel('CANCELLED'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('icon buttons expose their tooltip to screen readers', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      IconButton(
        tooltip: 'Delete',
        icon: const Icon(Icons.delete),
        onPressed: () {},
      ),
    );

    expect(find.byTooltip('Delete'), findsOneWidget);
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
}
