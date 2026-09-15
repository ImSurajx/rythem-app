import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/ai/models/model_tier.dart';
import '../../core/ai/services/model_download_manager.dart';
import '../../core/database/repositories/app_settings_repository.dart';
import '../../core/pacing/models/study_intensity.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/glass_button.dart';
import '../../core/widgets/glass_card.dart';

/// First-launch onboarding wizard introducing core Rythem principles:
/// 1. Philosophy: "Beats Over Clocks"
/// 2. Pacing Dilution: Guilt-free adaptation
/// 3. Offline AI: Local mentor without data leakage
/// 4. Calibration: Setting your initial rhythm
///
/// NOTE: Per user specifications, no re-run option is provided in settings.
class OnboardingWizardScreen extends StatefulWidget {
  final VoidCallback onFinished;
  final Future<void> Function()? onSeedDemoTrack;

  const OnboardingWizardScreen({
    super.key,
    required this.onFinished,
    this.onSeedDemoTrack,
  });

  @override
  State<OnboardingWizardScreen> createState() => _OnboardingWizardScreenState();
}

class _OnboardingWizardScreenState extends State<OnboardingWizardScreen> {
  final PageController _pageController = PageController();
  final AppSettingsRepository _settingsRepo = AppSettingsRepository();
  final ModelDownloadManager _modelManager = ModelDownloadManager();

  int _currentPage = 0;
  static const int _totalPages = 4;

  // Calibration choices
  String _selectedCadencePreset = 'balanced'; // accelerated, balanced, gentle
  final ModelTier _selectedModelTier = ModelTier.compact;
  bool _downloadAiNow = false;
  bool _isSeeding = false;

  Future<void> _completeOnboarding() async {
    if (widget.onSeedDemoTrack != null) {
      setState(() => _isSeeding = true);
    }
    HapticFeedback.mediumImpact();

    try {
      // 1. Save onboarding completion flag in SQLite
      await _settingsRepo.setSetting('has_completed_onboarding', 'true');
      final schedule = switch (_selectedCadencePreset) {
        'accelerated' => WeeklyStudySchedule.custom(
            monday: StudyIntensity.intense,
            tuesday: StudyIntensity.intense,
            wednesday: StudyIntensity.intense,
            thursday: StudyIntensity.intense,
            friday: StudyIntensity.intense,
            saturday: StudyIntensity.light,
            sunday: StudyIntensity.light,
          ),
        'gentle' => WeeklyStudySchedule.custom(
            monday: StudyIntensity.light,
            tuesday: StudyIntensity.rest,
            wednesday: StudyIntensity.light,
            thursday: StudyIntensity.rest,
            friday: StudyIntensity.light,
            saturday: StudyIntensity.light,
            sunday: StudyIntensity.rest,
          ),
        _ => WeeklyStudySchedule.defaultSchedule(),
      };
      await _settingsRepo.setSetting('study_intensity_schedule', schedule.encode());
      await _settingsRepo.setSetting('preferred_model_tier', _selectedModelTier.name);

      // 2. Seed initial starter track if requested
      if (widget.onSeedDemoTrack != null) {
        await widget.onSeedDemoTrack!();
      }

      // 3. Initiate background model download if user opted in
      if (_downloadAiNow) {
        _modelManager.downloadModel(_selectedModelTier).catchError((e) {
          debugPrint('Onboarding AI download background err: $e');
        });
      }
    } catch (e) {
      debugPrint('Error saving onboarding: $e');
    } finally {
      if (mounted) {
        if (_isSeeding) {
          setState(() => _isSeeding = false);
        }
        widget.onFinished();
      }
    }
  }

  void _nextPage() {
    HapticFeedback.lightImpact();
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _previousPage() {
    HapticFeedback.lightImpact();
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeColors = isDark ? RythemColors.dark : RythemColors.light;

    return Scaffold(
      backgroundColor: themeColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Back & Skip
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage > 0)
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: themeColors.textSecondary),
                      onPressed: _previousPage,
                    )
                  else
                    const SizedBox(width: 40),
                  // Progress Dots
                  Row(
                    children: List.generate(_totalPages, (index) {
                      final isActive = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 24 : 8,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isActive
                              ? themeColors.textPrimary
                              : (isDark ? Colors.white24 : Colors.black12),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  ),
                  // Skip button
                  if (_currentPage < _totalPages - 1)
                    TextButton(
                      onPressed: _completeOnboarding,
                      child: Text(
                        'Skip',
                        style: RythemTypography.labelSmall.copyWith(
                          color: themeColors.textTertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 40),
                ],
              ),
            ),

            // Main Content Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildPhilosophyPage(themeColors, isDark),
                  _buildPacingPage(themeColors, isDark),
                  _buildAiMentorPage(themeColors, isDark),
                  _buildCalibrationPage(themeColors, isDark),
                ],
              ),
            ),

            // Bottom Navigation Action
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: _isSeeding
                  ? Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: themeColors.textPrimary,
                      ),
                    )
                  : GlassButton(
                      label: _currentPage == _totalPages - 1
                          ? 'Enter Daily Flow'
                          : 'Continue',
                      icon: _currentPage == _totalPages - 1
                          ? Icons.offline_bolt_outlined
                          : Icons.arrow_forward_rounded,
                      onPressed: _nextPage,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Page 1: Philosophy ("Beats Over Clocks")
  Widget _buildPhilosophyPage(RythemColorTokens themeColors, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
              border: Border.all(
                color: isDark ? Colors.white24 : Colors.black12,
              ),
            ),
            child: Icon(
              Icons.radio_button_checked_rounded,
              size: 40,
              color: themeColors.textPrimary,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'BEATS OVER CLOCKS',
            style: RythemTypography.labelSmall.copyWith(
              color: themeColors.textTertiary,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Mastery is felt,\nnot measured.',
            style: RythemTypography.displayMedium.copyWith(
              color: themeColors.textPrimary,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.0,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Traditional learning apps punish you with ticking stopwatches, arbitrary minute goals, and broken streaks.\n\nRythem breaks long-form playlists and deep curricula into discrete, atomic Beats. You focus solely on the next concept in rhythm.',
            style: RythemTypography.bodyLarge.copyWith(
              color: themeColors.textSecondary,
              height: 1.5,
              fontSize: 14.5,
            ),
          ),
        ],
      ),
    );
  }

  // Page 2: Pacing Dilution (Guilt-Free Math)
  Widget _buildPacingPage(RythemColorTokens themeColors, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
              border: Border.all(
                color: isDark ? Colors.white24 : Colors.black12,
              ),
            ),
            child: Icon(
              Icons.water_drop_outlined,
              size: 40,
              color: themeColors.textPrimary,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'AUTOMATIC PACING DILUTION',
            style: RythemTypography.labelSmall.copyWith(
              color: themeColors.textTertiary,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Life happens.\nZero backlog guilt.',
            style: RythemTypography.displayMedium.copyWith(
              color: themeColors.textPrimary,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.0,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Miss a day? Rythem never shames you with red overdue banners. Instead, remaining effort is gently diluted across your target calendar window.\n\nWhen you finish today\'s mission, the Evening Unlock activates. Close the app and rest guilt-free.',
            style: RythemTypography.bodyLarge.copyWith(
              color: themeColors.textSecondary,
              height: 1.5,
              fontSize: 14.5,
            ),
          ),
        ],
      ),
    );
  }

  // Page 3: Offline AI Mentor
  Widget _buildAiMentorPage(RythemColorTokens themeColors, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
              border: Border.all(
                color: isDark ? Colors.white24 : Colors.black12,
              ),
            ),
            child: Icon(
              Icons.psychology_outlined,
              size: 40,
              color: themeColors.textPrimary,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'LOCAL ON-DEVICE AI',
            style: RythemTypography.labelSmall.copyWith(
              color: themeColors.textTertiary,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Private Mentor.\nZero cloud telemetry.',
            style: RythemTypography.displayMedium.copyWith(
              color: themeColors.textPrimary,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.0,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Rythem embeds on-device quantized models for intelligent pacing diagnosis, concept breakdowns, and test queries. All inference runs directly on your smartphone silicon.',
            style: RythemTypography.bodyLarge.copyWith(
              color: themeColors.textSecondary,
              height: 1.5,
              fontSize: 14.5,
            ),
          ),
          const SizedBox(height: 20),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Checkbox(
                  value: _downloadAiNow,
                  activeColor: themeColors.textPrimary,
                  checkColor: isDark ? Colors.black : Colors.white,
                  onChanged: (val) {
                    setState(() => _downloadAiNow = val ?? false);
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Download Compact Model in Background',
                        style: RythemTypography.titleSmall.copyWith(
                          color: themeColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '~1.2 GB • Recommended for mobile silicon',
                        style: RythemTypography.bodySmall.copyWith(
                          color: themeColors.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Page 4: Calibration
  Widget _buildCalibrationPage(RythemColorTokens themeColors, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
              border: Border.all(
                color: isDark ? Colors.white24 : Colors.black12,
              ),
            ),
            child: Icon(
              Icons.speed_rounded,
              size: 40,
              color: themeColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'SET YOUR WEEKLY RHYTHM',
            style: RythemTypography.labelSmall.copyWith(
              color: themeColors.textTertiary,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Calibrate your study cadence.',
            style: RythemTypography.displayMedium.copyWith(
              color: themeColors.textPrimary,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.0,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Choose your baseline weekly intensity. Daily goals dynamically calculate from this schedule, customizable for every weekday in Settings.',
            style: RythemTypography.bodyMedium.copyWith(
              color: themeColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // Weekly Rhythm Cadence Options
          _buildPillOption(
            label: 'Accelerated Rhythm',
            sublabel: 'High intensity daily focus sessions across the week',
            badge: '34 beats / wk',
            isSelected: _selectedCadencePreset == 'accelerated',
            themeColors: themeColors,
            isDark: isDark,
            onSelect: () => setState(() => _selectedCadencePreset = 'accelerated'),
          ),
          const SizedBox(height: 10),
          _buildPillOption(
            label: 'Balanced Rhythm • Recommended',
            sublabel: 'Sustainable weekday focus with relaxed weekends',
            badge: '22 beats / wk',
            isSelected: _selectedCadencePreset == 'balanced',
            themeColors: themeColors,
            isDark: isDark,
            onSelect: () => setState(() => _selectedCadencePreset = 'balanced'),
          ),
          const SizedBox(height: 10),
          _buildPillOption(
            label: 'Gentle Rhythm',
            sublabel: 'Low cognitive load suited for unpredictable schedules',
            badge: '8 beats / wk',
            isSelected: _selectedCadencePreset == 'gentle',
            themeColors: themeColors,
            isDark: isDark,
            onSelect: () => setState(() => _selectedCadencePreset = 'gentle'),
          ),

          const SizedBox(height: 24),
          Text(
            'A starter track ("Deep Learning & Neural Flow") will be initialized for your first session.',
            style: RythemTypography.labelSmall.copyWith(
              color: themeColors.textTertiary,
              fontSize: 10.5,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillOption({
    required String label,
    required String sublabel,
    required String badge,
    required bool isSelected,
    required RythemColorTokens themeColors,
    required bool isDark,
    required VoidCallback onSelect,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onSelect();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08))
              : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03)),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? themeColors.textPrimary
                : (isDark ? themeColors.glassBorder : const Color(0x14000000)),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: isSelected ? themeColors.textPrimary : themeColors.textTertiary,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        label,
                        style: RythemTypography.titleSmall.copyWith(
                          color: themeColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: RythemTypography.labelSmall.copyWith(
                            color: isSelected ? themeColors.textPrimary : themeColors.textTertiary,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sublabel,
                    style: RythemTypography.bodySmall.copyWith(
                      color: themeColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
