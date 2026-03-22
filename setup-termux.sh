#!/data/data/com.termux/files/usr/bin/bash
#
# setup-termux.sh — One-time setup for building the Android Hello World APK on Termux.
#
# Run after cloning this repo:
#   chmod +x setup-termux.sh
#   ./setup-termux.sh
#
# Then build:
#   cd android
#   ./gradlew assembleDebug --no-daemon
#
# The APK will be at: android/app/build/outputs/apk/debug/app-debug.apk
#
# NOTE: First gradlew run downloads Gradle 8.4 (~120 MB, one-time, cached in ~/.gradle/).

set -e

ANDROID_SDK_DIR="$HOME/android-sdk"
CMDLINE_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
CMDLINE_TOOLS_ZIP="$HOME/cmdline-tools.zip"

echo "========================================"
echo "  Android Hello World — Termux Setup"
echo "========================================"
echo ""

# ── Step 1: Update packages ──────────────────────────────────────────────────
echo ">>> [1/6] Updating Termux packages..."
pkg update -y && pkg upgrade -y

# ── Step 2: Install required tools ───────────────────────────────────────────
echo ""
echo ">>> [2/6] Installing required packages..."
# openjdk-17 : Java 17 compiler + runtime (required by AGP 8.1)
# aapt2      : ARM64-native resource packager (replaces Gradle's x86-64 download)
# wget       : download cmdline-tools zip
# unzip, zip : extract SDK
pkg install -y openjdk-17 aapt2 wget unzip zip

# ── Step 3: Download Android cmdline-tools ───────────────────────────────────
echo ""
echo ">>> [3/6] Setting up Android SDK cmdline-tools..."
if [ -d "$ANDROID_SDK_DIR/cmdline-tools/latest/bin" ]; then
    echo "    cmdline-tools already present, skipping download."
else
    echo "    Downloading cmdline-tools (~120 MB)..."
    wget -q --show-progress "$CMDLINE_TOOLS_URL" -O "$CMDLINE_TOOLS_ZIP"

    mkdir -p "$ANDROID_SDK_DIR"
    TMPDIR_TOOLS="$HOME/cmdline-tools-extract-$$"
    unzip -q "$CMDLINE_TOOLS_ZIP" -d "$TMPDIR_TOOLS"

    # The zip always extracts to a folder named 'cmdline-tools'.
    # sdkmanager expects it at <sdk>/cmdline-tools/latest/
    mkdir -p "$ANDROID_SDK_DIR/cmdline-tools"
    mv "$TMPDIR_TOOLS/cmdline-tools" "$ANDROID_SDK_DIR/cmdline-tools/latest"
    rm -rf "$TMPDIR_TOOLS" "$CMDLINE_TOOLS_ZIP"
    echo "    cmdline-tools installed."
fi

# ── Step 4: Configure environment ────────────────────────────────────────────
echo ""
echo ">>> [4/6] Configuring environment variables..."
export ANDROID_HOME="$ANDROID_SDK_DIR"
export JAVA_HOME="/data/data/com.termux/files/usr/lib/jvm/java-17-openjdk"
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools"

BASHRC="$HOME/.bashrc"
if ! grep -q "ANDROID_HOME" "$BASHRC" 2>/dev/null; then
    cat >> "$BASHRC" << 'ENVBLOCK'

# Android SDK (added by setup-termux.sh)
export ANDROID_HOME="$HOME/android-sdk"
export JAVA_HOME="/data/data/com.termux/files/usr/lib/jvm/java-17-openjdk"
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools"
ENVBLOCK
    echo "    Environment variables written to ~/.bashrc"
else
    echo "    Environment variables already in ~/.bashrc, skipping."
fi

# ── Step 5: Install SDK platform + build-tools ───────────────────────────────
echo ""
echo ">>> [5/6] Installing Android SDK platform 33 and build-tools 33.0.2..."
echo "    (Accepting all licenses...)"
yes | sdkmanager --sdk_root="$ANDROID_SDK_DIR" --licenses > /dev/null 2>&1 || true

sdkmanager --sdk_root="$ANDROID_SDK_DIR" \
    "platform-tools" \
    "platforms;android-33" \
    "build-tools;33.0.2"

# ── Step 6: Fix ARM64 aapt2 (CRITICAL for Termux) ───────────────────────────
echo ""
echo ">>> [6/6] Configuring ARM64 aapt2 override..."
# Gradle downloads an x86-64 aapt2 from Maven that cannot run on ARM64.
# We redirect it to Termux's native ARM64 binary installed in step 2.
mkdir -p "$HOME/.gradle"
GRADLE_PROPS="$HOME/.gradle/gradle.properties"
AAPT2_PATH="/data/data/com.termux/files/usr/bin/aapt2"

if [ ! -f "$AAPT2_PATH" ]; then
    echo "    WARNING: aapt2 not found at $AAPT2_PATH"
    echo "    Run 'pkg install aapt2' and re-run this script."
else
    if ! grep -q "aapt2FromMavenOverride" "$GRADLE_PROPS" 2>/dev/null; then
        echo "android.aapt2FromMavenOverride=$AAPT2_PATH" >> "$GRADLE_PROPS"
        echo "    aapt2 override added to $GRADLE_PROPS"
    else
        echo "    aapt2 override already present in $GRADLE_PROPS"
    fi
fi

# ── Write local.properties ───────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOCAL_PROPS="$SCRIPT_DIR/android/local.properties"
echo "sdk.dir=$ANDROID_SDK_DIR" > "$LOCAL_PROPS"
echo "    local.properties written: $LOCAL_PROPS"

# ── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo "========================================"
echo "  Setup complete!"
echo "========================================"
echo ""
echo "Build the APK:"
echo ""
echo "  cd $SCRIPT_DIR/android"
echo "  ./gradlew assembleDebug --no-daemon"
echo ""
echo "Output:"
echo "  android/app/build/outputs/apk/debug/app-debug.apk"
echo ""
echo "Install on this device:"
echo "  cp android/app/build/outputs/apk/debug/app-debug.apk /sdcard/Download/"
echo "  # Then open your file manager, tap the APK, and install."
echo "  # (Enable 'Install from unknown sources' for your file manager first.)"
echo ""
echo "NOTE: First 'gradlew' run downloads Gradle 8.4 (~120 MB, cached after that)."
