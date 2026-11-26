--[[
	JupiterReveal · P1 第 18 项 木星解锁演出（ReplicatedStorage.OrbitShared.JupiterReveal）
	客户端本地（解锁是每个玩家自己的进度）。木星由 03_planets 建：Body / Band ×8 / RedSpot / RedSpotCore（锁定态暗色）、
	Shield（ForceField 紫色护盾）+ ShieldGlow、LabelAnchor（「木星 · 已锁定」牌）、OrbitDash（淡紫虚线）、OrbitGate（locked）。
	演出（约 4.6 s，Web Demo startReveal / updateReveal）：
	  0–1.8    护盾呼吸闪烁越来越快（外发光忽明忽暗）
	  1.8      裂开：护盾发白、表面爬出一圈白色裂纹（朝镜头一侧）、紫色闪屏、镜头轻震
	  1.8–2.35 护盾抖动（±2%）
	  2.35     碎裂：护盾消失，碎成约 300 颗紫 / 金 / 白 / 橙光点向外飞散；金 / 紫两层冲击环（朝镜头）；暖白闪屏、震动
	  2.35–3.8 木星从暗色恢复全彩（饱和度 ×1.35、亮度 ×1.4），三层行星环（在轨道内侧，倾斜）从 0.5 倍展开到原大并淡入；
	           锁定牌隐藏，轨道门 locked → normal，轨道虚线变成和月球一样的白色
	  opts.camera = true：演出期间镜头移到能看全木星的位置，结束后还给玩家
	J.setUnlocked(u)：0 锁定 / 1 解锁（读档时直接设）；J.reset()：恢复锁定（演示用）；J.play(opts)：完整演出（阻塞）
]]

local B = require(script.Parent.BuildLib)
local O = require(script.Parent.Orbits)
local G = require(script.Parent.OrbitGate)
local FX = require(script.Parent.ShowFX)
local Players = game:GetService("Players")

local V = Vector3.new
local hex = B.hex
local J = {}
local JB = O.bodies.jupiter
local RINGS = { -- { 内径, 外径, 颜色, 不透明度 }（× 星球半径，Web Demo jRings）
	{ 1.12, 1.25, hex("E8C79A"), 0.6 },
	{ 1.28, 1.39, hex("C98D5B"), 0.42 },
	{ 1.42, 1.49, hex("F3E2C6"), 0.3 },
}
local RING_TILT = CFrame.Angles(math.pi / 2 - 0.38, 0, 0.2)
local LAVENDER, GOLD = hex("B8A8FF"), hex("FFE680")

local function clamp01(x) return math.clamp(x, 0, 1) end
local function smooth(x)
	x = clamp01(x)
	return x * x * (3 - 2 * x)
end

local function model()
	local w = workspace:FindFirstChild("OrbitWorld")
	local p = w and w:FindFirstChild("Planets")
	return p and p:FindFirstChild("Jupiter")
end

local function folder()
	local f = workspace:FindFirstChild("_ShowFX")
	if not f then
		f = Instance.new("Folder")
		f.Name = "_ShowFX"
		f.Archivable = false
		f.Parent = workspace
	end
	return f
end

-- 记下锁定态颜色，算出解锁态颜色（饱和度、亮度提高）
-- 锁定原色第一次读到时存进属性 Locked*，之后都从属性取：重复 require / 中途解锁后再 capture 也不会把解锁色当原色
local function keep(p, attr, cur)
	local v = p:GetAttribute(attr)
	if v == nil then
		p:SetAttribute(attr, cur)
		v = cur
	end
	return v
end
local state
local function capture()
	local m = model()
	if not m then return nil end
	if state and state.m == m then return state end
	state = { m = m, parts = {}, dashes = {} }
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("BasePart") then
			if p.Name == "Body" or p.Name == "Band" or p.Name == "RedSpot" or p.Name == "RedSpotCore" then
				local c0 = keep(p, "LockedColor", p.Color)
				local h, s, v = c0:ToHSV()
				local boost = (p.Name == "RedSpot" or p.Name == "RedSpotCore") and 1.6 or 1.35
				table.insert(state.parts, { p = p, c0 = c0, c1 = Color3.fromHSV(h, math.min(1, s * boost), math.min(1, v * 1.4)) })
			elseif p.Name == "OrbitDash" then
				table.insert(state.dashes, { p = p, c0 = keep(p, "LockedColor", p.Color), t0 = keep(p, "LockedT", p.Transparency) })
			end
		end
	end
	state.shield, state.glow = m:FindFirstChild("Shield"), m:FindFirstChild("ShieldGlow")
	if state.shield then
		state.shieldSize = keep(state.shield, "LockedSize", state.shield.Size)
		state.shieldColor = keep(state.shield, "LockedColor", state.shield.Color)
	end
	if state.glow then
		state.glowT = keep(state.glow, "LockedT", state.glow.Transparency)
		state.glowColor = keep(state.glow, "LockedColor", state.glow.Color)
	end
	local la = m:FindFirstChild("LabelAnchor")
	state.label = la and la:FindFirstChildOfClass("BillboardGui")
	state.gate = m:FindFirstChild("OrbitGate")
	-- 行星环（本地生成）
	local an = Instance.new("Part")
	an.Name = "JupiterRings"
	an.Anchored, an.CanCollide, an.CanQuery, an.CanTouch, an.CastShadow = true, false, false, false, false
	an.Transparency = 1
	an.Size = V(1, 1, 1)
	an.CFrame = CFrame.new(JB.c) * RING_TILT
	an.Parent = folder()
	state.rings = {}
	for _, r in ipairs(RINGS) do
		local a = Instance.new("CylinderHandleAdornment")
		a.Adornee = an
		a.Height = 0.6
		a.Color3 = r[3]
		a.ZIndex = 0
		a.Parent = an
		table.insert(state.rings, { a = a, r = r })
	end
	state.ringAnchor = an
	return state
end

-- u：0 锁定 → 1 解锁（颜色、行星环、虚线）；护盾 / 牌 / 门在 J.setUnlocked 里按 u ≥ 1 切换
local function applyColors(st, u)
	for _, e in ipairs(st.parts) do e.p.Color = e.c0:Lerp(e.c1, u) end
	for _, e in ipairs(st.rings) do
		local k = 0.5 + 0.5 * smooth(u)
		e.a.Radius = JB.r * e.r[2] * k
		e.a.InnerRadius = JB.r * e.r[1] * k
		e.a.Transparency = 1 - e.r[4] * u
		e.a.Visible = u > 0.01
	end
	for _, e in ipairs(st.dashes) do
		e.p.Color = e.c0:Lerp(Color3.new(1, 1, 1), u)
		e.p.Transparency = e.t0 + (0.45 - e.t0) * u
	end
end

-- 轨道门：客户端可能还没流式加载完（Jupiter 模型已设 Persistent，这里再兜底等一下）
local function setGate(st, s)
	local g = st.gate
	if not g then return end
	task.spawn(function()
		if g:WaitForChild("Ring", 10) and g:WaitForChild("GateCore", 10) then
			local ok, e = pcall(G.setState, g, s)
			if not ok then warn("[JupiterReveal] gate", e) end
		end
	end)
end

function J.setUnlocked(u)
	local st = capture()
	if not st then return end
	applyColors(st, u)
	local on = u >= 1
	if st.shield then st.shield.LocalTransparencyModifier = on and 1 or 0 end
	if st.glow then st.glow.LocalTransparencyModifier = on and 1 or 0 end
	if st.label then st.label.Enabled = not on end
	setGate(st, on and "normal" or "locked")
end

function J.reset()
	local st = capture()
	if not st then return end
	if st.shield then st.shield.Size, st.shield.Color = st.shieldSize, st.shieldColor end
	if st.glow then st.glow.Transparency, st.glow.Color = st.glowT, st.glowColor end
	J.setUnlocked(0)
end

------------------------------------------------------------------ 闪屏（本地 ScreenGui）
local function screenFlash(color, alpha, dur)
	local plr = Players.LocalPlayer
	local pg = plr and plr:FindFirstChildOfClass("PlayerGui")
	if not pg then return end
	local g = Instance.new("ScreenGui")
	g.Name = "ShowFlash"
	g.IgnoreGuiInset = true
	g.DisplayOrder = 50
	g.ResetOnSpawn = false
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = 1 - alpha
	f.BorderSizePixel = 0
	f.Parent = g
	g.Parent = pg
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < dur do
			f.BackgroundTransparency = 1 - alpha * (1 - (os.clock() - t0) / dur)
			task.wait()
		end
		g:Destroy()
	end)
end

-- 护盾表面的裂纹：朝镜头一侧的球面上随机长几条折线
local function cracks(center, radius, toward)
	local parts = {}
	local n = toward.Unit
	local ref = math.abs(n.Y) < 0.9 and Vector3.yAxis or Vector3.xAxis
	local u = n:Cross(ref).Unit
	local w = n:Cross(u).Unit
	for i = 1, 9 do
		local a = i / 9 * math.pi * 2 + math.random() * 0.4
		local d = (u * math.cos(a) + w * math.sin(a))
		local p = n * 0.2
		for _ = 1, 5 do
			local q = (p + d * (0.13 + math.random() * 0.08) + (u * (math.random() - 0.5) + w * (math.random() - 0.5)) * 0.08)
			local A = center + p.Unit * radius
			local Bp = center + q.Unit * radius
			local s = Instance.new("Part")
			s.Name = "ShieldCrack"
			s.Anchored, s.CanCollide, s.CanQuery, s.CanTouch, s.CastShadow = true, false, false, false, false
			s.Material = Enum.Material.Neon
			s.Color = Color3.new(1, 1, 1)
			s.Size = V(1.4, 1.4, (Bp - A).Magnitude)
			s.CFrame = CFrame.lookAt((A + Bp) / 2, Bp)
			s.Parent = folder()
			table.insert(parts, s)
			p = q
		end
	end
	return parts
end

------------------------------------------------------------------ 完整演出
function J.play(opts)
	opts = opts or {}
	local st = capture()
	if not st then return end
	J.reset()
	local cam = workspace.CurrentCamera
	local c, r = JB.c, JB.r
	local camFrom, camType
	local view
	if opts.camera and cam then
		camFrom, camType = cam.CFrame, cam.CameraType
		local dir = (V(0, 40, 80) * O.S - c).Unit
		view = CFrame.lookAt(c + dir * r * 4.6 + V(0, r * 0.5, 0), c)
		cam.CameraType = Enum.CameraType.Scriptable
	end
	local camPos = function() return cam and cam.CFrame.Position or (c + V(0, 0, 400)) end
	local DUR = 4.6
	local t0 = os.clock()
	local stage, crackParts = 0, nil
	while true do
		local t = os.clock() - t0
		-- 镜头
		if view then
			local k = smooth(t / 1.2) * (1 - smooth((t - (DUR - 0.6)) / 0.6))
			cam.CFrame = camFrom:Lerp(view, k)
		end
		-- 0–1.8 护盾呼吸闪烁
		if stage == 0 then
			local f = 3 + t * 6
			if st.glow then st.glow.Transparency = 0.95 - 0.12 * (0.5 + 0.5 * math.sin(t * f)) end
			if t >= 1.8 then
				stage = 1
				crackParts = cracks(c, r * 1.22, camPos() - c)
				if st.glow then st.glow.Color = Color3.new(1, 1, 1) st.glow.Transparency = 0.8 end
				if st.shield then st.shield.Color = Color3.new(1, 1, 1) end
				screenFlash(LAVENDER, 0.35, 0.5)
				FX.shake(camPos(), 0.4, 0.3)
			end
		end
		-- 1.8–2.35 抖动
		if stage == 1 then
			local j = 1 + math.sin(t * 70) * 0.02
			if st.shield then st.shield.Size = st.shieldSize * j end
			if t >= 2.35 then
				stage = 2
				for _, p in ipairs(crackParts) do p:Destroy() end
				if st.shield then st.shield.LocalTransparencyModifier = 1 end
				if st.glow then st.glow.LocalTransparencyModifier = 1 end
				-- 碎成光点：球面向外喷
				local burst = Instance.new("Part")
				burst.Name = "ShieldShards"
				burst.Anchored, burst.CanCollide, burst.CanQuery, burst.CanTouch = true, false, false, false
				burst.Transparency = 1
				burst.Shape = Enum.PartType.Ball
				burst.Size = V(1, 1, 1) * r * 2.44
				burst.CFrame = CFrame.new(c)
				burst.Parent = folder()
				for _, col in ipairs({ LAVENDER, GOLD, Color3.new(1, 1, 1), hex("FFB36B") }) do
					local pe = Instance.new("ParticleEmitter")
					pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
					pe.Color = ColorSequence.new(col)
					pe.LightEmission, pe.LightInfluence = 1, 0
					pe.Shape = Enum.ParticleEmitterShape.Sphere
					pe.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
					pe.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
					pe.Speed = NumberRange.new(40 * O.S, 130 * O.S)
					pe.Lifetime = NumberRange.new(1.2, 2.5)
					pe.Drag = 0.6
					pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 0) })
					pe.Rate = 0
					pe.Parent = burst
					pe:Emit(75)
				end
				game:GetService("Debris"):AddItem(burst, 3)
				local n = (camPos() - c).Unit
				local face = CFrame.lookAt(c, c + n) * CFrame.Angles(-math.pi / 2, 0, 0)
				FX.ring(face, r * 1.1, r * 1.9, GOLD, 1.1, { width = r * 0.12, height = 1 })
				FX.ring(face, r * 0.9, r * 1.5, LAVENDER, 1.5, { width = r * 0.1, height = 1 })
				screenFlash(hex("FFE8C0"), 0.9, 0.7)
				FX.shake(camPos(), 0.8, 0.5)
				if st.label then st.label.Enabled = false end
				setGate(st, "normal")
			end
		end
		-- 2.35–3.8 恢复全彩 + 行星环展开
		if stage == 2 then
			applyColors(st, clamp01((t - 2.35) / 1.45))
		end
		if t >= DUR then break end
		task.wait()
	end
	J.setUnlocked(1)
	if st.shield then st.shield.Size = st.shieldSize end
	if view then
		cam.CFrame = camFrom
		cam.CameraType = camType
	end
end

return J
