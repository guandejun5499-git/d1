--[[
	Orbits · 星球、轨道、轨道门位置与航线（ReplicatedStorage.OrbitShared.Orbits）
	数值沿用 Web Demo 的 BODIES，并乘以 11-25 场景放大系数 1.3（世界原点 = 广场中心）。
	轨道：p(a) = c + u·orbit·cos a + v·orbit·sin a；轨道门在 a0，门面法线 = 该点切线（飞行方向）。
	星尘碎片：每圈 36% / 64% 处各一颗，径向偏移 ±13% 轨道半径、竖直偏移 ∓7%。
	月球 → 木星转场：三次贝塞尔，从月球门出发沿切线飞出 80·S，再从木星门反切线方向 200·S 接入。
]]

local O = {}
O.S = 1.3
local S = O.S
local V = Vector3.new

O.bodies = {
	moon = {
		key = "moon", name = "月球",
		c = V(-50, 190, -60) * S, r = 28 * S, orbit = 52 * S,
		u = Vector3.xAxis, v = V(0, -0.3, 1).Unit,
		a0 = math.pi / 2, gateR = 7 * S, base = 10, orbitDur = 6,
	},
	jupiter = {
		key = "jupiter", name = "木星",
		c = V(170, 400, -220) * S, r = 72 * S, orbit = 115 * S,
		u = Vector3.xAxis, v = V(0, -0.25, 1).Unit,
		a0 = math.pi, gateR = 11 * S, base = 60, orbitDur = 8,
	},
}

function O.pt(b, a)
	return b.c + b.u * (b.orbit * math.cos(a)) + b.v * (b.orbit * math.sin(a))
end

function O.tan(b, a)
	return (b.u * -math.sin(a) + b.v * math.cos(a)).Unit
end

-- 轨道门框架：原点在门心，−Z（LookVector）= 飞行方向，门环在本地 XY 平面
function O.gateCF(b)
	local p = O.pt(b, b.a0)
	local t = O.tan(b, b.a0)
	local up = (p - b.c).Unit -- 门的「上」指向星球外侧
	return CFrame.lookAt(p, p + t, up)
end

-- 一圈里的两颗星尘碎片位置（lap 从 0 开始）
function O.shardPoints(b)
	local out = {}
	for i, u in ipairs({ 0.36, 0.64 }) do
		local p = O.pt(b, b.a0 + math.pi * 2 * u)
		local rad = (p - b.c).Unit
		local sgn = (i == 1) and 1 or -1
		out[i] = p + rad * (sgn * b.orbit * 0.13) + V(0, -sgn * b.orbit * 0.07, 0)
	end
	return out
end

-- 碎片尺寸（Web：月球 1.3、木星 2.4，八面体半径 1.5，乘放大系数）
function O.shardSize(b)
	return (b.key == "jupiter" and 2.4 or 1.3) * 1.5 * S
end

local function bez3(p0, p1, p2, p3, t)
	local m = 1 - t
	return p0 * (m * m * m) + p1 * (3 * m * m * t) + p2 * (3 * m * t * t) + p3 * (t * t * t)
end

-- 月球 → 木星转场航线上的点（t ∈ [0, 1]）
function O.transfer(t)
	local mo, ju = O.bodies.moon, O.bodies.jupiter
	local p0 = O.pt(mo, mo.a0)
	local e = O.pt(ju, ju.a0)
	local p1 = p0 + O.tan(mo, mo.a0) * (80 * S)
	local p2 = e - O.tan(ju, ju.a0) * (200 * S)
	return bez3(p0, p1, p2, e, t)
end

return O
