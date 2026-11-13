#!/usr/bin/env bash
# Build the Rust core for Android and then the Flutter APK/AAB.
#   scripts/build-android.sh            -> release APK (debug-signed unless android/key.properties exists)
#   scripts/build-android.sh debug      -> debug APK
#   scripts/build-android.sh appbundle  -> release AAB for Play
set -euo pipefail
cd "$(dirname "$0")/.."
MODE="${1:-release}"
: "${ANDROID_NDK_HOME:=${ANDROID_HOME:-/usr/lib/android-sdk}/ndk/28.2.13676358}"
export ANDROID_NDK_HOME

(cd core && cargo ndk -t arm64-v8a -t armeabi-v7a -t x86_64 -P 28 \
    -o ../app/android/app/src/main/jniLibs build --release --lib)

cd app
case "$MODE" in
  debug)     flutter build apk --debug ;;
  appbundle) flutter build appbundle --release ;;
  *)         flutter build apk --release --split-per-abi ;;
esac
