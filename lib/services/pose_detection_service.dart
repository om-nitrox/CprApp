// import 'dart:typed_data';
// import 'dart:ui';
// import 'package:flutter/foundation.dart';
// import 'package:camera/camera.dart';
// import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
// import '../models/landmark.dart';

// class PoseDetectionService {
//   late PoseDetector _poseDetector;
//   bool _isInitialized = false;

//   Future<bool> initializePoseDetection() async {
//     try {
//       final options = PoseDetectorOptions(
//         model: PoseDetectionModel.accurate,
//       );

//       _poseDetector = PoseDetector(options: options);
//       _isInitialized = true;
//       print('✅ ML Kit Pose Detection v0.14.0 initialized successfully');
//       return true;
//     } catch (e) {
//       print('❌ Error initializing pose detection: $e');
//       return false;
//     }
//   }

//   Future<List<Landmark>?> detectPose(CameraImage cameraImage) async {
//     if (!_isInitialized) {
//       await initializePoseDetection();
//     }

//     try {
//       final inputImage = _convertCameraImage(cameraImage);
//       if (inputImage == null) return null;

//       final poses = await _poseDetector.processImage(inputImage);

//       if (poses.isEmpty) return null;

//       final pose = poses.first;
//       return _convertPoseToLandmarks(pose);
//     } catch (e) {
//       print('❌ Error in pose detection: $e');
//       return null;
//     }
//   }

//   List<Landmark> _convertPoseToLandmarks(Pose pose) {
//     List<Landmark> landmarks = [];

//     final landmarkMap = {
//       0: PoseLandmarkType.nose,
//       1: PoseLandmarkType.leftEyeInner,
//       2: PoseLandmarkType.leftEye,
//       3: PoseLandmarkType.leftEyeOuter,
//       4: PoseLandmarkType.rightEyeInner,
//       5: PoseLandmarkType.rightEye,
//       6: PoseLandmarkType.rightEyeOuter,
//       7: PoseLandmarkType.leftEar,
//       8: PoseLandmarkType.rightEar,
//       9: PoseLandmarkType.leftMouth,
//       10: PoseLandmarkType.rightMouth,
//       11: PoseLandmarkType.leftShoulder,     // Important for CPR
//       12: PoseLandmarkType.rightShoulder,    // Important for CPR
//       13: PoseLandmarkType.leftElbow,        // Important for CPR
//       14: PoseLandmarkType.rightElbow,       // Important for CPR
//       15: PoseLandmarkType.leftWrist,        // Key for CPR analysis
//       16: PoseLandmarkType.rightWrist,       // Key for CPR analysis
//       17: PoseLandmarkType.leftPinky,
//       18: PoseLandmarkType.rightPinky,
//       19: PoseLandmarkType.leftIndex,
//       20: PoseLandmarkType.rightIndex,
//       21: PoseLandmarkType.leftThumb,
//       22: PoseLandmarkType.rightThumb,
//       23: PoseLandmarkType.leftHip,
//       24: PoseLandmarkType.rightHip,
//       25: PoseLandmarkType.leftKnee,
//       26: PoseLandmarkType.rightKnee,
//       27: PoseLandmarkType.leftAnkle,
//       28: PoseLandmarkType.leftHeel,
//       29: PoseLandmarkType.rightAnkle,
//       30: PoseLandmarkType.rightHeel,
//       31: PoseLandmarkType.leftFootIndex,
//       32: PoseLandmarkType.rightFootIndex,
//     };

//     // Create 33 landmarks
//     for (int i = 0; i < 33; i++) {
//       final landmarkType = landmarkMap[i];
//       if (landmarkType != null) {
//         final mlKitLandmark = pose.landmarks[landmarkType];
//         if (mlKitLandmark != null) {
//           landmarks.add(
//             Landmark(
//               x: mlKitLandmark.x / 1000,
//               y: mlKitLandmark.y / 1000,
//               z: 0.0,
//               visibility: 1.0,
//             ),
//           );
//         } else {
//           landmarks.add(Landmark(x: 0.0, y: 0.0, z: 0.0, visibility: 0.0));
//         }
//       } else {
//         landmarks.add(Landmark(x: 0.0, y: 0.0, z: 0.0, visibility: 0.0));
//       }
//     }

//     return landmarks;
//   }

//   InputImage? _convertCameraImage(CameraImage cameraImage) {
//     try {
//       final WriteBuffer allBytes = WriteBuffer();
//       for (final Plane plane in cameraImage.planes) {
//         allBytes.putUint8List(plane.bytes);
//       }
//       final bytes = allBytes.done().buffer.asUint8List();

//       return InputImage.fromBytes(
//         bytes: bytes,
//         metadata: InputImageMetadata(  // Changed from 'inputImageData' to 'metadata'
//           size: Size(
//             cameraImage.width.toDouble(),
//             cameraImage.height.toDouble(),
//           ),
//           rotation: InputImageRotation.rotation0deg,
//           format: InputImageFormat.nv21,
//           bytesPerRow: cameraImage.planes.first.bytesPerRow,
//         ),
//       );
//     } catch (e) {
//       print('❌ Error converting camera image: $e');
//       return null;
//     }
//   }

//   void dispose() {
//     if (_isInitialized) {
//       _poseDetector.close();
//       _isInitialized = false;
//       print('🧹 ML Kit Pose Detection disposed');
//     }
//   }
// }


import 'dart:typed_data';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../models/landmark.dart';

class PoseDetectionService {
  late PoseDetector _poseDetector;
  bool _isInitialized = false;

  Future<bool> initializePoseDetection() async {
    try {
      final options = PoseDetectorOptions(
        model: PoseDetectionModel.accurate,
        mode: PoseDetectionMode.stream, // Better for video streams
      );

      _poseDetector = PoseDetector(options: options);
      _isInitialized = true;
      print('✅ ML Kit Pose Detection v0.14.0 initialized successfully for ${Platform.operatingSystem}');
      return true;
    } catch (e) {
      print('❌ Error initializing pose detection: $e');
      return false;
    }
  }

  Future<List<Landmark>?> detectPose(CameraImage cameraImage) async {
    if (!_isInitialized) {
      final success = await initializePoseDetection();
      if (!success) return null;
    }

    try {
      final inputImage = _convertCameraImage(cameraImage);
      if (inputImage == null) return null;

      final poses = await _poseDetector.processImage(inputImage);

      if (poses.isEmpty) return null;

      final pose = poses.first;
      return _convertPoseToLandmarks(pose, cameraImage);
    } catch (e) {
      print('❌ Error in pose detection: $e');
      return null;
    }
  }

  List<Landmark> _convertPoseToLandmarks(Pose pose, CameraImage cameraImage) {
    List<Landmark> landmarks = [];
    
    // Get image dimensions for normalization
    final double imageWidth = cameraImage.width.toDouble();
    final double imageHeight = cameraImage.height.toDouble();

    final landmarkMap = {
      0: PoseLandmarkType.nose,
      1: PoseLandmarkType.leftEyeInner,
      2: PoseLandmarkType.leftEye,
      3: PoseLandmarkType.leftEyeOuter,
      4: PoseLandmarkType.rightEyeInner,
      5: PoseLandmarkType.rightEye,
      6: PoseLandmarkType.rightEyeOuter,
      7: PoseLandmarkType.leftEar,
      8: PoseLandmarkType.rightEar,
      9: PoseLandmarkType.leftMouth,
      10: PoseLandmarkType.rightMouth,
      11: PoseLandmarkType.leftShoulder,     // Critical for CPR
      12: PoseLandmarkType.rightShoulder,    // Critical for CPR
      13: PoseLandmarkType.leftElbow,        // Important for CPR
      14: PoseLandmarkType.rightElbow,       // Important for CPR
      15: PoseLandmarkType.leftWrist,        // Key for CPR analysis
      16: PoseLandmarkType.rightWrist,       // Key for CPR analysis
      17: PoseLandmarkType.leftPinky,
      18: PoseLandmarkType.rightPinky,
      19: PoseLandmarkType.leftIndex,
      20: PoseLandmarkType.rightIndex,
      21: PoseLandmarkType.leftThumb,
      22: PoseLandmarkType.rightThumb,
      23: PoseLandmarkType.leftHip,
      24: PoseLandmarkType.rightHip,
      25: PoseLandmarkType.leftKnee,
      26: PoseLandmarkType.rightKnee,
      27: PoseLandmarkType.leftAnkle,
      28: PoseLandmarkType.leftHeel,
      29: PoseLandmarkType.rightAnkle,
      30: PoseLandmarkType.rightHeel,
      31: PoseLandmarkType.leftFootIndex,
      32: PoseLandmarkType.rightFootIndex,
    };

    // Create 33 landmarks with proper normalization
    for (int i = 0; i < 33; i++) {
      final landmarkType = landmarkMap[i];
      if (landmarkType != null) {
        final mlKitLandmark = pose.landmarks[landmarkType];
        if (mlKitLandmark != null) {
          // Normalize coordinates to 0-1 range based on actual image dimensions
          landmarks.add(
            Landmark(
              x: mlKitLandmark.x / imageWidth,
              y: mlKitLandmark.y / imageHeight,
              z: 0.0, // ML Kit doesn't provide reliable Z values
              visibility: _calculateVisibility(mlKitLandmark),
            ),
          );
        } else {
          landmarks.add(Landmark(x: 0.0, y: 0.0, z: 0.0, visibility: 0.0));
        }
      } else {
        landmarks.add(Landmark(x: 0.0, y: 0.0, z: 0.0, visibility: 0.0));
      }
    }

    return landmarks;
  }

  double _calculateVisibility(PoseLandmark landmark) {
    // ML Kit provides likelihood (0.0 to 1.0)
    // Return 1.0 if landmark is detected, 0.0 otherwise
    return landmark.likelihood > 0.5 ? 1.0 : 0.0;
  }

  InputImage? _convertCameraImage(CameraImage cameraImage) {
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in cameraImage.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      // Platform-specific image format
      InputImageFormat format;
      if (Platform.isAndroid) {
        format = InputImageFormat.nv21;
      } else if (Platform.isIOS) {
        format = InputImageFormat.bgra8888;
      } else {
        // Fallback for other platforms
        format = InputImageFormat.yuv420;
      }

      // Get rotation based on device orientation
      final rotation = _getImageRotation();

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(
            cameraImage.width.toDouble(),
            cameraImage.height.toDouble(),
          ),
          rotation: rotation,
          format: format,
          bytesPerRow: cameraImage.planes.first.bytesPerRow,
        ),
      );
    } catch (e) {
      print('❌ Error converting camera image: $e');
      return null;
    }
  }

  InputImageRotation _getImageRotation() {
    // For now, return rotation0deg since we're forcing portrait mode
    // You can enhance this to handle device orientation changes
    return InputImageRotation.rotation0deg;
  }

  // Helper method to get critical landmarks for CPR analysis
  Map<String, Landmark?> getCriticalLandmarks(List<Landmark> landmarks) {
    if (landmarks.length < 33) return {};
    
    return {
      'leftShoulder': landmarks[11],
      'rightShoulder': landmarks[12],
      'leftElbow': landmarks[13],
      'rightElbow': landmarks[14],
      'leftWrist': landmarks[15],
      'rightWrist': landmarks[16],
      'leftHip': landmarks[23],
      'rightHip': landmarks[24],
    };
  }

  // Helper method to check if pose detection is working
  bool isPoseDetected(List<Landmark> landmarks) {
    if (landmarks.isEmpty) return false;
    
    final criticalLandmarks = getCriticalLandmarks(landmarks);
    int visibleCount = 0;
    
    criticalLandmarks.forEach((key, landmark) {
      if (landmark != null && landmark.visibility > 0.5) {
        visibleCount++;
      }
    });
    
    // At least 4 out of 8 critical landmarks should be visible
    return visibleCount >= 4;
  }

  void dispose() {
    if (_isInitialized) {
      try {
        _poseDetector.close();
        _isInitialized = false;
        print('🧹 ML Kit Pose Detection disposed');
      } catch (e) {
        print('❌ Error disposing pose detector: $e');
      }
    }
  }
}