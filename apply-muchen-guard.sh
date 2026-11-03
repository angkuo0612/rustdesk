#!/usr/bin/env bash
# RustDesk -> MuchenGuard 品牌定制补丁
# 用法: 在 rustdesk 仓库根目录执行  bash apply-muchen-guard.sh
# 跨平台: macOS / Linux / Windows(Git Bash) 均可，使用 perl 保证行为一致
#
# 注意: RustDesk 的 APP_NAME 只允许 字母/数字/连字符，不允许空格。
#       因此显示名使用无空格的 "MuchenGuard"（而非 "Muchen Guard"），
#       否则安装路径 C:\Program Files\Muchen Guard、服务名、IPC 名会失败。
set -e

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
ok()  { printf "${GREEN}[OK]${NC} %s\n" "$1"; }
die() { printf "${RED}[FAIL]${NC} %s\n" "$1"; exit 1; }

[ -f Cargo.toml ] && [ -d flutter ] || die "请在 rustdesk 仓库根目录执行"

echo "=== MuchenGuard 品牌定制补丁 ==="

# ---------------------------------------------------------------------------
# 1. APP_NAME 总开关（submodule libs/hbb_common）
#    APP_NAME != "RustDesk" 时，src/lang.rs 自动把所有语言文件中的 "RustDesk"
#    替换为 APP_NAME。必须无空格。
# ---------------------------------------------------------------------------
CFG=libs/hbb_common/src/config.rs
[ -f "$CFG" ] || die "缺少 $CFG，请先执行: git submodule update --init --recursive"
perl -pi -e 's/RwLock::new\("RustDesk"\.to_owned\(\)\)/RwLock::new("MuchenGuard".to_owned())/' "$CFG"
grep -q 'RwLock::new("MuchenGuard"' "$CFG" || die "APP_NAME 替换失败"
ok "APP_NAME -> MuchenGuard ($CFG)"

# ---------------------------------------------------------------------------
# 2. Windows 窗口默认名称（窗口标题 / 任务栏兜底值）
# ---------------------------------------------------------------------------
perl -pi -e 's/std::wstring app_name = L"RustDesk";/std::wstring app_name = L"MuchenGuard";/' \
  flutter/windows/runner/main.cpp
grep -q 'app_name = L"MuchenGuard"' flutter/windows/runner/main.cpp || die "main.cpp 替换失败"
ok "main.cpp 窗口名称"

# ---------------------------------------------------------------------------
# 3. exe 版本资源（右键 -> 属性 -> 详细信息）
# ---------------------------------------------------------------------------
RC=flutter/windows/runner/Runner.rc
perl -pi -e 's/VALUE "CompanyName", "Purslane Tech Pte\. Ltd\."/VALUE "CompanyName", "Muchen Tech"/'                        "$RC"
perl -pi -e 's/VALUE "FileDescription", "RustDesk Remote Desktop"/VALUE "FileDescription", "MuchenGuard Remote Desktop"/' "$RC"
perl -pi -e 's/VALUE "InternalName", "rustdesk"/VALUE "InternalName", "muchenguard"/'                                    "$RC"
perl -pi -e 's/VALUE "OriginalFilename", "rustdesk\.exe"/VALUE "OriginalFilename", "muchenguard.exe"/'                    "$RC"
perl -pi -e 's/VALUE "ProductName", "RustDesk"/VALUE "ProductName", "MuchenGuard"/'                                       "$RC"
perl -pi -e 's/Purslane Tech Pte\. Ltd\. All rights reserved\./Muchen Tech. All rights reserved./'                         "$RC"
grep -q 'VALUE "ProductName", "MuchenGuard"' "$RC" || die "Runner.rc 替换失败"
ok "Runner.rc 版本资源"

# ---------------------------------------------------------------------------
# 4. 产物 exe 文件名（BINARY_NAME 决定最终 exe 名字）
#    注意：不改 Cargo 包名，避免 Cargo.lock 失配导致 --locked 构建失败。
# ---------------------------------------------------------------------------
CM=flutter/windows/CMakeLists.txt
perl -pi -e 's/set\(BINARY_NAME "rustdesk"\)/set(BINARY_NAME "muchenguard")/' "$CM"
perl -pi -e 's/project\(rustdesk LANGUAGES CXX\)/project(muchenguard LANGUAGES CXX)/' "$CM"
grep -q 'set(BINARY_NAME "muchenguard")' "$CM" || die "CMakeLists.txt 替换失败"
ok "BINARY_NAME -> muchenguard"

# ---------------------------------------------------------------------------
# 5. MSI 安装包品牌（若使用 MSI 打包）
# ---------------------------------------------------------------------------
PP=res/msi/preprocess.py
if [ -f "$PP" ]; then
  perl -pi -e 's/"--app-name", type=str, default="RustDesk"/"--app-name", type=str, default="MuchenGuard"/' "$PP"
  ok "MSI preprocess.py 默认 app-name"
fi

# ---------------------------------------------------------------------------
# 6. 白板窗口标题
# ---------------------------------------------------------------------------
for f in src/whiteboard/windows.rs src/whiteboard/linux.rs src/whiteboard/macos.rs; do
  [ -f "$f" ] && perl -pi -e 's/\.with_title\("RustDesk whiteboard"\)/\.with_title("MuchenGuard whiteboard")/' "$f"
done
ok "白板窗口标题"

# ---------------------------------------------------------------------------
# 7. 剪贴板占位符（无任何代码比较该字符串，改名安全）
# ---------------------------------------------------------------------------
perl -pi -e 's/RustDesk placeholder to clear the file clipboard/MuchenGuard placeholder to clear the file clipboard/' src/clipboard.rs
ok "剪贴板占位符"

# ---------------------------------------------------------------------------
# 8. Flutter 桌面标签栏标题（用户可见）
# ---------------------------------------------------------------------------
perl -pi -e 's/^                              "RustDesk",$/                              "MuchenGuard",/' \
  flutter/lib/desktop/widgets/tabbar_widget.dart
grep -q '"MuchenGuard",' flutter/lib/desktop/widgets/tabbar_widget.dart || die "tabbar_widget.dart 替换失败"
ok "Flutter 标签栏标题"

# ---------------------------------------------------------------------------
# 9. Windows 服务控制错误信息
# ---------------------------------------------------------------------------
perl -pi -e 's/L"RustDesk service control failed/L"MuchenGuard service control failed/' \
  flutter/windows/runner/service_control.h
ok "service_control.h"

echo ""
echo "=== 补丁应用完成 ==="
