class IngestionResult {
  final String roadmapId;
  final String roadmapTitle;
  final int chaptersCount;
  final int beatsCount;
  final double totalEffort;
  final int mentorExtraCount;
  final int unconfirmedMatchesCount;
  final List<String> chapterTitles;

  const IngestionResult({
    required this.roadmapId,
    required this.roadmapTitle,
    required this.chaptersCount,
    required this.beatsCount,
    required this.totalEffort,
    required this.mentorExtraCount,
    required this.unconfirmedMatchesCount,
    required this.chapterTitles,
  });

  @override
  String toString() =>
      'IngestionResult(roadmap: $roadmapTitle, chapters: $chaptersCount, beats: $beatsCount, extras: $mentorExtraCount)';
}
