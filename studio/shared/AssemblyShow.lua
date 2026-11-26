--[[
	AssemblyShow · P1 第 12 项 组装演出（ReplicatedStorage.OrbitShared.AssemblyShow）
	客户端表现：舱内 5.6 s + 运输带 2.8 s。
	  0.0–1.35  龙门吊到发动机坞：部件在托盘上「长出来」（0.3 → 0.5 倍），吊起后边走边放大到实尺寸，落到转台 → 撞击火花
	  1.4–2.1   4 片尾翼依次从外侧滑入卡位（两台机械臂在尾翼之间的空档轻摆）
	  1.35–2.75 龙门吊吊燃料舱对接（最重，火花最多）
	  2.75–3.9  龙门吊吊鼻锥落位，抓爪张开升起、让到部件坞一侧
	  3.95–4.45 两台机械臂在燃料舱外壁点焊（蓝白焊花）
	  4.45–4.65 机械臂向 +X 收起；4.6–5.15 转台带火箭转一圈；5.15 状态灯转绿
	  4.9–5.2   舱门打开；5.2–5.6 火箭移到门口
	  5.6–8.4   运输带两段（先直行出门再斜向发射台，箭头和滚筒滚动）；带尾把火箭托高到台面，
	            发射台回收支架向外放平迎接（6.6–7.2），火箭滑到台心，支架合拢夹住（8.1–8.4），替换台上旧火箭
	  6.3–6.7   舱门关上、机械臂回位
	AS.prepare(bay, eq, homeColor, opts) → show；show:at(t) 按时间摆好所有零件（纯函数，可在编辑模式逐帧检查）；
	  show:finish() 收尾（火箭留在发射台、舱内零件复位）。
	AS.play(bay, eq, homeColor, opts) 按时间轴跑完整演出并触发特效，返回新火箭（坞清空、状态「待组装」、全息复位）。
	opts.padRocket：台上旧火箭（默认在 bay.Parent 里找 PadRocket）；opts.padParent：新火箭的父级（默认 = 旧火箭的父级）。
	11-25：用户指出两根液压支柱挡住出舱 → 做了全程碰撞扫描，去掉支柱、机械臂挪到尾翼空档、门加高加宽、运输带先直行。
]]

local B = require(script.Parent.BuildLib)
local RK = require(script.Parent.RocketKit)
local AB = require(script.Parent.AssemblyBay)
local CA = require(script.Parent.CatchArms)
local FX = require(script.Parent.ShowFX)
local CS = game:GetService("CollectionService")

local V = Vector3.new
local AS = {}
AS.SHOW = 5.6
AS.TRANSIT = 2.8
AS.TOTAL = AS.SHOW + AS.TRANSIT

local SEAT = 1.78 -- 转台顶面 1.7（虚线顶 1.755）之上
local BELT_Y = 0.8 -- 运输带箭头顶 0.655、转角圆台顶 0.71 之上（发动机喷口略低于底面）
local CLAW_REST = 15.2 -- 抓爪底面静止高度（建造时的位置）
local CLAW_MAX = 18.35 -- 抓爪底面最高（缆绳从横梁底面 18.9 放下）
local CABLE_TOP = 18.9
local GRIP = 0.15 -- 部件顶面在抓爪底面以下 0.15（四指包住顶部）
local SMAT = 0.3 -- 部件在坞里长到 0.3 倍就吊走，离开机械墙后边走边放大到实尺寸（巨型燃料舱侧挂舱半径约 4.4）
local DOCK_X, DOCK_Y = 6.2, 4.4
local DOCK_Z = { nose = -5.4, tank = -1.8, engine = 1.8, fins = 5.4 }
local DOCK_I = { nose = 1, tank = 2, engine = 3, fins = 4 }
local DOOR_X = -8.6
local PARK = V(4.2, 0, 0) -- 焊接时龙门吊让到部件坞一侧
local SPREAD = 0.45 -- 抓爪四指松开时向外张开

local function clamp01(x) return math.clamp(x, 0, 1) end
local function smooth(x)
	x = clamp01(x)
	return x * x * (3 - 2 * x)
end
local function seg(t, t0, t1) return clamp01((t - t0) / (t1 - t0)) end
local function lerp(a, b, u) return a + (b - a) * u end

-- 吊装三步：go 离开 → at 到坞上方 → down 落到坞 → mat 长成 0.5 倍 → up 吊起 → over 到转台上方（边走边放大）→ seat 落位
local STEPS = {
	{ slot = "engine", go = 0.0, at = 0.3, down = 0.5, mat = 0.7, up = 0.9, over = 1.15, seat = 1.35 },
	{ slot = "tank", go = 1.35, at = 1.65, down = 1.85, mat = 2.05, up = 2.25, over = 2.5, seat = 2.75 },
	{ slot = "nose", go = 2.75, at = 3.0, down = 3.15, mat = 3.3, up = 3.5, over = 3.7, seat = 3.9 },
}
local FIN_T0, FIN_GAP, FIN_DUR, FIN_OUT = 1.4, 0.13, 0.3, 1.8
local WELD0, WELD1 = 3.95, 4.45
local ARM_OUT, ARM_BACK = { 4.45, 4.65 }, { 6.3, 6.7 }
local SPIN0, SPIN1 = 4.6, 5.15
local DOOR_OPEN, DOOR_SHUT = { 4.9, 5.2 }, { 6.3, 6.7 }
local EXIT0 = 5.2
local PAD_OPEN, PAD_CLOSE, PAD_WIDE = { 6.6, 7.2 }, { 8.1, 8.4 }, 2.9 -- 回收支架放平到 28° × 2.9 ≈ 81°

------------------------------------------------------------------ 准备
function AS.prepare(bay, eq, homeColor, opts)
	opts = opts or {}
	local BAY = bay:GetPivot()
	local hE, hT, hN = B.ENGINE_H[eq.engine], B.TANK_H[eq.tank], B.NOSE_H[eq.nose]
	local origin = { engine = 0, tank = hE, fins = hE, nose = hE + hT }
	local height = { engine = hE, tank = hT, nose = hN }
	local seatB = { engine = SEAT, tank = SEAT + hE, nose = SEAT + hE + hT }
	local liftB = { engine = 6.6, tank = math.max(6.6, SEAT + hE + 0.5), nose = SEAT + hE + hT + 0.4 }
	-- 吊挂用实际高度（气动鼻锥的尖刺比名义高度高 0.86）
	local hang = { engine = hE, tank = hT, nose = hN }

	local S = { bay = bay, BAY = BAY, eq = eq, homeColor = homeColor }

	-- 新火箭：先建在转台上，零件按部位分组
	local rocket = RK.build(eq, homeColor, BAY * CFrame.new(0, SEAT, 0), bay)
	rocket.Name = "AssemblyRocket"
	S.rocket = rocket
	S.spinTags = {}
	for _, d in ipairs(rocket:GetDescendants()) do
		if CS:HasTag(d, "SpinFX") then
			table.insert(S.spinTags, d)
			CS:RemoveTag(d, "SpinFX")
		end
	end
	local pivot0 = rocket:GetPivot()
	-- 嵌套模型（全息环、尾焰等）的轴心：零件是逐个摆的，轴心不会跟着走，收尾时按这里记下的相对位置放回
	-- （11-25 用户发现：组装后全息环绕着组装舱位置乱转，就是轴心留在了转台上）
	S.subPivots = {}
	for _, d in ipairs(rocket:GetDescendants()) do
		if d:IsA("Model") then S.subPivots[d] = pivot0:ToObjectSpace(d:GetPivot()) end
	end
	local GROUP = { Nose = "nose", Tank = "tank", Fins = "fins" }
	S.rparts = {}
	S.emitters = { engine = {}, tank = {}, fins = {}, nose = {} }
	for _, ch in ipairs(rocket:GetChildren()) do
		local g = GROUP[ch.Name] or "engine"
		for _, d in ipairs(ch:GetDescendants()) do
			if d:IsA("BasePart") then
				local rel = CFrame.new(0, -origin[g], 0) * pivot0:ToObjectSpace(d.CFrame)
				local rec = { part = d, g = g, rel = rel, size = d.Size }
				if g == "fins" then
					local a = math.atan2(rel.X, rel.Z) % (math.pi * 2)
					rec.k = math.floor(a / (math.pi / 2)) % 4
					local ang = math.rad(45 + 90 * rec.k)
					rec.dir = V(math.sin(ang), 0, math.cos(ang))
				end
				table.insert(S.rparts, rec)
				if hang[g] then
					local _, y, _, _, _, _, r10, r11, r12 = rel:GetComponents()
					local top = y + (math.abs(r10) * d.Size.X + math.abs(r11) * d.Size.Y + math.abs(r12) * d.Size.Z) / 2
					if d.Transparency < 0.95 then hang[g] = math.max(hang[g], top) end
				end
			elseif d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") then
				table.insert(S.emitters[g], { inst = d, on = d.Enabled })
			end
		end
	end

	-- 龙门吊
	local crane = bay:FindFirstChild("Gantry")
	S.crane = {}
	if crane then
		for _, p in ipairs(crane:GetDescendants()) do
			if p:IsA("BasePart") then
				local role = (p.Name == "Beam" or p.Name == "EndTruck") and "bridge"
					or (p.Name == "Trolley") and "trolley"
					or (p.Name == "Cable") and "cable"
					or (p.Name == "Finger") and "finger"
					or "claw"
				local rel = BAY:ToObjectSpace(p.CFrame)
				local out = V(rel.X, 0, rel.Z)
				table.insert(S.crane, { part = p, role = role, rel = rel, size = p.Size, out = out.Magnitude > 0.01 and out.Unit or Vector3.zero })
			end
		end
	end
	-- 龙门吊关键帧 {t, x, z, 抓爪底面高度}
	local keys = { { 0, 0, 0, CLAW_REST } }
	local function key(t, x, z, cb) table.insert(keys, { t, x, z, math.min(cb, CLAW_MAX) }) end
	local prevCb = CLAW_REST
	for _, st in ipairs(STEPS) do
		local h = hang[st.slot]
		local z = DOCK_Z[st.slot]
		key(st.go + 0.08, 0, 0, math.max(CLAW_REST, prevCb)) -- 先升起
		key(st.at, DOCK_X, z, CLAW_REST)
		key(st.down, DOCK_X, z, DOCK_Y + 0.1 + h * SMAT + GRIP)
		key(st.mat, DOCK_X, z, DOCK_Y + 0.1 + h * SMAT + GRIP)
		key(st.up, DOCK_X - 1.2, z, liftB[st.slot] + h + GRIP) -- 边吊边离开机械墙（墙上有管线）
		key(st.over, 0, 0, liftB[st.slot] + h + GRIP)
		key(st.seat, 0, 0, seatB[st.slot] + h + GRIP)
		prevCb = seatB[st.slot] + h + GRIP
	end
	key(4.05, 0, 0, CLAW_MAX) -- 松开鼻锥后直接升到最高，再让开
	key(4.4, PARK.X, PARK.Z, CLAW_MAX)
	key(5.6, PARK.X, PARK.Z, CLAW_MAX)
	key(6.3, 0, 0, CLAW_REST)
	S.keys = keys
	S.carry = {}
	for _, st in ipairs(STEPS) do
		S.carry[st.slot] = st
	end
	S.height, S.origin, S.seatB, S.hang = height, origin, seatB, hang

	-- 机械臂：绕底座竖轴摆动；retract = 让臂指向 +X（收到部件坞一侧）所需的转角
	S.arms = {}
	for i, name in ipairs({ "WeldArm_A", "WeldArm_B" }) do
		local a = bay:FindFirstChild(name)
		local base = a and a:FindFirstChild("Base")
		if base then
			local pv = CFrame.new(base.Position) * (BAY - BAY.Position)
			local recs = {}
			for _, p in ipairs(a:GetDescendants()) do
				if p:IsA("BasePart") and p ~= base then
					table.insert(recs, { part = p, rel = pv:ToObjectSpace(p.CFrame) })
				end
			end
			local lp = BAY:PointToObjectSpace(base.Position)
			local toC = V(-lp.X, 0, -lp.Z).Unit
			table.insert(S.arms, {
				pv = pv, recs = recs, phase = (i - 1) * 1.7, torch = a:FindFirstChild("Torch"),
				retract = math.atan2(toC.Z, toC.X),
			})
		end
	end

	-- 转台虚线（随火箭转）
	S.dashes = {}
	for _, p in ipairs(bay:GetChildren()) do
		if p:IsA("BasePart") and p.Name == "Dash" then
			table.insert(S.dashes, { part = p, rel = BAY:ToObjectSpace(p.CFrame) })
		end
	end

	-- 伸缩舱门：带 OpenOffset 属性的门扇 / 边条按它滑开，中缝在门开时隐藏
	S.leaves = {}
	local door = bay:FindFirstChild("Door")
	if door then
		for _, p in ipairs(door:GetChildren()) do
			local off = p:GetAttribute("OpenOffset")
			if p:IsA("BasePart") and (off or p.Name == "DoorSeam") then
				table.insert(S.leaves, { part = p, rel = BAY:ToObjectSpace(p.CFrame), off = off })
			end
		end
	end

	-- 运输带：每段 Seg_i 一条 Belt，箭头和滚筒沿带面滚动（循环）
	S.belts = {}
	local cv = bay:FindFirstChild("Conveyor")
	if cv then
		local segs = {}
		for _, sg in ipairs(cv:GetChildren()) do
			if sg:IsA("Model") and sg.Name:match("^Seg_%d+$") and sg:FindFirstChild("Belt") then table.insert(segs, sg) end
		end
		table.sort(segs, function(a, b) return tonumber(a.Name:match("%d+")) < tonumber(b.Name:match("%d+")) end)
		for _, sg in ipairs(segs) do
			local beltPart = sg.Belt
			local CV = beltPart.CFrame * CFrame.new(0, -0.3, 0)
			local len = beltPart.Size.Z
			local belt = { CV = CV, len = len, items = {} }
			local nChev, nRoll = 0, 0
			for _, p in ipairs(sg:GetChildren()) do
				if p:IsA("BasePart") and (p.Name == "Chevron" or p.Name == "Roller") then
					table.insert(belt.items, { part = p, rel = CV:ToObjectSpace(p.CFrame), chev = p.Name == "Chevron" })
					if p.Name == "Chevron" then nChev += 1 else nRoll += 1 end
				end
			end
			belt.cycChev = math.max(2.2, (nChev / 2) * 2.2)
			belt.cycRoll = math.max(1, nRoll)
			belt.start = (CV * CFrame.new(0, BELT_Y, len / 2)).Position -- 靠组装舱一端
			belt.stop = (CV * CFrame.new(0, BELT_Y, -len / 2)).Position -- 靠发射台一端
			belt.dir = (belt.stop - belt.start).Unit
			table.insert(S.belts, belt)
		end
	end

	-- 发射台：旧火箭的位置就是新火箭的终点
	local old = opts.padRocket or (bay.Parent and bay.Parent:FindFirstChild("PadRocket", true))
	S.oldRocket = old
	S.padParent = opts.padParent or (old and old.Parent)
	S.catch = opts.catchArms or (S.padParent and S.padParent:FindFirstChild("CatchArms"))
	local last = S.belts[#S.belts]
	local padCF
	if old then
		padCF = old:GetPivot()
	elseif last then
		padCF = (BAY - BAY.Position) + (last.stop + last.dir * 8.2 + V(0, 0.8, 0))
	else
		padCF = BAY * CFrame.new(-20, 1.5, 0)
	end
	S.padCF = padCF
	-- 运输路线：门口 → 出舱平移（底座之上）→ 落到带面 → 各段带尾 → 带尾前托高到台面 → 台心上方 → 落位（匀速）
	local pts = { (BAY * CFrame.new(DOOR_X, SEAT, 0)).Position }
	local first = S.belts[1]
	local padTop = padCF.Position.Y + 0.5 -- 托高 0.5 越过台边和放平的支架根部，到台心再落位
	if first then
		local up = V(0, SEAT - BELT_Y, 0)
		table.insert(pts, first.start + first.dir * 2.2 + up) -- 发动机先整个离开底座边缘
		table.insert(pts, first.start + first.dir * 3.8)
		for i, b in ipairs(S.belts) do
			if i < #S.belts then
				table.insert(pts, b.stop)
			else
				local pre = b.stop - b.dir * 2.2 -- 带尾伸进了台面边缘：提前托高，发动机不擦台边
				table.insert(pts, pre)
				table.insert(pts, V(pre.X, padTop, pre.Z))
			end
		end
	end
	table.insert(pts, V(padCF.Position.X, padTop, padCF.Position.Z))
	table.insert(pts, padCF.Position)
	local lens, total = {}, 0
	for i = 2, #pts do
		lens[i] = (pts[i] - pts[i - 1]).Magnitude
		total += lens[i]
	end
	S.path, S.pathLens, S.pathLen = pts, lens, total
	setmetatable(S, { __index = AS })

	-- 回收支架合拢角：火箭停在台上时，从 0 开始往外找不夹进火箭的最小张角（巨型燃料舱的侧挂舱比机身宽）
	S.closeAlpha = 0
	if S.catch then
		S:at(AS.TOTAL)
		local saved = {}
		for _, r in ipairs(S.rparts) do
			saved[r.part] = r.part.CanQuery
			r.part.CanQuery = true
		end
		local op = OverlapParams.new()
		op.FilterType = Enum.RaycastFilterType.Include
		op.FilterDescendantsInstances = { S.rocket }
		local armParts = {}
		for _, d in ipairs(S.catch:GetDescendants()) do
			if d:IsA("BasePart") and d.Transparency < 0.95 and not d:IsDescendantOf(S.catch:FindFirstChild("Base") or S.rocket) then
				table.insert(armParts, d)
			end
		end
		for a = 0, 1.01, 0.1 do
			CA.setPose(S.catch, a)
			local hit = false
			for _, p in ipairs(armParts) do
				if #workspace:GetPartsInPart(p, op) > 0 then
					hit = true
					break
				end
			end
			S.closeAlpha = a
			if not hit then break end
		end
		for p, v in pairs(saved) do p.CanQuery = v end
		CA.setPose(S.catch, 0)
		S:at(0)
	end
	return S
end

------------------------------------------------------------------ 每帧摆位
local function craneAt(keys, t)
	if t <= keys[1][1] then return keys[1][2], keys[1][3], keys[1][4] end
	for i = 2, #keys do
		local a, b = keys[i - 1], keys[i]
		if t <= b[1] then
			local u = smooth((t - a[1]) / math.max(1e-3, b[1] - a[1]))
			return lerp(a[2], b[2], u), lerp(a[3], b[3], u), lerp(a[4], b[4], u)
		end
	end
	local k = keys[#keys]
	return k[2], k[3], k[4]
end

local function pathAt(S, u)
	local d = u * S.pathLen
	for i = 2, #S.path do
		if d <= S.pathLens[i] or i == #S.path then
			return S.path[i - 1]:Lerp(S.path[i], clamp01(d / math.max(1e-3, S.pathLens[i])))
		end
		d -= S.pathLens[i]
	end
	return S.path[#S.path]
end

function AS.spinAt(t) return math.pi * 2 * smooth(seg(t, SPIN0, SPIN1)) end

-- 抓爪四指：抓着部件时合拢，其余时间张开（开头和结尾回到建造时的合拢姿态）
local function gripOpen(t)
	local held = 0
	for _, st in ipairs(STEPS) do
		held = math.max(held, smooth(seg(t, st.down - 0.12, st.down)) * (1 - smooth(seg(t, st.seat, st.seat + 0.12))))
	end
	return (1 - held) * smooth(seg(t, 0.05, 0.25)) * (1 - smooth(seg(t, 5.9, 6.3)))
end

-- 火箭整体（转台 → 门口 → 运输带 → 发射台）
function AS.rocketCF(S, t)
	local rot = S.BAY - S.BAY.Position
	if t < EXIT0 then
		return S.BAY * CFrame.new(0, SEAT, 0) * CFrame.Angles(0, AS.spinAt(t), 0)
	elseif t < AS.SHOW then
		local u = smooth(seg(t, EXIT0, AS.SHOW))
		return S.BAY * CFrame.new(lerp(0, DOOR_X, u), SEAT, 0)
	elseif t < AS.TOTAL then
		local u = seg(t, AS.SHOW, AS.TOTAL)
		u = u * u * (3 - 2 * u) * 0.35 + u * 0.65 -- 起步和到站稍缓
		return rot + pathAt(S, u)
	end
	return S.padCF
end

function AS.at(S, t)
	local BAY = S.BAY
	-- 龙门吊
	local cx, cz, cb = craneAt(S.keys, t)
	local open = gripOpen(t) * SPREAD
	for _, c in ipairs(S.crane) do
		local p = c.part
		if c.role == "bridge" then
			p.CFrame = BAY * CFrame.new(cx, 0, 0) * c.rel
		elseif c.role == "trolley" then
			p.CFrame = BAY * CFrame.new(cx, 0, cz) * c.rel
		elseif c.role == "claw" or c.role == "finger" then
			local o = (c.role == "finger") and c.out * open or Vector3.zero
			p.CFrame = BAY * CFrame.new(V(cx, cb - CLAW_REST, cz) + o) * c.rel
		else -- 缆绳：上端固定在小车下面，下端跟着抓爪
			local len = math.max(0.1, CABLE_TOP - (cb + 0.5))
			p.Size = V(len, c.size.Y, c.size.Z)
			p.CFrame = BAY * CFrame.new(cx, CABLE_TOP - len / 2, cz) * CFrame.Angles(0, 0, math.pi / 2)
		end
	end

	-- 火箭各部位
	local RCF = AS.rocketCF(S, t)
	local rrot = RCF - RCF.Position
	S.rocket.WorldPivot = RCF -- 零件是逐个摆的，轴心要跟着更新，收尾时 PivotTo 才准
	local vis = {}
	for _, r in ipairs(S.rparts) do
		local p, g = r.part, r.g
		local cf, s, hidden = nil, 1, false
		if g == "fins" then
			local t0 = FIN_T0 + r.k * FIN_GAP
			hidden = t < t0 - 0.15
			local u = smooth(seg(t, t0, t0 + FIN_DUR))
			s = lerp(0.4, 1, smooth(seg(t, t0 - 0.15, t0 + 0.05)))
			local out = FIN_OUT * (1 - u)
			cf = (RCF * CFrame.new(0, S.origin.fins, 0) + rrot * r.dir * out)
		else
			local st = S.carry[g]
			local h = S.hang[g]
			hidden = t < st.down
			if t < st.mat then -- 在托盘上长出来
				s = lerp(0.12, SMAT, smooth(seg(t, st.down, st.mat)))
				cf = BAY * CFrame.new(DOCK_X, DOCK_Y + 0.1, DOCK_Z[g])
			elseif t < st.seat then -- 吊在抓爪下面，离开坞后边走边放大
				s = lerp(SMAT, 1, smooth(seg(t, st.up, st.over)))
				cf = BAY * CFrame.new(cx, cb - GRIP - h * s, cz)
			else
				cf = RCF * CFrame.new(0, S.origin[g], 0)
			end
		end
		vis[g] = not hidden
		p.LocalTransparencyModifier = hidden and 1 or 0
		if s ~= 1 then
			p.Size = r.size * s
			p.CFrame = cf * CFrame.new(r.rel.Position * s) * (r.rel - r.rel.Position)
		else
			if p.Size ~= r.size then p.Size = r.size end
			p.CFrame = cf * r.rel
		end
	end
	for g, list in pairs(S.emitters) do
		for _, e in ipairs(list) do
			e.inst.Enabled = e.on and (vis[g] ~= false)
		end
	end

	-- 机械臂：装尾翼时轻摆，点焊时抖动，转台转之前收到 +X，关门时回位
	local env1 = smooth(seg(t, 1.3, 1.45)) * (1 - smooth(seg(t, 2.0, 2.2)))
	local env2 = smooth(seg(t, WELD0 - 0.05, WELD0 + 0.05)) * (1 - smooth(seg(t, WELD1 - 0.1, WELD1)))
	local away = smooth(seg(t, ARM_OUT[1], ARM_OUT[2])) * (1 - smooth(seg(t, ARM_BACK[1], ARM_BACK[2])))
	for _, a in ipairs(S.arms) do
		local yaw = env1 * math.sin((t - 1.3) * 13 + a.phase) * 0.15 + env2 * math.sin((t - WELD0) * 31 + a.phase) * 0.06
		yaw = yaw + a.retract * away
		local base = a.pv * CFrame.Angles(0, yaw, 0)
		for _, r in ipairs(a.recs) do
			r.part.CFrame = base * r.rel
		end
	end

	-- 发射台回收支架：火箭来之前向外放平，到位时合拢夹住
	if S.catch then
		local c = smooth(seg(t, PAD_CLOSE[1], PAD_CLOSE[2]))
		CA.setPose(S.catch, PAD_WIDE * smooth(seg(t, PAD_OPEN[1], PAD_OPEN[2])) * (1 - c) + (S.closeAlpha or 0) * c)
	end

	-- 转台虚线
	local spin = (t < EXIT0) and AS.spinAt(t) or 0
	for _, d in ipairs(S.dashes) do
		d.part.CFrame = BAY * CFrame.Angles(0, spin, 0) * d.rel
	end

	-- 舱门：先向外让开，再左右滑到两侧玻璃外面
	local dopen = smooth(seg(t, DOOR_OPEN[1], DOOR_OPEN[2])) * (1 - smooth(seg(t, DOOR_SHUT[1], DOOR_SHUT[2])))
	local kx, kz = math.min(1, dopen * 4), smooth(dopen * 1.25 - 0.25)
	for _, l in ipairs(S.leaves) do
		if l.off then
			l.part.CFrame = BAY * CFrame.new(l.off.X * kx, 0, l.off.Z * kz) * l.rel
		else
			l.part.LocalTransparencyModifier = dopen > 0.05 and 1 or 0
		end
	end

	-- 运输带滚动（火箭出舱起）
	local speed = S.pathLen / AS.TRANSIT
	local run = math.max(0, math.min(t, AS.TOTAL) - EXIT0) * speed
	for _, b in ipairs(S.belts) do
		for _, it in ipairs(b.items) do
			local cyc = it.chev and b.cycChev or b.cycRoll
			local zmin = -b.len / 2 + (it.chev and 0.3 or 0.4)
			local z = it.rel.Position.Z - run
			z = zmin + ((z - zmin) % cyc)
			local rel = it.rel - it.rel.Position + V(it.rel.Position.X, it.rel.Position.Y, z)
			it.part.CFrame = b.CV * rel
			it.part.LocalTransparencyModifier = (z > b.len / 2 - 0.3) and 1 or 0
		end
	end
end

-- 零件复位（龙门吊、臂、门、带面回原位），火箭留在发射台
function AS.finish(S)
	S:at(AS.TOTAL)
	for _, c in ipairs(S.crane) do
		c.part.Size = c.size
		c.part.CFrame = S.BAY * c.rel
	end
	for _, a in ipairs(S.arms) do
		for _, r in ipairs(a.recs) do
			r.part.CFrame = a.pv * r.rel
		end
	end
	for _, b in ipairs(S.belts) do
		for _, it in ipairs(b.items) do
			it.part.CFrame = b.CV * it.rel
			it.part.LocalTransparencyModifier = 0
		end
	end
	for _, l in ipairs(S.leaves) do
		l.part.CFrame = S.BAY * l.rel
		l.part.LocalTransparencyModifier = 0
	end
	for _, d in ipairs(S.dashes) do
		d.part.CFrame = S.BAY * d.rel
	end
	if S.catch then CA.setPose(S.catch, S.closeAlpha or 0) end
	for _, r in ipairs(S.rparts) do
		r.part.LocalTransparencyModifier = 0
		r.part.Size = r.size
	end
	S.rocket:PivotTo(S.padCF)
	for d, rel in pairs(S.subPivots) do
		if d.Parent then d.WorldPivot = S.padCF * rel end
	end
	for _, d in ipairs(S.spinTags) do
		if d.Parent then CS:AddTag(d, "SpinFX") end
	end
	return S.rocket
end

------------------------------------------------------------------ 整场演出（客户端）
local function holoVisible(bay, on)
	local h = bay:FindFirstChild("HoloPreview")
	if not h then return end
	for _, p in ipairs(h:GetDescendants()) do
		if p:IsA("BasePart") then p.LocalTransparencyModifier = on and 0 or 1 end
	end
end

local WELD_COLORS = { Color3.fromRGB(220, 240, 255), Color3.fromRGB(120, 190, 255) }

function AS.play(bay, eq, homeColor, opts)
	opts = opts or {}
	local S = AS.prepare(bay, eq, homeColor, opts)
	local BAY = S.BAY
	local hE = S.height.engine
	local function W(x, y, z) return (BAY * CFrame.new(x, y, z)).Position end
	local function impact(pos, power)
		FX.sparks(pos, math.floor(40 * power), power)
		FX.chunks(pos, math.floor(6 * power), power)
		FX.flash(pos, FX.ORANGE, 16, 3 + 2 * power, 0.35)
		FX.ring(CFrame.new(pos), 0.6, 2.6 + power, FX.ORANGE, 0.35, { width = 0.25 })
		FX.shake(pos, 0.5 * power, 0.22)
	end
	local function scan(slot)
		local p = W(DOCK_X, DOCK_Y + 0.05, DOCK_Z[slot])
		FX.ring(CFrame.new(p), 0.4, 2.2, B.C.cyan, 0.4, { width = 0.2 })
		FX.flash(p, B.C.cyan, 10, 2.5, 0.35)
		AB.setDock(bay, DOCK_I[slot], nil)
	end

	local events = {
		{ 0, function()
			AB.setStatus(bay, "assembling", 4)
			holoVisible(bay, false)
			local old = S.oldRocket
			if old and old.Parent then
				FX.puff(old:GetPivot().Position + V(0, 3, 0), 24, Color3.fromRGB(200, 205, 230), 10, 3)
				old:Destroy()
			end
		end },
	}
	for _, st in ipairs(STEPS) do
		local slot = st.slot
		table.insert(events, { st.down, function() scan(slot) end })
		local power = (slot == "tank") and 1.4 or (slot == "engine") and 1.2 or 1.0
		table.insert(events, { st.seat, function() impact(W(0, S.seatB[slot], 0), power) end })
	end
	table.insert(events, { FIN_T0 - 0.2, function() scan("fins") end })
	for k = 0, 3 do
		local t = FIN_T0 + k * FIN_GAP + FIN_DUR
		table.insert(events, { t, function()
			local ang = math.rad(45 + 90 * k)
			local p = W(math.sin(ang) * 2.1, SEAT + hE + 1.2, math.cos(ang) * 2.1)
			FX.sparks(p, 18, 0.6)
			FX.flash(p, FX.ORANGE, 8, 2.5, 0.2)
		end })
	end
	table.insert(events, { SPIN1, function()
		AB.setStatus(bay, "ready", 4)
		FX.flash(W(0, 10, 0), Color3.fromRGB(80, 255, 120), 24, 3, 0.6)
	end })
	table.insert(events, { PAD_CLOSE[2], function()
		local p = S.padCF.Position
		for _, s in ipairs({ -1, 1 }) do
			local q = (S.padCF * CFrame.new(s * 2.3, 4, 0)).Position
			FX.sparks(q, 14, 0.6)
		end
		FX.shake(p, 0.4, 0.18)
	end })
	table.insert(events, { AS.TOTAL, function()
		local p = S.padCF.Position
		FX.puff(p + V(0, 1, 0), 18, Color3.fromRGB(255, 220, 120), 8, 2.2, { light = 0.6 })
		FX.ring(CFrame.new(p + V(0, 0.2, 0)), 1, 7, Color3.fromRGB(255, 204, 51), 0.5)
	end })
	table.sort(events, function(a, b) return a[1] < b[1] end)

	-- 点焊：焊枪尖在燃料舱外壁上，火花从枪尖迸出
	local nextWeld = WELD0
	local ei = 1
	local t0 = os.clock()
	while true do
		local t = os.clock() - t0
		S:at(math.min(t, AS.TOTAL))
		while events[ei] and events[ei][1] <= t do
			events[ei][2]()
			ei += 1
		end
		if t >= nextWeld and t < WELD1 - 0.05 then
			nextWeld = t + 0.06
			for _, arm in ipairs(S.arms) do
				if arm.torch then
					local tip = (arm.torch.CFrame * CFrame.new(0, 0, -arm.torch.Size.Z / 2)).Position
					FX.sparks(tip, 6, 0.45, WELD_COLORS)
					if math.random() < 0.3 then FX.flash(tip, Color3.fromRGB(170, 215, 255), 9, 2.5, 0.1) end
				end
			end
		end
		if t >= AS.TOTAL then break end
		task.wait()
	end

	local rocket = S:finish()
	rocket.Name = "PadRocket"
	if S.padParent then rocket.Parent = S.padParent end -- 放回旧火箭原来的父级（发射区）
	for i = 1, 4 do AB.setDock(bay, i, nil) end
	AB.setStatus(bay, "staging", 0)
	AB.setHolo(bay, {}, homeColor)
	return rocket
end

return AS
