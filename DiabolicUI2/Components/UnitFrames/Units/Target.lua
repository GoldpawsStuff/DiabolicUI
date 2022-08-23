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
local math_huge = math.huge
local table_sort = table.sort
local unpack = unpack

-- WoW API
local CreateFrame = CreateFrame

-- Addon API
local AbbreviateTime = ns.API.AbbreviateTimeShort
local Colors = ns.Colors
local GetFont = ns.API.GetFont
local GetMedia = ns.API.GetMedia


-- Callbacks
--------------------------------------------
local Aura_Sort = function(a, b)
	if (a and b) then
		if (a:IsShown() and b:IsShown()) then

			local aPlayer = a.isPlayer or false
			local bPlayer = b.isPlayer or false
			if (aPlayer == bPlayer) then

				local aTime = a.noDuration and math_huge or a.expiration or -1
				local bTime = b.noDuration and math_huge or b.expiration or -1
				if (aTime == bTime) then

					local aName = a.spell or ""
					local bName = b.spell or ""
					if (aName and bName) then
						if (sortDirection == "DESCENDING") then
							return (aName < bName)
						else
							return (aName > bName)
						end
					end

				elseif (aTime and bTime) then
					local sortDirection = a:GetParent().sortDirection
					if (sortDirection == "DESCENDING") then
						return (aTime < bTime)
					else
						return (aTime > bTime)
					end
				else
					return (aTime) and true or false
				end
	
			else
				local sortDirection = a:GetParent().sortDirection
				if (sortDirection == "DESCENDING") then
					return (not aPlayer and bPlayer)
				else
					return (aPlayer and not bPlayer)
				end
			end
		else
			return (a:IsShown())
		end
	end
end

local Aura_Filter = function(element, unit, button, name, texture,
	count, debuffType, duration, expiration, caster, isStealable, nameplateShowSelf, spellID,
	canApply, isBossDebuff, casterIsPlayer, nameplateShowAll,timeMod, effect1, effect2, effect3)

	button.unitIsCaster = unit and caster and UnitIsUnit(unit, caster)
	button.spell = name
	button.duration = duration
	button.expiration = expiration
	button.noDuration = (not duration or duration == 0)

	if (isBossDebuff) then
		return true
	end

	return (not button.noDuration and duration < 301) or (count > 1)
end

local Aura_Sorting = function(element, max)
	table_sort(element, Aura_Sort)
	return 1, #element
end

local Aura_Secure_UpdateTooltip = function(self)
	if (GameTooltip:IsForbidden()) then return end
	GameTooltip:SetUnitAura(self:GetParent().__owner.unit, self:GetID(), self.filter)
end

local Aura_Secure_OnEnter = function(self)
	if (not self:IsVisible()) then return end 
	if (GameTooltip:IsForbidden()) then return end
	GameTooltip:SetOwner(self, self:GetParent().tooltipAnchor)
	self:UpdateTooltip()
end

local Aura_Secure_OnLeave = function(self)
	if (GameTooltip:IsForbidden()) then return end
	GameTooltip:Hide()
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
	count:SetFontObject(GetFont(12,true))
	count:SetTextColor(Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3])
	count:SetPoint("BOTTOMRIGHT", aura, "BOTTOMRIGHT", -2, 3)
	aura.count = count

	local time = aura.border:CreateFontString(nil, "OVERLAY")
	time:SetFontObject(GetFont(12,true))
	time:SetTextColor(Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3])
	time:SetPoint("TOPLEFT", aura, "TOPLEFT", -3, 3)
	aura.time = time

	-- Using a virtual cooldown element with the timer attached, 
	-- allowing them to piggyback on the back-end's cooldown updates.
	aura.cd = ns.Widgets.RegisterCooldown(time)

	-- Replacing oUF's aura tooltips, as they are not secure.
	aura.UpdateTooltip = Aura_Secure_UpdateTooltip
	aura:SetScript("OnEnter", Aura_Secure_OnEnter)
	aura:SetScript("OnLeave", Aura_Secure_OnLeave)
	
	return aura
end

local Aura_PostUpdateIcon = function(element, unit, button, index, position, duration, expiration, debuffType, isStealable)

	-- Stealable buffs
	if(not button.isDebuff and isStealable and element.showStealableBuffs and not UnitIsUnit("player", unit)) then
	end

	-- Border Coloring
	local color
	if (button.isDebuff and element.showDebuffType) or (not button.isDebuff and element.showBuffType) or (element.showType) then
		color = Colors.debuff[debuffType] or Colors.debuff.none
	else
		color = Colors.verydarkgray
	end
	if (color) then
		button.border:SetBackdropBorderColor(color[1], color[2], color[3])
	end

	-- Icon Coloring
	if (button.isPlayer) then
		button.icon:SetDesaturated(false)
		button.icon:SetVertexColor(1, 1, 1)
	else
		button.icon:SetDesaturated(true)
		button.icon:SetVertexColor(.6, .6, .6)
	end
	
end

local Cast_CustomDelayText = function(element, duration)
	if (element.casting) then
		duration = element.max - duration
	end
	element.Time:SetFormattedText("%.1f |cffff0000%s%.2f|r", duration, element.casting and "+" or "-", element.delay)
end

local Cast_CustomTimeText = function(element, duration)
	if (element.casting) then
		duration = element.max - duration
	end
	element.Time:SetFormattedText("%.1f", duration)
end

local Cast_PostCastStart = function(element, unit)
	local self = element.__owner
	self.Name:Hide()
	self.SmartHealth.Value:Hide()

	local r, g, b = self.colors.offwhite[1], self.colors.offwhite[2], self.colors.offwhite[3]
	element.Text:SetTextColor(r, g, b)
	element.Time:SetTextColor(r, g, b)
	element.Time:Show()

	local _,class = UnitClass(unit)
	if (class == "PRIEST") then
		element:SetStatusBarColor(.3, .3, .3, .25)
	else
		element:SetStatusBarColor(1, 1, 1, .25)
	end
end

local Cast_PostCastStop = function(element, unit, spellID)
	local self = element.__owner
	self.Name:Show()
	self.SmartHealth.Value:Show()
	self.SmartHealth.Value:UpdateTag()
end

local Cast_PostCastFail = function(element, unit, spellID)
	local self = element.__owner
	self.SmartHealth.Value:Show()
	self.SmartHealth.Value:UpdateTag()

	local r, g, b = self.colors.normal[1], self.colors.normal[2], self.colors.normal[3]
	element.Text:SetTextColor(r, g, b)
	element.Time:Hide()
	element:SetValue(0)
end

local UpdateArtwork = function(self)
	local unit = self.unit
	if (not unit) then
		return
	end
	local l = UnitLevel(unit)
	if (UnitIsWildBattlePet(unit) or UnitIsBattlePetCompanion(unit)) then
		l = UnitBattlePetLevel(unit)
	end
	local c = UnitClassification(unit)
	if (c == "worldboss" or (l and l < 1) or c == "elite" or c == "rareelite" or c == "rare") then
		self.normalBg:SetAlpha(0)
		self.eliteBg:SetAlpha(1)
		self.SmartHealth:SetStatusBarTexture(GetMedia("target-bar-elite-diabolic"))
	else
		self.normalBg:SetAlpha(1)
		self.eliteBg:SetAlpha(0)
		self.SmartHealth:SetStatusBarTexture(GetMedia("target-bar-normal-diabolic"))
	end
end


UnitStyles["Target"] = function(self, unit, id)

	self:SetSize(350,75)

	local normalBg = self:CreateTexture(nil, "BACKGROUND", nil, -1)
	normalBg:SetSize(512,128)
	normalBg:SetPoint("CENTER")
	normalBg:SetTexture(GetMedia("target-normal-diabolic"))
	normalBg:SetAlpha(1)
	self.normalBg = normalBg
	
	local eliteBg = self:CreateTexture(nil, "BACKGROUND", nil, -1)
	eliteBg:SetSize(512,128)
	eliteBg:SetPoint("CENTER")
	eliteBg:SetTexture(GetMedia("target-elite-diabolic"))
	eliteBg:SetAlpha(0)
	self.eliteBg = eliteBg

	local health = self:CreateBar()
	health:SetSize(291,43)
	health:SetPoint("CENTER")
	health:SetStatusBarTexture(GetMedia("target-bar-normal-diabolic"))
	health:GetStatusBarTexture():SetTexCoord(221/1024, 803/1024, 85/256, 171/256)
	health:SetSparkTexture(GetMedia("blank"))
	health.colorDisconnected = true
	health.colorTapping = true
	health.colorClass = true
	health.colorReaction = true
	health.colorThreat = true
	health.colorHealth = true
	self.SmartHealth = health

	local healthValue = health:CreateFontString(nil, "OVERLAY", nil, 0)
	healthValue:SetFontObject(GetFont(16,true))
	healthValue:SetTextColor(unpack(self.colors.offwhite))
	healthValue:SetPoint("CENTER", 0, 0)
	self:Tag(healthValue, "[Diabolic:Health]")
	self.SmartHealth.Value = healthValue

	local name = self:CreateFontString(nil, "OVERLAY", nil, 0)
	name:SetJustifyH("CENTER")
	name:SetFontObject(GetFont(16,true))
	name:SetTextColor(unpack(self.colors.offwhite))
	name:SetAlpha(.85)
	name:SetPoint("BOTTOM", self, "TOP", 0, 0)
	self:Tag(name, "[Diabolic:Level:Prefix][name][Diabolic:Rare:Suffix]")
	self.Name = name

	local cast = self:CreateBar()
	cast:SetFrameLevel(health:GetFrameLevel() + 1)
	cast:SetSize(291,43)
	cast:SetPoint("CENTER")
	cast:SetStatusBarTexture(GetMedia("target-bar-normal-diabolic"))
	cast:GetStatusBarTexture():SetTexCoord(221/1024, 803/1024, 85/256, 171/256)
	cast:SetStatusBarColor(1, 1, 1, .25)
	cast:SetSparkTexture(GetMedia("blank"))
	cast:DisableSmoothing(true)
	cast.timeToHold = 0.5

	local castTime = cast:CreateFontString(nil, "OVERLAY", nil, 0)
	castTime:SetFontObject(GetFont(16,true))
	castTime:SetTextColor(unpack(self.colors.offwhite))
	castTime:SetPoint("CENTER", 0, 0)
	cast.Time = castTime

	local castText = cast:CreateFontString(nil, "OVERLAY", nil, 0)
	castText:SetFontObject(GetFont(16,true))
	castText:SetTextColor(unpack(self.colors.offwhite))
	castText:SetAlpha(.85)
	castText:SetPoint("BOTTOM", self, "TOP", 0, 0)
	cast.Text = castText

	cast.CustomDelayText = Cast_CustomDelayText
	cast.CustomTimeText = Cast_CustomTimeText
	cast.PostCastFail = Cast_PostCastFail
	cast.PostCastStop = Cast_PostCastStop
	cast.PostCastStart = Cast_PostCastStart
	cast:SetScript("OnHide", Cast_PostCastStop)

	self.Castbar = cast

	local auras = CreateFrame("Frame", nil, self)
	auras:SetSize(40*7-4, 36)
	auras:SetPoint("TOP", self, "BOTTOM", 0, -12)
	auras.size = 36
	auras.spacing = 4
	auras.numTotal = 7
	auras.disableMouse = false
	auras.disableCooldown = false
	auras.onlyShowPlayer = false
	auras.showStealableBuffs = false 
	auras.initialAnchor = "TOPLEFT"
	auras["spacing-x"] = 4
	auras["spacing-y"] = 4
	auras["growth-x"] = "RIGHT"
	auras["growth-y"] = "DOWN"
	auras.tooltipAnchor = "ANCHOR_BOTTOMRIGHT"
	auras.sortMethod = "TIME_REMAINING"
	auras.sortDirection = "ASCENDING"

	auras.CreateIcon = Aura_CreateIcon
	auras.PostUpdateIcon = Aura_PostUpdateIcon
	auras.CustomFilter = Aura_Filter
	auras.PreSetPosition = Aura_Sorting

	self.Auras = auras

	self.PostUpdate = UpdateArtwork
	self:RegisterEvent("PLAYER_TARGET_CHANGED", UpdateArtwork, true)
	self:RegisterEvent("UNIT_CLASSIFICATION_CHANGED", UpdateArtwork, true)

end