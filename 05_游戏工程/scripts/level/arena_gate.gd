class_name ArenaGate
extends Node2D
## 战斗锁门（01_GDD/10 §3）：玩家进入 rect 且里面有活着的敌人 → 两侧关门；
## rect 内敌人全灭 → 开门并记下 "arena:<id>"，之后永不再关。
## 玩家断线时开门；人离开 rect 后才会再次触发，复活后可以重打。

const DOOR_W := 24.0

@export var arena_id := ""
@export var rect := Rect2()

var _closed := false
var _armed := true
var _trigger: Area2D
var _doors: Array[CollisionShape2D] = []


func _ready() -> void:
	_trigger = Area2D.new()
	_trigger.name = "Trigger"
	_trigger.collision_layer = 0
	_trigger.collision_mask = 2
	_trigger.position = rect.get_center()
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = rect.size
	shape.shape = r
	_trigger.add_child(shape)
	add_child(_trigger)
	for side in ["DoorL", "DoorR"]:
		var door := StaticBody2D.new()
		door.name = side
		door.collision_layer = 1
		door.collision_mask = 0
		var x := rect.position.x - DOOR_W * 0.5 if side == "DoorL" else rect.end.x + DOOR_W * 0.5
		door.position = Vector2(x, rect.get_center().y)
		var col := CollisionShape2D.new()
		col.name = "Collision"
		var dr := RectangleShape2D.new()
		dr.size = Vector2(DOOR_W, rect.size.y)
		col.shape = dr
		col.disabled = true
		door.add_child(col)
		add_child(door)
		_doors.append(col)
	GameEvents.player_died.connect(_on_player_died)


func _cleared() -> bool:
	return GameState.has_flag("arena:" + arena_id)


func _player_inside() -> bool:
	for body in _trigger.get_overlapping_bodies():
		if body.is_in_group("player"):
			return true
	return false


func _alive_inside() -> int:
	var n := 0
	var world_rect := Rect2(global_position + rect.position, rect.size)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is EnemyBase and not e.is_dead() and world_rect.has_point(e.global_position):
			n += 1
	return n


func _physics_process(_delta: float) -> void:
	if _cleared():
		_set_closed(false)
		return
	var inside := _player_inside()
	if not inside:
		_armed = true
	if not _closed:
		if inside and _armed and _alive_inside() > 0:
			_set_closed(true)
	elif _alive_inside() == 0:
		_set_closed(false)
		GameState.set_flag("arena:" + arena_id)
		GameEvents.arena_cleared.emit(arena_id)


func _on_player_died() -> void:
	_set_closed(false)
	_armed = false


func _set_closed(v: bool) -> void:
	if v == _closed:
		return
	_closed = v
	for col in _doors:
		col.set_deferred("disabled", not v)
	queue_redraw()


func _draw() -> void:
	if not _closed:
		return
	for col in _doors:
		var p := col.get_parent() as Node2D
		draw_rect(Rect2(p.position - Vector2(DOOR_W, rect.size.y) * 0.5, Vector2(DOOR_W, rect.size.y)), Color("#E8463A"))
