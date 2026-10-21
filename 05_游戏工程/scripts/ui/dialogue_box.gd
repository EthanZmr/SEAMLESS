extends Control
## 可复用的对话框：屏幕底部的名字条 + 正文 + 继续提示。
##
## 和 prologue.gd 的区别：序章是一次性的全屏演出（标题、雨、淡出），
## 这里是"任何场景里跟谁说话"都能用的通用控件。两者共用 DialoguePlayer，
## 所以对白数据格式、推进语义、结束信号只有一个真相。
##
## 用法：
##     var box := preload("res://scripts/ui/dialogue_box.gd").new()
##     add_child(box)
##     box.closed.connect(_on_dialogue_closed)
##     box.open_file("res://data/dialogue/npc_01.json")

signal closed()
signal line_shown(line: Dictionary, index: int, total: int)

const BOX_H := 190.0
const MARGIN := 96.0
const CHARS_PER_SEC := 38.0

const BG_COLOR := Color(0.03, 0.045, 0.065, 0.92)
const TEXT_COLOR := Color("#F2EFE6")
const NARRATOR_TEXT := Color("#9FB6C9")
const ACCENT := Color("#3FE0D0")
const HINT_COLOR := Color(0.62, 0.72, 0.78, 0.75)

var player: DialoguePlayer
var source := "fallback"

var _speaker: Label
var _body: Label
var _hint: Label
var _typing := false
var _char_timer := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	player = DialoguePlayer.new()
	player.name = "Player"
	add_child(player)
	player.line_changed.connect(_on_line_changed)
	player.finished.connect(_on_finished)
	_build()
	visible = false


func _build() -> void:
	var bg := ColorRect.new()
	bg.name = "Bg"
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bg.offset_top = -BOX_H
	bg.offset_bottom = 0.0
	bg.offset_left = MARGIN
	bg.offset_right = -MARGIN
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var line := ColorRect.new()
	line.name = "Accent"
	line.color = ACCENT
	line.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	line.offset_top = -BOX_H
	line.offset_bottom = -BOX_H + 2.0
	line.offset_left = MARGIN
	line.offset_right = -MARGIN
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)

	_speaker = _make_label("Speaker", 24, ACCENT)
	_speaker.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_speaker.offset_top = -BOX_H + 18.0
	_speaker.offset_bottom = -BOX_H + 52.0
	_speaker.offset_left = MARGIN + 26.0
	_speaker.offset_right = -MARGIN - 26.0
	add_child(_speaker)

	_body = _make_label("Body", 22, TEXT_COLOR)
	_body.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_body.offset_top = -BOX_H + 56.0
	_body.offset_bottom = -BOX_H + 150.0
	_body.offset_left = MARGIN + 26.0
	_body.offset_right = -MARGIN - 26.0
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	add_child(_body)

	_hint = _make_label("Hint", 15, HINT_COLOR)
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -32.0
	_hint.offset_bottom = -8.0
	_hint.offset_left = MARGIN + 26.0
	_hint.offset_right = -MARGIN - 26.0
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.text = "E 继续"
	add_child(_hint)


func _make_label(node_name: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.add_theme_font_override("font", Fonts.ui())
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func open_file(path: String) -> void:
	var result := DialogueScript.load_lines(path)
	source = result.source
	open(result.lines)


func open(lines: Array) -> void:
	visible = true
	_char_timer = 0.0
	_typing = false
	player.start(lines)


func advance() -> void:
	if not visible:
		return
	if _typing:
		_body.visible_characters = -1
		_typing = false
		return
	player.advance()


func close() -> void:
	if not visible:
		return
	visible = false
	player.stop()
	closed.emit()


func _process(delta: float) -> void:
	if not visible or not _typing:
		return
	_char_timer += delta * CHARS_PER_SEC
	_body.visible_characters = int(_char_timer)
	if _body.visible_characters >= _body.text.length():
		_typing = false
		_body.visible_characters = -1


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var pressed := false
	if event.is_action_pressed("interact") or event.is_action_pressed("attack"):
		pressed = true
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = true
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	advance()


func _on_line_changed(line: Dictionary, current: int, total: int) -> void:
	var narrator := DialogueScript.is_narrator(line)
	_speaker.text = "" if narrator else String(line["who"])
	_speaker.visible = not narrator
	_body.text = String(line["text"])
	_body.add_theme_color_override("font_color",
		NARRATOR_TEXT if narrator else TEXT_COLOR)
	_body.visible_characters = 0
	_char_timer = 0.0
	_typing = true
	_hint.text = "%02d / %02d" % [current + 1, total]
	line_shown.emit(line, current, total)


func _on_finished() -> void:
	visible = false
	closed.emit()
