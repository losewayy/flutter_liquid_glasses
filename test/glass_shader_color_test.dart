import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_liquid_glasses/src/glass_params.dart';

void main() {
  testWidgets('glass tint matches native Hue rather than HSV value replacement', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final program = await ui.FragmentProgram.fromAsset(
        'shaders/liquid_glass.frag',
      );
      for (final background in [
        const ui.Color(0xff206090),
        const ui.Color(0xff20e040),
        const ui.Color(0xffeeeeee),
        const ui.Color(0xff080c10),
        const ui.Color(0x80406080),
        const ui.Color(0x00000000),
      ]) {
        for (final tint in [
          const ui.Color(0xffed2040),
          const ui.Color(0xff2030ed),
          const ui.Color(0xff808080),
          const ui.Color(0x802030ed),
          const ui.Color(0x00000000),
        ]) {
          const surface = ui.Color(0x40203040);
          const rect = ui.Rect.fromLTWH(0, 0, 16, 16);
          final sourceRecorder = ui.PictureRecorder();
          ui.Canvas(sourceRecorder)
              .drawRect(rect, ui.Paint()..color = background);
          final sourcePicture = sourceRecorder.endRecording();
          final source = await sourcePicture.toImage(16, 16);
          final referenceRecorder = ui.PictureRecorder();
          final referenceCanvas = ui.Canvas(referenceRecorder);
          referenceCanvas
            ..drawRect(rect, ui.Paint()..color = background)
            ..drawRect(
              rect,
              ui.Paint()
                ..color = tint
                ..blendMode = ui.BlendMode.hue,
            )
            ..drawRect(
              rect,
              ui.Paint()..color = tint.withValues(alpha: 0.75 * tint.a),
            )
            ..drawRect(rect, ui.Paint()..color = surface);
          final referencePicture = referenceRecorder.endRecording();
          final reference = await referencePicture.toImage(16, 16);
          final shader = program.fragmentShader();
          GlassParams(
            cornerRadius: 4,
            refractionHeight: 0,
            saturation: 1,
            highlightAlpha: 0,
            tintColor: [tint.r, tint.g, tint.b, tint.a],
            surfaceColor: [surface.r, surface.g, surface.b, surface.a],
          ).bind(shader, 0, 0, 16, 16);
          shader
            ..setFloat(0, 16)
            ..setFloat(1, 16)
            ..setImageSampler(0, source);
          final outputRecorder = ui.PictureRecorder();
          ui.Canvas(outputRecorder).drawRect(rect, ui.Paint()..shader = shader);
          final outputPicture = outputRecorder.endRecording();
          final output = await outputPicture.toImage(16, 16);
          final expected = (await reference.toByteData())!;
          final actual = (await output.toByteData())!;
          final errors = [
            for (var ch = 0; ch < 4; ch++)
              (actual.getUint8((8 * 16 + 8) * 4 + ch) -
                      expected.getUint8((8 * 16 + 8) * 4 + ch))
                  .abs(),
          ];
          var invalidPremultipliedPixels = 0;
          for (var i = 0; i < actual.lengthInBytes; i += 4) {
            final alpha = actual.getUint8(i + 3);
            if (actual.getUint8(i) > alpha ||
                actual.getUint8(i + 1) > alpha ||
                actual.getUint8(i + 2) > alpha) {
              invalidPremultipliedPixels++;
            }
          }
          output.dispose();
          outputPicture.dispose();
          shader.dispose();
          reference.dispose();
          referencePicture.dispose();
          source.dispose();
          sourcePicture.dispose();
          expect(
            errors,
            everyElement(lessThanOrEqualTo(2)),
            reason:
                'background=$background tint=$tint; native Hue + surface overlay',
          );
          expect(
            invalidPremultipliedPixels,
            0,
            reason: 'Rounded AA must attenuate premultiplied RGB together with alpha.',
          );
        }
      }
    });
  });

  testWidgets('color controls precede channel-separated dispersion', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final sourceRecorder = ui.PictureRecorder();
      final sourceCanvas = ui.Canvas(sourceRecorder);
      for (var x = 0; x < 100; x++) {
        sourceCanvas.drawRect(
          ui.Rect.fromLTWH(x.toDouble(), 0, 1, 100),
          ui.Paint()
            ..color = x % 12 < 6
                ? const ui.Color(0xff00ff00)
                : const ui.Color(0xff000000),
        );
      }
      final sourcePicture = sourceRecorder.endRecording();
      final source = await sourcePicture.toImage(100, 100);
      final program = await ui.FragmentProgram.fromAsset(
        'shaders/liquid_glass.frag',
      );
      final shader = program.fragmentShader();
      const GlassParams(
        cornerRadius: 16,
        refractionHeight: 14,
        refractionAmount: -24,
        chromatic: 1.0,
        saturation: 0,
        highlightAlpha: 0,
      ).bind(shader, 0, 0, 100, 100);
      // This exercises the production shader math through Paint, not the
      // unsupported test-backend ImageFilter path. Backdrop registration and
      // Impeller behavior are separately verified by the Windows fixture.
      shader
        ..setFloat(0, 100)
        ..setFloat(1, 100)
        ..setImageSampler(0, source);
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawRect(
        const ui.Rect.fromLTWH(0, 0, 100, 100),
        ui.Paint()..shader = shader,
      );
      final picture = recorder.endRecording();
      final output = await picture.toImage(100, 100);
      final bytes = (await output.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      var separated = 0;
      for (var y = 24; y < 76; y++) {
        for (var x = 87; x < 98; x++) {
          final i = (y * 100 + x) * 4;
          final r = bytes.getUint8(i);
          final g = bytes.getUint8(i + 1);
          final b = bytes.getUint8(i + 2);
          if ((r - g).abs() > 5 || (g - b).abs() > 5) separated++;
        }
      }
      output.dispose();
      picture.dispose();
      shader.dispose();
      source.dispose();
      sourcePicture.dispose();
      expect(
        separated,
        greaterThan(30),
        reason:
            'Desaturating after dispersion erases the lens channel separation.',
      );
    });
  });
}
