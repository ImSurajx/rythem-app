import '../models/extracted_beat.dart';
import '../models/extracted_chapter.dart';
import '../models/extracted_resource.dart';
import 'effort_weight_calculator.dart';

class ChapterClusterer {
  ChapterClusterer._();

  /// Clusters a flat list of raw resource items into 4-8 structured chapters.
  /// 
  /// Ground truths enforced:
  /// - 100% video coverage: Zero items are dropped or skipped.
  /// - Strict mentor sequence: Chronological item order is preserved (0..N).
  /// - Balanced distribution: Outputs 1-8 chapters depending on playlist length.
  static List<ExtractedChapter> cluster(
    List<RawResourceItem> items, {
    String? roadmapTitle,
  }) {
    if (items.isEmpty) {
      return [];
    }

    // 1. Convert all items to ExtractedBeat with effort weights
    final allBeats = <ExtractedBeat>[];
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final weight = EffortWeightCalculator.calculate(item.durationSeconds);
      allBeats.add(ExtractedBeat(
        title: item.title,
        sourceUrl: item.sourceUrl,
        timestampSeconds: item.timestampSeconds,
        durationSeconds: item.durationSeconds,
        effortWeight: weight,
        sortOrder: i,
        thumbnailUrl: item.thumbnailUrl,
      ));
    }

    final count = allBeats.length;

    // Small playlist (<= 4 items): single chapter
    if (count <= 4) {
      return [
        ExtractedChapter(
          title: roadmapTitle != null ? '$roadmapTitle • Core' : 'Core Curriculum',
          sortOrder: 0,
          beats: allBeats,
        ),
      ];
    }

    // Attempt to detect explicit section / module / chapter headers in video titles
    final sectionBoundaries = _detectSectionBoundaries(allBeats);

    if (sectionBoundaries.length > 1 && sectionBoundaries.length <= 8) {
      return _buildChaptersFromBoundaries(allBeats, sectionBoundaries);
    }

    // Fallback to balanced thematic chunking (4-8 chapters)
    return _buildBalancedChapters(allBeats, roadmapTitle: roadmapTitle);
  }

  /// Detects explicit section markers like "Module 1", "Part 1", "Section 2", "Chapter 3", "Day 5".
  static List<int> _detectSectionBoundaries(List<ExtractedBeat> beats) {
    final boundaries = <int>[0]; // Always start with index 0
    final moduleRegex = RegExp(
      r'(?:module|section|chapter|part|phase|stage|day)\s*(\d+)',
      caseSensitive: false,
    );

    int lastFoundNumber = -1;

    for (int i = 0; i < beats.length; i++) {
      final title = beats[i].title;
      final match = moduleRegex.firstMatch(title);
      if (match != null) {
        final numStr = match.group(1);
        final num = int.tryParse(numStr ?? '') ?? -1;
        if (num > 0 && num != lastFoundNumber && i > boundaries.last) {
          // Avoid tiny 1-beat chapters unless intentional
          if (i - boundaries.last >= 2) {
            boundaries.add(i);
            lastFoundNumber = num;
          }
        }
      }
    }

    return boundaries;
  }

  static List<ExtractedChapter> _buildChaptersFromBoundaries(
    List<ExtractedBeat> beats,
    List<int> boundaries,
  ) {
    final chapters = <ExtractedChapter>[];

    for (int b = 0; b < boundaries.length; b++) {
      final start = boundaries[b];
      final end = (b + 1 < boundaries.length) ? boundaries[b + 1] : beats.length;
      final chapterBeats = beats.sublist(start, end);

      final title = _synthesizeChapterTitle(chapterBeats, chapterIndex: b + 1);
      chapters.add(ExtractedChapter(
        title: title,
        sortOrder: b,
        beats: chapterBeats,
      ));
    }

    return chapters;
  }

  static List<ExtractedChapter> _buildBalancedChapters(
    List<ExtractedBeat> beats, {
    String? roadmapTitle,
  }) {
    final count = beats.length;
    // Determine target chapter count (typically 4 to 8)
    int targetChapters;
    if (count <= 8) {
      targetChapters = 2;
    } else if (count <= 16) {
      targetChapters = 3;
    } else if (count <= 28) {
      targetChapters = 4;
    } else if (count <= 42) {
      targetChapters = 5;
    } else if (count <= 60) {
      targetChapters = 6;
    } else {
      targetChapters = 7;
    }

    final itemsPerChapter = (count / targetChapters).ceil();
    final chapters = <ExtractedChapter>[];

    for (int c = 0; c < targetChapters; c++) {
      final start = c * itemsPerChapter;
      if (start >= count) break;
      final end = (start + itemsPerChapter < count) ? start + itemsPerChapter : count;

      final chapterBeats = beats.sublist(start, end);
      final title = _synthesizeChapterTitle(chapterBeats, chapterIndex: c + 1);

      chapters.add(ExtractedChapter(
        title: title,
        sortOrder: c,
        beats: chapterBeats,
      ));
    }

    return chapters;
  }

  /// Synthesizes a readable chapter title from common prefix or theme keywords.
  static String _synthesizeChapterTitle(
    List<ExtractedBeat> beats, {
    required int chapterIndex,
  }) {
    if (beats.isEmpty) {
      return 'Chapter $chapterIndex';
    }

    final firstTitle = beats.first.title;

    // Check for "Module X: <Name>" or "Section X - <Name>"
    final prefixMatch = RegExp(
      r'^(?:module|section|chapter|part)\s*\d+[\s\:\-\|]+(?<name>[^,\-\|]+)',
      caseSensitive: false,
    ).firstMatch(firstTitle);

    if (prefixMatch != null) {
      final name = prefixMatch.namedGroup('name')?.trim();
      if (name != null && name.length >= 3) {
        return 'Chapter $chapterIndex: $name';
      }
    }

    // Clean common leading numeric tags like "01 - " or "1. " or "#1 "
    final cleanLead = firstTitle
        .replaceAll(RegExp(r'^(?:#?\d+[\.\:\-\s]+)+'), '')
        .trim();

    // Take the main segment before separators like '|', '-', ':'
    final segment = cleanLead.split(RegExp(r'[\:\-\|]')).first.trim();
    if (segment.isNotEmpty && segment.length >= 4 && segment.length <= 35) {
      return 'Chapter $chapterIndex: $segment';
    }

    // Default sequential naming
    final thematicNames = [
      'Foundations & Core Setup',
      'Fundamental Mechanics',
      'Intermediate Concepts',
      'Advanced Implementations',
      'Deep Dive & Architecture',
      'Applied Patterns & Optimization',
      'Capstone & Mastery',
    ];

    final theme = (chapterIndex - 1 < thematicNames.length)
        ? thematicNames[chapterIndex - 1]
        : 'Milestone Phase $chapterIndex';

    return 'Chapter $chapterIndex: $theme';
  }
}
