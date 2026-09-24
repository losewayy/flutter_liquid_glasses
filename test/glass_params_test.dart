import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_liquid_glasses/src/glass_params.dart';

void main() {
  test('all material lengths scale together; color and angles do not', () {
    const p = GlassParams(
      cornerRadius: 25,
      refractionHeight: 14,
      refractionAmount: -20,
      highlightStroke: 1,
      highlightBlur: 0.25,
      shadowOffsetX: -2,
      shadowOffsetY: 2,
      shadowBlur: 8,
      glowX: 40,
      glowY: 80,
      glowRadius: 90,
      glowAlpha: 0.15,
      chromatic: 1.0,
    );
    for (final dpr in [1.0, 1.25, 1.75, 2.0]) {
      final actual = p.toPhysical(dpr);
      final lengths = [
        actual.cornerRadius, actual.refractionHeight, actual.refractionAmount,
        actual.highlightStroke, actual.highlightBlur, actual.shadowOffsetX,
        actual.shadowOffsetY, actual.shadowBlur,
        actual.glowX, actual.glowY, actual.glowRadius,
      ];
      expect(lengths, [
        for (final value in [25, 14, -20, 1, 0.25, -2, 2, 8, 40, 80, 90])
          value * dpr,
      ]);
      expect(actual.highlightAngle, p.highlightAngle);
      expect(actual.highlightAlpha, p.highlightAlpha);
      expect(actual.saturation, p.saturation);
      expect(actual.colorFilter, p.colorFilter);
      expect(actual.glowAlpha, p.glowAlpha);
      expect(actual.chromatic, 1.0);
    }
  });
}
