class_name AttackFrameSet
extends Resource
## 三段轻击的帧表容器。挂在 data/combat/light_frames.tres 上。
##
## 一段一个 AttackFrames 子资源，编辑器里展开即可改数值。
##
## 字段用强类型 AttackFrames，编辑器里能直接下拉并只显示合法资源。
## 依赖 .godot/global_script_class_cache.cfg —— 全新 checkout 先跑一次
## `godot --headless --path . --import`（tools/test_all.sh 已强制执行）。
## 万一缓存缺失，reload_frames() 会静默回退到内置字典，不会崩。

@export var light1: AttackFrames
@export var light2: AttackFrames
@export var light3: AttackFrames


## 取指定段的帧表；越界按第一段处理，类型不对时返回 null，由调用方决定兜底。
func frames_of(index: int) -> AttackFrames:
	match clampi(index, 0, 2):
		1:
			return light2
		2:
			return light3
		_:
			return light1
