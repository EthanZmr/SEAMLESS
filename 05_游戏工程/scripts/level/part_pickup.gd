class_name PartPickup
extends Area2D
## 零件：玩家碰到即装上，解锁对应能力（01_GDD/10 §4）。
## 已装过的零件在关卡重载时不再出现。安装演出（3–5 秒）留到美术阶段。

@export var part_id := ""

var pulse := 0.0


func _ready() -> void:
	if _already_installed():
		queue_free()
		return
	body_entered.connect(_on_body_entered)


func _already_installed() -> bool:
	var ids: Array = GameState.PARTS.get(part_id, [])
	if ids.is_empty():
		return false
	for id in ids:
		if not GameState.has_ability(id):
			return false
	return true


func _process(delta: float) -> void:
	pulse += delta
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player") or is_queued_for_deletion():
		return
	if not GameState.install_part(part_id):
		return
	GameEvents.message.emit("零件：%s。" % GameState.PART_NAMES.get(part_id, part_id))
	GameEvents.message.emit("……嗯。能用。")
	set_deferred("monitoring", false)
	queue_free()


func _draw() -> void:
	var r := 14.0 + sin(pulse * 4.0) * 2.0
	var c := Color("#F2B544")
	var pts := PackedVector2Array([Vector2(0, -r), Vector2(r, 0), Vector2(0, r), Vector2(-r, 0)])
	draw_colored_polygon(pts, Color(c, 0.35))
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), c, 2.0)
