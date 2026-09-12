import '../tables.dart';

class RoadmapEntity {
  final String id;
  final String title;
  final String? description;
  final DateTime? targetCompletionDate;
  final String status; // 'active', 'archived', 'completed'
  final bool isPrimary;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RoadmapEntity({
    required this.id,
    required this.title,
    this.description,
    this.targetCompletionDate,
    this.status = 'active',
    this.isPrimary = false,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive => status == 'active';
  bool get isArchived => status == 'archived';
  bool get isCompleted => status == 'completed';

  RoadmapEntity copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? targetCompletionDate,
    String? status,
    bool? isPrimary,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RoadmapEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      targetCompletionDate: targetCompletionDate ?? this.targetCompletionDate,
      status: status ?? this.status,
      isPrimary: isPrimary ?? this.isPrimary,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      RoadmapColumns.id: id,
      RoadmapColumns.title: title,
      RoadmapColumns.description: description,
      RoadmapColumns.targetCompletionDate:
          targetCompletionDate?.toIso8601String(),
      RoadmapColumns.status: status,
      RoadmapColumns.isPrimary: isPrimary ? 1 : 0,
      RoadmapColumns.createdAt: createdAt.toIso8601String(),
      RoadmapColumns.updatedAt: updatedAt.toIso8601String(),
    };
  }

  factory RoadmapEntity.fromMap(Map<String, dynamic> map) {
    return RoadmapEntity(
      id: map[RoadmapColumns.id] as String,
      title: map[RoadmapColumns.title] as String,
      description: map[RoadmapColumns.description] as String?,
      targetCompletionDate: map[RoadmapColumns.targetCompletionDate] != null
          ? DateTime.parse(map[RoadmapColumns.targetCompletionDate] as String)
          : null,
      status: (map[RoadmapColumns.status] as String?) ?? 'active',
      isPrimary: (map[RoadmapColumns.isPrimary] as int?) == 1,
      createdAt: DateTime.parse(map[RoadmapColumns.createdAt] as String),
      updatedAt: DateTime.parse(map[RoadmapColumns.updatedAt] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoadmapEntity &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'RoadmapEntity(id: $id, title: $title, status: $status, isPrimary: $isPrimary)';
}
