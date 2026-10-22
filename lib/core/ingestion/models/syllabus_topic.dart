class SyllabusTopic {
  final String id;
  final String title;
  final String? description;
  final int sortOrder;
  final double? effortPoints;

  const SyllabusTopic({
    required this.id,
    required this.title,
    this.description,
    this.sortOrder = 0,
    this.effortPoints,
  });

  SyllabusTopic copyWith({
    String? id,
    String? title,
    String? description,
    int? sortOrder,
    double? effortPoints,
  }) {
    return SyllabusTopic(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      sortOrder: sortOrder ?? this.sortOrder,
      effortPoints: effortPoints ?? this.effortPoints,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'sort_order': sortOrder,
      'effort_points': effortPoints,
    };
  }

  factory SyllabusTopic.fromMap(Map<String, dynamic> map) {
    return SyllabusTopic(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      effortPoints: (map['effort_points'] as num?)?.toDouble() ??
          (map['effort_weight'] as num?)?.toDouble() ??
          (map['effort'] as num?)?.toDouble() ??
          (map['points'] as num?)?.toDouble() ??
          (map['beats'] as num?)?.toDouble(),
    );
  }

  @override
  String toString() =>
      'SyllabusTopic(id: $id, title: $title, effortPoints: $effortPoints)';
}
