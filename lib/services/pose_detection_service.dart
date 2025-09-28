import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../models/landmark.dart';


class PoseDetectionService {
  late PoseDetector _poseDetector;
  bool _isInitialized = false;


  Future<bool> initializePoseDetection() async {
    try {
      final options = PoseDetectorOptions(
        model: PoseDetectionModel.accurate,
        mode: PoseDetectionMode.stream,
      );
      _poseDetector = PoseDetector(options: options);
      _isInitialized = true;
      debugPrint('✅ ML Kit Pose Detection v0.14.0 initialized successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error initializing pose detection: $e');
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
      return _convertPoseToLandmarks(pose, cameraImage);
    } catch (e) {
      debugPrint('❌ Error in pose detection: $e');
      return null;
    }
  }


  List<Landmark> _convertPoseToLandmarks(Pose pose, CameraImage cameraImage) {
    List<Landmark> landmarks = [];
    final double imageWidth = cameraImage.width.toDouble();
    final double imageHeight = cameraImage.height.toDouble();


    final landmarkMap = {
      0: PoseLandmarkType.nose, 1: PoseLandmarkType.leftEyeInner, 2: PoseLandmarkType.leftEye, 3: PoseLandmarkType.leftEyeOuter, 4: PoseLandmarkType.rightEyeInner, 5: PoseLandmarkType.rightEye, 6: PoseLandmarkType.rightEyeOuter, 7: PoseLandmarkType.leftEar, 8: PoseLandmarkType.rightEar, 9: PoseLandmarkType.leftMouth, 10: PoseLandmarkType.rightMouth, 11: PoseLandmarkType.leftShoulder, 12: PoseLandmarkType.rightShoulder, 13: PoseLandmarkType.leftElbow, 14: PoseLandmarkType.rightElbow, 15: PoseLandmarkType.leftWrist, 16: PoseLandmarkType.rightWrist, 17: PoseLandmarkType.leftPinky, 18: PoseLandmarkType.rightPinky, 19: PoseLandmarkType.leftIndex, 20: PoseLandmarkType.rightIndex, 21: PoseLandmarkType.leftThumb, 22: PoseLandmarkType.rightThumb, 23: PoseLandmarkType.leftHip, 24: PoseLandmarkType.rightHip, 25: PoseLandmarkType.leftKnee, 26: PoseLandmarkType.rightKnee, 27: PoseLandmarkType.leftAnkle, 28: PoseLandmarkType.rightAnkle, 29: PoseLandmarkType.leftHeel, 30: PoseLandmarkType.rightHeel, 31: PoseLandmarkType.leftFootIndex, 32: PoseLandmarkType.rightFootIndex,
    };


    for (int i = 0; i < 33; i++) {
      final landmarkType = landmarkMap[i];
      final mlKitLandmark = landmarkType != null ? pose.landmarks[landmarkType] : null;
      if (mlKitLandmark != null) {
        landmarks.add(
          Landmark(
            x: mlKitLandmark.x / imageWidth,
            y: mlKitLandmark.y / imageHeight,
            z: mlKitLandmark.z,
            visibility: mlKitLandmark.likelihood,
          ),
        );
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


      final imageSize = Size(cameraImage.width.toDouble(), cameraImage.height.toDouble());
      
      final imageRotation = InputImageRotation.rotation90deg;


      final inputImageFormat = InputImageFormatValue.fromRawValue(cameraImage.format.raw) ?? InputImageFormat.nv21;


      // --- THIS IS THE CORRECTED CODE ---
      // We are returning to the constructor that matches your library version,
      // which does not have the 'timestamp' parameter.
      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: imageSize,
          rotation: imageRotation,
          format: inputImageFormat,
          bytesPerRow: cameraImage.planes.first.bytesPerRow,
        ),
      );
      // ------------------------------------
      
    } catch (e) {
      debugPrint('❌ Error converting camera image: $e');
      return null;
    }
  }


  void dispose() {
    if (_isInitialized) {
      _poseDetector.close();
      _isInitialized = false;
      debugPrint('🧹 ML Kit Pose Detection disposed');
    }
  }
}
