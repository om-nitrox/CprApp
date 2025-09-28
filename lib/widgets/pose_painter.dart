import 'package:flutter/material.dart';
import '../models/landmark.dart';

class PosePainter extends CustomPainter {
  PosePainter({required this.landmarks, required this.imageSize});

  final List<Landmark> landmarks;
  final Size imageSize;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..color = Colors.lightGreenAccent;

    final leftPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.yellowAccent;
      
    final rightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.lightBlueAccent;

    void drawLine(int landmark1, int landmark2, Paint paintType) {
        if(landmarks[landmark1].visibility > 0.5 && landmarks[landmark2].visibility > 0.5){
            canvas.drawLine(
                Offset(landmarks[landmark1].x * size.width, landmarks[landmark1].y * size.height),
                Offset(landmarks[landmark2].x * size.width, landmarks[landmark2].y * size.height),
                paintType
            );
        }
    }

    // Draw skeleton
    drawLine(11, 12, paint); // Shoulders
    drawLine(11, 13, leftPaint); // Left Arm
    drawLine(13, 15, leftPaint); // Left Forearm
    drawLine(12, 14, rightPaint); // Right Arm
    drawLine(14, 16, rightPaint); // Right Forearm
    drawLine(11, 23, leftPaint);
    drawLine(12, 24, rightPaint);
    drawLine(23, 24, paint); // Hips
    drawLine(23, 25, leftPaint);
    drawLine(25, 27, leftPaint);
    drawLine(24, 26, rightPaint);
    drawLine(26, 28, rightPaint);
  
    // Draw landmarks
    for (final landmark in landmarks) {
      if (landmark.visibility > 0.5) {
        canvas.drawCircle(
            Offset(landmark.x * size.width, landmark.y * size.height),
            2,
            paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return oldDelegate.landmarks != landmarks || oldDelegate.imageSize != imageSize;
  }
}
