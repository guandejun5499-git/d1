return function(R)
	local rows={
		{1111,2.12,285,1,0,10,16.4},{1211,1.37,489,2,0,25,22.4},
		{1221,2.08,552,3,0,45,22.4},{1321,1.41,683,4,0,70,27.1},
		{3332,1.23,887,5,0,220,27.8},{2233,1.92,888,5,0,130,27.8},
		{2231,2,937,1,1,130,21.4},{1331,1.3,1004,1,1,100,21.4},
		{2332,1.32,1107,1,2,286,26.7},{1311,.92,nil,0,0},{3111,1.89,191,0,0}
	}
	for _,row in rows do
		local n,t,e,f=tostring(row[1]):match("(.)(.)(.)(.)")
		local p=R.performance({nose=tonumber(n),tank=tonumber(t),engine=tonumber(e),fins=tonumber(f)})
		local function check(value,want)
			assert(value==want,("%d expected %s got %s"):format(row[1],tostring(want),tostring(value)))
		end
		check(math.round(p.twr*100)/100,row[2])
		check(p.dv and math.round(p.dv),row[3])
		check(p.legs[1] and p.legs[1].orbits or 0,row[4])
		check(p.legs[2] and p.legs[2].orbits or 0,row[5])
		check(p.coins,row[6])
		check(p.duration and math.round(p.duration*10)/10,row[7])
	end
	return #rows
end