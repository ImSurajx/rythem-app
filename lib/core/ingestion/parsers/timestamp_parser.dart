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
  // 01:23, 1:23, 01:23:45, 1:23:45, [01:23], (01:23), 00:00 - Introduction
  static final RegExp _timestampPattern = RegExp(
    r'(?:^|[\s\[\(\-])(?:(?<hours>\d{1,2}):)?(?<minutes>\d{1,2}):(?<seconds>\d{2})(?:[\]\)\-\s]*)',
    multiLine: true,
  );

  /// Parses video description text for structured timestamps and chapter titles.
  /// If [totalVideoDurationSeconds] is provided, it calculates each segment's duration.
  /// Requires at least [minSegments] (default 2) to prevent false positives on single timestamp mentions.
  static List<ParsedTimestampSegment> parseDescription(
    String description, {
    int totalVideoDurationSeconds = 0,
    int minSegments = 2,
  }) {
    final lines = description.split('\n');
    final rawEntries = <({int startSeconds, String title})>[];

    for (final line in lines) {
      final trimmed = line.trim();
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
        title = title.replaceAll(RegExp(r'^[•\*\-\:\.\|\–\—\s]+'), '').trim();
        title = title.replaceAll(RegExp(r'^\d+[\.\)\-\:\s]+'), '').trim();
        // Clean trailing separators, brackets, and parentheses
        title = title.replaceAll(RegExp(r'[-\:\.\|\–\—\s\[\]\(\)]+$'), '').trim();

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
      final nextStart = (i + 1 < deduplicated.length)
          ? deduplicated[i + 1].startSeconds
          : (totalVideoDurationSeconds > current.startSeconds
              ? totalVideoDurationSeconds
              : current.startSeconds + 600); // 10 min default fallback

      final duration = (nextStart - current.startSeconds).clamp(60, 86400);

      segments.add(ParsedTimestampSegment(
        title: current.title,
        startSeconds: current.startSeconds,
        durationSeconds: duration,
      ));
    }

    return segments;
  }
}
