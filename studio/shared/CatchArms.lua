--[[
	CatchArms · 回收支架 L1–L4 + 张开 / 合拢两态（ReplicatedStorage.OrbitShared.CatchArms）
	A3：L1 灰 6.5 / L2 蓝 8 / L3 橙 10 / L4 金 12 带光点；升级后外形变长、变色。
	11-24 用户反馈：L3 要更有机械感和金属质感（钢、镀铬、工字钢、油缸），L4 要更有科技感、更炫（悬浮分段、能量线、全息环、能量夹爪）。
	结构：CatchArms(Model, 属性 Level / Pose) → Base（静止的地脚 + 铰链座）+ Arm_L / Arm_R（可动）。
	每只臂的 WorldPivot 就是铰链（地脚顶面），属性 ClosedPivot 记录合拢姿态；
	A.setPose(arms, alpha)：0 = 合拢（夹住火箭），1 = 张开外倾 28°（返航时），可在运行时用 NumberValue 补间。
	臂的本地坐标：+X 朝外、−X 朝火箭；火箭机身表面在 x = −4.2（臂距台心 6.2，机身半径 2）。
]]

local B = require(script.Parent.BuildLib)
local hex = B.hex
local C = B.C
local V = Vector3.new
local NEON = Enum.Material.Neon
local CS = game:GetService("CollectionService")

local A = {}

A.LEVELS = {
	{ name = "基础支架", bonus = 10, win = 0.16, cost = 50, color = hex("9AA3B5"), h = 6.5, foot = 0.5 },
	{ name = "液压支架", bonus = 25, win = 0.22, cost = 140, color = hex("3EA0FF"), h = 8, foot = 0.6 },
	{ name = "重型支架", bonus = 55, win = 0.28, cost = 320, color = hex("FF8A2E"), h = 10, foot = 0.8 },
	{ name = "星辉支架", bonus = 110, win = 0.36, cost = nil, color = hex("FFD43D"), h = 12, foot = 0.7 },
}
A.ARM_X = 6.2
A.DECK_Y = 1.5 -- 发射台台面高度
A.OPEN_ANGLE = math.rad(28)

------------------------------------------------------------------ 各级造型（H = 铰链框架，y 从铰链算起，yt = 立柱顶）
local function armL1(H, yt, col, m)
	B.box(V(1, yt, 1), H * CFrame.new(0, yt / 2, 0), { Name = "Post", Color = col }, m)
	B.box(V(2.6, 0.9, 1.1), H * CFrame.new(-1.3, yt - 0.45, 0), { Name = "Arm", Color = col }, m)
	B.box(V(0.4, 1.5, 1.6), H * CFrame.new(-2.6, yt - 0.6, 0), { Name = "Clamp", Color = C.graphite }, m)
end

local function armL2(H, yt, col, m) -- 液压：石墨套筒 + 镀铬活塞杆 + 蓝色头部 + 两侧小油缸
	local sy = yt * 0.55
	B.box(V(1.2, sy, 1.2), H * CFrame.new(0, sy / 2, 0), { Name = "Sleeve", Color = C.graphite2 }, m)
	B.box(V(1.4, 0.3, 1.4), H * CFrame.new(0, sy, 0), { Name = "Collar", Color = col }, m)
	B.cylAt(0.7, sy, yt - 0.9 - sy, H, { Name = "Rod", Color = C.metal, Material = Enum.Material.Metal }, m)
	B.box(V(1.3, 1.0, 1.3), H * CFrame.new(0, yt - 0.5, 0), { Name = "Head", Color = col }, m)
	for _, z in ipairs({ -0.78, 0.78 }) do
		B.cylAt(0.32, 0.3, sy - 0.2, H * CFrame.new(0.15, 0, z), { Name = "Piston", Color = C.metal, Material = Enum.Material.Metal }, m)
	end
	B.box(V(3.0, 0.8, 1.1), H * CFrame.new(-1.6, yt - 0.5, 0), { Name = "Arm", Color = col }, m)
	B.box(V(0.5, 2.2, 1.7), H * CFrame.new(-2.95, yt - 1.1, 0), { Name = "Clamp", Color = C.graphite }, m)
	B.box(V(0.12, 1.8, 1.3), H * CFrame.new(-3.24, yt - 1.15, 0), { Name = "ClampPad", Color = col }, m)
end

-- 金属件：钢、深钢、镀铬（L3 重型的机械感、L4 的金属点缀）
local MET = Enum.Material.Metal
local STEEL, STEEL_D, CHROME = hex("8E96A8"), hex("4A5064"), hex("D5DAE3")
local GOLD_GLOW = hex("FFE08A")
local function steel(name, c) return { Name = name, Color = c or STEEL, Material = MET, Reflectance = 0.06 } end
-- 两点之间的圆柱（油缸、软管）
local function cylBetween(a, b, d, props, parent)
	local pr = table.clone(props)
	pr.Shape = Enum.PartType.Cylinder
	pr.Size = V((b - a).Magnitude, d, d)
	pr.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0)
	return B.part(pr, parent)
end
local function pulse(p, base, amp, speed)
	p:SetAttribute("PulseBase", base)
	p:SetAttribute("PulseAmp", amp)
	p:SetAttribute("PulseSpeed", speed)
	CS:AddTag(p, "PulseFX")
	return p
end

-- L3 重型（11-24 用户要求更有机械感、金属质感）：
-- 工字钢双轨 + 每格交叉斜撑 + 横向连接板；螺栓固定的关节圆盘；橙色腹板 + 钢翼缘的工字钢臂（铆钉、警示条）；
-- 尾端配重块；镀铬大油缸 + 液压软管；深钢夹爪 + 镀铬锯齿。橙色只留在腹板、盖板和油缸色环上。
local function armL3(H, yt, col, m)
	local function at(x, y, z) return H * CFrame.new(x, y, z) end
	local function P(x, y, z) return (H * CFrame.new(x, y, z)).Position end
	-- 立柱：两根工字钢（钢芯 + 前后深钢翼缘）
	for _, x in ipairs({ -0.6, 0.6 }) do
		B.box(V(0.34, yt, 0.5), at(x, yt / 2, 0), steel("Rail"), m)
		for _, z in ipairs({ -0.3, 0.3 }) do
			B.box(V(0.5, yt, 0.1), at(x, yt / 2, z), steel("RailFlange", STEEL_D), m)
		end
	end
	-- 四格交叉斜撑 + 横向连接板
	local top = yt - 1.6
	for k = 0, 3 do
		local y0, y1 = 0.3 + top * k / 4, 0.3 + top * (k + 1) / 4
		B.beamBetween(P(-0.6, y0, 0), P(0.6, y1, 0), 0.14, 0.2, steel("Brace", STEEL_D), m)
		B.beamBetween(P(0.6, y0, 0), P(-0.6, y1, 0), 0.14, 0.2, steel("Brace", STEEL_D), m)
		B.box(V(1.6, 0.18, 0.62), at(0, y1, 0), steel("Tie"), m)
	end
	-- 臂与立柱的关节：两侧钢圆盘 + 橙色轴帽 + 4 颗镀铬螺栓
	local AY = yt - 0.8
	local J = at(0, AY, 0)
	for _, z in ipairs({ -0.42, 0.42 }) do
		B.discZ(1.9, 0.2, J * CFrame.new(0, 0, z), steel("JointPlate"), m)
		B.discZ(0.8, 0.26, J * CFrame.new(0, 0, z * 1.15), { Name = "JointCap", Color = col }, m)
		for b = 0, 3 do
			local a = math.rad(45 + 90 * b)
			B.ball(0.2, J * CFrame.new(math.cos(a) * 0.66, math.sin(a) * 0.66, z * 1.2), { Name = "Bolt", Color = CHROME, Material = MET }, m)
		end
	end
	-- 工字钢臂：橙色腹板 + 上下钢翼缘 + 铆钉 + 警示条
	B.box(V(3.9, 1.0, 0.5), at(-1.45, AY, 0), { Name = "Arm", Color = col }, m)
	for _, dy in ipairs({ 0.6, -0.6 }) do
		B.box(V(3.9, 0.2, 1.15), at(-1.45, AY + dy, 0), steel("Flange"), m)
		for i = 0, 4 do
			for _, z in ipairs({ -0.5, 0.5 }) do
				B.ball(0.13, at(0.2 - i * 0.85, AY + dy + (dy > 0 and 0.11 or -0.11), z), { Name = "Rivet", Color = CHROME, Material = MET }, m)
			end
		end
	end
	for i = 0, 3 do
		for _, z in ipairs({ -0.27, 0.27 }) do
			B.box(V(0.26, 0.85, 0.04), at(-0.55 - i * 0.72, AY, z) * CFrame.Angles(0, 0, math.rad(35)), { Name = "Hazard", Color = C.yellow }, m)
		end
	end
	-- 尾端配重
	B.box(V(1.0, 1.5, 1.3), at(1.05, AY, 0), steel("Counterweight", STEEL_D), m)
	B.box(V(1.04, 0.26, 1.34), at(1.05, AY + 0.42, 0), { Name = "WeightBand", Color = col }, m)
	-- 夹爪：深钢爪体 + 橙色盖板 + 镀铬锯齿（菱形齿朝火箭）
	local CY = AY - 1.25
	B.box(V(0.8, 3.0, 2.0), at(-3.35, CY, 0), steel("Clamp", STEEL_D), m)
	B.box(V(0.86, 0.3, 2.06), at(-3.35, CY + 1.4, 0), { Name = "ClampCap", Color = col }, m)
	for t = 0, 5 do
		B.box(V(0.3, 0.3, 1.8), at(-3.76, CY - 1.15 + t * 0.46, 0) * CFrame.Angles(0, 0, math.pi / 4), { Name = "Tooth", Color = CHROME, Material = MET, Reflectance = 0.2 }, m)
	end
	-- 外侧大油缸：深钢套筒（橙色色环）+ 镀铬活塞杆 + 两端耳座 + 液压软管
	local p0, p1 = P(1.35, 0.5, 0), P(0.8, yt - 2.4, 0)
	local mid = p0:Lerp(p1, 0.55)
	cylBetween(p0, mid, 0.64, steel("Sleeve", STEEL_D), m)
	cylBetween(p0:Lerp(mid, 0.4), p0:Lerp(mid, 0.55), 0.68, { Name = "SleeveBand", Color = col }, m)
	cylBetween(mid, p1, 0.32, { Name = "Rod", Color = CHROME, Material = MET, Reflectance = 0.3 }, m)
	for _, p in ipairs({ p0, p1 }) do
		B.box(V(0.5, 0.5, 0.75), CFrame.new(p) * (H - H.Position), steel("Clevis"), m)
	end
	cylBetween(P(1.2, 1.2, 0.3), P(0.5, 2.4, 0.34), 0.13, { Name = "Hose", Color = C.graphite3 }, m)
	cylBetween(P(0.5, 2.4, 0.34), P(0.45, 4.2, 0.34), 0.13, { Name = "Hose", Color = C.graphite3 }, m)
end

-- L4 星辉（11-24 用户要求更有科技感、更炫）：
-- 三段悬浮立柱（下粗上细，段间是发光能量环）+ 前后凹槽里的金色能量线；两道反向旋转的金色全息环；
-- 白色流线臂（金色背鳍 + 发光底线 + 金色关节毂）；能量夹爪：两根白色叉齿 + 发光尖 + 中间的能量场（脉动 + 闪光）；
-- 外侧金色尾翼；顶部脉动光球 + 小全息环 + 星光粒子。动画在 Play 模式下由客户端 RocketFX 驱动。
local function armL4(H, yt, col, m)
	local function at(x, y, z) return H * CFrame.new(x, y, z) end
	local segs = { { 0, yt * 0.34, 1.2 }, { yt * 0.34 + 0.35, yt * 0.67, 1.04 }, { yt * 0.67 + 0.35, yt - 0.2, 0.9 } }
	for i, sg in ipairs(segs) do
		local y0, y1, w = sg[1], sg[2], sg[3]
		local h, yc = y1 - y0, (y0 + y1) / 2
		B.box(V(w, h, w), at(0, yc, 0), { Name = "Post", Color = C.white, Reflectance = 0.08 }, m)
		for _, sz in ipairs({ -1, 1 }) do
			B.box(V(0.34, h - 0.5, 0.06), at(0, yc, sz * (w / 2 + 0.01)), { Name = "Groove", Color = C.graphite3 }, m)
			B.deco(B.box(V(0.1, h - 0.7, 0.08), at(0, yc, sz * (w / 2 + 0.03)), { Name = "Conduit", Color = GOLD_GLOW, Material = NEON, Transparency = 0.05, CastShadow = false }, m))
		end
		B.box(V(w + 0.12, 0.2, w + 0.12), at(0, y1 - 0.1, 0), { Name = "Band", Color = col, Material = MET, Reflectance = 0.15 }, m)
		if i < 3 then
			local ring = B.cylAt(w * 0.8, y1, 0.35, H, { Name = "EnergyCollar", Color = GOLD_GLOW, Material = NEON, Transparency = 0.1, CastShadow = false }, m)
			B.deco(ring)
			pulse(ring, 0.05, 0.5, 4)
		end
	end
	-- 光环挂在会开合的臂上：SpinFollowParent 让客户端按臂的当前姿态算光环位置，
	-- 服务器 setPose 同步过来时不会把客户端转过的角度冲掉（否则开合补间时光环会抖）
	for _, hr in ipairs({
		B.fx.haloRing(at(0, yt * 0.34 + 0.18, 0) * CFrame.Angles(math.rad(12), 0, 0), 1.3, 14, GOLD_GLOW, 1.4, m),
		B.fx.haloRing(at(0, yt * 0.67 + 0.18, 0) * CFrame.Angles(math.rad(-12), 0, 0), 1.15, 12, GOLD_GLOW, -1.1, m),
	}) do
		hr:SetAttribute("SpinFollowParent", true)
	end
	-- 外侧金色尾翼（上大下小）
	B.wedge(V(0.25, 3.4, 1.4), at(0.66, yt - 2.6, 0) * CFrame.Angles(0, math.pi / 2, 0), { Name = "Fin", Color = col, Material = MET, Reflectance = 0.15 }, m)
	B.wedge(V(0.22, 2.2, 1.0), at(0.72, yt * 0.45, 0) * CFrame.Angles(0, math.pi / 2, 0), { Name = "Fin", Color = col, Material = MET, Reflectance = 0.15 }, m)
	-- 白色流线臂：金色背鳍 + 发光底线 + 金色关节毂
	local AY = yt - 0.75
	B.box(V(3.3, 0.75, 0.9), at(-1.45, AY, 0), { Name = "Arm", Color = C.white, Reflectance = 0.08 }, m)
	B.wedge(V(0.5, 0.45, 3.1), at(-1.55, AY + 0.6, 0) * CFrame.Angles(0, math.pi / 2, 0), { Name = "ArmFin", Color = col, Material = MET, Reflectance = 0.15 }, m)
	B.deco(B.box(V(3.1, 0.08, 0.94), at(-1.45, AY - 0.38, 0), { Name = "ArmGlow", Color = GOLD_GLOW, Material = NEON, Transparency = 0.1, CastShadow = false }, m))
	B.discZ(1.3, 1.1, at(0, AY, 0), { Name = "Hub", Color = col, Material = MET, Reflectance = 0.15 }, m)
	B.deco(B.discZ(0.5, 1.16, at(0, AY, 0), { Name = "HubCore", Color = GOLD_GLOW, Material = NEON, CastShadow = false }, m))
	-- 能量夹爪
	local CY = AY - 1.55
	B.box(V(0.5, 0.45, 2.1), at(-3.05, AY - 0.55, 0), { Name = "ClampHead", Color = col, Material = MET, Reflectance = 0.15 }, m)
	for _, z in ipairs({ -0.82, 0.82 }) do
		B.box(V(0.4, 2.4, 0.3), at(-3.05, CY, z), { Name = "Prong", Color = C.white }, m)
		B.deco(B.ball(0.36, at(-3.05, CY - 1.25, z), { Name = "ProngTip", Color = GOLD_GLOW, Material = NEON, CastShadow = false }, m))
	end
	local field = B.box(V(0.06, 2.2, 1.34), at(-3.05, CY, 0), { Name = "EnergyField", Color = GOLD_GLOW, Material = NEON, Transparency = 0.55, CastShadow = false }, m)
	B.deco(field)
	pulse(field, 0.45, 0.4, 6)
	B.fx.sparkles(field, GOLD_GLOW, 8, 0.25)
	-- 顶部光球 + 小全息环 + 星光
	local orb = B.fx.orb(at(0, yt + 0.6, 0), 0.8, GOLD_GLOW, m)
	B.fx.sparkles(orb, Color3.new(1, 1, 1), 4, 0.3)
	B.fx.haloRing(at(0, yt + 0.6, 0) * CFrame.Angles(math.rad(25), 0, 0), 0.85, 10, Color3.new(1, 1, 1), 2.2, m)
end

local ARM = { armL1, armL2, armL3, armL4 }

local function footBase(F, lvl, level, m) -- 静止地脚（F = 地脚底面中心，台面上）
	local fh = lvl.foot
	if level == 1 then
		B.box(V(1.8, fh, 1.8), F * CFrame.new(0, fh / 2, 0), { Name = "Foot", Color = C.graphite }, m)
	elseif level == 2 then
		B.box(V(2.0, fh, 2.0), F * CFrame.new(0, fh / 2, 0), { Name = "Foot", Color = C.graphite }, m)
		B.box(V(2.1, 0.12, 2.1), F * CFrame.new(0, fh - 0.06, 0), { Name = "FootTrim", Color = lvl.color }, m)
	elseif level == 3 then -- 花纹钢板底座 + 橙色边 + 镀铬螺栓 + 两侧铰链耳板
		B.box(V(2.6, fh, 2.6), F * CFrame.new(0, fh / 2, 0), { Name = "Foot", Color = STEEL_D, Material = Enum.Material.DiamondPlate }, m)
		B.box(V(2.66, 0.12, 2.66), F * CFrame.new(0, fh - 0.06, 0), { Name = "FootTrim", Color = lvl.color }, m)
		for _, x in ipairs({ -1.0, 1.0 }) do
			for _, z in ipairs({ -1.0, 1.0 }) do
				B.cylAt(0.3, fh, 0.14, F * CFrame.new(x, 0, z), { Name = "Bolt", Color = CHROME, Material = MET }, m)
			end
		end
		for _, z in ipairs({ -0.78, 0.78 }) do
			B.box(V(1.3, 1.0, 0.18), F * CFrame.new(0, fh + 0.3, z), steel("HingeCheek"), m)
		end
	else -- 悬浮底座：白色 + 金边 + 底部金色光带
		B.box(V(2.4, fh, 2.4), F * CFrame.new(0, fh / 2, 0), { Name = "Foot", Color = C.white }, m)
		B.box(V(2.5, 0.15, 2.5), F * CFrame.new(0, fh - 0.08, 0), { Name = "FootTrim", Color = lvl.color, Material = MET, Reflectance = 0.15 }, m)
		B.deco(B.box(V(2.5, 0.06, 2.5), F * CFrame.new(0, 0.05, 0), { Name = "UnderGlow", Color = GOLD_GLOW, Material = NEON, Transparency = 0.3, CastShadow = false }, m))
	end
	-- 铰链座 + 销轴（沿 Z）
	B.part({ Name = "HingePin", Shape = Enum.PartType.Cylinder, Size = V(1.5, 0.5, 0.5), CFrame = F * CFrame.new(0, fh, 0) * CFrame.Angles(0, math.pi / 2, 0), Color = C.metal, Material = Enum.Material.Metal }, m)
end

------------------------------------------------------------------ 建造
-- 装饰件（关碰撞 / 查询）：细小零件和 L3 / L4 的外挂细节；立柱、臂、夹爪主体、地脚保持可碰撞
local DECO = {
	Hazard = true, Bolt = true, Rivet = true, FootTrim = true, ArmTrim = true, Band = true, Tooth = true, Hose = true, Groove = true, WeightBand = true, JointCap = true,
	-- L3 重型
	RailFlange = true, Brace = true, Tie = true, JointPlate = true, Flange = true, Counterweight = true, ClampCap = true,
	Sleeve = true, SleeveBand = true, Rod = true, Clevis = true, HingeCheek = true,
	-- L4 星辉
	Fin = true, ArmFin = true, Hub = true, ClampHead = true, Prong = true,
}
-- padCF：发射台中心（地面），level 1–4
function A.build(padCF, level, parent)
	local lvl = A.LEVELS[level]
	local arms = B.model("CatchArms")
	arms:SetAttribute("Level", level)
	arms:SetAttribute("Pose", 0)
	local base = B.model("Base", arms)
	for _, s in ipairs({ -1, 1 }) do
		local F = padCF * CFrame.new(s * A.ARM_X, A.DECK_Y, 0) * (s > 0 and CFrame.identity or CFrame.Angles(0, math.pi, 0))
		footBase(F, lvl, level, base)
		local H = F * CFrame.new(0, lvl.foot, 0)
		local a = B.model(s < 0 and "Arm_L" or "Arm_R", arms)
		ARM[level](H, lvl.h - lvl.foot, lvl.color, a)
		a.WorldPivot = H
		a:SetAttribute("Side", s)
		a:SetAttribute("ClosedPivot", H)
	end
	for _, d in ipairs(arms:GetDescendants()) do
		if d:IsA("BasePart") and DECO[d.Name] then B.deco(d) end
	end
	arms.Parent = parent
	return arms
end

-- alpha：0 合拢，1 张开（可略小于 0 表示用力夹紧）
function A.setPose(arms, alpha)
	for _, a in ipairs(arms:GetChildren()) do
		local closed = a:GetAttribute("ClosedPivot")
		if closed then
			a:PivotTo(closed * CFrame.Angles(0, 0, -A.OPEN_ANGLE * alpha))
		end
	end
	arms:SetAttribute("Pose", alpha)
end

------------------------------------------------------------------ 升级牌文字
function A.boardLines(level)
	local lvl = A.LEVELS[level]
	local lines = {
		{ text = "回收支架", h = 0.3 },
		{ text = ("Lv%d %s · 回收 +%d"):format(level, lvl.name, lvl.bonus), h = 0.22, color = hex("C9D1E0"), font = Enum.Font.GothamBold },
	}
	local nxt = A.LEVELS[level + 1]
	if nxt then
		table.insert(lines, { text = ("升级 → Lv%d %s"):format(level + 1, nxt.name), h = 0.22, color = hex("8FC6FF"), font = Enum.Font.GothamBold })
		table.insert(lines, { text = "◎ " .. lvl.cost, h = 0.24, color = C.yellow })
	else
		table.insert(lines, { text = ("已满级 · 完美窗口 %.2f s"):format(lvl.win), h = 0.22, color = hex("FFE08A"), font = Enum.Font.GothamBold })
		table.insert(lines, { text = "★ MAX", h = 0.24, color = C.yellow })
	end
	return lines
end

-- board = 升级牌 Model（含 Frame / Panel / UpgradeButton）
function A.updateBoard(board, level)
	local lvl = A.LEVELS[level]
	local frame = board:FindFirstChild("Frame")
	if frame then frame.Color = lvl.color end
	local panel = board:FindFirstChild("Panel")
	if panel then
		for _, g in ipairs(panel:GetChildren()) do
			if g:IsA("SurfaceGui") then g:Destroy() end
		end
		B.surfaceText(panel, Enum.NormalId.Front, A.boardLines(level))
	end
	local btn = board:FindFirstChild("UpgradeButton")
	if btn then
		for _, g in ipairs(btn:GetChildren()) do
			if g:IsA("SurfaceGui") then g:Destroy() end
		end
		local maxed = A.LEVELS[level + 1] == nil
		btn.Color = maxed and C.graphite2 or C.orange
		B.surfaceText(btn, Enum.NormalId.Front, { { text = maxed and "已满级" or "E · 升级" } }, { pps = 50 })
	end
	board:SetAttribute("Level", level)
end

return A
