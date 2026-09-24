import 'semver.dart';

class UpdateReleaseInfo {
  final String tagName;
  final SemVer semVer;
  final String title;
  final String releaseNotes;
  final DateTime? publishedAt;
  final String? apkUrl;
  final String? apkName;
  final int? apkSizeBytes;
  final String htmlUrl;
  final bool isUpdateAvailable;
  final SemVer currentVersion;
  final bool isPrerelease;

  const UpdateReleaseInfo({
    required this.tagName,
    required this.semVer,
    required this.title,
    required this.releaseNotes,
    this.publishedAt,
    this.apkUrl,
    this.apkName,
    this.apkSizeBytes,
    required this.htmlUrl,
    required this.isUpdateAvailable,
    required this.currentVersion,
    this.isPrerelease = false,
  });

  /// Human-readable file size (e.g. "24.5 MB", "1.2 GB").
  String get formattedSize {
    final bytes = apkSizeBytes;
    if (bytes == null || bytes <= 0) return 'Unknown size';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Formatted publication date (e.g. "Sep 24, 2026").
  String get formattedDate {
    final date = publishedAt;
    if (date == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final monthStr = months[date.month - 1];
    return '$monthStr ${date.day}, ${date.year}';
  }
}
