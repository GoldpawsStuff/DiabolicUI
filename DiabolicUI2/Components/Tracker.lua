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
local Tracker = ns:NewModule("Tracker", "LibMoreEvents-1.0")

-- WoW API
local hooksecurefunc = hooksecurefunc
local IsAddOnLoaded = IsAddOnLoaded
local SetOverrideBindingClick = SetOverrideBindingClick

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

local UpdateObjectiveTracker = function()
	local frame = ObjectiveTrackerFrame.MODULES
	if (frame) then
		for i = 1,#frame do
			local module = frame[i]
			if (module) then

				local header = module.Header

				local background = header.Background
				background:SetAtlas(nil)

				local msg = header.Text
				msg:SetFontObject(GetFont(16,true))
				msg:SetTextColor(unpack(ns.Colors.title))
				msg:SetShadowColor(0,0,0,0)
				msg:SetDrawLayer("OVERLAY", 7)
				msg:SetParent(header)

				local blocks = module:GetActiveBlocks()
				for id,block in pairs(blocks) do
					-- Quest/Objective title
					if (block.HeaderText) then
						block.HeaderText:SetFontObject(GetFont(13,true))
						block.HeaderText:SetSpacing(2)
					end
					-- Quest/Objective text/objectives
					for objectiveKey,line in pairs(block.lines) do
						line.Text:SetFontObject(GetFont(13,true))
						line.Text:SetSpacing(2)
						if (line.Dash) then
							line.Dash:SetParent(UIHider)
						end
					end
				end

				if (not Handled[module]) then
					local minimize = header.MinimizeButton
					minimize.SetCollapsed = function() return end
					minimize:DisableDrawLayer(minimize:GetNormalTexture():SetTexture(nil))
					minimize:DisableDrawLayer(minimize:GetPushedTexture():SetTexture(nil))
					minimize:DisableDrawLayer(minimize:GetHighlightTexture():SetTexture(nil))
					minimize:ClearAllPoints()
					minimize:SetAllPoints(header)

					Handled[module] = true
				end
			end
		end
	end
end

local UpdateProgressBar = function(_, _, line)

	local progress = line.ProgressBar
	local bar = progress.Bar

	if (bar) then
		local label = bar.Label
		local icon = bar.Icon
		local iconBG = bar.IconBG
		local barBG = bar.BarBG
		local glow = bar.BarGlow
		local sheen = bar.Sheen
		local frame = bar.BarFrame
		local frame2 = bar.BarFrame2
		local frame3 = bar.BarFrame3
		local borderLeft = bar.BorderLeft
		local borderRight = bar.BorderRight
		local borderMid = bar.BorderMid

		-- Some of these tend to pop back up, so let's just always hide them.
		if (barBG) then barBG:Hide(); barBG:SetAlpha(0) end
		if (iconBG) then iconBG:Hide(); iconBG:SetAlpha(0) end
		if (glow) then glow:Hide() end
		if (sheen) then sheen:Hide() end
		if (frame) then frame:Hide() end
		if (frame2) then frame2:Hide() end
		if (frame3) then frame3:Hide() end
		if (borderLeft) then borderLeft:SetAlpha(0) end
		if (borderRight) then borderRight:SetAlpha(0) end
		if (borderMid) then borderMid:SetAlpha(0) end

		-- This will fix "stuck" animations?
		if (progress.AnimatableFrames) then
			BonusObjectiveTrackerProgressBar_ResetAnimations(progress)
		end

		if (not Handled[bar]) then

			bar:SetStatusBarTexture(GetMedia("bar-progress"))
			bar:GetStatusBarTexture():SetDrawLayer("BORDER", 0)
			bar:DisableDrawLayer("BACKGROUND")
			bar:SetHeight(18)

			local backdrop = bar:CreateTexture(nil, "BORDER", nil, -1)
			backdrop:SetPoint("TOPLEFT", 0, 0)
			backdrop:SetPoint("BOTTOMRIGHT", 0, 0)
			backdrop:SetColorTexture(.6, .6, .6, .05)

			local border = bar:CreateTexture(nil, "BORDER", nil, -2)
			border:SetPoint("TOPLEFT", -2, 2)
			border:SetPoint("BOTTOMRIGHT", 2, -2)
			border:SetColorTexture(0, 0, 0, .75)

			if (label) then
				label:ClearAllPoints()
				label:SetPoint("CENTER", bar, 0,0)
				label:SetFontObject(GetFont(12,true))
			end

			if (icon) then
				icon:SetSize(20,20)
				icon:SetMask("")
				icon:SetMask(GetMedia("actionbutton-mask-square-rounded"))
				icon:ClearAllPoints()
				icon:SetPoint("RIGHT", bar, 26, 0)
			end

			Handled[bar] = true

		elseif (icon) and (bar.NewBorder) then
			bar.NewBorder:SetShown(icon:IsShown())
		end
	end
end

local UpdateWatchFrameLine = function(line)
	if (not Handled[line]) then
		--local name = line:GetName()
		--local icon = _G[name.."Icon"]
		--local border = _G[name.."Border"]
		line.text:SetFontObject(GetFont(15,true)) -- default size is 16
		Handled[line] = true
	end
	-- Always assure this is cleared
	-- *don't clear the text, it's indent is needed!
	line.dash:SetAlpha(0)
end

local UpdateQuestItemButton = function(button)
	local name = button:GetName()
	local icon = button.icon or _G[name.."IconTexture"]
	local count = button.Count or _G[name.."Count"]
	local hotKey = button.HotKey or _G[name.."HotKey"]

	if (not Handled[button]) then
		button:SetNormalTexture(nil)

		if (icon) then
			icon:SetDrawLayer("BACKGROUND",0)
			icon:SetTexCoord(5/64, 59/64, 5/64, 59/64)
			icon:ClearAllPoints()
			icon:SetPoint("TOPLEFT", 2, -2)
			icon:SetPoint("BOTTOMRIGHT", -2, 2)

			local backdrop = button:CreateTexture(nil, "BACKGROUND", nil, -7)
			backdrop:SetPoint("TOPLEFT", icon, -2, 2)
			backdrop:SetPoint("BOTTOMRIGHT", icon, 2, -2)
			backdrop:SetColorTexture(0, 0, 0, .75)
		end

		if (count) then
			count:ClearAllPoints()
			count:SetPoint("BOTTOMRIGHT", button, 0, 3)
			count:SetFontObject(GetFont(12,true))
		end

		if (hotKey) then
			hotKey:SetText("")
			hotKey:SetAlpha(0)
		end

		if (button.SetHighlightTexture and not button.Highlight) then
			local Highlight = button:CreateTexture()

			Highlight:SetColorTexture(1, 1, 1, 0.3)
			Highlight:SetAllPoints(icon)

			button.Highlight = Highlight
			button:SetHighlightTexture(Highlight)
		end

		if (button.SetPushedTexture and not button.Pushed) then
			local Pushed = button:CreateTexture()

			Pushed:SetColorTexture(0.9, 0.8, 0.1, 0.3)
			Pushed:SetAllPoints(icon)

			button.Pushed = Pushed
			button:SetPushedTexture(Pushed)
		end

		if (button.SetCheckedTexture and not button.Checked) then
			local Checked = button:CreateTexture()

			Checked:SetColorTexture(0, 1, 0, 0.3)
			Checked:SetAllPoints(icon)

			button.Checked = Checked
			button:SetCheckedTexture(Checked)
		end

		Handled[button] = true
	end
end

local UpdateQuestItem = function(_, block)
	local button = block.itemButton
	if (button) then
		UpdateQuestItemButton(button)
	end
end

-----------------------------------------------------------------
-- Frames
-----------------------------------------------------------------
local ObjectiveCover = CreateFrame("Frame", nil, UIParent)
ObjectiveCover:EnableMouse(true)
ObjectiveCover:Hide()

local ObjectiveAlphaDriver = CreateFrame("Frame", nil, UIParent, "SecureHandlerAttributeTemplate")
ObjectiveAlphaDriver.Update = function()

	-- The tracker addon might not be loaded.
	local tracker = WatchFrame or QuestWatchFrame or ObjectiveTrackerFrame

	-- Check for the visibility of addons conflicting with the visuals.
	--local bags = Wheel("LibModule"):GetModule("Backpacker", true)
	--local bagsVisible = bags and bags:IsVisible()
	local immersionVisible = ImmersionFrame and ImmersionFrame:IsShown()

	-- Fake-hide the tracker if something is covering its area. We don't like clutter.
	--local shouldHide = (tracker) and ((immersionVisible) or (bagsVisible) or (not ObjectiveAlphaDriver:IsShown()))
	local shouldHide = (tracker) and ((immersionVisible) or (not ObjectiveAlphaDriver:IsShown()))
	if (shouldHide) then
		tracker:SetIgnoreParentAlpha(false)
		tracker:SetAlpha(0)

		ObjectiveCover:SetFrameStrata(tracker:GetFrameStrata())
		ObjectiveCover:SetFrameLevel(tracker:GetFrameLevel() + 5)
		ObjectiveCover:ClearAllPoints()
		ObjectiveCover:SetAllPoints(tracker)
		ObjectiveCover:SetHitRectInsets(-40, -80, -40, 40)
		ObjectiveCover:Show()
	else
		-- The tracker addon might not be loaded.
		if (tracker) then
			tracker:SetIgnoreParentAlpha(false)
			tracker:SetAlpha(.9)
		end
		ObjectiveCover:Hide()
	end
end

-- This creates a driver frames that toggles
-- the displayed alpha of the tracker,
-- and also covers it with a mouse enabled overlay.
-- The driver frame does NOT toggle the actual tracker.
Tracker.InitializeAlphaDriver = function(self)

	if (not ObjectiveAlphaDriver.isHooked) then
		--ObjectiveAlphaDriver:HookScript("OnShow", ObjectiveAlphaDriver.Update)
		--ObjectiveAlphaDriver:HookScript("OnHide", ObjectiveAlphaDriver.Update)
		ObjectiveAlphaDriver:SetAttribute("_onattributechanged", [=[
			if (name == "state-vis") then
				if (value == "show") then
					self:Show();
					self:CallMethod("Update");

				elseif (value == "hide") then
					self:Hide();
					self:CallMethod("Update");
				end
			end
		]=])
	end

	if (ObjectiveAlphaDriver.isHooked) then
		UnregisterAttributeDriver(ObjectiveAlphaDriver, "state-vis")
	end

	local driver = "hide;show"
	--driver = "[overridebar][possessbar][shapeshift][vehicleui]"  .. driver
	driver = "[@arena1,exists][@arena2,exists][@arena3,exists][@arena4,exists][@arena5,exists]" .. driver
	driver = "[@boss1,exists][@boss2,exists][@boss3,exists][@boss4,exists]" .. driver
	--driver = "[combat]" .. driver

	RegisterAttributeDriver(ObjectiveAlphaDriver, "state-vis", driver)

	ObjectiveAlphaDriver.isHooked = true
end

Tracker.InitializeTracker = function(self, event, addon)
	if (event == "ADDON_LOADED") then
		if (addon ~= "Blizzard_ObjectiveTracker") then
			return
		end
		self:UnregisterEvent("ADDON_LOADED", "OnEvent")
	end

	local ObjectiveTrackerFrame = SetObjectScale(ObjectiveTrackerFrame, 1.1)
	ObjectiveTrackerFrame:SetHeight(480 / 1.1)
	ObjectiveTrackerFrame:SetAlpha(.9)
	ObjectiveTrackerFrame:ClearAllPoints()
	ObjectiveTrackerFrame:SetPoint("TOPRIGHT", MinimapCluster, "BOTTOMRIGHT")
	--ObjectiveTrackerFrame:SetMovable(true)
	--ObjectiveTrackerFrame:SetUserPlaced(true)
	ObjectiveTrackerFrame.IsUserPlaced = function() return true end

	ObjectiveTrackerUIWidgetContainer:SetFrameStrata("BACKGROUND")
	ObjectiveTrackerFrame:SetFrameStrata("BACKGROUND")

	hooksecurefunc("ObjectiveTracker_Update", UpdateObjectiveTracker)

	hooksecurefunc(QUEST_TRACKER_MODULE, "SetBlockHeader", UpdateQuestItem)
	hooksecurefunc(WORLD_QUEST_TRACKER_MODULE, "AddObjective", UpdateQuestItem)
	hooksecurefunc(CAMPAIGN_QUEST_TRACKER_MODULE, "AddObjective", UpdateQuestItem)

	hooksecurefunc(CAMPAIGN_QUEST_TRACKER_MODULE, "AddProgressBar", UpdateProgressBar)
	hooksecurefunc(QUEST_TRACKER_MODULE, "AddProgressBar", UpdateProgressBar)
	hooksecurefunc(DEFAULT_OBJECTIVE_TRACKER_MODULE, "AddProgressBar", UpdateProgressBar)
	hooksecurefunc(BONUS_OBJECTIVE_TRACKER_MODULE, "AddProgressBar", UpdateProgressBar)
	hooksecurefunc(WORLD_QUEST_TRACKER_MODULE, "AddProgressBar", UpdateProgressBar)
	hooksecurefunc(SCENARIO_TRACKER_MODULE, "AddProgressBar", UpdateProgressBar)

	local toggleButton = CreateFrame("Button", "DiabolicUI_ObjectiveTrackerToggleButton", UIParent, "SecureActionButtonTemplate")
	toggleButton:SetScript("OnClick", function()
		if (ObjectiveTrackerFrame:IsVisible()) then
			ObjectiveTrackerFrame:Hide()
		else
			ObjectiveTrackerFrame:Show()
		end
	end)
	SetOverrideBindingClick(toggleButton, true, "SHIFT-O", "DiabolicUI_ObjectiveTrackerToggleButton")

	self:InitializeAlphaDriver()

end

Tracker.InitializeWrathTracker = function(self)
	if (not ns.IsWrath) then
		return
	end

	--function WatchFrame_SetWidth(width)
	--	if ( width == "0" ) then
	--		WATCHFRAME_EXPANDEDWIDTH = 204;
	--		WATCHFRAME_MAXLINEWIDTH = 192;
	--	else
	--		WATCHFRAME_EXPANDEDWIDTH = 306;
	--		WATCHFRAME_MAXLINEWIDTH = 294;
	--	end
	--	if ( WatchFrame:IsShown() and not WatchFrame.collapsed ) then
	--		WatchFrame:SetWidth(WATCHFRAME_EXPANDEDWIDTH);
	--		WatchFrame_Update();
	--	end
	--end

	-- Does this taint?
	local locked
	hooksecurefunc(WatchFrame, "SetWidth", function()
		if (not locked) then
			locked = true
			-- Don't alter the width if the tracker is collapsed
			if (WatchFrame:IsShown() and not WatchFrame.collapsed) then
				WATCHFRAME_EXPANDEDWIDTH = 266
				WATCHFRAME_MAXLINEWIDTH = WATCHFRAME_EXPANDEDWIDTH - 12
				WatchFrame:SetWidth(WATCHFRAME_EXPANDEDWIDTH)
				WatchFrame_Update()
			end
			locked = nil
		end
	end)

	self:UpdateWrathTracker()
end

Tracker.UpdateWrathTracker = function(self)
	if (not ns.IsWrath) then
		return
	end

	SetObjectScale(WatchFrame, 1)

	WatchFrame:SetFrameStrata("LOW")
	WatchFrame:SetFrameLevel(50)
	WatchFrameTitle:SetFontObject(GetFont(15,true))

	WATCHFRAME_COLLAPSEDWIDTH = WatchFrameTitle:GetWidth() + 36

	if (WatchFrame:IsShown() and WatchFrame.collapsed) then
		WatchFrame:SetWidth(WATCHFRAME_COLLAPSEDWIDTH)
	end

	-- Style tracker fonts
	local UpdateWrathQuestLines = function()
		for i,line in pairs(WATCHFRAME_QUESTLINES) do
			UpdateWatchFrameLine(line)
		end
	end
	hooksecurefunc("WatchFrame_Update", UpdateWrathQuestLines)
	UpdateWrathQuestLines()

	-- Style quest buttons
	local i,item = 1,WatchFrameItem1
	while (item) do
		UpdateQuestItemButton(item)
		i = i + 1
		item = _G["WatchFrameItem" .. i]
	end

	hooksecurefunc("WatchFrameItem_OnShow", UpdateQuestItemButton)
end

Tracker.OnEvent = function(self, event, ...)
	if (event == "PLAYER_ENTERING_WORLD") then
		if (self.queueImmersionHook) then
			local frame = ImmersionFrame
			if (frame) then
				frame:HookScript("OnShow", ObjectiveAlphaDriver.Update)
				frame:HookScript("OnHide", ObjectiveAlphaDriver.Update)
				self.queueImmersionHook = nil
			end
		end
		ObjectiveAlphaDriver:Update()
		if (ns.IsWrath) then
			self:UpdateWrathTracker()
		end
	elseif (event == "VARIABLES_LOADED") then
		if (ns.IsWrath) then
			self:UpdateWrathTracker()
		end
	end
end

Tracker.OnInitialize = function(self)
	self.queueImmersionHook = IsAddOnEnabled("Immersion")

	if (ns.IsWrath) then
		self:InitializeWrathTracker()
		self:RegisterEvent("VARIABLES_LOADED", "OnEvent")
	else
		if (IsAddOnLoaded("Blizzard_ObjectiveTracker")) then
			self:InitializeTracker()
		else
			self:RegisterEvent("ADDON_LOADED", "InitializeTracker")
		end
	end

	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
end