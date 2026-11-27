-- Run in Studio with the shipped rules and art catalog.
return function(W,Rules)
	local Http=game:GetService("HttpService")
	local rng=Random.new(734)
	local function fresh(flights)
		local d={coins=1000,flights=flights}
		W.initialize(d)
		return d
	end
	local d=fresh(0)
	local function apply(op,slot,tier)
		assert(W.apply(d,op,slot,tier,rng)==nil,op)
	end
	local function denied(op,slot,tier)
		local revision=d.workshop.revision
		assert(W.apply(d,op,slot,tier,rng)~=nil)
		assert(d.workshop.revision==revision)
	end
	denied("roll")
	apply("assemble")
	assert(d.workshop.guide=="launch")
	d.flights=1
	W.landed(d.workshop,"moon")
	apply("roll")
	local w=d.workshop
	assert(w.guide=="tank" and w.bag.tank_2==1 and w.sold.tank)
	denied("buy","tank",2)
	apply("stage","tank",2)
	assert(w.bag.tank_2==0 and w.pad.tank==1)
	d=Http:JSONDecode(Http:JSONEncode(d))
	W.initialize(d)
	w=d.workshop
	assert(w.staged.tank==2 and w.pad.tank==1 and w.guide=="tank")
	apply("assemble")
	-- staged stays as the rocket on the pad (inventory: bag + staged)
	assert(w.pad.tank==2 and w.staged.tank==2 and w.guide=="second")
	assert(#Rules.performance(w.pad).laps==2)
	W.landed(w,"moon")
	assert(w.guide=="free")
	w.offers.engine=3
	w.sold.engine=false
	denied("buy","engine",2)
	apply("buy","engine",3)
	assert(d.coins==780 and w.bag.engine_3==1)
	denied("buy","engine",3)
	w.offers.tank=3
	w.sold.tank=false
	apply("buy","tank",3)
	apply("stage","tank",3)
	assert(w.bag.tank_2==1 and w.bag.tank_3==0)
	denied("assemble") -- basic + giant + basic + basic is too heavy
	apply("stage","engine",3)
	assert(w.jupiter and not w.reachedJupiter)
	apply("stage","engine",0)
	assert(w.jupiter and w.bag.engine_3==1 and w.bag.engine_0==nil)
	denied("assemble") -- missing engine
	apply("stage","engine",3)
	apply("assemble")
	assert(w.bag.tank_2==1 and w.pad.tank==3 and w.pad.engine==3)
	W.landed(w,"jupiter")
	assert(w.reachedJupiter)
	-- regression: swap one slot and keep the elite parts already on the rocket
	w.offers.nose=2
	w.sold.nose=false
	apply("buy","nose",2)
	apply("stage","nose",2)
	apply("assemble")
	assert(w.pad.nose==2 and w.pad.tank==3 and w.pad.engine==3)
	assert(w.bag.nose_2==0 and w.bag.tank_3==0 and w.bag.engine_3==0 and w.bag.tank_2==1)
	for _,cost in {50,140,320} do
		local before=d.coins
		apply("upgrade")
		assert(d.coins==before-cost)
	end
	denied("upgrade")
	d.coins=0
	w.offers.fins=2
	w.sold.fins=false
	denied("buy","fins",2)
	-- stock 1 saves: pad parts lived outside bag and staged
	local old={coins=0,flights=4,workshop={revision=7,level=1,rolls=3,bag={tank_2=1},pity={},offers={},sold={},
		staged={nose=2},pad={nose=1,tank=3,engine=3,fins=1},guide="free",jupiter=true,reachedJupiter=true}}
	W.initialize(old)
	local ow=old.workshop
	assert(ow.stock==2 and ow.staged.nose==2 and ow.staged.tank==3 and ow.staged.engine==3 and ow.staged.fins==1)
	assert(ow.bag.tank_2==1 and ow.bag.tank_3==nil and ow.bag.engine_3==nil)
	W.initialize(old) -- migration runs once
	assert(ow.staged.tank==3 and ow.bag.tank_3==nil)
	local legacy=fresh(3)
	assert(legacy.workshop.pad.tank==1 and legacy.workshop.guide=="roll")
	d=legacy
	apply("roll")
	apply("roll")
	assert(d.workshop.bag.tank_2==1)
	local allMiss={NextInteger=function(_,a) return a end}
	d.workshop.pity={nose=10,tank=10,engine=10,fins=10}
	assert(W.apply(d,"roll",nil,nil,allMiss)==nil)
	assert(d.workshop.offers.nose==3 and d.workshop.pity.nose==0 and d.workshop.pity.tank==11)
	local counts={0,0,0}
	for _=1,2500 do
		d.workshop.pity={}
		apply("roll")
		for _,tier in d.workshop.offers do counts[tier]+=1 end
	end
	assert(math.abs(counts[1]/10000-.55)<.025)
	assert(math.abs(counts[2]/10000-.35)<.025)
	assert(math.abs(counts[3]/10000-.10)<.02)
	return {offers=counts,checks="gift, migration, resume, inventory, invalid builds, orbit, unlock, upgrade, pity"}
end