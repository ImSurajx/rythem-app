import '../tables.dart';

class BeatEntity {
  final String id;
  final String chapterId;
  final String roadmapId;
  final String title;
  final String? sourceUrl;
  final int? timestampSeconds;
  final double effortWeight;
  final int sortOrder;
  final bool isCompleted;
  final DateTime? completedAt;
  final bool isMentorExtra;
  final double? matchConfidence;
  final String? syllabusTopicId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BeatEntity({
    required this.id,
    required this.chapterId,
    required this.roadmapId,
    required this.title,
    this.sourceUrl,
    this.timestampSeconds,
    this.effortWeight = 1.0,
    this.sortOrder = 0,
    this.isCompleted = false,
    this.completedAt,
    this.isMentorExtra = false,
    this.matchConfidence,
    this.syllabusTopicId,
    required this.createdAt,
    required this.updatedAt,
  });

  BeatEntity copyWith({
    String? id,
    String? chapterId,
    String? roadmapId,
    String? title,
    String? sourceUrl,
    int? timestampSeconds,
    double? effortWeight,
    int? sortOrder,
    bool? isCompleted,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    bool? isMentorExtra,
    double? matchConfidence,
    String? syllabusTopicId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BeatEntity(
      id: id ?? this.id,
      chapterId: chapterId ?? this.chapterId,
      roadmapId: roadmapId ?? this.roadmapId,
      title: title ?? this.title,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      timestampSeconds: timestampSeconds ?? this.timestampSeconds,
      effortWeight: effortWeight ?? this.effortWeight,
      sortOrder: sortOrder ?? this.sortOrder,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      isMentorExtra: isMentorExtra ?? this.isMentorExtra,
      matchConfidence: matchConfidence ?? this.matchConfidence,
      syllabusTopicId: syllabusTopicId ?? this.syllabusTopicId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      BeatColumns.id: id,
      BeatColumns.chapterId: chapterId,
      BeatColumns.roadmapId: roadmapId,
      BeatColumns.title: title,
      BeatColumns.sourceUrl: sourceUrl,
      BeatColumns.timestampSeconds: timestampSeconds,
      BeatColumns.effortWeight: effortWeight,
      BeatColumns.sortOrder: sortOrder,
      BeatColumns.isCompleted: isCompleted ? 1 : 0,
      BeatColumns.completedAt: completedAt?.toIso8601String(),
      BeatColumns.isMentorExtra: isMentorExtra ? 1 : 0,
      BeatColumns.matchConfidence: matchConfidence,
      BeatColumns.syllabusTopicId: syllabusTopicId,
      BeatColumns.createdAt: createdAt.toIso8601String(),
      BeatColumns.updatedAt: updatedAt.toIso8601String(),
    };
  }

  factory BeatEntity.fromMap(Map<String, dynamic> map) {
    return BeatEntity(
      id: map[BeatColumns.id] as String,
      chapterId: map[BeatColumns.chapterId] as String,
      roadmapId: map[BeatColumns.roadmapId] as String,
      title: map[BeatColumns.title] as String,
      sourceUrl: map[BeatColumns.sourceUrl] as String?,
      timestampSeconds: map[BeatColumns.timestampSeconds] as int?,
      effortWeight: (map[BeatColumns.effortWeight] as num?)?.toDouble() ?? 1.0,
      sortOrder: (map[BeatColumns.sortOrder] as int?) ?? 0,
      isCompleted: (map[BeatColumns.isCompleted] as int?) == 1,
      completedAt: map[BeatColumns.completedAt] != null
          ? DateTime.parse(map[BeatColumns.completedAt] as String)
          : null,
      isMentorExtra: (map[BeatColumns.isMentorExtra] as int?) == 1,
      matchConfidence: (map[BeatColumns.matchConfidence] as num?)?.toDouble(),
      syllabusTopicId: map[BeatColumns.syllabusTopicId] as String?,
      createdAt: DateTime.parse(map[BeatColumns.createdAt] as String),
      updatedAt: DateTime.parse(map[BeatColumns.updatedAt] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BeatEntity &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'BeatEntity(id: $id, title: $title, isCompleted: $isCompleted, isMentorExtra: $isMentorExtra, effortWeight: $effortWeight)';
}
