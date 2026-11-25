--[[
	AssemblyBay · 组装舱运行态（ReplicatedStorage.OrbitShared.AssemblyBay）
	组装舱模型由 05_home_bay 建：WorldPivot = 舱底中心；Docks/Dock_1–4 各有 DockPoint（托盘顶面中心）。
	AB.setStatus(bay, status, filled)：
	  "staging"    青 = 待组装（门楣屏：待组装 n / 4）
	  "ready"      绿 = 四个槽位都放好，可组装 / 组装完成
	  "assembling" 黄橙闪 = 组装中
	AB.setDock(bay, i, tier, homeColor)：部件坞 i（1 鼻锥 / 2 燃料舱 / 3 发动机 / 4 尾翼）放入一件缩小的部件；
	  tier = nil 清空，显示青色虚线空位框。
	AB.setHolo(bay, eq, homeColor)：转台上的青色全息按当前组合重建（缺的部位用基础件、更淡），客户端自转。
]]

local B = require(script.Parent.BuildLib)
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

function AB.setDock(bay, i, tier, homeColor)
	local dk = bay.Docks:FindFirstChild("Dock_" .. i)
	if not dk then return end
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
