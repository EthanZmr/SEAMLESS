extends Node2D
## W4-01 combat prototype: ground string, launcher, air attack.
## Run: godot --path 05_游戏工程 res://scenes/prototype/combat_prototype.tscn

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const SWEEPER_SCENE := preload("res://scenes/enemies/sweeper.tscn")
const CAMERA_SCRIPT := preload("res://scripts/camera/game_camera.gd")

var player: Player
var state_label: Label


func _ready() -> void:
	GameState.reset()
	_build_background()
	_add_platform(Rect2(-120, 620, 1500, 80), Color("#1B2A3F"))
	_add_label("W4-01 战斗原型", Vector2(44, 34), 26, Color("#E8FAFF"))
	_add_label("J ×3 三段连击   ·   S+J 挑空   ·   空中 J 空中攻击", Vector2(44, 72), 18, Color("#BFF7F0"))
	_add_label("目标：把清道夫打浮空，接空中追打。K 弹反，L 换人。", Vector2(44, 104), 15, Color("#7FA8C9"))
	_spawn_player()
	_spawn_dummy(Vector2(520, 560), 120.0)
	_spawn_dummy(Vector2(800, 560), 120.0)
	_add_label("靶子 A", Vector2(492, 515), 14, Color("#FFB13B"))
	_add_label("靶子 B", Vector2(772, 515), 14, Color("#FFB13B"))
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
	for i in range(8):
		var tower := Polygon2D.new()
		tower.z_index = -25
		tower.color = Color("#0D1728") if i % 2 == 0 else Color("#0A1322")
		var x := 40.0 + i * 190.0
		var h := 220.0 + float((i * 53) % 180)
		tower.polygon = PackedVector2Array([
			Vector2(x, 620.0 - h), Vector2(x + 110.0, 620.0 - h),
			Vector2(x + 110.0, 620.0), Vector2(x, 620.0)
		])
		add_child(tower)


func _add_platform(rect: Rect2, color: Color) -> void:
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


func _add_label(text: String, pos: Vector2, size: int = 15, color: Color = Color("#7FA8C9")) -> void:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", size)
	label.modulate = color
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


func _spawn_dummy(pos: Vector2, hp: float) -> void:
	var enemy: Sweeper = SWEEPER_SCENE.instantiate()
	enemy.position = pos
	enemy.passive = true
	enemy.hp = hp
	enemy.max_hp = hp
	add_child(enemy)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
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
	var combo_suffix := ""
	if player.combo_queued:
		combo_suffix = "  [NEXT]"
	elif player.combo_grace > 0.0:
		combo_suffix = "  [%.2fs]" % player.combo_grace
	state_label.text = "STATE  %s    VEL  %s    COMBO  %d%s    AIR  %s" % [
		names[int(player.state)] if int(player.state) < names.size() else "?",
		str(player.velocity.round()),
		player.combo_index + 1,
		combo_suffix,
		"YES" if player.double_jump_available else "NO"
	]
