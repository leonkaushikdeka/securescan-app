# SecureScan App - Developer Onboarding Guide

Welcome to the SecureScan project! This guide will help you understand the app, its architecture, and how to contribute.

## What is SecureScan?

SecureScan is a **free, offline Android app** that helps users detect:
1. **Deepfakes** - AI-generated or manipulated images
2. **Phishing URLs** - Malicious websites that steal personal information

**Key Philosophy:** 100% local processing. No user data ever leaves the device.

---

## Quick Start for New Developers

### 1. Setting Up Your Environment

```bash
# Clone the repository
git clone <repo-url>
cd securescanapp_new

# Install Flutter dependencies
flutter pub get

# Run on Android emulator
flutter run -d emulator-5554

# Build release APK
flutter build apk --release
```

### 2. Project Structure

```
securescanapp_new/
├── lib/
│   ├── main.dart                 # App entry point, DI setup
│   ├── core/                     # Shared services
│   │   ├── logger.dart          # Logging system
│   │   ├── analytics.dart       # Event tracking
│   │   └── crash_reporter.dart  # Error tracking
│   ├── features/                # Feature modules
│   │   ├── deepfake/            # Deepfake detection
│   │   ├── phishing/            # Phishing detection
│   │   ├── history/             # Scan history
│   │   └── settings/            # App settings
│   └── test/                    # Unit tests
├── assets/
│   └── models/                  # ML models
├── android/                     # Android config
└── pubspec.yaml                # Dependencies
```

---

## Understanding the Architecture

### Feature-First Design

Each feature (deepfake, phishing, history, settings) is a **self-contained module** in `lib/features/`. This makes the app:
- Easy to understand
- Easy to test
- Easy to maintain

### Core Services (lib/core/)

These are shared across all features:

| Service | Purpose |
|---------|---------|
| `logger.dart` | Debug logging for development |
| `analytics.dart` | Track user behavior (opt-in) |
| `crash_reporter.dart` | Capture errors for debugging |

### The Main App (lib/main.dart)

The `main.dart` file handles:
- Initializing all services
- Setting up navigation (4 tabs)
- Background task scheduling
- Database initialization

---

## Deepfake Detection - How It Works

### The Two Approaches

**1. ML Model Detection (When Available)**
```dart
// If a TensorFlow Lite model exists at assets/models/deepfake.tflite
// The app uses it for deepfake classification
_interpreter = await Interpreter.fromAsset('assets/models/deepfake.tflite');
```

**2. Heuristic Analysis (Fallback - Always On)**
When no ML model is available, the app uses image analysis:

```dart
Future<DeepfakeDetectionResult> _runHeuristicAnalysis(imageBytes) {
  // Analyzes 6 factors:
  // 1. Face regions - checks for GAN smoothness
  // 2. Noise patterns - looks for inconsistent noise
  // 3. Compression - detects double compression artifacts
  // 4. Frequency - catches GAN frequency signatures
  // 5. Edges - finds boundary artifacts
  // 6. Color/lighting - detects inconsistent shadows
}
```

### How Detection Works

```dart
// Each factor returns a score 0.0 to 1.0
final faceAnalysis = _analyzeFaceRegions(imageBytes);
// Returns: { 'consistency': 0.75, 'artifacts': 0.15 }

// Weighted combination (conservative approach)
double fakeScore = 0.0;
fakeScore += faceAnalysis['artifacts']! * 0.20;
fakeScore += (1.0 - faceAnalysis['consistency']!) * 0.10;
// ... more factors

// Final decision
final isDeepfake = fakeScore > 0.55;  // Need strong evidence
```

### Adding a Better ML Model

1. Download a trained model (TFLite format)
2. Place it at: `assets/models/deepfake.tflite`
3. The app will automatically use it

**Recommended free models:**
- Meso4 (lightweight CNN)
- EfficientNet-based classifiers

---

## Phishing Detection - How It Works

### The Detection Pipeline

```dart
Future<PhishingDetectionResult> detect(String url) {
  // 1. Check whitelist (known safe domains)
  if (_isWhitelisted(domain)) return safe;

  // 2. Run 22+ detection patterns
  // 3. Score each finding
  // 4. Calculate total threat score
  // 5. Return risk level
}
```

### Detection Patterns (22+)

| Category | Examples |
|----------|----------|
| **Blacklist** | Known phishing domains (30+) |
| **Typosquatting** | `goole.com` (looks like google.com) |
| **Brand Impersonation** | `paypal-secure.com` |
| **IP Addresses** | `http://192.168.1.1` |
| **URL Shorteners** | `bit.ly`, `tinyurl.com` |
| **Suspicious TLDs** | `.xyz`, `.tk`, `.top` |
| **Urgency Language** | "URGENT", "Account Suspended" |
| **Indian Scams** | KYC pending, Aadhaar linking |
| **Delivery Scams** | "Your parcel is held" |

### Scoring System

```
Critical: 80+ points  → CRITICAL risk
High:     50-79       → HIGH risk
Medium:   25-49       → MEDIUM risk
Low:      10-24       → LOW risk
Safe:     0-9         → SAFE
```

---

## Key Files to Understand

### For Deepfake Detection
- `lib/features/deepfake/deepfake_detector_service.dart` - Core detection logic
- `lib/features/deepfake/deepfake_scan_page.dart` - UI for scanning

### For Phishing Detection
- `lib/features/phishing/phishing_detector_service.dart` - Core detection logic
- `lib/features/phishing/phishing_scan_page.dart` - UI for scanning

### For Shared Services
- `lib/core/logger.dart` - How to log: `appLogger.i("Message")`
- `lib/core/analytics.dart` - How to track: `analyticsService.logEvent("name")`

---

## Common Tasks

### Adding a New Detection Pattern

**For Phishing:**
```dart
// In phishing_detector_service.dart
1. Add keyword to _suspiciousKeywords list
// OR
2. Add new detection method
// OR
3. Add to blacklist
```

**Example:**
```dart
// Add suspicious keyword
_finalList<String> _suspiciousKeywords = [
  'newkeyword',  // Add here
  // ...
];

// Add detection logic
if (domain.contains('newkeyword')) {
  findings.add(ThreatFinding(
    type: ThreatType.suspiciousKeywords,
    severity: RiskLevel.medium,
    description: 'Suspicious keyword found',
    score: 10,
  ));
}
```

### Adding a New Test

**For Phishing:**
```dart
// test/phishing_test.dart
test('should detect new scam pattern', () async {
  final result = await detector.detect('new-scam-domain.xyz');
  expect(result.isPhishing, true);
});
```

### Modifying the UI

**To change colors/theming:**
```dart
// lib/main.dart - MaterialApp theme
theme: ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.blue.shade700,
    // Change primary color here
  ),
)
```

### Changing Detection Sensitivity

**For Deepfake:**
```dart
// In deepfake_detector_service.dart, line ~207
final isDeepfake = fakeScore > 0.55;  // Higher = more conservative
// 0.55 = Only flag obvious deepfakes
// 0.40 = Flag more images
// 0.30 = Very aggressive
```

**For Phishing:**
```dart
// In phishing_detector_service.dart, _calculateRiskLevel()
if (score >= 80) return RiskLevel.critical;  // Increase to 90 for stricter
if (score >= 50) return RiskLevel.high;       // Increase to 60 for stricter
```

---

## Dependencies You Should Know

| Package | Purpose |
|---------|---------|
| `tflite_flutter` | Running ML models on-device |
| `sqflite` | Local SQLite database |
| `shared_preferences` | Simple key-value storage |
| `workmanager` | Background tasks |
| `flutter_local_notifications` | Push notifications |
| `image_picker` | Selecting images from gallery/camera |

---

## Debugging Tips

### View Logs
```bash
flutter run 2>&1 | grep -i "appLogger"
```

### Enable Verbose Logging
```dart
// In your code
appLogger.configure(
  enableConsole: true,
  minLevel: LogLevel.debug,  // Change to info for less output
);
```

### Test Phishing Detection
```dart
// Use these URLs to test:
await detector.detect('google.com')        // Should be SAFE
await detector.detect('paypal-secure.com') // Should be CRITICAL
await detector.detect('goole.com')         // Should be HIGH (typosquatting)
```

### Test Deepfake Detection
```dart
// Real photos → AUTHENTIC
// AI-generated → DEEPFAKE (if clear evidence)
```

---

## Building for Production

### Release Build
```bash
flutter build apk --release
```

### Test Release Build
```bash
flutter install -d emulator-5554
```

### Check for Issues
```bash
flutter analyze lib/
```

---

## Common Issues & Solutions

### "Interpreter output shape mismatch"
The ML model has an unexpected output format. Fix in:
`lib/features/deepfake/deepfake_detector_service.dart`
The `_createShapedOutput()` method handles flexible shapes.

### "Deepfake detection too aggressive"
Lower the detection threshold:
```dart
final isDeepfake = fakeScore > 0.65;  // More conservative
```

### "Phishing detection misses some URLs"
Add to the blacklist or detection patterns in:
`lib/features/phishing/phishing_detector_service.dart`

---

## Learning Resources

### Flutter Basics
- https://flutter.dev/docs
- https://docs.flutter.dev/development/ui

### TensorFlow Lite
- https://www.tensorflow.org/lite/guide

### Deepfake Detection Research
- Meso4 paper: "Real-time Forgery Detection"
- EfficientNet: https://tfhub.dev/google/aiy/vision/classifier

---

## Questions?

1. **Check the code first** - Most answers are in the comments
2. **Check the logs** - Use `appLogger.d()` to trace execution
3. **Run tests** - `flutter test`
4. **Ask for help** - The code is well-structured for learning

---

**Happy coding! 🔒**
