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

local MASK_TEXTURE = GetMedia("actionbutton-mask-circular")

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
						local sortDirection = a:GetParent().sortDirection
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

local Aura_BuffFilter = function(element, unit, button, name, texture,
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

local Aura_DebuffFilter = function(element, unit, button, name, texture,
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

	return true
end

local Aura_BuffSorting = function(element, max)
	table_sort(element, Aura_Sort)
	return 1, #element
end

local Aura_DebuffSorting = function(element, max)
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

local Aura_Secure_OnClick = function(self, button, down)
	if (button == "RightButton") and (not InCombatLockdown()) then
		local unit = self:GetParent().__owner.unit
		if (not self.isDebuff) and (UnitExists(unit)) then
			CancelUnitBuff(unit, self:GetID(), self.filter)
		end
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
	count:SetFontObject(GetFont(14,true))
	count:SetTextColor(Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3])
	count:SetPoint("BOTTOMRIGHT", aura, "BOTTOMRIGHT", -2, 3)
	aura.count = count

	local time = aura.border:CreateFontString(nil, "OVERLAY")
	time:SetFontObject(GetFont(14,true))
	time:SetTextColor(Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3])
	time:SetPoint("TOPLEFT", aura, "TOPLEFT", -4, 4)
	aura.time = time

	local bar = element.__owner:CreateBar(nil, aura)
	bar:SetPoint("TOP", aura, "BOTTOM", 0, 0)
	bar:SetPoint("LEFT", aura, "LEFT", 1, 0)
	bar:SetPoint("RIGHT", aura, "RIGHT", -1, 0)
	bar:SetHeight(6)
	bar:SetStatusBarTexture(GetMedia("bar-small"))
	bar.bg = bar:CreateTexture(nil, "BACKGROUND", -7)
	bar.bg:SetPoint("TOPLEFT", -1, 1)
	bar.bg:SetPoint("BOTTOMRIGHT", 1, -1)
	bar.bg:SetColorTexture(.05, .05, .05, .85)
	aura.bar = bar

	-- Using a virtual cooldown element with the bar and timer attached,
	-- allowing them to piggyback on oUF's cooldown updates.
	aura.cd = ns.Widgets.RegisterCooldown(bar, time)

	-- Replacing oUF's aura tooltips, as they are not secure.
	aura.UpdateTooltip = Aura_Secure_UpdateTooltip
	aura:SetScript("OnEnter", Aura_Secure_OnEnter)
	aura:SetScript("OnLeave", Aura_Secure_OnLeave)
	aura:SetScript("OnClick", Aura_Secure_OnClick)

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
		color = Colors.xp
	end
	if (color) then
		button.border:SetBackdropBorderColor(color[1], color[2], color[3])
		button.bar:SetStatusBarColor(color[1], color[2], color[3])
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


UnitStyles["Player"] = function(self, unit, id)

	self:SetSize(200,200)

	-- Health Orb
	--------------------------------------------
	local health = self:CreateOrb()
	health:SetSize(200,200)
	health:SetPoint("BOTTOM")
	health:SetStatusBarTexture(GetMedia("orb2"), GetMedia("orb2"))
	health.colorHealth = true
	health.showAbsorbGap = false -- wait until we got a shield texture up
	health.showAbsorbAsHealth = false -- don't. we die!

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

	-- Tags
	--------------------------------------------
	local healthValue = health:CreateFontString(nil, "OVERLAY", nil, 0)
	healthValue:Hide()
	healthValue:SetFontObject(GetFont(14,true))
	healthValue:SetTextColor(unpack(self.colors.offwhite))
	healthValue:SetAlpha(.85)
	healthValue:SetPoint("BOTTOM", health, "TOP", 0, 16)
	self:Tag(healthValue, "[Diabolic:Health:Full][Diabolic:Absorb]")
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

	buffs.CreateIcon = Aura_CreateIcon
	buffs.PostUpdateIcon = Aura_PostUpdateIcon
	buffs.CustomFilter = Aura_BuffFilter
	buffs.PreSetPosition = Aura_BuffSorting
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

	debuffs.CreateIcon = Aura_CreateIcon
	debuffs.PostUpdateIcon = Aura_PostUpdateIcon
	debuffs.CustomFilter = Aura_DebuffFilter
	debuffs.PreSetPosition = Aura_DebuffSorting
	self.Debuffs = debuffs


	-- Hover Scripts
	--------------------------------------------
	local UpdateMouseOver = function(_,event)
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

	self.OnEnter = UpdateMouseOver
	self.OnLeave = UpdateMouseOver
	self.OnHide = function()
		self.inCombat = nil
		self.isMouseOver = nil
		self.SmartPower.isMouseOver = nil
		UpdateMouseOver()
	end
	self.SmartPower.OnEnter = UpdateMouseOver
	self.SmartPower.OnLeave = UpdateMouseOver
	self.SmartPower:EnableMouse(true)
	self.SmartPower:SetScript("OnEnter", self:GetScript("OnEnter"))
	self.SmartPower:SetScript("OnLeave", self:GetScript("OnLeave"))
	self:RegisterEvent("PLAYER_REGEN_ENABLED", UpdateMouseOver, true)
	self:RegisterEvent("PLAYER_REGEN_DISABLED", UpdateMouseOver, true)


	-- SubElement Position Callbacks
	--------------------------------------------
	self.UpdatePositions = function(self, event, hasSecondary)
		if (hasSecondary) then
			self.Buffs:SetPoint("BOTTOMLEFT", UIParent, "BOTTOM", -320, 159)
			self.Debuffs:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOM", 320, 159)
		else
			self.Buffs:SetPoint("BOTTOMLEFT", UIParent, "BOTTOM", -320, 100)
			self.Debuffs:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOM", 320, 100)
		end
		ns:Fire("UnitFrame_Position_Updated", self:GetName())
	end
	self:UpdatePositions()
	ns.RegisterCallback(self, "ActionBars_SecondaryBar_Updated", "UpdatePositions")

end
