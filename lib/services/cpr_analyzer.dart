import 'dart:math';
import '../models/landmark.dart';
import '../models/cpr_metrics.dart';

class CPRAnalyzer {
  List<double> _handPositions = [];
  List<DateTime> _compressionTimestamps = [];
  double _lastHandY = 0.0;
  bool _wasUp = true;
  int _compressionCount = 0;
  
  static const int LEFT_WRIST = 15;  // MediaPipe landmark indices
  static const int RIGHT_WRIST = 16;
  static const int LEFT_SHOULDER = 11;
  static const int RIGHT_SHOULDER = 12;

  CPRMetrics analyzePose(List<Landmark> landmarks) {
    if (landmarks.length < 33) {
      return _getDefaultMetrics();
    }

    // Get hand and shoulder positions
    final leftWrist = landmarks[LEFT_WRIST];
    final rightWrist = landmarks[RIGHT_WRIST];
    final leftShoulder = landmarks[LEFT_SHOULDER];
    final rightShoulder = landmarks[RIGHT_SHOULDER];

    // Calculate average hand position
    final avgHandY = (leftWrist.y + rightWrist.y) / 2;
    final avgShoulderY = (leftShoulder.y + rightShoulder.y) / 2;

    // Detect compression cycle
    _detectCompression(avgHandY);

    // Calculate metrics
    final compressionRate = _calculateCompressionRate();
    final estimatedDepth = _estimateDepth(avgHandY, avgShoulderY);
    final isInRange = compressionRate >= 100 && compressionRate <= 120;

    return CPRMetrics(
      compressionRate: compressionRate,
      estimatedDepth: estimatedDepth,
      totalCompressions: _compressionCount,
      isInRange: isInRange,
      timestamp: DateTime.now(),
    );
  }

  void _detectCompression(double handY) {
    const double threshold = 0.02; // Adjust based on testing
    
    if (_wasUp && handY > _lastHandY + threshold) {
      // Detected downward compression
      _compressionCount++;
      _compressionTimestamps.add(DateTime.now());
      _wasUp = false;
      
      // Keep only recent timestamps (last 30 seconds)
      final cutoff = DateTime.now().subtract(Duration(seconds: 30));
      _compressionTimestamps.removeWhere((timestamp) => timestamp.isBefore(cutoff));
    } else if (!_wasUp && handY < _lastHandY - threshold) {
      // Hand moving back up
      _wasUp = true;
    }
    
    _lastHandY = handY;
  }

  double _calculateCompressionRate() {
    if (_compressionTimestamps.length < 2) return 0.0;
    
    final now = DateTime.now();
    final recentCompressions = _compressionTimestamps
        .where((timestamp) => now.difference(timestamp).inSeconds <= 60)
        .length;
    
    return recentCompressions.toDouble();
  }

  double _estimateDepth(double handY, double shoulderY) {
    // Simple depth estimation based on hand-shoulder distance
    // Note: This will be less accurate as mentioned in the research paper
    final relativePosition = (handY - shoulderY).abs();
    return (relativePosition * 100).clamp(0.0, 10.0); // Convert to cm, clamp to reasonable range
  }

  CPRMetrics _getDefaultMetrics() {
    return CPRMetrics(
      compressionRate: 0.0,
      estimatedDepth: 0.0,
      totalCompressions: _compressionCount,
      isInRange: false,
      timestamp: DateTime.now(),
    );
  }

  void reset() {
    _handPositions.clear();
    _compressionTimestamps.clear();
    _compressionCount = 0;
    _wasUp = true;
    _lastHandY = 0.0;
  }
}
