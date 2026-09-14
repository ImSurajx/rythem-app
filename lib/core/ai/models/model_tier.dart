enum ModelTier {
  fallback,
  compact,
  balanced,
}

class ModelInfo {
  final ModelTier tier;
  final String id;
  final String displayName;
  final String subtitle;
  final String description;
  final String quantization;
  final String filename;
  final String downloadUrl;
  final int sizeBytes;
  final int targetRamMb;
  final double estimatedTokensPerSec;

  const ModelInfo({
    required this.tier,
    required this.id,
    required this.displayName,
    required this.subtitle,
    required this.description,
    required this.quantization,
    required this.filename,
    required this.downloadUrl,
    required this.sizeBytes,
    required this.targetRamMb,
    required this.estimatedTokensPerSec,
  });

  String get formattedSize {
    if (sizeBytes == 0) return '0 MB (Built-in)';
    final mb = sizeBytes / (1024 * 1024);
    if (mb >= 1000) {
      return '${(mb / 1024).toStringAsFixed(2)} GB';
    }
    return '${mb.toStringAsFixed(1)} MB';
  }

  static const ModelInfo fallback = ModelInfo(
    tier: ModelTier.fallback,
    id: 'fallback',
    displayName: 'Fallback Heuristic',
    subtitle: 'Built-in deterministic similarity engine',
    description:
        'Instant token-overlap and string similarity. Requires 0 MB download and runs on any device with zero RAM footprint.',
    quantization: 'N/A',
    filename: '',
    downloadUrl: '',
    sizeBytes: 0,
    targetRamMb: 0,
    estimatedTokensPerSec: 0,
  );

  static const ModelInfo compact = ModelInfo(
    tier: ModelTier.compact,
    id: 'compact',
    displayName: 'Compact (Qwen 2.5 0.5B)',
    subtitle: 'Lightweight & multilingual GGUF',
    description:
        'Optimized for fast playlist clustering and Hinglish/multilingual topic matching. Runs in ~600 MB RAM.',
    quantization: 'Q4_K_M',
    filename: 'qwen2.5-0.5b-instruct-q4_k_m.gguf',
    downloadUrl:
        'https://github.com/ImSurajx/rythem-app/releases/download/models-v1.0.0/qwen2.5-0.5b-instruct-q4_k_m.gguf',
    sizeBytes: 491400032, // ~468.6 MB
    targetRamMb: 600,
    estimatedTokensPerSec: 35.0,
  );

  static const ModelInfo balanced = ModelInfo(
    tier: ModelTier.balanced,
    id: 'balanced',
    displayName: 'Balanced (Qwen 2.5 1.5B)',
    subtitle: 'Deep reasoning & mentor Q&A',
    description:
        'Superior reasoning for ambiguous syllabus alignment and concise AI mentor clarifications. Runs in ~1.35 GB RAM.',
    quantization: 'Q4_K_M',
    filename: 'qwen2.5-1.5b-instruct-q4_k_m.gguf',
    downloadUrl:
        'https://github.com/ImSurajx/rythem-app/releases/download/models-v1.0.0/qwen2.5-1.5b-instruct-q4_k_m.gguf',
    sizeBytes: 1117320736, // ~1,065.6 MB
    targetRamMb: 1350,
    estimatedTokensPerSec: 22.0,
  );

  static ModelInfo forTier(ModelTier tier) {
    switch (tier) {
      case ModelTier.fallback:
        return fallback;
      case ModelTier.compact:
        return compact;
      case ModelTier.balanced:
        return balanced;
    }
  }

  static ModelInfo fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'compact':
        return compact;
      case 'balanced':
        return balanced;
      case 'fallback':
      default:
        return fallback;
    }
  }
}
