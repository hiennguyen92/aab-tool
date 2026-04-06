#!/bin/bash

APP_NAME="AABTool"
BUILD_DIR=".build/release"
APP_DIR="dist/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "🔨 Building Swift package..."
swift build -c release

echo "📦 Creating app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

echo "📄 Copy binary..."
cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/"

echo "📄 Copy bundle..."
cp -R "$BUILD_DIR/${APP_NAME}_${APP_NAME}.bundle" "$RESOURCES_DIR/"

echo "🎨 Copy icon..."
cp AppIcon.icns "$RESOURCES_DIR/"

echo "📝 Copy Info.plist..."
cp Info.plist "$CONTENTS_DIR/Info.plist"

echo "✅ Done: $APP_DIR"