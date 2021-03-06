
--------------------------------------------------------------------------------
-- TODO List:
-- - the cd timers really suck on this fight
-- - on mythic testing she started with p2 sometimes. i guess thats a bug, change timers if its intended
-- - i assume that they changed a lot of timers after heroic testing.
--   need some heroic data to verify that they've beed changed there also.
-- - dont show bars for stuff that would happen during HeartOfTheSwarm

--------------------------------------------------------------------------------
-- Module Declaration
--

local mod, CL = BigWigs:NewBoss("Nythendra", 1094, 1703)
if not mod then return end
mod:RegisterEnableMob(102672)
mod.engageId = 1853
mod.respawnTime = 30

--------------------------------------------------------------------------------
-- Locals
--

local rotCount = 1
local mindControlledPlayers = 0

--------------------------------------------------------------------------------
-- Localization
--

local L = mod:GetLocale()

--------------------------------------------------------------------------------
-- Initialization
--

function mod:GetOptions()
	return {
		--[[ General ]]--
		202977, -- Infested Breath
		{203096, "SAY", "FLASH", "PROXIMITY"}, -- Rot
		{204463, "SAY", "FLASH"}, -- Volatile Rot
		203552, -- Heart of the Swarm
		203045, -- Infested Ground
		"berserk",

		--[[ Mythic ]]--
		204504, -- Infested
		205043, -- Infested Mind
		205070, -- Spread Infestation
	},{
		[202977] = "general",
		[204504] = "mythic",
	}
end

function mod:OnBossEnable()
	--[[ General ]]--
	self:Log("SPELL_CAST_START", "InfestedBreath", 202977)
	self:Log("SPELL_AURA_APPLIED", "Rot", 203096)
	self:Log("SPELL_AURA_REMOVED", "RotRemoved", 203096)
	self:Log("SPELL_AURA_APPLIED", "VolatileRot", 204463)
	self:Log("SPELL_CAST_START", "HeartOfTheSwarm", 203552)
	self:Log("SPELL_AURA_APPLIED", "InfestedGroundDamage", 203045)
	self:Log("SPELL_PERIODIC_DAMAGE", "InfestedGroundDamage", 203045)
	self:Log("SPELL_PERIODIC_MISSED", "InfestedGroundDamage", 203045)

	--[[ Mythic ]]--
	self:Log("SPELL_AURA_APPLIED_DOSE", "Infested", 204504) -- also on hc, but i don't think it's relevant there
	self:Log("SPELL_AURA_APPLIED", "InfestedMind", 205043)
	self:Log("SPELL_AURA_APPLIED", "InfestedMindRemoved", 205043)
	self:Log("SPELL_CAST_START", "SpreadInfestation", 205070)
end

function mod:OnEngage()
	self:Message("berserk", "Neutral", nil, "Nythendra (Alpha) Engaged (Post Mythic Test Mod v2)", 23074) -- some red dragon icon
	rotCount = 1
	mindControlledPlayers = 0
	self:Berserk(720) -- 12 minutes on heroic, not kidding
	self:CDBar(203096, 10.5) -- Rot
	self:CDBar(204463, 22) -- Volatile Rot
	self:CDBar(202977, 38) -- Infested Breath
	self:CDBar(203552, 90) -- Heart of the Swarm
end

--------------------------------------------------------------------------------
-- Event Handlers
--

function mod:InfestedBreath(args)
	self:Message(args.spellId, "Urgent", "Alarm", CL.casting:format(args.spellName))
	self:Bar(args.spellId, 7, CL.cast:format(args.spellName)) -- 2s cast time + 5s channel
	self:CDBar(args.spellId, 45)  -- alpha mythic timing
end

do
	local playerList, proxList, isOnMe = mod:NewTargetList(), {}, nil
	function mod:Rot(args)
		if self:Me(args.destGUID) then
			isOnMe = true
			self:Flash(args.spellId)
			self:Say(args.spellId)
			self:TargetBar(args.spellId, 9, args.destName)
			self:OpenProximity(args.spellId, 10)
			self:ScheduleTimer("Say", 6, args.spellId, 3, true)
			self:ScheduleTimer("Say", 7, args.spellId, 2, true)
			self:ScheduleTimer("Say", 8, args.spellId, 1, true)
		end

		proxList[#proxList+1] = args.destName
		if not isOnMe then
			self:OpenProximity(args.spellId, 10, proxList)
		end

		playerList[#playerList+1] = args.destName
		if #playerList == 1 then
			self:ScheduleTimer("TargetMessage", 0.1, args.spellId, playerList, "Important", "Alert")
			rotCount = rotCount + 1
			--self:CDBar(args.spellId, rotCount == 2 and 34 or 21)  -- alpha heroic timing
			self:CDBar(args.spellId, 44)  -- mythic testing only had 2 rots per phase
		end
	end

	function mod:RotRemoved(args)
		if self:Me(args.destGUID) then
			isOnMe = nil
			self:StopBar(args.spellName, args.destName)
			self:CloseProximity(args.spellId)
		end

		tDeleteItem(proxList, args.destName)
		if not isOnMe then -- Don't change proximity if it's on you and expired on someone else
			if #proxList == 0 then
				self:CloseProximity(args.spellId)
			else
				self:OpenProximity(args.spellId, 10, proxList)
			end
		end
	end
end

function mod:VolatileRot(args)
	self:TargetMessage(args.spellId, args.destName, "Urgent", "Info", nil, nil, self:Tank())
	self:TargetBar(args.spellId, 8, args.destName)
	self:CDBar(args.spellId, 43) -- alpha mythic timing, cd was a lot less on heroic
	if self:Me(args.destGUID) then
		self:Say(args.spellId)
		self:Flash(args.spellId)
	end
end

function mod:HeartOfTheSwarm(args)
	self:Message(args.spellId, "Attention", "Long", CL.casting:format(args.spellName))
	self:Bar(args.spellId, 23.7, CL.cast:format(args.spellName)) -- 3.7s cast time + 20s channel
	-- This is basically a phase, so start timers for next "normal" phase here
	self:CDBar(args.spellId, 122) -- alpha mythic timing
	self:CDBar(203096, 41.2) -- Rot, 23.7 + 17.5, alpha mythic timing
	self:CDBar(204463, 52.7) -- Volatile Rot, 23.7 + 29, alpha mythic timing
	self:CDBar(202977, 66.7) -- Infested Breath, 23.7 + 43, alpha mythic timing
	rotCount = 1
end

do
	local prev = 0
	function mod:InfestedGroundDamage(args)
		local t = GetTime()
		if self:Me(args.destGUID) and t-prev > 1.5 then
			prev = t
			self:Message(args.spellId, "Personal", "Alert", CL.underyou:format(args.spellName))
		end
	end
end

function mod:Infested(args)
	if self:Mythic() and self:Me(args.destGUID) and args.amount > 6 then
		self:StackMessage(args.spellId, args.destName, args.amount, "Personal", "Warning")
	end
end

function mod:InfestedMind(args)
	self:TargetMessage(args.spellId, args.destName, "Important", "Alarm")
	mindControlledPlayers = mindControlledPlayers + 1
end

function mod:InfestedMindRemoved(args)
	mindControlledPlayers = mindControlledPlayers - 1
end


function mod:SpreadInfestation(args)
	if not self:Me(args.sourceGUID) and mindControlledPlayers < 4 then -- TODO hardcoded anti spam check (for wipes): only warn if max 3 players are mind controlled
		self:Message(args.spellId, "Attention", "Alert", CL.other:format(mod:ColorName(args.sourceName), CL.casting:format(args.spellName))) -- Player: Casting Spread Infestation!
	end
end
