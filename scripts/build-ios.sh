#!/usr/bin/env bash
# Build the Rust core as static libraries for iOS (device + Apple-silicon simulator), then the
# Flutter iOS app. Runs on macOS with Xcode. The Runner target links the .a files with
# -force_load (see Runner.xcodeproj) so Dart can find nv_call via DynamicLibrary.process().
#   scripts/build-ios.sh            -> release build for a device (needs signing)
#   scripts/build-ios.sh sim        -> debug build for the simulator
#   scripts/build-ios.sh ipa        -> App Store archive (.ipa)
#   scripts/build-ios.sh core       -> Rust libraries only
set -euo pipefail
cd "$(dirname "$0")/.."
MODE="${1:-release}"
export IPHONEOS_DEPLOYMENT_TARGET=15.0
CARGO="${CARGO:-$(command -v cargo || echo "$HOME/.cargo/bin/cargo")}"
FLUTTER="${FLUTTER:-$(command -v flutter || echo "$HOME/fvm/default/bin/flutter")}"

# Only the staticlib crate type: with several crate types Cargo embeds LLVM bitcode in the
# objects, which Xcode's older LLVM cannot read ("Not an int attribute"), and the symbols vanish.
for t in aarch64-apple-ios aarch64-apple-ios-sim; do
  (cd core && "$CARGO" rustc --release --lib --target "$t" --crate-type staticlib)
done
[ "$MODE" = core ] && exit 0

cd app
case "$MODE" in
  sim) "$FLUTTER" build ios --simulator --debug ;;
  ipa) "$FLUTTER" build ipa --release ;;
  *)   "$FLUTTER" build ios --release ;;
esac

# Dart looks up nv_call / nv_free by name; a release link that dead-strips them builds fine
# but fails on the first call. Check the binary that was actually produced.
case "$MODE" in
  sim) BIN=build/ios/iphonesimulator/Runner.app ;;
  ipa) BIN=build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app ;;
  *)   BIN=build/ios/iphoneos/Runner.app ;;
esac
BIN="$BIN/Runner"; [ -f "${BIN%/Runner}/Runner.debug.dylib" ] && BIN="${BIN%/Runner}/Runner.debug.dylib"
for sym in _nv_call _nv_free; do
  nm -gU "$BIN" | grep -q " T $sym\$" || { echo "error: $sym missing from $BIN" >&2; exit 1; }
done
echo "ffi symbols present in $BIN"
