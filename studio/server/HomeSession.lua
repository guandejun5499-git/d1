local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Http=game:GetService("HttpService")
local Rules=require(RS.OrbitShared.logic.Rules)
local net=require(RS.OrbitShared.logic.Network).event(true)
local Profiles=require(script.Parent.Profiles)
local Workshop=require(RS.OrbitShared.logic.Workshop)
local Arms=require(RS.OrbitShared.CatchArms)
local Build=require(RS.OrbitShared.BuildLib)
local rollRng=Random.new()
local MAX_SETTLE_TRIES=5
return function(home,index)
	local plan
	local pad=home.LaunchArea.LaunchPad.FlameHole
	local bay=home.AssemblyBay.Turntable
	local rollArea=home:WaitForChild("RollArea")
	local rollButton=rollArea.RollButton.Button
	local board=home.LaunchArea.FrameBoard
	local boardButton=board.UpgradeButton
	local padFrame=Build.homeFrame(index)*CFrame.new(0,0,-26)
	local owner,state
	local leaving=false
	local public={}
	local function publish()
		if leaving then return end
		home:SetAttribute("Activity",Http:JSONEncode(public))
	end
	local now=function() return workspace:GetServerTimeNow() end
	local function send(kind,...)
		if not leaving and owner and owner.Parent then net:FireClient(owner,kind,...) end
	end
	local function near(player,part)
		local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		return root and (root.Position-part.Position).Magnitude<=26
	end
	local function showArms(level)
		local old=home.LaunchArea:FindFirstChild("CatchArms")
		if not old or old:GetAttribute("Level")~=level then
			if old then old:Destroy() end
			Arms.build(padFrame,level,home.LaunchArea)
		end
		Arms.updateBoard(board,level)
	end

	local function snapshot(s,op,slot,reason)
		send("workshop",s.data.workshop,op,slot,reason,s.data.perfectStreak,s.data.bestStreak)
	end

	local function transact(player,s,revision,op,slot,tier)
		if s.writing or (s.phase~="bay" and s.phase~="pad" and s.phase~="done") then
			snapshot(s,"error",nil,"当前操作进行中")
			return
		end
		if revision~=s.data.workshop.revision then snapshot(s,"error",nil,"状态已更新，请重试") return end
		if typeof(op)~="string" or (slot~=nil and typeof(slot)~="string") or (tier~=nil and typeof(tier)~="number") then return end
		local station
		if op=="roll" then station=rollButton
		elseif op=="buy" then
			local index=table.find(require(RS.OrbitShared.PartPad).SLOTS,slot)
			if not index then return end
			station=rollArea["PartPad_"..index].Cap
			if near(player,rollButton) then station=rollButton end
		elseif op=="upgrade" then station=boardButton
		elseif op=="stage" or op=="assemble" then station=bay
		else return end
		if not near(player,station) then snapshot(s,"error",nil,"请靠近对应操作台") return end
		if (op=="roll" or op=="buy") and now()<(s.rollReady or 0) then snapshot(s,"error",nil,"揭晓中") return end
		-- One result per revision, including across UpdateAsync retries and ambiguous write acknowledgements.
		local seed=rollRng:NextInteger(1,2147483646)
		local token=Http:GenerateGUID(false)
		local reason
		s.writing=true
		local ok,data=pcall(Profiles.change,player,function(d)
			if d.workshop.lastCommand==token then reason=nil return end
			if d.workshop.revision~=revision then reason="状态已更新" return end
			reason=Workshop.apply(d,op,slot,tier,Random.new(seed))
			if not reason then d.workshop.lastCommand=token end
		end)
		s.writing=false
		if not ok or not data then
			if player.Parent then player:Kick("存档连接中断，请重新加入以恢复已保存的进度") end
			return
		end
		s.data=data
		if leaving or not player.Parent then return end
		if reason then snapshot(s,"error",slot,reason) return end
		if op=="assemble" then
			s.phase="assembly"
			s.ready=now()+8.4
		elseif op=="roll" then s.rollReady=now()+1.2
		elseif op=="upgrade" then showArms(data.workshop.level) end
		player.leaderstats.Coins.Value=data.coins
		public.coins,public.level=data.coins,data.workshop.level
		public.pad,public.staged,public.offers,public.sold=data.workshop.pad,data.workshop.staged,data.workshop.offers,data.workshop.sold
		public.event,public.eventAt=op,now()
		publish()
		snapshot(s,op,slot)
		if op=="assemble" then send("assemble",data.workshop.pad) end
	end

	local function join(player)
		if owner then return end
		public={name=player.DisplayName,coins=0,level=1}
		publish()
		owner=player
		local function spawnAtHome(character)
			character:WaitForChild("HumanoidRootPart")
			local pos=home.SpawnMarker.Dot.Position+Vector3.yAxis*4
			character:PivotTo(CFrame.lookAt(pos,Vector3.new(pad.Position.X,pos.Y,pad.Position.Z)))
		end
		player.CharacterAdded:Connect(spawnAtHome)
		if player.Character then task.spawn(spawnAtHome,player.Character) end
		local ok,data=pcall(Profiles.open,player)
		if owner~=player then
			if ok and data then Profiles.change(player,nil,true) end
			return
		end
		if not ok or not data then player:Kick("无法取得存档，请稍后重试") return end
		local stats=Instance.new("Folder")
		stats.Name="leaderstats"
		for key,value in {Coins=data.coins,Flights=data.flights} do
			local n=Instance.new("IntValue")
			n.Name=key
			n.Value=value
			n.Parent=stats
		end
		stats.Parent=player
		showArms(data.workshop.level)
		state={phase=data.workshop.pad and "pad" or "bay",data=data,lastInput=0}
		public.coins,public.level=data.coins,data.workshop.level
		public.pad,public.staged,public.offers,public.sold=data.workshop.pad,data.workshop.staged,data.workshop.offers,data.workshop.sold
		publish()
		player:SetAttribute("FlightHome",index)
	end
	local function launch(s,stamp)
		plan=Rules.performance(s.data.workshop.pad)
		plan.catchWindow=Arms.LEVELS[s.data.workshop.level].win
		plan.catchBonus=Arms.LEVELS[s.data.workshop.level].bonus
		s.judge,s.factor=Rules.ignition(stamp-s.charge)
		s.id=Http:GenerateGUID(false)
		s.clock={wall=now()+.1,t=0,rate=1,slow=plan.duration-plan.catchWindow-.6}
		s.phase="flight"
		s.rows,s.shards,s.dust,s.chain,s.fever={}, {},0,0,false
		s.catch,s.catchFactor,s.lastStamp=nil,nil,0
		public.flight={id=s.id,plan=plan,clock=s.clock,fever=false}
		publish()
		send("launch",s.id,s.judge,plan,s.clock,s.data.perfectStreak)
	end
	local function gate(s,i,judge,factor)
		local lap=plan.laps[i]
		local count=0
		for j=1,2 do if s.shards[i*2+j] then count+=1 end end
		local coins=math.round(lap.base*plan.coinFactor*(1+.5*(i-1))*s.factor*factor*(1+.25*count)*(s.fever and 2 or 1))
		s.rows[i]={grade=judge,coins=coins,body=lap.body,chain=1+.5*(i-1),ignition=s.factor,gate=factor,shards=1+.25*count,fever=s.fever}
		local chain,fever=Rules.chain(s.chain,judge)
		s.chain=chain
		-- Fever only lives inside the orbits: after the last gate the return and landing run at normal speed
		-- and the client turns the rainbow orbit and trail off (same as the accepted P1 FlightShow).
		if i==#plan.laps then fever=false end
		if fever~=s.fever then
			local wall=now()
			s.clock={wall=wall,t=Rules.position(s.clock,wall),rate=fever and 1.2 or 1,slow=plan.duration-plan.catchWindow-.6}
			s.fever=fever
		end
		public.flight.clock,public.flight.fever,public.flight.body=s.clock,s.fever,lap.body
		publish()
		send("gate",judge,coins,s.chain,s.fever,s.clock,lap.body)
	end
	local function settle(s,player)
		s.phase="saving"
		s.wasAtJupiter=s.data.workshop.reachedJupiter
		local result=s.catch or "crash"
		local streak=if result=="perfect" then s.data.perfectStreak+1 else 0
		local bonus=math.round(plan.catchBonus*(result=="crash" and .5 or s.catchFactor)*(1+.25*math.clamp(streak-1,0,4)))
		local total=bonus+s.dust
		-- Only laps actually flown count (a player who leaves mid-flight is settled with what they earned)
		local reachedJupiter=false
		for i,r in s.rows do
			total+=r.coins
			if plan.laps[i].body=="jupiter" then reachedJupiter=true end
		end
		local record=total>s.data.bestFlight
		local ok,data
		for attempt=1,MAX_SETTLE_TRIES do
			ok,data=pcall(Profiles.change,player,function(d)
				if d.lastFlight==s.id then return end
				d.lastFlight=s.id
				d.coins+=total
				d.flights+=1
				Workshop.landed(d.workshop,reachedJupiter and "jupiter" or "moon")
				if s.judge=="super" then d.workshop.superSeen=true end
				d.perfectStreak=streak
				d.bestStreak=math.max(d.bestStreak,streak)
				d.bestFlight=math.max(d.bestFlight,total)
			end)
			if ok then break end
			if attempt<MAX_SETTLE_TRIES then task.wait(2) end
		end
		local saved=ok and data~=nil
		if saved then
			s.data=data
			if player.Parent then
				player.leaderstats.Coins.Value=data.coins
				player.leaderstats.Flights.Value=data.flights
				public.coins=data.coins
				snapshot(s,"landed")
			end
		end
		public.flight=nil
		public.event,public.eventAt=result,now()
		publish()
		-- Always answer so the client can finish the landing (8th field = saved). A failed save is reported,
		-- then the player is sent back to rejoin (same handling as other lost-session paths).
		if player.Parent then
			local firstJupiter=saved and reachedJupiter and not s.wasAtJupiter
			send("receipt",s.rows,s.dust,bonus,total,result,firstJupiter,saved and record,saved)
			if not saved then
				task.delay(4,function()
					if player.Parent then player:Kick("存档连接中断，本趟收益未保存，请重新加入") end
				end)
			end
		end
		s.phase="done"
	end
	local function input(player,kind,stamp,id,i,j,tier)
		local s=state
		if player~=owner or not s then return end
		local wall=now()
		if typeof(stamp)~="number" then return end
		-- Workshop commands and sync are not timing-judged, so a slow connection must not drop them.
		-- Every work request gets an answer (snapshot or error), so the client never stays busy.
		if kind=="sync" then
			if wall-(s.lastSync or 0)>.25 then s.lastSync=wall snapshot(s,"init") end
			return
		end
		if kind=="work" then
			if wall-(s.lastWork or 0)<.06 then snapshot(s,"error",nil,"操作过快") return end
			s.lastWork=wall
			transact(player,s,id,i,j,tier)
			return
		end
		-- Timing inputs (charge / release / boost / shard / catch) are judged on their stamp, so it must be recent
		if not (stamp>=wall-.45 and stamp<=wall+.08) then return end
		if s.writing then
			if kind=="charge" then send("retry","charge") end
			return
		end
		if kind=="release" and s.phase=="charge" and stamp>=s.charge then launch(s,stamp) return end
		if wall-s.lastInput<.035 then return end
		s.lastInput=wall
		if kind=="charge" and (s.phase=="pad" or s.phase=="done") and near(player,pad) then
			s.phase="charge"
			s.charge=stamp
			send("charge")
		elseif kind=="charge" or kind=="assemble" then
			send("retry",kind)
		elseif s.phase=="flight" and id==s.id and stamp>=s.lastStamp then
			local t=Rules.position(s.clock,stamp)
			s.lastStamp=stamp
			if kind=="catch" and not s.catch and t>=plan.landStart and t<=plan.duration then
				local left=plan.duration-t
				s.catch,s.catchFactor=Rules.catch(left,plan.catchWindow)
				if left>plan.catchWindow+.4 then s.clock={wall=stamp,t=t,rate=1} end
				public.flight.catch,public.flight.lead,public.flight.clock=s.catch,left,s.clock
				publish()
				send("caught",s.catch,left,s.clock)
			elseif typeof(i)=="number" and plan.laps[i] and not s.rows[i] then
				local lap=plan.laps[i]
				if kind=="boost" then
					local grade,k=Rules.gate(t-lap.gate,plan.window,s.fever)
					if grade~="MISS" then gate(s,i,grade,k) end
				elseif kind=="shard" and (j==1 or j==2) and math.abs(t-lap.shards[j])<=.9 and not s.shards[i*2+j] then
					s.shards[i*2+j]=true
					s.dust+=math.round(lap.base*.5*plan.coinFactor)
					send("shard",i,j)
				end
			end
		end
	end
	local function tick()
		local s=state
		if not s then return end
		local wall=now()
		if s.phase=="assembly" and wall>=s.ready then s.phase="pad"
		elseif s.phase=="charge" and wall>=s.charge+3.85 then launch(s,s.charge+3.4)
		elseif s.phase=="flight" then
			local t=Rules.position(s.clock,wall)
			for i,lap in plan.laps do
				if not s.rows[i] and t>lap.gate+.54+.45*s.clock.rate then gate(s,i,"MISS",1) end
			end
			if t>=plan.duration+.45 then settle(s,owner) end
		end
	end
	local function leave(player)
		if player~=owner or leaving then return end
		leaving=true
		local s=state
		-- Leaving mid-flight keeps what was earned: laps and shards so far, no catch (counts as a crash)
		if s and s.phase=="flight" then settle(s,player) end
		while s and (s.phase=="saving" or s.writing) do task.wait(.1) end
		if s then pcall(Profiles.change,player,nil,true) end
		owner,state=nil,nil
		leaving=false
	end

	return {
		join=join, input=input, leave=leave, tick=tick,
		renew=function(player)
			if owner==player and state and not leaving then
				local ok,data=pcall(Profiles.change,player)
				if (not ok or not data) and player.Parent then player:Kick("存档连接中断，请重新加入") end
			end
		end,
	}
end
