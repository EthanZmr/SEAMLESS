extends SceneTree
## Pure combat-math tests. Run with:
##   godot --headless --path 05_游戏工程 -s res://tests/test_runner.gd
## Exits non-zero on failure so CI can gate the build.

const CM := preload("res://scripts/combat/combat_math.gd")

var failures := 0


func _init() -> void:
	_check(CM.classify_parry(-0.01) == "none", "negative elapsed is not a parry")
	_check(CM.classify_parry(0.0) == "perfect", "0.00s is perfect")
	_check(CM.classify_parry(0.08) == "perfect", "0.08s is perfect (inclusive)")
	_check(CM.classify_parry(0.081) == "normal", "0.081s is normal")
	_check(CM.classify_parry(0.20) == "normal", "0.20s is normal (inclusive)")
	_check(CM.classify_parry(0.201) == "none", "0.201s is late")
	_check(CM.is_active(0.0), "active at 0")
	_check(CM.is_active(0.20), "active at 0.20")
	_check(not CM.is_active(0.21), "inactive at 0.21")
	_check(CM.parry_cooldown_after(true) == 0.0, "perfect refunds cooldown")
	_check(CM.parry_cooldown_after(false) == CM.COOLDOWN, "normal costs cooldown")
	_check(CM.damage_multiplier(true) == 1.5, "exposed seam takes 1.5x")
	_check(CM.damage_multiplier(false) == 1.0, "normal damage is 1.0x")
	_check(CM.PERFECT_WINDOW == 0.08, "perfect window is 0.08")
	_check(CM.ACTIVE_WINDOW == 0.20, "active window is 0.20")
	_check(CM.COOLDOWN == 0.40, "cooldown is 0.40")

	if failures == 0:
		print("TEST_RUNNER: PASS (%d assertions)" % 16)
	else:
		print("TEST_RUNNER: FAIL (%d failures)" % failures)
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)
