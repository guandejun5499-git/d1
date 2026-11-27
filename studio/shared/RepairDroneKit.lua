-- E1 repair drones. Local -Z is the face; pivot is at the centre of the head.
-- RepairEmitter points down via its local -Z; WeldTip points along the stylus.
local CollectionService = game:GetService("CollectionService")
local Kit = {}
local v, cf = Vector3.new, CFrame.new
local rad, sin, cos, pi = math.rad, math.sin, math.cos, math.pi
local smooth, neon, metal = Enum.Material.SmoothPlastic, Enum.Material.Neon, Enum.Material.Metal
local ball, drum = Enum.PartType.Ball, Enum.PartType.Cylinder
local ivory = Color3.fromRGB(240, 238, 225)
local cream = Color3.fromRGB(204, 208, 218)
local dark = Color3.fromRGB(42, 50, 75)
local slate = Color3.fromRGB(76, 86, 114)
local screen = Color3.fromRGB(12, 23, 39)
local cyan = Color3.fromRGB(39, 224, 247)
local amber = Color3.fromRGB(255, 167, 57)
local tip = Color3.fromRGB(255, 204, 113)
local paint = {
	Color3.fromRGB(187, 194, 207),
	Color3.fromRGB(255, 191, 47),
	Color3.fromRGB(96, 135, 226),
	Color3.fromRGB(247, 156, 47),
}
local names = {"Basic", "Fitter", "Welder", "Industrial"}
local up = v(0,1,0)
local down = CFrame.Angles(-pi/2, 0, 0)
local cylY = CFrame.Angles(0, 0, pi/2)

local function group(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function part(parent, name, size, frame, color, shape, material)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color = name, size, frame, color
	p.Material = material or smooth
	if shape then p.Shape = shape end
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
	p.CastShadow = p.Material ~= neon
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function disc(m, name, frame, diameter, height, color, material)
	return part(m,name,v(height,diameter,diameter),frame*cylY,color,drum,material)
end

local function ellipsoid(m,name,pos,size,color,material)
	return part(m,name,size,cf(pos),color,ball,material)
end

local function rod(m, name, a, b, w, h, color, material)
	local delta = b-a
	return part(m,name,v(w,h,delta.Magnitude),CFrame.lookAt((a+b)/2,b),color,nil,material)
end

local function joint(m,name,pos,size,color)
	return ellipsoid(m,name,pos,v(size,size,size),color,metal)
end

local function attach(p, name, world)
	local a = Instance.new("Attachment")
	a.Name, a.CFrame = name, p.CFrame:ToObjectSpace(world)
	a.Parent = p
	return a
end

local function hoop(m, center, radius, width, height, color)
	-- Open ring assembled from short rim segments so the actual blades show through.
	local count = 14
	local halfAngle = pi/count
	for i=0,count-1 do
		local angle = i*2*halfAngle
		local frame = cf(center)*CFrame.Angles(0,angle,0)*cf(0,0,radius)
		part(m,"Rim",v(2*(radius+width/2)*math.tan(halfAngle),height,width),frame,color)
	end
end

local function propeller(m, sign, tier, accent)
	local side = sign < 0 and "Port" or "Starboard"
	local x = tier == 1 and 1.77 or 1.88
	local pos = v(sign*x,1.38,0.11)
	local mount = v(sign*0.84,0.46,0.16)
	local motor = pos-up*0.10
	rod(m,side.."Pylon",mount,motor,0.23,0.22,slate)
	joint(m,side.."Pivot",mount,0.34,accent)
	disc(m,side.."Motor",cf(motor),0.47,0.36,slate)
	local support = group(m,side.."RotorGuard")
	hoop(support,pos,tier==1 and 0.78 or 0.84,tier==1 and 0.09 or 0.18,tier==1 and 0.11 or 0.23,accent)
	-- Two slim fixed spokes tie the surrounding guard into the motor.
	for _,z in ipairs({-1,1}) do
		local from = motor + v(0,0.01,z*0.15)
		local to = pos + v(0,-0.06,z*(tier==1 and 0.78 or 0.84))
		rod(support,"GuardSpoke",from,to,0.065,0.055,slate)
	end
	local rotor = group(m,side.."Rotor")
	local spinAt = cf(pos)
	for i=0,2 do
		local bladeFrame=spinAt*CFrame.Angles(0,(2*pi/3)*i,0)*cf(0,0.035,-0.41)*CFrame.Angles(0,rad(8),0)
		part(rotor,"Blade",v(0.17,0.055,0.67),bladeFrame,cream)
	end
	disc(rotor,"Hub",spinAt*cf(0,0.07,0),0.37,0.12,ivory)
	rotor.WorldPivot = spinAt
	rotor:SetAttribute("SpinSpeed",sign*26)
	rotor:SetAttribute("SpinFollowParent",true)
	CollectionService:AddTag(rotor,"SpinFX")
end

local function hoverPod(m, name, pos, mount, radius, accent, tier)
	local pod = group(m,name)
	pod:SetAttribute("ModuleType","HoverThruster")
	rod(pod,"Support",mount,pos-up*0.12,0.27,0.27,accent)
	joint(pod,"Hinge",mount,0.39,slate)
	local seat = cf(pos)
	disc(pod,"UpperCap",seat*cf(0,0.145,0),2*radius*0.90,0.16,ivory)
	disc(pod,"Rim",seat,2*radius,0.25,tier==4 and slate or cream)
	disc(pod,"Underside",seat*cf(0,-0.145,0),2*radius*0.92,0.13,dark)
	disc(pod,"LiftRing",seat*cf(0,-0.224,0),2*radius*0.81,0.045,cyan,neon)
	disc(pod,"RingInset",seat*cf(0,-0.255,0),2*radius*0.58,0.055,dark)
	local nozzle = disc(pod,"LiftCore",seat*cf(0,-0.292,0),2*radius*0.29,0.08,cyan,neon)
	part(pod,"EdgeMarker",v(0.32,0.12,0.065),seat*cf(0,0.014,-radius),tier==4 and amber or accent,nil,tier==4 and neon or smooth)
	attach(nozzle,"LiftOutlet",seat*cf(0,-0.34,0)*down)
	pod.WorldPivot=seat
end

local function head(m,tier,accent)
	local shell = ellipsoid(m,"RoundHead",Vector3.zero,v(2.50,2.49,2.23),ivory)
	ellipsoid(m,"VisorGasket",v(0,-0.055,-0.89),v(2.20,1.62,0.71),slate)
	ellipsoid(m,"FaceScreen",v(0,-0.055,-0.96),v(2.11,1.49,0.65),screen)
	for _,s in ipairs({-1,1}) do
		local eye = ellipsoid(m,"Eye",v(s*0.35,-0.016,-1.267),v(0.182,0.54,0.15),cyan,neon)
		eye.CFrame *= CFrame.Angles(0,-s*rad(8),0)
		part(m,"EarSocket",v(0.20,0.86,0.86),cf(s*1.173,-0.018,0.005),cream,drum)
		part(m,"EarHub",v(0.13,0.66,0.66),cf(s*1.275,-0.018,0.005),ivory,drum)
		part(m,"EarLight",v(0.08,0.39,0.39),cf(s*1.351,-0.018,0.005),cyan,drum,neon)
	end
	disc(m,"CapSeal",cf(0,1.135,0.035),0.77,0.09,slate)
	ellipsoid(m,"BlueCap",v(0,1.21,0.035),v(0.68,0.29,0.63),paint[3])
	disc(m,"LowerCollar",cf(0,-1.09,0.04),tier>=3 and 1.57 or 1.1,0.24,dark)
	local lamp = disc(m,"BellyProjector",cf(0,-1.255,0.04),0.54,0.115,cyan,neon)
	attach(lamp,"RepairEmitter",cf(0,-1.315,0.04)*down)
	return shell
end

local function fairings(m,tier,accent)
	for _,s in ipairs({-1,1}) do
		local x=tier==2 and 1.16 or 1.28
		local y=tier==2 and -0.16 or -0.55
		local shoulder=cf(s*x,y,0.15)*CFrame.Angles(0,0,s*rad(-12))
		part(m,"ShoulderUnderbody",v(0.88,0.58,1.12),shoulder*cf(0,-0.09,0),dark)
		part(m,"ShoulderCowl",v(0.90,0.68,1.17),shoulder*cf(0,0.085,0),accent)
		local strip=shoulder*cf(0,0.02,-0.601)
		part(m,"Inset",v(0.64,0.34,0.095),strip,dark)
		part(m,"RunningLight",v(0.45,0.14,0.07),strip*cf(0,0,-0.061),tier==4 and amber or cyan,nil,neon)
	end
end

local function jaw(m, pos, scale, accent)
	local wrist=joint(m,"PincerWrist",pos,0.32*scale,slate)
	for _,s in ipairs({-1,1}) do
		local top=pos+v(s*0.08,-0.02,0)*scale
		local corner=pos+v(s*0.36,-0.37,-0.03)*scale
		local tipPos=pos+v(s*0.17,-0.61,-0.065)*scale
		rod(m,"JawFinger",top,corner,0.16*scale,0.20*scale,ivory)
		joint(m,"JawKnuckle",corner,0.18*scale,accent)
		rod(m,"FingerPad",corner,tipPos,0.17*scale,0.20*scale,accent)
	end
	attach(wrist,"GripCenter",cf(pos+v(0,-0.49,-0.045)*scale)*down)
end

local function clawArm(m,tier,accent)
	local arm=group(m,"PincerArm")
	local shoulder, elbow, wrist
	if tier==4 then
		shoulder,elbow,wrist=v(0.93,-0.89,0),v(1.3,-1.43,-0.22),v(1.16,-1.76,-0.62)
	else
		-- Slightly forward of the belly lens; its optical axis stays clear.
		shoulder,elbow,wrist=v(0,-1.02,-0.36),v(0,-1.49,-0.44),v(0,-1.78,-0.53)
	end
	joint(arm,"PincerShoulder",shoulder,0.31,slate)
	rod(arm,"UpperLink",shoulder,elbow,0.24,0.26,tier==1 and slate or accent)
	joint(arm,"PincerElbow",elbow,0.28,cream)
	rod(arm,"WristLink",elbow,wrist,0.19,0.22,slate)
	jaw(arm,wrist,tier==1 and 0.83 or 1.04,accent)
	arm.WorldPivot=cf(shoulder)
end

local function weldArm(m,tier,accent)
	local arm=group(m,"WeldArm")
	local shoulder=tier==3 and v(0.02,-1.02,-0.40) or v(-0.91,-0.87,0.02)
	local elbow=tier==3 and v(-0.59,-1.52,-0.44) or v(-1.27,-1.42,-0.29)
	local wrist=elbow+v(-0.20,-0.24,-0.38)
	local endPos=wrist+v(-0.10,-0.25,-0.39)
	joint(arm,"WeldShoulder",shoulder,0.42,slate)
	rod(arm,"UpperLink",shoulder,elbow,0.32,0.31,accent)
	joint(arm,"ElbowHinge",elbow,0.36,amber)
	rod(arm,"Forearm",elbow,wrist,0.24,0.27,slate)
	local axis=(endPos-wrist).Unit
	local lensFrame=CFrame.lookAt(endPos,endPos+axis)
	local barrel=CFrame.lookAt((wrist+endPos)/2,endPos)*CFrame.Angles(0,pi/2,0)
	part(arm,"WeldHousing",v((endPos-wrist).Magnitude,0.43,0.43),barrel,slate,drum)
	part(arm,"LensBezel",v(0.11,0.38,0.38),lensFrame*CFrame.Angles(0,pi/2,0),accent,drum)
	local endFace=lensFrame*cf(0,0,-0.082)
	local lens=part(arm,"WeldingLens",v(0.07,0.24,0.24),endFace*CFrame.Angles(0,pi/2,0),tip,drum,neon)
	attach(lens,"WeldTip",endFace*cf(0,0,-0.045))
	if tier==3 then
		local a=v(0.60,-0.98,0.12)
		local b=v(0.61,-1.60,0.08)
		local c=v(0.27,-1.82,-0.04)
		rod(arm,"ServiceCable",a,b,0.095,0.095,dark)
		rod(arm,"ServiceCable",b,c,0.095,0.095,dark)
		rod(arm,"ServiceCable",c,elbow,0.095,0.095,dark)
	end
	arm.WorldPivot=cf(shoulder)
end

function Kit.build(tier,pivot,parent)
	assert(type(tier)=="number" and paint[tier],"RepairDroneKit.build expects an integer tier 1–4")
	assert(typeof(pivot)=="CFrame","RepairDroneKit.build expects a CFrame pivot")
	local m=Instance.new("Model")
	m.Name="RepairDrone_L"..tier
	m:SetAttribute("Tier",tier)
	m:SetAttribute("FrameType",names[tier])
	local accent=paint[tier]
	local shell=head(m,tier,accent)
	m.PrimaryPart=shell
	if tier>=2 then fairings(m,tier,accent) end
	if tier<=2 then
		propeller(m,-1,tier,accent)
		propeller(m,1,tier,accent)
	else
		for _,s in ipairs({-1,1}) do
			local side=s<0 and "Port" or "Starboard"
			hoverPod(m,side.."UpperThruster",v(s*(tier==3 and 1.85 or 1.99),1.48,0.54),v(s*0.9,0.44,0.36),0.84,accent,tier)
			if tier==4 then
				hoverPod(m,side.."LowerThruster",v(s*2.27,0.37,-0.43),v(s*1.13,-0.30,-0.06),0.77,accent,tier)
			end
		end
		weldArm(m,tier,accent)
	end
	if tier~=3 then clawArm(m,tier,accent) end
	local scales={1,1.06,1.14,1.20}
	m:ScaleTo(scales[tier])
	m:PivotTo(pivot)
	m.Parent=parent
	return m
end

return Kit
