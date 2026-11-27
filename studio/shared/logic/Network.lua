local Network={}
function Network.event(server)
	local rs=game:GetService("ReplicatedStorage")
	local function get(parent,name,class)
		if not server then return parent:WaitForChild(name) end
		local obj=parent:FindFirstChild(name) or Instance.new(class)
		assert(obj:IsA(class))
		obj.Name=name
		obj.Parent=parent
		return obj
	end
	return get(get(rs,"Remotes","Folder"),"FirstFlight","RemoteEvent")
end
return Network