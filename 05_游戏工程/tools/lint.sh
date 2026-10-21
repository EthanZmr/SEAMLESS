#!/usr/bin/env bash
# GDScript 静态检查。
#
# 设计取舍：**gdlint 缺失时提示并跳过，不阻塞门禁。**
# 理由：本地开发机不一定装了 Python 工具链，而"门禁跑不动"比"少一道静态检查"更糟。
# CI 里会显式安装并强制跑，所以提交前没查到的，push 之后会被拦住。
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

GDLINT=${GDLINT:-}

if [ -z "$GDLINT" ] && command -v gdlint >/dev/null 2>&1; then
	GDLINT=$(command -v gdlint)
fi

# Windows 上 pip 装到 Python 的 Scripts 目录，通常不在 PATH 里。
if [ -z "$GDLINT" ]; then
	for py in python python3 py; do
		command -v "$py" >/dev/null 2>&1 || continue
		scripts_dir=$("$py" -c "import sysconfig;print(sysconfig.get_path('scripts'))" 2>/dev/null)
		[ -n "$scripts_dir" ] || continue
		for cand in "$scripts_dir/gdlint" "$scripts_dir/gdlint.exe"; do
			if [ -x "$cand" ]; then
				GDLINT=$cand
				break 2
			fi
		done
	done
fi

if [ -z "$GDLINT" ]; then
	echo "gdlint 未安装，跳过静态检查。"
	echo "  安装：python -m pip install gdtoolkit"
	echo "  或指定：GDLINT=/path/to/gdlint bash tools/lint.sh"
	echo "  （CI 会强制跑这一道，本地可选）"
	exit 0
fi

echo "== gdlint =="
# 只查代码目录。.gdlintrc 里已关掉风格类规则，剩下的是能挡 bug 的。
if ! "$GDLINT" scripts/ tests/ tools/; then
	echo "静态检查未通过" >&2
	exit 1
fi

echo "== 语法解析（godot --import 全量编译）=="
GODOT=${GODOT:-godot}
if command -v "$GODOT" >/dev/null 2>&1; then
	# 为什么不用 `--check-only --script`：那是**脚本模式**，autoload 一个都不会创建，
	# 于是所有引用 DebugLog / GameState / GameEvents 的脚本都会假报
	# "Compile Error: Identifier not found"，把真实问题淹掉。
	# 全量 --import 走完整项目上下文，能真的编译每个脚本。
	out=$("$GODOT" --headless --path . --import 2>&1)
	if printf '%s' "$out" | grep -qE "Parse Error|Compile Error|Failed to load script"; then
		echo "$out" | grep -E "Parse Error|Compile Error|Failed to load script|at: " | head -10
		echo "存在无法编译的脚本" >&2
		exit 1
	fi
	echo "全部脚本编译通过"
else
	echo "找不到 godot，跳过解析检查（GODOT=/path/to/godot 可指定）"
fi
