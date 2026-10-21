extends Node
## 字体加载器：把"用哪个字体"从散落各处的 SystemFont 里收出来。
##
## 现在的项目没有字体文件（白盒阶段），所以默认走 SystemFont 回退链，
## 界面依然能显示中文。等美术把字体丢进 res://assets/fonts/，这里自动接上，
## 不需要改任何调用点 —— 这正是这一层的意义：字体是内容，不是代码。
##
## 用法：
##     label.add_theme_font_override("font", Fonts.ui())
##     label.add_theme_font_size_override("font_size", Fonts.SIZE_BODY)

const DIR := "res://assets/fonts"
## 系统字体回退链：Windows / macOS / Linux 各放一个能显示中文的。
const SYSTEM_NAMES: Array[String] = [
	"Microsoft YaHei", "PingFang SC", "Noto Sans CJK SC", "Source Han Sans SC",
	"SimHei", "WenQuanYi Micro Hei", "Arial",
]
const MONO_NAMES: Array[String] = [
	"Consolas", "JetBrains Mono", "Cascadia Mono", "Menlo", "DejaVu Sans Mono", "Courier New",
]

## 约定文件名（不带扩展名）：丢 assets/fonts/ui.ttf 就是 UI 字体，
## display.ttf 是标题字体，mono.ttf 是调试面板等宽字体。
const SLOT_UI := "ui"
const SLOT_DISPLAY := "display"
const SLOT_MONO := "mono"

const SIZE_CAPTION := 15
const SIZE_BODY := 22
const SIZE_SUB := 24
const SIZE_TITLE := 28
const SIZE_HEAD := 30
const SIZE_HERO := 96

const EXTENSIONS: Array[String] = ["ttf", "otf", "woff2", "woff"]

var _cache: Dictionary = {}
var _available: Dictionary = {}
var _scanned := false


func _ready() -> void:
	scan()


## 扫 res://assets/fonts/ 下所有字体文件。目录不存在也不报错 —— 白盒阶段就没有。
func scan() -> void:
	_scanned = true
	_available.clear()
	if not DirAccess.dir_exists_absolute(DIR):
		return
	var dir := DirAccess.open(DIR)
	if dir == null:
		return
	for file_name in dir.get_files():
		var stem := file_name.get_basename()
		var ext := file_name.get_extension().to_lower()
		if ext in EXTENSIONS and not _available.has(stem):
			_available[stem] = "%s/%s" % [DIR, file_name]


## 这个槽位有没有真字体文件（还是走系统回退）。
func has(slot: String = SLOT_UI) -> bool:
	if not _scanned:
		scan()
	return _available.has(slot)


## 磁盘上认到的字体名列表，便于调试/界面提示"当前用的什么字体"。
func available() -> Array[String]:
	if not _scanned:
		scan()
	var names: Array[String] = []
	for key in _available:
		names.append(String(key))
	names.sort()
	return names


func ui() -> Font:
	return _font_for(SLOT_UI, SYSTEM_NAMES)


func display() -> Font:
	return _font_for(SLOT_DISPLAY, SYSTEM_NAMES)


func mono() -> Font:
	return _font_for(SLOT_MONO, MONO_NAMES)


## 按槽位取名。没有文件时返回对应回退槽位的 SystemFont，
## 永远不返回 null —— 调用点不需要判空。
func _font_for(slot: String, fallback_names: Array[String]) -> Font:
	if _cache.has(slot):
		return _cache[slot] as Font
	if not _scanned:
		scan()
	var font: Font = null
	if _available.has(slot):
		var loaded: Variant = load(String(_available[slot]))
		if loaded is Font:
			font = loaded as Font
	if font == null:
		var sys := SystemFont.new()
		sys.font_names = PackedStringArray(fallback_names)
		# 字体缺失时让同一名字的粗细/斜体也跟着系统走，避免标题字重塌掉。
		sys.allow_system_fallback = true
		font = sys
	_cache[slot] = font
	return font


## 测试/热重载用：清缓存，下次取字体重新扫盘。
func reload() -> void:
	_cache.clear()
	_scanned = false
	scan()


## 当前用的是文件字体还是系统回退。写进启动日志，排查"字看着不对"时有用。
func describe(slot: String = SLOT_UI) -> String:
	if has(slot):
		return "file:%s" % String(_available[slot])
	return "system:%s" % SYSTEM_NAMES[0]
