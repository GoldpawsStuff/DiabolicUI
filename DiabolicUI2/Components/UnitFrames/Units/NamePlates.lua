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
local UnitStyles = ns.UnitStyles
if (not UnitStyles) then
	return
end

-- Lua API
local _G = _G

-- WoW API
local CreateFrame = CreateFrame

-- Addon API
local Colors = ns.Colors
local GetFont = ns.API.GetFont
local GetMedia = ns.API.GetMedia

local AuraFilter = function(element, unit, button, name, texture,
	count, debuffType, duration, expiration, caster, isStealable, nameplateShowSelf, spellID,
	canApply, isBossDebuff, casterIsPlayer, nameplateShowAll, timeMod, effect1, effect2, effect3)

	return nameplateShowAll or
		   (nameplateShowSelf and (caster == "player" or caster == "pet" or caster == "vehicle"))
end

-- Callbacks
--------------------------------------------
local UpdateHighlight = function(self)
	local highlight = self.Highlight
	if (not highlight) then
		return
	end
	if (UnitIsUnit("target", self.unit)) then
		highlight:SetBackdropBorderColor(1, 1, 1)
		highlight:Show()
	elseif (UnitIsUnit("focus", self.unit)) then
		highlight:SetBackdropBorderColor(144/255, 195/255, 255/255)
		highlight:Show()
	else
		highlight:Hide()
	end
end

local Aura_CreateIcon = function(element, position)
	local aura = CreateFrame("Button", element:GetDebugName() .. "Button" .. position, element)
	aura:RegisterForClicks("RightButtonUp")

	local icon = aura:CreateTexture(nil, "BACKGROUND", nil, 1)
	icon:SetAllPoints()
	icon:SetMask(GetMedia("actionbutton-mask-square"))
	aura.icon = icon

	local border = CreateFrame("Frame", nil, aura, ns.BackdropTemplate)
	border:SetBackdrop({ edgeFile = GetMedia("border-aura"), edgeSize = 12 })
	border:SetBackdropBorderColor(Colors.xp[1], Colors.xp[2], Colors.xp[3])
	border:SetPoint("TOPLEFT", -6, 6)
	border:SetPoint("BOTTOMRIGHT", 6, -6)
	border:SetFrameLevel(aura:GetFrameLevel() + 2)
	aura.border = border

	local count = aura.border:CreateFontString(nil, "OVERLAY")
	count:SetFontObject(GetFont(10,true))
	count:SetTextColor(Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3])
	count:SetPoint("BOTTOMRIGHT", aura, "BOTTOMRIGHT", 2, -3)
	aura.count = count

	local time = aura.border:CreateFontString(nil, "OVERLAY")
	time:SetFontObject(GetFont(12,true))
	time:SetTextColor(Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3])
	time:SetPoint("TOPLEFT", aura, "TOPLEFT", -3, 3)
	aura.time = time

	-- Using a virtual cooldown element with the timer attached, 
	-- allowing them to piggyback on the back-end's cooldown updates.
	aura.cd = ns.Widgets.RegisterCooldown(time)
	
	return aura
end

local Aura_PostUpdateIcon = function(element, unit, button, index, position, duration, expiration, debuffType, isStealable)

	-- Stealable buffs
	if(not button.isDebuff and isStealable and element.showStealableBuffs and not UnitIsUnit("player", unit)) then
	end

	-- Coloring
	local color
	if (button.isDebuff and element.showDebuffType) or (not button.isDebuff and element.showBuffType) or (element.showType) then
		color = Colors.debuff[debuffType] or Colors.debuff.none
	else
		color = Colors.verydarkgray
	end
	if (color) then
		button.border:SetBackdropBorderColor(color[1], color[2], color[3])
	end

end

local Cast_UpdateInterruptible = function(element, unit)
	if (element.notInterruptible) then
		element:SetStatusBarColor(unpack(Colors.red))
	else
		element:SetStatusBarColor(unpack(Colors.cast))
	end
end

local Power_PostUpdate = function(element, unit, cur, min, max)
	local self = element.__owner
	if (not unit) then
		unit = self.unit
	end
	if (not unit) then
		return
	end

	local shouldShow

	if (self.isPRD) then
		if (not cur) then
			cur, max = UnitPower(unit), UnitPowerMax(unit)
		end
		if (cur and cur == 0) and (max and max == 0) then
			shouldShow = nil
		else
			shouldShow = true
		end
	end

	local power = self.SmartPower

	if (shouldShow) then
		if (power.isHidden) then
			local health = self.SmartHealth
			health:ClearAllPoints()
			health:SetPoint("CENTER", 0, 5)

			local cast = self.Castbar
			cast:ClearAllPoints()
			cast:SetPoint("CENTER", health, 0, -20)

			power:SetAlpha(1)
			power.isHidden = false
		end
	else
		if (not power.isHidden) then
			local health = self.SmartHealth
			health:ClearAllPoints()
			health:SetPoint("CENTER", 0, 0)

			power:SetAlpha(0)
			power.isHidden = true

			local cast = self.Castbar
			cast:ClearAllPoints()
			cast:SetPoint("CENTER", health, 0, -10)
		end
	end

end


UnitStyles["NamePlate"] = function(self, unit, id)

	self:SetSize(75,45) -- 90,45
	self.colors = ns.Colors
	
	-- Health
	--------------------------------------------
	local health = self:CreateBar()
	health:SetSize(75,5) -- 90,6
	health:SetPoint("CENTER")
	health:SetStatusBarTexture(GetMedia("bar-small"))
	health:SetSparkTexture(GetMedia("blank"))
	health.colorDisconnected = true
	health.colorTapping = true
	health.colorClass = true
	health.colorReaction = true
	health.colorThreat = true
	health.colorHealth = true

	local healthBorder = health:CreateTexture(nil, "BACKGROUND", nil, -2)
	healthBorder:SetPoint("TOPLEFT", -2, 2)
	healthBorder:SetPoint("BOTTOMRIGHT", 2, -2)
	healthBorder:SetColorTexture(0, 0, 0, .75)
	health.Border = healthBorder

	local healthBackdrop = health:CreateTexture(nil, "BACKGROUND", nil, -1)
	healthBackdrop:SetPoint("TOPLEFT", 0, 0)
	healthBackdrop:SetPoint("BOTTOMRIGHT", 0, 0)
	healthBackdrop:SetColorTexture(.6, .6, .6, .05)
	health.Backdrop = healthBackdrop

	self.SmartHealth = health


	-- Power
	--------------------------------------------
	local power = self:CreateBar()
	power:SetSize(75,5) 
	power:SetPoint("CENTER", health, 0, -10)
	power:SetStatusBarTexture(GetMedia("bar-small"))
	power:SetSparkTexture(GetMedia("blank"))
	power:SetAlpha(0)
	power.isHidden = true
	power.colorPower = true
	power.PostUpdate = Power_PostUpdate

	local powerBorder = power:CreateTexture(nil, "BACKGROUND", nil, -2)
	powerBorder:SetPoint("TOPLEFT", -2, 2)
	powerBorder:SetPoint("BOTTOMRIGHT", 2, -2)
	powerBorder:SetColorTexture(0, 0, 0, .75)
	power.Border = powerBorder

	local powerBackdrop = power:CreateTexture(nil, "BACKGROUND", nil, -1)
	powerBackdrop:SetPoint("TOPLEFT", 0, 0)
	powerBackdrop:SetPoint("BOTTOMRIGHT", 0, 0)
	powerBackdrop:SetColorTexture(.6, .6, .6, .05)
	power.Backdrop = powerBackdrop

	self.SmartPower = power


	-- Highlight
	--------------------------------------------
	local highlight = CreateFrame("Frame", nil, health, ns.BackdropTemplate)
	highlight:SetPoint("TOPLEFT", -7, 7)
	highlight:SetPoint("BOTTOMRIGHT", 7, -7)
	highlight:SetBackdrop({ edgeFile = GetMedia("border-glow"), edgeSize = 8 })
	highlight:SetFrameLevel(0)
	highlight:Hide()

	self.Highlight = highlight

	self:RegisterEvent("PLAYER_TARGET_CHANGED", UpdateHighlight, true)
	self:RegisterEvent("PLAYER_FOCUS_CHANGED", UpdateHighlight, true)
	self:RegisterEvent("NAME_PLATE_UNIT_ADDED", UpdateHighlight, true)
	self:RegisterEvent("NAME_PLATE_UNIT_REMOVED", UpdateHighlight, true)


	-- Castbar
	--------------------------------------------
	local cast = self:CreateBar()
	cast:Hide()
	cast:SetSize(75,5) 
	cast:SetPoint("CENTER", health, 0, -10)
	cast:SetStatusBarTexture(GetMedia("bar-small"))
	cast:SetSparkTexture(GetMedia("blank"))
	cast:SetStatusBarColor(64/255, 128/255, 255/255)
	cast:DisableSmoothing(true)
	cast.PostCastInterruptible = Cast_UpdateInterruptible
	cast.PostCastStart = Cast_UpdateInterruptible

	local castBorder = cast:CreateTexture(nil, "BACKGROUND", nil, -2)
	castBorder:SetPoint("TOPLEFT", -2, 2)
	castBorder:SetPoint("BOTTOMRIGHT", 2, -2)
	castBorder:SetColorTexture(0, 0, 0, .75)
	cast.Border = castBorder

	local castBackdrop = cast:CreateTexture(nil, "BACKGROUND", nil, -1)
	castBackdrop:SetPoint("TOPLEFT", 0, 0)
	castBackdrop:SetPoint("BOTTOMRIGHT", 0, 0)
	castBackdrop:SetColorTexture(.6, .6, .6, .05)
	cast.Backdrop = castBackdrop

	local castIcon = cast:CreateTexture(nil, "ARTWORK", nil, 0)
	castIcon:SetSize(16, 16)
	castIcon:SetPoint("TOPRIGHT", health, "TOPLEFT", -6, 0)
	castIcon:SetMask(GetMedia("actionbutton-mask-square"))
	castIcon:SetAlpha(.85)
	cast.Icon = castIcon

	local castIconFrame = CreateFrame("Frame", nil, cast, ns.BackdropTemplate)
	castIconFrame:SetPoint("TOPLEFT", castIcon, "TOPLEFT", -5, 5)
	castIconFrame:SetPoint("BOTTOMRIGHT", castIcon, "BOTTOMRIGHT", 5, -5)
	castIconFrame:SetBackdrop({ edgeFile = GetMedia("border-glow"), edgeSize = 8 })
	castIconFrame:SetBackdropBorderColor(0, 0, 0, 1)
	castIconFrame:SetFrameLevel(0)
	castIcon.Frame = castIconFrame

	local castIconBackdrop = castIconFrame:CreateTexture(nil, "BACKGROUND", nil, -2)
	castIconBackdrop:SetPoint("TOPLEFT", 3, -3)
	castIconBackdrop:SetPoint("BOTTOMRIGHT", -3, 3)
	castIconBackdrop:SetColorTexture(0, 0, 0, .75)
	castIcon.Backdrop = castIconBackdrop

	self.Castbar = cast


	-- Auras
	--------------------------------------------
	local auras = CreateFrame("Frame", nil, self)
	auras:SetSize(30*3-4, 26)
	--auras:SetPoint("BOTTOM", self, "TOP", 0, 10) -- with name
	auras:SetPoint("BOTTOM", self.SmartHealth, "TOP", 0, 6)
	auras.size = 26
	auras.spacing = 4
	auras.numTotal = 6
	auras.disableMouse = true
	auras.disableCooldown = false
	auras.onlyShowPlayer = false
	auras.showStealableBuffs = false 
	auras.initialAnchor = "BOTTOMLEFT"
	auras["spacing-x"] = 4
	auras["spacing-y"] = 4
	auras["growth-x"] = "RIGHT"
	auras["growth-y"] = "UP"
	auras.sortMethod = "TIME_REMAINING"
	auras.sortDirection = "ASCENDING"

	auras.CreateIcon = Aura_CreateIcon
	auras.PostUpdateIcon = Aura_PostUpdateIcon
	auras.CustomFilter = AuraFilter
	auras.PreSetPosition = AuraSorting

	self.Auras = auras
end
