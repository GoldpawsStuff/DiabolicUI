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
local UnitBattlePetLevel = UnitBattlePetLevel
local UnitClass = UnitClass
local UnitClassification = UnitClassification
local UnitIsBattlePetCompanion = UnitIsBattlePetCompanion
local UnitIsWildBattlePet = UnitIsWildBattlePet
local UnitLevel = UnitLevel

-- Addon API
local AbbreviateTime = ns.API.AbbreviateTimeShort
local Colors = ns.Colors
local GetFont = ns.API.GetFont
local GetMedia = ns.API.GetMedia
local IsWrath = ns.IsWrath

-- Callbacks
--------------------------------------------
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
	if (not IsWrath) then
		if (UnitIsWildBattlePet(unit) or UnitIsBattlePetCompanion(unit)) then
			l = UnitBattlePetLevel(unit)
		end
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
	auras.sortDirection = "DESCENDING"
	auras.CreateIcon = ns.AuraStyles.CreateIcon
	auras.PostUpdateIcon = ns.AuraStyles.TargetPostUpdateIcon
	auras.CustomFilter = ns.AuraFilters.TargetAuraFilter
	auras.PreSetPosition = ns.AuraSorts.Default

	self.Auras = auras

	self.PostUpdate = UpdateArtwork
	self:RegisterEvent("PLAYER_TARGET_CHANGED", UpdateArtwork, true)
	self:RegisterEvent("UNIT_CLASSIFICATION_CHANGED", UpdateArtwork, true)

end