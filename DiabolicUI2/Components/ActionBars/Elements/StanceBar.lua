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
local StanceBar = ActionBars:NewModule("StanceBar", "LibMoreEvents-1.0")

-- Lua API
local pairs = pairs
local setmetatable = setmetatable
local string_format = string.format

-- WoW API
local ClearOverrideBindings = ClearOverrideBindings
local CreateFrame = CreateFrame
local GetBindingKey = GetBindingKey
local GetNumShapeshiftForms = GetNumShapeshiftForms
local InCombatLockdown = InCombatLockdown
local PlaySound = PlaySound
local SetOverrideBindingClick = SetOverrideBindingClick

-- Addon API
local GetFont = ns.API.GetFont
local GetMedia = ns.API.GetMedia
local SetObjectScale = ns.API.SetObjectScale

local Bar = {}

Bar.UpdateBackdrop = function(self)
end

StanceBar.Create = function(self)
	if (not self.Bar) then
		local bar = SetObjectScale(ns.StanceBar:Create(ns.Prefix.."StanceBar", UIParent))
		bar:Hide()
		bar:SetFrameStrata("MEDIUM")

		-- Embed our custom methods.
		for method,func in pairs(Bar) do
			bar[method] = func
		end

		local button
		for i = 1,10 do
			button = bar:CreateButton(i, ActionBars:GetStyle("StanceButton"))
			button:SetPoint("BOTTOMLEFT", (i-1)*(54), 0)
			bar:SetFrameRef("Button"..i, button)
		end
		bar:UpdateStates()

		local button = SetObjectScale(CreateFrame("CheckButton", nil, UIParent, "SecureHandlerClickTemplate"))
		button:SetFrameRef("StanceBar", bar)
		button:RegisterForClicks("AnyUp")
		button:SetAttribute("_onclick", [[
			local bar = self:GetFrameRef("StanceBar");
			bar:UnregisterAutoHide();
			bar:Show();

			local button;
			local numButtons = 0;
			for i = 1,10 do
				button = bar:GetFrameRef("Button"..i);
				if (button:IsShown()) then
					numButtons = numButtons + 1;
				end
			end
			if (numButtons > 0) then
				bar:SetWidth(numButtons*53 + (numButtons-1));
				bar:SetHeight(53);
			else
				bar:SetWidth(2);
				bar:SetHeight(2);
			end
			bar:CallMethod("UpdateBackdrop");

			bar:RegisterAutoHide(.75);
			bar:AddToAutoHide(self);

			for i = 1,numButtons do
				button = bar:GetFrameRef("Button"..i);
				if (button:IsShown()) then
					bar:AddToAutoHide(button);
				end
			end
		]])

		button:SetSize(32,32)
		bar:SetPoint("BOTTOM", button, "TOP", 0, 4)

		local backdrop = button:CreateTexture(nil, "BACKGROUND", nil, -7)
		backdrop:SetSize(32,32)
		backdrop:SetPoint("CENTER")
		backdrop:SetTexture(GetMedia("plus"))
		button.Backdrop = backdrop

		-- Called after secure click handler, I think.
		button:HookScript("OnClick", function()
			if (bar:IsShown()) then
				PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON, "SFX")
			else
				PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF, "SFX")
			end
		end)

		button:HookScript("OnEnter", function(self)
		end)

		button:HookScript("OnLeave", function(self)
		end)

		self.Bar = bar
		self.ToggleButton = button

	end
end

StanceBar.ForAll = function(self, method, ...)
	if (self.Bar) then
		self.Bar:ForAll(method, ...)
	end
end

StanceBar.UpdateBindings = function(self)
	if (self.Bar) then
		self.Bar:UpdateBindings()
	end
end

StanceBar.UpdateStanceButtons = function(self)
	if (InCombatLockdown()) then
		self.updateStateOnCombatLeave = true
		return
	end
	if (self.Bar) then
		self.Bar:UpdateButtons()
		local numStances = GetNumShapeshiftForms()
		if (numStances and numStances > 0) then
			self.ToggleButton:Show()
		else
			self.ToggleButton:Hide()
		end
	end
end

StanceBar.UpdateToggleButton = function(self)
	if (not self.ToggleButton) then
		return
	end
	if (ActionBars:HasSecondaryBar()) then
		self.ToggleButton:SetPoint("BOTTOM", 0, 70 + 100)
	else
		self.ToggleButton:SetPoint("BOTTOM", 0, 11 + 100)
	end
end

StanceBar.OnEvent = function(self, event, ...)
	if (event == "UPDATE_SHAPESHIFT_COOLDOWN") then
		self:ForAll("Update")

	elseif (event == "PLAYER_REGEN_ENABLED") then
		if (self.updateStateOnCombatLeave) and (not InCombatLockdown()) then
			self.updateStateOnCombatLeave = nil
			self:UpdateStanceButtons()
		end
	else
		if (event == "PLAYER_ENTERING_WORLD") then
			if (self.Bar) then
				self.Bar:Hide()
			end
			self:UpdateStanceButtons()
			self:UpdateToggleButton()
			return
		end
		if (InCombatLockdown()) then
			self.updateStateOnCombatLeave = true
			self:ForAll("Update")
		else
			self:UpdateStanceButtons()
		end
	end
end

StanceBar.OnInitialize = function(self)
	-- Just not going to allow this yet, not in any version.
	if (not ns.db.global.core.enableDevelopmentMode) or (true) then
		self:Disable()
		return
	end
	self:Create()
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
	self:RegisterEvent("UPDATE_BONUS_ACTIONBAR", "OnEvent")
	self:RegisterEvent("ACTIONBAR_PAGE_CHANGED", "OnEvent")
	self:RegisterEvent("UPDATE_SHAPESHIFT_FORM", "OnEvent")
	self:RegisterEvent("UPDATE_SHAPESHIFT_FORMS", "OnEvent")
	self:RegisterEvent("UPDATE_SHAPESHIFT_USABLE", "OnEvent")
	self:RegisterEvent("UPDATE_SHAPESHIFT_COOLDOWN", "OnEvent")
	self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
	self:RegisterEvent("UPDATE_VEHICLE_ACTIONBAR", "OnEvent")
	self:RegisterEvent("UPDATE_OVERRIDE_ACTIONBAR", "OnEvent")
	self:RegisterEvent("UPDATE_POSSESS_BAR", "OnEvent")
	self:RegisterEvent("UPDATE_BINDINGS", "UpdateBindings")
	ns.RegisterCallback(self, "ActionBars_SecondaryBar_Updated", "UpdateToggleButton")
end

StanceBar.OnEnable = function(self)
	self:UpdateBindings()
	self:UpdateToggleButton()
end
