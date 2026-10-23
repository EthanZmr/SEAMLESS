extends Node
## 逐帧动画接入（`03_美术/28` 跑步试点）：没图退回占位；有图时跑步显示逐帧、
## 每张停 5 帧、朝左翻转、脚底对齐碰撞底。测试自己塞贴图，不依赖美术是否已交付。
## Run: bash tools/test_all.sh test_player_frames

const PLAYER := preload("res://scenes/player/player.tscn")

var _total := 0
var _fails := 0


func _ready() -> void:
	await get_tree().process_frame
	await _test_fallback()
	await _test_run_frames()
	if _fails == 0:
		print("TEST_PLAYER_FRAMES: PASS (%d assertions)" % _total)
	else:
		print("TEST_PLAYER_FRAMES: FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _check(condition: bool, label: String) -> void:
	_total += 1
	if condition:
		print("  PASS  ", label)
	else:
		_fails += 1
		print("  FAIL  ", label)


func _spawn() -> Player:
	var arena := Node2D.new()
	arena.name = "Arena"
	add_child(arena)
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(2400, 400)
	shape.shape = rect
	body.position = Vector2(0, 200)
	body.add_child(shape)
	arena.add_child(body)
	var p: Player = PLAYER.instantiate()
	p.name = "Player"
	p.position = Vector2(0, -28)
	arena.add_child(p)
	for i in range(3):
		await get_tree().physics_frame
	return p


func _despawn(p: Player) -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	p.get_parent().queue_free()
	await get_tree().process_frame


func _test_fallback() -> void:
	var p := await _spawn()
	_check(p.frames != null, "玩家有 Frames 节点")
	_check(not p.frames.show_anim("no_such_anim", 1, Color.WHITE, Color.CYAN), "没有的动作 → show_anim 返回 false")
	_check(not p.frames.visible, "没图时 Frames 隐藏")
	p._update_visuals()
	_check(p.state != Player.State.RUN and p.sprite.visible, "站着时显示占位图")
	await _despawn(p)


func _test_run_frames() -> void:
	var p := await _spawn()
	var spec := FrameSet.new()
	var textures: Array[Texture2D] = []
	for k in range(spec.count):
		var img := Image.create(spec.canvas.x, spec.canvas.y, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		textures.append(ImageTexture.create_from_image(img))
	p.frames.set_anim("run", spec, textures)

	Input.action_press("move_right")
	var seq: Array[int] = []
	for i in range(40):
		await get_tree().physics_frame
		if p.state == Player.State.RUN:
			seq.append(textures.find(p.frames.texture))
	_check(seq.size() > 20, "按右进入 RUN")
	_check(p.frames.visible and not p.sprite.visible, "跑步时显示逐帧、隐藏占位图")
	_check(seq[0] == 0, "进入跑步从第 1 张开始")
	var runs := _run_lengths(seq)
	var inner := runs.slice(1, runs.size() - 1)
	_check(inner.size() >= 2 and inner.all(func(n: int) -> bool: return n == 5),
		"每张停 5 帧（中段连续长度 %s）" % str(inner))
	_check(p.frames.scale.x > 0.0 and is_equal_approx(p.frames.position.y, -6.0),
		"朝右：不翻转，脚底基线对到碰撞底（y=%.2f）" % p.frames.position.y)

	Input.action_release("move_right")
	Input.action_press("move_left")
	for i in range(20):
		await get_tree().physics_frame
	_check(p.facing == -1 and p.frames.scale.x < 0.0, "朝左：水平翻转")
	_check(is_equal_approx(p.frames.position.x, 0.0), "翻转绕躯干中线，不左右偏移")

	Input.action_release("move_left")
	for i in range(30):
		await get_tree().physics_frame
	_check(p.state == Player.State.IDLE, "松手回到 IDLE")
	_check(not p.frames.visible and p.sprite.visible, "停下退回占位图")
	await _despawn(p)


## 连续相同值的长度序列，例如 [0,0,1,1,1] → [2,3]。
func _run_lengths(seq: Array[int]) -> Array:
	var out: Array = []
	var n := 0
	for k in range(seq.size()):
		n += 1
		if k == seq.size() - 1 or seq[k + 1] != seq[k]:
			out.append(n)
			n = 0
	return out
