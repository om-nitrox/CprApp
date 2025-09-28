class CPRMetrics {
  final double compressionRate; // compressions per minute
  final double estimatedDepth; // estimated depth in cm
  final int totalCompressions;
  final bool isInRange;
  final DateTime timestamp;
  final String armAngleFeedback;

  CPRMetrics({
    required this.compressionRate,
    required this.estimatedDepth,
    required this.totalCompressions,
    required this.isInRange,
    required this.timestamp,
    this.armAngleFeedback = "",
  });

  Map<String, dynamic> toJson() {
    return {
      'compressionRate': compressionRate,
      'estimatedDepth': estimatedDepth,
      'totalCompressions': totalCompressions,
      'isInRange': isInRange,
      'timestamp': timestamp.toIso8601String(),
      'armAngleFeedback': armAngleFeedback,
    };
  }
}
