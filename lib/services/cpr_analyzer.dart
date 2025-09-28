import 'dart:collection';
import '../models/cpr_metrics.dart';
import '../models/landmark.dart';
import 'dart:math';

class CPRAnalyzer {
  final Queue<DateTime> _compressionTimestamps = Queue();
  final int _rateCalculationSeconds = 5; 
  
  static const double _movementThreshold = 0.02; 
  static const int _minCompressionIntervalMs = 300; 

  DateTime? _lastCompressionTime;
  double _lastShoulderY = 0.0;
  bool _isPushingDown = false;
  int _totalCompressions = 0;
  String _armAngleFeedback = 'Keep Arms Straight';
  double _peakDepth = 0.0;

  void reset() {
    _compressionTimestamps.clear();
    _totalCompressions = 0;
    _lastShoulderY = 0.0;
    _isPushingDown = false;
    _armAngleFeedback = 'Keep Arms Straight';
    _peakDepth = 0.0;
    _lastCompressionTime = null;
  }

  CPRMetrics? analyzePose(List<Landmark> landmarks) {
    if (landmarks.length < 24) return null;

    final leftShoulder = landmarks[11];
    final rightShoulder = landmarks[12];
    final leftElbow = landmarks[13];
    final rightElbow = landmarks[14];
    final leftWrist = landmarks[15];
    final rightWrist = landmarks[16];
    final leftHip = landmarks[23];

    if (leftShoulder.visibility < 0.5 || rightShoulder.visibility < 0.5 || leftWrist.visibility < 0.5) {
      return null;
    }
    
    double leftArmAngle = _calculateAngle(leftShoulder, leftElbow, leftWrist);
    double rightArmAngle = _calculateAngle(rightShoulder, rightElbow, rightWrist);
    
    _armAngleFeedback = (leftArmAngle > 160 && rightArmAngle > 160) ? 'Good: Arms are straight' : 'Adjust: Keep Arms Straight';

    final currentShoulderY = (leftShoulder.y + rightShoulder.y) / 2;
    final double yDifference = currentShoulderY - _lastShoulderY;
    final now = DateTime.now();

    if (yDifference > _movementThreshold && !_isPushingDown) {
      _isPushingDown = true;
    } else if (yDifference < -_movementThreshold && _isPushingDown) {
      _isPushingDown = false;
      
      if (_lastCompressionTime == null || now.difference(_lastCompressionTime!).inMilliseconds > _minCompressionIntervalMs) {
        _totalCompressions++;
        _compressionTimestamps.add(now);
        _lastCompressionTime = now;
        
        final hipY = leftHip.visibility > 0.5 ? leftHip.y : (leftShoulder.y + 0.5);
        _peakDepth = ((currentShoulderY - _lastShoulderY).abs() * 100).toDouble();
      }
    }

    _lastShoulderY = currentShoulderY;

    _cullOldTimestamps();
    final int rate = _calculateRate();

    // --- THIS IS THE FINAL FIX ---
    // Added the required timestamp parameter
    return CPRMetrics(
      timestamp: DateTime.now(), // THIS LINE FIXES THE ERROR
      compressionRate: rate.toDouble(),
      totalCompressions: _totalCompressions,
      isInRange: rate >= 100 && rate <= 120,
      armAngleFeedback: _armAngleFeedback,
      estimatedDepth: _peakDepth > 6.0 ? 6.0 : _peakDepth,
    );
    // ------------------------------------
  }

  void _cullOldTimestamps() {
    final now = DateTime.now();
    while (_compressionTimestamps.isNotEmpty && now.difference(_compressionTimestamps.first).inSeconds >= _rateCalculationSeconds) {
      _compressionTimestamps.removeFirst();
    }
  }

  int _calculateRate() {
    if (_compressionTimestamps.isEmpty) return 0;
    
    final double seconds = _compressionTimestamps.length > 1 
        ? _compressionTimestamps.last.difference(_compressionTimestamps.first).inMilliseconds / 1000.0 
        : _rateCalculationSeconds.toDouble();

    if (seconds < 0.5) return 0;

    return (_compressionTimestamps.length / seconds * 60).round();
  }

  double _calculateAngle(Landmark a, Landmark b, Landmark c) {
    double angle = (atan2(c.y - b.y, c.x - b.x) - atan2(a.y - b.y, a.x - b.x)) * (180 / pi);
    angle = angle.abs();
    if (angle > 180) {
      angle = 360 - angle;
    }
    return angle;
  }
}
