--[[
	VisitorShow · P1 第 19 项 围观访客动作（ReplicatedStorage.OrbitShared.VisitorShow）
	客户端本地。访客由 13_visitors 建（Home_K.Visitors，标签 Visitor，根部锚定 + Motor6D），这里只改根部 CFrame 和关节 Transform。
	动作（Web Demo updateSpectators / updateRagdoll，距离 / 速度 ×1.3）：
	  待机：双臂轻摆、面朝发射台
	  欢呼 VS.cheer(pos, dur)：双手举过头挥动、原地蹦、抬头看天；pos 60 格内的访客
	  掀翻 VS.knock(pos, power)：pos 半径 RAG_R（32.5）内的访客被抛起（越近越猛），空中翻滚、四肢乱甩，
	      落地弹一下 → 仰面躺 1.4 s（手脚摊开）→ 0.45 s 爬起 → 走回原位（11.7 格/秒）→ 转回面朝发射台
	      （被掀翻期间攒下的欢呼，回到原位后接着欢呼）
	VS.start()：开始每帧更新（Visitors.client.lua 调）；没 start 时 cheer / knock 什么也不做（Edit 里逐帧检查演出不受影响）。
	挂钩：LaunchShow 点火（超级：knock 48 + 欢呼 3 s；完美 2 s；普通 1.5 s；熄火 1 s）、
	      CatchShow 落台（完美 2 s，连击 ≥ 3 为 3 s；漂亮 1.5 s）、CrashShow 爆炸（knock 30 + 欢呼 2.5 s）。
]]

local RunService = game:GetService("RunService")
local CS = game:GetService("CollectionService")

local V = Vector3.new
local VS = {}
local S = 1.3
VS.RAG_R = 25 * S
VS.CHEER_R = 60
local GRAV = 90 * S
local WALK = 9 * S
local LIE_Y = 0.55 -- 仰面躺时根部中心离地

local list = {} -- [model] = rec
local started = false
local clock = 0

local function clamp01(x) return math.clamp(x, 0, 1) end
local function lerp(a, b, u) return a + (b - a) * u end
local function smooth(u)
	u = clamp01(u)
	return u * u * (3 - 2 * u)
end
local function angLerp(a, b, u)
	local d = (b - a + math.pi) % (2 * math.pi) - math.pi
	return a + d * u
end
local function yawOf(cf)
	local l = cf.LookVector
	return math.atan2(-l.X, -l.Z)
end

local JOINTS = { "LeftShoulder", "RightShoulder", "LeftElbow", "RightElbow", "LeftHip", "RightHip", "LeftKnee", "RightKnee", "Neck", "Waist" }

local function add(m)
	if list[m] then return end
	local hrp = m:FindFirstChild("HumanoidRootPart")
	local home = m:GetAttribute("HomeCF")
	if not hrp or not home then return end
	local rec = {
		m = m, hrp = hrp, home = home, off = m:GetAttribute("GroundOffset") or 3,
		pos = home.Position, yaw = yawOf(home), face = yawOf(home),
		cheer = 0, walk = 0, ph = math.random() * 6, j = {}, a = {},
	}
	for _, n in ipairs(JOINTS) do
		local j = m:FindFirstChild(n, true)
		if j and j:IsA("Motor6D") then rec.j[n] = j end
		rec.a[n] = { 0, 0 } -- { 绕 X（向前抬），绕 Z（侧展）}
	end
	rec.rp = RaycastParams.new()
	rec.rp.FilterType = Enum.RaycastFilterType.Exclude
	list[m] = rec
end

local function remove(m) list[m] = nil end

-- 射线排除所有访客（新版 R15 身体件在客户端仍能被射线命中，会撞到自己）、演出碎块 / 火花 / 彩纸（_ShowFX）、流星和玩家角色
local function refreshFilter(r)
	local ex = {}
	for m in pairs(list) do table.insert(ex, m) end
	for _, n in ipairs({ "_ShowFX", "_Meteors" }) do
		local f = workspace:FindFirstChild(n)
		if f then table.insert(ex, f) end
	end
	local plr = game:GetService("Players").LocalPlayer
	if plr and plr.Character then table.insert(ex, plr.Character) end
	r.rp.FilterDescendantsInstances = ex
end

------------------------------------------------------------------ 触发
function VS.cheer(pos, dur, radius)
	if not started then return end
	radius = radius or VS.CHEER_R
	for _, r in pairs(list) do
		if (V(r.pos.X - pos.X, 0, r.pos.Z - pos.Z)).Magnitude < radius then r.cheer = math.max(r.cheer, dur) end
	end
end

function VS.knock(from, power, radius)
	if not started then return end
	radius = radius or VS.RAG_R
	for _, r in pairs(list) do
		local d = V(r.pos.X - from.X, 0, r.pos.Z - from.Z)
		local dist = math.max(1, d.Magnitude)
		if dist < radius then
			if d.Magnitude < 1e-3 then -- 正好在冲击点上：随便挑一个水平方向（零向量取 Unit 会得到 NaN）
				local a = math.random() * math.pi * 2
				d = V(math.cos(a), 0, math.sin(a))
			else
				d = d.Unit
			end
			local f = power * S * (0.45 + 0.55 * clamp01(1 - dist / radius))
			r.rd = {
				phase = "fly", t = 0,
				vel = V(d.X * f * 0.6, f, d.Z * f * 0.6),
				spin = V((math.random() < 0.5 and -1 or 1) * (7 + math.random() * 6), 0, (math.random() - 0.5) * 9),
				rx = 0, rz = 0, y = r.off,
			}
			r.yaw = math.atan2(-d.X, -d.Z) + math.pi -- 背朝冲击方向被掀
			refreshFilter(r)
		end
	end
end

------------------------------------------------------------------ 每帧
local function ground(r, p)
	local hit = workspace:Raycast(p + V(0, 3, 0), V(0, -40, 0), r.rp)
	return hit and hit.Position.Y or r.home.Position.Y
end

local function dust(p, n)
	local ok, FX = pcall(require, script.Parent.ShowFX)
	if ok then FX.puff(p + V(0, 0.4, 0), n, Color3.fromRGB(200, 205, 230), 3 * S, 2.6, { life = 0.9, influence = 1 }) end
end

-- target：{ [joint] = { x, z } }；snap = true 时直接设，否则平滑过去
local function pose(r, target, dt, snap)
	local k = snap and 1 or (1 - math.exp(-dt * 14))
	for _, n in ipairs(JOINTS) do
		local a, t = r.a[n], target[n] or { 0, 0 }
		a[1] = lerp(a[1], t[1], k)
		a[2] = lerp(a[2], t[2], k)
		local j = r.j[n]
		if j then j.Transform = CFrame.Angles(0, 0, a[2]) * CFrame.Angles(a[1], 0, 0) end
	end
end

local function place(r, yOff, rx, rz)
	r.hrp.CFrame = CFrame.new(r.pos) * CFrame.Angles(0, r.yaw, 0) * CFrame.new(0, yOff, 0) * CFrame.Angles(rx or 0, 0, rz or 0)
end

local function updateRagdoll(r, dt)
	local d = r.rd
	d.t += dt
	if d.phase == "fly" then
		d.vel -= V(0, GRAV * dt, 0)
		local step = V(d.vel.X, 0, d.vel.Z) * dt
		if step.Magnitude > 1e-3 then
			-- 撞墙，或下一步脚下没地面（岛边 / 桥边，Web 的 walkable）→ 水平速度反弹
			local hit = workspace:Raycast(r.pos + V(0, 2, 0), step + step.Unit * 1, r.rp)
			local floor = hit or workspace:Raycast(r.pos + step + V(0, 3, 0), V(0, -60, 0), r.rp)
			if hit or not floor then
				r.lastHit = hit and hit.Instance:GetFullName() or "edge"
				d.vel = V(-d.vel.X * 0.45, d.vel.Y, -d.vel.Z * 0.45)
			else
				r.pos += step
			end
		end
		r.pos += V(0, d.vel.Y * dt, 0)
		d.rx += d.spin.X * dt
		d.rz += d.spin.Z * dt
		local t = d.t
		pose(r, {
			LeftShoulder = { math.sin(t * 26) * 1.6, -0.5 }, RightShoulder = { math.cos(t * 23) * 1.6, 0.5 },
			LeftHip = { math.sin(t * 19) * 1.1, 0 }, RightHip = { math.cos(t * 21) * 1.1, 0 },
			LeftKnee = { -0.6, 0 }, RightKnee = { -0.6, 0 }, LeftElbow = { 0.6, 0 }, RightElbow = { 0.6, 0 },
		}, dt, true)
		local g = ground(r, r.pos)
		if r.pos.Y <= g and d.vel.Y < 0 then
			r.pos = V(r.pos.X, g, r.pos.Z)
			if math.abs(d.vel.Y) > 16 * S then
				d.vel = V(d.vel.X * 0.6, -d.vel.Y * 0.35, d.vel.Z * 0.6)
				d.spin *= 0.5
				dust(r.pos, 3)
			else
				d.phase, d.t, d.fx, d.fz = "lie", 0, d.rx, d.rz
				dust(r.pos, 5)
			end
		end
		place(r, r.off, d.rx, d.rz)
	elseif d.phase == "lie" then
		local u = math.min(1, d.t / 0.25)
		d.rx = angLerp(d.fx, math.pi / 2, u)
		d.rz = angLerp(d.fz, 0, u)
		pose(r, {
			LeftShoulder = { 2.8, 0.6 }, RightShoulder = { 2.8, -0.6 },
			LeftHip = { 0.2, -0.15 }, RightHip = { -0.2, 0.15 },
		}, dt)
		place(r, lerp(r.off, LIE_Y, u), d.rx, d.rz)
		if d.t > 1.4 then d.phase, d.t = "up", 0 end
	else
		local u = math.min(1, d.t / 0.45)
		pose(r, {}, dt)
		place(r, lerp(LIE_Y, r.off, u) + math.sin(u * math.pi) * 0.8 * S, lerp(math.pi / 2, 0, smooth(u)), 0)
		if u >= 1 then r.rd = nil end
	end
end

local function update(r, dt)
	if r.rd then
		updateRagdoll(r, dt)
		return
	end
	local hp = r.home.Position
	local to = V(hp.X - r.pos.X, 0, hp.Z - r.pos.Z)
	local dist = to.Magnitude
	if dist > 0.6 then -- 走回原位
		local st = math.min(dist, WALK * dt)
		r.pos += to.Unit * st
		r.pos = V(r.pos.X, ground(r, r.pos), r.pos.Z)
		r.yaw = angLerp(r.yaw, math.atan2(-to.X, -to.Z), 1 - math.exp(-dt * 12))
		r.walk += dt * 10
		local sw = math.sin(r.walk) * 0.8
		pose(r, {
			LeftShoulder = { sw, 0 }, RightShoulder = { -sw, 0 },
			LeftHip = { -sw, 0 }, RightHip = { sw, 0 },
			LeftKnee = { -math.max(0, sw) * 0.8, 0 }, RightKnee = { -math.max(0, -sw) * 0.8, 0 },
			LeftElbow = { 0.3, 0 }, RightElbow = { 0.3, 0 },
		}, dt)
		place(r, r.off + math.abs(math.sin(r.walk)) * 0.15)
		return
	end
	r.pos = V(hp.X, hp.Y, hp.Z)
	r.yaw = angLerp(r.yaw, r.face, 1 - math.exp(-dt * 6))
	if r.cheer > 0 then
		r.cheer -= dt
		local w = math.sin(clock * 14 + r.ph)
		pose(r, {
			LeftShoulder = { 2.7 + w * 0.3, 0.35 }, RightShoulder = { 2.7 - w * 0.3, -0.35 },
			LeftElbow = { 0.25, 0 }, RightElbow = { 0.25, 0 },
			Neck = { 0.35, 0 },
		}, dt)
		place(r, r.off + math.max(0, math.sin(clock * 9 + r.ph)) * 0.6 * S)
	else
		local s = math.sin(clock * 1.5 + r.ph) * 0.1
		pose(r, {
			LeftShoulder = { s, -0.05 }, RightShoulder = { -s, 0.05 },
			LeftElbow = { 0.12, 0 }, RightElbow = { 0.12, 0 },
			Neck = { 0.08 + math.sin(clock * 0.7 + r.ph) * 0.05, 0 },
		}, dt)
		place(r, r.off + math.sin(clock * 2.2 + r.ph) * 0.03)
	end
end

function VS.start()
	if started then return end
	started = true
	for _, m in ipairs(CS:GetTagged("Visitor")) do add(m) end
	CS:GetInstanceAddedSignal("Visitor"):Connect(function(m) task.defer(add, m) end)
	CS:GetInstanceRemovedSignal("Visitor"):Connect(remove)
	-- 仅 Studio：测试用触发口（命令栏 / MCP 在另一个 require 实例里，拿不到这里的状态）
	-- workspace._VisitorDebug:Fire("knock", pos, power) / ("cheer", pos, dur) / ("dump") → 写回属性 Dump
	if RunService:IsStudio() then
		local be = Instance.new("BindableEvent")
		be.Name = "_VisitorDebug"
		be.Archivable = false
		be.Event:Connect(function(cmd, a, b)
			if cmd == "knock" then VS.knock(a, b)
			elseif cmd == "cheer" then VS.cheer(a, b)
			elseif cmd == "dump" then
				local t = {}
				for m, r in pairs(list) do
					table.insert(t, string.format("%s pos(%.1f,%.1f,%.1f) %s", m.Name, r.pos.X, r.pos.Y, r.pos.Z, r.rd and r.rd.phase or (r.cheer > 0 and "cheer" or "idle")) .. (r.lastHit and (" hit " .. r.lastHit) or ""))
				end
				be:SetAttribute("Dump", table.concat(t, " | "))
			end
		end)
		be.Parent = workspace
	end
	RunService.RenderStepped:Connect(function(dt)
		clock += dt
		local cam = workspace.CurrentCamera
		local cp = cam and cam.CFrame.Position
		for m, r in pairs(list) do
			if not m.Parent or not r.hrp.Parent then
				list[m] = nil
			elseif r.rd or r.cheer > 0 or not cp or (r.pos - cp).Magnitude < 260 then
				update(r, math.min(dt, 1 / 20))
			end
		end
	end)
end

return VS
