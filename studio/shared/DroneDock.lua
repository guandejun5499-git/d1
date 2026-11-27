-- ModuleScript. The supplied pivot is the centre of the dock's underside.
local Dock = {}

local TIER_COLOR = {
	Color3.fromRGB(200, 203, 221),
	Color3.fromRGB(250, 191, 44),
	Color3.fromRGB(68, 132, 246),
	Color3.fromRGB(255, 142, 39),
}

local FOOT = Color3.fromRGB(35, 37, 51)
local GRAPHITE = Color3.fromRGB(52, 56, 81)
local SHOULDER = Color3.fromRGB(73, 78, 107)
local WELL = Color3.fromRGB(29, 44, 61)
local CYAN = Color3.fromRGB(48, 224, 255)
local AMBER = Color3.fromRGB(255, 186, 60)
local SHELL = Enum.Material.SmoothPlastic
local METAL = Enum.Material.Metal

function Dock.build(tier: number, pivot: CFrame, parent: Instance): Model
	local accent = TIER_COLOR[tier]
	assert(accent, "Dock.build expects an integer tier from 1 to 4")
	local dock = Instance.new("Model")
	dock.Name = "RepairDroneDock_L" .. tier
	dock:SetAttribute("Tier", tier)

	local function part(name, size, localCF, color, material, shape, collidable)
		local item = Instance.new("Part")
		item.Name = name
		item.Shape = shape
		item.Size = size
		item.CFrame = pivot * localCF
		item.Color = color
		item.Material = material
		item.Anchored = true
		item.CanCollide = collidable
		item.CanQuery = collidable
		item.CanTouch = false
		item.CastShadow = material ~= Enum.Material.Neon
		item.TopSurface = Enum.SurfaceType.Smooth
		item.BottomSurface = Enum.SurfaceType.Smooth
		item.Parent = dock
		return item
	end

	local function disc(name, diameter, height, centreY, color, material, collidable)
		-- Roblox cylinders have a local X axis.
		return part(name, Vector3.new(height, diameter, diameter),
			CFrame.new(0, centreY, 0) * CFrame.Angles(0, 0, math.pi / 2),
			color, material, Enum.PartType.Cylinder, collidable)
	end

	local function tile(name, size, localCF, color, material)
		return part(name, size, localCF, color, material, Enum.PartType.Block, false)
	end

	disc("Undersole", 7.64, 0.16, 0.08, FOOT, SHELL, true)
	disc("GraphiteDrum", 7.8, 0.43, 0.365, GRAPHITE, SHELL, true)
	disc("UpperShoulder", 7.43, 0.15, 0.645, SHOULDER, SHELL, true)
	disc("ServiceDeck", 7.0, 0.10, 0.76, GRAPHITE, METAL, true)
	disc("DockingWell", 5.34, 0.04, 0.815, WELL, SHELL, false)

	-- Two concentric, continuous discs give a clean luminous ring at any camera angle.
	disc("GuidanceRing", 3.36, 0.034, 0.843, CYAN, Enum.Material.Neon, false)
	disc("LandingTarget", 3.03, 0.032, 0.860, WELL, SHELL, false)

	for index = 1, 4 do
		-- The four large corner pieces leave the centre clear for a downward-facing tool.
		local radial = CFrame.Angles(0, math.rad(45 + 90 * (index - 1)), 0)
		tile("Skirt" .. index, Vector3.new(1.02, 0.47, 0.36),
			radial * CFrame.new(0, 0.39, -3.675), accent, SHELL)
		tile("SlopedShoulder" .. index, Vector3.new(1.02, 0.15, 0.87),
			radial * CFrame.new(0, 0.70, -3.41) * CFrame.Angles(math.rad(-21), 0, 0),
			accent, SHELL)
		tile("InnerShoe" .. index, Vector3.new(1.02, 0.095, 0.47),
			radial * CFrame.new(0, 0.853, -2.87), accent, SHELL)
	end

	for index = 1, 4 do
		local radial = CFrame.Angles(0, math.rad(90 * (index - 1)), 0)
		tile("LampBezel" .. index, Vector3.new(0.75, 0.18, 0.085),
			radial * CFrame.new(0, 0.645, -3.715), FOOT, SHELL)
		tile("Marker" .. index, Vector3.new(0.46, 0.07, 0.045),
			radial * CFrame.new(0, 0.645, -3.758), AMBER, Enum.Material.Neon)
	end

	dock.WorldPivot = pivot
	dock.Parent = parent
	return dock
end

return Dock
