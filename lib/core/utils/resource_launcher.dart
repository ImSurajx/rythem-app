import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/glass_toast.dart';

/// Central utility for opening learning resources directly per design spec:
/// - YouTube links open directly in YouTube / external browser
/// - Webpages open directly in default browser
/// - Multiple links show a minimal frosted resource-selection sheet
/// - Empty resources show a subtle, non-intrusive notification
class ResourceLauncher {
  ResourceLauncher._();

  static List<String> extractUrls(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return [];

    final urlRegex = RegExp(r'https?:\/\/[^\s,;]+', caseSensitive: false);
    final matches = urlRegex.allMatches(trimmed).map((m) => m.group(0)!).toList();

    if (matches.isNotEmpty) {
      return matches;
    }

    // If it looks like a domain without scheme (e.g. youtube.com or flutter.dev)
    final parts = trimmed.split(RegExp(r'[\r\n,;]+')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final results = <String>[];
    for (final part in parts) {
      if (part.startsWith('http://') || part.startsWith('https://')) {
        results.add(part);
      } else if (part.contains('.') && !part.contains(' ')) {
        results.add('https://$part');
      }
    }
    return results.isNotEmpty ? results : (trimmed.isNotEmpty ? [trimmed] : []);
  }

  static bool isYouTube(String url) {
    final lower = url.toLowerCase();
    return lower.contains('youtube.com') || lower.contains('youtu.be');
  }

  static String getDisplayDomain(String url) {
    try {
      final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
      return uri.host.replaceFirst(RegExp(r'^www\.'), '');
    } catch (_) {
      return url;
    }
  }

  /// Opens the resource directly or presents a lightweight picker if multiple resources exist.
  static Future<void> openResource(
    BuildContext context, {
    required String? url,
    String? title,
  }) async {
    HapticFeedback.lightImpact();

    if (url == null || url.trim().isEmpty) {
      _showSubtleNotice(context, 'No learning resource attached to this beat.');
      return;
    }

    final urls = extractUrls(url);

    if (urls.isEmpty) {
      _showSubtleNotice(context, 'No valid resource link found.');
      return;
    }

    if (urls.length == 1) {
      await _launchSingleUrl(context, urls.first);
    } else {
      await _showResourcePickerSheet(context, urls: urls, taskTitle: title);
    }
  }

  static Future<void> _launchSingleUrl(BuildContext context, String rawUrl) async {
    String formattedUrl = rawUrl.trim();
    if (!formattedUrl.startsWith('http://') && !formattedUrl.startsWith('https://')) {
      formattedUrl = 'https://$formattedUrl';
    }

    final uri = Uri.tryParse(formattedUrl);
    if (uri == null) {
      _showSubtleNotice(context, 'Invalid link address.');
      return;
    }

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && context.mounted) {
        // Fallback to platform default
        final fallbackLaunched = await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
        );
        if (!fallbackLaunched && context.mounted) {
          _showSubtleNotice(context, 'Unable to open link.');
        }
      }
    } catch (e) {
      if (context.mounted) {
        _showSubtleNotice(context, 'Unable to open link.');
      }
    }
  }

  static void _showSubtleNotice(BuildContext context, String message) {
    showGlassToast(context, message, icon: Icons.info_outline_rounded);
  }

  static Future<void> _showResourcePickerSheet(
    BuildContext context, {
    required List<String> urls,
    String? taskTitle,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeColors = isDark ? RythemColors.dark : RythemColors.light;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xF0121318) : const Color(0xF2FFFFFF),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0x28FFFFFF) : const Color(0x1F000000),
                    width: 0.8,
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Learning Resources',
                    style: RythemTypography.titleMedium.copyWith(
                      color: themeColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  if (taskTitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      taskTitle,
                      style: RythemTypography.bodySmall.copyWith(
                        color: themeColors.textTertiary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 14),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: urls.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final itemUrl = urls[index];
                      final yt = isYouTube(itemUrl);
                      final domain = getDisplayDomain(itemUrl);

                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          _launchSingleUrl(context, itemUrl);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? const Color(0x20FFFFFF) : const Color(0x12000000),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04),
                                ),
                                child: Icon(
                                  yt ? Icons.play_arrow_rounded : Icons.language_rounded,
                                  size: 16,
                                  color: themeColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      yt ? 'YouTube Video' : domain,
                                      style: RythemTypography.bodyMedium.copyWith(
                                        color: themeColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      itemUrl,
                                      style: RythemTypography.labelSmall.copyWith(
                                        color: themeColors.textTertiary,
                                        fontSize: 10.5,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.open_in_new_rounded,
                                size: 14,
                                color: themeColors.textTertiary,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
