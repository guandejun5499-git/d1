local DSS=game:GetService("DataStoreService")
local Run=game:GetService("RunService")
local Http=game:GetService("HttpService")
local store=DSS:GetDataStore(Run:IsStudio() and "OrbitFirstFlight_Studio_v1" or "OrbitPlayers_v1")
local session=Http:GenerateGUID(false)
local Workshop=require(game.ReplicatedStorage.OrbitShared.logic.Workshop)
local Profiles={}
local memory={}
local function update(player,transform,opening)
	local key=tostring(player.UserId)
	for attempt=1,4 do
		if player:GetAttribute("SessionOnly") then
			local data=transform(memory[key])
			if data then memory[key]=data end
			return data
		end
		local ok,result=pcall(store.UpdateAsync,store,key,transform)
		if ok then return result end
		if opening and Run:IsStudio() and (string.find(tostring(result),"API access is not enabled",1,true) or string.find(tostring(result),"StudioAccessToApisNotAllowed") or string.find(tostring(result),"API Services rejected") or string.find(tostring(result),"Studio access to APIs is not allowed")) then
			warn("Studio API disabled: session-only first flight")
			player:SetAttribute("SessionOnly",true)
			local nextData=transform(memory[key])
			if nextData then memory[key]=nextData end
			return nextData
		end
		warn("First flight save retry",attempt,result)
		task.wait(attempt)
	end
	error("存档服务不可用")
end
function Profiles.open(player)
	return update(player,function(data)
		data=data or {coins=0,flights=0,bestFlight=0,perfectStreak=0,bestStreak=0}
		if data.owner and data.owner~=session and data.expires>os.time() then return nil end
		Workshop.initialize(data)
		data.owner=session
		data.expires=os.time()+180
		return data
	end,true)
end
function Profiles.change(player,fn,release)
	return update(player,function(data)
		if not data or data.owner~=session then return nil end
		if fn then fn(data) end
		data.owner=if release then nil else session
		data.expires=os.time()+180
		return data
	end)
end
return Profiles