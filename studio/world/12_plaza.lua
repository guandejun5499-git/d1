--[[
	Orbit Roll · P1 第 20 项 广场内容（Workspace.OrbitWorld.PlazaContent）
	中央圆台（02 建，台面 y ≈ 1.45，Ø21）上立火箭雕塑：气动鼻锥 + 巨型燃料舱 + 等离子发动机 + 基础尾翼，放大 1.6 倍
	（Web Demo 同款组合），站在带金色饰环的底座上，四周 6 盏青色地灯，客户端缓慢自转（SpinFX）。
	公共商店位 ×3（P0 定：在 30° / 150° / 270° 两座桥之间的空档）：光柱在半径 51.6，商店往里放在半径 40、
	正面朝广场中心，光柱在店后。造型和家园店位同一套（白色小屋 + 卷帘门 + 黄框），放大一号，
	加条纹遮阳棚、柜台和「即将开放」招牌；三家各一种点缀色。商店内容待商业化设计决定。
	可重复运行。
]]

local SH = game.ReplicatedStorage.OrbitShared:Clone()
SH.Parent = game.ServerStorage
local B = require(SH.BuildLib)
local RK = require(SH.RocketKit)
local C = B.C
local V = Vector3.new
local hex = B.hex
local CS = game:GetService("CollectionService")
local NEON = Enum.Material.Neon

local root = workspace.OrbitWorld
local old = root:FindFirstChild("PlazaContent")
if old then old:Destroy() end
local m = B.model("PlazaContent")

------------------------------------------------------------------ 火箭雕塑
local STAGE_TOP = 1.45
local sc = B.model("Sculpture", m)
local P = CFrame.new(0, STAGE_TOP, 0)
B.cylAt(10, 0, 1.4, P, { Name = "Plinth", Color = C.graphite }, sc)
B.cylAt(10.4, 1.15, 0.25, P, { Name = "PlinthTrim", Color = hex("FFC93C") }, sc)
B.cylAt(8.4, 1.4, 0.3, P, { Name = "PlinthTop", Color = C.graphite2 }, sc)
for i = 0, 5 do
	local a = i / 6 * math.pi * 2 + math.pi / 6
	local lp = P * CFrame.new(math.sin(a) * 6.2, 0, math.cos(a) * 6.2)
	B.cylAt(0.9, 0, 0.35, lp, { Name = "UplightBase", Color = C.graphite3 }, sc)
	local lamp = B.cylAt(0.6, 0.35, 0.12, lp, { Name = "Uplight", Color = C.cyan, Material = NEON }, sc)
	local sl = Instance.new("SpotLight")
	sl.Face = Enum.NormalId.Right -- 圆柱的轴沿本地 X：Right = 朝上
	sl.Color, sl.Range, sl.Brightness, sl.Angle = hex("BFF6FF"), 26, 1.2, 40
	sl.Parent = lamp
end
local rocket = RK.build({ nose = 2, tank = 3, engine = 3, fins = 1 }, hex("FFC93C"), P * CFrame.new(0, 1.7, 0), sc)
rocket.Name = "SculptureRocket"
rocket:ScaleTo(1.6)
rocket:PivotTo(P * CFrame.new(0, 1.7, 0))
rocket.WorldPivot = P * CFrame.new(0, 1.7, 0)
rocket:SetAttribute("SpinSpeed", 0.15)
CS:AddTag(rocket, "SpinFX")
B.decoAll(rocket)

------------------------------------------------------------------ 公共商店位 ×3
local ACCENTS = { hex("FFC93C"), hex("2FD3C8"), hex("FF8AD8") }
local shops = B.model("PlazaShops", m)
for i, deg in ipairs({ 30, 150, 270 }) do
	local a = math.rad(deg)
	local pos = V(math.sin(a), 0, math.cos(a)) * 40
	local S = CFrame.lookAt(pos, V(0, 0, 0)) -- 本地 −Z（正面）朝广场中心
	local s = B.model("PlazaShop_" .. i, shops)
	local acc = ACCENTS[i]
	B.box(V(11, 0.4, 9), S * CFrame.new(0, 0.2, 0), { Name = "Base", Color = C.graphite }, s)
	B.box(V(9, 5.6, 7), S * CFrame.new(0, 3.2, 0.4), { Name = "Body", Color = C.white }, s)
	B.box(V(10, 0.8, 8), S * CFrame.new(0, 6.4, 0.4), { Name = "Roof", Color = C.graphite }, s)
	B.box(V(10.2, 0.25, 8.2), S * CFrame.new(0, 5.9, 0.4), { Name = "RoofTrim", Color = acc }, s)
	-- 卷帘门（黄框）
	B.box(V(5.2, 3.8, 0.2), S * CFrame.new(0, 2.3, -3.15), { Name = "Shutter", Color = C.graphite2 }, s)
	for y = 0.8, 4.0, 0.45 do
		B.box(V(5, 0.08, 0.22), S * CFrame.new(0, y, -3.16), { Name = "ShutterLine", Color = C.graphite }, s)
	end
	B.box(V(0.3, 3.9, 0.3), S * CFrame.new(-2.75, 2.35, -3.15), { Name = "DoorFrame", Color = C.yellow }, s)
	B.box(V(0.3, 3.9, 0.3), S * CFrame.new(2.75, 2.35, -3.15), { Name = "DoorFrame", Color = C.yellow }, s)
	-- 条纹遮阳棚（白 / 点缀色相间，向前下斜）
	for k = 0, 6 do
		local x = -4.29 + k * 1.43
		B.wedge(V(1.43, 1.0, 2.2), S * CFrame.new(x, 5.0, -4.15), { Name = "Awning", Color = (k % 2 == 0) and acc or C.white }, s)
	end
	-- 柜台
	B.box(V(7, 1.2, 1.2), S * CFrame.new(0, 1.0, -4.6), { Name = "Counter", Color = C.white }, s)
	B.box(V(7.2, 0.2, 1.4), S * CFrame.new(0, 1.7, -4.6), { Name = "CounterTop", Color = acc }, s)
	-- 招牌「即将开放」
	local sign = B.box(V(6.4, 1.2, 0.25), S * CFrame.new(0, 6.95, -3.7), { Name = "Sign", Color = C.graphite3 }, s)
	B.surfaceText(sign, Enum.NormalId.Front, {
		{ text = "即将开放", h = 0.62, color = acc },
		{ text = "公共商店", h = 0.3, color = hex("E6ECF5"), font = Enum.Font.GothamBold },
	}, { pps = 50 })
	s:SetAttribute("ShopIndex", i)
	s:SetAttribute("Angle", deg)
end
for _, d in ipairs(shops:GetDescendants()) do
	if d:IsA("BasePart") and (d.Name == "ShutterLine" or d.Name == "Sign" or d.Name == "RoofTrim" or d.Name == "Awning") then B.deco(d) end
end

m.Parent = root
SH:Destroy()
local n = 0
for _, d in ipairs(m:GetDescendants()) do
	if d:IsA("BasePart") then n += 1 end
end
return "plaza ok · parts " .. n
