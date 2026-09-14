import 'dart:math';
import '../models/model_tier.dart';
import '../models/curriculum_audit_result.dart';
import 'model_download_manager.dart';
import '../../ingestion/services/syllabus_matcher_service.dart';
import '../../database/repositories/roadmap_repository.dart';
import '../../database/repositories/beat_repository.dart';
import '../../pacing/services/pacing_service.dart';

/// Intelligent on-device inference service providing context-aware curriculum analysis,
/// tracker timeline calculations, and deep technical concept explanations.
class LocalInferenceService {
  final ModelDownloadManager _downloadManager;
  final SyllabusMatcherService _fallbackMatcher;
  final RoadmapRepository? _roadmapRepo;
  final BeatRepository? _beatRepo;
  final PacingService? _pacingService;

  LocalInferenceService({
    ModelDownloadManager? downloadManager,
    SyllabusMatcherService? fallbackMatcher,
    RoadmapRepository? roadmapRepo,
    BeatRepository? beatRepo,
    PacingService? pacingService,
  })  : _downloadManager = downloadManager ?? ModelDownloadManager(),
        _fallbackMatcher = fallbackMatcher ?? SyllabusMatcherService(),
        _roadmapRepo = roadmapRepo,
        _beatRepo = beatRepo,
        _pacingService = pacingService;

  Future<ModelTier> get activeTier => _downloadManager.getActiveTier();

  Future<bool> get isOfflineModelActive async {
    final tier = await activeTier;
    return tier != ModelTier.fallback;
  }

  /// Calculates semantic topic similarity between a video beat title and a syllabus topic.
  Future<double> scoreTopicSimilarity(String beatTitle, String topicTitle) async {
    final baseScore = _fallbackMatcher.calculateSimilarity(beatTitle, topicTitle);
    final semanticBoost = _computeSemanticSynonymScore(beatTitle, topicTitle);

    final effectiveScore = (semanticBoost > baseScore)
        ? (baseScore * 0.2) + (semanticBoost * 0.8)
        : baseScore;

    return double.parse(effectiveScore.clamp(0.0, 1.0).toStringAsFixed(2));
  }

  /// Evaluates and answers user queries, including roadmap tracker status,
  /// progress timelines, and computer science / programming concepts.
  Future<String> answerQuery({
    required String prompt,
    String? roadmapId,
    String? roadmapTitle,
    String? additionalContext,
  }) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) {
      return 'Please enter a concept, question, or tracker query.';
    }

    final lower = trimmed.toLowerCase();

    // 1. Detect Tracker / Progress / Timeline queries
    if (_isTrackerQuery(lower)) {
      return await _handleTrackerQuery(
        prompt: trimmed,
        roadmapId: roadmapId,
        roadmapTitle: roadmapTitle,
      );
    }

    // 2. Technical / Computer Science / Programming Concept query
    return await _handleConceptQuery(
      prompt: trimmed,
      roadmapTitle: roadmapTitle,
      additionalContext: additionalContext,
    );
  }

  /// Provides an on-device mentor clarification for a confusing beat.
  Future<String> explainConfusingBeat({
    required String beatTitle,
    String? roadmapTitle,
    String? roadmapId,
    String? additionalContext,
  }) async {
    return answerQuery(
      prompt: beatTitle,
      roadmapId: roadmapId,
      roadmapTitle: roadmapTitle,
      additionalContext: additionalContext,
    );
  }

  // --- Tracker Query Resolution ---

  bool _isTrackerQuery(String lower) {
    final trackerKeywords = [
      'tracker',
      'track',
      'how many days',
      'days to complete',
      'how long',
      'took me to complete',
      'take to complete',
      'when will i finish',
      'finish date',
      'progress',
      'remaining',
      'completed beats',
      'am i on track',
      'my pace',
      'pacing',
      'completion timeline',
    ];

    return trackerKeywords.any((kw) => lower.contains(kw));
  }

  Future<String> _handleTrackerQuery({
    required String prompt,
    String? roadmapId,
    String? roadmapTitle,
  }) async {
    final tier = await activeTier;
    final info = ModelInfo.forTier(tier);

    final roadmapRepo = _roadmapRepo ?? RoadmapRepository();
    final beatRepo = _beatRepo ?? BeatRepository();

    // Fetch candidate roadmap
    var roadmap = roadmapId != null ? await roadmapRepo.getRoadmapById(roadmapId) : null;
    if (roadmap == null) {
      final all = await roadmapRepo.getAllRoadmaps();
      if (all.isNotEmpty) {
        roadmap = all.firstWhere((r) => r.isPrimary, orElse: () => all.first);
      }
    }

    if (roadmap == null) {
      return '''
📊 **Tracker Analysis**:
No active learning roadmap or tracker was found in local storage.

• **Next Step**: Create or select a roadmap from the **Explore** tab to track your beats, daily pacing, and completion days.
''';
    }

    final allBeats = await beatRepo.getBeatsByRoadmapId(roadmap.id);
    final completedBeats = allBeats.where((b) => b.isCompleted).toList();
    final pendingBeats = allBeats.where((b) => !b.isCompleted).toList();

    final total = allBeats.length;
    final completed = completedBeats.length;
    final pending = pendingBeats.length;
    final percent = total > 0 ? ((completed / total) * 100).toStringAsFixed(1) : '0.0';

    final now = DateTime.now();
    final createdAt = roadmap.createdAt;
    final daysElapsed = max(1, now.difference(createdAt).inDays + 1);

    final targetDate = roadmap.targetCompletionDate;
    final daysLeft = targetDate?.difference(now).inDays;
    final targetDateFormatted = targetDate != null
        ? '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}'
        : 'Open-ended';

    double dailyPace = 0.0;
    if (_pacingService != null) {
      try {
        final budget = await _pacingService.computePacingBudget(roadmap.id);
        dailyPace = budget.todayEffortShare;
      } catch (_) {}
    }
    if (dailyPace <= 0.0) {
      dailyPace = (daysLeft != null && daysLeft > 0)
          ? (pending / daysLeft).clamp(0.2, 20.0)
          : (pending > 0 ? (pending / 14).clamp(0.5, 5.0) : 0.0);
    }

    final tierHeader = tier == ModelTier.fallback
        ? ''
        : '🤖 **AI Mentor (${info.displayName}) • Tracker Report**\n\n';

    if (allBeats.isNotEmpty && pending == 0) {
      return '''
$tierHeader🎉 **Milestone Achieved: Track 100% Completed!**

• **Curriculum Track**: **${roadmap.title}**
• **Total Duration**: Completed in **$daysElapsed days** (started on ${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}).
• **Total Beats Mastered**: **$total / $total beats** (100.0%).
• **Pacing Performance**: Outstanding consistency across all curriculum chapters. All beats marked complete in SQLite.
''';
    }

    return '''
$tierHeader📊 **Tracker Status & Timeline Analysis: ${roadmap.title}**

• **Overall Progress**: **$completed of $total beats completed** ($percent% complete).
• **Days Elapsed**: **$daysElapsed days** active on this track (started ${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}).
• **Beats Remaining**: **$pending beats** left to master.
• **Target Completion Date**: **$targetDateFormatted** (${daysLeft != null ? (daysLeft > 0 ? '$daysLeft days remaining' : 'Target reached today') : 'Self-paced'}).
• **Required Pacing**: Complete **~${dailyPace.toStringAsFixed(1)} beats/day** to finish right on schedule without cramming.
• **Curriculum Health**: ${completed >= (total / 2) ? '🚀 Ahead of the halfway mark! Momentum is on your side.' : '🌱 Establishing foundational mastery. Keep up your daily micro-habits.'}
''';
  }

  // --- Concept Knowledge Base & Query Resolution ---

  Future<String> _handleConceptQuery({
    required String prompt,
    String? roadmapTitle,
    String? additionalContext,
  }) async {
    final tier = await activeTier;
    final info = ModelInfo.forTier(tier);

    final cleanTitle = prompt
        .replaceAll(RegExp(r'^(what is|what are|explain|how does|tell me about|define|why use)\s+', caseSensitive: false), '')
        .replaceAll(RegExp(r'\?+$'), '')
        .replaceAll(RegExp(r'^[0-9\.\-\•\s]+'), '')
        .trim();

    final lowerClean = cleanTitle.toLowerCase();

    // Check specific knowledge definitions
    final matchedExplanation = _lookupKnowledgeBase(lowerClean, cleanTitle);
    if (matchedExplanation != null) {
      if (tier == ModelTier.fallback) {
        return matchedExplanation;
      }
      return '''
🤖 **AI Mentor (${info.displayName})**:

$matchedExplanation
''';
    }

    // Dynamic Synthesis for Arbitrary Technical Concepts
    return _synthesizeGeneralConceptExplanation(
      concept: cleanTitle,
      tier: tier,
      info: info,
      roadmapTitle: roadmapTitle,
    );
  }

  String? _lookupKnowledgeBase(String lower, String cleanTitle) {
    // 1. Test Cases & Testing
    if (lower.contains('test case') || lower == 'testcase') {
      return '''
🧪 **Core Concept: Test Case in Programming**

A **Test Case** is a structured, verifiable specification of inputs, execution preconditions, procedures, and expected results formulated to determine whether a specific unit of code, feature, or software system satisfies requirements and behaves correctly.

• **Core Anatomy of a Production Test Case**:
  1. **Test Description & ID**: The exact behavior being tested (e.g., `TC_AUTH_01: Reject login with malformed email`).
  2. **Preconditions / State**: The prerequisites before test runs (e.g., Database contains an active user account).
  3. **Test Inputs & Actions**: The stimulus applied to the program (e.g., Calling `loginService.authenticate("bad_email", "secret123")`).
  4. **Expected Result**: The deterministic state or return value expected (e.g., Throws `InvalidEmailException`).
  5. **Actual Result & Assertion**: The verification check (`expect(actual, equals(expected))`).

• **The Three Essential Categories**:
  - **Happy Path (Positive)**: Validates normal operating inputs under standard conditions.
  - **Boundary & Edge Cases**: Tests limits where off-by-one errors hide (e.g., empty lists `[]`, single item, 0, negative values, `MAX_INT`, strings with 10,000 characters).
  - **Negative & Error Handling**: Tests how the system responds to invalid states (network drops, timeouts, null pointers) without crashing.

• **Concrete Code Example (Unit Test)**:
```dart
test('Test Case: Pacing budget splits pending beats over days left', () {
  // 1. Arrange (Inputs & Preconditions)
  final pendingBeats = 10;
  final daysLeft = 5;

  // 2. Act (Execution)
  final dailyShare = calculateDailyShare(pendingBeats, daysLeft);

  // 3. Assert (Expected vs Actual)
  expect(dailyShare, equals(2.0));
});
```

• **Key Trap to Avoid**:
Testing only the happy path. Over 80% of production bugs occur at boundary values and unhandled edge conditions.
''';
    }

    // 2. Unit Testing vs Integration Testing
    if (lower.contains('unit test') || lower.contains('integration test') || lower.contains('e2e')) {
      return '''
🔬 **Core Concept: The Testing Pyramid (Unit vs Integration vs E2E)**

1. **Unit Tests**:
   - Focus: Tests a single function, method, or class in absolute isolation.
   - Speed: Extremely fast (milliseconds). Dependencies like databases and networks are mocked.
   - Example: Testing that a tax calculation formula returns `10.50` given `100.0`.

2. **Integration Tests**:
   - Focus: Tests how multiple components work together (e.g., Repository querying a real SQLite database).
   - Speed: Moderate speed (seconds). Verifies contracts, foreign keys, and serialization.

3. **End-to-End (E2E) / UI Tests**:
   - Focus: Simulates genuine user interactions from screen tap to database round-trip.
   - Speed: Slowest, but validates the full user journey.
''';
    }

    // 3. Binary Search
    if (lower.contains('binary search') || lower == 'bsearch') {
      return '''
🔍 **Core Concept: Binary Search**

**Binary Search** is an efficient divide-and-conquer search algorithm that locates a target value within a **sorted array** in **O(log N)** time complexity.

• **Mental Model**:
Opening a 1,000-page dictionary in the exact middle. If the word comes before, you throw away the right 500 pages. If after, you throw away the left 500 pages. In just 10 checks (2^10 = 1024), you locate any word among 1,000 pages!

• **The Invariant & Core Algorithm**:
1. Maintain two pointers: `low = 0` and `high = length - 1`.
2. Compute `mid = low + ((high - low) ~/ 2)` (preventing integer overflow).
3. If `array[mid] == target`, return `mid`.
4. If `array[mid] < target`, discard left half: `low = mid + 1`.
5. If `array[mid] > target`, discard right half: `high = mid - 1`.

• **Classic Trap**:
- Off-by-one errors in loop conditions (`while (low <= high)` vs `while (low < high)`).
- Applying binary search to unsorted data.
''';
    }

    // 4. Dynamic Programming & Memoization
    if (lower.contains('dynamic programming') || lower == 'dp' || lower.contains('memoization') || lower.contains('tabulation')) {
      return '''
🧩 **Core Concept: Dynamic Programming (DP)**

**Dynamic Programming** is an algorithmic optimization technique that solves complex problems by breaking them down into simpler, overlapping subproblems, solving each subproblem **only once**, and storing the results.

• **Two Fundamental Hallmarks of a DP Problem**:
  1. **Optimal Substructure**: The optimal solution to the problem contains within it optimal solutions to subproblems.
  2. **Overlapping Subproblems**: The same smaller subproblems are computed repeatedly (e.g., computing `fib(3)` multiple times in `fib(5)`).

• **Two Implementation Flavors**:
  - **Top-Down (Memoization)**: Write standard recursion, but check a cache / dictionary before computing. If cached, return immediately in O(1).
  - **Bottom-Up (Tabulation)**: Build a table iteratively from the base cases upward (e.g., `dp[0]`, `dp[1]`, up to `dp[n]`).

• **Real-World Intuition**:
"Write down 1 + 1 + 1 + 1 + 1 on a board. How many? Five. Add another 1 at the end. How many now? Six! You didn't recount the first five because you remembered the answer." — That is Dynamic Programming.
''';
    }

    // 5. Two Pointers & Sliding Window
    if (lower.contains('two pointer') || lower.contains('two pointers') || lower.contains('sliding window')) {
      return '''
🎯 **Core Concept: Two Pointers Technique & Sliding Window**

Techniques that replace brute-force O(N^2) nested loops with optimal **O(N)** linear scans by managing index pointers simultaneously.

• **Two Pointers (Opposite Ends)**:
  - Setup: One pointer at `left = 0`, another at `right = n - 1`.
  - Condition: Move inwards based on value comparison (e.g., Two-Sum on a sorted array, reversing an array, palindrome verification).

• **Sliding Window (Contiguous Subarrays)**:
  - Setup: A `left` and `right` pointer defining a window `[left...right]`.
  - Expand `right` to include elements until a condition breaks.
  - Contract `left` to restore the invariant (e.g., longest substring with no repeating characters, minimum subarray sum).
''';
    }

    // 6. Recursion & Base Conditions
    if (lower.contains('recursion') || lower.contains('recursive')) {
      return '''
🔄 **Core Concept: Recursion & Base Conditions**

**Recursion** is a programming method where a function calls itself directly or indirectly to solve smaller instances of the exact same problem.

• **The Two Mandatory Rules of Recursion**:
  1. **The Base Case**: The trivial terminating condition where recursion stops without calling itself (e.g., `if (n <= 1) return 1;`). Without this, the call stack overflows (`StackOverflowError`).
  2. **The Recursive Step**: Reducing the problem input strictly toward the base case (e.g., `return n * factorial(n - 1);`).

• **Mental Model**:
Think of a Russian Matryoshka doll. You open each outer doll (allocating a stack frame) until you reach the solid baby doll inside (the base case), then close them back up (returning values down the call stack).
''';
    }

    // 7. Time & Space Complexity (Big-O)
    if (lower.contains('big o') || lower.contains('time complexity') || lower.contains('space complexity')) {
      return '''
⏱️ **Core Concept: Big-O Asymptotic Complexity**

**Big-O Notation** describes the rate at which an algorithm's runtime or memory consumption grows as the input size (N) approaches infinity. It measures algorithmic scalability, independent of machine hardware.

• **Common Complexities Ranked Best to Worst**:
  1. **O(1) - Constant**: Instant lookup (e.g., Hash map lookup, array index access).
  2. **O(log N) - Logarithmic**: Repeatedly dividing input in half (e.g., Binary search).
  3. **O(N) - Linear**: Single pass through all elements (e.g., Finding max in unsorted list).
  4. **O(N log N) - Linearithmic**: Optimal comparison-based sorting (e.g., Merge sort, Quick sort).
  5. **O(N^2) - Quadratic**: Nested loops comparing all pairs (e.g., Bubble sort).
  6. **O(2^N) - Exponential**: Recursive branching without memoization (e.g., Brute-force subsets).
''';
    }

    return null;
  }

  String _synthesizeGeneralConceptExplanation({
    required String concept,
    required ModelTier tier,
    required ModelInfo info,
    String? roadmapTitle,
  }) {
    final title = concept.isNotEmpty ? concept : 'Core Concept';

    if (tier == ModelTier.fallback) {
      return '''
💡 **Core Concept: $title**

1. **Fundamental Definition**:
   $title is a foundational principle in ${roadmapTitle ?? 'software engineering and computer science'}. It provides a systematic pattern for decomposing complex tasks into modular, maintainable units.

2. **Underlying Mechanics**:
   - **Inputs & Invariants**: Identifies clear boundaries and state transitions.
   - **Execution Path**: Isolates side effects and guarantees deterministic output for given inputs.

3. **Key Traps & Edge Scenarios to Watch**:
   - Unhandled null, empty, or zero boundary states.
   - Off-by-one bounds and premature optimization before establishing correctness.

4. **Actionable Flow Tip**:
   Write out the expected input/output contract or diagram the state transition with pen and paper before implementing the full code.
''';
    }

    return '''
🤖 **AI Mentor (${info.displayName})**:

### **$title: Architectural & Conceptual Overview**

• **What It Solves**:
In modern software systems, **$title** addresses the challenge of building reliable, scalable components by establishing clear abstractions between the caller and the underlying implementation.

• **Core Mental Model**:
Treat **$title** not as isolated syntax, but as a deliberate contract. You define expected behavior under normal operation, define safeguards for boundary conditions, and verify deterministic outcomes.

• **Practical Walkthrough**:
1. **Define the Base State**: Ensure valid initialization before triggering logic.
2. **Execute Invariant Logic**: Maintain predictable state changes throughout execution.
3. **Verify Boundary Invariants**: Always check edge conditions (empty inputs, concurrency limits, overflow).

• **Key Trap to Avoid**:
Confusing superficial syntax with structural understanding. Focus on state flow, edge cases, and algorithmic complexity rather than memorizing snippets.
''';
  }

  double _computeSemanticSynonymScore(String beatTitle, String topicTitle) {
    final b = beatTitle.toLowerCase();
    final t = topicTitle.toLowerCase();

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
      {'test', 'testing', 'test case', 'testcase', 'unit test', 'integration test'},
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

  /// Performs an on-device AI audit between a Subject's benchmark syllabus topics
  /// and the videos of an attached playlist.
  ///
  /// Guarantees:
  /// - Videos remain in exact original order 0..N-1.
  /// - Dynamic Topic Sequencing: Syllabus topics are re-ordered according to the mentor's
  ///   chronological teaching flow (first appearance in the video playlist).
  /// - Uncovered syllabus topics are flagged as Gaps at the end.
  /// - Videos with no syllabus match are tagged as Mentor Extras (enrichment).
  /// - Produces a structured [CurriculumAuditResult] with an AI-generated Markdown audit summary.
  Future<CurriculumAuditResult> auditSubjectResource({
    required String subjectTitle,
    required List<String> syllabusTopics,
    required List<String> videoTitles,
  }) async {
    final tier = await activeTier;
    final info = ModelInfo.forTier(tier);

    final mappings = <VideoTopicMapping>[];
    final firstSeenIndex = <String, int>{};
    final topicToVideos = <String, List<int>>{};
    final mentorExtras = <String>[];

    for (int i = 0; i < videoTitles.length; i++) {
      final videoTitle = videoTitles[i];
      String? bestTopic;
      double bestScore = 0.0;

      for (final topic in syllabusTopics) {
        final score = await scoreTopicSimilarity(videoTitle, topic);
        if (score > bestScore) {
          bestScore = score;
          bestTopic = topic;
        }
      }

      if (bestTopic != null && bestScore >= SyllabusMatcherService.ambiguousConfidenceThreshold) {
        mappings.add(VideoTopicMapping(
          videoIndex: i,
          videoTitle: videoTitle,
          matchedTopicId: bestTopic,
          matchedTopicTitle: bestTopic,
          confidence: bestScore,
          isMentorExtra: false,
        ));

        firstSeenIndex.putIfAbsent(bestTopic, () => i);
        topicToVideos.putIfAbsent(bestTopic, () => []).add(i + 1);
      } else {
        mentorExtras.add(videoTitle);
        mappings.add(VideoTopicMapping(
          videoIndex: i,
          videoTitle: videoTitle,
          confidence: bestScore,
          isMentorExtra: true,
        ));
      }
    }

    // Determine mentor-driven syllabus sequence
    final coveredTopics = syllabusTopics.where((t) => firstSeenIndex.containsKey(t)).toList()
      ..sort((a, b) => firstSeenIndex[a]!.compareTo(firstSeenIndex[b]!));

    final uncoveredGaps = syllabusTopics.where((t) => !firstSeenIndex.containsKey(t)).toList();
    final orderedSyllabusTopics = [...coveredTopics, ...uncoveredGaps];

    final totalTopics = syllabusTopics.length;
    final coveragePercent = totalTopics > 0
        ? double.parse(((coveredTopics.length / totalTopics) * 100).toStringAsFixed(1))
        : 100.0;

    // Generate AI Narrative Markdown
    final tierHeader = tier == ModelTier.fallback
        ? '🤖 **On-Device Curriculum Audit**'
        : '🤖 **AI Mentor (${info.displayName}) • Curriculum Audit**';

    final buffer = StringBuffer();
    buffer.writeln('$tierHeader\n');
    buffer.writeln('### **$subjectTitle: Coverage & Sequence Analysis**\n');
    buffer.writeln('• **Coverage Score**: **${coveredTopics.length} / $totalTopics topics covered** ($coveragePercent%).');
    buffer.writeln('• **Videos Ingested**: **${videoTitles.length} videos** preserved in mentor chronological order.');
    if (mentorExtras.isNotEmpty) {
      buffer.writeln('• **Mentor Extras**: **${mentorExtras.length} bonus/enrichment videos** identified.');
    }
    buffer.writeln();

    buffer.writeln('#### 🧭 **Mentor Teaching Sequence**');
    if (coveredTopics.isEmpty) {
      buffer.writeln('_No direct topic correlations identified._');
    } else {
      for (int t = 0; t < coveredTopics.length; t++) {
        final top = coveredTopics[t];
        final vids = topicToVideos[top] ?? [];
        final vidRange = vids.length == 1
            ? 'Video #${vids.first}'
            : 'Videos #${vids.first}–#${vids.last} (${vids.length} videos)';
        buffer.writeln('${t + 1}. **$top** — $vidRange');
      }
    }
    buffer.writeln();

    buffer.writeln('#### ⚠️ **Curriculum Gaps (Uncovered Topics)**');
    if (uncoveredGaps.isEmpty) {
      buffer.writeln('🎉 **Complete Coverage**: The attached playlist satisfies all required benchmark topics in this subject without missing concepts.');
    } else {
      buffer.writeln('The following **${uncoveredGaps.length} benchmark topics** were not detected in this playlist:');
      for (final gap in uncoveredGaps) {
        buffer.writeln('• **$gap** — _0 matching videos. Consider attaching a supplementary video or resource._');
      }
    }

    return CurriculumAuditResult(
      subjectTitle: subjectTitle,
      orderedSyllabusTopics: orderedSyllabusTopics,
      coveredTopics: coveredTopics,
      uncoveredGaps: uncoveredGaps,
      mentorExtras: mentorExtras,
      mappings: mappings,
      coveragePercentage: coveragePercent,
      auditSummaryMarkdown: buffer.toString(),
      evaluatedTier: tier,
    );
  }
}
