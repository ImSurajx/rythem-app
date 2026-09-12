import '../tables.dart';

class ChapterEntity {
  final String id;
  final String roadmapId;
  final String title;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChapterEntity({
    required this.id,
    required this.roadmapId,
    required this.title,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  ChapterEntity copyWith({
    String? id,
    String? roadmapId,
    String? title,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChapterEntity(
      id: id ?? this.id,
      roadmapId: roadmapId ?? this.roadmapId,
      title: title ?? this.title,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      ChapterColumns.id: id,
      ChapterColumns.roadmapId: roadmapId,
      ChapterColumns.title: title,
      ChapterColumns.sortOrder: sortOrder,
      ChapterColumns.createdAt: createdAt.toIso8601String(),
      ChapterColumns.updatedAt: updatedAt.toIso8601String(),
    };
  }

  factory ChapterEntity.fromMap(Map<String, dynamic> map) {
    return ChapterEntity(
      id: map[ChapterColumns.id] as String,
      roadmapId: map[ChapterColumns.roadmapId] as String,
      title: map[ChapterColumns.title] as String,
      sortOrder: (map[ChapterColumns.sortOrder] as int?) ?? 0,
      createdAt: DateTime.parse(map[ChapterColumns.createdAt] as String),
      updatedAt: DateTime.parse(map[ChapterColumns.updatedAt] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChapterEntity &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'ChapterEntity(id: $id, roadmapId: $roadmapId, title: $title, sortOrder: $sortOrder)';
}
