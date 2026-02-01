# Memory Mine - Detailed Game Design Proposal

# 记忆矿坑 - 详细游戏设计提案

---

## Core Concept | 核心概念

Dig downward through limited grid-based levels to collect treasures from the past, balancing risk and reward through strategic mining, resource management, and puzzle-solving.

向下挖掘穿越有限的网格关卡，收集过去的宝藏，通过策略性挖掘、资源管理和解谜平衡风险与回报。

**Theme**: "Excavating forgotten treasures from the depths of memory" - deeper layers represent older eras (90s → 80s → 70s → 60s)

**主题**: "从记忆深处挖掘遗忘的珍宝" - 越深的层级代表越久远的年代（90年代→80年代→70年代→60年代）

主角是来自未来的机器人

---

## Gameplay Mechanics | 玩法机制

## Character Movement | 角色移动

**Basic Movement**:  
**基础移动**:

- Horizontal movement (left/right) on solid blocks  
  在实心方块上横向移动（左/右）
- Free fall downward when no support beneath  
  下方无支撑时自由掉落
- **No climbing or jumping** - movement is one-way downward (strategic commitment)  
  **无攀爬或跳跃** - 移动是单向向下的（策略性承诺）

**Fall Damage**:  
**掉落伤害**:

- Falling from 3+ blocks height causes 1 HP damage  
  从3格以上高度掉落造成1点生命值伤害
- Falling from 5+ blocks height causes instant death  
  从5格以上高度掉落造成即死

**Restart Mechanic**: If player makes irreversible mistakes (trapped/wrong path), they can restart the level  
**重开机制**: 如果玩家犯了不可逆错误（被困/走错路线），可以重新开始关卡

## Block Types | 方块类型

| Block Type | Hits to Break | Yields | Special Properties |

| 方块类型                      | 挖掘次数 | 产出          | 特殊属性                                                                                     |
| ----------------------------- | -------- | ------------- | -------------------------------------------------------------------------------------------- |
| **Soft Dirt 软土**            | 1 hit    | 1 Energy      | Easy to break, common                                                                        |
|                               | 1次      | 1能量         | 易破坏，常见                                                                                 |
| **Hard Stone 硬石**           | 3 hits   | 2 Energy      | Requires planning, slows progress                                                            |
|                               | 3次      | 2能量         | 需要规划，减慢进度                                                                           |
| **Unbreakable Rock 坚固岩石** | ∞        | None          | Cannot be mined, must route around, not fall down                                            |
|                               | ∞        | 无            | 无法挖掘，必须绕路，不会掉落                                                                 |
| **Treasure Block 宝藏方块**   | 1 hit    | Treasure Item | inVisible, after scanning, become visible with sparkle effect, contains vintage collectibles |
|                               | 1次      | 宝藏物品      | 不可见，扫描后，有闪光效果可见，包含复古收藏品                                               |
| **Energy Crystal 能量晶体**   | 2 hits   | 5 Energy      | invisible，scanning and become visible Rare, valuable for scanning/bombs                     |
|                               | 2次      | 5能量         | 不可见，扫描后，可见，稀有，对扫描/炸弹很有价值                                              |

## Resource System | 资源系统

**Energy (能量)** - Primary resource obtained from mining  
**能量** - 从挖掘中获得的主要资源

**Energy Uses**:  
**能量用途**:

1. **Scanning (扫描)**:
   - Cost: 10 Energy per scan  
	 消耗：每次扫描10能量
   - Effect: Reveals contents of a 2x2 grid area (shows treasure locations, block types)  
	 效果：揭示2x2网格区域的内容（显示宝藏位置）
   - Strategic use: Plan optimal path before committing to digging  
	 策略用途：在开始挖掘前规划最优路线

2. **Bombs (炸弹)**:
   - Cost: 15 Energy per bomb  
	 消耗：每枚炸弹15能量
   - Effect: Destroys 3x3 area of blocks instantly (except unbreakable rocks)  
	 效果：瞬间摧毁3x3区域的方块（坚固岩石除外）
   - **Risk**: Can destroy treasure blocks if caught in blast radius  
	 **风险**：如果在爆炸范围内会摧毁宝藏方块
   - **Risk**: Treasures fall if support blocks beneath them are destroyed - broken treasures are worthless  
	 **风险**：如果宝藏下方的支撑方块被摧毁，宝藏会掉落 - 破损的宝藏毫无价值

Pickaxe Durability (镐耐久度):

Each level gives limited pickaxe hits (e.g., 30 hits for early levels)  
 每个关卡给予有限的镐击打次数（如早期关卡30次）

- ~~Hitting harder blocks consumes durability proportionally (soft=1, hard=3)~~  
  ~~击打更硬的方块按比例消耗耐久度（软=1，硬=3）~~
- ~~Running out of durability = mission failed~~  
  ~~耗尽耐久度 = 任务失败~~
- ~~Creates tension: scan first or dig blindly? Use bombs or conserve energy?~~  
  ~~制造紧张感：先扫描还是盲挖？使用炸弹还是保存能量？~~

## Physics System | 物理系统

**Block Falling Mechanics**:  
**方块掉落机制**:

- Blocks have a 0.5-second delay before falling when support is removed  
  方块在失去支撑后有0.5秒延迟才会掉落
- Player can move out of the way during this grace period  
  玩家可以在此缓冲期内离开
- Falling blocks deal 2 HP damage if they hit the player  
  掉落的方块砸到玩家造成2点生命值伤害
- (optional) **Treasure blocks break if they fall more than 2 blocks** - becomes "Broken Treasure" (0 value)  
  **宝藏方块掉落超过2格会破碎** - 变成"破损宝藏"（0价值）

**Strategic Implications**:  
**策略性影响**:

- Must plan digging order to avoid chain reactions  
  必须规划挖掘顺序以避免连锁反应
- Can intentionally trigger falls to clear paths quickly  
  可以故意触发掉落以快速清理路径
- Must protect treasures while mining around them  
  必须在周围挖掘时保护宝藏

---

## Core Loop | 核心循环

## Level Structure | 关卡结构

**Grid-Based Levels (网格化关卡)**:

- Fixed grid size: 12 columns × 20 rows (finite, puzzle-like)  
  固定网格大小：12列 × 20行（有限的，解谜性质）
- Each level is hand-designed with specific challenges  
  每个关卡都是手工设计的特定挑战
- Level objectives: "Collect 3 treasures and reach the bottom" or "Collect treasure worth 500 coins"  
  关卡目标："收集1/3个宝藏并到达底部"或"收集价值500金币的宝藏"

## Gameplay Flow | 游戏流程

1. **Observation Phase (观察阶段)**:
   - Enter level with limited information
	 进入关卡，信息有限

1. **Resource Gathering (资源收集)**:
   - Mine soft dirt and energy crystals to build energy reserves  
	 挖掘软土和能量晶体以积累能量储备
   - Balance between progressing toward treasures vs. gathering resources  
	 在朝宝藏前进与收集资源之间平衡

1. **Strategic Decisions (策略决策)**:
   - Use energy for scanning (reveal safe paths) or bombs (fast clearing but risky)  
	 用能量扫描（揭示安全路径）还是炸弹（快速清理但有风险）
   - Plan digging path to avoid falls, traps, and dead ends  
	 规划挖掘路径以避免掉落、陷阱和死路

1. **Treasure Collection (宝藏收集)**:
   - Carefully extract treasures without letting them fall  
	 小心提取宝藏，不让它们掉落
   - Reach level exit with treasures intact  
	 带着完好的宝藏到达关卡出口

1. **Completion & Progression (完成与进程)**:
   - Treasures added to collection catalog  
	 宝藏添加到收藏图鉴
   - Earn coins to upgrade pickaxe durability, max HP, starting energy  
	 赚取金币以升级镐耐久度、最大生命值、初始能量
   - Unlock deeper levels (older eras)  
	 解锁更深的关卡（更古老的年代）

---

## Treasure System | 宝藏系统

## Visibility & Discovery | 可见性与发现

**Default State**:  
**默认状态**:

- Treasure blocks invisible but after scanning, they have subtle sparkle/glow effect (player knows "treasure is here")  
  宝藏block是不可见的，扫描后宝藏方块有微妙的闪光/发光效果（玩家知道"这里有宝藏"）
- ~~Exact item type is hidden until mined~~  
  ~~确切的物品类型在挖掘前是隐藏的~~

**Scanning Mechanic**:  
**扫描机制**:

- Spend 10 Energy to scan any 2x2 grid area  
  花费10能量扫描任意2x2网格区域
- Reveals: treasure identities, hidden energy crystals  
  揭示：宝藏身份、隐藏的能量晶体
- Allows informed decision-making about which treasures to prioritize  
  允许就优先收集哪些宝藏做出明智决策

## Treasure Categories | 宝藏类别

**By Era (按年代)**:

- 1990s: Game consoles, CDs, pagers, floppy disks  
  1990年代：游戏机、CD、传呼机、软盘
- 1980s: Walkmans, cassette tapes, arcade cabinets, boom boxes  
  1980年代：随身听、磁带、街机柜、手提音响
- 1970s: Vinyl records, rotary phones, film cameras, 8-tracks  
  1970年代：黑胶唱片、拨号电话、胶片相机、8轨磁带
- 1960s: Transistor radios, vintage toys, analog devices  
  1960年代：晶体管收音机、复古玩具、模拟设备

**By Rarity (按稀有度)**:

| Rarity | Value | Appearance Rate |

| 稀有度         | 价值           | 出现率 |
| -------------- | -------------- | ------ |
| Common 普通    | 50-100 coins   | 60%    |
| Uncommon 罕见  | 150-250 coins  | 25%    |
| Rare 稀有      | 300-500 coins  | 12%    |
| Legendary 传说 | 800-1500 coins | 3%     |

**Collection System (收集系统)**:

- Gallery/catalog UI showing all discovered treasures  
  画廊/图鉴UI显示所有发现的宝藏
- Each treasure has flavor text describing its historical context  
  每个宝藏都有描述其历史背景的风味文本
- Completion bonuses for collecting full sets (e.g., "Complete 1980s Collection")  
  收集全套的完成奖励（如"完成1980年代收藏"）

---

## Progression & Upgrades | 进程与升级

## ~~Upgrade Shop | 升级商店~~

~~**Pickaxe Upgrades (镐升级)**:~~

- ~~Level 1: 30 durability → Level 5: 60 durability~~  
  ~~等级1：30耐久 → 等级5：60耐久~~
- ~~Cost: 200 / 400 / 700 / 1200 coins~~  
  ~~花费：200 / 400 / 700 / 1200金币~~

~~**Health Upgrades (生命值升级)**:~~

- ~~Level 1: 3 HP → Level 5: 7 HP~~  
  ~~等级1：3点生命 → 等级5：7点生命~~
- ~~Cost: 250 / 500 / 900 / 1500 coins~~  
  ~~花费：250 / 500 / 900 / 1500金币~~

~~**Energy Capacity (能量容量)**:~~

- ~~Level 1: 50 max energy → Level 4: 80 max energy~~  
  ~~等级1：50最大能量 → 等级4：80最大能量~~
- ~~Cost: 300 / 600 / 1000 coins~~  
  ~~花费：300 / 600 / 1000金币~~

**Starting Energy (初始能量)**:

- Level 1: Start with 0
  等级1：开始时0能量
- ~~Cost: 400 / 800 coins~~  
  ~~花费：400 / 800金币~~

---

## UI & Interface | 界面与交互

## In-Game HUD | 游戏内HUD

(see the generated image above)

**Top Bar**:  
**顶部栏**:

- Level name and era (e.g., "Level 3: 1980s Memories")  
  关卡名称和年代（如"第3关：1980年代的记忆"）
- Mission objective (e.g., "Collect 3 Treasures")  
  任务目标（如"收集3个宝藏"）

**Left Panel**:  
**左侧面板**:

- HP hearts display (current/max)  
  生命值心形显示（当前/最大）
- Pickaxe durability bar with hit count  
  镐耐久度条带击打计数
- Current energy counter  
  当前能量计数器

**Right Panel**:  
**右侧面板**:

- Minimap showing explored areas  
  小地图显示已探索区域
- Treasure counter (collected/total)  
  宝藏计数器（已收集/总数）

**Bottom Bar**:  
**底部栏**:

- Scan button (shows cost: 10 Energy)  
  扫描按钮（显示消耗：10能量）
- Bomb button (shows cost: 15 Energy)  
  炸弹按钮（显示消耗：15能量）
- Restart level button  
  重新开始关卡按钮

## Main Menu | 主菜单

(see the generated image above)

- **New Game**: Start new playthrough  
  **新游戏**：开始新的游戏流程
- **Continue**: Resume from last checkpoint  
  **继续**：从上次检查点继续
- **Collection**: View treasure catalog/gallery  
  **收藏**：查看宝藏图鉴/画廊
- **Upgrades**: Access shop for equipment upgrades  
  **升级**：访问商店进行装备升级
- **Settings**: Audio, controls, display options  
  **设置**：音频、控制、显示选项

## ~~Upgrade Shop Screen | 升级商店界面~~

~~(see the generated image above)~~

- ~~Three upgrade categories displayed side-by-side~~  
  ~~三个升级类别并排显示~~
- ~~Current stats, upgrade cost, and next level preview~~  
  ~~当前属性、升级花费和下一级预览~~
- ~~Coin balance prominently displayed~~  
  ~~金币余额突出显示~~
- ~~NPC shopkeeper character for atmosphere~~  
  ~~NPC商店老板角色增加氛围~~

---

## Technical Implementation | 技术实现

## Minimum Viable Product (MVP) | 最小可行产品

**Day 1 - Core Mechanics (核心机制)**:

- Grid-based movement and digging  
  基于网格的移动和挖掘
- 3 block types: soft dirt, hard stone, treasure  
  3种方块类型：软土、硬石、宝藏
- Basic physics: block falling with 0.5s delay  
  基础物理：方块以0.5秒延迟掉落
- Pickaxe durability system  
  镐耐久度系统
- Energy collection from mining  
  从挖掘中收集能量

**Day 2 - Systems & Content (系统与内容)**:

- Scanning mechanic (2x2 area reveal)  
  扫描机制（2x2区域揭示）
- Bomb mechanic (3x3 destruction)  
  炸弹机制（3x3摧毁）
- 5-8 treasure types with rarity tiers  
  5-8种宝藏类型带稀有度等级
- Upgrade shop with 3 upgrade paths  
  升级商店带3条升级路径
- 3-5 playable levels  
  3-5个可玩关卡

**Day 3 - Polish & Content (打磨与内容)**:

- Collection catalog UI  
  收藏图鉴UI
- Particle effects (sparkles, dust, explosions)  
  粒子效果（闪光、尘土、爆炸）
- Sound effects and background music  
  音效和背景音乐
- Tutorial level with on-screen hints  
  带屏幕提示的教程关卡
- Juice and visual feedback polish  
  爽快感和视觉反馈打磨

## Recommended Tech Stack | 推荐技术栈

- **Engine**: Unity 2D or Godot (grid system support)  
  **引擎**：Unity 2D或Godot（网格系统支持）
- **Art**: Pixel art (16-bit or 32-bit style for nostalgia)  
  **美术**：像素艺术（16位或32位风格以怀旧）
- **Audio**: Chiptune-style music, retro sound effects  
  **音频**：芯片音乐风格，复古音效

---

## Risk Mitigation | 风险缓解

**Scope Control for Hackathon (Hackathon范围控制)**:

**Can be simplified if time-constrained**:  
**如果时间紧张可以简化**:

- Remove scanning mechanic → treasures fully visible from start  
  移除扫描机制 → 宝藏从一开始完全可见
- Remove bombs → focus purely on pickaxe mining  
  移除炸弹 → 纯粹专注于镐挖掘
- Reduce upgrade paths from 4 to 2 (pickaxe + health only)  
  将升级路径从4条减少到2条（仅镐+生命值）
- Hand-design 3 levels instead of 5  
  手工设计3个关卡而不是5个

**Must-keep core features**:  
**必须保留的核心功能**:

- Grid movement + digging  
  网格移动+挖掘
- Block falling physics  
  方块掉落物理
- Treasure collection + catalog  
  宝藏收集+图鉴
- At least 1 upgrade system  
  至少1个升级系统

---

## Why This Design Works | 为什么这个设计有效

**Theme Alignment (主题契合)**:

- "The Past" theme is embedded in every treasure (vintage items)  
  "过去"主题嵌入每个宝藏中（复古物品）
- Depth = time metaphor is intuitive and emotionally resonant  
  深度=时间的隐喻直观且情感共鸣

**Gameplay Depth (玩法深度)**:

- Resource management (energy for scan vs. bomb)  
  资源管理（能量用于扫描还是炸弹）
- Risk/reward decisions (use bomb near treasure?)  
  风险/回报决策（在宝藏附近使用炸弹？）
- Spatial puzzle-solving (optimal digging paths)  
  空间解谜（最优挖掘路径）

**Hackathon-Friendly (适合Hackathon)**:

- Core loop can be prototyped in 4-6 hours  
  核心循环可以在4-6小时内原型化
- Systems are modular and can be added incrementally  
  系统是模块化的，可以逐步添加
- Pixel art reduces art asset workload  
  像素艺术减少美术资产工作量

**Replayability (重玩性)**:

- Collection system encourages replaying for 100% completion  
  收集系统鼓励重玩以达到100%完成度
- Each level can have optimal solutions (speedrun potential)  
  每个关卡可以有最优解（速通潜力）
- Upgrades allow progressive mastery  
  升级允许渐进式精通

---

祝你Hackathon顺利！🎮⛏️✨

能力构建

这个设计思路很好！让我先整理一下你的想法，然后帮你细化到12个具体的treasure。

现有的12个Treasure图标
根据 treasure_data.gd 中的sprite列表：

图标 年代 意象
arcade_80s 80s 街机
boombox_80s 80s 收音机/音响
camera_60s 60s 相机
cd_90s 90s CD光盘
floppy_90s 90s 软盘
gameboy_90s 90s 游戏机
pager_90s 90s 寻呼机
radio_60s 60s 收音机
robot_70s 70s 机器人
rotary_phone_80s 80s 旋转电话
tubes_60s 60s 电子管
vinyl_80s 80s 黑胶唱片
能力分类与Treasure匹配建议
一、挖掘增强类
Treasure 能力 理由
robot_70s 镐子强化：每次挖掘等于2次 机器人=力量增强
arcade_80s 可挖掘不可破坏石块 街机=突破限制
二、能量类
Treasure 能力 理由
floppy_90s 能量上限+30（最高100） 软盘=存储容量
cd_90s 能量自动恢复（1点/秒，上限5点） CD=持续播放
三、血量类
Treasure 能力 理由
tubes_60s 血量上限+2 电子管=生命力
radio_60s 血量自动恢复（1点/5秒） 收音机=持续信号
四、能量-血量转换
Treasure 能力 理由
rotary_phone_80s 能量↔血量模式切换（1血=15能量） 电话=交换/通讯
五、伤害免疫类
Treasure 能力 理由
gameboy_90s 免疫掉落伤害 游戏机=轻便
vinyl_80s 免疫岩石坠落伤害 黑胶=耐压
boombox_80s 免疫爆炸伤害 音响=抗震
六、技能增强类
Treasure 能力 理由
pager_90s 扫描范围扩大到5×5 寻呼机=信号探测
camera_60s 揭示所有隐藏Treasure位置 相机=全景拍摄
需要确认的问题
能力叠加：如果一局获得多个treasure，能力是否叠加？比如获得两个血量+2的treasure，是否变成+4？
不是只能获取一个，不能相同获取吗，所以treasure单局应该唯一。

rotary_phone转换模式：这个比较复杂，是否需要一个按键来切换模式？还是获得后自动激活？
获取后自动激活为这个模式

camera揭示所有：这个效果很强，是否应该设为最稀有(LEGENDARY)？
可以，但是目前稀有度好像没什么体现

能力持久性：这些能力是当前关卡有效，还是整个游戏流程有效？
当前关卡有效

数值平衡：

能量恢复1点/秒是否太快？
血量恢复1点/5秒是否合适？
1血=15能量的转换比例是否平衡？
数值平衡先不用管，反正这个treasure是随机给的，当前局出现了就让他爽一把就完事。
