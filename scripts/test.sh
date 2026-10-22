#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

swift test --package-path Packages/HalfUnitCore

SIM_IPHONE="${SIM_IPHONE:-iPhone 17}"

xcodebuild -project HalfUnit.xcodeproj -scheme HalfUnit \
    -destination "platform=iOS Simulator,name=$SIM_IPHONE" \
    -derivedDataPath .build/DerivedData test

xcodebuild -project HalfUnit.xcodeproj -scheme HalfUnitWatch \
    -destination "generic/platform=watchOS Simulator" \
    -derivedDataPath .build/DerivedData build
