--[[
	RocketKit · 运行时火箭（ReplicatedStorage.OrbitShared.RocketKit）
	服务器和客户端都能调用：按部件组合实时生成火箭、挂尾焰、切换飞行放大。
	K.build(eq, homeColor, cf, parent)：eq = { nose, tank, engine, fins, deco? }（档次 1–3）；
	  cf = 发动机底面中心（WorldPivot），火箭全部不碰撞；自带尾焰（默认熄火）。
	K.setFlame(rocket, { power, mode, rainbow })：
	  power 0 熄火 / 0.2–1 点火蓄力与正常飞行 / 1.8 轨道狂热；
	  mode "flight"（默认）| "launch"（离台，加烟）| "retro"（返航反推：火焰短、带烟）；
	  rainbow = true：超级发射 / 狂热的彩虹尾焰（焰锥颜色由客户端 RainbowFX 循环，粒子用彩虹渐变）。
	尾焰三色：基础 橙 / 涡轮 蓝 / 等离子 紫（Web Demo FLAME_COL）。
	K.setScale(rocket, s)：飞行中放大（Roblox 定为 1.5）；尾焰会按当前缩放重算。
]]

local B = require(script.Parent.BuildLib)
local hex = B.hex
local V = Vector3.new
local NEON = Enum.Material.Neon
local CS = game:GetService("CollectionService")

local K = {}
K.FLIGHT_SCALE = 1.5
K.FLAME = {
	{ outer = hex("FF8A1F"), inner = hex("FFE36B") },
	{ outer = hex("2F9BFF"), inner = hex("D9F3FF") },
	{ outer = hex("B14DFF"), inner = hex("FFD7FF") },
}
K.RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, hex("FF5E7A")),
	ColorSequenceKeypoint.new(0.2, hex("FFCC33")),
	ColorSequenceKeypoint.new(0.4, hex("3BD85C")),
	ColorSequenceKeypoint.new(0.6, hex("2FD3C8")),
	ColorSequenceKeypoint.new(0.8, hex("3EA0FF")),
	ColorSequenceKeypoint.new(1, hex("A46BFF")),
})
local OUTER = { d = 3.0, h = 4.5 }
local INNER = { d = 1.7, h = 2.8 }
local FIRE_TEX = "rbxasset://textures/particles/fire_main.dds"
local SMOKE_TEX = "rbxasset://textures/particles/smoke_main.dds"

local function emitter(name, parent)
	local pe = Instance.new("ParticleEmitter")
	pe.Name = name
	pe.EmissionDirection = Enum.NormalId.Bottom
	pe.Enabled = false
	pe.Parent = parent
	return pe
end

function K.addFlame(rocket, tier)
	local old = rocket:FindFirstChild("Flame")
	if old then old:Destroy() end
	local pivot = rocket:GetPivot()
	local f = B.model("Flame", rocket)
	f:SetAttribute("Tier", tier)
	local anchor = B.part({ Name = "FlameAnchor", Size = V(0.4, 0.2, 0.4), CFrame = pivot, Transparency = 1, CastShadow = false }, f)
	local down = pivot * CFrame.Angles(math.pi, 0, 0)
	B.cone(OUTER.d, OUTER.h, down, { Name = "FlameOuter", Color = K.FLAME[tier].outer, Material = NEON, Transparency = 1, CastShadow = false }, f)
	B.cone(INNER.d, INNER.h, down * CFrame.new(0, 0.05, 0), { Name = "FlameInner", Color = K.FLAME[tier].inner, Material = NEON, Transparency = 1, CastShadow = false }, f)

	local ex = emitter("Exhaust", anchor)
	ex.Texture = FIRE_TEX
	ex.LightEmission = 0.9
	ex.LightInfluence = 0
	ex.Lifetime = NumberRange.new(0.22, 0.4)
	ex.SpreadAngle = Vector2.new(9, 9)
	ex.RotSpeed = NumberRange.new(-120, 120)
	ex.Rotation = NumberRange.new(0, 360)
	ex.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(0.7, 0.55), NumberSequenceKeypoint.new(1, 1) })

	local sm = emitter("Smoke", anchor)
	sm.Texture = SMOKE_TEX
	sm.Color = ColorSequence.new(hex("CFCBE0"), hex("6E6A86"))
	sm.LightEmission = 0
	sm.LightInfluence = 0.6
	sm.Lifetime = NumberRange.new(1.2, 2.0)
	sm.SpreadAngle = Vector2.new(28, 28)
	sm.Drag = 2
	sm.RotSpeed = NumberRange.new(-40, 40)
	sm.Rotation = NumberRange.new(0, 360)
	sm.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })

	B.decoAll(f)
	K.setFlame(rocket, { power = 0 })
	return f
end

function K.build(eq, homeColor, cf, parent)
	local r = B.rocket(eq, homeColor, cf, nil)
	r.WorldPivot = cf
	B.decoAll(r)
	K.addFlame(r, eq.engine)
	r:SetAttribute("Runtime", true)
	r.Parent = parent
	return r
end

local function setTag(inst, tag, on)
	if on then CS:AddTag(inst, tag) else CS:RemoveTag(inst, tag) end
end

function K.setFlame(rocket, o)
	local f = rocket:FindFirstChild("Flame")
	if not f then return end
	o = o or {}
	local power = o.power or 1
	local mode = o.mode or "flight"
	local rainbow = o.rainbow == true
	local tier = f:GetAttribute("Tier") or 1
	local s = rocket:GetScale()
	local on = power > 0.01
	local anchor = f:FindFirstChild("FlameAnchor")
	local pivot = anchor.CFrame
	local down = pivot * CFrame.Angles(math.pi, 0, 0)
	local len = power * (mode == "retro" and 0.55 or 1)
	local wid = math.clamp(0.7 + 0.3 * power, 0.6, 1.35)

	for _, spec in ipairs({ { "FlameOuter", OUTER, 0.35, "outer" }, { "FlameInner", INNER, 0.1, "inner" } }) do
		local p = f:FindFirstChild(spec[1])
		local h = math.max(0.05, spec[2].h * len * s)
		p.Size = V(spec[2].d * wid * s, h, spec[2].d * wid * s)
		p.CFrame = down * CFrame.new(0, h / 2, 0)
		p.Transparency = on and spec[3] or 1
		p.Color = K.FLAME[tier][spec[4]]
		setTag(p, "RainbowFX", on and rainbow)
		p:SetAttribute("RainbowOffset", spec[4] == "inner" and 0.3 or 0)
		-- 焰锥轻微闪烁（客户端 PulseFX：透明度呼吸）
		p:SetAttribute("PulseBase", spec[3])
		p:SetAttribute("PulseAmp", 0.18)
		p:SetAttribute("PulseSpeed", 22)
		setTag(p, "PulseFX", on)
	end

	local col = K.FLAME[tier]
	local ex = anchor:FindFirstChild("Exhaust")
	ex.Enabled = on
	ex.Color = rainbow and K.RAINBOW or ColorSequence.new({
		ColorSequenceKeypoint.new(0, col.inner),
		ColorSequenceKeypoint.new(0.4, col.outer),
		ColorSequenceKeypoint.new(1, hex("2A2440")),
	})
	ex.Rate = 40 + 50 * power
	ex.Speed = NumberRange.new(16 * len * s, 26 * len * s)
	ex.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.3 * wid * s),
		NumberSequenceKeypoint.new(1, (rainbow and 4.2 or 3.2) * wid * s),
	})
	ex.Lifetime = NumberRange.new(0.22, rainbow and 0.7 or 0.4)

	local sm = anchor:FindFirstChild("Smoke")
	sm.Enabled = on and (mode == "launch" or mode == "retro")
	sm.Rate = (mode == "launch") and 45 or 18
	sm.Speed = NumberRange.new(6 * s, 11 * s)
	sm.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2 * s), NumberSequenceKeypoint.new(1, 6.5 * s) })

	f:SetAttribute("Power", power)
	f:SetAttribute("Mode", mode)
	f:SetAttribute("Rainbow", rainbow)
end

function K.setScale(rocket, s)
	rocket:ScaleTo(s)
	local f = rocket:FindFirstChild("Flame")
	if f then
		K.setFlame(rocket, { power = f:GetAttribute("Power"), mode = f:GetAttribute("Mode"), rainbow = f:GetAttribute("Rainbow") })
	end
end

function K.place(rocket, cf)
	rocket:PivotTo(cf)
end

return K
