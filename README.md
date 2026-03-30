# SecureScan

**100% offline deepfake and phishing URL detection for Android.**

No data leaves your device. No cloud APIs. No accounts required.

---

## Features

### Deepfake Detection
Analyzes images using a 10-signal heuristic system derived from published image forensics research. When a TFLite model is present it uses that; otherwise the heuristic engine runs automatically.

| Signal | What it detects |
|---|---|
| Error Level Analysis (ELA) | Inconsistent JPEG compression history across regions |
| Benford's Law (DCT) | DCT AC coefficient distribution deviating from natural images (χ² test) |
| Checkerboard artifact | Periodic GAN transposed-conv upsampling pattern |
| Chromatic aberration | Missing radial R-B channel offset — real camera lenses always produce this |
| Bilateral symmetry | Too-perfect (GAN) or too-broken (face-swap) facial symmetry |
| Color temperature | Illumination mismatch across image quadrants |
| Noise field | Unnaturally smooth or patterned sensor noise |
| JPEG block boundary ratio | Atypical 8×8 DCT boundary vs interior pixel discontinuity |
| Gradient diversity | Narrow gradient magnitude spread (over-uniform sharpness) |
| Color channel statistics | Unnaturally balanced R/G/B channel means and variances |

Each signal has an independent weight. A fake verdict requires multiple signals to fire (threshold: ≥ 25% of maximum weighted score), reducing single-signal false positives.

### Phishing URL Detection
Rule-based + edit-distance analysis with no external lookups.

- **Trusted whitelist** — 50+ known-good domains bypass all checks
- **Known blacklist** — 60+ hardcoded phishing domains
- **Typosquatting** — Levenshtein edit distance (catches `amazom`, `g00gle`, `paypall`)
- **Leet-speak** — detects `p4yp4l`, `4m4z0n`, `micr0soft`
- **Brand-in-subdomain** — flags `paypal.evil.com` separately
- **URL shortener detection** — bit.ly, tinyurl, goo.gl and 14 others
- **Malicious URI schemes** — `javascript:` and `data:` (instant critical)
- **Obfuscation checks** — heavy `%XX` encoding, unusual ports, punycode
- **Expanded lists** — 50+ brands, 40+ high-risk TLDs
- **Proper confidence scoring** — normalized 0–1, was broken in previous version

### Other
- Scan history stored locally in SQLite
- Background clipboard monitoring (optional)
- Camera and gallery image input

---

## Tech Stack

| | |
|---|---|
| Framework | Flutter (Dart) |
| ML inference | TensorFlow Lite (`tflite_flutter`) |
| Image analysis | `image` package (v4) |
| Local storage | SQLite (`sqflite`) |
| Platform | Android |

---

## Getting Started

**Requirements:** Flutter 3.0+, Android SDK

```bash
git clone https://github.com/leonkaushikdeka/securescan-app.git
cd securescan-app
flutter pub get
flutter run
```

The app runs fully offline. No API keys or configuration needed.

---

## Project Structure

```
lib/
└── main.dart          # All app logic (UI + detectors + database)

assets/
├── models/
│   └── deepfake.tflite    # Drop-in TFLite model (optional)
└── data/
    └── phishing_domains.txt
```

To use a real deepfake model: replace `assets/models/deepfake.tflite` with any TFLite binary that accepts `[1, 80, 80, 3]` float input and outputs `[real_score, fake_score]`. If the model fails to load, the heuristic engine activates automatically.
