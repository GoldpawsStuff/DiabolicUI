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
local Timers = ns:NewModule("Timers", "LibMoreEvents-1.0", "AceTimer-3.0", "AceHook-3.0")

-- Lua API
local _G = _G
local math_floor = math.floor
local table_insert = table.insert
local table_sort = table.sort
local table_wipe = table.wipe
local unpack = unpack

-- WoW API
local GetTime = GetTime
local GetUnitPowerBarInfo = GetUnitPowerBarInfo
local GetUnitPowerBarInfoByID = GetUnitPowerBarInfoByID
local GetUnitPowerBarStringsByID = GetUnitPowerBarStringsByID
local UnitPowerBarTimerInfo = UnitPowerBarTimerInfo

-- WoW Constants
local ALT_POWER_TYPE_COUNTER = ALT_POWER_TYPE_COUNTER or 4

-- Addon API
local Colors = ns.Colors
local GetFont = ns.API.GetFont
local GetMedia = ns.API.GetMedia
local SetObjectScale = ns.API.SetObjectScale
local IsAddOnEnabled = ns.API.IsAddOnEnabled

-- Global hider frame
local UIHider = ns.Hider

-- Cache of handled elements
local Handled = {}

Timers.UpdateMirrorTimers = function(self)
	for i = 1, MIRRORTIMER_NUMTIMERS do
		local timer  = _G["MirrorTimer"..i] -- 206,26
		if (timer) then
			local bar = _G[timer:GetName().."StatusBar"] -- 195,13 "TOP"
			if (not Handled[bar]) then

				SetObjectScale(timer)
				if (i == 1) then
					timer:ClearAllPoints()
					timer:SetPoint("TOP", 0, -300)
				end

				local oldborder = _G[timer:GetName().."Border"] -- 256,64 "TOP",0,25
				local label = _G[timer:GetName().."Text"] -- "TOP"

				for i = 1, bar:GetNumRegions() do
					local region = select(i, bar:GetRegions())
					if (region:GetObjectType() == "Texture") then
						region:SetTexture(nil)
					end
				end
				oldborder:SetTexture(nil)

				bar:SetStatusBarTexture(GetMedia("bar-progress"))
				bar:GetStatusBarTexture():SetDrawLayer("BORDER", 0)
				--bar:DisableDrawLayer("BACKGROUND")
				bar:SetHeight(18)
				bar:ClearAllPoints()
				bar:SetPoint("TOP", 0, 3)

				label:ClearAllPoints()
				label:SetPoint("CENTER", bar, 0,0)
				label:SetFontObject(GetFont(12,true))

				local border = bar:CreateTexture(nil, "BORDER", nil, -2)
				border:SetDrawLayer("BORDER", -2)
				border:SetPoint("TOPLEFT", -2, 2)
				border:SetPoint("BOTTOMRIGHT", 2, -2)
				border:SetColorTexture(0, 0, 0, .75)

				local backdrop = bar:CreateTexture(nil, "BORDER", nil, -1)
				backdrop:SetPoint("TOPLEFT", 0, 0)
				backdrop:SetPoint("BOTTOMRIGHT", 0, 0)
				backdrop:SetColorTexture(.6, .6, .6, .05)

				Handled[bar] = true
			end
			bar:SetStatusBarColor(Colors.quest.red[1], Colors.quest.red[2], Colors.quest.red[3])
		end

	end
end

Timers.UpdateTimerTrackers = function(self, event, ...)
	for _,timer in pairs(TimerTracker.timerList) do
		local bar = timer and timer.bar
		if (bar) then
			if (not Handled[bar]) then

				for i = 1, bar:GetNumRegions() do
					local region = select(i, bar:GetRegions())
					if (region:GetObjectType() == "Texture") then
						region:SetTexture(nil)
					elseif (region:GetObjectType() == "FontString") then
						-- Should only be one
						region:ClearAllPoints()
						region:SetPoint("CENTER", bar, 0,0)
						region:SetFontObject(GetFont(12,true))
					end
				end

				SetObjectScale(timer)

				bar:SetStatusBarTexture(GetMedia("bar-progress"))
				bar:GetStatusBarTexture():SetDrawLayer("BORDER", 0)
				--bar:DisableDrawLayer("BACKGROUND")
				bar:SetHeight(18)
				bar:ClearAllPoints()
				bar:SetPoint("TOP", 0, 3)

				local border = bar:CreateTexture(nil, "BORDER", nil, -2)
				border:SetDrawLayer("BORDER", -2)
				border:SetPoint("TOPLEFT", -2, 2)
				border:SetPoint("BOTTOMRIGHT", 2, -2)
				border:SetColorTexture(0, 0, 0, .75)

				local backdrop = bar:CreateTexture(nil, "BORDER", nil, -1)
				backdrop:SetPoint("TOPLEFT", 0, 0)
				backdrop:SetPoint("BOTTOMRIGHT", 0, 0)
				backdrop:SetColorTexture(.6, .6, .6, .05)

				Handled[bar] = true
			end
			bar:SetStatusBarColor(Colors.quest.red[1], Colors.quest.red[2], Colors.quest.red[3])
		end
	end
end

Timers.UpdateAll = function(self)
	self:UpdateMirrorTimers("ForceUpdate")

	if (ns.IsRetail) then
		self:UpdateTimerTrackers("ForceUpdate")
	end
end

Timers.OnInitialize = function(self)

	-- Reset scripts and events
	for i = 1, MIRRORTIMER_NUMTIMERS do
		local timer  = _G["MirrorTimer"..i]
		if (timer) then
			timer:SetParent(UIParent)
			timer:SetScript("OnEvent", MirrorTimerFrame_OnEvent)
			timer:SetScript("OnUpdate", MirrorTimerFrame_OnUpdate)
			MirrorTimerFrame_OnLoad(timer)
		end
	end

	-- Update mirror timers (breath/fatigue)
	self:SecureHook("MirrorTimer_Show", "UpdateMirrorTimers")

	-- Update timer trackers (instance/bg countdowns)
	if (ns.IsRetail) then
		self:RegisterEvent("START_TIMER", "UpdateTimerTrackers")
	end

	-- Update all on world entering
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateAll")

end

Timers.OnEnable = function(self)

end
