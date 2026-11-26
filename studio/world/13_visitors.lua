--[[
	Orbit Roll · P1 第 19 项 围观访客 ×3（Home_K.Visitors，K = 0–5 每家一组）
	Web Demo 同款三人，站在发射台（家园本地 (0, −26)）周围、面朝发射台：
	  Visitor_Leo  (−3, −38)  肤 C68A5A · 蓝衣 3EA0FF · 黑裤 1B1D2B · 黄帽 FFCC33（塔架右前方）
	  Visitor_Mia  (12, −32)  肤 F1C9A5 · 绿衣 3BD85C · 蓝裤 3A4580 · 粉帽 FF5E7A
	  Visitor_Sam  (−17, −14) 肤 8D5A3B · 紫衣 A46BFF · 藏青裤 2A3156 · 白帽 FFFFFF（出生点一侧）
	（Web 坐标 ×1.3 后按 11-25 发射区外移到 (0, −26) 调过，避开塔架和升级牌。）
	标准 R15 体型（和玩家角色一样大，高约 5.5），HumanoidDescription 生成后把 AnimationConstraint 关节换成 Motor6D；
	只有 HumanoidRootPart 锚定，其余部件靠 Motor6D 挂着：客户端 VisitorShow 改根部 CFrame + 关节 Transform 做动作
	（待机摆臂、欢呼、被掀飞 → 躺倒 → 爬起 → 走回原位）。全部不碰撞、不参与射线、不触发。
	帽子是两件 Part（帽顶半球 + 前檐），焊在头上。名字牌用 Humanoid 自带的显示名（60 格内可见）。
	属性：HomeCF（站位 CFrame，脚底）、GroundOffset（根部中心离脚底的高度）、Home（家园号）；标签 Visitor。
	可重复运行：替换各家的 Visitors。
]]

local SH = game.ReplicatedStorage.OrbitShared:Clone()
SH.Parent = game.ServerStorage
local B = require(SH.BuildLib)
local V = Vector3.new
local hex = B.hex
local CS = game:GetService("CollectionService")
local Players = game:GetService("Players")

local TARGETS = { 0, 1, 2, 3, 4, 5 }
local PAD = V(0, 0, -26)
local PEOPLE = {
	{ name = "Visitor_Leo", x = -3, z = -38, skin = "C68A5A", shirt = "3EA0FF", pants = "1B1D2B", hat = "FFCC33" },
	{ name = "Visitor_Mia", x = 12, z = -32, skin = "F1C9A5", shirt = "3BD85C", pants = "3A4580", hat = "FF5E7A" },
	{ name = "Visitor_Sam", x = -17, z = -14, skin = "8D5A3B", shirt = "A46BFF", pants = "2A3156", hat = "FFFFFF" },
}
local SHIRT_PARTS = { UpperTorso = true, LowerTorso = false, LeftUpperArm = true, RightUpperArm = true, LeftLowerArm = true, RightLowerArm = true }
local PANTS_PARTS = { LowerTorso = true, LeftUpperLeg = true, RightUpperLeg = true, LeftLowerLeg = true, RightLowerLeg = true }

local rp = RaycastParams.new()

local function makeVisitor(p, cf)
	local d = Instance.new("HumanoidDescription")
	local skin, shirt, pants = hex(p.skin), hex(p.shirt), hex(p.pants)
	d.HeadColor, d.LeftArmColor, d.RightArmColor = skin, shirt, shirt
	d.TorsoColor, d.LeftLegColor, d.RightLegColor = shirt, pants, pants
	local m = Players:CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R15)
	m.Name = p.name
	local h = m:FindFirstChildOfClass("Humanoid")
	-- 新版生成器的关节是 AnimationConstraint（物理约束，服务器模拟，客户端本地改 Transform 看不到）+ 布娃娃球窝；
	-- 换回刚性 Motor6D（同名、C0 / C1 取两头的 RigAttachment），整个人和锚定的根部成一个装配体，客户端改 Transform 立刻生效
	for _, ac in ipairs(m:GetDescendants()) do
		if ac:IsA("AnimationConstraint") then
			local a0, a1 = ac.Attachment0, ac.Attachment1
			local j = Instance.new("Motor6D")
			j.Name = ac.Name
			j.Part0, j.Part1 = a0.Parent, a1.Parent
			j.C0, j.C1 = a0.CFrame, a1.CFrame
			j.Parent = a1.Parent
		end
	end
	for _, c in ipairs(m:GetDescendants()) do
		if c:IsA("AnimationConstraint") or c:IsA("BallSocketConstraint") or c:IsA("NoCollisionConstraint") then c:Destroy() end
	end
	-- 去掉脚本、BodyColors 和 Animator（Animator 会把关节 Transform 每帧清掉，VisitorShow 自己写 Transform）
	for _, s in ipairs(m:GetDescendants()) do
		if s:IsA("LuaSourceContainer") or s:IsA("BodyColors") or s:IsA("Animator") then s:Destroy() end
	end
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- 整个人一起流式加载，关节两头不会只到一半
	-- 逐件上色：手 = 肤色，腰 / 腿 = 裤色，脚 = 深色鞋
	for _, bp in ipairs(m:GetChildren()) do
		if bp:IsA("BasePart") then
			if bp.Name == "Head" or bp.Name:find("Hand") then bp.Color = skin
			elseif bp.Name:find("Foot") then bp.Color = hex("23263A")
			elseif PANTS_PARTS[bp.Name] then bp.Color = pants
			elseif SHIRT_PARTS[bp.Name] then bp.Color = shirt end
			bp.Material = Enum.Material.SmoothPlastic
			bp.Anchored = bp.Name == "HumanoidRootPart"
			bp.CanCollide, bp.CanQuery, bp.CanTouch = false, false, false
		end
	end
	local hrp = m.HumanoidRootPart
	hrp.Transparency = 1
	h.DisplayName = p.name
	h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	h.NameDisplayDistance = 60
	h.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	h.EvaluateStateMachine = false
	h.RequiresNeck = false
	h.BreakJointsOnDeath = false

	-- 先摆到原点量尺寸：脚底高度、头顶
	m:PivotTo(CFrame.new())
	local lowest = math.huge
	for _, bp in ipairs(m:GetChildren()) do
		if bp:IsA("BasePart") and bp ~= hrp then lowest = math.min(lowest, bp.Position.Y - bp.Size.Y / 2) end
	end
	local off = hrp.Position.Y - lowest

	-- 帽子：帽顶球（下半埋在头里）+ 深色帽箍 + 前檐（本地 −Z 是正面）
	local head = m.Head
	local top = head.CFrame * CFrame.new(0, head.Size.Y * 0.28, 0)
	local hatC = hex(p.hat)
	local crown = B.part({ Name = "HatCrown", Shape = Enum.PartType.Ball, Size = V(1, 1, 1) * head.Size.X * 1.06, CFrame = top, Color = hatC, Anchored = false }, m)
	local brim = B.part({ Name = "HatBrim", Size = V(head.Size.X * 0.9, 0.12, 0.75), CFrame = top * CFrame.new(0, -0.02, -head.Size.Z * 0.5 - 0.2), Color = hatC, Anchored = false }, m)
	local band = B.part({ Name = "HatBand", Shape = Enum.PartType.Cylinder, Size = V(0.14, head.Size.X * 1.08, head.Size.X * 1.08), CFrame = top * CFrame.new(0, -0.02, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = hex("1F2236"), Anchored = false }, m)
	for _, hp in ipairs({ crown, brim, band }) do
		hp.CanCollide, hp.CanQuery, hp.CanTouch, hp.Massless = false, false, false, true
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = head, hp
		w.Parent = hp
	end

	m.PrimaryPart = hrp
	m:PivotTo(cf * CFrame.new(0, off, 0))
	m:SetAttribute("HomeCF", cf)
	m:SetAttribute("GroundOffset", off)
	CS:AddTag(m, "Visitor")
	return m, off
end

local report = {}
for _, k in ipairs(TARGETS) do
	local HOME = B.homeFrame(k)
	local f = B.homeFolder(k)
	local old = f:FindFirstChild("Visitors")
	if old then old:Destroy() end
	local g = B.model("Visitors")
	local padW = HOME * PAD
	for _, p in ipairs(PEOPLE) do
		local pos = HOME * V(p.x, 0, p.z)
		local hit = workspace:Raycast(pos + V(0, 40, 0), V(0, -80, 0), rp)
		local y = hit and hit.Position.Y or 0
		pos = V(pos.X, y, pos.Z)
		local cf = CFrame.lookAt(pos, V(padW.X, y, padW.Z))
		local m, off = makeVisitor(p, cf)
		m:SetAttribute("Home", k)
		m.Parent = g
		table.insert(report, string.format("%d %s y%.2f off%.2f", k, p.name, y, off))
	end
	g.Parent = f
end
SH:Destroy()
return table.concat(report, " | ")
