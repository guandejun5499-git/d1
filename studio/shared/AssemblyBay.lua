--[[
	AssemblyBay · 组装舱运行态（ReplicatedStorage.OrbitShared.AssemblyBay）
	组装舱模型由 05_home_bay 建：WorldPivot = 舱底中心；Docks/Dock_1–4 各有 DockPoint（托盘顶面中心）。
	AB.setStatus(bay, status, filled)：
	  "staging"    青 = 待组装（门楣屏：待组装 n / 4）
	  "ready"      绿 = 四个槽位都放好，可组装 / 组装完成
	  "assembling" 黄橙闪 = 组装中
	AB.setDock(bay, i, tier, homeColor)：部件坞 i（1 鼻锥 / 2 燃料舱 / 3 发动机 / 4 尾翼）放入一件缩小的部件；
	  tier = nil 清空，显示青色虚线空位框。墙上铭牌跟着变（11-25）：空位 = 深色牌写部位名「空位」；
	  放入后 = 和 Roll 台价格卡同一套稀有度配色（基础灰 / 高级蓝 / 精英金渐变），写级别 + 部件名。
	AB.setHolo(bay, eq, homeColor)：转台上的青色全息按当前组合重建（缺的部位用基础件、更淡），客户端自转。
]]

local B = require(script.Parent.BuildLib)
local PP = require(script.Parent.PartPad)
local hex = B.hex
local V = Vector3.new
local CS = game:GetService("CollectionService")

local AB = {}
AB.SLOTS = { "nose", "tank", "engine", "fins" }
AB.STATUS = {
	staging = { color = hex("4FE3F0"), lines = function(n) return { "待组装", n .. " / 4", "从背包放入部件" } end },
	ready = { color = hex("3BD85C"), lines = function() return { "可组装", "4 / 4", "按 E 开始组装" } end },
	assembling = { color = hex("FFB33D"), lines = function() return { "组装中", "· · ·", "请稍候" } end },
}
AB.DOCK_FIT = 2.3 -- 部件在坞里的最大尺寸

local function screenText(bay, lines, color)
	local screen = bay:FindFirstChild("InfoScreen")
	if not screen then return end
	for _, g in ipairs(screen:GetChildren()) do
		if g:IsA("SurfaceGui") then g:Destroy() end
	end
	B.surfaceText(screen, Enum.NormalId.Left, {
		{ text = lines[1], h = 0.32, color = hex("FFFFFF") },
		{ text = lines[2], h = 0.4, color = color },
		{ text = lines[3], h = 0.2, color = hex("CFEFFF"), font = Enum.Font.GothamBold },
	}, { lightInfluence = 0 })
end

function AB.filledCount(bay)
	local n = 0
	local docks = bay:FindFirstChild("Docks")
	if docks then
		for _, dk in ipairs(docks:GetChildren()) do
			if dk:FindFirstChild("DockPart") then n += 1 end
		end
	end
	return n
end

function AB.setStatus(bay, status, filled)
	local s = AB.STATUS[status] or AB.STATUS.staging
	local lights = bay:FindFirstChild("StatusLights")
	if lights then
		for _, p in ipairs(lights:GetChildren()) do
			if p:IsA("BasePart") then
				p.Color = s.color
				p.Transparency = 0
				if status == "assembling" then
					p:SetAttribute("PulseBase", 0)
					p:SetAttribute("PulseAmp", 0.85)
					p:SetAttribute("PulseSpeed", 12)
					CS:AddTag(p, "PulseFX")
				else
					CS:RemoveTag(p, "PulseFX")
				end
			end
		end
		lights:SetAttribute("State", status)
	end
	screenText(bay, s.lines(filled or AB.filledCount(bay)), s.color)
	bay:SetAttribute("Status", status)
end

-- 部件坞铭牌（墙上 Label 的 −X 面，朝舱内）
-- 11-25 第二版（用户反馈看不清）：隔着舱壁玻璃（透明 0.72）看会发灰 → 牌子加大到 3.2 × 1.5、SurfaceGui 提亮 2 倍；
-- 上下两段：上 = 级别条（深色底 + 浅色字），下 = 部件名（亮色稀有度底 + 粗白字 + 黑描边）；字体用 Heavy 字重
local HEAVY = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
local function cardText(parent, text, x, y, w, h, color, strokeT)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Position = UDim2.fromScale(x, y)
	t.Size = UDim2.fromScale(w, h)
	t.Text = text
	t.FontFace = HEAVY
	t.TextColor3 = color
	t.TextScaled = true
	t.ZIndex = 4
	t.Parent = parent
	if strokeT then
		local s = Instance.new("UIStroke")
		s.Color = hex("0B0D1C")
		s.Thickness = strokeT
		s.LineJoinMode = Enum.LineJoinMode.Round
		s.Parent = t
	end
	return t
end

local function box(parent, x, y, w, h, color, z)
	local f = Instance.new("Frame")
	f.Position = UDim2.fromScale(x, y)
	f.Size = UDim2.fromScale(w, h)
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.ZIndex = z or 2
	f.Parent = parent
	return f
end

function AB.drawLabel(dk, slot, tier)
	local plate = dk:FindFirstChild("Label")
	if not plate then return end
	for _, g in ipairs(plate:GetChildren()) do
		if g:IsA("SurfaceGui") then g:Destroy() end
	end
	local sg = Instance.new("SurfaceGui")
	sg.Name = "DockCard"
	sg.Face = Enum.NormalId.Left
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 90
	sg.LightInfluence = 0
	sg.Brightness = 2
	sg.MaxDistance = 140
	sg.Parent = plate
	local f = box(sg, 0, 0, 1, 1, hex("1B1F3C"), 1)
	Instance.new("UICorner", f).CornerRadius = UDim.new(0.16, 0)
	local stroke = Instance.new("UIStroke", f)
	stroke.Thickness = 5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	if tier then
		local r = PP.RARITY[tier]
		f.BackgroundColor3 = r.top
		local grad = Instance.new("UIGradient")
		grad.Rotation = 90
		grad.Color = ColorSequence.new(r.top, r.top:Lerp(r.bot, 0.35))
		grad.Parent = f
		stroke.Color = r.stroke
		-- 级别条：圆角条 + 下半截方块补齐，和下面的名字区拼成一张卡
		local band = box(f, 0, 0, 1, 0.36, r.bot, 2)
		Instance.new("UICorner", band).CornerRadius = UDim.new(0.45, 0)
		box(f, 0, 0.18, 1, 0.18, r.bot, 2)
		cardText(f, r.label, 0.06, 0.04, 0.88, 0.28, r.rc, 2)
		cardText(f, PP.NAMES[slot][tier], 0.04, 0.42, 0.92, 0.52, Color3.new(1, 1, 1), 3)
	else
		stroke.Color = B.C.cyan
		stroke.Transparency = 0.15
		cardText(f, PP.SLOT_NAMES[slot], 0.06, 0.1, 0.88, 0.52, Color3.new(1, 1, 1), 2)
		cardText(f, "空位 · 待放入", 0.06, 0.64, 0.88, 0.26, hex("8FE9F2"), 1.5)
	end
	return sg
end

function AB.setDock(bay, i, tier, homeColor)
	local dk = bay.Docks:FindFirstChild("Dock_" .. i)
	if not dk then return end
	AB.drawLabel(dk, AB.SLOTS[i], tier)
	local old = dk:FindFirstChild("DockPart")
	if old then old:Destroy() end
	for _, p in ipairs(dk:GetChildren()) do
		if p.Name == "EmptyOutline" then p.Transparency = tier and 1 or 0.35 end
	end
	if not tier then return end
	local tray = dk:FindFirstChild("Tray")
	local point = tray and tray:FindFirstChild("DockPoint")
	if not point then return end
	local slot = AB.SLOTS[i]
	-- 部件竖立在托盘中心，整体缩到 2.3 studs 以内；DockPoint 的本地 +Z 朝舱内（部件舷窗朝舱门方向）
	local base = point.WorldCFrame
	local d
	if slot == "nose" then
		d = B.nose(tier, base, dk)
	elseif slot == "tank" then
		d = B.tank(tier, base, homeColor or hex("3BD85C"), dk)
	elseif slot == "engine" then
		d = B.engine(tier, base, dk)
	else
		d = B.model("FinsDock", dk)
		B.cylAt(4, 0, 4, base * CFrame.new(0, -1.5, 0), { Name = "Core", Color = B.C.graphite2 }, d)
		B.fins(tier, base, d)
	end
	for _, x in ipairs(d:GetDescendants()) do
		if x:IsA("Model") then CS:RemoveTag(x, "SpinFX") end
	end
	local _, size0 = d:GetBoundingBox()
	d:ScaleTo(AB.DOCK_FIT / math.max(size0.X, size0.Y, size0.Z))
	local bcf, bsize = d:GetBoundingBox()
	d:PivotTo(d:GetPivot() + (base.Position + Vector3.yAxis * (bsize.Y / 2 + 0.02) - bcf.Position))
	B.decoAll(d)
	d.Name = "DockPart"
	d:SetAttribute("Tier", tier)
end

function AB.setHolo(bay, eq, homeColor)
	local old = bay:FindFirstChild("HoloPreview")
	local base
	if old then
		base = old:GetAttribute("BaseCF")
		old:Destroy()
	end
	base = base or (bay:GetPivot() * CFrame.new(0, 1.7, 0))
	local full = {}
	for _, s in ipairs(AB.SLOTS) do full[s] = eq[s] or 1 end
	local holo = B.rocket(full, homeColor or hex("3BD85C"), base, bay)
	holo.Name = "HoloPreview"
	B.holo(holo, B.C.cyan)
	local MAP = { Nose = "nose", Tank = "tank", Engine = "engine", Fins = "fins" }
	for _, ch in ipairs(holo:GetChildren()) do
		local slot = MAP[ch.Name]
		if slot and not eq[slot] then
			for _, p in ipairs(ch:GetDescendants()) do
				if p:IsA("BasePart") then p.Transparency = 0.9 end
			end
		end
	end
	for _, x in ipairs(holo:GetDescendants()) do
		if x:IsA("Model") then CS:RemoveTag(x, "SpinFX") end
		if x:IsA("ParticleEmitter") then x.Enabled = false end
		if x:IsA("BasePart") then CS:RemoveTag(x, "PulseFX") end
	end
	holo.WorldPivot = base
	holo:SetAttribute("BaseCF", base)
	holo:SetAttribute("SpinSpeed", 0.6)
	CS:AddTag(holo, "SpinFX")
	return holo
end

return AB
