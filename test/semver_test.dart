import 'package:flutter_test/flutter_test.dart';
import 'package:rythem_app/core/updater/models/semver.dart';

void main() {
  group('SemVer Parsing Tests', () {
    test('parses simple semver strings', () {
      final v1 = SemVer.parse('1.0.0');
      expect(v1.major, 1);
      expect(v1.minor, 0);
      expect(v1.patch, 0);
      expect(v1.build, 0);

      final v2 = SemVer.parse('v1.2.3');
      expect(v2.major, 1);
      expect(v2.minor, 2);
      expect(v2.patch, 3);
      expect(v2.build, 0);
    });

    test('parses semver with build number', () {
      final v = SemVer.parse('1.0.1+2');
      expect(v.major, 1);
      expect(v.minor, 0);
      expect(v.patch, 1);
      expect(v.build, 2);
      expect(v.toString(), '1.0.1+2');
      expect(v.displayTag, 'v1.0.1');
    });

    test('parses semver with pre-release tags', () {
      final v = SemVer.parse('v2.0.0-beta.1+15');
      expect(v.major, 2);
      expect(v.minor, 0);
      expect(v.patch, 0);
      expect(v.build, 15);
    });

    test('handles partial versions gracefully', () {
      final v = SemVer.parse('2.1');
      expect(v.major, 2);
      expect(v.minor, 1);
      expect(v.patch, 0);
      expect(v.build, 0);
    });
  });

  group('SemVer Comparison Tests', () {
    test('compares patch versions', () {
      final v1 = SemVer.parse('1.0.1');
      final v2 = SemVer.parse('1.0.2');
      expect(v1 < v2, isTrue);
      expect(v2 > v1, isTrue);
      expect(v1 <= v2, isTrue);
      expect(v2 >= v1, isTrue);
    });

    test('compares minor versions', () {
      final v1 = SemVer.parse('1.0.9');
      final v2 = SemVer.parse('1.1.0');
      expect(v1 < v2, isTrue);
      expect(v2 > v1, isTrue);
    });

    test('compares major versions', () {
      final v1 = SemVer.parse('1.9.9');
      final v2 = SemVer.parse('2.0.0');
      expect(v1 < v2, isTrue);
      expect(v2 > v1, isTrue);
    });

    test('compares build numbers when version numbers are identical', () {
      final v1 = SemVer.parse('1.0.1+2');
      final v2 = SemVer.parse('1.0.1+3');
      expect(v1 < v2, isTrue);
      expect(v2 > v1, isTrue);
    });

    test('version with higher patch beats version with higher build', () {
      final v1 = SemVer.parse('1.0.1+99');
      final v2 = SemVer.parse('1.0.2+1');
      expect(v1 < v2, isTrue);
      expect(v2 > v1, isTrue);
    });

    test('handles equality and prefix tolerance', () {
      final v1 = SemVer.parse('v1.0.1');
      final v2 = SemVer.parse('1.0.1');
      expect(v1 == v2, isTrue);
      expect(v1.compareTo(v2), 0);
    });
  });
}
