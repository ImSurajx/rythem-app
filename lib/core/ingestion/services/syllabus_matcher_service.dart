import '../models/extracted_beat.dart';
import '../models/extracted_chapter.dart';
import '../models/syllabus_topic.dart';

class MatchResult {
  final ExtractedBeat beat;
  final String? matchedTopicId;
  final double? confidence;
  final bool isMentorExtra;

  const MatchResult({
    required this.beat,
    this.matchedTopicId,
    this.confidence,
    required this.isMentorExtra,
  });
}

class SyllabusMatcherService {
  /// Confidence threshold above which a match is considered confirmed
  static const double highConfidenceThreshold = 0.70;

  /// Minimum confidence threshold to propose a match (below this is mentor_extra)
  static const double ambiguousConfidenceThreshold = 0.50;

  static const Set<String> _stopWords = {
    'the', 'and', 'for', 'with', 'from', 'into', 'about', 'over', 'after',
    'how', 'what', 'why', 'part', 'chapter', 'module', 'lesson', 'lecture',
    'video', 'tutorial', 'course', 'guide', 'basics', 'introduction', 'intro',
    'an', 'a', 'in', 'on', 'at', 'to', 'of', 'by', 'is', 'it', 'or',
  };

  /// Static CS & programming synonym groups for cross-concept understanding
  static const List<Set<String>> _domainEquivalents = [
    // Conditionals & Control Flow
    {'condition', 'conditions', 'conditional', 'if else', 'if statement', 'control flow'},
    // Object Oriented Programming & Classes
    {'oop', 'object oriented', 'class', 'classes', 'init', 'inheritance', 'encapsulation', 'polymorphism', 'dunder', 'magic methods', 'magic method', 'abstraction'},
    // Error & Exception Handling
    {'exception', 'exceptions', 'try except', 'error handling', 'traceback'},
    // File I/O
    {'file handling', 'open file', 'read file', 'write file', 'csv', 'json', 'text file', 'text files'},
    // Modules & Packages
    {'module', 'modules', 'package', 'packages', 'import', 'pip'},
    // Virtual Environments
    {'virtualenv', 'virtual environment', 'venv', 'conda'},
    // Web Requests & APIs
    {'requests', 'http requests', 'api', 'rest api', 'endpoints'},
    // Git & Version Control
    {'git', 'github', 'version control', 'commit', 'branch', 'pull request', 'pr', 'readme'},
    // Testing & Quality
    {'pytest', 'unit test', 'unittests', 'unit testing', 'test case', 'testcases'},
    // Typing
    {'type hints', 'type hint', 'type annotations', 'typing'},
    // DSA - Hash & Maps
    {'hash', 'hashing', 'hashmap', 'hash map', 'hash table'},
    // DSA - Search & Graphs
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
    {'precalculus', 'algebra', 'trigonometry', 'trig'},
    {'calculus', 'derivatives', 'integrals', 'limits', 'backpropagation'},
  ];

  /// Aligns extracted chapters & beats against a syllabus topic list.
  /// 
  /// Ground truths strictly enforced:
  /// - Mentor sequence is never reordered.
  /// - Unmatched beats stay in place and are tagged [isMentorExtra: true].
  /// - Matches carry confidence score (high vs ambiguous).
  List<ExtractedChapter> alignCurriculum({
    required List<ExtractedChapter> chapters,
    required List<SyllabusTopic> syllabus,
  }) {
    if (syllabus.isEmpty) {
      return chapters;
    }

    final updatedChapters = <ExtractedChapter>[];

    for (final chapter in chapters) {
      final updatedBeats = <ExtractedBeat>[];

      for (final beat in chapter.beats) {
        final match = _findBestTopicMatch(beat, syllabus);

        if (match != null && match.confidence >= ambiguousConfidenceThreshold) {
          updatedBeats.add(beat.copyWith(
            syllabusTopicId: match.topic.id,
            matchConfidence: match.confidence,
            isMentorExtra: false,
          ));
        } else {
          // Unmatched mentor topic kept in chronological position, tagged mentor extra
          updatedBeats.add(beat.copyWith(
            isMentorExtra: true,
            matchConfidence: null,
            syllabusTopicId: null,
          ));
        }
      }

      updatedChapters.add(chapter.copyWith(beats: updatedBeats));
    }

    return updatedChapters;
  }

  /// Finds the best matching topic from the syllabus for a given beat.
  ({SyllabusTopic topic, double confidence})? _findBestTopicMatch(
    ExtractedBeat beat,
    List<SyllabusTopic> syllabus,
  ) {
    ({SyllabusTopic topic, double confidence})? best;

    for (final topic in syllabus) {
      final score = calculateSimilarity(beat.title, topic.title);
      if (best == null || score > best.confidence) {
        best = (topic: topic, confidence: score);
      }
    }

    return best;
  }

  /// Computes a normalized similarity score (0.0 to 1.0) between a beat title and a syllabus topic.
  /// Uses a 3-layer assessment:
  /// 1. Direct match & substring containment.
  /// 2. Deconstructed sub-clause matching with morphological stemming.
  /// 3. Domain semantic synonym boosts.
  double calculateSimilarity(String beatTitle, String topicTitle) {
    final cleanBeat = _normalize(beatTitle);
    final cleanTopic = _normalize(topicTitle);

    if (cleanBeat.isEmpty || cleanTopic.isEmpty) {
      return 0.0;
    }

    // 1. Exact match
    if (cleanBeat == cleanTopic) {
      return 1.0;
    }

    // Substring containment
    if (cleanBeat.contains(cleanTopic)) {
      return 0.95;
    }
    if (cleanTopic.contains(cleanBeat)) {
      return 0.90;
    }

    // 2. Deconstructed sub-clause assessment with stemming
    final subClauses = _decomposeClauses(topicTitle);
    double maxClauseScore = 0.0;

    final beatStems = _tokenizeAndStem(cleanBeat);

    for (final clause in subClauses) {
      final cleanClause = _normalize(clause);
      final clauseStems = _tokenizeAndStem(cleanClause);
      if (clauseStems.isEmpty) continue;

      final intersection = beatStems.intersection(clauseStems);
      if (intersection.isEmpty) continue;

      final clauseRecall = intersection.length / clauseStems.length;
      final union = beatStems.union(clauseStems);
      final jaccard = intersection.length / union.length;

      // Base score from clause recall
      double clauseScore = clauseRecall >= 0.75
          ? 0.75 + (clauseRecall * 0.15)
          : (jaccard * 0.35) + (clauseRecall * 0.65);

      // Specificity bonus: more intersecting tokens break ties in favor of deeper multi-word matches
      clauseScore += (intersection.length * 0.03);

      if (clauseScore > maxClauseScore) {
        maxClauseScore = clauseScore;
      }
    }

    // 3. Domain semantic synonym boost (for cross-term conceptual equivalents)
    final synonymScore = _computeSynonymScore(cleanBeat, cleanTopic);

    // Combine max clause score and synonym boost
    final bestScore = [maxClauseScore, synonymScore].reduce((a, b) => a > b ? a : b);
    return double.parse(bestScore.clamp(0.0, 1.0).toStringAsFixed(2));
  }

  /// Decomposes composite syllabus topics into sub-clause atoms.
  /// E.g. "Python Syntax: Variables, Conditions, Loops & Functions" ->
  /// ["Python Syntax", "Variables", "Conditions", "Loops", "Functions"]
  /// Also handles distributed head nouns: "List, Dictionary & Set Comprehensions" ->
  /// adds "List Comprehensions", "Dictionary Comprehensions".
  List<String> _decomposeClauses(String topic) {
    final clauses = <String>[topic];
    final parts = topic
        .split(RegExp(r'[:,\/&|]|\band\b'))
        .map((p) => p.trim())
        .where((p) => p.length > 2)
        .toList();

    clauses.addAll(parts);

    // If the last part has a trailing head noun (e.g. "Set Comprehensions"),
    // distribute it across earlier single-word adjectives (e.g. "List Comprehensions")
    if (parts.length >= 2) {
      final lastWords = parts.last.split(' ');
      if (lastWords.length >= 2) {
        final headNoun = lastWords.sublist(1).join(' ');
        for (int i = 0; i < parts.length - 1; i++) {
          final p = parts[i];
          if (!p.contains(' ')) {
            clauses.add('$p $headNoun');
          }
        }
      }
    }

    return clauses;
  }

  /// Computes synonym match boost using the technical domain equivalent dictionary.
  double _computeSynonymScore(String cleanBeat, String cleanTopic) {
    for (final group in _domainEquivalents) {
      final bMatches = group.any((term) => cleanBeat.contains(term));
      final tMatches = group.any((term) => cleanTopic.contains(term));
      if (bMatches && tMatches) {
        return 0.88;
      }
    }
    return 0.0;
  }

  String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Tokenizes and applies lightweight English suffix stemming to normalize word forms.
  Set<String> _tokenizeAndStem(String text) {
    return text
        .split(' ')
        .where((t) => t.length > 1 && !_stopWords.contains(t))
        .map(_stem)
        .where((t) => t.isNotEmpty)
        .toSet();
  }

  /// Lightweight English morphological suffix stemmer.
  /// Normalizes plurals, gerunds, and standard inflections:
  /// - exceptions -> exception
  /// - looping -> loop
  /// - classes -> class
  /// - comprehensions -> comprehension
  /// - dictionaries -> dictionary
  static String _stem(String word) {
    if (word.length <= 3) return word;

    var w = word;

    // Plural ies -> y (dictionaries -> dictionary)
    if (w.endsWith('ies') && w.length > 4) {
      return '${w.substring(0, w.length - 3)}y';
    }

    // es suffixes (classes -> class, branches -> branch, boxes -> box)
    if (w.endsWith('sses')) {
      return w.substring(0, w.length - 2);
    }
    if (w.endsWith('ches') || w.endsWith('shes') || w.endsWith('xes') || w.endsWith('zes')) {
      return w.substring(0, w.length - 2);
    }

    // Standard plural s (loops -> loop, exceptions -> exception)
    if (w.endsWith('s') && !w.endsWith('ss') && !w.endsWith('us') && !w.endsWith('is')) {
      w = w.substring(0, w.length - 1);
    }

    // Gerund ing (looping -> loop, handling -> handl, testing -> test)
    if (w.endsWith('ing') && w.length > 5) {
      w = w.substring(0, w.length - 3);
      if (w.endsWith('dd') || w.endsWith('tt') || w.endsWith('gg') || w.endsWith('pp') || w.endsWith('nn')) {
        w = w.substring(0, w.length - 1);
      }
    }

    // Past tense ed (handled -> handl, sorted -> sort)
    if (w.endsWith('ed') && w.length > 4) {
      w = w.substring(0, w.length - 2);
      if (w.endsWith('dd') || w.endsWith('tt') || w.endsWith('gg') || w.endsWith('pp') || w.endsWith('nn')) {
        w = w.substring(0, w.length - 1);
      }
    }

    return w;
  }
}
