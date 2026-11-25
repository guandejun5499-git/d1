--[[
	Orbit Roll · 火箭部件验收台（临时）
	放在玩家家园（Home 0）背后的星空里：平台前沿离家园背面边缘约 5 studs（中心世界 z ≈ 197.6；11-25 场景放大前为 158.4）。
	从家园背面边缘（z ≈ 130）朝 +Z 看：左边 4 行 × 3 档单个部件（前排矮、后排高：鼻锥 → 发动机 → 尾翼 → 燃料舱），
	右边 5 枚整箭组合。每件上方有 BillboardGui 名字标签。验收通过后整块删除（Workspace.OrbitWorld._PartsReview）。
]]

-- 克隆整个 OrbitShared 再 require：模块之间互相 require，克隆能避开编辑器里的模块缓存
local SH = game.ReplicatedStorage.OrbitShared:Clone()
SH.Parent = game.ServerStorage
local B = require(SH.BuildLib)

local C = B.C
local V = Vector3.new
local hex = B.hex
local NEON = Enum.Material.Neon
local HOME_COLOR = hex("3BD85C")

local root = workspace.OrbitWorld
local old = root:FindFirstChild("_PartsReview")
if old then old:Destroy() end
local m = B.model("_PartsReview")

-- 本地坐标：+X = 观察者右手，+Z = 朝向观察者（家园方向）
-- 平台前沿离家园背面边缘约 5 studs：中心 z = 家园背边 + 5 + 23
local HOME_BACK = B.HOME_D + 55 * math.cos(math.pi / 6) -- 122 + 47.63 = 169.63（家园外接半径 55）
local R = CFrame.new(0, 0, HOME_BACK + 5 + 23) * CFrame.Angles(0, math.pi, 0)
local function P(x, y, z) return R * CFrame.new(x, y, z) end

------------------------------------------------------------------ 平台
B.box(V(104, 1.2, 46), P(8, -0.6, 0), { Name = "Deck", Color = hex("DEDBF0") }, m)
B.box(V(102, 3, 44), P(8, -2.7, 0), { Name = "Skirt", Color = hex("4B4F8A") }, m)
B.deco(B.box(V(104.4, 0.3, 0.3), P(8, -0.25, 23.05), { Name = "Edge", Color = C.yellow, Material = NEON, Transparency = 0.3 }, m))
B.deco(B.box(V(0.3, 0.04, 40), P(-6.5, 0.02, 0), { Name = "Divider", Color = hex("B4ADD8") }, m))

local function tag(parent, worldPos, title, sub, color)
	local a = B.deco(B.box(V(0.2, 0.2, 0.2), CFrame.new(worldPos), { Name = "TagAnchor", Transparency = 1 }, parent))
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(sub and 7 or 5.2, sub and 1.9 or 1.0)
	bb.LightInfluence = 0
	bb.MaxDistance = 160
	bb.Parent = a
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = hex("16182E")
	f.BackgroundTransparency = 0.15
	f.Parent = bb
	Instance.new("UICorner", f).CornerRadius = UDim.new(0.3, 0)
	local st = Instance.new("UIStroke", f)
	st.Color = color
	st.Thickness = 2
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(0.94, sub and 0.55 or 0.9)
	t.Position = UDim2.fromScale(0.03, 0.05)
	t.Font = Enum.Font.FredokaOne
	t.Text = title
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextScaled = true
	t.Parent = f
	if sub then
		local s = Instance.new("TextLabel")
		s.BackgroundTransparency = 1
		s.Size = UDim2.fromScale(0.94, 0.34)
		s.Position = UDim2.fromScale(0.03, 0.6)
		s.Font = Enum.Font.GothamBold
		s.Text = sub
		s.TextColor3 = hex("C9D1E0")
		s.TextScaled = true
		s.Parent = f
	end
end

local function pedestal(cf, dia, tierColor, parent)
	B.cylAt(dia, 0, 0.6, cf, { Name = "Pedestal", Color = C.graphite }, parent)
	B.deco(B.cylAt(dia + 0.15, 0.25, 0.12, cf, { Name = "PedestalGlow", Color = tierColor, Material = NEON, Transparency = 0.35 }, parent))
	B.cylAt(dia - 0.8, 0.6, 0.1, cf, { Name = "PedestalTop", Color = C.graphite2 }, parent)
end

------------------------------------------------------------------ 单个部件：4 行 × 3 档
local NAMES = {
	nose = { "基础鼻锥", "气动鼻锥", "黄金鼻锥" },
	engine = { "基础发动机", "涡轮发动机", "等离子发动机" },
	fins = { "基础尾翼", "后掠尾翼", "栅格尾翼" },
	tank = { "基础燃料舱", "大燃料舱", "巨型燃料舱" },
}
local ROWS = { { "nose", 14 }, { "engine", 4 }, { "fins", -6 }, { "tank", -16 } }
local COLS = { -37, -27, -17 }
local parts = B.model("Parts", m)
for _, row in ipairs(ROWS) do
	local slot, z = row[1], row[2]
	for tier = 1, 3 do
		local base = P(COLS[tier], 0, z)
		local g = B.model(slot .. "_" .. tier, parts)
		pedestal(base, 6, B.TIER_COLOR[tier], g)
		local top = base * CFrame.new(0, 0.7, 0)
		if slot == "nose" then
			B.nose(tier, top, g)
		elseif slot == "engine" then
			B.engine(tier, top, g)
		elseif slot == "tank" then
			B.tank(tier, top, HOME_COLOR, g)
		else
			-- 尾翼挂在一段石墨短芯上展示
			local core = top * CFrame.new(0, 2.2, 0)
			B.cylAt(4, -2.2, 4.2, core, { Name = "DisplayCore", Color = C.graphite2 }, g)
			B.fins(tier, core, g)
		end
		-- 标签放在底座前方低处，避免前后排互相遮挡
		tag(g, (base * CFrame.new(0, 0.9, 4.2)).Position, NAMES[slot][tier], nil, B.TIER_COLOR[tier])
	end
end

------------------------------------------------------------------ 整箭组合
local COMBOS = {
	{ { nose = 1, tank = 1, engine = 1, fins = 1 }, "首航 · 全基础", "Δv 285 · 月球 ×1" },
	{ { nose = 2, tank = 2, engine = 2, fins = 2 }, "高级全套", "Δv 645 · 月球 ×4" },
	{ { nose = 3, tank = 3, engine = 3, fins = 2 }, "金币路线", "Δv 887 · 月球 ×5" },
	{ { nose = 2, tank = 3, engine = 3, fins = 2 }, "最优木星组合", "Δv 1107 · 月球 → 木星 ×2" },
	{ { nose = 3, tank = 3, engine = 3, fins = 3 }, "精英全套", "Δv 859 · 月球 ×5" },
}
local rockets = B.model("Rockets", m)
for i, cmb in ipairs(COMBOS) do
	local base = P(2 + (i - 1) * 12, 0, 2) -- 间距 12：精英燃料舱的太阳能翼板单侧伸出约 5.8
	local g = B.model("Combo_" .. i, rockets)
	local best = (i == 4)
	pedestal(base, 8, best and C.elite or C.cyan, g)
	local r = B.rocket(cmb[1], HOME_COLOR, base * CFrame.new(0, 0.7, 0), g)
	tag(g, (base * CFrame.new(0, r:GetAttribute("Height") + 3.6, 0)).Position, cmb[2], cmb[3], best and C.elite or C.cyan)
end

------------------------------------------------------------------ 后排：更高档次预留的太阳能翼板（11-24 用户确定：第三档用电池舱，翼板留给第四档起）
local deco = B.model("DecoVariants", m)
local p1 = P(12, 0, -14)
pedestal(p1, 7, C.cyan, deco)
B.tank(3, p1 * CFrame.new(0, 0.7, 0), HOME_COLOR, deco, "solar")
tag(deco, (p1 * CFrame.new(0, 12, 0)).Position, "更高档次预留 · 太阳能翼板", "第四档起（如锻造融合神话件）", C.cyan)
local p2 = P(34, 0, -14)
pedestal(p2, 8, C.elite, deco)
local rv = B.rocket({ nose = 2, tank = 3, engine = 3, fins = 2, deco = "solar" }, HOME_COLOR, p2 * CFrame.new(0, 0.7, 0), deco)
tag(deco, (p2 * CFrame.new(0, rv:GetAttribute("Height") + 3.6, 0)).Position, "更高档次整箭效果预览", "第三档用能量电池舱", C.elite)

-- 角色比例参照（5 studs 高的方块人）
local ref = B.model("ScaleRef", m)
local rc = P(57, 0, 8)
B.box(V(2, 2, 1), rc * CFrame.new(0, 3, 0), { Name = "Torso", Color = hex("4F7BFF") }, ref)
B.box(V(1.2, 1.2, 1.2), rc * CFrame.new(0, 4.6, 0), { Name = "Head", Color = hex("F5CBA0") }, ref)
B.box(V(0.95, 2, 1), rc * CFrame.new(-0.5, 1, 0), { Name = "Leg", Color = hex("2E3247") }, ref)
B.box(V(0.95, 2, 1), rc * CFrame.new(0.5, 1, 0), { Name = "Leg", Color = hex("2E3247") }, ref)
tag(ref, (rc * CFrame.new(0, 7, 0)).Position, "R15 · 5 studs", nil, C.basic)

tag(m, P(4, 26, -10).Position, "火箭部件验收台（临时）", "左：单个部件 3 档 · 右：整箭组合", C.orange)

B.decoAll(m)

-- 可行走：甲板、裙边、展台底座恢复碰撞（部件本身和标签保持不碰撞）
local WALK = { Deck = true, Skirt = true, Pedestal = true, PedestalTop = true }
for _, d in ipairs(m:GetDescendants()) do
	if d:IsA("BasePart") and WALK[d.Name] then
		d.CanCollide = true
		d.CanQuery = true
	end
end

-- 连接步道：家园背面边缘 → 验收台前沿（相距 5），两端各搭 1.5
local walk = B.model("Walkway", m)
local wz0, wz1 = HOME_BACK - 1.5, HOME_BACK + 5 + 1.5
local wcf = CFrame.new(0, 0, (wz0 + wz1) / 2)
B.box(V(10, 1.2, wz1 - wz0), wcf * CFrame.new(0, -0.65, 0), { Name = "Deck", Color = hex("6F79C2") }, walk)
for _, z in ipairs({ -1.5, 0, 1.5 }) do
	B.deco(B.box(V(8.4, 0.08, 0.5), wcf * CFrame.new(0, -0.01, z), { Name = "Stripe", Color = hex("5D67AF") }, walk))
end
for _, sx in ipairs({ -1, 1 }) do
	B.box(V(0.8, 1.1, 5), wcf * CFrame.new(sx * 4.6, 0.5, 0), { Name = "Rail", Color = C.yellow }, walk)
end

m.Parent = root
SH:Destroy()
return "parts review ok"
