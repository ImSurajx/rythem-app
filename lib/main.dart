import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/colors.dart';
import 'core/theme/theme.dart';
import 'core/theme/typography.dart';
import 'core/widgets/widgets.dart';

void main() {
  runApp(const RythemApp());
}

class RythemApp extends StatefulWidget {
  const RythemApp({super.key});

  @override
  State<RythemApp> createState() => _RythemAppState();
}

class _RythemAppState extends State<RythemApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rythem',
      debugShowCheckedModeBanner: false,
      theme: RythemTheme.lightTheme,
      darkTheme: RythemTheme.darkTheme,
      themeMode: _themeMode,
      home: DesignSystemShowcaseScreen(
        isDark: _themeMode == ThemeMode.dark,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}

class DesignSystemShowcaseScreen extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;

  const DesignSystemShowcaseScreen({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
  });

  @override
  State<DesignSystemShowcaseScreen> createState() => _DesignSystemShowcaseScreenState();
}

class _DesignSystemShowcaseScreenState extends State<DesignSystemShowcaseScreen> {
  double _milestoneProgress = 0.45;
  int _activeBeats = 3;
  final int _totalBeats = 7;

  void _incrementProgress() {
    setState(() {
      if (_activeBeats < _totalBeats) {
        _activeBeats++;
      } else {
        _activeBeats = 1;
      }
      _milestoneProgress = _activeBeats / _totalBeats;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeColors = RythemColors.of(context);
    final isDark = themeColors.isDark;

    return Scaffold(
      backgroundColor: themeColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar with Brand & Theme Mode Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(width: 44), // balance centering
                  Column(
                    children: [
                      const SizedBox(height: 6),
                      Text(
                        'RYTHEM',
                        style: RythemTypography.brandLogo.copyWith(
                          color: themeColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'beats over clocks • felt, not measured',
                        style: RythemTypography.labelSmall.copyWith(
                          color: themeColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  // Dark / Light Glass Toggle
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      widget.onToggleTheme();
                    },
                    child: GlassContainer(
                      width: 44,
                      height: 44,
                      borderRadius: BorderRadius.circular(22),
                      padding: EdgeInsets.zero,
                      child: Center(
                        child: Icon(
                          isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                          color: themeColors.textPrimary,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Theme Spec Section
              Text(
                isDark ? 'MONOCHROME LIQUID GLASS (DARK)' : 'APPLE CONTROL CENTER GLASS (LIGHT)',
                style: RythemTypography.labelSmall.copyWith(
                  color: themeColors.textTertiary,
                ),
              ),
              const SizedBox(height: 12),

              // Hero Glass Card
              GlassCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Flow Milestone',
                          style: RythemTypography.titleLarge.copyWith(
                            color: themeColors.textPrimary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.08)
                                : Colors.black.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark
                                  ? themeColors.glassBorder
                                  : const Color(0x14000000),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            isDark ? 'DARK GLASS' : 'LIGHT GLASS',
                            style: RythemTypography.labelSmall.copyWith(
                              color: themeColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Progress is measured strictly in discrete beats and milestone bars. Zero clocks, zero stopwatches, zero minutes.',
                      style: RythemTypography.bodyMedium.copyWith(
                        color: themeColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Milestone Progress Bar (No time, pure ratio)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$_activeBeats of $_totalBeats beats completed',
                          style: RythemTypography.labelSmall.copyWith(
                            color: themeColors.textSecondary,
                          ),
                        ),
                        Text(
                          'In Flow',
                          style: RythemTypography.labelSmall.copyWith(
                            color: themeColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    GlassProgressBar(
                      progress: _milestoneProgress,
                      height: 8,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Interactive Beat Tile Cards
              Text(
                'TACTILE BEAT TILES',
                style: RythemTypography.labelSmall.copyWith(
                  color: themeColors.textTertiary,
                ),
              ),
              const SizedBox(height: 12),

              GlassCard(
                onTap: _incrementProgress,
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? Colors.white.withOpacity(0.10)
                            : Colors.black.withOpacity(0.07),
                        border: Border.all(
                          color: isDark
                              ? themeColors.glassBorderHighlight
                              : const Color(0x20000000),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.check,
                        color: themeColors.textPrimary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Interactive Milestone Beat',
                            style: RythemTypography.titleMedium.copyWith(
                              color: themeColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tap to advance milestone progress',
                            style: RythemTypography.bodyMedium.copyWith(
                              fontSize: 12,
                              color: themeColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: themeColors.textTertiary,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              GlassCard(
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? Colors.white.withOpacity(0.04)
                            : Colors.black.withOpacity(0.03),
                        border: Border.all(
                          color: isDark
                              ? themeColors.glassBorder
                              : const Color(0x12000000),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.circle_outlined,
                        color: themeColors.textTertiary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pending Beat',
                            style: RythemTypography.titleMedium.copyWith(
                              color: themeColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Queued in mentor chronological order',
                            style: RythemTypography.bodyMedium.copyWith(
                              fontSize: 12,
                              color: themeColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Button Variants Section
              Text(
                'TACTILE BUTTON CONTROLS',
                style: RythemTypography.labelSmall.copyWith(
                  color: themeColors.textTertiary,
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: GlassButton(
                      label: 'Advance Beat',
                      variant: GlassButtonVariant.primary,
                      onPressed: _incrementProgress,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GlassButton(
                      label: 'Secondary',
                      variant: GlassButtonVariant.secondary,
                      onPressed: () {},
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              GlassButton(
                label: 'Ghost Translucent Action',
                variant: GlassButtonVariant.ghost,
                width: double.infinity,
                onPressed: () {},
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
