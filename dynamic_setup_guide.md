# Dynamic Flutter Setup Prompt

## Option 1: Automated (Run Python Script)

```bash
python generate_setup_prompt.py
```

This fetches latest versions from official sources and generates an up-to-date prompt.

## Option 2: Manual - Copy & Fill Template

**Before creating a Flutter Android project, fill in and use this template:**

```
I am creating a new Flutter Android project. Please configure:

1. AGP Version: ________ (check: https://developer.android.com/studio/releases/gradle)
2. Gradle Version: ________ (check: https://gradle.org/releases/)
3. NDK Version: ________ (check Flutter plugins for latest requirement)
4. Java Version: ________ (should match AGP requirements)

SETUP STEPS:
1. flutter create --androidx appname
2. Update android/settings.gradle with AGP version above
3. Update android/gradle/wrapper/gradle-wrapper.properties with Gradle version
4. Update android/app/build.gradle:
   - ndkVersion = "above_ndk_version"
   - sourceCompatibility = JavaVersion.VERSION_java_version
   - targetCompatibility = JavaVersion.VERSION_java_version
   - coreLibraryDesugaringEnabled = true
5. Add to dependencies: coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.3'
6. flutter clean && flutter pub get && flutter run
```

## Version Check Links (Bookmark These)

| Check | URL |
|-------|-----|
| AGP Versions | https://developer.android.com/studio/releases/gradle |
| Gradle Releases | https://gradle.org/releases/ |
| NDK Versions | https://developer.android.com/ndk/downloads |
| Java Versions | https://www.oracle.com/java/technologies/downloads/ |

## Quick Version Fetch Commands

```bash
# Check your current versions
flutter doctor -v | grep -A2 "Android"
java -version
ls $ANDROID_HOME/platforms/  # List installed SDKs
ls $ANDROID_HOME/ndk/       # List installed NDKs
```

## Environment Variables to Set

```
JAVA_HOME = C:\Program Files\Eclipse Adoptium\jdk-17.x.x.x-hotspot
ANDROID_HOME = C:\Users\%USERNAME%\AppData\Local\Android\sdk
ANDROID_SDK_ROOT = %ANDROID_HOME%
PATH += %ANDROID_HOME%\platform-tools
PATH += %ANDROID_HOME%\cmdline-tools\latest\bin
PATH += %JAVA_HOME%\bin
PATH += C:\flutter\bin
```

## Before Any Project - Pre-Flight Check

```bash
# 1. Verify environment
java -version          # Should show 17+
flutter --version      # Should show latest
flutter doctor         # Should show all [✓]

# 2. Accept licenses
flutter doctor --android-licenses

# 3. Check available devices
flutter devices        # Should show emulator

# 4. Create project
flutter create --androidx myapp

# 5. Navigate and configure
cd myapp
# Edit the config files as above

# 6. Build
flutter clean
flutter pub get
flutter run -d emulator-5554
```

## If Issues Occur - Diagnostic Commands

```bash
flutter doctor -v          # Full diagnostic
flutter analyze            # Code issues
flutter pub deps           # Dependency tree
./gradlew --version        # Gradle version check
./gradlew build --stacktrace  # Full error trace
```

## Common Issues Quick Fixes

| Error | Fix |
|-------|-----|
| AGP needs newer Gradle | Update gradle-wrapper.properties |
| Java 21 incompatibility | AGP 8.2.1+ or downgrade Java to 17 |
| NDK version mismatch | Set ndkVersion in app/build.gradle |
| Core library desugaring | Enable + add dependency |
| Plugin requires NDK 27 | Update ndkVersion to "27.0.12077973" |
| License not accepted | flutter doctor --android-licenses |

---

**Tip:** Run `python generate_setup_prompt.py` before starting any new project to get the latest recommended versions.
