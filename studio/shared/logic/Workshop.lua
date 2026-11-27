local Rules = require(script.Parent.Rules)
local shared = script.Parent.Parent
local Parts = require(shared.PartPad)
local Arms = require(shared.CatchArms)
local Workshop = {}

-- Numeric tiers match the existing art modules. Bag keys identify both slot and tier.
local function adjust(w,slot,tier,delta)
	if not tier or tier <= 1 then return end
	local key = slot.."_"..tier
	w.bag[key] = (w.bag[key] or 0) + delta
end

-- Inventory invariant (stock 2): every owned non-basic part is either in the bag or in a staged slot.
-- The pad is a snapshot of the staged set at assembly time, so its parts are not counted a second time.
-- Stock 1 cleared `staged` on assembly and kept the pad's parts outside both the bag and staged.
local STOCK = 2
local function migrate(w)
	if (w.stock or 1) >= STOCK then return end
	if w.pad then
		for _,slot in Parts.SLOTS do
			local onPad = w.pad[slot]
			if w.staged[slot] == nil then
				w.staged[slot] = onPad -- the pad part becomes the staged part
			else
				adjust(w,slot,onPad,1) -- slot already holds another copy: return the pad part to the bag
			end
		end
	end
	w.stock = STOCK
end

function Workshop.initialize(data)
	if data.workshop then
		migrate(data.workshop)
		return
	end
	local veteran = data.flights > 0
	data.workshop = {
		revision = 0, level = 1, rolls = 0, bag = {}, pity = {}, offers = {}, sold = {},
		staged = table.clone(Rules.basic), pad = veteran and table.clone(Rules.basic) or nil,
		guide = veteran and "roll" or "assembly", jupiter = false, reachedJupiter = false,
		stock = STOCK,
	}
end

function Workshop.preview(staged)
	for _,slot in Parts.SLOTS do
		if not staged[slot] then return nil, "还缺"..Parts.SLOT_NAMES[slot] end
	end
	local p = Rules.performance(staged)
	if not p.duration then
		return p, if p.route=="ground" then ("太重 · 推重比 %.2f"):format(p.twr) else "Δv 不足 270，无法入轨"
	end
	return p
end

local function roll(w,rng)
	local pity = {}
	local first = w.rolls == 0
	for _,slot in Parts.SLOTS do
		if (w.pity[slot] or 0)>=10 and not (first and slot=="tank") then table.insert(pity,slot) end
	end
	local guaranteed = {}
	for _=1,math.min(#pity,rng:NextInteger(1,2)) do
		guaranteed[table.remove(pity,rng:NextInteger(1,#pity))] = true
	end
	w.sold = {}
	for _,slot in Parts.SLOTS do
		local n = rng:NextInteger(1,100)
		local tier = if guaranteed[slot] or n>90 then 3 elseif n>55 then 2 else 1
		if first and slot=="tank" then tier=2 end
		w.offers[slot] = tier
		w.pity[slot] = if tier==3 then 0 else (w.pity[slot] or 0)+1
	end
	w.rolls += 1
	if first then
		adjust(w,"tank",2,1)
		w.sold.tank = true
		w.guide = "tank"
		for _,slot in Parts.SLOTS do w.staged[slot] = w.staged[slot] or 1 end
	end
end

function Workshop.apply(data,op,slot,tier,rng)
	local w = data.workshop
	if op=="roll" then
		if data.flights==0 then return "先完成首飞" end
		roll(w,rng)
	elseif op=="buy" then
		if not Parts.PRICES[slot] then return "未知部位" end
		local offer = w.offers[slot]
		if w.sold[slot] or offer~=tier or not offer or offer==1 then return "该部件不可购买" end
		local price = Parts.PRICES[slot][offer]
		if data.coins<price then return ("还差 %d 金币"):format(price-data.coins) end
		data.coins -= price
		w.sold[slot] = true
		adjust(w,slot,offer,1)
	elseif op=="stage" then
		if data.flights==0 then return "首飞使用预装基础件" end
		if not Parts.PRICES[slot] or not table.find({0,1,2,3},tier) then return "无效部件" end
		local old = w.staged[slot]
		if old==tier or (not old and tier==0) then return "槽位没有变化" end
		if tier>1 and (w.bag[slot.."_"..tier] or 0)<1 then return "背包数量不足" end
		adjust(w,slot,old,1)
		adjust(w,slot,tier,-1)
		w.staged[slot] = if tier>0 then tier else nil
		local p = Workshop.preview(w.staged)
		if p and p.route=="jupiter" then w.jupiter=true end
	elseif op=="assemble" then
		local _,reason = Workshop.preview(w.staged)
		if reason then return reason end
		-- Staged stays as the new rocket: parts swapped out of staged already went back to the bag,
		-- so nothing is returned here and the rocket's parts can be kept in the next build.
		w.pad = table.clone(w.staged)
		if w.guide=="assembly" then w.guide="launch" end
		if w.guide=="tank" and w.pad.tank>=2 then w.guide="second" end
	elseif op=="upgrade" then
		local cost = Arms.LEVELS[w.level].cost
		if not cost then return "支架已满级" end
		if data.flights==0 then return "先完成首飞" end
		if data.coins<cost then return ("还差 %d 金币"):format(cost-data.coins) end
		data.coins -= cost
		w.level += 1
	else
		return "未知操作"
	end
	w.revision += 1
end

function Workshop.landed(w,route)
	if w.guide=="launch" then w.guide="roll"
	elseif w.guide=="second" and w.pad.tank>=2 then w.guide="free" end
	if route=="jupiter" then w.reachedJupiter=true end
	w.revision += 1
end
return Workshop