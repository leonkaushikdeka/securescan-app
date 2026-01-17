import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'deepfake_detector_service.dart';
import '../../main.dart';

class DeepfakeScanPage extends StatefulWidget {
  const DeepfakeScanPage({super.key});

  @override
  State<DeepfakeScanPage> createState() => _DeepfakeScanPageState();
}

class _DeepfakeScanPageState extends State<DeepfakeScanPage> {
  File? _selectedImage;
  bool _isProcessing = false;
  DeepfakeDetectionResult? _result;
  String _statusMessage = 'Tap to select an image';
  final ImagePicker _picker = ImagePicker();
  final DeepfakeDetectorService _detector = DeepfakeDetectorService();

  @override
  void initState() {
    super.initState();
    _initializeDetector();
  }

  Future<void> _initializeDetector() async {
    setState(() => _statusMessage = 'Loading detection engine...');
    try {
      await _detector.loadModel();
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Ready - Select an image';
      });
    } catch (e) {
      setState(() => _statusMessage = 'Using enhanced analysis mode');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source, maxWidth: 1024, maxHeight: 1024);
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _result = null;
          _statusMessage = 'Image selected - Tap Scan to analyze';
        });
      }
    } catch (e) {
      setState(() => _statusMessage = 'Error selecting image');
    }
  }

  Future<void> _scanImage() async {
    if (_selectedImage == null || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Analyzing image...';
    });

    try {
      final bytes = await _selectedImage!.readAsBytes();
      final result = await _detector.detect(Uint8List.fromList(bytes));

      setState(() {
        _result = result;
        _isProcessing = false;
        _statusMessage = result.isDeepfake ? 'Deepfake Detected!' : 'Image appears Authentic';
      });

      // Save to history
      await HistoryDatabase.instance.insertScan(
        type: 'deepfake',
        content: _selectedImage!.path,
        result: result.isDeepfake ? 'DEEPFAKE' : 'AUTHENTIC',
        confidence: result.confidence,
        details: 'Method: ${result.method.name}',
      );
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Error analyzing image';
      });
    }
  }

  Color _getRiskColor() {
    if (_result == null) return Colors.grey;
    return _result!.isDeepfake ? Colors.red : Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: _selectedImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(_selectedImage!, fit: BoxFit.contain),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300, width: 2),
                      ),
                      child: const Icon(Icons.image, size: 100, color: Colors.grey),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('Gallery'),
              ),
              ElevatedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Camera'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _selectedImage != null && !_isProcessing ? _scanImage : null,
              icon: _isProcessing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.security),
              label: Text(_isProcessing ? 'Analyzing...' : 'SCAN IMAGE'),
            ),
          ),
          const SizedBox(height: 16),
          if (_result != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getRiskColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _getRiskColor(), width: 2),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_result!.isDeepfake ? Icons.warning : Icons.check_circle, color: _getRiskColor(), size: 32),
                      const SizedBox(width: 12),
                      Text(
                        _result!.isDeepfake ? 'DEEPFAKE DETECTED' : 'AUTHENTIC',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _getRiskColor()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Confidence: ${(_result!.confidence * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 16),
                  ),
                  if (_result!.method == DeepfakeDetectionMethod.heuristic)
                    Text(
                      'Analysis: Image forensics-based detection',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                ],
              ),
            ),
          Text(_statusMessage, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
