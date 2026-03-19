#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FRONTEND_DIR="$ROOT_DIR/frontend"
REPORT_DIR="$ROOT_DIR/build_outputs/release_gate"
mkdir -p "$REPORT_DIR"

echo "[1/5] flutter analyze"
(
  cd "$FRONTEND_DIR"
  flutter analyze --no-fatal-infos --no-fatal-warnings | tee "$REPORT_DIR/analyze.log"
)

echo "[2/5] flutter test"
(
  cd "$FRONTEND_DIR"
  flutter test -r compact | tee "$REPORT_DIR/test.log"
)

echo "[3/5] build release"
(
  cd "$FRONTEND_DIR"
  flutter build macos --release | tee "$REPORT_DIR/build_macos.log"
)

echo "[4/5] smoke check output"
APP_PATH="$FRONTEND_DIR/build/macos/Build/Products/Release/voice_transcription.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "missing app artifact: $APP_PATH" | tee "$REPORT_DIR/smoke.log"
  exit 1
fi
echo "artifact ok: $APP_PATH" | tee "$REPORT_DIR/smoke.log"

echo "[4.5/5] backend syntax check"
(
  cd "$ROOT_DIR"
  python3 -m py_compile backend/server.py
  echo "backend/server.py syntax ok" | tee -a "$REPORT_DIR/smoke.log"
)

echo "[5/5] checksums"
shasum -a 256 "$APP_PATH/Contents/MacOS/voice_transcription" \
  | tee "$REPORT_DIR/checksums.txt"

echo "release gate passed"
echo "report dir: $REPORT_DIR"
