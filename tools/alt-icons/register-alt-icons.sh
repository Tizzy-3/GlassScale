#!/bin/bash
# 把解码好的备选图标拷进 .app 包根目录，并用 PlistBuddy 注册 CFBundleAlternateIcons，
# 供 UIApplication.setAlternateIconName 调用（我的 → 偏好设置 → App 图标）。
# 在 project.pbxproj 中是最后一个构建阶段（"Register Alternate App Icons"，
# alwaysOutOfDate=1，每次构建都运行）。inputPaths 里声明了
# $(TARGET_BUILD_DIR)/$(INFOPLIST_PATH)，构建系统会把它排在 ProcessInfoPlistFile
# 之后；target 级 ENABLE_USER_SCRIPT_SANDBOXING=NO，保证 PlistBuddy 的原地写入
# 真正落盘（沙盒开启时写入会被丢弃）。
#
# 注意：CFBundleAlternateIcons 必须是 CFBundleIcons 的子键（iOS 只认这个嵌套位置），
# 放在 plist 顶层会导致 supportsAlternateIcons 恒为 NO。
set -euo pipefail

SRC_DIR="$DERIVED_FILE_DIR/AltIcons"
DST_DIR="$TARGET_BUILD_DIR/$CONTENTS_FOLDER_PATH"
BUDDY=/usr/libexec/PlistBuddy
PLIST="$TARGET_BUILD_DIR/$INFOPLIST_PATH"

if [ ! -f "$PLIST" ]; then
  echo "error: built Info.plist not found at $PLIST (Register phase ran before ProcessInfoPlistFile?)" >&2
  exit 1
fi

for name in AppIcon-Cat AppIcon-Dumbbell; do
  # SpringBoard 只认 PNG 做图标文件（CFBundleIconFiles 填基名，系统拼 .png 查找）
  cp "$SRC_DIR/$name.png" "$DST_DIR/$name.png"
done

# 清掉之前版本误写在顶层的键，避免混淆
$BUDDY -c "Delete :CFBundleAlternateIcons dict" "$PLIST" 2>/dev/null || true
# iOS 认的位置：CFBundleIcons > CFBundleAlternateIcons
$BUDDY -c "Add :CFBundleIcons dict" "$PLIST" 2>/dev/null || true
$BUDDY -c "Add :CFBundleIcons:CFBundleAlternateIcons dict" "$PLIST" 2>/dev/null || true
for spec in "Cat:AppIcon-Cat" "Dumbbell:AppIcon-Dumbbell"; do
  name="${spec%%:*}"
  file="${spec##*:}"
  $BUDDY -c "Delete :CFBundleIcons:CFBundleAlternateIcons:$name dict" "$PLIST" 2>/dev/null || true
  $BUDDY -c "Add :CFBundleIcons:CFBundleAlternateIcons:$name dict" "$PLIST"
  $BUDDY -c "Add :CFBundleIcons:CFBundleAlternateIcons:$name:CFBundleIconFiles array" "$PLIST"
  $BUDDY -c "Add :CFBundleIcons:CFBundleAlternateIcons:$name:CFBundleIconFiles:0 string $file" "$PLIST"
  $BUDDY -c "Add :CFBundleIcons:CFBundleAlternateIcons:$name:UIPrerenderedIcon bool false" "$PLIST" 2>/dev/null || true
done

# 验证：iOS 认的位置必须能读到（之前版本验证了错误的位置，教训）
for name in Cat Dumbbell; do
  if ! $BUDDY -c "Print :CFBundleIcons:CFBundleAlternateIcons:$name:CFBundleIconFiles:0" "$PLIST" >/dev/null 2>&1; then
    echo "error: CFBundleIcons:CFBundleAlternateIcons:$name was not persisted to $PLIST" >&2
    exit 1
  fi
done
echo "alternate icons registered under CFBundleIcons: Cat, Dumbbell"
