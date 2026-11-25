--[[
	Stardust · 星尘碎片（ReplicatedStorage.OrbitShared.Stardust）
	每圈 36% / 64% 处各一颗金色晶体（位置见 Orbits.shardPoints），玩家点中后增强下一道门。
	造型：拉长的八面体（高 = 1.5 × 半径），8 个三角面用楔形零件拼出、两种金色交替显出棱面；
	外层金色光晕（SphereHandleAdornment）+ 细闪粒子。自转（SpinFX）+ 呼吸缩放（BreatheFX）由客户端驱动。
	SD.build(cf, r, parent)：r = 八面体腰部半径（月球约 2.5，木星约 4.7）。
	SD.collect(shard)：收集爆发（金色星屑四散）并隐藏晶体；在客户端调用（ParticleEmitter:Emit 不会从服务器复制）。
]]

local B = require(script.Parent.BuildLib)
local hex = B.hex
local V = Vector3.new
local CS = game:GetService("CollectionService")

local SD = {}
SD.FACE = { hex("FFE680"), hex("FFC24A") }
SD.GLOW = hex("FFD27A")

-- 三角面：两块 WedgePart（经典做法），thickness = 面厚
local function triangle(a, b, c, props, parent, thickness)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab).Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	local w1 = B.wedge(V(thickness, height, math.abs(ab:Dot(back))), CFrame.fromMatrix((a + b) / 2, right, up, back), props, parent)
	local w2 = B.wedge(V(thickness, height, math.abs(ac:Dot(back))), CFrame.fromMatrix((a + c) / 2, -right, up, -back), props, parent)
	return w1, w2
end

function SD.build(cf, r, parent)
	local m = B.model("Stardust")
	local h = r * 1.5
	local top, bot = cf * V(0, h, 0), cf * V(0, -h, 0)
	local eq = {}
	for i = 0, 3 do
		local a = i * math.pi / 2
		eq[i] = cf * V(math.cos(a) * r, 0, math.sin(a) * r)
	end
	local th = math.max(0.05, r * 0.03)
	for i = 0, 3 do
		local e0, e1 = eq[i], eq[(i + 1) % 4]
		local k = i % 2
		triangle(top, e0, e1, { Name = "Facet", Color = SD.FACE[k + 1], Reflectance = 0.12, CastShadow = false }, m, th)
		triangle(bot, e1, e0, { Name = "Facet", Color = SD.FACE[2 - k], Reflectance = 0.12, CastShadow = false }, m, th)
	end
	local core = B.part({ Name = "Core", Size = V(r, r, r), CFrame = cf, Transparency = 1, CastShadow = false }, m)
	local glow = Instance.new("SphereHandleAdornment")
	glow.Name = "Glow"
	glow.Adornee = core
	glow.Radius = r * 2.2
	glow.Color3 = SD.GLOW
	glow.Transparency = 0.82
	glow.AlwaysOnTop = false
	glow.ZIndex = 0
	glow.Parent = core
	B.fx.sparkles(core, hex("FFE08A"), 6, r * 0.3)
	local burst = Instance.new("ParticleEmitter")
	burst.Name = "Burst"
	burst.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	burst.Color = ColorSequence.new(hex("FFF1B8"), hex("FFB000"))
	burst.LightEmission = 1
	burst.LightInfluence = 0
	burst.Rate = 0
	burst.Enabled = true
	burst.Lifetime = NumberRange.new(0.5, 0.9)
	burst.Speed = NumberRange.new(r * 5, r * 10)
	burst.Drag = 3
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, r * 0.45), NumberSequenceKeypoint.new(1, 0) })
	burst.Parent = core
	B.decoAll(m)
	m.WorldPivot = cf
	m:SetAttribute("Radius", r)
	m:SetAttribute("SpinSpeed", 2.5)
	m:SetAttribute("BreatheAmp", 0.08)
	CS:AddTag(m, "SpinFX")
	CS:AddTag(m, "BreatheFX")
	m.Parent = parent
	return m
end

function SD.collect(m)
	local core = m:FindFirstChild("Core")
	if core and core:FindFirstChild("Burst") then core.Burst:Emit(40) end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "Facet" then d.Transparency = 1 end
		if d:IsA("HandleAdornment") then d.Visible = false end
		if d:IsA("ParticleEmitter") and d.Name ~= "Burst" then d.Enabled = false end
	end
	m:SetAttribute("Collected", true)
end

return SD
