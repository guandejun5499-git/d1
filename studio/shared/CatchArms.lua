--[[
	CatchArms · 回收支架 L1–L4 + 张开 / 合拢两态（ReplicatedStorage.OrbitShared.CatchArms）
	A3：L1 灰 6.5 / L2 蓝 8 / L3 橙 10 / L4 金 12 带光点；升级后外形变长、变色。
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

local function armL3(H, yt, col, m) -- 重型：XY 面桁架 + 粗臂 + 警示条 + 双夹爪
	for _, x in ipairs({ -0.55, 0.55 }) do
		B.box(V(0.45, yt, 0.6), H * CFrame.new(x, yt / 2, 0), { Name = "Rail", Color = col }, m)
	end
	local n = 5
	for k = 0, n - 1 do
		local y0, y1 = yt * k / n + 0.2, yt * (k + 1) / n - 0.2
		local xa = (k % 2 == 0) and -0.55 or 0.55
		B.beamBetween((H * CFrame.new(xa, y0, 0)).Position, (H * CFrame.new(-xa, y1, 0)).Position, 0.2, 0.3, { Name = "Brace", Color = C.graphite }, m)
	end
	B.box(V(1.8, 0.4, 1.0), H * CFrame.new(0, yt - 0.2, 0), { Name = "Cap", Color = C.graphite }, m)
	B.box(V(3.7, 1.2, 1.2), H * CFrame.new(-1.45, yt - 0.9, 0), { Name = "Arm", Color = col }, m)
	B.box(V(3.7, 0.25, 1.25), H * CFrame.new(-1.45, yt - 1.55, 0), { Name = "ArmBelly", Color = C.graphite }, m)
	for i = 0, 3 do
		for _, z in ipairs({ -0.63, 0.63 }) do
			B.box(V(0.3, 0.95, 0.05), H * CFrame.new(-0.2 - i * 0.75, yt - 0.9, z) * CFrame.Angles(0, 0, math.rad(35)), { Name = "Hazard", Color = C.yellow }, m)
		end
	end
	B.box(V(0.6, 3.0, 2.0), H * CFrame.new(-3.3, yt - 1.9, 0), { Name = "Clamp", Color = C.graphite }, m)
	for _, z in ipairs({ -0.6, 0.6 }) do
		B.box(V(0.14, 2.6, 0.55), H * CFrame.new(-3.66, yt - 1.95, z), { Name = "ClampPad", Color = col }, m)
	end
	-- 外侧大油缸（套筒 + 活塞杆）
	local p0 = (H * CFrame.new(1.25, 0.5, 0)).Position
	local p1 = (H * CFrame.new(0.65, yt * 0.62, 0)).Position
	local mid = p0:Lerp(p1, 0.55)
	B.beamBetween(p0, mid, 0.55, 0.55, { Name = "Sleeve", Color = C.graphite2 }, m)
	B.beamBetween(mid, p1, 0.3, 0.3, { Name = "Rod", Color = C.metal, Material = Enum.Material.Metal }, m)
end

local function armL4(H, yt, col, m) -- 星辉：白色流线立柱 + 金环 + 光点 + 发光夹爪 + 顶部光球
	B.box(V(1.0, yt, 1.0), H * CFrame.new(0, yt / 2, 0), { Name = "Post", Color = C.white }, m)
	for _, y in ipairs({ 2.6, 5.6, 8.6 }) do
		B.box(V(1.16, 0.28, 1.16), H * CFrame.new(0, y, 0), { Name = "Band", Color = col }, m)
	end
	for i = 0, 5 do -- 光点：前后两面各一列
		for _, z in ipairs({ -0.52, 0.52 }) do
			local d = B.ball(0.26, H * CFrame.new(0, 1.2 + i * 1.5 + 0.75, z), { Name = "LightDot", Color = hex("FFF1B8"), Material = NEON, CastShadow = false }, m)
			B.deco(d)
		end
	end
	B.wedge(V(0.3, 3.2, 1.3), H * CFrame.new(0.66, yt - 2.4, 0) * CFrame.Angles(0, math.pi / 2, 0), { Name = "Fin", Color = col }, m)
	B.box(V(3.4, 0.9, 1.0), H * CFrame.new(-1.5, yt - 0.6, 0), { Name = "Arm", Color = col }, m)
	B.box(V(3.4, 0.14, 1.04), H * CFrame.new(-1.5, yt - 0.1, 0), { Name = "ArmTrim", Color = C.white }, m)
	B.box(V(0.5, 2.6, 1.8), H * CFrame.new(-3.0, yt - 1.6, 0), { Name = "Clamp", Color = C.white }, m)
	for _, z in ipairs({ -0.84, 0.84 }) do
		local s = B.box(V(0.1, 2.4, 0.14), H * CFrame.new(-3.27, yt - 1.6, z), { Name = "ClampGlow", Color = hex("FFE08A"), Material = NEON, Transparency = 0.15, CastShadow = false }, m)
		B.deco(s)
	end
	B.fx.orb(H * CFrame.new(0, yt + 0.55, 0), 0.7, hex("FFE08A"), m)
end

local ARM = { armL1, armL2, armL3, armL4 }

local function footBase(F, lvl, level, m) -- 静止地脚（F = 地脚底面中心，台面上）
	local fh = lvl.foot
	if level == 1 then
		B.box(V(1.8, fh, 1.8), F * CFrame.new(0, fh / 2, 0), { Name = "Foot", Color = C.graphite }, m)
	elseif level == 2 then
		B.box(V(2.0, fh, 2.0), F * CFrame.new(0, fh / 2, 0), { Name = "Foot", Color = C.graphite }, m)
		B.box(V(2.1, 0.12, 2.1), F * CFrame.new(0, fh - 0.06, 0), { Name = "FootTrim", Color = lvl.color }, m)
	elseif level == 3 then
		B.box(V(2.4, fh, 2.4), F * CFrame.new(0, fh / 2, 0), { Name = "Foot", Color = C.graphite }, m)
		for _, x in ipairs({ -0.9, 0.9 }) do
			for _, z in ipairs({ -0.9, 0.9 }) do
				B.cylAt(0.3, fh, 0.12, F * CFrame.new(x, 0, z), { Name = "Bolt", Color = C.metal }, m)
			end
		end
	else
		B.box(V(2.2, fh, 2.2), F * CFrame.new(0, fh / 2, 0), { Name = "Foot", Color = C.white }, m)
		B.box(V(2.3, 0.15, 2.3), F * CFrame.new(0, fh - 0.08, 0), { Name = "FootTrim", Color = lvl.color }, m)
	end
	-- 铰链座 + 销轴（沿 Z）
	B.part({ Name = "HingePin", Shape = Enum.PartType.Cylinder, Size = V(1.5, 0.5, 0.5), CFrame = F * CFrame.new(0, fh, 0) * CFrame.Angles(0, math.pi / 2, 0), Color = C.metal, Material = Enum.Material.Metal }, m)
end

------------------------------------------------------------------ 建造
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
		if d:IsA("BasePart") and (d.Name == "Hazard" or d.Name == "Bolt" or d.Name == "FootTrim" or d.Name == "ArmTrim" or d.Name == "Band") then B.deco(d) end
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
