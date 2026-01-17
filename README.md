# SecureScan App

<div align="center">

![SecureScan Logo](https://img.shields.io/badge/SecureScan-Deepfake%20%26%20Phishing%20Detection-blue?style=for-the-badge)
![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue?style=flat-square&logo=flutter)
![Platform](https://img.shields.io/badge/Platform-Android%20Only-green?style=flat-square)
![License](https://img.shields.io/badge/License-MIT-yellow?style=flat-square)

**A production-ready Flutter Android app for detecting deepfakes and phishing URLs - 100% offline.**

[Features](#features) • [Installation](#installation) • [Usage](#usage) • [Architecture](#architecture)

</div>

---

## Overview

SecureScan is a privacy-focused mobile application that detects:
- **Deepfakes** - AI-generated or manipulated images
- **Phishing URLs** - Malicious and suspicious web links

All detection happens **locally on your device** - no data is ever sent to external servers.

## Features

### 🔍 Deepfake Detection
- **ML Model Support** - TensorFlow Lite integration for image analysis
- **Heuristic Analysis** - 6-factor detection without ML model
  - Face Region Consistency (GAN smoothness detection)
  - Noise Pattern Analysis (inconsistent noise patterns)
  - Compression Artifact Detection (double compression)
  - Frequency Domain Analysis (GAN signatures)
  - Edge Quality Assessment (boundary artifacts)
  - Color/Lighting Consistency (shadow inconsistencies)
- **Conservative Confidence** - Reduces false positives

### 🛡️ Phishing Detection
- **22+ Detection Patterns** including:
  - Blacklist matching (30+ known phishing domains)
  - IP Address URL detection
  - URL shortener warnings
  - Typosquatting detection (Indian banks, global brands)
  - Suspicious TLDs (.xyz, .tk, .top)
  - APK download detection
  - Urgency/Lottery scam keywords
  - And more...

### 📋 Scan History
- SQLite database storage
- Stores 100 scan entries
- Searchable and filterable
- Export functionality

### ⚙️ Settings
- Background protection toggle
- Notification preferences
- Clipboard monitoring
- Analytics opt-in/out
- Privacy policy

## Installation

### Prerequisites
- Flutter 3.0+
- Android SDK 21+
- Android device or emulator

### Setup

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/securescan-app.git
cd securescan-app

# Get dependencies
flutter pub get

# Run on connected device
flutter run

# Build release APK
flutter build apk --release
```

### APK Output
The release APK will be at:
```
build/app/outputs/flutter-apk/app-release.apk
```

## Usage

### Deepfake Scanning
1. Open the app
2. Select "Deepfake Detection"
3. Choose an image from gallery or camera
4. View detection results with confidence score

### Phishing Scanning
1. Open the app
2. Select "Phishing Detection"
3. Enter or paste a URL
4. View risk assessment (Critical/High/Medium/Low/Safe)

### View History
1. Tap "History" in the navigation
2. Browse past scans
3. Filter by type (deepfake/phishing)
4. Search through entries

## Architecture

```
lib/
├── main.dart                    # App entry, DI, navigation
├── core/
│   ├── logger.dart             # Logging service
│   ├── analytics.dart          # Analytics service
│   └── crash_reporter.dart     # Crash reporting
├── features/
│   ├── deepfake/
│   │   ├── deepfake_detector_service.dart
│   │   └── deepfake_scan_page.dart
│   ├── phishing/
│   │   ├── phishing_detector_service.dart
│   │   └── phishing_scan_page.dart
│   ├── history/
│   │   └── history_page.dart
│   └── settings/
│       └── settings_page.dart
└── services/
    ├── enhanced_phishing_detector.dart
    ├── overlay_service.dart
    ├── notification_service.dart
    └── realtime_deepfake_detector.dart
```

## Technical Stack

| Component | Technology |
|-----------|------------|
| Framework | Flutter |
| ML Engine | TensorFlow Lite |
| Database | SQLite (sqflite) |
| Background Tasks | WorkManager |
| Notifications | flutter_local_notifications |
| Image Processing | image_picker, image |

## Detection Accuracy

### Deepfake Detection
- **Threshold:** fakeScore > 0.55
- **Authentic Base Confidence:** 85%
- **Fake Base Confidence:** 65%
- **Maximum Confidence:** 98%

### Phishing Detection
| Risk Level | Score Range |
|------------|-------------|
| Critical | 80+ points |
| High | 50-79 points |
| Medium | 25-49 points |
| Low | 10-24 points |
| Safe | 0-9 points |

## Privacy

🔒 **100% Offline Operation**
- All processing happens on-device
- No data transmitted to external servers
- No cloud dependencies
- No account required

## Testing

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/phishing_test.dart

# Code analysis
flutter analyze lib/
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [TensorFlow Lite](https://www.tensorflow.org/lite) for ML inference
- [Flutter](https://flutter.dev) for the cross-platform framework
- Open source community for various dependencies

---

<div align="center">

**Made with ❤️ for a safer internet**

</div>
