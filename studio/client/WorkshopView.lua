local Run=game:GetService("RunService")
local Players=game:GetService("Players")
local shared=game.ReplicatedStorage.OrbitShared
local Parts=require(shared.PartPad)
local Arms=require(shared.CatchArms)
local Rules=require(shared.logic.Rules)
local Workshop=require(shared.logic.Workshop)
local AB=require(shared.AssemblyBay)
local RR=require(shared.RollReveal)
local JR=require(shared.JupiterReveal)
local RK=require(shared.RocketKit)
local Catch=require(shared.CatchShow)

local View={}
View.__index=View
local navy=Color3.fromRGB(22,33,52)
local blue=Color3.fromRGB(39,72,100)
local accent=Color3.fromRGB(168,72,15)
local muted=Color3.fromRGB(57,63,76)
local guidance={
	assembly="① 前往组装舱 · 用四件基础部件组装首飞火箭",
	launch="② 到发射台点火 · 绿区松手",
	roll="首航完成 · 前往 Roll 台免费抽取四件部件",
	tank="大燃料舱已在背包 · 回组装舱装入燃料舱槽，再点组装",
	second="去发射台试飞新组合 · 大燃料舱可绕月两圈",
	free="自由飞行 · Roll 新部件，或到橙色升级牌提升回收支架",
}
local function box(parent,class,name)
	local obj=Instance.new(class)
	obj.Name=name
	obj.BorderSizePixel=0
	obj.BackgroundColor3=navy
	obj.Parent=parent
	Instance.new("UICorner",obj).CornerRadius=UDim.new(0,8)
	return obj
end
local function textBox(parent,title,fn,enabled)
	local obj=box(parent,fn and "TextButton" or "TextLabel",title)
	obj.Font=Enum.Font.GothamBold
	obj.TextColor3=Color3.fromRGB(247,244,227)
	obj.TextWrapped=true
	obj.TextSize=15
	obj.Text=title
	obj.AutomaticSize=Enum.AutomaticSize.Y
	obj.Size=UDim2.new(1,-6,0,34)
	obj.BackgroundColor3=if enabled==false then muted elseif fn then blue else navy
	if fn then
		obj.AutoButtonColor=enabled~=false
		if enabled~=false then obj.Activated:Connect(fn) end
	end
	return obj
end
local function billboard(part,name)
	local b=Instance.new("BillboardGui")
	b.Name=name
	b.Adornee=part
	b.Size=UDim2.fromOffset(170,42)
	b.StudsOffsetWorldSpace=Vector3.new(0,5,0)
	b.AlwaysOnTop=true
	b.MaxDistance=120
	b.Parent=part
	local t=Instance.new("TextLabel",b)
	t.BackgroundTransparency=1
	t.Size=UDim2.fromScale(1,1)
	t.TextScaled=true
	t.TextStrokeTransparency=.12
	t.Font=Enum.Font.GothamBold
	t.TextColor3=Color3.fromRGB(255,213,69)
	return b,t
end
function View.new(ctx)
	local self=setmetatable(ctx,View)
	self.tab="tank"
	self.rollArea=self.home:WaitForChild("RollArea")
	self.rollPart=self.rollArea:WaitForChild("RollButton"):WaitForChild("Button")
	self.upPart=self.area:WaitForChild("FrameBoard"):WaitForChild("UpgradeButton")
	self.rollPrompt=self.prompt(self.rollPart,"免费 Roll")
	self.upPrompt=self.prompt(self.upPart,"升级回收支架")
	self.rollPrompt.MaxActivationDistance=13
	self.upPrompt.MaxActivationDistance=8
	self.padPrompts={}
	for i,slot in Parts.SLOTS do
		local pad=self.rollArea:WaitForChild("PartPad_"..i)
		local buy=self.prompt(pad:WaitForChild("Cap"),"购买"..Parts.SLOT_NAMES[slot])
		buy.MaxActivationDistance=6
		buy.Triggered:Connect(function() self:command("buy",slot,self.data.offers[slot]) end)
		self.padPrompts[slot]=buy
	end
	self.rollPrompt.Triggered:Connect(function() self:command("roll") end)
	self.upPrompt.Triggered:Connect(function() self:open("upgrade") end)
	self.bagButton=textBox(self.gui,"背包",function() self:open("bag") end)
	self.bagButton.AutomaticSize=Enum.AutomaticSize.None
	self.bagButton.Position=UDim2.fromScale(.015,.09)
	self.bagButton.Size=UDim2.fromOffset(66,32)
	self.panel=box(self.gui,"Frame","WorkshopPanel")
	local scroll=Instance.new("ScrollingFrame",self.panel)
	scroll.Name="Contents"
	scroll.Size=UDim2.new(1,-16,1,-16)
	scroll.Position=UDim2.fromOffset(8,8)
	scroll.ScrollBarThickness=4
	scroll.BackgroundTransparency=1
	scroll.BorderSizePixel=0
	scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
	scroll.CanvasSize=UDim2.new()
	self.scroll=scroll
	local layout=Instance.new("UIListLayout",scroll)
	layout.Padding=UDim.new(0,5)
	layout.SortOrder=Enum.SortOrder.LayoutOrder
	self.panel.Visible=false
	self.arrow,self.arrowText=billboard(self.bay.Turntable,"GuideArrow")
	self.arrowText.Text="▼"
	self.arrow.Enabled=false
	self.streakSign,self.streakText=billboard(self.upPart,"CatchRecord")
	self.streakSign.StudsOffsetWorldSpace=Vector3.new(0,3,0)
	self.streakSign.Size=UDim2.fromOffset(150,27)
	self.streakSign.MaxDistance=40
	local nextCheck=0
	Run.RenderStepped:Connect(function()
		if os.clock()>=nextCheck then
			nextCheck=os.clock()+.12
			self:controls()
		end
		if self.arrow.Enabled then self.arrow.StudsOffsetWorldSpace=Vector3.new(0,6+.5*math.sin(os.clock()*4),0) end
	end)
	self.coins.Changed:Connect(function() if self.mode then self:render() end end)
	self:controls()
	return self
end
function View:hint()
	if self.data and self.data.guide=="tank" and self.data.staged.tank==2 then return "大燃料舱已装入 · 点组装，再去发射台" end
	return self.data and guidance[self.data.guide] or "正在载入进度…"
end
function View:controls()
	local w=self.data
	local idle=w and self.idle() and not self.busy and not self.mode and not self.animating
	local free=idle and self.flights.Value>0
	self.bagButton.Visible=free==true
	self.assemblePrompt.ActionText=w and w.pad and "打开组装舱" or "组装基础火箭"
	local nearest,best=nil,math.huge
	local character=Players.LocalPlayer.Character
	local root=character and character:FindFirstChild("HumanoidRootPart")
	local function consider(prompt,available)
		if not available or not root then return end
		local distance=(root.Position-prompt.Parent.Position).Magnitude
		if distance<=prompt.MaxActivationDistance and distance<best then nearest,best=prompt,distance end
	end
	consider(self.assemblePrompt,idle and (self.flights.Value>0 or w.guide=="assembly"))
	consider(self.padPrompt,idle and w.pad)
	consider(self.rollPrompt,free)
	consider(self.upPrompt,free)
	for slot,p in self.padPrompts do
		local tier=w and w.offers[slot]
		local offer=free and tier and tier>1 and not w.sold[slot]
		consider(p,offer)
		if offer then p.ActionText=("%s · %d 金币"):format(Parts.NAMES[slot][tier],Parts.PRICES[slot][tier]) end
	end
	for _,p in {self.assemblePrompt,self.padPrompt,self.rollPrompt,self.upPrompt} do p.Enabled=p==nearest end
	for _,p in self.padPrompts do p.Enabled=p==nearest end
	local target
	if idle then
		if w.guide=="assembly" or w.guide=="tank" then target=self.bay.Turntable
		elseif w.guide=="launch" or w.guide=="second" then target=self.pad
		elseif w.guide=="roll" then target=self.rollPart end
	end
	self.arrow.Adornee=target
	self.arrow.Enabled=target~=nil
end
function View:command(op,slot,tier)
	if self.busy or self.animating or not self.data or not self.idle() then return end
	self.busy=true
	self:controls()
	self.send(self.data.revision,op,slot,tier)
end
function View:close()
	if self.bayCamera then
		workspace.CurrentCamera.CameraType=Enum.CameraType.Custom
		self.bayCamera=nil
	end
	self.mode=nil
	self.panel.Visible=false
	self:controls()
end
function View:open(mode)
	if not self.data or not self.idle() or self.animating then return end
	self.mode=mode
	if mode=="bay" then
		self.tab=self.data.guide=="tank" and "tank" or self.tab
		local focus=self.bay.Turntable.Position+Vector3.yAxis*7
		local cam=workspace.CurrentCamera
		cam.CameraType=Enum.CameraType.Scriptable
		cam.CFrame=CFrame.lookAt(focus+Vector3.new(-34,11,17),focus+Vector3.new(0,1,4))
		self.bayCamera=true
	end
	self:render()
	self:controls()
end
local function route(p)
	local result={}
	for _,leg in p.legs do table.insert(result,(leg.body=="moon" and "月球" or "木星").." ×"..leg.orbits) end
	return table.concat(result," → ")
end
local function difference(w,slot,tier)
	local eq=table.clone(Rules.basic)
	for s,value in w.staged do eq[s]=value end
	local base=Rules.performance(eq)
	eq[slot]=tier
	local nextPlan=Rules.performance(eq)
	if nextPlan.route=="ground" then return ("无法起飞 · 推重比 %.2f"):format(nextPlan.twr) end
	return ("Δv %+d · 金币/趟 %+d"):format(math.round((nextPlan.dv or 0)-(base.dv or 0)),(nextPlan.coins or 0)-(base.coins or 0))
end
function View:render()
	local mode,w=self.mode,self.data
	if not mode or not w then return end
	local portrait=workspace.CurrentCamera.ViewportSize.X<650
	self.panel.Size=if portrait then UDim2.fromScale(.96,.56) else UDim2.fromScale(.43,.70)
	self.panel.Position=if portrait then UDim2.fromScale(.02,.42) else UDim2.fromScale(.55,.20)
	for _,child in self.scroll:GetChildren() do if child:IsA("GuiObject") then child:Destroy() end end
	local order=0
	local function row(label,fn,enabled)
		local item=textBox(self.scroll,label,fn,enabled)
		order+=1
		item.LayoutOrder=order
		return item
	end
	local dismiss=function() self:close() self.tell(self:hint()) end
	row(mode=="unlock" and "返回组装舱" or "关闭 ×",mode=="unlock" and function() self:open("bay") end or dismiss)
	if mode=="unlock" then
		row("新星球已解锁 · 木星")
		row("月球后继续飞向木星\n每圈基础收益 60 金币\n继续提高 Δv 可增加木星圈数")
	elseif mode=="upgrade" then
		local lv=Arms.LEVELS[w.level]
		row(("L%d %s · 回收奖金 %d · 完美窗口 %.2f 秒"):format(w.level,lv.name,lv.bonus,lv.win))
		if lv.cost then
			local nextLv=Arms.LEVELS[w.level+1]
			row(("下一级 · %s · 回收 %d · 完美窗口 %.2f 秒"):format(nextLv.name,nextLv.bonus,nextLv.win))
			local gap=lv.cost-self.coins.Value
			row(gap>0 and ("还差 %d 金币"):format(gap) or ("升级 · %d 金币"):format(lv.cost),function() self:command("upgrade") end,gap<=0)
		else row("支架已满级") end
	elseif mode=="roll" then
		row("免费 Roll · 基础 55% / 高级 35% / 精英 10%")
		for _,slot in Parts.SLOTS do
			local tier=w.offers[slot]
			if tier then
				local price=Parts.PRICES[slot][tier]
				local owned=w.bag[slot.."_"..tier] or 0
				local status=if w.sold[slot] then "已入包" elseif tier==1 then "不限量" elseif price>self.coins.Value then ("还差 %d 金币"):format(price-self.coins.Value) else ("购买 %d 金币"):format(price)
				row(("%s · %s · 已有 %s\n%s"):format(Parts.NAMES[slot][tier],status,tier==1 and "∞" or owned,difference(w,slot,tier)),function() self:command("buy",slot,tier) end,not w.sold[slot] and tier>1 and price<=self.coins.Value)
			end
		end
		row("再 Roll 一次",function() self:command("roll") end)
	else
		local editable=mode=="bay"
		local p,reason=Workshop.preview(w.staged)
		row(editable and "组装舱 · 待组装" or "背包 · 前往组装舱可装配")
		if editable then
			row(p and (("推重比 %.2f · 干重 %.1f / 湿重 %.1f t · Δv %d\n%s"):format(p.twr,p.dry,p.wet,math.round(p.dv or 0),reason or (route(p)..(" · %d 金币 / %.1f 秒"):format(p.coins,p.duration)))) or reason)
			if p and p.ideal then row(("理想 Δv %d  − 重力 %d  − 阻力 %d  − 姿态 %d"):format(math.round(p.ideal),math.round(p.gravity),math.round(p.drag),math.round(p.stability))) end
		end
		for _,slot in Parts.SLOTS do
			local selected=w.staged[slot]
			row((slot==self.tab and "▾ " or "▸ ")..Parts.SLOT_NAMES[slot].."  ·  "..(selected and Parts.NAMES[slot][selected] or "空槽"),function() self.tab=slot self:render() end)
			if slot==self.tab then
				for tier=1,3 do
					local count=w.bag[slot.."_"..tier] or 0
					row(("%s · %s  |  %s"):format(Parts.NAMES[slot][tier],tier==1 and "∞" or ("×"..count),difference(w,slot,tier)),function() self:command("stage",slot,tier) end,editable and self.flights.Value>0 and selected~=tier and (tier==1 or count>0))
				end
				if editable and selected and self.flights.Value>0 then row("移出"..Parts.SLOT_NAMES[slot],function() self:command("stage",slot,0) end) end
			end
		end
		if editable then row(reason or "组装并运上发射台",function() self:command("assemble") end,reason==nil).BackgroundColor3=reason and muted or accent end
	end
	self.panel.Visible=true
end
function View:staging()
	local w=self.data
	local count=0
	for i,slot in Parts.SLOTS do
		if w.staged[slot] then count+=1 end
		AB.setDock(self.bay,i,w.staged[slot],self.color)
	end
	AB.setHolo(self.bay,w.staged,self.color)
	local _,reason=Workshop.preview(w.staged)
	AB.setStatus(self.bay,reason and "staging" or "ready",count)
end
function View:offers()
	local w=self.data
	for i,slot in Parts.SLOTS do
		local mode=if w.sold[slot] then "sold" elseif w.offers[slot] then "offer" else "idle"
		Parts.setState(self.rollArea["PartPad_"..i],{mode=mode,tier=w.offers[slot]},{homeColor=self.color})
	end
end
function View:update(w,op,slot,reason,streak,best)
	local prev=self.data
	self.data=w
	self.busy=false
	self.streakText.Text=("连续完美 %d · 最佳 %d"):format(streak,best)
	if op=="error" then self.tell(reason) self:render() self:controls() return end
	if op=="init" then
		self:staging()
		self:offers()
		JR.setUnlocked(w.jupiter and 1 or 0)
		if w.pad then
			local old=self.area:WaitForChild("PadRocket")
			local rebuilt=RK.build(w.pad,self.color,old:GetPivot(),self.area)
			old:Destroy()
			rebuilt.Name="PadRocket"
			local arms=self.area:WaitForChild("CatchArms")
			Arms.setPose(arms,Catch.fitClose(arms,rebuilt))
		end
		self.tell(self:hint())
	elseif op=="roll" then
		self.animating=true
		self:controls()
		local show=RR.prepare(self.rollArea,w.offers,{homeColor=self.color})
		local start=os.clock()
		repeat
			show:runTo(math.min(1,(os.clock()-start)/1.2)*show.duration)
			Run.RenderStepped:Wait()
		until os.clock()-start>=1.2
		show:runTo(show.duration)
		show:cleanup()
		self:offers()
		self:staging()
		self.animating=false
		self:open("roll")
		self.tell(w.rolls==1 and "首抽赠送 · 大燃料舱已入包，回组装舱替换基础燃料舱" or "部件已揭晓")
	elseif op=="buy" then
		self.animating=true
		self:controls()
		local i=table.find(Parts.SLOTS,slot)
		local root=Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		if root then RR.buy(self.rollArea["PartPad_"..i],root,{homeColor=self.color}) end
		self:offers()
		self.animating=false
		self.tell("已购买 · "..Parts.NAMES[slot][w.offers[slot]].."已入背包")
	elseif op=="assemble" then
		self:close()
	elseif op=="stage" then
		self.tell(self:hint())
		self:staging()
		if w.jupiter and prev and not prev.jupiter then
			self.animating=true
			self.panel.Visible=false
			self:controls()
			self.tell("木星进入射程！")
			task.wait(1)
			JR.play({camera=true})
			self.animating=false
			self:open("unlock")
		end
	elseif op=="upgrade" then self.tell(("支架已升级至 L%d"):format(w.level))
	end
	self:render()
	self:controls()
end
return View