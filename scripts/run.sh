#!/bin/bash

# Run the CRT filter application

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RACKET_DIR="$PROJECT_DIR/racket"

# Check if native library exists
if [ ! -f "$PROJECT_DIR/libcrt-native.dylib" ]; then
    echo "Native library not found. Building..."
    "$SCRIPT_DIR/build-native.sh"
fi

# Ensure generated directory exists
mkdir -p "$PROJECT_DIR/generated"

# Change to project directory for correct relative paths
cd "$PROJECT_DIR"

echo "Starting CRT Filter..."
echo ""

# Run the Racket application
racket "$RACKET_DIR/main.rkt" "$@"
