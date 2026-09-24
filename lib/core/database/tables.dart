class DatabaseTables {
  DatabaseTables._();

  static const String roadmaps = 'roadmaps';
  static const String chapters = 'chapters';
  static const String beats = 'beats';
  static const String beatLogs = 'beat_logs';
  static const String appSettings = 'app_settings';
  static const String dailyMissions = 'daily_missions';
}

class RoadmapColumns {
  RoadmapColumns._();

  static const String id = 'id';
  static const String title = 'title';
  static const String description = 'description';
  static const String startDate = 'start_date';
  static const String targetCompletionDate = 'target_completion_date';
  static const String status = 'status'; // active, archived, completed
  static const String isPrimary = 'is_primary';
  static const String createdAt = 'created_at';
  static const String updatedAt = 'updated_at';
}

class ChapterColumns {
  ChapterColumns._();

  static const String id = 'id';
  static const String roadmapId = 'roadmap_id';
  static const String title = 'title';
  static const String sortOrder = 'sort_order';
  static const String createdAt = 'created_at';
  static const String updatedAt = 'updated_at';
}

class BeatColumns {
  BeatColumns._();

  static const String id = 'id';
  static const String chapterId = 'chapter_id';
  static const String roadmapId = 'roadmap_id';
  static const String title = 'title';
  static const String sourceUrl = 'source_url';
  static const String timestampSeconds = 'timestamp_seconds';
  static const String effortWeight = 'effort_weight';
  static const String sortOrder = 'sort_order';
  static const String isCompleted = 'is_completed';
  static const String completedAt = 'completed_at';
  static const String isMentorExtra = 'is_mentor_extra';
  static const String matchConfidence = 'match_confidence';
  static const String syllabusTopicId = 'syllabus_topic_id';
  static const String totalParts = 'total_parts';
  static const String completedParts = 'completed_parts';
  static const String createdAt = 'created_at';
  static const String updatedAt = 'updated_at';
}

class BeatLogColumns {
  BeatLogColumns._();

  static const String id = 'id';
  static const String beatId = 'beat_id';
  static const String roadmapId = 'roadmap_id';
  static const String completedDate = 'completed_date'; // YYYY-MM-DD
  static const String createdAt = 'created_at';
}

class AppSettingsColumns {
  AppSettingsColumns._();

  static const String key = 'key';
  static const String value = 'value';
  static const String updatedAt = 'updated_at';
}

class DailyMissionColumns {
  DailyMissionColumns._();

  static const String id = 'id';
  static const String roadmapId = 'roadmap_id';
  static const String date = 'date'; // YYYY-MM-DD
  static const String beatId = 'beat_id';
  static const String sortIndex = 'sort_index';
  static const String createdAt = 'created_at';
}

