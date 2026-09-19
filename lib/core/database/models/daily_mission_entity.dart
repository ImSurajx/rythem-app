import '../tables.dart';

class DailyMissionEntity {
  final String id;
  final String roadmapId;
  final String date; // YYYY-MM-DD
  final String beatId;
  final int sortIndex;
  final DateTime createdAt;

  const DailyMissionEntity({
    required this.id,
    required this.roadmapId,
    required this.date,
    required this.beatId,
    required this.sortIndex,
    required this.createdAt,
  });

  DailyMissionEntity copyWith({
    String? id,
    String? roadmapId,
    String? date,
    String? beatId,
    int? sortIndex,
    DateTime? createdAt,
  }) {
    return DailyMissionEntity(
      id: id ?? this.id,
      roadmapId: roadmapId ?? this.roadmapId,
      date: date ?? this.date,
      beatId: beatId ?? this.beatId,
      sortIndex: sortIndex ?? this.sortIndex,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      DailyMissionColumns.id: id,
      DailyMissionColumns.roadmapId: roadmapId,
      DailyMissionColumns.date: date,
      DailyMissionColumns.beatId: beatId,
      DailyMissionColumns.sortIndex: sortIndex,
      DailyMissionColumns.createdAt: createdAt.toIso8601String(),
    };
  }

  factory DailyMissionEntity.fromMap(Map<String, dynamic> map) {
    return DailyMissionEntity(
      id: map[DailyMissionColumns.id] as String,
      roadmapId: map[DailyMissionColumns.roadmapId] as String,
      date: map[DailyMissionColumns.date] as String,
      beatId: map[DailyMissionColumns.beatId] as String,
      sortIndex: (map[DailyMissionColumns.sortIndex] as num).toInt(),
      createdAt: DateTime.parse(map[DailyMissionColumns.createdAt] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyMissionEntity &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'DailyMissionEntity(id: $id, roadmapId: $roadmapId, date: $date, beatId: $beatId, sortIndex: $sortIndex)';
}
