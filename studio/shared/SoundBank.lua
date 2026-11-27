local Debris=game:GetService("Debris")
local SoundService=game:GetService("SoundService")
local tickSample=122293143209564
local impact=9125672726
local blast=12222065
-- Free Creator Store samples. IDs, mix levels and playback rates are centralized here.
local cues={
	roll={tickSample,.8,.32}, reveal={tickSample,1.6,.45}, buy={135483737426662,1.85,.38},
	assemble={impact,.75,.43}, weld={9119992547,1.9,.35},
	charge={92777055952573,.7,.30}, launch={blast,1.15,.50}, super={blast,.72,.62},
	count={tickSample,1.1,.32}, beat={tickSample,1.8,.44}, shard={tickSample,2,.52},
	lock={impact,1.8,.44}, perfect={tickSample,1.5,.48}, crash={blast,.8,.55},
	streakEnd={75541012837733,1.6,.28}, row={tickSample,1.3,.32}, claim={135483737426662,1.8,.40},
	unlock={81435732851200,1,.50}, kick={137721550021975,.64,.3}, snare={101273489328917,1.6,.23}, arpeggio={tickSample,1.4,.2},
}
local Bank={}
function Bank.play(name,parent,ratio,looped)
	local cue=cues[name]
	local s=Instance.new("Sound")
	s.Name="Orbit_"..name
	s.SoundId="rbxassetid://"..cue[1]
	s.Volume=cue[3]
	s.PlaybackSpeed=cue[2]*(ratio or 1)
	s.RollOffMaxDistance=130
	s.Looped=looped==true
	s.Parent=parent or SoundService
	s:Play()
	if not looped then Debris:AddItem(s,4) end
	return s
end
function Bank.chord(name)
	for i,r in {1,1.25,1.5} do task.delay((i-1)*.10,Bank.play,name,nil,r) end
end
local generation=0
local playing=false
function Bank.fever(on)
	if playing==on then return end
	playing=on
	if not on then Bank.play("streakEnd") end
	generation+=1
	local id=generation
	if not on then return end
	task.spawn(function()
		local step=0
		while generation==id do
			Bank.play(step%4==2 and "snare" or "kick")
			Bank.play("arpeggio",nil,({1,1.25,1.5,2})[step%4+1])
			step+=1 task.wait(.25)
		end
	end)
end
return Bank
