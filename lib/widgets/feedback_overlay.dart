import 'package:flutter/material.dart';
import '../models/cpr_metrics.dart';

class FeedbackOverlay extends StatelessWidget {
  final CPRMetrics metrics;

  const FeedbackOverlay({Key? key, required this.metrics}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        children: [
          // Top metrics display
          Container(
            margin: EdgeInsets.only(top: 50),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  '${metrics.compressionRate.toInt()}/min',
                  style: TextStyle(
                    color: metrics.isInRange ? Colors.green : Colors.red,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Compression Rate',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                SizedBox(height: 10),
                Text(
                  'Depth: ${metrics.estimatedDepth.toStringAsFixed(1)}cm',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                Text(
                  'Total: ${metrics.totalCompressions}',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
          
          Spacer(),
          
          // Feedback messages
          Container(
            margin: EdgeInsets.only(bottom: 150),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getFeedbackColor().withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _getFeedbackMessage(),
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Color _getFeedbackColor() {
    if (metrics.compressionRate < 100) return Colors.orange;
    if (metrics.compressionRate > 120) return Colors.red;
    return Colors.green;
  }

  String _getFeedbackMessage() {
    if (metrics.compressionRate < 100) {
      return 'PUSH FASTER\nTarget: 100-120/min';
    } else if (metrics.compressionRate > 120) {
      return 'SLOW DOWN\nTarget: 100-120/min';
    } else {
      return 'GOOD RHYTHM\nKeep it up!';
    }
  }
}
