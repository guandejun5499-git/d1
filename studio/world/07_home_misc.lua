--[[
	Orbit Roll · 任务二 · 07 出生点标记 + 家园店位（家园 K）
	出生点 (0, −6.5)：青色圆环 + 指向发射台（−Z）的箭头，纯装饰不碰撞（SpawnLocation 本体在 02 里设为透明薄片）。
	三个店位 (−31.2, −15.6 / 0 / 15.6)：玩具小屋，门朝家园中心（+X），门上「即将开放」。
]]

-- 克隆整个 OrbitShared 再 require：模块之间互相 require，克隆能避开编辑器里的模块缓存
local SH = game.ReplicatedStorage.OrbitShared:Clone()
SH.Parent = game.ServerStorage
local B = require(SH.BuildLib)

-- 要建的家园：0 = 玩家自家（全量），1–5 = 邻居（简化版 LITE：保留轮廓和主色，去掉细节件、文字牌和点光源）
local TARGETS = { 0, 1, 2, 3, 4, 5 }

-- 邻居简化版：不建出生点标记，店位去掉卷帘细线、檐口和招牌文字
local LITE_DROP = { ShutterLine = true, RoofTrim = true }

local function build(K, LITE)
	local HOME_COLOR = B.homeColor(K)
	local H = B.homeFrame(K)
	local C = B.C
	local V = Vector3.new
	local hex = B.hex
	local folder = B.homeFolder(K)
	local function L(x, y, z) return H * CFrame.new(x, y, z) end

	------------------------------------------------------------------ 出生点
	local old = folder:FindFirstChild("SpawnMarker")
	if old and LITE then old:Destroy() end
	if not LITE then
		local sp = B.replace(folder, "SpawnMarker")
		local S = L(0, 0, -6.5)
		B.cylAt(5.2, 0, 0.06, S, { Name = "Ring", Color = hex("2FB8C8") }, sp)
		B.cylAt(4.3, 0.005, 0.07, S, { Name = "Inner", Color = hex("D6F6F8") }, sp)
		B.cylAt(1.6, 0.01, 0.08, S, { Name = "Dot", Color = hex("2FB8C8") }, sp)
		-- 朝发射台的小箭头
		local tip = (S * CFrame.new(0, 0.09, -3.4)).Position
		for _, sx in ipairs({ -0.7, 0.7 }) do
			B.beamBetween(tip, (S * CFrame.new(sx, 0.09, -2.6)).Position, 0.3, 0.06, { Name = "Arrow", Color = hex("2FB8C8") }, sp)
		end
		B.decoAll(sp)
		sp.Parent = folder
	end

	------------------------------------------------------------------ 店位 ×3
	local shops = B.replace(folder, "ShopSlots")
	for i, z in ipairs({ -15.6, 0, 15.6 }) do
		local P = L(-31.2, 0, z) * CFrame.Angles(0, -math.pi / 2, 0) -- 本地 −Z（正面）朝 +X = 家园中心
		local s = B.model("Shop_" .. i, shops)
		B.box(V(7.6, 0.4, 7.6), P * CFrame.new(0, 0.2, 0), { Name = "Base", Color = C.graphite }, s)
		B.box(V(6, 4.4, 6), P * CFrame.new(0, 2.6, 0), { Name = "Body", Color = C.white }, s)
		B.box(V(7, 0.7, 7), P * CFrame.new(0, 5.15, 0), { Name = "Roof", Color = C.graphite }, s)
		B.box(V(7.2, 0.25, 7.2), P * CFrame.new(0, 4.7, 0), { Name = "RoofTrim", Color = C.graphite2 }, s)
		-- 卷帘门（黄框）
		B.box(V(2.8, 3.2, 0.2), P * CFrame.new(0, 2.0, -3.05), { Name = "Shutter", Color = C.graphite2 }, s)
		for y = 0.7, 3.4, 0.45 do
			B.box(V(2.6, 0.08, 0.22), P * CFrame.new(0, y, -3.06), { Name = "ShutterLine", Color = C.graphite }, s)
		end
		B.box(V(0.25, 3.3, 0.3), P * CFrame.new(-1.5, 2.05, -3.05), { Name = "DoorFrame", Color = C.yellow }, s)
		B.box(V(0.25, 3.3, 0.3), P * CFrame.new(1.5, 2.05, -3.05), { Name = "DoorFrame", Color = C.yellow }, s)
		-- 招牌「即将开放」
		local sign = B.box(V(4.4, 0.8, 0.2), P * CFrame.new(0, 4.1, -3.1), { Name = "Sign", Color = C.graphite3 }, s)
		B.surfaceText(sign, Enum.NormalId.Front, { { text = "即将开放", color = C.yellow } }, { pps = 50 })
		s:SetAttribute("ShopIndex", i)
	end
	for _, d in ipairs(shops:GetDescendants()) do
		if d:IsA("BasePart") and (d.Name == "ShutterLine" or d.Name == "Sign" or d.Name == "RoofTrim") then B.deco(d) end
	end
	if LITE then B.lite(shops, LITE_DROP) end
	shops.Parent = folder
end

for _, k in ipairs(TARGETS) do
	build(k, k ~= 0)
	task.wait()
end

SH:Destroy()
return "misc ok · homes " .. table.concat(TARGETS, ",")
