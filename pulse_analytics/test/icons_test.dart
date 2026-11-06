import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_analytics/widgets/tt_icons.dart';

void main() {
  testWidgets('every header icon paints without errors', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            for (final icon in TtIcon.values)
              TtIconView(icon, color: Colors.black),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
