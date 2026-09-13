import 'dart:convert';
import '../models/syllabus_topic.dart';

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

  /// Parses arbitrary syllabus text, markdown, or JSON into structured chapters and topics.
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
              topics.add(SyllabusTopic(
                id: 'topic_$i',
                title: item.trim(),
                sortOrder: i,
              ));
            } else if (item is Map) {
              final title = item['title']?.toString() ?? item['name']?.toString() ?? '';
              if (title.isNotEmpty) {
                topics.add(SyllabusTopic(
                  id: item['id']?.toString() ?? 'topic_$i',
                  title: title,
                  description: item['description']?.toString(),
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

    final rawChapters = <String, List<String>>{};
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

      // Clean topic line (strip leading bullets: -, *, •, 1., 01.)
      final cleanedTopic = line
          .replaceAll(RegExp(r'^(?:[-*•]|\d+[\.\)])\s*'), '')
          .trim();

      if (cleanedTopic.isNotEmpty) {
        rawChapters.putIfAbsent(currentChapter, () => []).add(cleanedTopic);
      }
    }

    final chapters = <ParsedChapterTopics>[];

    // If only default chapter with no topics, return empty
    rawChapters.forEach((chTitle, topicList) {
      if (topicList.isNotEmpty) {
        final topics = <SyllabusTopic>[];
        for (final t in topicList) {
          topics.add(SyllabusTopic(
            id: 'topic_${topicCounter++}',
            title: t,
            sortOrder: topics.length,
          ));
        }
        chapters.add(ParsedChapterTopics(
          chapterTitle: chTitle,
          topics: topics,
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
}
