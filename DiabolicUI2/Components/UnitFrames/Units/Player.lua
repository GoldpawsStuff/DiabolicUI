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
local getmetatable = getmetatable
local math_huge = math.huge
local pairs = pairs
local table_sort = table.sort
local unpack = unpack

-- WoW API
local CancelUnitBuff = CancelUnitBuff
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local UnitExists = UnitExists
local UnitIsUnit = UnitIsUnit

-- Addon API
local Colors = ns.Colors
local GetFont = ns.API.GetFont
local GetMedia = ns.API.GetMedia
local IsAddOnEnabled = ns.API.IsAddOnEnabled

-- Constants
local _, PlayerClass = UnitClass("player")

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

-- Element Callbacks
--------------------------------------------
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

local SmartPower_OnEnter = function(element)
	local OnEnter = element.__owner:GetScript("OnEnter")
	if (OnEnter) then
		OnEnter(element)
	end
end

local SmartPower_OnLeave = function(element)
	local OnLeave = element.__owner:GetScript("OnLeave")
	if (OnLeave) then
		OnLeave(element)
	end
end

local SmartPower_OnMouseOver = function(element)
	element.__owner:OnMouseOver()
end

-- Frame Script Handlers
--------------------------------------------
local OnEvent = function(self, event)
	if (event == "PLAYER_REGEN_DISABLED") then
		self:OnMouseOver(event)
		local runes = self.Runes
		if (runes) and (not runes.inCombat) then
			runes.inCombat = true
			runes:ForceUpdate()
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
		local classpower = self.ClassPower
		if (classpower) and (classpower.inCombat) then
			classpower.inCombat = false
			classpower:ForceUpdate()
		end
	end
end

local OnHide = function(self)
	self.inCombat = nil
	self.isMouseOver = nil
	self.SmartPower.isMouseOver = nil
	self:OnMouseOver()
end

local OnMouseOver = function(self, event)
	if (event == "PLAYER_REGEN_DISABLED") then
		self.inCombat = true
	elseif (event == "PLAYER_REGEN_ENABLED") then
		self.inCombat = nil
	end
	if (self.isMouseOver) or (self.SmartPower.isMouseOver) or (self.inCombat) then
		self.SmartHealth.Value:Show()
		self.SmartPower.Value:Show()
		self:UpdateTags()
	else
		self.SmartHealth.Value:Hide()
		self.SmartPower.Value:Hide()
	end
end

-- Callbacks
--------------------------------------------
local PostUpdateAuraPositions = function(self, event, hasSecondary)
	if (hasSecondary) then
		self.Buffs:SetPoint("BOTTOMLEFT", UIParent, "BOTTOM", -320, 159)
		self.Debuffs:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOM", 320, 159)
	else
		self.Buffs:SetPoint("BOTTOMLEFT", UIParent, "BOTTOM", -320, 100)
		self.Debuffs:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOM", 320, 100)
	end
	ns:Fire("UnitFrame_Position_Updated", self:GetName())
end

UnitStyles["Player"] = function(self, unit, id)

	self:SetSize(200,200)

	-- Health Orb
	--------------------------------------------
	local health = self:CreateOrb()
	health:SetSize(200,200)
	health:SetPoint("BOTTOM")
	health:SetStatusBarTexture(GetMedia("orb2"), GetMedia("orb2"))
	health.colorHealth = true

	local a,b,c,d = health:GetStatusBarTexture()
	b:SetTexCoord(1,0,1,0)

	local overlay = CreateFrame("Frame", nil, health)
	overlay:SetFrameLevel(health:GetFrameLevel() + 2)

	local shade = overlay:CreateTexture(nil, "BACKGROUND")
	shade:SetAllPoints(health)
	shade:SetTexture(GetMedia("shade-circle"))
	shade:SetVertexColor(0,0,0,1)

	local glass = overlay:CreateTexture(nil, "BORDER")
	glass:SetSize(330,330)
	glass:SetPoint("CENTER", health)
	glass:SetTexture(GetMedia("orb-glass"))
	glass:SetAlpha(.6)

	local backdrop = health:CreateTexture(nil, "BACKGROUND", nil, -7)
	backdrop:SetAllPoints(glass)
	backdrop:SetTexture(GetMedia("orb-backdrop1"))
	backdrop:SetAlpha(1)

	local border = overlay:CreateTexture(nil, "ARTWORK")
	border:SetAllPoints(glass)
	border:SetTexture(GetMedia("orb-border"))

	local art = overlay:CreateTexture(nil, "OVERLAY", nil, 1)
	art:SetSize(glass:GetSize())
	art:SetPoint("BOTTOMRIGHT", health, "BOTTOM", 29, -25)
	art:SetTexture(GetMedia("orb-art1"))

	self.SmartHealth = health

	-- Power Orb
	--------------------------------------------
	local power = self:CreateOrb()
	power:SetSize(200,200)
	power:SetPoint("BOTTOM", 882, 0)
	power:SetStatusBarTexture(GetMedia("orb2"), GetMedia("orb2"))
	power:EnableMouse(true)
	power:SetScript("OnEnter", SmartPower_OnEnter)
	power:SetScript("OnLeave", SmartPower_OnLeave)
	power.OnEnter = SmartPower_OnMouseOver
	power.OnLeave = SmartPower_OnMouseOver
	power.frequentUpdates = true
	power.displayAltPower = true
	power.colorPower = true

	local a,b,c,d = power:GetStatusBarTexture()
	b:SetTexCoord(1,0,1,0)

	local overlay = CreateFrame("Frame", nil, power)
	overlay:SetFrameLevel(power:GetFrameLevel() + 2)

	local shade = overlay:CreateTexture(nil, "BACKGROUND")
	shade:SetAllPoints(power)
	shade:SetTexture(GetMedia("shade-circle"))
	shade:SetVertexColor(0,0,0,1)

	local glass = overlay:CreateTexture(nil, "BORDER")
	glass:SetSize(330,330)
	glass:SetPoint("CENTER", power)
	glass:SetTexture(GetMedia("orb-glass"))
	glass:SetAlpha(.6)

	local backdrop = power:CreateTexture(nil, "BACKGROUND", nil, -7)
	backdrop:SetAllPoints(glass)
	backdrop:SetTexture(GetMedia("orb-backdrop2"))
	backdrop:SetAlpha(1)

	local border = overlay:CreateTexture(nil, "ARTWORK")
	border:SetAllPoints(glass)
	border:SetTexture(GetMedia("orb-border"))

	local art = overlay:CreateTexture(nil, "OVERLAY", nil, 1)
	art:SetSize(glass:GetSize())
	art:SetPoint("BOTTOMLEFT", power, "BOTTOM", -29, -25)
	art:SetTexture(GetMedia("orb-art2"))

	self.SmartPower = power

	-- Castbar
	--------------------------------------------
	if (not IsAddOnEnabled("Quartz")) then

		local cast = self:CreateBar()
		cast:SetFrameStrata("MEDIUM")
		cast:SetSize(220,2)
		cast:SetPoint("CENTER", UIParent, "CENTER", 0, -150)
		--cast:SetStatusBarTexture(.3, .5, .9)
		cast:SetStatusBarTexture(GetMedia("plain"))
		cast:SetStatusBarColor(unpack(self.colors.cast))
		cast:DisableSmoothing(true)
		cast.timeToHold = 0.5

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

		local maxPoints = (ns.IsRetail) and (PlayerClass == "MONK" or PlayerClass == "ROGUE") and 6 or 5
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
	if (PlayerClass == "MONK") and (not SCP) then

		local stagger = CreateFrame("Frame", nil, self)
		stagger:SetSize(210,70)
		stagger:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 300)
		stagger.PostUpdate = ClassPower_PostUpdate

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
	end

	-- Runes (Death Knight)
	--------------------------------------------
	if (PlayerClass == "DEATHKNIGHT") and ((ns.IsWrath) or (ns.IsRetail and not SCP)) then

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

	-- Tags
	--------------------------------------------
	local healthValue = health:CreateFontString(nil, "OVERLAY", nil, 0)
	healthValue:Hide()
	healthValue:SetFontObject(GetFont(14,true))
	healthValue:SetTextColor(unpack(self.colors.offwhite))
	healthValue:SetAlpha(.85)
	healthValue:SetPoint("BOTTOM", health, "TOP", 0, 16)
	if (ns.IsWrath) then
		self:Tag(healthValue, "[Diabolic:Health:Full]")
	else
		self:Tag(healthValue, "[Diabolic:Health:Full][Diabolic:Absorb]")
	end
	self.SmartHealth.Value = healthValue

	local powerValue = power:CreateFontString(nil, "OVERLAY", nil, 0)
	powerValue:Hide()
	powerValue:SetFontObject(GetFont(14,true))
	powerValue:SetTextColor(unpack(self.colors.offwhite))
	powerValue:SetAlpha(.85)
	powerValue:SetPoint("BOTTOM", power, "TOP", 0, 16)
	self:Tag(powerValue, "[Diabolic:Power:Full]")
	self.SmartPower.Value = powerValue

	-- Auras
	--------------------------------------------
	local buffs = CreateFrame("Frame", nil, self)
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
	buffs.CreateIcon = ns.AuraStyles.CreateIconWithBar
	buffs.PostUpdateIcon = ns.AuraStyles.PlayerPostUpdateIcon
	buffs.CustomFilter = ns.AuraFilters.PlayerBuffFilter
	buffs.PreSetPosition = ns.AuraSorts.Default
	self.Buffs = buffs

	local debuffs = CreateFrame("Frame", nil, self)
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
	debuffs.CreateIcon = ns.AuraStyles.CreateIconWithBar
	debuffs.PostUpdateIcon = ns.AuraStyles.PlayerPostUpdateIcon
	debuffs.CustomFilter = ns.AuraFilters.PlayerDebuffFilter
	debuffs.PreSetPosition = ns.AuraSorts.Default
	self.Debuffs = debuffs

	-- Scripts & Events
	--------------------------------------------
	self.OnEvent = OnEvent
	self.OnEnter = OnMouseOver  -- called by script handler
	self.OnLeave = OnMouseOver  -- called by script handler
	self.OnHide = OnHide -- called by script handler
	self.OnMouseOver = OnMouseOver

	self:RegisterEvent("PLAYER_REGEN_ENABLED", self.OnEvent, true)
	self:RegisterEvent("PLAYER_REGEN_DISABLED", self.OnEvent, true)


	-- SubElement Position Callbacks
	--------------------------------------------
	self.PostUpdateAuraPositions = PostUpdateAuraPositions
	self:PostUpdateAuraPositions()

	ns.RegisterCallback(self, "ActionBars_SecondaryBar_Updated", "PostUpdateAuraPositions")

end
