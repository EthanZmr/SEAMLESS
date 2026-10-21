extends Node
## Global signal bus. Declarations only — no state, no logic.
##
## 架构约定（P1-3）：HUD 只从这里拿数据，不直接 cast 玩家/敌人类型。
## 谁改了什么就去 emit；订阅方不需要认识上游的具体类。

signal sync_changed(value: float)
signal integrity_changed(value: float)
signal form_changed(form: int)
signal takeover_started
signal takeover_ended
signal parry_result(result: String, perfect: bool)
signal player_died
signal checkpoint_reached(position: Vector2)
signal seam_used(kind: String)
signal boss_phase_changed(phase: int)
signal boss_defeated
signal choice_made(choice: String)
signal message(text: String)

## GameState 的完整快照（sync / integrity / form / takeover / flags）。
## HUD、存档、调试面板统一订阅这个，不必直读 autoload。
signal state_snapshot(payload: Dictionary)

## 玩家调试数据（state / velocity / buff / hook …）。
## 只在 DebugLog.enabled 时发送，HUD 不需要认识 Player 类。
signal debug_snapshot(payload: Dictionary)

## 关卡生命周期。
signal level_loaded(level_id: String)
signal level_unloaded(level_id: String)

## 暂停状态。
signal pause_changed(paused: bool)
