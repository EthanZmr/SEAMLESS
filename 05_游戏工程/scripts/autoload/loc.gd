extends Node
## 文本本地化入口。**新写的 UI 一律走 Loc.t()，不要再硬编码中文。**
##
## 为什么还要一张 FALLBACK 表：翻译是导入产物（data/loc/strings.csv →
## .godot/imported/*.translation），全新 checkout 没跑过 --import 时
## TranslationServer 里是空的，tr() 会把 key 原样吐回来（界面上就是
## "UI_RESUME"）。兜底表保证界面上永远是中文而不是键名。
##
## 注意：FALLBACK 只用于"翻译没加载"，不参与翻译流程 —— 真翻译在 CSV 里。

signal locale_changed(code: String)

const FALLBACK := {
	"UI_CONTINUE": "继续",
	"UI_RESUME": "继续游戏",
	"UI_SETTINGS": "设置",
	"UI_SAVE": "保存进度",
	"UI_LOAD": "读取进度",
	"UI_RESTART": "重开本关",
	"UI_QUIT": "退出到标题",
	"UI_BACK": "返回",
	"UI_CLOSE": "关闭",
	"UI_YES": "是",
	"UI_NO": "否",
	"UI_PAUSED": "已暂停",
	"UI_VOLUME_MASTER": "总音量",
	"UI_VOLUME_MUSIC": "音乐",
	"UI_VOLUME_SFX": "音效",
	"UI_VOLUME_UI": "界面",
	"UI_VOLUME_AMBIENCE": "环境",
	"UI_SECTION_AUDIO": "音频",
	"UI_SECTION_VIDEO": "画面",
	"UI_SECTION_GAMEPLAY": "手感",
	"UI_SECTION_INPUT": "按键",
	"UI_FULLSCREEN": "全屏",
	"UI_VSYNC": "垂直同步",
	"UI_MAX_FPS": "帧率上限",
	"UI_SCREEN_SHAKE": "屏幕震动",
	"UI_HITSTOP": "打击停顿",
	"UI_KEYBIND": "按键绑定",
	"UI_RESET_DEFAULTS": "恢复默认",
	"UI_PRESS_KEY": "按下新的键…",
	"UI_EMPTY_SLOT": "空档位",
	"UI_SLOT": "档位 %d",
	"UI_DELETE": "删除",
	"UI_CONFIRM_DELETE": "确定删除这个档位？",
	"UI_SAVED": "已保存",
	"UI_LOAD_FAILED": "读取失败",
	"UI_SAVE_FAILED": "保存失败",
	"UI_NO_SAVES": "还没有存档",
	"UI_LEVEL": "关卡",
	"GAME_TITLE": "无缝",
	"PROLOGUE_TITLE": "雨市",
}

## 可切换的语言（与 CSV 列头一致）。
const LOCALES: Array[String] = ["zh", "en"]


func _enter_tree() -> void:
	# 用户上次选的语言优先；没有就用系统 locale 的近似值。
	var saved := "zh"
	if Settings != null:
		saved = str(Settings.get_value("video", "locale", "zh"))
	TranslationServer.set_locale(saved)


## 取翻译。args 用 String.format 的占位写法：Loc.t("UI_SLOT", [3]) → "档位 3"。
func t(key: String, args: Array = []) -> String:
	var text := tr(key)
	if text == key:
		text = str(FALLBACK.get(key, key))
	if not args.is_empty():
		text = text % args
	return text


func has(key: String) -> bool:
	if FALLBACK.has(key):
		return true
	return tr(key) != key


func set_locale(code: String) -> void:
	if not LOCALES.has(code):
		push_warning("Loc: 未知语言 %s" % code)
		return
	TranslationServer.set_locale(code)
	if Settings != null:
		Settings.set_value("video", "locale", code)
	locale_changed.emit(code)


func current_locale() -> String:
	return TranslationServer.get_locale()


## 当前语言下缺哪些键（设置界面/CI 用）。
func missing_keys() -> Array[String]:
	var out: Array[String] = []
	for key in FALLBACK:
		if tr(key) == key:
			out.append(key)
	return out
