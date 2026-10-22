extends Node2D
## Whitebox Rain Market.
##
## 几何、敌人、缝、检查点、补丁、Boss 触发点全部来自
## `data/levels/rain_market.json`；本脚本只负责"怎么画"（碰撞体 + 多边形），
## 不再负责"画在哪"。改关卡布局：在编辑器里改 `level_src/<id>.tscn`，
## 再跑 `tools/export_level.gd` 导出 JSON，不用碰代码。
##
## A1 layout (W6-01):
##   A 0-900: safehouse -> first fight -> 260px gap + bridge seam -> second
##   fight -> safehouse/needle-eye. B/C/D/F 在数据里用 "shift": "east" 标记，
##   由 meta.east_shift 统一平移，避免逐条改写坐标。

const SWEEPER_SCENE := preload("res://scenes/enemies/sweeper.tscn")
const LANCER_SCENE := preload("res://scenes/enemies/lancer.tscn")
const TRIMMER_SCENE := preload("res://scenes/boss/trimmer.tscn")
const SEAM_SCENE := preload("res://scenes/level/seam.tscn")
const CHECKPOINT_SCENE := preload("res://scenes/level/checkpoint.tscn")
const PATCH_SCENE := preload("res://scenes/level/patch_pickup.tscn")
const BOSS_TRIGGER_SCENE := preload("res://scenes/level/boss_trigger.tscn")
const PART_SCENE := preload("res://scenes/level/part_pickup.tscn")

## 兜底路径：LevelManager 不可用（或清单里没这一关）时用。
const LEVEL_DATA_PATH := "res://data/levels/rain_market.json"
const DEFAULT_EAST_SHIFT := 2000.0

var player: Player
var data: Dictionary = {}
## "json" = 数据文件生效；"empty" = 文件缺失，只剩兜底地面。
var data_source := "empty"

var east_shift := DEFAULT_EAST_SHIFT
var LEVEL_LEFT := -220.0
var LEVEL_RIGHT := 5020.0
var LEVEL_TOP := -420.0
var LEVEL_BOTTOM := 820.0


func _ready() -> void:
	_load_data()
	player = get_parent().get_node_or_null("Player") as Player
	_build_background()
	_build_geometry()
	_spawn_enemies()
	_spawn_seams()
	_spawn_patch()
	_spawn_parts()
	_spawn_checkpoint()
	_spawn_boss_trigger()
	_setup_camera()
	if player:
		GameState.checkpoint = player.global_position
	GameEvents.message.emit("雨市。尺寸不合。")
	GameEvents.message.emit("J 攻击 · K 弹反 · L 换人 · U 缝 · Shift 冲刺")


## 读关卡数据；失败时只留一条兜底地面，保证不黑屏。
func _load_data() -> bool:
	var path := LEVEL_DATA_PATH
	# 关卡数据由 LevelManager 指定：level.gd 不需要知道自己读的是哪一份。
	var from_manager := LevelManager.current_data_path()
	if not from_manager.is_empty():
		path = from_manager
	if not FileAccess.file_exists(path):
		push_error("Level: 缺少关卡数据 %s，使用兜底地面" % path)
		_add_platform(Rect2(-220, 620, 1120, 200), Color("#1B2A3F"))
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Level: %s 不是合法 JSON 对象，使用兜底地面" % path)
		_add_platform(Rect2(-220, 620, 1120, 200), Color("#1B2A3F"))
		return false
	data = parsed
	data_source = "json"
	var meta: Dictionary = data.get("meta", {})
	east_shift = float(meta.get("east_shift", DEFAULT_EAST_SHIFT))
	var bounds: Dictionary = meta.get("bounds", {})
	LEVEL_LEFT = float(bounds.get("left", LEVEL_LEFT))
	LEVEL_RIGHT = float(bounds.get("right", LEVEL_RIGHT))
	LEVEL_TOP = float(bounds.get("top", LEVEL_TOP))
	LEVEL_BOTTOM = float(bounds.get("bottom", LEVEL_BOTTOM))
	return true


func _entries(key: String) -> Array:
	var value: Variant = data.get(key, [])
	return value if value is Array else []


func _east_rect(rect: Rect2) -> Rect2:
	return Rect2(rect.position + Vector2(east_shift, 0), rect.size)


func _east_pos(pos: Vector2) -> Vector2:
	return pos + Vector2(east_shift, 0)


func _rect_of(entry: Dictionary) -> Rect2:
	var r: Array = entry.get("rect", [0, 0, 0, 0])
	var rect := Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
	return _east_rect(rect) if entry.get("shift", "none") == "east" else rect


func _pos_of(entry: Dictionary, key: String = "pos") -> Vector2:
	var p: Array = entry.get(key, [0, 0])
	var pos := Vector2(float(p[0]), float(p[1]))
	return _east_pos(pos) if entry.get("shift", "none") == "east" else pos


func _build_background() -> void:
	var skyline := Polygon2D.new()
	skyline.z_index = -20
	skyline.color = Color("#0B1220")
	skyline.polygon = PackedVector2Array([
		Vector2(-400, -500), Vector2(3900, -500), Vector2(3900, 900), Vector2(-400, 900)
	])
	add_child(skyline)
	for i in range(18):
		var w := 120.0 + float((i * 37) % 90)
		var h := 260.0 + float((i * 71) % 380)
		var x := -200.0 + float(i) * 230.0
		var tower := Polygon2D.new()
		tower.z_index = -19
		tower.color = Color("#101C2E") if i % 2 == 0 else Color("#0E1828")
		tower.polygon = PackedVector2Array([
			Vector2(x, 700.0 - h), Vector2(x + w, 700.0 - h),
			Vector2(x + w, 700.0), Vector2(x, 700.0)
		])
		add_child(tower)
		for j in range(3):
			var window := Polygon2D.new()
			window.z_index = -18
			window.color = Color("#3FE0D0", 0.16) if (i + j) % 3 == 0 else Color("#FF3E8A", 0.12)
			window.polygon = PackedVector2Array([
				Vector2(x + 18.0 + j * 30.0, 700.0 - h + 40.0),
				Vector2(x + 36.0 + j * 30.0, 700.0 - h + 40.0),
				Vector2(x + 36.0 + j * 30.0, 700.0 - h + 70.0),
				Vector2(x + 18.0 + j * 30.0, 700.0 - h + 70.0)
			])
			add_child(window)


func _build_geometry() -> void:
	for entry in _entries("platforms"):
		_add_platform(_rect_of(entry), Color(entry.get("color", "#1B2A3F")))

	for entry in _entries("climb_zones"):
		var zone := _add_climb_zone(_rect_of(entry))
		if entry.has("tint"):
			var t: Array = entry["tint"]
			if t.size() >= 4:
				zone.tint = Color(float(t[0]), float(t[1]), float(t[2]), float(t[3]))

	for entry in _entries("hook_anchors"):
		_add_hook_anchor(_pos_of(entry))

	for entry in _entries("labels"):
		var text := String(entry.get("text", ""))
		var pos := _pos_of(entry)
		if entry.get("kind", "hint") == "zone":
			_add_zone_label(text, pos)
		else:
			_add_label(text, pos, int(entry.get("size", 15)))


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


func _add_platform(rect: Rect2, color: Color) -> StaticBody2D:
	var platform := StaticBody2D.new()
	platform.collision_layer = 1
	platform.collision_mask = 0
	platform.position = rect.get_center()
	var shape_node := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = rect.size
	shape_node.shape = rect_shape
	platform.add_child(shape_node)
	var poly := Polygon2D.new()
	var hw := rect.size.x * 0.5
	var hh := rect.size.y * 0.5
	poly.polygon = PackedVector2Array([
		Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)
	])
	poly.color = color
	platform.add_child(poly)
	add_child(platform)
	return platform


func _add_zone_label(text: String, pos: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", 20)
	label.modulate = Color("#7FA8C9")
	add_child(label)


func _add_label(text: String, pos: Vector2, font_size: int = 15) -> void:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate = Color("#7FA8C9")
	add_child(label)


func _spawn_enemies() -> void:
	for entry in _entries("enemies"):
		var pos := _pos_of(entry)
		if entry.get("kind", "sweeper") == "lancer":
			_add_lancer(pos)
		else:
			_add_enemy(pos)


func _add_enemy(pos: Vector2, group_name := "") -> void:
	var enemy := SWEEPER_SCENE.instantiate()
	enemy.position = pos
	if not group_name.is_empty():
		enemy.add_to_group(group_name)
	add_child(enemy)


func _add_lancer(pos: Vector2) -> void:
	var enemy := LANCER_SCENE.instantiate()
	enemy.position = pos
	add_child(enemy)


func _spawn_seams() -> void:
	for entry in _entries("seams"):
		_add_seam(_pos_of(entry), String(entry.get("kind", "bridge")))


func _spawn_patch() -> void:
	for entry in _entries("patches"):
		var patch := PATCH_SCENE.instantiate()
		patch.position = _pos_of(entry)
		add_child(patch)


func _spawn_parts() -> void:
	for entry in _entries("parts"):
		var part := PART_SCENE.instantiate()
		part.part_id = String(entry.get("kind", ""))
		part.position = _pos_of(entry)
		add_child(part)


func _add_seam(pos: Vector2, kind: String) -> void:
	var seam := SEAM_SCENE.instantiate()
	seam.position = pos
	seam.kind = kind
	add_child(seam)


func _spawn_checkpoint() -> void:
	for entry in _entries("checkpoints"):
		_add_checkpoint(_pos_of(entry))


func _add_checkpoint(pos: Vector2) -> void:
	var checkpoint := CHECKPOINT_SCENE.instantiate()
	checkpoint.position = pos
	add_child(checkpoint)


func _spawn_boss_trigger() -> void:
	var spec: Dictionary = data.get("boss_trigger", {})
	if spec.is_empty():
		return
	var trigger := BOSS_TRIGGER_SCENE.instantiate()
	trigger.position = _pos_of(spec)
	trigger.boss_scene = TRIMMER_SCENE
	trigger.boss_spawn = _pos_of(spec, "boss_spawn")
	add_child(trigger)


func _setup_camera() -> void:
	var cam := get_parent().get_node_or_null("Camera") as Camera2D
	if cam:
		cam.limit_left = int(LEVEL_LEFT)
		cam.limit_right = int(LEVEL_RIGHT)
		cam.limit_top = int(LEVEL_TOP)
		cam.limit_bottom = int(LEVEL_BOTTOM)
		cam.reset_smoothing()
