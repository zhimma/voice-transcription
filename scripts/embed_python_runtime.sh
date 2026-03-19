#!/usr/bin/env bash
set -euo pipefail

PLATFORM="${1:-}"
EMBED_PYTHON_DIR="${EMBED_PYTHON_DIR:-}"

if [[ -z "$PLATFORM" ]]; then
  echo "Usage: EMBED_PYTHON_DIR=/path/to/python ./scripts/embed_python_runtime.sh <macos|windows|linux>"
  exit 1
fi

case "$PLATFORM" in
  macos)
    EMBED_PYTHON_DIR="${EMBED_PYTHON_DIR_MACOS:-$EMBED_PYTHON_DIR}"
    ;;
  windows)
    EMBED_PYTHON_DIR="${EMBED_PYTHON_DIR_WINDOWS:-$EMBED_PYTHON_DIR}"
    ;;
  linux)
    EMBED_PYTHON_DIR="${EMBED_PYTHON_DIR_LINUX:-$EMBED_PYTHON_DIR}"
    ;;
esac

if [[ -z "$EMBED_PYTHON_DIR" ]]; then
  ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  DEFAULT_DIR="$ROOT_DIR/third_party/python/$PLATFORM/current"
  if [[ -d "$DEFAULT_DIR" ]]; then
    EMBED_PYTHON_DIR="$DEFAULT_DIR"
  else
    echo "Python runtime dir not set for $PLATFORM."
    echo "Set EMBED_PYTHON_DIR or EMBED_PYTHON_DIR_${PLATFORM^^}."
    exit 1
  fi
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

case "$PLATFORM" in
  macos)
    DEST="$ROOT_DIR/frontend/build/macos/Build/Products/Release/voice_transcription.app/Contents/Resources/python"
    ;;
  windows)
    DEST="$ROOT_DIR/frontend/build/windows/x64/Release/bundle/python"
    ;;
  linux)
    DEST="$ROOT_DIR/frontend/build/linux/x64/release/bundle/python"
    ;;
  *)
    echo "Unknown platform: $PLATFORM"
    exit 1
    ;;
esac

mkdir -p "$DEST"

# If a runtime_path.txt exists, use it to locate runtime root
if [[ -f "$EMBED_PYTHON_DIR/runtime_path.txt" ]]; then
  EMBED_PYTHON_DIR="$(cat "$EMBED_PYTHON_DIR/runtime_path.txt")"
fi

# Copy runtime
rsync -a --delete "$EMBED_PYTHON_DIR/" "$DEST/"

echo "Embedded Python runtime to: $DEST"
