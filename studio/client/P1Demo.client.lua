-- P1Demo · P1 演出验收循环（StarterPlayer.StarterPlayerScripts，验收完删除）
-- Workspace 属性 P1Demo = true 时才跑，在家园 0 轮流播放：
--   第 13 项 Roll 揭晓（随机结果，概率同正式 55 / 35 / 10）→ 买下最好的一件（光球飞进玩家）
--   第 12 项 组装演出（四种组合轮流，先把部件放进部件坞）
--   第 14 项 点火与发射（按住点火的蓄力按 Web Demo 的 2.3 s 一圈模拟：完美 / 超级发射 / 超载熄火 轮流），
--   第 15 项 飞行表现：升空后接着飞月球两圈（完美 / 超级那一轮第二圈进入轨道狂热）→ 返航降落；
--          同时邻居家园 1 的火箭也起飞（带狂热），看邻居的彩虹尾迹
-- 只改本地显示：台上旧火箭会在本地被新火箭替换。

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

if not workspace:GetAttribute("P1Demo") then return end

local SH = ReplicatedStorage:WaitForChild("OrbitShared")
local B = require(SH:WaitForChild("BuildLib"))
local AB = require(SH:WaitForChild("AssemblyBay"))
local AS = require(SH:WaitForChild("AssemblyShow"))
local PP = require(SH:WaitForChild("PartPad"))
local RR = require(SH:WaitForChild("RollReveal"))
local LS = require(SH:WaitForChild("LaunchShow"))
local FX = require(SH:WaitForChild("ShowFX"))
local FS = require(SH:WaitForChild("FlightShow"))

local home = workspace:WaitForChild("OrbitWorld"):WaitForChild("Homes"):WaitForChild("Home_0")
local bay = home:WaitForChild("AssemblyBay")
local rollArea = home:WaitForChild("RollArea")
local launchArea = home:WaitForChild("LaunchArea")

local EQS = {
	{ nose = 1, tank = 1, engine = 1, fins = 1 },
	{ nose = 2, tank = 2, engine = 2, fins = 2 },
	{ nose = 3, tank = 3, engine = 3, fins = 3 },
	{ nose = 2, tank = 3, engine = 1, fins = 3 },
}
local color = B.homeColor(0)

local function rollTier()
	local r = math.random(100)
	return (r <= 55) and 1 or (r <= 90) and 2 or 3
end

local function demoRoll()
	local res = {}
	for _, s in ipairs(PP.SLOTS) do res[s] = rollTier() end
	RR.play(rollArea, res, { homeColor = color })
	task.wait(0.8)
	-- 买下最好的一件（基础件不出售）
	local best, bestT
	for i = 1, 4 do
		local p = rollArea:FindFirstChild("PartPad_" .. i)
		local t = p and tonumber(tostring(p:GetAttribute("State")):match("Tier(%d)"))
		if t and t > 1 and (not bestT or t > bestT) then best, bestT = p, t end
	end
	local ch = Players.LocalPlayer.Character
	local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
	if best then RR.buy(best, hrp or rollArea:GetPivot().Position, { homeColor = color }) end
end

local function demoAssemble(eq)
	for k, slot in ipairs(AB.SLOTS) do
		AB.setDock(bay, k, eq[slot], color)
	end
	AB.setStatus(bay, "ready", 4)
	AB.setHolo(bay, eq, color)
	task.wait(2)
	AS.play(bay, eq, color)
end

-- 点火蓄力：一圈 2.3 s；完美 = 第一圈 85% 松手，超级 = 第三圈（彩虹区）85% 松手，超载 = 撑满三圈自动熄火
local CYCLE = 2.3
local HOLD = { perfect = 0.85 * CYCLE, super = 2.85 * CYCLE, stall = 3 * CYCLE }
local JUDGES = { "perfect", "super", "stall" }
local function demoLaunch(judge)
	launchArea:WaitForChild("PadRocket", 5)
	local S = LS.prepare(launchArea)
	local t0 = os.clock()
	while os.clock() - t0 < HOLD[judge] do
		local t = os.clock() - t0
		S:charge((t % CYCLE) / CYCLE, math.min(2, math.floor(t / CYCLE)))
		task.wait()
	end
	-- 邻居家园 1 的火箭同时起飞（带狂热），从自家看它的彩虹尾迹
	local nb = workspace.OrbitWorld.Homes:FindFirstChild("Home_1")
	local nRocket = nb and nb:FindFirstChild("PadRocket", true)
	if nRocket then
		task.spawn(function()
			local N = FS.prepare(nRocket, nRocket:GetPivot(), { { body = "moon", orbits = 2, fever = { [1] = true, [2] = true } } }, { fromPad = true, speed = 1.1, worldFever = false })
			local ok, err = pcall(N.play, N)
			if not ok then warn("[P1Demo] neighbor flight", err) end
			N:cleanup()
		end)
	end
	S:launch(judge)
	S:destroy()
	-- 第 15 项：接着飞
	local rocket = launchArea:FindFirstChild("PadRocket")
	-- 起飞前的比例和支架夹紧角都由 LaunchShow 记下，交给飞行（宽火箭降落时支架不能合到 0）
	local F = FS.prepare(rocket, S.home, { { body = "moon", orbits = 2, fever = { [2] = judge ~= "stall" } } },
		{ launchArea = launchArea, scale0 = S.scale0, catchClosed = S.catchPose0 })
	F:play()
	FX.puff(S.base + Vector3.new(0, 1.5, 0), 16, Color3.fromRGB(214, 217, 234), 8, 3, { life = 1.4, influence = 1 })
	F:cleanup()
end

task.wait(3)
local i = 0
while true do
	local ok, err = pcall(demoRoll)
	if not ok then warn("[P1Demo] RollReveal", err) end
	task.wait(2)
	i = i % #EQS + 1
	ok, err = pcall(demoAssemble, EQS[i])
	if not ok then warn("[P1Demo] AssemblyShow", err) end
	task.wait(1.5)
	ok, err = pcall(demoLaunch, JUDGES[(i - 1) % #JUDGES + 1])
	if not ok then warn("[P1Demo] LaunchShow", err) end
	task.wait(3)
end
