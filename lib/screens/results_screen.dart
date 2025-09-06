import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/cpr_metrics.dart';
import '../services/data_export_service.dart';

class ResultsScreen extends StatelessWidget {
  final List<CPRMetrics> sessionData;
  final Duration sessionDuration;

  const ResultsScreen({
    Key? key,
    required this.sessionData,
    required this.sessionDuration,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final averageRate = sessionData.isEmpty
        ? 0.0
        : sessionData.map((m) => m.compressionRate).reduce((a, b) => a + b) / sessionData.length;

    final averageDepth = sessionData.isEmpty
        ? 0.0
        : sessionData.map((m) => m.estimatedDepth).reduce((a, b) => a + b) / sessionData.length;

    final totalCompressions = sessionData.isEmpty ? 0 : sessionData.last.totalCompressions;
    
    final targetAchieved = averageRate >= 100 && averageRate <= 120;
    final qualityScore = _calculateQualityScore(averageRate, averageDepth);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Training Results',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.red.shade600,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card with Overall Score
              Card(
                elevation: 8,
                shadowColor: Colors.black.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: targetAchieved 
                          ? [Colors.green.shade400, Colors.green.shade600]
                          : [Colors.orange.shade400, Colors.orange.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        targetAchieved ? Icons.check_circle : Icons.warning,
                        size: 50,
                        color: Colors.white,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Training Complete!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Quality Score: ${qualityScore}/100',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: 20),
              
              // Session Summary Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.analytics, color: Colors.red.shade600, size: 24),
                          SizedBox(width: 8),
                          Text(
                            'Session Summary',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      
                      _buildStatRow(
                        'Session Duration',
                        _formatDuration(sessionDuration),
                        Icons.timer,
                      ),
                      _buildStatRow(
                        'Total Compressions',
                        totalCompressions.toString(),
                        Icons.replay,
                      ),
                      _buildStatRow(
                        'Average Rate',
                        '${averageRate.toInt()}/min',
                        Icons.speed,
                        isTarget: targetAchieved,
                      ),
                      _buildStatRow(
                        'Average Depth',
                        '${averageDepth.toStringAsFixed(1)}cm',
                        Icons.vertical_align_center,
                      ),
                      _buildStatRow(
                        'Target Achievement',
                        targetAchieved ? 'Excellent' : 'Needs Improvement',
                        targetAchieved ? Icons.check_circle : Icons.error,
                        isTarget: targetAchieved,
                      ),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: 20),
              
              // Performance Breakdown Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.insights, color: Colors.blue.shade600, size: 24),
                          SizedBox(width: 8),
                          Text(
                            'Performance Analysis',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      
                      _buildProgressBar(
                        'Compression Rate',
                        averageRate,
                        100,
                        120,
                        '${averageRate.toInt()}/min',
                      ),
                      
                      SizedBox(height: 12),
                      
                      _buildProgressBar(
                        'Session Length',
                        sessionDuration.inMinutes.toDouble(),
                        2,
                        10,
                        _formatDuration(sessionDuration),
                      ),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: 24),
              
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _exportData(context),
                      icon: Icon(Icons.download, size: 20),
                      label: Text('Export Data'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue.shade600,
                        side: BorderSide(color: Colors.blue.shade300),
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _shareResults(context),
                      icon: Icon(Icons.share, size: 20),
                      label: Text('Share'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green.shade600,
                        side: BorderSide(color: Colors.green.shade300),
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 12),
              
              // Main Action Buttons
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  icon: Icon(Icons.home, color: Colors.white),
                  label: Text(
                    'Back to Home',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon, {bool isTarget = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isTarget ? Colors.green : Colors.grey[600],
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isTarget ? Colors.green : Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(String label, double value, double min, double max, String displayValue) {
    final progress = ((value - min) / (max - min)).clamp(0.0, 1.0);
    final isGood = value >= min && value <= max;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            Text(
              displayValue,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isGood ? Colors.green : Colors.orange,
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(
            isGood ? Colors.green : Colors.orange,
          ),
        ),
      ],
    );
  }

  int _calculateQualityScore(double rate, double depth) {
    int score = 0;
    
    // Rate scoring (60% of total)
    if (rate >= 100 && rate <= 120) {
      score += 60;
    } else if (rate >= 90 && rate <= 130) {
      score += 40;
    } else if (rate >= 80 && rate <= 140) {
      score += 20;
    }
    
    // Depth scoring (30% of total)
    if (depth >= 5.0 && depth <= 6.0) {
      score += 30;
    } else if (depth >= 4.0 && depth <= 7.0) {
      score += 20;
    } else if (depth >= 3.0 && depth <= 8.0) {
      score += 10;
    }
    
    // Session completeness (10% of total)
    if (sessionDuration.inMinutes >= 2) {
      score += 10;
    } else if (sessionDuration.inMinutes >= 1) {
      score += 5;
    }
    
    return score;
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds % 60);
    return '$minutes:$seconds';
  }

  void _exportData(BuildContext context) async {
    try {
      HapticFeedback.lightImpact();
      await DataExportService.exportSessionData(sessionData);
      
      if (!context.mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Training data exported successfully!'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(child: Text('Export failed: $e')),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  void _shareResults(BuildContext context) {
    final summary = '''
CPR Training Results:
• Duration: ${_formatDuration(sessionDuration)}
• Total Compressions: ${sessionData.isEmpty ? 0 : sessionData.last.totalCompressions}
• Average Rate: ${sessionData.isEmpty ? 0 : (sessionData.map((m) => m.compressionRate).reduce((a, b) => a + b) / sessionData.length).toInt()}/min
• Target Achievement: ${(sessionData.isEmpty ? 0.0 : sessionData.map((m) => m.compressionRate).reduce((a, b) => a + b) / sessionData.length) >= 100 && (sessionData.isEmpty ? 0.0 : sessionData.map((m) => m.compressionRate).reduce((a, b) => a + b) / sessionData.length) <= 120 ? 'Good' : 'Needs Improvement'}

Generated by CPR AI Trainer
    ''';
    
    // Copy to clipboard
    Clipboard.setData(ClipboardData(text: summary));
    HapticFeedback.lightImpact();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.copy, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Results copied to clipboard!'),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 2),
      ),
    );
  }
}
