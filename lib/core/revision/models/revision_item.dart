import 'dart:convert';

/// Represents a concept / beat candidate in the mathematical spaced-repetition revision system.
class RevisionItem {
  final String beatId;
  final String roadmapId;
  final String roadmapTitle;
  final String title;
  final bool isFlaggedWeak;
  final String? flagNote;
  final DateTime? lastRevisedAt;
  final int revisionCount;
  final double stabilityDays;
  final double retentionScore; // 0.0 to 1.0 (calculated using e^(-t/S))
  final String suggestedReason;

  const RevisionItem({
    required this.beatId,
    required this.roadmapId,
    required this.roadmapTitle,
    required this.title,
    this.isFlaggedWeak = false,
    this.flagNote,
    this.lastRevisedAt,
    this.revisionCount = 0,
    this.stabilityDays = 1.0,
    this.retentionScore = 1.0,
    required this.suggestedReason,
  });

  RevisionItem copyWith({
    String? beatId,
    String? roadmapId,
    String? roadmapTitle,
    String? title,
    bool? isFlaggedWeak,
    String? flagNote,
    DateTime? lastRevisedAt,
    int? revisionCount,
    double? stabilityDays,
    double? retentionScore,
    String? suggestedReason,
  }) {
    return RevisionItem(
      beatId: beatId ?? this.beatId,
      roadmapId: roadmapId ?? this.roadmapId,
      roadmapTitle: roadmapTitle ?? this.roadmapTitle,
      title: title ?? this.title,
      isFlaggedWeak: isFlaggedWeak ?? this.isFlaggedWeak,
      flagNote: flagNote ?? this.flagNote,
      lastRevisedAt: lastRevisedAt ?? this.lastRevisedAt,
      revisionCount: revisionCount ?? this.revisionCount,
      stabilityDays: stabilityDays ?? this.stabilityDays,
      retentionScore: retentionScore ?? this.retentionScore,
      suggestedReason: suggestedReason ?? this.suggestedReason,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'beatId': beatId,
      'roadmapId': roadmapId,
      'roadmapTitle': roadmapTitle,
      'title': title,
      'isFlaggedWeak': isFlaggedWeak,
      'flagNote': flagNote,
      'lastRevisedAt': lastRevisedAt?.toIso8601String(),
      'revisionCount': revisionCount,
      'stabilityDays': stabilityDays,
      'retentionScore': retentionScore,
      'suggestedReason': suggestedReason,
    };
  }

  factory RevisionItem.fromMap(Map<String, dynamic> map) {
    return RevisionItem(
      beatId: map['beatId'] as String,
      roadmapId: map['roadmapId'] as String? ?? '',
      roadmapTitle: map['roadmapTitle'] as String? ?? 'Curriculum Track',
      title: map['title'] as String? ?? 'Untitled Topic',
      isFlaggedWeak: map['isFlaggedWeak'] as bool? ?? false,
      flagNote: map['flagNote'] as String?,
      lastRevisedAt: map['lastRevisedAt'] != null ? DateTime.tryParse(map['lastRevisedAt'] as String) : null,
      revisionCount: map['revisionCount'] as int? ?? 0,
      stabilityDays: (map['stabilityDays'] as num?)?.toDouble() ?? 1.0,
      retentionScore: (map['retentionScore'] as num?)?.toDouble() ?? 1.0,
      suggestedReason: map['suggestedReason'] as String? ?? 'Scheduled Review',
    );
  }

  String toJson() => json.encode(toMap());

  factory RevisionItem.fromJson(String source) =>
      RevisionItem.fromMap(json.decode(source) as Map<String, dynamic>);

  TopicStrength get strength {
    if (isFlaggedWeak && revisionCount == 0) return TopicStrength.weak;
    if (revisionCount == 1) return TopicStrength.strengthening;
    if (revisionCount == 2) return TopicStrength.strong;
    if (revisionCount >= 3) return TopicStrength.strongest;
    return isFlaggedWeak ? TopicStrength.weak : TopicStrength.strengthening;
  }

  String get strengthLabel {
    switch (strength) {
      case TopicStrength.weak:
        return 'WEAK TOPIC';
      case TopicStrength.strengthening:
        return 'STRENGTHENING (1x)';
      case TopicStrength.strong:
        return 'STRONG (2x)';
      case TopicStrength.strongest:
        return 'STRONGEST (MASTERED 🏆)';
    }
  }
}

enum TopicStrength {
  weak,
  strengthening,
  strong,
  strongest,
}
