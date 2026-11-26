--[[
	CatchShow · P1 第 16 项 完美接住 / 连续接住（ReplicatedStorage.OrbitShared.CatchShow）
	客户端表现，由 FlightShow 的降落段驱动（opts.landing / opts.streak），也可单独用。
	降落中：发射台接住区光柱显示（CatchZone：底部绿区 = 完美窗口，高度随支架等级；上方黄区），火箭底环随区段变色；
	        离台面 14 格以内开始扬起尘土，越低越多
	按「接住」的时刻（演示里按结果模拟）：回收支架 0.12 s 合拢，夹口一小撮火花；合拢角按火箭实际宽度自动找
	        （巨型燃料舱的侧挂舱比机身宽，夹到挂舱外沿为止，不穿模）
	落地：
	  perfect 完美：落台定格（火箭 0.1 s 放大 6% 回弹）+ 两个夹口大火花 + 金色双层冲击波 + 彩色纸屑 + 台面金光 + 震动
	          连续第 3 次起夹口火花加倍；第 5 次起两只支架之间拉 1.6 s 电弧
	  great 良好：蓝色冲击波 + 夹口火花（少）
	  early 太早：支架提前空合一下、弹回半开，火箭落台弹一下（0.42 s）+ 扬尘，再夹紧
	  crash 没接住：支架保持张开，交给 CrashShow（第 17 项）
	C.prepare(launchArea, rocket, result, streak) → c；c:land(u, dur, rocket)（降落段每帧）；c:touchdown()（落地那一帧）
	C.fitClose(catchArms, rocket)：火箭停在台上时不夹进火箭的最小合拢角
]]

local B = require(script.Parent.BuildLib)
local CA = require(script.Parent.CatchArms)
local Z = require(script.Parent.CatchZone)
local FX = require(script.Parent.ShowFX)
local VS = require(script.Parent.VisitorShow)

local V = Vector3.new
local C = {}
C.CATCH_BEFORE = { perfect = 0.22, great = 0.55, early = 1.35 } -- 「接住」比落地提前多少秒（换成降落段进度）
local GOLD, BLUE, CYAN = B.hex("FFCC33"), B.hex("7CC0FF"), B.hex("BFE9FF")

local function clamp01(x) return math.clamp(x, 0, 1) end
local function smooth(x)
	x = clamp01(x)
	return x * x * (3 - 2 * x)
end

-- 不夹进火箭的最小合拢角（0 = 标准夹紧；巨型燃料舱约 0.2）
function C.fitClose(arms, rocket)
	if not (arms and rocket) then return 0 end
	local saved = {}
	for _, d in ipairs(rocket:GetDescendants()) do
		if d:IsA("BasePart") then
			saved[d] = d.CanQuery
			d.CanQuery = true
		end
	end
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Include
	op.FilterDescendantsInstances = { rocket }
	local parts = {}
	local base = arms:FindFirstChild("Base")
	for _, d in ipairs(arms:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 0.95 and not (base and d:IsDescendantOf(base)) then table.insert(parts, d) end
	end
	local pose0 = arms:GetAttribute("Pose") or 0
	local best = 0
	for a = 0, 1.01, 0.1 do
		CA.setPose(arms, a)
		local hit = false
		for _, p in ipairs(parts) do
			if #workspace:GetPartsInPart(p, op) > 0 then
				hit = true
				break
			end
		end
		best = a
		if not hit then break end
	end
	CA.setPose(arms, pose0)
	for p, v in pairs(saved) do p.CanQuery = v end
	return best
end

-- 两个夹口的位置（找夹爪零件；找不到按台心两侧估）
local function clawPoints(arms, deck)
	local pts = {}
	for _, side in ipairs({ "Arm_L", "Arm_R" }) do
		local a = arms and arms:FindFirstChild(side)
		local best
		if a then
			for _, d in ipairs(a:GetDescendants()) do
				if d:IsA("BasePart") and (d.Name == "Clamp" or d.Name == "ClampHead" or d.Name == "ClampPad") then
					if not best or d.Position.Y > best.Y then best = d.Position end
				end
			end
		end
		table.insert(pts, best or (deck + V((side == "Arm_L") and -4.2 or 4.2, 4, 0)))
	end
	return pts
end

------------------------------------------------------------------ 准备
-- scale0：火箭落地后的比例（可选）。「接早了」时火箭还没缩回原尺寸，合拢角要按落地后的比例量
function C.prepare(area, rocket, result, streak, scale0)
	local S = { area = area, rocket = rocket, result = result or "perfect", streak = streak or 1, scale0 = scale0 }
	S.arms = area:FindFirstChild("CatchArms")
	S.zone = area:FindFirstChild("CatchZone")
	local hole = area:FindFirstChild("LaunchPad") and area.LaunchPad:FindFirstChild("FlameHole")
	S.deck = hole and (hole.Position + V(0, hole.Size.X / 2, 0)) or (rocket:GetPivot().Position)
	local level = S.arms and S.arms:GetAttribute("Level") or 1
	S.green, S.yellow = Z.heightsFor(CA.LEVELS[level].win)
	S.closeTo = nil -- 落地前算（要火箭在台上的姿态）
	S.nextDust = 0
	return setmetatable(S, { __index = C })
end

-- 降落段每帧：u = 段进度，dur = 段时长
function C.land(S, u, dur)
	local base = S.rocket:GetPivot().Y - S.deck.Y
	-- 接住区光柱
	if S.zone then
		local st = (base <= S.green) and "green" or (base <= S.yellow) and "yellow" or "none"
		Z.set(S.zone, { visible = u < 0.999, green = S.green, yellow = S.yellow, base = math.max(0.1, base), state = st })
	end
	-- 扬尘：离台面 14 格以内，越低越密
	if base < 14 and os.clock() >= S.nextDust then
		local k = 1 - base / 14
		S.nextDust = os.clock() + 0.12 - 0.08 * k
		for _ = 1, 1 + math.floor(k * 3) do
			local a = math.random() * math.pi * 2
			local r = 3 + math.random() * 3.5
			FX.puff(S.deck + V(math.cos(a) * r, 0.3, math.sin(a) * r), 1, B.hex("D6D9EA"), 4 + 6 * k, 2 + 2.5 * k, { life = 1.1, influence = 1, t0 = 0.3, spread = 60 })
		end
	end
	-- 支架：降落时张开，到「接住」时刻 0.12 s 合拢（没接住就一直张开）
	if S.arms then
		local lead = C.CATCH_BEFORE[S.result]
		if lead then
			local uc = 1 - lead / dur
			if u >= uc and not S.closeTo then
				-- 合拢角：按火箭落在台上的姿态和落地后的比例算（临时把火箭缩回原尺寸、放到落位再算，算完复原）
				local cf = S.rocket:GetPivot()
				local s = S.rocket:GetScale()
				local resize = S.scale0 and math.abs(s - S.scale0) > 1e-3
				if resize then S.rocket:ScaleTo(S.scale0) end
				S.rocket:PivotTo(CFrame.new(S.deck) * (cf - cf.Position))
				S.closeTo = C.fitClose(S.arms, S.rocket)
				if resize then S.rocket:ScaleTo(s) end
				S.rocket:PivotTo(cf)
				local pts = clawPoints(S.arms, S.deck)
				for _, p in ipairs(pts) do FX.sparks(p, 10, 0.5) end
			end
			local k = smooth((u - uc) * dur / 0.12)
			local pose = (1 - k) * 1 + k * (S.closeTo or 0)
			if S.result == "early" then -- 空合：夹空后弹回半开，火箭落下来再夹
				pose = pose + smooth(((u - uc) * dur - 0.3) / 0.3) * (0.7 - (S.closeTo or 0))
			end
			CA.setPose(S.arms, pose)
		else
			CA.setPose(S.arms, 1)
		end
	end
end

------------------------------------------------------------------ 落地
local function shock(S, color, r1, dur, width)
	FX.ring(CFrame.new(S.deck + V(0, 0.1, 0)), 2, r1, color, dur, { width = width })
end

-- 两只支架之间的电弧：一串折线 Neon 小段，每 0.05 s 重新抖一次
local function arc(S, a, b, dur)
	task.spawn(function()
		local folder = workspace:FindFirstChild("_ShowFX") or Instance.new("Folder")
		folder.Name = "_ShowFX"
		folder.Archivable = false
		folder.Parent = workspace
		local segs = {}
		for i = 1, 10 do
			local p = Instance.new("Part")
			p.Name = "Arc"
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
			p.Material = Enum.Material.Neon
			p.Color = (i % 3 == 0) and Color3.new(1, 1, 1) or CYAN
			p.Parent = folder
			segs[i] = p
		end
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness = CYAN, 18, 3
		light.Parent = segs[5]
		local t0 = os.clock()
		while os.clock() - t0 < dur do
			local pts = { a }
			for i = 1, 9 do
				local q = a:Lerp(b, i / 10)
				local j = math.sin(i / 10 * math.pi) * 1.1
				table.insert(pts, q + V((math.random() - 0.5) * j, (math.random() - 0.5) * j * 1.6, (math.random() - 0.5) * j))
			end
			table.insert(pts, b)
			local fade = clamp01((os.clock() - t0 - (dur - 0.3)) / 0.3)
			for i = 1, 10 do
				local p0, p1 = pts[i], pts[i + 1]
				local len = (p1 - p0).Magnitude
				segs[i].Size = V(0.16, 0.16, len)
				segs[i].CFrame = CFrame.lookAt((p0 + p1) / 2, p1)
				segs[i].Transparency = fade + ((math.random() < 0.15) and 0.6 or 0)
			end
			light.Brightness = 1.5 + math.random() * 3
			if math.random() < 0.3 then FX.sparks(pts[math.random(2, 10)], 3, 0.4, { Color3.new(1, 1, 1), CYAN }) end
			task.wait(0.05)
		end
		for _, p in ipairs(segs) do p:Destroy() end
	end)
end

function C.touchdown(S)
	if S.zone then Z.set(S.zone, { visible = false }) end
	local deck, r = S.deck, S.result
	local pts = clawPoints(S.arms, deck)
	-- 落地的尘土一圈
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		FX.puff(deck + V(math.cos(a) * 3, 0.4, math.sin(a) * 3), 2, B.hex("D6D9EA"), 9, 3.2, { life = 1.3, influence = 1, t0 = 0.3, spread = 40 })
	end
	if r == "perfect" then
		local n = S.streak
		-- 落台定格：火箭放大 6% 再弹回
		task.spawn(function()
			local s0 = S.rocket:GetScale()
			local t0 = os.clock()
			while os.clock() - t0 < 0.22 do
				local u = (os.clock() - t0) / 0.22
				S.rocket:ScaleTo(s0 * (1 + 0.06 * math.sin(u * math.pi)))
				task.wait()
			end
			S.rocket:ScaleTo(s0)
		end)
		FX.flash(deck + V(0, 4, 0), B.hex("FFF3C4"), 40, 8, 0.6)
		shock(S, GOLD, 20, 0.75, 1.0)
		shock(S, Color3.new(1, 1, 1), 12, 0.5, 0.5)
		for _, p in ipairs(pts) do
			FX.sparks(p, (n >= 3) and 90 or 46, 1.3)
			FX.chunks(p, (n >= 3) and 10 or 5, 1)
		end
		FX.sparks(deck + V(0, 0.6, 0), 40, 1)
		FX.confetti(deck + V(0, 5, 0), 70, 1)
		FX.shake(deck, 0.7, 0.35)
		VS.cheer(deck, (n >= 3) and 3 or 2)
		if n >= 5 and #pts == 2 then arc(S, pts[1], pts[2], 1.6) end
	elseif r == "great" then
		FX.flash(deck + V(0, 4, 0), B.hex("CFE6FF"), 30, 4, 0.4)
		shock(S, BLUE, 15, 0.6, 0.8)
		for _, p in ipairs(pts) do FX.sparks(p, 24, 0.9) end
		FX.shake(deck, 0.5, 0.25)
		VS.cheer(deck, 1.5)
	elseif r == "early" then
		-- 支架已经提前夹上：火箭砸在夹爪上弹一下
		local cf = S.rocket:GetPivot()
		task.spawn(function()
			local t0 = os.clock()
			while os.clock() - t0 < 0.42 do
				local u = (os.clock() - t0) / 0.42
				S.rocket:PivotTo(cf + V(0, 1.4 * math.sin(u * math.pi) * (1 - u * 0.5), 0))
				task.wait()
			end
			S.rocket:PivotTo(cf)
			if S.arms then -- 弹完再夹紧
				local t1 = os.clock()
				while os.clock() - t1 < 0.15 do
					CA.setPose(S.arms, 0.7 + ((S.closeTo or 0) - 0.7) * smooth((os.clock() - t1) / 0.15))
					task.wait()
				end
				CA.setPose(S.arms, S.closeTo or 0)
				for _, p in ipairs(clawPoints(S.arms, deck)) do FX.sparks(p, 12, 0.6) end
			end
		end)
		for _, p in ipairs(pts) do FX.sparks(p, 14, 0.7) end
		FX.puff(deck + V(0, 1, 0), 20, B.hex("C8CDE6"), 14, 3, { life = 1.4, influence = 1 })
		FX.shake(deck, 0.6, 0.3)
	end
end

return C
