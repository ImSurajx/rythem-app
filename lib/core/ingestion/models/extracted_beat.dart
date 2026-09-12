class ExtractedBeat {
  final String title;
  final String? sourceUrl;
  final int? timestampSeconds;
  final int durationSeconds;
  final double effortWeight;
  final int sortOrder;
  final bool isMentorExtra;
  final double? matchConfidence;
  final String? syllabusTopicId;
  final String? thumbnailUrl;

  const ExtractedBeat({
    required this.title,
    this.sourceUrl,
    this.timestampSeconds,
    required this.durationSeconds,
    required this.effortWeight,
    required this.sortOrder,
    this.isMentorExtra = false,
    this.matchConfidence,
    this.syllabusTopicId,
    this.thumbnailUrl,
  });

  ExtractedBeat copyWith({
    String? title,
    String? sourceUrl,
    int? timestampSeconds,
    int? durationSeconds,
    double? effortWeight,
    int? sortOrder,
    bool? isMentorExtra,
    double? matchConfidence,
    String? syllabusTopicId,
    String? thumbnailUrl,
  }) {
    return ExtractedBeat(
      title: title ?? this.title,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      timestampSeconds: timestampSeconds ?? this.timestampSeconds,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      effortWeight: effortWeight ?? this.effortWeight,
      sortOrder: sortOrder ?? this.sortOrder,
      isMentorExtra: isMentorExtra ?? this.isMentorExtra,
      matchConfidence: matchConfidence ?? this.matchConfidence,
      syllabusTopicId: syllabusTopicId ?? this.syllabusTopicId,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    );
  }

  @override
  String toString() =>
      'ExtractedBeat(title: $title, order: $sortOrder, weight: $effortWeight, mentorExtra: $isMentorExtra)';
}
