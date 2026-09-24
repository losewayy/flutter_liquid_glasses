import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_liquid_glasses/flutter_liquid_glasses.dart';

// Temporary probe: which component produces a non-finite SemanticsNode rect?
void main() {
  final cases = <String, Widget>{
    'surface': const GlassSurface(child: SizedBox(width: 100, height: 40)),
    'press': const GlassPressSurface(
      params: GlassParams(),
      child: SizedBox(width: 100, height: 40),
    ),
    'swipe': const LiquidSwipeSurface(child: SizedBox(width: 100, height: 40)),
    'segmented': SizedBox(
      width: 300,
      child: GlassSegmentedControl<int>(
        segments: const [
          GlassSegment(value: 0, label: 'L'),
          GlassSegment(value: 1, label: 'C'),
          GlassSegment(value: 2, label: 'R'),
        ],
        selected: 1,
        onChanged: (_) {},
      ),
    ),
    'menuButton': GlassMenuButton<String>(
      tooltip: 'm',
      onSelected: (_) {},
      itemBuilder: () => const [GlassMenuItem(value: 'a', child: Text('a'))],
      child: const Text('Menu'),
    ),
    'select': GlassSelect<String>(
      value: 'a',
      options: const [(value: 'a', label: 'A')],
      onChanged: (_) {},
    ),
  };

  for (final entry in cases.entries) {
    testWidgets('semantics probe: ${entry.key}', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        GlassTheme(
          data: const GlassThemeData(),
          child: MaterialApp(
            home: Scaffold(body: Center(child: entry.value)),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      handle.dispose();
    });
  }
}
