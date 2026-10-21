extends Node
## 第二刀回归：玩家调参数值必须来自 data/player/player_stats.tres。
##
## 运行：godot --headless --path . res://tests/test_player_stats.tscn
## （用场景而不是 -s：Player 依赖 DebugLog 等 autoload，脚本模式下无法编译。）

const PlayerStatsScript := preload("res://scripts/player/player_stats.gd")
const STATS_PATH := "res://data/player/player_stats.tres"

var _fail := 0
var _total := 0


func _ready() -> void:
	print("TEST_PLAYER_STATS: start")

	_test_file_exposure()
	_test_overrides_player()
	_test_missing_file_falls_back()
	_test_data_is_live()
	_test_data_file_is_complete()

	print("TEST_PLAYER_STATS: %s (%d assertions)" % [
		"FAIL" if _fail > 0 else "PASS", _total])
	await get_tree().process_frame
	get_tree().quit(1 if _fail > 0 else 0)


func _test_file_exposure() -> void:
	_check(FileAccess.file_exists(STATS_PATH), "player_stats.tres 已落到 data/player/")

	var stats: Resource = PlayerStatsScript.load_from(STATS_PATH)
	_check(stats != null, "资源可加载")
	_check(stats.has_method("apply_to"), "资源暴露 apply_to 接口")
	_check(stats.get("SPEED") == 220.0, "资源内含 SPEED=220.0")

	var dmg: Array = stats.get("COMBO_DAMAGE")
	_check(dmg.size() == 3, "COMBO_DAMAGE 有三段")
	_check(float(dmg[2]) == 20.0, "收招伤害 20.0")

	var names: Array = PlayerStatsScript.FIELD_NAMES
	_check(names.size() >= 60, "字段清单覆盖完整（%d 项）" % names.size())


func _test_overrides_player() -> void:
	var probe := Player.new()
	_check(probe.stats_source == "builtin", "新建实例默认走内建默认值")
	probe._apply_stats()
	_check(probe.stats_source == "resource", "apply 之后标记为 resource 来源")
	_check(probe.SPEED == 220.0, "SPEED 取自资源")
	_check(probe.ATTACK_RANGE == 84.0, "ATTACK_RANGE 取自资源")
	_check(probe.attack_range == 84.0, "派生运行态 attack_range 已同步")
	_check(probe.HOOK_SPEED == 680.0, "HOOK_SPEED 取自资源")

	var stats: Resource = PlayerStatsScript.load_from(STATS_PATH)
	var missing: Array = stats.missing_fields(probe)
	_check(missing.is_empty(), "Player 没有缺失字段 %s" % str(missing))
	probe.free()


func _test_missing_file_falls_back() -> void:
	var absent: Resource = PlayerStatsScript.load_from("res://data/player/__absent__.tres")
	_check(absent == null, "文件缺失时返回 null，不崩")

	var probe := Player.new()
	probe._apply_stats()
	probe._apply_stats()
	_check(probe.stats_source == "resource", "重复 apply 幂等，不报错")
	probe.free()


func _test_data_is_live() -> void:
	# 直接改资源再 apply，玩家必须跟着变——证明数值真的从数据走，不是巧合。
	var custom: Resource = PlayerStatsScript.new()
	custom.set("SPEED", 999.0)
	custom.set("HOOK_RANGE", 123.0)
	var probe := Player.new()
	var applied: int = custom.apply_to(probe)
	_check(applied >= 60, "apply_to 写入全部字段（%d）" % applied)
	_check(probe.SPEED == 999.0, "改资源 SPEED 立即生效")
	_check(probe.HOOK_RANGE == 123.0, "改资源 HOOK_RANGE 立即生效")
	probe.free()


func _test_data_file_is_complete() -> void:
	# ResourceSaver 会省略“等于脚本默认值”的字段，直接存 player_stats.tres
	# 就只剩 script 一行，策划打开看不到任何数值。gen_data.gd 必须全字段落盘。
	var text := FileAccess.get_file_as_string(STATS_PATH)
	var missing := PackedStringArray()
	for field_name in PlayerStatsScript.FIELD_NAMES:
		if not text.contains("\n%s = " % field_name):
			missing.append(field_name)
	_check(missing.is_empty(), "player_stats.tres 含全部 %d 个字段%s" % [
		PlayerStatsScript.FIELD_NAMES.size(),
		"" if missing.is_empty() else "（缺 %s）" % ", ".join(missing)])


func _check(condition: bool, label: String) -> void:
	_total += 1
	if condition:
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)
