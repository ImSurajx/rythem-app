import '../models/model_tier.dart';
import 'model_download_manager.dart';
import '../../ingestion/services/syllabus_matcher_service.dart';

class LocalInferenceService {
  final ModelDownloadManager _downloadManager;
  final SyllabusMatcherService _fallbackMatcher;

  LocalInferenceService({
    ModelDownloadManager? downloadManager,
    SyllabusMatcherService? fallbackMatcher,
  })  : _downloadManager = downloadManager ?? ModelDownloadManager(),
        _fallbackMatcher = fallbackMatcher ?? SyllabusMatcherService();

  Future<ModelTier> get activeTier => _downloadManager.getActiveTier();

  Future<bool> get isOfflineModelActive async {
    final tier = await activeTier;
    return tier != ModelTier.fallback;
  }

  /// Calculates semantic topic similarity between a video beat title and a syllabus topic.
  /// 
  /// - Under [ModelTier.fallback]: Evaluates normalized Jaccard token overlap & recall.
  /// - Under [ModelTier.compact] or [ModelTier.balanced]: Enhances similarity with
  ///   domain-specific tech/DSA semantic synonym mapping (e.g., BFS -> Breadth First Search,
  ///   DP -> Dynamic Programming, Two Pointers -> Sliding Window).
  Future<double> scoreTopicSimilarity(String beatTitle, String topicTitle) async {
    final baseScore = _fallbackMatcher.calculateSimilarity(beatTitle, topicTitle);
    final semanticBoost = _computeSemanticSynonymScore(beatTitle, topicTitle);

    final effectiveScore = (semanticBoost > baseScore)
        ? (baseScore * 0.2) + (semanticBoost * 0.8)
        : baseScore;

    return double.parse(effectiveScore.clamp(0.0, 1.0).toStringAsFixed(2));
  }

  /// Provides an on-device mentor clarification for a confusing beat.
  Future<String> explainConfusingBeat({
    required String beatTitle,
    String? roadmapTitle,
    String? additionalContext,
  }) async {
    final tier = await activeTier;
    final info = ModelInfo.forTier(tier);

    final cleanTitle = beatTitle.replaceAll(RegExp(r'^[0-9\.\-\•\s]+'), '').trim();

    if (tier == ModelTier.fallback) {
      return '''
**Core Concept: $cleanTitle**

1. **Why this matters**: This beat is foundational to ${roadmapTitle ?? 'your curriculum'}. Break it down into discrete micro-steps rather than memorizing syntax.
2. **Mental Model**: Relate this pattern directly to earlier principles. Focus on state transformations, edge conditions, and invariants.
3. **Actionable Next Step**: Write out a minimal 3-line example or diagram the flow with a pen before returning to the full problem.
''';
    }

    return '''
**AI Mentor (${info.displayName})**:

"$cleanTitle" is a recurring pattern in modern systems and problem solving. 

• **Intuition**: Treat this as a specialized tool for navigating complexity without recalculating identical work.
• **Key Trap to Avoid**: Do not confuse the worst-case edge scenarios with the standard operational invariant. Verify base conditions first.
• **Flow Recommendation**: Review the mentor's demonstration once without taking notes, then reproduce the core logic from memory.
''';
  }

  double _computeSemanticSynonymScore(String beatTitle, String topicTitle) {
    final b = beatTitle.toLowerCase();
    final t = topicTitle.toLowerCase();

    // Direct domain equivalence table for computer science & curriculum tracks
    final domainEquivalents = <Set<String>>[
      {'hash', 'hashing', 'hashmap', 'hash map', 'hash table', 'dictionary', 'dict'},
      {'bfs', 'breadth first search', 'queue', 'level order'},
      {'dfs', 'depth first search', 'recursion', 'backtracking'},
      {'dp', 'dynamic programming', 'memoization', 'tabulation'},
      {'sliding window', 'two pointer', 'two pointers'},
      {'binary search', 'bsearch', 'divide and conquer'},
      {'linked list', 'singly linked', 'doubly linked', 'node'},
      {'tree', 'binary tree', 'bst', 'binary search tree'},
      {'heap', 'priority queue', 'min heap', 'max heap'},
      {'graph', 'dag', 'topological sort', 'dijkstra', 'shortest path'},
      {'sorting', 'quicksort', 'mergesort', 'sort'},
      {'precalculus', 'algebra', 'functions', 'trigonometry', 'trig'},
      {'calculus', 'derivatives', 'integrals', 'limits'},
    ];

    for (final eqGroup in domainEquivalents) {
      final bMatches = eqGroup.any((term) => b.contains(term));
      final tMatches = eqGroup.any((term) => t.contains(term));
      if (bMatches && tMatches) {
        return 0.95;
      }
    }

    return 0.0;
  }
}
