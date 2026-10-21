#!/usr/bin/env bash
# 导出预设自检。
#
# 为什么单独有这个脚本：Godot 的 `--export-release` 在失败时**退出码仍是 0**，
# 所以只能靠检查产物来判断成败。另外导出模板缺失属于环境问题（一台机器可能从未
# 下载过 ~200MB 模板），不该让本地门禁红掉，所以那种情况下脚本降级为"提示 + 0"。
#
# 用法：
#   bash tools/export_check.sh            # 检查所有预设
#   bash tools/export_check.sh "Linux"    # 只检查某个预设
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

GODOT="${GODOT:-godot}"
PRESETS=("Windows Desktop" "Linux" "Web")
if [ "$#" -ge 1 ]; then
	PRESETS=("$1")
fi

if ! command -v "$GODOT" >/dev/null 2>&1; then
	echo "✗ 找不到 godot（可用 GODOT=/path/to/godot 指定）"
	exit 1
fi

# `--version` 形如 4.7.2.stable.official.ed1daf0bf；模板目录只取前三段 + .stable。
RAW_VER="$("$GODOT" --version | head -1 | awk '{print $1}')"
VER="$(printf '%s' "$RAW_VER" | sed -E 's/^([0-9]+\.[0-9]+\.[0-9]+).*/\1/')"
# 注意用 $HOME 而不是 $APPDATA：后者在 Git Bash 里是 `C:\Users\...` 反斜杠形式，
# 拼进 POSIX 路径会失效。
TPL_DIRS=(
	"${HOME}/AppData/Roaming/Godot/export_templates/${VER}.stable"
	"${HOME}/.local/share/godot/export_templates/${VER}.stable"
	"${HOME}/Library/Application Support/Godot/export_templates/${VER}.stable"
)
TPL=""
for d in "${TPL_DIRS[@]}"; do
	if [ -d "$d" ] && [ -n "$(ls -A "$d" 2>/dev/null)" ]; then
		TPL="$d"
		break
	fi
done

echo "Godot ${VER}   模板目录: ${TPL:-<未安装>}"

if [ -z "$TPL" ]; then
	cat <<-EOF
	⚠ 导出模板未安装 —— 跳过实际导出（不算失败）。

	  安装方式（任选一种）：
	    1) 图形界面：编辑器 → 编辑器菜单 → 管理导出模板 → 下载并安装
	    2) 手动放置：下载官方模板包后解压到
	       ${TPL_DIRS[0]}
	       或 ${TPL_DIRS[1]}

	  预设文件 export_presets.cfg 已就位，装好模板后本脚本会自动真导出。
	EOF
	exit 0
fi

# 预设 → 产物路径 → 最小字节数
out_of() {
	case "$1" in
		"Windows Desktop") echo "build/windows/Seamless.exe|8000000" ;;
		"Linux")           echo "build/linux/Seamless.x86_64|8000000" ;;
		"Web")             echo "build/web/index.html|5000" ;;
		*)                 echo "|0" ;;
	esac
}

fails=0
for preset in "${PRESETS[@]}"; do
	spec="$(out_of "$preset")"
	out="${spec%%|*}"
	min="${spec##*|}"
	if [ -z "$out" ] || [ "$min" = "0" ]; then
		echo "  ?  $preset —— 预设未在 export_check.sh 里登记产物路径"
		fails=$((fails + 1))
		continue
	fi
	rm -f "$out"
	mkdir -p "$(dirname "$out")"
	# 导出失败时退出码仍可能是 0，所以不看 $?，只看产物。
	"$GODOT" --headless --path . --export-release "$preset" "$out" >/tmp/export_"${preset// /_}".log 2>&1
	if [ ! -f "$out" ]; then
		echo "  ✗  $preset —— 没有产出 $out（日志 /tmp/export_${preset// /_}.log）"
		fails=$((fails + 1))
		continue
	fi
	size=$(wc -c <"$out")
	if [ "$size" -lt "$min" ]; then
		echo "  ✗  $preset —— 产物只有 ${size}B，低于阈值 ${min}B"
		fails=$((fails + 1))
		continue
	fi
	echo "  ✓  $preset —— $out (${size} B)"
done

if [ "$fails" -gt 0 ]; then
	echo "EXPORT_CHECK: FAIL (${fails} 个预设)"
	exit 1
fi
echo "EXPORT_CHECK: PASS (${#PRESETS[@]} 个预设)"
exit 0
