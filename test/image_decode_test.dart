import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gulflimousine_travel/utils/image_decode.dart';

void main() {
  testWidgets('decode width scales logical size by the screen pixel ratio', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(1080, 2400); // 360 x 800 logical
    addTearDown(tester.view.reset);

    late int thumb;
    late int screen;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          thumb = decodeWidth(context, 56);
          screen = screenDecodeWidth(context);
          return const SizedBox();
        },
      ),
    );

    expect(thumb, 168);
    expect(screen, 1080);
  });
}
