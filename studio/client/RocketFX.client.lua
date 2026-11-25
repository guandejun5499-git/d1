--!strict
-- RocketFX · 场景装饰与运行态的客户端动画（StarterPlayer.StarterPlayerScripts）
-- SpinFX（Model）：绕 WorldPivot 的本地 Y 轴旋转，属性 SpinSpeed（弧度/秒，可为负）。
-- PulseFX（BasePart）：透明度呼吸 / 闪烁，属性 PulseBase / PulseAmp / PulseSpeed。
-- RainbowFX（BasePart / HandleAdornment）：颜色沿色相循环，属性 RainbowOffset（0–1）。彩虹尾焰、狂热轨道门用。
-- BreatheFX（Model）：整体缩放呼吸，属性 BreatheAmp（默认 0.08）。星尘碎片用。
-- 只改本地显示，不影响服务器；离相机很远的对象跳过，减少每帧开销。

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MAX_DIST = 600

local spins: { [Model]: boolean } = {}
local pulses: { [BasePart]: number } = {}
local rainbows: { [Instance]: boolean } = {}
local breathes: { [Model]: number } = {}

local function track(tag: string, add: (Instance) -> ())
	for _, inst in CollectionService:GetTagged(tag) do add(inst) end
	CollectionService:GetInstanceAddedSignal(tag):Connect(add)
end

-- SpinFollowParent 的光环挂在会动的父 Model 上（例如回收支架的臂）：记下相对父 Model 的初始位置，
-- 每帧按父 Model 当前姿态 + 累计角度重算，服务器移动父 Model 时不会和客户端自转互相覆盖。
type Follow = { rel: CFrame, angle: number }
local follows: { [Model]: Follow } = {}

track("SpinFX", function(inst)
	if not inst:IsA("Model") then return end
	local parent = inst.Parent
	if inst:GetAttribute("SpinFollowParent") and parent and parent:IsA("Model") then
		follows[inst] = { rel = parent:GetPivot():ToObjectSpace(inst:GetPivot()), angle = 0 }
	else
		spins[inst] = true
	end
end)
CollectionService:GetInstanceRemovedSignal("SpinFX"):Connect(function(inst) follows[inst :: Model] = nil end)

-- HideInsideFX（CylinderHandleAdornment，轴沿自身 Z）：镜头进到柱体里时临时全透明，出来后恢复。
-- 服务器在隐藏期间改了透明度也没关系：同步过来的新值会在下一帧被记下再隐藏。
local hideInside: { [CylinderHandleAdornment]: boolean } = {}
local hiddenSaved: { [CylinderHandleAdornment]: number } = {}
track("HideInsideFX", function(inst)
	if inst:IsA("CylinderHandleAdornment") then hideInside[inst] = true end
end)
CollectionService:GetInstanceRemovedSignal("HideInsideFX"):Connect(function(inst)
	hideInside[inst :: CylinderHandleAdornment] = nil
	hiddenSaved[inst :: CylinderHandleAdornment] = nil
end)
local INSIDE_MARGIN = 0.6
track("PulseFX", function(inst) if inst:IsA("BasePart") then pulses[inst] = math.random() * math.pi * 2 end end)
track("RainbowFX", function(inst) rainbows[inst] = true end)
track("BreatheFX", function(inst)
	if inst:IsA("Model") then breathes[inst] = inst:GetScale() end
end)
CollectionService:GetInstanceRemovedSignal("SpinFX"):Connect(function(inst) spins[inst :: Model] = nil end)
CollectionService:GetInstanceRemovedSignal("PulseFX"):Connect(function(inst) pulses[inst :: BasePart] = nil end)
CollectionService:GetInstanceRemovedSignal("RainbowFX"):Connect(function(inst) rainbows[inst] = nil end)
CollectionService:GetInstanceRemovedSignal("BreatheFX"):Connect(function(inst) breathes[inst :: Model] = nil end)

local function posOf(inst: Instance): Vector3?
	if inst:IsA("BasePart") then return inst.Position end
	if inst:IsA("HandleAdornment") then
		local a = inst.Adornee
		if a and a:IsA("BasePart") then return a.Position end
	end
	return nil
end

local t = 0
RunService.RenderStepped:Connect(function(dt: number)
	t += dt
	local cam = Workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position or Vector3.zero
	for model in spins do
		if model.Parent then
			local pivot = model:GetPivot()
			if (pivot.Position - camPos).Magnitude < MAX_DIST then
				local speed = (model:GetAttribute("SpinSpeed") :: number?) or 1
				model:PivotTo(pivot * CFrame.Angles(0, speed * dt, 0))
			end
		end
	end
	for model, fw in follows do
		local parent = model.Parent
		if parent and parent:IsA("Model") then
			local base = parent:GetPivot() * fw.rel
			if (base.Position - camPos).Magnitude < MAX_DIST then
				fw.angle += ((model:GetAttribute("SpinSpeed") :: number?) or 1) * dt
				model:PivotTo(base * CFrame.Angles(0, fw.angle, 0))
			end
		end
	end
	for ad in hideInside do
		local adornee = ad.Adornee
		local inside = false
		if ad.Visible and adornee and adornee:IsA("BasePart") then
			local lp = (adornee.CFrame * ad.CFrame):PointToObjectSpace(camPos)
			inside = math.sqrt(lp.X * lp.X + lp.Y * lp.Y) < ad.Radius + INSIDE_MARGIN and math.abs(lp.Z) < ad.Height / 2 + INSIDE_MARGIN
		end
		if inside then
			if ad.Transparency < 1 then
				hiddenSaved[ad] = ad.Transparency
				ad.Transparency = 1
			end
		elseif hiddenSaved[ad] then
			ad.Transparency = hiddenSaved[ad]
			hiddenSaved[ad] = nil
		end
	end
	for part, phase in pulses do
		if part.Parent and (part.Position - camPos).Magnitude < MAX_DIST then
			local base = (part:GetAttribute("PulseBase") :: number?) or 0.1
			local amp = (part:GetAttribute("PulseAmp") :: number?) or 0.4
			local speed = (part:GetAttribute("PulseSpeed") :: number?) or 3
			part.Transparency = base + amp * (0.5 + 0.5 * math.sin(t * speed + phase))
		end
	end
	for inst in rainbows do
		local p = posOf(inst)
		if inst.Parent and p and (p - camPos).Magnitude < MAX_DIST then
			local off = (inst:GetAttribute("RainbowOffset") :: number?) or 0
			local c = Color3.fromHSV((t * 0.9 + off) % 1, 0.75, 1)
			if inst:IsA("BasePart") then
				inst.Color = c
			elseif inst:IsA("HandleAdornment") then
				inst.Color3 = c
			end
		end
	end
	for model, s0 in breathes do
		if model.Parent and (model:GetPivot().Position - camPos).Magnitude < MAX_DIST then
			local amp = (model:GetAttribute("BreatheAmp") :: number?) or 0.08
			model:ScaleTo(s0 * (1 + amp * math.sin(t * 6)))
		end
	end
end)
