import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_liquid_glasses/flutter_liquid_glasses.dart';

Widget _app({required int selected, required ValueChanged<int> onChanged}) {
  return GlassTheme(
    data: const GlassThemeData(),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: 300,
          child: GlassSegmentedControl<int>(
            segments: const [
              GlassSegment(value: 0, label: 'L'),
              GlassSegment(value: 1, label: 'C'),
              GlassSegment(value: 2, label: 'R'),
            ],
            selected: selected,
            onChanged: onChanged,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('tap on a segment fires onChanged with its value', (
    tester,
  ) async {
    int? selected;
    await tester.pumpWidget(
      _app(selected: 1, onChanged: (v) => selected = v),
    );
    final rect = tester.getRect(find.byType(GlassSegmentedControl<int>));
    await tester.tapAt(rect.centerRight - const Offset(10, 0));
    expect(selected, 2);
  });

  testWidgets('horizontal drag ends on the nearest segment', (tester) async {
    int? selected;
    await tester.pumpWidget(
      _app(selected: 0, onChanged: (v) => selected = v),
    );
    final rect = tester.getRect(find.byType(GlassSegmentedControl<int>));
    final gesture = await tester.startGesture(rect.centerLeft + const Offset(10, 0));
    await gesture.moveBy(const Offset(210, 0));
    await gesture.up();
    expect(selected, 2);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('press inflates the thumb past the track on both axes', (
    tester,
  ) async {
    await tester.pumpWidget(_app(selected: 0, onChanged: (_) {}));
    final rect = tester.getRect(find.byType(GlassSegmentedControl<int>));
    // Hold a press (no release) so pressProgress saturates.
    final gesture = await tester.startGesture(rect.center);
    // Hold until the springs fully settle — deterministic geometry.
    await tester.pumpAndSettle();

    final control = tester.widget<Stack>(
      find.descendant(
        of: find.byType(GlassSegmentedControl<int>),
        matching: find.byType(Stack),
      ),
    );
    // Stack order: track, labels, thumb — thumb is topmost so its lens
    // refracts the label beneath it.
    expect(control.children.length, 3);

    // The thumb is the last Positioned → find its GlassSurface rect.
    final surfaces = find.descendant(
      of: find.byType(GlassSegmentedControl<int>),
      matching: find.byType(GlassSurface),
    );
    expect(surfaces, findsNWidgets(2)); // track glass + thumb glass
    final thumbRect = tester.getRect(surfaces.last);
    final trackRect = tester.getRect(surfaces.first);

    // Pressed thumb = (78/64)·trackHeight → protrudes above and below.
    expect(thumbRect.top, lessThan(trackRect.top));
    expect(thumbRect.bottom, greaterThan(trackRect.bottom));
    expect(thumbRect.height, greaterThan(trackRect.height));
    // Two-axis: width also grows past its segment slot.
    final segW = (rect.width - 6) / 3;
    expect(thumbRect.width, greaterThan(segW * 1.2));
    // Finite geometry — no NaN poisoning.
    expect(thumbRect.top.isFinite, isTrue);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('thumb does not inherit the track press scale', (tester) async {
    await tester.pumpWidget(_app(selected: 0, onChanged: (_) {}));
    final rect = tester.getRect(find.byType(GlassSegmentedControl<int>));
    final gesture = await tester.startGesture(rect.center);
    await tester.pumpAndSettle();

    // The container scale (1+16/W·p) wraps track + labels. The thumb's own
    // scale Transform is its nearest Transform ancestor — verify no ancestor
    // Transform sits between the control and the thumb's own scale.
    final surfaces = find.descendant(
      of: find.byType(GlassSegmentedControl<int>),
      matching: find.byType(GlassSurface),
    );
    final thumbSurface = surfaces.last;
    final thumbRect = tester.getRect(thumbSurface);
    // If the container scale reached the thumb, height would exceed
    // 1.39·1.08·30 ≈ 45px on the 36px track. Thumb height = 78/64·36 ≈ 43.9.
    expect(thumbRect.height, lessThan(44.5));
    expect(thumbRect.height, greaterThan(40));

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('reduced motion snaps without crashing', (tester) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures.allOn;
    int? selected;
    await tester.pumpWidget(
      _app(selected: 0, onChanged: (v) => selected = v),
    );
    final rect = tester.getRect(find.byType(GlassSegmentedControl<int>));
    await tester.tapAt(rect.centerRight - const Offset(10, 0));
    await tester.pump();
    expect(selected, 2);
    addTearDown(() {
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue();
    });
  });
}
