class SyllabusTopic {
  final String id;
  final String title;
  final String? description;
  final int sortOrder;

  const SyllabusTopic({
    required this.id,
    required this.title,
    this.description,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'sort_order': sortOrder,
    };
  }

  factory SyllabusTopic.fromMap(Map<String, dynamic> map) {
    return SyllabusTopic(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  String toString() => 'SyllabusTopic(id: $id, title: $title)';
}
