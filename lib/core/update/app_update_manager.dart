import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateProgress {
  final double progress; // 0.0 to 1.0
  final int receivedBytes;
  final int totalBytes;
  final bool isCompleted;
  final String? error;

  const AppUpdateProgress({
    required this.progress,
    required this.receivedBytes,
    required this.totalBytes,
    this.isCompleted = false,
    this.error,
  });

  String get formattedProgress => '${(progress * 100).toInt()}%';
  String get formattedReceived => '${(receivedBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  String get formattedTotal => '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class AppUpdateInfo {
  final String tagName;
  final String releaseName;
  final String? releaseNotes;
  final String? apkDownloadUrl;
  final int? apkSizeBytes;
  final String htmlUrl;
  final bool isUpdateAvailable;

  const AppUpdateInfo({
    required this.tagName,
    required this.releaseName,
    this.releaseNotes,
    this.apkDownloadUrl,
    this.apkSizeBytes,
    required this.htmlUrl,
    required this.isUpdateAvailable,
  });

  String get formattedSize => apkSizeBytes != null && apkSizeBytes! > 0
      ? '${(apkSizeBytes! / (1024 * 1024)).toStringAsFixed(1)} MB'
      : '';
}

class AppUpdateManager {
  static const String currentVersion = 'v1.1.7';
  static const String _releasesApiUrl = 'https://api.github.com/repos/ImSurajx/rythem-app/releases/latest';
  static const MethodChannel _platformChannel = MethodChannel('com.rythem.rythem_app/storage_permission');

  static AppUpdateManager? _instance;
  static AppUpdateManager get instance => _instance ??= AppUpdateManager._internal();

  final http.Client _client;

  AppUpdateManager._internal({http.Client? client}) : _client = client ?? http.Client();

  factory AppUpdateManager({http.Client? client}) {
    if (client != null) {
      return AppUpdateManager._internal(client: client);
    }
    return instance;
  }

  final ValueNotifier<AppUpdateInfo?> updateInfoNotifier = ValueNotifier<AppUpdateInfo?>(null);
  final ValueNotifier<AppUpdateProgress?> updateProgressNotifier = ValueNotifier<AppUpdateProgress?>(null);
  final ValueNotifier<bool> isCheckingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String?> downloadedApkPathNotifier = ValueNotifier<String?>(null);

  http.Client? _activeDownloadClient;
  bool _isCancelled = false;

  /// Compares two semver tags (e.g., 'v1.1.0-Stable' vs 'v1.2.0').
  /// Returns true if [remoteTag] is newer than [localTag].
  static bool isNewerVersion(String remoteTag, String localTag) {
    try {
      final remoteClean = _cleanVersionString(remoteTag);
      final localClean = _cleanVersionString(localTag);

      final remoteParts = remoteClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final localParts = localClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      while (remoteParts.length < 3) {
        remoteParts.add(0);
      }
      while (localParts.length < 3) {
        localParts.add(0);
      }

      for (int i = 0; i < 3; i++) {
        if (remoteParts[i] > localParts[i]) return true;
        if (remoteParts[i] < localParts[i]) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static String _cleanVersionString(String tag) {
    var v = tag.trim();
    if (v.startsWith('v') || v.startsWith('V')) {
      v = v.substring(1);
    }
    final dashIdx = v.indexOf('-');
    if (dashIdx != -1) {
      v = v.substring(0, dashIdx);
    }
    final plusIdx = v.indexOf('+');
    if (plusIdx != -1) {
      v = v.substring(0, plusIdx);
    }
    return v;
  }

  /// Checks GitHub Releases API for the latest version.
  Future<AppUpdateInfo?> checkForUpdates() async {
    isCheckingNotifier.value = true;
    try {
      final response = await _client.get(
        Uri.parse(_releasesApiUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'Rythem-App',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return null;
      }

      final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = data['tag_name'] as String? ?? '';
      final releaseName = data['name'] as String? ?? tagName;
      final body = data['body'] as String?;
      final htmlUrl = data['html_url'] as String? ?? 'https://github.com/ImSurajx/rythem-app/releases';

      String? apkUrl;
      int? apkSize;
      final assets = data['assets'] as List<dynamic>? ?? [];
      for (final asset in assets) {
        if (asset is Map<String, dynamic>) {
          final name = (asset['name'] as String? ?? '').toLowerCase();
          if (name.endsWith('.apk')) {
            apkUrl = asset['browser_download_url'] as String?;
            apkSize = asset['size'] as int?;
            break;
          }
        }
      }

      final isAvailable = tagName.isNotEmpty && isNewerVersion(tagName, currentVersion);
      final info = AppUpdateInfo(
        tagName: tagName,
        releaseName: releaseName,
        releaseNotes: body,
        apkDownloadUrl: apkUrl,
        apkSizeBytes: apkSize,
        htmlUrl: htmlUrl,
        isUpdateAvailable: isAvailable,
      );

      updateInfoNotifier.value = info;
      return info;
    } catch (e) {
      debugPrint('Error checking for updates: $e');
      return null;
    } finally {
      isCheckingNotifier.value = false;
    }
  }

  /// Downloads the APK from the update info.
  Future<String?> downloadUpdate(AppUpdateInfo info) async {
    final downloadUrl = info.apkDownloadUrl ?? info.htmlUrl;
    if (info.apkDownloadUrl == null) {
      // Fallback: open release page in browser
      await launchUrl(Uri.parse(info.htmlUrl), mode: LaunchMode.externalApplication);
      return null;
    }

    _isCancelled = false;
    _activeDownloadClient = http.Client();

    updateProgressNotifier.value = const AppUpdateProgress(
      progress: 0.0,
      receivedBytes: 0,
      totalBytes: 0,
    );

    try {
      final request = http.Request('GET', Uri.parse(downloadUrl));
      request.headers['User-Agent'] = 'Rythem-App';

      final response = await _activeDownloadClient!.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Download failed with status ${response.statusCode}');
      }

      final totalBytes = response.contentLength ?? (info.apkSizeBytes ?? 0);
      final cacheDir = await getTemporaryDirectory();
      final targetFile = File(p.join(cacheDir.path, 'rythem_update.apk'));
      if (await targetFile.exists()) {
        await targetFile.delete();
      }

      final sink = targetFile.openWrite();
      int receivedBytes = 0;

      await for (final chunk in response.stream) {
        if (_isCancelled) {
          await sink.close();
          if (await targetFile.exists()) {
            await targetFile.delete();
          }
          updateProgressNotifier.value = null;
          return null;
        }

        sink.add(chunk);
        receivedBytes += chunk.length;

        final prog = totalBytes > 0 ? (receivedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;
        updateProgressNotifier.value = AppUpdateProgress(
          progress: prog,
          receivedBytes: receivedBytes,
          totalBytes: totalBytes,
        );
      }

      await sink.close();

      updateProgressNotifier.value = AppUpdateProgress(
        progress: 1.0,
        receivedBytes: receivedBytes,
        totalBytes: totalBytes > 0 ? totalBytes : receivedBytes,
        isCompleted: true,
      );

      downloadedApkPathNotifier.value = targetFile.path;
      return targetFile.path;
    } catch (e) {
      if (!_isCancelled) {
        updateProgressNotifier.value = AppUpdateProgress(
          progress: 0.0,
          receivedBytes: 0,
          totalBytes: 0,
          error: e.toString(),
        );
      }
      return null;
    } finally {
      _activeDownloadClient?.close();
      _activeDownloadClient = null;
    }
  }

  void cancelDownload() {
    _isCancelled = true;
    _activeDownloadClient?.close();
    _activeDownloadClient = null;
    updateProgressNotifier.value = null;
  }

  /// Triggers native APK installation.
  /// Returns 'SUCCESS', 'PERMISSION_REQUESTED', 'FILE_NOT_FOUND', or 'ERROR'.
  Future<String> installDownloadedUpdate() async {
    final apkPath = downloadedApkPathNotifier.value;
    if (apkPath == null || !await File(apkPath).exists()) {
      final info = updateInfoNotifier.value;
      if (info != null) {
        await launchUrl(Uri.parse(info.htmlUrl), mode: LaunchMode.externalApplication);
      }
      return 'FILE_NOT_FOUND';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final result = await _platformChannel.invokeMethod<String>(
          'installApk',
          {'filePath': apkPath},
        );
        return result ?? 'SUCCESS';
      } catch (e) {
        debugPrint('Native APK installer error: $e');
        return 'ERROR: $e';
      }
    } else {
      final info = updateInfoNotifier.value;
      if (info != null) {
        await launchUrl(Uri.parse(info.htmlUrl), mode: LaunchMode.externalApplication);
      }
      return 'UNSUPPORTED_PLATFORM';
    }
  }
}
