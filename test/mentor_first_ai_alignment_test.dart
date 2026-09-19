import 'package:flutter_test/flutter_test.dart';
import 'package:rythem_app/core/ai/ai.dart';
import 'package:rythem_app/core/ingestion/ingestion.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Mentor-First On-Device AI Alignment & Gap Detection Tests', () {
    late SyllabusMatcherService matcher;
    late LocalInferenceService inferenceService;

    setUp(() {
      matcher = SyllabusMatcherService();
      inferenceService = LocalInferenceService(fallbackMatcher: matcher);
    });

    test('Clause deconstruction, stemming & synonym boosts correctly identify compound concepts', () {
      const syntaxTopic = 'Python Syntax: Variables, Conditions, Loops & Functions';
      const oopTopic = 'Basic Object-Oriented Programming';
      const errTopic = 'Exceptions & Error Handling';
      const fileTopic = 'File Handling: CSV, JSON & Text Files';
      const compTopic = 'List, Dictionary & Set Comprehensions';
      const modTopic = 'Modules & Packages';

      // 1. Control flow sub-clauses matched against compound syntax header
      expect(matcher.calculateSimilarity('While Loops in Python', syntaxTopic), greaterThanOrEqualTo(0.85));
      expect(matcher.calculateSimilarity('For Loops', syntaxTopic), greaterThanOrEqualTo(0.85));
      expect(matcher.calculateSimilarity('Introduction to Functions', syntaxTopic), greaterThanOrEqualTo(0.85));
      expect(matcher.calculateSimilarity('If Else Statements in Python', syntaxTopic), greaterThanOrEqualTo(0.85));

      // 2. OOP synonyms & sub-topics matched against Basic OOP
      expect(matcher.calculateSimilarity('Encapsulation in Python', oopTopic), greaterThanOrEqualTo(0.85));
      expect(matcher.calculateSimilarity('Inheritance in Python', oopTopic), greaterThanOrEqualTo(0.85));
      expect(matcher.calculateSimilarity('Building a Complete Student Class', oopTopic), greaterThanOrEqualTo(0.85));
      expect(matcher.calculateSimilarity('Creating Classes & Objects with init', oopTopic), greaterThanOrEqualTo(0.85));

      // 3. Morphological stemming: plural/singular & gerunds
      expect(matcher.calculateSimilarity('Exception Handling in Python', errTopic), greaterThanOrEqualTo(0.90));
      expect(matcher.calculateSimilarity('File Handling in Python', fileTopic), greaterThanOrEqualTo(0.90));
      expect(matcher.calculateSimilarity('List Comprehension', compTopic), greaterThanOrEqualTo(0.90));
      expect(matcher.calculateSimilarity('Modules & Packages in Python', modTopic), greaterThanOrEqualTo(0.95));

      // 4. Genuine mentor bonuses remain below threshold (Mentor Extras)
      expect(matcher.calculateSimilarity('Install VS Code', syntaxTopic), lessThan(SyllabusMatcherService.ambiguousConfidenceThreshold));
      expect(matcher.calculateSimilarity('Install Python on Windows', syntaxTopic), lessThan(SyllabusMatcherService.ambiguousConfidenceThreshold));
      expect(matcher.calculateSimilarity('Pattern Questions in Python', syntaxTopic), lessThan(SyllabusMatcherService.ambiguousConfidenceThreshold));
      expect(matcher.calculateSimilarity('Python Part 2 Announcement', syntaxTopic), lessThan(SyllabusMatcherService.ambiguousConfidenceThreshold));
    });

    test('End-to-End Mentor-First Curriculum Ingestion: Topic Subtraction without mutating mentor sequence', () async {
      final syllabus = [
        const SyllabusTopic(id: 'syl_syntax', title: 'Python Syntax: Variables, Conditions, Loops & Functions'),
        const SyllabusTopic(id: 'syl_ds', title: 'Python Data Structures: Lists, Dictionaries, Sets & Tuples'),
        const SyllabusTopic(id: 'syl_comp', title: 'List, Dictionary & Set Comprehensions'),
        const SyllabusTopic(id: 'syl_file', title: 'File Handling: CSV, JSON & Text Files'),
        const SyllabusTopic(id: 'syl_err', title: 'Exceptions & Error Handling'),
        const SyllabusTopic(id: 'syl_debug', title: 'Debugging'),
        const SyllabusTopic(id: 'syl_log', title: 'Logging'),
        const SyllabusTopic(id: 'syl_mod', title: 'Modules & Packages'),
        const SyllabusTopic(id: 'syl_venv', title: 'Virtual Environments'),
        const SyllabusTopic(id: 'syl_type', title: 'Type Hints'),
        const SyllabusTopic(id: 'syl_oop', title: 'Basic Object-Oriented Programming'),
        const SyllabusTopic(id: 'syl_pytest', title: 'Pytest'),
        const SyllabusTopic(id: 'syl_req', title: 'HTTP Requests with Requests'),
        const SyllabusTopic(id: 'syl_git', title: 'Git & GitHub: Commits, Branches, Pull Requests & READMEs'),
      ];

      // Simulated extracted chapters from Resource 1 (Mentor Alpha)
      final r1Items = [
        'Introduction & Course Overview',
        'Install VS Code',
        'Python Variables & Naming Rules',
        'If Else Statements in Python',
        'While Loops',
        'For Loops',
        'Introduction to Functions',
        'Pattern Questions in Python',
        'Introduction to Lists',
        'List Comprehension',
        'Introduction to Tuples',
        'Introduction to Dictionaries',
        'Dictionary Comprehension',
        'Introduction to Sets',
      ];

      final r1Beats = r1Items.asMap().entries.map((e) {
        return ExtractedBeat(
          title: e.value,
          sourceUrl: 'https://youtube.com/watch?v=r1_v${e.key}',
          timestampSeconds: e.key * 300,
          durationSeconds: 600,
          effortWeight: 1.0,
          sortOrder: e.key,
        );
      }).toList();

      final chapter = ExtractedChapter(
        title: 'Python Fundamentals',
        sortOrder: 0,
        beats: r1Beats,
      );

      // Align R1 against syllabus
      final alignedChapters = matcher.alignCurriculum(
        chapters: [chapter],
        syllabus: syllabus,
      );

      final alignedBeats = alignedChapters.first.beats;

      // 1. Zero-Drop guarantee: all 14 videos present in exact mentor sequence 0..13
      expect(alignedBeats.length, r1Items.length);
      for (int i = 0; i < alignedBeats.length; i++) {
        expect(alignedBeats[i].sortOrder, i);
        expect(alignedBeats[i].title, r1Items[i]);
      }

      // 2. Mentor Extras: 'Install VS Code' and 'Pattern Questions' kept in place
      expect(alignedBeats[1].isMentorExtra, isTrue);
      expect(alignedBeats[1].syllabusTopicId, isNull);
      expect(alignedBeats[7].isMentorExtra, isTrue); // Pattern Questions

      // 3. Topic Subtraction: Topics covered by mentor are satisfied
      final matchedSyllabusIds = alignedBeats
          .where((b) => !b.isMentorExtra && b.syllabusTopicId != null)
          .map((b) => b.syllabusTopicId!)
          .toSet();

      expect(matchedSyllabusIds.contains('syl_syntax'), isTrue);
      expect(matchedSyllabusIds.contains('syl_ds'), isTrue);
      expect(matchedSyllabusIds.contains('syl_comp'), isTrue);

      // 4. Residual Gaps: Uncovered topics accurately identified
      final residualGaps = syllabus.where((s) => !matchedSyllabusIds.contains(s.id)).toList();
      expect(residualGaps.length, 11);
      expect(residualGaps.any((g) => g.id == 'syl_oop'), isTrue);
      expect(residualGaps.any((g) => g.id == 'syl_err'), isTrue);
      expect(residualGaps.any((g) => g.id == 'syl_file'), isTrue);
      expect(residualGaps.any((g) => g.id == 'syl_mod'), isTrue);

      // Now attach Resource 2 (targeting the remaining gaps)
      final r2Items = [
        'Creating Classes & Objects with init',
        'Encapsulation in Python',
        'Inheritance in Python',
        'Exception Handling in Python',
        'File Handling in Python',
        'Modules & Packages in Python',
      ];

      final audit = await inferenceService.auditSubjectResource(
        subjectTitle: 'Python Fundamentals',
        syllabusTopics: residualGaps.map((g) => g.title).toList(),
        videoTitles: r2Items,
      );

      // R2 should cover OOP, Exceptions, File Handling, Modules & Packages
      expect(audit.coveredTopics.length, greaterThanOrEqualTo(4));
      expect(audit.uncoveredGaps.length, lessThan(residualGaps.length));
    });
  });
}
