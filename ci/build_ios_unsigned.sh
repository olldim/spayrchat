#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"
mkdir -p build/ci-logs build/ios/ipa
log_dir="$project_root/build/ci-logs"
derived_dir="$(mktemp -d "$project_root/build/ios/unsigned.XXXXXX")"
result_bundle="$derived_dir/Build.xcresult"
output="$project_root/build/ios/ipa/Spayr-unsigned.ipa"
# Do not expose an IPA from a previous successful run if this build fails.
if [[ -f "$output" ]]; then
  rm -f "$output"
fi

collect_result() {
  status=$?
  trap - EXIT
  if [[ -d "$result_bundle" ]]; then
    # Diagnostic packaging must not turn a failed Xcode build into a green run.
    if ! ditto -c -k --keepParent "$result_bundle" "$log_dir/xcode-result.zip"; then
      printf '%s\n' 'Could not zip xcresult; the complete Xcode text log is still available.' >&2
    fi
  fi
  exit "$status"
}
trap collect_result EXIT

export XCODE_XCCONFIG_FILE="$project_root/ci/ios-unsigned.xcconfig"
xcodebuild -version 2>&1 | tee "$log_dir/xcode-version.log"

# Flutter prepares its frameworks, generated settings and Swift package graph.
# Use Xcode directly for compilation so the original error is retained instead
# of Flutter's generic "select a Development Team" fallback diagnostic.
flutter build ios --release --no-codesign --config-only --no-pub --verbose \
  2>&1 | tee "$log_dir/ios-configure.log"

xcodebuild \
  -workspace "$project_root/ios/Runner.xcworkspace" \
  -scheme Runner \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$derived_dir" \
  -resultBundlePath "$result_bundle" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY= \
  CODE_SIGN_ENTITLEMENTS= \
  DEVELOPMENT_TEAM= \
  PROVISIONING_PROFILE_SPECIFIER= \
  COMPILER_INDEX_STORE_ENABLE=NO \
  build 2>&1 | tee "$log_dir/ios-xcodebuild.log"

app="$derived_dir/Build/Products/Release-iphoneos/Runner.app"
if [[ ! -f "$app/Runner" || ! -f "$app/Info.plist" ]]; then
  printf '%s\n' "Xcode did not produce a complete Runner.app at $app" >&2
  exit 1
fi

# Build a fresh archive every time; never update an old IPA with stale files.
stage="$(mktemp -d "$project_root/build/ios/ipa-stage.XXXXXX")"
mkdir "$stage/Payload"
ditto "$app" "$stage/Payload/Runner.app"
(
  cd "$stage"
  zip -q -r -y Spayr-unsigned.ipa Payload
)
mv -f "$stage/Spayr-unsigned.ipa" "$output"
printf '%s\n' 'Created build/ios/ipa/Spayr-unsigned.ipa. Sign it with AltStore or Sideloadly before installation.'
