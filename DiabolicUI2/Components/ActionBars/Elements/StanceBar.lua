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
		local bar = SetObjectScale(ns.StanceBar:Create(ns.Prefix.."StanceBar", UIParent))
		bar:Hide()
		bar:SetFrameStrata("MEDIUM")
		bar.customVisibilityDriver = "[petbattle][possessbar][overridebar][vehicleui][target=vehicle,exists]hide"

		bar.UpdateBackdrop = function(self)
		end

		local button
		for id = 1,10 do
			button = bar:CreateButton(id, bar:GetName().."Button"..id)
			button:SetPoint("BOTTOMLEFT", (id-1)*(54), 0)
			bar:SetFrameRef("Button"..id, button)
			style(button)
		end
		bar:UpdateVisibilityDriver()

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
				bar:SetWidth(numButtons*54 + (numButtons-1));
				bar:SetHeight(54);
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
		--backdrop:SetTexture(GetMedia("plus"))
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
		if (not InCombatLockdown()) then
			if (self.updateStateOnCombatLeave) then
				self.updateStateOnCombatLeave = nil
				self:UpdateStanceButtons()
			end
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

	self:UpdateToggleButton()
	ns.RegisterCallback(self, "ActionBars_SecondaryBar_Updated", "UpdateToggleButton")

end
