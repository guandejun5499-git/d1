return function(R)
	local chain,on=R.chain(0,"PERFECT")
	assert(chain==1 and not on)
	chain,on=R.chain(chain,"PERFECT")
	assert(chain==2 and on)
	assert(R.gate(.25,.18,on)=="PERFECT")
	chain,on=R.chain(chain,"GREAT")
	assert(chain==0 and not on)
	assert(R.gate(.25,.18,on)=="GREAT")
	assert(R.gate(.53,.18,false)=="OK" and R.gate(.55,.18,false)=="MISS")
	assert(R.ignition(1.36)=="perfect" and R.ignition(3.265)=="super")
	assert(R.ignition(3.4)=="stall" and R.ignition(.3)=="normal")
	assert(R.catch(.15,.16)=="perfect" and R.catch(.5,.16)=="great")
	assert(R.catch(.6,.16)=="early" and R.catch(-.01,.16)=="crash")
	local clock={wall=1,t=2,rate=1.2,slow=8}
	assert(math.abs(R.position(clock,7)-8.36)<.00001)
	return true
end