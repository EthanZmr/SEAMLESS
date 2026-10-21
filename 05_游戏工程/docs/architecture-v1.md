# 无缝 · 架构评审 v1

> 评审对象：`05_游戏工程`（4045 行 GDScript / 30 脚本 / 17 场景）
> 日期：2026-10-22
> 目的：判断哪些结构该现在改、哪些该等。**判断依据不是"重要程度"，是"改动成本随内容量增长的速度"**。

---

## 0. 结论先行

**问题不在细节，在整整一层缺失。**

现在的代码在"零件"层面质量不错：事件总线窄、输入缓冲成熟、顿帧防重入写对了、数据刚外置完、测试门禁能跑。这些都不要动。

但**世界生命周期这一层是空的**——没有关卡管理器、没有存档边界、`GameState` 既是规则又是状态还自己用 `_process` 跑时间。这一层的特点是：**越晚改越贵，且贵得不成比例**。它的成本不随代码量增长，随"关卡数 × 状态种类数"增长。

一句话：**零件都对，缺的是把所有零件串起来的那根轴。**

---

## 0.5 落地状态（W4 更新）

本文档的 P0 四项与 P1 四项**已全部落地**，12 个测试套件 0 失败。
下面是"当时建议"与"实际做成什么"的对照 —— 方案在实施时改过的地方都标了原因。

| 项 | 状态 | 实际落点 | 与原方案的差异 |
| --- | --- | --- | --- |
| P0-1 关卡生命周期 | ✅ | `autoload/level_manager.gd`、`autoload/save_manager.gd`、`data/levels/index.json` | 存档拆成独立 autoload（`SaveManager`）而不是塞进 LevelManager：存档要同时管 GameState 与关卡 id，塞进去会让 LevelManager 认识 GameState 的内部结构。暂停没做 autoload，挂在 `GameLoop` 上 —— 少一个全局单例。 |
| P0-2 GameState 拆层 | ✅ | `rules/sync_rules.gd`、`rules/game_loop.gd`、`data/rules/sync_rules.tres` | 规则做成 `Resource` + `.tres`（和 AttackFrames/PlayerStats 同一套路），不是硬编码在 GameLoop 里。`GameLoop` 挂在 `main.tscn` 而非 autoload —— 序章和测试场景不需要规则推进。 |
| P0-3 敌人架构 | ✅ | `enemies/enemy_base.gd` → `melee_chaser.gd` → `sweeper.gd`/`lancer.gd` | 拆成**三层**而不是原方案的两层。骨架（重力/受击/死亡/标签契约）与近战 AI（巡逻/追击/前摇/攻击/恢复）分开，因为「远程敌人」将来要复用骨架但不要近战 AI。Boss 不继承 EnemyBase：它有阶段与技能表，差异大于共性。 |
| P0-4 字符串状态机 | ✅ | 两个 `enum`：`EnemyBase.State`、`Trimmer.State`/`Trimmer.Attack` | 加了 `_set_state()` 作为唯一迁移入口 + `_enter_state/_exit_state` 钩子，这样"进入某状态时要做的事"不会散落在赋值点。 |
| P1-1 命中判定物理化 | ✅ | `player.gd::_enemies_in_attack_box/_enemies_in_radius` | 只换了"枚举来源"，**保留原来的偏移筛选**，所以手感与语义完全不变。刻意没加遮挡 raycast：当前关卡没有可穿透薄墙，加了只会改手感。 |
| P1-2 暂停与 time_scale 分层 | ✅ | `get_tree().paused` 归 GameLoop；`Engine.time_scale` 归 `hit_stop.gd` 的缩放栈 | 比原方案多做了一步：顿帧不再是"结束就写回 1.0"，改成栈（`push_scale/pop_scale`）。原写法会把并行的慢动作一起抹掉。 |
| P1-3 HUD 绕过事件总线 | ✅ | `game_events.gd` 加 `state_snapshot`/`debug_snapshot`；HUD 按需重绘 | HUD 从"每帧无条件 `queue_redraw`"改成脏标记驱动。顺带删掉三个只用来 `queue_redraw` 的冗余订阅。 |
| P1-4 敌人自建 Label | ✅ | `ui/enemy_label_layer.gd` 一个 Control 画全部标签 | 定了四方法契约（`label_text/label_anchor/label_alpha/label_tint`），标签层不认识敌人类型。 |

实施中踩到的、值得记住的三件事：

1. **字符串改 `enum` 是静默炸弹。** 残留的 `state == "windup"` 不在编译期报错，
   运行到才炸 `Invalid operands 'int' and 'String'`。藏最深的是测试与 prototype 工具。
2. **`--import` 必须进 CI。** 新 `class_name` 不进 `.godot/global_script_class_cache.cfg`
   就会 `Parse Error: Could not find type`，而 `-s`/`.tscn` 两种运行模式都不重建缓存。
3. **改架构必须先补测试再改。** `GameState` 原来的 `_process` 每帧推进**没有任何测试覆盖**，
   拆层时如果不先写 `test_sync_rules`，改坏了也不会有人知道。

第 7 节"分期路线"与第 8 节"触发信号表"保留原样 —— 它们描述的是**后续**该怎么走，
不是这次的施工单。

---

## 1. 分层现状

> ⚠️ 本节是**改造前的快照**，用来解释为什么那八项要现在改。改造后的状态见第 0.5 节。

| 层 | 职责 | 现状 |
|---|---|---|
| **L0 世界生命周期** | 关卡加载/切换、存档边界、暂停、场景栈 | 🔴 **空** |
| **L1 规则与状态** | 数值规则、实体状态机 | 🟡 混在 GameState / 字符串状态机 |
| **L2 实体与战斗** | 玩家、敌人、Boss、命中判定 | 🟡 两处硬伤 |
| **L3 表现** | HUD、白盒绘制、特效 | 🟢 可接受 |
| **L4 基础设施** | 事件总线、输入、顿帧、日志、测试 | 🟢 **健康** |

L4 健康是这个项目最大的资产。**绝大多数项目死在这里**（20 个 autoload、测试跑不动、事件总线变成全局垃圾场）。这里只有 6 个 autoload、10 套测试、16 行事件总线。这是能继续加内容的地基。

问题集中在 L0 整层 + L1 的两处。

---

## 2. 判断标准

不用"重要/紧急"排，用**成本增长率**：

| 档 | 定义 | 处置 |
|---|---|---|
| **P0 必改** | 现在改 0.5–1 天；做完 5 关后改 5–30 天，且改动跨模块 | 现在做 |
| **P1 可等** | 现在改半天；做完 5 关后改 1–3 天，改动局限在一处 | 等触发信号 |
| **P2 不必** | 现在改 2 天，以后也不用改 | 想到再做 |
| **不做** | 现在做了，以后还得删 | 明确拒绝 |

关键差别在 P0 和 P1：**P0 的成本是超线性的**（每加一个内容单元，改动点乘性增长）；P1 是线性的（加多少内容都只改那一处）。

---

## 3. P0 · 必须现在改

### P0-1 · 关卡生命周期层缺失

**现象**
全项目只有一处场景跳转：`scripts/ui/prologue.gd:163`

```gdscript
get_tree().change_scene_to_file("res://scenes/main.tscn")
```

这是硬编码。没有任何抽象。

**为什么现在改便宜、后期改不起**

第 2 关开始，有 4 个问题必须回答，每个都会散落到 N 处：

1. **切关时保留什么？** `sync`？`form`？`flags`？`checkpoint`？现在没人定义。
2. **死亡从哪重开？** `GameState.checkpoint` 字段存在、`checkpoint_reached` 信号存在，但**没有任何代码用它重生**。现在"重开"是 `reset()` 全清。
3. **过场/暂停/主菜单怎么进出？** 没有场景栈，退出就是销毁。
4. **关卡元数据放哪？** 关卡名、BGM、下一关 ID、出生点——现在全在 `main.tscn` 里写死。

现在回答＝设计一次，半天。5 关之后回答＝改 5 个关卡的入口代码 + 回头兼容已有关卡数据 + 每个组合都要测，3–5 天且必出 bug。

**具体方案**

新增 `scripts/autoload/level_manager.gd`（约 120 行，第 7 个 autoload）：

```gdscript
extends Node
## 唯一允许调用 change_scene 的地方。

signal level_loaded(level_id: String)

const LEVELS := {
    "rain_market": "res://scenes/main.tscn",
    "prologue": "res://scenes/prologue.tscn",
}

var current_level := ""
var pending_spawn := Vector2.ZERO

func goto(level_id: String, keep: Dictionary = {}) -> void:
    # keep: 明确声明哪些状态跨关保留，默认全清
func reload_from_checkpoint() -> void:
    # 读 GameState.checkpoint，切关后把 player 放到那里
func to_main_menu() -> void:
```

配套 `data/levels/index.json`（关卡表：id → 场景路径 + 显示名 + 下一关）。

改造 `prologue.gd:163` 一行 → `LevelManager.goto("rain_market")`。

**工作量**：半天（含一个冒烟测试）。

---

### P0-2 · GameState 拆成「状态」与「规则」两层

**这是全项目最该动的一处。** 它同时违反三条原则，而这三条的后果都会在后期放大。

**现象**（`scripts/autoload/game_state.gd:117` 行）

```gdscript
func _process(delta: float) -> void:
    if sync_frozen > 0.0: ...
    if is_takeover:
        takeover_timer -= delta
        if takeover_timer <= 0.0: end_takeover()
        return
    if sync_frozen <= 0.0:
        if form == 0: add_sync(ZHEN_SYNC_RATE * delta)
        else:         add_sync(LING_SYNC_RATE * delta)
    if form == 0 and integrity < 100.0:
        integrity = minf(100.0, integrity + ZHEN_REGEN_RATE * delta)
        GameEvents.integrity_changed.emit(integrity)
```

一个类里同时有：**可变状态**（8 个字段）、**规则**（速率、倒计时、边界条件）、**时间驱动**（`_process`）、**信号发射**。

**三条硬伤**

1. **不可存档。**
   `sync` / `integrity` / `form` 是可存的结果值；`takeover_timer 3.7` / `sync_frozen 1.2` 是进行中的过程量。玩家在接管第 4 秒存档，读档后 `is_takeover = false`——**接管凭空消失**。玩家会认为这是 bug，而它确实是。

2. **暂停语义未定义。**
   `Engine.time_scale` 已被 `HitStop` 独占（顿帧时设 0.08）。而 `_process(delta)` 的 `delta` **也受 time_scale 缩放**——顿帧期间 `sync` 变化变慢。这是设计意图吗？没人回答过。等做暂停菜单要 `get_tree().paused` 时，两套时间控制会打架。

3. **规则无处扩展。**
   想做"受伤时 sync 掉 5"、"不同关卡不同沉降速率"、"难度倍率"、"某个 patch 让回血翻倍"——只能往 `_process` 里塞更多 `if`。这个类的 117 行会在半年内变成 300 行。

**为什么这是 P0 而不是 P1**

因为它是**唯一一个"以后每加一个系统都受它影响"的点**。存档系统要读它、暂停系统要停它、难度系统要改它、HUD 要监听它、Boss 战要冻结它。

现在拆＝8 个字段归位。
10 个月后拆＝30+ 字段散落各脚本，要先写迁移映射表，再逐处验证。

**具体方案**（关键：**不引入新框架，只做移位**）

```gdscript
# game_state.gd —— 纯数据，无 _process，可序列化
extends Node
var sync := 30.0
var integrity := 100.0
var form := 0
var is_takeover := false
var takeover_timer := 0.0
var sync_frozen := 0.0
var checkpoint := Vector2.ZERO
var flags: Dictionary = {}

func to_dict() -> Dictionary: ...
func from_dict(d: Dictionary) -> void: ...   # 完整还原，含 takeover_timer
func reset() -> void: ...
```

```gdscript
# scripts/rules/sync_rules.gd —— 规则，数据驱动
class_name SyncRules extends Resource
@export var max_sync := 100.0
@export var min_sync := 0.0
@export var takeover_duration := 8.0
@export var takeover_exit_sync := 50.0
@export var takeover_integrity_cost := 20.0
@export var zhen_sync_rate := -2.0
@export var ling_sync_rate := 4.0
@export var zhen_regen_rate := 1.0

func tick(state: Node, delta: float) -> void:
    # 原来的 _process 逻辑搬到这里，只读写 state 的字段
```

由 `main.tscn` 上的一个 `GameLoop` 节点持有 `SyncRules`（或加载 `data/rules/sync.tres`）并驱动 `rules.tick(GameState, delta)`。

**收益立刻可见**：
- 存档＝`GameState.to_dict()`，一行
- 暂停＝`GameLoop.set_process(false)`，不依赖 time_scale
- 难度＝换一份 `.tres`
- 测试＝不需要 autoload 就能跑规则单测

**工作量**：1 天（含 3 个新测试：序列化往返、takeover 存档还原、速率可配）。

---

### P0-3 · 敌人架构：伪数据驱动

**现象**

`scenes/enemies/lancer.tscn` 的 script 指向 `res://scripts/enemies/sweeper.gd`。

两种敌人靠 9 个 `@export` 区分：

| 参数 | sweeper | lancer |
|---|---|---|
| `move_speed` | 62.0 | 48.0 |
| `attack_range` | 78.0 | 112.0 |
| `detect_range` | 240.0 | 260.0 |
| `windup_time` | 0.42 | 0.68 |
| `recover_time` | 0.55 | 0.75 |
| `attack_damage` | 10.0 | 14.0 |
| `max_hp` | 40.0 | 55.0 |
| `enemy_name` | "清道夫" | "截线者" |
| `body_tint` | 红 | 青 |

这**参数化了数值，没参数化行为**。两种敌人的 AI 完全相同——同样的追击、同样的前摇、同样的横砍。

**拐点在第 3 种敌人，不是第 10 种**

复制第 2 份时还能忍（改一处调参）。第 3 种（飞行 / 远程 / 召唤）必须复制 257 行，此后任何 AI bug 修复要同步三份，漏一处就是线上 bug。这是典型的"越过拐点后成本突变"。

**具体方案**（不做 ECS、不做行为树）

```gdscript
# scripts/enemies/enemy_base.gd
class_name EnemyBase extends CharacterBody2D
# 管：hp、take_hit、死亡流程、受击闪白、朝向、Label、被动模式
# 留：func _ai_tick(delta) -> void  —— 子类唯一要实现的方法
```

```gdscript
# scripts/enemies/sweeper.gd  → extends EnemyBase，只留 _ai_tick + 数值
# scripts/enemies/lancer.gd   → 同上
# scripts/enemies/enemy_stats.gd
class_name EnemyStats extends Resource   # 复用 PlayerStats 的模式
```

**工作量**：半天（257 行拆成 base ~120 + sweeper ~90 + lancer ~90）。

---

### P0-4 · 字符串状态机

**现象**

```gdscript
# sweeper.gd
var state := "patrol"
# trimmer.gd
var state := "idle"
```

字符串状态。`state = "patrol"` 写成 `"patro"` —— **静默通过，敌人永远站着不动**。没有编译期检查，没有搜索保障。

`trimmer.gd`（260 行）已经管着 5 个技能（combo / overhead / laser / grid / spin）+ 3 个阶段 + stagger + invuln + seam_timer。Boss 是这个游戏的核心体验，这个文件会最先膨胀。

对比：`player.gd` 用了 `enum State`（13 个），这是对的。同一项目里两套做法。

**为什么算 P0**

因为它是**乘法因子**。后面每加一个 Boss 技能，出错概率都乘在这个不受检的基础上。修它只要 2 小时/文件，但每多等一个技能，未来排查成本就多一份。

**具体方案**

```gdscript
enum State { IDLE, PATROL, CHASE, WINDUP, ATTACK, RECOVER, STAGGER, DEAD }

func _set_state(s: State) -> void:
    if state == s: return
    _exit_state(state)
    state = s
    _enter_state(s)

func _enter_state(s: State) -> void:
    match s:
        State.WINDUP: timer = windup_time
        State.STAGGER: timer = stagger_duration
        ...
```

`enter/exit` 钩子的价值不在优雅，在**堵住"进状态时忘了重置 timer"这一类 bug**。这类 bug 现在靠肉眼，改完靠结构。

**工作量**：2 小时 / 文件，共 2 个文件 + 回归测试。

---

## 4. P1 · 现在改便宜，但可以等

这些的成本是**线性**的——不管做多少关卡、加多少敌人，都只改那一处。等触发信号出现再动手。

### P1-1 · 命中判定不走物理

`player.gd:596 _do_attack_hit()`：遍历 `get_tree().get_nodes_in_group("enemies")`，手算 `absf(offset.x) <= attack_range and absf(offset.y) <= 62.0`。

问题不是性能（10 个敌人无所谓），是**语义不一致**：碰撞层说"打不到"，判定说"打得到"。会出现"隔墙打中"和"明明贴着却没打中"，而且极难调试——因为两套真相。

**触发信号**：敌人同屏 > 10，或出现"隔墙命中"/"贴身 miss"的手感反馈。

**方案**：换成一次 `PhysicsDirectSpaceState2D.intersect_shape()` 查询（不改场景结构，只换实现）。半天。

### P1-2 · 暂停与 time_scale 分层

`Engine.time_scale` 被 `HitStop` 独占。做暂停菜单时 `get_tree().paused` 和它两套时间控制会互相干扰（暂停时 time_scale 仍是 0.08，恢复时机难对齐）。

**触发信号**：要做暂停菜单 / 设置界面 / 过场。

**方案**：`TimeScaleStack`（push/pop 缩放层级，50 行），`HitStop` 和 `Pause` 都往栈里压，栈顶生效。

### P1-3 · HUD 绕过事件总线

`scripts/ui/hud.gd` 混用两种模式：

- 第 25–31 行订阅了 `GameEvents` 的 7 个信号 ✅
- 第 117 行 `var p := get_tree().get_first_node_in_group("player") as Player` 直接读数值 ❌

**触发信号**：做角色切换的 UI 反馈，或出现"切换后 HUD 数字不对"。

**方案**：二选一——要么全走事件（推荐，加 `GameEvents.sync_snapshot(dict)`），要么接受直接读但**删掉事件订阅**。混用是唯一不能接受的。

### P1-4 · 敌人自建 Label

`sweeper._ensure_info()` 在敌人节点内建 Label。10 个敌人 = 10 个 Control 节点跟着物理体跑。

**触发信号**：敌人 > 15，或要统一改敌人 UI 样式。

**方案**：一个 `EnemyLabelLayer`（CanvasLayer + 每帧同步投影位置）。或者白盒期干脆去掉。

---

## 5. 保持 · 这些是对的，别动

写清楚**为什么对**，避免以后有人"重构"掉。

| 资产 | 为什么是对的 |
|---|---|
| `game_events.gd`（16 行 / 12 信号） | **总线够窄**。它只声明信号，不含状态不含逻辑。大多数项目的事件总线会变成"什么都往里塞"的全局垃圾场——这里没有。 |
| `input_buffer.gd`（61 行，带时间戳） | 这是**格斗游戏的做法**（`peek_stamp` / `add_age_grace`），不是普通平台的输入队列。方向正确，不要简化成 `Input.is_action_just_pressed`。 |
| `hit_stop.gd` 的 `_generation` 防重入 | `await` 之后检查代数是否变化，是"异步操作被覆盖"的标准解。**很多人写错这一处**（直接 await 然后无条件恢复 time_scale，导致连击时顿帧时长错乱）。 |
| 数据分离四件（AttackFrames / AttackFrameSet / PlayerStats / level JSON 解释器） | 刚做完，模式正确：`Resource` + 全字段落盘 + `validate()` + `FIELD_NAMES` 测试守门。**照这个模式继续扩展**。 |
| `tools/test_all.sh` + 10 套件 | 能跑、能拦、能回归。这是唯一让"改架构"这件事安全的东西。任何改动前先跑通。 |
| autoload 只有 6 个 | 克制。**第 7 个（LevelManager）加进来后要停手**，再往里加就说明分层出问题了。 |
| `player.gd` 用 `enum State` | 虽然 1170 行偏大，但状态用 enum 是对的。**别学 sweeper/trimmer 的字符串**。 |
| 白盒 `_draw()` 散在各实体 | 白盒期这是正确做法。关卡节奏还没验证完，抽象渲染层是浪费。 |

---

## 6. 明确不做 · 现在做会亏

| 提案 | 为什么不做 |
|---|---|
| **ECS 架构** | ECS 的收益场景是"大量相似实体的属性组合"（几千个子弹、上百个 NPC）。这里有 13 个状态的单角色 + 2 种敌人。收益为零，心智负担全额。**改了以后会想改回来**。 |
| **行为树插件**（LimboAI 等） | Boss 5 个技能，`match state` 够用且直观。行为树在"技能 20+ 且需要非程序员在编辑器里编排"时才值得。现在引入＝多一层调试盲区。 |
| **依赖注入容器** | GDScript 的 autoload + `preload` 已经够用。DI 容器解决的是"单元测试无法构造依赖"——而这里的测试是场景级集成测试，不是单元测试。 |
| **现在接美术管线** | 关卡节奏、战斗手感还没定。这时候定渲染层抽象，等于用未知约束设计接口。白盒先跑通 3 关。 |
| **多语言 / 多平台抽象** | 没有第二个平台的真实需求。抽象层成本立刻付，收益可能永远不来。 |
| **对象池** | 现在没有性能问题。**先测量再优化**。敌人 10 个、粒子几十个，`queue_free` 完全够。等 profiler 显示 GC 峰值再说。 |
| **信号总线框架**（自己写一个 EventBus 库） | `game_events.gd` 16 行已经在做这件事。再包一层只会增加一层间接。 |

---

## 7. 分期路线

顺序不是按优先级排的，是**按依赖关系排的**——后一批要用前一批的接口。

### 第 1 批（约 1.5 天）：内部改造，接口不变

1. **P0-2 GameState 拆两层**
2. **P0-4 状态机 enum 化**（sweeper + trimmer）

为什么先做这两个：都是"外部行为完全不变"的改造，风险最低；而且它们产出后一批要用的接口——`GameState.to_dict()` 给 LevelManager 用，`EnemyBase` 的状态约定给敌人基类用。

**验收**：`bash tools/test_all.sh` 10 套件全绿 + 新增 3 个测试（序列化往返 / 存档还原 takeover / 速率可配）。

### 第 2 批（约半天）：补上 L0

3. **P0-1 LevelManager + 关卡表**

依赖第 1 批的 `GameState.to_dict()`。做完后"存档/继续"这条链就通了。

**验收**：从序章进主场景走 LevelManager；死亡重开回到检查点（不是关卡开头）；新增一个测试验证存档往返后玩家位置正确。

### 第 3 批（约半天）：敌人架构

4. **P0-3 EnemyBase + 数据驱动**

依赖第 1 批的状态机约定。做完后加第 3 种敌人是"新建一个 90 行脚本"，不是"复制 257 行"。

**验收**：sweeper 与 lancer 回归全过（行为不变是硬要求）；新增一个飞行敌人的最小实现，证明扩展成本。

### 之后：按触发信号做 P1

不要主动做。等下表的现象出现。

---

## 8. 触发信号表

比"优先级"更实用——不用凭感觉判断该不该动手，看现象。

| 出现这个现象 | 说明该做 |
|---|---|
| 开始做第 2 关 | P0-1 LevelManager |
| 想加"存档 / 继续游戏" | P0-2（做完就能直接存） |
| 想加第 3 种敌人 | P0-3 敌人基类 |
| Boss 要加第 6 个技能 | P0-4（若还没做，先做） |
| 敌人同屏 > 10，或出现"隔墙打中 / 贴身 miss" | P1-1 判定重构 |
| 要做暂停菜单 / 设置 / 过场 | P1-2 TimeScaleStack |
| 出现"切换角色后 HUD 数字不对" | P1-3 HUD 解耦 |
| 敌人 > 15 个 | P1-4 Label 层 |
| profiler 显示 GC 峰值卡顿 | 对象池 |

---

## 9. 如果只做一件事

**做 P0-2（GameState 拆两层）。**

理由是它是唯一一个"以后每加一个系统都会受影响"的点：存档要读它、暂停要停它、难度要改它、HUD 要监听它、Boss 战要冻结它。其他问题都是局部的，这个问题是全局的。

而且它现在只要 1 天。等做完第 3 关、加了耐力条和装备词条再回来拆，就变成 3 天起、且必须写状态迁移——那才是真正的"后期回来改架构"。

---

## 附录：本次评审未覆盖

- **音频架构**：目前无音频系统（`project.godot` 无 AudioServer 配置）。等第一段 BGM 进来再评审总线规划。
- **存档格式**：`to_dict()` 之后的落盘格式（JSON / binary / `ResourceSaver`）未定。建议 JSON + 版本号字段，与 `data/` 下现有数据风格一致。
- **性能基线**：未做 profiler 采样。P1-1 的性能部分（O(n) 判定）缺乏实测数据支撑，判断仅基于语义一致性。
