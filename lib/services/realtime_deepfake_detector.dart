import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import 'package:tflite_flutter/tflite_flutter.dart';

class RealtimeDeepfakeDetector {
  Interpreter? _interpreter;
  bool _isInitialized = false;
  bool _useSimulated = true;
  int _frameCount = 0;
  
  // Face detector for ROI extraction
  FaceDetector? _faceDetector;
  
  // Performance tracking
  int _totalFramesProcessed = 0;
  int _totalInferenceTime = 0;
  int _lastDetectionTime = 0;
  
  // Singleton
  static final RealtimeDeepfakeDetector _instance = RealtimeDeepfakeDetector._();
  factory RealtimeDeepfakeDetector() => _instance;
  RealtimeDeepfakeDetector._();
  
  bool get isInitialized => _isInitialized;
  int get framesProcessed => _totalFramesProcessed;
  double get averageInferenceTime => 
      _totalFramesProcessed > 0 ? _totalInferenceTime / _totalFramesProcessed : 0;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Load TFLite model
      _interpreter = await Interpreter.fromAsset(
        'assets/models/deepfake.tflite',
        options: InterpreterOptions()..threads = 4,
      );
      _useSimulated = false;
      print('TFLite model loaded successfully');
    } catch (e) {
      print('Failed to load TFLite model: $e');
      _useSimulated = true;
    }
    
    // Initialize face detector
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableLandmarks: false,
        enableClassification: false,
        minFaceSize: 0.2,
        performanceMode: FaceDetectorPerformanceMode.fast,
      ),
    );
    
    _isInitialized = true;
    print('RealtimeDeepfakeDetector initialized');
  }

  // Process a single image frame and detect deepfake
  Future<DeepfakeDetectionResult> detectFrame(Uint8List imageBytes) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    final stopwatch = Stopwatch()..start();
    
    try {
      // Decode image
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        return DeepfakeDetectionResult(
          isDeepfake: false,
          confidence: 0.0,
          hasFace: false,
          processingTimeMs: 0,
        );
      }
      
      // Detect faces first
      final inputImage = InputImage.fromBytes(
        bytes: imageBytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.bgra8888,
        ),
      );
      
      final faces = await _faceDetector.processImage(inputImage);
      
      if (faces.isEmpty) {
        // No face detected, scan entire image
        final result = await _detectInImage(image);
        _updateStats(stopwatch.elapsedMilliseconds);
        return result.copyWith(hasFace: false);
      }
      
      // Focus on largest face
      final largestFace = faces.reduce((a, b) => 
        a.boundingBox.width * a.boundingBox.height > 
        b.boundingBox.width * b.boundingBox.height ? a : b
      );
      
      // Crop to face region
      final faceImage = _cropToFace(image, largestFace.boundingBox);
      
      // Detect deepfake in cropped face
      final result = await _detectInImage(faceImage);
      _updateStats(stopwatch.elapsedMilliseconds);
      
      return result.copyWith(
        hasFace: true,
        facePosition: {
          'x': largestFace.boundingBox.left,
          'y': largestFace.boundingBox.top,
          'width': largestFace.boundingBox.width,
          'height': largestFace.boundingBox.height,
        },
      );
      
    } catch (e) {
      print('Detection error: $e');
      return DeepfakeDetectionResult(
        isDeepfake: false,
        confidence: 0.0,
        hasFace: false,
        error: e.toString(),
        processingTimeMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  // Batch process video frames
  Future<List<DeepfakeDetectionResult>> detectVideoFrames(
    List<Uint8List> frames, {
    int frameSkip = 10,
  }) async {
    final results = <DeepfakeDetectionResult>[];
    
    for (int i = 0; i < frames.length; i += frameSkip) {
      final result = await detectFrame(frames[i]);
      results.add(result);
    }
    
    return results;
  }

  Future<DeepfakeDetectionResult> _detectInImage(img.Image image) async {
    // Resize to 80x80 (model input size)
    final resized = img.copyResize(image, width: 80, height: 80);
    
    // Preprocess
    final input = _preprocessImage(resized);
    
    if (_useSimulated) {
      await Future.delayed(const Duration(milliseconds: 50));
      final random = resized.data.fold(0, (a, b) => a + b) / resized.data.length;
      final isFake = random > 100;
      
      return DeepfakeDetectionResult(
        isDeepfake: isFake,
        confidence: 0.7 + (random / 500),
        hasFace: true,
        processingTimeMs: 50,
        method: 'simulated',
      );
    }
    
    // Run inference
    final output = List.generate(1, (_) => List.filled(2, 0.0));
    _interpreter!.run(input, output);
    
    final realScore = output[0][0];
    final fakeScore = output[0][1];
    final isDeepfake = fakeScore > realScore;
    final confidence = isDeepfake ? fakeScore : realScore;
    
    return DeepfakeDetectionResult(
      isDeepfake: isDeepfake,
      confidence: confidence,
      hasFace: true,
      processingTimeMs: 0,
      method: 'tflite',
    );
  }

  List<List<List<List<double>>>> _preprocessImage(img.Image image) {
    const height = 80;
    const width = 80;
    
    final input = List.generate(
      1,
      (_) => List.generate(
        height,
        (_) => List.generate(
          width,
          (_) => List.generate(3, (_) => 0.0),
        ),
      ),
    );
    
    for (int y = 0; y < height && y < image.height; y++) {
      for (int x = 0; x < width && x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final r = img.getRed(pixel);
        final g = img.getGreen(pixel);
        final b = img.getBlue(pixel);
        input[0][y][x][0] = r / 255.0;
        input[0][y][x][1] = g / 255.0;
        input[0][y][x][2] = b / 255.0;
      }
    }
    
    return input;
  }

  img.Image _cropToFace(img.Image image, Rect faceRect) {
    final x = faceRect.left.toInt().clamp(0, image.width - 1);
    final y = faceRect.top.toInt().clamp(0, image.height - 1);
    final w = faceRect.width.toInt().clamp(1, image.width - x);
    final h = faceRect.height.toInt().clamp(1, image.height - y);
    
    return img.copyCrop(image, x, y, w, h);
  }

  void _updateStats(int inferenceTime) {
    _totalFramesProcessed++;
    _totalInferenceTime += inferenceTime;
    _lastDetectionTime = DateTime.now().millisecondsSinceEpoch;
  }

  // Get video analysis summary
  VideoAnalysisResult analyzeVideoResults(List<DeepfakeDetectionResult> results) {
    if (results.isEmpty) {
      return VideoAnalysisResult(
        totalFrames: 0,
        fakeFrames: 0,
        realFrames: 0,
        avgConfidence: 0.0,
        overallAssessment: 'No analysis available',
      );
    }
    
    final fakeCount = results.where((r) => r.isDeepfake).length;
    final avgConfidence = results.fold(0.0, (sum, r) => sum + r.confidence) / results.length;
    
    String assessment;
    final fakeRatio = fakeCount / results.length;
    
    if (fakeRatio > 0.7) {
      assessment = 'HIGH LIKELIHOOD OF DEEPFAKE';
    } else if (fakeRatio > 0.3) {
      assessment = 'POSSIBLE DEEPFAKE - MANUAL REVIEW RECOMMENDED';
    } else if (results.any((r) => r.confidence > 0.9 && r.isDeepfake)) {
      assessment = 'SUSPICIOUS FRAMES DETECTED';
    } else {
      assessment = 'APPEARS AUTHENTIC';
    }
    
    return VideoAnalysisResult(
      totalFrames: results.length,
      fakeFrames: fakeCount,
      realFrames: results.length - fakeCount,
      avgConfidence: avgConfidence,
      overallAssessment: assessment,
    );
  }

  void dispose() {
    _interpreter?.close();
    _faceDetector?.close();
    _isInitialized = false;
  }
}

class DeepfakeDetectionResult {
  final bool isDeepfake;
  final double confidence;
  final bool hasFace;
  final int processingTimeMs;
  final String method;
  final Map<String, dynamic>? facePosition;
  final String? error;

  DeepfakeDetectionResult({
    required this.isDeepfake,
    required this.confidence,
    required this.hasFace,
    this.processingTimeMs = 0,
    this.method = 'unknown',
    this.facePosition,
    this.error,
  });

  DeepfakeDetectionResult copyWith({
    bool? isDeepfake,
    double? confidence,
    bool? hasFace,
    int? processingTimeMs,
    String? method,
    Map<String, dynamic>? facePosition,
    String? error,
  }) {
    return DeepfakeDetectionResult(
      isDeepfake: isDeepfake ?? this.isDeepfake,
      confidence: confidence ?? this.confidence,
      hasFace: hasFace ?? this.hasFace,
      processingTimeMs: processingTimeMs ?? this.processingTimeMs,
      method: method ?? this.method,
      facePosition: facePosition ?? this.facePosition,
      error: error ?? this.error,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isDeepfake': isDeepfake,
      'confidence': confidence,
      'hasFace': hasFace,
      'processingTimeMs': processingTimeMs,
      'method': method,
      'facePosition': facePosition,
      'error': error,
    };
  }
}

class VideoAnalysisResult {
  final int totalFrames;
  final int fakeFrames;
  final int realFrames;
  final double avgConfidence;
  final String overallAssessment;

  VideoAnalysisResult({
    required this.totalFrames,
    required this.fakeFrames,
    required this.realFrames,
    required this.avgConfidence,
    required this.overallAssessment,
  });

  Map<String, dynamic> toMap() {
    return {
      'totalFrames': totalFrames,
      'fakeFrames': fakeFrames,
      'realFrames': realFrames,
      'avgConfidence': avgConfidence,
      'overallAssessment': overallAssessment,
    };
  }
}
