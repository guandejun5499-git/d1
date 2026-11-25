--[[
	RocketKit · 运行时火箭（ReplicatedStorage.OrbitShared.RocketKit）
	服务器和客户端都能调用：按部件组合实时生成火箭、挂尾焰、切换飞行放大。
	K.build(eq, homeColor, cf, parent)：eq = { nose, tank, engine, fins, deco? }（档次 1–3）；
	  cf = 发动机底面中心（WorldPivot），火箭全部不碰撞；自带尾焰（默认熄火）。
	K.setFlame(rocket, { power, mode, rainbow })：
	  power 0 熄火 / 0.2–1 点火蓄力与正常飞行 / 1.8 轨道狂热；
	  mode "flight"（默认）| "launch"（离台，加烟）| "retro"（返航反推：火焰短、带烟）；
	  rainbow = true：超级发射 / 狂热的彩虹尾焰（11-24 加强：加长 1.5 倍、白色辉光外焰 + 纯白核心、
	  6 片彩虹焰瓣、4 道彩虹激波环、喷口辉光、彩虹星火、彩虹拖尾；颜色由客户端 RainbowFX 流动）。
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
K.RAINBOW_LEN = 1.5 -- 彩虹尾焰额外加长
K.RAINBOW_HUES = { hex("FF5E7A"), hex("FFB33D"), hex("FFE14D"), hex("3BD85C"), hex("3EA0FF"), hex("A46BFF") }
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

-- 彩虹附加件（每次 setFlame 重建）：
--   6 片彩虹焰瓣绕轴一圈、略向外张（客户端 RainbowFX 让颜色沿圈流动）；
--   4 道彩虹激波环沿火焰排开（越往下越小）；喷口白色辉光球；彩虹星火粒子；
--   彩虹拖尾（Trail，火箭移动时才拉出来，飞行 / 狂热时可见）。
function K.rainbowExtras(f, anchorCF, down, len, wid, s)
	local x = B.model("RainbowExtras", f)
	local ra = B.part({ Name = "RainbowAnchor", Size = V(0.2, 0.2, 0.2), CFrame = anchorCF, Transparency = 1, CastShadow = false }, x)
	B.deco(ra)
	local Lh = OUTER.h * len * s
	for k = 0, 5 do
		local cf = down * CFrame.Angles(0, k * math.pi / 3, 0) * CFrame.new(0.7 * wid * s, 0, 0) * CFrame.Angles(0, 0, math.rad(-7))
		local p = B.cone(1.5 * wid * s, Lh * (k % 2 == 0 and 1 or 0.86), cf, { Name = "RainbowPetal", Color = K.RAINBOW_HUES[k + 1], Material = NEON, Transparency = 0.08, CastShadow = false }, x)
		B.deco(p)
		p:SetAttribute("RainbowOffset", k / 6)
		p:SetAttribute("PulseBase", 0.06)
		p:SetAttribute("PulseAmp", 0.2)
		p:SetAttribute("PulseSpeed", 18)
		CS:AddTag(p, "RainbowFX")
		CS:AddTag(p, "PulseFX")
	end
	local outerR = OUTER.d * 0.5 * wid * 1.3 * s
	for i, frac in ipairs({ 0.18, 0.38, 0.58, 0.78 }) do
		local r = outerR * (1 - 0.925 * frac) + 0.3 * s
		local ad = Instance.new("CylinderHandleAdornment")
		ad.Name = "ShockRing"
		ad.Adornee = ra
		ad.Radius = r
		ad.InnerRadius = math.max(0, r - 0.3 * s)
		ad.Height = 0.2 * s
		ad.CFrame = CFrame.new(0, -Lh * frac, 0) * CFrame.Angles(math.pi / 2, 0, 0)
		ad.Color3 = K.RAINBOW_HUES[(i * 2 - 2) % 6 + 1]
		ad.Transparency = 0.1
		ad.AlwaysOnTop = false
		ad.ZIndex = 0
		ad:SetAttribute("RainbowOffset", i * 0.22)
		CS:AddTag(ad, "RainbowFX")
		ad.Parent = ra
	end
	local glow = Instance.new("SphereHandleAdornment")
	glow.Name = "NozzleGlow"
	glow.Adornee = ra
	glow.Radius = 1.9 * wid * s
	glow.CFrame = CFrame.new(0, -0.4 * s, 0)
	glow.Color3 = Color3.new(1, 1, 1)
	glow.Transparency = 0.78
	glow.AlwaysOnTop = false
	glow.ZIndex = 0
	glow.Parent = ra

	local sp = Instance.new("ParticleEmitter")
	sp.Name = "RainbowSparks"
	sp.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sp.EmissionDirection = Enum.NormalId.Bottom
	sp.Color = K.RAINBOW
	sp.LightEmission = 1
	sp.LightInfluence = 0
	sp.Rate = 80
	sp.Lifetime = NumberRange.new(0.6, 1.2)
	sp.Speed = NumberRange.new(12 * s, 26 * s)
	sp.SpreadAngle = Vector2.new(35, 35)
	sp.Drag = 2
	sp.Rotation = NumberRange.new(0, 360)
	sp.RotSpeed = NumberRange.new(-180, 180)
	sp.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9 * s), NumberSequenceKeypoint.new(1, 0) })
	sp.Parent = ra

	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Name, a1.Name = "TrailL", "TrailR"
	a0.Position, a1.Position = V(-1.4 * wid * s, -0.3 * s, 0), V(1.4 * wid * s, -0.3 * s, 0)
	a0.Parent, a1.Parent = ra, ra
	local tr = Instance.new("Trail")
	tr.Name = "RainbowTrail"
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Color = K.RAINBOW
	tr.LightEmission = 1
	tr.LightInfluence = 0
	tr.Lifetime = 1.0
	tr.FaceCamera = true
	tr.MinLength = 0.05
	tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
	tr.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.2) })
	tr.Parent = ra
	return x
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
	-- 彩虹尾焰（11-24 用户要求更夸张）：整体加长 1.5 倍、加宽，外焰变成大块白色辉光，核心纯白
	local len = power * (mode == "retro" and 0.55 or 1) * (rainbow and K.RAINBOW_LEN or 1)
	local wid = math.clamp(0.7 + 0.3 * power, 0.6, 1.35) * (rainbow and 1.1 or 1)

	for _, spec in ipairs({ { "FlameOuter", OUTER, 0.35, "outer" }, { "FlameInner", INNER, 0.1, "inner" } }) do
		local p = f:FindFirstChild(spec[1])
		local outer = spec[4] == "outer"
		local h = math.max(0.05, spec[2].h * len * s * ((rainbow and not outer) and 0.6 or 1)) -- 彩虹时白色核心缩短，露出焰瓣颜色
		local d = spec[2].d * wid * s * ((rainbow and outer) and 1.3 or 1)
		local tr = rainbow and (outer and 0.88 or 0.05) or spec[3]
		p.Size = V(d, h, d)
		p.CFrame = down * CFrame.new(0, h / 2, 0)
		p.Transparency = on and tr or 1
		p.Color = rainbow and (outer and hex("FFF6E0") or Color3.new(1, 1, 1)) or K.FLAME[tier][spec[4]]
		setTag(p, "RainbowFX", false) -- 彩虹色交给下面的焰瓣
		-- 焰锥轻微闪烁（客户端 PulseFX：透明度呼吸）
		p:SetAttribute("PulseBase", tr)
		p:SetAttribute("PulseAmp", 0.18)
		p:SetAttribute("PulseSpeed", 22)
		setTag(p, "PulseFX", on)
	end
	local oldExtras = f:FindFirstChild("RainbowExtras")
	if oldExtras then oldExtras:Destroy() end
	if on and rainbow then K.rainbowExtras(f, anchor.CFrame, down, len, wid, s) end

	local col = K.FLAME[tier]
	local ex = anchor:FindFirstChild("Exhaust")
	ex.Enabled = on
	ex.Color = rainbow and K.RAINBOW or ColorSequence.new({
		ColorSequenceKeypoint.new(0, col.inner),
		ColorSequenceKeypoint.new(0.4, col.outer),
		ColorSequenceKeypoint.new(1, hex("2A2440")),
	})
	ex.Rate = rainbow and 160 or (40 + 50 * power)
	ex.Speed = NumberRange.new(16 * len * s, 26 * len * s)
	ex.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, (rainbow and 1.8 or 1.3) * wid * s),
		NumberSequenceKeypoint.new(1, (rainbow and 6 or 3.2) * wid * s),
	})
	ex.Lifetime = rainbow and NumberRange.new(0.4, 0.9) or NumberRange.new(0.22, 0.4)
	ex.LightEmission = rainbow and 1 or 0.9

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
