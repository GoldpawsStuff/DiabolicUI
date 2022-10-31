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
	if (self:IsMouseOver(20, 0, -20, 20)) then
		self:OnEnter()
	else
		self:OnLeave()
	end
end

local style = function(button)

	-- Clean up the button template
	for _,i in next,{ "AutoCastShine", "Border", "Name", "NewActionTexture", "NormalTexture", "SpellHighlightAnim", "SpellHighlightTexture",
		--[[ WoW10 ]] "CheckedTexture", "HighlightTexture", "BottomDivider", "RightDivider", "SlotArt", "SlotBackground" } do
		if (button[i] and button[i].Stop) then button[i]:Stop() elseif button[i] then button[i]:SetParent(UIHider) end
	end

	_G[button:GetName().."NormalTexture2"]:SetParent(UIHider)

	local m = GetMedia("actionbutton-mask-square-rounded")
	local b = GetMedia("blank")

	button:SetAttribute("buttonLock", true)
	button:SetSize(53,53)
	button:SetNormalTexture(nil)
	button:SetHighlightTexture(nil)
	button:SetCheckedTexture(nil)

	-- Custom slot texture
	local backdrop = button:CreateTexture(nil, "BACKGROUND", nil, -7)
	backdrop:SetSize(64,64)
	backdrop:SetPoint("CENTER")
	backdrop:SetTexture(GetMedia("button-big"))
	button.backdrop = backdrop

	-- Icon
	local icon = button.icon
	icon:SetDrawLayer("BACKGROUND", 1)
	icon:ClearAllPoints()
	icon:SetPoint("TOPLEFT", 3, -3)
	icon:SetPoint("BOTTOMRIGHT", -3, 3)
	if (ns.IsRetail) then icon:RemoveMaskTexture(button.IconMask) end
	icon:SetMask(m)

	-- Custom icon darkener
	local darken = button:CreateTexture(nil, "BACKGROUND", nil, 2)
	darken:SetAllPoints(button.icon)
	darken:SetTexture(m)
	darken:SetVertexColor(0, 0, 0, .1)
	button.icon.darken = darken

	button:SetScript("OnEnter", buttonOnEnter)
	button:SetScript("OnLeave", buttonOnLeave)

	-- Button is pushed
	-- Responds to mouse and keybinds
	-- if we allow blizzard to handle it.
	local pushedTexture = button:CreateTexture(nil, "ARTWORK", nil, 1)
	pushedTexture:SetVertexColor(1, 1, 1, .05)
	pushedTexture:SetTexture(m)
	pushedTexture:SetAllPoints(button.icon)
	button.PushedTexture = pushedTexture

	button:SetPushedTexture(button.PushedTexture)
	button:GetPushedTexture():SetBlendMode("ADD")
	button:GetPushedTexture():SetDrawLayer("ARTWORK", 1)

	-- Autoattack flash
	local flash = button.Flash
	flash:SetDrawLayer("ARTWORK", 2)
	flash:SetAllPoints(icon)
	flash:SetVertexColor(1, 0, 0, .25)
	flash:SetTexture(m)
	flash:Hide()

	-- Button cooldown frame
	local cooldown = button.cooldown
	cooldown:SetFrameLevel(button:GetFrameLevel() + 1)
	cooldown:ClearAllPoints()
	cooldown:SetAllPoints(button.icon)
	cooldown:SetReverse(false)
	cooldown:SetSwipeTexture(m)
	cooldown:SetDrawSwipe(true)
	cooldown:SetBlingTexture(b, 0, 0, 0, 0)
	cooldown:SetDrawBling(false)
	cooldown:SetEdgeTexture(b)
	cooldown:SetDrawEdge(false)
	cooldown:SetHideCountdownNumbers(true)

	-- Custom overlay frame
	local overlay = CreateFrame("Frame", nil, button)
	overlay:SetFrameLevel(button:GetFrameLevel() + 3)
	overlay:SetAllPoints()
	button.overlay = overlay

	-- Custom spell highlight
	local spellHighlight = overlay:CreateTexture(nil, "ARTWORK", nil, -7)
	spellHighlight:SetTexture(GetMedia("actionbutton-spellhighlight-square-rounded"))
	spellHighlight:SetSize(92,92)
	spellHighlight:SetPoint("CENTER", 0, 0)
	spellHighlight:Hide()
	button.spellHighlight = spellHighlight

	-- Custom cooldown count
	local cooldownCount = overlay:CreateFontString(nil, "ARTWORK", nil, 1)
	cooldownCount:SetPoint("CENTER", 1, 0)
	cooldownCount:SetFontObject(GetFont(16,true))
	cooldownCount:SetJustifyH("CENTER")
	cooldownCount:SetJustifyV("MIDDLE")
	cooldownCount:SetShadowOffset(0, 0)
	cooldownCount:SetShadowColor(0, 0, 0, 0)
	cooldownCount:SetTextColor(250/255, 250/255, 250/255, .85)
	button.cooldownCount = cooldownCount

	-- Macro name
	local name = button.Name
	name:SetParent(overlay)
	name:SetDrawLayer("OVERLAY", -1)
	name:ClearAllPoints()
	name:SetPoint("BOTTOMLEFT", 0, 2)
	name:SetFontObject(GetFont(12,true))
	name:SetTextColor(.75, .75, .75)

	-- Button charge/stack count
	local count = button.Count
	count:SetParent(overlay)
	count:SetDrawLayer("OVERLAY", 1)
	count:ClearAllPoints()
	count:SetPoint("BOTTOMRIGHT", 0, 2)
	count:SetFontObject(GetFont(14,true))

	-- Button keybind
	local hotkey = button.HotKey
	hotkey:SetParent(overlay)
	hotkey:SetDrawLayer("OVERLAY", 1)
	hotkey:ClearAllPoints()
	hotkey:SetPoint("TOPRIGHT", 0, -3)
	hotkey:SetFontObject(GetFont(12,true))
	hotkey:SetTextColor(.75, .75, .75)

	RegisterCooldown(button.cooldown, button.cooldownCount)

	hooksecurefunc(cooldown, "SetSwipeTexture", function(c,t) if t ~= m then c:SetSwipeTexture(m) end end)
	hooksecurefunc(cooldown, "SetBlingTexture", function(c,t) if t ~= b then c:SetBlingTexture(b,0,0,0,0) end end)
	hooksecurefunc(cooldown, "SetEdgeTexture", function(c,t) if t ~= b then c:SetEdgeTexture(b) end end)
	hooksecurefunc(cooldown, "SetSwipeColor", function(c,r,g,b,a) if not a or a>.8 then c:SetSwipeColor(r,g,b,.75) end end)
	hooksecurefunc(cooldown, "SetDrawSwipe", function(c,h) if not h then c:SetDrawSwipe(true) end end)
	hooksecurefunc(cooldown, "SetDrawBling", function(c,h) if h then c:SetDrawBling(false) end end)
	hooksecurefunc(cooldown, "SetDrawEdge", function(c,h) if h then c:SetDrawEdge(false) end end)
	hooksecurefunc(cooldown, "SetHideCountdownNumbers", function(c,h) if not h then c:SetHideCountdownNumbers(true) end end)

	if (not ns.IsRetail) then
		hooksecurefunc(button, "SetNormalTexture", function(b,...) if(...)then b:SetNormalTexture(nil) end end)
		hooksecurefunc(button, "SetHighlightTexture", function(b,...) if(...)then b:SetHighlightTexture(nil) end end)
		hooksecurefunc(button, "SetCheckedTexture", function(b,...) if(...)then b:SetCheckedTexture(nil) end end)
	end

	-- Disable masque for our buttons,
	-- they are not compatible.
	button.AddToMasque = noop
	button.AddToButtonFacade = noop
	button.LBFSkinned = nil
	button.MasqueSkinned = nil

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
		handle:SetHitRectInsets(-20, -20, -20, 0)
		handle:HookScript("OnClick", handleOnClick)
		handle:SetScript("OnEnter", handleOnEnter)
		handle:SetScript("OnLeave", handleOnLeave)
		handle.OnEnter = handleOnEnter
		handle.OnLeave = handleOnLeave
		handle.UpdateAlpha = handleUpdateAlpha
		handle.bar = bar

		local texture = handle:CreateTexture()
		texture:SetColorTexture(.5, 0, 0, .5)
		texture:SetAllPoints()
		handle.texture = texture

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
	if (not ns.db.global.core.enableDevelopmentMode) then
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
