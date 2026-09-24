import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_liquid_glasses/flutter_liquid_glasses.dart';

void main() {
  testWidgets('GlassMenuButton tap opens menu items', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: GlassMenuButton<String>(
            itemBuilder: () => const [
              GlassMenuItem(value: 'a', height: 30, child: Text('Alpha')),
              GlassMenuItem(value: 'b', height: 30, child: Text('Beta')),
            ],
            onSelected: (v) {},
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text('菜单'),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.tap(find.text('菜单'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.text('Alpha'), findsOneWidget);
  });
}
