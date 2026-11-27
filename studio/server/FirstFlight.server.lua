local Players=game:GetService("Players")
local Http=game:GetService("HttpService")
local SH=game.ReplicatedStorage.OrbitShared
local Build=require(SH.BuildLib)
local Rules=require(SH.logic.Rules)
local Arms=require(SH.CatchArms)
local net=require(SH.logic.Network).event(true)
local createSession=require(script.Parent.HomeSession)
local homes=workspace:WaitForChild("OrbitWorld"):WaitForChild("Homes")
-- Review stands remain available in Edit mode, outside the replicated play scene.
for _,name in {"_PartsReview","_P0Review","_PaidBrackets","_DroneReview"} do
	local stand=homes.Parent:FindFirstChild(name)
	if stand then stand.Parent=game.ServerStorage end
end
local assigned,slots={},{} 
local now=function() return workspace:GetServerTimeNow() end

-- Assemble full runtime copies before assigning seats. The saved art scene remains editable.
local sections={"LaunchArea","AssemblyBay","RollArea","ShopSlots","SpawnMarker"}
local full=homes.Home_0
for index=0,5 do
	local home=homes:WaitForChild("Home_"..index)
	local transform=Build.homeFrame(index)*Build.homeFrame(0):Inverse()
	for _,name in sections do
		local model=home:FindFirstChild(name)
		if index~=0 then
			local copy=full[name]:Clone()
			copy:PivotTo(transform*copy:GetPivot())
			for _,obj in copy:GetDescendants() do
				for _,key in {"HomeCF","BaseCF","ClosedPivot"} do
					local cf=obj:GetAttribute(key)
					if typeof(cf)=="CFrame" then obj:SetAttribute(key,transform*cf) end
				end
				if obj:IsA("BasePart") and obj.Color==Build.homeColor(0) then obj.Color=Build.homeColor(index) end
			end
			if model then model:Destroy() end
			copy.Parent=home
			model=copy
		end
		model.ModelStreamingMode=Enum.ModelStreamingMode.PersistentPerPlayer
	end
	slots[index]={home=home,index=index}
end
local botLevels={1,2,1,4,3,2}
local botNames={"织女星","天琴","海燕","猎户","天鹅","星尘"}
local function resetBot(slot)
	local k=slot.index
	local level=botLevels[k+1]
	local area=slot.home.LaunchArea
	if area.CatchArms:GetAttribute("Level")~=level then
		area.CatchArms:Destroy()
		Arms.build(Build.homeFrame(k)*CFrame.new(0,0,-26),level,area)
	end
	Arms.updateBoard(area.FrameBoard,level)
	slot.bot={name=botNames[k+1].." · NPC",coins=slot.botCoins or 0,level=level,
		pad={nose=1,tank=2,engine=k%2+1,fins=1},offers={},staged={},sold={}}
	slot.nextFlight=now()+math.random(25,50)
	slot.home:SetAttribute("Activity",Http:JSONEncode(slot.bot))
end
for _,slot in slots do resetBot(slot) end
local function join(p)
	if assigned[p] then return end
	for k=0,5 do
		local slot=slots[k]
		if not slot.player then
			slot.player=p
			slot.api=createSession(slot.home,k)
			slot.bot=nil
			assigned[p]=slot
			for _,name in sections do slot.home[name]:AddPersistentPlayer(p) end
			slot.api.join(p)
			return
		end
	end
	p:Kick("六个家园均已有人，请加入其他服务器")
end
local function leave(p)
	local slot=assigned[p]
	if not slot then return end
	assigned[p]=nil
	local session=slot.api
	slot.player,slot.api=nil,nil
	-- PlayerRemoving can run after engine persistence membership has already been released.
	resetBot(slot)
	session.leave(p)
end
Players.PlayerAdded:Connect(join)
Players.PlayerRemoving:Connect(leave)
for _,p in Players:GetPlayers() do task.spawn(join,p) end
net.OnServerEvent:Connect(function(p,...)
	local slot=assigned[p]
	if slot then slot.api.input(p,...) end
end)
for _,slot in slots do
	game:GetService("RunService").Heartbeat:Connect(function()
		if slot.player then slot.api.tick() return end
		if now()<slot.nextFlight then return end
		local bot=slot.bot
		if bot.flight then
			slot.botCoins=bot.coins+bot.flight.plan.coins+Arms.LEVELS[bot.level].bonus
			bot.coins=slot.botCoins
			bot.flight=nil
			slot.nextFlight=now()+math.random(25,50)
		else
			local plan=Rules.performance(bot.pad)
			bot.flight={id=Http:GenerateGUID(false),plan=plan,clock={wall=now(),t=0,rate=1},body="moon",fever=math.random()<.35,catch="great",lead=.35}
			slot.nextFlight=now()+plan.duration+.2
		end
		slot.home:SetAttribute("Activity",Http:JSONEncode(bot))
	end)
end
task.spawn(function()
	while task.wait(50) do for p,slot in assigned do task.spawn(slot.api.renew,p) end end
end)
game:BindToClose(function()
	local remaining=0
	for p in assigned do
		remaining+=1
		task.spawn(function() leave(p) remaining-=1 end)
	end
	while remaining>0 do task.wait(.1) end
end)
