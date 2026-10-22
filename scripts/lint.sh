#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

dirs=()
for dir in Packages Apps Extensions UITests; do
    if [[ -d "$dir" ]]; then
        dirs+=("$dir")
    fi
done

if [[ ${#dirs[@]} -gt 0 ]]; then
    swift format lint --recursive --strict "${dirs[@]}"
fi
