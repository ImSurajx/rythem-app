enum DownloadStatus {
  idle,
  connecting,
  downloading,
  completed,
  cancelled,
  error,
}

class UpdateDownloadProgress {
  final DownloadStatus status;
  final int bytesDownloaded;
  final int totalBytes;
  final int speedBytesPerSec;
  final String? savedFilePath;
  final String? errorMessage;

  const UpdateDownloadProgress({
    this.status = DownloadStatus.idle,
    this.bytesDownloaded = 0,
    this.totalBytes = 0,
    this.speedBytesPerSec = 0,
    this.savedFilePath,
    this.errorMessage,
  });

  double get progress {
    if (totalBytes <= 0) return 0.0;
    return (bytesDownloaded / totalBytes).clamp(0.0, 1.0);
  }

  int get percentage => (progress * 100).toInt();

  bool get isCompleted => status == DownloadStatus.completed;
  bool get isDownloading => status == DownloadStatus.downloading;
  bool get hasError => status == DownloadStatus.error;

  String get formattedSpeed {
    if (speedBytesPerSec <= 0) return '';
    if (speedBytesPerSec < 1024 * 1024) {
      return '${(speedBytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(speedBytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  String get formattedProgress {
    final downloadedMB = (bytesDownloaded / (1024 * 1024)).toStringAsFixed(1);
    if (totalBytes <= 0) {
      return '$downloadedMB MB';
    }
    final totalMB = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
    return '$downloadedMB / $totalMB MB';
  }
}
