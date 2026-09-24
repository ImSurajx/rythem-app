import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/download_progress.dart';
import '../models/semver.dart';
import '../models/update_release_info.dart';

class GithubReleaseService {
  static const String defaultOwner = 'ImSurajx';
  static const String defaultRepo = 'rythem-app';
  static const String currentAppVersion = '1.0.2-pre+3';

  final http.Client _httpClient;

  GithubReleaseService({http.Client? client})
      : _httpClient = client ?? http.Client();

  void close() {
    _httpClient.close();
  }

  /// Checks GitHub releases API for the latest published release or pre-release.
  Future<UpdateReleaseInfo> checkForUpdate({
    String? owner,
    String? repo,
    String? currentVersionOverride,
    http.Client? client,
  }) async {
    final effectiveOwner = owner ?? defaultOwner;
    final effectiveRepo = repo ?? defaultRepo;
    final httpClient = client ?? _httpClient;

    final url = Uri.parse(
      'https://api.github.com/repos/$effectiveOwner/$effectiveRepo/releases?per_page=5',
    );

    try {
      final response = await httpClient.get(
        url,
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'Rythem-App-Updater',
        },
      );

      if (response.statusCode != 200) {
        throw Exception(
          'GitHub API returned status ${response.statusCode}: ${response.body}',
        );
      }

      final decoded = jsonDecode(response.body);
      final Map<String, dynamic> data;
      if (decoded is List) {
        if (decoded.isEmpty) {
          throw Exception('No releases found.');
        }
        data = decoded.firstWhere(
          (item) => item is Map<String, dynamic> && item['draft'] != true,
          orElse: () => decoded.first as Map<String, dynamic>,
        ) as Map<String, dynamic>;
      } else if (decoded is Map<String, dynamic>) {
        data = decoded;
      } else {
        throw Exception('Unexpected response format.');
      }

      final isPrerelease = data['prerelease'] == true;
      final tagName = data['tag_name']?.toString() ?? 'v0.0.0';
      final title = data['name']?.toString() ?? tagName;
      final body = data['body']?.toString() ?? 'No release notes provided.';
      final htmlUrl = data['html_url']?.toString() ??
          'https://github.com/$effectiveOwner/$effectiveRepo/releases';
      final publishedAtStr = data['published_at']?.toString();
      final publishedAt = publishedAtStr != null
          ? DateTime.tryParse(publishedAtStr)
          : null;

      // Locate APK asset among release assets
      String? apkUrl;
      String? apkName;
      int? apkSizeBytes;

      final assets = data['assets'] as List?;
      if (assets != null) {
        for (final item in assets) {
          if (item is Map<String, dynamic>) {
            final name = item['name']?.toString().toLowerCase() ?? '';
            if (name.endsWith('.apk')) {
              apkUrl = item['browser_download_url']?.toString();
              apkName = item['name']?.toString();
              apkSizeBytes = int.tryParse(item['size']?.toString() ?? '');
              break;
            }
          }
        }
      }

      final remoteSemVer = SemVer.parse(tagName);
      final currentSemVer =
          SemVer.parse(currentVersionOverride ?? currentAppVersion);
      final isUpdateAvailable = remoteSemVer > currentSemVer;

      return UpdateReleaseInfo(
        tagName: tagName,
        semVer: remoteSemVer,
        title: title,
        releaseNotes: body,
        publishedAt: publishedAt,
        apkUrl: apkUrl,
        apkName: apkName,
        apkSizeBytes: apkSizeBytes,
        htmlUrl: htmlUrl,
        isUpdateAvailable: isUpdateAvailable,
        currentVersion: currentSemVer,
        isPrerelease: isPrerelease,
      );
    } catch (e) {
      debugPrint('Update check failed: $e');
      rethrow;
    }
  }

  /// Downloads the APK file in chunks, emitting live progress and speed metrics.
  Stream<UpdateDownloadProgress> downloadApkStream({
    required String apkUrl,
    required String savePath,
    http.Client? client,
    bool Function()? isCancelled,
  }) async* {
    final httpClient = client ?? _httpClient;

    yield const UpdateDownloadProgress(status: DownloadStatus.connecting);

    final file = File(savePath);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    if (file.existsSync()) {
      file.deleteSync();
    }

    try {
      final request = http.Request('GET', Uri.parse(apkUrl));
      request.headers['User-Agent'] = 'Rythem-App-Updater';

      final response = await httpClient.send(request);
      if (response.statusCode != 200) {
        yield UpdateDownloadProgress(
          status: DownloadStatus.error,
          errorMessage: 'Server returned HTTP ${response.statusCode}',
        );
        return;
      }

      final totalBytes = response.contentLength ?? 0;
      int bytesDownloaded = 0;
      final sink = file.openWrite();

      final stopwatch = Stopwatch()..start();
      DateTime lastEmitTime = DateTime.now();
      int lastBytes = 0;

      try {
        await for (final chunk in response.stream) {
          if (isCancelled != null && isCancelled()) {
            await sink.flush();
            await sink.close();
            if (file.existsSync()) file.deleteSync();
            yield const UpdateDownloadProgress(status: DownloadStatus.cancelled);
            return;
          }

          sink.add(chunk);
          bytesDownloaded += chunk.length;

          final now = DateTime.now();
          final elapsedSinceLastEmit = now.difference(lastEmitTime).inMilliseconds;

          // Throttle progress updates to ~100ms or on completion
          if (elapsedSinceLastEmit >= 100 ||
              (totalBytes > 0 && bytesDownloaded >= totalBytes)) {
            final deltaBytes = bytesDownloaded - lastBytes;
            final speed = elapsedSinceLastEmit > 0
                ? ((deltaBytes / elapsedSinceLastEmit) * 1000).toInt()
                : 0;

            lastEmitTime = now;
            lastBytes = bytesDownloaded;

            yield UpdateDownloadProgress(
              status: DownloadStatus.downloading,
              bytesDownloaded: bytesDownloaded,
              totalBytes: totalBytes,
              speedBytesPerSec: speed,
              savedFilePath: savePath,
            );
          }
        }

        await sink.flush();
        await sink.close();
        stopwatch.stop();

        yield UpdateDownloadProgress(
          status: DownloadStatus.completed,
          bytesDownloaded: bytesDownloaded,
          totalBytes: totalBytes > 0 ? totalBytes : bytesDownloaded,
          savedFilePath: savePath,
        );
      } catch (e) {
        try {
          await sink.close();
        } catch (_) {}
        rethrow;
      }
    } catch (e) {
      yield UpdateDownloadProgress(
        status: DownloadStatus.error,
        errorMessage: e.toString(),
      );
    }
  }
}
