import 'dart:typed_data';
import 'dart:ui';
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
      );

      _poseDetector = PoseDetector(options: options);
      _isInitialized = true;
      print('✅ ML Kit Pose Detection v0.14.0 initialized successfully');
      return true;
    } catch (e) {
      print('❌ Error initializing pose detection: $e');
      return false;
    }
  }

  Future<List<Landmark>?> detectPose(CameraImage cameraImage) async {
    if (!_isInitialized) {
      await initializePoseDetection();
    }

    try {
      final inputImage = _convertCameraImage(cameraImage);
      if (inputImage == null) return null;

      final poses = await _poseDetector.processImage(inputImage);

      if (poses.isEmpty) return null;

      final pose = poses.first;
      return _convertPoseToLandmarks(pose);
    } catch (e) {
      print('❌ Error in pose detection: $e');
      return null;
    }
  }

  List<Landmark> _convertPoseToLandmarks(Pose pose) {
    List<Landmark> landmarks = [];

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
      11: PoseLandmarkType.leftShoulder,     // Important for CPR
      12: PoseLandmarkType.rightShoulder,    // Important for CPR
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

    // Create 33 landmarks
    for (int i = 0; i < 33; i++) {
      final landmarkType = landmarkMap[i];
      if (landmarkType != null) {
        final mlKitLandmark = pose.landmarks[landmarkType];
        if (mlKitLandmark != null) {
          landmarks.add(
            Landmark(
              x: mlKitLandmark.x / 1000,
              y: mlKitLandmark.y / 1000,
              z: 0.0,
              visibility: 1.0,
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

  InputImage? _convertCameraImage(CameraImage cameraImage) {
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in cameraImage.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(  // Changed from 'inputImageData' to 'metadata'
          size: Size(
            cameraImage.width.toDouble(),
            cameraImage.height.toDouble(),
          ),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21,
          bytesPerRow: cameraImage.planes.first.bytesPerRow,
        ),
      );
    } catch (e) {
      print('❌ Error converting camera image: $e');
      return null;
    }
  }

  void dispose() {
    if (_isInitialized) {
      _poseDetector.close();
      _isInitialized = false;
      print('🧹 ML Kit Pose Detection disposed');
    }
  }
}
