#!/bin/bash
# 把解码好的备选图标拷进 .app 包根目录，并用 PlistBuddy 注册 CFBundleAlternateIcons，
# 供 UIApplication.setAlternateIconName 调用（我的 → 偏好设置 → App 图标）。
# 在 project.pbxproj 中是最后一个构建阶段（"Register Alternate App Icons"，
# alwaysOutOfDate=1，每次构建都运行；输入文件已在 inputPaths 声明以通过构建沙盒）。
set -euo pipefail

SRC_DIR="$DERIVED_FILE_DIR/AltIcons"
DST_DIR="$TARGET_BUILD_DIR/$CONTENTS_FOLDER_PATH"
BUDDY=/usr/libexec/PlistBuddy
PLIST="$TARGET_BUILD_DIR/$INFOPLIST_PATH"

for name in AppIcon-Cat AppIcon-Dumbbell; do
  cp "$SRC_DIR/$name.jpg" "$DST_DIR/$name.jpg"
done

$BUDDY -c "Add :CFBundleAlternateIcons dict" "$PLIST" 2>/dev/null || true
for spec in "Cat:AppIcon-Cat" "Dumbbell:AppIcon-Dumbbell"; do
  name="${spec%%:*}"
  file="${spec##*:}"
  $BUDDY -c "Delete :CFBundleAlternateIcons:$name dict" "$PLIST" 2>/dev/null || true
  $BUDDY -c "Add :CFBundleAlternateIcons:$name dict" "$PLIST"
  $BUDDY -c "Add :CFBundleAlternateIcons:$name:CFBundleIconFiles array" "$PLIST"
  $BUDDY -c "Add :CFBundleAlternateIcons:$name:CFBundleIconFiles:0 string $file" "$PLIST"
  $BUDDY -c "Add :CFBundleAlternateIcons:$name:UIPrerenderedIcon bool false" "$PLIST" 2>/dev/null || true
done
