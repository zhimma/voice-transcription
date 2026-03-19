#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT_DIR/backend/server.py"
REQ_SRC="$ROOT_DIR/backend/requirements.txt"
DST_DIR="$ROOT_DIR/frontend/assets/python"
DST="$DST_DIR/server.py"
REQ_DST="$DST_DIR/requirements.txt"

mkdir -p "$DST_DIR"
cp "$SRC" "$DST"
cp "$REQ_SRC" "$REQ_DST"

echo "Synced Python server to assets: $DST"
echo "Synced Python requirements to assets: $REQ_DST"
