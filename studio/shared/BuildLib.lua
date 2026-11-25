--[[
	BuildLib · Orbit Roll 场景建造工具 + D1 火箭部件造型
	安装位置：ReplicatedStorage.OrbitShared.BuildLib（ModuleScript；11-24 从 ServerStorage 挪来，运行时服务器和客户端都能用）。
	家园建造脚本 04–08 和 OrbitShared 里的其他模块通过它建模。Studio 里那份去掉了注释，打补丁用纯文本查找替换。

	火箭部件（D1，已确认）：机身 Ø4，接口环 Ø4.4 × 0.35（石墨），轴心在底面中心，
	按 发动机 → 燃料舱 → 鼻锥 沿 Y 堆叠；尾翼 4 片 45° 分布挂在燃料舱底部 0–3 studs。
	高度：发动机 3 / 3.4 / 3.4，燃料舱 4 / 6 / 8，鼻锥 3 / 4 / 3.4。档次 1 基础 / 2 高级 / 3 精英。
	v2（11-24）：鼻锥、喷管改用光滑的圆锥网格 / 半椭球（模板在 ReplicatedStorage.RocketAssets），
	造型语言参考用户提供的部件原画：石墨倒角端盖、档次色发光条、卡箍 / 装甲片。
]]

local B = {}

local function hex(s) return Color3.fromHex(s) end
B.hex = hex

B.C = {
	white = hex("F4F6FB"),
	graphite = hex("2E3247"),
	graphite2 = hex("3B4060"),
	graphite3 = hex("262A3D"),
	orange = hex("FF7A1A"),
	yellow = hex("FFC93C"),
	basic = hex("B8C2D1"),
	adv = hex("2F8CFF"),
	elite = hex("FFC53D"),
	eliteDark = hex("C8901E"),
	cyan = hex("4FE3F0"),
	teal = hex("3FB8C0"),
	glass = hex("CFEFFF"),
	frameL1 = hex("9AA3B5"),
	metal = hex("A9B0BF"),
	nozzle = hex("5A6178"),
	porthole = hex("8FE3FF"),
	purple = hex("B46BFF"),
	red = hex("FF4D5E"),
}
B.TIER_COLOR = { B.C.basic, B.C.adv, B.C.elite }
B.ENGINE_H = { 3, 3.4, 3.4 }
B.TANK_H = { 4, 6, 8 }
B.NOSE_H = { 3, 4, 3.4 }

------------------------------------------------------------------ 基础几何
function B.part(props, parent)
	local p = Instance.new(props.ClassName or "Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	if props.Shape then p.Shape = props.Shape end
	for k, v in pairs(props) do
		if k ~= "CFrame" and k ~= "ClassName" and k ~= "Shape" then p[k] = v end
	end
	if props.CFrame then p.CFrame = props.CFrame end
	p.Parent = parent
	return p
end

function B.deco(p)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

local function copy(props) return props and table.clone(props) or {} end

function B.box(size, cf, props, parent)
	props = copy(props)
	props.Size = size
	props.CFrame = cf
	return B.part(props, parent)
end

function B.wedge(size, cf, props, parent)
	props = copy(props)
	props.ClassName = "WedgePart"
	props.Size = size
	props.CFrame = cf
	return B.part(props, parent)
end

-- 竖直圆柱：中心在 cf，轴沿 cf 的 Y
function B.cyl(dia, h, cf, props, parent)
	props = copy(props)
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(h, dia, dia)
	props.CFrame = cf * CFrame.Angles(0, 0, math.pi / 2)
	return B.part(props, parent)
end

-- 底面在 cf 的圆柱（y0 为底面高度）
function B.cylAt(dia, y0, h, cf, props, parent)
	return B.cyl(dia, h, cf * CFrame.new(0, y0 + h / 2, 0), props, parent)
end

-- 圆盘：轴沿 cf 的 Z（贴在竖直面上用）
function B.discZ(dia, thick, cf, props, parent)
	props = copy(props)
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(thick, dia, dia)
	props.CFrame = cf * CFrame.Angles(0, -math.pi / 2, 0)
	return B.part(props, parent)
end

function B.ball(d, cf, props, parent)
	props = copy(props)
	props.Shape = Enum.PartType.Ball
	props.Size = Vector3.new(d, d, d)
	props.CFrame = cf
	return B.part(props, parent)
end

-- 两点之间的方条
function B.beamBetween(a, b, w, h, props, parent)
	local len = (b - a).Magnitude
	return B.box(Vector3.new(w, h, len), CFrame.lookAt((a + b) / 2, b), props, parent)
end

-- 绕 cf 的 Y 轴一圈小方块（虚线环 / 点阵）
function B.segRing(cf, radius, n, segLen, w, h, props, parent)
	for i = 0, n - 1 do
		local a = (i + 0.5) / n * math.pi * 2
		local c = cf * CFrame.new(math.sin(a) * radius, 0, math.cos(a) * radius) * CFrame.Angles(0, a + math.pi / 2, 0)
		B.box(Vector3.new(w, h, segLen), c, props, parent)
	end
end

function B.model(name, parent)
	local m = Instance.new("Model")
	m.Name = name
	if parent then m.Parent = parent end
	return m
end

function B.decoAll(inst)
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("BasePart") then B.deco(d) end
	end
	return inst
end

------------------------------------------------------------------ 家园坐标
B.HOME_D = 122 -- 11-25 场景放大约 1.3 倍（原 94）
-- 家园色（k = 0 是玩家自家），与 02_islands 的 HOME_COLORS 一致
B.HOME_COLORS = { hex("3BD85C"), hex("FF5E7A"), hex("FFB33D"), hex("A46BFF"), hex("2FD3C8"), hex("FF8AD8") }
function B.homeColor(k) return B.HOME_COLORS[k + 1] end

-- 邻居简化版（LOD）：建完全量后按名字删细节件，并去掉所有点光源和 Surface / Billboard 文字
function B.lite(root, drop)
	for _, d in ipairs(root:GetDescendants()) do
		if d.Parent and (drop[d.Name] or d:IsA("Light") or d:IsA("LayerCollector")) then d:Destroy() end
	end
	root:SetAttribute("LOD", "Lite")
end
-- 家园 k 的本地坐标系：原点在家园中心地面，−Z 朝广场
function B.homeFrame(k)
	local a = math.rad(60 * k)
	return CFrame.new(Vector3.new(math.sin(a), 0, math.cos(a)) * B.HOME_D) * CFrame.Angles(0, a, 0)
end

function B.homeFolder(k)
	local root = workspace:FindFirstChild("OrbitWorld")
	local homes = root:FindFirstChild("Homes")
	if not homes then
		homes = Instance.new("Folder")
		homes.Name = "Homes"
		homes.Parent = root
	end
	local f = homes:FindFirstChild("Home_" .. k)
	if not f then
		f = Instance.new("Folder")
		f.Name = "Home_" .. k
		f.Parent = homes
	end
	return f
end

function B.replace(parent, name)
	local o = parent:FindFirstChild(name)
	if o then o:Destroy() end
	return B.model(name)
end

------------------------------------------------------------------ 文字
function B.surfaceText(part, face, lines, opts)
	opts = opts or {}
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = opts.pps or 60
	sg.LightInfluence = opts.lightInfluence or 0.2
	sg.Parent = part
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.Parent = sg
	local list = Instance.new("UIListLayout")
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = frame
	for i, ln in ipairs(lines) do
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(0.92, ln.h or (1 / #lines))
		t.Text = ln.text
		t.Font = ln.font or Enum.Font.FredokaOne
		t.TextColor3 = ln.color or Color3.new(1, 1, 1)
		t.TextScaled = true
		t.LayoutOrder = i
		t.Parent = frame
	end
	return sg
end

------------------------------------------------------------------ 火箭部件 v2（cf = 部件底面中心）
-- 11-24 按 D1 + 用户提供的部件原画（厚实倒角端盖、档次色发光条、卡箍 / 装甲片）重做：
-- 鼻锥改为光滑造型（圆锥网格 / 半椭球），不再用叠层圆柱。
-- 模板在 ReplicatedStorage.RocketAssets：ConeTemplate（MeshPart，圆锥，资源 1033714）、DomeTemplate（UnionOperation，上半球）。

local RS = game:GetService("ReplicatedStorage")
local function tpl(name) return RS:WaitForChild("RocketAssets"):WaitForChild(name) end

local function apply(p, props, parent)
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props or {}) do
		if k ~= "CFrame" and k ~= "Size" and k ~= "Shape" and k ~= "ClassName" then p[k] = v end
	end
	p.Parent = parent
	return p
end

-- 圆锥：cf = 底面中心，尖朝 cf 的 +Y
function B.cone(dia, h, cf, props, parent)
	local p = tpl("ConeTemplate"):Clone()
	p.Size = Vector3.new(dia, h, dia)
	p.CFrame = cf * CFrame.new(0, h / 2, 0)
	return apply(p, props, parent)
end

-- 半椭球（圆顶）：cf = 底面中心
function B.dome(dia, h, cf, props, parent)
	local p = tpl("DomeTemplate"):Clone()
	p.Size = Vector3.new(dia, h, dia)
	p.CFrame = cf * CFrame.new(0, h / 2, 0)
	pcall(function() p.UsePartColor = true end)
	return apply(p, props, parent)
end

local NEON = Enum.Material.Neon
local FLAME = { B.hex("FF8A1F"), B.hex("3FA7FF"), B.hex("B46BFF") } -- 尾焰：橙 / 蓝 / 紫

local function ring(cf, y, parent)
	return B.cylAt(4.4, y, 0.35, cf, { Name = "InterfaceRing", Color = B.C.graphite }, parent)
end
local function band(cf, y, h, color, parent, mat, tr, dia)
	return B.cylAt(dia or 4.12, y, h, cf, { Name = "Band", Color = color, Material = mat or Enum.Material.SmoothPlastic, Transparency = tr or 0 }, parent)
end
local function glow(cf, y, h, color, parent, dia)
	return B.cylAt(dia or 4.14, y, h, cf, { Name = "Glow", Color = color, Material = NEON, Transparency = 0.2 }, parent)
end

-- 舷窗：贴在曲面上（y = 高度，r = 该高度的外半径，tilt = 法线上仰角）
local function porthole(cf, y, r, tilt, parent, rimColor)
	local c = cf * CFrame.new(0, y, r - 0.12) * CFrame.Angles(-tilt, 0, 0)
	B.discZ(1.3, 0.3, c, { Name = "PortholeRim", Color = rimColor or B.C.graphite }, parent)
	B.discZ(0.95, 0.36, c, { Name = "Porthole", Color = B.C.porthole }, parent)
end

-- 绕轴一圈的小方块（装甲片、卡箍、竖条），a 为角度（度）
local function around(cf, angles, radial, y, size, props, parent)
	for _, deg in ipairs(angles) do
		local a = math.rad(deg)
		local p = Vector3.new(math.sin(a) * radial, y, math.cos(a) * radial)
		B.box(size, cf * CFrame.lookAt(p, p + Vector3.new(math.sin(a), 0, math.cos(a))), props, parent)
	end
end

---------------------------------------------------------------- 科技装饰 / 特效工具
-- 第三档起使用；以后更高档次（例如阶段二锻造融合的神话件）复用这些工具并加量。
-- 动画由客户端脚本 RocketFX 驱动（编辑模式下静止，Play 时可见）：
--   标签 SpinFX（Model，绕 WorldPivot 的 Y 轴旋转，属性 SpinSpeed = 弧度/秒）
--   标签 PulseFX（BasePart，透明度呼吸，属性 PulseBase / PulseAmp / PulseSpeed）
-- 粒子在编辑模式下就会显示。发光件保持小尺寸、半透明，避免晃眼。
local CS = game:GetService("CollectionService")
B.fx = {}

-- 全息虚线环：cf = 环心，环在 cf 的 XZ 平面内
function B.fx.haloRing(cf, radius, n, color, speed, parent)
	local r = B.model("HoloRing", parent)
	local seg = 2 * math.pi * radius / n * 0.62
	B.segRing(cf, radius, n, seg, 0.14, 0.14, { Name = "Seg", Color = color, Material = NEON, Transparency = 0.25, CastShadow = false }, r)
	B.decoAll(r)
	r.WorldPivot = cf
	r:SetAttribute("SpinSpeed", speed)
	CS:AddTag(r, "SpinFX")
	return r
end

-- 脉动发光球
function B.fx.orb(cf, d, color, parent)
	local o = B.ball(d, cf, { Name = "GlowOrb", Color = color, Material = NEON, Transparency = 0.1, CastShadow = false }, parent)
	B.deco(o)
	o:SetAttribute("PulseBase", 0.1)
	o:SetAttribute("PulseAmp", 0.45)
	o:SetAttribute("PulseSpeed", 3)
	CS:AddTag(o, "PulseFX")
	return o
end

-- 细小闪光粒子
function B.fx.sparkles(part, color, rate, size)
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "Sparkles"
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(color)
	pe.LightEmission = 1
	pe.LightInfluence = 0
	pe.Rate = rate
	pe.Lifetime = NumberRange.new(0.6, 1.3)
	pe.Speed = NumberRange.new(0.4, 1.4)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, size), NumberSequenceKeypoint.new(1, 0) })
	pe.Transparency = NumberSequence.new(0.15)
	pe.Parent = part
	return pe
end

-- 太阳能翼板（11-24 重做：科技感 + 金属质感）。用户确定：留给第四档及以上（例如阶段二锻造融合的神话件），
-- 第三档燃料舱用能量电池舱。目前通过燃料舱 deco = "solar" 预览。
-- 肩部舱座（石墨 + 金色铆钉 + 青色状态灯缝）→ 旋转关节（金属盘 + 金环）→ 金属桁架臂（双导轨 + 斜撑）
-- → 铰链块 + 销轴 → 两段折叠翼板（银色金属框 + 3×2 反光电池片 + 青色顶边灯条，前倾 18°）→ 翼尖端盖 + 导航灯。
-- cf = 机身轴线上的挂点（朝向与部件一致），side = ±1。单侧伸出机身约 6.2 studs。
function B.fx.solarWing(cf, side, parent)
	local w = B.model("SolarWing", parent)
	local WF = cf * CFrame.new(side * 2.0, 0, 0) * CFrame.Angles(0, side > 0 and 0 or math.pi, 0) -- 本地 +X 朝外
	local MET = Enum.Material.Metal
	local function at(x, y, z) return WF * CFrame.new(x, y, z) end
	-- 肩部舱座
	B.box(Vector3.new(0.7, 1.0, 1.0), at(0.25, 0, 0), { Name = "Shoulder", Color = B.C.graphite }, w)
	B.box(Vector3.new(0.5, 0.06, 1.02), at(0.25, 0.35, 0), { Name = "ShoulderTrim", Color = B.C.elite }, w)
	for _, z in ipairs({ -0.52, 0.52 }) do
		for _, q in ipairs({ { 0.05, 0.3 }, { 0.45, 0.3 }, { 0.05, -0.3 }, { 0.45, -0.3 } }) do
			B.ball(0.14, at(q[1], q[2], z), { Name = "Bolt", Color = B.C.elite }, w)
		end
		B.box(Vector3.new(0.08, 0.45, 0.05), at(0.25, -0.02, z), { Name = "StatusSlit", Color = B.C.cyan, Material = NEON, Transparency = 0.25 }, w)
	end
	-- 旋转关节
	B.part({ Name = "Joint", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.28, 0.95, 0.95), CFrame = at(0.74, 0, 0), Color = B.C.metal, Material = MET }, w)
	B.part({ Name = "JointRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.08, 1.05, 1.05), CFrame = at(0.64, 0, 0), Color = B.C.elite }, w)
	-- 金属桁架臂
	local x0, x1 = 0.88, 2.35
	for _, y in ipairs({ -0.22, 0.22 }) do
		B.box(Vector3.new(x1 - x0, 0.14, 0.14), at((x0 + x1) / 2, y, 0), { Name = "Rail", Color = B.hex("C9D1E0"), Material = MET }, w)
	end
	for k = 0, 3 do
		local xa, xb = x0 + (x1 - x0) * k / 4, x0 + (x1 - x0) * (k + 1) / 4
		local ya = (k % 2 == 0) and -0.22 or 0.22
		B.beamBetween(at(xa, ya, 0).Position, at(xb, -ya, 0).Position, 0.07, 0.07, { Name = "Brace", Color = B.C.metal, Material = MET }, w)
	end
	-- 铰链块 + 销轴
	B.box(Vector3.new(0.3, 0.75, 0.5), at(2.48, 0, 0), { Name = "HingeBlock", Color = B.C.graphite }, w)
	B.part({ Name = "HingePin", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.9, 0.16, 0.16), CFrame = at(2.48, 0, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = B.C.metal, Material = MET }, w)
	-- 两段折叠翼板
	local PW, PH = 1.7, 1.4
	for k = 0, 1 do
		local P = at(2.63 + PW / 2 + k * (PW + 0.1), 0, 0) * CFrame.Angles(math.rad(18), 0, 0)
		B.box(Vector3.new(PW, PH, 0.1), P, { Name = "PanelFrame", Color = B.hex("B8C2D1"), Material = MET, Reflectance = 0.1 }, w)
		for c = -1, 1 do
			for r = -1, 1, 2 do
				B.box(Vector3.new(0.5, 0.6, 0.13), P * CFrame.new(c * 0.55, r * 0.33, 0), { Name = "Cell", Color = B.hex("2A45B8"), Material = Enum.Material.Glass, Reflectance = 0.4 }, w)
			end
		end
		B.box(Vector3.new(PW, 0.06, 0.14), P * CFrame.new(0, PH / 2 - 0.03, 0), { Name = "EdgeLight", Color = B.C.cyan, Material = NEON, Transparency = 0.35 }, w)
		if k == 0 then
			B.part({ Name = "PanelHinge", Shape = Enum.PartType.Cylinder, Size = Vector3.new(PH, 0.14, 0.14), CFrame = P * CFrame.new(PW / 2 + 0.05, 0, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = B.C.metal, Material = MET }, w)
		end
	end
	-- 翼尖端盖 + 导航灯
	local T = at(2.63 + 2 * PW + 0.16, 0, 0) * CFrame.Angles(math.rad(18), 0, 0)
	B.box(Vector3.new(0.12, PH + 0.1, 0.16), T, { Name = "EndCap", Color = B.C.graphite }, w)
	B.fx.orb(T * CFrame.new(0.1, PH / 2 + 0.1, 0), 0.26, B.C.cyan, w)
	return w
end

-- 能量电池舱（11-24 替换太阳能翼板）：挂在机身侧面的竖直胶囊舱，强调机械结构 + 能量感。
-- 石墨端盖 / 深色舱壳 / 三道青色能量环 / 外侧白色装甲肋 / 金色锁紧环 + 卡箍支臂 + 铆钉 / 斜向液压撑杆 /
-- 顶部发射极（小圆顶 + 天线 + 脉动光球）/ 底部微型喷口。单侧伸出机身约 1.8 studs。
-- cf = 部件底面中心（朝向与部件一致），side = ±1（左 / 右），y0 = 舱底高度，h = 舱高
function B.fx.powerCell(cf, side, y0, h, parent)
	local w = B.model("PowerCell", parent)
	local R0, D = 3.1, 1.3
	local pc = cf * CFrame.new(side * R0, y0, 0)
	B.cylAt(D + 0.14, 0, 0.3, pc, { Name = "Cap", Color = B.C.graphite }, w)
	B.cylAt(D, 0.3, h - 0.6, pc, { Name = "Shell", Color = B.C.graphite2 }, w)
	B.cylAt(D + 0.14, h - 0.3, 0.3, pc, { Name = "Cap", Color = B.C.graphite }, w)
	for i = 1, 3 do
		B.cylAt(D + 0.06, 0.3 + (h - 0.6) * i / 4 - 0.09, 0.18, pc, { Name = "EnergyRing", Color = B.C.cyan, Material = NEON, Transparency = 0.15 }, w)
	end
	B.box(Vector3.new(0.12, h - 0.9, 0.42), pc * CFrame.new(side * (D / 2), h / 2, 0), { Name = "ArmorRib", Color = B.C.white }, w)
	-- 锁紧环 + 卡箍支臂 + 铆钉
	for _, yy in ipairs({ 0.62, h - 0.62 }) do
		B.cylAt(D + 0.16, yy - 0.12, 0.24, pc, { Name = "ClampRing", Color = B.C.elite }, w)
		local a = (cf * CFrame.new(side * 1.95, y0 + yy, 0)).Position
		local b = (cf * CFrame.new(side * (R0 - D / 2 + 0.05), y0 + yy, 0)).Position
		B.beamBetween(a, b, 0.75, 0.42, { Name = "Bracket", Color = B.C.graphite }, w)
		for _, z in ipairs({ -0.25, 0.25 }) do
			B.ball(0.18, cf * CFrame.new(side * ((1.95 + R0 - D / 2) / 2), y0 + yy + 0.22, z), { Name = "Bolt", Color = B.C.elite }, w)
		end
	end
	-- 斜向液压撑杆（正面一侧）
	local p0 = (cf * CFrame.new(side * 2.0, y0 + h * 0.3, 0.5)).Position
	local p1 = (cf * CFrame.new(side * (R0 - D / 2), y0 + h * 0.62, 0.5)).Position
	local mid = p0:Lerp(p1, 0.55)
	B.beamBetween(p0, mid, 0.26, 0.26, { Name = "PistonSleeve", Color = B.C.graphite }, w)
	B.beamBetween(mid, p1, 0.13, 0.13, { Name = "PistonRod", Color = B.C.metal }, w)
	-- 顶部发射极
	B.dome(D - 0.1, 0.45, pc * CFrame.new(0, h, 0), { Name = "EmitterDome", Color = B.C.graphite2 }, w)
	B.cylAt(0.1, h + 0.35, 0.7, pc, { Name = "Antenna", Color = B.C.metal }, w)
	B.fx.orb(pc * CFrame.new(0, h + 1.1, 0), 0.28, B.C.cyan, w)
	-- 底部微型喷口
	B.cone(0.95, 0.65, pc * CFrame.Angles(math.pi, 0, 0), { Name = "Nozzle", Color = B.C.nozzle }, w)
	B.cylAt(0.98, -0.08, 0.08, pc, { Name = "NozzleGlow", Color = B.C.cyan, Material = NEON, Transparency = 0.3 }, w)
	return w
end

---------------------------------------------------------------- 鼻锥
-- 子弹头：圆锥 + 下部半椭球肩部（让锥底鼓起来，接近原画的圆锥子弹头）。cf = 底面中心，直径 4
local function ogive(cf, h, color, parent)
	B.cone(4, h, cf, { Name = "Shell", Color = color }, parent)
	B.dome(4, h * 0.42, cf, { Name = "Shoulder", Color = color }, parent)
end

function B.nose(tier, cf, parent)
	local m = B.model("Nose", parent)
	local H = B.NOSE_H[tier]
	B.cylAt(4.3, 0, 0.3, cf, { Name = "Collar", Color = B.C.graphite }, m)
	if tier == 1 then
		-- 基础：白色子弹头（圆锥 + 鼓起的肩部）
		local h = H - 0.3
		local base = cf * CFrame.new(0, 0.3, 0)
		ogive(base, h, B.C.white, m)
		local y = 1.0
		porthole(base, y, 2 * (1 - 0.925 * y / h), math.atan(1.85 / h), m)
		B.ball(0.42, base * CFrame.new(0, h - 0.12, 0), { Name = "Tip", Color = B.C.graphite }, m)
	elseif tier == 2 then
		-- 气动：白色尖锥 + 蓝色锥尖 + 蓝色底环 + 两片导流小翼 + 尖针
		local h = H - 0.3
		local base = cf * CFrame.new(0, 0.3, 0)
		B.cone(4, h, base, { Name = "Shell", Color = B.C.white }, m)
		-- 圆锥网格实测：r(t) = R·(1 − 0.925 t)，尖顶截平。蓝色锥尖从 58% 高度开始，
		-- 斜率不能比主锥陡，否则会缩进主锥面：h_tip ≥ 1.85 · R_tip
		local y0 = h * 0.58
		local rTip = 2 * (1 - 0.925 * 0.58) + 0.05
		local hTip = 1.85 * rTip + 0.02
		B.cone(rTip * 2, hTip, base * CFrame.new(0, y0, 0), { Name = "TipCone", Color = B.C.adv }, m)
		B.cylAt(4.16, 0.3, 0.32, cf, { Name = "Band", Color = B.C.adv }, m)
		for _, s in ipairs({ -1, 1 }) do -- 侧面导流小翼：楔形高边朝外
			local a = s * math.pi / 2
			local d = Vector3.new(math.sin(a), 0, math.cos(a))
			local p = d * 1.85 + Vector3.new(0, 1.15, 0)
			B.wedge(Vector3.new(0.16, 1.3, 0.8), cf * CFrame.lookAt(p, p - d), { Name = "Strake", Color = B.C.adv }, m)
		end
		local top = 0.3 + y0 + hTip
		B.cylAt(0.16, top - 0.1, 0.55, cf, { Name = "Spike", Color = B.C.adv }, m)
		B.ball(0.24, cf * CFrame.new(0, top + 0.47, 0), { Name = "SpikeTip", Color = B.C.white }, m)
		local y = 0.7
		porthole(base, y, 2 * (1 - 0.925 * y / h), math.atan(1.85 / h), m)
	else
		-- 黄金：金色子弹头 + 发光底环 + 6 道竖棱 + 金框舷窗 + 白色顶灯
		local h = H - 0.45
		local base = cf * CFrame.new(0, 0.45, 0)
		B.cylAt(4.2, 0.3, 0.15, cf, { Name = "Glow", Color = B.hex("FFE08A"), Material = NEON, Transparency = 0.2 }, m)
		ogive(base, h, B.C.elite, m)
		for i = 0, 5 do
			local a = math.rad(30 + 60 * i)
			local d = Vector3.new(math.sin(a), 0, math.cos(a))
			local function surf(t) -- 锥面上 t 高度处的点（略向外 0.04）
				local y = h * t
				return (base * CFrame.new(d * (2 * (1 - 0.925 * t) + 0.04) + Vector3.new(0, y, 0))).Position
			end
			B.beamBetween(surf(0.38), surf(0.8), 0.2, 0.14, { Name = "Ridge", Color = B.C.eliteDark }, m)
		end
		local y = 0.75
		porthole(base, y, 2 * (1 - 0.925 * y / h), math.atan(1.85 / h), m, B.C.eliteDark)
		B.cylAt(0.75, h + 0.45 - 0.2, 0.22, cf, { Name = "TipBase", Color = B.C.eliteDark }, m)
		local tl = B.ball(0.62, cf * CFrame.new(0, H + 0.28, 0), { Name = "TipLight", Color = Color3.new(1, 1, 1), Material = NEON }, m)
		-- 科技装饰：倾斜的金色全息环（旋转）+ 顶灯闪光
		B.fx.sparkles(tl, B.hex("FFE08A"), 3, 0.35)
		B.fx.haloRing(cf * CFrame.new(0, H * 0.42, 0) * CFrame.Angles(math.rad(14), 0, 0), 2.7, 18, B.hex("FFD45A"), 1.2, m)
	end
	m:SetAttribute("Height", H)
	return m
end

---------------------------------------------------------------- 燃料舱
-- deco：第三档装饰，"cell"（默认，能量电池舱）或 "solar"（太阳能翼板）
function B.tank(tier, cf, homeColor, parent, deco)
	local m = B.model("Tank", parent)
	local H = B.TANK_H[tier]
	-- 底部倒角端盖 → 白色机身 → 顶部倒角 → 接口环
	B.cylAt(4.3, 0, 0.35, cf, { Name = "Cap", Color = B.C.graphite }, m)
	B.cylAt(4.12, 0.35, 0.15, cf, { Name = "Bevel", Color = B.C.graphite2 }, m)
	B.cylAt(4, 0.5, H - 1.0, cf, { Name = "Body", Color = B.C.white }, m)
	B.cylAt(4.12, H - 0.5, 0.15, cf, { Name = "Bevel", Color = B.C.graphite2 }, m)
	ring(cf, H - 0.35, m)
	band(cf, H - 1.05, 0.35, homeColor, m) -- 燃料舱顶一圈家园色
	if tier == 1 then
		band(cf, 1.0, 0.4, B.C.basic, m)
		around(cf, { 0, 90, 180, 270 }, 2.03, 2.0, Vector3.new(0.5, 0.5, 0.12), { Name = "Rivet", Color = B.C.basic }, m)
	elseif tier == 2 then
		band(cf, H * 0.28, 0.5, B.C.adv, m)
		band(cf, H * 0.52, 0.5, B.C.adv, m)
		around(cf, { -38, 38 }, 2.03, H * 0.5, Vector3.new(0.2, H - 2.6, 0.1), { Name = "Glow", Color = B.hex("5FB8FF"), Material = NEON, Transparency = 0.2 }, m)
		-- 水滴徽标
		local c = cf * CFrame.new(0, H * 0.74, 1.98)
		B.discZ(1.2, 0.16, c, { Name = "Emblem", Color = B.C.adv }, m)
		B.ball(0.42, c * CFrame.new(0, -0.08, 0.1), { Name = "Drop", Color = B.C.white }, m)
		B.cone(0.36, 0.36, c * CFrame.new(0, 0.02, 0.1), { Name = "Drop", Color = B.C.white }, m)
	else
		for _, f in ipairs({ 0.3, 0.45, 0.6 }) do band(cf, H * f, 0.5, B.C.elite, m) end
		-- 四根卡箍（石墨）+ 金色发光槽
		around(cf, { 45, 135, 225, 315 }, 2.1, H / 2, Vector3.new(0.7, H - 1.6, 0.4), { Name = "Clamp", Color = B.C.graphite }, m)
		around(cf, { 45, 135, 225, 315 }, 2.3, H / 2, Vector3.new(0.18, H - 3.0, 0.08), { Name = "Glow", Color = B.hex("FFD45A"), Material = NEON, Transparency = 0.2 }, m)
		around(cf, { 45, 135, 225, 315 }, 2.25, 1.0, Vector3.new(0.9, 0.5, 0.3), { Name = "ClampFoot", Color = B.C.graphite2 }, m)
		around(cf, { 45, 135, 225, 315 }, 2.25, H - 1.15, Vector3.new(0.9, 0.5, 0.3), { Name = "ClampFoot", Color = B.C.graphite2 }, m)
		-- 科技装饰：左右能量电池舱 + 包住电池舱、反向旋转的青色全息环
		if deco == "solar" then
			B.fx.solarWing(cf * CFrame.new(0, H * 0.78, 0), 1, m)
			B.fx.solarWing(cf * CFrame.new(0, H * 0.78, 0), -1, m)
			B.fx.haloRing(cf * CFrame.new(0, H * 0.5, 0) * CFrame.Angles(math.rad(-8), 0, 0), 2.95, 22, B.C.cyan, -0.8, m)
		else
			B.fx.powerCell(cf, 1, H * 0.3, 3.4, m)
			B.fx.powerCell(cf, -1, H * 0.3, 3.4, m)
			B.fx.haloRing(cf * CFrame.new(0, H * 0.55, 0) * CFrame.Angles(math.rad(-8), 0, 0), 4.3, 28, B.C.cyan, -0.8, m)
		end
	end
	m:SetAttribute("Height", H)
	return m
end

---------------------------------------------------------------- 发动机
function B.engine(tier, cf, parent)
	local m = B.model("Engine", parent)
	local H = B.ENGINE_H[tier]
	local nozzleCol = ({ B.C.nozzle, B.hex("4A5270"), B.C.graphite2 })[tier]
	-- 喷管钟罩：圆锥尖藏进外壳，只露出下部的截头锥
	B.cone(3.1, 2.7, cf, { Name = "Nozzle", Color = nozzleCol }, m)
	B.cylAt(3.18, 0, 0.12, cf, { Name = "NozzleLip", Color = FLAME[tier], Material = NEON, Transparency = 0.25 }, m)
	local core = B.cylAt(2.3, -0.02, 0.05, cf, { Name = "NozzleCore", Color = FLAME[tier], Material = NEON, Transparency = 0.1 }, m)
	-- 阶梯外壳
	B.cylAt(3.2, 1.1, 0.5, cf, { Name = "Housing", Color = B.C.graphite }, m)
	B.cylAt(3.8, 1.6, 0.3, cf, { Name = "Housing", Color = B.C.graphite2 }, m)
	B.cylAt(4, 1.9, H - 2.25, cf, { Name = "Body", Color = B.C.white }, m)
	ring(cf, H - 0.35, m)
	if tier == 1 then
		band(cf, 2.05, 0.28, B.C.basic, m)
	elseif tier == 2 then
		glow(cf, 1.2, 0.08, FLAME[2], m, 3.26)
		glow(cf, 1.42, 0.08, FLAME[2], m, 3.26)
		band(cf, H - 0.85, 0.35, B.C.adv, m)
		around(cf, { 0, 45, 90, 135, 180, 225, 270, 315 }, 2.02, 2.25, Vector3.new(0.42, 0.34, 0.14), { Name = "Vent", Color = B.C.graphite }, m)
	else
		glow(cf, 1.3, 0.12, FLAME[3], m, 3.26)
		band(cf, 1.95, 0.22, B.C.elite, m)
		glow(cf, 2.25, 0.35, FLAME[3], m)
		band(cf, 2.68, 0.22, B.C.elite, m)
		around(cf, { 45, 135, 225, 315 }, 1.95, 1.75, Vector3.new(0.9, 1.3, 0.45), { Name = "Armor", Color = B.C.elite }, m)
		around(cf, { 45, 135, 225, 315 }, 2.2, 1.75, Vector3.new(0.5, 0.8, 0.1), { Name = "ArmorPlate", Color = B.C.eliteDark }, m)
		-- 科技装饰：能量线圈 + 两侧小推进舱 + 喷口紫色能量粒子
		for _, y in ipairs({ 1.15, 1.48 }) do glow(cf, y, 0.06, FLAME[3], m, 3.3) end
		for _, s in ipairs({ -1, 1 }) do
			local pc = cf * CFrame.new(s * 2.35, 0, 0)
			B.cylAt(0.8, 1.0, 1.3, pc, { Name = "Pod", Color = B.C.graphite }, m)
			B.cylAt(0.6, 2.3, 0.25, pc, { Name = "PodCap", Color = B.C.elite }, m)
			B.cylAt(0.86, 0.9, 0.12, pc, { Name = "PodGlow", Color = FLAME[3], Material = NEON, Transparency = 0.2 }, m)
		end
		B.fx.sparkles(core, FLAME[3], 6, 0.3)
	end
	m:SetAttribute("Height", H)
	return m
end

---------------------------------------------------------------- 尾翼（cf = 燃料舱底面中心，4 片 45° 分布）
function B.fins(tier, cf, parent)
	local m = B.model("Fins", parent)
	for i = 0, 3 do
		local a = math.rad(45 + 90 * i)
		local d = Vector3.new(math.sin(a), 0, math.cos(a))
		local function at(radial, y) -- 本地 Z 指向机身（楔形高边朝内）
			local p = d * radial + Vector3.new(0, y, 0)
			return cf * CFrame.lookAt(p, p + d)
		end
		if tier == 1 then
			B.box(Vector3.new(0.5, 2.8, 0.35), at(2.1, 0.0), { Name = "Root", Color = B.C.graphite }, m)
			B.box(Vector3.new(0.36, 2.2, 1.5), at(2.85, -0.3), { Name = "Fin", Color = B.C.basic }, m)
			B.wedge(Vector3.new(0.36, 1.6, 1.5), at(2.85, 1.6), { Name = "Fin", Color = B.C.basic }, m)
		elseif tier == 2 then
			B.box(Vector3.new(0.5, 3.6, 0.35), at(2.1, -0.2), { Name = "Root", Color = B.C.graphite }, m)
			B.box(Vector3.new(0.36, 1.6, 2.2), at(3.2, -1.3), { Name = "Fin", Color = B.C.adv }, m)
			B.wedge(Vector3.new(0.36, 3.0, 2.2), at(3.2, 1.0), { Name = "Fin", Color = B.C.adv }, m)
			B.box(Vector3.new(0.4, 3.2, 0.45), at(2.45, -0.6), { Name = "Stripe", Color = B.C.white }, m)
		else
			B.box(Vector3.new(0.35, 0.35, 0.9), at(2.45, 1.2), { Name = "Strut", Color = B.C.graphite }, m)
			B.box(Vector3.new(0.22, 1.9, 1.9), at(3.85, 1.2), { Name = "GridFrame", Color = B.C.graphite }, m)
			for _, o in ipairs({ -0.62, 0, 0.62 }) do
				B.box(Vector3.new(0.3, 0.14, 1.9), at(3.85, 1.2 + o), { Name = "Grid", Color = B.C.elite }, m)
				B.box(Vector3.new(0.3, 1.9, 0.14), at(3.85 + o, 1.2), { Name = "Grid", Color = B.C.elite }, m)
			end
			for _, o in ipairs({ -0.92, 0.92 }) do
				B.box(Vector3.new(0.3, 0.14, 1.9), at(3.85, 1.2 + o), { Name = "Grid", Color = B.C.elite }, m)
				B.box(Vector3.new(0.3, 1.9, 0.14), at(3.85 + o, 1.2), { Name = "Grid", Color = B.C.elite }, m)
			end
			B.fx.orb(at(4.85, 2.15), 0.42, B.hex("E8C8FF"), m) -- 科技装饰：格栅外角脉动光球
		end
	end
	return m
end

-- 整箭：eq = { nose, tank, engine, fins }（档次 1–3）；cf = 发动机底面中心
function B.rocket(eq, homeColor, cf, parent)
	local m = B.model("Rocket", parent)
	local y = 0
	B.engine(eq.engine, cf, m)
	y += B.ENGINE_H[eq.engine]
	B.tank(eq.tank, cf * CFrame.new(0, y, 0), homeColor, m, eq.deco)
	B.fins(eq.fins, cf * CFrame.new(0, y, 0), m)
	y += B.TANK_H[eq.tank]
	B.nose(eq.nose, cf * CFrame.new(0, y, 0), m)
	y += B.NOSE_H[eq.nose]
	m:SetAttribute("Height", y)
	for k, v in pairs(eq) do m:SetAttribute(k, v) end
	m.WorldPivot = cf -- 轴心 = 发动机底面中心，运行时 PivotTo / ScaleTo 以它为准
	return m
end

-- 全息化：半透明 Neon。
-- 原定用 ForceField，但放在组装舱玻璃后面时 ForceField / Glass 背后的半透明物体都不渲染，改用 Neon 0.72。
function B.holo(inst, color)
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Material = Enum.Material.Neon
			d.Transparency = 0.72
			d.Color = color
			d.CastShadow = false
			B.deco(d)
		end
	end
	return inst
end

return B
