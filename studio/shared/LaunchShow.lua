--[[
	LaunchShow · P1 第 14 项 点火与发射（ReplicatedStorage.OrbitShared.LaunchShow）
	客户端表现。发射区由 04_home_launch 建（LaunchArea/LaunchPad + PadRocket，PadRocket 是 RocketKit 运行时火箭）。
	LS.prepare(launchArea, rocket?) → show
	show:charge(v, stage)：按住点火时每帧调用。v = 当前这一圈的进度 0–1，stage 0 = 点火 / 1 = 超载 / 2 = 彩虹区
	  点火瞬间一圈小烟 + 火星；从一开始尾焰就带烟，台面贴地烟雾随强度慢慢堆起来；
	  台面暖光（贴着台面，只照亮台子，不把火箭照白）随强度闪动；超载起火箭抖动、台底冒白色蒸汽；彩虹区尾焰变彩虹
	  （11-25 用户反馈：原来先亮很久才冒烟 → 改成点火即冒烟、暖光压低）
	show:launch(judge)：松手发射，judge = "normal" | "good" | "perfect" | "super" | "stall"
	  普通：强光 + 地面双层冲击环（金 / 白）+ 一圈贴地向外翻滚的灰色烟雾（Normal 混合，不发光）+ 镜头震动，
	        火箭加速升空（3.2 s 升到 95 高）；离台时保持原尺寸，升到约 18 高以后再慢慢放大到飞行比例 1.5
	        （11-25 用户反馈：原来一离台就变大，太突兀）
	  超级：更白更大的闪光、三层冲击环（白 / 粉 / 蓝）、一圈彩虹火花、彩虹尾焰、震动更强
	  超载熄火（stall）：火箭剧烈抖动、喷口冒黑烟、尾焰断续后熄火约 0.6 s，再「噗」一声重新点着，弱发射
	  离台瞬间回收支架张开（0.25 s，不然火箭会从夹爪里穿出去），reset 时回到原来的夹紧角度
	  launch 是阻塞的（约 3.2–3.9 s）；也可以 show:startLaunch(judge) + show:runTo(t) 在编辑模式逐帧检查
	show:reset()：演示用，把火箭放回台上、熄火。正式游戏由第 15 项飞行接管。
]]

local B = require(script.Parent.BuildLib)
local RK = require(script.Parent.RocketKit)
local CA = require(script.Parent.CatchArms)
local FX = require(script.Parent.ShowFX)

local V = Vector3.new
local NSK = NumberSequenceKeypoint.new
local LS = {}

LS.ASCENT, LS.RISE = 3.2, 95
local WARM = B.hex("FFB347")
local SMOKE_TEX = "rbxasset://textures/particles/smoke_main.dds"
local RAINBOW = { B.hex("FF5E7A"), B.hex("FFB33D"), B.hex("FFE14D"), B.hex("3BD85C"), B.hex("3EA0FF"), B.hex("A46BFF") }

local function clamp01(x) return math.clamp(x, 0, 1) end
local function seg(t, t0, t1) return clamp01((t - t0) / (t1 - t0)) end

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

------------------------------------------------------------------ 准备
function LS.prepare(area, rocket)
	local S = {}
	S.area = area
	S.rocket = rocket or area:FindFirstChild("PadRocket")
	S.home = S.rocket:GetPivot()
	S.scale0 = S.rocket:GetScale()
	S.catch = area:FindFirstChild("CatchArms")
	S.catchPose0 = S.catch and (S.catch:GetAttribute("Pose") or 0) or 0
	local plate = area:FindFirstChild("LaunchPad") and area.LaunchPad:FindFirstChild("FlameHole")
	S.base = plate and (plate.Position + V(0, plate.Size.X / 2, 0)) or (S.home.Position) -- 台面（导流孔顶）
	-- 锚点：暖光 + 一圈贴地烟雾喷口
	local an = Instance.new("Part")
	an.Name = "LaunchFX"
	an.Anchored, an.CanCollide, an.CanQuery, an.CanTouch = true, false, false, false
	an.Transparency = 1
	an.Size = V(0.2, 0.2, 0.2)
	an.CFrame = CFrame.new(S.base + V(0, 0.8, 0)) -- 暖光贴着台面
	an.Parent = folder()
	S.anchor = an
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Shadows = WARM, 16, 0, false
	light.Parent = an
	S.light = light
	S.smoke = {}
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		local at = Instance.new("Attachment")
		at.Parent = an
		-- 喷口在火箭底部一圈（半径 2.2），朝外、略向上
		at.WorldCFrame = CFrame.new(S.base + V(math.sin(a) * 2.2, 0.4, math.cos(a) * 2.2)) * CFrame.Angles(0, a + math.pi, 0) * CFrame.Angles(math.rad(8), 0, 0)
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = SMOKE_TEX
		pe.EmissionDirection = Enum.NormalId.Front
		pe.LightEmission, pe.LightInfluence = 0, 1 -- Normal 混合：受场景光照，像真烟
		pe.Rate = 0
		pe.Lifetime = NumberRange.new(2.4, 3.8)
		pe.Speed = NumberRange.new(14, 28)
		pe.Drag = 2.2
		pe.SpreadAngle = Vector2.new(22, 8)
		pe.Acceleration = V(0, 1.4, 0)
		pe.Rotation = NumberRange.new(0, 360)
		pe.RotSpeed = NumberRange.new(-30, 30)
		pe.Size = NumberSequence.new({ NSK(0, 2.6), NSK(0.4, 8), NSK(1, 12) })
		pe.Transparency = NumberSequence.new({ NSK(0, 0.25), NSK(0.6, 0.55), NSK(1, 1) })
		pe.Parent = at
		table.insert(S.smoke, pe)
	end
	S.lastPower = -1
	S.t, S.ei, S.events = -1, 1, {}
	return setmetatable(S, { __index = LS })
end

local function smokeColor(S, c0, c1)
	for _, pe in ipairs(S.smoke) do
		pe.Color = ColorSequence.new(c0, c1)
	end
end

local function emitSmoke(S, n, speedK)
	for _, pe in ipairs(S.smoke) do
		if speedK then pe.Speed = NumberRange.new(14 * speedK, 28 * speedK) end
		pe:Emit(n)
	end
end

local function setFlame(S, power, rainbow, mode)
	local key = string.format("%.2f%s%s", power, tostring(rainbow), mode or "")
	if key == S.lastPower then return end
	S.lastPower = key
	RK.setFlame(S.rocket, { power = power, rainbow = rainbow, mode = mode or "launch" })
end

------------------------------------------------------------------ 按住点火
function LS.charge(S, v, stage)
	stage = stage or 0
	if not S.ignited then -- 点火瞬间：一圈小烟 + 火星
		S.ignited = true
		smokeColor(S, B.hex("D6D9EA"), B.hex("9EA4BE"))
		for _, pe in ipairs(S.smoke) do pe.Speed = NumberRange.new(4, 9) end
		emitSmoke(S, 2)
		FX.sparks(S.base + V(0, 0.4, 0), 18, 0.7)
		FX.ring(CFrame.new(S.base + V(0, 0.06, 0)), 1.2, 5, WARM, 0.4, { width = 0.3 })
	end
	-- 台面贴地烟雾随强度慢慢堆起来
	for _, pe in ipairs(S.smoke) do pe.Rate = 1 + 3 * v + 2 * stage end
	local jitter = 0.8 + math.random() * 0.4
	S.light.Brightness = (0.3 + v * 0.9) * jitter * (1 + 0.3 * stage)
	if stage >= 2 then
		S.light.Color = RAINBOW[math.floor(os.clock() * 12) % #RAINBOW + 1]
	else
		S.light.Color = WARM
	end
	-- 镜头轻震：点火阶段随强度变强，超载 / 彩虹区更强
	FX.rumble(S.base, (stage == 0) and (0.25 + 0.35 * v) or (0.5 + 0.15 * stage))
	-- 尾焰：功率按 0.05 一档变，避免每帧重建
	local p = math.floor((0.25 + 0.55 * v + 0.15 * stage) * 20 + 0.5) / 20
	setFlame(S, p, stage >= 2, "launch") -- launch 模式自带喷口烟
	-- 超载起：火箭抖动 + 白色蒸汽
	if stage >= 1 then
		local a = 0.09 * stage
		S.rocket:PivotTo(S.home * CFrame.new((math.random() - 0.5) * a * 2, 0, (math.random() - 0.5) * a * 2) * CFrame.Angles(0, 0, (math.random() - 0.5) * 0.01 * stage))
		if math.random() < 0.35 then
			FX.puff(S.base + V((math.random() - 0.5) * 3, 0.6, (math.random() - 0.5) * 3), 2, B.hex("E6E9F5"), 5, 2.4, { life = 1.2, influence = 1 })
		end
	else
		S.rocket:PivotTo(S.home)
	end
end

------------------------------------------------------------------ 发射
function LS.startLaunch(S, judge)
	S.judge = judge or "normal"
	S.events, S.ei, S.t = {}, 1, -1
	local function ev(t, fn) table.insert(S.events, { t, fn }) end
	local base = S.base
	S.lift0 = (judge == "stall") and 0.7 or 0 -- 熄火要先抖 0.7 s 再起飞
	S.rocket:PivotTo(S.home)

	if judge == "stall" then
		ev(0, function()
			smokeColor(S, B.hex("2A2A32"), B.hex("17171C"))
			emitSmoke(S, 3, 0.6)
			FX.puff(base + V(0, 1.5, 0), 14, B.hex("22222A"), 6, 4, { life = 1.8, influence = 1, t0 = 0.15 })
			FX.shake(base, 0.5, 0.6)
		end)
		for k = 0, 5 do
			ev(0.05 + k * 0.1, function()
				setFlame(S, (k % 2 == 0) and 0.35 or 0.05, false, "launch")
				FX.puff(base + V(0, 1.2, 0), 3, B.hex("1C1C22"), 4, 3, { life = 1.4, influence = 1, t0 = 0.2 })
			end)
		end
		ev(0.58, function() setFlame(S, 0, false, "flight") end) -- 熄火
		ev(S.lift0, function() -- 重新点着
			FX.puff(base + V(0, 1, 0), 10, B.hex("4A4A55"), 8, 3, { life = 1.2, influence = 1 })
			FX.flash(base + V(0, 2, 0), WARM, 24, 4, 0.4)
		end)
	end

	local l0 = S.lift0
	ev(0, function()
		for _, pe in ipairs(S.smoke) do pe.Rate = 0 end -- 蓄力时的持续烟停掉，改成发射的一次性大烟
	end)
	ev(l0, function()
		local super = judge == "super"
		local weak = judge == "stall"
		setFlame(S, super and 1.2 or 1, super, "launch")
		if not weak then smokeColor(S, B.hex("D6D9EA"), B.hex("9EA4BE")) end
		emitSmoke(S, super and 12 or (weak and 4 or 8), super and 1.3 or 1)
		FX.flash(base + V(0, 3, 0), super and Color3.new(1, 1, 1) or B.hex("FFE2B0"), super and 80 or 55, super and 14 or 9, super and 1.0 or 0.8)
		if super then
			FX.ring(CFrame.new(base + V(0, 0.08, 0)), 3, 26, Color3.new(1, 1, 1), 1.0, { width = 1.0, t0 = 0.05 })
			FX.ring(CFrame.new(base + V(0, 0.12, 0)), 2, 18, B.hex("FF7AF5"), 1.4, { width = 0.8 })
			FX.ring(CFrame.new(base + V(0, 0.16, 0)), 1.5, 12, B.hex("7CC0FF"), 1.8, { width = 0.6 })
			for i, c in ipairs(RAINBOW) do
				local a = i / #RAINBOW * math.pi * 2
				FX.sparks(base + V(math.sin(a) * 3, 1, math.cos(a) * 3), 30, 2, { Color3.new(1, 1, 1), c })
			end
			FX.chunks(base + V(0, 1, 0), 14, 1.5)
			FX.shake(base, 1.4, 0.9)
		elseif not weak then
			FX.ring(CFrame.new(base + V(0, 0.08, 0)), 2.5, 16, B.hex("FFD27A"), 0.8, { width = 0.8 })
			FX.ring(CFrame.new(base + V(0, 0.12, 0)), 1.5, 11, Color3.new(1, 1, 1), 1.1, { width = 0.5 })
			FX.sparks(base + V(0, 1, 0), 50, 1.5)
			FX.shake(base, 0.8, 0.6)
		else
			FX.ring(CFrame.new(base + V(0, 0.08, 0)), 2, 9, B.hex("C8CDE6"), 0.7, { width = 0.4 })
			FX.shake(base, 0.4, 0.4)
		end
	end)
	S.duration = l0 + LS.ASCENT
	table.sort(S.events, function(a, b) return a[1] < b[1] end)
end

-- t 时刻的火箭位置 / 比例和台下暖光
function LS.at(S, t)
	local l0 = S.lift0 or 0
	if t < l0 then -- 熄火前的剧烈抖动
		local a = 0.25 * (1 - t / l0 * 0.5)
		S.rocket:PivotTo(S.home * CFrame.new((math.random() - 0.5) * a, 0, (math.random() - 0.5) * a) * CFrame.Angles((math.random() - 0.5) * 0.03, 0, (math.random() - 0.5) * 0.03))
		S.light.Brightness = (math.random() < 0.5) and 2.5 or 0.3
		S.light.Color = WARM
		FX.rumble(S.base, 0.7)
		return
	end
	if S.catch then -- 离台：回收支架张开
		local o = seg(t, l0 - 0.05, l0 + 0.25)
		CA.setPose(S.catch, S.catchPose0 + (1 - S.catchPose0) * o * o * (3 - 2 * o))
	end
	local u = seg(t, l0, l0 + LS.ASCENT)
	if u < 0.7 then FX.rumble(S.base, ((S.judge == "super") and 0.75 or 0.55) * (1 - u / 0.7)) end -- 升空时的余震，越飞越远越弱
	local y = LS.RISE * (0.12 * u + 0.88 * u * u) * ((S.judge == "stall") and 0.85 or 1)
	-- 离台时保持原尺寸，升到约 18 高（u = 0.4）以后再慢慢放大到飞行比例，远处放大不显突兀
	local g = seg(u, 0.4, 1)
	local k = S.scale0 * (1 + (RK.FLIGHT_SCALE - 1) * g * g * (3 - 2 * g))
	if math.abs(S.rocket:GetScale() - k) > 0.02 or (g >= 1 and S.rocket:GetScale() ~= k) then
		S.rocket:ScaleTo(k)
		S.lastPower = -1 -- 缩放后尾焰要按新比例重算
		setFlame(S, (S.judge == "super") and 1.2 or 1, S.judge == "super", "launch")
	end
	S.rocket:PivotTo(S.home + V(0, y, 0))
	local after = t - l0
	S.light.Color = (S.judge == "super") and Color3.new(1, 0.95, 0.9) or WARM
	S.light.Brightness = math.max(0, ((S.judge == "super") and 10 or 6) * (1 - after / 1.2))
	S.light.Range = 16 + 30 * math.max(0, 1 - after / 1.2)
end

function LS.runTo(S, t)
	while S.events[S.ei] and S.events[S.ei][1] <= t do
		S.events[S.ei][2]()
		S.ei += 1
	end
	S:at(t)
	S.t = t
end

function LS.launch(S, judge)
	S:startLaunch(judge)
	local t0 = os.clock()
	while true do
		local t = os.clock() - t0
		S:runTo(math.min(t, S.duration))
		if t >= S.duration then break end
		task.wait()
	end
end

-- 演示用：火箭放回台上、熄火、复原比例
function LS.reset(S)
	S.rocket:ScaleTo(S.scale0)
	S.rocket:PivotTo(S.home)
	S.lastPower = -1
	RK.setFlame(S.rocket, { power = 0 })
	S.light.Brightness = 0
	S.ignited = false
	for _, pe in ipairs(S.smoke) do pe.Rate = 0 end
	if S.catch then CA.setPose(S.catch, S.catchPose0) end
	smokeColor(S, B.hex("D6D9EA"), B.hex("9EA4BE"))
end

function LS.destroy(S)
	S.anchor:Destroy()
end

return LS
