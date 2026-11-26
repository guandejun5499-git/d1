--[[
	Orbit Roll · 任务二 · 05 玻璃组装舱 + 运输带（家园 K）—— 原画 C2 机械科技版
	组装舱中心 (33.8, −6.5)。底座 18 × 18 × 1.2，外框 16 × 16，舱内净高 18.8，总高约 22.1。
	11-24 用户调整：除了门对面的 +X 墙，其余三面（−X、−Z、+Z）都是整面玻璃，前角 (−8, −8) 不设立柱；
	−X 面中间是朝发射台的伸缩舱门（11-25 P1 加宽到 10 × 14，四扇玻璃门），「待组装」信息屏在门上方、朝舱外。
	门对面的 +X 墙是石墨机械墙：4 个部件坞（鼻锥 / 燃料舱 / 发动机 / 尾翼）、管线。
	舱内：顶部龙门吊（横梁 + 小车 + 缆绳 + 四指抓爪）、两台焊接机械臂、中央转台（Ø7.6）、
	转台上是待组装组合的青色全息轮廓。舱外控制台在 −Z 面。状态灯默认青色 = 待组装。
	11-25 P1 组装演出：龙门吊小车骑在横梁上；舱门 10 × 17.2；信息屏在屋顶边梁上。
	运输带 (24.8, −6.5) → (18.2, −6.5) → (6.58, −21.1)（发射台边缘）：11-25 P1 改成先直行出门再斜向发射台，黄色箭头指向发射台。
	11-25 场景放大：组装舱整体从 (26, −5) 外移到 (33.8, −6.5)，舱内相对位置不变。
	11-24 P0：状态灯 / 门楣屏 / 部件坞 / 全息由 OrbitShared.AssemblyBay 切换（WorldPivot = 舱底中心，托盘上有 DockPoint）。
]]

-- 克隆整个 OrbitShared 再 require：模块之间互相 require，克隆能避开编辑器里的模块缓存
local SH = game.ReplicatedStorage.OrbitShared:Clone()
SH.Parent = game.ServerStorage
local B = require(SH.BuildLib)
local AB = require(SH.AssemblyBay)

-- 要建的家园：0 = 玩家自家（全量），1–5 = 邻居（简化版 LITE：保留轮廓和主色，去掉细节件、文字牌和点光源）
local TARGETS = { 0, 1, 2, 3, 4, 5 }

-- 邻居简化版删掉的细节件：保留底座、外框、状态灯、三面玻璃、门、机械墙、转台、龙门吊和运输带主体
local LITE_DROP = {
	Seam = true, Hazard = true, PanelSeam = true, Pipe = true, ScreenFrame = true, InfoScreen = true, ScreenPost = true,
	Docks = true, Dash = true, HoloPreview = true,
	WeldArm_A = true, WeldArm_B = true, Console = true, Roller = true, Chevron = true, DoorSeam = true,
}

local function build(K, LITE)
	local HOME_COLOR = B.homeColor(K)
	local H = B.homeFrame(K)
	local C = B.C
	local V = Vector3.new
	local folder = B.homeFolder(K)

	local m = B.replace(folder, "AssemblyBay")
	local BAY = H * CFrame.new(33.8, 0, -6.5)
	local function Bc(x, y, z) return BAY * CFrame.new(x, y, z) end
	-- 玻璃用半透明 SmoothPlastic：Glass 材质背后的半透明物体（全息、屏幕文字）不会渲染
	local GLASS = { Name = "Glass", Color = C.glass, Transparency = 0.72, Reflectance = 0.12, CastShadow = false }
	local NEON = Enum.Material.Neon
	local TOP = 20 -- 立柱顶 = 1.2 + 18.8

	------------------------------------------------------------------ 底座
	B.box(V(18, 1.2, 18), Bc(0, 0.6, 0), { Name = "Base", Color = C.graphite2 }, m)
	B.box(V(15.6, 0.05, 15.6), Bc(0, 1.225, 0), { Name = "Floor", Color = B.hex("4A5070") }, m)
	for i = -3, 3 do
		B.box(V(15.6, 0.06, 0.12), Bc(0, 1.23, i * 2.2), { Name = "Seam", Color = C.graphite }, m)
	end
	-- 11-25 用户要求：底座四周的黄色斜纹警示块去掉

	------------------------------------------------------------------ 外框（前角无立柱）
	for _, p in ipairs({ { 8, 8 }, { 8, -8 }, { -8, 8 } }) do
		B.box(V(1.2, 18.8, 1.2), Bc(p[1], 1.2 + 9.4, p[2]), { Name = "Pillar", Color = C.white }, m)
	end
	B.box(V(17.2, 1.4, 1.2), Bc(0, TOP + 0.7, -8), { Name = "TopBeam", Color = C.white }, m)
	B.box(V(17.2, 1.4, 1.2), Bc(0, TOP + 0.7, 8), { Name = "TopBeam", Color = C.white }, m)
	B.box(V(1.2, 1.4, 17.2), Bc(-8, TOP + 0.7, 0), { Name = "TopBeam", Color = C.white }, m)
	B.box(V(1.2, 1.4, 17.2), Bc(8, TOP + 0.7, 0), { Name = "TopBeam", Color = C.white }, m)
	B.box(V(17.2, 0.35, 0.15), Bc(0, TOP + 0.3, -8.65), { Name = "Accent", Color = C.orange }, m)
	local status = B.model("StatusLights", m)
	for _, p in ipairs({ { 8, 8 }, { 8, -8 }, { -8, 8 }, { -8, -8 } }) do
		B.box(V(1, 0.7, 1), Bc(p[1], TOP + 1.75, p[2]), { Name = "StatusLight", Color = C.cyan, Material = NEON }, status)
	end
	status:SetAttribute("State", "Staging") -- 青 = 待组装，绿 = 可组装 / 完成，黄橙闪 = 组装中

	------------------------------------------------------------------ 玻璃面
	-- −Z 面：整面玻璃 + 两根细竖框 + 底槛
	B.box(V(16, 18.8, 0.2), Bc(0, 10.6, -8), GLASS, m)
	for _, x in ipairs({ -2.67, 2.67 }) do
		B.box(V(0.25, 18.8, 0.3), Bc(x, 10.6, -8), { Name = "Mullion", Color = C.white }, m)
	end
	B.box(V(16.6, 0.9, 0.9), Bc(0, 1.65, -8), { Name = "Sill", Color = C.white }, m)
	-- +Z 面：整面玻璃 + 两根细竖框 + 底槛（与 −Z 面对称）
	B.box(V(16, 18.8, 0.2), Bc(0, 10.6, 8), GLASS, m)
	for _, x in ipairs({ -2.67, 2.67 }) do
		B.box(V(0.25, 18.8, 0.3), Bc(x, 10.6, 8), { Name = "Mullion", Color = C.white }, m)
	end
	B.box(V(16.6, 0.9, 0.9), Bc(0, 1.65, 8), { Name = "Sill", Color = C.white }, m)
	-- −X 面：门两侧和门上方玻璃（11-25 P1：门洞从 5.2 加宽到 10，三档火箭带尾翼约 8.2 宽也能出舱）
	B.box(V(0.2, 18.8, 3), Bc(-8, 10.6, -6.5), GLASS, m)
	B.box(V(0.2, 18.8, 3), Bc(-8, 10.6, 6.5), GLASS, m)
	-- 门上方是实心石墨门楣（信息屏在屋顶边上：挂在半透明玻璃前时 SurfaceGui 文字会被玻璃的渲染排序吃掉）
	B.box(V(0.4, 1.4, 10), Bc(-8, 19.3, 0), { Name = "DoorHeader", Color = C.graphite }, m)
	B.box(V(0.9, 0.9, 3), Bc(-8, 1.65, -6.5), { Name = "Sill", Color = C.white }, m)
	B.box(V(0.9, 0.9, 3), Bc(-8, 1.65, 6.5), { Name = "Sill", Color = C.white }, m)
	-- 伸缩舱门 10 × 17.2（黄框，门顶 18.4：最高的组合 = 等离子发动机 + 巨型燃料舱 + 气动鼻锥尖刺，连转台约 18.05）
	-- 四扇 2.5 宽的玻璃门，打开时两两叠到两侧玻璃外面
	-- 每扇门（和它的黄色边条）带 OpenOffset 属性 = 全开时的舱本地位移，组装演出（AssemblyShow）按它滑动
	local door = B.model("Door", m)
	B.box(V(0.4, 17.2, 0.35), Bc(-8, 9.8, -5), { Name = "DoorFrame", Color = C.yellow }, door)
	B.box(V(0.4, 17.2, 0.35), Bc(-8, 9.8, 5), { Name = "DoorFrame", Color = C.yellow }, door)
	B.box(V(0.4, 0.35, 10.35), Bc(-8, 18.4, 0), { Name = "DoorFrame", Color = C.yellow }, door)
	local leafProps = table.clone(GLASS)
	leafProps.Name = "DoorLeaf"
	for _, s in ipairs({ -1, 1 }) do
		-- { 关闭时 z, 打开时 z, 向外让开的距离 }：外扇叠在里扇外面
		for _, l in ipairs({ { 1.25, 6.3, 0.55 }, { 3.75, 6.0, 0.3 } }) do
			local off = V(-l[3], 0, s * (l[2] - l[1]))
			local leaf = B.box(V(0.15, 17.0, 2.45), Bc(-8.05, 9.7, s * l[1]), leafProps, door)
			leaf:SetAttribute("OpenOffset", off)
			local edge = B.box(V(0.2, 17.0, 0.1), Bc(-8.1, 9.7, s * (l[1] - 1.22)), { Name = "DoorEdge", Color = C.yellow }, door)
			edge:SetAttribute("OpenOffset", off)
		end
	end
	B.box(V(0.2, 17.0, 0.12), Bc(-8.1, 9.7, 0), { Name = "DoorSeam", Color = C.yellow }, door)

	------------------------------------------------------------------ 机械墙（只有门对面的 +X 墙）
	B.box(V(0.6, 18.8, 16), Bc(8, 10.6, 0), { Name = "MechWall", Color = C.graphite }, m)
	for _, z in ipairs({ -4, 0, 4 }) do
		B.box(V(0.08, 18.8, 0.25), Bc(7.66, 10.6, z), { Name = "PanelSeam", Color = C.graphite3 }, m)
	end
	for _, y in ipairs({ 7, 13 }) do
		B.box(V(0.08, 0.25, 16), Bc(7.66, y, 0), { Name = "PanelSeam", Color = C.graphite3 }, m)
	end
	-- 管线（+X 墙，部件坞上方和两侧）
	for i, y in ipairs({ 17.0, 17.8 }) do
		B.part({ Name = "Pipe", Shape = Enum.PartType.Cylinder, Size = V(15, 0.6, 0.6), CFrame = Bc(7.25, y, 0) * CFrame.Angles(0, math.pi / 2, 0), Color = (i == 1) and C.white or C.metal }, m)
	end
	B.cyl(0.6, 15.8, Bc(7.25, 9.1, -7.1), { Name = "Pipe", Color = C.white }, m)
	B.cyl(0.45, 15.8, Bc(7.3, 9.1, 7.1), { Name = "Pipe", Color = C.orange }, m)
	-- 「待组装」信息屏：立在门这一侧的屋顶边梁上（11-25 门加高后挪上来），朝舱外（−X，面向家园中心和走来的玩家）
	B.box(V(0.3, 2.8, 5.8), Bc(-8.3, 23.0, 0), { Name = "ScreenFrame", Color = C.graphite3 }, m)
	B.box(V(0.1, 2.5, 5.4), Bc(-8.5, 23.0, 0), { Name = "InfoScreen", Color = B.hex("1D5E74") }, m)
	for _, z in ipairs({ -2.2, 2.2 }) do
		B.box(V(0.3, 0.3, 0.3), Bc(-8.3, 21.5, z), { Name = "ScreenPost", Color = C.graphite3 }, m)
	end
	-- 文字由 AssemblyBay.setStatus 写（建完后设为「待组装 0 / 4」）

	------------------------------------------------------------------ 部件坞（+X 墙，4 个）
	local docks = B.model("Docks", m)
	for i, z in ipairs({ -5.4, -1.8, 1.8, 5.4 }) do
		local dk = B.model("Dock_" .. i, docks)
		local tray = B.box(V(2.8, 0.35, 3.0), Bc(6.2, 4.2, z), { Name = "Tray", Color = C.white }, dk)
		local dp = Instance.new("Attachment") -- 部件放置点：托盘顶面中心，本地 +Z 朝舱内（部件舷窗朝舱门方向）
		dp.Name = "DockPoint"
		dp.Parent = tray
		dp.WorldCFrame = Bc(6.2, 4.2 + 0.175, z) * CFrame.Angles(0, -math.pi / 2, 0)
		B.box(V(0.15, 0.5, 3.0), Bc(4.85, 4.3, z), { Name = "Lip", Color = C.orange }, dk)
		B.box(V(1.0, 1.2, 0.4), Bc(7.1, 3.5, z), { Name = "Bracket", Color = C.graphite3 }, dk)
		local top = 4.2 + 0.175 + 0.03
		local o = { Name = "EmptyOutline", Color = C.cyan, Material = NEON, Transparency = 0.35 }
		B.box(V(2.2, 0.05, 0.12), Bc(6.2, top, z - 1.1), o, dk)
		B.box(V(2.2, 0.05, 0.12), Bc(6.2, top, z + 1.1), o, dk)
		B.box(V(0.12, 0.05, 2.2), Bc(5.1, top, z), o, dk)
		B.box(V(0.12, 0.05, 2.2), Bc(7.3, top, z), o, dk)
		-- 铭牌（11-25 加大、挪到托盘部件上方）：内容由 AssemblyBay.setDock 画——空位写部位名，放入部件后按稀有度变色
		B.box(V(0.1, 1.5, 3.2), Bc(7.62, 8.0, z), { Name = "Label", Color = C.graphite3 }, dk)
		dk:SetAttribute("Slot", ({ "nose", "tank", "engine", "fins" })[i])
	end

	------------------------------------------------------------------ 转台 + 全息（11-25 P1：去掉两侧液压支柱，纯装饰、挡火箭出舱）
	B.cylAt(9.4, 1.2, 0.3, BAY, { Name = "TurntableRing", Color = C.yellow }, m)
	B.cylAt(7.6, 1.2, 0.5, BAY, { Name = "Turntable", Color = C.graphite }, m)
	B.segRing(BAY * CFrame.new(0, 1.73, 0), 2.9, 16, 0.6, 0.18, 0.05, { Name = "Dash", Color = C.yellow }, m)
	m.WorldPivot = BAY -- 运行态模块（OrbitShared.AssemblyBay）以舱底中心为基准
	AB.setHolo(m, { nose = 1, tank = 1, engine = 1, fins = 1 }, HOME_COLOR) -- 青色全息，客户端自转

	------------------------------------------------------------------ 龙门吊
	-- 11-25 P1：小车骑在横梁上面（原来吊在横梁下面），缆绳从横梁底面 18.9 放下，抓爪最高可到 18.35，
	-- 最高的组合（连转台约 18.05）也吊得进；照明灯挂在抓爪上，跟着移动
	local crane = B.model("Gantry", m)
	B.box(V(1.0, 1.0, 16), Bc(0, 19.4, 0), { Name = "Beam", Color = C.orange }, crane)
	B.box(V(1.6, 0.6, 1.0), Bc(0, 19.9, -7.6), { Name = "EndTruck", Color = C.graphite }, crane)
	B.box(V(1.6, 0.6, 1.0), Bc(0, 19.9, 7.6), { Name = "EndTruck", Color = C.graphite }, crane)
	B.box(V(2.4, 1.0, 2.4), Bc(0, 20.4, 0), { Name = "Trolley", Color = C.graphite }, crane)
	B.cylAt(0.15, 15.7, 3.2, BAY, { Name = "Cable", Color = C.graphite3 }, crane)
	local trolley = B.box(V(2.2, 0.5, 2.2), Bc(0, 15.45, 0), { Name = "Claw", Color = C.graphite }, crane)
	for _, p in ipairs({ { 0.8, 0.8 }, { -0.8, 0.8 }, { 0.8, -0.8 }, { -0.8, -0.8 } }) do
		B.box(V(0.3, 1.4, 0.3), Bc(p[1], 14.5, p[2]), { Name = "Finger", Color = C.orange }, crane)
	end
	local lamp = Instance.new("PointLight")
	lamp.Color = B.hex("DDF4FF")
	lamp.Range = 18
	lamp.Brightness = 0.7
	lamp.Parent = trolley

	------------------------------------------------------------------ 焊接机械臂 ×2
	local function robotArm(name, bx, bz)
		local a = B.model(name, m)
		local base = Bc(bx, 1.2, bz)
		B.cylAt(1.8, 0, 0.6, base, { Name = "Base", Color = C.graphite }, a)
		B.cylAt(1.3, 0.6, 0.5, base, { Name = "Turret", Color = C.metal }, a)
		local p0 = base:PointToWorldSpace(V(0, 1.3, 0))
		local toC = BAY.Position - base.Position
		toC = V(toC.X, 0, toC.Z).Unit
		local p1 = p0 + V(0, 3.4, 0) + toC * 0.9
		local p2 = p1 + toC * 2.4 - V(0, 0.9, 0)
		local p3 = p2 + toC * 0.6 - V(0, 0.6, 0)
		B.beamBetween(p0, p1, 0.7, 0.7, { Name = "Upper", Color = C.white }, a)
		B.beamBetween(p1, p2, 0.55, 0.55, { Name = "Fore", Color = C.white }, a)
		B.beamBetween(p2, p3, 0.3, 0.3, { Name = "Torch", Color = C.graphite }, a)
		for _, p in ipairs({ p0, p1, p2 }) do
			B.ball(0.95, CFrame.new(p), { Name = "Joint", Color = C.orange }, a)
		end
	end
	-- 11-25 P1：两台臂挪到尾翼之间的空档（舱的 +Z / −Z 两侧），焊枪尖正好在燃料舱外壁（半径 2.4），
	-- 装好的尾翼（45° 方向）不会穿过机械臂；出舱前臂向 +X 收起（AssemblyShow）
	robotArm("WeldArm_A", 0, 6.3)
	robotArm("WeldArm_B", 0, -6.3)

	------------------------------------------------------------------ 舱外控制台（−Z 面）
	local con = B.model("Console", m)
	local CS = Bc(-4.5, 0, -10.4)
	B.box(V(2.2, 3.0, 1.4), CS * CFrame.new(0, 1.5, 0), { Name = "Pedestal", Color = C.graphite }, con)
	local panel = B.box(V(2.4, 1.5, 0.25), CS * CFrame.new(0, 3.35, -0.3) * CFrame.Angles(math.rad(35), 0, 0), { Name = "Panel", Color = C.orange }, con)
	B.surfaceText(panel, Enum.NormalId.Front, {
		{ text = "组装舱", h = 0.5 },
		{ text = "E · 打开", h = 0.35, color = B.hex("FFF1E0"), font = Enum.Font.GothamBold },
	}, { pps = 50 })

	------------------------------------------------------------------ 运输带
	-- 11-25 P1：折线两段——先从舱门直行 6.6 再斜向发射台（宽火箭出门时不会擦到门框），转角盖一块圆台
	-- 每段一个 Seg_i（Belt 本地 −Z 指向下一段），组装演出按段滚动箭头和滚筒
	local cv = B.model("Conveyor", m)
	local PTS = { V(24.8, 0, -6.5), V(18.2, 0, -6.5), V(6.58, 0, -21.1) } -- 舱底边缘 → 转角 → 发射台 (0, −26) 朝舱方向 8.2 处
	for i = 1, #PTS - 1 do
		local a, b = PTS[i], PTS[i + 1]
		local d = (b - a).Unit
		local len = (b - a).Magnitude
		local mid = (a + b) / 2
		local CV = H * CFrame.lookAt(mid, mid + d) -- 本地 −Z 指向发射台
		local sg = B.model("Seg_" .. i, cv)
		B.box(V(3.4, 0.6, len), CV * CFrame.new(0, 0.3, 0), { Name = "Belt", Color = C.graphite }, sg)
		for _, x in ipairs({ -1.8, 1.8 }) do
			B.box(V(0.25, 0.7, len), CV * CFrame.new(x, 0.35, 0), { Name = "Lip", Color = C.graphite2 }, sg)
		end
		for z = -len / 2 + 0.5, len / 2 - 0.5, 1 do
			B.box(V(3.2, 0.03, 0.1), CV * CFrame.new(0, 0.615, z), { Name = "Roller", Color = C.graphite3 }, sg)
		end
		for zc = -len / 2 + 1.6, len / 2 - 1.2, 2.2 do
			local apex = (CV * CFrame.new(0, 0.63, zc - 0.55)).Position
			for _, sx in ipairs({ -0.95, 0.95 }) do
				local tail = (CV * CFrame.new(sx, 0.63, zc + 0.35)).Position
				B.beamBetween(apex, tail, 0.35, 0.05, { Name = "Chevron", Color = C.yellow }, sg)
			end
		end
	end
	B.cylAt(4.4, 0, 0.68, H * CFrame.new(PTS[2]), { Name = "TurnPlate", Color = C.graphite2 }, cv)
	B.cylAt(3.6, 0.68, 0.03, H * CFrame.new(PTS[2]), { Name = "TurnRing", Color = C.yellow }, cv)

	------------------------------------------------------------------ 细节件不碰撞
	local DECO = {
		Floor = true, Seam = true, Hazard = true, Accent = true, StatusLight = true, PanelSeam = true, Pipe = true,
		ScreenFrame = true, InfoScreen = true, EmptyOutline = true, Label = true, Dash = true, Cable = true,
		Roller = true, Chevron = true, DoorSeam = true, DoorEdge = true, TurntableRing = true, TurnRing = true,
	}
	for _, x in ipairs(m:GetDescendants()) do
		if x:IsA("BasePart") and DECO[x.Name] then B.deco(x) end
	end

	AB.setStatus(m, "staging", 0) -- 状态灯青 + 门楣屏「待组装 0 / 4」
	for i = 1, 4 do AB.setDock(m, i, nil) end -- 部件坞空位 + 铭牌「空位」
	if LITE then B.lite(m, LITE_DROP) end
	m.Parent = folder
end

for _, k in ipairs(TARGETS) do
	build(k, k ~= 0)
	task.wait()
end

SH:Destroy()
return "assembly bay ok · homes " .. table.concat(TARGETS, ",")
