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
local KeyBound = LibStub("LibKeyBound-1.0")

-- WoW API
local CreateFrame = CreateFrame
local GetNumShapeshiftForms = GetNumShapeshiftForms
local InCombatLockdown = InCombatLockdown
local PlaySound = PlaySound

-- Addon API
local Colors = ns.Colors
local GetFont = ns.API.GetFont
local GetMedia = ns.API.GetMedia
local RegisterCooldown = ns.Widgets.RegisterCooldown
local SetObjectScale = ns.API.SetObjectScale
local UIHider = ns.Hider
local noop = ns.Noop

local buttonOnEnter = function(self)
	self.icon.darken:SetAlpha(0)
	if (self.OnEnter) then
		self:OnEnter()
	end
end

local buttonOnLeave = function(self)
	self.icon.darken:SetAlpha(.1)
	if (self.OnLeave) then
		self:OnLeave()
	end
end

local iconPostSetShown = function(self, isShown)
	self.desaturator:SetShown(isShown)
end

local iconPostShow = function(self)
	self.desaturator:Show()
end

local iconPostHide = function(self)
	self.desaturator:Hide()
end

local iconPostSetAlpha = function(self, alpha)
	self.desaturator:SetAlpha(self.desaturator.alpha or .2)
end

local iconPostSetVertexColor = function(self, r, g, b, a)
	self.desaturator:SetVertexColor(r, g, b)
end

local iconPostSetTexture = function(self, ...)
	self.desaturator:SetTexture(...)
	self.desaturator:SetDesaturated(true)
	local r, g, b = self:GetVertexColor() -- can return nil in WoW10
	if (r and g and b) then
		if (not r or not g or not b) then
			r, g, b = 1, 1, 1
		end
		self.desaturator:SetVertexColor(r, g, b)
	end
	self.desaturator:SetAlpha(self.desaturator.alpha or .2)
end

local handleOnClick = function(self)
	if (self.bar:IsShown()) then
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON, "SFX")
	else
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF, "SFX")
	end
end

local handleOnEnter = function(self)
	self:SetAlpha(1)
end

local handleOnLeave = function(self)
	if (self.bar:IsShown()) then
		self:SetAlpha(0)
	end
end

local handleUpdateAlpha = function(self)
	if (self:IsMouseOver(10,-10,-10,10)) then
		self:OnEnter()
	else
		self:OnLeave()
	end
end

local style = function(button)

	button.autoCastShine:SetParent(UIHider)
	button.border:SetParent(UIHider)
	button.newActionTexture:SetParent(UIHider)
	button.normalTexture:SetParent(UIHider)
	button.spellHighlightAnim:Stop()
	button.spellHighlightTexture:SetParent(UIHider)

	if (button.QuickKeybindHighlightTexture) then
		button.QuickKeybindHighlightTexture:SetParent(UIHider)
	end

	if (ns.WoW10) then
		button.checkedTexture:SetParent(UIHider)
		button.highlightTexture:SetParent(UIHider)
		button.bottomDivider:SetParent(UIHider)
		button.rightDivider:SetParent(UIHider)
		button.slotArt:SetParent(UIHider)
		button.slotBackground:SetParent(UIHider)
	end

	button:SetSize(51,51)

	button.backdrop = button:CreateTexture(nil, "BACKGROUND", nil, -7)
	button.backdrop:SetSize(64,64)
	button.backdrop:SetPoint("CENTER")
	button.backdrop:SetTexture(GetMedia("button-big"))

	button.overlay = CreateFrame("Frame", nil, button)
	button.overlay:SetFrameLevel(button:GetFrameLevel() + 2)
	button.overlay:SetAllPoints()

	button.icon:SetDrawLayer("BACKGROUND", 1)
	button.icon:ClearAllPoints()
	button.icon:SetPoint("TOPLEFT", 3, -3)
	button.icon:SetPoint("BOTTOMRIGHT", -3, 3)
	button.icon:SetMask(GetMedia("actionbutton-mask-square-rounded"))

	button.icon.desaturator = button:CreateTexture(nil, "BACKGROUND", nil, 2)
	button.icon.desaturator:SetShown(button.icon:IsShown())
	button.icon.desaturator:SetAllPoints(button.icon)
	button.icon.desaturator:SetMask(GetMedia("actionbutton-mask-square-rounded"))
	button.icon.desaturator:SetTexture(button.icon:GetTexture())
	button.icon.desaturator:SetDesaturated(true)
	button.icon.desaturator:SetVertexColor(button.icon:GetVertexColor())
	button.icon.desaturator:SetAlpha(.2)
	button.icon.desaturator.alpha = .2

	button.icon.darken = button:CreateTexture(nil, "BACKGROUND", nil, 3)
	button.icon.darken:SetAllPoints(button.icon)
	button.icon.darken:SetTexture(GetMedia("actionbutton-mask-square-rounded"))
	button.icon.darken:SetVertexColor(0, 0, 0, .1)

	button.pushedTexture = button:CreateTexture(nil, "ARTWORK", nil, 1)
	button.pushedTexture:SetVertexColor(1, 1, 1, .05)
	button.pushedTexture:SetTexture(GetMedia("actionbutton-mask-square-rounded"))
	button.pushedTexture:SetAllPoints(button.icon)

	button.spellHighlight = button.overlay:CreateTexture(nil, "ARTWORK", nil, -7)
	button.spellHighlight:SetTexture(GetMedia("actionbutton-spellhighlight-square-rounded"))
	button.spellHighlight:SetSize(92,92)
	button.spellHighlight:SetPoint("CENTER", 0, 0)
	button.spellHighlight:Hide()

	button.cooldown:ClearAllPoints()
	button.cooldown:SetAllPoints(button.icon)
	button.cooldown:SetReverse(false)
	button.cooldown:SetSwipeTexture(GetMedia("actionbutton-mask-square-rounded"))
	button.cooldown:SetDrawSwipe(true)
	button.cooldown:SetBlingTexture(GetMedia("blank"), 0, 0, 0, 0)
	button.cooldown:SetDrawBling(false)
	button.cooldown:SetEdgeTexture(GetMedia("blank"))
	button.cooldown:SetDrawEdge(false)
	button.cooldown:SetHideCountdownNumbers(true)

	button.cooldownCount = button.overlay:CreateFontString()
	button.cooldownCount:SetDrawLayer("ARTWORK", 1)
	button.cooldownCount:SetPoint("CENTER", 1, 0)
	button.cooldownCount:SetFontObject(GetFont(16,true))
	button.cooldownCount:SetJustifyH("CENTER")
	button.cooldownCount:SetJustifyV("MIDDLE")
	button.cooldownCount:SetShadowOffset(0, 0)
	button.cooldownCount:SetShadowColor(0, 0, 0, 0)
	button.cooldownCount:SetTextColor(250/255, 250/255, 250/255, .85)

	button.count:SetParent(button.overlay)
	button.count:ClearAllPoints()
	button.count:SetPoint("BOTTOMRIGHT", 0, 2)
	button.count:SetFontObject(GetFont(14,true))

	button.hotkey:SetParent(button.overlay)
	button.hotkey:ClearAllPoints()
	button.hotkey:SetPoint("TOPRIGHT", 0, -3)
	button.hotkey:SetFontObject(GetFont(12,true))
	button.hotkey:SetTextColor(.75, .75, .75)

	button.macro:SetParent(button.overlay)
	button.macro:ClearAllPoints()
	button.macro:SetPoint("BOTTOMLEFT", 0, 2)
	button.macro:SetFontObject(GetFont(12,true))
	button.macro:SetTextColor(.75, .75, .75)

	button.flash:SetDrawLayer("ARTWORK", 2)
	button.flash:SetAllPoints(button.icon)
	button.flash:SetVertexColor(1, 0, 0, .25)
	button.flash:SetTexture(GetMedia("actionbutton-mask-square-rounded"))
	button.flash:Hide()

	button:SetNormalTexture("")
	button:SetHighlightTexture("")
	button:SetCheckedTexture("")
	button:SetPushedTexture(button.pushedTexture)
	button:GetPushedTexture():SetBlendMode("ADD")
	button:GetPushedTexture():SetDrawLayer("ARTWORK", 1)
	button:SetScript("OnEnter", buttonOnEnter)
	button:SetScript("OnLeave", buttonOnLeave)

	hooksecurefunc(button.icon, "SetShown",iconPostSetShown)
	hooksecurefunc(button.icon, "Show", iconPostShow)
	hooksecurefunc(button.icon, "Hide", iconPostHide)
	hooksecurefunc(button.icon, "SetAlpha", iconPostSetAlpha)
	hooksecurefunc(button.icon, "SetVertexColor", iconPostSetVertexColor)
	hooksecurefunc(button.icon, "SetTexture", iconPostSetTexture)

	RegisterCooldown(button.cooldown, button.cooldownCount)

	button.AddToButtonFacade = noop
	button.AddToMasque = noop
	button.SetNormalTexture = noop
	button.SetHighlightTexture = noop
	button.SetCheckedTexture = noop

	return button
end

StanceBar.SpawnBar = function(self)
	if (not self.Bar) then

		-- Create stance bar
		local scale = .8
		local bar = SetObjectScale(ns.StanceBar:Create(ns.Prefix.."StanceBar", UIParent), scale)
		bar:SetFrameStrata("BACKGROUND")
		bar:SetFrameLevel(1)
		bar:SetHeight(54)
		bar.scale = scale

		-- Create the stance buttons
		local button
		for id = 1,10 do
			button = bar:CreateButton(id, bar:GetName().."Button"..id)
			button:SetPoint("BOTTOMLEFT", (id-1)*(54), 0)
			bar:SetFrameRef("Button"..id, button)
			style(button)
		end

		-- Lua callback to update saved settings
		bar.UpdateSettings = function(self)
			ns.db.char.actionbars.enableStanceBar = self:GetAttribute("enableStanceBar")
			ns.db.char.actionbars.preferPetOrStanceBar = self:GetAttribute("preferPetOrStanceBar")
		end

		-- Store saved settings as bar attributes
		bar:SetAttribute("enableStanceBar", ns.db.char.actionbars.enableStanceBar)
		bar:SetAttribute("preferPetOrStanceBar", ns.db.char.actionbars.preferPetOrStanceBar)

		-- Environment callback to signal pet bar visibility changes.
		local onVisibility = function(self) ns:Fire("ActionBars_StanceBar_Updated", self:IsShown() and true or false) end
		bar:HookScript("OnHide", onVisibility)
		bar:HookScript("OnShow", onVisibility)

		-- Create pull-out handle
		local handle = SetObjectScale(CreateFrame("CheckButton", bar:GetName().."Handle", UIParent, "SecureHandlerClickTemplate"))
		handle:SetSize(64,12)
		handle:SetFrameStrata("MEDIUM")
		handle:RegisterForClicks("AnyUp")
		handle.bar = bar

		local texture = handle:CreateTexture()
		texture:SetColorTexture(.5, 0, 0, .5)
		texture:SetAllPoints()
		handle.texture = texture

		handle.OnEnter = handleOnEnter
		handle.OnLeave = handleOnLeave
		handle.UpdateAlpha = handleUpdateAlpha
		handle:HookScript("OnClick", handleOnClick)
		handle:SetScript("OnEnter", handleOnEnter)
		handle:SetScript("OnLeave", handleOnLeave)

		-- Handle onclick handler triggering visibility changes
		-- for both the the stance bar and the pet bar, if it exists.
		handle:SetAttribute("_onclick", [[

			-- Retrieve and update the visibility setting
			local bar = self:GetFrameRef("Bar");
			local enableStanceBar = not bar:GetAttribute("enableStanceBar")

			-- Handle pet bar visibility, if it exists
			local pet = self:GetFrameRef("PetBar");
			if (pet) then

				-- If pet bar should be shown,
				-- we need to handle the pet bar.
				if (enableStanceBar) then

					-- Check if the pet bar is currently shown
					if (pet:GetAttribute("enablePetBar")) then

						-- Create a temporary setting to restore
						-- the pet if we close the stance bar.
						-- This is saved through sessions.
						bar:SetAttribute("restorePetOrStanceBar", "pet");
						pet:SetAttribute("restorePetOrStanceBar", "pet");

						-- Disable the saved setting to show the pet bar
						pet:SetAttribute("enablePetBar", false);

						-- Save stance bar settings in lua
						pet:CallMethod("UpdateSettings");

						-- Update pet bar visibility driver
						pet:RunAttribute("UpdateVisibility");

					else

						-- Stance bar was not enabled when closed, so we clear this setting.
						bar:SetAttribute("restorePetOrStanceBar", false);
						pet:SetAttribute("restorePetOrStanceBar", false);

						-- Save pet bar settings in lua
						pet:CallMethod("UpdateSettings");
					end

				else

					-- Check if the pet bar was previously shown
					if (bar:GetAttribute("restorePetOrStanceBar") == "pet") then

						-- Restore the pet bar's saved visibility setting
						pet:SetAttribute("enablePetBar", true);

						-- Save pet bar settings in lua
						pet:CallMethod("UpdateSettings");

						-- Update the pet bar's visibility driver
						pet:RunAttribute("UpdateVisibility");
					end

					-- Whether or not the pet bar was previously shown,
					-- this setting is no longer needed.
					bar:SetAttribute("restorePetOrStanceBar", false);
					pet:SetAttribute("restorePetOrStanceBar", false);
				end
			end

			-- Update the stance bar's saved visibility setting
			bar:SetAttribute("enableStanceBar", enableStanceBar);

			-- Save stance bar settings in lua
			bar:CallMethod("UpdateSettings");

			-- Update the stance bar's visibility driver
			bar:RunAttribute("UpdateVisibility");
		]])

		-- Handle visibility updater
		-- This is where the actualy visibility driver is applied.
		-- Can't rely only on macros, since we don't always have stances.
		handle:SetAttribute("UpdateVisibility", [[
			local bar = self:GetFrameRef("Bar");
			local driver = bar:GetAttribute("visibility-driver");
			local newstate = SecureCmdOptionParse(driver);
			local numButtons = bar:GetAttribute("numButtons");
			UnregisterStateDriver(self, "visibility");
			if (numButtons and numButtons > 0 and newstate == "show") then
				RegisterStateDriver(self, "visibility", driver);
			else
				RegisterStateDriver(self, "visibility", "hide");
			end
		]])

		-- Handle position updater
		-- Triggered by the bar's UpdateVisibility attribute
		handle:SetAttribute("UpdatePosition", [[
			self:ClearAllPoints();
			local bar = self:GetFrameRef("Bar");
			if (bar:IsShown()) then
				self:SetPoint("BOTTOM", bar, "TOP", 0, 2);
			else
				self:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -40, 0);
			end
			self:RunAttribute("UpdateVisibility");
			self:CallMethod("UpdateAlpha");
		]])

		-- The handle's state handler reacting to visibility driver suggestions.
		handle:SetAttribute("_onstate-vis", [[
			if not newstate then return end
			self:RunAttribute("UpdateVisibility");
		]])

		-- Custom visibility updater
		-- Also triggers handle position change
		bar:SetAttribute("UpdateVisibility", [[
			local driver = self:GetAttribute("visibility-driver");
			if not driver then return end
			local newstate = SecureCmdOptionParse(driver);
			local enabled = self:GetAttribute("enableStanceBar");
			-- Count number of buttons
			local numButtons = 0;
			local button;
			for i = 1,10 do
				button = self:GetFrameRef("Button"..i);
				if (button:IsShown()) then
					numButtons = numButtons + 1;
				end
			end
			self:SetAttribute("numButtons", numButtons);
			-- Adjust bar size to button count
			if (numButtons > 0) then
				self:SetWidth(numButtons*54 + (numButtons-1));
				self:SetHeight(54);
			else
				self:SetWidth(2);
				self:SetHeight(2);
			end
			-- Toggle bar visibility
			if (enabled and newstate == "show") then
				self:Show();
				--local point, anchor, rpoint, x, y = self:GetPoint();
				--self:SetPoint(point, anchor, rpoint, x, y);
			else
				self:Hide();
			end
			-- Run handle's visibility update
			local handle = self:GetFrameRef("Handle");
			handle:RunAttribute("UpdatePosition");
		]])

		-- State handler reacting to visibility driver updates.
		bar:SetAttribute("_onstate-vis", [[
			if not newstate then return end
			self:RunAttribute("UpdateVisibility");
		]])

		-- Cross reference the bar and its handle
		bar:SetFrameRef("Handle", handle)
		handle:SetFrameRef("Bar", bar)

		-- Run once to initially set the bar's visibility-driver
		--bar:Enable()

		-- Adopt the same baseline visibility driver for the handle as for its bar.
		-- Note that this doesn't directly affect visibility, it merely suggests
		-- as the actual visibility also relies on whether stances exist.
		--RegisterStateDriver(handle, "vis", bar:GetAttribute("visibility-driver"))

		self.Bar = bar
		self.Bar.Handle = handle

	end

	self:UpdatePosition()
end

StanceBar.ForAll = function(self, method, ...)
	if (self.Bar) then
		self.Bar:ForAll(method, ...)
	end
end

StanceBar.GetAll = function(self)
	if (self.Bar) then
		return self.Bar:GetAll()
	end
end

StanceBar.UpdateBindings = function(self)
	if (self.Bar) then
		self.Bar:UpdateBindings()
	end
end

StanceBar.UpdatePosition = function(self)
	if (not self.Bar) then
		return
	end
	self.Bar:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOM", 380, (84 + ActionBars:GetBarOffset()) / self.Bar.scale)
end

StanceBar.UpdateStanceButtons = function(self)
	if (InCombatLockdown()) then
		self.updateStateOnCombatLeave = true
		return self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
	end
	if (self.Bar) then
		self.Bar:UpdateButtons()
		self.Bar:Execute([[ self:RunAttribute("UpdateVisibility"); ]])
		local numStances = GetNumShapeshiftForms()
		if (numStances and numStances > 0) then
			self.Bar.Handle:Show()
		else
			self.Bar.Handle:Hide()
		end
	end
end

StanceBar.OnEvent = function(self, event, ...)
	if (event == "UPDATE_SHAPESHIFT_COOLDOWN") then
		self:ForAll("Update")

	elseif (event == "PLAYER_REGEN_ENABLED") then
		if (not InCombatLockdown()) then
			self:UnregisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
			if (self.updateStateOnCombatLeave) then
				self.updateStateOnCombatLeave = nil
				self:UpdateStanceButtons()
			end
		end
	else
		if (event == "PLAYER_ENTERING_WORLD") then
			local isInitialLogin, isReloadingUi = ...
			if (isInitialLogin or isReloadingUi) then
				local PetBar = ActionBars:GetModule("PetBar", true)
				if (PetBar and PetBar.Bar) then
					self.Bar:SetFrameRef("PetBar", PetBar.Bar)
				end
				self.Bar:Enable()
			end
		end
		self:ForAll("Update")
		self:UpdateStanceButtons()
	end
end

StanceBar.OnInitialize = function(self)
	if (not ns.db.global.core.enableDevelopmentMode or not ns.IsDevelopment) then
		self:Disable()
		return
	end
	self:SpawnBar()
end

StanceBar.OnEnable = function(self)

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
	self:UpdateBindings()

	ns.RegisterCallback(self, "ActionBars_Artwork_Updated", "UpdatePosition")

end
