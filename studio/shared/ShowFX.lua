--[[
	ShowFX · P1 演出通用特效（ReplicatedStorage.OrbitShared.ShowFX）
	都在客户端调用，生成的东西自动清理（Debris）。12–17 项共用。
	FX.sparks(pos, n, power, colors?)        一次性火花（重力下落、发光）
	FX.chunks(pos, n, power, color?)         受重力弹跳的小火星（真物理小球，只在运行时生成）
	FX.flash(pos, color, range, bright, dur) 点光源闪一下后淡出
	FX.ring(cf, r0, r1, color, dur, opts?)   地面冲击环：从 r0 扩到 r1 并淡出（cf 的 Y 轴 = 环的法线）
	FX.puff(pos, n, color, speed, size, opts?) 烟 / 尘一团
	FX.shake(pos, power, dur)                镜头震动：一次冲击（累加「震感」后慢慢衰减），dur 内保持一定强度
	FX.rumble(pos, level)                    持续轻震：每帧调用（点火蓄力、火箭抖动时用）
	  11-25 用户要求火箭震动时镜头也要有反馈 → 改成统一的震感控制器：每帧在相机更新之后叠加平滑噪声的
	  位移（±0.6）+ 转角（±2°），强度 = 震感²（小震轻、大震重），离镜头 / 角色 90 格外不震
]]

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local V = Vector3.new
local NSK = NumberSequenceKeypoint.new
local CSK = ColorSequenceKeypoint.new
local SPARK_TEX = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE_TEX = "rbxasset://textures/particles/smoke_main.dds"

local FX = {}
FX.HOT = Color3.fromRGB(255, 244, 200)
FX.ORANGE = Color3.fromRGB(255, 150, 40)

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

local function holder(pos, life)
	local a = Instance.new("Attachment")
	a.Name = "FXHolder"
	a.Parent = workspace.Terrain
	a.WorldPosition = pos
	Debris:AddItem(a, life)
	return a
end

function FX.sparks(pos, n, power, colors)
	power = power or 1
	local a = holder(pos, 1.5)
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = SPARK_TEX
	pe.LightEmission, pe.LightInfluence = 1, 0
	local c0, c1 = FX.HOT, FX.ORANGE
	if colors then c0, c1 = colors[1], colors[2] or colors[1] end
	pe.Color = ColorSequence.new({ CSK(0, c0), CSK(1, c1) })
	pe.Size = NumberSequence.new({ NSK(0, 0.3 + 0.15 * power), NSK(1, 0) })
	pe.Lifetime = NumberRange.new(0.25, 0.55 + 0.15 * power)
	pe.Speed = NumberRange.new(5 * power, 14 * power)
	pe.EmissionDirection = Enum.NormalId.Top
	pe.SpreadAngle = Vector2.new(80, 80)
	pe.Acceleration = V(0, -45, 0)
	pe.Drag = 1.2
	pe.Rate = 0
	pe.Parent = a
	pe:Emit(n)
end

function FX.chunks(pos, n, power, color)
	if not RunService:IsRunning() then return end -- 编辑模式没有物理
	power = power or 1
	local f = folder()
	for _ = 1, n do
		local p = Instance.new("Part")
		p.Name = "Spark"
		p.Shape = Enum.PartType.Ball
		p.Size = V(0.2, 0.2, 0.2)
		p.Material = Enum.Material.Neon
		p.Color = color or (math.random() < 0.5 and FX.HOT or FX.ORANGE)
		p.CanQuery, p.CanTouch, p.CastShadow = false, false, false
		p.CustomPhysicalProperties = PhysicalProperties.new(0.3, 0.2, 0.55, 1, 1)
		p.CFrame = CFrame.new(pos + V(math.random() - 0.5, 0.1, math.random() - 0.5) * 0.6)
		p.Parent = f
		local a = math.random() * math.pi * 2
		local out = 3 + math.random() * 6
		p.AssemblyLinearVelocity = V(math.cos(a) * out, 8 + math.random() * 10, math.sin(a) * out) * power
		TweenService:Create(p, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = V(0.04, 0.04, 0.04) }):Play()
		Debris:AddItem(p, 1.25)
	end
end

function FX.flash(pos, color, range, bright, dur)
	local a = holder(pos, (dur or 0.3) + 0.1)
	local l = Instance.new("PointLight")
	l.Color = color or FX.ORANGE
	l.Range = range or 14
	l.Brightness = bright or 4
	l.Shadows = false
	l.Parent = a
	TweenService:Create(l, TweenInfo.new(dur or 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 }):Play()
end

-- 冲击环：用很薄的空心圆柱装饰（CylinderHandleAdornment + InnerRadius），不碰撞、不挡视线
function FX.ring(cf, r0, r1, color, dur, opts)
	opts = opts or {}
	dur = dur or 0.5
	local p = Instance.new("Part")
	p.Name = "RingAnchor"
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Transparency = 1
	p.Size = V(0.2, 0.2, 0.2)
	p.CFrame = cf
	p.Parent = folder()
	local ad = Instance.new("CylinderHandleAdornment")
	ad.Adornee = p
	ad.CFrame = CFrame.Angles(math.pi / 2, 0, 0) -- 装饰的轴沿 Z，转到 cf 的 Y
	ad.Height = opts.height or 0.08
	ad.Color3 = color
	ad.AlwaysOnTop = false
	ad.ZIndex = 0
	ad.Transparency = opts.t0 or 0.1
	ad.Radius = r0
	ad.InnerRadius = math.max(0, r0 - (opts.width or 0.35))
	ad.Parent = p
	Debris:AddItem(p, dur + 0.1)
	local t0 = os.clock()
	task.spawn(function()
		while p.Parent do
			local u = math.clamp((os.clock() - t0) / dur, 0, 1)
			local e = 1 - (1 - u) ^ 3
			local r = r0 + (r1 - r0) * e
			local w = (opts.width or 0.35) * (1 + (opts.grow or 1) * e)
			ad.Radius = r
			ad.InnerRadius = math.max(0, r - w)
			ad.Transparency = (opts.t0 or 0.1) + (1 - (opts.t0 or 0.1)) * u
			if u >= 1 then break end
			task.wait()
		end
	end)
	return p
end

function FX.puff(pos, n, color, speed, size, opts)
	opts = opts or {}
	local life = opts.life or 1.4
	local a = holder(pos, life + 0.6)
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = SMOKE_TEX
	pe.Color = ColorSequence.new(color or Color3.fromRGB(200, 205, 230))
	pe.LightEmission = opts.light or 0
	pe.LightInfluence = opts.influence or 0.6
	pe.Size = NumberSequence.new({ NSK(0, (size or 2) * 0.5), NSK(1, size or 2) })
	pe.Transparency = NumberSequence.new({ NSK(0, opts.t0 or 0.35), NSK(1, 1) })
	pe.Lifetime = NumberRange.new(life * 0.6, life)
	pe.Speed = NumberRange.new((speed or 6) * 0.4, speed or 6)
	pe.SpreadAngle = Vector2.new(opts.spread or 180, opts.spread or 180)
	pe.EmissionDirection = opts.dir or Enum.NormalId.Top
	pe.Drag = opts.drag or 3
	pe.Acceleration = opts.acc or V(0, 1.5, 0)
	pe.Rotation = NumberRange.new(0, 360)
	pe.RotSpeed = NumberRange.new(-40, 40)
	pe.Rate = 0
	pe.Parent = a
	pe:Emit(n)
end

-- 镜头震动：统一的「震感」控制器（只在运行时的客户端）
local shake = { trauma = 0, hold = 0, holdUntil = 0, bound = false, seed = math.random() * 100 }

local function falloff(pos)
	local cam = workspace.CurrentCamera
	local plr = Players.LocalPlayer
	local ch = plr and plr.Character
	local root = ch and ch:FindFirstChild("HumanoidRootPart")
	local from = root and root.Position or (cam and cam.CFrame.Position)
	if not from then return 0 end
	return math.clamp(1 - (from - pos).Magnitude / 90, 0, 1)
end

local function ensureBound()
	if shake.bound or not RunService:IsRunning() or not RunService:IsClient() then return false end
	shake.bound = true
	local t = 0
	RunService:BindToRenderStep("OrbitShowShake", Enum.RenderPriority.Camera.Value + 1, function(dt)
		t += dt
		shake.trauma = math.max(0, shake.trauma - 1.5 * dt)
		local lv = shake.trauma
		if os.clock() < shake.holdUntil then
			lv = math.max(lv, shake.hold)
		else
			shake.hold = 0
		end
		if lv <= 0.002 then return end
		local k = lv * lv
		local function n(o) return math.noise(t * 16, o, shake.seed) end -- 平滑噪声，约 ±0.5
		local cam = workspace.CurrentCamera
		cam.CFrame = cam.CFrame
			* CFrame.new(n(1) * 1.2 * k, n(2) * 1.2 * k, 0)
			* CFrame.Angles(math.rad(n(3) * 4 * k), math.rad(n(4) * 4 * k), math.rad(n(5) * 2.5 * k))
	end)
	return true
end

-- 一次冲击：power 1 ≈ 普通发射；dur 内至少保持 0.7 × 强度
function FX.shake(pos, power, dur)
	if not RunService:IsRunning() or not RunService:IsClient() then return end
	ensureBound()
	local a = (power or 1) * falloff(pos)
	if a <= 0.01 then return end
	shake.trauma = math.min(1.2, shake.trauma + a * 0.8)
	if dur and dur > 0 then
		shake.hold = math.max(shake.hold, a * 0.7)
		shake.holdUntil = math.max(shake.holdUntil, os.clock() + dur)
	end
end

-- 持续轻震：每帧调用，停止调用 0.1 s 后自动消失
function FX.rumble(pos, level)
	if not RunService:IsRunning() or not RunService:IsClient() then return end
	ensureBound()
	local a = (level or 0) * falloff(pos)
	local now = os.clock()
	shake.hold = (now < shake.holdUntil) and math.max(shake.hold, a) or a
	shake.holdUntil = math.max(shake.holdUntil, now + 0.1)
end

return FX
