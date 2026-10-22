import 'dart:convert';
import '../models/syllabus_topic.dart';
import 'effort_weight_calculator.dart';

class ParsedChapterTopics {
  final String chapterTitle;
  final List<SyllabusTopic> topics;

  const ParsedChapterTopics({
    required this.chapterTitle,
    required this.topics,
  });
}

class ParsedSyllabus {
  final String title;
  final List<ParsedChapterTopics> chapters;

  const ParsedSyllabus({
    required this.title,
    required this.chapters,
  });

  List<SyllabusTopic> get allTopics {
    return [for (final ch in chapters) ...ch.topics];
  }
}

class SyllabusParser {
  SyllabusParser._();

  /// Parses arbitrary syllabus text, markdown, or JSON into structured chapters and topics
  /// with extracted beat/effort points.
  static ParsedSyllabus parse(String input, {String defaultTitle = 'Imported Syllabus'}) {
    final cleanInput = input.trim();
    if (cleanInput.isEmpty) {
      return ParsedSyllabus(
        title: defaultTitle,
        chapters: [
          const ParsedChapterTopics(
            chapterTitle: 'Core Curriculum',
            topics: [],
          ),
        ],
      );
    }

    // Try parsing as JSON first
    if (cleanInput.startsWith('{') || cleanInput.startsWith('[')) {
      try {
        final decoded = jsonDecode(cleanInput);
        if (decoded is List) {
          final topics = <SyllabusTopic>[];
          for (int i = 0; i < decoded.length; i++) {
            final item = decoded[i];
            if (item is String && item.trim().isNotEmpty) {
              final parsed = parseTopicLine(item);
              topics.add(SyllabusTopic(
                id: 'topic_$i',
                title: parsed.title,
                effortPoints: parsed.effortPoints,
                sortOrder: i,
              ));
            } else if (item is Map) {
              final rawTitle = item['title']?.toString() ?? item['name']?.toString() ?? '';
              if (rawTitle.isNotEmpty) {
                final explicitEffort = (item['effort_points'] as num?)?.toDouble() ??
                    (item['effort_weight'] as num?)?.toDouble() ??
                    (item['effort'] as num?)?.toDouble() ??
                    (item['points'] as num?)?.toDouble() ??
                    (item['beats'] as num?)?.toDouble();

                final parsedTitle = parseTopicLine(rawTitle);
                final finalEffort = explicitEffort != null
                    ? double.parse(explicitEffort
                        .clamp(EffortWeightCalculator.minWeight, EffortWeightCalculator.maxWeight)
                        .toStringAsFixed(1))
                    : parsedTitle.effortPoints;

                topics.add(SyllabusTopic(
                  id: item['id']?.toString() ?? 'topic_$i',
                  title: parsedTitle.title,
                  description: item['description']?.toString(),
                  effortPoints: finalEffort,
                  sortOrder: i,
                ));
              }
            }
          }
          if (topics.isNotEmpty) {
            return ParsedSyllabus(
              title: defaultTitle,
              chapters: [
                ParsedChapterTopics(chapterTitle: 'Core Curriculum', topics: topics),
              ],
            );
          }
        }
      } catch (_) {
        // Fall back to line-based parsing
      }
    }

    // Line-based parsing
    final lines = cleanInput.split(RegExp(r'\r?\n'));
    final chapterRegex = RegExp(
      r'^(?:#+\s*|(?:module|chapter|unit|section|part|phase)\s*\d+[\s\:\-\|]+)(?<title>.+)$',
      caseSensitive: false,
    );

    final rawChapters = <String, List<SyllabusTopic>>{};
    String currentChapter = 'Core Foundations';
    rawChapters[currentChapter] = [];

    int topicCounter = 0;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      // Check if line represents a chapter / module header
      final headerMatch = chapterRegex.firstMatch(line);
      final isMarkdownHeader = line.startsWith('#') || line.startsWith('==');

      if (headerMatch != null || isMarkdownHeader) {
        final name = headerMatch?.namedGroup('title')?.trim() ??
            line.replaceAll(RegExp(r'^#+\s*'), '').trim();
        if (name.isNotEmpty) {
          currentChapter = name;
          rawChapters.putIfAbsent(currentChapter, () => []);
          continue;
        }
      }

      // Parse topic line extracting both cleaned title and effort points
      final parsed = parseTopicLine(line);
      if (parsed.title.isNotEmpty) {
        final topic = SyllabusTopic(
          id: 'topic_${topicCounter++}',
          title: parsed.title,
          effortPoints: parsed.effortPoints,
          sortOrder: rawChapters[currentChapter]?.length ?? 0,
        );
        rawChapters.putIfAbsent(currentChapter, () => []).add(topic);
      }
    }

    final chapters = <ParsedChapterTopics>[];

    // Build structured chapters
    rawChapters.forEach((chTitle, topicList) {
      if (topicList.isNotEmpty) {
        chapters.add(ParsedChapterTopics(
          chapterTitle: chTitle,
          topics: topicList,
        ));
      }
    });

    if (chapters.isEmpty) {
      chapters.add(const ParsedChapterTopics(
        chapterTitle: 'Core Curriculum',
        topics: [],
      ));
    }

    return ParsedSyllabus(
      title: defaultTitle,
      chapters: chapters,
    );
  }

  /// Parses an individual topic line to separate the topic title from any
  /// user-defined effort / beat points notation.
  /// 
  /// Supported patterns:
  /// - Brackets: `[2.5]`, `[2.5 beats]`, `[2.5 pts]`, `[effort: 2.5]`
  /// - Parentheses: `(2.5)`, `(2.5 beats)`, `(2 pts)`, `(effort: 2.5)`
  /// - Separators: `| 2.5 beats`, `| 2.5`, `: 2.5 beats`, `- 2.5 beats`
  /// - Prefix: `[2.5 beats] Topic`, `(2.5) Topic`
  static ({String title, double? effortPoints}) parseTopicLine(String rawLine) {
    var line = rawLine.replaceAll(RegExp(r'^(?:[-*•]|\d+[\.\)])\s*'), '').trim();
    if (line.isEmpty) {
      return (title: '', effortPoints: null);
    }

    double? extractedEffort;

    // 1. Check for leading bracket/parenthesis prefix:
    // e.g. "[2.5 beats] Topic", "[2.5] Topic", "(effort: 3) Topic"
    final prefixRegex = RegExp(
      r'^[\[\(]\s*(?:(?:effort|beats?|pts?|points?)\s*[:=]?\s*)?(\d+(?:\.\d+)?)\s*(?:beats?|pts?|points?|effort)?\s*[\]\)]\s*[:\-]?\s*',
      caseSensitive: false,
    );
    final prefixMatch = prefixRegex.firstMatch(line);
    if (prefixMatch != null) {
      final numStr = prefixMatch.group(1);
      if (numStr != null) {
        final val = double.tryParse(numStr);
        if (val != null && val >= EffortWeightCalculator.minWeight && val <= EffortWeightCalculator.maxWeight) {
          extractedEffort = double.parse(val.clamp(EffortWeightCalculator.minWeight, EffortWeightCalculator.maxWeight).toStringAsFixed(1));
          line = line.substring(prefixMatch.end).trim();
        }
      }
    }

    // 2. Check for trailing bracket/parenthesis:
    // e.g. "Topic [2.5]", "Topic (3 beats)", "Topic [effort: 2.0]"
    final trailingBracketRegex = RegExp(
      r'[\s\-]*[\[\(]\s*(?:(?:effort|beats?|pts?|points?)\s*[:=]?\s*)?(\d+(?:\.\d+)?)\s*(?:beats?|pts?|points?|effort)?\s*[\]\)]\s*$',
      caseSensitive: false,
    );
    final trailingMatch = trailingBracketRegex.firstMatch(line);
    if (trailingMatch != null) {
      final numStr = trailingMatch.group(1);
      if (numStr != null) {
        final val = double.tryParse(numStr);
        final fullMatch = trailingMatch.group(0)?.toLowerCase() ?? '';
        final hasKeyword = fullMatch.contains('beat') ||
            fullMatch.contains('pt') ||
            fullMatch.contains('point') ||
            fullMatch.contains('effort');
        // Only parse if explicit keyword exists OR number is within standard effort range (0.1..50.0)
        if (val != null && (hasKeyword || (val >= EffortWeightCalculator.minWeight && val <= EffortWeightCalculator.maxWeight))) {
          extractedEffort ??= double.parse(val.clamp(EffortWeightCalculator.minWeight, EffortWeightCalculator.maxWeight).toStringAsFixed(1));
          line = line.substring(0, trailingMatch.start).trim();
        }
      }
    }

    // 3. Check for trailing pipe/dash/colon separator:
    // e.g. "Topic | 2.5 beats", "Topic | 2.5", "Topic - 3 beats", "Topic: 2.5 beats"
    final separatorRegex = RegExp(
      r'(?:\s*\|\s*|\s*:\s*|\s+--?\s*)(?:(?:effort|beats?|pts?|points?)\s*[:=]?\s*)?(\d+(?:\.\d+)?)\s*(?:beats?|pts?|points?|effort)?\s*$',
      caseSensitive: false,
    );
    final sepMatch = separatorRegex.firstMatch(line);
    if (sepMatch != null) {
      final numStr = sepMatch.group(1);
      final fullMatch = sepMatch.group(0)?.toLowerCase() ?? '';
      final hasKeyword = fullMatch.contains('beat') ||
          fullMatch.contains('pt') ||
          fullMatch.contains('point') ||
          fullMatch.contains('effort');
      final isPipe = fullMatch.contains('|');
      if (numStr != null) {
        final val = double.tryParse(numStr);
        if (val != null && (hasKeyword || isPipe) && val >= EffortWeightCalculator.minWeight && val <= EffortWeightCalculator.maxWeight) {
          extractedEffort ??= double.parse(val.clamp(EffortWeightCalculator.minWeight, EffortWeightCalculator.maxWeight).toStringAsFixed(1));
          line = line.substring(0, sepMatch.start).trim();
        }
      }
    }

    // Clean any trailing or leading punctuation leftover from stripping
    line = line.replaceAll(RegExp(r'^[\:\-\|\,\s]+|[\:\-\|\,\s]+$'), '').trim();

    return (
      title: line,
      effortPoints: extractedEffort,
    );
  }
}
