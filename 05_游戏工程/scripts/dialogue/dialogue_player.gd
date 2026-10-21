class_name DialoguePlayer
extends Node
## 对白推进器：只管"现在第几行、还能不能往下"，不碰任何 UI。
##
## UI 订阅 line_changed 自己画；输入层订阅 finished 自己收尾。
## 这样同一个对白数据既能给序章的全屏演出用，也能给场景里的 NPC 气泡用。
##
## 用法：
##     var p := DialoguePlayer.new()
##     add_child(p)
##     p.line_changed.connect(_on_line)
##     p.finished.connect(_on_finished)
##     p.start(lines)

signal line_changed(line: Dictionary, index: int, total: int)
signal started(total: int)
signal finished()

## 当前行下标；-1 表示还没开始或已结束。
var index := -1
var lines: Array[Dictionary] = []
var source := "fallback"

var _playing := false


## 从 JSON 文件直接开始播放。返回 LoadResult 便于调用方读 source/error。
func start_from_file(path: String) -> DialogueScript.LoadResult:
	var result := DialogueScript.load_lines(path)
	start(result.lines)
	source = result.source
	return result


## 播放一组已就绪的 lines。空数组视为立即结束。
func start(next_lines: Array) -> void:
	lines.clear()
	for entry in next_lines:
		if entry is Dictionary:
			lines.append(DialogueScript.normalize(entry))
	index = -1
	if lines.is_empty():
		_playing = false
		finished.emit()
		return
	_playing = true
	started.emit(lines.size())
	_advance_to(0)


## 推进一行。已结束返回 false；否则 true。
func advance() -> bool:
	if not _playing:
		return false
	if index + 1 >= lines.size():
		stop()
		return false
	_advance_to(index + 1)
	return true


## 主动结束（跳过对白 / 玩家离开）。
func stop() -> void:
	if not _playing:
		return
	_playing = false
	index = lines.size() - 1
	finished.emit()


func is_playing() -> bool:
	return _playing


func total() -> int:
	return lines.size()


## 已播到第几行（1 起）。没有行为 0。
func position() -> int:
	return index + 1 if index >= 0 else 0


## 当前行；未开始/空数据返回空 Dictionary。
func current() -> Dictionary:
	if index < 0 or index >= lines.size():
		return {}
	return lines[index]


func has_next() -> bool:
	return _playing and index + 1 < lines.size()


func _advance_to(next_index: int) -> void:
	index = next_index
	line_changed.emit(lines[index], index, lines.size())
