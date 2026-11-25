--[[
	CatchZone · 发射台接住区光柱（ReplicatedStorage.OrbitShared.CatchZone）
	返航后段在发射台上升起半透明光柱：底部绿区 = 完美窗口（高度随支架等级变高），上方黄区 = 良好；
	火箭底部一圈白色光环，进入黄区变黄、进入绿区变绿。Web Demo 半径 3.3。
	用 CylinderHandleAdornment（光柱实心、圆环用 InnerRadius）：无零件、不受光照，像全息光。
	Z.build(deckCF, parent)：deckCF = 发射台台面中心；默认隐藏。
	Z.set(zone, { visible, green, yellow, base, state })：green / yellow = 两段顶部高度（离台面），
	base = 火箭底部高度，state = "none" | "yellow" | "green"（决定底环颜色和光柱闪亮）。
]]

local B = require(script.Parent.BuildLib)
local hex = B.hex

local Z = {}
Z.R = 3.3
Z.GREEN = hex("3BD85C")
Z.YELLOW = hex("FFCC33")
Z.WHITE = Color3.new(1, 1, 1)
Z.DEFAULT_SPEED = 22 -- 落台前火箭下降速度（studs/s），用来把时间窗口换算成高度

-- 完美窗口（秒）换算成光柱高度；黄区比绿区多 0.4 s
function Z.heightsFor(win, speed)
	speed = speed or Z.DEFAULT_SPEED
	return win * speed, (win + 0.4) * speed
end

local UP = CFrame.Angles(math.pi / 2, 0, 0) -- 圆柱装饰的轴默认沿 Z，转成沿 Y

local function adorn(anchor, name, radius, inner, height, color, tr)
	local a = Instance.new("CylinderHandleAdornment")
	a.Name = name
	a.Adornee = anchor
	a.Radius = radius
	a.InnerRadius = inner
	a.Height = height
	a.CFrame = UP
	a.Color3 = color
	a.Transparency = tr
	a.AlwaysOnTop = false
	a.ZIndex = 0
	a:SetAttribute("BaseTransparency", tr)
	a.Parent = anchor
	return a
end

function Z.build(deckCF, parent)
	local m = B.model("CatchZone")
	local anchor = B.part({ Name = "ZoneAnchor", Size = Vector3.new(0.2, 0.2, 0.2), CFrame = deckCF, Transparency = 1, CastShadow = false }, m)
	B.deco(anchor)
	-- 光柱用实心圆柱（InnerRadius = 0）：细壁高筒会在屏幕上画出横贯全屏的细线（11-24 实测）
	adorn(anchor, "GreenColumn", Z.R, 0, 1, Z.GREEN, 0.78)
	adorn(anchor, "YellowColumn", Z.R, 0, 1, Z.YELLOW, 0.8)
	adorn(anchor, "GreenRing", Z.R + 0.14, Z.R - 0.12, 0.22, Z.GREEN, 0.1)
	adorn(anchor, "YellowRing", Z.R + 0.14, Z.R - 0.12, 0.22, Z.YELLOW, 0.1)
	adorn(anchor, "BaseRing", 2.6, 2.2, 0.22, Z.WHITE, 0.05)
	m.WorldPivot = deckCF
	m.Parent = parent
	Z.set(m, { visible = false, green = 3.5, yellow = 12.3, base = 14 })
	return m
end

function Z.set(m, o)
	local anchor = m:FindFirstChild("ZoneAnchor")
	if not anchor then return end
	local g = o.green or m:GetAttribute("Green") or 3.5
	local y = math.max(o.yellow or m:GetAttribute("Yellow") or g + 8, g + 0.4)
	local base = o.base or m:GetAttribute("Base") or y + 2
	local state = o.state or "none"
	local visible = o.visible ~= false
	local function get(n) return anchor:FindFirstChild(n) end

	local gc, yc = get("GreenColumn"), get("YellowColumn")
	gc.Height = g
	gc.CFrame = CFrame.new(0, g / 2, 0) * UP
	yc.Height = y - g
	yc.CFrame = CFrame.new(0, g + (y - g) / 2, 0) * UP
	get("GreenRing").CFrame = CFrame.new(0, g, 0) * UP
	get("YellowRing").CFrame = CFrame.new(0, y, 0) * UP
	local br = get("BaseRing")
	br.CFrame = CFrame.new(0, math.max(0.1, base), 0) * UP
	br.Color3 = (state == "green" and Z.GREEN) or (state == "yellow" and Z.YELLOW) or Z.WHITE
	-- 火箭底部所在的区段更亮
	gc.Transparency = (state == "green") and 0.6 or gc:GetAttribute("BaseTransparency")
	yc.Transparency = (state == "yellow") and 0.66 or yc:GetAttribute("BaseTransparency")
	for _, a in ipairs(anchor:GetChildren()) do
		if a:IsA("HandleAdornment") then a.Visible = visible end
	end
	m:SetAttribute("Green", g)
	m:SetAttribute("Yellow", y)
	m:SetAttribute("Base", base)
	m:SetAttribute("State", state)
	m:SetAttribute("Visible", visible)
end

return Z
