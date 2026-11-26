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
	FX.confetti(pos, n, power, colors?)      彩色纸屑：向上炸开后翻转飘落、淡出（锚定小薄片，客户端逐帧移动，约 2.6 s）
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

-- 弹跳小火星：锚定小球 + 客户端自算重力和反弹（射线只打场景、忽略角色），不会撞到玩家
-- （碰撞组只能在服务器 / 编辑时建，客户端特效里用不了）
local GRAV, BOUNCE, FRICTION, R_BALL = 60, 0.55, 0.7, 0.1
function FX.chunks(pos, n, power, color)
	if not RunService:IsRunning() then return end -- 编辑模式不跑
	power = power or 1
	local f = folder()
	local ignore = { f }
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then table.insert(ignore, plr.Character) end
	end
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = ignore
	rp.RespectCanCollide = true
	local balls = {}
	for _ = 1, n do
		local p = Instance.new("Part")
		p.Name = "Spark"
		p.Shape = Enum.PartType.Ball
		p.Size = V(0.2, 0.2, 0.2)
		p.Material = Enum.Material.Neon
		p.Color = color or (math.random() < 0.5 and FX.HOT or FX.ORANGE)
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		local p0 = pos + V(math.random() - 0.5, 0.1, math.random() - 0.5) * 0.6
		p.CFrame = CFrame.new(p0)
		p.Parent = f
		local a = math.random() * math.pi * 2
		local out = 3 + math.random() * 6
		table.insert(balls, { part = p, pos = p0, vel = V(math.cos(a) * out, 8 + math.random() * 10, math.sin(a) * out) * power })
		TweenService:Create(p, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = V(0.04, 0.04, 0.04) }):Play()
		Debris:AddItem(p, 1.25)
	end
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		dt = math.min(dt, 1 / 20)
		local alive = false
		for _, b in ipairs(balls) do
			if b.part.Parent then
				alive = true
				b.vel -= V(0, GRAV * dt, 0)
				local step = b.vel * dt
				local hit = workspace:Raycast(b.pos, step + step.Unit * R_BALL, rp)
				if hit then
					local nrm = hit.Normal
					local vn = nrm * b.vel:Dot(nrm)
					b.vel = (b.vel - vn) * FRICTION - vn * BOUNCE
					b.pos = hit.Position + nrm * R_BALL
				else
					b.pos += step
				end
				b.part.CFrame = CFrame.new(b.pos)
			end
		end
		if not alive then conn:Disconnect() end
	end)
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
-- trauma：一次冲击后衰减；hold / holdUntil：FX.shake 的 dur 内保底强度；
-- rumble / rumbleUntil：FX.rumble 每帧覆盖（可升可降，停止调用 0.1 s 后消失）。三者每帧取最大。
local shake = { trauma = 0, hold = 0, holdUntil = 0, rumble = 0, rumbleUntil = 0, bound = false, seed = math.random() * 100, applied = nil }

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
		local cam = workspace.CurrentCamera
		if not cam then return end
		-- Scriptable 镜头不会每帧被镜头脚本重写：先撤掉上一帧加的偏移，避免越震越偏
		-- （默认镜头每帧都会重算 CFrame，上一帧的偏移已经不在了，不用撤）
		if shake.applied and cam.CameraType == Enum.CameraType.Scriptable then
			cam.CFrame = cam.CFrame * shake.applied:Inverse()
		end
		shake.applied = nil
		local now = os.clock()
		shake.trauma = math.max(0, shake.trauma - 1.5 * dt)
		local lv = shake.trauma
		if now < shake.holdUntil then lv = math.max(lv, shake.hold) else shake.hold = 0 end
		if now < shake.rumbleUntil then lv = math.max(lv, shake.rumble) else shake.rumble = 0 end
		if lv <= 0.002 then return end
		local k = lv * lv
		local function n(o) return math.noise(t * 16, o, shake.seed) end -- 平滑噪声，约 ±0.5
		local off = CFrame.new(n(1) * 1.2 * k, n(2) * 1.2 * k, 0)
			* CFrame.Angles(math.rad(n(3) * 4 * k), math.rad(n(4) * 4 * k), math.rad(n(5) * 2.5 * k))
		cam.CFrame = cam.CFrame * off
		shake.applied = off
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
	-- 直接覆盖：强度跟着本帧的 level 走，可以渐弱（升空余震）；一次性冲击的保底在 hold 里，互不影响
	shake.rumble = (level or 0) * falloff(pos)
	shake.rumbleUntil = os.clock() + 0.1
end

-- 彩色纸屑：锚定薄片逐帧模拟（重力小 + 空气阻力 + 翻转），不进物理
FX.CONFETTI = { Color3.fromRGB(255, 204, 51), Color3.fromRGB(62, 160, 255), Color3.fromRGB(255, 94, 122), Color3.fromRGB(59, 216, 92), Color3.fromRGB(255, 255, 255), Color3.fromRGB(164, 107, 255) }
function FX.confetti(pos, n, power, colors)
	power = power or 1
	colors = colors or FX.CONFETTI
	local f = folder()
	local bits = {}
	for i = 1, n do
		local p = Instance.new("Part")
		p.Name = "Confetti"
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Material = Enum.Material.SmoothPlastic
		p.Color = colors[(i - 1) % #colors + 1]
		p.Size = V(0.42, 0.05, 0.26)
		local a = math.random() * math.pi * 2
		local out = (4 + math.random() * 9) * power
		table.insert(bits, {
			p = p, pos = pos + V(math.cos(a), 0, math.sin(a)) * math.random() * 1.2,
			v = V(math.cos(a) * out, (14 + math.random() * 14) * power, math.sin(a) * out),
			rot = CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6),
			spin = V(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 14,
			sway = math.random() * 6,
		})
		p.CFrame = CFrame.new(pos)
		p.Parent = f
	end
	local life = 2.6
	task.spawn(function()
		local t0, last = os.clock(), os.clock()
		while true do
			local now = os.clock()
			local dt, t = math.min(0.05, now - last), now - t0
			last = now
			if t >= life then break end
			for _, b in ipairs(bits) do
				b.v = b.v * (1 - math.min(1, 2.4 * dt)) + V(0, -16 * dt, 0) -- 阻力大、下落慢，像纸片
				b.pos += (b.v + V(math.sin(t * 5 + b.sway) * 1.5, 0, math.cos(t * 4 + b.sway) * 1.5)) * dt
				b.rot = b.rot * CFrame.Angles(b.spin.X * dt, b.spin.Y * dt, b.spin.Z * dt)
				b.p.CFrame = CFrame.new(b.pos) * b.rot
				b.p.Transparency = math.clamp((t - (life - 0.6)) / 0.6, 0, 1)
			end
			task.wait()
		end
		for _, b in ipairs(bits) do b.p:Destroy() end
	end)
end

return FX
