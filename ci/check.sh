#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"
mkdir -p build/ci-logs
flutter analyze --no-pub 2>&1 | tee build/ci-logs/flutter-analyze.log
# Golden PNGs were rendered on Windows. Layout/interaction assertions still run
# on CI, while OS-dependent font rasterization is not compared to those PNGs.
flutter test --no-pub --dart-define=SPAYR_CHECK_GOLDENS=false 2>&1 | tee build/ci-logs/flutter-test.log
