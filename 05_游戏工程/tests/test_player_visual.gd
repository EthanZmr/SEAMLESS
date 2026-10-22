extends Node
## 玩家用锁定形象 v4 的占位贴图代替白盒方块（尺度见 01_GDD/09：世界高 64，脚底对齐碰撞底）。
## 运行：bash tools/test_all.sh test_player_visual

const PLAYER := preload("res://scenes/player/player.tscn")

var _fail := 0
var _total := 0


func _ready() -> void:
	var p: Player = PLAYER.instantiate()
	add_child(p)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var sprite := p.get_node_or_null("Sprite") as Sprite2D
	_check(sprite != null and sprite.texture != null, "玩家有角色贴图")
	if sprite:
		_check(sprite.visible, "贴图可见")
		_check(not (p.get_node("Body") as CanvasItem).visible, "白盒方块已隐藏")
		var sy := absf(sprite.scale.y)
		var tex_h := float(sprite.texture.get_height())
		var top := sprite.position.y + (-tex_h * 0.5 + sprite.offset.y) * sy
		var bottom := sprite.position.y + (tex_h * 0.5 + sprite.offset.y) * sy
		_check(absf((bottom - top) - 64.0) < 1.0, "贴图世界高 64（%.1f）" % (bottom - top))
		_check(absf(bottom - 28.0) < 1.0, "脚底对齐碰撞底 y=28（%.1f）" % bottom)
		p.facing = 1
		p._update_visuals()
		var right_x := sprite.scale.x
		p.facing = -1
		p._update_visuals()
		_check(signf(sprite.scale.x) == -signf(right_x), "面朝左时贴图翻转")
		p.form = 0
		p._update_visuals()
		var c0 := sprite.modulate
		p.form = 1
		p._update_visuals()
		_check(sprite.modulate != c0, "阿绫形态时贴图变色")
		_check(not (p.get_node("Overlay") as CanvasItem).visible, "不再叠粉色方块")
	p.queue_free()
	if _fail == 0:
		print("TEST_PLAYER_VISUAL: PASS (%d assertions)" % _total)
	else:
		print("TEST_PLAYER_VISUAL: FAIL (%d failures)" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


func _check(ok: bool, label: String) -> void:
	_total += 1
	if ok:
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)
