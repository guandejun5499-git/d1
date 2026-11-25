--[[
	Orbit Roll · 任务一 · 02 世界布局（中央广场 + 六块家园地台 + 连桥 + 悬浮岩体 + 光柱）
	可重复运行：先删除 Workspace.OrbitWorld.Islands 再重建。

	坐标：广场中心为世界原点；家园 k 位于角度 a = k·60°，方向 (sin a, 0, cos a)。
	玩家自家（绿色）为 k = 0，中心 (0, 0, 122)，家园本地 −Z 朝广场，与设计方案「家园设施坐标」一致：
	世界坐标 = 家园中心 + CFrame.Angles(0, a, 0) * 本地坐标。
	地台顶面 y = 0。
]]

local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")

local function hex(s) return Color3.fromHex(s) end

------------------------------------------------------------------ 参数
-- 11-25 整体放大约 1.3 倍（用户参考《Mine a Planet》觉得场景偏小）：设施模型尺寸不变，只拉开间距。
-- 原值：PLAZA_R 46 / HOME_R 42 / HOME_D 94 / BRIDGE_W 22
local S = 1.3               -- 岩体深度、碎石、晶体、光柱等装饰尺度
local PLAZA_R = 60          -- 广场外接半径（平边到平边 ≈ 104）
local HOME_R = 55           -- 家园外接半径（平边到平边 ≈ 95）
local HOME_D = 122          -- 广场中心到家园中心
local BRIDGE_W = 26         -- 桥面总宽（护栏内净宽约 24.2，桥长约 22.4）
local COS30 = math.cos(math.pi / 6)
local PLAZA_APO = PLAZA_R * COS30   -- 51.96
local HOME_APO = HOME_R * COS30     -- 47.63
local BRIDGE_L = HOME_D - HOME_APO - PLAZA_APO -- ≈ 22.4，净宽 > 长度

local PAL = {
	floorHome = hex("DEDBF0"),   -- 淡紫灰（参考 Mine a Planet 地面）
	floorPlaza = hex("C9C5E6"),
	side = hex("4B4F8A"),
	rockA = hex("3D3870"),
	rockB = hex("2E2A5A"),
	rockC = hex("221E46"),
	deck = hex("6F79C2"),
	deckStripe = hex("5D67AF"),
	rail = hex("FFC93C"),
	graphite = hex("2E3247"),
	white = hex("F4F6FB"),
	crystalA = hex("A57AFF"), -- 晶体不发光（11-24 降低自发光），只用亮色
	crystalB = hex("74E5FF"),
}
-- 家园色：自己 + 五位邻居
local HOME_COLORS = { hex("3BD85C"), hex("FF5E7A"), hex("FFB33D"), hex("A46BFF"), hex("2FD3C8"), hex("FF8AD8") }
local BEAM_COLORS = { hex("4FD8FF"), hex("A46BFF"), hex("FF8AD8") }

-- 凸点贴图：Creator Store「Roblox Stud Texture New」Decal 91719898711547 解析出的图片 ID
-- （Texture 只能用 Image ID，直接填 Decal ID 会加载失败）
local STUD_TEX = "rbxassetid://123208729655253"

------------------------------------------------------------------ 工具
local root = Workspace:FindFirstChild("OrbitWorld")
if not root then
	root = Instance.new("Folder")
	root.Name = "OrbitWorld"
	root.Parent = Workspace
end
local old = root:FindFirstChild("Islands")
if old then old:Destroy() end

local tmp = Instance.new("Folder")
tmp.Name = "_csg_tmp"
tmp.Parent = Workspace

local function part(props, parent)
	local p = Instance.new(props.ClassName or "Part")
	props.ClassName = nil
	p.Anchored = true
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

local function deco(p) -- 纯装饰：不碰撞、不参与射线
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

-- 六边形棱柱：三块 R × 2·apo 的长方体旋转 0/60/120° 求并。顶点在本地 ±X，平边朝 ±Z。
local function hexPrism(R, H, cf, props, parent)
	local apo = R * COS30
	local pieces = {}
	for i = 0, 2 do
		pieces[i + 1] = part({ Size = Vector3.new(R, H, 2 * apo), CFrame = cf * CFrame.Angles(0, i * math.pi / 3, 0) }, tmp)
	end
	local u = pieces[1]:UnionAsync({ pieces[2], pieces[3] })
	for _, p in ipairs(pieces) do p:Destroy() end
	u.UsePartColor = true
	u.Anchored = true
	u.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do u[k] = v end
	u.Parent = parent
	return u
end

local function cylY(dia, h, pos, props, parent) -- 竖直圆柱（Roblox 圆柱轴为 X）
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(h, dia, dia)
	props.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2)
	return part(props, parent)
end

local function lightBeam(name, pos, height, color, width, parent, glowMul)
	glowMul = glowMul or 3.2
	local holder = deco(part({ Name = name, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(pos), Transparency = 1 }, parent))
	local a0 = Instance.new("Attachment")
	a0.Parent = holder
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, height, 0)
	a1.Parent = holder
	local b = Instance.new("Beam")
	b.Attachment0, b.Attachment1 = a0, a1
	b.FaceCamera = true
	b.Width0, b.Width1 = width, width * 0.55
	b.Color = ColorSequence.new(color)
	b.LightEmission = 0.5
	b.LightInfluence = 0
	b.Brightness = 1.2
	b.Segments = 1
	b.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(0.35, 0.7),
		NumberSequenceKeypoint.new(1, 1),
	})
	b.Parent = holder
	-- 外层柔光
	local b2 = b:Clone()
	b2.Width0, b2.Width1 = width * glowMul, width * glowMul / 2
	b2.Brightness = 0.6
	b2.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.88),
		NumberSequenceKeypoint.new(0.4, 0.95),
		NumberSequenceKeypoint.new(1, 1),
	})
	b2.Parent = holder
	return holder
end

------------------------------------------------------------------ 地台
-- 构建一块悬浮地台：凸点顶面 + 家园色边 + 霓虹细线 + 侧壁 + 阶梯岩体 + 碎石 + 晶体
local function island(name, center, yaw, R, floorColor, rimColor, seed, parent)
	local m = Instance.new("Model")
	m.Name = name
	local base = CFrame.new(center) * CFrame.Angles(0, yaw, 0)
	local rng = Random.new(seed)

	local floor = hexPrism(R, 0.6, base * CFrame.new(0, -0.3, 0), { Name = "Floor", Color = floorColor }, m)
	pcall(function() floor.CollisionFidelity = Enum.CollisionFidelity.Hull end)
	local tex = Instance.new("Texture")
	tex.Name = "Studs"
	tex.Face = Enum.NormalId.Top
	tex.Texture = STUD_TEX
	tex.StudsPerTileU = 2
	tex.StudsPerTileV = 2
	tex.Transparency = 0.72 -- 更实会读成棋盘格
	tex.Parent = floor

	deco(hexPrism(R + 0.5, 1.3, base * CFrame.new(0, -0.75, 0), { Name = "Rim", Color = rimColor }, m))
	deco(hexPrism(R + 0.65, 0.25, base * CFrame.new(0, -1.62, 0), { Name = "RimGlow", Color = rimColor, Material = Enum.Material.Neon }, m)) -- 地台边下方的霓虹细线（用户要求保留）
	deco(hexPrism(R - 0.2, 3.9, base * CFrame.new(0, -2.55, 0), { Name = "Side", Color = PAL.side }, m))

	-- 阶梯式倒锥岩体（每层轻微错角，避免机械感）
	local layers = {
		{ 0.92, 4.0 * S, -6.5 * S, PAL.rockA, 7 },
		{ 0.76, 5.0 * S, -11.0 * S, PAL.rockA, -9 },
		{ 0.56, 6.0 * S, -16.5 * S, PAL.rockB, 14 },
		{ 0.34, 7.0 * S, -23.0 * S, PAL.rockB, -5 },
		{ 0.15, 6.0 * S, -29.5 * S, PAL.rockC, 21 },
	}
	for i, L in ipairs(layers) do
		deco(hexPrism(R * L[1], L[2], base * CFrame.new(0, L[3], 0) * CFrame.Angles(0, math.rad(L[5]), 0),
			{ Name = "Rock" .. i, Color = L[4], Material = Enum.Material.Slate, CastShadow = false }, m))
	end

	-- 碎石块：打破阶梯轮廓
	for i = 1, 22 do
		local L = layers[rng:NextInteger(1, 4)]
		local ang = rng:NextNumber(0, math.pi * 2)
		local r = R * L[1] * rng:NextNumber(0.78, 0.98)
		local s = rng:NextNumber(3.5, 8.5) * S
		deco(part({
			Name = "Chunk",
			Size = Vector3.new(s, s * rng:NextNumber(0.6, 1.1), s * rng:NextNumber(0.7, 1.2)),
			CFrame = base * CFrame.new(math.cos(ang) * r, L[3] - rng:NextNumber(0, 2.5 * S), math.sin(ang) * r)
				* CFrame.Angles(rng:NextNumber(-0.7, 0.7), rng:NextNumber(0, 6.28), rng:NextNumber(-0.7, 0.7)),
			Color = (i % 3 == 0) and PAL.rockB or PAL.rockA,
			Material = Enum.Material.Slate,
			CastShadow = false,
		}, m))
	end

	-- 发光晶体：从岩体侧面和底部斜伸出来
	for i = 1, 4 do
		local ang = rng:NextNumber(0, math.pi * 2)
		local L = layers[rng:NextInteger(2, 4)]
		local r = R * L[1] * 0.95
		local len = rng:NextNumber(4, 8) * S
		local pos = base * CFrame.new(math.cos(ang) * r, L[3] - 1, math.sin(ang) * r)
		local outward = (pos.Position - (center + Vector3.new(0, L[3], 0))).Unit
		local dir = (outward + Vector3.new(0, -0.9, 0)).Unit
		deco(part({
			Name = "Crystal",
			Size = Vector3.new(1.4 * S, len, 1.4 * S),
			CFrame = CFrame.lookAt(pos.Position + dir * len * 0.4, pos.Position + dir * len * 0.4 + dir) * CFrame.Angles(math.pi / 2, 0, math.pi / 4),
			Color = (i % 2 == 0) and PAL.crystalA or PAL.crystalB,
			Material = Enum.Material.SmoothPlastic,
			CastShadow = false,
		}, m))
	end
	-- 底部垂坠晶簇
	deco(part({
		Name = "Crystal",
		Size = Vector3.new(2.2 * S, 9 * S, 2.2 * S),
		CFrame = base * CFrame.new(0, -35 * S, 0) * CFrame.Angles(0, math.rad(45), 0),
		Color = PAL.crystalA,
		Material = Enum.Material.SmoothPlastic,
		CastShadow = false,
	}, m))

	m.Parent = parent
	return m
end

------------------------------------------------------------------ 连桥
local function bridge(k, a, parent)
	local m = Instance.new("Model")
	m.Name = "Bridge_" .. k
	local dir = Vector3.new(math.sin(a), 0, math.cos(a))
	local mid = (PLAZA_APO + HOME_D - HOME_APO) / 2
	local cf = CFrame.new(dir * mid) * CFrame.Angles(0, a, 0) -- 本地 +Z 指向家园，−Z 指向广场
	local L = BRIDGE_L

	part({ Name = "Deck", Size = Vector3.new(BRIDGE_W, 1.2, L + 2), CFrame = cf * CFrame.new(0, -0.65, 0), Color = PAL.deck }, m)
	for z = -L / 2 + 1.5, L / 2 - 1.5, 3 do
		deco(part({ Name = "Stripe", Size = Vector3.new(BRIDGE_W - 3.6, 0.08, 0.6), CFrame = cf * CFrame.new(0, -0.01, z), Color = PAL.deckStripe }, m))
	end
	local railX = BRIDGE_W / 2 - 0.45
	for _, sx in ipairs({ -1, 1 }) do
		part({ Name = "Rail", Size = Vector3.new(0.9, 1.1, L), CFrame = cf * CFrame.new(sx * railX, 0.5, 0), Color = PAL.rail }, m)
		-- 广场端外撇护栏：入口稍微放宽
		local th = math.rad(32)
		local len = 4.2
		part({
			Name = "RailFlare",
			Size = Vector3.new(0.9, 1.1, len),
			CFrame = cf * CFrame.new(sx * (railX + math.sin(th) * len / 2), 0.5, -L / 2 - math.cos(th) * len / 2 + 0.2) * CFrame.Angles(0, sx * -th, 0),
			Color = PAL.rail,
		}, m)
		-- 护栏端头灯
		for _, ez in ipairs({ -L / 2, L / 2 }) do
			deco(part({ Name = "RailCap", Size = Vector3.new(1.1, 0.35, 1.1), CFrame = cf * CFrame.new(sx * railX, 1.2, ez), Color = PAL.rail }, m))
		end
		deco(part({ Name = "Beam", Size = Vector3.new(1.2, 1.4, L + 2), CFrame = cf * CFrame.new(sx * BRIDGE_W * 0.36, -1.95, 0), Color = PAL.graphite }, m))
	end
	m.Parent = parent
	return m
end

------------------------------------------------------------------ 构建
local islands = Instance.new("Folder")
islands.Name = "Islands"
islands.Parent = root

-- 广场
local plaza = island("Plaza", Vector3.zero, 0, PLAZA_R, PAL.floorPlaza, PAL.rail, 7, islands)
task.wait()

-- 广场中央：活动 / 观看发射的圆台（日后放火箭雕塑）
do
	local m = Instance.new("Model")
	m.Name = "CenterStage"
	cylY(24, 1.2, Vector3.new(0, 0.6, 0), { Name = "Base", Color = PAL.graphite }, m)
	deco(cylY(22, 0.2, Vector3.new(0, 1.25, 0), { Name = "Glow", Color = BEAM_COLORS[1], Material = Enum.Material.Neon, Transparency = 0.45 }, m))
	cylY(21, 0.3, Vector3.new(0, 1.3, 0), { Name = "Top", Color = PAL.white }, m)
	deco(cylY(8, 0.1, Vector3.new(0, 1.48, 0), { Name = "Emblem", Color = hex("FF7A1A") }, m))
	local pl = Instance.new("PointLight")
	pl.Color = BEAM_COLORS[1]
	pl.Range = 28
	pl.Brightness = 0.7
	pl.Parent = m:FindFirstChild("Glow")
	m.Parent = plaza
end

-- 广场六角：光柱底座 + Beam 光柱 + 点光源（位于两座桥之间，避开入口）
for k = 0, 5 do
	local a = math.rad(30 + 60 * k)
	local pos = Vector3.new(math.sin(a), 0, math.cos(a)) * (PLAZA_R * 0.86)
	local col = BEAM_COLORS[(k % 3) + 1]
	local m = Instance.new("Model")
	m.Name = "LightPillar_" .. k
	cylY(5, 1.4, pos + Vector3.new(0, 0.7, 0), { Name = "Base", Color = PAL.graphite }, m)
	local ring = deco(cylY(3.6, 0.5, pos + Vector3.new(0, 1.65, 0), { Name = "Lamp", Color = col, Material = Enum.Material.Neon, Transparency = 0.45 }, m))
	local pl = Instance.new("PointLight")
	pl.Color = col
	pl.Range = 20
	pl.Brightness = 0.7
	pl.Parent = ring
	-- 只到 65 高（原 50，随场景 ×1.3）：更高时从家园抬头看会直戳月球
	lightBeam("Beam", pos + Vector3.new(0, 1.9, 0), 65, col, 2.0, m, 2.2)
	m.Parent = plaza
end

-- 六块家园 + 桥
for k = 0, 5 do
	local a = math.rad(60 * k)
	local c = Vector3.new(math.sin(a), 0, math.cos(a)) * HOME_D
	local name = (k == 0) and "Home_0_Player" or ("Home_" .. k)
	local home = island(name, c, a, HOME_R, PAL.floorHome, HOME_COLORS[k + 1], 100 + k, islands)
	home:SetAttribute("HomeIndex", k)
	home:SetAttribute("HomeColor", HOME_COLORS[k + 1])
	-- 家园色光柱：家园背面右后角（本地 (23.4, 0, apo − 6)），从广场一眼看出各家位置。
	-- 不放在背面正中：那里正对 Roll 部件区，从出生点看会像是某座部件台在发光柱。
	local back = CFrame.new(c) * CFrame.Angles(0, a, 0) * CFrame.new(23.4, 0, HOME_APO - 6)
	local pm = Instance.new("Model")
	pm.Name = "HomeBeacon"
	cylY(3.4, 0.8, back.Position + Vector3.new(0, 0.4, 0), { Name = "Base", Color = PAL.graphite }, pm)
	deco(cylY(2.4, 0.3, back.Position + Vector3.new(0, 0.9, 0), { Name = "Lamp", Color = HOME_COLORS[k + 1], Material = Enum.Material.Neon, Transparency = 0.45 }, pm))
	-- 近看时不能是一条宽光带：主光 1.3 宽、柔光 ×1.8
	lightBeam("Beam", back.Position + Vector3.new(0, 1, 0), 156, HOME_COLORS[k + 1], 1.3, pm, 1.8)
	pm.Parent = home
	bridge(k, a, islands)
	task.wait()
end

-- 漂浮光点（全局氛围）
do
	local p = deco(part({ Name = "FloatingMotes", Size = Vector3.new(340, 1, 340), CFrame = CFrame.new(0, 18, 0), Transparency = 1 }, islands))
	local pe = Instance.new("ParticleEmitter")
	pe.Rate = 50
	pe.Lifetime = NumberRange.new(10, 16)
	pe.Speed = NumberRange.new(0.4, 1.4)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, 0.35), NumberSequenceKeypoint.new(0.8, 0.35), NumberSequenceKeypoint.new(1, 0) })
	pe.Transparency = NumberSequence.new(0.15)
	pe.Color = ColorSequence.new(hex("CDBBFF"), hex("8FE8FF"))
	pe.LightEmission = 1
	pe.LightInfluence = 0
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Parent = p
end

tmp:Destroy()

------------------------------------------------------------------ 出生点 / 旧底板
local spawn = Workspace:FindFirstChildOfClass("SpawnLocation")
if spawn then
	-- 玩家家园本地 (0, −6.5)，面向 −Z（发射台方向）
	local pos = Vector3.new(0, 0.1, HOME_D - 6.5)
	spawn.Size = Vector3.new(5, 0.2, 5)
	spawn.CFrame = CFrame.lookAt(pos, pos + Vector3.new(0, 0, -1))
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	for _, d in ipairs(spawn:GetChildren()) do
		if d:IsA("Decal") then d:Destroy() end
	end
end
local bp = Workspace:FindFirstChild("Baseplate")
if bp then
	bp.Parent = ServerStorage -- 收起默认底板（不删除）
end

return ("islands ok · bridge L=%.2f W=%d (net %.1f) · home gap=%.1f"):format(BRIDGE_L, BRIDGE_W, BRIDGE_W - 1.8, HOME_D - 2 * HOME_APO)
