--[[
	FlightShow · P1 第 15 项 飞行表现（ReplicatedStorage.OrbitShared.FlightShow）
	客户端表现。航线沿用 Web Demo buildPath（乘场景放大 1.3，Orbits 模块）：
	  爬升（接着 LaunchShow 的升空，或从台面自己起飞）→ 进月球门 → 绕月 N 圈 →（可选：转场木星绕 N 圈）→ 返航 → 台上空悬停 → 降落
	表现：
	  尾焰外发光：喷口一颗半透明 Neon 光球 + 点光源（尾焰色）
	  尾迹：喷口一条尾焰色拖尾（1.4 s）+ 一条更长的白色航迹云（3 s）
	  过门：门上一圈金色闪光环
	  轨道狂热（fever）：开始时三层彩虹冲击环 + 彩虹火花；尾焰变彩虹、拖尾换成更长更宽的彩虹拖尾、
	    火箭周围彩虹星火；轨道虚线变成流动的彩虹、轨道门切到 fever（放大 1.6 倍、彩虹）；离开轨道时恢复
	  返航降落：反推尾焰（短、带烟），落地前缩回原尺寸
	FS.prepare(rocket, padCF, legs, opts) → show
	  padCF = 台上火箭的落位（PadRocket 原来的 pivot）；legs = { { body = "moon", orbits = 2, fever = { [2] = true } } }
	  opts.speed（默认 1.2）；opts.fromPad = true 时从台面起飞（邻居 / 单独演示），否则从火箭当前位置接着爬升；
	  opts.worldFever = false：狂热时不改轨道线和门（邻居的火箭用）
	  opts.landing = "perfect" | "great" | "early" | "crash"、opts.streak：降落和落地交给 CatchShow（第 16 项）；
	  "crash" 落地后再调 CrashShow.play（第 17 项）
	show:runTo(t) 逐帧 / show:play() 跑完；show.duration 总时长；FS.cleanup(show) 拆掉拖尾和光球、恢复轨道线和门
]]

local B = require(script.Parent.BuildLib)
local RK = require(script.Parent.RocketKit)
local O = require(script.Parent.Orbits)
local G = require(script.Parent.OrbitGate)
local FX = require(script.Parent.ShowFX)
local CA = require(script.Parent.CatchArms)
local CatchShow = require(script.Parent.CatchShow)
local CS = game:GetService("CollectionService")

local V = Vector3.new
local NSK = NumberSequenceKeypoint.new
local S13 = O.S
local FS = {}

local RAINBOW = { B.hex("FF5E7A"), B.hex("FFB33D"), B.hex("FFE14D"), B.hex("3BD85C"), B.hex("3EA0FF"), B.hex("A46BFF") }
local GOLD = B.hex("FFC93C")

local function clamp01(x) return math.clamp(x, 0, 1) end
local function smooth(x)
	x = clamp01(x)
	return x * x * (3 - 2 * x)
end
local function bez3(p0, p1, p2, p3, u)
	local m = 1 - u
	return p0 * (m * m * m) + p1 * (3 * m * m * u) + p2 * (3 * m * u * u) + p3 * (u * u * u)
end

local function planetsFolder()
	local w = workspace:FindFirstChild("OrbitWorld")
	return w and w:FindFirstChild("Planets")
end
local MODEL_OF = { moon = "Moon", jupiter = "Jupiter" }

------------------------------------------------------------------ 拖尾 / 光球
local function trail(parent, a0, a1, color, life, emission, transp)
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Color = color
	tr.Lifetime = life
	tr.LightEmission, tr.LightInfluence = emission, 0
	tr.FaceCamera = true
	tr.MinLength = 0.2
	tr.WidthScale = NumberSequence.new({ NSK(0, 1), NSK(1, 0.25) })
	tr.Transparency = transp
	tr.Parent = parent
	return tr
end

-- 给火箭挂飞行表现（拖尾、航迹云、喷口光球、狂热星火）；返回句柄
function FS.attach(rocket)
	local f = rocket:FindFirstChild("Flame")
	local anchor = f and f:FindFirstChild("FlameAnchor")
	if not anchor then return nil end
	local tier = f:GetAttribute("Tier") or 1
	local col = RK.FLAME[tier]
	local s = rocket:GetScale()
	local H = {}
	local folder = Instance.new("Folder")
	folder.Name = "FlightFX"
	folder.Parent = rocket
	H.folder = folder
	-- 喷口两侧的拖尾附件（喷口局部 X 方向，宽 2.6）
	local function att(x, y)
		local a = Instance.new("Attachment")
		a.Name = "FlightAtt"
		a.Position = V(x, y, 0)
		a.Parent = anchor
		return a
	end
	local w = 1.3
	local a0, a1 = att(-w, -0.6), att(w, -0.6)
	local c0, c1 = att(-0.35, -1.2), att(0.35, -1.2)
	H.flameTrail = trail(anchor, a0, a1, ColorSequence.new({
		ColorSequenceKeypoint.new(0, col.inner), ColorSequenceKeypoint.new(0.35, col.outer), ColorSequenceKeypoint.new(1, B.hex("3A3458")),
	}), 1.4, 0.8, NumberSequence.new({ NSK(0, 0.2), NSK(0.6, 0.6), NSK(1, 1) }))
	H.contrail = trail(anchor, c0, c1, ColorSequence.new(Color3.new(1, 1, 1), B.hex("C9CEE8")), 3, 0.3,
		NumberSequence.new({ NSK(0, 0.55), NSK(1, 1) }))
	H.contrail.WidthScale = NumberSequence.new({ NSK(0, 1), NSK(1, 3.5) }) -- 航迹云越往后越散
	H.rainbowTrail = trail(anchor, a0, a1, RK.RAINBOW, 2.6, 1, NumberSequence.new({ NSK(0, 0.05), NSK(0.7, 0.35), NSK(1, 1) }))
	H.rainbowTrail.WidthScale = NumberSequence.new({ NSK(0, 1.6), NSK(1, 0.6) })
	H.rainbowTrail.Enabled = false
	for _, t in ipairs({ H.flameTrail, H.contrail, H.rainbowTrail }) do t:SetAttribute("FlightFX", true) end
	-- 喷口外发光
	local g = Instance.new("Part")
	g.Name = "FlameGlow"
	g.Shape = Enum.PartType.Ball
	g.Anchored, g.CanCollide, g.CanQuery, g.CanTouch, g.CastShadow = true, false, false, false, false
	g.Material = Enum.Material.Neon
	g.Color = col.outer
	g.Transparency = 0.72
	g.Size = V(2.6, 2.6, 2.6) * s
	g.CFrame = anchor.CFrame * CFrame.new(0, -0.8 * s, 0)
	g.Parent = folder
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness, l.Shadows = col.outer, 22, 2, false
	l.Parent = g
	H.glow, H.light = g, l
	-- 狂热星火（火箭周围）
	local au = Instance.new("Attachment")
	au.Name = "FeverAura"
	au.Position = V(0, 4 * s, 0)
	au.Parent = anchor
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = RK.RAINBOW
	pe.LightEmission, pe.LightInfluence = 1, 0
	pe.Rate = 0
	pe.Lifetime = NumberRange.new(0.5, 0.9)
	pe.Speed = NumberRange.new(4, 9)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Drag = 2
	pe.Size = NumberSequence.new({ NSK(0, 0.9), NSK(1, 0) })
	pe.Parent = au
	H.aura = pe
	H.col, H.tier, H.anchor = col, tier, anchor
	return H
end

------------------------------------------------------------------ 轨道线 / 门的狂热态（本地）
local function orbitParts(body)
	local pf = planetsFolder()
	local m = pf and pf:FindFirstChild(MODEL_OF[body])
	if not m then return {}, nil end
	local dashes = {}
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("BasePart") and p.Name == "OrbitDash" then table.insert(dashes, p) end
	end
	return dashes, m:FindFirstChild("OrbitGate")
end

local function setOrbitFever(S, body, on)
	local dashes, gate = orbitParts(body)
	S.saved = S.saved or {}
	local c = O.bodies[body].c
	for _, p in ipairs(dashes) do
		if on then
			if not S.saved[p] then S.saved[p] = { p.Color, p.Transparency } end
			-- 按绕行角度给彩虹偏移，客户端 RainbowFX 让颜色沿轨道流动
			local d = p.Position - c
			local a = math.atan2(d.Z, d.X)
			p:SetAttribute("RainbowOffset", (a / (math.pi * 2)) % 1)
			p.Transparency = 0.15
			CS:AddTag(p, "RainbowFX")
		elseif S.saved[p] then
			CS:RemoveTag(p, "RainbowFX")
			p.Color, p.Transparency = S.saved[p][1], S.saved[p][2]
		end
	end
	if gate then
		if on then
			S.gateState = S.gateState or {}
			if S.gateState[gate] == nil then S.gateState[gate] = gate:GetAttribute("State") or "normal" end
			G.setState(gate, "fever")
		elseif S.gateState and S.gateState[gate] then
			G.setState(gate, S.gateState[gate])
		end
	end
end

------------------------------------------------------------------ 航线
function FS.prepare(rocket, padCF, legs, opts)
	opts = opts or {}
	local S = { rocket = rocket, padCF = padCF, legs = legs, opts = opts, events = {}, ei = 1, segs = {} }
	local speed = opts.speed or 1.2
	local padTop = padCF.Position
	-- 原尺寸：调用方传入（接着 LaunchShow 时火箭已放大，要传它记下的起飞前比例）；从台面起飞时就是当前比例
	S.scale0 = opts.scale0 or (opts.fromPad and rocket:GetScale()) or 1
	S.flightScale = RK.FLIGHT_SCALE
	local t = 0
	local function add(sg)
		sg.t0 = t
		table.insert(S.segs, sg)
		t += sg.dur
	end
	local b0 = O.bodies[legs[1].body]
	local e0, tan0 = O.pt(b0, b0.a0), O.tan(b0, b0.a0)
	-- 爬升：接着当前位置（LaunchShow 已升空）或从台面起飞
	local s0 = opts.fromPad and padTop or rocket:GetPivot().Position
	local s1 = s0 + V(0, (opts.fromPad and 90 or 45) * S13, 0)
	local s2 = e0 - tan0 * (45 * S13)
	add({ type = "ascent", dur = (opts.fromPad and 3.6 or 2.6) / speed, pos = function(u) return bez3(s0, s1, s2, e0, 0.35 * u + 0.65 * u * u) end })
	local last, lastTan = e0, tan0
	for li, leg in ipairs(legs) do
		local b = O.bodies[leg.body]
		if li > 1 then
			local e, tn = O.pt(b, b.a0), O.tan(b, b.a0)
			local p0, p1, p2 = last, last + lastTan * (80 * S13), e - tn * (200 * S13)
			add({ type = "transfer", body = leg.body, dur = 4.8 / speed, pos = function(u) return bez3(p0, p1, p2, e, u) end })
		end
		for k = 1, leg.orbits do
			add({ type = "orbit", body = leg.body, lap = k, fever = leg.fever and leg.fever[k] or false, dur = b.orbitDur / speed,
				pos = function(u) return O.pt(b, b.a0 + math.pi * 2 * u) end })
		end
		last, lastTan = O.pt(b, b.a0), O.tan(b, b.a0)
	end
	local hover = padTop + V(0, 45 * S13, 0)
	local r0, r1, r2 = last, last + lastTan * (70 * S13), hover + V(0, 60 * S13, 0)
	add({ type = "return", dur = ((#legs > 1) and 5.8 or 4.2) / speed, pos = function(u) return bez3(r0, r1, r2, hover, u) end })
	add({ type = "land", dur = 2.6, pos = function(u) return hover:Lerp(padTop, 1 - (1 - u) ^ 2.2) end })
	S.duration = t
	S.hover = hover

	-- 事件：过门闪光、狂热开始 / 结束、尾焰模式
	local function ev(tt, fn) table.insert(S.events, { tt, fn }) end
	local planned = false -- 排时间轴时的狂热状态（运行时看 S.fever）
	for i, sg in ipairs(S.segs) do
		if sg.type == "orbit" then
			local b = O.bodies[sg.body]
			ev(sg.t0, function()
				local gcf = O.gateCF(b)
				FX.ring(gcf * CFrame.Angles(math.pi / 2, 0, 0), b.gateR * 1.1, b.gateR * 2.2, sg.fever and Color3.new(1, 1, 1) or GOLD, 0.6, { width = 0.8, height = 0.3 })
				FX.sparks(gcf.Position, 24, 1.2, { Color3.new(1, 1, 1), sg.fever and RAINBOW[(i % #RAINBOW) + 1] or GOLD })
				if sg.fever and not S.fever then
					S:setFever(true, sg.body)
				elseif not sg.fever and S.fever then
					S:setFever(false, sg.body)
				end
			end)
			planned = sg.fever
		elseif sg.type ~= "ascent" and planned then
			local body = S.segs[i - 1].body
			ev(sg.t0, function()
				if S.fever then S:setFever(false, body) end
			end)
			planned = false
		end
		if sg.type == "return" then
			ev(sg.t0, function() S:flame(0.7, false, "flight") end)
		elseif sg.type == "land" then
			ev(sg.t0, function() S:flame(0.6, false, "retro") end)
			ev(sg.t0 + sg.dur - 0.05, function() S:flame(0, false, "flight") end)
		end
	end
	table.sort(S.events, function(a, b) return a[1] < b[1] end)
	S.H = FS.attach(rocket)
	-- 回收支架：从台面起飞时先张开；降落时张开，落地瞬间合拢
	local area = opts.launchArea or (rocket.Parent and rocket.Parent:FindFirstChild("CatchArms") and rocket.Parent)
	S.catch = area and area:FindFirstChild("CatchArms")
	-- 落地后的合拢角：调用方传入（宽火箭不能合到 0，见 AssemblyShow.closeAlpha）；
	-- 从台面起飞时支架还在原来的夹紧姿态，直接读它
	S.catchClosed = opts.catchClosed or (opts.fromPad and S.catch and S.catch:GetAttribute("Pose")) or 0
	if opts.landing and area then
		S.catchShow = CatchShow.prepare(area, rocket, opts.landing, opts.streak)
		local land = S.segs[#S.segs]
		table.insert(S.events, { land.t0 + land.dur, function() S.catchShow:touchdown() end })
		table.sort(S.events, function(a, b) return a[1] < b[1] end)
	end
	S.fever = false
	S.lastQ = rocket:GetPivot() - rocket:GetPivot().Position
	return setmetatable(S, { __index = FS })
end

function FS.flame(S, power, rainbow, mode)
	RK.setFlame(S.rocket, { power = power, rainbow = rainbow, mode = mode })
	S.flameState = { power, rainbow, mode }
	local H = S.H
	if H then
		H.glow.Transparency = (power > 0.01) and 0.72 or 1
		H.light.Enabled = power > 0.01
		H.flameTrail.Enabled = power > 0.01 and not rainbow
		H.contrail.Enabled = power > 0.01
		H.rainbowTrail.Enabled = power > 0.01 and rainbow
	end
end

function FS.setFever(S, on, body)
	S.fever = on
	local H = S.H
	local pos = S.rocket:GetPivot().Position
	if on then
		for i = 1, 3 do
			FX.ring(CFrame.new(pos) * CFrame.Angles(math.pi / 2 * (i - 1) / 2, 0, 0), 2, 9 + i * 4, RAINBOW[i * 2], 0.7 + i * 0.2, { width = 0.8 })
		end
		for i, c in ipairs(RAINBOW) do FX.sparks(pos, 26, 2.2, { Color3.new(1, 1, 1), c }) end
		FX.flash(pos, B.hex("FF9AF5"), 40, 6, 0.8)
		if H then H.aura.Rate = 70 end
	else
		if H then H.aura.Rate = 0 end
	end
	S:flame(1, on, "flight")
	-- 轨道线和门变彩虹只跟自己的狂热走；邻居的狂热只显示在他的火箭上（opts.worldFever = false）
	if S.opts.worldFever ~= false then setOrbitFever(S, body, on) end
	if H then
		H.glow.Color = on and Color3.new(1, 1, 1) or H.col.outer
		H.light.Color = on and B.hex("FF9AF5") or H.col.outer
		if on then CS:AddTag(H.glow, "RainbowFX") else CS:RemoveTag(H.glow, "RainbowFX") H.glow.Color = H.col.outer end
	end
end

local function segAt(S, t)
	for i = #S.segs, 1, -1 do
		if t >= S.segs[i].t0 then return S.segs[i], i end
	end
	return S.segs[1], 1
end

local function posAt(S, t)
	local sg = segAt(S, math.clamp(t, 0, S.duration))
	return sg.pos(clamp01((t - sg.t0) / sg.dur)), sg
end

function FS.at(S, t)
	local p, sg = posAt(S, t)
	local u = clamp01((t - sg.t0) / sg.dur)
	-- 朝向：机头沿速度方向；返航后半段慢慢转回竖直，降落保持竖直
	local a, b = posAt(S, math.max(0, t - 0.03)), posAt(S, t + 0.03)
	local dir = b - a
	local target = CFrame.identity
	if dir.Magnitude > 1e-3 and sg.type ~= "land" then
		local d = dir.Unit
		local axis = Vector3.yAxis:Cross(d)
		if axis.Magnitude > 1e-4 then
			target = CFrame.fromAxisAngle(axis.Unit, math.acos(math.clamp(Vector3.yAxis:Dot(d), -1, 1)))
		elseif d.Y < 0 then
			target = CFrame.Angles(math.pi, 0, 0)
		end
		if sg.type == "return" then target = target:Lerp(CFrame.identity, smooth((u - 0.4) / 0.6)) end
		if sg.type == "ascent" and u < 0.03 then target = CFrame.identity end
	end
	local base = S.padCF - S.padCF.Position
	-- 朝向平滑按时间算（原来每帧 0.35，帧率低时转得慢）：60 FPS 下等同 0.35 / 帧
	local dt = S.lastT and math.clamp(t - S.lastT, 0, 0.25) or 0
	S.lastT = t
	local turn = (dt > 0) and (1 - 0.65 ^ (dt * 60)) or 0.35
	local q = S.lastQ:Lerp(target * base, turn)
	S.lastQ = q
	-- 尺寸：降落时缩回原尺寸
	local k = S.flightScale
	if sg.type == "ascent" and S.opts.fromPad then -- 从台面起飞：离台后再慢慢放大（同 LaunchShow）
		k = S.scale0 + (S.flightScale - S.scale0) * smooth((u - 0.3) / 0.7)
	end
	if sg.type == "land" then k = S.flightScale + (S.scale0 - S.flightScale) * smooth(u / 0.7) end
	if math.abs(S.rocket:GetScale() - k) > 0.02 or (sg.type == "land" and u >= 1 and S.rocket:GetScale() ~= k) then
		S.rocket:ScaleTo(k)
		if S.flameState then S:flame(table.unpack(S.flameState)) end
	end
	S.rocket:PivotTo(q + p)
	if S.catchShow and sg.type == "land" then
		S.catchShow:land(u, sg.dur)
	elseif S.catch and not S.catchShow then
		local pose
		if sg.type == "ascent" and S.opts.fromPad then pose = smooth(u / 0.06) end
		if sg.type == "land" then pose = 1 - smooth((u - 0.86) / 0.14) * (1 - S.catchClosed) end
		if pose then CA.setPose(S.catch, pose) end
	end
	-- 喷口光球跟着喷口
	local H = S.H
	if H then
		local sc = S.rocket:GetScale()
		H.glow.Size = V(2.6, 2.6, 2.6) * sc * (S.fever and 1.4 or 1)
		H.glow.CFrame = H.anchor.CFrame * CFrame.new(0, -0.8 * sc, 0)
	end
end

function FS.runTo(S, t)
	if not S.started then
		S.started = true
		S:flame(1, false, "flight")
	end
	while S.events[S.ei] and S.events[S.ei][1] <= t do
		S.events[S.ei][2]()
		S.ei += 1
	end
	S:at(t)
end

function FS.play(S)
	local t0 = os.clock()
	while true do
		local t = os.clock() - t0
		S:runTo(math.min(t, S.duration))
		if t >= S.duration then break end
		task.wait()
	end
end

function FS.cleanup(S)
	if S.fever then
		for _, sg in ipairs(S.segs) do
			if sg.body then setOrbitFever(S, sg.body, false) end
		end
	end
	if S.H then S.H.folder:Destroy() end
	for _, x in ipairs(S.rocket:GetDescendants()) do
		if x:IsA("Trail") and x:GetAttribute("FlightFX") then x:Destroy() end
		if x:IsA("Attachment") and (x.Name == "FlightAtt" or x.Name == "FeverAura") then x:Destroy() end
	end
	S.rocket:ScaleTo(S.scale0)
	S.rocket:PivotTo(S.padCF)
	RK.setFlame(S.rocket, { power = 0 })
end

return FS
