#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IOS_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="${IOS_DIR}/screenshots"
RESULT_PATH="${IOS_DIR}/screenshots/board.png"
XCRESULT_PATH="${IOS_DIR}/build/screenshots.xcresult"

# Clean up previous results
rm -rf "$XCRESULT_PATH" "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

DEVICE_NAME="iPhone 17 Pro Max"

# Resolve a concrete simulator UDID so we can pre-boot it and clean up its status bar.
DEVICE_UDID="$(xcrun simctl list devices available --json | python3 -c "
import json, sys
devices = json.load(sys.stdin)['devices']
udids = [d['udid'] for rt in devices for d in devices[rt] if d.get('name') == '$DEVICE_NAME' and d.get('isAvailable')]
print(udids[0] if udids else '')
")"

if [ -z "$DEVICE_UDID" ]; then
    echo "ERROR: シミュレータ '$DEVICE_NAME' が見つかりません"
    exit 1
fi

echo "==> Booting simulator ($DEVICE_NAME / $DEVICE_UDID)..."
# 同じ UDID を再利用することで、初回起動時のシステム通知（Apple Intelligence 等）を
# 消化済みの状態で撮影し、スクリーンショットにバナーが写り込むのを防ぐ。
xcrun simctl boot "$DEVICE_UDID" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE_UDID" 2>/dev/null || true

echo "==> Overriding status bar (9:41, full signal/battery)..."
xcrun simctl status_bar "$DEVICE_UDID" override \
    --time "9:41" \
    --dataNetwork wifi --wifiMode active --wifiBars 3 \
    --cellularMode active --cellularBars 4 \
    --batteryState charged --batteryLevel 100

# 撮影後は必ず status bar のオーバーライドを解除する
cleanup_status_bar() {
    xcrun simctl status_bar "$DEVICE_UDID" clear 2>/dev/null || true
}
trap cleanup_status_bar EXIT

echo "==> Running screenshot tests..."
xcodebuild test \
    -project "$IOS_DIR/Rikako.xcodeproj" \
    -scheme high-school-chemistry-dev \
    -destination "platform=iOS Simulator,id=$DEVICE_UDID" \
    -only-testing:RikakoUITests/ScreenshotTests \
    -resultBundlePath "$XCRESULT_PATH" \
    -configuration Debug \
    CODE_SIGNING_ALLOWED=NO \
    2>&1 | tail -5

echo "==> Extracting screenshots from xcresult..."

python3 - "$XCRESULT_PATH" "$OUTPUT_DIR" <<'PYTHON'
import json, subprocess, sys, os

xcresult = sys.argv[1]
output_dir = sys.argv[2]

def xcresult_get(ref_id=None):
    cmd = ["xcrun", "xcresulttool", "get", "--path", xcresult, "--format", "json", "--legacy"]
    if ref_id:
        cmd += ["--id", ref_id]
    result = subprocess.run(cmd, capture_output=True, text=True)
    return json.loads(result.stdout)

def find_by_type(obj, type_name, results=None):
    if results is None:
        results = []
    if isinstance(obj, dict):
        if obj.get("_type", {}).get("_name") == type_name:
            results.append(obj)
        for v in obj.values():
            find_by_type(v, type_name, results)
    elif isinstance(obj, list):
        for item in obj:
            find_by_type(item, type_name, results)
    return results

# Step 1: Get top-level data and find testsRef
top = xcresult_get()
actions = top.get("actions", {}).get("_values", [])
tests_ref = None
for action in actions:
    ref = action.get("actionResult", {}).get("testsRef", {}).get("id", {}).get("_value")
    if ref:
        tests_ref = ref
        break

if not tests_ref:
    print("ERROR: No testsRef found")
    sys.exit(1)

# Step 2: Get test metadata and find summaryRefs
tests_data = xcresult_get(tests_ref)
test_metadatas = find_by_type(tests_data, "ActionTestMetadata")

# Step 3: For each test, get summary and extract attachments
for meta in test_metadatas:
    summary_ref = meta.get("summaryRef", {}).get("id", {}).get("_value")
    if not summary_ref:
        continue

    summary = xcresult_get(summary_ref)
    attachments = find_by_type(summary, "ActionTestAttachment")

    for att in attachments:
        name = att.get("name", {}).get("_value", "")
        payload_ref = att.get("payloadRef", {}).get("id", {}).get("_value", "")
        if not name or not payload_ref:
            continue

        output_path = os.path.join(output_dir, f"{name}.png")
        subprocess.run([
            "xcrun", "xcresulttool", "export",
            "--type", "file",
            "--path", xcresult,
            "--id", payload_ref,
            "--output-path", output_path,
            "--legacy"
        ], check=True)
        print(f"  Extracted: {name}.png")

PYTHON

# Count extracted screenshots
SCREENSHOT_COUNT=$(ls "$OUTPUT_DIR"/*.png 2>/dev/null | wc -l | tr -d ' ')
echo "==> Extracted $SCREENSHOT_COUNT screenshots"

if [ "$SCREENSHOT_COUNT" -eq 0 ]; then
    echo "ERROR: No screenshots extracted"
    exit 1
fi

# Check if ImageMagick is available
if ! command -v montage &> /dev/null; then
    echo "==> ImageMagick not found. Installing via Homebrew..."
    brew install imagemagick
fi

echo "==> Generating board image..."
montage "$OUTPUT_DIR"/0*.png \
    -geometry +20+20 \
    -tile "${SCREENSHOT_COUNT}x1" \
    -background '#f5f5f5' \
    -shadow \
    -title "Rikako iOS Screenshots" \
    "$RESULT_PATH"

echo "==> Done! Board image: $RESULT_PATH"
open "$RESULT_PATH"
