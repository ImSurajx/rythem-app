import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/ai/models/model_tier.dart';
import '../../core/ai/services/model_download_manager.dart';
import '../../core/database/repositories/app_settings_repository.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/glass_button.dart';
import '../../core/widgets/glass_error_dialog.dart';
import '../../core/widgets/glass_progress_bar.dart';

/// First-launch onboarding wizard introducing core Rythem principles:
/// 1. Philosophy: "Beats Over Clocks"
/// 2. Self-Paced Freedom: Learn without rigid daily quotas or pressure
/// 3. Offline AI: Mandatory on-device model setup (Compact or Balanced)
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
  static const int _totalPages = 3;

  ModelTier _selectedModelTier = ModelTier.compact;
  bool _compactDownloaded = false;
  bool _balancedDownloaded = false;
  bool _isSeeding = false;
  bool _isCompleting = false;
  bool _hasTriggeredDownload = false;

  @override
  void initState() {
    super.initState();
    _checkDownloadedModels();
    _modelManager.downloadProgressNotifier.addListener(_onDownloadProgress);
  }

  @override
  void dispose() {
    _modelManager.downloadProgressNotifier.removeListener(_onDownloadProgress);
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _checkDownloadedModels() async {
    final c = await _modelManager.isModelDownloaded(ModelTier.compact);
    final b = await _modelManager.isModelDownloaded(ModelTier.balanced);
    if (mounted) {
      setState(() {
        _compactDownloaded = c;
        _balancedDownloaded = b;
      });
    }
  }

  bool _isErrorDialogShowing = false;
  String? _lastDismissedError;

  void _onDownloadProgress() {
    final progress = _modelManager.downloadProgressNotifier.value;
    if (progress == null) return;

    if (progress.error != null && mounted) {
      _showDownloadErrorDialog(
        'Model Download Interrupted',
        'The ${_selectedModelTier.name.toUpperCase()} model download could not be completed. Your partial progress is preserved and will resume seamlessly.',
        progress.error!,
        () => _startDownload(_selectedModelTier),
      );
    }

    if (progress.isCompleted) {
      _checkDownloadedModels();
      _selectedModelTier = progress.tier;
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted && _modelManager.downloadProgressNotifier.value?.isCompleted == true) {
          _modelManager.downloadProgressNotifier.value = null;
          setState(() {});
        }
      });
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _showDownloadErrorDialog(String title, String message, String details, VoidCallback onRetry) {
    if (!mounted || _isErrorDialogShowing || _lastDismissedError == details) return;
    _isErrorDialogShowing = true;
    GlassErrorDialog.show(
      context,
      title: title,
      message: message,
      details: details,
      onDismiss: () {
        _isErrorDialogShowing = false;
        _lastDismissedError = details;
        _modelManager.clearDownloadError();
      },
      onRetry: () {
        _isErrorDialogShowing = false;
        _lastDismissedError = null;
        _modelManager.clearDownloadError();
        onRetry();
      },
    );
  }

  void _startDownload(ModelTier tier) {
    if (_hasTriggeredDownload &&
        _modelManager.isDownloading &&
        _modelManager.downloadingTier == tier) {
      return;
    }
    _hasTriggeredDownload = true;
    HapticFeedback.mediumImpact();
    setState(() => _selectedModelTier = tier);
    _lastDismissedError = null;
    _modelManager.clearDownloadError();

    _modelManager.downloadModel(tier).catchError((e) {
      debugPrint('Onboarding model download failed: $e');
    });
  }

  bool get _hasAnyModelReadyOrDownloading {
    final isDownloading = _modelManager.isDownloading;
    return _compactDownloaded || _balancedDownloaded || isDownloading || _hasTriggeredDownload;
  }

  Future<void> _completeOnboarding() async {
    if (_isCompleting) return;
    _isCompleting = true;

    // Model download is mandatory
    if (!_hasAnyModelReadyOrDownloading) {
      _startDownload(_selectedModelTier);
    }

    if (widget.onSeedDemoTrack != null) {
      setState(() => _isSeeding = true);
    }
    HapticFeedback.mediumImpact();

    try {
      // 1. Save onboarding completion flag in SQLite
      await _settingsRepo.setSetting('has_completed_onboarding', 'true');
      await _settingsRepo.setSetting('preferred_model_tier', _selectedModelTier.name);
      if (_compactDownloaded || _balancedDownloaded) {
        await _settingsRepo.setSetting('active_model_tier', _selectedModelTier.name);
      }

      // 2. Seed initial starter track if requested
      if (widget.onSeedDemoTrack != null) {
        await widget.onSeedDemoTrack!();
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeColors = isDark ? RythemColors.dark : RythemColors.light;

    return Scaffold(
      backgroundColor: themeColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Back & Progress Dots
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage > 0)
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: themeColors.textSecondary,
                      ),
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

                  // Step Indicator & Skip Button
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${_currentPage + 1}/$_totalPages',
                          style: RythemTypography.labelSmall.copyWith(
                            color: themeColors.textTertiary,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      if (_currentPage < _totalPages - 1) ...[
                        const SizedBox(width: 4),
                        TextButton(
                          onPressed: _completeOnboarding,
                          child: Text(
                            'Skip',
                            style: RythemTypography.labelSmall.copyWith(
                              color: themeColors.textTertiary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
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
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? const Color(0xFF3B82F6).withOpacity(0.12) : const Color(0xFF3B82F6).withOpacity(0.08),
              border: Border.all(
                color: isDark ? const Color(0xFF3B82F6).withOpacity(0.3) : const Color(0xFF3B82F6).withOpacity(0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3B82F6).withOpacity(0.15),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              Icons.graphic_eq_rounded,
              size: 36,
              color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'BEATS OVER CLOCKS',
            style: RythemTypography.labelSmall.copyWith(
              color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
              letterSpacing: 1.4,
              fontWeight: FontWeight.w800,
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
          const SizedBox(height: 12),
          Text(
            'Traditional learning apps punish you with ticking stopwatches, arbitrary minute goals, and broken streaks.\n\nRythem breaks long-form playlists and deep curricula into discrete, atomic Beats. You focus solely on the next concept in rhythm.',
            style: RythemTypography.bodyLarge.copyWith(
              color: themeColors.textSecondary,
              height: 1.45,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 18),
          _buildRhythmBeatDemoCard(themeColors, isDark),
        ],
      ),
    );
  }

  Widget _buildRhythmBeatDemoCard(RythemColorTokens themeColors, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14171F) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.waves_rounded,
                size: 15,
                color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
              ),
              const SizedBox(width: 6),
              Text(
                'THE RYTHEM ATOM: BEATS',
                style: RythemTypography.labelSmall.copyWith(
                  color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0x15EF4444) : const Color(0x10EF4444),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer_off_outlined, size: 14, color: Color(0xFFEF4444)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Traditional: Monolithic 4-hour video or giant chapter',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0x1510B981) : const Color(0x1010B981),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bolt_rounded, size: 14, color: Color(0xFF10B981)),
                    const SizedBox(width: 4),
                    Text(
                      'Rythem: Bite-sized Beats in sequence',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF059669),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    _buildMiniBeatChip('⚡ 1.0 beat', 'Core Concept', themeColors, isDark),
                    _buildMiniBeatChip('⚡ 1.5 beats', 'Deep Mechanics', themeColors, isDark),
                    _buildMiniBeatChip('⚡ 0.5 beat', 'Recap & Notes', themeColors, isDark),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBeatChip(String beats, String label, RythemColorTokens themeColors, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            beats,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFFFBBF24),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
              color: themeColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // Page 2: Self-Paced Freedom
  Widget _buildPacingPage(RythemColorTokens themeColors, bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? const Color(0xFF10B981).withOpacity(0.12) : const Color(0xFF10B981).withOpacity(0.08),
              border: Border.all(
                color: isDark ? const Color(0xFF10B981).withOpacity(0.3) : const Color(0xFF10B981).withOpacity(0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withOpacity(0.15),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              Icons.spa_outlined,
              size: 36,
              color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'SELF-PACED FREEDOM',
            style: RythemTypography.labelSmall.copyWith(
              color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
              letterSpacing: 1.4,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Learn at your pace.\nZero target pressure.',
            style: RythemTypography.displayMedium.copyWith(
              color: themeColors.textPrimary,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.0,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No rigid daily quotas, no weekly beat targets, and no overdue shaming. Study when you have momentum, rest when you need to.\n\nEvery task you conquer counts towards your journey and tracks honestly in your personal metrics dashboard.',
            style: RythemTypography.bodyLarge.copyWith(
              color: themeColors.textSecondary,
              height: 1.45,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 18),
          _buildPacingPillarsCard(themeColors, isDark),
        ],
      ),
    );
  }

  Widget _buildPacingPillarsCard(RythemColorTokens themeColors, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14171F) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
        ),
      ),
      child: Column(
        children: [
          _buildPillarRow(
            icon: Icons.bolt_rounded,
            iconColor: const Color(0xFFFBBF24),
            title: 'Atomic Momentum',
            description: '10 mins = 1 Beat. Every single focused increment moves you forward.',
            themeColors: themeColors,
          ),
          const Divider(height: 16, thickness: 0.5),
          _buildPillarRow(
            icon: Icons.self_improvement_rounded,
            iconColor: isDark ? Colors.white : Colors.black87,
            title: 'Zero Guilt or Broken Streaks',
            description: 'Rest when you need to. Momentum is always preserved honestly.',
            themeColors: themeColors,
          ),
          const Divider(height: 16, thickness: 0.5),
          _buildPillarRow(
            icon: Icons.shield_outlined,
            iconColor: const Color(0xFF10B981),
            title: '100% Private & On-Device',
            description: 'Your curricula, checkpoints, and notes stay strictly on your phone.',
            themeColors: themeColors,
          ),
        ],
      ),
    );
  }

  Widget _buildPillarRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required RythemColorTokens themeColors,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 15, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: RythemTypography.titleSmall.copyWith(
                  color: themeColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: RythemTypography.bodySmall.copyWith(
                  color: themeColors.textTertiary,
                  fontSize: 10.5,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Page 3: Mandatory Offline AI Mentor (Both Models Offered)
  Widget _buildAiMentorPage(RythemColorTokens themeColors, bool isDark) {
    final progress = _modelManager.downloadProgressNotifier.value;
    final isDownloading = _modelManager.isDownloading;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                  border: Border.all(
                    color: isDark ? Colors.white24 : Colors.black12,
                  ),
                ),
                child: Icon(
                  Icons.psychology_outlined,
                  size: 32,
                  color: themeColors.textPrimary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LOCAL ON-DEVICE AI',
                      style: RythemTypography.labelSmall.copyWith(
                        color: themeColors.actionPrimary,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Offline Model',
                      style: RythemTypography.titleLarge.copyWith(
                        color: themeColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Private offline intelligence for guidance and concept clarity. Downloads in the background.',
            style: RythemTypography.bodySmall.copyWith(
              color: themeColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),

          // Option 1: Compact Mentor (468.6 MB)
          _buildModelCard(
            tier: ModelTier.compact,
            title: 'Compact Mentor',
            subtitle: 'Qwen 2.5 0.5B Instruct • ${ModelInfo.compact.formattedSize}',
            description: 'Ultra-fast, low battery consumption. Ideal for standard mobile hardware (~600 MB RAM).',
            badge: 'RECOMMENDED',
            isDownloaded: _compactDownloaded,
            isSelected: _selectedModelTier == ModelTier.compact,
            themeColors: themeColors,
            isDark: isDark,
            onSelect: () => setState(() => _selectedModelTier = ModelTier.compact),
          ),
          const SizedBox(height: 12),

          // Option 2: Balanced Mentor (1.04 GB)
          _buildModelCard(
            tier: ModelTier.balanced,
            title: 'Balanced Mentor',
            subtitle: 'Qwen 2.5 1.5B Instruct • ${ModelInfo.balanced.formattedSize}',
            description: 'Deep mathematical reasoning, advanced code explanations, and richer syllabus gap analysis (~1.3 GB RAM).',
            badge: 'DEEP REASONING',
            isDownloaded: _balancedDownloaded,
            isSelected: _selectedModelTier == ModelTier.balanced,
            themeColors: themeColors,
            isDark: isDark,
            onSelect: () => setState(() => _selectedModelTier = ModelTier.balanced),
          ),
          const SizedBox(height: 14),

          // Privacy Reassurance Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF14171F) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 15,
                  color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF059669),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '100% On-Device AI • Runs locally on your hardware • Zero telemetry or cloud API keys',
                    style: RythemTypography.caption.copyWith(
                      color: themeColors.textSecondary,
                      fontSize: 10.5,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Live Download Status Card
          if (isDownloading && progress != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: isDark ? const Color(0xFF16181D) : Colors.white,
                border: Border.all(
                  color: themeColors.actionPrimary.withOpacity(0.4),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: themeColors.actionPrimary.withOpacity(0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Downloading ${progress.tier.name.toUpperCase()} Mentor...',
                            style: RythemTypography.labelSmall.copyWith(
                              color: themeColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        progress.formattedProgress,
                        style: RythemTypography.labelSmall.copyWith(
                          color: themeColors.actionPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  GlassProgressBar(progress: progress.progress),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${progress.formattedReceived} / ${progress.formattedTotal}',
                        style: RythemTypography.caption.copyWith(
                          color: themeColors.textTertiary,
                          fontSize: 10.5,
                        ),
                      ),
                      Text(
                        'Auto-resumes if paused',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.green.shade400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            Row(
              children: [
                Icon(Icons.shield_outlined, size: 14, color: Colors.green.shade400),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Download pauses safely if app is closed and resumes automatically. Keep app open for fastest download.',
                    style: RythemTypography.caption.copyWith(
                      color: themeColors.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModelCard({
    required ModelTier tier,
    required String title,
    required String subtitle,
    required String description,
    required String badge,
    required bool isDownloaded,
    required bool isSelected,
    required RythemColorTokens themeColors,
    required bool isDark,
    required VoidCallback onSelect,
  }) {
    final isDownloadingThis = _modelManager.downloadingTier == tier;

    return GestureDetector(
      onTap: onSelect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isSelected
              ? (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04))
              : (isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02)),
          border: Border.all(
            color: isSelected
                ? themeColors.actionPrimary
                : (isDark ? Colors.white12 : Colors.black.withOpacity(0.08)),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                  size: 20,
                  color: isSelected ? themeColors.actionPrimary : themeColors.textTertiary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: RythemTypography.titleSmall.copyWith(
                              color: themeColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: themeColors.actionPrimary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              badge,
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                color: themeColors.actionPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        subtitle,
                        style: RythemTypography.caption.copyWith(
                          color: themeColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isDownloaded) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 14, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          'Ready',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.green.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (isDownloadingThis) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: themeColors.actionPrimary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Downloading...',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: themeColors.actionPrimary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: RythemTypography.bodySmall.copyWith(
                color: themeColors.textTertiary,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

}
