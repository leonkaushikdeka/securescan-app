# Deepfake Detection Model

## Current Status
This is a placeholder. You need to add a real TensorFlow Lite model.

## How to Get a Model

### Option 1: Download MiniFASNetV2 (Recommended - 600KB, 98% accuracy)
1. Go to: https://github.com/johnraivenolazo/face-antispoof-onnx
2. Download the ONNX model file
3. Convert to TFLite using:
   ```
   python -c "
   import onnx
   from onnx2tf import convert
   
   model = onnx.load('model.onnx')
   convert(model, output_folder='output')
   "
   ```
4. Copy the .tflite file here as 'deepfake.tflite'

### Option 2: Use Silent Face Anti-Spoofing TFLite (1-2MB, 95%+ accuracy)
1. Go to: https://github.com/feni-katharotiya/silent-face-anti-spoofing-tflite
2. Download the TFLite model
3. Copy to this folder as 'deepfake.tflite'

### Option 3: Use Meso4 (2-5MB, 85-90% accuracy)
1. Go to: https://github.com/DariusAf/MesoNet
2. Download the pre-trained weights
3. Convert PyTorch to TFLite

## Model Requirements
- Input shape: [1, 128, 128, 3] or [1, 3, 224, 224]
- Output: 2 classes (real, fake)
- Size: Under 10MB preferred
- Format: .tflite

## Labels File
The labels.txt file should contain:
```
real
fake
```

One label per line.

## Integration
The app expects the model at: `assets/models/deepfake.tflite`
