--[[
	BracketSkins · 付费回收支架（商业化外观，ReplicatedStorage.OrbitShared.BracketSkins）
	11-25 v2：用户认为 v1 与原画差距太大，要求保留原画的细节、自发光、金属材质和纹理质感，重做。
	四套对应用户的 4 张原画：中级 / 进阶 / 高阶（概念图）/ 旗舰；每套带自己的支架底座（着陆平台）。
	和 L1–L4 升级支架是两条线：这 4 套是付费外观（价格、是否带数值加成待商业化设计定）。
	材质：AI 生成的 MaterialVariant（MaterialService 下）——OR_BrushedAlloy 拉丝合金、OR_AnodizedTitanium 阳极钛、
	OR_CarbonFiber 碳纤维、涂装件用干净 SmoothPlastic（试过 OR_ArmorPaint / OR_PaintPlate：前者暗光下发黑，后者出现大理石花纹，均弃用）、OR_DeckPlate 着陆甲板、OR_VentGrille 散热格栅；没有时退回基础材质。
	自发光（11-25 用户第二轮反馈）：数量砍掉约六成、全部改细线。
	11-25 第三轮：参考用户给的《mini war》神圣级以上工厂 / 军事建筑截图的设计理念——
	  深色枪灰机体、发光只做细缝 / 菱形光点 / 窗格；每座建筑一种标志发光色（中级青、进阶红、高阶品红、旗舰金）+ 白热核心；
	  台心做能量核心（视觉焦点，粒子上升）；用尖刺、塔楼、阶梯式底座强化轮廓；等级越高越像纪念碑（塔越多越高）。
	  原画的配色（蓝 / 橙 / 淡紫 / 金）降为少量涂装点缀。发光色由 applyHue 统一刷成本套的 hue / hot。
	结构：RecoveryBracket(Model，属性 SkinId / DeckY / ArmCount)
	  → Platform（静止）+ Arm_1…n（可动，WorldPivot = 铰链，属性 ClosedPivot）+ 可选 GuideBeam（引导光柱）。
	开合沿用 CatchArms.setPose(bracket, alpha)。S.build(P, id, parent, opts)；S.deckCF(bracket)；S.setGuide(bracket, on)。
	臂的铰链框架：+X 朝外、−X 朝火箭轴线，Y 向上；臂在框架 XY 平面里。
]]

local B = require(script.Parent.BuildLib)
local hex = B.hex
local C = B.C
local V = Vector3.new
local NEON = Enum.Material.Neon
local MET = Enum.Material.Metal
local CS = game:GetService("CollectionService")
local MS = game:GetService("MaterialService")

local S = {}
local CHROME = hex("D5DAE3")

------------------------------------------------------------------ 材质
local MV = { alloy = "OR_BrushedAlloy", ti = "OR_AnodizedTitanium", carbon = "OR_CarbonFiber", armor = "OR_PaintPlate", deck = "OR_DeckPlate", vent = "OR_VentGrille" }
local MVBASE = { OR_BrushedAlloy = MET, OR_AnodizedTitanium = MET, OR_CarbonFiber = Enum.Material.Plastic, OR_PaintPlate = Enum.Material.SmoothPlastic, OR_ArmorPaint = MET, OR_DeckPlate = Enum.Material.DiamondPlate, OR_VentGrille = MET }
local function pr(name, color, mv, extra)
	local t = { Name = name, Color = color }
	if mv == "armor" then
		-- 涂装件用干净的 SmoothPlastic（原画的涂装面是干净的卡通漆面；AI 生成的漆面纹理会出现大理石花纹）
		t.Material = Enum.Material.SmoothPlastic
	elseif mv then
		local id = MV[mv]
		t.Material = MVBASE[id]
		if MS:FindFirstChild(id, true) then t.MaterialVariant = id end
	end
	if extra then
		for k, v in pairs(extra) do t[k] = v end
	end
	return t
end
local function neon(name, color, tr) return { Name = name, Color = color, Material = NEON, Transparency = tr or 0, CastShadow = false } end
local function pulse(p, base, amp, speed)
	p:SetAttribute("PulseBase", base)
	p:SetAttribute("PulseAmp", amp)
	p:SetAttribute("PulseSpeed", speed)
	CS:AddTag(p, "PulseFX")
	return p
end

------------------------------------------------------------------ 臂平面几何（a、b = 铰链框架里的 {x, y[, z]}）
local function seg(H, a, b, thick, width, props, parent)
	local pa, pb = H * V(a[1], a[2], a[3] or 0), H * V(b[1], b[2], b[3] or 0)
	local axis = (pb - pa).Unit
	local n = H.ZVector
	local p = table.clone(props)
	p.Size = V(thick, width, (pb - pa).Magnitude)
	p.CFrame = CFrame.fromMatrix((pa + pb) / 2, n, axis:Cross(n))
	return B.part(p, parent)
end
local function disc(H, p, dia, thick, props, parent)
	local q = table.clone(props)
	q.Shape = Enum.PartType.Cylinder
	q.Size = V(thick, dia, dia)
	q.CFrame = CFrame.fromMatrix(H * V(p[1], p[2], p[3] or 0), H.ZVector, H.YVector)
	return B.part(q, parent)
end
local function cylBetween(pa, pb, d, props, parent)
	local q = table.clone(props)
	q.Shape = Enum.PartType.Cylinder
	q.Size = V((pb - pa).Magnitude, d, d)
	q.CFrame = CFrame.lookAt((pa + pb) / 2, pb) * CFrame.Angles(0, math.pi / 2, 0)
	return B.part(q, parent)
end
local function at(H, x, y, z) return H * CFrame.new(x, y, z or 0) end
local function lerp2(a, b, t) return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] } end
local function perp(a, b)
	local dx, dy = b[1] - a[1], b[2] - a[2]
	local L = math.sqrt(dx * dx + dy * dy)
	return -dy / L, dx / L, L
end
local function off(p, px, py, k) return { p[1] + px * k, p[2] + py * k, p[3] } end

-- 装甲臂段：主体 + 两面凸起面板 + 面板缝 + 两侧包边 + 发光灯带
-- o = { color, mv, panel, panelMv, seam, edge, glow, glowK（灯带在宽度方向的位置，−0.5…0.5）}
local function armor(H, a, b, thick, width, o, parent)
	local px, py, L = perp(a, b)
	local inset = math.min(0.35, L * 0.12) / L
	seg(H, a, b, thick, width, pr("Armor", o.color, o.mv or "armor"), parent)
	if o.panel then
		seg(H, lerp2(a, b, inset), lerp2(a, b, 1 - inset), thick + 0.12, width * 0.62, pr("Panel", o.panel, o.panelMv or o.mv or "armor"), parent)
		for _, k in ipairs({ -0.33, 0.33 }) do
			seg(H, off(lerp2(a, b, inset), px, py, width * k), off(lerp2(a, b, 1 - inset), px, py, width * k), thick + 0.16, 0.07, { Name = "Seam", Color = o.seam or hex("15172A") }, parent)
		end
	end
	if o.edge then
		for _, k in ipairs({ -0.5, 0.5 }) do
			seg(H, off(a, px, py, width * k), off(b, px, py, width * k), thick * 0.7, 0.16, pr("Edge", o.edge, o.edgeMv), parent)
		end
	end
	if o.glow then
		seg(H, off(lerp2(a, b, inset * 1.5), px, py, width * (o.glowK or 0.2)), off(lerp2(a, b, 1 - inset * 1.5), px, py, width * (o.glowK or 0.2)), thick + 0.1, 0.07, neon("GlowStrip", o.glow), parent) -- 灯带只做细线
	end
end

-- 光环关节：外壳 + 发光外圈 + 面盘 + 发光轴心 + 轴帽 + 两面各 6 颗螺栓
-- o = { housing, mv, ring, face, core, cap }
local function ringJoint(H, p, dia, thick, o, parent)
	disc(H, p, dia, thick, pr("JointHousing", o.housing, o.mv or "armor"), parent)
	if o.ring then disc(H, p, dia * 1.05, thick * 0.16, neon("JointRing", o.ring, 0.05), parent) end -- 细光圈
	disc(H, p, dia * 0.74, thick + 0.1, pr("JointFace", o.face or o.housing, o.faceMv or o.mv or "armor"), parent)
	if o.core then
		disc(H, p, dia * 0.3, thick + 0.16, neon("JointCore", o.core), parent) -- 轴心只留一小点光
	end
	disc(H, p, dia * 0.26, thick + 0.24, pr("JointCap", o.cap or hex("1B1D30"), "alloy"), parent)
	for _, sz in ipairs({ -1, 1 }) do
		for i = 0, 5 do
			local ang = i * math.pi / 3 + math.pi / 6
			B.ball(dia * 0.09, at(H, p[1] + math.cos(ang) * dia * 0.62, p[2] + math.sin(ang) * dia * 0.62, (p[3] or 0) + sz * (thick / 2 + 0.06)), pr("Bolt", CHROME, "alloy"), parent)
		end
	end
end

-- 液压缸：套筒 + 色环 + 镀铬杆 + 两端耳座
local function hydraulic(H, a, b, d, sleeve, band, parent)
	local pa, pb = H * V(a[1], a[2], a[3] or 0), H * V(b[1], b[2], b[3] or 0)
	local mid = pa:Lerp(pb, 0.58)
	cylBetween(pa, mid, d, pr("Sleeve", sleeve, "alloy"), parent)
	cylBetween(pa:Lerp(mid, 0.72), pa:Lerp(mid, 0.86), d * 1.08, pr("SleeveBand", band, "armor"), parent)
	cylBetween(mid, pb, d * 0.48, pr("Rod", CHROME, "alloy", { Reflectance = 0.3 }), parent)
	for _, p in ipairs({ pa, pb }) do
		B.box(V(d * 1.1, d * 1.1, d * 1.5), CFrame.new(p) * (H - H.Position), pr("Clevis", hex("2A2C40"), "alloy"), parent)
	end
end

-- 格构桁架
local function truss(H, a, b, halfW, railT, railW, railProps, braceProps, parent, bays)
	local px, py = perp(a, b)
	local a1, b1, a2, b2 = off(a, px, py, halfW), off(b, px, py, halfW), off(a, px, py, -halfW), off(b, px, py, -halfW)
	seg(H, a1, b1, railT, railW, railProps, parent)
	seg(H, a2, b2, railT, railW, railProps, parent)
	for k = 0, bays - 1 do
		local p0 = lerp2((k % 2 == 0) and a1 or a2, (k % 2 == 0) and b1 or b2, k / bays)
		local p1 = lerp2((k % 2 == 0) and a2 or a1, (k % 2 == 0) and b2 or b1, (k + 1) / bays)
		seg(H, p0, p1, railT * 0.75, railW * 0.55, braceProps, parent)
		B.ball(railW * 1.05, at(H, p1[1], p1[2], p1[3]), railProps, parent)
	end
end

------------------------------------------------------------------ 底座工具
local function ringOf(P, n, radius, y, size, props, parent, phase)
	local out = {}
	for i = 0, n - 1 do
		local a = (i + (phase or 0)) / n * math.pi * 2
		out[#out + 1] = B.box(size, P * CFrame.Angles(0, a, 0) * CFrame.new(0, y, -radius), props, parent)
	end
	return out
end
local function deckRings(P, y, rings, parent)
	local anchor = B.part({ Name = "RingAnchor", Size = V(0.2, 0.2, 0.2), CFrame = P * CFrame.new(0, y, 0), Transparency = 1 }, parent)
	for _, r in ipairs(rings) do
		local a = Instance.new("CylinderHandleAdornment")
		a.Name = "DeckRing"
		a.Adornee = anchor
		a.Radius = r[1]
		a.InnerRadius = r[1] - r[2]
		a.Height = 0.06
		a.CFrame = CFrame.Angles(math.pi / 2, 0, 0)
		a.Color3 = r[3]
		a.Transparency = r[4] or 0.05
		a.AlwaysOnTop = false
		a.ZIndex = 0
		a.Parent = anchor
	end
	return anchor
end
-- 黄黑警示板（斜纹）：cf = 板面中心，面朝 cf 的 −Z
local function hazardPanel(cf, w, h, parent)
	B.box(V(w, h, 0.3), cf, { Name = "HazardBase", Color = hex("1B1B22") }, parent)
	local n = math.floor(w / 0.9)
	for i = 0, n - 1 do
		local x = -w / 2 + 0.45 + i * (w - 0.9) / math.max(1, n - 1)
		B.box(V(0.42, h * 1.2, 0.06), cf * CFrame.new(x, 0, -0.17) * CFrame.Angles(0, 0, math.rad(35)), { Name = "Hazard", Color = hex("FFC21A") }, parent)
	end
	-- 用两条边框把斜纹截齐
	for _, dy in ipairs({ -h / 2 - 0.1, h / 2 + 0.1 }) do
		B.box(V(w + 0.2, 0.25, 0.4), cf * CFrame.new(0, dy, 0), { Name = "HazardFrame", Color = hex("2A2C40") }, parent)
	end
end
-- 磁吸 / 能量玻璃面板（带暗色网格线），面朝 H 的 −X
-- 11-25 改：面板本身不再整块发光，改成深色着色半透明玻璃 + 一圈细发光边框（用户嫌自发光太多）
local function glassPad(H, c, h, w, color, parent)
	local tint = Color3.new(color.R * 0.35, color.G * 0.35, color.B * 0.45)
	local g = B.box(V(0.2, h, w), at(H, c[1], c[2], c[3]), { Name = "EnergyGlass", Color = tint, Transparency = 0.2, Reflectance = 0.35, CastShadow = false }, parent)
	for _, dy in ipairs({ -h / 4, h / 4 }) do
		B.box(V(0.24, 0.05, w), at(H, c[1], c[2] + dy, c[3]), { Name = "GlassGrid", Color = hex("10263A") }, parent)
	end
	for _, dy in ipairs({ -h / 2, h / 2 }) do
		B.box(V(0.26, 0.06, w), at(H, c[1], c[2] + dy, c[3]), neon("GlassEdge", color), parent)
	end
	for _, dz in ipairs({ -w / 2, w / 2 }) do
		local e = B.box(V(0.26, h, 0.06), at(H, c[1], c[2], (c[3] or 0) + dz), neon("GlassEdge", color), parent)
		pulse(e, 0, 0.4, 2.6)
	end
	return g
end

------------------------------------------------------------------ mini war 式造型元素
-- 棱锥尖刺：4 块楔形拼成，cf = 底面中心，尖朝 cf 的 +Y
local function spike(cf, w, h, props, parent)
	for _, rot in ipairs({ 0, math.pi / 2 }) do
		for _, side in ipairs({ -1, 1 }) do
			B.wedge(V(w, h, w / 2), cf * CFrame.Angles(0, rot + (side > 0 and math.pi or 0), 0) * CFrame.new(0, h / 2, -w / 4), props, parent)
		end
	end
end
-- 塔楼 / 支柱：深色塔身 + 底座 + 外侧竖缝光 + 菱形光点 + 顶部尖刺；style = "slits" | "windows"（窗格）| "crown"（窗格 + 尖刺冠）
local function pylon(P, ang, r, h, w, style, cols, parent)
	local cf = P * CFrame.Angles(0, ang, 0) * CFrame.new(0, 0, -r)
	B.box(V(w + 1.0, 1.0, w + 1.0), cf * CFrame.new(0, 0.5, 0), pr("PylonBase", cols.dark2, "alloy"), parent)
	B.box(V(w, h, w), cf * CFrame.new(0, 1 + h / 2, 0), pr("PylonBody", cols.dark, "alloy"), parent)
	for _, sx in ipairs({ -1, 1 }) do -- 两侧扶壁
		B.wedge(V(0.5, h * 0.45, 1.0), cf * CFrame.new(sx * (w / 2 + 0.25), 1 + h * 0.225, 0) * CFrame.Angles(0, sx * math.pi / 2, 0), pr("Buttress", cols.dark2, "alloy"), parent)
	end
	local face = cf * CFrame.new(0, 0, -w / 2 - 0.03)
	if style == "slits" then
		B.box(V(0.08, h * 0.7, 0.06), face * CFrame.new(0, 1 + h * 0.5, 0), neon("Slit", cols.hue), parent)
		for _, y in ipairs({ 0.25, 0.75 }) do
			B.box(V(w * 0.6, 0.07, 0.06), face * CFrame.new(0, 1 + h * y, 0), neon("Slit", cols.hue), parent)
		end
	else
		local rows, cs = math.floor(h / 1.1), 3
		for i = 0, rows - 1 do
			for j = 0, cs - 1 do
				B.box(V(0.28, 0.32, 0.06), face * CFrame.new((j - 1) * w * 0.28, 1.6 + i * 1.05, 0), neon("Window", cols.hue, 0.15), parent)
			end
		end
	end
	B.box(V(0.4, 0.4, 0.4), face * CFrame.new(0, 1 + h + 0.0, -0.1) * CFrame.Angles(0, 0, math.pi / 4), neon("Node", cols.hue), parent)
	B.box(V(w + 0.3, 0.4, w + 0.3), cf * CFrame.new(0, 1 + h + 0.2, 0), pr("PylonCap", cols.dark2, "alloy"), parent)
	spike(cf * CFrame.new(0, 1 + h + 0.4, 0), w * 0.7, h * 0.45, pr("Spike", cols.dark, "alloy"), parent)
	if style == "crown" then -- 塔顶余烬：缓慢上升的本色火星
		local tip = B.part({ Name = "EmberAnchor", Size = V(w * 0.6, 0.2, w * 0.6), CFrame = cf * CFrame.new(0, 1 + h + h * 0.45, 0), Transparency = 1 }, parent)
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "Embers"
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.EmissionDirection = Enum.NormalId.Top
		pe.LightEmission, pe.LightInfluence = 1, 0
		pe.Rate = 5
		pe.Lifetime = NumberRange.new(2, 3.5)
		pe.Speed = NumberRange.new(1.5, 3)
		pe.SpreadAngle = Vector2.new(25, 25)
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
		pe.Parent = tip
		for _, cx in ipairs({ -1, 1 }) do
			for _, cz in ipairs({ -1, 1 }) do
				spike(cf * CFrame.new(cx * w * 0.42, 1 + h + 0.4, cz * w * 0.42), w * 0.3, h * 0.22, pr("Spike", cols.dark, "alloy"), parent)
			end
		end
	end
end
-- 台心能量核心：白热圆盘 + 内外两道细光环 + 上升粒子（视觉焦点）
local function energyCore(P, y, parent)
	B.cylAt(2.0, y, 0.06, P, neon("CoreHot", Color3.new(1, 1, 1)), parent)
	local a = B.part({ Name = "CoreAnchor", Size = V(1.6, 0.2, 1.6), CFrame = P * CFrame.new(0, y + 0.1, 0), Transparency = 1 }, parent)
	for _, rr in ipairs({ { 1.7, 0.14, "CoreHotRing" }, { 2.8, 0.1, "CoreRing" } }) do
		local ad = Instance.new("CylinderHandleAdornment")
		ad.Name = rr[3]
		ad.Adornee, ad.Radius, ad.InnerRadius, ad.Height = a, rr[1], rr[1] - rr[2], 0.05
		ad.CFrame = CFrame.Angles(math.pi / 2, 0, 0)
		ad.Transparency, ad.ZIndex = 0.05, 0
		ad.Parent = a
	end
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "CoreSparks"
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.EmissionDirection = Enum.NormalId.Top
	pe.LightEmission, pe.LightInfluence = 1, 0
	pe.Rate = 12
	pe.Lifetime = NumberRange.new(1.2, 2.2)
	pe.Speed = NumberRange.new(3, 7)
	pe.SpreadAngle = Vector2.new(14, 14)
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
	pe.Parent = a
end
-- 姿态推进器（11-25，第 3、4 套）：夹爪 / 锁体背面的小喷口，平时轻微喷焰，接住时由 S.setThrusters 调大。
-- H = 臂的铰链框架；p = 喷口位置 {x, y, z}；down = 喷射方向从 +X（朝外）往下压的角度（弧度）
local FIRE_TEX = "rbxasset://textures/particles/fire_main.dds"
local function thruster(H, p, down, size, parent)
	local A = at(H, p[1], p[2], p[3]) * CFrame.Angles(0, 0, -(math.pi / 2 + down)) -- A 的 +Y = 喷射方向
	B.cone(0.9 * size, 0.8 * size, A * CFrame.Angles(math.pi, 0, 0), pr("Nozzle", hex("2A2C40"), "alloy"), parent)
	B.cylAt(0.98 * size, -0.04, 0.1 * size, A, pr("NozzleRim", hex("8A90A8"), "alloy"), parent)
	local flame = B.cone(0.55 * size, 1.1 * size, A, neon("ThrusterFlame", Color3.new(1, 1, 1), 0.3), parent)
	pulse(flame, 0.25, 0.35, 26)
	local anchor = B.part({ Name = "ThrusterAnchor", Size = V(0.2, 0.2, 0.2), CFrame = A, Transparency = 1 }, parent)
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "ThrusterJet"
	pe.Texture = FIRE_TEX
	pe.EmissionDirection = Enum.NormalId.Top
	pe.LightEmission, pe.LightInfluence = 1, 0
	pe.SpreadAngle = Vector2.new(6, 6)
	pe.Rotation = NumberRange.new(0, 360)
	pe.RotSpeed = NumberRange.new(-120, 120)
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	pe:SetAttribute("Size0", size)
	pe.Parent = anchor
end
-- 底座喷焰环（11-25，第 3、4 套）：底座下沿一圈贴地喷出的能量火焰 + 地面光晕 + 上升火星，
-- 像平台被点火的能量托起；颜色 白热 → 本色 → 暗；setThrusters 全开时一起变旺。
local function baseFlames(P, radius, n, hue, hot, size, bright, parent)
	local fx = B.model("BaseFX", parent)
	local tail = Color3.new(hue.R * 0.25, hue.G * 0.15, hue.B * 0.25)
	for i = 0, n - 1 do
		local a = (i + 0.5) / n * math.pi * 2
		local cf = P * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.3, -(radius + 0.1)) * CFrame.Angles(math.rad(12), 0, 0) -- 喷口贴在底座外沿，焰头不被底座挡住
		local anchor = B.part({ Name = "BaseFlameAnchor", Size = V(1.2, 0.3, 0.3), CFrame = cf, Transparency = 1 }, fx)
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "BaseFlame"
		pe.Texture = FIRE_TEX
		pe.EmissionDirection = Enum.NormalId.Front -- 朝外（局部 −Z），略向上
		-- 白热只留最前 12%，其余是饱和本色（品红 / 紫色叠在紫地面上容易洗成淡紫烟）
		pe.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, hot), ColorSequenceKeypoint.new(0.12, hue), ColorSequenceKeypoint.new(0.7, hue), ColorSequenceKeypoint.new(1, tail) })
		pe.Brightness = bright
		pe.LightEmission, pe.LightInfluence = 1, 0
		pe.Lifetime = NumberRange.new(0.35, 0.7)
		pe.SpreadAngle = Vector2.new(28, 10)
		pe.Drag = 2.5
		pe.Acceleration = V(0, 4, 0)
		pe.Rotation = NumberRange.new(0, 360)
		pe.RotSpeed = NumberRange.new(-90, 90)
		pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.6, 0.35), NumberSequenceKeypoint.new(1, 1) })
		pe:SetAttribute("Size0", size)
		pe.Parent = anchor
	end
	-- 地面光晕：底座外一圈半透明本色 + 边缘一道亮细环
	local g = B.part({ Name = "GroundGlowAnchor", Size = V(0.2, 0.2, 0.2), CFrame = P * CFrame.new(0, 0.04, 0), Transparency = 1 }, fx)
	for _, rr in ipairs({ { radius + 2.6, radius - 0.4, 0.72 }, { radius + 0.45, radius + 0.15, 0.1 } }) do
		local ad = Instance.new("CylinderHandleAdornment")
		ad.Name = "GroundGlow"
		ad.Adornee, ad.Radius, ad.InnerRadius, ad.Height = g, rr[1], rr[2], 0.04
		ad.CFrame = CFrame.Angles(math.pi / 2, 0, 0)
		ad.Color3, ad.Transparency, ad.ZIndex = hue, rr[3], 0
		ad.Parent = g
	end
	-- 上升火星：从底座下沿一圈冒出
	local e = B.part({ Name = "BaseEmberAnchor", Size = V(radius * 2, 0.2, radius * 2), CFrame = P * CFrame.new(0, 0.2, 0), Transparency = 1 }, fx)
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "BaseEmbers"
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.EmissionDirection = Enum.NormalId.Top
	pe.Color = ColorSequence.new(hot, hue)
	pe.LightEmission, pe.LightInfluence = 1, 0
	pe.Rate = 10
	pe.Lifetime = NumberRange.new(1.2, 2.2)
	pe.Speed = NumberRange.new(2, 5)
	pe.SpreadAngle = Vector2.new(20, 20)
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
	pe.Parent = e
	B.decoAll(fx)
	return fx
end
-- 磁吸火花：磁吸面板边缘迸出的细小星火
local function magSparks(part, rate)
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "MagSparks"
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.LightEmission, pe.LightInfluence = 1, 0
	pe.Rate = rate
	pe.Lifetime = NumberRange.new(0.3, 0.6)
	pe.Speed = NumberRange.new(2, 5)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Drag = 4
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.22), NumberSequenceKeypoint.new(1, 0) })
	pe.Parent = part
end
-- 统一发光色：所有 Neon 件、台面光环、粒子刷成本套的 hue；轴心 / 指示灯 / 路灯 / 核心刷成 hot（白热）
local HOT_NAMES = { JointCore = true, FrontLight = true, Lamp = true, CoreHot = true, CoreHotRing = true } -- 推进器焰锥用本色，喷射粒子从白热渐变到本色
local function applyHue(m, hue, hot)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			if d.Material == NEON then
				d.Color = HOT_NAMES[d.Name] and hot or hue
			elseif d.Name == "EnergyGlass" then
				d.Color = Color3.new(hue.R * 0.3, hue.G * 0.3, hue.B * 0.35)
			end
		elseif d:IsA("HandleAdornment") then
			d.Color3 = HOT_NAMES[d.Name] and hot or hue
		elseif d:IsA("ParticleEmitter") then
			d.Color = ColorSequence.new(hot, hue)
		end
	end
end

------------------------------------------------------------------ 皮肤
local SKINS = {}

------------------------------------------------ 1. 中级：蓝橙装甲臂 + 格构下臂 + 橙色大关节 + 液压缸 + 加强齿爪；厚圆台 + 青色灯带
do
	local NAVY, NAVY2, BLUE, ORANGE, CYAN, STEEL = hex("2B3048"), hex("3A4062"), hex("3D5FD0"), hex("E07A2A"), hex("36D8FF"), hex("8A90A8")
	SKINS.mid = {
		name = "中级火箭回收支架", tag = "中级回收设备", deckY = 2.4, R = 9.2, angles = { 0, 180 },
		hue = hex("36D8FF"), hot = hex("E6FBFF"), dark = hex("2B3048"), dark2 = hex("3A4062"),
		horns = { { 1.7, 9.8, 0.8, 1.8, -0.5 }, { -2.0, 14.0, 0.9, 2.2, -0.25 } },
		base = function(P, m)
			B.cylAt(24, 0, 1.2, P, pr("Base", NAVY, "armor"), m)
			B.cylAt(22.6, 1.2, 0.8, P, pr("Tier", NAVY2, "armor"), m)
			B.cylAt(20.2, 2.0, 0.4, P, pr("Deck", hex("1F2244"), "deck"), m)
			ringOf(P, 10, 11.9, 0.62, V(3.1, 1.0, 0.9), pr("Bumper", ORANGE, "armor"), m, 0.5)
			ringOf(P, 5, 12.0, 0.55, V(2.4, 0.1, 0.1), neon("RimLight", CYAN), m)
			ringOf(P, 10, 11.38, 1.6, V(0.5, 0.5, 0.2), pr("Rivet", STEEL, "alloy"), m, 0.5)
			-- 正面圆形指示灯
			B.cylAt(1.8, 0.2, 0.15, P * CFrame.new(0, 0.6, -12.05) * CFrame.Angles(math.pi / 2, 0, 0), pr("LightHousing", hex("1B1D30"), "alloy"), m)
			B.ball(0.55, P * CFrame.new(0, 0.6, -12.1), neon("FrontLight", hex("FFC46B")), m) -- 琥珀色指示灯
			-- 台面：内凸圆盘 + 青色同心光环 + 绿色引导核心
			B.cylAt(13, 2.4, 0.12, P, pr("InnerPad", hex("2A2E5C"), "deck"), m)
			deckRings(P, 2.56, { { 9.6, 0.12, CYAN }, { 3.4, 0.1, hex("9EDBFF") }, { 0.9, 0.9, hex("3BD85C"), 0.2 } }, m)
		end,
		pedestal = function(F, m)
			B.box(V(3.4, 2.2, 3.4), F * CFrame.new(0.2, 0.6, 0), pr("Pedestal", NAVY2, "armor"), m)
			B.box(V(3.5, 0.3, 3.5), F * CFrame.new(0.2, 1.75, 0), pr("PedestalTrim", ORANGE, "armor"), m)
			B.box(V(0.06, 0.1, 2.0), F * CFrame.new(1.93, 1.0, 0), neon("PedestalLight", hex("FFC46B")), m)
			return 1.2
		end,
		arm = function(H, m)
			local J0, J1, J2, J3, c = { 0, 0.8 }, { 1.2, 8.6 }, { -2.2, 13.0 }, { -4.7, 10.4 }, { -5.9, 9.0 }
			-- 下臂：A 字格构 + 橙色加强板 + 大液压缸
			truss(H, J0, J1, 0.85, 1.0, 0.6, pr("Rail", NAVY2, "armor"), pr("Brace", hex("1C1E36"), "alloy"), m, 5)
			seg(H, lerp2(J0, J1, 0.08), lerp2(J0, J1, 0.3), 1.2, 1.9, pr("Gusset", ORANGE, "armor"), m)
			hydraulic(H, { 2.0, 1.0 }, { 1.8, 7.0 }, 1.05, STEEL, ORANGE, m)
			-- 上臂 / 前臂：深蓝装甲 + 蓝色面板 + 橙色条
			armor(H, J1, J2, 1.7, 2.0, { color = NAVY, panel = BLUE, edge = ORANGE, glow = hex("9EDBFF"), glowK = -0.05 }, m)
			armor(H, J2, J3, 1.5, 1.6, { color = NAVY, panel = BLUE, edge = ORANGE }, m)
			ringJoint(H, J0, 3.0, 2.0, { housing = NAVY2, face = ORANGE, cap = hex("1B1D30") }, m)
			ringJoint(H, J1, 2.8, 2.2, { housing = NAVY2, face = ORANGE, cap = hex("1B1D30") }, m)
			ringJoint(H, J2, 2.4, 1.9, { housing = NAVY2, face = ORANGE, cap = hex("1B1D30") }, m)
			seg(H, J3, { c[1] + 0.6, c[2] + 1.0 }, 1.0, 1.0, pr("Wrist", STEEL, "alloy"), m)
			-- 加强齿爪：合金爪体 + 橙色背板 + 蓝色侧板 + 横向齿排 + 青色指示灯
			B.box(V(1.7, 3.4, 2.6), at(H, c[1], c[2]), pr("Clamp", STEEL, "alloy"), m)
			B.box(V(0.5, 3.6, 2.8), at(H, c[1] + 0.95, c[2]), pr("ClampBack", ORANGE, "armor"), m)
			for _, z in ipairs({ -1.38, 1.38 }) do
				B.box(V(1.6, 3.0, 0.2), at(H, c[1], c[2], z), pr("ClampSide", BLUE, "armor"), m)
				B.box(V(0.05, 1.0, 0.22), at(H, c[1] + 0.3, c[2], z * 1.01), neon("ClampLight", CYAN), m)
			end
			for t = 0, 5 do
				B.box(V(0.45, 0.32, 2.4), at(H, c[1] - 1.0, c[2] - 1.35 + t * 0.54), pr("Tooth", CHROME, "alloy", { Reflectance = 0.2 }), m)
			end
		end,
	}
end

------------------------------------------------ 2. 进阶：多关节装甲臂 + 橙色发光关节环 + 辅助稳定臂 + 青色磁力模块 + 弹簧缓冲；八边装甲底座 + 正面警示板
do
	local NAVY, NAVY2, BLUE, ORANGE, CYAN, STEEL = hex("2A2D44"), hex("3A3E5E"), hex("3A55B8"), hex("D9742A"), hex("FF3040"), hex("8A90A8")
	SKINS.adv = {
		name = "进阶火箭回收支架", tag = "中高阶回收设备", deckY = 2.6, R = 9.6, angles = { 0, 180 },
		hue = hex("FF3040"), hot = hex("FFE2E4"), dark = hex("2A2D44"), dark2 = hex("3A3E5E"),
		horns = { { 1.5, 9.4, 0.9, 2.0, -0.6 }, { -1.2, 14.6, 1.0, 2.6, -0.25 } },
		pylons = { n = 4, r = 12.3, h = 4.6, w = 1.8, style = "slits" },
		base = function(P, m)
			B.cylAt(25, 0, 1.0, P, pr("Base", hex("1C1E36"), "armor"), m)
			ringOf(P, 8, 11.9, 1.0, V(5.4, 1.8, 1.4), pr("ArmorPlate", NAVY2, "armor"), m)
			ringOf(P, 8, 12.62, 1.25, V(3.0, 0.08, 0.1), neon("RimLight", hex("9EDBFF")), m)
			ringOf(P, 8, 12.3, 1.0, V(1.2, 2.0, 1.6), pr("CornerBlock", ORANGE, "armor"), m, 0.5)
			hazardPanel(P * CFrame.new(0, 1.0, -12.7), 5.0, 1.1, m)
			B.cylAt(22, 1.8, 0.8, P, pr("Deck", hex("1F2244"), "deck"), m)
			B.cylAt(14, 2.6, 0.1, P, pr("InnerPad", hex("2A2E5C"), "deck"), m)
			deckRings(P, 2.72, { { 10.2, 0.12, CYAN }, { 5.0, 0.1, hex("9EDBFF") }, { 0.9, 0.9, hex("3BD85C"), 0.2 } }, m)
		end,
		pedestal = function(F, m)
			B.box(V(3.6, 2.0, 3.8), F * CFrame.new(0.2, 0.5, 0), pr("Pedestal", NAVY2, "armor"), m)
			B.box(V(3.7, 0.3, 3.9), F * CFrame.new(0.2, 1.55, 0), pr("PedestalTrim", ORANGE, "armor"), m)
			-- 弹簧缓冲器（外侧）
			B.cylAt(0.5, 0, 3.0, F * CFrame.new(2.6, 0, 0), pr("CoilRod", CHROME, "alloy"), m)
			for i = 0, 5 do -- 弹簧圈用镀铬，只有上下两圈细发光
				local glowRing = (i == 0 or i == 5)
				B.cylAt(1.3, 0.3 + i * 0.42, glowRing and 0.08 or 0.16, F * CFrame.new(2.6, 0, 0), glowRing and neon("Coil", CYAN) or pr("Coil", CHROME, "alloy"), m)
			end
			B.cylAt(1.5, 2.9, 0.3, F * CFrame.new(2.6, 0, 0), pr("CoilCap", STEEL, "alloy"), m)
			return 1.2
		end,
		arm = function(H, m)
			local J0, J1, J2, J3, c = { 0, 0.8 }, { 1.0, 8.2 }, { -1.4, 13.4 }, { -4.2, 11.8 }, { -6.0, 9.8 }
			armor(H, J0, J1, 1.8, 1.9, { color = NAVY, panel = BLUE, edge = ORANGE }, m)
			armor(H, J1, J2, 1.7, 1.9, { color = NAVY, panel = NAVY2, edge = ORANGE, glow = hex("9EDBFF"), glowK = -0.1 }, m)
			armor(H, J2, J3, 1.5, 1.6, { color = NAVY, panel = BLUE, edge = ORANGE }, m)
			-- 辅助稳定臂（前后各一根，带橙色销轴）
			for _, z in ipairs({ -1.2, 1.2 }) do
				seg(H, { 2.4, 0.8, z }, { 0.6, 9.6, z }, 0.45, 0.55, pr("AuxLink", STEEL, "alloy"), m)
				disc(H, { 2.4, 0.8, z }, 0.8, 0.55, pr("AuxPin", ORANGE, "armor"), m)
				disc(H, { 0.6, 9.6, z }, 0.8, 0.55, pr("AuxPin", ORANGE, "armor"), m)
			end
			hydraulic(H, { -0.9, 2.0 }, { -0.4, 7.6 }, 0.8, STEEL, ORANGE, m)
			for i, j in ipairs({ J0, J1, J2, J3 }) do
				local d = ({ 3.0, 2.9, 2.5, 2.0 })[i]
				ringJoint(H, j, d, 2.1, { housing = hex("1C1E36"), ring = hex("FF5A10"), face = NAVY2, core = hex("FF6A1A") }, m) -- 发光橙要压深，Bloom 会把亮橙推成黄
			end
			seg(H, J3, { c[1] + 0.8, c[2] + 1.2 }, 1.1, 1.1, pr("Wrist", STEEL, "alloy"), m)
			-- 磁力夹持模块：深色模块 + 橙色框 + 大块青色能量玻璃
			B.box(V(1.9, 3.6, 2.9), at(H, c[1], c[2]), pr("Module", hex("1C1E36"), "armor"), m)
			for _, dy in ipairs({ -1.85, 1.85 }) do
				B.box(V(2.0, 0.35, 3.0), at(H, c[1], c[2] + dy), pr("ModuleFrame", ORANGE, "armor"), m)
			end
			for _, z in ipairs({ -1.5, 1.5 }) do
				B.box(V(2.0, 3.6, 0.25), at(H, c[1], c[2], z), pr("ModuleSide", BLUE, "armor"), m)
			end
			glassPad(H, { c[1] - 1.02, c[2], 0 }, 3.0, 2.5, CYAN, m)
		end,
	}
end

------------------------------------------------ 3. 高阶（概念图）：淡紫装甲大拱臂 + 发光橙色大关节环 + 黄色液压 + 蓝色磁吸夹头；
--    三层岛式底座（橙色灯带、装甲板）+ 正面导向灯带坡道 + 控制模块 + 路灯
do
	local LAV, LAV2, DARK, ORANGE, GOLD, YELLOW, BLUEG, CYAN = hex("3E3A62"), hex("8C84CF"), hex("22213A"), hex("C844FF"), hex("C844FF"), hex("D9A21A"), hex("C844FF"), hex("C844FF")
	SKINS.hi = {
		name = "高阶火箭回收支架", tag = "高阶回收设备", deckY = 3.0, R = 10.5, angles = { 0, 180 },
		hue = hex("C844FF"), hot = hex("F6E2FF"), dark = hex("2E2B48"), dark2 = hex("423D66"),
		horns = { { 1.7, 12.7, 1.1, 2.8, -0.55 }, { -2.6, 15.9, 1.2, 3.2, -0.2 }, { -0.9, 15.6, 0.8, 1.9, 0.15 } },
		pylons = { n = 4, r = 13.5, h = 7.0, w = 2.2, style = "slits" },
		baseFx = { r = 14, n = 12, size = 1.35, bright = 3 }, -- 底座喷焰环（品红火焰偏暗：尺寸放大 + 亮度 ×3）
		base = function(P, m)
			B.cylAt(28, 0, 1.2, P, pr("Base", LAV2, "armor"), m)
			ringOf(P, 10, 14.02, 0.6, V(3.0, 0.1, 0.1), neon("RimLight", ORANGE), m)
			B.cylAt(25.4, 1.2, 1.0, P, pr("Tier", DARK, "armor"), m)
			ringOf(P, 12, 12.4, 1.7, V(5.4, 1.1, 1.1), pr("ArmorPlate", LAV, "armor"), m, 0.5)
			B.cylAt(20, 2.2, 0.8, P, pr("Deck", hex("23244A"), "deck"), m)
			B.cylAt(15, 3.0, 0.1, P, pr("InnerPad", hex("1E1F44"), "deck"), m)
			B.segRing(P * CFrame.new(0, 3.08, 0), 7.0, 28, 1.0, 0.12, 0.04, neon("DeckDash", GOLD), m)
			deckRings(P, 3.12, { { 5.4, 0.12, BLUEG }, { 1.0, 1.0, hex("3BD85C"), 0.2 } }, m)
			-- 坡道两侧警示板
			for _, sx in ipairs({ -1, 1 }) do
				hazardPanel(P * CFrame.Angles(0, sx * math.rad(24), 0) * CFrame.new(0, 1.7, -12.95), 3.6, 0.9, m)
			end
			-- 导向灯带坡道（正面 −Z）：橙色侧边灯 + 护栏 + 三道脉动青色箭头
			local L, Hh, Wd = 10, 3.0, 7.4
			B.wedge(V(Wd, Hh, L), P * CFrame.new(0, Hh / 2, -12.2 - L / 2), pr("Ramp", DARK, "deck"), m)
			local alpha = math.atan(Hh / L)
			local function slope(t, x, y) return P * CFrame.new(x or 0, Hh * t + (y or 0.08), -12.2 - L + L * t) * CFrame.Angles(-alpha, 0, 0) end
			for _, sx in ipairs({ -1, 1 }) do
				B.box(V(0.6, 0.5, L * 1.04), slope(0.5, sx * (Wd / 2 - 0.3), 0.3), pr("RampRail", LAV, "armor"), m)
				B.box(V(0.08, 0.06, L * 1.02), slope(0.5, sx * (Wd / 2 - 0.75)), neon("RampLight", ORANGE), m)
			end
			for i, t in ipairs({ 0.22, 0.47, 0.72 }) do
				for _, sx in ipairs({ -1, 1 }) do
					local p = B.box(V(2.0, 0.04, 0.22), slope(t) * CFrame.new(sx * 0.82, 0, 0) * CFrame.Angles(0, sx * math.rad(32), 0), neon("Chevron", CYAN), m)
					pulse(p, 0.0, 0.7, 5 + i)
				end
			end
			-- 控制模块（监控 / 调度）：机柜 + 金边 + 倾斜屏幕（火箭图标）
			local K = P * CFrame.new(10.2, 0, -13.6)
			B.box(V(3.0, 2.8, 2.0), K * CFrame.new(0, 1.4, 0), pr("Console", LAV, "armor"), m)
			B.box(V(3.1, 0.25, 2.1), K * CFrame.new(0, 2.9, 0), pr("ConsoleTrim", LAV2, "alloy"), m)
			B.box(V(2.0, 0.06, 0.06), K * CFrame.new(0, 1.0, -1.02), neon("ConsoleLight", ORANGE), m)
			B.box(V(3.4, 2.2, 0.3), K * CFrame.new(0, 3.9, -0.3) * CFrame.Angles(math.rad(-25), 0, 0), pr("ScreenFrame", DARK, "armor"), m)
			local scr = B.box(V(3.0, 1.8, 0.1), K * CFrame.new(0, 3.9, -0.3) * CFrame.Angles(math.rad(-25), 0, 0) * CFrame.new(0, 0, -0.18), { Name = "Screen", Color = hex("1E5BD8"), Material = NEON, Transparency = 0.1 }, m)
			B.surfaceText(scr, Enum.NormalId.Front, { { text = "🚀", h = 0.6 }, { text = "回收控制", h = 0.3, color = hex("CFEFFF"), font = Enum.Font.GothamBold } }, { pps = 40, lightInfluence = 0 })
			-- 路灯 ×2
			for _, sx in ipairs({ -1, 1 }) do
				local Lp = P * CFrame.new(sx * 7.6, 0, -14.0)
				B.box(V(0.9, 0.5, 0.9), Lp * CFrame.new(0, 0.25, 0), pr("LampBase", DARK, "armor"), m)
				B.box(V(0.4, 3.8, 0.4), Lp * CFrame.new(0, 2.2, 0), pr("LampPost", DARK, "alloy"), m)
				B.box(V(0.6, 0.7, 0.6), Lp * CFrame.new(0, 4.4, 0), neon("Lamp", hex("FFF1D6")), m) -- 暖白灯
				B.box(V(1.2, 0.2, 1.2), Lp * CFrame.new(0, 5.0, 0), pr("LampCap", DARK, "alloy"), m)
			end
		end,
		pedestal = function(F, m)
			B.box(V(4.0, 3.4, 4.2), F * CFrame.new(0.3, 0.2, 0), pr("Pedestal", LAV, "armor"), m)
			B.box(V(4.1, 0.35, 4.3), F * CFrame.new(0.3, 1.95, 0), pr("PedestalTrim", DARK, "armor"), m)
			B.box(V(0.06, 0.1, 2.8), F * CFrame.new(2.32, 1.2, 0), neon("PedestalLight", ORANGE), m)
			B.box(V(1.6, 1.2, 0.2), F * CFrame.new(0.3, 0.6, 2.16), pr("PedestalPanel", DARK, "armor"), m)
			return 1.8
		end,
		arm = function(H, m)
			local J0, J1, J2, J3, c = { 0, 1.0 }, { 0.8, 11.0 }, { -2.8, 14.6 }, { -5.6, 11.4 }, { -7.25, 9.9 }
			-- 大拱臂：淡紫装甲 + 深色内板 + 橙色灯带
			armor(H, J0, J1, 2.3, 2.6, { color = LAV, panel = DARK, panelMv = "armor", edge = LAV2, glow = ORANGE, glowK = 0 }, m)
			armor(H, J1, J2, 2.0, 2.2, { color = LAV, panel = DARK, edge = LAV2 }, m)
			-- 关节：底部、肩部大发光环、肘部
			ringJoint(H, J0, 3.2, 2.6, { housing = DARK, face = LAV2, core = ORANGE }, m)
			ringJoint(H, J1, 4.0, 2.8, { housing = DARK, ring = ORANGE, face = DARK, core = GOLD }, m)
			ringJoint(H, J2, 2.6, 2.3, { housing = DARK, face = LAV, core = GOLD }, m)
			-- 黄色液压前臂（双缸）+ 关节
			for _, z in ipairs({ -0.55, 0.55 }) do
				hydraulic(H, { J2[1], J2[2], z }, { J3[1], J3[2], z }, 1.0, YELLOW, DARK, m)
			end
			ringJoint(H, J3, 2.0, 1.9, { housing = DARK, face = YELLOW }, m)
			seg(H, J3, { c[1] + 0.8, c[2] + 0.9 }, 1.1, 1.1, pr("Wrist", DARK, "alloy"), m)
			-- 磁吸夹头：黄框 + 深色模块 + 蓝色发光面板（两块）
			B.box(V(1.8, 3.2, 2.8), at(H, c[1], c[2]), pr("Clamp", DARK, "armor"), m)
			for _, dy in ipairs({ -1.6, 1.6 }) do
				B.box(V(1.9, 0.4, 2.9), at(H, c[1], c[2] + dy), pr("ClampFrame", YELLOW, "armor"), m)
			end
			for _, z in ipairs({ -1.4, 1.4 }) do
				B.box(V(1.9, 3.6, 0.35), at(H, c[1], c[2], z), pr("ClampFrame", YELLOW, "armor"), m)
			end
			local pad = glassPad(H, { c[1] - 0.97, c[2], 0 }, 2.6, 2.3, BLUEG, m)
			magSparks(pad, 6)
			-- 姿态推进器：夹头背面上下两个，朝外略向下喷
			for _, dy in ipairs({ -1.0, 1.0 }) do
				thruster(H, { c[1] + 1.0, c[2] + dy, 0 }, math.rad(dy > 0 and 15 or 35), 1.0, m)
			end
		end,
	}
end

------------------------------------------------ 4. 旗舰：4 支多轴捕获臂（拉丝合金 + 碳纤维 + 阳极钛 + 金色发光关节）+ 能量玻璃磁吸缓冲锁；
--    重装八边底座：合金装甲板、散热格栅、金色徽标、青色 / 橙色灯带、绿色能量环 + 刻度 + 悬浮稳定环
do
	local ALLOY, ALLOY_D, CARBON, TI, GOLD, GOLDG, ORANGE, ENERGY, GREEN = hex("6A6F8A"), hex("4E5268"), hex("24263A"), hex("4A4290"), hex("D9A72E"), hex("FFB82E"), hex("FFB82E"), hex("FFB82E"), hex("FFB82E")
	SKINS.flag = {
		name = "旗舰火箭回收支架", tag = "旗舰级回收设备", deckY = 3.2, R = 10, angles = { 25, 155, 205, 335 },
		hue = hex("FFB82E"), hot = hex("FFF4D6"), dark = hex("262838"), dark2 = hex("3A3D52"),
		horns = { { 2.0, 10.5, 1.0, 2.4, -0.6 }, { -1.4, 14.9, 1.1, 3.0, -0.2 } },
		pylons = { n = 4, r = 14.4, h = 11, w = 2.6, style = "crown" },
		baseFx = { r = 15, n = 16, size = 1.25, bright = 1.5 },
		base = function(P, m)
			B.cylAt(30, 0, 1.2, P, pr("Base", CARBON, "carbon"), m)
			ringOf(P, 12, 15.02, 0.6, V(3.0, 0.1, 0.1), neon("RimLight", ENERGY), m)
			B.cylAt(27, 1.2, 1.2, P, pr("Core", TI, "ti"), m)
			ringOf(P, 8, 13.6, 1.8, V(6.2, 1.9, 1.5), pr("ArmorPlate", ALLOY, "alloy", { Reflectance = 0.08 }), m, 0.5)
			ringOf(P, 8, 14.37, 2.6, V(5.0, 0.06, 0.08), neon("ArmorTrim", GOLDG), m, 0.5)
			ringOf(P, 8, 13.7, 1.8, V(3.4, 1.4, 1.2), pr("Vent", hex("17181F"), "vent"), m)
			-- 正面金色徽标
			B.box(V(4.2, 1.6, 0.4), P * CFrame.new(0, 1.8, -14.45), pr("Emblem", GOLD, "alloy", { Reflectance = 0.15 }), m)
			for _, sx in ipairs({ -1, 1 }) do
				B.box(V(1.6, 0.22, 0.12), P * CFrame.new(sx * 0.5, 1.8, -14.7) * CFrame.Angles(0, 0, sx * math.rad(55)), neon("EmblemMark", hex("FFF1B8")), m)
			end
			B.cylAt(23, 2.4, 0.8, P, pr("Deck", hex("1B1C2C"), "deck"), m)
			B.cylAt(17, 3.2, 0.1, P, pr("InnerPad", hex("16172A"), "deck"), m)
			deckRings(P, 3.32, { { 8.0, 0.12, GREEN }, { 6.2, 0.08, hex("A8F5C0") }, { 2.2, 0.1, GREEN }, { 0.9, 0.9, GREEN, 0.2 } }, m)
			for i = 0, 15 do -- 刻度
				local a = i / 16 * math.pi * 2
				B.box(V(0.08, 0.04, i % 4 == 0 and 1.2 or 0.7), P * CFrame.Angles(0, a, 0) * CFrame.new(0, 3.29, -7.1), neon("Tick", hex("A8F5C0")), m)
			end
			-- 智能稳定环：台面上方悬浮的绿色全息环（客户端自转）
			B.fx.haloRing(P * CFrame.new(0, 4.4, 0), 5.0, 24, GREEN, 0.7, m)
		end,
		pedestal = function(F, m)
			B.box(V(3.8, 2.6, 4.0), F * CFrame.new(0.2, 0.5, 0), pr("Pedestal", ALLOY, "alloy", { Reflectance = 0.08 }), m)
			B.box(V(3.9, 0.28, 4.1), F * CFrame.new(0.2, 1.8, 0), pr("PedestalCap", GOLD, "alloy", { Reflectance = 0.15 }), m)
			B.box(V(0.06, 0.06, 3.6), F * CFrame.new(2.12, 1.62, 0), neon("PedestalLine", GOLDG), m)
			for _, z in ipairs({ -2.02, 2.02 }) do
				B.box(V(2.6, 1.6, 0.12), F * CFrame.new(0.2, 0.4, z), pr("PedestalPanel", CARBON, "carbon"), m)
			end
			return 1.9
		end,
		arm = function(H, m)
			local J0, J1, J2, J3, c = { 0, 0.9 }, { 1.2, 9.0 }, { -1.6, 13.6 }, { -4.6, 11.9 }, { -6.45, 10.0 }
			local AL = pr("Rail", ALLOY, "alloy", { Reflectance = 0.08 })
			-- 下臂：合金格构桁架 + 金色灯点 + 双伺服液压（碳纤维套筒、金环）
			truss(H, J0, J1, 1.0, 1.1, 0.75, AL, pr("Brace", CARBON, "carbon"), m, 6)
			for _, z in ipairs({ -0.9, 0.9 }) do
				hydraulic(H, { 2.1, 1.2, z }, { 1.9, 7.4, z }, 0.85, CARBON, GOLD, m)
			end
			-- 上臂 / 前臂：拉丝合金装甲 + 碳纤维嵌板 + 金色包边 + 灯带
			armor(H, J1, J2, 2.0, 2.2, { color = ALLOY, mv = "alloy", panel = CARBON, panelMv = "carbon", edge = GOLD, edgeMv = "alloy", glow = GOLDG, glowK = 0 }, m)
			armor(H, J2, J3, 1.7, 1.8, { color = ALLOY, mv = "alloy", panel = TI, panelMv = "ti", edge = GOLD, edgeMv = "alloy" }, m)
			for i, j in ipairs({ J0, J1, J2, J3 }) do
				local d = ({ 3.2, 3.1, 2.7, 2.2 })[i]
				ringJoint(H, j, d, 2.3, { housing = CARBON, mv = "carbon", ring = GOLDG, face = ALLOY, faceMv = "alloy", core = ORANGE }, m)
			end
			seg(H, J3, { c[1] + 1.0, c[2] + 1.2 }, 1.2, 1.2, pr("Wrist", CARBON, "carbon"), m)
			-- 磁吸缓冲锁：碳纤维锁体 + 合金背壳 + 金框 + 能量玻璃 + 侧面青色灯
			B.box(V(2.2, 3.8, 3.2), at(H, c[1], c[2]), pr("Lock", CARBON, "carbon"), m)
			B.box(V(0.9, 4.1, 3.5), at(H, c[1] + 1.2, c[2]), pr("LockShell", ALLOY, "alloy", { Reflectance = 0.08 }), m)
			for _, dy in ipairs({ -1.95, 1.95 }) do
				B.box(V(2.3, 0.3, 3.3), at(H, c[1], c[2] + dy), pr("LockFrame", GOLD, "alloy", { Reflectance = 0.15 }), m)
			end
			for _, z in ipairs({ -1.62, 1.62 }) do
				B.box(V(1.4, 0.06, 0.06), at(H, c[1], c[2] + 1.0, z), neon("LockLight", hex("FFC46B")), m)
			end
			local g = glassPad(H, { c[1] - 1.17, c[2], 0 }, 3.2, 2.8, ENERGY, m)
			magSparks(g, 8)
			-- 姿态推进器：合金背壳上下两个（比高阶大一号）
			for _, dy in ipairs({ -1.3, 1.3 }) do
				thruster(H, { c[1] + 1.65, c[2] + dy, 0 }, math.rad(dy > 0 and 10 or 35), 1.25, m)
			end
		end,
	}
end

S.SKINS = SKINS
S.ORDER = { "mid", "adv", "hi", "flag" }

------------------------------------------------------------------ 建造
local function decoAllSmall(m)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			local s = d.Size
			if d.Material == NEON or math.min(s.X, s.Y, s.Z) < 0.35 then B.deco(d) end
		end
	end
end

-- P：平台中心（地面）；opts.guide = true 时显示绿色引导光柱（原画里火箭降落时的引导场）
function S.build(P, id, parent, opts)
	local sk = SKINS[id]
	local m = B.model("RecoveryBracket")
	m:SetAttribute("SkinId", id)
	m:SetAttribute("SkinName", sk.name)
	m:SetAttribute("DeckY", sk.deckY)
	m:SetAttribute("Pose", 0)
	local plat = B.model("Platform", m)
	sk.base(P, plat)
	m:SetAttribute("ArmCount", #sk.angles)
	m:SetAttribute("Hue", sk.hue)
	if sk.pylons then -- 底座四角塔楼（45° 方向，避开臂和正面坡道）
		local py = sk.pylons
		for k = 0, py.n - 1 do
			pylon(P, math.rad(45 + 90 * k), py.r, py.h, py.w, py.style, { dark = sk.dark, dark2 = sk.dark2, hue = sk.hue }, plat)
		end
	end
	energyCore(P, sk.deckY + 0.14, plat)
	for i, deg in ipairs(sk.angles) do
		local F = P * CFrame.Angles(0, math.rad(deg), 0) * CFrame.new(sk.R, sk.deckY, 0)
		local h = sk.pedestal(F, plat)
		local H = F * CFrame.new(0, h, 0)
		local a = B.model("Arm_" .. i, m)
		sk.arm(H, a)
		for _, hn in ipairs(sk.horns or {}) do -- 臂上尖刺（关节外侧，向外斜）
			spike(at(H, hn[1], hn[2]) * CFrame.Angles(0, 0, hn[5]), hn[3], hn[4], pr("Horn", sk.dark, "alloy"), a)
		end
		a.WorldPivot = H
		a:SetAttribute("ClosedPivot", H)
	end
	applyHue(m, sk.hue, sk.hot)
	if sk.baseFx then baseFlames(P, sk.baseFx.r, sk.baseFx.n, sk.hue, sk.hot, sk.baseFx.size, sk.baseFx.bright or 1, plat) end
	decoAllSmall(m)
	S.setThrusters(m, (opts and opts.thrusters) or 0.4)
	m.WorldPivot = P
	if opts and opts.guide then S.setGuide(m, true) end
	m.Parent = parent
	return m
end

function S.deckCF(m)
	return m:GetPivot() * CFrame.new(0, m:GetAttribute("DeckY"), 0)
end

-- 推进器强度：0 熄火 / 0.4 待机（默认）/ 1 接住瞬间全开（运行时可补间）
function S.setThrusters(m, power)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("ParticleEmitter") and d.Name == "ThrusterJet" then
			local s0 = d:GetAttribute("Size0") or 1
			d.Enabled = power > 0.01
			d.Rate = 15 + 70 * power
			d.Speed = NumberRange.new((3 + 8 * power) * s0, (5 + 12 * power) * s0)
			d.Lifetime = NumberRange.new(0.12, 0.18 + 0.2 * power)
			d.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, (0.35 + 0.45 * power) * s0), NumberSequenceKeypoint.new(1, 0.05) })
		elseif d:IsA("BasePart") and d.Name == "ThrusterFlame" then
			-- 焰锥尺寸不变（臂会动，改尺寸会让焰锥离开喷口），用透明度表现强弱
			local tr = power > 0.01 and (0.55 - 0.35 * math.min(power, 1)) or 1
			d.Transparency = tr
			d:SetAttribute("PulseBase", tr)
			d:SetAttribute("PulseAmp", power > 0.01 and 0.3 or 0)
		end
	end
	for _, d in ipairs(m:GetDescendants()) do -- 底座喷焰随推进器一起变旺
		if d:IsA("ParticleEmitter") and d.Name == "BaseFlame" then
			local s0 = d:GetAttribute("Size0") or 1
			d.Enabled = power > 0.01
			d.Rate = 10 + 22 * power
			d.Speed = NumberRange.new((3 + 4 * power) * s0, (5 + 7 * power) * s0)
			d.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, (0.9 + 0.6 * power) * s0), NumberSequenceKeypoint.new(1, (2.0 + 1.4 * power) * s0) })
		end
	end
	m:SetAttribute("Thrusters", power)
end

-- 绿色引导光柱（实心圆柱装饰 + 三道光环），降落对准时打开
function S.setGuide(m, on)
	local g = m:FindFirstChild("GuideBeam")
	if g then g:Destroy() end
	if not on then return end
	local anchor = B.part({ Name = "GuideBeam", Size = V(0.2, 0.2, 0.2), CFrame = S.deckCF(m), Transparency = 1 }, m)
	B.deco(anchor)
	local UP = CFrame.Angles(math.pi / 2, 0, 0)
	local col = m:GetAttribute("Hue") or hex("3BD85C") -- 引导光柱用本套标志色
	local beam = Instance.new("CylinderHandleAdornment")
	beam.Adornee, beam.Radius, beam.InnerRadius, beam.Height = anchor, 3.6, 0, 14
	beam.CFrame = CFrame.new(0, 7, 0) * UP
	beam.Color3, beam.Transparency, beam.ZIndex = col, 0.86, 0
	beam.Parent = anchor
	for _, y in ipairs({ 0.15, 4.5, 9 }) do
		local r = Instance.new("CylinderHandleAdornment")
		r.Adornee, r.Radius, r.InnerRadius, r.Height = anchor, 3.9, 3.5, 0.18
		r.CFrame = CFrame.new(0, y, 0) * UP
		r.Color3, r.Transparency, r.ZIndex = col, 0.05, 0
		r.Parent = anchor
	end
end

return S
