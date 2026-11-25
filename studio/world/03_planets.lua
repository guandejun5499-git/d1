--[[
	Orbit Roll · 任务一 · 03 星球（共享月球 + 锁定的木星）
	可重复运行：先删除 Workspace.OrbitWorld.Planets 再重建。
	位置沿用 Web Demo（相对广场中心）：月球 (−50, 190, −60) r 28；木星 (170, 400, −220) r 72。
	11-25 场景整体放大：建好后两颗星球以世界原点为中心统一 ScaleTo(WORLD_S = 1.3)，
	实际为 月球 (−65, 247, −78) r 36.4、木星 (221, 520, −286) r 93.6（轨道、轨道门、护盾一起缩放）。
	星球全部不投影（太阳在头顶，会把月球影子投到广场上）、不碰撞。
	11-24 P0：正式轨道门（OrbitShared.OrbitGate，月球 normal / 木星 locked）、木星轨道虚线、月球 → 木星转场航线（TransferRoute）。
]]

local Workspace = game:GetService("Workspace")
local function hex(s) return Color3.fromHex(s) end

local root = Workspace:FindFirstChild("OrbitWorld")
if not root then
	root = Instance.new("Folder")
	root.Name = "OrbitWorld"
	root.Parent = Workspace
end
local old = root:FindFirstChild("Planets")
if old then old:Destroy() end
local planets = Instance.new("Folder")
planets.Name = "Planets"

local function part(props, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	local cf = props.CFrame
	props.CFrame = nil
	for k, v in pairs(props) do p[k] = v end
	if cf then p.CFrame = cf end
	p.Parent = parent
	return p
end
local function ball(d, pos, props, parent)
	props.Shape = Enum.PartType.Ball
	props.Size = Vector3.new(d, d, d)
	props.CFrame = CFrame.new(pos)
	return part(props, parent)
end
-- 圆盘：圆柱轴（本地 X）对齐法线 n
local function disc(dia, thick, pos, n, props, parent)
	local up = math.abs(n.Y) < 0.95 and Vector3.yAxis or Vector3.xAxis
	local y = n:Cross(up).Unit
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(thick, dia, dia)
	props.CFrame = CFrame.fromMatrix(pos, n, y)
	return part(props, parent)
end

local VIEW = Vector3.new(0, 0, 94) -- 玩家家园中心，用来让环形坑 / 大红斑朝向家园

------------------------------------------------------------------ 月球
do
	local m = Instance.new("Model")
	m.Name = "Moon"
	local C = Vector3.new(-50, 190, -60)
	local R = 28
	ball(R * 2, C, { Name = "Body", Color = hex("DFE3EE") }, m)
	ball(R * 2.5, C, { Name = "Halo", Color = hex("C8D7FF"), Material = Enum.Material.Neon, Transparency = 0.94 }, m)

	local rng = Random.new(42)
	local toward = (VIEW - C).Unit
	for i = 1, 12 do
		local n = (Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)) + toward * 1.1).Unit
		local d = rng:NextNumber(5, 15)
		disc(d, 1.6, C + n * (R - 0.35), n, { Name = "CraterRim", Color = hex("C5CADA") }, m)
		disc(d * 0.7, 1.6, C + n * (R - 0.2), n, { Name = "Crater", Color = hex("A7AEC3") }, m)
	end

	-- 轨道虚线（与 Web Demo 相同的轨道面：u = X，v = (0, −0.3, 1)）
	local orbit = 52
	local u = Vector3.xAxis
	local v = Vector3.new(0, -0.3, 1).Unit
	local N = 56
	for i = 0, N - 1 do
		local a = (i + 0.5) / N * math.pi * 2
		local p = C + u * orbit * math.cos(a) + v * orbit * math.sin(a)
		local t = (-u * math.sin(a) + v * math.cos(a)).Unit
		part({ Name = "OrbitDash", Size = Vector3.new(0.35, 0.35, 2.6), CFrame = CFrame.lookAt(p, p + t), Color = hex("FFFFFF"), Material = Enum.Material.Neon, Transparency = 0.45 }, m)
	end

	-- 轨道门：放大后由 OrbitShared.OrbitGate 建（见文件末尾）
	m.Parent = planets
end

------------------------------------------------------------------ 木星（锁定态）
do
	local m = Instance.new("Model")
	m.Name = "Jupiter"
	m:SetAttribute("Locked", true)
	local C = Vector3.new(170, 400, -220)
	local R = 72
	local tilt = CFrame.new(C) * CFrame.Angles(0, 0, 0.12)
	local dim = 0.78 -- 锁定时偏暗
	local function d(c) return Color3.new(c.R * dim, c.G * dim, c.B * dim) end

	ball(R * 2, C, { Name = "Body", Color = d(hex("C49A74")) }, m)
	local bands = {
		{ -60, -50, hex("8A6248") }, { -42, -30, hex("D9C3A0") }, { -24, -12, hex("B4703F") },
		{ -6, 6, hex("E3D2B0") }, { 12, 22, hex("8A6248") }, { 30, 40, hex("C98A55") },
		{ 46, 54, hex("D9C3A0") }, { 58, 64, hex("8A6248") },
	}
	for _, b in ipairs(bands) do
		local ym = (b[1] + b[2]) / 2
		local r = math.sqrt(R * R - ym * ym) + 0.4
		part({
			Name = "Band",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(b[2] - b[1], r * 2, r * 2),
			CFrame = tilt * CFrame.new(0, ym, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Color = d(b[3]),
		}, m)
	end
	-- 大红斑：朝向家园一侧的南半球
	local flat = Vector3.new(VIEW.X - C.X, 0, VIEW.Z - C.Z).Unit
	local n = (flat * math.cos(math.rad(20)) + Vector3.new(0, -math.sin(math.rad(20)), 0)).Unit
	n = (n + Vector3.new(0.35, 0, 0)).Unit
	disc(26, 4, C + n * (R - 0.6), n, { Name = "RedSpot", Color = d(hex("C4493A")) }, m)
	disc(17, 4, C + n * (R - 0.3), n, { Name = "RedSpotCore", Color = d(hex("A8352C")) }, m)

	-- 紫色能量护盾（ForceField 材质自带流动动画）+ 外层柔光
	ball(R * 2.42, C, { Name = "Shield", Color = hex("A46BFF"), Material = Enum.Material.ForceField }, m)
	ball(R * 2.62, C, { Name = "ShieldGlow", Color = hex("A46BFF"), Material = Enum.Material.Neon, Transparency = 0.95 }, m)

	-- 木星轨道虚线（Web Demo：半径 115，u = X，v = (0, −0.25, 1)）。锁定时偏暗的灰紫色，解锁后改白色。
	do
		local orbit = 115
		local u = Vector3.xAxis
		local v = Vector3.new(0, -0.25, 1).Unit
		local N = 96
		for i = 0, N - 1 do
			local a = (i + 0.5) / N * math.pi * 2
			local p = C + u * orbit * math.cos(a) + v * orbit * math.sin(a)
			local t = (-u * math.sin(a) + v * math.cos(a)).Unit
			part({ Name = "OrbitDash", Size = Vector3.new(0.45, 0.45, 3.2), CFrame = CFrame.lookAt(p, p + t), Color = hex("B9B0E6"), Material = Enum.Material.Neon, Transparency = 0.7 }, m)
		end
	end

	-- 锁定标签：放在星球下方（玩家从下往上看，放上方会压住星球）
	local anchor = part({ Name = "LabelAnchor", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(C - Vector3.new(0, R * 1.32 + 16, 0)), Transparency = 1 }, m)
	local bb = Instance.new("BillboardGui")
	bb.Name = "LockLabel"
	bb.Size = UDim2.fromOffset(300, 96)
	bb.LightInfluence = 0
	bb.MaxDistance = 3000
	bb.Parent = anchor
	local fr = Instance.new("Frame")
	fr.Size = UDim2.fromScale(1, 1)
	fr.BackgroundColor3 = hex("1C1640")
	fr.BackgroundTransparency = 0.15
	fr.Parent = bb
	Instance.new("UICorner", fr).CornerRadius = UDim.new(0, 18)
	local st = Instance.new("UIStroke", fr)
	st.Color = hex("A46BFF")
	st.Thickness = 3
	local t1 = Instance.new("TextLabel")
	t1.BackgroundTransparency = 1
	t1.Size = UDim2.new(1, 0, 0.58, 0)
	t1.Position = UDim2.fromScale(0, 0.06)
	t1.Font = Enum.Font.FredokaOne
	t1.Text = "🔒 木星 · 已锁定"
	t1.TextColor3 = Color3.new(1, 1, 1)
	t1.TextScaled = true
	t1.Parent = fr
	local t2 = Instance.new("TextLabel")
	t2.BackgroundTransparency = 1
	t2.Size = UDim2.new(1, 0, 0.3, 0)
	t2.Position = UDim2.fromScale(0, 0.62)
	t2.Font = Enum.Font.GothamBold
	t2.Text = "需要 Δv 900 的组合"
	t2.TextColor3 = hex("CDB6FF")
	t2.TextScaled = true
	t2.Parent = fr

	m.Parent = planets
end

-- 整体放大：以广场中心（世界原点）为基准缩放，位置和尺寸一起 ×1.3；
-- VIEW (0, 0, 94) 缩放后正好落在新的玩家家园中心 (0, 0, 122) 附近，朝向不变。
local WORLD_S = 1.3
for _, m in ipairs(planets:GetChildren()) do
	if m:IsA("Model") then
		m.WorldPivot = CFrame.new()
		m:ScaleTo(WORLD_S)
	end
end

------------------------------------------------------------------ 轨道门 + 月球 → 木星航线（放大后，坐标取自 OrbitShared.Orbits）
-- 克隆整个 OrbitShared 再 require，避开编辑器里的模块缓存
local SH = game.ReplicatedStorage.OrbitShared:Clone()
SH.Parent = game.ServerStorage
local O = require(SH.Orbits)
local G = require(SH.OrbitGate)
local moonM, jupM = planets:FindFirstChild("Moon"), planets:FindFirstChild("Jupiter")
local mo, ju = O.bodies.moon, O.bodies.jupiter
G.build(O.gateCF(mo), mo.gateR, moonM, "OrbitGate") -- 月球门半径 9.1，a0 = 90°
local jg = G.build(O.gateCF(ju), ju.gateR, jupM, "OrbitGate") -- 木星门半径 14.3，a0 = 180°
G.setState(jg, "locked")

-- 转场航线：月球门 → 木星门的三次贝塞尔，虚线；锁定时很淡
local route = Instance.new("Model")
route.Name = "TransferRoute"
route:SetAttribute("Locked", true)
local N = 44
for i = 0, N - 1 do
	local t0, t1 = (i + 0.2) / N, (i + 0.75) / N
	local p0, p1 = O.transfer(t0), O.transfer(t1)
	part({ Name = "RouteDash", Size = Vector3.new(0.5, 0.5, (p1 - p0).Magnitude), CFrame = CFrame.lookAt((p0 + p1) / 2, p1), Color = hex("B9B0E6"), Material = Enum.Material.Neon, Transparency = 0.8 }, route)
end
route.Parent = planets
SH:Destroy()

planets.Parent = root
return "planets ok"
