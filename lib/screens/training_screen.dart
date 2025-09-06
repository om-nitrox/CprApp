import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/pose_detection_service.dart';
import '../services/cpr_analyzer.dart';
import '../models/cpr_metrics.dart';
import 'results_screen.dart';

class TrainingScreen extends StatefulWidget {
  @override
  _TrainingScreenState createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  CameraController? _cameraController;
  PoseDetectionService _poseService = PoseDetectionService();
  CPRAnalyzer _analyzer = CPRAnalyzer();
  
  List<CPRMetrics> _sessionData = [];
  CPRMetrics? _currentMetrics;
  bool _isTraining = false;
  bool _isInitialized = false;
  DateTime? _sessionStart;
  bool _showInstructions = true;
  bool _isPaused = false;
  Timer? _sessionTimer;

  @override
  void initState() {
    super.initState();
    // Force portrait orientation for CPR training
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _requestPermissions();
    await _initializeCamera();
    await _initializePoseDetection();
    setState(() {
      _isInitialized = true;
    });
  }

  Future<void> _requestPermissions() async {
    final cameraStatus = await Permission.camera.request();
    if (cameraStatus != PermissionStatus.granted) {
      _showPermissionDialog();
    }
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

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        print('❌ No cameras available');
        return;
      }

      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await _cameraController!.initialize();
      
      // Start image stream for pose detection
      _cameraController!.startImageStream(_processCameraImage);
      
      print('✅ Camera initialized successfully');
    } catch (e) {
      print('❌ Error initializing camera: $e');
    }
  }

  Future<void> _initializePoseDetection() async {
    final success = await _poseService.initializePoseDetection();
    if (!success) {
      print('❌ Failed to initialize pose detection');
    }
  }

  void _processCameraImage(CameraImage image) async {
    if (!_isTraining || _isPaused) return;
    
    try {
      final landmarks = await _poseService.detectPose(image);
      
      if (landmarks != null && mounted) {
        final metrics = _analyzer.analyzePose(landmarks);
        
        setState(() {
          _currentMetrics = metrics;
        });
        
        _sessionData.add(metrics);
      }
    } catch (e) {
      print('❌ Error processing camera image: $e');
    }
  }

  void _startTraining() {
    setState(() {
      _isTraining = true;
      _isPaused = false;
      _sessionStart = DateTime.now();
      _showInstructions = false;
    });

    _analyzer.reset();
    _sessionData.clear();
    
    // Update session timer every second
    _sessionTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted && _isTraining && !_isPaused) {
        setState(() {}); // Trigger rebuild to update session time
      }
    });

    // Haptic feedback
    HapticFeedback.lightImpact();
  }

  void _pauseResumeTraining() {
    setState(() {
      _isPaused = !_isPaused;
    });
    
    HapticFeedback.selectionClick();
  }

  void _stopTraining() {
    setState(() {
      _isTraining = false;
      _isPaused = false;
    });
    
    _sessionTimer?.cancel();
    
    if (_sessionStart != null) {
      Navigator.push(
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
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

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  color: Colors.red,
                  strokeWidth: 3,
                ),
                SizedBox(height: 24),
                Text(
                  'Initializing AI Camera...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Please wait while we set up pose detection',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Camera Preview Background
            if (_cameraController != null && _cameraController!.value.isInitialized)
              Positioned.fill(
                child: AspectRatio(
                  aspectRatio: _cameraController!.value.aspectRatio,
                  child: CameraPreview(_cameraController!),
                ),
              )
            else
              Container(
                color: Colors.grey[900],
                child: Center(
                  child: Text(
                    'Camera not available',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            
            // Top Status Bar
            Positioned(
              top: 12,
              left: 16,
              right: 16,
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
                    // Status Indicator
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _isTraining 
                                ? (_isPaused ? Colors.orange : Colors.green)
                                : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          _isTraining 
                              ? (_isPaused ? 'PAUSED' : 'TRAINING')
                              : 'READY',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    
                    // Session Time
                    if (_isTraining && _sessionStart != null)
                      Text(
                        _formatDuration(DateTime.now().difference(_sessionStart!)),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            // Main Metrics Display
            if (_currentMetrics != null && _isTraining && !_isPaused)
              Positioned(
                top: 80,
                left: 16,
                right: 16,
                child: Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _currentMetrics!.isInRange ? Colors.green : Colors.red,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Compression Rate
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '${_currentMetrics!.compressionRate.toInt()}',
                            style: TextStyle(
                              color: _currentMetrics!.isInRange ? Colors.green : Colors.red,
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          Text(
                            '/min',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      
                      SizedBox(height: 8),
                      
                      // Target Range Indicator
                      Text(
                        'Target: 100-120/min',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      
                      SizedBox(height: 16),
                      
                      // Additional Metrics Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildMetricItem(
                            'Total',
                            '${_currentMetrics!.totalCompressions}',
                            Icons.replay,
                          ),
                          _buildMetricItem(
                            'Depth',
                            '${_currentMetrics!.estimatedDepth.toStringAsFixed(1)}cm',
                            Icons.vertical_align_center,
                          ),
                          _buildMetricItem(
                            'Quality',
                            _currentMetrics!.isInRange ? 'Good' : 'Adjust',
                            _currentMetrics!.isInRange ? Icons.check_circle : Icons.warning,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            
            // Feedback Message
            if (_currentMetrics != null && _isTraining && !_isPaused)
              Positioned(
                left: 20,
                right: 20,
                top: MediaQuery.of(context).size.height * 0.45,
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _getFeedbackColor().withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
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
              ),
            
            // Pause Overlay
            if (_isPaused)
              Container(
                color: Colors.black.withOpacity(0.7),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.pause_circle_filled,
                        size: 80,
                        color: Colors.orange,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Training Paused',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Tap resume to continue',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            // Instructions Overlay
            if (_showInstructions)
              Container(
                color: Colors.black.withOpacity(0.9),
                child: Center(
                  child: SingleChildScrollView(
                    child: Container(
                      margin: EdgeInsets.all(20),
                      padding: EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.favorite,
                            size: 48,
                            color: Colors.red,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'CPR AI Trainer',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          SizedBox(height: 16),
                          _buildInstructionItem(
                            Icons.visibility,
                            'Position yourself in camera view',
                          ),
                          _buildInstructionItem(
                            Icons.pan_tool,
                            'Practice on a firm surface or mannequin',
                          ),
                          _buildInstructionItem(
                            Icons.speed,
                            'Target: 100-120 compressions per minute',
                          ),
                          _buildInstructionItem(
                            Icons.smart_toy,
                            'Follow real-time AI feedback',
                          ),
                          SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: () => setState(() => _showInstructions = false),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'Start Training',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            
            // Control Buttons (Bottom)
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Close Button
                    _buildControlButton(
                      icon: Icons.close,
                      label: 'Exit',
                      color: Colors.grey[700]!,
                      onPressed: () => Navigator.pop(context),
                    ),
                    
                    // Pause/Resume Button (only when training)
                    if (_isTraining)
                      _buildControlButton(
                        icon: _isPaused ? Icons.play_arrow : Icons.pause,
                        label: _isPaused ? 'Resume' : 'Pause',
                        color: Colors.orange,
                        onPressed: _pauseResumeTraining,
                      ),
                    
                    // Reset Button (only when training)
                    if (_isTraining)
                      _buildControlButton(
                        icon: Icons.refresh,
                        label: 'Reset',
                        color: Colors.blue,
                        onPressed: _resetSession,
                      ),
                    
                    // Main Start/Stop Button
                    _buildControlButton(
                      icon: _isTraining ? Icons.stop : Icons.play_arrow,
                      label: _isTraining ? 'Stop' : 'Start',
                      color: _isTraining ? Colors.red : Colors.green,
                      onPressed: _isTraining ? _stopTraining : _startTraining,
                      isLarge: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
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
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
    bool isLarge = false,
  }) {
    final size = isLarge ? 70.0 : 56.0;
    final iconSize = isLarge ? 32.0 : 24.0;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          child: FloatingActionButton(
            onPressed: onPressed,
            backgroundColor: color,
            heroTag: label,
            elevation: 4,
            child: Icon(icon, size: iconSize, color: Colors.white),
          ),
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Color _getFeedbackColor() {
    if (_currentMetrics == null) return Colors.grey;
    if (_currentMetrics!.compressionRate < 100) return Colors.orange;
    if (_currentMetrics!.compressionRate > 120) return Colors.red;
    return Colors.green;
  }

  String _getFeedbackMessage() {
    if (_currentMetrics == null) return 'Getting ready...';
    
    final rate = _currentMetrics!.compressionRate;
    if (rate < 80) {
      return 'MUCH FASTER NEEDED\nCurrent: ${rate.toInt()}/min';
    } else if (rate < 100) {
      return 'PUSH FASTER\nTarget: 100-120/min';
    } else if (rate > 140) {
      return 'MUCH TOO FAST\nCurrent: ${rate.toInt()}/min';
    } else if (rate > 120) {
      return 'SLOW DOWN\nTarget: 100-120/min';
    } else {
      return 'EXCELLENT RHYTHM!\nKeep it up: ${rate.toInt()}/min';
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds % 60);
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    // Restore all orientations when leaving
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    _sessionTimer?.cancel();
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _poseService.dispose();
    super.dispose();
  }
}
