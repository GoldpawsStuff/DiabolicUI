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
local select = select
local unpack = unpack

-- WoW API
local CreateFrame = CreateFrame

-- Addon API
local Colors = ns.Colors
local GetFont = ns.API.GetFont
local GetMedia = ns.API.GetMedia
local IsAddOnEnabled = ns.API.IsAddOnEnabled
local SetObjectScale = ns.API.SetObjectScale

-- Constants
local playerClass = ns.PlayerClass

-- Element Callbacks
--------------------------------------------
-- Forceupdate health prediction on health updates,
-- to assure our smoothed elements are properly aligned.
local Health_PostUpdate = function(element, unit, cur, max)
	local predict = element.__owner.HealthPrediction
	if (predict) then
		predict:ForceUpdate()
	end
end

-- Update the health preview color on health color updates.
local Health_PostUpdateColor = function(element, unit, r, g, b)
	local preview = element.Preview
	if (preview) then
		preview:SetStatusBarColor(r * .7, g * .7, b * .7)
	end
end

-- Align our custom health prediction texture
-- based on the plugin's provided values.
local HealPredict_PostUpdate = function(element, unit, myIncomingHeal, otherIncomingHeal, absorb, healAbsorb, hasOverAbsorb, hasOverHealAbsorb, curHealth, maxHealth)

	local allIncomingHeal = myIncomingHeal + otherIncomingHeal
	local allNegativeHeals = healAbsorb
	local showPrediction, change

	if ((allIncomingHeal > 0) or (allNegativeHeals > 0)) and (maxHealth > 0) then
		local startPoint = curHealth/maxHealth

		-- Dev switch to test absorbs with normal healing
		--allIncomingHeal, allNegativeHeals = allNegativeHeals, allIncomingHeal

		-- Hide predictions if the change is very small, or if the unit is at max health.
		change = (allIncomingHeal - allNegativeHeals)/maxHealth
		if ((curHealth < maxHealth) and (change > (element.health.predictThreshold or .05))) then
			local endPoint = startPoint + change

			-- Crop heal prediction overflows
			if (endPoint > 1) then
				endPoint = 1
				change = endPoint - startPoint
			end

			-- Crop heal absorb overflows
			if (endPoint < 0) then
				endPoint = 0
				change = -startPoint
			end

			-- This shouldn't happen, but let's do it anyway.
			if (startPoint ~= endPoint) then
				showPrediction = true
			end
		end
	end

	if (showPrediction) then

		local preview = element.preview
		local min,max = preview:GetMinMaxValues()
		local anchor = preview:GetValue() / max
		local texture = preview:GetStatusBarTexture()
		local width, height = preview:GetSize()

		if (change > 0) then
			element:ClearAllPoints()
			element:SetPoint("BOTTOM", texture, "BOTTOM", 0, anchor * height)
			element:SetSize(width, change*height)
			element:SetTexCoord(0, 1, 1 - anchor - change, 1 - anchor)
			element:SetVertexColor(0, .7, 0, .25)
			element:Show()

		elseif (change < 0) then
			element:ClearAllPoints()
			element:SetPoint("BOTTOM", texture, "BOTTOM", 0, (anchor - change) * height)
			element:SetSize(width, -change*height)
			element:SetTexCoord(0, 1, 1 - anchor, 1 - anchor - change)
			element:SetVertexColor(.25, 0, 0, .75)
			element:Show()

		else
			element:Hide()
		end
	else
		element:Hide()
	end

end

local Cast_CustomDelayText = function(element, duration)
	if (element.casting) then
		duration = element.max - duration
	end
	--element.Time:SetFormattedText("%.1f |cffff0000%s%.2f|r", duration, element.casting and "+" or "-", element.delay)
	element.Time:SetFormattedText("%.1f", duration)
	element.Delay:SetFormattedText("|cffff0000%s%.2f|r", element.casting and "+" or "-", element.delay)
end

local Cast_CustomTimeText = function(element, duration)
	if (element.casting) then
		duration = element.max - duration
	end
	element.Time:SetFormattedText("%.1f", duration)
	element.Delay:SetText()
end

-- Update cast bar color to indicate protected casts.
local Cast_UpdateInterruptible = function(element, unit)
	if (element.notInterruptible) then
		element:SetStatusBarColor(unpack(Colors.red))
	else
		element:SetStatusBarColor(unpack(Colors.cast))
	end
end

local ClassPower_OnDisplayValueChanged = function(point)
	local value = point:GetValue()
	local min, max = point:GetMinMaxValues()

	-- Base it all on the bar's current color
	if (point.fg) then
		local r, g, b = point:GetStatusBarColor()
		point.fg:SetVertexColor(r, g, b, .75)

		-- Adjust texcoords of the overlay glow to match the bars
		local c = point.fg.texCoords
		point.fg:SetTexCoord(c[1], c[2], c[4] - (c[4]-c[3]) * ((value-min)/(max-min)), c[4])
	end
end

local ClassPower_PostUpdate = function(element, cur, max, hasMaxChanged, powerType)
	-- Resize the holder frame to keep points centered
	if (hasMaxChanged) then
		element:SetWidth(max * element.pointWidth)
	end
	for i = 1, #element do
		local point = element[i]
		if (point:IsShown()) then
			local value = point:GetValue()
			local pmin, pmax = point:GetMinMaxValues()
			if (element.inCombat) then
				point:SetAlpha((cur == max) and 1 or (value < pmax) and .5 or 1)
			else
				point:SetAlpha((cur == max) and 0 or (value < pmax) and .5 or 1)
			end
		end
	end
end

local ClassPower_PostUpdateColor = function(element, r, g, b)
	for i = 1, #element do
		local bar = element[i]
		bar:SetStatusBarColor(r, g, b)
		local fg = bar.fg
		if (fg) then
			local mu = fg.multiplier or 1
			fg:SetVertexColor(r, g, b)
		end
	end
end

local Runes_PostUpdate = function(element, runemap, hasVehicle, allReady)
	for i = 1, #element do
		local rune = element[i]
		if (rune:IsShown()) then
			local value = rune:GetValue()
			local min, max = rune:GetMinMaxValues()
			if (element.inCombat) then
				rune:SetAlpha(allReady and 1 or (value < max) and .5 or 1)
			else
				rune:SetAlpha(allReady and 0 or (value < max) and .5 or 1)
			end
		end
	end
end

local Runes_PostUpdateColor = function(element, r, g, b, color, rune)
	local m = ns.IsWrath and .5 or 1 -- Probably only needed on our current runes
	if (rune) then
		rune:SetStatusBarColor(r * m, g * m, b * m)
		rune.fg:SetVertexColor(r * m, g * m, b * m)
	else
		if (not ns.IsWrath) then
			color = element.__owner.colors.power.RUNES
			r, g, b = color[1] * m, color[2] * m, color[3] * m
		end
		for i = 1, #element do
			local rune = element[i]
			if (ns.IsWrath) then
				color = element.__owner.colors.runes[rune.runeType]
				r, g, b = color[1] * m, color[2] * m, color[3] * m
			end
			rune:SetStatusBarColor(r, g, b)
			rune.fg:SetVertexColor(r, g, b)
		end
	end
end

local Stagger_SetStatusBarColor = function(element, r, g, b)
	for i,point in next,element do
		point:SetStatusBarColor(r, g, b)
	end
end

local Stagger_PostUpdate = function(element, cur, max)

	element[1].min = 0
	element[1].max = max * .3
	element[2].min = element[1].max
	element[2].max = max * .6
	element[3].min = element[2].max
	element[3].max = max

	for i,point in next,element do
		local value = (cur > point.max) and point.max or (cur < point.min) and point.min or cur

		point:SetMinMaxValues(point.min, point.max)
		point:SetValue(value)

		if (element.inCombat) then
			point:SetAlpha((cur == max) and 1 or (value < point.max) and .5 or 1)
		else
			point:SetAlpha((cur == 0) and 0 or (value < point.max) and .5 or 1)
		end
	end
end

-- Script Handlers
--------------------------------------------
local UnitFrame_OnEvent = function(self, event)
	if (event == "PLAYER_REGEN_DISABLED") then
		self:OnMouseOver(event)
		local runes = self.Runes
		if (runes) and (not runes.inCombat) then
			runes.inCombat = true
			runes:ForceUpdate()
		end
		local stagger = self.Stagger
		if (stagger and not stagger.inCombat) then
			stagger.inCombat = true
			stagger:ForceUpdate()
		end
		local classpower = self.ClassPower
		if (classpower) and (not classpower.inCombat) then
			classpower.inCombat = true
			classpower:ForceUpdate()
		end
	elseif (event == "PLAYER_REGEN_ENABLED") then
		self:OnMouseOver(event)
		local runes = self.Runes
		if (runes) and (runes.inCombat) then
			runes.inCombat = false
			runes:ForceUpdate()
		end
		local stagger = self.Stagger
		if (stagger and stagger.inCombat) then
			stagger.inCombat = false
			stagger:ForceUpdate()
		end
		local classpower = self.ClassPower
		if (classpower) and (classpower.inCombat) then
			classpower.inCombat = false
			classpower:ForceUpdate()
		end
	end
end

local UnitFrame_OnHide = function(self)
	self.inCombat = nil
	self.isMouseOver = nil
	self.Power.isMouseOver = nil
	self:OnMouseOver()
end

local UnitFrame_OnMouseOver = function(self, event)
	if (event == "PLAYER_REGEN_DISABLED") then
		self.inCombat = true
	elseif (event == "PLAYER_REGEN_ENABLED") then
		self.inCombat = nil
	end
	if (self.isMouseOver) or (self.Power.isMouseOver) or (self.inCombat) then
		self.Health.Value:Show()
		self.Power.Value:Show()
		self:UpdateTags()
	else
		self.Health.Value:Hide()
		self.Power.Value:Hide()
	end
end

local Power_OnEnter = function(element)
	local OnEnter = element.__owner:GetScript("OnEnter")
	if (OnEnter) then
		OnEnter(element)
	end
end

local Power_OnLeave = function(element)
	local OnLeave = element.__owner:GetScript("OnLeave")
	if (OnLeave) then
		OnLeave(element)
	end
end

local Power_OnMouseOver = function(element)
	element.__owner:OnMouseOver()
end

-- Callbacks
--------------------------------------------
-- Update aura positons when visible bars change.
local PostUpdateAuraPositions = function(self, event, ...)

	local ActionBars = ns:GetModule("ActionBars")
	local PetBar = ActionBars:GetModule("PetBar", true)
	local StanceBar = ActionBars:GetModule("StanceBar", true)
	local offset = ActionBars:GetBarOffset()
	local stanceOffset = 0

	self.hasStanceBar = StanceBar and StanceBar.Bar and StanceBar.Bar:IsShown()
	self.hasPetBar = PetBar and PetBar.Bar and PetBar.Bar:IsShown()

	if (self.hasPetBar) then
		offset = offset + 40
	elseif (self.hasStanceBar) then
		stanceOffset = 40
	end

	self.Buffs:SetPoint("BOTTOMLEFT", UIParent, "BOTTOM", -320, 100 + offset)
	self.Debuffs:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOM", 320, 100 + offset + stanceOffset)

	ns:Fire("UnitFrame_Position_Updated", self:GetName())
end

-- Utility Functions
--------------------------------------------
-- Create the points used for class power, stagger and runes.
local CreatePoint = function(self, i)

	local point = self:CreateBar()
	point:SetSize(70,70)
	point.pointWidth = 70
	point:SetStatusBarTexture(GetMedia("diabolic-runes"))
	point:GetStatusBarTexture():SetTexCoord((i-1)*128/1024, i*128/1024, 128/512, 256/512)
	point:SetSparkTexture(GetMedia("blank"))
	point:DisableSmoothing(true) -- Force disable smoothing, it's too inaccurate for this.
	point:SetOrientation("UP")
	point:SetMinMaxValues(0, 1)
	point:SetValue(1)
	point:SetScript("OnDisplayValueChanged", ClassPower_OnDisplayValueChanged)

	-- Empty slot texture
	local bg = point:CreateTexture()
	bg:SetDrawLayer("BACKGROUND", -1)
	bg:ClearAllPoints()
	bg:SetPoint("BOTTOM", 0, 0)
	bg:SetSize(70,70)
	bg:SetTexture(GetMedia("diabolic-runes"))
	bg:SetTexCoord((i-1)*128/1024, i*128/1024, 0/512, 128/512)
	bg.multiplier = .25
	point.bg = bg

	-- Overlay glow, aligned to the bar texture
	-- This needs post updates to adjust its texcoords based on bar value.
	local fg = point:CreateTexture()
	fg:SetDrawLayer("ARTWORK", 1)
	fg:SetPoint("TOP", point:GetStatusBarTexture(), "TOP", 0, 0)
	fg:SetPoint("BOTTOM", 0, 0)
	fg:SetPoint("LEFT", 0, 0)
	fg:SetPoint("RIGHT", 0, 0)
	fg:SetSize(70,70) -- this is overriden by the points above
	fg:SetBlendMode("ADD")
	fg:SetTexture(GetMedia("diabolic-runes"))
	fg:SetTexCoord((i-1)*128/1024, i*128/1024, 256/512, 384/512)
	fg:SetAlpha(.85)
	fg.texCoords = { (i-1)*128/1024, i*128/1024, 256/512, 384/512 }
	point.fg = fg

	return point
end

UnitStyles["Player"] = function(self, unit, id)

	self:SetSize(200,200)
	self:SetFrameLevel(self:GetFrameLevel() + 1)

	-- Holders for always visible elements
	--------------------------------------------
	local artworkHolder = SetObjectScale(CreateFrame("Frame", nil, UIParent))
	artworkHolder:SetAllPoints(self)
	artworkHolder:SetFrameStrata(self:GetFrameStrata())
	artworkHolder:SetFrameLevel(self:GetFrameLevel())

	self.Artwork = artworkHolder

	local artworkOverlay = CreateFrame("Frame", nil, artworkHolder)
	artworkOverlay:SetAllPoints()
	artworkOverlay:SetFrameStrata(self:GetFrameStrata())
	artworkOverlay:SetFrameLevel(self:GetFrameLevel() + 5)

	self.Artwork.Overlay = artworkOverlay

	-- Health Orb
	--------------------------------------------
	local health = self:CreateOrb(self:GetName().."HealthOrb")
	health:SetSize(200,200)
	health:SetPoint("BOTTOM")
	health:SetStatusBarTexture(GetMedia("orb2"), GetMedia("orb2"))
	health.colorHealth = true

	select(2, health:GetStatusBarTexture()):SetTexCoord(1,0,1,0) -- flip 2nd texture horizontally

	self.Health = health
	self.Health.Override = ns.API.UpdateHealth
	self.Health.PostUpdate = Health_PostUpdate
	self.Health.PostUpdateColor = Health_PostUpdateColor

	local healthBackdrop = artworkHolder:CreateTexture(health:GetName().."Backdrop", "BACKGROUND", nil, -7)
	healthBackdrop:SetSize(330,330)
	healthBackdrop:SetPoint("CENTER", health)
	healthBackdrop:SetTexture(GetMedia("orb-backdrop1"))

	self.Health.Bacdrop = healthBackdrop

	local healthOverlay = CreateFrame("Frame", nil, health)
	healthOverlay:SetFrameLevel(health:GetFrameLevel() + 5)

	self.Health.Overlay = healthOverlay

	local healthShade = artworkOverlay:CreateTexture(nil, "BACKGROUND")
	healthShade:SetAllPoints(health)
	healthShade:SetTexture(GetMedia("shade-circle"))
	healthShade:SetVertexColor(0,0,0,1)

	self.Health.Shade = healthShade

	local healthGlass = artworkOverlay:CreateTexture(health:GetName().."Glass", "BORDER")
	healthGlass:SetAllPoints(healthBackdrop)
	healthGlass:SetTexture(GetMedia("orb-glass"))
	healthGlass:SetAlpha(.6)

	self.Health.Glass = healthGlass

	local healthBorder = artworkOverlay:CreateTexture(health:GetName().."Border", "ARTWORK")
	healthBorder:SetAllPoints(healthBackdrop)
	healthBorder:SetTexture(GetMedia("orb-border"))

	self.Health.Border = healthBorder

	local healthArt = artworkOverlay:CreateTexture(health:GetName().."Artwork", "OVERLAY", nil, 1)
	healthArt:SetSize(healthBackdrop:GetSize())
	healthArt:SetPoint("BOTTOMRIGHT", health, "BOTTOM", 29, -25)
	healthArt:SetTexture(GetMedia("orb-art1"))

	self.Health.Artwork = healthArt

	-- Health Value Text
	--------------------------------------------
	local healthValue = health:CreateFontString(health:GetName().."ValueText", "OVERLAY", nil, 0)
	healthValue:Hide()
	healthValue:SetFontObject(GetFont(14,true))
	healthValue:SetTextColor(unpack(self.colors.offwhite))
	healthValue:SetAlpha(.85)
	healthValue:SetPoint("BOTTOM", health, "TOP", 0, 16)

	if (ns.IsWrath) then
		self:Tag(healthValue, "["..ns.Prefix..":Health:Full]")
	else
		self:Tag(healthValue, "["..ns.Prefix..":Health:Full]["..ns.Prefix..":Absorb]")
	end

	self.Health.Value = healthValue

	-- Health Preview
	--------------------------------------------
	local layer, level = health:GetStatusBarTexture():GetDrawLayer()
	local preview = self:CreateOrb(health:GetName().."Preview")
	preview:SetFrameLevel(health:GetFrameLevel())
	preview:SetSize(200,200)
	preview:SetPoint("BOTTOM")
	preview:SetStatusBarTexture(GetMedia("minimap-mask-transparent"))
	preview:GetStatusBarTexture():SetDrawLayer(layer, level - 1)
	preview:SetAlpha(.5)
	preview:DisableSmoothing(true)

	self.Health.Preview = preview

	-- Health Prediction
	--------------------------------------------
	local healPredictFrame = CreateFrame("Frame", nil, health)
	healPredictFrame:SetFrameLevel(health:GetFrameLevel() + 2)
	healPredictFrame:SetAllPoints()

	local healPredict = healPredictFrame:CreateTexture(health:GetName().."Prediction", "OVERLAY")
	healPredict.health = health
	healPredict.preview = preview
	healPredict.maxOverflow = 1
	healPredict:SetTexture(GetMedia("minimap-mask-opaque"))

	self.HealthPrediction = healPredict
	self.HealthPrediction.PostUpdate = HealPredict_PostUpdate

	-- CombatFeedback
	--------------------------------------------
	local feedbackText = healthOverlay:CreateFontString(self:GetName().."CombatFeedbackText", "OVERLAY")
	feedbackText.maxAlpha = .8
	feedbackText.feedbackFont = GetFont(24, true)
	feedbackText.feedbackFontLarge = GetFont(24, true)
	feedbackText.feedbackFontSmall = GetFont(18, true)
	feedbackText:SetFontObject(feedbackText.feedbackFont)
	feedbackText:SetPoint("CENTER", health, "CENTER", 2, 2)

	self.CombatFeedback = feedbackText

	-- Power Orb
	--------------------------------------------
	local power = self:CreateOrb(self:GetName().."PowerOrb")
	power:SetSize(200,200)
	power:SetPoint("BOTTOM", 882, 0)
	power:SetStatusBarTexture(GetMedia("orb2"), GetMedia("orb2"))
	power:EnableMouse(true)
	power:SetScript("OnEnter", Power_OnEnter)
	power:SetScript("OnLeave", Power_OnLeave)
	power:SetMouseClickEnabled(false)
	power.OnEnter = Power_OnMouseOver
	power.OnLeave = Power_OnMouseOver
	power.frequentUpdates = true
	power.displayAltPower = true
	power.colorPower = true

	select(2, power:GetStatusBarTexture()):SetTexCoord(1,0,1,0) -- flip 2nd texture horizontally

	self.Power = power
	self.Power.Override = ns.API.UpdatePower

	local powerBackdrop = artworkHolder:CreateTexture(power:GetName().."Backdrop", "BACKGROUND", nil, -7)
	powerBackdrop:SetSize(330,330)
	powerBackdrop:SetPoint("CENTER", power)
	powerBackdrop:SetTexture(GetMedia("orb-backdrop2"))

	self.Power.Backdrop = powerBackdrop

	local powerOverlay = CreateFrame("Frame", nil, power)
	powerOverlay:SetFrameLevel(power:GetFrameLevel() + 5)

	self.Power.Overlay = powerOverlay

	local powerShade = artworkOverlay:CreateTexture(nil, "BACKGROUND")
	powerShade:SetAllPoints(power)
	powerShade:SetTexture(GetMedia("shade-circle"))
	powerShade:SetVertexColor(0,0,0,1)

	self.Power.Shade = powerShade

	local powerGlass = artworkOverlay:CreateTexture(power:GetName().."Glass", "BORDER")
	powerGlass:SetAllPoints(powerBackdrop)
	powerGlass:SetTexture(GetMedia("orb-glass"))
	powerGlass:SetAlpha(.6)

	self.Power.Glass = powerGlass

	local powerBorder = artworkOverlay:CreateTexture(power:GetName().."Border", "ARTWORK")
	powerBorder:SetAllPoints(powerBackdrop)
	powerBorder:SetTexture(GetMedia("orb-border"))

	self.Power.Border = powerBorder

	local powerArt = artworkOverlay:CreateTexture(power:GetName().."Artwork", "OVERLAY", nil, 1)
	powerArt:SetSize(powerBackdrop:GetSize())
	powerArt:SetPoint("BOTTOMLEFT", power, "BOTTOM", -29, -25)
	powerArt:SetTexture(GetMedia("orb-art2"))

	self.Power.Artwork = powerArt

	-- Power Value Text
	--------------------------------------------
	local powerValue = powerOverlay:CreateFontString(power:GetName().."ValueText", "OVERLAY", nil, 0)
	powerValue:Hide()
	powerValue:SetFontObject(GetFont(14,true))
	powerValue:SetTextColor(unpack(self.colors.offwhite))
	powerValue:SetAlpha(.85)
	powerValue:SetPoint("BOTTOM", power, "TOP", 0, 16)
	self:Tag(powerValue, "["..ns.Prefix..":Power:Full]")

	self.Power.Value = powerValue

	-- Castbar
	--------------------------------------------
	if (not IsAddOnEnabled("Quartz")) then

		local cast = self:CreateBar()
		cast:SetFrameStrata("MEDIUM")
		cast:SetSize(220,2)
		cast:SetPoint("CENTER", UIParent, "CENTER", 0, -150)
		cast:SetStatusBarTexture(GetMedia("plain"))
		cast:SetStatusBarColor(unpack(self.colors.cast))
		cast:DisableSmoothing(true)
		cast.timeToHold = .5

		local castBackdrop = cast:CreateTexture(nil, "BORDER", nil, -1)
		castBackdrop:SetPoint("TOPLEFT", 0, 0)
		castBackdrop:SetPoint("BOTTOMRIGHT", 0, 0)
		castBackdrop:SetColorTexture(.6, .6, .6, .05)

		local castBorder = cast:CreateTexture(nil, "BORDER", nil, -2)
		castBorder:SetPoint("TOPLEFT", -3, 3)
		castBorder:SetPoint("BOTTOMRIGHT", 3, -3)
		castBorder:SetColorTexture(0, 0, 0, .75)

		local castSafeZone = cast:CreateTexture(nil, "ARTWORK", nil, 0)
		castSafeZone:SetColorTexture(unpack(self.colors.palered))
		castSafeZone:SetAlpha(.25)
		cast.SafeZone = castSafeZone

		local castText = cast:CreateFontString(nil, "OVERLAY", nil, 0)
		castText:SetFontObject(GetFont(13,true))
		castText:SetTextColor(unpack(self.colors.offwhite))
		castText:SetAlpha(.85)
		castText:SetPoint("BOTTOM", cast, "TOP", 0, 6)
		cast.Text = castText

		local castTime = cast:CreateFontString(nil, "OVERLAY", nil, 0)
		castTime:SetFontObject(GetFont(15,true))
		castTime:SetTextColor(unpack(self.colors.offwhite))
		castTime:SetPoint("LEFT", cast, "RIGHT", 8, 0)
		castTime:SetJustifyV("MIDDLE")
		cast.Time = castTime

		local castDelay = cast:CreateFontString(nil, "OVERLAY", nil, 0)
		castDelay:SetFontObject(GetFont(12,true))
		castDelay:SetTextColor(unpack(self.colors.red))
		castDelay:SetPoint("LEFT", castTime, "RIGHT", 0, 0)
		castDelay:SetJustifyV("MIDDLE")
		cast.Delay = castDelay

		cast.CustomDelayText = Cast_CustomDelayText
		cast.CustomTimeText = Cast_CustomTimeText
		cast.PostCastInterruptible = Cast_UpdateInterruptible
		cast.PostCastStart = Cast_UpdateInterruptible
		--cast.PostCastStop = Cast_UpdateInterruptible -- needed?

		self.Castbar = cast
	end

	-- Classpowers
	--------------------------------------------
	-- 	Supported class powers:
	-- 	- All     - Combo Points
	-- 	- Mage    - Arcane Charges
	-- 	- Monk    - Chi Orbs
	-- 	- Paladin - Holy Power
	-- 	- Warlock - Soul Shards
	--------------------------------------------
	local SCP = IsAddOnEnabled("SimpleClassPower")
	if (not SCP) then

		local classpower = CreateFrame("Frame", nil, self)
		classpower:SetSize(350,70)
		classpower:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 300)
		classpower.pointWidth = 70
		classpower.PostUpdate = ClassPower_PostUpdate
		classpower.PostUpdateColor = ClassPower_PostUpdateColor

		local maxPoints = (ns.IsRetail) and (playerClass == "MONK" or playerClass == "ROGUE") and 6 or 5
		for i = 1,maxPoints do
			local point = CreatePoint(self, i)
			point:SetParent(classpower)
			if (i == 1) then
				point:SetPoint("TOPLEFT", classpower, "TOPLEFT", 0, 0)
			else
				point:SetPoint("TOPLEFT", classpower[i-1], "TOPRIGHT", 0, 0)
			end
			classpower[i] = point
		end

		self.ClassPower = classpower
	end

	-- Stagger (Monk)
	--------------------------------------------
	if (playerClass == "MONK") and (not SCP) then

		local stagger = CreateFrame("Frame", nil, self)
		stagger:SetSize(210,70)
		stagger:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 300)
		stagger.SetValue = noop
		stagger.SetMinMaxValues = noop
		stagger.SetStatusBarColor = Stagger_SetStatusBarColor

		for i = 1,3 do
			local point = CreatePoint(self, i)
			point:SetParent(stagger)
			if (i == 1) then
				point:SetPoint("TOPLEFT", stagger, "TOPLEFT", 0, 0)
			else
				point:SetPoint("TOPLEFT", stagger[i-1], "TOPRIGHT", 0, 0)
			end
			stagger[i] = point
		end

		self.Stagger = stagger
		self.Stagger.PostUpdate = Stagger_PostUpdate
	end

	-- Runes (Death Knight)
	--------------------------------------------
	if (playerClass == "DEATHKNIGHT") and ((ns.IsWrath) or (ns.IsRetail and not SCP)) then

		local runes = CreateFrame("Frame", nil, self)
		runes:SetSize(420,70)
		runes:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 300)
		runes.sortOrder = "ASC"
		runes.PostUpdate = Runes_PostUpdate
		runes.PostUpdateColor = Runes_PostUpdateColor

		for i = 1,6 do
			local rune = CreatePoint(self, i)
			rune:SetParent(runes)
			if (i == 1) then
				rune:SetPoint("TOPLEFT", runes, "TOPLEFT", 0, 0)
			else
				rune:SetPoint("TOPLEFT", runes[i-1], "TOPRIGHT", 0, 0)
			end
			runes[i] = rune
		end

		self.Runes = runes
	end

	-- Auras
	--------------------------------------------
	local buffs = CreateFrame("Frame", self:GetName().."BuffFrame", self)
	buffs:SetSize(300, 110)
	buffs.size = 40
	buffs.spacing = 4
	buffs.disableMouse = false
	buffs.disableCooldown = false
	buffs.onlyShowPlayer = false
	buffs.showStealableBuffs = false
	buffs.initialAnchor = "BOTTOMLEFT"
	buffs["spacing-x"] = 4
	buffs["spacing-y"] = 11
	buffs["growth-x"] = "RIGHT"
	buffs["growth-y"] = "UP"
	buffs.tooltipAnchor = "ANCHOR_TOPLEFT"
	buffs.sortMethod = "TIME_REMAINING"
	buffs.sortDirection = "ASCENDING"
	buffs.reanchorIfVisibleChanged = true
	buffs.CreateButton = ns.AuraStyles.CreateButtonWithBar
	buffs.PostUpdateButton = ns.AuraStyles.PlayerPostUpdateButton
	buffs.CustomFilter = ns.AuraFilters.PlayerBuffFilter
	buffs.PreSetPosition = ns.AuraSorts.Default -- only in classic
	buffs.SortAuras = ns.AuraSorts.DefaultFunction -- only in retail

	self.Buffs = buffs

	local debuffs = CreateFrame("Frame", self:GetName().."DebuffFrame", self)
	debuffs:SetSize(300, 110)
	debuffs.size = 40
	debuffs.spacing = 4
	debuffs.disableMouse = false
	debuffs.disableCooldown = false
	debuffs.onlyShowPlayer = false
	debuffs.showDebuffType = true
	debuffs.showStealableBuffs = false
	debuffs.initialAnchor = "BOTTOMRIGHT"
	debuffs["spacing-x"] = 4
	debuffs["spacing-y"] = 11
	debuffs["growth-x"] = "LEFT"
	debuffs["growth-y"] = "UP"
	debuffs.tooltipAnchor = "ANCHOR_TOPRIGHT"
	debuffs.sortMethod = "TIME_REMAINING"
	debuffs.sortDirection = "ASCENDING"
	debuffs.reanchorIfVisibleChanged = true
	debuffs.CreateButton = ns.AuraStyles.CreateButtonWithBar
	debuffs.PostUpdateButton = ns.AuraStyles.PlayerPostUpdateButton
	debuffs.CustomFilter = ns.AuraFilters.PlayerDebuffFilter
	debuffs.PreSetPosition = ns.AuraSorts.Default -- only in classic
	debuffs.SortAuras = ns.AuraSorts.DefaultFunction -- only in retail

	self.Debuffs = debuffs

	-- Scripts & Events
	--------------------------------------------
	self.OnEvent = UnitFrame_OnEvent
	self.OnEnter = UnitFrame_OnMouseOver  -- called by script handler
	self.OnLeave = UnitFrame_OnMouseOver  -- called by script handler
	self.OnHide = UnitFrame_OnHide -- called by script handler
	self.OnMouseOver = UnitFrame_OnMouseOver

	self:RegisterEvent("PLAYER_REGEN_ENABLED", self.OnEvent, true)
	self:RegisterEvent("PLAYER_REGEN_DISABLED", self.OnEvent, true)


	-- SubElement Position Callbacks
	--------------------------------------------
	self.PostUpdateAuraPositions = PostUpdateAuraPositions
	self:PostUpdateAuraPositions()

	ns.RegisterCallback(self, "ActionBars_SecondaryBar_Updated", "PostUpdateAuraPositions")
	ns.RegisterCallback(self, "ActionBars_PetBar_Updated", "PostUpdateAuraPositions")
	ns.RegisterCallback(self, "ActionBars_StanceBar_Updated", "PostUpdateAuraPositions")

end
