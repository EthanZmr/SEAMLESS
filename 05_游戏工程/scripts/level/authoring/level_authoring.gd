@tool
class_name LevelAuthoring
extends Node2D
## 关卡编辑场景的根节点：持有 meta，并在编辑器里画出关卡边界。
## 子节点是以 JSON 键名命名的分类容器，容器下面是 LevelEntry。
## 导出：godot --headless --path . -s res://tools/export_level.gd -- <level_id>

@export var level_id := ""
@export var display_name := ""
## 对应 meta.east_shift。改它不会移动任何节点，只影响导出时 shift_east 条目的换算。
@export var east_shift := 0.0
## 对应 meta.bounds（left/top/right/bottom），相机限位用。
@export var bounds := Rect2()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(bounds, Color(1, 0.6, 0.1, 0.8), false, 2.0)
