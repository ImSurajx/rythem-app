import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rythem_app/core/theme/colors.dart';
import 'package:rythem_app/core/widgets/ambient_aurora_canvas.dart';
import 'package:rythem_app/core/widgets/glass_progress_bar.dart';

void main() {
  group('Colorful Liquid Glass & Theme Engine Tests', () {
    test('ThemePalette enum contains 4 curated palettes with preview colors', () {
      expect(ThemePalette.values.length, 4);
      expect(ThemePalette.aurora.displayName, 'Aurora');
      expect(ThemePalette.cobalt.displayName, 'Cobalt');
      expect(ThemePalette.solar.displayName, 'Solar');
      expect(ThemePalette.studio.displayName, 'Studio');

      for (final palette in ThemePalette.values) {
        expect(palette.previewColors.length, greaterThanOrEqualTo(2));
      }
    });

    test('RythemColors.resolve generates correct accents and ambient orbs', () {
      final auroraDark = RythemColors.resolve(isDark: true, palette: ThemePalette.aurora);
      expect(auroraDark.palette, ThemePalette.aurora);
      expect(auroraDark.accentPrimary, const Color(0xFF00E5FF)); // Electric Cyan
      expect(auroraDark.ambientOrbs.length, 3);

      final cobaltDark = RythemColors.resolve(isDark: true, palette: ThemePalette.cobalt);
      expect(cobaltDark.palette, ThemePalette.cobalt);
      expect(cobaltDark.accentPrimary, const Color(0xFF00B4D8)); // Ice Blue
      expect(cobaltDark.ambientOrbs.length, 3);

      final solarDark = RythemColors.resolve(isDark: true, palette: ThemePalette.solar);
      expect(solarDark.palette, ThemePalette.solar);
      expect(solarDark.accentPrimary, const Color(0xFFFF9500)); // Solar Amber
      expect(solarDark.ambientOrbs.length, 3);

      final studioDark = RythemColors.resolve(isDark: true, palette: ThemePalette.studio);
      expect(studioDark.palette, ThemePalette.studio);
      expect(studioDark.accentPrimary, const Color(0xFFFFFFFF)); // Specular White
    });

    test('TrackAccents maps subject domains to signature luminous colors', () {
      expect(TrackAccents.getAccent('Complete Python Mastery'), TrackAccents.emerald);
      expect(TrackAccents.getAccent('Django Backend Engineering'), TrackAccents.emerald);
      expect(TrackAccents.getAccent('DSA in C++ & Algorithms'), TrackAccents.cyan);
      expect(TrackAccents.getAccent('Data Structures & Logic'), TrackAccents.cyan);
      expect(TrackAccents.getAccent('Deep Learning & AI Fundamentals'), TrackAccents.violet);
      expect(TrackAccents.getAccent('Machine Learning with PyTorch'), TrackAccents.violet);
      expect(TrackAccents.getAccent('Flutter & Dart Cross-Platform'), TrackAccents.coral);
      expect(TrackAccents.getAccent('Modern UI Frontend React'), TrackAccents.coral);
      expect(TrackAccents.getAccent('Distributed System Design'), TrackAccents.amber);
      expect(TrackAccents.getAccent('Database Architecture & SQL'), TrackAccents.amber);
    });

    testWidgets('AmbientAuroraCanvas paints without error under widget hierarchy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AmbientAuroraCanvas(
              palette: ThemePalette.aurora,
              child: Container(
                key: const Key('aurora_child'),
                child: const Text('Luminous Flow'),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(AmbientAuroraCanvas), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.byKey(const Key('aurora_child')), findsOneWidget);
      expect(find.text('Luminous Flow'), findsOneWidget);
    });

    testWidgets('RythemThemeScope propagates palette colors to descendants', (tester) async {
      final customColors = RythemColors.resolve(isDark: true, palette: ThemePalette.solar);

      late RythemThemeColors resolvedInChild;

      await tester.pumpWidget(
        RythemThemeScope(
          colors: customColors,
          child: Builder(
            builder: (context) {
              resolvedInChild = RythemColors.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(resolvedInChild.palette, ThemePalette.solar);
      expect(resolvedInChild.accentPrimary, const Color(0xFFFF9500));
    });

    testWidgets('GlassProgressBar renders with custom track accent and glow', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: GlassProgressBar(
                  progress: 0.65,
                  customColor: TrackAccents.emerald,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(GlassProgressBar), findsOneWidget);
      expect(find.byType(AnimatedContainer), findsOneWidget);
    });
  });
}
