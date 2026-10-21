#!/usr/bin/env bash
# 统一门禁入口 —— 所有测试都从这里跑，不要手敲 godot 命令。
#
# 为什么要有这个脚本：
#   1) `.gd` 测试分两种运行方式：`-s` (extends SceneTree) 和 `.tscn` (extends Node)。
#      选错模式时 Godot 报的是一堆天书（Identifier not found: DebugLog /
#      Nonexistent function 'new' in base 'GDScript'），排查很费时间。
#      这里按文件头自动判型，调用方永远不用选。
#   2) `-s` 与 `.tscn` 两种模式都**不会**扫描项目脚本，所以全新 checkout 的
#      .godot/global_script_class_cache.cfg 里没有 AttackFrames / PlayerStats，
#      `@export var x: AttackFrames` 会直接 Parse Error。先跑 --import 重建缓存。
#
# 用法：
#   tools/test_all.sh              跑全部
#   tools/test_all.sh test_scene   只跑指定套件（可多个）
#   GODOT=/path/to/godot tools/test_all.sh
#
# 退出码：0 = 全绿，1 = 有失败。

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

GODOT=${GODOT:-godot}
FAILED=0
PASSED=0

if ! command -v "$GODOT" >/dev/null 2>&1; then
	echo "找不到 godot（可用 GODOT=/path/to/godot 指定）" >&2
	exit 1
fi

echo "== 1/2 重建 class cache（--import）=="
if ! "$GODOT" --headless --path . --import >/dev/null 2>&1; then
	echo "  --import 失败，后面的测试会因为 class_name 缺失而误报" >&2
fi
echo "  done"

echo "== 2/2 跑测试 =="

run_one() {
	local name=$1
	local gd="tests/$name.gd"
	if [ ! -f "$gd" ]; then
		printf 'skip  %-22s 无此套件\n' "$name"
		return
	fi

	local out
	if head -5 "$gd" | grep -q '^extends SceneTree'; then
		out=$("$GODOT" --headless --path . -s "res://$gd" 2>&1)
	else
		if [ ! -f "tests/$name.tscn" ]; then
			printf 'FAIL  %-22s 缺 tests/%s.tscn\n' "$name" "$name"
			FAILED=$((FAILED + 1))
			return
		fi
		out=$("$GODOT" --headless --path . "res://tests/$name.tscn" 2>&1)
	fi

	local fails errs summary
	fails=$(printf '%s\n' "$out" | grep -cE '^  FAIL')
	errs=$(printf '%s\n' "$out" | grep -cE 'SCRIPT ERROR|Parse Error')
	summary=$(printf '%s\n' "$out" | grep -E 'PASS \(|FAIL \(|: PASS$|: FAIL$' | tail -1)

	if [ "$fails" -gt 0 ] || [ "$errs" -gt 0 ]; then
		FAILED=$((FAILED + 1))
		printf 'FAIL  %-22s fails=%s errs=%s  %s\n' "$name" "$fails" "$errs" "$summary"
		printf '%s\n' "$out" | grep -E '^  FAIL|SCRIPT ERROR|Parse Error' | head -5 | sed 's/^/        /'
	else
		PASSED=$((PASSED + 1))
		printf 'ok    %-22s %s\n' "$name" "$summary"
	fi
}

if [ "$#" -gt 0 ]; then
	for name in "$@"; do
		run_one "$name"
	done
else
	for gd in tests/*.gd; do
		run_one "$(basename "$gd" .gd)"
	done
fi

echo "----------------------------------------"
echo "套件：通过 $PASSED，失败 $FAILED"
# 一条都没跑也算失败：防止路径写错 / 套件被误删时“静默全绿”。
if [ "$PASSED" -eq 0 ]; then
	echo "没有任何套件跑起来，门禁无效" >&2
	exit 1
fi
if [ "$FAILED" -gt 0 ]; then
	exit 1
fi
