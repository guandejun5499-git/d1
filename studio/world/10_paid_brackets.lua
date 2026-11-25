--[[
	Orbit Roll · 付费回收支架验收台（临时，验收后整块删除）
	11-25 按用户给的 4 张原画做的商业化付费支架（OrbitShared.BracketSkins），每套带自己的支架底座。
	放在 P0 验收台右侧（x 157.5–275.5，z 174.6–224.6），步道接 P0 验收台。
	从家园一侧看，从左到右：中级 / 进阶 / 高阶 / 旗舰；全部合拢夹住一枚火箭（和原画主视图一致）。
	价格、是否带数值加成待商业化设计决定，牌子上写「价格待定」。
]]

local SH = game.ReplicatedStorage.OrbitShared:Clone()
SH.Parent = game.ServerStorage
local B = require(SH.BuildLib)
local BS = require(SH.BracketSkins)
local RK = require(SH.RocketKit)
local C = B.C
local V = Vector3.new
local hex = B.hex

local root = workspace.OrbitWorld
local old = root:FindFirstChild("_PaidBrackets")
if old then old:Destroy() end
local m = B.model("_PaidBrackets")

local X0, Z0, W, D = 216.5, 199.6, 118, 50
-- 从家园一侧看 +X 在左手边：x 从大到小排，读起来从左到右是 中级 → 旗舰（v2 底座 Ø24–30，按各自半径留间距）
local XS = { mid = 261, adv = 234, hi = 205, flag = 174 }

local function label(text, pos, sub)
	local a = B.part({ Name = "LabelAnchor", Size = V(0.2, 0.2, 0.2), CFrame = CFrame.new(pos), Transparency = 1 }, m)
	B.deco(a)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(16, 2.8)
	bb.LightInfluence = 0
	bb.MaxDistance = 120
	bb.Parent = a
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = hex("16182E")
	f.BackgroundTransparency = 0.2
	f.Parent = bb
	Instance.new("UICorner", f).CornerRadius = UDim.new(0.3, 0)
	local st = Instance.new("UIStroke", f)
	st.Color = hex("FFC53D")
	st.Thickness = 2
	for i, ln in ipairs({ { text, 0.08, 0.52, Color3.new(1, 1, 1) }, { sub, 0.62, 0.3, hex("FFE08A") } }) do
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Position = UDim2.fromScale(0.03, ln[2])
		t.Size = UDim2.fromScale(0.94, ln[3])
		t.Font = Enum.Font.GothamBold
		t.Text = ln[1]
		t.TextColor3 = ln[4]
		t.TextScaled = true
		t.Parent = f
	end
end

------------------------------------------------------------------ 甲板 + 步道
B.box(V(W, 1.2, D), CFrame.new(X0, -0.6, Z0), { Name = "Deck", Color = C.graphite2 }, m)
B.box(V(W - 2, 3, D - 2), CFrame.new(X0, -2.7, Z0), { Name = "Skirt", Color = C.graphite }, m)
B.box(V(W + 0.4, 0.3, 0.3), CFrame.new(X0, -0.25, Z0 - D / 2), { Name = "Edge", Color = C.yellow }, m)
B.box(V(4, 1.2, 10), CFrame.new(156, -0.6, 197.6), { Name = "Walkway", Color = C.graphite2 }, m)
for _, z in ipairs({ 192.75, 202.45 }) do
	B.box(V(4, 1.0, 0.3), CFrame.new(156, 0.5, z), { Name = "Rail", Color = C.yellow }, m)
end
label("付费回收支架 · 商业化外观", V(X0, 24, Z0 - D / 2 + 1), "按原画制作 · 每套含支架底座 · 验收后整块删除")

------------------------------------------------------------------ 四套支架
local EQ = {
	mid = { nose = 2, tank = 1, engine = 2, fins = 2 },
	adv = { nose = 2, tank = 2, engine = 2, fins = 2 },
	hi = { nose = 2, tank = 2, engine = 3, fins = 2 },
	flag = { nose = 3, tank = 2, engine = 3, fins = 2 },
}
for i, id in ipairs(BS.ORDER) do
	local x = XS[id]
	local P = CFrame.new(x, 0, Z0 + 2)
	local br = BS.build(P, id, m, { guide = true, thrusters = 1 }) -- 引导光柱打开；第 3、4 套的姿态推进器在验收台上全开（模块默认待机 0.4）
	RK.build(EQ[id], B.homeColor(0), BS.deckCF(br), m)
	local sk = BS.SKINS[id]
	label(sk.name, V(x, 27, Z0 + 2), sk.tag .. " · 价格待定")
end

m.Parent = root
SH:Destroy()

local n = 0
for _, d in ipairs(m:GetDescendants()) do
	if d:IsA("BasePart") then n += 1 end
end
return "paid brackets ok · parts " .. n
