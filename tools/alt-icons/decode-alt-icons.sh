#!/bin/bash
# 构建期解码备选 App 图标：把 tools/alt-icons 下的 base64 文本还原成 JPEG，
# 放进 GlassScale/Resources/AltIcons（该目录被 Xcode 文件同步组自动打包进 App）。
# 只用 macOS 自带的 base64，无 python / pip 依赖，避免 runner 上缺 pip 导致构建失败。
#
# 在 Xcode 构建的最早阶段运行（见 project.pbxproj 的 "Decode Alternate App Icons"）。
set -euo pipefail

SRC_DIR="$SRCROOT/tools/alt-icons"
DST_DIR="$SRCROOT/GlassScale/Resources/AltIcons"
mkdir -p "$DST_DIR"

for name in AppIcon-Cat AppIcon-Dumbbell; do
  base64 -D < "$SRC_DIR/$name.jpg.b64" > "$DST_DIR/$name.jpg"
  test -s "$DST_DIR/$name.jpg"
done
