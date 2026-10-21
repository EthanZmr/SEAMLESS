class_name DialogueScript
extends RefCounted
## 对白数据层：把 JSON 读成可直接播放的 line 数组，与 UI 完全无关。
##
## 行格式：{ "who": String, "text": String, "color": String }。
## 约定：who 为空字符串表示旁白；color 缺省走 DEFAULT_COLOR。
##
## 这一层刻意不继承 Node/Resource —— 解析是纯函数，测试可以直接调，
## 也不用为了读一段文案去建节点。

const DEFAULT_COLOR := "#F2EFE6"
const NARRATOR_COLOR := "#9FB6C9"

## 读取结果。source = "json" 表示数据文件生效；"fallback" 表示文件缺失/损坏，
## lines 里只放一条提示行，保证调用方永远能拿到"至少一行"。
class LoadResult:
	var lines: Array[Dictionary] = []
	var source := "fallback"
	var error := ""


## 从 path 读对白。任何失败都不抛错：返回 fallback 的一条提示行。
static func load_lines(path: String) -> LoadResult:
	var result := LoadResult.new()
	var parsed: Variant = null
	if FileAccess.file_exists(path):
		parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	else:
		result.error = "文件不存在"
	if typeof(parsed) == TYPE_DICTIONARY:
		var raw: Variant = (parsed as Dictionary).get("lines", [])
		if raw is Array:
			for entry in raw:
				if entry is Dictionary:
					var line := normalize(entry)
					# 空文本会被当成"瞬间过掉的一行"，宁可丢掉也不要留坑。
					if not String(line["text"]).is_empty():
						result.lines.append(line)
		else:
			result.error = "lines 不是数组"
	elif result.error.is_empty():
		result.error = "JSON 解析失败"
	if result.lines.is_empty():
		result.lines.append({
			"who": "旁白",
			"text": "（对白数据缺失：%s）" % path,
			"color": NARRATOR_COLOR,
		})
		result.source = "fallback"
	else:
		result.source = "json"
	return result


## 把任意 Dictionary 收敛成 line 的三个字段，多余键丢弃。
static func normalize(entry: Dictionary) -> Dictionary:
	var who := String(entry.get("who", ""))
	var color := String(entry.get("color", ""))
	if color.is_empty():
		color = NARRATOR_COLOR if who.is_empty() or who == "旁白" else DEFAULT_COLOR
	return {
		"who": who,
		"text": String(entry.get("text", "")),
		"color": color,
	}


## 校验一份 line 数组，返回问题列表（空数组 = 通过）。
## 这些是"能播放但会出丑"的问题，不是致命错误，所以只报告不阻断。
static func validate(lines: Array) -> Array[String]:
	var problems: Array[String] = []
	if lines.is_empty():
		problems.append("没有对白行")
	for i in range(lines.size()):
		if not (lines[i] is Dictionary):
			problems.append("第 %d 行不是 Dictionary" % (i + 1))
			continue
		var line: Dictionary = lines[i]
		if String(line.get("text", "")).is_empty():
			problems.append("第 %d 行文本为空" % (i + 1))
		if String(line.get("text", "")).length() > 140:
			problems.append("第 %d 行超过 140 字，对话框会溢出" % (i + 1))
		var color := String(line.get("color", ""))
		if color.is_empty():
			problems.append("第 %d 行缺少颜色" % (i + 1))
		elif not Color.html_is_valid(color):
			problems.append("第 %d 行颜色无法解析：%s" % [i + 1, color])
	return problems


## 旁白行判定：who 为空或"旁白"。UI 用它决定是否显示名字条。
static func is_narrator(line: Dictionary) -> bool:
	var who := String(line.get("who", ""))
	return who.is_empty() or who == "旁白"
