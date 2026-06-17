#!/bin/bash
# Health+ iOS App — One-time project setup
# Run this script once to generate the Xcode project from project.yml

set -e

echo "🏥 Health+ Project Setup"
echo "========================"

# Check for Homebrew
if ! command -v brew &> /dev/null; then
    echo "❌ Homebrew not found. Install it from https://brew.sh"
    exit 1
fi

# Install XcodeGen if needed
if ! command -v xcodegen &> /dev/null; then
    echo "📦 Installing XcodeGen..."
    brew install xcodegen
fi

# Generate the Xcode project
echo "🔨 Generating Xcode project..."
xcodegen generate

echo ""
echo "✅ Done! Open HealthAggregator.xcodeproj in Xcode."
echo ""
echo "Next steps:"
echo "  1. Set your Development Team in Xcode → Signing & Capabilities"
echo "  2. Add your WHOOP Client ID/Secret to Info.plist"
echo "  3. Change bundle ID from 'com.healthaggregator.app' to something unique"
echo "  4. Build and run on your iPhone (iOS 17+ required)"
echo "  5. For TestFlight: Product → Archive → Upload to App Store Connect"
