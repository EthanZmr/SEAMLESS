extends Node
## 架构改造回归：规则资源 + 每帧推进 + 全局状态序列化。
##
## 为什么必须单独测：GameState 的 _process 被删掉了，规则推进搬到 GameLoop。
## 这一步没有别的测试覆盖 —— 旧测试只检查不变量（clamp、扣血），
## 从来没验证过"时间真的在走"。删错了不会红，只会静默变成一潭死水。
##
## 运行：godot --headless --path . res://tests/test_sync_rules.tscn

const SyncRulesScript := preload("res://scripts/rules/sync_rules.gd")
const RULES_PATH := "res://data/rules/sync_rules.tres"

var _fail := 0
var _total := 0


func _ready() -> void:
	print("TEST_SYNC_RULES: start")

	_test_file_and_fields()
	_test_apply_to_state()
	_test_tick_moves_sync()
	_test_tick_freezes()
	_test_takeover_counts_down()
	_test_serialization_roundtrip()
	await _test_game_loop_wired()
	_test_game_state_has_no_own_process()

	print("TEST_SYNC_RULES: %s (%d assertions)" % [
		"FAIL" if _fail > 0 else "PASS", _total])
	await get_tree().process_frame
	get_tree().quit(1 if _fail > 0 else 0)


func _check(ok: bool, label: String) -> void:
	_total += 1
	if ok:
		print("  PASS  " + label)
	else:
		_fail += 1
		print("  FAIL  " + label)


func _test_file_and_fields() -> void:
	_check(FileAccess.file_exists(RULES_PATH), "sync_rules.tres 已落到 data/rules/")

	var rules: Resource = SyncRulesScript.load_from(RULES_PATH)
	_check(rules != null, "规则资源可加载")
	if rules == null:
		return
	_check(rules.get("max_sync") == 100.0, "max_sync = 100.0")
	_check(rules.get("takeover_duration") == 8.0, "takeover_duration = 8.0")
	_check(rules.get("zhen_sync_rate") == -2.0, "针形态每秒 -2 同步")
	_check(rules.get("ling_sync_rate") == 4.0, "绫形态每秒 +4 同步")
	_check(rules.validate().is_empty(), "规则自身校验通过")

	var names: Array = SyncRulesScript.FIELD_NAMES
	_check(names.size() == 9, "字段清单 9 项（got %d）" % names.size())
	var text := FileAccess.get_file_as_string(RULES_PATH)
	var missing := 0
	for field_name in names:
		if not text.contains("%s =" % field_name):
			missing += 1
	_check(missing == 0, "每个字段都显式落盘（缺 %d）" % missing)


func _test_apply_to_state() -> void:
	GameState.reset()
	var rules: Resource = SyncRulesScript.load_from(RULES_PATH)
	rules.apply_to(GameState)
	_check(GameState.MAX_SYNC == 100.0, "apply_to 注入 MAX_SYNC")
	_check(GameState.TAKEOVER_DURATION == 8.0, "apply_to 注入 TAKEOVER_DURATION")

	# 换一份规则，边界必须立刻跟着变 —— 难度调参靠这个。
	var fast: Resource = SyncRulesScript.load_from(RULES_PATH)
	fast.set("max_sync", 60.0)
	fast.apply_to(GameState)
	_check(GameState.MAX_SYNC == 60.0, "换规则后 MAX_SYNC 立即生效")

	# 还原，别污染后面的用例。
	rules.apply_to(GameState)
	GameState.reset()


func _test_tick_moves_sync() -> void:
	GameState.reset()
	var rules: Resource = SyncRulesScript.load_from(RULES_PATH)
	rules.apply_to(GameState)

	GameState.set_form(0)
	var before := GameState.sync
	rules.tick(GameState, 1.0)
	var after := GameState.sync
	_check(after < before, "针形态 tick 1s 后同步率下降（%.1f → %.1f）" % [before, after])
	_check(is_equal_approx(after, before - 2.0), "下降幅度正好是 zhen_sync_rate")

	GameState.set_form(1)
	var before2 := GameState.sync
	rules.tick(GameState, 1.0)
	_check(GameState.sync > before2, "绫形态 tick 1s 后同步率上升")
	_check(is_equal_approx(GameState.sync, before2 + 4.0), "上升幅度正好是 ling_sync_rate")


func _test_tick_freezes() -> void:
	GameState.reset()
	var rules: Resource = SyncRulesScript.load_from(RULES_PATH)
	rules.apply_to(GameState)
	GameState.set_form(0)
	GameState.freeze_sync(2.0)
	var before := GameState.sync
	rules.tick(GameState, 1.0)
	_check(is_equal_approx(GameState.sync, before), "冻结期间同步率不动")
	_check(GameState.sync_frozen < 2.0, "冻结计时器在递减")


func _test_takeover_counts_down() -> void:
	GameState.reset()
	var rules: Resource = SyncRulesScript.load_from(RULES_PATH)
	rules.apply_to(GameState)
	GameState.start_takeover()
	_check(GameState.is_takeover, "接管已开始")
	var t0 := GameState.takeover_timer
	_check(is_equal_approx(t0, 8.0), "接管时长来自规则（got %.2f）" % t0)

	rules.tick(GameState, 3.0)
	_check(GameState.takeover_timer < t0, "接管计时器在递减（%.2f）" % GameState.takeover_timer)

	# 收尾：把 8 秒走完，必须自动结束接管。
	rules.tick(GameState, 6.0)
	_check(not GameState.is_takeover, "时间走完自动结束接管")


func _test_serialization_roundtrip() -> void:
	GameState.reset()
	GameState.set_form(1)
	GameState.add_sync(17.0)
	GameState.damage(23.0)
	GameState.start_takeover()
	GameState.set_flag("met_boss", true)
	GameState.checkpoint = Vector2(1234, 567)

	var snap := GameState.to_dict()
	_check(snap.get("version") == 2, "快照带版本号 2")
	_check(snap.has("takeover_timer"), "快照包含 takeover_timer（旧版漏了这个字段）")
	_check(snap.has("flags"), "快照包含 flags")

	# 破坏现场，再从快照还原。
	GameState.reset()
	_check(GameState.form == 0, "reset 后回到针形态")
	GameState.from_dict(snap)

	_check(GameState.form == 1, "还原后形态正确")
	_check(is_equal_approx(GameState.sync, float(snap["sync"])), "还原后同步率一致")
	_check(is_equal_approx(GameState.takeover_timer, float(snap["takeover_timer"])),
		"还原后接管计时器一致")
	_check(GameState.has_flag("met_boss"), "还原后 flags 保留")
	_check(GameState.checkpoint.is_equal_approx(Vector2(1234, 567)), "还原后检查点一致")


func _test_game_loop_wired() -> void:
	# main.tscn 必须挂着 GameLoop，否则规则永远不推进。
	var packed := load("res://scenes/main.tscn") as PackedScene
	_check(packed != null, "main.tscn 可加载")
	var main := packed.instantiate()
	add_child(main)
	await get_tree().process_frame

	var loop := main.get_node_or_null("GameLoop") as GameLoop
	_check(loop != null, "main.tscn 挂有 GameLoop")
	if loop != null:
		_check(loop.rules_source == "resource", "GameLoop 的规则来自 .tres（got %s）" % loop.rules_source)
		_check(loop.rules != null, "GameLoop 持有规则实例")
		_check(loop.process_mode == Node.PROCESS_MODE_ALWAYS, "暂停时 GameLoop 仍能收输入")
		_check(not loop.paused, "默认未暂停")

	main.queue_free()
	await get_tree().process_frame


func _test_game_state_has_no_own_process() -> void:
	# 判定依据：GameState 不该再自带每帧逻辑。用 script 的方法表检查。
	var script: Script = GameState.get_script()
	_check(script != null, "GameState 有脚本")
	if script == null:
		return
	var methods := script.get_script_method_list()
	var has_process := false
	for m in methods:
		if str(m.get("name", "")) == "_process":
			has_process = true
	# 注意：_process 若存在但从不被调用，说明它在 Node 上仍然会被引擎每帧调 ——
	# 那样规则会跑两遍。这条断言把"忘记删"钉死。
	_check(not has_process, "GameState 不再自带 _process（规则推进只在 GameLoop）")
