import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/updater/updater.dart';
import '../../../core/widgets/glass_button.dart';

class UpdateModalSheet extends StatefulWidget {
  final UpdateReleaseInfo releaseInfo;
  final GithubReleaseService releaseService;
  final NativeInstallerService installerService;

  const UpdateModalSheet({
    super.key,
    required this.releaseInfo,
    required this.releaseService,
    required this.installerService,
  });

  static Future<void> show(
    BuildContext context, {
    required UpdateReleaseInfo releaseInfo,
    GithubReleaseService? releaseService,
    NativeInstallerService? installerService,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => UpdateModalSheet(
        releaseInfo: releaseInfo,
        releaseService: releaseService ?? GithubReleaseService(),
        installerService: installerService ?? NativeInstallerService(),
      ),
    );
  }

  @override
  State<UpdateModalSheet> createState() => _UpdateModalSheetState();
}

class _UpdateModalSheetState extends State<UpdateModalSheet> {
  UpdateDownloadProgress _progress = const UpdateDownloadProgress();
  bool _isDownloading = false;
  bool _isCancelled = false;
  String? _downloadedFilePath;
  bool _canInstallPackages = true;
  StreamSubscription<UpdateDownloadProgress>? _downloadSub;

  @override
  void initState() {
    super.initState();
    _checkInstallPermission();
  }

  @override
  void dispose() {
    _downloadSub?.cancel();
    super.dispose();
  }

  Future<void> _checkInstallPermission() async {
    final canInstall = await widget.installerService.canRequestPackageInstalls();
    if (mounted) {
      setState(() => _canInstallPackages = canInstall);
    }
  }

  Future<void> _startDownload() async {
    final apkUrl = widget.releaseInfo.apkUrl;
    if (apkUrl == null) {
      // Fallback: no direct APK asset found, open release in browser
      await widget.installerService.openReleasePage(widget.releaseInfo.htmlUrl);
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isDownloading = true;
      _isCancelled = false;
      _progress = const UpdateDownloadProgress(status: DownloadStatus.connecting);
    });

    try {
      final tempDir = await getTemporaryDirectory();
      final apkName = widget.releaseInfo.apkName ?? 'rythem-update.apk';
      final savePath = '${tempDir.path}/$apkName';

      final stream = widget.releaseService.downloadApkStream(
        apkUrl: apkUrl,
        savePath: savePath,
        isCancelled: () => _isCancelled,
      );

      _downloadSub = stream.listen(
        (progress) {
          if (mounted) {
            setState(() {
              _progress = progress;
              if (progress.status == DownloadStatus.completed) {
                _isDownloading = false;
                _downloadedFilePath = progress.savedFilePath;
              } else if (progress.status == DownloadStatus.error ||
                  progress.status == DownloadStatus.cancelled) {
                _isDownloading = false;
              }
            });

            // Automatically trigger install on completion
            if (progress.status == DownloadStatus.completed &&
                progress.savedFilePath != null) {
              _triggerInstall(progress.savedFilePath!);
            }
          }
        },
        onError: (err) {
          if (mounted) {
            setState(() {
              _isDownloading = false;
              _progress = UpdateDownloadProgress(
                status: DownloadStatus.error,
                errorMessage: err.toString(),
              );
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _progress = UpdateDownloadProgress(
            status: DownloadStatus.error,
            errorMessage: e.toString(),
          );
        });
      }
    }
  }

  void _cancelDownload() {
    HapticFeedback.lightImpact();
    setState(() {
      _isCancelled = true;
      _isDownloading = false;
    });
    _downloadSub?.cancel();
  }

  Future<void> _triggerInstall(String filePath) async {
    HapticFeedback.mediumImpact();
    if (!kIsWeb && Platform.isAndroid && !_canInstallPackages) {
      // Request install permission first
      await widget.installerService.openInstallPermissionSettings();
      // Re-check after user returns
      await _checkInstallPermission();
      if (!_canInstallPackages) return;
    }

    await widget.installerService.installApk(
      filePath,
      fallbackUrl: widget.releaseInfo.htmlUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = isDark ? RythemColors.dark : RythemColors.light;
    final isUpdate = widget.releaseInfo.isUpdateAvailable;
    const warningColor = Color(0xFFF59E0B);
    const successColor = Color(0xFF10B981);
    const errorColor = Color(0xFFEF4444);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xE6141418) : const Color(0xF5F7F7FA),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: colors.glassBorder),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.of(context).padding.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textTertiary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Top Header: Label & Status Chip
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'SOFTWARE UPDATE',
                  style: RythemTypography.labelSmall.copyWith(
                    color: colors.textSecondary,
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isUpdate
                        ? warningColor.withOpacity(0.18)
                        : successColor.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isUpdate
                          ? warningColor.withOpacity(0.4)
                          : successColor.withOpacity(0.4),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    isUpdate ? 'UPDATE AVAILABLE' : 'UP TO DATE',
                    style: RythemTypography.labelSmall.copyWith(
                      color: isUpdate ? warningColor : successColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 9.5,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Version Bump Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0x14FFFFFF) : const Color(0x0A000000),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.glassBorder),
              ),
              child: Row(
                children: [
                  _buildVersionBadge(
                    label: widget.releaseInfo.currentVersion.displayTag,
                    isCurrent: true,
                    colors: colors,
                  ),
                  if (isUpdate) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: colors.actionPrimary,
                      ),
                    ),
                    _buildVersionBadge(
                      label: widget.releaseInfo.tagName,
                      isCurrent: false,
                      colors: colors,
                    ),
                  ],
                  const Spacer(),
                  if (widget.releaseInfo.apkSizeBytes != null)
                    Text(
                      widget.releaseInfo.formattedSize,
                      style: RythemTypography.labelSmall.copyWith(
                        color: colors.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Title & Publish Date
            Text(
              widget.releaseInfo.title,
              style: RythemTypography.titleMedium.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            if (widget.releaseInfo.formattedDate.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Published ${widget.releaseInfo.formattedDate}',
                style: RythemTypography.bodySmall.copyWith(
                  color: colors.textTertiary,
                  fontSize: 11,
                ),
              ),
            ],
            const SizedBox(height: 12),

            // Changelog Section
            Text(
              "WHAT'S NEW",
              style: RythemTypography.labelSmall.copyWith(
                color: colors.textSecondary,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(maxHeight: 160),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0x0DFFFFFF) : const Color(0x06000000),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.glassBorder.withOpacity(0.5)),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: _buildChangelogContent(
                  widget.releaseInfo.releaseNotes,
                  colors,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Download Progress Section
            if (_isDownloading || _progress.status == DownloadStatus.downloading) ...[
              _buildProgressSection(colors),
              const SizedBox(height: 16),
            ],

            // Android Permission Warning (if needed)
            if (!kIsWeb &&
                Platform.isAndroid &&
                !_canInstallPackages &&
                isUpdate &&
                !_isDownloading) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: warningColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: warningColor.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: warningColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Install unknown apps permission is required for APK updates.',
                        style: RythemTypography.bodySmall.copyWith(
                          color: colors.textPrimary,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        await widget.installerService
                            .openInstallPermissionSettings();
                        await _checkInstallPermission();
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Grant',
                        style: TextStyle(
                          color: warningColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Error display
            if (_progress.hasError) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: errorColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: errorColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 16,
                      color: errorColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _progress.errorMessage ?? 'Download failed. Please try again.',
                        style: RythemTypography.bodySmall.copyWith(
                          color: errorColor,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Action Buttons
            _buildActionButtons(isUpdate, colors),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionBadge({
    required String label,
    required bool isCurrent,
    required RythemThemeColors colors,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isCurrent
            ? colors.textTertiary.withOpacity(0.15)
            : colors.actionPrimary.withOpacity(0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCurrent
              ? colors.textTertiary.withOpacity(0.3)
              : colors.actionPrimary.withOpacity(0.4),
        ),
      ),
      child: Text(
        label,
        style: RythemTypography.labelSmall.copyWith(
          color: isCurrent ? colors.textSecondary : colors.actionPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildChangelogContent(String notes, RythemThemeColors colors) {
    final lines = notes.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) return const SizedBox(height: 4);

        if (trimmed.startsWith('#')) {
          final headerText = trimmed.replaceAll(RegExp(r'^#+\s*'), '');
          return Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 2),
            child: Text(
              headerText,
              style: RythemTypography.bodySmall.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          );
        }

        if (trimmed.startsWith('*') || trimmed.startsWith('-')) {
          final bulletText = trimmed.substring(1).trim();
          return Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• ',
                  style: TextStyle(color: colors.actionPrimary, fontSize: 12),
                ),
                Expanded(
                  child: Text(
                    bulletText,
                    style: RythemTypography.bodySmall.copyWith(
                      color: colors.textSecondary,
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(
            trimmed,
            style: RythemTypography.bodySmall.copyWith(
              color: colors.textSecondary,
              fontSize: 11,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildProgressSection(RythemThemeColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _progress.status == DownloadStatus.connecting
                  ? 'Connecting...'
                  : 'Downloading ${_progress.percentage}%',
              style: RythemTypography.labelSmall.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
            Text(
              _progress.formattedProgress,
              style: RythemTypography.labelSmall.copyWith(
                color: colors.textTertiary,
                fontSize: 10.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: _progress.status == DownloadStatus.connecting
                ? null
                : _progress.progress,
            backgroundColor: colors.textTertiary.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation<Color>(colors.actionPrimary),
            minHeight: 6,
          ),
        ),
        if (_progress.formattedSpeed.isNotEmpty) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              _progress.formattedSpeed,
              style: RythemTypography.labelSmall.copyWith(
                color: colors.textTertiary.withOpacity(0.8),
                fontSize: 10,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons(bool isUpdate, RythemThemeColors colors) {
    if (!isUpdate) {
      return Row(
        children: [
          Expanded(
            child: GlassButton(
              onPressed: () => Navigator.of(context).pop(),
              label: 'Done',
              variant: GlassButtonVariant.secondary,
            ),
          ),
        ],
      );
    }

    if (_isDownloading) {
      return Row(
        children: [
          Expanded(
            child: GlassButton(
              onPressed: _cancelDownload,
              icon: Icons.close_rounded,
              label: 'Cancel Download',
              variant: GlassButtonVariant.secondary,
            ),
          ),
        ],
      );
    }

    if (_downloadedFilePath != null) {
      return Row(
        children: [
          Expanded(
            child: GlassButton(
              onPressed: () => _triggerInstall(_downloadedFilePath!),
              icon: Icons.system_update_rounded,
              label: 'Install Now',
              variant: GlassButtonVariant.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GlassButton(
              onPressed: () => Navigator.of(context).pop(),
              label: 'Later',
              variant: GlassButtonVariant.secondary,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: GlassButton(
            onPressed: _startDownload,
            icon: Icons.download_rounded,
            label: 'Download & Install',
            variant: GlassButtonVariant.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GlassButton(
            onPressed: () =>
                widget.installerService.openReleasePage(widget.releaseInfo.htmlUrl),
            icon: Icons.open_in_browser_rounded,
            label: 'GitHub',
            variant: GlassButtonVariant.secondary,
          ),
        ),
      ],
    );
  }
}
