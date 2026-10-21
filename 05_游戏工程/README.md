# 《无缝》游戏工程（白盒切片）

> Godot 4.7.2 · 2D · GDScript

## 运行

```bash
# 在 05_游戏工程 目录下
godot --path . --editor --quit          # 首次导入（生成 .godot/）
godot --path .                          # 运行
```

默认窗口 1280×720，内部 1920×1080（canvas_items 拉伸）。

## 操作

序章：`Enter / J / 空格` 继续，`Esc` 跳过到标题；标题出现后 `Enter / J` 进入雨市。

| 动作 | 键盘 | 手柄 |
|---|---|---|
| 移动 | A / D 或 ← / → | 左摇杆 / 十字键 |
| 跳跃 | Space | A |
| 冲刺 | Shift | B |
| 攻击 | J | X |
| 弹反 | K | Y |
| 换人 | L | LB |
| 缝（接缝/处决/自愈） | U | RB |
| 交互 | E | X |
| 暂停 | Esc | Start |
| Boss 战后选择 | U 拆 / I 缝 | — |
| 切片结束后重开 | R | — |

## 测试

**一条命令跑全部门禁**（推荐，也是 CI 唯一入口）：

```bash
bash tools/test_all.sh                 # 全部套件
bash tools/test_all.sh test_scene      # 只跑指定套件
```

脚本自己干两件事：先 `--import` 重建 `.godot/global_script_class_cache.cfg`，
再按文件头判断每个套件该用 `-s` 还是 `.tscn` 方式跑。
退出码 0 = 全绿；有失败、或一个套件都没跑起来，都返回 1。

全量基线（W4）：12 个套件 0 失败 ——
test_runner 16 / test_attack_spec 27 / test_player_stats 20 / test_sync_rules 39 /
test_level_save 64 / test_prologue_data 8 / test_stage_cancel 7 /
test_light1_behavior 7 / test_combo_grab 3 / test_scene / test_movement / hook_sweep。

新加套件不用注册：脚本扫 `tests/*.gd`，按文件头判型。

> 手敲命令也可以，但**必须选对模式**：`extends SceneTree` 的用 `-s`，
> `extends Node` 的用 `.tscn`。选错不是报错，是**假绿** —— `-s` 模式不加载
> autoload，`DebugLog`/`GameState` 会 `Identifier not found` 编译失败，
> 而 Godot 依然返回 0。所以别手敲，跑 `tools/test_all.sh`。

## 数据分离（W3 起）

数值与内容不再写在脚本里，改数据不用碰代码。加载失败一律静默回退到脚本内置默认值，
只 `push_warning`/`push_error`，不会白屏。

| 数据 | 文件 | 读取方 | 回退 |
| --- | --- | --- | --- |
| 攻击帧表 | `data/combat/light_frames.tres` | `attack_spec.gd::reload_frames()` | 内置 `static var LIGHT1/2/3` |
| 玩家数值 | `data/player/player_stats.tres` | `player.gd::_apply_stats()` | 脚本内 `var` 初值 |
| 同步规则 | `data/rules/sync_rules.tres` | `game_loop.gd::_ready()` → `SyncRules.apply_to(GameState)` | 脚本内 `var` 初值 |
| 关卡几何 | `data/levels/rain_market.json` | `level.gd::_load_data()` | 一条兜底地面 |
| 关卡清单 | `data/levels/index.json` | `level_manager.gd::_load_index()` | 空清单（`start_level` 全部拒绝） |
| 序章对白 | `data/dialogue/prologue_01.json` | `prologue.gd::_load_lines()` | 单行提示 |

重新生成数据文件（只有加 `--force` 才覆盖已有文件）：

```bash
godot --headless --path . -s res://tools/gen_data.gd -- --force
```

生成器会做 round-trip 校验：写完立刻回读，字段值/类型漂移、或帧表自检不过，
都以非 0 退出码报错，不会留下一个"看着有数据其实全是默认值"的文件。

## 架构分层（W4 起）

一次改造把"零件"串成了轴。判断标准不是"重要不重要"，而是**加内容时改动点会不会
跟着内容量一起长**。

| 层 | 负责 | 关键文件 | 硬规则 |
| --- | --- | --- | --- |
| L0 世界 | 关卡生命周期、存档 | `autoload/level_manager.gd`、`autoload/save_manager.gd` | `change_scene_to_file` 只在 `level_manager` 里出现 |
| L1 规则 | 同步/接管推进、暂停 | `rules/game_loop.gd`、`rules/sync_rules.gd` | `game_state.gd` 里**没有** `_process`，推进只发生在 GameLoop |
| L2 实体 | 玩家、敌人、Boss | `player/player.gd`、`enemies/enemy_base.gd`、`melee_chaser.gd` | 敌人状态用 `enum`；状态迁移只走 `_set_state()` |
| L3 表现 | HUD、敌人标签 | `ui/hud.gd`、`ui/enemy_label_layer.gd` | UI 只吃 `GameEvents` 的快照，**不认识 Player 类型** |
| L4 基础设施 | 输入、缓冲、事件、顿帧 | `autoload/` 其余五个 | autoload 只 8 个，加第 9 个要写清理由 |

几个刻意的取舍：

- **暂停与慢动作分两套。** `get_tree().paused` 管整局停住，`Engine.time_scale` 管
  瞬时顿帧。混用会出现"取消暂停之后时间还是 0.1 倍"。
- **时间缩放用栈，不直接写 `Engine.time_scale`。** 并行触发的慢动作彼此独立，
  谁结束都不能把别人的效果抹掉（`hit_stop.gd::push_scale/pop_scale`）。
- **命中判定走物理查询**（`intersect_shape`，mask 4），但保留原来的偏移筛选，
  所以手感与语义不变，只是不再全场景遍历。刻意没加遮挡 raycast —— 当前关卡没有
  可穿透薄墙，加了只会改手感。
- **敌人标签集中到一层画。** 敌人只实现 `label_text/label_anchor/label_alpha/label_tint`
  四个方法，`enemy_label_layer.gd` 每 0.1 秒扫一遍统一绘制，不再每个敌人挂 Label 节点。
- **敌人分三层**：`EnemyBase`（骨架：重力/受击/死亡/闪白/标签契约）→
  `MeleeChaser`（近战 AI：巡逻/追击/前摇/攻击/恢复）→ `Sweeper`/`Lancer`
  （只留数值覆盖）。Boss 不继承，因为它有阶段与技能表，差异大于共性。
- **存档原子写**：先写 `.tmp` 再 rename，不会留下写了一半的存档。

判断依据与"为什么现在不做 ECS / 行为树 / DI、对象池"的完整论证见
`docs/architecture-v1.md`。



三个坑都改在了工具层，不用记，但值得知道为什么。

**1. `-s` 模式静默假绿。** `--headless ... -s res://tests/xxx.gd` 跑一个
`extends Node` 的测试时，autoload 不注册，被测脚本编译失败，**但退出码是 0**。
`Engine.register_singleton()` 也救不了 —— 它只影响运行时单例表，GDScript 的
全局标识符解析在编译期就完成了。修法不是让 `-s` 支持 autoload，而是消灭
"选模式"这件事：`tools/test_all.sh` 按文件头自动判型，并且把输出里出现
`Compile Error` / `SCRIPT ERROR` 也算失败。

**2. `class_name` 缓存缺失导致 `@export` 类型解析失败。** 全新 checkout 没有
`.godot/global_script_class_cache.cfg`，`@export var light1: AttackFrames` 直接
`Parse Error: Could not find type "AttackFrames"`。缓存由编辑器扫描生成，
`-s` 和 `.tscn` 模式都不会重建它。修法：`tools/test_all.sh` 第一步无条件跑
`godot --headless --path . --import`；同时 `reload_frames()` 保留内置兜底，
缓存真缺了也只是回退，不会崩。

**3. `ResourceSaver` 省略默认值，数据文件看着是空的。** 保存 Resource 时会跳过
"等于脚本默认值"的字段。`light_frames.tres` 第一段原本只剩 3 个字段，
`player_stats.tres` 只剩 script 一行 —— 策划打开什么也看不到，代码评审也看不到数值。
修法两层：
- `AttackFrames` 的默认值全部改成中性哨兵（`0` / `false` / `[]`），真实数值必须
  显式写进 `.tres`；漏字段 → 加载成 0 → `validate()` 报错 → 自动回退内置帧表。
- `tools/gen_data.gd` 按 `FIELD_NAMES` 手写全部字段（`body_lean` 带
  `Array[float]([...])` 类型标注），写完 round-trip 比对；测试里再守一道
  "每个字段在文件里出现 N 次"。

**4. 字符串状态改 `enum` 是静默定时炸弹。** `state` 从 `"windup"` 换成
`State.WINDUP` 之后，任何残留的 `state == "windup"` 都不会在编译期报错，而是运行到
那一行才炸：`Invalid operands 'int' and 'String' in operator '!='`。
而且藏得最深的往往在**测试和调试工具**里（`telegraph_preview.gd` 就是）。
改法：改完立刻全项目 grep `state == "`、`state != "`、`state = "`，连
`tests/` 和 `scripts/prototype/` 一起搜，别只搜业务代码。

## 目录

```
data/
  combat/        攻击帧表 .tres
  player/        玩家数值 .tres
  rules/         同步/接管规则 .tres
  levels/        关卡几何 .json + 关卡清单 index.json
  dialogue/      对白 .json
tools/
  gen_data.gd    数据文件生成器（--force 覆盖）
  test_all.sh    门禁入口（--import + 自动判型跑全部套件）
scripts/
  autoload/      输入、输入缓冲、全局状态、事件总线、关卡管理、存档、顿帧
  rules/         GameLoop（规则推进+暂停）、SyncRules（数据驱动规则）
  combat/        弹反帧数据（纯函数，可单测）+ 帧表 Resource
  player/        阿针/阿绫控制器 + PlayerStats 资源
  enemies/       EnemyBase / MeleeChaser / Sweeper / Lancer
  boss/          裁断者
  level/         关卡解释器（读 rain_market.json）、接缝、针眼、Boss 触发器
  camera/        跟随相机
  ui/            序章文本屏、HUD、敌人标签层
scenes/
  prologue.tscn  序章（默认启动场景）
  main.tscn      白盒雨市（挂 GameLoop / Level / LabelLayer / HUDLayer）
  player/        玩家
  enemies/       敌人
  boss/          Boss
  level/         接缝/针眼/触发器
tests/           无头测试（12 套件）
```

## 白盒实现范围

- 序章：34 条对白、打字机、Esc 跳过、标题、淡入雨市。
- 移动/跳跃/冲刺/轻击/弹反/换人/缝/接管 AI/死亡重生。
- 清道夫：巡逻、追击、可弹反挥击、接缝暴露。
- 截线者：同骨架、臂长更长判定更高（跳不过去）、移速更慢。
- 裁断者：三阶段、三连剪、红招过顶剪、激光、网格、旋风剪、三连全弹硬直。
- 雨市：A-F 区白盒平台、3 个接缝、1 个针眼、3 个杂兵、Boss 触发。
- HUD：完整度、同步率、形态、消息、Boss 拆/缝选择、切片结束卡；敌人名牌单独一层。
- 关卡切换（`LevelManager.start_level`）、9 槽存档、暂停（Esc）、时间缩放栈。
- 音效/美术/动画尚未接入；当前是几何占位。

## 已知占位

- 无 TileMap/TileSet；平台由 `rain_market.json` 描述、`level.gd` 实例化。
- 无音频总线/音效；`default_bus_layout.tres` 待建。
- 存档已能落盘（`user://saves`，9 槽，原子写），但**没有存档 UI**，只由代码调用；
  存档里不含敌人/Boss 状态，读档回到检查点重新开打。
- 无通用对话系统；序章是专用文本屏（读 JSON），雨市用 HUD 短消息。
- 中文字体用 `SystemFont` 回退；发布前需嵌入 OFL 字体子集。
- 暂停已做（Esc），设置/按键重绑/音量菜单未做；手柄未实测。
- 真人从头到 Boss 的完整试玩尚未进行（W2 门禁）。
- 关卡清单 `index.json` 只有一关，`next_level_id()` 恒为空；换关路径已打通但没有第二份关卡数据。
- 数据文件仍是手写维护 + `gen_data.gd` 兜底，没有编辑器导出流程。
- `EnemyBase` 只覆盖近战追击型；要做远程/飞行敌人得在 `_update_ai` 之外再加一层
  （当前没有这个需求，所以没提前抽象）。
