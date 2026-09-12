import '../tables.dart';

class BeatLogEntity {
  final String id;
  final String beatId;
  final String roadmapId;
  final String completedDate; // YYYY-MM-DD
  final DateTime createdAt;

  const BeatLogEntity({
    required this.id,
    required this.beatId,
    required this.roadmapId,
    required this.completedDate,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      BeatLogColumns.id: id,
      BeatLogColumns.beatId: beatId,
      BeatLogColumns.roadmapId: roadmapId,
      BeatLogColumns.completedDate: completedDate,
      BeatLogColumns.createdAt: createdAt.toIso8601String(),
    };
  }

  factory BeatLogEntity.fromMap(Map<String, dynamic> map) {
    return BeatLogEntity(
      id: map[BeatLogColumns.id] as String,
      beatId: map[BeatLogColumns.beatId] as String,
      roadmapId: map[BeatLogColumns.roadmapId] as String,
      completedDate: map[BeatLogColumns.completedDate] as String,
      createdAt: DateTime.parse(map[BeatLogColumns.createdAt] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BeatLogEntity &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'BeatLogEntity(id: $id, beatId: $beatId, date: $completedDate)';
}
