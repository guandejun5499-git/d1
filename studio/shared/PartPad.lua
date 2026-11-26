--[[
	PartPad · 部件台全部状态（ReplicatedStorage.OrbitShared.PartPad）
	部件台模型由 06_home_roll 建：WorldPivot = 台底中心，含 RingLight / Cap / HoloDisc，属性 Slot。
	P.setState(pad, st, opts)：
	  { mode = "idle" }                    待机：环灯暗、全息盘淡、无卡片
	  { mode = "rolling" }                 开箱中：环灯青色快闪、「? ? ?」卡
	  { mode = "offer", tier, name?, price? }  开出部件：环灯 = 稀有度色（银 / 蓝 / 金），悬浮部件 + 价格卡；
	                                        基础件卡片写「背包不限量 · 不出售」；精英加金色光柱 + 点光源
	  { mode = "sold" }                    已售出：环灯熄灭、SOLD 卡
	  opts.homeColor（燃料舱家园色带）、opts.lite（邻居简化版：不挂卡片、光柱、点光源）
	悬浮部件带 SpinFX 标签（客户端自转）。
]]

local B = require(script.Parent.BuildLib)
local hex = B.hex
local C = B.C
local V = Vector3.new
local NEON = Enum.Material.Neon
local CS = game:GetService("CollectionService")

local P = {}
P.SLOTS = { "nose", "tank", "engine", "fins" }
P.SLOT_NAMES = { nose = "鼻锥", tank = "燃料舱", engine = "发动机", fins = "尾翼" }
P.NAMES = {
	nose = { "基础鼻锥", "气动鼻锥", "黄金鼻锥" },
	tank = { "基础燃料舱", "大燃料舱", "巨型燃料舱" },
	engine = { "基础发动机", "涡轮发动机", "等离子发动机" },
	fins = { "基础尾翼", "后掠尾翼", "栅格尾翼" },
}
P.PRICES = { nose = { 0, 40, 150 }, tank = { 0, 50, 180 }, engine = { 0, 60, 220 }, fins = { 0, 30, 100 } }
P.RING = {
	idle = { Color = hex("4A5578"), Material = Enum.Material.SmoothPlastic, Transparency = 0 },
	rolling = { Color = C.cyan, Material = NEON, Transparency = 0.2 },
	sold = { Color = hex("2A2E44"), Material = Enum.Material.SmoothPlastic, Transparency = 0 },
}
P.FLOAT_Y = 2.6 -- 悬浮区底部（离地）
P.FLOAT_H = 3.2 -- 悬浮区高度上限

------------------------------------------------------------------ 价格卡（BillboardGui）
local RAR = {
	{ label = "BASIC · 基础", top = hex("8E9AB0"), bot = hex("3B4258"), stroke = hex("D7DEEA"), rc = hex("E6ECF5") },
	{ label = "ADVANCED · 高级", top = hex("2F8CFF"), bot = hex("102C6E"), stroke = hex("6DB5FF"), rc = hex("9ED0FF") },
	{ label = "ELITE · 精英", top = hex("FFC53D"), bot = hex("3A2508"), stroke = hex("FFE08A"), rc = hex("FFE7A3") },
}
P.RARITY = RAR -- 组装舱部件坞铭牌（AssemblyBay）用同一套稀有度配色

local function label(parent, text, y, h, color, font, strokeT)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Position = UDim2.fromScale(0.04, y)
	t.Size = UDim2.fromScale(0.92, h)
	t.Text = text
	t.Font = font or Enum.Font.FredokaOne
	t.TextColor3 = color
	t.TextScaled = true
	t.ZIndex = 3
	t.Parent = parent
	if strokeT then
		local s = Instance.new("UIStroke")
		s.Color = hex("101326")
		s.Thickness = strokeT
		s.Parent = t
	end
	return t
end

local function darkCard(bb, text, stroke, color)
	bb.Size = UDim2.fromScale(4.4, 1.9)
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = hex("16182E")
	f.Parent = bb
	Instance.new("UICorner", f).CornerRadius = UDim.new(0.25, 0)
	local s = Instance.new("UIStroke", f)
	s.Color = stroke
	s.Thickness = 3
	label(f, text, 0.12, 0.76, color)
end

function P.card(att, st)
	local bb = Instance.new("BillboardGui")
	bb.Name = "PriceCard"
	bb.LightInfluence = 0
	bb.MaxDistance = 90
	bb.Parent = att
	if st.mode == "sold" then
		darkCard(bb, "SOLD", hex("4E5380"), hex("A9B0FF"))
		return bb
	elseif st.mode == "rolling" then
		darkCard(bb, "? ? ?", C.cyan, hex("BFF6FF"))
		return bb
	end
	bb.Size = UDim2.fromScale(6.4, 3.3)
	local r = RAR[st.tier]
	if st.tier == 3 then -- 精英外发光
		local g = Instance.new("Frame")
		g.AnchorPoint = Vector2.new(0.5, 0.5)
		g.Position = UDim2.fromScale(0.5, 0.43)
		g.Size = UDim2.fromScale(1.0, 0.86)
		g.BackgroundColor3 = r.top
		g.BackgroundTransparency = 0.5
		g.ZIndex = 1
		g.Parent = bb
		Instance.new("UICorner", g).CornerRadius = UDim.new(0.22, 0)
		local gs = Instance.new("UIStroke", g)
		gs.Color = r.top
		gs.Thickness = 10
		gs.Transparency = 0.45
	end
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 0.86)
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.ZIndex = 2
	f.Parent = bb
	Instance.new("UICorner", f).CornerRadius = UDim.new(0.2, 0)
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new(r.top, r.bot)
	grad.Parent = f
	local stroke = Instance.new("UIStroke", f)
	stroke.Color = r.stroke
	stroke.Thickness = (st.tier == 3) and 4 or 3
	local ptr = Instance.new("Frame") -- 指示小三角
	ptr.AnchorPoint = Vector2.new(0.5, 0.5)
	ptr.Position = UDim2.fromScale(0.5, 0.86)
	ptr.Size = UDim2.fromScale(0.09, 0.17)
	ptr.Rotation = 45
	ptr.BackgroundColor3 = r.bot
	ptr.BorderSizePixel = 0
	ptr.ZIndex = 1
	ptr.Parent = bb
	Instance.new("UIAspectRatioConstraint", ptr).AspectRatio = 1

	label(f, r.label, 0.05, 0.24, r.rc, Enum.Font.FredokaOne, 1.5)
	label(f, st.name, 0.29, 0.36, Color3.new(1, 1, 1), Enum.Font.FredokaOne, 2)
	if st.tier == 1 then
		label(f, "背包不限量 · 不出售", 0.68, 0.22, hex("E6ECF5"), Enum.Font.GothamBold)
	else
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Position = UDim2.fromScale(0.04, 0.66)
		row.Size = UDim2.fromScale(0.92, 0.28)
		row.ZIndex = 3
		row.Parent = f
		local list = Instance.new("UIListLayout")
		list.FillDirection = Enum.FillDirection.Horizontal
		list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		list.VerticalAlignment = Enum.VerticalAlignment.Center
		list.Padding = UDim.new(0.03, 0)
		list.Parent = row
		local coin = Instance.new("Frame")
		coin.Size = UDim2.fromScale(0.13, 0.82)
		coin.BackgroundColor3 = hex("FFC53D")
		coin.ZIndex = 4
		coin.Parent = row
		Instance.new("UIAspectRatioConstraint", coin).AspectRatio = 1
		Instance.new("UICorner", coin).CornerRadius = UDim.new(1, 0)
		local cs = Instance.new("UIStroke", coin)
		cs.Color = hex("A26A00")
		cs.Thickness = 2
		local price = Instance.new("TextLabel")
		price.BackgroundTransparency = 1
		price.Size = UDim2.fromScale(0.36, 1)
		price.Text = tostring(st.price)
		price.Font = Enum.Font.FredokaOne
		price.TextColor3 = hex("FFD84A")
		price.TextScaled = true
		price.ZIndex = 4
		price.Parent = row
		local ps = Instance.new("UIStroke", price)
		ps.Color = hex("101326")
		ps.Thickness = 2
	end
	return bb
end

------------------------------------------------------------------ 悬浮部件
-- 部件正面（舷窗）朝出生点一侧：FACE = 台心转 180°
function P.display(slot, tier, PC, homeColor, parent)
	local FACE = PC * CFrame.Angles(0, math.pi, 0)
	local d
	if slot == "nose" then
		d = B.nose(tier, FACE, parent)
	elseif slot == "tank" then
		d = B.tank(tier, FACE, homeColor or hex("3BD85C"), parent)
	elseif slot == "engine" then
		d = B.engine(tier, FACE, parent)
	else
		d = B.model("FinsDisplay", parent)
		B.cylAt(4, 0, 4, FACE * CFrame.new(0, -1.5, 0), { Name = "Core", Color = C.graphite2 }, d)
		B.fins(tier, FACE, d)
	end
	local scale = ({ nose = 0.75, tank = 0.8, engine = 0.8, fins = 0.6 })[slot]
	local _, size0 = d:GetBoundingBox()
	scale = math.min(scale, P.FLOAT_H / size0.Y)
	d:ScaleTo(scale)
	local bcf, bsize = d:GetBoundingBox()
	local target = PC * CFrame.new(0, P.FLOAT_Y + bsize.Y / 2, 0)
	d:PivotTo(d:GetPivot() + (target.Position - bcf.Position))
	B.decoAll(d)
	-- 自转轴心 = 台心竖线；去掉部件内部的旋转标签，避免嵌套自转
	for _, x in ipairs(d:GetDescendants()) do
		if x:IsA("Model") then CS:RemoveTag(x, "SpinFX") end
	end
	d.WorldPivot = CFrame.new(target.Position) * (PC - PC.Position)
	d:SetAttribute("SpinSpeed", 0.9)
	CS:AddTag(d, "SpinFX")
	d.Name = "Display"
	return d
end

------------------------------------------------------------------ 台体（06_home_roll 和 P0 验收台共用）
-- PC = 台底中心：原石墨底座（黄虚线环）→ 白色圆筒 → 状态环灯 → 顶板（嵌全息盘），总高约 2.15；名牌朝 −Z
function P.buildPad(PC, slot, parent, name)
	local pm = B.model(name or "PartPad")
	pm:SetAttribute("Slot", slot)
	B.cylAt(6.2, 0, 0.75, PC, { Name = "Base", Color = C.graphite }, pm)
	-- 11-25 用户要求：台座底部的黄色虚线去掉
	B.cylAt(5.0, 0.75, 1.0, PC, { Name = "Column", Color = C.white }, pm)
	B.cylAt(5.2, 1.75, 0.18, PC, { Name = "RingLight", Color = P.RING.idle.Color }, pm)
	local cap = B.cylAt(5.0, 1.93, 0.17, PC, { Name = "Cap", Color = C.graphite }, pm)
	B.cylAt(3.0, 2.10, 0.05, PC, { Name = "HoloDisc", Color = C.teal, Material = NEON, Transparency = 0.6 }, pm)
	local plate = B.box(V(2.4, 0.45, 0.12), PC * CFrame.new(0, 0.4, -3.13), { Name = "SlotPlate", Color = C.graphite3 }, pm)
	B.surfaceText(plate, Enum.NormalId.Front, { { text = P.SLOT_NAMES[slot], color = hex("E6ECF5") } }, { pps = 50 })
	for _, x in ipairs(pm:GetDescendants()) do
		if x:IsA("BasePart") and (x.Name == "Dash" or x.Name == "HoloDisc" or x.Name == "SlotPlate") then B.deco(x) end
	end
	local att = Instance.new("Attachment")
	att.Name = "CardAnchor"
	att.Parent = cap
	pm.WorldPivot = PC
	pm.Parent = parent
	return pm
end

------------------------------------------------------------------ 状态切换
local function clear(pad)
	local d = pad:FindFirstChild("Display")
	if d then d:Destroy() end
	local cap = pad:FindFirstChild("Cap")
	if cap then
		for _, x in ipairs(cap:GetChildren()) do
			if x:IsA("Beam") or (x:IsA("Attachment") and x.Name ~= "CardAnchor") then x:Destroy() end
		end
		local att = cap:FindFirstChild("CardAnchor")
		if att then
			for _, g in ipairs(att:GetChildren()) do g:Destroy() end
		end
	end
	local ring = pad:FindFirstChild("RingLight")
	if ring then
		for _, x in ipairs(ring:GetChildren()) do
			if x:IsA("Light") then x:Destroy() end
		end
		CS:RemoveTag(ring, "PulseFX")
	end
end

local function elitePillar(cap, ring, PC)
	local a0 = Instance.new("Attachment")
	a0.Name = "PillarBottom"
	a0.Parent = cap
	a0.Position = cap.CFrame:PointToObjectSpace((PC * CFrame.new(0, 2.15, 0)).Position)
	local a1 = Instance.new("Attachment")
	a1.Name = "PillarTop"
	a1.Parent = cap
	a1.Position = cap.CFrame:PointToObjectSpace((PC * CFrame.new(0, 48, 0)).Position)
	local bm = Instance.new("Beam")
	bm.Name = "ElitePillar"
	bm.Attachment0, bm.Attachment1 = a0, a1
	bm.FaceCamera = true
	bm.Width0, bm.Width1 = 4.6, 3.6
	bm.Color = ColorSequence.new(C.elite)
	bm.LightEmission = 0.5
	bm.LightInfluence = 0
	bm.Brightness = 1
	bm.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.5, 0.8), NumberSequenceKeypoint.new(1, 1) })
	bm.Parent = cap
	local pl = Instance.new("PointLight")
	pl.Color = C.elite
	pl.Range = 10
	pl.Brightness = 0.8
	pl.Parent = ring
end

function P.setState(pad, st, opts)
	opts = opts or {}
	local slot = pad:GetAttribute("Slot")
	local PC = pad:GetPivot()
	local ring, cap, disc = pad:FindFirstChild("RingLight"), pad:FindFirstChild("Cap"), pad:FindFirstChild("HoloDisc")
	clear(pad)
	local mode = st.mode
	if mode == "offer" then
		st = table.clone(st)
		st.name = st.name or P.NAMES[slot][st.tier]
		st.price = st.price or P.PRICES[slot][st.tier]
	end

	-- 环灯
	if mode == "offer" then
		ring.Color = B.TIER_COLOR[st.tier]
		ring.Material = NEON
		ring.Transparency = 0.25
	else
		local r = P.RING[mode] or P.RING.idle
		ring.Color, ring.Material, ring.Transparency = r.Color, r.Material, r.Transparency
	end
	if mode == "rolling" then
		ring:SetAttribute("PulseBase", 0.05)
		ring:SetAttribute("PulseAmp", 0.6)
		ring:SetAttribute("PulseSpeed", 14)
		CS:AddTag(ring, "PulseFX")
	end
	-- 全息盘
	disc.Transparency = (mode == "offer" or mode == "rolling") and 0.35 or (mode == "idle" and 0.6 or 0.85)

	-- 悬浮部件
	if mode == "offer" then
		P.display(slot, st.tier, PC, opts.homeColor, pad)
	end

	-- 价格卡 / 光柱（简化版不挂）
	if not opts.lite and mode ~= "idle" then
		local att = cap:FindFirstChild("CardAnchor")
		if not att then
			att = Instance.new("Attachment")
			att.Name = "CardAnchor"
			att.Parent = cap
		end
		local big = (mode == "offer")
		att.Position = cap.CFrame:PointToObjectSpace((PC * CFrame.new(0, big and 8.35 or 7.65, 0)).Position)
		P.card(att, st)
		if mode == "offer" and st.tier == 3 then elitePillar(cap, ring, PC) end
	end
	pad:SetAttribute("State", mode == "offer" and ("Tier" .. st.tier) or (mode:sub(1, 1):upper() .. mode:sub(2)))
end

return P
