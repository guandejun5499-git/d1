--[[
	RollReveal · P1 第 13 项 Roll 揭晓（ReplicatedStorage.OrbitShared.RollReveal）
	客户端表现。部件台由 06_home_roll 建（RollArea/PartPad_1–4 + RollButton），状态切换用 OrbitShared.PartPad。
	时间轴（约 2.2 s，Web Demo：1.15 s 开箱 + 每台间隔 0.16 s 揭晓）：
	  0.0–0.3   绿色按钮按下回弹 + 绿色冲击环；4 颗能量光球从按钮沿弧线飞向 4 座台
	  0.45–1.3  光球落到哪座台，哪座台就进入「开箱中」：环灯青色快闪、「? ? ?」卡、台面上青色星火盘旋上升
	  1.35 起   按稀有度从低到高依次揭晓（同档按台序），间隔 0.2 s：
	            部件弹出（0.2 → 1.12 → 1 倍）+ 价格卡弹出 + 稀有度色爆闪和冲击环 + 同色光柱升起
	            （基础 12 / 高级 24 / 精英 48 高）；精英另有金色火花雨、大范围闪光、镜头轻震，
	            揭晓光柱淡去后留下 PartPad 自带的常驻金色光柱
	RR.prepare(area, results, opts) → show；show:runTo(t) 触发 t 之前的事件并摆好 t 时刻（编辑模式可逐帧检查）。
	RR.play(area, results, opts)：跑完整段，返回 show。results = { nose = tier, tank = tier, engine = tier, fins = tier }。
	RR.buy(pad, target, opts)：买下——悬浮部件缩成稀有度色光球（拖尾 + 星火），弧线飞进 target（玩家 HumanoidRootPart，
	  会跟着移动），落到身上爆一下；台子转「已售出」。
	opts.homeColor：燃料舱色带。
]]

local B = require(script.Parent.BuildLib)
local PP = require(script.Parent.PartPad)
local FX = require(script.Parent.ShowFX)
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local V = Vector3.new
local NSK = NumberSequenceKeypoint.new
local RR = {}

RR.PILLAR_H = { 12, 24, 48 }
RR.COLORS = { B.hex("DDE5F2"), B.hex("3EA0FF"), B.hex("FFC53D") } -- 光柱 / 爆闪：基础偏白，比台上的银灰更亮
local CYAN = B.C.cyan
local GREEN = B.hex("3BD85C")
local T_FLY0, T_FLY = 0.12, 0.42 -- 光球出发时间与飞行时长（每颗错开 0.06）
local T_REVEAL, GAP = 1.35, 0.2
local RISE, HOLD, FADE = 0.3, 0.5, 1.2

local function clamp01(x) return math.clamp(x, 0, 1) end
local function smooth(x)
	x = clamp01(x)
	return x * x * (3 - 2 * x)
end
local function seg(t, t0, t1) return clamp01((t - t0) / (t1 - t0)) end
local function bezier(a, b, c, u) return a:Lerp(b, u):Lerp(b:Lerp(c, u), u) end

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

local function anchorPart(name, cf)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Transparency = 1
	p.Size = V(0.2, 0.2, 0.2)
	p.CFrame = cf
	p.Parent = folder()
	return p
end

-- 发光小球（光球 / 买下的部件）：Neon 球 + 点光源 + 拖尾 + 星火
local function orb(pos, color, size, opts)
	opts = opts or {}
	local p = Instance.new("Part")
	p.Name = "Orb"
	p.Shape = Enum.PartType.Ball
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = V(size, size, size)
	p.CastShadow = false
	p.CFrame = CFrame.new(pos)
	p.Parent = folder()
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness = color, opts.range or 8, opts.bright or 1.5
	l.Parent = p
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = V(0, size * 0.35, 0), V(0, -size * 0.35, 0)
	a0.Parent, a1.Parent = p, p
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	tr.LightEmission, tr.LightInfluence = 1, 0
	tr.Lifetime = opts.trail or 0.3
	tr.WidthScale = NumberSequence.new({ NSK(0, 1), NSK(1, 0) })
	tr.Transparency = NumberSequence.new({ NSK(0, 0.1), NSK(1, 1) })
	tr.FaceCamera = true
	tr.Parent = p
	if opts.sparkles then
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Color = ColorSequence.new(color)
		pe.LightEmission, pe.LightInfluence = 1, 0
		pe.Rate = opts.sparkles
		pe.Lifetime = NumberRange.new(0.3, 0.6)
		pe.Speed = NumberRange.new(0.5, 2)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.Size = NumberSequence.new({ NSK(0, size * 0.35), NSK(1, 0) })
		pe.Parent = p
	end
	return p
end

------------------------------------------------------------------ 准备
function RR.prepare(area, results, opts)
	opts = opts or {}
	local S = { area = area, results = results, opts = opts, pads = {}, events = {}, ei = 1, t = -1 }
	-- 按钮
	-- 开了 StreamingEnabled：客户端刚进来时零件可能还没流到，最多等 5 s，等不到的台子跳过
	local rb = area:WaitForChild("RollButton", 5)
	local btn = rb and rb:WaitForChild("Button", 5)
	if btn then
		S.button = { part = btn, cf = btn.CFrame }
		S.buttonTop = btn.Position + V(0, btn.Size.Y / 2, 0)
	else
		S.buttonTop = area:GetPivot().Position + V(0, 3, 0)
	end
	-- 部件台：按 Slot 对应结果；揭晓顺序 = 稀有度从低到高，同档按台序
	for i = 1, 4 do
		local pad = area:WaitForChild("PartPad_" .. i, 5)
		local ready = pad ~= nil
		for _, n in ipairs({ "RingLight", "Cap", "HoloDisc" }) do
			ready = ready and pad:WaitForChild(n, 5) ~= nil
		end
		if ready then
			local slot = pad:GetAttribute("Slot")
			local tier = results[slot] or 1
			local PC = pad:GetPivot()
			table.insert(S.pads, {
				pad = pad, i = i, slot = slot, tier = tier, PC = PC,
				top = (PC * CFrame.new(0, 2.15, 0)).Position,
				flyAt = T_FLY0 + (i - 1) * 0.06,
			})
		end
	end
	local order = table.clone(S.pads)
	table.sort(order, function(a, b) return a.tier < b.tier or (a.tier == b.tier and a.i < b.i) end)
	for k, p in ipairs(order) do
		p.revealAt = T_REVEAL + (k - 1) * GAP
	end
	S.duration = T_REVEAL + (#order - 1) * GAP + RISE + HOLD + FADE

	-- 光柱：两条 Beam（外层柔光 + 内层亮芯），顶端附件随时间升高
	for _, p in ipairs(S.pads) do
		local col = RR.COLORS[p.tier]
		local an = anchorPart("RevealPillar", CFrame.new(p.top))
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Parent, a1.Parent = an, an
		local function beam(w0, w1, tr0, emission)
			local bm = Instance.new("Beam")
			bm.Attachment0, bm.Attachment1 = a0, a1
			bm.FaceCamera = true
			bm.Width0, bm.Width1 = w0, w1
			bm.Color = ColorSequence.new(col)
			bm.LightEmission, bm.LightInfluence = emission, 0
			bm.Segments = 1
			bm.Enabled = false
			bm:SetAttribute("T0", tr0)
			bm.Parent = an
			return bm
		end
		local wide = (p.tier == 3) and 1.25 or 1
		p.pillar = {
			anchor = an, top = a1,
			outer = beam(5.2 * wide, 3.6 * wide, 0.45, 0.6),
			core = beam(1.6 * wide, 1.0 * wide, 0.15, 1),
		}
		-- 开箱中：台面上青色星火盘旋上升
		local sw = anchorPart("RollSwirl", CFrame.new(p.top + V(0, 0.2, 0)))
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Color = ColorSequence.new(Color3.new(1, 1, 1), CYAN)
		pe.LightEmission, pe.LightInfluence = 1, 0
		pe.Rate = 0
		pe.Lifetime = NumberRange.new(0.6, 1.0)
		pe.Speed = NumberRange.new(2, 4)
		pe.SpreadAngle = Vector2.new(25, 25)
		pe.EmissionDirection = Enum.NormalId.Top
		pe.RotSpeed = NumberRange.new(-200, 200)
		pe.Size = NumberSequence.new({ NSK(0, 0.35), NSK(1, 0) })
		pe.Shape = Enum.ParticleEmitterShape.Disc
		pe.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
		pe.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		pe.Parent = sw
		sw.Size = V(2.6, 0.2, 2.6)
		p.swirl = { part = sw, pe = pe }
	end

	-- 事件
	local function ev(t, fn) table.insert(S.events, { t, fn }) end
	ev(0, function()
		if S.buttonTop then
			FX.ring(CFrame.new(S.buttonTop - V(0, 1.7, 0)), 1.5, 6, GREEN, 0.45, { width = 0.35 })
			FX.flash(S.buttonTop, GREEN, 14, 3, 0.35)
		end
		for _, p in ipairs(S.pads) do PP.setState(p.pad, { mode = "idle" }, { homeColor = opts.homeColor }) end
	end)
	for _, p in ipairs(S.pads) do
		ev(p.flyAt, function()
			p.orb = orb(S.buttonTop, CYAN, 1.0, { trail = 0.3, range = 8, sparkles = 24 })
		end)
		ev(p.flyAt + T_FLY, function()
			if p.orb then p.orb:Destroy() p.orb = nil end
			PP.setState(p.pad, { mode = "rolling" }, { homeColor = opts.homeColor })
			FX.sparks(p.top + V(0, 0.3, 0), 14, 0.5, { Color3.new(1, 1, 1), CYAN })
			FX.ring(CFrame.new(p.top + V(0, 0.05, 0)), 0.8, 3.4, CYAN, 0.3, { width = 0.2 })
			p.swirl.pe.Rate = 26
		end)
		ev(p.revealAt, function()
			p.swirl.pe.Rate = 0
			PP.setState(p.pad, { mode = "offer", tier = p.tier }, { homeColor = opts.homeColor })
			local d = p.pad:FindFirstChild("Display")
			p.display = d and { model = d, s0 = d:GetScale() } or nil
			local att = p.pad:FindFirstChild("Cap") and p.pad.Cap:FindFirstChild("CardAnchor")
			local card = att and att:FindFirstChildOfClass("BillboardGui")
			p.card = card and { gui = card, size = card.Size } or nil
			local col = RR.COLORS[p.tier]
			local mid = p.top + V(0, 2.4, 0)
			if p.tier == 3 then
				FX.sparks(mid, 70, 1.6, { Color3.new(1, 1, 1), col })
				FX.chunks(mid, 12, 1.2, col)
				FX.flash(mid, col, 34, 6, 0.7)
				FX.ring(CFrame.new(p.top), 2.5, 13, col, 0.6, { width = 0.6 })
				FX.ring(CFrame.new(p.top + V(0, 0.1, 0)), 1.5, 8, Color3.new(1, 1, 1), 0.4, { width = 0.25 })
				FX.puff(mid, 20, col, 9, 1.6, { light = 1, influence = 0, life = 0.9, t0 = 0.3 })
				FX.shake(mid, 0.6, 0.3)
			elseif p.tier == 2 then
				FX.sparks(mid, 34, 1.1, { Color3.new(1, 1, 1), col })
				FX.flash(mid, col, 20, 4, 0.45)
				FX.ring(CFrame.new(p.top), 2, 8, col, 0.45, { width = 0.4 })
			else
				FX.sparks(mid, 16, 0.7, { Color3.new(1, 1, 1), col })
				FX.flash(mid, col, 12, 2.5, 0.3)
				FX.ring(CFrame.new(p.top), 1.8, 5.5, col, 0.35, { width = 0.3 })
			end
		end)
	end
	table.sort(S.events, function(a, b) return a[1] < b[1] end)
	return setmetatable(S, { __index = RR })
end

------------------------------------------------------------------ 每帧
function RR.at(S, t)
	-- 按钮按下回弹
	if S.button then
		local dip = smooth(seg(t, 0, 0.1)) * (1 - smooth(seg(t, 0.1, 0.32)))
		S.button.part.CFrame = S.button.cf * CFrame.new(0, -0.3 * dip, 0)
	end
	for _, p in ipairs(S.pads) do
		-- 光球沿弧线飞向台子
		if p.orb then
			local u = smooth(seg(t, p.flyAt, p.flyAt + T_FLY))
			local a, c = S.buttonTop, p.top + V(0, 0.6, 0)
			local b = (a + c) / 2 + V(0, 6, 0)
			p.orb.CFrame = CFrame.new(bezier(a, b, c, u))
		end
		-- 光柱：升起 → 停留 → 淡出（精英淡到 PartPad 常驻光柱）
		local pl = p.pillar
		local r0 = p.revealAt
		local rise = smooth(seg(t, r0, r0 + RISE))
		local fade = smooth(seg(t, r0 + RISE + HOLD, r0 + RISE + HOLD + FADE))
		local on = t >= r0 and fade < 1
		pl.top.Position = V(0, RR.PILLAR_H[p.tier] * (0.15 + 0.85 * rise), 0)
		for _, bm in ipairs({ pl.outer, pl.core }) do
			bm.Enabled = on
			local base = bm:GetAttribute("T0")
			local flick = (1 - rise) * 0.2
			local tr = base + (1 - base) * fade + flick
			bm.Transparency = NumberSequence.new({ NSK(0, math.min(1, tr)), NSK(0.7, math.min(1, tr + (1 - tr) * 0.5)), NSK(1, 1) })
		end
		-- 部件和价格卡弹出
		if p.display and p.display.model.Parent then
			local u = seg(t, r0, r0 + 0.3)
			local k = (u < 0.6) and (0.2 + 0.92 * smooth(u / 0.6)) or (1.12 - 0.12 * smooth((u - 0.6) / 0.4))
			if u >= 1 then k = 1 end
			p.display.model:ScaleTo(p.display.s0 * k)
		end
		if p.card and p.card.gui.Parent then
			local u = smooth(seg(t, r0 + 0.05, r0 + 0.25))
			local k = (u < 1) and (0.3 + 0.8 * u - 0.1 * u * u) or 1
			p.card.gui.Size = UDim2.fromScale(p.card.size.X.Scale * k, p.card.size.Y.Scale * k)
		end
	end
end

function RR.runTo(S, t)
	while S.events[S.ei] and S.events[S.ei][1] <= t do
		S.events[S.ei][2]()
		S.ei += 1
	end
	S:at(t)
	S.t = t
end

function RR.cleanup(S)
	for _, p in ipairs(S.pads) do
		if p.orb then p.orb:Destroy() end
		p.pillar.anchor:Destroy()
		p.swirl.part:Destroy()
		if p.display and p.display.model.Parent then p.display.model:ScaleTo(p.display.s0) end
		if p.card and p.card.gui.Parent then p.card.gui.Size = p.card.size end
	end
	if S.button then S.button.part.CFrame = S.button.cf end
end

function RR.play(area, results, opts)
	local S = RR.prepare(area, results, opts)
	local t0 = os.clock()
	while true do
		local t = os.clock() - t0
		S:runTo(math.min(t, S.duration))
		if t >= S.duration then break end
		task.wait()
	end
	S:cleanup()
	return S
end

------------------------------------------------------------------ 买下：部件化作光点飞进玩家
function RR.buy(pad, target, opts)
	opts = opts or {}
	local tier = tonumber(tostring(pad:GetAttribute("State")):match("Tier(%d)")) or 1
	local col = RR.COLORS[tier]
	local d = pad:FindFirstChild("Display")
	local start = d and d:GetBoundingBox().Position or (pad:GetPivot() * CFrame.new(0, 4, 0)).Position
	-- 部件缩小成光球（0.18 s）
	if d then
		local s0 = d:GetScale()
		local t0 = os.clock()
		while os.clock() - t0 < 0.18 do
			d:ScaleTo(s0 * math.max(0.05, 1 - (os.clock() - t0) / 0.18))
			task.wait()
		end
	end
	FX.flash(start, col, 14, 3, 0.3)
	FX.sparks(start, 20, 0.8, { Color3.new(1, 1, 1), col })
	PP.setState(pad, { mode = "sold" }, { homeColor = opts.homeColor })
	local o = orb(start, col, 1.0, { trail = 0.45, sparkles = 30, range = 10, bright = 2 })
	-- 弧线飞向玩家（终点每帧跟着玩家）
	local dur = opts.dur or 0.7
	local t0 = os.clock()
	local function goal()
		if typeof(target) == "Instance" and target.Parent then return target.Position + V(0, 0.5, 0) end
		if typeof(target) == "Vector3" then return target end
		return start + V(0, 0, 6)
	end
	while true do
		local u = math.min(1, (os.clock() - t0) / dur)
		local e = u * u * (3 - 2 * u)
		local g = goal()
		local mid = (start + g) / 2 + V(0, 7, 0)
		o.CFrame = CFrame.new(bezier(start, mid, g, e))
		o.Size = V(1, 1, 1) * (1 - 0.4 * e)
		if u >= 1 then break end
		task.wait()
	end
	local g = goal()
	o.Transparency = 1
	for _, x in ipairs(o:GetChildren()) do
		if x:IsA("ParticleEmitter") then x.Enabled = false end
	end
	Debris:AddItem(o, 0.5)
	FX.sparks(g, 30, 1, { Color3.new(1, 1, 1), col })
	FX.flash(g, col, 12, 3, 0.4)
	FX.ring(CFrame.new(g - V(0, 2.8, 0)), 0.8, 4.5, col, 0.4, { width = 0.3 })
end

return RR
