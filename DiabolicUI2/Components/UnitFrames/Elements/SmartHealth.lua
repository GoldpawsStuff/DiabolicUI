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

-- WoW API
local UnitCanAttack = UnitCanAttack
local UnitClass = UnitClass
local UnitGetTotalAbsorbs = UnitGetTotalAbsorbs
local UnitGUID = UnitGUID
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitIsConnected = UnitIsConnected
local UnitIsPlayer = UnitIsPlayer
local UnitIsTapDenied = UnitIsTapDenied
local UnitPlayerControlled = UnitPlayerControlled
local UnitReaction = UnitReaction
local UnitThreatSituation = UnitThreatSituation

local UpdateColor = function(self, event, unit)
	if (not unit or self.unit ~= unit) then return end
	local element = self.SmartHealth

	local r, g, b, t
	if (element.colorDisconnected and not UnitIsConnected(unit)) then
		t = self.colors.disconnected
	elseif (element.colorTapping and UnitCanAttack("player", unit) and not UnitPlayerControlled(unit) and UnitIsTapDenied(unit)) then
		t = self.colors.tapped
	elseif (element.colorThreat and not UnitPlayerControlled(unit) and UnitThreatSituation("player", unit)) then
		t =  self.colors.threat[UnitThreatSituation("player", unit)]
	elseif (element.colorClass and UnitIsPlayer(unit))
		or (element.colorClassNPC and not UnitIsPlayer(unit))
		or (element.colorClassPet and UnitPlayerControlled(unit) and not UnitIsPlayer(unit)) then
		local _, class = UnitClass(unit)
		t = self.colors.class[class]
	elseif (element.colorReaction and UnitReaction(unit, "player")) then
		t = self.colors.reaction[UnitReaction(unit, "player")]
	elseif (element.colorHealth) then
		t = self.colors.health
	end

	if (t) then
		r, g, b = t[1], t[2], t[3]
	end

	if (b) then
		element:SetStatusBarColor(r, g, b)

		local bg = element.bg
		if (bg) then
			local mu = bg.multiplier or 1
			bg:SetVertexColor(r * mu, g * mu, b * mu)
		end
	end

	--[[ Callback: SmartHealth:PostUpdateColor(unit, r, g, b)
	Called after the element color has been updated.

	* self - the SmartHealth element
	* unit - the unit for which the update has been triggered (string)
	* r    - the red component of the used color (number)[0-1]
	* g    - the green component of the used color (number)[0-1]
	* b    - the blue component of the used color (number)[0-1]
	--]]
	if (element.PostUpdateColor) then
		element:PostUpdateColor(unit, r, g, b)
	end
end

local ColorPath = function(self, ...)
	--[[ Override: SmartHealth.UpdateColor(self, event, unit)
	Used to completely override the internal function for updating the widgets' colors.

	* self  - the parent object
	* event - the event triggering the update (string)
	* unit  - the unit accompanying the event (string)
	--]]
	(self.SmartHealth.UpdateColor or UpdateColor) (self, ...)
end

local Update = function(self, event, unit)
	if (not unit or self.unit ~= unit) then return end
	local element = self.SmartHealth

	--[[ Callback: SmartHealth:PreUpdate(unit)
	Called before the element has been updated.

	* self - the SmartHealth element
	* unit - the unit for which the update has been triggered (string)
	--]]
	if (element.PreUpdate) then
		element:PreUpdate(unit)
	end

	-- Different GUID means a different player or NPC,
	-- so we want updates to be instant, not smoothed. 
	local guid = UnitGUID(unit)
	local forced = (guid ~= element.guid) or (UnitIsDeadOrGhost(unit))
	element.guid = guid

	local absorb
	local cur, max = UnitHealth(unit), UnitHealthMax(unit)
	local connected = UnitIsConnected(unit)

	if ((element.showAbsorbGap) or (element.showAbsorbAsHealth)) then
		absorb = UnitGetTotalAbsorbs(unit) or 0
		if (max + absorb ~= (element.max or 0) + (element.absorb or 0)) then
			forced = true
		end
		element:SetMinMaxValues(0, max + absorb, forced)
	else
		element:SetMinMaxValues(0, max, forced)
	end

	if (connected) then
		if (element.showAbsorbAsHealth) then
			element:SetValue(cur + absorb, forced)
		else
			element:SetValue(cur, forced)
		end
	else
		element:SetValue(max, true)
	end

	element.cur = cur
	element.max = max
	element.absorb = absorb

	--[[ Callback: SmartHealth:PostUpdate(unit, cur, max)
	Called after the element has been updated.

	* self - the SmartHealth element
	* unit - the unit for which the update has been triggered (string)
	* cur  - the unit's current health value (number)
	* max  - the unit's maximum possible health value (number)
	--]]
	if (element.PostUpdate) then
		element:PostUpdate(unit, cur, max, absorb)
	end
end

local Path = function(self, ...)
	--[[ Override: SmartHealth.Override(self, event, unit)
	Used to completely override the internal update function.

	* self  - the parent object
	* event - the event triggering the update (string)
	* unit  - the unit accompanying the event (string)
	--]]
	(self.SmartHealth.Override or Update) (self, ...);

	ColorPath(self, ...)
end

local ForceUpdate = function(element)
	Path(element.__owner, "ForceUpdate", element.__owner.unit)
end

--[[ SmartHealth:SetColorDisconnected(state, isForced)
Used to toggle coloring if the unit is offline.

* self     - the SmartHealth element
* state    - the desired state (boolean)
* isForced - forces the event update even if the state wasn't changed (boolean)
--]]
local SetColorDisconnected = function(element, state, isForced)
	if (element.colorDisconnected ~= state or isForced) then
		element.colorDisconnected = state
		if (state) then
			element.__owner:RegisterEvent("UNIT_CONNECTION", ColorPath)
		else
			element.__owner:UnregisterEvent("UNIT_CONNECTION", ColorPath)
		end
	end
end

--[[ SmartHealth:SetColorTapping(state, isForced)
Used to toggle coloring if the unit isn't tapped by the player.

* self     - the SmartHealth element
* state    - the desired state (boolean)
* isForced - forces the event update even if the state wasn't changed (boolean)
--]]
local SetColorTapping = function(element, state, isForced)
	if (element.colorTapping ~= state or isForced) then
		element.colorTapping = state
		if (state) then
			element.__owner:RegisterEvent("UNIT_FACTION", ColorPath)
		else
			element.__owner:UnregisterEvent("UNIT_FACTION", ColorPath)
		end
	end
end

--[[ SmartHealth:SetColorThreat(state, isForced)
Used to toggle coloring by the unit's threat status.

* self     - the SmartHealth element
* state    - the desired state (boolean)
* isForced - forces the event update even if the state wasn't changed (boolean)
--]]
local SetColorThreat = function(element, state, isForced)
	if (element.colorThreat ~= state or isForced) then
		element.colorThreat = state
		if (state) then
			element.__owner:RegisterEvent("UNIT_THREAT_LIST_UPDATE", ColorPath)
		else
			element.__owner:UnregisterEvent("UNIT_THREAT_LIST_UPDATE", ColorPath)
		end
	end
end

--[[ SmartHealth:SetShowAbsorbGap(state, isForced)
Used to toggle the inclusion of shields in the size of the max health.

* self     - the SmartHealth element
* state    - the desired state (boolean)
* isForced - forces the event update even if the state wasn't changed (boolean)
--]]
local SetShowAbsorbGap = function(element, state, isForced)
	if (element.showAbsorbGap ~= state or isForced) then
		element.showAbsorbGap = state
		if (state) then
			element.__owner:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED", Path)
		else
			element.__owner:UnregisterEvent("UNIT_ABSORB_AMOUNT_CHANGED", Path)
		end
	end
end

local Enable = function(self, unit)
	local element = self.SmartHealth
	if (element) then
		element.__owner = self
		element.ForceUpdate = ForceUpdate
		element.SetColorDisconnected = SetColorDisconnected
		element.SetColorTapping = SetColorTapping
		element.SetColorThreat = SetColorThreat
		element.SetShowAbsorbGap = SetShowAbsorbGap

		if (element.colorDisconnected) then
			self:RegisterEvent("UNIT_CONNECTION", ColorPath)
		end

		if (element.colorTapping) then
			self:RegisterEvent("UNIT_FACTION", ColorPath)
		end

		if (element.colorThreat) then
			self:RegisterEvent("UNIT_THREAT_LIST_UPDATE", ColorPath)
		end

		if (element.showAbsorbGap) then
			self:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED", Path)
		end

		self:RegisterEvent("UNIT_HEALTH", Path)
		self:RegisterEvent("UNIT_MAXHEALTH", Path)

		element:Show()

		return true
	end
end

local Disable = function(self)
	local element = self.SmartHealth
	if (element) then
		element:Hide()

		self:UnregisterEvent("UNIT_HEALTH", Path)
		self:UnregisterEvent("UNIT_MAXHEALTH", Path)
		self:UnregisterEvent("UNIT_ABSORB_AMOUNT_CHANGED", Path)
		self:UnregisterEvent("UNIT_CONNECTION", ColorPath)
		self:UnregisterEvent("UNIT_FACTION", ColorPath)
		self:UnregisterEvent("UNIT_THREAT_LIST_UPDATE", ColorPath)
	end
end

oUF:AddElement("SmartHealth", Path, Enable, Disable)
