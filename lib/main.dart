import 'package:flutter/material.dart';
import 'core/theme/colors.dart';
import 'core/theme/theme.dart';
import 'core/theme/typography.dart';
import 'core/widgets/widgets.dart';

void main() {
  runApp(const RythemApp());
}

class RythemApp extends StatelessWidget {
  const RythemApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rythem',
      debugShowCheckedModeBanner: false,
      theme: RythemTheme.darkTheme,
      home: const DesignSystemShowcaseScreen(),
    );
  }
}

class DesignSystemShowcaseScreen extends StatefulWidget {
  const DesignSystemShowcaseScreen({super.key});

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
    return Scaffold(
      backgroundColor: RythemColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Brand Header
              Center(
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Text(
                      'RYTHEM',
                      style: RythemTypography.brandLogo,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'beats over clocks • felt, not measured',
                      style: RythemTypography.labelSmall.copyWith(
                        color: RythemColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // Theme Spec Section
              Text(
                'MONOCHROME LIQUID GLASS',
                style: RythemTypography.labelSmall,
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
                          style: RythemTypography.titleLarge,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: RythemColors.glassBorder,
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            'STAGE 2',
                            style: RythemTypography.labelSmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Progress is measured strictly in discrete beats and milestone bars. Zero clocks, zero stopwatches, zero minutes.',
                      style: RythemTypography.bodyMedium,
                    ),
                    const SizedBox(height: 20),

                    // Milestone Progress Bar (No time, pure ratio)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$_activeBeats of $_totalBeats beats completed',
                          style: RythemTypography.labelSmall.copyWith(
                            color: RythemColors.textSecondary,
                          ),
                        ),
                        Text(
                          'In Flow',
                          style: RythemTypography.labelSmall.copyWith(
                            color: Colors.white,
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
                style: RythemTypography.labelSmall,
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
                        color: Colors.white.withOpacity(0.1),
                        border: Border.all(
                          color: RythemColors.glassBorderHighlight,
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
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
                            style: RythemTypography.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tap to advance milestone progress',
                            style: RythemTypography.bodyMedium.copyWith(
                              fontSize: 12,
                              color: RythemColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: RythemColors.textTertiary,
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
                        color: Colors.white.withOpacity(0.04),
                        border: Border.all(
                          color: RythemColors.glassBorder,
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.circle_outlined,
                        color: RythemColors.textTertiary,
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
                              color: RythemColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Queued in mentor chronological order',
                            style: RythemTypography.bodyMedium.copyWith(
                              fontSize: 12,
                              color: RythemColors.textTertiary,
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
                style: RythemTypography.labelSmall,
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
