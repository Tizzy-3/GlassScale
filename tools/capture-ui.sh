#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

OUT="$RUNNER_TEMP/glassscale-ui"
mkdir -p "$OUT"
xcrun swiftc tools/check-screenshot.swift -o "$RUNNER_TEMP/check-screenshot"
xcrun simctl list devices available --json > "$OUT/available-devices.json"
DEVICE_ID=$(python3 - "$OUT/available-devices.json" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    devices = json.load(f)['devices']
options = [d for runtime, group in devices.items() if 'iOS-26' in runtime
           for d in group if d.get('isAvailable', False) and 'iPhone' in d['name']]
options.sort(key=lambda d: (d['name'] != 'iPhone 17 Pro', d['name'] != 'iPhone 17', d['name']))
if not options:
    raise SystemExit('No available iOS 26 iPhone simulator; see available-devices.json')
print(options[0]['udid'])
PY
)

xcodebuild -project GlassScale.xcodeproj -scheme GlassScale \
  -configuration Debug -sdk iphonesimulator \
  -destination "id=$DEVICE_ID" -derivedDataPath "$RUNNER_TEMP/ui-build" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" build > "$OUT/simulator-build.log" 2>&1 || {
    tail -100 "$OUT/simulator-build.log"
    exit 1
  }

APP="$RUNNER_TEMP/ui-build/Build/Products/Debug-iphonesimulator/GlassScale.app"
test -d "$APP"
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")
xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE_ID" -b
xcrun simctl status_bar "$DEVICE_ID" override --time '9:41' --dataNetwork wifi --wifiMode active --wifiBars 3 --batteryState charged --batteryLevel 100
xcrun simctl install "$DEVICE_ID" "$APP"

capture() {
  local page="$1"
  local appearance="$2"
  shift 2
  xcrun simctl terminate "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl ui "$DEVICE_ID" appearance "$appearance"
  if [ "$page" = records ]; then
    xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID" --ui-preview --ui-preview-records -AppleLanguages '(zh-Hans)' -AppleLocale zh_CN
  else
    xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID" --ui-preview "$@" -AppleLanguages '(zh-Hans)' -AppleLocale zh_CN
  fi
  # A cold simulator may still show its blank launch frame after launch returns.
  # Retry that frame instead of silently accepting it as a visual check.
  for attempt in 1 2 3 4 5 6; do
    sleep 8
    xcrun simctl io "$DEVICE_ID" screenshot "$OUT/$page-$appearance.png"
    if "$RUNNER_TEMP/check-screenshot" "$OUT/$page-$appearance.png"; then
      return
    fi
  done
  echo "Screenshot stayed on a blank launch frame: $page-$appearance" >&2
  return 1
}

capture home light --ui-store-smoke
DATA_DIR=$(xcrun simctl get_app_container "$DEVICE_ID" "$BUNDLE_ID" data)
cp "$DATA_DIR/Documents/ui-store-checks.json" "$OUT/ui-store-checks.json"
python3 - "$OUT/ui-store-checks.json" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    report = json.load(f)
print('Simulator store checks:', len(report['checks']), 'checks;', len(report['failures']), 'failures')
assert len(report['checks']) >= 33, 'Incomplete Store smoke report'
assert not report['failures'], report['failures']
PY
capture home dark
capture home-stale light --ui-preview-stale
capture achievements light --ui-preview-achievements
capture achievements dark --ui-preview-achievements
capture achievement-history light --ui-preview-achievements --ui-preview-achievement-history --ui-preview-recent-achievement
capture achievement-empty light --ui-preview-achievements --ui-preview-empty
capture achievement-detail light --ui-preview-achievements --ui-preview-badge-detail
capture goal-celebration light --ui-preview-goal-celebration
xcrun simctl ui "$DEVICE_ID" content_size accessibility-extra-extra-extra-large
capture home-accessibility light
capture achievement-accessibility light --ui-preview-achievements
capture goal-celebration-accessibility light --ui-preview-goal-celebration
xcrun simctl ui "$DEVICE_ID" content_size large
xcrun simctl terminate "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true

# Use a real 375pt simulator to check compact width, without rebuilding the app.
RUNTIME_ID=$(python3 - "$OUT/available-devices.json" "$DEVICE_ID" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    devices = json.load(f)['devices']
print(next(runtime for runtime, group in devices.items() if any(d['udid'] == sys.argv[2] for d in group)))
PY
)
xcrun simctl shutdown "$DEVICE_ID" || true
DEVICE_ID=$(xcrun simctl create GlassScale-Compact com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation "$RUNTIME_ID")
xcrun simctl boot "$DEVICE_ID"
xcrun simctl bootstatus "$DEVICE_ID" -b
xcrun simctl status_bar "$DEVICE_ID" override --time '9:41' --dataNetwork wifi --wifiMode active --wifiBars 3 --batteryState charged --batteryLevel 100
xcrun simctl install "$DEVICE_ID" "$APP"
capture home-small light --ui-preview-pounds
capture home-small-details light --ui-preview-pounds --ui-preview-weight-details
capture achievement-small light --ui-preview-pounds --ui-preview-achievements
xcrun simctl ui "$DEVICE_ID" content_size accessibility-extra-extra-extra-large
capture achievement-small-accessibility light --ui-preview-achievements
xcrun simctl ui "$DEVICE_ID" content_size large
xcrun simctl terminate "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true
printf 'Screenshots captured for %s using simulator %s\n' "$BUNDLE_ID" "$DEVICE_ID"
