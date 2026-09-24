import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:rythem_app/core/updater/updater.dart';

class MockReleaseHttpClient extends http.BaseClient {
  final int statusCode;
  final String body;

  MockReleaseHttpClient({required this.statusCode, required this.body});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bytes = utf8.encode(body);
    return http.StreamedResponse(
      Stream.value(bytes),
      statusCode,
      contentLength: bytes.length,
      headers: {'content-type': 'application/json'},
    );
  }
}

class MockDownloadHttpClient extends http.BaseClient {
  final List<List<int>> chunks;
  final int totalLength;

  MockDownloadHttpClient({required this.chunks, required this.totalLength});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream.fromIterable(chunks),
      200,
      contentLength: totalLength,
      headers: {'content-type': 'application/vnd.android.package-archive'},
    );
  }
}

void main() {
  group('GithubReleaseService Check For Update Tests', () {
    const mockReleaseJson = '''
{
  "tag_name": "v1.0.2",
  "name": "Rythem v1.0.2 - Revision Shelf & Performance",
  "body": "## What's Changed\\n* Feature 5: Clean Revision Shelf\\n* Performance optimizations",
  "published_at": "2026-09-24T20:00:00Z",
  "html_url": "https://github.com/ImSurajx/rythem-app/releases/tag/v1.0.2",
  "assets": [
    {
      "name": "rythem-app-v1.0.2.apk",
      "browser_download_url": "https://github.com/ImSurajx/rythem-app/releases/download/v1.0.2/rythem-app-v1.0.2.apk",
      "size": 25600000
    },
    {
      "name": "source.tar.gz",
      "browser_download_url": "https://github.com/ImSurajx/rythem-app/archive/v1.0.2.tar.gz",
      "size": 1024000
    }
  ]
}
''';

    test('parses release details and detects newer version', () async {
      final mockClient = MockReleaseHttpClient(
        statusCode: 200,
        body: mockReleaseJson,
      );
      final service = GithubReleaseService(client: mockClient);

      final info = await service.checkForUpdate(
        currentVersionOverride: '1.0.1+2',
      );

      expect(info.isUpdateAvailable, isTrue);
      expect(info.tagName, 'v1.0.2');
      expect(info.title, 'Rythem v1.0.2 - Revision Shelf & Performance');
      expect(info.releaseNotes, contains('Feature 5: Clean Revision Shelf'));
      expect(info.apkUrl, contains('rythem-app-v1.0.2.apk'));
      expect(info.apkName, 'rythem-app-v1.0.2.apk');
      expect(info.apkSizeBytes, 25600000);
      expect(info.formattedSize, '24.4 MB');
      expect(info.formattedDate, 'Sep 24, 2026');

      service.close();
    });

    test('detects up to date when current version is equal or newer', () async {
      final mockClient = MockReleaseHttpClient(
        statusCode: 200,
        body: mockReleaseJson,
      );
      final service = GithubReleaseService(client: mockClient);

      final infoSame = await service.checkForUpdate(
        currentVersionOverride: '1.0.2',
      );
      expect(infoSame.isUpdateAvailable, isFalse);

      final infoNewer = await service.checkForUpdate(
        currentVersionOverride: '1.0.3',
      );
      expect(infoNewer.isUpdateAvailable, isFalse);

      service.close();
    });

    test('handles API errors gracefully', () async {
      final mockClient = MockReleaseHttpClient(
        statusCode: 404,
        body: 'Not Found',
      );
      final service = GithubReleaseService(client: mockClient);

      expect(
        () => service.checkForUpdate(),
        throwsA(isA<Exception>()),
      );

      service.close();
    });
  });

  group('GithubReleaseService Streaming APK Download Tests', () {
    test('streams chunked download and verifies written file', () async {
      final tempDir = Directory.systemTemp.createTempSync('rythem_updater_test');
      final targetPath = '${tempDir.path}/test-update.apk';

      final chunk1 = List.filled(512 * 1024, 65); // 512 KB
      final chunk2 = List.filled(512 * 1024, 66); // 512 KB
      final total = chunk1.length + chunk2.length;

      final mockClient = MockDownloadHttpClient(
        chunks: [chunk1, chunk2],
        totalLength: total,
      );
      final service = GithubReleaseService(client: mockClient);

      final progressEvents = <UpdateDownloadProgress>[];
      await for (final p in service.downloadApkStream(
        apkUrl: 'https://example.com/test.apk',
        savePath: targetPath,
        client: mockClient,
      )) {
        progressEvents.add(p);
      }

      expect(progressEvents.isNotEmpty, isTrue);
      expect(progressEvents.first.status, DownloadStatus.connecting);

      final last = progressEvents.last;
      expect(last.status, DownloadStatus.completed);
      expect(last.bytesDownloaded, total);
      expect(last.totalBytes, total);
      expect(last.percentage, 100);

      // Verify file exists on disk with exact size
      final writtenFile = File(targetPath);
      expect(writtenFile.existsSync(), isTrue);
      expect(writtenFile.lengthSync(), total);

      // Cleanup
      tempDir.deleteSync(recursive: true);
      service.close();
    });

    test('supports cancellation and cleans up partial file', () async {
      final tempDir = Directory.systemTemp.createTempSync('rythem_updater_cancel_test');
      final targetPath = '${tempDir.path}/test-cancel.apk';

      final chunk1 = List.filled(256 * 1024, 65);
      final chunk2 = List.filled(256 * 1024, 66);

      bool cancelRequested = false;

      final mockClient = MockDownloadHttpClient(
        chunks: [chunk1, chunk2],
        totalLength: chunk1.length + chunk2.length,
      );
      final service = GithubReleaseService(client: mockClient);

      int callCount = 0;

      final progressEvents = <UpdateDownloadProgress>[];
      await for (final p in service.downloadApkStream(
        apkUrl: 'https://example.com/test.apk',
        savePath: targetPath,
        client: mockClient,
        isCancelled: () {
          callCount++;
          if (callCount >= 2) {
            cancelRequested = true;
            return true;
          }
          return false;
        },
      )) {
        progressEvents.add(p);
      }

      expect(cancelRequested, isTrue);
      expect(progressEvents.last.status, DownloadStatus.cancelled);

      // Verify partial file was cleaned up
      final file = File(targetPath);
      expect(file.existsSync(), isFalse);

      tempDir.deleteSync(recursive: true);
      service.close();
    });
  });
}
