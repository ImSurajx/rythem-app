class ParsedTimestampSegment {
  final String title;
  final int startSeconds;
  final int durationSeconds;

  const ParsedTimestampSegment({
    required this.title,
    required this.startSeconds,
    required this.durationSeconds,
  });

  @override
  String toString() =>
      'ParsedTimestampSegment(start: ${startSeconds}s, dur: ${durationSeconds}s, title: $title)';
}

class TimestampParser {
  TimestampParser._();

  // Matches timestamps like:
  // 01:23, 1:23, 01:23:45, 1:23:45, [01:23], (01:23), 00:00 - Introduction, Intro - 00:00
  static final RegExp _timestampPattern = RegExp(
    r'(?:^|[\s\[\(\-\*_•|~])(?:(?<hours>\d{1,2}):)?(?<minutes>\d{1,2}):(?<seconds>\d{2})(?:[\]\)\-\s\*_•|~]*)',
    multiLine: true,
  );

  /// Splits text into lines, handling both newline-delimited timestamps and inline lists.
  static List<String> _extractLines(String text) {
    final rawLines = text.split('\n');
    final result = <String>[];
    for (final line in rawLines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      // If multiple timestamps appear on a single line separated by delimiters (e.g. •, |, ~)
      if ((trimmed.contains('•') || trimmed.contains('|') || trimmed.contains('~') || trimmed.contains(' - ')) &&
          _timestampPattern.allMatches(trimmed).length >= 2) {
        final parts = trimmed.split(RegExp(r'\s*[•|~]\s+|\s{3,}'));
        result.addAll(parts.map((p) => p.trim()).where((p) => p.isNotEmpty));
      } else {
        result.add(trimmed);
      }
    }
    return result;
  }

  /// Parses video description or comment text for structured timestamps and chapter titles.
  /// If [totalVideoDurationSeconds] is provided, it calculates each segment's duration.
  /// Requires at least [minSegments] (default 2) to prevent false positives on single timestamp mentions.
  static List<ParsedTimestampSegment> parseDescription(
    String description, {
    int totalVideoDurationSeconds = 0,
    int minSegments = 2,
  }) {
    final lines = _extractLines(description);
    final rawEntries = <({int startSeconds, String title})>[];

    for (final trimmed in lines) {
      if (trimmed.isEmpty) continue;

      final match = _timestampPattern.firstMatch(trimmed);
      if (match != null) {
        final hoursStr = match.namedGroup('hours');
        final minutesStr = match.namedGroup('minutes') ?? '0';
        final secondsStr = match.namedGroup('seconds') ?? '0';

        final hours = hoursStr != null ? int.tryParse(hoursStr) ?? 0 : 0;
        final minutes = int.tryParse(minutesStr) ?? 0;
        final seconds = int.tryParse(secondsStr) ?? 0;

        final totalSeconds = (hours * 3600) + (minutes * 60) + seconds;

        // Extract title by stripping the timestamp part
        String title = trimmed.replaceFirst(match.group(0)!, '').trim();
        // Clean leading bracketed numbers e.g. [1], [02], (3)
        title = title.replaceAll(RegExp(r'^[\[\(]\s*\d+\s*[\]\)]\s*'), '').trim();
        // Clean leading separators like '-', ':', '|', '.', '–', bullets, and numbering
        title = title.replaceAll(RegExp(r'^[•\*\-\:\.\|\–\—\s_~]+'), '').trim();
        title = title.replaceAll(RegExp(r'^\d+[\.\)\-\:\s]+'), '').trim();
        // Clean trailing separators, preserving balanced parentheses in titles
        title = title.replaceAll(RegExp(r'[•\*\-\:\.\|\–\—\s_~]+$'), '').trim();
        title = title.replaceAll(RegExp(r'[\[\(]+$'), '').trim();

        if (title.isEmpty) {
          title = 'Beat at ${match.group(0)!.trim()}';
        }

        rawEntries.add((startSeconds: totalSeconds, title: title));
      }
    }

    if (rawEntries.length < minSegments) {
      return [];
    }

    // Sort by chronological start timestamp
    rawEntries.sort((a, b) => a.startSeconds.compareTo(b.startSeconds));

    // Deduplicate entries with identical start timestamps (preserve first descriptive title)
    final deduplicated = <({int startSeconds, String title})>[];
    for (final entry in rawEntries) {
      if (deduplicated.isEmpty || deduplicated.last.startSeconds != entry.startSeconds) {
        deduplicated.add(entry);
      }
    }

    final segments = <ParsedTimestampSegment>[];
    for (int i = 0; i < deduplicated.length; i++) {
      final current = deduplicated[i];
      // Zero-drop boundary guarantee: if early intro begins <= 90s, clamp to 0
      final startSec = (i == 0 && current.startSeconds <= 90) ? 0 : current.startSeconds;
      final nextStart = (i + 1 < deduplicated.length)
          ? deduplicated[i + 1].startSeconds
          : (totalVideoDurationSeconds > startSec
              ? totalVideoDurationSeconds
              : startSec + 600); // 10 min default fallback

      final duration = (nextStart - startSec).clamp(60, 86400);

      segments.add(ParsedTimestampSegment(
        title: current.title,
        startSeconds: startSec,
        durationSeconds: duration,
      ));
    }

    return segments;
  }

  /// Parses multiple community comments and returns the highest quality chapter breakdown.
  /// Prioritizes comments with the most structured, chronological coverage.
  static List<ParsedTimestampSegment> parseComments(
    List<String> commentTexts, {
    int totalVideoDurationSeconds = 0,
    int minSegments = 2,
  }) {
    List<ParsedTimestampSegment> bestSegments = [];

    for (final comment in commentTexts) {
      if (comment.trim().isEmpty) continue;
      final segments = parseDescription(
        comment,
        totalVideoDurationSeconds: totalVideoDurationSeconds,
        minSegments: minSegments,
      );

      // Select candidate with the most comprehensive breakdown
      if (segments.length > bestSegments.length) {
        bestSegments = segments;
      }
    }

    return bestSegments;
  }
}
