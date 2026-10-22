#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null 2>&1; then
    if command -v brew >/dev/null 2>&1; then
        brew install xcodegen
    else
        echo "Error: xcodegen is not installed and Homebrew (brew) was not found." >&2
        exit 1
    fi
fi

if [[ ! -f Config/Local.xcconfig ]]; then
    cp Config/Local.xcconfig.example Config/Local.xcconfig
fi

xcodegen generate
