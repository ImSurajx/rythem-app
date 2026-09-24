class SemVer implements Comparable<SemVer> {
  final int major;
  final int minor;
  final int patch;
  final int build;
  final String raw;

  const SemVer({
    required this.major,
    required this.minor,
    required this.patch,
    this.build = 0,
    required this.raw,
  });

  /// Parses a version string like "v1.0.1+2", "1.0.2", "2.0.0-beta.1+5".
  factory SemVer.parse(String input) {
    final raw = input.trim();
    var clean = raw;
    if (clean.startsWith('v') || clean.startsWith('V')) {
      clean = clean.substring(1).trim();
    }

    int buildNum = 0;
    if (clean.contains('+')) {
      final parts = clean.split('+');
      clean = parts[0];
      if (parts.length > 1) {
        buildNum = int.tryParse(parts[1].trim()) ?? 0;
      }
    }

    // Strip any pre-release tag like "-beta", "-rc.1"
    if (clean.contains('-')) {
      clean = clean.split('-')[0];
    }

    final segments = clean.split('.');
    final major = segments.isNotEmpty ? int.tryParse(segments[0]) ?? 0 : 0;
    final minor = segments.length > 1 ? int.tryParse(segments[1]) ?? 0 : 0;
    final patch = segments.length > 2 ? int.tryParse(segments[2]) ?? 0 : 0;

    return SemVer(
      major: major,
      minor: minor,
      patch: patch,
      build: buildNum,
      raw: raw,
    );
  }

  @override
  int compareTo(SemVer other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);
    return build.compareTo(other.build);
  }

  bool operator <(SemVer other) => compareTo(other) < 0;
  bool operator <=(SemVer other) => compareTo(other) <= 0;
  bool operator >(SemVer other) => compareTo(other) > 0;
  bool operator >=(SemVer other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SemVer &&
        other.major == major &&
        other.minor == minor &&
        other.patch == patch &&
        other.build == build;
  }

  @override
  int get hashCode => Object.hash(major, minor, patch, build);

  @override
  String toString() {
    final base = '$major.$minor.$patch';
    return build > 0 ? '$base+$build' : base;
  }

  /// Formatted display representation (e.g. "v1.0.2").
  String get displayTag => 'v$major.$minor.$patch';
}
