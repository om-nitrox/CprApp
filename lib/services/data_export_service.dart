import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/cpr_metrics.dart';

class DataExportService {
  static Future<void> exportSessionData(List<CPRMetrics> sessionData) async {
    if (sessionData.isEmpty) return;

    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File('${directory.path}/cpr_session_$timestamp.csv');

    final csvContent = StringBuffer();
    csvContent.writeln('Timestamp,CompressionRate,EstimatedDepth,TotalCompressions,IsInRange');
    
    for (final metrics in sessionData) {
      csvContent.writeln(
        '${metrics.timestamp.toIso8601String()},'
        '${metrics.compressionRate},'
        '${metrics.estimatedDepth},'
        '${metrics.totalCompressions},'
        '${metrics.isInRange}'
      );
    }

    await file.writeAsString(csvContent.toString());
  }
}
