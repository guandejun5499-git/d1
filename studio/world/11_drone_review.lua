--[[
	Orbit Roll · 维修无人机验收台（临时，验收后整块删除）
	第 17 项的维修无人机（OrbitShared.CrashShow.buildDrone）平时只在坠毁时临时生成，这里放静态的给用户验收模型。
	放在付费支架验收台南边（甲板 x 194–234，z 236–254），步道接付费支架验收台。
	  左：放大 2.5 倍、缓慢自转，看细节（旋翼、焊接臂、机腹眼睛）
	  右：原尺寸，悬停在一枚一档火箭上方，打开青色修复光锥，看和火箭 / 发射台的比例
	原画 E1 还没画；模型按组装舱龙门吊的造型语言设计（深蓝机身 + 白色顶壳 + 橙色饰条）。
]]

local SH = game.ReplicatedStorage.OrbitShared:Clone()
SH.Parent = game.ServerStorage
local B = require(SH.BuildLib)
local RK = require(SH.RocketKit)
local XS = require(SH.CrashShow)
local C = B.C
local V = Vector3.new
local hex = B.hex
local CS = game:GetService("CollectionService")

local root = workspace.OrbitWorld
local old = root:FindFirstChild("_DroneReview")
if old then old:Destroy() end
local m = B.model("_DroneReview")

local X0, Z0, W, D = 214, 245, 40, 18
local CYAN = hex("6FD4FF")

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
	st.Color = CYAN
	st.Thickness = 2
	for _, ln in ipairs({ { text, 0.08, 0.52, Color3.new(1, 1, 1) }, { sub, 0.62, 0.3, hex("BFF6FF") } }) do
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

------------------------------------------------------------------ 甲板 + 步道（接付费支架验收台南边 z 224.6）
B.box(V(W, 1.2, D), CFrame.new(X0, -0.6, Z0), { Name = "Deck", Color = C.graphite2 }, m)
B.box(V(W - 2, 3, D - 2), CFrame.new(X0, -2.7, Z0), { Name = "Skirt", Color = C.graphite }, m)
B.box(V(W + 0.4, 0.3, 0.3), CFrame.new(X0, -0.25, Z0 - D / 2), { Name = "Edge", Color = CYAN }, m)
B.box(V(4, 1.2, 11.4), CFrame.new(X0, -0.6, 230.3), { Name = "Walkway", Color = C.graphite2 }, m)
for _, x in ipairs({ X0 - 1.85, X0 + 1.85 }) do
	B.box(V(0.3, 1.0, 11.4), CFrame.new(x, 0.5, 230.3), { Name = "Rail", Color = C.yellow }, m)
end
label("维修无人机 · 第 17 项", V(X0, 22, Z0 - D / 2 + 1), "原画 E1 待补 · 左：放大 2.5 倍 · 右：原尺寸工作状态 · 验收后整块删除")

------------------------------------------------------------------ 左：放大 2.5 倍，缓慢自转
local BIG = CFrame.new(X0 + 10, 0, Z0)
B.cylAt(9, 0, 0.8, BIG, { Name = "Pedestal", Color = C.graphite }, m)
B.cylAt(9.4, 0.8, 0.12, BIG, { Name = "PedestalRing", Color = CYAN, Material = Enum.Material.Neon, Transparency = 0.2 }, m)
local big = XS.buildDrone(CFrame.new(X0 + 10, 9, Z0), m)
big.Name = "Drone_x2.5"
big:ScaleTo(2.5)
big:PivotTo(CFrame.new(X0 + 10, 9, Z0))
big:SetAttribute("SpinSpeed", 0.35)
CS:AddTag(big, "SpinFX")
label("放大 2.5 倍", V(X0 + 10, 16, Z0), "深蓝机身 · 白顶壳 · 橙饰条 · 四旋翼 · 机腹青眼 + 焊接臂")

------------------------------------------------------------------ 右：原尺寸工作状态（悬停在一档火箭上方 + 修复光锥）
local PAD = CFrame.new(X0 - 10, 0, Z0)
B.cylAt(8, 0, 0.5, PAD, { Name = "MiniPad", Color = C.graphite }, m)
local rocket = RK.build({ nose = 1, tank = 1, engine = 1, fins = 1 }, B.homeColor(0), PAD * CFrame.new(0, 0.5, 0), m)
local h = rocket:GetAttribute("Height") or 10
local at = CFrame.new(X0 - 10, 0.5 + h + 8, Z0) * CFrame.Angles(0, math.rad(-30), 0)
local small = XS.buildDrone(at, m)
small.Name = "Drone_x1"
-- 修复光锥：尖端在机腹眼睛，底面在台面
local an = B.part({ Name = "RepairBeamAnchor", Size = V(0.2, 0.2, 0.2), Transparency = 1 }, m)
B.deco(an)
local top = at.Position - V(0, 0.65, 0)
local base = PAD.Position + V(0, 0.5, 0)
an.CFrame = CFrame.lookAt(base, top)
local cone = Instance.new("ConeHandleAdornment")
cone.Adornee = an
cone.Color3 = CYAN
cone.Radius = 5
cone.Height = (top - base).Magnitude
cone.Transparency = 0.72
cone.ZIndex = 0
cone.Parent = an
label("原尺寸 · 工作状态", V(X0 - 10, 0.5 + h + 13, Z0), "悬停在一档火箭上方 · 青色修复光锥")

m.Parent = root
SH:Destroy()

local n = 0
for _, d in ipairs(m:GetDescendants()) do
	if d:IsA("BasePart") then n += 1 end
end
return "drone review ok · parts " .. n
