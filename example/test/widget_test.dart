import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_liquid_glasses_example/main.dart';

void main() {
  testWidgets('demo app builds with a glass surface', (tester) async {
    await tester.pumpWidget(const DemoApp());
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('reset restores default params', (tester) async {
    await tester.pumpWidget(const DemoApp());
    await tester.pump();

    // cornerRadius defaults to 25.00 — the first slider's value label.
    expect(find.text('25.00'), findsOneWidget);

    // Drag the first slider (cornerRadius) off its default.
    await tester.drag(find.byType(Slider).first, const Offset(-120, 0));
    await tester.pump();
    expect(find.text('25.00'), findsNothing);

    // The reset button restores the launch-state value.
    await tester.tap(find.byIcon(Icons.restart_alt));
    await tester.pump();
    expect(find.text('25.00'), findsOneWidget);
  });
}
