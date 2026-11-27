local RS=game.ReplicatedStorage.OrbitShared
local Http=game:GetService("HttpService")
local Run=game:GetService("RunService")
local Build=require(RS.BuildLib)
local Kit=require(RS.RocketKit)
local Rules=require(RS.logic.Rules)
local Flight=require(RS.FlightShow)
local Assembly=require(RS.AssemblyShow)
local Bay=require(RS.AssemblyBay)
local Roll=require(RS.RollReveal)
local Parts=require(RS.PartPad)
local Crash=require(RS.CrashShow)
local visitors=require(RS.VisitorShow)
local style=require(RS.UIStyle)
local Sound=require(RS.SoundBank)
local Harbor={}
local drop={Seam=true,PanelSeam=true,Hazard=true,Rivet=true,ShutterLine=true,Pipe=true,Chevron=true,Hose=true,Roller=true,Tooth=true}
local function finishAssembly(v)
	local rocket=v.assembly:finish()
	if v.rocket and v.rocket.Parent then v.rocket:Destroy() end
	rocket.Name="PadRocket"
	rocket.Parent=v.area
	v.rocket=rocket
	v.assembly=nil
end
local function clearFlight(v)
	if v.flight and v.rocket.Parent then v.flight:cleanup() end
	v.flight=nil
	v.flightId=nil
end
local function draw(v,data,now,near)
	local home=v.home
	local area=home:FindFirstChild("LaunchArea")
	local bay=home:FindFirstChild("AssemblyBay")
	local roll=home:FindFirstChild("RollArea")
	if not (area and bay and roll) then v.area=nil return end
	if v.area~=area or v.bay~=bay or v.roll~=roll then
		local rocket=area:FindFirstChild("PadRocket")
		if not rocket then return end
		v.area,v.bay,v.roll=area,bay,roll
		v.rocket=rocket
		v.cf=Build.homeFrame(v.index)*CFrame.new(0,1.5,-26)
		v.prev,v.flight,v.flightId,v.assembly,v.reveal=nil,nil,nil,nil,nil
		for _,m in {area,bay,roll,home:FindFirstChild("ShopSlots")} do if m then Build.lite(m,drop) end end
	end
	local prev=v.prev
	if prev~=data then
		local sameEvent=prev and prev.name==data.name and prev.eventAt==data.eventAt
		local recent=near and data.eventAt and now-data.eventAt<1
		if v.flight and (not data.flight or v.flightId~=data.flight.id) then clearFlight(v) end
		if not sameEvent then
			if v.assembly then finishAssembly(v) end
			if v.reveal then v.reveal:cleanup() v.reveal=nil end
			local eq=data.pad or Rules.basic
			if recent and data.event=="assemble" then
				v.assembly=Assembly.prepare(bay,eq,v.color,{padRocket=v.rocket,padParent=area})
				Sound.play("assemble",bay.Turntable)
			elseif not prev or prev.name~=data.name or not prev.pad or not data.pad or
				eq.nose~=prev.pad.nose or eq.tank~=prev.pad.tank or eq.engine~=prev.pad.engine or eq.fins~=prev.pad.fins then
				v.rocket:Destroy()
				v.rocket=Kit.build(eq,v.color,v.cf,area)
				v.rocket.Name="PadRocket"
			end
			if recent and data.event=="roll" then
				v.reveal=Roll.prepare(roll,data.offers,{homeColor=v.color,lite=true})
			else
				for i,slot in Parts.SLOTS do
					local pad=roll:FindFirstChild("PartPad_"..i)
					local tier=data.offers and data.offers[slot]
					if pad then Parts.setState(pad,{mode=data.sold and data.sold[slot] and "sold" or tier and "offer" or "idle",tier=tier},{homeColor=v.color,lite=true}) end
				end
			end
			local staged=data.staged or {}
			local filled=0
			for i,slot in Parts.SLOTS do
				if staged[slot] then filled+=1 end
				Bay.setDock(bay,i,staged[slot],v.color)
			end
			Bay.setStatus(bay,v.assembly and "assembling" or filled==4 and "ready" or "staging",filled)
			if recent and data.event=="crash" then
				local wreck=v.rocket:Clone()
				wreck.Parent=area
				local original=v.rocket
				original.Parent=nil
				Sound.play("crash",area.LaunchPad.FlameHole)
				task.spawn(function()
					pcall(Crash.play,area,wreck)
					wreck:Destroy()
					if v.rocket==original and area.Parent then original.Parent=area else original:Destroy() end
				end)
			end
		end
		v.prev=data
	end
	if v.assembly then
		local elapsed=now-data.eventAt
		if elapsed>=Assembly.TOTAL or data.flight then finishAssembly(v) else v.assembly:at(math.max(0,elapsed)) end
	end
	if v.reveal then
		local fraction=math.clamp((now-data.eventAt)/1.2,0,1)
		v.reveal:runTo(v.reveal.duration*fraction)
		if fraction==1 then
			v.reveal:cleanup() v.reveal=nil
			for i,slot in Parts.SLOTS do
				if data.sold[slot] then Parts.setState(roll["PartPad_"..i],{mode="sold"},{lite=true}) end
			end
		end
	end
	local f=data.flight
	if not f then return end
	if not v.flight then
		v.rocket.Parent=area
		v.flight=Flight.prepare(v.rocket,v.cf,f.plan.legs,{speed=f.plan.speed,fromPad=true,worldFever=false,live=true,launchArea=area,landing="crash"})
		v.flightId=f.id
		if near and now-f.clock.wall<1 then visitors.cheer(v.cf.Position,1.2) Sound.play("launch",area.LaunchPad.FlameHole) end
	end
	local show=v.flight
	if show.fever~=f.fever then show:setFever(f.fever,f.body or "moon") end
	if f.catch and show.catchShow then show.catchShow.result=f.catch show.catchShow.inputLead=f.lead end
	local t=math.clamp(Rules.position(f.clock,now),0,show.duration)
	show:runTo(t)
	local lap=0
	for i,segment in f.plan.laps do if t>=segment.start then lap=i end end
	if not v.tag or v.tag.Parent~=v.rocket then
		v.tag=Instance.new("BillboardGui")
		v.tag.Name="Pilot"
		v.tag.Adornee=v.rocket:FindFirstChildWhichIsA("BasePart",true)
		v.tag.Size=UDim2.fromOffset(140,28)
		v.tag.StudsOffsetWorldSpace=Vector3.new(0,10,0)
		v.tag.Parent=v.rocket
		local label=Instance.new("TextLabel",v.tag)
		label.Size=UDim2.fromScale(1,1)
		label.BackgroundTransparency=1 label.Font=style.font label.TextStrokeTransparency=.2 label.TextColor3=v.color
	end
	v.tag.TextLabel.Text=data.name.."  "..lap.."/"..#f.plan.laps
end
function Harbor.start(folder,own,gui)
	local roster=Instance.new("TextButton",gui)
	roster.Name="HarborRoster"
	roster.Position=UDim2.new(1,-112,0,4) roster.Size=UDim2.fromOffset(108,28)
	roster.Text="同服家园 ▾"
	style.apply(roster)
	local panel=Instance.new("TextLabel",gui)
	panel.Position=UDim2.new(1,-190,0,36) panel.Size=UDim2.fromOffset(186,150)
	panel.TextSize=15 panel.Visible=false style.apply(panel)
	roster.Activated:Connect(function() panel.Visible=not panel.Visible end)
	local seats={}
	for i=0,5 do
		local home=folder:WaitForChild("Home_"..i)
		local v={home=home,index=i,color=Build.homeColor(i),next=0}
		seats[i]=v
		local function sync()
			local json=home:GetAttribute("Activity")
			v.data=json and Http:JSONDecode(json)
			local lines={}
			for k=0,5 do local seat=seats[k] local d=seat and seat.data
				if d then table.insert(lines,("%s%s   %d 金币"):format(k==own and "★ " or "",d.name,d.coins)) end
			end
			panel.Text=table.concat(lines,"\n")
		end
		home:GetAttributeChangedSignal("Activity"):Connect(sync)
		sync()
		if i~=own then
			task.spawn(function()
				while gui.Parent do
					local camera=workspace.CurrentCamera
					local near=camera and (camera.CFrame.Position-Build.homeFrame(i).Position).Magnitude<185
					if v.data then draw(v,v.data,workspace:GetServerTimeNow(),near) end
					if v.tag then v.tag.Enabled=v.flight~=nil end
					task.wait(near and 1/30 or .12)
				end
			end)
		end
	end
end
return Harbor
