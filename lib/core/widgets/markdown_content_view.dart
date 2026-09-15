import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

/// Lightweight, on-device Markdown parser and renderer that compiles headers,
/// bold tokens, bullet points, inline code tags, and quote blocks without external dependencies.
class MarkdownContentView extends StatelessWidget {
  final String content;
  final bool isDark;
  final RythemColorTokens? themeColors;

  const MarkdownContentView({
    super.key,
    required this.content,
    required this.isDark,
    this.themeColors,
  });

  @override
  Widget build(BuildContext context) {
    final colors = themeColors ?? (isDark ? RythemColors.dark : RythemColors.light);
    final lines = content.split('\n');

    final List<Widget> widgets = [];

    for (int i = 0; i < lines.length; i++) {
      final rawLine = lines[i];
      final trimmed = rawLine.trim();

      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      // 1. Headers (###, ##, #)
      if (trimmed.startsWith('### ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              trimmed.substring(4),
              style: RythemTypography.titleSmall.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        );
      } else if (trimmed.startsWith('## ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Text(
              trimmed.substring(3),
              style: RythemTypography.titleMedium.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
        );
      } else if (trimmed.startsWith('# ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: Text(
              trimmed.substring(2),
              style: RythemTypography.titleLarge.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
          ),
        );
      }
      // 2. Bullet list item (• or - or *)
      else if (trimmed.startsWith('• ') || trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        final bulletText = trimmed.substring(2);
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6, right: 8),
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white70 : Colors.black87,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: _buildRichText(bulletText, colors),
                ),
              ],
            ),
          ),
        );
      }
      // 3. Blockquote (> )
      else if (trimmed.startsWith('> ')) {
        final quoteText = trimmed.substring(2);
        widgets.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
              borderRadius: BorderRadius.circular(8),
              border: Border(
                left: BorderSide(
                  color: isDark ? Colors.white54 : Colors.black54,
                  width: 3,
                ),
              ),
            ),
            child: _buildRichText(quoteText, colors),
          ),
        );
      }
      // 4. Standard Paragraph
      else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _buildRichText(trimmed, colors),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widgets,
    );
  }

  Widget _buildRichText(String raw, RythemColorTokens colors) {
    final spans = <InlineSpan>[];
    final regex = RegExp(r'(\*\*.*?\*\*|`.*?`|[^\*`]+)');
    final matches = regex.allMatches(raw);

    for (final match in matches) {
      final token = match.group(0) ?? '';
      if (token.startsWith('**') && token.endsWith('**') && token.length >= 4) {
        // Bold token
        spans.add(
          TextSpan(
            text: token.substring(2, token.length - 2),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
        );
      } else if (token.startsWith('`') && token.endsWith('`') && token.length >= 2) {
        // Inline code token
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.06),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isDark ? Colors.white24 : Colors.black12,
                  width: 0.8,
                ),
              ),
              child: Text(
                token.substring(1, token.length - 1),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
          ),
        );
      } else {
        // Plain text
        spans.add(
          TextSpan(
            text: token,
            style: TextStyle(
              fontWeight: FontWeight.w400,
              color: colors.textPrimary.withOpacity(0.9),
            ),
          ),
        );
      }
    }

    return Text.rich(
      TextSpan(
        style: RythemTypography.bodySmall.copyWith(
          fontSize: 12,
          height: 1.45,
          color: colors.textPrimary,
        ),
        children: spans,
      ),
    );
  }
}
