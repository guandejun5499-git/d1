--[[
	Orbit Roll · P0 验收台（临时，验收完整块删除）
	放在临时部件验收台（_PartsReview）右侧，中间有 6 studs 步道相连；甲板 104 × 76，前沿 z ≈ 174.6，顶面 y = 0。
	把 P0 运行态资产的各个状态并排摆出来，编辑模式下就能逐项看：
	  第 1 排  回收支架 L1–L4：L1 合拢 / L2 张开 + 接住区（火箭底部在黄区）/ L3 张开 + 接住区（绿区）/ L4 合拢
	  第 2 排  尾焰：基础橙 / 涡轮蓝 / 等离子紫 / 彩虹（狂热）/ 返航反推 / 离台带烟；星尘碎片（月球、木星两种尺寸）
	  第 3 排  部件台六种状态：待机 / 开箱中 / 基础件 / 高级件 / 精英件 / 已售出；组装舱状态灯三色
	  后方    轨道门三态：普通（显示虚线目标框 + 收缩光圈）/ 增幅紫 / 狂热彩虹 1.6 倍（锁定态看天上的木星门）
	动画（自转、呼吸、彩虹、闪烁）由客户端 RocketFX 驱动，Play 模式下才动；粒子在编辑模式就能看到。
]]

local SH = game.ReplicatedStorage.OrbitShared:Clone()
SH.Parent = game.ServerStorage
local B = require(SH.BuildLib)
local CA = require(SH.CatchArms)
local CZ = require(SH.CatchZone)
local RK = require(SH.RocketKit)
local G = require(SH.OrbitGate)
local SD = require(SH.Stardust)
local PP = require(SH.PartPad)
local AB = require(SH.AssemblyBay)
local O = require(SH.Orbits)
local C = B.C
local V = Vector3.new
local hex = B.hex
local CS = game:GetService("CollectionService")

local root = workspace.OrbitWorld
local old = root:FindFirstChild("_P0Review")
if old then old:Destroy() end
local m = B.model("_P0Review")

local X0, Z0, W, D = 102, 212.6, 104, 76 -- 甲板中心与尺寸（前沿 z = 174.6）
local HOME = B.homeColor(0)
-- 从家园一侧（−Z）看过来时世界 +X 在左手边：x 镜像后，各排从左到右读作 L1 → L4、橙 → 紫、待机 → 已售出
local function MX(x) return 2 * X0 - x end

local function label(text, pos, sub)
	local a = B.part({ Name = "LabelAnchor", Size = V(0.2, 0.2, 0.2), CFrame = CFrame.new(pos), Transparency = 1 }, m)
	B.deco(a)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(sub and 15 or 12, sub and 2.6 or 1.6)
	bb.LightInfluence = 0
	bb.MaxDistance = 75 -- 只看得到附近几块牌子，避免三排标签叠在一起
	bb.Parent = a
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = hex("16182E")
	f.BackgroundTransparency = 0.2
	f.Parent = bb
	Instance.new("UICorner", f).CornerRadius = UDim.new(0.3, 0)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(0.94, sub and 0.55 or 0.8)
	t.Position = UDim2.fromScale(0.03, 0.1)
	t.Font = Enum.Font.GothamBold
	t.Text = text
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextScaled = true
	t.Parent = f
	if sub then
		local s = t:Clone()
		s.Size = UDim2.fromScale(0.94, 0.3)
		s.Position = UDim2.fromScale(0.03, 0.64)
		s.Text = sub
		s.TextColor3 = hex("B9C3E6")
		s.Parent = f
	end
end

------------------------------------------------------------------ 甲板 + 步道
B.box(V(W, 1.2, D), CFrame.new(X0, -0.6, Z0), { Name = "Deck", Color = C.graphite2 }, m)
B.box(V(W - 2, 3, D - 2), CFrame.new(X0, -2.7, Z0), { Name = "Skirt", Color = C.graphite }, m)
B.box(V(W + 0.4, 0.3, 0.3), CFrame.new(X0, -0.25, Z0 - D / 2), { Name = "Edge", Color = C.yellow }, m)
for _, z in ipairs({ Z0 - 13, Z0 + 13 }) do -- 三排之间的分隔线
	B.deco(B.box(V(W - 6, 0.04, 0.3), CFrame.new(X0, 0.02, z), { Name = "Divider", Color = hex("4A5070") }, m))
end
B.box(V(6, 1.2, 10), CFrame.new(47, -0.6, 197.6), { Name = "Walkway", Color = C.graphite2 }, m) -- 接部件验收台（x = 44）
for _, z in ipairs({ 192.75, 202.45 }) do
	B.box(V(6, 1.0, 0.3), CFrame.new(47, 0.5, z), { Name = "Rail", Color = C.yellow }, m)
end
label("P0 验收台 · 核心循环资产", V(X0, 14, Z0 - D / 2 + 1), "临时展示，验收后整块删除（编辑模式静止，Play 模式下自转 / 彩虹 / 闪烁）")

------------------------------------------------------------------ 第 1 排：回收支架 L1–L4 + 开合 + 接住区
local ROW1 = Z0 - 25
local ARM_CASES = {
	{ eq = { nose = 1, tank = 1, engine = 1, fins = 1 }, pose = 0, note = "合拢（夹住火箭）" },
	{ eq = { nose = 2, tank = 1, engine = 2, fins = 2 }, pose = 1, zone = "yellow", base = 11, note = "张开 · 火箭底部在黄区" },
	{ eq = { nose = 2, tank = 2, engine = 3, fins = 2 }, pose = 1, zone = "green", base = 3.6, note = "张开 · 火箭底部在绿区" },
	{ eq = { nose = 3, tank = 2, engine = 3, fins = 2 }, pose = 0, note = "合拢 · 满级" },
}
for i, case in ipairs(ARM_CASES) do
	local x = MX(63 + (i - 1) * 26)
	local P = CFrame.new(x, 0, ROW1)
	B.cylAt(17, 0, 1.0, P, { Name = "PadBase", Color = C.graphite }, m)
	B.cylAt(16, 1.0, 0.5, P, { Name = "PadDeck", Color = C.graphite2 }, m)
	B.cylAt(7, 1.5, 0.08, P, { Name = "LaunchPlate", Color = hex("5A6178") }, m)
	local arms = CA.build(P, i, m)
	CA.setPose(arms, case.pose)
	local deck = P * CFrame.new(0, 1.5, 0)
	local r = RK.build(case.eq, HOME, deck * CFrame.new(0, case.base or 0, 0), m)
	if case.zone then
		local z = CZ.build(deck, m)
		local g, y = CZ.heightsFor(CA.LEVELS[i].win)
		CZ.set(z, { visible = true, green = g, yellow = y, base = case.base, state = case.zone })
		RK.setFlame(r, { power = 0.8, mode = "retro" })
	end
	local lvl = CA.LEVELS[i]
	label(("L%d %s · 高 %g"):format(i, lvl.name, lvl.h), V(x, 22, ROW1), case.note .. ("  · 完美窗口 %.2f s"):format(lvl.win))
end

------------------------------------------------------------------ 第 2 排：尾焰 + 星尘碎片
local ROW2 = Z0
local FLAME_CASES = {
	{ eq = { nose = 1, tank = 1, engine = 1, fins = 1 }, f = { power = 1 }, t = "基础 · 橙焰" },
	{ eq = { nose = 2, tank = 2, engine = 2, fins = 2 }, f = { power = 1 }, t = "涡轮 · 蓝焰" },
	{ eq = { nose = 2, tank = 2, engine = 3, fins = 2 }, f = { power = 1 }, t = "等离子 · 紫焰" },
	{ eq = { nose = 2, tank = 2, engine = 2, fins = 2 }, f = { power = 1.8, rainbow = true }, t = "彩虹尾焰 · 狂热 1.8", y = 14 }, -- 彩虹焰更长，火箭抬高
	{ eq = { nose = 1, tank = 1, engine = 1, fins = 1 }, f = { power = 1, mode = "retro" }, t = "返航反推" },
	{ eq = { nose = 1, tank = 1, engine = 1, fins = 1 }, f = { power = 1, mode = "launch" }, t = "离台 · 带烟" },
}
for i, case in ipairs(FLAME_CASES) do
	local x = MX(58 + (i - 1) * 13)
	local y = case.y or 8
	local r = RK.build(case.eq, HOME, CFrame.new(x, y, ROW2), m)
	RK.setFlame(r, case.f)
	label(case.t, V(x, y + 17, ROW2))
end
local mo, ju = O.bodies.moon, O.bodies.jupiter
SD.build(CFrame.new(MX(138), 8, ROW2), O.shardSize(mo), m)
label("星尘碎片 · 月球", V(MX(138), 15, ROW2))
SD.build(CFrame.new(MX(151), 10, ROW2), O.shardSize(ju), m)
label("星尘碎片 · 木星", V(MX(151), 22, ROW2))

------------------------------------------------------------------ 第 3 排：部件台六种状态 + 组装舱状态灯
local ROW3 = Z0 + 24
local PAD_CASES = {
	{ slot = "nose", st = { mode = "idle" }, t = "待机" },
	{ slot = "tank", st = { mode = "rolling" }, t = "开箱中" },
	{ slot = "fins", st = { mode = "offer", tier = 1 }, t = "基础件" },
	{ slot = "nose", st = { mode = "offer", tier = 2 }, t = "高级件" },
	{ slot = "engine", st = { mode = "offer", tier = 3 }, t = "精英件" },
	{ slot = "tank", st = { mode = "sold" }, t = "已售出" },
}
for i, case in ipairs(PAD_CASES) do
	local x = MX(58 + (i - 1) * 9)
	local pm = PP.buildPad(CFrame.new(x, 0, ROW3), case.slot, m, "PartPad_" .. i)
	PP.setState(pm, case.st, { homeColor = HOME })
	label(case.t, V(x, 12, ROW3))
end
for i, st in ipairs({ "staging", "ready", "assembling" }) do
	local x = MX(118 + (i - 1) * 9)
	B.box(V(1.6, 4, 1.6), CFrame.new(x, 2, ROW3), { Name = "LightPost", Color = C.white }, m)
	local l = B.box(V(1.4, 1.0, 1.4), CFrame.new(x, 4.5, ROW3), { Name = "StatusLight", Color = AB.STATUS[st].color, Material = Enum.Material.Neon }, m)
	if st == "assembling" then
		l:SetAttribute("PulseBase", 0)
		l:SetAttribute("PulseAmp", 0.85)
		l:SetAttribute("PulseSpeed", 12)
		CS:AddTag(l, "PulseFX")
	end
	label(({ "待组装 · 青", "可组装 · 绿", "组装中 · 黄橙闪" })[i], V(x, 7.5, ROW3))
end

------------------------------------------------------------------ 后方：轨道门三态（月球门尺寸 R 9.1）
local GZ, GY = Z0 + D / 2 + 12, 25
local GATE_CASES = {
	{ x = 66, state = "normal", t = "普通 · 金", sub = "下一道门：虚线目标框 + 收缩光圈" },
	{ x = 97, state = "boost", t = "增幅 · 紫", sub = "点中星尘后的下一道门" },
	{ x = 134, state = "fever", t = "狂热 · 彩虹 ×1.6", sub = "颜色循环在 Play 模式下可见" },
}
for _, case in ipairs(GATE_CASES) do
	local g = G.build(CFrame.new(MX(case.x), GY, GZ), mo.gateR, m, "Gate_" .. case.state)
	G.setState(g, case.state)
	if case.state == "normal" then
		G.setActive(g, true)
		G.setShrink(g, 1.7)
	end
	local top = mo.gateR * (case.state == "fever" and G.FEVER_SCALE or 1) * 1.45 + 3
	label(case.t, V(MX(case.x), GY + top, GZ), case.sub)
end

m.Parent = root
SH:Destroy()

local n = 0
for _, d in ipairs(m:GetDescendants()) do
	if d:IsA("BasePart") then n += 1 end
end
return "P0 review ok · parts " .. n
