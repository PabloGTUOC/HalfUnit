#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

swift test --package-path Packages/HalfUnitCore

SIM_IPHONE="${SIM_IPHONE:-iPhone 17}"

xcodebuild -project HalfUnit.xcodeproj -scheme HalfUnit \
    -destination "platform=iOS Simulator,name=$SIM_IPHONE" \
    -derivedDataPath .build/DerivedData test

if xcodebuild -project HalfUnit.xcodeproj -list | grep -q "HalfUnitWatch"; then
    SIM_WATCH="${SIM_WATCH:-Apple Watch Series 11 (46mm)}"
    xcodebuild -project HalfUnit.xcodeproj -scheme HalfUnitWatch \
        -destination "platform=watchOS Simulator,name=$SIM_WATCH" \
        -derivedDataPath .build/DerivedData build
else
    echo "Skipping watchOS build: HalfUnitWatch scheme does not exist yet."
fi
