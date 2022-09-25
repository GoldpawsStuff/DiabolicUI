--[[

	The MIT License (MIT)

	Copyright (c) 2022 Lars Norberg

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.

--]]
local Addon, ns = ...
local oUF = ns.oUF
local AceTimer = LibStub and LibStub("AceTimer-3.0", true)
local Timer = AceTimer and AceTimer:Embed({})

-- Lua API
local math_huge = math.huge
local ipairs = ipairs
local select = select
local tonumber = tonumber

-- WoW API
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
local GetInventoryItemID = GetInventoryItemID
local GetInventorySlotInfo = GetInventorySlotInfo
local GetItemInfo = GetItemInfo
local GetTime = GetTime
local UnitAttackSpeed = UnitAttackSpeed
local UnitGUID = UnitGUID


local mh = GetInventorySlotInfo("MainHandSlot")
local oh = GetInventorySlotInfo("SecondaryHandSlot")

local playerGUID
local lastSwingMain, lastSwingOff
local swingDurationMain, swingDurationOff, mainSwingOffset
local mainTimer, offTimer
local mainSpeed, offSpeed = UnitAttackSpeed("player")
local casting = false
local skipNextAttack, skipNextAttackCount
local isAttacking

local RESET = {}
local RESET_RANGED = {
	[2480] = true, -- Shoot Bow
	[7919] = true, -- Shoot Crossbow
	[7918] = true, -- Shoot Gun
	[2764] = true, -- Throw
	[5019] = true, -- Shoot Wands
	[75] = true, -- Auto Shot
}
local NO_RESET = {
	[23063] = true, -- Dense Dynamite
	[4054] = true, -- Rough Dynamite
	[4064] = true, -- Rough Copper Bomb
	[4061] = true, -- Coarse Dynamite
	[8331] = true, -- Ez-Thro Dynamite
	[4065] = true, -- Large Copper Bomb
	[4066] = true, -- Small Bronze Bomb
	[4062] = true, -- Heavy Dynamite
	[4067] = true, -- Big Bronze Bomb
	[4068] = true, -- Iron Grenade
	[23000] = true, -- Ez-Thro Dynamite II
	[12421] = true, -- Mithril Frag Bomb
	[4069] = true, -- Big Iron Bomb
	[12562] = true, -- The Big One
	[12543] = true, -- Hi-Explosive Bomb
	[19769] = true, -- Thorium Grenade
	[19784] = true, -- Dark Iron Bomb
	[30216] = true, -- Fel Iron Bomb
	[19821] = true, -- Arcane Bomb
	[39965] = true, -- Frost Grenade
	[30461] = true, -- The Bigger One
	[30217] = true, -- Adamantite Grenade
	[35476] = true, -- Drums of Battle
	[35475] = true, -- Drums of War
	[35477] = true, -- Drums of Speed
	[35478] = true, -- Drums of Restoration
	[34120] = true, -- Steady Shot (rank 1)
	[19434] = true, -- Aimed Shot (rank 1)
	--35474 Drums of Panic DO reset the swing timer, do not add
}


local GetSwingTimerInfo = function(hand)
	if (hand == "main") then
		local itemId = GetInventoryItemID("player", mh)
		local name, _, _, _, _, _, _, _, _, icon = GetItemInfo(itemId or 0)
		if (lastSwingMain) then
			return swingDurationMain, lastSwingMain + swingDurationMain - mainSwingOffset, name, icon
		else
			return 0, math_huge, name, icon
		end
	elseif (hand == "off") then
		local itemId = GetInventoryItemID("player", oh)
		local name, _, _, _, _, _, _, _, _, icon = GetItemInfo(itemId or 0)
		if (lastSwingOff) then
			return swingDurationOff, lastSwingOff + swingDurationOff, name, icon
		else
			return 0, math_huge, name, icon
		end
	end

	return 0, math_huge
end

local SwingEnd = function(hand)
	if (hand == "main") then
		lastSwingMain, swingDurationMain, mainSwingOffset = nil, nil, nil
	elseif (hand == "off") then
		lastSwingOff, swingDurationOff = nil, nil
	end
	-- SWING_TIMER_UPDATE
end

local SwingStart = function(hand)
	mainSpeed, offSpeed = UnitAttackSpeed("player")
	offSpeed = offSpeed or 0
	local currentTime = GetTime()
	if (hand == "main") then
		lastSwingMain = currentTime
		swingDurationMain = mainSpeed
		mainSwingOffset = 0
		if (mainTimer) then
			Timer:CancelTimer(mainTimer)
		end
		if (mainSpeed and mainSpeed > 0) then
			mainTimer = Timer:ScheduleTimer(SwingEnd, mainSpeed, hand)
		else
			SwingEnd(hand)
		end
	elseif (hand == "off") then
		lastSwingOff = currentTime
		swingDurationOff = offSpeed
		if (offTimer) then
			Timer:CancelTimer(offTimer)
		end
		if (offSpeed and offSpeed > 0) then
			offTimer = Timer:ScheduleTimer(SwingEnd, offSpeed, hand)
		else
			SwingEnd(hand)
		end
	end
end

local SwingTimerCheck = function(self, event, unit, guid, spell)
	if (event ~= "PLAYER_EQUIPMENT_CHANGED") and (unit and unit ~= "player") then 
		return 
	end

	if (event == "UNIT_ATTACK_SPEED") then
		local mainSpeedNew, offSpeedNew = UnitAttackSpeed("player")
		offSpeedNew = offSpeedNew or 0

		if (lastSwingMain) then
			if (mainSpeedNew ~= mainSpeed) then
				Timer:CancelTimer(mainTimer)
				local multiplier = mainSpeedNew / mainSpeed
				local timeLeft = (lastSwingMain + swingDurationMain - GetTime()) * multiplier
				swingDurationMain = mainSpeedNew
				mainTimer = Timer:ScheduleTimer(SwingEnd, timeLeft, "main")
			end
		end
		if (lastSwingOff) then
			if offSpeedNew ~= offSpeed then
				Timer:CancelTimer(offTimer)
				local multiplier = offSpeedNew / mainSpeed
				local timeLeft = (lastSwingOff + swingDurationOff - GetTime()) * multiplier
				swingDurationOff = offSpeedNew
				offTimer = Timer:ScheduleTimer(SwingEnd, timeLeft, "off")
			end
		end
		mainSpeed, offSpeed = mainSpeedNew, offSpeedNew
		-- SWING_TIMER_UPDATE

	elseif (casting) and (event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED") then
		casting = false

	elseif (event == "PLAYER_EQUIPMENT_CHANGED" and isAttacking) then
		SwingStart("main")
		SwingStart("off")
		-- SWING_TIMER_UPDATE

	elseif (event == "UNIT_SPELLCAST_SUCCEEDED") then
		if (RESET[spell] or casting) then
			if (casting) then
				casting = false
			end
			if (isAttacking) then
				SwingStart("main")
				-- SWING_TIMER_UPDATE
			end
		end
		if (RESET_RANGED[spell]) then
			SwingStart("main")
			-- SWING_TIMER_UPDATE
		end
	elseif (event == "UNIT_SPELLCAST_START") then
		if (not NO_RESET[spell]) then
			-- pause swing timer
			casting = true
			lastSwingMain, swingDurationMain, mainSwingOffset = nil, nil, nil
			lastSwingOff, swingDurationOff = nil, nil
			-- SWING_TIMER_UPDATE
		end

	elseif (event == "PLAYER_ENTER_COMBAT") then
		isAttacking = true

	elseif (event == "PLAYER_LEAVE_COMBAT") then
		isAttacking = nil
	end

end

local SwingTimerCLEUCheck = function(self, _, unit, ts, event, _, sourceGUID, _, _, _, destGUID, _, _, _, ...)
	if (sourceGUID == playerGUID) then
		if (event == "SPELL_EXTRA_ATTACKS") then
			skipNextAttack = ts
			skipNextAttackCount = select(4, ...)

		elseif (event == "SWING_DAMAGE" or event == "SWING_MISSED") then
			if (skipNextAttack == ts and tonumber(skipNextAttackCount)) then
				if (skipNextAttackCount > 0) then
					skipNextAttackCount = skipNextAttackCount - 1
					return
				end
			end
			local isOffHand = select(event == "SWING_DAMAGE" and 10 or 2, ...)
			if (not isOffHand) then
				SwingStart("main")
			elseif(isOffHand) then
				SwingStart("off")
			end
			-- SWING_TIMER_UPDATE
		end

	elseif (destGUID == playerGUID and (... == "PARRY" or select(4, ...) == "PARRY")) then
		if (lastSwingMain) then
			local timeLeft = lastSwingMain + swingDurationMain - GetTime()
			if (timeLeft > .6 * swingDurationMain) then
				Timer:CancelTimer(mainTimer)
				mainTimer = Timer:ScheduleTimer(SwingEnd, timeLeft - .4 * swingDurationMain, "main")
				mainSwingOffset = .4 * swingDurationMain
				-- SWING_TIMER_UPDATE

			elseif (timeLeft > .2 * swingDurationMain) then
				Timer:CancelTimer(mainTimer)
				mainTimer = Timer:ScheduleTimer(SwingEnd, timeLeft - .2 * swingDurationMain, "main")
				mainSwingOffset = .2 * swingDurationMain
				-- SWING_TIMER_UPDATE

			end
		end
	end
end

local Update = function(self, event, unit, ...)
	if (not unit or self.unit ~= unit) then return end
	local element = self.SwingTimer

	--[[ Callback: SwingTimer:PreUpdate(unit)
	Called before the element has been updated.

	* self - the SwingTimer element
	* unit - the unit for which the update has been triggered (string)
	--]]
	if (element.PreUpdate) then
		element:PreUpdate(unit)
	end

	if (event == "COMBAT_LOG_EVENT_UNFILTERED") then
		SwingTimerCLEUCheck(self, event, unit, CombatLogGetCurrentEventInfo())
	else
		SwingTimerCheck(self, event, unit, ...)
	end

	--[[ Callback: SwingTimer:PostUpdate(unit)
	Called after the element has been updated.

	* self - the SwingTimer element
	* unit - the unit for which the update has been triggered (string)
	--]]
	if (element.PostUpdate) then
		element:PostUpdate(unit)
	end
end

local Path = function(self, ...)
	--[[ Override: SwingTimer.Override(self, event, unit)
	Used to completely override the internal update function.

	* self  - the parent object
	* event - the event triggering the update (string)
	* unit  - the unit accompanying the event (string)
	--]]
	(self.SwingTimer.Override or Update) (self, ...)
end

local ForceUpdate = function(element)
	Path(element.__owner, "ForceUpdate", element.__owner.unit)
end


local Enable = function(self, unit)
	local element = self.SwingTimer
	if (element) then
		element.__owner = self
		element.ForceUpdate = ForceUpdate

		if (unit ~= "player") or (not Timer) then
			element:Hide()
			return
		end

		self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", Path, true)
		self:RegisterEvent("PLAYER_ENTER_COMBAT", Path, true)
		self:RegisterEvent("PLAYER_LEAVE_COMBAT", Path, true)
		self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", Path, true)
		self:RegisterEvent("UNIT_ATTACK_SPEED", Path)
		self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")

		playerGUID = UnitGUID("player")

		element:Hide()

		return true
	end
end

local Disable = function(self)
	local element = self.SwingTimer
	if (element) then
		element:Hide()

		self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED", Path)
		self:UnregisterEvent("PLAYER_ENTER_COMBAT", Path)
		self:UnregisterEvent("PLAYER_LEAVE_COMBAT", Path)
		self:UnregisterEvent("PLAYER_EQUIPMENT_CHANGED", Path)
		self:UnregisterEvent("UNIT_ATTACK_SPEED", Path)
		self:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED", Path)
		self:UnregisterEvent("UNIT_SPELLCAST_START", Path)
		self:UnregisterEvent("UNIT_SPELLCAST_INTERRUPTED", Path)
		self:UnregisterEvent("UNIT_SPELLCAST_FAILED", Path)
	end
end

oUF:AddElement("SwingTimer", Path, Enable, Disable)
