--[[
	CrashShow · P1 第 17 项 华丽坠毁 + 维修无人机（ReplicatedStorage.OrbitShared.CrashShow）
	客户端表现。没接住（landing = "crash"）时火箭落地后：
	  0.0–0.6  火箭往一侧倾倒（绕底面边缘转 80°）
	  0.6      卡通爆炸：橙色火球膨胀淡出 + 白热闪光 + 火花 + 弹跳火星 + 黑烟 / 橙烟 + 橙色冲击环 + 强震；
	           火箭拆成发动机 / 燃料舱 / 鼻锥 / 四片尾翼，各自带速度和自转飞出去，落到台面 / 地面弹跳、冒烟
	  2.2–2.9  维修无人机从组装舱上空飞来（四旋翼转动、上下浮动），悬停在台上方
	  2.9–4.5  青色修复光锥照住发射台；部件一件件（间隔 0.12 s）沿弧线飞回原位，卡上时冒火花；
	           无人机焊接臂迸蓝白焊花
	  全部归位：青色爆闪「修好了」；4.6–5.2 无人机升空飞走
	维修无人机（原画 E1 还没画，按组装舱龙门吊的造型语言设计）：深蓝机身 + 白色顶壳 + 橙色饰条，
	  四个机臂 + 半透明旋翼盘，机腹青色「眼睛」+ 点光源，机腹一支小焊接臂；约 6 × 1.6 × 6
	X.buildDrone(cf, parent) → 无人机 Model；X.play(launchArea, rocket, opts)：跑完整段（阻塞约 5.3 s）
	opts.dronFrom：无人机出发点（默认组装舱上空）
]]

local B = require(script.Parent.BuildLib)
local FX = require(script.Parent.ShowFX)
local VS = require(script.Parent.VisitorShow)
local CA = require(script.Parent.CatchArms)
local CatchShow = require(script.Parent.CatchShow)
local CS = game:GetService("CollectionService")

local V = Vector3.new
local hex = B.hex
local X = {}
local CYAN = hex("6FD4FF")

local function clamp01(x) return math.clamp(x, 0, 1) end
local function smooth(x)
	x = clamp01(x)
	return x * x * (3 - 2 * x)
end

local function folder()
	local f = workspace:FindFirstChild("_ShowFX")
	if not f then
		f = Instance.new("Folder")
		f.Name = "_ShowFX"
		f.Archivable = false
		f.Parent = workspace
	end
	return f
end

------------------------------------------------------------------ 维修无人机
function X.buildDrone(cf, parent)
	local C = B.C
	local m = B.model("RepairDrone")
	local NEON = Enum.Material.Neon
	-- 机身：深蓝底壳 + 白色顶壳 + 橙色饰条
	B.box(V(3.2, 0.9, 3.2), cf, { Name = "Body", Color = hex("2F365F") }, m)
	B.box(V(2.6, 0.4, 2.6), cf * CFrame.new(0, 0.62, 0), { Name = "TopShell", Color = C.white }, m)
	B.box(V(3.26, 0.18, 3.26), cf * CFrame.new(0, -0.1, 0), { Name = "Trim", Color = C.orange }, m)
	B.box(V(0.5, 0.2, 0.5), cf * CFrame.new(0, 0.92, 0), { Name = "StatusLight", Color = hex("3BD85C"), Material = NEON }, m)
	-- 四个机臂 + 电机 + 旋翼
	for _, d in ipairs({ { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } }) do
		local tip = cf * CFrame.new(d[1] * 2.6, 0.2, d[2] * 2.6)
		B.beamBetween((cf * CFrame.new(d[1] * 1.2, 0.2, d[2] * 1.2)).Position, tip.Position, 0.4, 0.3, { Name = "Arm", Color = hex("2F365F") }, m)
		B.cylAt(0.7, 0, 0.6, tip * CFrame.new(0, -0.2, 0), { Name = "Motor", Color = hex("6E7CC4") }, m)
		B.box(V(0.3, 0.3, 0.3), tip * CFrame.new(0, -0.35, 0), { Name = "MotorTip", Color = C.orange }, m)
		local rotor = B.model("Rotor", m)
		B.cylAt(2.6, 0.45, 0.06, tip, { Name = "Disc", Color = hex("C9CEDE"), Transparency = 0.6 }, rotor)
		B.box(V(2.4, 0.05, 0.22), tip * CFrame.new(0, 0.5, 0), { Name = "Blade", Color = hex("E6E9F5") }, rotor)
		rotor.WorldPivot = tip
		rotor:SetAttribute("SpinSpeed", 40)
		CS:AddTag(rotor, "SpinFX")
	end
	-- 机腹「眼睛」+ 光
	local eye = B.ball(1.0, cf * CFrame.new(0, -0.65, 0), { Name = "Eye", Color = CYAN, Material = NEON }, m)
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness = CYAN, 16, 1.5
	l.Parent = eye
	-- 焊接臂（机腹一侧斜向下）+ 焊枪尖
	local a0 = (cf * CFrame.new(1.0, -0.5, 0)).Position
	local a1 = (cf * CFrame.new(1.6, -1.6, 0)).Position
	B.beamBetween(a0, a1, 0.25, 0.25, { Name = "WeldArm", Color = C.white }, m)
	B.ball(0.35, CFrame.new(a0), { Name = "WeldJoint", Color = C.orange }, m)
	B.ball(0.3, CFrame.new(a1), { Name = "WeldTip", Color = hex("D9F3FF"), Material = NEON }, m)
	B.decoAll(m)
	m.WorldPivot = cf
	m.Parent = parent
	return m
end

------------------------------------------------------------------ 拆分火箭（发动机 / 燃料舱 / 鼻锥 / 四片尾翼 各自一组）
local function splitRocket(rocket)
	local pivot = rocket:GetPivot()
	local groups = {}
	local function add(name, parts)
		if #parts == 0 then return end
		-- 组中心 = 零件位置平均
		local c = Vector3.zero
		for _, p in ipairs(parts) do c += p.Position end
		c /= #parts
		local g = { name = name, cf = (pivot - pivot.Position) + c, parts = {} }
		for _, p in ipairs(parts) do table.insert(g.parts, { part = p, rel = g.cf:ToObjectSpace(p.CFrame) }) end
		g.home = g.cf
		table.insert(groups, g)
	end
	for _, ch in ipairs(rocket:GetChildren()) do
		if ch:IsA("Model") and ch.Name ~= "Flame" then
			local parts = {}
			for _, d in ipairs(ch:GetDescendants()) do
				if d:IsA("BasePart") and d.Transparency < 1 then table.insert(parts, d) end
			end
			if ch.Name == "Fins" then
				local quad = { {}, {}, {}, {} }
				for _, p in ipairs(parts) do
					local l = pivot:PointToObjectSpace(p.Position)
					local k = math.floor((math.atan2(l.X, l.Z) % (math.pi * 2)) / (math.pi / 2)) + 1
					table.insert(quad[math.clamp(k, 1, 4)], p)
				end
				for i, q in ipairs(quad) do add("Fin" .. i, q) end
			else
				add(ch.Name, parts)
			end
		end
	end
	return groups
end

local function place(g)
	for _, r in ipairs(g.parts) do r.part.CFrame = g.cf * r.rel end
end

------------------------------------------------------------------ 整段
function X.play(area, rocket, opts)
	opts = opts or {}
	local hole = area:FindFirstChild("LaunchPad") and area.LaunchPad:FindFirstChild("FlameHole")
	local deck = hole and (hole.Position + V(0, hole.Size.X / 2, 0)) or rocket:GetPivot().Position
	local home = rocket:GetPivot()
	local h = rocket:GetAttribute("Height") or 12
	local dir = (math.random() < 0.5) and -1 or 1
	-- 无人机出发点：组装舱上空（默认）
	local bay = area.Parent and area.Parent:FindFirstChild("AssemblyBay")
	local from = opts.droneFrom or ((bay and bay:GetPivot().Position or deck + V(30, 0, 20)) + V(0, 26, 0))
	local at = deck + V(0, h + 8, 0)

	-- 先按直立姿态拆组（部件飞回时回到这里），记下嵌套模型轴心，暂停全息环自转
	local groups = splitRocket(rocket)
	local subPivots, spins = {}, {}
	for _, d in ipairs(rocket:GetDescendants()) do
		if d:IsA("Model") then
			subPivots[d] = home:ToObjectSpace(d:GetPivot())
			if CS:HasTag(d, "SpinFX") then
				table.insert(spins, d)
				CS:RemoveTag(d, "SpinFX")
			end
		end
	end
	-- 0–0.6 倾倒：绕底面边缘转
	local edge = home * CFrame.new(dir * 1.8, 0, 0)
	local t0 = os.clock()
	FX.shake(deck, 0.3, 0.3)
	while os.clock() - t0 < 0.6 do
		local u = (os.clock() - t0) / 0.6
		local a = dir * -1.4 * u * u
		rocket:PivotTo(edge * CFrame.Angles(0, 0, a) * edge:ToObjectSpace(home))
		task.wait()
	end

	-- 0.6 爆炸：各组从倾倒后的位置飞出
	local tilted = rocket:GetPivot()
	for _, g in ipairs(groups) do g.cf = tilted * home:ToObjectSpace(g.home) end
	local c = deck + V(0, 3, 0)
	FX.flash(c, hex("FFB070"), 60, 12, 1.0)
	FX.sparks(c, 80, 1.8)
	FX.chunks(c, 16, 1.6)
	FX.puff(c, 24, hex("2A2A33"), 10, 7, { life = 2.6, influence = 1, t0 = 0.15 })
	FX.puff(c, 12, hex("FF8A3D"), 9, 5, { life = 0.9, light = 1, influence = 0, t0 = 0.1 })
	FX.ring(CFrame.new(deck + V(0, 0.1, 0)), 2, 18, hex("FF8A3D"), 0.9, { width = 1 })
	FX.shake(deck, 1.3, 0.7)
	VS.knock(deck, 30) -- 爆炸掀翻附近的访客；爬起走回去后欢呼（看无人机修火箭）
	VS.cheer(deck, 2.5)
	-- 火球：橙色 Neon 球膨胀淡出
	local fb = Instance.new("Part")
	fb.Name = "Fireball"
	fb.Shape = Enum.PartType.Ball
	fb.Anchored, fb.CanCollide, fb.CanQuery, fb.CanTouch, fb.CastShadow = true, false, false, false, false
	fb.Material = Enum.Material.Neon
	fb.Color = hex("FF9A3D")
	fb.CFrame = CFrame.new(c)
	fb.Parent = folder()
	local core = fb:Clone()
	core.Color = hex("FFF1B8")
	core.Parent = folder()
	for _, g in ipairs(groups) do
		g.v = V((math.random() - 0.5) * 34, 20 + math.random() * 22, (math.random() - 0.5) * 34)
		g.w = V((math.random() - 0.5) * 12, (math.random() - 0.5) * 12, (math.random() - 0.5) * 12)
	end
	local flame = rocket:FindFirstChild("Flame")
	if flame then
		for _, d in ipairs(flame:GetDescendants()) do
			if d:IsA("BasePart") then d.LocalTransparencyModifier = 1 end
		end
	end

	-- 无人机
	local drone
	local boomT = os.clock()
	local last = boomT
	local nextWeld = 0
	local done = false
	local beam
	while true do
		local now = os.clock()
		local dt = math.min(0.05, now - last)
		last = now
		local t = now - boomT + 0.6 -- 以倾倒开始为 0
		-- 火球 0.6–1.3
		local fu = clamp01((t - 0.6) / 0.7)
		if fb.Parent then
			fb.Size = V(1, 1, 1) * (3 + 13 * (1 - (1 - fu) ^ 3))
			core.Size = fb.Size * 0.55
			fb.Transparency = 0.15 + 0.85 * fu
			core.Transparency = 0.05 + 0.95 * math.min(1, fu * 1.4)
			fb.CFrame, core.CFrame = CFrame.new(c + V(0, 2 * fu, 0)), CFrame.new(c + V(0, 2 * fu, 0))
			if fu >= 1 then fb:Destroy() core:Destroy() end
		end
		-- 碎片弹跳（2.9 s 前）
		if t < 2.9 then
			for _, g in ipairs(groups) do
				g.v += V(0, -70 * dt, 0)
				local p = g.cf.Position + g.v * dt
				local d = Vector2.new(p.X - deck.X, p.Z - deck.Z).Magnitude
				local floor = ((d < 7.6) and deck.Y or (deck.Y - 1.5)) + 0.6
				if p.Y < floor and g.v.Y < 0 then
					p = V(p.X, floor, p.Z)
					g.v = V(g.v.X * 0.7, -g.v.Y * 0.4, g.v.Z * 0.7)
					g.w *= 0.6
				end
				g.cf = CFrame.new(p) * (g.cf - g.cf.Position) * CFrame.Angles(g.w.X * dt, g.w.Y * dt, g.w.Z * dt)
				place(g)
				if math.random() < 0.08 then FX.puff(p, 1, hex("3A3A44"), 2, 2.2, { life = 1.1, influence = 1 }) end
			end
		end
		-- 无人机 2.2–5.2
		if t >= 2.2 and not drone then
			drone = X.buildDrone(CFrame.new(from), folder())
		end
		if drone then
			local u = smooth((t - 2.2) / 0.7)
			local away = smooth((t - 4.6) / 0.6)
			local p = from:Lerp(at, u) + V(0, away * 30 + math.sin(t * 6) * 0.3, 0)
			local face = CFrame.lookAt(p, p + (at - from) * V(1, 0, 1) + V(0.001, 0, 0))
			drone:PivotTo(face * CFrame.Angles(math.rad(-10) * (1 - u) + math.rad(8) * away, 0, 0))
			if t >= 5.2 then drone:Destroy() drone = nil break end
		end
		-- 修复光锥 2.9–4.5
		if t >= 2.9 and t < 4.5 then
			if not beam then
				local an = Instance.new("Part")
				an.Name = "RepairBeam"
				an.Anchored, an.CanCollide, an.CanQuery, an.CanTouch = true, false, false, false
				an.Transparency = 1
				an.Size = V(0.2, 0.2, 0.2)
				an.Parent = folder()
				local cone = Instance.new("ConeHandleAdornment")
				cone.Adornee = an
				cone.Color3 = CYAN
				cone.Radius = 5
				cone.Height = h + 7.5
				cone.ZIndex = 0
				cone.Parent = an
				beam = { part = an, cone = cone }
			end
			-- 光锥：尖端在无人机眼睛，底面在台面
			local top = at - V(0, 0.65, 0)
			beam.part.CFrame = CFrame.lookAt(deck, top)
			beam.cone.Height = (top - deck).Magnitude
			beam.cone.Transparency = 0.72 + math.sin(t * 20) * 0.06
			-- 焊花
			if drone and now >= nextWeld then
				nextWeld = now + 0.08
				local tip = drone:FindFirstChild("WeldTip")
				if tip then FX.sparks(tip.Position, 5, 0.5, { Color3.new(1, 1, 1), hex("7CC0FF") }) end
			end
		elseif beam then
			beam.part:Destroy()
			beam = nil
		end
		-- 部件飞回 2.9 起
		if t >= 2.9 then
			for i, g in ipairs(groups) do
				if not g.back then
					local u = clamp01((t - (2.9 + (i - 1) * 0.12)) / 0.7)
					if u > 0 then
						if not g.from then g.from = g.cf end
						local e = smooth(u)
						local p = g.from.Position:Lerp(g.home.Position, e) + V(0, math.sin(e * math.pi) * 4, 0)
						g.cf = (g.from - g.from.Position):Lerp(g.home - g.home.Position, e) + p
						place(g)
						if u >= 1 then
							g.back = true
							g.cf = g.home
							place(g)
							FX.sparks(g.home.Position, 10, 0.5, { Color3.new(1, 1, 1), CYAN })
						end
					end
				end
			end
			if not done then
				local all = true
				for _, g in ipairs(groups) do all = all and g.back == true end
				if all then
					done = true
					rocket.WorldPivot = home -- 零件已逐个摆好，只把轴心放回
					FX.puff(deck + V(0, h * 0.5, 0), 20, CYAN, 10, 2.4, { light = 1, influence = 0, life = 0.9, t0 = 0.2 })
					FX.flash(deck + V(0, h * 0.5, 0), CYAN, 30, 5, 0.6)
					FX.ring(CFrame.new(deck + V(0, 0.15, 0)), 2, 10, CYAN, 0.6, { width = 0.6 })
				end
			end
		end
		if t > 5.4 then break end
		task.wait()
	end
	if drone then drone:Destroy() end
	if beam then beam.part:Destroy() end
	for _, g in ipairs(groups) do
		g.cf = g.home
		place(g)
	end
	rocket.WorldPivot = home
	for d, rel in pairs(subPivots) do
		if d.Parent then d.WorldPivot = home * rel end
	end
	for _, d in ipairs(spins) do
		if d.Parent then CS:AddTag(d, "SpinFX") end
	end
	if flame then
		for _, d in ipairs(flame:GetDescendants()) do
			if d:IsA("BasePart") then d.LocalTransparencyModifier = 0 end
		end
	end
	-- 修好后回收支架合拢（按火箭实际宽度）
	local arms = area:FindFirstChild("CatchArms")
	if arms then
		local from = arms:GetAttribute("Pose") or 1
		local to = CatchShow.fitClose(arms, rocket)
		local t1 = os.clock()
		while os.clock() - t1 < 0.25 do
			CA.setPose(arms, from + (to - from) * smooth((os.clock() - t1) / 0.25))
			task.wait()
		end
		CA.setPose(arms, to)
	end
end

return X
