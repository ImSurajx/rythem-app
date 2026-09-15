import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../database/repositories/app_settings_repository.dart';
import '../models/model_tier.dart';

class DownloadProgress {
  final ModelTier tier;
  final double progress; // 0.0 to 1.0
  final int receivedBytes;
  final int totalBytes;
  final bool isCompleted;
  final String? error;

  const DownloadProgress({
    required this.tier,
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

class ModelDownloadManager {
  static const String _prefActiveModelTierKey = 'active_model_tier';

  final AppSettingsRepository _settingsRepo;
  final http.Client _client;
  String? _overrideModelsDir;

  http.Client? _activeDownloadClient;
  ModelTier? _downloadingTier;
  final ValueNotifier<DownloadProgress?> downloadProgressNotifier =
      ValueNotifier<DownloadProgress?>(null);

  ModelDownloadManager({
    AppSettingsRepository? settingsRepo,
    http.Client? client,
    String? overrideModelsDir,
  })  : _settingsRepo = settingsRepo ?? AppSettingsRepository(),
        _client = client ?? http.Client(),
        _overrideModelsDir = overrideModelsDir;

  @visibleForTesting
  void setOverrideModelsDir(String? dir) {
    _overrideModelsDir = dir;
  }

  bool get isDownloading => _downloadingTier != null;
  ModelTier? get downloadingTier => _downloadingTier;

  Future<String> getModelsDirectory() async {
    if (_overrideModelsDir != null) {
      final dir = Directory(_overrideModelsDir!);
      if (!dir.existsSync()) {
        await dir.create(recursive: true);
      }
      return _overrideModelsDir!;
    }
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final modelsDir = Directory(p.join(appDir.path, 'models'));
      if (!modelsDir.existsSync()) {
        await modelsDir.create(recursive: true);
      }
      return modelsDir.path;
    } catch (_) {
      // Fallback for widget test environments where path_provider channel is unmocked
      return p.join(Directory.systemTemp.path, 'rythem_models');
    }
  }

  Future<String?> getModelFilePath(ModelTier tier) async {
    if (tier == ModelTier.fallback) return null;
    final info = ModelInfo.forTier(tier);
    final dir = await getModelsDirectory();
    return p.join(dir, info.filename);
  }

  Future<bool> isModelDownloaded(ModelTier tier) async {
    if (tier == ModelTier.fallback) return true;
    final path = await getModelFilePath(tier);
    if (path == null) return false;
    final file = File(path);
    if (!file.existsSync()) return false;
    // Verify file size is reasonably non-empty (> 10MB)
    final size = await file.length();
    return size > 10 * 1024 * 1024;
  }

  Future<int> getDownloadedSize(ModelTier tier) async {
    if (tier == ModelTier.fallback) return 0;
    final path = await getModelFilePath(tier);
    if (path == null) return 0;
    final file = File(path);
    if (!file.existsSync()) return 0;
    return await file.length();
  }

  Future<ModelTier> getActiveTier() async {
    final raw = await _settingsRepo.getSetting(_prefActiveModelTierKey);
    final tier = ModelInfo.fromString(raw).tier;
    if (tier == ModelTier.fallback) {
      return ModelTier.fallback;
    }
    // Verify file exists on device
    final downloaded = await isModelDownloaded(tier);
    if (!downloaded) {
      await setActiveTier(ModelTier.fallback);
      return ModelTier.fallback;
    }
    return tier;
  }

  Future<void> setActiveTier(ModelTier tier) async {
    if (tier != ModelTier.fallback) {
      final downloaded = await isModelDownloaded(tier);
      if (!downloaded) {
        throw StateError('Model for tier $tier is not downloaded.');
      }
    }
    await _settingsRepo.setSetting(_prefActiveModelTierKey, tier.name);
  }

  static const String _prefPendingTierKey = 'model_download_pending_tier';
  static const String _prefPendingBytesKey = 'model_download_bytes';

  /// Returns the tier of any pending/interrupted download saved in settings.
  Future<ModelTier?> getPendingDownloadTier() async {
    final raw = await _settingsRepo.getSetting(_prefPendingTierKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final tier = ModelTier.values.firstWhere((t) => t.name == raw);
      if (tier != ModelTier.fallback) {
        final isCompleted = await isModelDownloaded(tier);
        if (!isCompleted) return tier;
      }
    } catch (_) {}
    return null;
  }

  /// Returns bytes downloaded so far for an incomplete .part file.
  Future<int> getPartialDownloadedBytes(ModelTier tier) async {
    if (tier == ModelTier.fallback) return 0;
    final finalPath = await getModelFilePath(tier);
    if (finalPath == null) return 0;
    final partFile = File('$finalPath.part');
    if (partFile.existsSync()) {
      return await partFile.length();
    }
    return 0;
  }

  /// Automatically resumes any pending or interrupted model download.
  Future<void> resumePendingDownload({
    void Function(DownloadProgress progress)? onProgress,
  }) async {
    if (_downloadingTier != null) return;
    final pendingTier = await getPendingDownloadTier();
    if (pendingTier != null) {
      try {
        await downloadModel(pendingTier, onProgress: onProgress);
      } catch (e) {
        debugPrint('Notice: Background model resume interrupted: $e');
      }
    }
  }

  Future<void> downloadModel(
    ModelTier tier, {
    void Function(DownloadProgress progress)? onProgress,
  }) async {
    if (tier == ModelTier.fallback) return;
    if (_downloadingTier != null) {
      throw StateError('Another download is already in progress: $_downloadingTier');
    }

    final info = ModelInfo.forTier(tier);
    final finalPath = await getModelFilePath(tier);
    if (finalPath == null) return;
    final partPath = '$finalPath.part';
    final partFile = File(partPath);

    _downloadingTier = tier;
    final downloadClient = _client;
    _activeDownloadClient = downloadClient;

    // Reset progress and clear any previous errors
    downloadProgressNotifier.value = DownloadProgress(
      tier: tier,
      progress: 0.0,
      receivedBytes: 0,
      totalBytes: info.sizeBytes,
    );

    IOSink? sink;
    try {
      int existingBytes = 0;
      if (partFile.existsSync()) {
        existingBytes = await partFile.length();
      }

      final request = http.Request('GET', Uri.parse(info.downloadUrl));
      request.headers['User-Agent'] = 'Rythem-App/1.0.0';

      // If we have an existing partial download, request Range from existing offset
      if (existingBytes > 0) {
        request.headers['Range'] = 'bytes=$existingBytes-';
      }

      await _settingsRepo.setSetting(_prefPendingTierKey, tier.name);
      await _settingsRepo.setSetting(_prefPendingBytesKey, existingBytes.toString());

      final response = await downloadClient.send(request);
      if (response.statusCode >= 400 && response.statusCode != 416) {
        throw HttpException(
            'Failed to download model asset. HTTP Status: ${response.statusCode}');
      }

      // If HTTP 416 (Range Not Satisfiable), file might already be complete or corrupted
      if (response.statusCode == 416) {
        if (existingBytes >= info.sizeBytes) {
          final finalFile = File(finalPath);
          if (finalFile.existsSync()) await finalFile.delete();
          await partFile.rename(finalPath);
          await _settingsRepo.removeSetting(_prefPendingTierKey);
          await _settingsRepo.removeSetting(_prefPendingBytesKey);
          await setActiveTier(tier);
          final completed = DownloadProgress(
            tier: tier,
            progress: 1.0,
            receivedBytes: existingBytes,
            totalBytes: existingBytes,
            isCompleted: true,
          );
          downloadProgressNotifier.value = completed;
          onProgress?.call(completed);
          return;
        } else {
          // Invalidate corrupted partial file and restart
          await partFile.delete();
          existingBytes = 0;
          return await downloadModel(tier, onProgress: onProgress);
        }
      }

      final bool isPartial = response.statusCode == 206;
      int receivedBytes;
      int totalBytes;

      if (isPartial) {
        sink = partFile.openWrite(mode: FileMode.append);
        receivedBytes = existingBytes;
        totalBytes = existingBytes + (response.contentLength ?? (info.sizeBytes - existingBytes));
      } else {
        if (partFile.existsSync()) {
          await partFile.delete();
        }
        sink = partFile.openWrite(mode: FileMode.write);
        receivedBytes = 0;
        totalBytes = response.contentLength ?? info.sizeBytes;
      }

      int lastCheckpointBytes = receivedBytes;

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        final progress = totalBytes > 0 ? (receivedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;

        final update = DownloadProgress(
          tier: tier,
          progress: progress,
          receivedBytes: receivedBytes,
          totalBytes: totalBytes,
        );
        downloadProgressNotifier.value = update;
        onProgress?.call(update);

        // Checkpoint periodically to survive background suspension / crash
        if (receivedBytes - lastCheckpointBytes > 2 * 1024 * 1024) {
          lastCheckpointBytes = receivedBytes;
          unawaited(_settingsRepo.setSetting(_prefPendingBytesKey, receivedBytes.toString()));
        }
      }

      await sink.flush();
      await sink.close();
      sink = null;

      // Rename .part file to final .gguf file
      final finalFile = File(finalPath);
      if (finalFile.existsSync()) {
        await finalFile.delete();
      }
      await partFile.rename(finalPath);

      // Clear checkpoint
      await _settingsRepo.removeSetting(_prefPendingTierKey);
      await _settingsRepo.removeSetting(_prefPendingBytesKey);

      final completedUpdate = DownloadProgress(
        tier: tier,
        progress: 1.0,
        receivedBytes: totalBytes,
        totalBytes: totalBytes,
        isCompleted: true,
      );
      downloadProgressNotifier.value = completedUpdate;
      onProgress?.call(completedUpdate);

      // Automatically set as active tier upon first successful download
      await setActiveTier(tier);
    } catch (e) {
      if (sink != null) {
        try {
          await sink.flush();
          await sink.close();
        } catch (_) {}
      }

      final errorUpdate = DownloadProgress(
        tier: tier,
        progress: 0.0,
        receivedBytes: 0,
        totalBytes: info.sizeBytes,
        error: e.toString(),
      );
      downloadProgressNotifier.value = errorUpdate;
      onProgress?.call(errorUpdate);
      rethrow;
    } finally {
      _downloadingTier = null;
      _activeDownloadClient = null;
    }
  }

  void cancelDownload() {
    if (_activeDownloadClient != null) {
      _activeDownloadClient!.close();
      _activeDownloadClient = null;
    }
    if (_downloadingTier != null) {
      final cancelledTier = _downloadingTier!;
      _downloadingTier = null;
      downloadProgressNotifier.value = DownloadProgress(
        tier: cancelledTier,
        progress: 0.0,
        receivedBytes: 0,
        totalBytes: 0,
        error: 'Download cancelled',
      );
    }
  }

  Future<void> deleteModel(ModelTier tier) async {
    if (tier == ModelTier.fallback) return;

    final path = await getModelFilePath(tier);
    if (path != null) {
      final file = File(path);
      if (file.existsSync()) {
        await file.delete();
      }
      final partFile = File('$path.part');
      if (partFile.existsSync()) {
        await partFile.delete();
      }
    }

    final active = await getActiveTier();
    if (active == tier) {
      await setActiveTier(ModelTier.fallback);
    }
  }
}
