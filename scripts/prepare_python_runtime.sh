#!/usr/bin/env bash
set -euo pipefail

PLATFORM="${1:-}"
ARCH="${2:-}"
PYTHON_VERSION="${PYTHON_VERSION:-3.11}"
BUILD_VERSION="${PYTHON_BUILD_VERSION:-latest}"
BUILD_CONFIG="${PYTHON_BUILD_CONFIG:-pgo+lto}"
CONTENT_TYPE="${PYTHON_CONTENT_TYPE:-install_only_stripped}"
WINDOWS_VARIANT="${PYTHON_WINDOWS_VARIANT:-shared}"

if [[ -z "$PLATFORM" || -z "$ARCH" ]]; then
  echo "Usage: ./scripts/prepare_python_runtime.sh <macos|windows|linux> <arch>"
  echo "Example: ./scripts/prepare_python_runtime.sh macos aarch64-apple-darwin"
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT_DIR/third_party/python/$PLATFORM/$ARCH"
CURRENT_LINK="$ROOT_DIR/third_party/python/$PLATFORM/current"

mkdir -p "$OUT_DIR"

# Install getpybs in a local venv to avoid PEP 668 issues
VENV_DIR="$ROOT_DIR/.venv-getpybs"
if [[ ! -f "$VENV_DIR/bin/python" ]]; then
  python3 -m venv "$VENV_DIR"
fi

VENV_PY="$VENV_DIR/bin/python"

if ! $VENV_PY -m getpybs --help >/dev/null 2>&1; then
  $VENV_PY -m pip install -q --upgrade pip
  $VENV_PY -m pip install -q getpybs
fi

# Download python-build-standalone runtime
GETPYBS_ARGS=(
  --python-version "$PYTHON_VERSION"
  --build-version "$BUILD_VERSION"
  --architecture "$ARCH"
  --build-config "$BUILD_CONFIG"
  --content-type "$CONTENT_TYPE"
  --dest "$OUT_DIR"
)

if [[ "$PLATFORM" == "windows" ]]; then
  GETPYBS_ARGS+=(--windows-variant "$WINDOWS_VARIANT")
fi

$VENV_PY -m getpybs "${GETPYBS_ARGS[@]}"

# If an archive was downloaded, extract it
ARCHIVE=$(ls "$OUT_DIR"/*.tar.gz "$OUT_DIR"/*.tar.zst "$OUT_DIR"/*.zip 2>/dev/null | head -n 1 || true)
if [[ -n "$ARCHIVE" ]]; then
  case "$ARCHIVE" in
    *.tar.gz)
      tar -xzf "$ARCHIVE" -C "$OUT_DIR"
      ;;
    *.tar.zst)
      if command -v unzstd >/dev/null 2>&1; then
        tar --use-compress-program=unzstd -xf "$ARCHIVE" -C "$OUT_DIR"
      else
        echo "unzstd not found. Please install zstd to extract $ARCHIVE."
        exit 1
      fi
      ;;
    *.zip)
      unzip -q "$ARCHIVE" -d "$OUT_DIR"
      ;;
  esac
fi

# Locate python executable
PYBIN=""
if [[ "$PLATFORM" == "windows" ]]; then
  PYBIN=$(find "$OUT_DIR" \( -type f -o -type l \) -name "python.exe" | head -n 1 || true)
else
  PYBIN=$(find "$OUT_DIR" \( -type f -o -type l \) -name "python3" | head -n 1 || true)
fi

if [[ -z "$PYBIN" ]]; then
  echo "Failed to locate python executable in $OUT_DIR"
  exit 1
fi

# Determine runtime root dir
if [[ "$PLATFORM" == "windows" ]]; then
  RUNTIME_DIR="$(dirname "$PYBIN")"
else
  RUNTIME_DIR="$(dirname "$(dirname "$PYBIN")")"
fi

echo "$RUNTIME_DIR" > "$OUT_DIR/runtime_path.txt"
ln -sfn "$OUT_DIR" "$CURRENT_LINK"

# Ensure pip and install dependencies into runtime
"$PYBIN" -m ensurepip || true
"$PYBIN" -m pip install --upgrade pip
"$PYBIN" -m pip install -r "$ROOT_DIR/backend/requirements.txt"

echo "Prepared Python runtime at: $RUNTIME_DIR"
echo "Current runtime link: $CURRENT_LINK"
