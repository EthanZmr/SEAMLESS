extends Control
## 敌人标签层（P1-4）。
##
## 之前每个敌人 _ready() 里 `Label.new()` 往自己身上挂一个子节点：
## 敌人越多 Control 节点越多，而且"敌人"这个实体里混进了 UI 布局代码
## （position 用标签的 offset_top 手算、字号/阴影都在敌人脚本里设）。
##
## 现在反过来：敌人只回答四个问题（写什么、锚在哪、多透明、什么颜色），
## 由一个 Control 统一画。加 20 个敌人不会多出 20 个节点，只有一个 draw 循环。
##
## 每帧重画是没必要的 —— 10Hz 足够肉眼看懂，也足够跟上移动。

## 节流间隔（秒）。0.1 = 10Hz。
const REFRESH_INTERVAL := 0.1
const FONT_SIZE := 15
## 文字框宽度，用于居中。
const LABEL_WIDTH := 480.0

var font: Font
var _accum := 0.0
var _entries: Array[Dictionary] = []


func _ready() -> void:
	var sys := SystemFont.new()
	sys.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "SimHei", "Arial"])
	font = sys
	set_process(true)


func _process(delta: float) -> void:
	_accum += delta
	if _accum < REFRESH_INTERVAL:
		return
	_accum = 0.0
	_rebuild()
	queue_redraw()


## 收集所有敌人要画的标签。不认识敌人类型，只调约定好的四个方法。
func _rebuild() -> void:
	_entries.clear()
	var xform := get_viewport().get_canvas_transform()
	for node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(node):
			continue
		if not node.has_method("label_text") or not node.has_method("label_anchor"):
			continue
		if node.has_method("is_dead") and node.is_dead():
			continue
		var anchor: Vector2 = node.label_anchor()
		var screen_pos: Vector2 = xform * anchor
		_entries.append({
			"pos": screen_pos,
			"text": str(node.label_text()),
			"alpha": float(node.label_alpha()) if node.has_method("label_alpha") else 0.72,
			"tint": node.label_tint() if node.has_method("label_tint") else Color.WHITE,
		})


func _draw() -> void:
	if font == null or _entries.is_empty():
		return
	for entry in _entries:
		var text := str(entry.get("text", ""))
		if text.is_empty():
			continue
		var pos: Vector2 = entry.get("pos", Vector2.ZERO)
		var tint: Color = entry.get("tint", Color.WHITE)
		tint.a = float(entry.get("alpha", 0.72))
		# 水平居中到锚点上。
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		draw_string(font, pos - Vector2(w * 0.5, 0.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, tint)
