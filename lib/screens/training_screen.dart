import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
// import 'package:flutter_vision/flutter_vision.dart'; // Commented out - not supported on iOS

import '../services/pose_detection_service.dart';
import '../services/cpr_analyzer.dart';
import '../models/cpr_metrics.dart';
import '../models/landmark.dart';
import '../widgets/pose_painter.dart';
import 'results_screen.dart';

class TrainingScreen extends StatefulWidget {
  @override
  _TrainingScreenState createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  // Services and Camera
  CameraController? _cameraController;
  final PoseDetectionService _poseService = PoseDetectionService();
  final CPRAnalyzer _analyzer = CPRAnalyzer();

  // YOLO Vision State (Android only)
  // FlutterVision? _vision; // Commented out - not supported on iOS
  List<Map<String, dynamic>> _yoloResults = [];
  bool _isDetecting = false;
  bool _isYoloSupported = false;

  // UI and Training State
  List<Landmark> _landmarks = [];
  final List<CPRMetrics> _sessionData = [];
  CPRMetrics? _currentMetrics;
  bool _isTraining = false;
  bool _isInitialized = false;
  DateTime? _sessionStart;
  bool _showInstructions = true;
  bool _isPaused = false;
  Timer? _sessionTimer;
  String? _initializationError;

  @override
  void initState() {
    super.initState();
    // _vision = FlutterVision(); // Commented out - not supported on iOS
    _isYoloSupported = Platform.isAndroid; // Only support YOLO on Android
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _initializeApp();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _sessionTimer?.cancel();
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _poseService.dispose();
    // _vision?.closeYoloModel(); // Commented out - not supported on iOS
    super.dispose();
  }

  // --- Initialization Logic ---

  Future<void> _initializeApp() async {
    try {
      await _requestPermissions();
      if (_isYoloSupported) {
        await _loadYoloModel();
      }
      await _initializePoseDetection();
      await _initializeCamera();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      print('❌ Initialization error: $e');
      if (mounted) {
        setState(() {
          _initializationError = e.toString();
        });
      }
    }
  }

  Future<void> _requestPermissions() async {
    final cameraStatus = await Permission.camera.request();
    if (cameraStatus != PermissionStatus.granted) {
      _showPermissionDialog();
      throw Exception('Camera permission denied');
    }
  }

  Future<void> _loadYoloModel() async {
    if (!_isYoloSupported) {
      print("ℹ️ YOLO detection not supported on iOS, skipping...");
      return;
    }
    
    try {
      // YOLO model loading would go here for Android
      // await _vision.loadYoloModel(
      //   labels: 'assets/models/labels.txt',
      //   modelPath: 'assets/models/yolov8n.tflite',
      //   modelVersion: "yolov8",
      //   numThreads: 1,
      //   useGpu: true,
      // );
      print("✅ YOLO model loading skipped (iOS not supported)");
    } catch (e) {
      throw Exception("Failed to load YOLO model: $e");
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw Exception('No cameras available');

      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();
      await _cameraController!.lockCaptureOrientation(DeviceOrientation.portraitUp);
      
      if (mounted && _cameraController!.value.isInitialized) {
        _cameraController!.startImageStream(_processCameraImage);
        print('✅ Camera initialized successfully');
      }
    } catch (e) {
      print('❌ Error initializing camera: $e');
      throw Exception('Camera initialization failed: $e');
    }
  }
  
  Future<void> _initializePoseDetection() async {
    try {
      final success = await _poseService.initializePoseDetection();
      if (!success) throw Exception('Failed to initialize pose detection');
    } catch (e) {
      print('❌ Pose detection initialization error: $e');
      throw Exception('Pose detection initialization failed: $e');
    }
  }

  // --- Real-time Processing ---

  void _processCameraImage(CameraImage image) async {
    if (_isDetecting || !_isTraining || _isPaused) return;
    _isDetecting = true;

    try {
      final landmarksFuture = _poseService.detectPose(image);
      
      // Only run YOLO detection on Android
      Future<List<Map<String, dynamic>>> yoloResultFuture = Future.value([]);
      if (_isYoloSupported) {
        // YOLO detection would go here for Android
        // yoloResultFuture = _vision.yoloOnFrame(
        //   bytesList: image.planes.map((plane) => plane.bytes).toList(),
        //   imageHeight: image.height,
        //   imageWidth: image.width,
        //   iouThreshold: 0.4,
        //   confThreshold: 0.4,
        //   classThreshold: 0.5,
        // );
      }

      final results = await Future.wait([landmarksFuture, yoloResultFuture]);
      final landmarks = results[0] as List<Landmark>?;
      final yoloResult = results[1] as List<Map<String, dynamic>>;
      
      final filteredYoloResults = yoloResult.where((result) => result['tag'] == 'person').toList();

      if (mounted) {
        setState(() {
          if (landmarks != null) {
            _landmarks = landmarks;
            final metrics = _analyzer.analyzePose(landmarks);
            if (metrics != null) {
              _currentMetrics = metrics;
              _sessionData.add(metrics);
            }
          }
          if (filteredYoloResults.isNotEmpty) {
            _yoloResults = filteredYoloResults;
          } else {
            _yoloResults = []; 
          }
        });
      }
    } catch (e) {
      print('❌ Error processing camera image: $e');
    } finally {
      _isDetecting = false;
    }
  }

  // --- Training Controls ---

  void _startTraining() {
    setState(() {
      _isTraining = true;
      _isPaused = false;
      _sessionStart = DateTime.now();
      _showInstructions = false;
    });
    _analyzer.reset();
    _sessionData.clear();
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted && _isTraining && !_isPaused) setState(() {});
    });
    HapticFeedback.lightImpact();
  }

  void _pauseResumeTraining() {
    setState(() { _isPaused = !_isPaused; });
    HapticFeedback.selectionClick();
  }

  void _stopTraining() {
    setState(() {
      _isTraining = false;
      _isPaused = false;
    });
    _sessionTimer?.cancel();
    if (_sessionStart != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ResultsScreen(
            sessionData: _sessionData,
            sessionDuration: DateTime.now().difference(_sessionStart!),
          ),
        ),
      );
    }
    HapticFeedback.mediumImpact();
  }

  void _resetSession() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset Session?'),
        content: Text('This will clear all current training data.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _sessionData.clear();
                _currentMetrics = null;
                _sessionStart = DateTime.now();
              });
              _analyzer.reset();
            },
            child: Text('Reset'),
          ),
        ],
      ),
    );
  }

  // --- Build Methods ---

  @override
  Widget build(BuildContext context) {
    if (_initializationError != null) return _buildErrorScreen();
    if (!_isInitialized || _cameraController == null || !_cameraController!.value.isInitialized) {
        return _buildLoadingScreen();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // --- THIS IS THE FINAL FIX FOR FULL-SCREEN CAMERA ---
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraController!.value.previewSize!.height,
                  height: _cameraController!.value.previewSize!.width,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            ),
            // ----------------------------------------------------
            
            // All overlays are built on top of the stable camera preview
            if (_landmarks.isNotEmpty)
              CustomPaint(
                size: MediaQuery.of(context).size,
                painter: PosePainter(
                  landmarks: _landmarks,
                  imageSize: _cameraController!.value.previewSize!,
                ),
              ),
            _buildYoloResultsOverlay(),
            _buildTopStatusBar(),
            if (_currentMetrics != null && _isTraining && !_isPaused)
              _buildMetricsDisplay(),
            if (_currentMetrics != null && _isTraining && !_isPaused)
              _buildFeedbackMessage(),
            if (_isPaused) _buildPauseOverlay(),
            if (_showInstructions) _buildInstructionsOverlay(),
            _buildControlButtons(),
          ],
        ),
      ),
    );
  }

  // --- UI Helper Widgets (Your Original Code) ---

  Widget _buildYoloResultsOverlay() {
    final size = MediaQuery.of(context).size;
    if (_yoloResults.isEmpty) return const SizedBox.shrink();
    return Stack(
      children: _yoloResults.map((result) {
        return Positioned(
          left: result['box'][0] * size.width,
          top: result['box'][1] * size.height,
          width: (result['box'][2] - result['box'][0]) * size.width,
          height: (result['box'][3] - result['box'][1]) * size.height,
          child: Container(
            decoration: BoxDecoration(border: Border.all(color: Colors.cyan, width: 2)),
            child: Align(
              alignment: Alignment.topLeft,
              child: Container(
                color: Colors.cyan,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  '${result['tag']} ${(result['box'][4] * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.red, strokeWidth: 3),
            SizedBox(height: 24),
            Text('Initializing AI Camera...', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500)),
            SizedBox(height: 12),
            Text('Please wait while we set up pose detection', style: TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48),
            SizedBox(height: 24),
            Text('Initialization Failed', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(_initializationError!, style: TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _initializationError = null;
                  _isInitialized = false;
                });
                _initializeApp();
              },
              child: Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopStatusBar() {
    return Positioned(
      top: 12, left: 16, right: 16,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  color: _isTraining ? (_isPaused ? Colors.orange : Colors.green) : Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 8),
              Text(
                _isTraining ? (_isPaused ? 'PAUSED' : 'TRAINING') : 'READY',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ]),
            if (_isTraining && _sessionStart != null)
              Text(
                _formatDuration(DateTime.now().difference(_sessionStart!)),
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFeatures: [FontFeature.tabularFigures()]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsDisplay() {
    return Positioned(
      top: 80, left: 16, right: 16,
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _currentMetrics!.isInRange ? Colors.green : Colors.red, width: 2),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('${_currentMetrics!.compressionRate.toInt()}', style: TextStyle(color: _currentMetrics!.isInRange ? Colors.green : Colors.red, fontSize: 42, fontWeight: FontWeight.bold, fontFeatures: [FontFeature.tabularFigures()])),
                Text('/min', style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.w500)),
              ],
            ),
            SizedBox(height: 8),
            Text('Target: 100-120/min', style: TextStyle(color: Colors.white70, fontSize: 14)),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildMetricItem('Total', '${_currentMetrics!.totalCompressions}', Icons.replay),
                _buildMetricItem('Depth', '${_currentMetrics!.estimatedDepth.toStringAsFixed(1)}cm', Icons.vertical_align_center),
                _buildMetricItem('Quality', _currentMetrics!.isInRange ? 'Good' : 'Adjust', _currentMetrics!.isInRange ? Icons.check_circle : Icons.warning),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackMessage() {
    return Positioned(
      left: 20, right: 20,
      top: MediaQuery.of(context).size.height * 0.45,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _getFeedbackColor().withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Text(
          _getFeedbackMessage(),
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildPauseOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pause_circle_filled, size: 80, color: Colors.orange),
            SizedBox(height: 16),
            Text('Training Paused', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Tap resume to continue', style: TextStyle(color: Colors.white70, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionsOverlay() {
    return GestureDetector(
      onTap: _startTraining,
      child: Container(
        color: Colors.black.withOpacity(0.9),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              margin: EdgeInsets.all(20),
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite, size: 48, color: Colors.red),
                  SizedBox(height: 16),
                  Text('CPR AI Trainer', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey[800])),
                  SizedBox(height: 16),
                  _buildInstructionItem(Icons.visibility, 'Position yourself in camera view'),
                  _buildInstructionItem(Icons.pan_tool, 'Practice on a firm surface or mannequin'),
                  _buildInstructionItem(Icons.speed, 'Target: 100-120 compressions per minute'),
                  _buildInstructionItem(Icons.straighten, 'Keep your arms straight'),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _startTraining,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text('Start Training', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlButtons() {
    return Positioned(
      bottom: 30, left: 0, right: 0,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildControlButton(icon: Icons.close, label: 'Exit', color: Colors.grey[700]!, onPressed: () => Navigator.pop(context)),
            if (_isTraining)
              _buildControlButton(icon: _isPaused ? Icons.play_arrow : Icons.pause, label: _isPaused ? 'Resume' : 'Pause', color: Colors.orange, onPressed: _pauseResumeTraining),
            if (_isTraining)
              _buildControlButton(icon: Icons.refresh, label: 'Reset', color: Colors.blue, onPressed: _resetSession),
            _buildControlButton(icon: _isTraining ? Icons.stop : Icons.play_arrow, label: _isTraining ? 'Stop' : 'Start', color: _isTraining ? Colors.red : Colors.green, onPressed: _isTraining ? _stopTraining : _startTraining, isLarge: true),
          ],
        ),
      ),
    );
  }

  // --- UI Data Helpers ---

  Widget _buildMetricItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        SizedBox(height: 4),
        Text(value, style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFeatures: [FontFeature.tabularFigures()])),
        Text(label, style: TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildInstructionItem(IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.red, size: 20),
          SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(fontSize: 14, color: Colors.grey[700]))),
        ],
      ),
    );
  }

  Widget _buildControlButton({required IconData icon, required String label, required Color color, required VoidCallback onPressed, bool isLarge = false}) {
    final size = isLarge ? 70.0 : 56.0;
    final iconSize = isLarge ? 32.0 : 24.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size, height: size,
          child: FloatingActionButton(
            onPressed: onPressed,
            backgroundColor: color,
            heroTag: label,
            elevation: 4,
            child: Icon(icon, size: iconSize, color: Colors.white),
          ),
        ),
        SizedBox(height: 8),
        Text(label, style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Camera Permission Required'),
        content: Text('This app needs camera access to analyze your CPR technique.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: Text('Settings'),
          ),
        ],
      ),
    );
  }

  Color _getFeedbackColor() {
    if (_currentMetrics == null) return Colors.grey;
    if (!_currentMetrics!.armAngleFeedback.contains("Good")) return Colors.amber;
    if (_currentMetrics!.compressionRate < 100) return Colors.orange;
    if (_currentMetrics!.compressionRate > 120) return Colors.red;
    return Colors.green;
  }

  String _getFeedbackMessage() {
    if (_currentMetrics == null) return 'Getting ready...';
    
    if (!_currentMetrics!.armAngleFeedback.contains("Good")) {
      return _currentMetrics!.armAngleFeedback;
    }

    final rate = _currentMetrics!.compressionRate;
    if (rate < 80) return 'MUCH FASTER NEEDED\n${rate.toInt()}/min';
    if (rate < 100) return 'PUSH FASTER\nTarget: 100-120/min';
    if (rate > 140) return 'MUCH TOO FAST\n${rate.toInt()}/min';
    if (rate > 120) return 'SLOW DOWN\nTarget: 100-120/min';
    return 'EXCELLENT RHYTHM!\nKeep it up: ${rate.toInt()}/min';
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds % 60);
    return '$minutes:$seconds';
  }
}
