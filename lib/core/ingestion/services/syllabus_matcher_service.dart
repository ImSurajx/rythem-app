import '../models/extracted_beat.dart';
import '../models/extracted_chapter.dart';
import '../models/syllabus_topic.dart';

class MatchResult {
  final ExtractedBeat beat;
  final String? matchedTopicId;
  final double? confidence;
  final bool isMentorExtra;

  const MatchResult({
    required this.beat,
    this.matchedTopicId,
    this.confidence,
    required this.isMentorExtra,
  });
}

class SyllabusMatcherService {
  /// Confidence threshold above which a match is considered confirmed
  static const double highConfidenceThreshold = 0.70;

  /// Minimum confidence threshold to propose a match (below this is mentor_extra)
  static const double ambiguousConfidenceThreshold = 0.40;

  static const Set<String> _stopWords = {
    'the', 'and', 'for', 'with', 'from', 'into', 'about', 'over', 'after',
    'how', 'what', 'why', 'part', 'chapter', 'module', 'lesson', 'lecture',
    'video', 'tutorial', 'course', 'guide', 'basics', 'introduction', 'intro',
    'an', 'a', 'in', 'on', 'at', 'to', 'of', 'by', 'is', 'it', 'or',
  };

  /// Aligns extracted chapters & beats against a syllabus topic list.
  /// 
  /// Ground truths strictly enforced:
  /// - Mentor sequence is never reordered.
  /// - Unmatched beats stay in place and are tagged [isMentorExtra: true].
  /// - Matches carry confidence score (high vs ambiguous).
  List<ExtractedChapter> alignCurriculum({
    required List<ExtractedChapter> chapters,
    required List<SyllabusTopic> syllabus,
  }) {
    if (syllabus.isEmpty) {
      return chapters;
    }

    final updatedChapters = <ExtractedChapter>[];

    for (final chapter in chapters) {
      final updatedBeats = <ExtractedBeat>[];

      for (final beat in chapter.beats) {
        final match = _findBestTopicMatch(beat, syllabus);

        if (match != null && match.confidence >= ambiguousConfidenceThreshold) {
          updatedBeats.add(beat.copyWith(
            syllabusTopicId: match.topic.id,
            matchConfidence: match.confidence,
            isMentorExtra: false,
          ));
        } else {
          // Unmatched mentor topic kept in chronological position, tagged mentor extra
          updatedBeats.add(beat.copyWith(
            isMentorExtra: true,
            matchConfidence: null,
            syllabusTopicId: null,
          ));
        }
      }

      updatedChapters.add(chapter.copyWith(beats: updatedBeats));
    }

    return updatedChapters;
  }

  /// Finds the best matching topic from the syllabus for a given beat.
  ({SyllabusTopic topic, double confidence})? _findBestTopicMatch(
    ExtractedBeat beat,
    List<SyllabusTopic> syllabus,
  ) {
    ({SyllabusTopic topic, double confidence})? best;

    for (final topic in syllabus) {
      final score = calculateSimilarity(beat.title, topic.title);
      if (best == null || score > best.confidence) {
        best = (topic: topic, confidence: score);
      }
    }

    return best;
  }

  /// Computes a normalized similarity score (0.0 to 1.0) between a beat title and a syllabus topic.
  double calculateSimilarity(String beatTitle, String topicTitle) {
    final cleanBeat = _normalize(beatTitle);
    final cleanTopic = _normalize(topicTitle);

    if (cleanBeat.isEmpty || cleanTopic.isEmpty) {
      return 0.0;
    }

    // Exact match
    if (cleanBeat == cleanTopic) {
      return 1.0;
    }

    // Substring containment
    if (cleanBeat.contains(cleanTopic)) {
      return 0.95;
    }
    if (cleanTopic.contains(cleanBeat)) {
      return 0.85;
    }

    // Word token overlap (Jaccard coefficient with keyword boost)
    final beatTokens = _tokenize(cleanBeat);
    final topicTokens = _tokenize(cleanTopic);

    if (beatTokens.isEmpty || topicTokens.isEmpty) {
      return 0.0;
    }

    final intersection = beatTokens.intersection(topicTokens);
    if (intersection.isEmpty) {
      return 0.0;
    }

    final union = beatTokens.union(topicTokens);
    final jaccard = intersection.length / union.length;

    // Recall score: fraction of topic words covered by the beat
    final recall = intersection.length / topicTokens.length;

    // Weighted blend favoring topic coverage
    final finalScore = (jaccard * 0.4) + (recall * 0.6);
    return double.parse(finalScore.clamp(0.0, 1.0).toStringAsFixed(2));
  }

  String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Set<String> _tokenize(String text) {
    return text
        .split(' ')
        .where((t) => t.length > 1 && !_stopWords.contains(t))
        .toSet();
  }
}
