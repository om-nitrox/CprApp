import 'package:flutter/material.dart';
import '../models/cpr_metrics.dart';

class MetricsDisplay extends StatelessWidget {
  final CPRMetrics? metrics;
  final Duration? sessionDuration;

  const MetricsDisplay({
    Key? key,
    this.metrics,
    this.sessionDuration,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Session Timer
          if (sessionDuration != null)
            Text(
              _formatDuration(sessionDuration!),
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          
          if (metrics != null) ...[
            SizedBox(height: 12),
            
            // Compression Rate with color coding
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _getRateColor(metrics!.compressionRate),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${metrics!.compressionRate.toInt()}/min',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            SizedBox(height: 8),
            Text(
              'Compression Rate',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            
            SizedBox(height: 16),
            
            // Metrics Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildMetricItem(
                  'Depth',
                  '${metrics!.estimatedDepth.toStringAsFixed(1)}cm',
                  Icons.vertical_align_center,
                ),
                _buildMetricItem(
                  'Total',
                  '${metrics!.totalCompressions}',
                  Icons.replay,
                ),
              ],
            ),
            
            SizedBox(height: 12),
            
            // Target Achievement Indicator
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: metrics!.isInRange ? Colors.green : Colors.orange,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                metrics!.isInRange ? 'ON TARGET' : 'ADJUST RATE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ] else
            Text(
              'Waiting for pose detection...',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Color _getRateColor(double rate) {
    if (rate < 100) return Colors.orange;
    if (rate > 120) return Colors.red;
    return Colors.green;
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '${twoDigits(duration.inMinutes)}:$twoDigitSeconds';
  }
}
