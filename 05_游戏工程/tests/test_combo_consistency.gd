extends SceneTree
## 连招数值两份数据源的一致性守门。
##
## player.gd 的攻击时长/判定时刻/距离/击退读 data/player/player_stats.tres 的
## COMBO_*（秒），取消窗与连段窗读 data/combat/light_frames.tres 的帧表（帧）。
## 两边只改一边时，判定帧会漂、取消窗还按旧帧算，其他测试照样绿 —— 这里拦住。
## 运行：bash tools/test_all.sh test_combo_consistency

const AS := preload("res://scripts/combat/attack_spec.gd")
const STATS := preload("res://scripts/player/player_stats.gd")

var failures := 0
var total := 0


func _init() -> void:
	_check(AS.data_source == "resource", "帧表来自 light_frames.tres")
	var stats: Resource = STATS.load_from(STATS.PATH)
	_check(stats != null, "player_stats.tres 可读")
	if stats != null:
		for i in 3:
			var spec: Dictionary = AS.spec_of(i)
			var seg := "第%d段" % (i + 1)
			var t: float = stats.COMBO_TIMES[i]
			_check(roundi(t * AS.FPS) == int(spec.total_frames),
				"%s 时长 COMBO_TIMES %.3fs ≈ total_frames %df" % [seg, t, int(spec.total_frames)])
			var active: float = stats.COMBO_ACTIVE[i]
			_check(absf(active - float(spec.hit_time)) < 0.0001,
				"%s 判定时刻 COMBO_ACTIVE %.3fs == hit_time %.3fs" % [seg, active, float(spec.hit_time)])
			_check(AS.frame_of(active) == int(spec.hit_frame),
				"%s 判定时刻落在 hit_frame %df" % [seg, int(spec.hit_frame)])
			var reach: float = stats.COMBO_RANGE[i]
			_check(is_equal_approx(reach, float(spec.hitbox_forward)),
				"%s 距离 COMBO_RANGE %.0f == hitbox_forward %.0f" % [seg, reach, float(spec.hitbox_forward)])

		_check(is_equal_approx(stats.COMBO_KNOCKBACK[1], float(AS.LIGHT2.pull_speed_cap)),
			"二段 COMBO_KNOCKBACK == pull_speed_cap")
		_check(is_equal_approx(stats.COMBO_KNOCKBACK[2], float(AS.LIGHT3.knockback)),
			"三段 COMBO_KNOCKBACK == knockback")
		_check(is_equal_approx(stats.ATTACK_COOLDOWN, float(AS.LIGHT3.attack_cd_after)),
			"ATTACK_COOLDOWN == 三段 attack_cd_after")

	if failures == 0:
		print("TEST_COMBO_CONSISTENCY: PASS (%d assertions)" % total)
	else:
		print("TEST_COMBO_CONSISTENCY: FAIL (%d failures)" % failures)
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	total += 1
	if condition:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)
