# Session Notes · Roblox Rocket-Launch Game (Project D1)

Sessions on 19–23 November 2026. This file collects everything discussed, in order, with the decisions that came out of each step. The full, current game design lives in `火箭发射游戏设计方案.md`.

## 1. Context

- Independent Roblox developer. Projects mentioned: a "+1" incremental game, and the rocket-launch game this folder is about.
- Rocket game concept: world layout inspired by *Mine a Planet*, core loop inspired by *Steel Fighters* (roll parts → assemble → the flight replaces combat → earn → upgrade → fly again).

## 2. General advice covered

**Indie development on Roblox**
- Ship a small playable loop early and iterate on live data; day-1 and day-7 retention matter most for discovery.
- Nail the first five minutes: a satisfying upgrade within ~30 seconds and a visible next goal at all times.
- Treat icon, thumbnail and title as part of the game (click-through rate drives discovery).
- Technical foundation: server-authoritative logic, robust saving (DataStore with session locking such as ProfileService), big-number handling, mobile-first UI.
- Monetization designed into the game: boosts, convenience (auto features), cosmetics; keep the free experience fun.
- Plan for live-ops (regular updates, events, codes); use the DevForum, Discords and YouTubers in the genre; check current payout and DevEx terms on the Creator Hub.

**Discord server for the game**
- Start with 8–12 channels: welcome/rules, announcements, update log, general, showcase, codes, suggestions (with vote reactions), bug reports (pinned template), help; 1–2 voice channels; private mod and dev channels.
- Use roles and permissions, verification (Roblox account linking), AutoMod and short rules; post regularly yourself.

**Preparing to build a Roblox game from scratch**
- Accounts and tools (Roblox account with 2-step verification, Roblox Studio, Creator Hub).
- Learn Luau and the client-server model; define the concept and study 3–5 games in the genre; scope aggressively.
- Plan systems, folder structure and version control; set up saving, server authority, mobile UI and analytics early.
- Check Creator Store assets for malicious scripts; read Community Standards and monetization rules; prepare icon/thumbnail/description and a post-launch plan.

**Trending Roblox games (snapshot, November 2026)**
- Top by live players (Nov 18): Steal An Egg, Brookhaven RP, Adopt Me!, Throw Food For Animals, Murder Mystery 2, Hyper Realistic Ragdoll.
- Fastest-growing new games (early Nov): DONT SPLASH, Break and Steal an Egg, Cat Battles, Turbo Soccer, RoWorld, Sell Fries!, Backseat Rally, Fake an Egg, Kukirin Life, Bike Universe.
- Trends: "+1" incremental games launching in a cluster with very high like ratios; steal-and-collect loops; ragdoll physics; one-line hooks.
- Sources: [GGRecon · 30 of Roblox's 99 top games didn't exist before October](https://www.ggrecon.com/articles/roblox-top-games-didnt-exist-before-october/), [GGRecon · The 10 fastest-growing new Roblox games (November 2026)](https://www.ggrecon.com/articles/fastest-growing-new-roblox-games-november-2026/)

## 3. Design feedback on the rocket concept

- Keep "preview → verify": the preview must be deterministic and the flight must deliver it. Compute results on the server; play the flight back visually rather than with physics.
- Give each part type a distinct job and real trade-offs, keep early flights short, define the orbit-bonus rule precisely, plan coin sinks, make the maiden flight the showpiece, use planets as the progression axis, keep the demo small.
- Upgrading the roll system: tier unlocks, luck, extra slots, speed/batching, pity, part locking; keep roll upgrades, rolls and frame upgrades doing different jobs.

**Why the first demo felt flat, and the fixes (all implemented)**

| Problem | Fix |
|---|---|
| No uncertainty in the flight | Preview is the guaranteed floor; timing skill adds the ceiling |
| Nothing to do during the flight | Ignition timing, BOOST at each gate, star shards, landing catch |
| Small, linear rewards | Combo per lap, multiplicative bonuses shown on screen |
| Upgrades change one number | Four part slots with mass and stats; visible changes on the rocket |
| Payoff happens off-screen | Coin pops per lap, counting tally, coins flying into the counter |

## 4. Build history

| Version | What changed |
|---|---|
| 2D web prototype | Roblox-style side view: roll (with reveal and comparison), 3 slots × 3 tiers, assemble, ignition timing, gate BOOST, catch landing, tally; Moon and Jupiter |
| 3D v1 | Three.js world: hex home plot per the design doc, plaza and five NPC neighbour plots, blocky avatar (WalkSpeed 16, JumpPower 50, gravity 196.2), proximity prompts, player list, mobile thumbstick and jump, tutorial arrow |
| 3D v2 | Glass assembly bay with staged part drops, sparks and clang; fourth slot (fins); Δv performance model; Jupiter reached only by the right combination |
| 3D v3 | Ignition camera moved off the assembly-bay side; low angle; push-in while holding; avatar hidden if it blocks the shot |
| 3D v4 | Perfect landing rework: catch zone column on the pad, slow motion, catch arms that open and snap shut, shockwave, hit stop |
| 3D v5 | Best-build testing shortcut; Jupiter payout raised from 35 to 60 so the best Jupiter build out-earns the Golden-Nose Moon build |
| 3D v6 | Jupiter unlock cinematic (shield shatters, rings appear, unlock card); star shards with gate supercharge; tips; global effects (speed lines, vignette, flashes, glows, ring pulses, meteors, light pillars, flying coins) |
| 3D v7 | Jupiter chase camera; Jupiter rings moved inside the orbit |
| Web package | Standalone `index.html` (3D) and `prototype-2d.html`, README with hosting steps, zipped |
| 3D v8 | Stage-1 features: Super Launch (overcharged ignition, ragdoll shockwave), Orbit Fever, Consecutive Catches, Spectacular Crash with repair drone; three visitor NPCs; new tips |
| 3D v9 | New home layout (spawn in the centre facing the pad, assembly bay on the right, frame board beside the catch arms, tower behind the pad); the Part Roller is replaced by a Roll button and one part pad per slot: one roll = 4 parts for 50 coins, per-pad pity (10 rolls, a random 1–2 due pads guaranteed Elite per roll), 4-card result panel with a preselected best loadout |
| 3D v10 | Backpack and staging: free Roll with a 10 s cooldown; each pad shows one part with a price (Basic unlimited, never sold); bought parts stack in the backpack by count; parts are staged from the backpack into the bay's four slots (✕ returns a part) and only Assemble builds the rocket; the rocket on the pad stays flyable until a new one is assembled; star bonus removed; backpack button in the HUD; save key bumped to v3 |
| 3D v11 | Roll button cooldown removed (input only locked during the ~1.2 s reveal); part-pad labels now show name, rarity and price above each part. Art: C2 mechanical assembly bay and C1 part pads (no display cage, BillboardGui cards) finalised on the design canvas |

| Roblox 任务一（11-24） | 在 Studio Place3 里用 MCP 生成整体场景氛围与布局（白盒 + 氛围），脚本存于 `studio/world/01_atmosphere.lua`、`02_islands.lua`、`03_planets.lua`，均可重复运行。详见下方「Roblox 场景 · 任务一」 |

**Best build:** Aero Nose + Mega Tank + Plasma Engine + Swept Fins → Δv 1,107, Moon ×1 → Jupiter ×2, about 286 orbit coins before bonuses. 8 of the 81 builds reach Jupiter.

## 5. Files in this folder

| Path | What it is |
|---|---|
| `docs/火箭发射游戏设计方案.md` | Current design document (updated 23 Nov) |
| `docs/archive/火箭发射游戏设计方案_v1_2026-11-19.md` | The original design document, for reference |
| `docs/SESSION_NOTES.md` | This file |
| `web-build/index.html` | 3D game, runs in a browser (needs internet on first load for three.js and fonts) |
| `web-build/prototype-2d.html` | 2D prototype |
| `web-build/README.md` | How to run locally, host online, controls and testing tools |
| `orbit-roll-web.zip` | The web build zipped, ready to upload |

Online copies (private to your claude.ai account until shared): [Orbit Roll 3D](https://claude.ai/artifact/WyERH5gsU9Xb8hGEzh62BM) · [Orbit Roll 2D](https://claude.ai/artifact/Jgy8tYro7NfkLV3XZX1cSR)

## 6. Two-stage plan (decided 23 Nov)

High-impact features were brainstormed and split into two stages. Full specs are in the design document.

| Stage | Features |
|---|---|
| Stage 1 · Demo validation | Super Launch (M), Orbit Fever (S–M), Consecutive Catches (S), Spectacular Crash (M) · **implemented in 3D v8** |
| Stage 2 · Full production | Engine Test-Fire (S), Jackpot Comet (M), Slingshot Finale (M), Firework ×10 Roll (M), Forge Fusion (M–L), Server-Wide Moments (Fleet Launch, Jupiter Storm, Planet Flag) |
| Not yet scheduled | Booster Separation, Supernova Rebirth, Overburn, Moon chase camera, more planets |

Stage 2 also covers the Roblox port: server-authoritative rolls, Δv and payouts; deterministic flight playback; DataStore with session locking; real six-player servers; odds disclosure for paid rolls; mobile-first testing.

## 7. Roblox 场景 · 任务一（2026-11-24，待用户验收）

在 Roblox Studio 已打开的 Place3（未保存到云端）中，通过 Roblox Studio MCP 直接生成。所有对象在 `Workspace.OrbitWorld` 下（`Islands`、`Planets`），天空素材在 `ServerStorage.WorldAssets`，原默认 Baseplate 已移到 ServerStorage（未删除）。

**布局参数**（广场中心为世界原点，顶面 y = 0）

| 项目 | 值 | 说明 |
|---|---|---|
| 广场 | 六边形外接半径 46，淡紫灰凸点地面，金色边 | 中央 Ø18 圆台（日后放火箭雕塑 / 活动），六个角各一座光柱底座 + Beam 光柱（青 / 紫 / 粉） |
| 家园 | 六边形外接半径 42，中心距广场 **94**（Web Demo 为 110） | 家园 k 在角度 k·60°，玩家自家（绿）为 k = 0，中心 (0, 0, 94)，本地 −Z 朝广场，与设计方案的家园坐标表一致 |
| 连桥 | 长 ≈ 17.8，总宽 22（护栏内净宽 ≈ 20.2），广场端护栏外撇 32° | 满足「净宽略大于通道长度、靠广场一端稍微放宽」；Web Demo 的 14 宽 × 33.8 长不满足这条，所以缩短了中心距 |
| 相邻家园间距 | 平边相对，空隙 ≈ 21.3 | 开敞星空 |
| 地台结构 | 凸点顶面 → 家园色边（SmoothPlastic）→ 霓虹细线 → 侧壁 → 五层错角阶梯岩体（Slate）+ 碎石 + 发光晶体 | 每家背面平边中点有一根家园色光柱，从广场能分辨各家 |
| 出生点 | 玩家家园本地 (0, −5)，朝 −Z | SpawnLocation 已设为透明薄片 |
| 月球 | 中心 (−50, 190, −60)，r 28，环形坑朝玩家家园，虚线轨道 + 一个金色轨道门预览 | 位置沿用 Web Demo（相对广场） |
| 木星 | 中心 (170, 400, −220)，r 72，条带 + 大红斑，整体压暗 22%，ForceField 紫色护盾 + 「🔒 木星 · 已锁定 / 需要 Δv 900 的组合」标签 | |

**氛围**：Bloom 0.7 / 28 / 1.6，ColorCorrection 饱和 +0.12、对比 +0.08；紫色星云天空盒（Creator Store「Purple Nebula Space Skybox」，作者 Zalthen，纯 Sky 实例，无脚本；备选 `SpaceSky_Alt`）；家园上空漂浮光点粒子。

**与美术方向的偏差（需确认）**
- **ClockTime 改为 14.5，而不是 0。** Roblox 在夜间会隐藏自定义天空盒（实测 ClockTime 0 时天空全黑），所以用白天时段 + 隐藏太阳 + 紫色环境色偏来做「深紫星空」。
- **不加 Atmosphere。** 白天时段的大气会把星云天空冲成灰雾。
- **Lighting.Technology**：当前 Studio 已经移除这个属性，改为 `LightingStyle`（Realistic / Soft）+ `PrioritizeLightingQuality`。本场景保持 LightingStyle = Soft（阴影柔和，适合玩具风）并勾选 PrioritizeLightingQuality，相当于原来的 Future 质量。
- 家园与广场中心距从 110 改为 94（见上表），**用户 11-24 已确认**，ClockTime 方案也已确认。待同步设计方案「3D Demo 的实现」一段和 Web Demo。

**第二轮调整（截图验收后）**
- 地面改为更浅的淡紫灰（家园 #DEDBF0、广场 #C9C5E6），环境光改为偏灰的淡紫（OutdoorAmbient #8E88B4、ColorShift_Top #E4DCFF），之前整片地面被染成饱和紫。
- 凸点贴图透明度 0.72（更实会读成棋盘格）。
- 广场光柱压到 50 高：原 170 高时，从家园抬头看会直戳月球。家园色光柱柔光收窄。
- 木星「已锁定」标签挪到星球下方，原来在上方会压住星球。

**状态**：用户已把场景保存到 Roblox（现名 Place4，Team Create，版本 3）。Lighting.Technology 由用户手动设置。截图在 Studio 窗口切到前台后恢复正常。

**第三轮调整（用户反馈自发光太多、晃眼）**
- 护栏端头、岩体晶体不再用 Neon。地台边下方的霓虹细线一度改为不发光，用户随后要求保留，已恢复 Neon。
- 光柱：Beam LightEmission 1 → 0.5，主光亮度 3 → 1.2，起始透明度 0.15 → 0.45；外层柔光亮度 0.6、透明度 0.88 起。
- 光柱底座灯环与广场中央圆台光环：Neon 加 0.45 透明度，PointLight 亮度降到 0.7。
- Bloom 参数（0.7 / 28 / 1.6）未改。现在 Neon 只留在：地台边下方细线、光柱灯环、圆台光环、月球光晕、轨道虚线与轨道门、木星护盾外光。

## 8. Roblox 场景 · 任务二：玩家家园（2026-11-24，待用户验收）

按家园布局图（B1）和原画 C1 / C2 / D1 在玩家自家（Home 0，中心 (0, 0, 94)）生成全部设施，对象在 `Workspace.OrbitWorld.Homes.Home_0`。家园本地坐标 = 设计方案「家园设施坐标」表，−Z 朝广场。

**脚本**（`studio/world/`，均可重复运行，按家园编号 K 生成，改 K 即可给邻居建）
- `lib/BuildLib.lua`：建造工具 + D1 火箭部件造型（三档鼻锥 / 燃料舱 / 发动机 / 尾翼、整箭、全息化），安装在 `ServerStorage.WorldAssets.BuildLib`。
- `04_home_launch.lua`：发射台 Ø17 × 1.5（A3）、橙色互动虚线、L1 回收支架（6.5 高）、25 高塔架 + 红色信标 + 服务臂、面向出生点的支架升级牌、台上首航基础火箭。
- `05_home_bay.lua`：C2 玻璃组装舱（前角无立柱、黄框滑动舱门、龙门吊 + 四指抓爪、两台焊接臂、转台 + 液压支柱、4 个部件坞带青色空位虚线、信息屏、管线、舱外控制台、青色状态灯）+ 运输带（黄色箭头指向发射台）。
- `06_home_roll.lua`：Roll 按钮（橙色街机按钮 + 金属护圈 + 铭牌 ROLL · FREE）、概率公示牌、Roll 部件区地面、4 座 C1 部件台 + BillboardGui 价格卡。
- `07_home_misc.lua`：出生点青色圆环 + 朝发射台箭头、3 个「即将开放」店位小屋。

**预览状态**：部件台按 C1 原画摆成 鼻锥 高级·气动 40 / 燃料舱 SOLD / 发动机 精英·等离子 220（金色光柱）/ 尾翼 基础，用来一次验收所有卡片样式；正式游戏由 Roll 系统在运行时改写，悬浮部件的自转也放到运行时脚本。

**实现中的调整**
- 全息从 ForceField 改为半透明 Neon（0.72）；组装舱玻璃从 Glass 材质改为半透明 SmoothPlastic + 反光 0.12。原因：Glass / ForceField 背后的半透明物体（全息、信息屏文字）在 Roblox 里不渲染。
- 运输带从组装舱底座边缘开始（底座 18 × 18 会盖住 (18.4, −5) 起点）。
- 六家的家园色光柱从背面正中挪到右后角 (18, apo − 6)：原位置从出生点看正好在燃料舱台后面，像是部件台在发光柱。
- 塔架信标点光源范围 12 → 6，避免把白色塔身染红。

**规模**：Home 0 共 589 个零件、4 盏点光源（每家预算 ≤ 8）。

**待确认**：部件台按坐标表 x = −6.3 / −0.1 / 6.1 / 12.3 摆放，但玩家从出生点转身走向 Roll 区时面朝 +Z，看到的顺序是 尾翼 → 发动机 → 燃料舱 → 鼻锥（从左到右）。如果希望玩家视角从左到右是 鼻锥 → 尾翼，需要把 x 顺序反过来，并同步设计方案和 Web Demo。

**第二轮（用户反馈，11-24）**
- 部件台反向排列：x = 12.3 / 6.1 / −0.1 / −6.3（鼻锥、燃料舱、发动机、尾翼），玩家视角从左到右读到 鼻锥 → 尾翼。已同步设计方案坐标表、交接文档和 Web Demo（`web-build/index.html` 的 PEDS；`orbit-roll-web.zip` 尚未重新打包）。
- 组装舱三面玻璃：只有舱门对面的 +X 墙是机械墙（部件坞 + 管线），+Z 面改为玻璃；「待组装」信息屏挪到舱门上方的石墨门楣上、朝舱外。门楣不用玻璃，因为挂在半透明玻璃前的屏幕文字会被渲染排序吃掉。已同步设计方案 C2 描述。原画 C2、布局图 B1 仍是旧版。

## 9. 火箭部件 v2（2026-11-24，待用户验收）

用户给了新的部件原画（厚实玩具风：倒角端盖、发光条、卡箍、圆锥鼻锥），要求参考 D1 和这张原画优化部件，鼻锥不要叠层，做成圆锥。

**验收台**：`Workspace.OrbitWorld._PartsReview`，玩家家园背后的星空里（世界 z ≈ 142–188），脚本 `studio/world/08_parts_review.lua`。左边 4 行 × 3 档单个部件（前排到后排：鼻锥、发动机、尾翼、燃料舱），右边 5 枚整箭（首航全基础、高级全套、金币路线、最优木星、精英全套，标注 Δv 和航线），右侧有 5 studs 角色比例参照。验收后整块删除。

**新几何**（模板在 `ReplicatedStorage.RocketAssets`）
- `ConeTemplate`：MeshPart，Roblox 经典圆锥网格 1033714。实测侧面 r(t) = R·(1 − 0.925 t)，尖顶截平；叠加的小圆锥斜率不能比主锥陡（h ≥ 1.85·R），否则会缩进主锥面。
- `DomeTemplate`：UnionOperation 上半球（实体求差，存档可保存）。
- 截头锥用 MeshPart 做实体运算得到的是内存网格，存档可能丢失，不用；喷管钟罩改为把圆锥尖藏进外壳。

**部件 v2**（`lib/BuildLib.lua`，D1 尺寸体系不变）
- 鼻锥：基础 = 白色子弹头（圆锥 + 半椭球肩部）+ 舷窗 + 石墨尖；气动 = 白锥 + 蓝色锥尖 + 蓝底环 + 两片蓝色导流小翼 + 尖针；黄金 = 金色子弹头 + 发光底环 + 6 道竖棱 + 金框舷窗 + 白色顶灯。
- 燃料舱：上下石墨倒角端盖；高级加两道蓝环带、两条蓝色发光竖条、水滴徽标；精英加三道金环带、四根石墨卡箍（带金色发光槽和卡脚）。
- 发动机：光滑锥形喷管 + 尾焰色发光唇口（橙 / 蓝 / 紫）+ 石墨阶梯外壳；涡轮加蓝色发光环和散热口；等离子加紫色发光环和四块金色装甲片。
- 尾翼：加厚并带石墨翼根；后掠翼加白色内侧条；栅格翼为石墨框 + 金色格栅。
- 保留色板规则（基础银 / 高级蓝 / 精英金，机身白 + 石墨）：原画里基础尾翼是红色、高级燃料舱整体蓝色，这两处按色板规则改为银色尾翼、白机身蓝环带。

**未同步**：家园里台上的火箭、组装舱全息、部件台上的悬浮部件仍是 v1 造型。验收通过后重跑 04 / 05 / 06 即可换成 v2。

**第三档科技装饰与特效（用户要求，11-24）**：参考用户给的截图（太阳能板、发光球、全息环），第三档及以后更高档次的部件加科技感装饰和特效。
- 特效工具 `B.fx`（`lib/BuildLib.lua`）：`haloRing` 全息虚线环（旋转）、`orb` 脉动发光球、`sparkles` 细小闪光粒子、`solarWing` 太阳能翼板。以后更高档次（例如阶段二锻造融合的神话件）复用这些工具并加量。
- 黄金鼻锥：倾斜的金色全息环 + 顶灯金色闪光。巨型燃料舱：左右太阳能翼板（翼尖紫色脉动光球）+ 反向旋转的青色全息环。等离子发动机：两道紫色能量线圈 + 两侧小推进舱 + 喷口紫色能量粒子。栅格尾翼：格栅外角脉动光球。
- 动画：客户端脚本 `StarterPlayer.StarterPlayerScripts.RocketFX`（源文件 `studio/client/RocketFX.client.lua`），按标签 SpinFX（模型绕自身轴旋转）/ PulseFX（透明度呼吸）驱动，离镜头 400 studs 外跳过。编辑模式下静止，Play 测试时可见；粒子编辑模式就能看到。
- 带翼板的燃料舱单侧伸出约 5.8 studs（整箭翼展约 11.6），验收台整箭间距改为 12。家园里发射台、组装舱的空间放得下，部件台上的悬浮燃料舱需要缩小显示。

**太阳能翼板 → 能量电池舱（用户反馈翼板难看，11-24）**：巨型燃料舱两侧改为竖直的能量电池舱 `B.fx.powerCell`，组成如下：
- 舱体：石墨端盖、深色舱壳、三道青色发光能量环、外侧白色装甲肋。
- 固定结构：金色锁紧环、石墨卡箍支臂加金色铆钉、正面斜向液压撑杆。
- 两端：顶部发射极（小圆顶、天线、青色脉动光球），底部微型喷口带青色发光唇口。

单侧只伸出机身约 1.8 studs（翼板约 5.8）。燃料舱的青色全息环半径 2.95 → 4.3，包住两个电池舱。`solarWing` 已删除。Studio 现在连接的是已发布的场景「D1-火箭发射」（placeId 104365800097917）。

**太阳能翼板 v2（用户要求保留为另一种高级装饰，强化科技感和金属质感，11-24）**：`B.fx.solarWing` 重做，结构从内到外：
- 肩部舱座：石墨，带金色铆钉和青色状态灯缝。
- 旋转关节：金属盘 + 金环。
- 金属桁架臂：双导轨 + 斜撑，Metal 材质。
- 铰链块 + 销轴。
- 两段折叠翼板：银色金属框、3×2 块反光电池片（Glass 材质，不透明）、青色顶边灯条，前倾 18°。
- 翼尖：端盖 + 青色导航灯。

单侧伸出约 6.2 studs。燃料舱新增参数 `deco`（`"cell"` 默认电池舱 / `"solar"` 翼板），整箭用 `eq.deco` 传入。验收台后排有「巨型燃料舱（翼板版）」和「最优木星组合 · 翼板版」，可与前排电池舱版对比。翼板挂到哪个部件 / 档次待用户决定。

**决定（11-24）**：太阳能翼板留给更高档次（第四档起，例如锻造融合神话件）；第三档燃料舱用能量电池舱。已写入设计方案「美术参考」段落，验收台后排标签已改为「更高档次预留」。

**家园全部换成 v2 部件（11-24）**：发射台上的首航火箭、组装舱转台上的全息、部件台上的悬浮部件（气动鼻锥 / 等离子发动机 / 基础尾翼）都已重建为 v2 造型。等离子发动机带侧推进舱后变宽，部件台悬浮缩放 0.85 → 0.8（已同步 `06_home_roll.lua`）。04 / 05 脚本直接调用 BuildLib，重跑即为 v2，无需改动。
**验收台位置**：按用户要求挪到家园背面边缘外约 5 studs（平台前沿 z ≈ 135.4，中心 z ≈ 158.4），`08_parts_review.lua` 已同步。

**验收台可行走（11-24）**：甲板、裙边、展台底座恢复碰撞；家园背面边缘到验收台之间加了一条 10 宽 × 8 长的连接步道（黄色护栏）。射线检查走道和平台无空洞，Play 测试中角色可从出生点走到平台前排和整箭区。部件和标签仍不碰撞（避免卡住角色）。

**Roll 按钮与部件台精简（用户反馈叠层太多、台子太高，11-24）**
- Roll 按钮只保留三件：底部石墨托盘 Ø4.6 × 0.45 + 中部白色圆筒 Ø3.4 × 1.45 + 顶部绿色圆顶按钮 Ø2.9 × 0.75（家园绿 #3BD85C），总高约 2.65。去掉护圈、环灯、多层按钮帽和铭牌。绿色按钮是用户指定，例外于「橙色 = 可互动」。
- 部件台：托盘 Ø6.2 × 0.5 → 白色圆筒 Ø5 × 1.0 → 状态环灯 Ø5.2 × 0.18 → 顶板 Ø5 × 0.17（嵌全息盘），总高约 1.9（原 3.85）。去掉黄虚线环、两道加强箍和三段叠台；状态环灯保留（表示待机 / 稀有度 / 已售出）。
- 悬浮区 4.5–7.6 → 2.6–5.7，价格卡底边 8.6 → 6.7，精英光柱从台面 1.9 起。已同步 `06_home_roll.lua` 和交接文档 C1 描述；原画 C1 仍是旧版。
- 补充：部件台底层按用户要求恢复为原石墨底座 Ø6.2 × 0.75 + 黄色虚线环，上部（圆筒、环灯、顶板）整体抬高 0.25，总高约 2.15；价格卡位置不变。

## 10. 邻居家园 ×5（2026-11-24 下午，待用户验收）

**用户决定**：邻居用简化版；Roblox 飞行中火箭放大 1.5 倍；广场商店 3 个（30° / 150° / 270° 桥间空档）；验收台等用户提醒再删。已写入设计方案。

**脚本参数化（T3）**：04–07 的脚本体包进 `build(K, LITE)`，顶部 `TARGETS = { 0, 1, 2, 3, 4, 5 }` 一次建六家。BuildLib 新增 `B.HOME_COLORS`、`B.homeColor(k)`、`B.lite(root, drop)`（本地文件和 Studio 的 ModuleScript 都已加；Studio 那份是去注释版本，按 `B.HOME_D = 94` 标记纯文本插入，并用克隆 require 验证过）。简化版先建全量，再按各脚本的 `LITE_DROP` 名单删细节件，并去掉所有 Light 和 Surface / Billboard 文字，坐标只维护一份。05 / 06 的换行符统一成 LF。

**结果**：Home_0 重建后仍是 586 件（发射区 128、组装舱 247、Roll 区 164、店位 42、出生点 5），和改造前一致。邻居 Home_1–5 为 175 / 157 / 206 / 178 / 169 件，共 885 件，没有点光源；全场 3268 件（含验收台 1332）。各家台上火箭组合不同（高级全套、大燃料舱、黄金鼻锥 + 等离子、等离子发动机、涡轮 + 后掠）。Home_3 原计划放全套精英，单枚火箭约 170 件，改成 黄金鼻锥 + 大燃料舱 + 等离子 + 后掠。

**部件零件数**（基础 / 高级 / 精英）：鼻锥 6 / 10 / 32，燃料舱 11 / 13 / 97，发动机 8 / 18 / 27，尾翼 12 / 16 / 52。

**未做**：本轮改动还没保存成新版本；广场商店模型、NPC 定时发射留到后面。

## 10. 场景放大约 1.3 倍（2026-11-25，待用户验收）

用户参考《Mine a Planet》觉得家园和广场偏小。用户选 1.3 倍、设施模型尺寸不变、只拉开间距。
- 家园 R 42 → 55，广场 R 46 → 60，中心距 94 → 122，桥宽 22 → 26（桥长 22.4）。
- 岩体、碎石、晶体 ×1.3；中央圆台 Ø24；光柱 50 → 65、120 → 156。
- 星球整体 ScaleTo 1.3。
- 设施按组外移：发射台 (0, −26)、组装舱 (33.8, −6.5)、出生点 (0, −6.5)、Roll 按钮 (2.6, 11.7)、部件台 z 24.7，间距 6.2 → 8；店位 x −31.2。
- 验收台平移到中心 z ≈ 197.6。

详细参数见 `docs/HANDOFF_STUDIO.md` 第 13 节，设计方案「场景放大」段落和家园坐标表已同步。Web Demo 未同步；Studio 已保存为版本 28。

## 11. P0 · 核心循环运行态资产（2026-11-24 晚，待用户验收）

用户要求按 `3D制作计划.md` 先完成 P0（11 项），验收后再做 P1、P2。第 1 项邻居家园之前已做；本轮完成第 2–11 项，建在另一个会话做的 1.3 倍场景放大（版本 28）之上。

- **BuildLib 挪到 `ReplicatedStorage.OrbitShared`**（P0-11），本地文件挪到 `studio/shared/BuildLib.lua`；`B.rocket` 的 WorldPivot 设为发动机底面中心。04–08 的开头改成克隆整个 OrbitShared 再 require。
- **新增 8 个共享模块**：Orbits、CatchArms、CatchZone、RocketKit、OrbitGate、Stardust、PartPad、AssemblyBay（接口见 HANDOFF_STUDIO 第 14 节）。客户端 RocketFX 加 RainbowFX、BreatheFX。
- **建造脚本副本**：03–06、09 在 `ServerStorage.WorldBuild` 各存一份 ModuleScript（B03…B09），重跑只要 require 克隆。
- **场景改动**：六家支架 L1 / L2 / L1 / L4 / L3 / L2，升级牌随等级；每家台上有隐藏接住区；台上火箭带熄火尾焰；组装舱有 DockPoint、全息自转；部件台改用 PartPad；月球正式门、木星轨道 + 锁定门、转场航线。
- **P0 验收台 `_P0Review`**（1187 件）：支架四级与开合、接住区黄 / 绿、六种尾焰、两种星尘、部件台六态、状态灯三色、轨道门三态。第一次摆出来左右颠倒（从家园看 +X 在左），已镜像。
- **踩到的坑**：细壁高筒 CylinderHandleAdornment 会画出横贯全屏的细线 → 光柱改实心；半透明饱和金色光晕在夜空上发褐 → 改浅色高透明；刚重建的 SurfaceGui 立即截图是空白（等一下再截就有）。
- **验证**：模块全部 require 通过；本地与 Studio 模块逐字节一致；Play 模式下自转、彩虹、呼吸都在动，无脚本报错。组装舱和升级牌的状态试过后已复位。已保存为版本 36（Team Create）。

**用户优化反馈（11-24 晚）**
- **L3 重型支架**要更有机械感、金属质感 → 改成 Metal 材质的工字钢桁架、花纹钢板底座、钢关节圆盘 + 镀铬螺栓、工字钢臂（铆钉、警示条）、配重、镀铬大油缸 + 软管、深钢夹爪 + 镀铬锯齿，橙色只做点缀。
- **L4 星辉支架**要更有科技感、更炫 → 三段悬浮立柱 + 脉动能量环、金色能量线、两道旋转全息环、金色尾翼、能量夹爪（叉齿 + 能量场 + 闪光）、顶部光球 + 小全息环、悬浮底座光带。
- **彩虹尾焰**要更夸张 → 加长 1.5 倍；6 片彩虹焰瓣、4 道彩虹激波环、喷口辉光、彩虹星火、彩虹拖尾；第一版焰瓣被白色外焰罩成粉彩，已改成淡白辉光 + 缩短白芯 + 焰瓣更实。
- 邻居简化版另外去掉 L3 / L4 的小零件和全息环。P0 验收台彩虹火箭抬高到 14，避免焰尾插进甲板。改动未保存（版本 36 之后）。

## 12. 付费回收支架（2026-11-25，待用户验收）

- 用户给 4 张回收支架原画，要求做一批并包含支架底座；等级对应问题上用户答「按商业化付费的支架进行考虑」→ 做成独立的 4 套付费外观（中级 / 进阶 / 高阶 / 旗舰），先放验收台 `_PaidBrackets` 对比。
- v1（BracketSkins 初版）用户否决：与原画差距太大，要保留细节、自发光、金属材质和纹理质感。
- v2：按原画加粗臂、加装甲面板 / 缝 / 包边 / 灯带、光环关节、液压、能量玻璃、多层底座；用 Studio AI 生成 MaterialVariant 做拉丝合金、阳极钛、碳纤维、甲板、格栅纹理；涂装件改回干净 SmoothPlastic（两版 AI 漆面一暗一花，弃用）。进阶的发光橙压深到 #FF5A10（Bloom 会把亮橙推黄）。
- 截图确认四套都对上原画主视图；未保存（版本 36 之后）。下一步看用户意见，再做 LOD 和接入发射区。
- 11-25 第二轮：用户嫌自发光太多、颜色都一样 → 砍发光、全部细线、玻璃只留发光边。
- 11-25 第三轮：用户要求参考《mini war》神圣级以上建筑（发来 7 张截图）→ 深色机体 + 每套一种标志发光色 + 能量核心 + 尖刺 / 塔楼 / 窗格；网上查不到该作的画面资料，按截图提炼。未保存。
- 11-25 第四轮：用户提议第 3、4 套加助推器火焰 → 做成小型姿态推进器（夹爪 / 锁体背面，本色小焰 + 粒子，接住时全开）+ 磁吸火花 + 旗舰塔顶余烬。焰锥先做成白热像白色尖刺，改为本色。未保存。
- 11-25 第五轮：第 3、4 套底座加喷焰环（底座外沿一圈贴地火焰 + 地面光晕 + 上升火星），随 setThrusters 变旺。高阶品红火焰太淡：喷口挪到底座外沿，加大尺寸，亮度 ×3。
- **11-25 已保存为版本 49（Team Create）**，包含版本 36 之后的全部改动（邻居简化版、P0 修整、付费支架一至五轮）。

## 13. P1 · 阶段一演出（2026-11-25 起）

- 用户验收通过 P0，开始 P1。定了做法：每项演出一个共享模块（`prepare` / `at(t)` / `play`），通用特效放 `ShowFX`，验收用 `P1Demo` 本地脚本在家园 0 循环播放。
- 第 12 项组装演出做完：龙门吊真吊（横梁、小车、缆绳伸缩）、部件从坞里放大成形、尾翼由机械臂装、点焊 + 转台转一圈、开门、运输带滚动送上发射台，共 8.4 s。
- 发现三档火箭比舱门宽，把组装舱门从 5.2 加宽到 10（四扇伸缩玻璃门），6 家都重建了。
- 用户指出转台旁两根小柱子挡住运输 → 做了全程碰撞扫描，删柱子、焊接臂挪到尾翼空档并在转台转前收起、舱门加高到 18.4（信息屏上屋顶）、龙门吊小车改骑横梁上、运输带先直行再斜向、部件在坞里缩小吊离墙后再放大、到台时回收支架放平迎接再合拢。扫描后全程不穿模。
- 部件坞铭牌按放入的部件变：级别 + 部件名 + 稀有度底色（和 Roll 台价格卡一致），空位写「空位」。
- 去掉 Roll 台、发射台、组装舱底座的黄色虚线 / 警示块。
- **11-25 已保存为版本 61（Team Create）**。
- 部件坞铭牌看不清 → 加大、提亮、上级别条 / 下大字部件名（白色粗字黑描边）。
- 第 13 项 Roll 揭晓做完：按钮按下 → 能量光球飞向各台 → 开箱中 → 按稀有度从低到高依次揭晓（部件和价格卡弹出、同色光柱，精英金柱最高 + 火花雨）；买下时部件化成光球飞进玩家。开了 StreamingEnabled，模块里加了等零件。未保存（版本 61 之后）。
- 第 14 项点火与发射做完：蓄力时台下暖光和尾焰随强度变化，超载时火箭抖动冒白汽，彩虹区尾焰变彩虹；发射时强光 + 双层冲击环 + 贴地翻滚的烟雾 + 震动，火箭加速升空并放大到 1.5；超级发射三层彩虹冲击环；超载熄火黑烟 + 尾焰断续熄灭再重新点着。离台时回收支架自动张开。未保存（版本 61 之后）。
- 第 14 项按用户反馈修：全息环乱转（组装演出后嵌套模型轴心留在转台上）→ 收尾时放回；蓄力时点火即冒烟、暖光压低；升空放大改成离台 20 高以后再慢慢放大。未保存（版本 61 之后）。
- 镜头震动改成统一的震感控制器（ShowFX.shake / rumble）：蓄力时随强度轻震、发射冲击、升空余震渐弱；组装、Roll 精英揭晓的震动也跟着变明显。未保存（版本 61 之后）。
- 第 15 项飞行表现做完：喷口外发光 + 尾焰拖尾 + 航迹云；轨道狂热时彩虹尾焰 / 彩虹拖尾 / 彩虹星火，轨道线流动彩虹、轨道门变 fever；邻居的狂热只显示在他的火箭上。演示里火箭发射后飞月球两圈再降落。未保存（版本 61 之后）。
- 点火等太久：演示蓄力改成 1.6 / 0.9 / 0.9 三段（完美 1.4 s、超级 3.3 s、超载 3.4 s），熄火抖动缩到 0.5 s；建议正式蓄力表同步，待用户确认。未保存（版本 61 之后）。
- 第 16、17 项一起做完：接住区光柱 + 降落扬尘 + 按结果的落地效果（完美纸屑 / 金色冲击波 / 第 5 连电弧，良好蓝波，太早弹一下）；坠毁倾倒爆炸、部件四散弹跳、维修无人机飞来用光锥把部件吸回去。无人机造型按龙门吊风格设计，原画 E1 待补。支架合拢角按火箭宽度自动算（巨型燃料舱不再被夹穿）。未保存（版本 61 之后）。
- 新增维修无人机验收台 _DroneReview（付费支架验收台南边）：放大 2.5 倍自转 + 原尺寸工作状态（火箭 + 修复光锥）。未保存（版本 61 之后）。
- 第 18–21 项（11-26）：
  - 18 木星解锁演出：护盾闪烁 → 裂纹 → 碎成 300 颗光点 + 冲击环 + 闪屏 → 木星恢复全彩、三层行星环展开、轨道门转正常、虚线变白，镜头自动对准木星再还给玩家。木星模型改为常驻（Persistent），否则轨道门没流到客户端时演出会中断。P1Demo 每轮开头播一次。
  - 19 围观访客：每家 3 人（Leo / Mia / Sam，Web Demo 配色 + 帽子），R15 体型；普通发射 / 接住时欢呼，超级发射和坠毁时被掀飞、翻滚、躺倒、爬起、走回原位再欢呼。新版 R15 生成器的关节是物理约束，建造时换成 Motor6D 才能在客户端做动作。
  - 20 广场：中央火箭雕塑（1.6 倍，金色，缓慢自转，6 盏地灯）+ 3 个公共商店位（即将开放）。
  - 21 流星：远空每 2–6.5 s 划过一颗。
  - 未保存（版本 61 之后）。
- **11-26 用户验收通过 P1 第 12–21 项，并已保存场景（版本 61 之后的修改全部存好）。** 点火蓄力 1.6 / 0.9 / 0.9 s 已同步到设计方案（「超级发射」一节 + 更新记录）；Web Demo 未同步。
