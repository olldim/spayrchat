#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

# Regenerate local paths and native plugin manifests on the build machine.
# A Windows-generated Generated.xcconfig must never be reused on macOS.
flutter clean
mkdir -p build/ci-logs
flutter --version 2>&1 | tee build/ci-logs/flutter-version.log
flutter pub get --enforce-lockfile 2>&1 | tee build/ci-logs/pub-get.log
