#!/bin/bash
# 把 tools/alt-icons 下的 base64(webp) 还原为 1024x1024 PNG。
#
# 在 Xcode 构建的最早阶段运行（见 project.pbxproj 的 "Decode Alternate App Icons"）。
# 输出目录 GlassScale/Resources/AltIcons 位于文件系统同步组内，
# 生成的 PNG 会被自动打进 App 包，供 CFBundleAlternateIcons 引用。
set -euo pipefail

SRC_DIR="$SRCROOT/tools/alt-icons"
DST_DIR="$SRCROOT/GlassScale/Resources/AltIcons"
mkdir -p "$DST_DIR"

decode_one() {
  local name="$1"   # cat / dumbbell（对应 $name-1024.webp.b64）
  local out="$2"    # 输出的 PNG 文件名
  local webp="$DST_DIR/$name-1024.webp"
  base64 -D -i "$SRC_DIR/$name-1024.webp.b64" -o "$webp"
  python3 - "$webp" "$DST_DIR/$out" <<'PYEOF'
import sys
try:
    from PIL import Image
except ImportError:
    import subprocess
    subprocess.run([sys.executable, "-m", "pip", "install", "--quiet", "pillow"], check=True)
    from PIL import Image
Image.open(sys.argv[1]).convert("RGB").save(sys.argv[2], "PNG")
PYEOF
  rm -f "$webp"
}

decode_one cat "AppIcon-Cat.png"
decode_one dumbbell "AppIcon-Dumbbell.png"
