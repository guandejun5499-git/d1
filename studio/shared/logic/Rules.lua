local R = {}
R.basic = {nose=1, tank=1, engine=1, fins=1}
local noses = {{1,1,1},{0.6,0.7,1.3},{1.8,0.9,2.2}}
local tanks = {{1,3},{1.6,6},{2.6,10}}
local engines = {{1.2,14,1,1},{1.6,22,1.05,1.3},{1.4,20,1.35,1.5}}
local fins = {{0.4,1,0.18},{0.5,1.3,0.22},{0.8,1.7,0.27}}

function R.performance(eq)
	local n,t,e,f = noses[eq.nose], tanks[eq.tank], engines[eq.engine], fins[eq.fins]
	local dry = n[1]+t[1]+e[1]+f[1]
	local wet = dry+t[2]
	local p = {dry=dry,wet=wet,twr=e[2]/wet,speed=e[4],coinFactor=n[3],window=f[3],laps={},legs={}}
	if p.twr < 1 then p.route="ground" return p end
	p.ideal = 1000*e[3]*math.log(wet/dry)
	p.gravity,p.drag,p.stability = 300/p.twr,100*n[2],80/f[2]
	p.dv = p.ideal-p.gravity-p.drag-p.stability
	if p.dv < 270 then p.route="suborbital" return p end
	local far = p.dv >= 900
	p.route = far and "jupiter" or "moon"
	local cursor = 3.6/p.speed
	p.coins = 0
	local function add(body,count,base,seconds)
		table.insert(p.legs,{body=body,orbits=count})
		for _=1,count do
			local duration=seconds/p.speed
			local lap={body=body,start=cursor,gate=cursor+duration,shards={cursor+.36*duration,cursor+.64*duration},base=base}
			p.coins += base*n[3]*(1+.5*#p.laps)
			table.insert(p.laps,lap)
			cursor=lap.gate
		end
	end
	add("moon",far and 1 or math.min(5,math.floor((p.dv-150)/120)),10,6)
	if far then
		cursor+=4.8/p.speed
		add("jupiter",math.min(3,1+math.floor((p.dv-900)/200)),60,8)
	end
	p.coins=math.round(p.coins)
	p.landStart=cursor+(far and 5.8 or 4.2)/p.speed
	p.duration=p.landStart+2.6
	return p
end

function R.gauge(t)
	if t<1.6 then return math.clamp(t/1.6,0,1),0 end
	if t<2.5 then return (t-1.6)/.9,1 end
	return math.clamp((t-2.5)/.9,0,1),2
end
function R.ignition(t)
	local v,stage=R.gauge(t)
	if stage==0 then
		if v>=.78 and v<=.92 then return "perfect",1.25 end
		if v>=.60 and v<=.97 then return "good",1.1 end
		return "normal",1
	end
	if stage==2 and v>=.82 and v<=.88 then return "super",1.6 end
	return "stall",1
end
function R.gate(errorTime,window,fever)
	local d=math.abs(errorTime-.04)
	local perfect=window+(fever and .05 or 0)
	if d<=perfect then return "PERFECT",2 end
	if d<=perfect+.18 then return "GREAT",1.5 end
	if d<=.5 then return "OK",1.2 end
	return "MISS",1
end
function R.chain(previous,grade)
	local count=if grade=="PERFECT" then previous+1 else 0
	return count,count>=2
end

function R.catch(left,win)
	if left<0 then return "crash",.5 end
	if left<=win then return "perfect",2 end
	if left<=win+.4 then return "great",1.4 end
	return "early",1
end
-- Clock segments are rebased whenever fever or an early catch changes playback speed.
function R.position(clock,now)
	local t=clock.t+math.max(0,now-clock.wall)*clock.rate
	if clock.slow and t>clock.slow then
		t=clock.slow+(t-clock.slow)*.36/clock.rate
	end
	return t
end
return R