#!/usr/bin/env python3
"""
Flutter Android Setup - Dynamic Version Checker
Run this script before creating a new Flutter project to get latest compatible versions.
"""

import requests
import json
import re


def get_latest_gradle_version():
    """Fetch latest Gradle version from official API"""
    try:
        response = requests.get(
            "https://services.gradle.org/distributions/", timeout=10
        )
        # Find latest version from download links
        versions = re.findall(r"gradle-(\d+\.\d+)-all\.zip", response.text)
        if versions:
            return sorted(versions, key=lambda x: [int(n) for n in x.split(".")])[-1]
    except:
        pass
    return "8.9"  # fallback


def get_latest_agp_version():
    """Fetch latest Android Gradle Plugin version"""
    try:
        response = requests.get(
            "https://dl.google.com/android/maven2/com/android/tools/build/gradle/maven-metadata.xml",
            timeout=10,
        )
        versions = re.findall(r"<version>(\d+\.\d+\.\d+)</version>", response.text)
        if versions:
            return versions[-1]  # Latest stable
    except:
        pass
    return "8.7.0"  # fallback


def get_recommended_ndk_version():
    """NDK versions change less frequently - return current recommended"""
    return "27.0.12077973"


def get_java_version():
    """Return recommended Java version for current AGP"""
    return "17"


def generate_prompt():
    gradle_version = get_latest_gradle_version()
    agp_version = get_latest_agp_version()
    ndk_version = get_recommended_ndk_version()
    java_version = get_java_version()

    prompt = f"""# Flutter Android Project Setup Prompt

**Copy and paste this prompt before starting any Flutter Android project:**

---

I am creating a new Flutter project targeting Android. Please set up with these **CURRENTLY RECOMMENDED** versions:

## Environment Requirements (Verify First)
```
java -version  # Should be 17 or higher
flutter doctor  # Should show no errors
flutter doctor --android-licenses  # Accept all licenses
flutter devices  # Should show your emulator
```

## Project Configuration

### 1. android/settings.gradle
```
plugins {{
    id "com.android.application" version "{agp_version}" apply false
    id "org.jetbrains.kotlin.android" version "1.8.22" apply false
    id "dev.flutter.flutter-gradle-plugin" version "2.0.0" apply false
}}
```

### 2. android/gradle/wrapper/gradle-wrapper.properties
```
distributionUrl=https\\://services.gradle.org/distributions/gradle-{gradle_version}-all.zip
```

### 3. android/app/build.gradle
```
android {{
    namespace = "com.example.appname"
    compileSdk = 36
    ndkVersion = "{ndk_version}"

    compileOptions {{
        sourceCompatibility = JavaVersion.VERSION_{java_version}
        targetCompatibility = JavaVersion.VERSION_{java_version}
        coreLibraryDesugaringEnabled true
    }}

    kotlinOptions {{
        jvmTarget = JavaVersion.VERSION_{java_version}
    }}

    defaultConfig {{
        minSdk = 24
        targetSdk = 36
    }}
}}

dependencies {{
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.3'
}}
```

### 4. android/build.gradle
```
allprojects {{
    repositories {{
        google()
        mavenCentral()
    }}
}}
```

## Command to Create Project
```
flutter create --androidx appname
```

## Run on Emulator
```
flutter run -d emulator-5554
```

---

## Why These Versions Matter
| Component | Version | Why |
|-----------|---------|-----|
| AGP | {agp_version} | Required for Java {java_version}+ compatibility |
| Gradle | {gradle_version} | Required by AGP {agp_version} |
| NDK | {ndk_version} | Required by current Flutter plugins |
| Java | {java_version} | Required by AGP {agp_version} |
| Desugaring | 2.1.3 | Required by flutter_local_notifications & other plugins |

---

*Generated on: Dynamic - versions fetched from official sources*
"""

    return prompt


def main():
    print("Fetching latest versions...")
    prompt = generate_prompt()

    # Save to file
    with open("project_setup_prompt.txt", "w") as f:
        f.write(prompt)

    print("\nPrompt saved to: project_setup_prompt.txt")
    print("\n" + "=" * 60)
    print(prompt)
    print("=" * 60)


if __name__ == "__main__":
    main()
