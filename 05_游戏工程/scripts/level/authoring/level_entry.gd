@tool
class_name LevelEntry
extends Node2D
## 关卡编辑场景里的一条数据（平台/攀爬区/钩点/敌人/接缝/补丁/检查点/Boss 触发/文字）。
##
## 属于哪一类由父节点名决定（= JSON 键名，如 `platforms`），见 LevelExporter.CATEGORIES。
## position 是世界坐标：矩形类是左上角，点类是点本身。
## 只在编辑场景 level_src/*.tscn 里用；游戏运行时读的是导出的 JSON。

## 对应 JSON 的 "shift": "east"。position 仍是世界坐标，导出时减去 east_shift。
@export var shift_east := false
@export_group("Rect")
@export var rect_size := Vector2.ZERO
@export var color := Color("#1B2A3F")
@export var has_tint := false
@export var tint := Color(1, 1, 1, 1)
@export_group("Point")
@export var kind := ""
## Boss 刷出点，世界坐标（只用于 boss_trigger）。
@export var boss_spawn := Vector2.ZERO
@export_group("Label")
@export_multiline var text := ""
@export var font_size := 15


func category() -> String:
	var parent := get_parent()
	return String(parent.name) if parent else ""


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var font := ThemeDB.fallback_font
	match category():
		"platforms":
			draw_rect(Rect2(Vector2.ZERO, rect_size), color)
			draw_rect(Rect2(Vector2.ZERO, rect_size), Color(1, 1, 1, 0.25), false, 1.0)
		"climb_zones":
			draw_rect(Rect2(Vector2.ZERO, rect_size), tint if has_tint else Color(0.3, 1.0, 0.5, 0.25))
			draw_rect(Rect2(Vector2.ZERO, rect_size), Color(0.3, 1.0, 0.5, 0.9), false, 1.0)
		"labels":
			draw_string(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("#7FA8C9"))
		_:
			var c := _marker_color()
			draw_circle(Vector2.ZERO, 10.0, c)
			draw_string(font, Vector2(12, -10), "%s %s" % [category(), kind], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, c)
			if category() == "boss_trigger":
				var local_spawn := boss_spawn - position
				draw_line(Vector2.ZERO, local_spawn, c, 1.0)
				draw_circle(local_spawn, 14.0, Color(c, 0.5))


func _marker_color() -> Color:
	match category():
		"enemies": return Color("#FF5050")
		"hook_anchors": return Color("#FF3E8A")
		"seams": return Color("#FFD24A")
		"patches": return Color("#8FF5E3")
		"checkpoints": return Color("#7CFF7C")
		"boss_trigger": return Color("#FF8C1A")
	return Color.WHITE
