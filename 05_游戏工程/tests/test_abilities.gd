extends Node
## 能力解锁：GameState 的能力集合、零件、存档迁移，以及玩家各动作的门控。
##
## 运行：bash tools/test_all.sh test_abilities

const PROTO := preload("res://scenes/prototype/climb_prototype.tscn")

var _fail := 0
var _total := 0


func _ready() -> void:
	_test_default_all()
	_test_new_game_empty()
	_test_unlock()
	_test_install_part()
	_test_reset_keeps()
	_test_roundtrip()
	_test_legacy_without_abilities()
	GameState.unlock_all_abilities()
	if _fail == 0:
		print("TEST_ABILITIES: PASS (%d assertions)" % _total)
	else:
		print("TEST_ABILITIES: FAIL (%d failures)" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


func _check(ok: bool, label: String) -> void:
	_total += 1
	if ok:
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)


func _count_unlocked() -> int:
	var n := 0
	for id in GameState.ABILITIES:
		if GameState.has_ability(id):
			n += 1
	return n


func _test_default_all() -> void:
	GameState.unlock_all_abilities()
	_check(_count_unlocked() == GameState.ABILITIES.size(), "全部解锁后 7 个能力都有")


func _test_new_game_empty() -> void:
	GameState.set_flag("x")
	GameState.begin_new_game()
	_check(_count_unlocked() == 0, "新游戏没有任何能力")
	_check(GameState.flags.is_empty(), "新游戏清空剧情标记")


func _test_unlock() -> void:
	GameState.begin_new_game()
	_check(GameState.unlock_ability("climb"), "首次解锁 climb 返回 true")
	_check(GameState.has_ability("climb"), "解锁后 has_ability(climb)")
	_check(not GameState.unlock_ability("climb"), "重复解锁返回 false")
	_check(not GameState.unlock_ability("fly"), "未知能力返回 false")
	_check(not GameState.has_ability("fly"), "未知能力不会被记下")


func _test_install_part() -> void:
	GameState.begin_new_game()
	_check(GameState.install_part("valve"), "安装气阀返回 true")
	_check(GameState.has_ability("double_jump") and GameState.has_ability("dash"), "气阀解锁二段跳和冲刺")
	_check(not GameState.install_part("valve"), "重复安装返回 false")
	_check(not GameState.install_part("wing"), "未知零件返回 false")
	_check(GameState.PART_NAMES.get("claw", "") == "攀爬爪", "零件名：claw = 攀爬爪")


func _test_reset_keeps() -> void:
	GameState.begin_new_game()
	GameState.unlock_ability("climb")
	GameState.reset()
	_check(GameState.has_ability("climb"), "断线复活（reset）不丢能力")


func _test_roundtrip() -> void:
	GameState.begin_new_game()
	GameState.unlock_ability("climb")
	GameState.unlock_ability("hook")
	var d := GameState.to_dict()
	_check(int(d.get("version", 0)) == 3, "状态结构版本为 3")
	GameState.begin_new_game()
	GameState.from_dict(d)
	_check(GameState.has_ability("climb") and GameState.has_ability("hook"), "存读档保留已解锁能力")
	_check(_count_unlocked() == 2, "存读档不多出能力")


func _test_legacy_without_abilities() -> void:
	GameState.begin_new_game()
	GameState.from_dict({"version": 2, "sync": 30.0})
	_check(_count_unlocked() == GameState.ABILITIES.size(), "旧档（无 abilities 字段）视为全部解锁")
