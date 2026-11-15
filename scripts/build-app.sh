#!/bin/zsh
# 构建 release 并打包成 build/Calendr.app（ad-hoc 签名，仅本机使用）
set -euo pipefail
cd "${0:A:h}/.."

swift build -c release

bin="$(swift build -c release --show-bin-path)"
app="build/Calendr.app"

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin/Calendr" "$app/Contents/MacOS/Calendr"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$app"

echo "✅ $app"
echo "安装：cp -R $app /Applications/ && open /Applications/Calendr.app"
