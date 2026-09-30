#!/bin/sh
# 解码正式 App 图标：base64 分片 → JPEG → sips 转 PNG → 覆盖 workflow 生成的占位图。
# 必须在 asset catalog 编译前运行（buildPhases 里排第一，alwaysOutOfDate）。
set -e
APPICONSET="$SRCROOT/GlassScale/Resources/Assets.xcassets/AppIcon.appiconset"
TOOLS="$SRCROOT/tools/app-icon"

decode_one() {
    # $1 = AppIcon / AppIcon-Dark
    tmp_jpg="$TMPDIR/appicon-$1.jpg"
    cat "$TOOLS/$1.jpg.b64.part_"* | base64 -D > "$tmp_jpg"
    sips -s format png "$tmp_jpg" --out "$APPICONSET/$1.png" > /dev/null
    rm -f "$tmp_jpg"
}

decode_one "AppIcon"
decode_one "AppIcon-Dark"

for f in "$APPICONSET/AppIcon.png" "$APPICONSET/AppIcon-Dark.png"; do
    if [ ! -s "$f" ]; then
        echo "error: 图标解码失败 $f" >&2
        exit 1
    fi
done
echo "App icons decoded OK"
