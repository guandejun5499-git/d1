local Players=game:GetService("Players")
local Run=game:GetService("RunService")
local Input=game:GetService("UserInputService")

local player=Players.LocalPlayer
local sh=game.ReplicatedStorage:WaitForChild("OrbitShared")
local Rules=require(sh.logic.Rules)
local net=require(sh.logic.Network).event(false)
local AB,AS=require(sh.AssemblyBay),require(sh.AssemblyShow)
local LS,FS=require(sh.LaunchShow),require(sh.FlightShow)
local SD,O,G=require(sh.Stardust),require(sh.Orbits),require(sh.OrbitGate)
local index=player:GetAttribute("FlightHome")
while index==nil do player:GetAttributeChangedSignal("FlightHome"):Wait() index=player:GetAttribute("FlightHome") end
local B=require(sh.BuildLib)
local color=B.homeColor(index)
local frame=B.homeFrame(index)
local Style=require(sh.UIStyle)
local Sound=require(sh.SoundBank)
local crash=require(sh.CrashShow)
local gui=Instance.new("ScreenGui")
gui.Name="FirstFlightHUD"
gui.ResetOnSpawn=false
gui.Parent=player:WaitForChild("PlayerGui")
local function widget(class,name,pos,size)
	local v=Instance.new(class)
	v.Name=name
	v.AnchorPoint=Vector2.new(.5,.5)
	v.Position=pos
	v.Size=size
	v.BackgroundColor3=Color3.fromRGB(27,36,58)
	v.BackgroundTransparency=.12
	v.TextColor3=Color3.fromRGB(255,249,229)
	v.Font=Enum.Font.GothamBold
	v.TextScaled=true
	v.TextWrapped=true
	v.Parent=gui
	Style.apply(v)
	local limit=Instance.new("UITextSizeConstraint",v)
	limit.MaxTextSize=22
	return v
end
local info=widget("TextLabel","Status",UDim2.fromScale(.5,.22),UDim2.fromScale(.88,.065))
info.Text="正在载入首飞…"
local balance=widget("TextLabel","Coins",UDim2.fromScale(.13,.045),UDim2.fromScale(.23,.06))
local button=widget("TextButton","Action",UDim2.fromScale(.5,.86),UDim2.fromScale(.46,.09))
button.BackgroundColor3=Style.accent
button.Visible=false
local cancel=widget("TextButton","ReturnToHome",UDim2.fromScale(.5,.95),UDim2.fromScale(.26,.055))
cancel.Text="返回家园"
cancel.Visible=false
local bar=Instance.new("Frame")
bar.Size=UDim2.fromScale(.56,.032)
bar.Position=UDim2.fromScale(.22,.77)
bar.BackgroundColor3=Color3.fromRGB(52,66,87)
bar.Visible=false
bar.Parent=gui
local function strip(start,width,color3)
	local f=Instance.new("Frame")
	f.BorderSizePixel=0
	f.Size=UDim2.fromScale(width,1)
	f.Position=UDim2.fromScale(start,0)
	f.BackgroundColor3=color3
	f.Parent=bar
	return f
end
local zone=strip(.78,.14,Color3.fromRGB(57,217,128))
local needle=strip(0,.012,Color3.new(1,1,1))
local receipt=widget("TextLabel","Receipt",UDim2.fromScale(.5,.48),UDim2.fromScale(.82,.40))
receipt.Visible=false
local world=workspace:WaitForChild("OrbitWorld")
local home=world:WaitForChild("Homes"):WaitForChild("Home_"..index)
local area=home:WaitForChild("LaunchArea")
local bay=home:WaitForChild("AssemblyBay")
local pad=area:WaitForChild("LaunchPad"):WaitForChild("FlameHole")
task.spawn(require(script.Parent.HarborView).start,world.Homes,index,gui)
local camera=workspace.CurrentCamera
local pop=widget("TextLabel","FlightCallout",UDim2.fromScale(.5,.34),UDim2.fromScale(.55,.09))
pop.Visible=false
local serial=0
local function callout(title)
	serial+=1 local token=serial
	pop.Text=title pop.Visible=true
	task.delay(1,function() if token==serial then pop.Visible=false end end)
end
local border=Instance.new("Frame",gui)
border.Size=UDim2.new(1,-6,1,-6) border.Position=UDim2.fromOffset(3,3) border.BackgroundTransparency=1
local rim=Instance.new("UIStroke",border)
rim.Thickness=4 rim.Color=Color3.fromRGB(255,142,226) border.Visible=false
local beats={}
local chargeAudio
local receiptId=0
local function prompt(part,title)
	local p=Instance.new("ProximityPrompt")
	p.ActionText=title
	p.ObjectText="轨道工坊"
	p.MaxActivationDistance=22
	p.RequiresLineOfSight=false
	p.Parent=part
	return p
end
local assemblePrompt=prompt(bay:WaitForChild("Turntable"),"组装基础火箭")
local padPrompt=prompt(pad,"准备点火")
padPrompt.Enabled=false
local coins=player:WaitForChild("leaderstats"):WaitForChild("Coins")
local function refresh() balance.Text="金币  "..coins.Value end
refresh()
coins.Changed:Connect(refresh)
local phase="bay"
local function action(label)
	button.Text=label or ""
	button.Visible=label~=nil
end
local function tell(text) info.Text=text end
tell("前往右侧组装舱，按 E 检查四件基础部件")
local work=require(script.Parent:WaitForChild("WorkshopView")).new({
	gui=gui,home=home,bay=bay,area=area,pad=pad,color=color,frame=frame,coins=coins,
	flights=player.leaderstats.Flights,assemblePrompt=assemblePrompt,padPrompt=padPrompt,
	prompt=prompt,tell=tell,idle=function() return phase=="bay" or phase=="pad" or phase=="confirm" end,
	send=function(revision,op,slot,tier) net:FireServer("work",workspace:GetServerTimeNow(),revision,op,slot,tier) end,
})
assemblePrompt.Triggered:Connect(function()
	if not work.data then return end
	if work.data.guide=="assembly" then
		phase="confirm" tell("基础火箭  ·  Δv 285  ·  月球一圈") action("组装")
	else work:open("bay") end
end)
padPrompt.Triggered:Connect(function()
	if phase=="pad" then
		phase="ready"
		work:controls()
		cancel.Visible=true
		action("按住点火 · 绿区松手")
		local different=false
		for slot,tier in work.data.staged do
			if work.data.pad[slot]~=tier then different=true end
		end
		local tip="绿区 +25%  /  继续按住可冲超级发射"
		if player.leaderstats.Flights.Value>0 and not work.data.superSeen then
			tip="NEW · 超级发射！越过绿区继续按住，在第三段彩虹标记松手，绕行 +60%"
		end
		tell(different and "组装舱里有新组合 · 可先组装，或直接点火" or tip)
	end
end)
cancel.Activated:Connect(function()
	if phase~="ready" then return end
	phase="pad"
	cancel.Visible=false
	action(nil)
	work:controls()
	tell(work:hint())
end)
local launch,flight,clock,plan,id,chargeStart,holding
local lapIndex,landing,streak,received,visualDone
local shards={}
local now=function() return workspace:GetServerTimeNow() end
local function fire(kind,i,j) net:FireServer(kind,now(),id,i,j) end
local function restore()
	camera.CameraType=Enum.CameraType.Custom
	local char=player.Character
	if char then camera.CameraSubject=char:FindFirstChildOfClass("Humanoid") end
end
local RECEIPT_TIMEOUT=20
local function finish()
	if not visualDone then return end
	if not received then
		-- No answer from the server in time: finish the landing anyway so the player is not stuck
		tell("结算未完成 · 金币以服务器存档为准，稍后会自动同步")
		action(nil)
		phase="pad"
		padPrompt.Enabled=true
		work:controls()
		return
	end
	local rows,dust,bonus,total,result,firstJupiter=table.unpack(received,1,6)
	local saved=received[8]~=false
	local labels={perfect="完美接住",great="良好接住",early="提前接住",crash="残骸回收"}
	local lines={not saved and "保存失败 · 本趟收益未入账，即将断开重连" or firstJupiter and "首次木星飞行！" or received[7] and "新的最佳飞行！" or "飞行回收"}
	for i,r in rows do
		table.insert(lines,("%s %d  ·  %s  +%d\n连圈 ×%g   点火 ×%g   门 ×%g   星尘 ×%g%s"):format(
			r.body=="jupiter" and "木星" or "月球",i,r.grade,r.coins,r.chain,r.ignition,r.gate,r.shards,r.fever and "   狂热 ×2" or ""))
	end
	table.insert(lines,("星尘 +%d    %s +%d\n合计  +%d 金币"):format(dust,labels[result],bonus,total))
	if result=="perfect" and streak>=1 then
		table.insert(lines,("连续完美 %d 次 · 连击奖励 ×%g"):format(streak+1,1+.25*math.min(streak,4)))
	elseif streak>0 then
		table.insert(lines,("连续完美中断 · 上次 %d 次"):format(streak))
	end
	receiptId+=1 local ticket=receiptId
	receipt.Text=lines[1]
	task.spawn(function()
		for i=2,#lines do
			if not Style.reduced() then task.wait(.10) end
			if ticket~=receiptId then return end
			receipt.Text=table.concat(lines,"\n",1,i)
			Sound.play("row",nil,1+.05*i)
		end
	end)
	receipt.Visible=true
	tell(not saved and "存档连接中断 · 本趟收益未保存，即将断开，请重新加入" or ("奖励已到账 · %s"):format(work:hint()))
	action("领取")
	phase="receipt"
end
local function showGate(body)
	local planet=world.Planets:FindFirstChild(body=="moon" and "Moon" or "Jupiter")
	return planet and planet:FindFirstChild("OrbitGate")
end
local function clearShards()
	for _,s in shards do s:Destroy() end
	table.clear(shards)
end
local function startLap(i)
	clearShards()
	lapIndex=i
	local body=O.bodies[plan.laps[i].body]
	for j,pos in O.shardPoints(body) do shards[j]=SD.build(CFrame.new(pos),O.shardSize(body),workspace) end
	action("BOOST")
	tell(("%s · 第 %d/%d 圈 · 门圈重合时 BOOST，沿途点击星尘"):format(plan.laps[i].body=="moon" and "月球" or "木星",i,#plan.laps))
	local gate=showGate(plan.laps[i].body)
	if gate then G.setState(gate,flight.fever and "fever" or "normal") end
end
local function down(input,pos)
	if phase=="confirm" then
		work:command("assemble")
	elseif phase=="ready" then
		cancel.Visible=false
		if (player.Character:GetPivot().Position-pad.Position).Magnitude>25 then
			phase="pad" action(nil) work:controls() tell("请回到发射台旁") return
		end
		phase="charge"
		holding=input
		chargeStart=now()
		launch=LS.prepare(area)
		chargeAudio=Sound.play("charge",pad,1,true)
		fire("charge")
		bar.Visible=true
		padPrompt.Enabled=false
	elseif phase=="flight" and flight then
		local t=Rules.position(clock,now())
		if t>=plan.landStart then
			if not landing and t<=plan.duration then fire("catch") end
		elseif lapIndex then
			if pos then
				for j,shard in shards do
					local point,visible=camera:WorldToViewportPoint(O.shardPoints(O.bodies[plan.laps[lapIndex].body])[j])
					local radius=input.UserInputType==Enum.UserInputType.Touch and 84 or 66
					if not shard:GetAttribute("Collected") and visible and (pos-Vector2.new(point.X,point.Y)).Magnitude<=radius and math.abs(t-plan.laps[lapIndex].shards[j])<=.9 then
						fire("shard",lapIndex,j) return
					end
				end
			end
			fire("boost",lapIndex)
		end
	elseif phase=="receipt" then
		receiptId+=1 Sound.chord("claim")
		if not Style.reduced() then
			local token=widget("TextLabel","CoinAward",UDim2.fromScale(.5,.48),UDim2.fromOffset(85,32))
			token.Text="+"..received[4]
			game:GetService("TweenService"):Create(token,TweenInfo.new(.45),{Position=balance.Position,BackgroundTransparency=1}):Play()
			game:GetService("Debris"):AddItem(token,.46)
		end
		receipt.Visible=false
		phase="pad"
		action(nil)
		padPrompt.Enabled=true
		tell(work:hint())
		work:controls()
	end
end
local function pointer(i) return i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch end
button.InputBegan:Connect(function(i) if pointer(i) then down(i) end end)
Input.InputBegan:Connect(function(i,processed)
	if processed then return end
	if i.KeyCode==Enum.KeyCode.Space then down(i)
	elseif phase=="flight" and pointer(i) then down(i,Vector2.new(i.Position.X,i.Position.Y)) end
end)
local function release()
	if phase=="charge" and holding then holding=nil fire("release") end
end
Input.InputEnded:Connect(function(i) if i==holding or (holding and i.UserInputType==Enum.UserInputType.MouseButton1) then release() end end)
net.OnClientEvent:Connect(function(kind,a,b,c,d,e,f,g,h)
	if kind=="workshop" then
		if b=="init" then phase=a.pad and "pad" or "bay" end
		work:update(a,b,c,d,e,f)
	elseif kind=="retry" then
		if a=="charge" and phase=="charge" then
			holding=nil
			if chargeAudio then chargeAudio:Destroy() chargeAudio=nil end
			bar.Visible=false
			launch:reset()
			launch:destroy()
			restore()
			phase="pad"
			padPrompt.Enabled=true
			action(nil)
			tell("请回到发射台旁，按 E 准备点火")
			work:controls()
		elseif a=="assemble" and phase=="confirm" then
			phase="bay"
			action(nil)
			tell("请靠近组装舱，按 E 组装")
		end
	elseif kind=="assemble" then
		phase="assembly"
		action(nil)
		assemblePrompt.Enabled=false
		tell("组装中 · 等待火箭运上发射台")
		work:controls()
		Sound.play("assemble",bay.Turntable)
		for _,delay in {1.3,2.5,4.1} do task.delay(delay,Sound.play,"weld",bay.Turntable) end
		AS.play(bay,a,color)
		phase="pad"
		padPrompt.Enabled=true
		work:controls()
		tell("火箭已就位 · 前往发射台，按 E 准备点火")
	elseif kind=="launch" then
		id,plan,clock,streak=a,c,d,e
		holding=nil
		bar.Visible=false
		phase="launch"
		landing,lapIndex,received,visualDone=nil,nil,nil,false
		if chargeAudio then chargeAudio:Destroy() chargeAudio=nil end
		Sound.play(b=="super" and "super" or "launch",pad)
		table.clear(beats)
		launch=launch or LS.prepare(area)
		camera.CameraType=Enum.CameraType.Scriptable
		launch:startLaunch(b)
		tell("点火  "..string.upper(b))
		action(nil)
	elseif kind=="gate" then
		clock=e
		local changed=flight and flight.fever~=d
		if changed then flight:setFever(d,f) Sound.fever(d) end
		border.Visible=d
		callout(changed and d and "ORBIT FEVER!" or ("%s   +%d"):format(a,b))
		if a=="PERFECT" then Sound.play("perfect",nil,1+.06*c) end
		tell(("%s   +%d   %s"):format(a,b,d and "ORBIT FEVER!" or ("FEVER "..c.."/2")))
	elseif kind=="caught" then
		landing=a
		Sound.play("lock",pad)
		if a=="perfect" then Sound.chord("perfect") elseif streak>0 then Sound.play("streakEnd") end
		clock=c
		if flight then
			flight.catchShow.result=a
			flight.catchShow.inputLead=b
			flight.catchShow.streak=streak+1
		end
		action(nil)
		tell("回收支架已启动")
	elseif kind=="shard" then
		Sound.play("shard",nil,1+.1*b)
		if a==lapIndex and shards[b] then SD.collect(shards[b]) local g=showGate(plan.laps[a].body) if g then G.setState(g,"boost") end end
	elseif kind=="receipt" then
		received={a,b,c,d,e,f,g,h}
		finish()
	end
end)
task.spawn(function()
	repeat
		net:FireServer("sync",workspace:GetServerTimeNow())
		task.wait(1)
	until work.data
end)
Run.RenderStepped:Connect(function()
	if phase=="charge" then
		local t=now()-chargeStart
		local v,stage=Rules.gauge(t)
		launch:charge(v,stage)
		if chargeAudio then chargeAudio.PlaybackSpeed=.7+.45*(stage+v) end
		zone.BackgroundColor3=stage==2 and Color3.fromHSV(v,.8,1) or Color3.fromRGB(57,217,128)
		needle.Position=UDim2.fromScale(v,0)
		zone.Position=UDim2.fromScale(stage==2 and .82 or .78,0)
		zone.Size=UDim2.fromScale(stage==1 and 0 or stage==2 and .06 or .14,1)
		button.Text=({"绿区松手","继续按住…","彩虹区松手 +60%"})[stage+1]
		camera.CameraType=Enum.CameraType.Scriptable
		camera.CFrame=CFrame.lookAt(pad.Position+frame:VectorToWorldSpace(Vector3.new(-28,9,24)),pad.Position+Vector3.yAxis*9)
		if t>=3.4 then release() end
	elseif phase=="launch" or phase=="flight" then
		local t=Rules.position(clock,now())
		local intro=1/plan.speed
		if phase=="launch" then
			launch:runTo(math.min(t/intro,1)*launch.duration)
			if t<intro then return end
			launch:destroy()
			flight=FS.prepare(launch.rocket,launch.home,plan.legs,{launchArea=area,scale0=launch.scale0,catchClosed=launch.catchPose0,speed=plan.speed,ascentDuration=2.6/plan.speed,live=true,landing="crash"})
			local descentSpeed=(flight.hover.Y-launch.home.Y)/2.6
			flight.catchShow.green,flight.catchShow.yellow=require(sh.CatchZone).heightsFor(plan.catchWindow,descentSpeed)
			phase="flight"
		end
		flight:runTo(math.clamp(t-intro,0,flight.duration))
		local pos=flight.rocket:GetPivot().Position
		for i,lap in plan.laps do
			if t>=lap.start and t<=lap.gate+.54 then
				if lapIndex~=i then startLap(i) end
				local g=showGate(lap.body)
				local left=lap.gate-t
				local beat=if left<=0 then 3 elseif left<=.3 then 2 elseif left<=.6 then 1 else 0
				if beat>(beats[i] or 0) then beats[i]=beat Sound.play(beat==3 and "beat" or "count",nil,1+.04*i+.08*beat) end
				if border.Visible and not Style.reduced() then rim.Color=Color3.fromHSV((t*.5)%1,.65,1) end
				if g then G.setShrink(g,1+math.min(2,math.abs(left))) G.setActive(g,math.abs(left)<=plan.window+(flight.fever and .05 or 0)) end
				local body=O.bodies[lap.body]
				local u=math.clamp((t-lap.start)/(lap.gate-lap.start),0,1)
				local dir=O.tan(body,body.a0+2*math.pi*u)
				camera.CFrame=CFrame.lookAt(pos-dir*34+Vector3.yAxis*12,pos+dir*16)
				for j,obj in shards do if t>lap.shards[j]+.9 then obj:Destroy() shards[j]=nil end end
				break
			end
		end
		local last=plan.laps[#plan.laps]
		local between=plan.legs[2] and t>plan.laps[1].gate+.54 and t<plan.laps[2].start
		if t<plan.laps[1].start or t>last.gate+.54 or between then
			camera.CFrame=CFrame.lookAt(pos+frame:VectorToWorldSpace(Vector3.new(-30,12,27)),pos+Vector3.yAxis*5)
			if lapIndex then
				local g=showGate(plan.laps[lapIndex].body)
				if g then G.setShrink(g,nil) G.setActive(g,false) G.setState(g,"normal") end
				clearShards() lapIndex=nil action(nil)
				if between then tell("飞向木星！") end
			end
		end
		if t>=plan.landStart and not landing then
			local left=plan.duration-t
			tell(left<=plan.catchWindow and "绿区 · 现在接住！" or left<=plan.catchWindow+.4 and "黄区 · 即将着陆" or "返航 · 等火箭进入绿区")
			action("CATCH")
		end
		if t>=plan.duration then
			phase="landing"
			Sound.fever(false) border.Visible=false
			action(nil)
			task.spawn(function()
				-- Allow the server to confirm a last-frame catch before choosing crash FX (bounded wait).
				local waited=os.clock()
				while not received and os.clock()-waited<RECEIPT_TIMEOUT do task.wait() end
				local result=received and received[5] or landing or "crash"
				if result=="crash" then Sound.play("crash",pad) callout("华丽坠毁 · 无人机回收") crash.play(area,flight.rocket) else task.wait(.3) end
				flight:cleanup()
				flight=nil
				launch=nil
				restore()
				visualDone=true
				finish()
			end)
		end
	end
end)
