--[[
	Orbit Roll · 任务二 · 06 Roll 按钮 + 部件台（家园 K）—— 原画 C1
	Roll 按钮 @ (2, 9)（11-24 用户要求精简）：底部石墨托盘 + 中部白色圆筒 + 顶部绿色圆顶按钮，总高约 2.6；旁边是概率公示牌。
	Roll 部件区中心 (3.9, 24.7)，约 37 × 13；4 座部件台 x = 15.9 / 7.9 / −0.1 / −8.1（鼻锥、燃料舱、发动机、尾翼），间距 8。
	11-25 场景放大：原中心 (3, 19)、31 × 13、台 x = 12.3 / 6.1 / −0.1 / −6.3（间距 6.2，台与台贴边）；
	Roll 按钮 (2, 9) → (2.6, 11.7)，概率牌 (5.4, 9) → (7, 11.7)。
	（11-24 用户确认反向排列：玩家从出生点转身面朝 +Z 走向 Roll 区时，从左到右读到 鼻锥 → 尾翼。）
	部件台 Ø6.2（11-24 用户要求精简、降低）：原石墨底座（黄虚线环）→ 一段白色圆筒 → 状态环灯 → 带全息盘的顶板，总高约 2.15；
	部件悬浮在 2.6–5.7；BillboardGui 价格卡 6.4 × 3.3 studs，底边离地约 6.7。环灯颜色 = 状态（暗 = 待机，青 = 开箱中，银 / 蓝 / 金 = 稀有度，熄灭 = 已售出）。
	这里按 C1 原画摆出预览状态：鼻锥 高级·气动 40 / 燃料舱 SOLD / 发动机 精英·等离子 220（带光柱）/ 尾翼 基础。
	正式游戏里由 Roll 系统在运行时调用 OrbitShared.PartPad.setState 改写（11-24 起台体、价格卡、悬浮部件都在模块里；悬浮部件靠客户端 SpinFX 自转）。
]]

-- 克隆整个 OrbitShared 再 require：模块之间互相 require，克隆能避开编辑器里的模块缓存
local SH = game.ReplicatedStorage.OrbitShared:Clone()
SH.Parent = game.ServerStorage
local B = require(SH.BuildLib)
local PP = require(SH.PartPad)

-- 要建的家园：0 = 玩家自家（全量），1–5 = 邻居（简化版 LITE：保留轮廓和主色，去掉细节件、文字牌和点光源）
local TARGETS = { 0, 1, 2, 3, 4, 5 }

-- 邻居简化版：部件台一律摆待机态（环灯暗、无悬浮部件、无价格卡），删掉虚线环、名牌和概率牌
local LITE_DROP = { Dash = true, SlotPlate = true, OddsSign = true }

local function build(K, LITE)
	local HOME_COLOR = B.homeColor(K)
	local H = B.homeFrame(K)
	local C = B.C
	local V = Vector3.new
	local hex = B.hex
	local folder = B.homeFolder(K)
	local function L(x, y, z) return H * CFrame.new(x, y, z) end

	local m = B.replace(folder, "RollArea")
	m:SetAttribute("HomeIndex", K)

	------------------------------------------------------------------ 部件区地面
	local ZONE = L(3.9, 0, 24.7)
	B.deco(B.box(V(37, 0.04, 13), ZONE * CFrame.new(0, 0.02, 0), { Name = "Zone", Color = hex("D0CBE8") }, m))
	for _, z in ipairs({ -6.5, 6.5 }) do
		B.deco(B.box(V(37, 0.05, 0.18), ZONE * CFrame.new(0, 0.03, z), { Name = "ZoneEdge", Color = hex("B4ADD8") }, m))
	end
	for _, x in ipairs({ -18.5, 18.5 }) do
		B.deco(B.box(V(0.18, 0.05, 13), ZONE * CFrame.new(x, 0.03, 0), { Name = "ZoneEdge", Color = hex("B4ADD8") }, m))
	end

	------------------------------------------------------------------ 部件台（台体和状态切换都在 OrbitShared.PartPad）
	-- 自家按 C1 原画摆预览状态：鼻锥 高级·气动 40 / 燃料舱 SOLD / 发动机 精英·等离子 220（带光柱）/ 尾翼 基础；
	-- 邻居一律待机态。正式游戏由 Roll 系统在运行时调用 PartPad.setState 改写。
	local PREVIEW = { { mode = "offer", tier = 2 }, { mode = "sold" }, { mode = "offer", tier = 3 }, { mode = "offer", tier = 1 } }
	for i, x in ipairs({ 15.9, 7.9, -0.1, -8.1 }) do
		local pm = PP.buildPad(L(x, 0, 24.7), PP.SLOTS[i], m, "PartPad_" .. i)
		PP.setState(pm, LITE and { mode = "idle" } or PREVIEW[i], { homeColor = HOME_COLOR, lite = LITE })
	end

	------------------------------------------------------------------ Roll 按钮
	local RB = L(2.6, 0, 11.7)
	local rb = B.model("RollButton", m)
	-- 只保留三件：底部托盘 + 中部圆筒 + 顶部绿色圆顶按钮
	local GREEN = hex("3BD85C")
	B.cylAt(4.6, 0, 0.45, RB, { Name = "Base", Color = C.graphite }, rb)
	B.cylAt(3.4, 0.45, 1.45, RB, { Name = "Column", Color = C.white }, rb)
	local button = B.dome(2.9, 0.75, RB * CFrame.new(0, 1.9, 0), { Name = "Button", Color = GREEN }, rb)
	local bl = Instance.new("PointLight")
	bl.Color = GREEN
	bl.Range = 8
	bl.Brightness = 0.6
	bl.Parent = button

	-- 概率公示牌（Roll 按钮旁始终公示）
	local OS = L(7, 0, 11.7)
	local odds = B.model("OddsSign", m)
	B.box(V(0.35, 2.0, 0.35), OS * CFrame.new(0, 1.0, 0), { Name = "Post", Color = C.graphite }, odds)
	local board = B.box(V(4.8, 1.2, 0.2), OS * CFrame.new(0, 2.5, 0), { Name = "Board", Color = C.graphite2 }, odds)
	B.surfaceText(board, Enum.NormalId.Front, {
		{ text = "每座台独立 · 10 次保底精英", h = 0.4, color = hex("C9D1E0"), font = Enum.Font.GothamBold },
		{ text = "基础 55% · 高级 35% · 精英 10%", h = 0.5, color = Color3.new(1, 1, 1), font = Enum.Font.GothamBold },
	}, { pps = 70 })

	if LITE then B.lite(m, LITE_DROP) end
	m.Parent = folder
end

for _, k in ipairs(TARGETS) do
	build(k, k ~= 0)
	task.wait()
end

SH:Destroy()
return "roll area ok · homes " .. table.concat(TARGETS, ",")
