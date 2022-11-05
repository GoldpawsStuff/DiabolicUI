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
local ActionBars = ns:GetModule("ActionBars")
local StatusBars = ActionBars:NewModule("StatusBars", "LibMoreEvents-1.0")
local LibSmoothBar = LibStub("LibSmoothBar-1.0")

-- Lua API
local math_floor = math.floor
local math_min = math.min
local string_format = string.format
local unpack = unpack

-- WoW API
local GetFactionInfo = GetFactionInfo
local GetFactionParagonInfo = C_Reputation and C_Reputation.GetFactionParagonInfo
local C_GossipInfo_GetFriendshipReputation = C_GossipInfo and C_GossipInfo.GetFriendshipReputation
local GetNumFactions = GetNumFactions
local GetRestState = GetRestState
local GetTimeToWellRested = GetTimeToWellRested
local GetWatchedFactionInfo = GetWatchedFactionInfo
local GetXPExhaustion = GetXPExhaustion
local IsFactionParagon = C_Reputation and C_Reputation.IsFactionParagon
local IsPlayerAtEffectiveMaxLevel = IsPlayerAtEffectiveMaxLevel
local IsResting = IsResting
local IsXPUserDisabled = IsXPUserDisabled
local UnitLevel = UnitLevel
local UnitSex = UnitSex
local UnitXP = UnitXP
local UnitXPMax = UnitXPMax

-- Addon API
local Colors = ns.Colors
local GetFont = ns.API.GetFont
local GetMedia = ns.API.GetMedia
local SetObjectScale = ns.API.SetObjectScale

local playerLevel = UnitLevel("player")

-- Local bar registry
local Bars = {}

local Reputation_OnEnter = function(self)
	if (GameTooltip:IsForbidden()) then
		return
	end
	local r, g, b = unpack(Colors[self.isFriend and "friendship" or "reaction"][self.standingID])
	GameTooltip_SetDefaultAnchor(GameTooltip, self)
	GameTooltip:AddDoubleLine(self.name, self.standingLabel, r, g, b, unpack(Colors.gray))
	GameTooltip:Show()
end

local Reputation_OnLeave = function(self)
	if (GameTooltip:IsForbidden()) then
		return
	end
	GameTooltip:Hide()
end

local XP_OnEnter = function(self)
	if (GameTooltip:IsForbidden()) then
		return
	end

	local r, g, b = unpack(Colors.highlight)

	local exhaustionCountdown = GetTimeToWellRested() and (GetTimeToWellRested() / 60)
	local exhaustionStateID, exhaustionStateName, exhaustionStateMultiplier = GetRestState()
	local tooltipText = string_format(EXHAUST_TOOLTIP1, exhaustionStateName, exhaustionStateMultiplier * 100)

	if (exhaustionCountdown and GetXPExhaustion() and IsResting()) then
		tooltipText = tooltipText..string_format(EXHAUST_TOOLTIP4, exhaustionCountdown)
	elseif (exhaustionStateID == 4 or exhaustionStateID == 5) then
		tooltipText = tooltipText..EXHAUST_TOOLTIP2
	end

	GameTooltip_SetDefaultAnchor(GameTooltip, self)
	GameTooltip:AddDoubleLine(COMBAT_XP_GAIN, string_format(UNIT_LEVEL_TEMPLATE, UnitLevel("player")), r, g, b, unpack(Colors.gray))
	GameTooltip:AddLine("\n"..tooltipText)
	GameTooltip:Show()
end

local XP_OnLeave = function(self)
	if (GameTooltip:IsForbidden()) then
		return
	end
	GameTooltip:Hide()
end

StatusBars.CreateBars = function(self)
	local scaffold = SetObjectScale(CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate"))
	scaffold:SetPoint("BOTTOM")
	scaffold:SetSize(2,2)
	scaffold:SetFrameStrata("BACKGROUND")
	scaffold:SetFrameLevel(15) -- keep this a few levels above the bar artwork
	RegisterStateDriver(scaffold, "visibility", "[petbattle]hide;show")

	for i = 1,2 do
		local bar = LibSmoothBar:CreateSmoothBar(ns.Prefix.."TrackingStatusBar", scaffold)
		bar:SetSize(650,10)
		bar:GetStatusBarTexture():SetTexCoord(374/2048, 1674/2048, 4/32, 28/32)

		if (i == 1) then
			bar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 68)
			bar:SetStatusBarTexture(GetMedia("statusbars-diabolic"))
			bar:SetStatusBarColor(unpack(Colors.rested))

			local backdrop = bar:CreateTexture(nil, "BACKGROUND", nil, -7)
			backdrop:SetSize(1024,14)
			backdrop:SetPoint("CENTER", 0, 0)
			backdrop:SetTexture(GetMedia("statusbars-backdrop-diabolic"))
			backdrop:SetVertexColor(.6, .55, .5, .5)

			local overlay = bar:CreateTexture(nil, "OVERLAY", nil, 0)
			overlay:SetIgnoreParentAlpha(true)
			overlay:SetSize(1024,14)
			overlay:SetPoint("CENTER", 0, 0)
			overlay:SetTexture(GetMedia("statusbars-overlay-diabolic"))
			overlay:SetVertexColor(1, 1, 1, 2/3)

			local label = bar:CreateFontString(nil, "HIGHLIGHT", nil, 1)
			label:SetPoint("CENTER", 4, 0)
			label:SetJustifyH("CENTER")
			label:SetJustifyV("MIDDLE")
			label:SetFontObject(GetFont(14, "true"))
			label:SetTextColor(unpack(Colors.offwhite))
			bar.Label = label

			local extraLabel = bar:CreateFontString(nil, "HIGHLIGHT", nil, 1)
			extraLabel:SetPoint("LEFT", label, "RIGHT", 6, 0)
			extraLabel:SetJustifyH("CENTER")
			extraLabel:SetJustifyV("MIDDLE")
			extraLabel:SetFontObject(GetFont(14, "true"))
			extraLabel:SetTextColor(unpack(Colors.gray))
			bar.ExtraLabel = extraLabel

			local AdjustOverlayTexCoords = function(self)
				local displayValue = self:GetDisplayValue()
				if (displayValue ~= self.displayValue) then
					local min,max = self:GetMinMaxValues()
					local perc = displayValue/max
					if (perc < 99.9) then
						local size = (374 + perc*1300)
						overlay:SetTexCoord(0, size/2048, 0, 1)
						overlay:SetWidth(size/2)
						overlay:SetPoint("CENTER", -(2048-size)/4, 0)
					else
						overlay:SetTexCoord(0, 1, 0, 1)
						overlay:SetWidth(1024)
						overlay:SetPoint("CENTER", 0, 0)
					end
				end
			end
			AdjustOverlayTexCoords(bar)
			bar:SetScript("OnUpdate", AdjustOverlayTexCoords)

		elseif (i == 2) then
			bar:SetPoint("BOTTOM", Bars[1], "BOTTOM", 0, 0)
			bar:SetStatusBarTexture(GetMedia("statusbars-dimmed-diabolic"))
			bar:GetStatusBarTexture():SetDrawLayer("BACKGROUND", -6)
			bar:SetStatusBarColor(unpack(Colors.restedBonus))
			Bars[1].BonusBar = bar
		end

		Bars[i] = bar
	end
	ns:Fire("StatusTrackingBar_Created", Bars[1]:GetName())
end

StatusBars.UpdateBars = function(self, event, ...)
	if (not Bars) then
		return
	end
	local bar,bonus = Bars[1],Bars[2]
	local bonusShown = bonus:IsShown()

	local name, reaction, min, max, current, factionID = GetWatchedFactionInfo()
	if (name) then
		local forced = bar.currentType ~= "reputation"
		local gender = UnitSex("player")

		-- Check for retail paragon factions
		if (ns.IsRetail) then
			if (factionID and IsFactionParagon(factionID)) then
				local currentValue, threshold, _, hasRewardPending = GetFactionParagonInfo(factionID)
				if (currentValue and threshold) then
					min, max = 0, threshold
					current = currentValue % threshold
					if (hasRewardPending) then
						current = current + threshold
					end
				end
			end
		end

		-- Figure out the standingID of the watched faction
		local standingID, standingLabel, standingDescription, isFriend, friendText
		for i = 1, GetNumFactions() do
			local factionName, description, standingId, barMin, barMax, barValue, atWarWith, canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild, factionID, hasBonusRepGain, canBeLFGBonus = GetFactionInfo(i)
			if (factionName == name) then

				-- Check if the watched faction is a retail friendship
				if (ns.IsRetail) then
					local repInfo = C_GossipInfo_GetFriendshipReputation(factionID)
					if (repInfo and repInfo.friendshipFactionID > 0) then
						if (repInfo.friendshipFactionID) then
							isFriend = true
							if (repInfo.nextThreshold) then
								min = repInfo.reactionThreshold
								max = repInfo.nextThreshold
								current = repInfo.standing
							else
								-- Make maxed friendships appear as a full bar.
								min = 0
								max = 1
								current = 1
							end
							standingLabel = repInfo.reaction
						end
					end
				end

				standingDescription = description
				standingID = standingId
				break
			end
		end

		if (standingID) then
			local barMax = max - min
			local barValue = current - min
			if (barMax == 0) then
				bar:SetMinMaxValues(0,1)
				bar:SetValue(1)
			else
				bar:SetMinMaxValues(0, max-min)
				bar:SetValue(current-min)
			end
			bar:SetStatusBarColor(unpack(Colors[isFriend and "friendship" or "reaction"][standingID]))
			bar.currentType = "reputation"

			if (not isFriend) then
				standingLabel = GetText("FACTION_STANDING_LABEL"..standingID, gender)
			end

			bar.name = name
			bar.isFriend = isFriend
			bar.standingID, bar.standingLabel = standingID, standingLabel

			bar.Label:SetFormattedText("%s "..Colors.gray.colorCode.."/|r %s", barValue, barMax)
			bar.ExtraLabel:SetText("("..standingLabel..")")

			bar:SetScript("OnEnter", Reputation_OnEnter)
			bar:SetScript("OnLeave", Reputation_OnLeave)
			bar:SetMouseClickEnabled(false)
			bar:Show()

		else
			-- this can happen?
			bar:SetScript("OnEnter", nil)
			bar:SetScript("OnLeave", nil)
			bar:SetMouseClickEnabled(false)
			bar:Hide()
		end

		if (bonusShown) then
			bonus:Hide()
			bonus:SetValue(0, true)
			bonus:SetMinMaxValues(0, 1, true)
		end
	else
		if (IsPlayerAtEffectiveMaxLevel() or IsXPUserDisabled()) then
			bar.currentType = nil
			bar:Hide()
			bar:SetScript("OnEnter", nil)
			bar:SetScript("OnLeave", nil)
			bar:SetMouseClickEnabled(false)
			bar.Label:SetText("")
			bar.ExtraLabel:SetText("")
		else
			if (event == "PLAYER_LEVEL_UP") then
				playerLevel = ...
			end

			local forced = bar.currentType ~= "xp"
			local resting = IsResting()
			local restState, restedName, mult = GetRestState()
			local restedLeft, restedTimeLeft = GetXPExhaustion(), GetTimeToWellRested()
			local min = UnitXP("player") or 0
			local max = UnitXPMax("player") or 0

			bar:SetMinMaxValues(0, max, forced)
			bar:SetValue(min, forced)
			bar:SetStatusBarColor(unpack(Colors[restedLeft and "rested" or "xp"]))
			bar.currentType = "xp"

			if (restedLeft) then
				bonus:SetMinMaxValues(0, max, not bonusShown)
				bonus:SetValue(math_min(max, min + (restedLeft or 0)), not bonusShown)
				if (not bonusShown) then
					bonus:Show()
				end
			elseif (bonusShown) then
				bonus:Hide()
				bonus:SetValue(0, true)
				bonus:SetMinMaxValues(0, 1, true)
			end

			bar.Label:SetFormattedText("%s "..Colors.gray.colorCode.."/|r %s ", min, max)
			bar.ExtraLabel:SetFormattedText("("..UNIT_LEVEL_TEMPLATE..")", playerLevel or UnitLevel("player"))

			bar:SetScript("OnEnter", XP_OnEnter)
			bar:SetScript("OnLeave", XP_OnLeave)
			bar:SetMouseClickEnabled(false)
			bar:Show()
		end
	end

end

StatusBars.UpdatePosition = function(self)
	if (not Bars) then
		return
	end
	Bars[1]:SetPoint("BOTTOM", 0, 68 + ActionBars:GetBarOffset())
end

StatusBars.OnInitialize = function(self)
	self:CreateBars()
	ns.RegisterCallback(self, "ActionBars_SecondaryBar_Updated", "UpdatePosition")
end

StatusBars.OnEnable = function(self)
	self:UpdateBars()
	self:UpdatePosition()
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateBars")
	self:RegisterEvent("PLAYER_LOGIN", "UpdateBars")
	self:RegisterEvent("PLAYER_ALIVE", "UpdateBars")
	self:RegisterEvent("PLAYER_LEVEL_UP", "UpdateBars")
	self:RegisterEvent("PLAYER_XP_UPDATE", "UpdateBars")
	self:RegisterEvent("PLAYER_FLAGS_CHANGED", "UpdateBars")
	self:RegisterEvent("DISABLE_XP_GAIN", "UpdateBars")
	self:RegisterEvent("ENABLE_XP_GAIN", "UpdateBars")
	self:RegisterEvent("PLAYER_UPDATE_RESTING", "UpdateBars")
	self:RegisterEvent("UPDATE_EXHAUSTION", "UpdateBars")
	self:RegisterEvent("UPDATE_FACTION", "UpdateBars")
end