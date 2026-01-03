#!/bin/bash

# Generate Metal shader from Racket DSL

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RACKET_DIR="$PROJECT_DIR/racket"

mkdir -p "$PROJECT_DIR/generated"
cd "$PROJECT_DIR"

echo "Generating Metal shader..."
racket "$RACKET_DIR/main.rkt" --generate-only

echo ""
echo "Shader generated at: $PROJECT_DIR/generated/crt-shader.metal"
