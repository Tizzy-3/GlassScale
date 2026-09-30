#!/bin/bash
# 构建期解码备选 App 图标：把 tools/alt-icons 下的 base64 文本还原成 JPEG，
# 再用 macOS 自带 sips 转成 PNG（SpringBoard 只认 PNG 做桌面图标，给 JPG 会
# 导致 setAlternateIconName 报"资源暂时不可用"），输出到
# $DERIVED_FILE_DIR/AltIcons（派生目录，不污染源码树）。
# "Register Alternate App Icons" 阶段会把 PNG 拷进 .app 包并注册 CFBundleAlternateIcons。
# 只用 macOS 自带 base64 / sips，无 python / pip 依赖。
# 注意：本文件及两个 .jpg.b64 已在 project.pbxproj 的 inputPaths 声明，
# 否则构建沙盒（ENABLE_USER_SCRIPT_SANDBOXING）会拒绝读取。
set -euo pipefail

SRC_DIR="$SRCROOT/tools/alt-icons"
OUT_DIR="$DERIVED_FILE_DIR/AltIcons"
mkdir -p "$OUT_DIR"

for name in AppIcon-Cat AppIcon-Dumbbell; do
  base64 -D < "$SRC_DIR/$name.jpg.b64" > "$OUT_DIR/$name.jpg"
  test -s "$OUT_DIR/$name.jpg"
  # JPEG -> PNG：sips 是 macOS 系统自带，无需额外依赖
  sips -s format png "$OUT_DIR/$name.jpg" --out "$OUT_DIR/$name.png" >/dev/null
  test -s "$OUT_DIR/$name.png"
done
