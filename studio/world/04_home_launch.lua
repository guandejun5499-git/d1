--[[
	Orbit Roll · 任务二 · 04 发射区（家园 K）
	发射台 / 回收台 Ø17 × 1.5 @ (0, −26)（A3 比例尺）；回收支架在台两侧（11-24 起 L1–L4 由 OrbitShared.CatchArms 建，各家等级见 ARM_LEVEL）；
	台上有隐藏的接住区光柱（OrbitShared.CatchZone，高度随支架等级）；
	发射塔架 25 高 @ (−9, −35)；支架升级牌 @ (−9.5, −22.5) 面向出生点；台上放一枚基础火箭（首航组合）。
	11-25 场景放大：发射区整体从 (0, −20) 外移到 (0, −26)，区内相对位置不变。
	依赖 ReplicatedStorage.OrbitShared.BuildLib。可重复运行：替换 Home_K.LaunchArea。
]]

-- 克隆整个 OrbitShared 再 require：模块之间互相 require，克隆能避开编辑器里的模块缓存
local SH = game.ReplicatedStorage.OrbitShared:Clone()
SH.Parent = game.ServerStorage
local B = require(SH.BuildLib)
local CA = require(SH.CatchArms)
local CZ = require(SH.CatchZone)
local RK = require(SH.RocketKit)

-- 要建的家园：0 = 玩家自家（全量），1–5 = 邻居（简化版 LITE：保留轮廓和主色，去掉细节件、文字牌和点光源）
local TARGETS = { 0, 1, 2, 3, 4, 5 }

-- 台上火箭组合：自家是首航基础组合；邻居各不相同，从自家看过去能读出「别人家的火箭更高级」
local PAD_EQ = {
	{ nose = 1, tank = 1, engine = 1, fins = 1 }, -- 0 自家 · 首航
	{ nose = 2, tank = 2, engine = 2, fins = 2 }, -- 1 高级全套
	{ nose = 1, tank = 2, engine = 1, fins = 1 }, -- 2 大燃料舱
	{ nose = 3, tank = 2, engine = 3, fins = 2 }, -- 3 黄金鼻锥 + 等离子（精英燃料舱 97 件、栅格尾翼 52 件，简化版放不下全套精英）
	{ nose = 2, tank = 1, engine = 3, fins = 1 }, -- 4 等离子发动机
	{ nose = 1, tank = 1, engine = 2, fins = 2 }, -- 5 涡轮 + 后掠
}
-- 回收支架等级：自家首航 L1；邻居各不相同（L1–L4 都能在场景里看到）
local ARM_LEVEL = { 1, 2, 1, 4, 3, 2 }
-- 邻居简化版删掉的细节件
local LITE_DROP = { Hazard = true, Dash = true, Grate = true, FrameBoard = true, ArmPlate = true, Rivet = true, Tooth = true, Hose = true, Groove = true, HoloRing = true } -- 后几项是 L3 / L4 支架的小零件，远看不出

local function build(K, LITE)
	local HOME_COLOR = B.homeColor(K)
	local H = B.homeFrame(K)
	local C = B.C
	local folder = B.homeFolder(K)
	local function L(x, y, z) return H * CFrame.new(x, y, z) end
	local function W(x, y, z) return H:PointToWorldSpace(Vector3.new(x, y, z)) end

	local m = B.replace(folder, "LaunchArea")

	------------------------------------------------------------------ 发射台
	local P = L(0, 0, -26)
	local pad = B.model("LaunchPad", m)
	B.cylAt(17, 0, 1.0, P, { Name = "Base", Color = C.graphite }, pad)
	B.cylAt(16, 1.0, 0.5, P, { Name = "Deck", Color = C.graphite2 }, pad)
	-- 11-25 用户要求：台座侧面的黄色警示块去掉（台面上的橙色虚线保留，表示可互动）
	B.segRing(P * CFrame.new(0, 1.53, 0), 6.4, 24, 1.0, 0.5, 0.06, { Name = "Dash", Color = C.orange }, pad) -- 橙色虚线 = 可互动
	B.cylAt(7, 1.5, 0.08, P, { Name = "LaunchPlate", Color = B.hex("5A6178") }, pad)
	B.cylAt(3.4, 1.5, 0.12, P, { Name = "FlameHole", Color = C.graphite3 }, pad)
	for i = 0, 3 do -- 导流槽格栅
		B.box(Vector3.new(3.0, 0.14, 0.25), P * CFrame.new(0, 1.55, -1.05 + i * 0.7), { Name = "Grate", Color = C.graphite2 }, pad)
	end

	------------------------------------------------------------------ 回收支架 L1–L4（OrbitShared.CatchArms，默认合拢）+ 接住区光柱（默认隐藏）
	local level = ARM_LEVEL[K + 1]
	CA.build(P, level, m)
	local zone = CZ.build(P * CFrame.new(0, 1.5, 0), m)
	local g, y = CZ.heightsFor(CA.LEVELS[level].win)
	CZ.set(zone, { visible = false, green = g, yellow = y })

	------------------------------------------------------------------ 发射塔架
	local T = L(-9, 0, -35)
	local tw = B.model("Tower", m)
	B.box(Vector3.new(3.6, 0.8, 3.6), T * CFrame.new(0, 0.4, 0), { Name = "Base", Color = C.graphite }, tw)
	B.box(Vector3.new(1.8, 24, 1.8), T * CFrame.new(0, 12.8, 0), { Name = "Column", Color = C.white }, tw)
	for _, y in ipairs({ 5.5, 10.5, 15.5, 20.5 }) do
		B.box(Vector3.new(2.3, 0.8, 2.3), T * CFrame.new(0, y, 0), { Name = "Collar", Color = C.orange }, tw)
	end
	B.box(Vector3.new(2.3, 0.4, 2.3), T * CFrame.new(0, 25, 0), { Name = "Cap", Color = C.graphite }, tw)
	local beacon = B.ball(1.1, T * CFrame.new(0, 25.75, 0), { Name = "Beacon", Color = C.red, Material = Enum.Material.Neon }, tw)
	local bl = Instance.new("PointLight")
	bl.Color = C.red
	bl.Range = 6 -- 太大会把白色塔身染红
	bl.Brightness = 0.8
	bl.Parent = beacon
	-- 服务臂：从塔架伸向火箭
	local a0, a1 = W(-9, 12.5, -35), W(0, 12.5, -26)
	local dir = (a1 - a0).Unit
	B.beamBetween(a0 + dir * 0.9, a0 + dir * 6.6, 0.8, 0.7, { Name = "ServiceArm", Color = C.graphite }, tw)
	B.box(Vector3.new(1.4, 1.2, 0.3), CFrame.lookAt(a0 + dir * 6.75, a0 + dir * 8), { Name = "ArmPlate", Color = C.graphite2 }, tw)

	------------------------------------------------------------------ 支架升级牌（面向出生点）
	local fbPos = W(-9.5, 0, -22.5)
	local sp = W(0, 0, -6.5)
	local FB = CFrame.lookAt(fbPos, Vector3.new(sp.X, fbPos.Y, sp.Z))
	local fb = B.model("FrameBoard", m)
	for _, x in ipairs({ -2.2, 2.2 }) do
		B.box(Vector3.new(0.5, 4.2, 0.5), FB * CFrame.new(x, 2.1, 0), { Name = "Post", Color = C.graphite }, fb)
	end
	B.box(Vector3.new(5.6, 3.0, 0.4), FB * CFrame.new(0, 5.2, 0), { Name = "Frame", Color = C.frameL1 }, fb)
	B.box(Vector3.new(5.1, 2.5, 0.1), FB * CFrame.new(0, 5.2, -0.22), { Name = "Panel", Color = C.graphite2 }, fb)
	B.box(Vector3.new(3.6, 0.6, 0.45), FB * CFrame.new(0, 3.35, -0.05), { Name = "UpgradeButton", Color = C.orange }, fb)
	CA.updateBoard(fb, level) -- 框色、文字、按钮随等级变化（满级显示「已满级」）

	------------------------------------------------------------------ 台上火箭
	local rocket = RK.build(PAD_EQ[K + 1], HOME_COLOR, P * CFrame.new(0, 1.5, 0), m) -- 运行时同款：带尾焰（熄火）、轴心在发动机底面
	rocket.Name = "PadRocket"

	-- 细节件不参与碰撞
	local DECO = { Hazard = true, Dash = true, LaunchPlate = true, FlameHole = true, Grate = true, Beacon = true, ArmPlate = true }
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and DECO[d.Name] then B.deco(d) end
	end

	if LITE then B.lite(m, LITE_DROP) end
	m.Parent = folder
end

for _, k in ipairs(TARGETS) do
	build(k, k ~= 0)
	task.wait()
end

SH:Destroy()
return "launch area ok · homes " .. table.concat(TARGETS, ",")
