#!/bin/bash

APP_NAME="AIAudiobook"
ENTRY_POINT="main.py"

echo "Creating virtual environment..."
python3 -m venv .venv
source .venv/bin/activate

echo "Installing dependencies..."
pip install -r requirements.txt pyinstaller

echo "Building macOS app bundle..."
pyinstaller --noconfirm \
  --onefile \
  --windowed \
  --name "$APP_NAME" \
  "$ENTRY_POINT"

echo "Build complete. Executable is in dist/$APP_NAME"
