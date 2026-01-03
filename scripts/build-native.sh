#!/bin/bash

# Build the native CRT library

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
NATIVE_DIR="$PROJECT_DIR/native"

echo "Building CRT native library..."
echo "Project directory: $PROJECT_DIR"

cd "$NATIVE_DIR"

# Clean and build
make clean
make

# Install to project root
make install

echo ""
echo "Build complete!"
echo "Library installed to: $PROJECT_DIR/libcrt-native.dylib"
