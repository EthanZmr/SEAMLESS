# 《无缝》游戏工程（白盒切片）

> Godot 4.7.2 · 2D · GDScript · 18 个无头测试套件

## 运行

```bash
# 在 05_游戏工程 目录下
godot --path . --editor --quit          # 首次导入（生成 .godot/）
godot --path .                          # 运行
godot --path . -- --log                 # 运行 + 写会话日志到 user://logs/
```

默认窗口 1280×720，内部 1920×1080（canvas_items 拉伸）。

## 操作

序章：`Enter / J / 空格` 继续，`Esc` 跳过到标题；标题出现后 `Enter / J` 进入雨市。

下表是**出厂默认键**。游戏内 `Esc` → 设置 → 按键绑定可以逐个改，改完存在
`user://settings.cfg`，下次启动自动生效。

| 动作 | 键盘 | 手柄 |
|---|---|---|
| 移动 | A / D 或 ← / → | 左摇杆 / 十字键 |
| 跳跃 | Space | A |
| 冲刺 | Shift | B |
| 攻击 | J | X |
| 弹反 | K | Y |
| 换人 | L | LB |
| 缝（接缝/处决/自愈） | U | RB |
| 钩索 | H | — |
| 交互 | E | X |
| 暂停 | Esc | Start |
| Boss 战后选择 | U 拆 / I 缝 | — |
| 切片结束后重开 | R | — |

## 门禁（改完必跑）

```bash
bash tools/test_all.sh                 # 全部套件
bash tools/test_all.sh test_scene      # 只跑指定套件
bash tools/lint.sh                     # gdlint + 全量编译检查
bash tools/export_check.sh             # 三平台导出并检查产物
```

`test_all.sh` 自己干两件事：先 `--import` 重建 `.godot/global_script_class_cache.cfg`，
再按文件头判断每个套件该用 `-s` 还是 `.tscn` 方式跑。退出码 0 = 全绿；
有失败、或一个套件都没跑起来，都返回 1。

全量基线（W5）：**20 个套件 0 失败** ——
test_attack_spec 27 / test_combo_grab 3 / test_dialogue 57 / test_fonts 21 /
test_level_save 64 / test_light1_behavior 7 / test_loc 20 / test_log 23 /
test_menu 27 / test_player_stats 20 / test_probe 35 / test_prologue_data 8 /
test_runner 16 / test_save_migration 34 / test_settings 30 / test_stage_cancel 7 /
test_sync_rules 39 / test_scene / test_movement / hook_sweep。

新加套件不用注册：脚本扫 `tests/*.gd`，按文件头判型。

> 手敲命令也可以，但**必须选对模式**：`extends SceneTree` 的用 `-s`，
> `extends Node` 的用 `.tscn`。选错不是报错，是**假绿** —— `-s` 模式不加载
> autoload，`DebugLog`/`GameState` 会 `Identifier not found` 编译失败，
> 而 Godot 依然返回 0。所以别手敲，跑 `tools/test_all.sh`。

## 数据分离

数值与内容不再写在脚本里，改数据不用碰代码。加载失败一律静默回退到脚本内置默认值，
只 `push_warning`/`push_error`，不会白屏。

| 数据 | 文件 | 读取方 | 回退 |
| --- | --- | --- | --- |
| 攻击帧表 | `data/combat/light_frames.tres` | `attack_spec.gd::reload_frames()` | 内置 `static var LIGHT1/2/3` |
| 玩家数值 | `data/player/player_stats.tres` | `player.gd::_apply_stats()` | 脚本内 `var` 初值 |
| 同步规则 | `data/rules/sync_rules.tres` | `game_loop.gd::_ready()` → `SyncRules.apply_to(GameState)` | 脚本内 `var` 初值 |
| 关卡几何 | `data/levels/rain_market.json` | `level.gd::_load_data()` | 一条兜底地面 |
| 关卡清单 | `data/levels/index.json` | `level_manager.gd::_load_index()` | 空清单（`start_level` 全部拒绝） |
| 序章对白 | `data/dialogue/prologue_01.json` | `DialogueScript.load_lines()` | 单行提示 |
| 界面文案 | `data/loc/strings.csv` | `loc.gd::t()` | 内置 40 条中文兜底表 |
| 字体槽位 | `assets/fonts/{ui,display,mono}.ttf` | `fonts.gd::ui()/display()/mono()` | `SystemFont` 回退链 |

重新生成数据文件（只有加 `--force` 才覆盖已有文件）：

```bash
godot --headless --path . -s res://tools/gen_data.gd -- --force
```

生成器会做 round-trip 校验：写完立刻回读，字段值/类型漂移、或帧表自检不过，
都以非 0 退出码报错，不会留下一个"看着有数据其实全是默认值"的文件。

## 架构分层

判断标准不是"重要不重要"，而是**加内容时改动点会不会跟着内容量一起长**。

| 层 | 负责 | 关键文件 | 硬规则 |
| --- | --- | --- | --- |
| L0 世界 | 关卡生命周期、存档 | `autoload/level_manager.gd`、`autoload/save_manager.gd` | `change_scene_to_file` 只在 `level_manager` 里出现 |
| L1 规则 | 同步/接管推进、暂停 | `rules/game_loop.gd`、`rules/sync_rules.gd` | `game_state.gd` 里**没有** `_process`，推进只发生在 GameLoop |
| L2 实体 | 玩家、敌人、Boss | `player/player.gd`、`enemies/enemy_base.gd`、`melee_chaser.gd` | 敌人状态用 `enum`；状态迁移只走 `_set_state()` |
| L3 表现 | HUD、敌人标签、菜单、对话框 | `ui/*.gd` | UI 只吃 `GameEvents` 的快照，**不认识 Player 类型** |
| L4 基础设施 | 输入、缓冲、事件、顿帧、设置、本地化、字体、日志 | `autoload/` | autoload 只 12 个，加第 13 个要写清理由 |

autoload 加载顺序：`DebugLog → Fonts → Settings → Loc → InputSetup → InputRebind
→ InputBuffer → GameState → GameEvents → LevelManager → SaveManager → HitStop`。
顺序是有依赖方向的：`Settings` 要在 `Loc`、`InputRebind` 之前（后者读设置），
`HitStop` 放最后（`Settings` 应用 gameplay 项时要找它，用 `get_node_or_null`）。

几个刻意的取舍：

- **暂停与慢动作分两套。** `get_tree().paused` 管整局停住，`Engine.time_scale` 管
  瞬时顿帧。混用会出现"取消暂停之后时间还是 0.1 倍"。
- **时间缩放用栈，不直接写 `Engine.time_scale`。** 并行触发的慢动作彼此独立，
  谁结束都不能把别人的效果抹掉（`hit_stop.gd::push_scale/pop_scale`）。
- **命中判定走物理查询**（`intersect_shape`，mask 4），但保留原来的偏移筛选，
  所以手感与语义不变，只是不再全场景遍历。查询本体在 `player/attack_probe.gd`
  （全 static，不认识 Player），`player.gd` 只负责喂位置/朝向/攻击距离。
  刻意没加遮挡 raycast —— 当前关卡没有可穿透薄墙，加了只会改手感。
- **空间查询与实体行为分开。** `MovementProbe`（有没有地/有没有墙/能不能抓边沿）
  与 `AttackProbe`（谁在攻击盒里/谁最近）只吃 `World2D` + 坐标，不持有节点、
  不写状态，因此可以脱离 `main.tscn` 用自造的 StaticBody2D 单测
  （`tests/test_probe.tscn`）。玩家保留的只有"读状态 → 决定转哪个 State"的部分。
- **敌人标签集中到一层画。** 敌人只实现 `label_text/label_anchor/label_alpha/label_tint`
  四个方法，`enemy_label_layer.gd` 每 0.1 秒扫一遍统一绘制，不再每个敌人挂 Label 节点。
- **敌人分三层**：`EnemyBase`（骨架：重力/受击/死亡/闪白/标签契约）→
  `MeleeChaser`（近战 AI：巡逻/追击/前摇/攻击/恢复）→ `Sweeper`/`Lancer`
  （只留数值覆盖）。Boss 不继承，因为它有阶段与技能表，差异大于共性。
- **存档原子写**：先写 `.tmp` 再 rename，不会留下写了一半的存档。
- **存档走版本链，不是版本校验。** 旧档按 `_migration_steps()` 逐级升上来并立刻
  回写；只有"来自更新版本"才硬拒。加字段不会让玩家存档作废。
- **对白分三层**：`DialogueScript`（纯函数解析/校验）→ `DialoguePlayer`（推进器，
  发 `line_changed`/`finished`，不碰 UI）→ `DialogueBox`（可复用对话框）。
  序章共用数据层但保留自己的舞台节奏，因为它是演出不是对话。
- **键盘绑定只有一处真相**：`InputRebind` 管默认值 + 重绑 + 持久化，
  `InputSetup` 只管手柄。两边都写会在重绑后出现"键盘还是老键"。

判断依据与"为什么现在不做 ECS / 行为树 / DI、对象池"的完整论证见
`docs/architecture-v1.md`；工程与内容管线侧的补齐见 `../00_前期补齐清单.md`。

## 工程基础设施

| 项 | 在哪 | 怎么用 |
| --- | --- | --- |
| 版本控制 | `无缝/.git` | 仓库根在 `无缝/`，策划/美术/构建一起纳管 |
| CI 门禁 | `.github/workflows/gate.yml` | push/PR 跑测试 + lint；手动触发额外跑导出 |
| 导出预设 | `export_presets.cfg` | Windows / Linux / Web 三平台，产物到 `build/` |
| 静态检查 | `.gdlintrc` + `tools/lint.sh` | 只挡 bug 不挑风格，见下面的说明 |
| 性能探针 | `tools/perf_probe.gd` | `godot --headless --path . -s res://tools/perf_probe.gd` |
| 会话日志 | `debug_log.gd` | `--log` 开启，`user://logs/session_*.log`，留最近 10 个 |
| 输入调试 | `debug_log.gd` | `--hook-debug` 开启，`user://hook_debug.log`，毫秒级密集记录 |

`.gdlintrc` 禁掉了 6 条规则：`class-variable-name`（项目里大量"本该是常量但要被
数据文件注入"的大写 `var`，那是设计不是错误）、`class-definitions-order`、
`max-line-length`、`max-returns`、`max-file-lines`、`duplicated-load`。
保留默认开启的 `unused-argument` / `unused-variable` / `shadowed-variable` /
`comparison-with-itself` / `expression-not-assigned` / `private-method-call`。

## 踩过的坑（已修）

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

**5. `ConfigFile.get_value()` 的默认值不接受 `null`。** 缺键时直接报
`Couldn't find the given section "input" and key "move_left", and no default was given.`，
而不是返回默认值。必须先 `has_section_key()` 判断。反过来也有坑：传了非 null 的
fallback 会**绕过默认值表**，永远返回 fallback，测试里断言默认值时千万别传第三参。

**6. 代码建 UI 必须显式给节点命名。** `Control.new()` 的 `name` 是空串，`add_child`
时自动取类名。一旦有两层同类型容器，路径就变成猜的，实测报
`Node not found: "CenterContainer/VBoxContainer"`。凡是会被 `get_node` 找到的
代码建节点，都在 `add_child` 前写 `xxx.name = "..."`。

**7. 音频总线布局不能从 `AudioBusLayout` 建。** 它没有 `set_bus_count`/`set_bus_name`，
只能反过来：先 `AudioServer.set_bus_count()` / `set_bus_name()` / `set_bus_send()`，
再 `AudioServer.generate_bus_layout()` 存成 `.tres`。

**8. `extends SceneTree` 的脚本抛错后进程空转挂死。** `_init()` 里出错时
`quit()` 不执行，CI 会卡到超时。所以逻辑全部收进 `_run() -> int`，由
`_init()` / `_initialize()` 统一 `quit(code)`。

**9. 存档存在两层版本号，混用会让迁移写错层。** `SaveManager.SAVE_VERSION`
是**文件格式**版本（payload 的顶层结构），`GameState.STATE_VERSION` 是**状态结构**
版本（`state` 里面的字段含义）。加字段只需动对应那一层；两层都动就会让
"只加了一个字段"变成"所有旧存档走一遍不必要的迁移链"。文件格式版本过新时
必须硬拒（来自更新版本的游戏，降级读会静默丢数据）；状态结构版本过新只警告
（字段缺失已有逐字段兜底）。

## 目录

```
data/
  combat/        攻击帧表 .tres
  player/        玩家数值 .tres
  rules/         同步/接管规则 .tres
  levels/        关卡几何 .json + 关卡清单 index.json
  dialogue/      对白 .json
  loc/           界面文案 strings.csv（→ 生成的 .translation）
assets/
  fonts/         字体槽位（ui/display/mono）+ 署名与授权说明
tools/
  gen_data.gd    数据文件生成器（--force 覆盖）
  test_all.sh    门禁入口（--import + 自动判型跑全部套件）
  lint.sh        gdlint + 全量编译检查（gdlint 缺失时跳过，CI 强制跑）
  export_check.sh 三平台导出并检查产物大小
  perf_probe.gd  性能基线探针（p50/p95/p99 帧时间）
scripts/
  autoload/      日志、字体、设置、本地化、输入、输入缓冲、全局状态、事件总线、
                 关卡管理、存档、顿帧
  rules/         GameLoop（规则推进+暂停）、SyncRules（数据驱动规则）
  combat/        弹反帧数据（纯函数，可单测）+ 帧表 Resource
  dialogue/      DialogueScript（数据层）、DialoguePlayer（推进器）
  player/        阿针/阿绫控制器 + PlayerStats 资源
                 + MovementProbe / AttackProbe（只读空间查询，全 static）
  enemies/       EnemyBase / MeleeChaser / Sweeper / Lancer
  boss/          裁断者
  level/         关卡解释器（读 rain_market.json）、接缝、针眼、Boss 触发器
  camera/        跟随相机
  ui/            序章、HUD、敌人标签层、暂停菜单、设置面板、存档面板、对话框
scenes/
  prologue.tscn  序章（默认启动场景）
  main.tscn      白盒雨市（挂 GameLoop / Level / LabelLayer / HUDLayer / MenuLayer）
  player/        玩家
  enemies/       敌人
  boss/          Boss
  level/         接缝/针眼/触发器
tests/           无头测试（20 套件）
```

## 白盒实现范围

- 序章：34 条对白、打字机、Esc 跳过、标题、淡入雨市。
- 移动/跳跃/冲刺/轻击/弹反/换人/缝/接管 AI/死亡重生。
- 清道夫：巡逻、追击、可弹反挥击、接缝暴露。
- 截线者：同骨架、臂长更长判定更高（跳不过去）、移速更慢。
- 裁断者：三阶段、三连剪、红招过顶剪、激光、网格、旋风剪、三连全弹硬直。
- 雨市：A-F 区白盒平台、3 个接缝、1 个针眼、3 个杂兵、Boss 触发。
- HUD：完整度、同步率、形态、消息、Boss 拆/缝选择、切片结束卡；敌人名牌单独一层。
- 关卡切换、9 槽存档（原子写）、暂停菜单、设置（音量/显示/手感）、按键重绑、
  中英双语切换、时间缩放栈。
- 音效/美术/动画尚未接入；当前是几何占位。

## 已知占位

- 无 TileMap/TileSet；平台由 `rain_market.json` 描述、`level.gd` 实例化。
- 音频总线（5 条）已建好，但**没有任何音频资源**；`AudioStreamPlayer` 还没接。
- 存档不含敌人/Boss 状态，读档回到检查点重新开打。存档面板是 3 个手工档位，
  `SaveManager` 本身支持 1–9 槽。
- 中文字体走 `SystemFont` 回退；`assets/fonts/` 里还没有真字体，发布前必须补
  OFL 字体子集并在 `CREDITS.md` 记授权。
- 英文翻译只覆盖 40 条界面文案，对白与关卡文本仍是中文单语。
- 对话框 `DialogueBox` 已可复用，但除了序章共用数据层之外，**还没有第二个使用方**
  （NPC 对话、剧情触发点都没做）。
- 手柄按键已注册但未在真机上实测。
- 真人从头到 Boss 的完整试玩尚未进行（W2 门禁）。
- 关卡清单 `index.json` 只有一关，`next_level_id()` 恒为空；换关路径已打通但没有第二份关卡数据。
- 数据文件仍是手写维护 + `gen_data.gd` 兜底，没有编辑器导出流程。
- `EnemyBase` 只覆盖近战追击型；要做远程/飞行敌人得在 `_update_ai` 之外再加一层
  （当前没有这个需求，所以没提前抽象）。
- `perf_probe.gd` 在 headless 下没有绘制数据，只有 CPU 侧帧时间；真机性能仍靠肉眼看。
