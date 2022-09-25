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

-- sourced from FrameXML/UnitPowerBarAlt.lua
local ALTERNATE_POWER_INDEX = Enum.PowerType.Alternate or 10

-- WoW API
local GetUnitPowerBarInfo = GetUnitPowerBarInfo
local UnitClass = UnitClass
local UnitInParty = UnitInParty
local UnitInRaid = UnitInRaid
local UnitIsConnected = UnitIsConnected
local UnitIsPlayer = UnitIsPlayer
local UnitIsTapDenied = UnitIsTapDenied
local UnitPlayerControlled = UnitPlayerControlled
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitPowerType = UnitPowerType
local UnitReaction = UnitReaction
local UnitThreatSituation = UnitThreatSituation

--[[ Override: SmartPower:GetDisplayPower()
Used to get info on the unit's alternative power, if any.
Should return the power type index (see [Enum.PowerType.Alternate](https://wow.gamepedia.com/Enum_Unit.PowerType))
and the minimum value for the given power type (see [info.minPower](https://wow.gamepedia.com/API_GetUnitPowerBarInfo))
or nil if the unit has no alternative (alternate) power or it should not be
displayed. In case of a nil return, the element defaults to the primary power
type and zero for the minimum value.

* self - the Power element
--]]
local GetDisplayPower = function(element)
	local unit = element.__owner.unit
	local barInfo = GetUnitPowerBarInfo(unit)
	if (barInfo and barInfo.showOnRaid and (UnitInParty(unit) or UnitInRaid(unit))) then
		return ALTERNATE_POWER_INDEX, barInfo.minPower
	end
end

local UpdateColor = function(self, event, unit)
	if (self.unit ~= unit) then
		return
	end
	local element = self.SmartPower

	local pType, pToken, altR, altG, altB = UnitPowerType(unit)

	local r, g, b, t
	if (element.colorDisconnected and not UnitIsConnected(unit)) then
		t = self.colors.disconnected
	elseif (element.colorTapping and not UnitPlayerControlled(unit) and UnitIsTapDenied(unit)) then
		t = self.colors.tapped
	elseif (element.colorThreat and not UnitPlayerControlled(unit) and UnitThreatSituation("player", unit)) then
		t =  self.colors.threat[UnitThreatSituation("player", unit)]
	elseif (element.colorPower) then
		if (element.displayType ~= ALTERNATE_POWER_INDEX) then
			t = self.colors.power[pToken]
			if (not t) then
				if(element.GetAlternativeColor) then
					r, g, b = element:GetAlternativeColor(unit, pType, pToken, altR, altG, altB)
				elseif (altR) then
					r, g, b = altR, altG, altB
					if (r > 1 or g > 1 or b > 1) then
						-- BUG: As of 7.0.3, altR, altG, altB may be in 0-1 or 0-255 range.
						r, g, b = r / 255, g / 255, b / 255
					end
				else
					t = self.colors.power[pType] or self.colors.power.MANA
				end
			end
		else
			t = self.colors.power[ALTERNATE_POWER_INDEX]
		end
	elseif (element.colorClass and UnitIsPlayer(unit))
		or (element.colorClassNPC and not UnitIsPlayer(unit))
		or (element.colorClassPet and UnitPlayerControlled(unit) and not UnitIsPlayer(unit)) then
		local _, class = UnitClass(unit)
		t = self.colors.class[class]
	elseif (element.colorReaction and UnitReaction(unit, "player")) then
		t = self.colors.reaction[UnitReaction(unit, "player")]
	elseif (element.colorSmooth) then
		local adjust = 0 - (element.min or 0)
		r, g, b = self:ColorGradient((element.cur or 1) + adjust, (element.max or 1) + adjust, unpack(element.smoothGradient or self.colors.smooth))
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

	--[[ Callback: SmartPower:PostUpdateColor(unit, r, g, b)
	Called after the element color has been updated.

	* self - the SmartPower element
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
	--[[ Override: SmartPower.UpdateColor(self, event, unit)
	Used to completely override the internal function for updating the widgets' colors.

	* self  - the parent object
	* event - the event triggering the update (string)
	* unit  - the unit accompanying the event (string)
	--]]
	(self.SmartPower.UpdateColor or UpdateColor) (self, ...)
end

local Update = function(self, event, unit)
	if(self.unit ~= unit) then return end
	local element = self.SmartPower

	--[[ Callback: SmartPower:PreUpdate(unit)
	Called before the element has been updated.

	* self - the SmartPower element
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

	local displayType, min
	if (element.displayAltPower and oUF.isRetail) then
		displayType, min = element:GetDisplayPower()
	end

	local cur, max = UnitPower(unit, displayType), UnitPowerMax(unit, displayType)
	element:SetMinMaxValues(min or 0, max)

	if (UnitIsConnected(unit)) then
		element:SetValue(cur, forced)
	else
		element:SetValue(max, forced)
	end

	element.cur = cur
	element.min = min
	element.max = max
	element.displayType = displayType

	--[[ Callback: SmartPower:PostUpdate(unit, cur, min, max)
	Called after the element has been updated.

	* self - the SmartPower element
	* unit - the unit for which the update has been triggered (string)
	* cur  - the unit's current power value (number)
	* min  - the unit's minimum possible power value (number)
	* max  - the unit's maximum possible power value (number)
	--]]
	if (element.PostUpdate) then
		element:PostUpdate(unit, cur, min, max)
	end
end

local Path = function(self, ...)
	--[[ Override: SmartPower.Override(self, event, unit, ...)
	Used to completely override the internal update function.

	* self  - the parent object
	* event - the event triggering the update (string)
	* unit  - the unit accompanying the event (string)
	* ...   - the arguments accompanying the event
	--]]
	(self.SmartPower.Override or Update) (self, ...);

	ColorPath(self, ...)
end

local ForceUpdate = function(element)
	Path(element.__owner, "ForceUpdate", element.__owner.unit)
end

--[[ SmartPower:SetColorDisconnected(state, isForced)
Used to toggle coloring if the unit is offline.

* self     - the Power element
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

--[[ SmartPower:SetColorSelection(state, isForced)
Used to toggle coloring by the unit's selection.

* self     - the Power element
* state    - the desired state (boolean)
* isForced - forces the event update even if the state wasn't changed (boolean)
--]]
local SetColorSelection = function(element, state, isForced)
	if (element.colorSelection ~= state or isForced) then
		element.colorSelection = state
		if (state) then
			element.__owner:RegisterEvent("UNIT_FLAGS", ColorPath)
		else
			element.__owner:UnregisterEvent("UNIT_FLAGS", ColorPath)
		end
	end
end

--[[ SmartPower:SetColorTapping(state, isForced)
Used to toggle coloring if the unit isn't tapped by the player.

* self     - the Power element
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

--[[ SmartPower:SetColorThreat(state, isForced)
Used to toggle coloring by the unit's threat status.

* self     - the Power element
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

--[[ SmartPower:SetFrequentUpdates(state, isForced)
Used to toggle frequent updates.

* self     - the Power element
* state    - the desired state (boolean)
* isForced - forces the event update even if the state wasn't changed (boolean)
--]]
local SetFrequentUpdates = function(element, state, isForced)
	if (element.frequentUpdates ~= state or isForced) then
		element.frequentUpdates = state
		if (state) then
			element.__owner:UnregisterEvent("UNIT_POWER_UPDATE", Path)
			element.__owner:RegisterEvent("UNIT_POWER_FREQUENT", Path)
		else
			element.__owner:UnregisterEvent("UNIT_POWER_FREQUENT", Path)
			element.__owner:RegisterEvent("UNIT_POWER_UPDATE", Path)
		end
	end
end

local Enable = function(self)
	local element = self.SmartPower
	if (element) then
		element.__owner = self
		element.ForceUpdate = ForceUpdate
		element.SetColorDisconnected = SetColorDisconnected
		element.SetColorSelection = SetColorSelection
		element.SetColorTapping = SetColorTapping
		element.SetColorThreat = SetColorThreat
		element.SetFrequentUpdates = SetFrequentUpdates

		if (element.colorDisconnected) then
			self:RegisterEvent("UNIT_CONNECTION", ColorPath)
		end

		if (element.colorSelection) then
			self:RegisterEvent("UNIT_FLAGS", ColorPath)
		end

		if (element.colorTapping) then
			self:RegisterEvent("UNIT_FACTION", ColorPath)
		end

		if (element.colorThreat) then
			self:RegisterEvent("UNIT_THREAT_LIST_UPDATE", ColorPath)
		end

		if (element.frequentUpdates) then
			self:RegisterEvent("UNIT_POWER_FREQUENT", Path)
		else
			self:RegisterEvent("UNIT_POWER_UPDATE", Path)
		end

		self:RegisterEvent("UNIT_DISPLAYPOWER", Path)
		self:RegisterEvent("UNIT_MAXPOWER", Path)
		self:RegisterEvent("UNIT_POWER_BAR_HIDE", Path)
		self:RegisterEvent("UNIT_POWER_BAR_SHOW", Path)

		if (element:IsObjectType("StatusBar") and not (element:GetStatusBarTexture() or element:GetStatusBarAtlas())) then
			element:SetStatusBarTexture([[Interface\TargetingFrame\UI-StatusBar]])
		end

		if (not element.GetDisplayPower) then
			element.GetDisplayPower = GetDisplayPower
		end

		element:Show()

		return true
	end
end

local Disable = function(self)
	local element = self.SmartPower
	if (element) then
		element:Hide()

		self:UnregisterEvent("UNIT_DISPLAYPOWER", Path)
		self:UnregisterEvent("UNIT_MAXPOWER", Path)
		self:UnregisterEvent("UNIT_POWER_BAR_HIDE", Path)
		self:UnregisterEvent("UNIT_POWER_BAR_SHOW", Path)
		self:UnregisterEvent("UNIT_POWER_FREQUENT", Path)
		self:UnregisterEvent("UNIT_POWER_UPDATE", Path)
		self:UnregisterEvent("UNIT_CONNECTION", ColorPath)
		self:UnregisterEvent("UNIT_FACTION", ColorPath)
		self:UnregisterEvent("UNIT_FLAGS", ColorPath)
		self:UnregisterEvent("UNIT_THREAT_LIST_UPDATE", ColorPath)
	end
end

oUF:AddElement("SmartPower", Path, Enable, Disable)
