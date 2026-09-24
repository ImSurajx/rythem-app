import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rythem_app/core/database/models/beat_entity.dart';
import 'package:rythem_app/core/theme/colors.dart';
import 'package:rythem_app/features/explore/widgets/chapter_accordion.dart';

void main() {
  group('Timestamp and Duration Formatter Tests', () {
    test('formats seconds into M:SS and H:MM:SS', () {
      expect(formatTimestampSeconds(0), '0:00');
      expect(formatTimestampSeconds(59), '0:59');
      expect(formatTimestampSeconds(60), '1:00');
      expect(formatTimestampSeconds(125), '2:05');
      expect(formatTimestampSeconds(865), '14:25');
      expect(formatTimestampSeconds(3600), '1:00:00');
      expect(formatTimestampSeconds(3725), '1:02:05');
      expect(formatTimestampSeconds(-5), '0:00');
    });

    test('formats effort weight into human duration', () {
      expect(formatDurationFromEffort(0.5), '30 min');
      expect(formatDurationFromEffort(1.0), '1h');
      expect(formatDurationFromEffort(1.5), '1h 30m');
      expect(formatDurationFromEffort(2.25), '2h 15m');
      expect(formatDurationFromEffort(0.0), '');
    });
  });

  group('BeatTile Widget UI Tests', () {
    final testBeatWithTimestamp = BeatEntity(
      id: 'beat_test_1',
      chapterId: 'ch_1',
      roadmapId: 'rm_1',
      title: 'Full Stack Flutter with Advanced State Management and In-Depth Architecture',
      sourceUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      timestampSeconds: 865, // 14:25
      effortWeight: 1.5,
      isMentorExtra: true,
      totalParts: 3,
      completedParts: 1,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    testWidgets('renders full title, mentor extra badge, video badge, and timestamp chip', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BeatTile(
              beat: testBeatWithTimestamp,
              themeColors: RythemColors.darkThemeColors,
              isDark: true,
              isDelayed: true,
              onToggle: (_) {},
              onOpenResource: () {},
              onSplit: () {},
              onToggleDelay: () {},
              onToggleFocus: () {},
              onMarkForRevision: () {},
            ),
          ),
        ),
      );

      // Verify Mentor Extra badge and Delayed badge render cleanly
      expect(find.text('MENTOR EXTRA'), findsOneWidget);
      expect(find.text('DELAYED • LATER'), findsOneWidget);

      // Verify title renders
      expect(find.text('Full Stack Flutter with Advanced State Management and In-Depth Architecture'), findsOneWidget);

      // Verify video chip renders
      expect(find.text('video'), findsOneWidget);

      // Verify timestamp 14:25 renders
      expect(find.text('14:25'), findsOneWidget);

      // Verify duration renders
      expect(find.textContaining('1h 30m'), findsOneWidget);

      // Verify multi-part indicator
      expect(find.text('part 1/3'), findsOneWidget);

      // Verify Options popup menu button renders
      expect(find.byType(PopupMenuButton<String>), findsOneWidget);

      // Tap options menu to open it
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      // Verify popup menu items exist
      expect(find.text('Edit Parts (1/3)'), findsOneWidget);
      expect(find.text('Resume into Focus'), findsOneWidget);
      expect(find.text('Add to Today\'s Focus'), findsOneWidget);
    });
  });
}
