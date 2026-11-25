--[[
	OrbitGate · 正式版轨道门（ReplicatedStorage.OrbitShared.OrbitGate）
	金色门环 + 内圈光边 + 四个科技卡座 + 光晕；虚线目标框 + 收缩光圈（判定提示）。
	状态：normal 金 / boost 紫（星尘增幅）/ fever 彩虹并放大 1.6 倍（轨道狂热）/ locked 灰紫（木星未解锁）。
	G.build(cf, R, parent, name)：cf = 门心，门环在本地 XY 平面，−Z = 飞行方向；R = 门半径（月球 9.1、木星 14.3）。
	G.setActive(gate, on)：显示虚线目标框（下一道要过的门）。
	G.setShrink(gate, k)：收缩光圈半径 = R × k（k 从约 2.6 收到 1 = 判定时刻）；k = nil 隐藏。
	光边、光晕、目标框、收缩光圈用 CylinderHandleAdornment（不受光照，像发光体），门环本体是零件。
]]

local B = require(script.Parent.BuildLib)
local hex = B.hex
local C = B.C
local V = Vector3.new
local NEON = Enum.Material.Neon
local CS = game:GetService("CollectionService")

local G = {}
G.FEVER_SCALE = 1.6
G.SEGS = 24
G.COLORS = {
	normal = { tube = hex("FFC93C"), edge = hex("FFB000"), glow = hex("FFF3C8"), dot = hex("FFF1B8") },
	boost = { tube = hex("B98CFF"), edge = hex("A46BFF"), glow = hex("EADFFF"), dot = hex("F0E2FF") },
	fever = { tube = hex("FFC93C"), edge = hex("FFB000"), glow = hex("FFF3C8"), dot = hex("FFFFFF") },
	locked = { tube = hex("6E6A8C"), edge = hex("8C84B8"), glow = hex("8C84B8"), dot = hex("8C84B8") },
}

local function adorn(anchor, name, radius, inner, height, color, tr, angle, cf)
	local a = Instance.new("CylinderHandleAdornment")
	a.Name = name
	a.Adornee = anchor
	a.Radius = radius
	a.InnerRadius = inner
	a.Height = height
	a.Angle = angle or 360
	a.CFrame = cf or CFrame.identity
	a.Color3 = color
	a.Transparency = tr
	a.AlwaysOnTop = false
	a.ZIndex = 0
	a:SetAttribute("R0", radius)
	a:SetAttribute("IR0", inner)
	a:SetAttribute("H0", height)
	a:SetAttribute("T0", tr)
	a.Parent = anchor
	return a
end

function G.build(cf, R, parent, name)
	local m = B.model(name or "OrbitGate")
	local t = R * 0.13 -- 门环管径
	local col = G.COLORS.normal
	-- 门环：圆柱段 + 关节球
	local ring = B.model("Ring", m)
	local N = G.SEGS
	local function at(a, r) return (cf * CFrame.new(math.cos(a) * r, math.sin(a) * r, 0)).Position end
	for i = 0, N - 1 do
		local a0, a1 = i / N * math.pi * 2, (i + 1) / N * math.pi * 2
		local p0, p1 = at(a0, R), at(a1, R)
		local len = (p1 - p0).Magnitude + t * 0.15
		B.part({ Name = "Tube", Shape = Enum.PartType.Cylinder, Size = V(len, t, t), CFrame = CFrame.lookAt((p0 + p1) / 2, p1) * CFrame.Angles(0, math.pi / 2, 0), Color = col.tube, Reflectance = 0.08 }, ring)
		B.ball(t * 1.02, CFrame.new(p0), { Name = "Tube", Color = col.tube, Reflectance = 0.08 }, ring)
	end
	-- 四个科技卡座（45° 方向）：石墨块 + 金色盖板 + 小光点
	for k = 0, 3 do
		local a = math.rad(45 + 90 * k)
		local P = CFrame.new(at(a, R)) * (cf - cf.Position) * CFrame.Angles(0, 0, a)
		B.box(V(t * 1.6, t * 1.5, t * 1.7), P, { Name = "Clamp", Color = C.graphite }, ring)
		B.box(V(t * 0.5, t * 1.62, t * 1.8), P * CFrame.new(t * 0.6, 0, 0), { Name = "ClampCap", Color = col.tube }, ring)
		B.ball(t * 0.42, P * CFrame.new(t * 0.92, 0, 0), { Name = "Dot", Color = col.dot, Material = NEON, CastShadow = false }, ring)
	end
	B.decoAll(ring)

	local core = B.part({ Name = "GateCore", Size = V(0.3, 0.3, 0.3), CFrame = cf, Transparency = 1, CastShadow = false }, m)
	B.deco(core)
	adorn(core, "Edge", R - t * 0.42, R - t * 0.62, t * 0.5, col.edge, 0.05)
	adorn(core, "Glow", R + t * 1.5, R + t * 0.55, 0.06, col.glow, 0.88) -- 光晕用浅色 + 高透明：Roblox 是普通混合，饱和金色叠在夜空上会发褐
	adorn(core, "GlowOuter", R + t * 3.2, R + t * 1.5, 0.05, col.glow, 0.94)
	-- 虚线目标框：门外沿一圈 16 段短弧
	local n = 16
	for i = 0, n - 1 do
		local deg = 360 / n
		adorn(core, "Target", R + t * 1.25, R + t * 0.95, 0.12, Color3.new(1, 1, 1), 0.15, deg * 0.55, CFrame.Angles(0, 0, math.rad(i * deg)))
	end
	adorn(core, "Shrink", R * 2.4, R * 2.4 - t * 0.35, 0.12, Color3.new(1, 1, 1), 0.1)

	m.WorldPivot = cf
	m:SetAttribute("Radius", R)
	m.Parent = parent
	G.setState(m, "normal")
	G.setActive(m, false)
	G.setShrink(m, nil)
	return m
end

local function adorns(m, name)
	local out = {}
	local core = m:FindFirstChild("GateCore")
	for _, a in ipairs(core:GetChildren()) do
		if a.Name == name then table.insert(out, a) end
	end
	return out
end

local function sizeAdorns(m, s)
	for _, a in ipairs(m.GateCore:GetChildren()) do
		if a:IsA("CylinderHandleAdornment") and a.Name ~= "Shrink" then
			a.Radius = a:GetAttribute("R0") * s
			a.InnerRadius = a:GetAttribute("IR0") * s
			a.Height = a:GetAttribute("H0") * s
		end
	end
end

function G.setState(m, state)
	local col = G.COLORS[state] or G.COLORS.normal
	local fever = state == "fever"
	local s = fever and G.FEVER_SCALE or 1
	if math.abs(m:GetScale() - s) > 1e-3 then m:ScaleTo(s) end
	sizeAdorns(m, s)
	for _, p in ipairs(m.Ring:GetChildren()) do
		if p.Name == "Tube" or p.Name == "ClampCap" then
			p.Color = col.tube
			if fever then CS:AddTag(p, "RainbowFX") else CS:RemoveTag(p, "RainbowFX") end
		elseif p.Name == "Dot" then
			p.Color = col.dot
		end
	end
	for _, a in ipairs(m.GateCore:GetChildren()) do
		if a.Name == "Edge" or a.Name == "Glow" or a.Name == "GlowOuter" then
			a.Color3 = (a.Name == "Edge") and col.edge or col.glow
			local t0 = a:GetAttribute("T0")
			a.Transparency = (state == "locked") and math.min(1, t0 + 0.4) or (fever and math.max(0, t0 - 0.15) or t0)
			if fever then CS:AddTag(a, "RainbowFX") else CS:RemoveTag(a, "RainbowFX") end
			a:SetAttribute("RainbowOffset", a.Name == "Edge" and 0.4 or 0.1)
		end
	end
	m:SetAttribute("State", state)
end

function G.setActive(m, on)
	for _, a in ipairs(adorns(m, "Target")) do a.Visible = on end
	m:SetAttribute("Active", on)
end

function G.setShrink(m, k)
	local sh = adorns(m, "Shrink")[1]
	if not sh then return end
	if k == nil then
		sh.Visible = false
		return
	end
	local R = m:GetAttribute("Radius") * m:GetScale()
	local w = sh:GetAttribute("R0") - sh:GetAttribute("IR0")
	sh.Radius = R * k
	sh.InnerRadius = R * k - w
	sh.Visible = true
end

return G
