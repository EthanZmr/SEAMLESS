extends Node2D
## W2-02 movement-kit prototype: climb, wall jump, ledge, seam hook.
## Run: godot --path 05_游戏工程 res://scenes/prototype/climb_prototype.tscn

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const CAMERA_SCRIPT := preload("res://scripts/camera/game_camera.gd")

var player: Player
var state_label: Label


func _ready() -> void:

	GameState.reset()
	_build_background()
	_build_geometry()
	_spawn_player()
	_build_hud()


func _build_background() -> void:
	var bg := Polygon2D.new()
	bg.z_index = -30
	bg.color = Color("#070B12")
	bg.polygon = PackedVector2Array([
		Vector2(-300, -300), Vector2(1700, -300),
		Vector2(1700, 900), Vector2(-300, 900)
	])
	add_child(bg)
	for i in range(10):
		var tower := Polygon2D.new()
		tower.z_index = -25
		tower.color = Color("#0D1728") if i % 2 == 0 else Color("#0A1322")
		var x := -200.0 + i * 190.0
		var h := 240.0 + float((i * 67) % 220)
		tower.polygon = PackedVector2Array([
			Vector2(x, 720.0 - h), Vector2(x + 120.0, 720.0 - h),
			Vector2(x + 120.0, 720.0), Vector2(x, 720.0)
		])
		add_child(tower)


func _build_geometry() -> void:
	# Ground and landing.
	_add_platform(Rect2(-100, 620, 1500, 80), Color("#1B2A3F"))
	_add_label("起点：W/S 攀爬，Space 跳/二段/墙跳/翻越，H 钩索，S 放手", Vector2(60, 650))

	# Route 1: climb a tower, then mantle onto its roof.
	_add_platform(Rect2(420, 220, 48, 400), Color("#15243A"))
	_add_climb_zone(Rect2(410 - 18, 250, 36, 360))
	_add_platform(Rect2(420, 220, 300, 24), Color("#23384F"))
	_add_label("路线 1 · 攀爬", Vector2(470, 170))
	_add_label("贴墙按 W 攀爬；攀爬中 Space 上跳；到顶翻越", Vector2(300, 300))

	# Route 2: a narrow wall-jump shaft. Two walls, no floor between them.
	_add_platform(Rect2(900, 180, 40, 440), Color("#15243A"))
	_add_platform(Rect2(1120, 180, 40, 440), Color("#15243A"))
	_add_platform(Rect2(900, 156, 40, 24), Color("#23384F"))
	_add_platform(Rect2(1120, 156, 40, 24), Color("#23384F"))
	_add_label("路线 2 · 墙跳", Vector2(950, 110))
	_add_label("跳向墙 → 贴墙时 Space 反向墙跳；空中再按一次 Space 二段跳", Vector2(900, 640))

	# A couple of ledges/collision checks, so the route is not a straight line.
	_add_platform(Rect2(680, 360, 120, 20), Color("#23384F"))
	_add_platform(Rect2(780, 500, 100, 20), Color("#23384F"))
	_add_platform(Rect2(1320, 360, 120, 20), Color("#23384F"))

	# W2-02 hook anchors: pull toward these, then drop onto the platform below.
	_add_hook_anchor(Vector2(840, 300))
	_add_hook_anchor(Vector2(1360, 300))
	_add_hook_anchor(Vector2(1200, 180))
	_add_label("钩索锚点：靠近后按 H 拉近，松开脱离", Vector2(760, 260))

	# Visual goal line: reaching the roof is the prototype's north star.
	var goal := Line2D.new()
	goal.points = PackedVector2Array([Vector2(420, 210), Vector2(720, 210)])
	goal.width = 2.0
	goal.default_color = Color(0.247, 0.878, 0.815, 0.7)
	add_child(goal)
	_add_label("GOAL · 屋顶", Vector2(520, 180))


func _add_platform(rect: Rect2, color: Color) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = rect.get_center()
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	shape_node.shape = shape
	body.add_child(shape_node)
	var poly := Polygon2D.new()
	var half := rect.size * 0.5
	poly.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y)
	])
	poly.color = color
	body.add_child(poly)
	add_child(body)
	return body


func _add_climb_zone(rect: Rect2) -> ClimbZone:
	var zone := ClimbZone.new()
	zone.position = rect.get_center()
	zone.size = rect.size
	add_child(zone)
	return zone


func _add_hook_anchor(pos: Vector2) -> void:
	var anchor := Node2D.new()
	anchor.position = pos
	anchor.add_to_group("hook_anchors")
	add_child(anchor)
	var diamond := Polygon2D.new()
	diamond.polygon = PackedVector2Array([
		Vector2(0, -12), Vector2(12, 0), Vector2(0, 12), Vector2(-12, 0)
	])
	diamond.color = Color("#FF3E8A")
	anchor.add_child(diamond)
	var ring := Line2D.new()
	ring.points = PackedVector2Array([
		Vector2(0, -18), Vector2(18, 0), Vector2(0, 18), Vector2(-18, 0), Vector2(0, -18)
	])
	ring.width = 1.0
	ring.default_color = Color(0.749, 0.969, 0.941, 0.8)
	anchor.add_child(ring)


func _add_label(text: String, pos: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", 15)
	label.modulate = Color("#7FA8C9")
	add_child(label)


func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate()
	player.position = Vector2(250, 560)
	add_child(player)

	var cam := Camera2D.new()
	cam.set_script(CAMERA_SCRIPT)
	add_child(cam)
	cam.global_position = player.global_position + Vector2(0, -40)
	cam.limit_left = -100
	cam.limit_right = 1500
	cam.limit_top = -100
	cam.limit_bottom = 720
	cam.make_current()


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var help := Label.new()
	help.text = "W2-02 移动套件 · 90 秒\nW/S 攀爬 · Space 跳/二段/墙跳 · H 钩索\n目标：用攀爬或钩索到达右侧高台"
	help.position = Vector2(24, 20)
	help.add_theme_font_size_override("font_size", 18)
	layer.add_child(help)
	state_label = Label.new()
	state_label.position = Vector2(24, 560)
	state_label.add_theme_font_size_override("font_size", 14)
	state_label.modulate = Color("#BFF7F0")
	layer.add_child(state_label)


func _process(_delta: float) -> void:
	if player == null or state_label == null:
		return
	var names := [
		"IDLE", "RUN", "JUMP", "FALL", "DASH", "ATTACK",
		"PARRY", "HURT", "DEAD", "CLIMB", "WALL_SLIDE", "LEDGE", "HOOK"
	]
	state_label.text = "STATE  %s    VEL  %s    AIR  %s" % [
		names[int(player.state)] if int(player.state) < names.size() else "?",
		str(player.velocity.round()),
		"YES" if (player.double_jump_available or player.hook_air_charge > 0) else "NO"
	]
