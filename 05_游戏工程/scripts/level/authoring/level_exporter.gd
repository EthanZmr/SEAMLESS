class_name LevelExporter
extends RefCounted
## 关卡编辑场景（level_src/<id>.tscn）与关卡数据（data/levels/<id>.json）互转。
##
## 运行时仍然只读 JSON（level.gd 不变）；编辑场景只是摆放工具。
## 两个方向都按固定的键顺序生成，所以"JSON → 场景 → JSON"逐字节不变，
## tests/test_level_authoring.gd 守住这一点，并检查编辑场景与 JSON 没有脱节。

const AuthoringScript := preload("res://scripts/level/authoring/level_authoring.gd")
const EntryScript := preload("res://scripts/level/authoring/level_entry.gd")

const SRC_DIR := "res://level_src"
const DATA_DIR := "res://data/levels"

## JSON 键 → 条目形态。顺序就是 JSON 里的顺序。
const CATEGORIES := [
	["platforms", "rect"],
	["climb_zones", "rect"],
	["hook_anchors", "point"],
	["enemies", "point"],
	["seams", "point"],
	["patches", "point"],
	["checkpoints", "point"],
	["boss_trigger", "single"],
	["parts", "point"],
	["lifts", "point"],
	["arenas", "rect"],
	["labels", "label"],
]
## 第一阶段新增的分类：没有条目时不写进 JSON，旧关卡数据保持逐字节不变。
const OPTIONAL_CATEGORIES := ["parts", "lifts", "arenas"]


static func scene_path(level_id: String) -> String:
	return "%s/%s.tscn" % [SRC_DIR, level_id]


static func data_path(level_id: String) -> String:
	return "%s/%s.json" % [DATA_DIR, level_id]


static func to_json_text(data: Dictionary) -> String:
	return JSON.stringify(data, "  ", false) + "\n"


# --- JSON → 编辑场景 ----------------------------------------------------------

static func dict_to_scene(data: Dictionary) -> Node2D:
	var root := AuthoringScript.new()
	var meta: Dictionary = data.get("meta", {})
	var bounds: Dictionary = meta.get("bounds", {})
	root.name = "Level"
	root.level_id = String(meta.get("id", ""))
	root.display_name = String(meta.get("display_name", ""))
	root.east_shift = float(meta.get("east_shift", 0.0))
	var left := float(bounds.get("left", 0.0))
	var top := float(bounds.get("top", 0.0))
	root.bounds = Rect2(left, top,
		float(bounds.get("right", left)) - left, float(bounds.get("bottom", top)) - top)
	var shift := Vector2(root.east_shift, 0.0)

	for cat in CATEGORIES:
		var key: String = cat[0]
		var container := Node2D.new()
		container.name = key
		root.add_child(container)
		var entries: Array = []
		if cat[1] == "single":
			var single: Variant = data.get(key, {})
			if single is Dictionary and not single.is_empty():
				entries.append(single)
		else:
			entries = data.get(key, [])
		for i in entries.size():
			var e: Dictionary = entries[i]
			var node := EntryScript.new()
			node.name = "%s_%02d" % [key, i + 1]
			node.shift_east = e.get("shift", "none") == "east"
			var offset := shift if node.shift_east else Vector2.ZERO
			match cat[1]:
				"rect":
					var r: Array = e.get("rect", [0, 0, 0, 0])
					node.position = Vector2(float(r[0]), float(r[1])) + offset
					node.rect_size = Vector2(float(r[2]), float(r[3]))
					if e.has("color"):
						node.color = Color(String(e["color"]))
					if e.has("tint"):
						var t: Array = e["tint"]
						node.has_tint = true
						node.tint = Color(float(t[0]), float(t[1]), float(t[2]), float(t[3]))
					node.kind = String(e.get("kind", ""))
				"label":
					node.position = _vec(e.get("pos", [0, 0]))
					node.kind = String(e.get("kind", "hint"))
					node.text = String(e.get("text", ""))
					node.font_size = int(e.get("size", 15))
				_:
					node.position = _vec(e.get("pos", [0, 0])) + offset
					node.kind = String(e.get("kind", ""))
					if e.has("boss_spawn"):
						node.boss_spawn = _vec(e["boss_spawn"]) + offset
					if e.has("pos_b"):
						node.has_point_b = true
						node.point_b = _vec(e["pos_b"]) + offset
					node.surface = String(e.get("surface", ""))
					node.drops = String(e.get("drops", ""))
			container.add_child(node)
	return root


## 把整棵树的 owner 设成根，PackedScene.pack 才会把子节点存进去。
static func pack(root: Node) -> PackedScene:
	for child in root.find_children("*", "", true, false):
		child.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	return scene


# --- 编辑场景 → JSON ----------------------------------------------------------

## errors 收集结构问题（未知容器、非 LevelEntry 子节点、多个 Boss 触发点）。
static func scene_to_dict(root: Node, errors: Array = []) -> Dictionary:
	var shift := Vector2(float(root.get("east_shift")), 0.0)
	var b: Rect2 = root.get("bounds")
	var data := {
		"meta": {
			"id": String(root.get("level_id")),
			"display_name": String(root.get("display_name")),
			"east_shift": _num(shift.x),
			"bounds": {
				"left": _num(b.position.x),
				"right": _num(b.end.x),
				"top": _num(b.position.y),
				"bottom": _num(b.end.y),
			},
		},
	}
	var known := {}
	for cat in CATEGORIES:
		known[cat[0]] = cat[1]
	for child in root.get_children():
		if not known.has(String(child.name)):
			errors.append("未知分类容器 %s（可用：%s）" % [child.name, ", ".join(known.keys())])

	for cat in CATEGORIES:
		var key: String = cat[0]
		var container := root.get_node_or_null(NodePath(key))
		var out: Array = []
		if container:
			for node in container.get_children():
				if node.get_script() != EntryScript:
					errors.append("%s/%s 不是 LevelEntry，已忽略" % [key, node.name])
					continue
				out.append(_entry_to_dict(node as EntryScript, cat[1], shift))
		if cat[1] == "single":
			if out.size() > 1:
				errors.append("%s 只能有 1 个条目（现在 %d 个）" % [key, out.size()])
			data[key] = out[0] if not out.is_empty() else {}
		elif not (out.is_empty() and key in OPTIONAL_CATEGORIES):
			data[key] = out
	return data


static func _entry_to_dict(node: EntryScript, shape: String, shift: Vector2) -> Dictionary:
	var offset := shift if node.shift_east else Vector2.ZERO
	var shift_text := "east" if node.shift_east else "none"
	var p := node.position - offset
	match shape:
		"rect":
			var d := {"rect": [_num(p.x), _num(p.y), _num(node.rect_size.x), _num(node.rect_size.y)]}
			if String(node.get_parent().name) == "platforms":
				d["color"] = "#" + node.color.to_html(false).to_upper()
			if String(node.get_parent().name) == "arenas":
				d["kind"] = node.kind
			d["shift"] = shift_text
			if node.has_tint:
				d["tint"] = [_unit(node.tint.r), _unit(node.tint.g), _unit(node.tint.b), _unit(node.tint.a)]
			return d
		"label":
			return {
				"kind": node.kind,
				"text": node.text,
				"pos": [_num(node.position.x), _num(node.position.y)],
				"size": node.font_size,
			}
		"single":
			var spawn := node.boss_spawn - offset
			return {
				"pos": [_num(p.x), _num(p.y)],
				"boss_spawn": [_num(spawn.x), _num(spawn.y)],
				"shift": shift_text,
			}
	# point：enemies 键序是 kind 在前，seams 是 pos 在前，与现有数据保持一致。
	var pb := node.point_b - offset
	match String(node.get_parent().name):
		"enemies":
			var en := {"kind": node.kind, "pos": [_num(p.x), _num(p.y)], "shift": shift_text}
			if node.has_point_b:
				en["pos_b"] = [_num(pb.x), _num(pb.y)]
			if not node.surface.is_empty():
				en["surface"] = node.surface
			if not node.drops.is_empty():
				en["drops"] = node.drops
			return en
		"parts":
			return {"kind": node.kind, "pos": [_num(p.x), _num(p.y)], "shift": shift_text}
		"lifts":
			return {"kind": node.kind, "pos": [_num(p.x), _num(p.y)], "pos_b": [_num(pb.x), _num(pb.y)], "shift": shift_text}
		"seams":
			return {"pos": [_num(p.x), _num(p.y)], "kind": node.kind, "shift": shift_text}
	return {"pos": [_num(p.x), _num(p.y)], "shift": shift_text}


## 坐标走 float32，导出时收到 0.01，避免 1010.0000000001 这种噪音进 JSON。
static func _num(v: float) -> float:
	return snappedf(v, 0.01)


## 颜色分量收到 0.001（float32 的 0.247 会读成 0.24699999）。
static func _unit(v: float) -> float:
	return snappedf(v, 0.001)


static func _vec(a: Variant) -> Vector2:
	var arr: Array = a
	return Vector2(float(arr[0]), float(arr[1]))
