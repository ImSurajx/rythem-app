import '../tables.dart';

class AppSettingsEntity {
  final String key;
  final String value;
  final DateTime updatedAt;

  const AppSettingsEntity({
    required this.key,
    required this.value,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      AppSettingsColumns.key: key,
      AppSettingsColumns.value: value,
      AppSettingsColumns.updatedAt: updatedAt.toIso8601String(),
    };
  }

  factory AppSettingsEntity.fromMap(Map<String, dynamic> map) {
    return AppSettingsEntity(
      key: map[AppSettingsColumns.key] as String,
      value: map[AppSettingsColumns.value] as String,
      updatedAt: DateTime.parse(map[AppSettingsColumns.updatedAt] as String),
    );
  }

  @override
  String toString() => 'AppSettingsEntity(key: $key, value: $value)';
}
