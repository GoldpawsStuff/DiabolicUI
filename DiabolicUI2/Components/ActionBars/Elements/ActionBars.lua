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
local Bars = ActionBars:NewModule("Bars", "LibMoreEvents-1.0", "AceConsole-3.0")

-- Lua API
local math_floor = math.floor
local pairs = pairs
local select = select
local string_format = string.format
local tonumber = tonumber

-- WoW API
local CreateFrame = CreateFrame
local GetBindingKey = GetBindingKey
local InCombatLockdown = InCombatLockdown
local PetDismiss = PetDismiss
local RegisterStateDriver = RegisterStateDriver
local UnitExists = UnitExists
local VehicleExit = VehicleExit

-- Addon API
local GetMedia = ns.API.GetMedia
local SetObjectScale = ns.API.SetObjectScale

-- Constants
local _,playerClass = UnitClass("player")
local BOTTOMLEFT_ACTIONBAR_PAGE = BOTTOMLEFT_ACTIONBAR_PAGE
local BOTTOMRIGHT_ACTIONBAR_PAGE = BOTTOMRIGHT_ACTIONBAR_PAGE
local RIGHT_ACTIONBAR_PAGE = RIGHT_ACTIONBAR_PAGE
local LEFT_ACTIONBAR_PAGE = LEFT_ACTIONBAR_PAGE

Bars.SpawnBars = function(self)
	if (not self.Bars) then
		self.Bars = {}
	end

	-- Primary ActionBar
	-------------------------------------------------------
	local bar = SetObjectScale(ns.ActionBar:Create(1, ns.Prefix.."ActionBar1", UIParent))
	bar:SetPoint("BOTTOM", -1, 11)
	bar:SetSize(647, 53)

	local exitButton = {
		func = function(button)
			if (UnitExists("vehicle")) then
				VehicleExit()
			else
				PetDismiss()
			end
		end,
		tooltip = _G.LEAVE_VEHICLE,
		texture = (ns.IsClassic or ns.IsTBC) and [[Interface\Icons\Spell_Shadow_SacrificialShield]]
			   or (ns.IsWrath) and [[Interface\Icons\achievement_bg_kill_carrier_opposing_flagroom]]
			   or [[Interface\Icons\INV_Pet_ExitBattle]]
	}

	for i = 1,12 do
		local button = bar:CreateButton(i)
		button:SetPoint("BOTTOMLEFT", (i-1)*(53+1), 0)
		if (i == 12) then
			-- these don't get texture updates. why?
			button:SetState(11, "custom", exitButton)
			button:SetState(12, "custom", exitButton)
		end
	end
	bar:UpdateStateDriver()

	local buttons = bar.buttons
	local controller = CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate")
	controller:SetAttribute("_onstate-petbattle", string_format([[
		if (newstate == "petbattle") then
			b = b or table.new();
			b[1], b[2], b[3], b[4], b[5], b[6] = "%s", "%s", "%s", "%s", "%s", "%s";
			for i = 1,6 do
				local button, vbutton = "CLICK "..b[i]..":LeftButton", "ACTIONBUTTON"..i
				for k=1,select("#", GetBindingKey(button)) do
					local key = select(k, GetBindingKey(button))
					self:SetBinding(true, key, vbutton)
				end
				-- do the same for the default UIs bindings
				for k=1,select("#", GetBindingKey(vbutton)) do
					local key = select(k, GetBindingKey(vbutton))
					self:SetBinding(true, key, vbutton)
				end
			end
		else
			self:ClearBindings()
		end
	]], buttons[1]:GetName(), buttons[2]:GetName(), buttons[3]:GetName(), buttons[4]:GetName(), buttons[5]:GetName(), buttons[6]:GetName()))

	RegisterStateDriver(controller, "petbattle", "[petbattle]petbattle;nopetbattle")

	self.Bars.PrimaryActionBar = bar
	self.Bars.PrimaryActionBar.Controller = controller


	-- Secondary ActionBar (Bottom Left MultiBar)
	-------------------------------------------------------
	local bar = SetObjectScale(ns.ActionBar:Create(BOTTOMLEFT_ACTIONBAR_PAGE, ns.Prefix.."ActionBar2", UIParent))
	bar:SetPoint("BOTTOM", -1, 70)
	bar:SetSize(647, 53)
	bar:Hide()
	--bar:SetAttribute("userhidden", true)

	for i = 1,12 do
		local button = bar:CreateButton(i)
		button:SetPoint("BOTTOMLEFT", (i-1)*54, 0)
	end

	bar:UpdateStateDriver()

	local onVisibility = function(self)
		ns:Fire("ActionBars_SecondaryBar_Updated", self:IsShown() and true or false)
	end
	bar:HookScript("OnHide", onVisibility)
	bar:HookScript("OnShow", onVisibility)

	self.Bars.SecondaryActionBar = bar


	-- Left Bar 1 (Bottom Right MultiBar, Buttons 1-6)
	-------------------------------------------------------
	local bar = SetObjectScale(ns.ActionBar:Create(BOTTOMRIGHT_ACTIONBAR_PAGE, ns.Prefix.."SmallActionBar1", UIParent))
	bar:SetAttribute("userhidden", true)
	bar:SetFrameStrata("MEDIUM")
	bar:SetSize(162, 112)
	bar:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOM", -660, 11)

	local backdrop = bar:CreateTexture(nil, "BACKGROUND", nil, -7)
	backdrop:SetSize(256,256)
	backdrop:SetPoint("CENTER", -1, 0)
	backdrop:SetTexture(GetMedia("bars-floater"))
	bar.Backdrop = backdrop

	for i = 1,6 do
		local button = bar:CreateButton(i)
		button:SetPoint("TOPLEFT", ((i-1)%3)*54, -(math_floor((i-1)/3))*(53 + 6))
	end

	bar:UpdateStateDriver()
	bar:Enable()

	self.Bars.SmallActionBar1 = bar


	-- Left Bar 2 (Left Side MultiBar, Buttons 1-6)
	-------------------------------------------------------
	local bar = SetObjectScale(ns.ActionBar:Create(LEFT_ACTIONBAR_PAGE, ns.Prefix.."SmallActionBar2", UIParent))
	bar:SetAttribute("userhidden", true)
	bar:SetFrameStrata("MEDIUM")
	bar:SetSize(162, 112)
	bar:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOM", -660, 140)

	local backdrop = bar:CreateTexture(nil, "BACKGROUND", nil, -7)
	backdrop:SetSize(256,256)
	backdrop:SetPoint("CENTER", -1, 0)
	backdrop:SetTexture(GetMedia("bars-floater"))
	bar.Backdrop = backdrop

	for i = 1,6 do
		local button = bar:CreateButton(i)
		button:SetPoint("TOPLEFT", ((i-1)%3)*54, -(math_floor((i-1)/3))*(53 + 6))
	end

	bar:UpdateStateDriver()
	bar:Enable()

	self.Bars.SmallActionBar2 = bar


	-- Left Bar 3 (Left Side MultiBar, Buttons 7-12)
	-------------------------------------------------------
	local bar = SetObjectScale(ns.ActionBar:Create(LEFT_ACTIONBAR_PAGE, ns.Prefix.."SmallActionBar3", UIParent))
	bar:SetAttribute("userhidden", true)
	bar:SetFrameStrata("MEDIUM")
	bar:SetSize(162, 112)
	bar:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOM", -660, 269)

	local backdrop = bar:CreateTexture(nil, "BACKGROUND", nil, -7)
	backdrop:SetSize(256,256)
	backdrop:SetPoint("CENTER", -1, 0)
	backdrop:SetTexture(GetMedia("bars-floater"))
	bar.Backdrop = backdrop

	for i = 1,6 do
		local button = bar:CreateButton(i + 6)
		button:SetPoint("TOPLEFT", ((i-1)%3)*54, -(math_floor((i-1)/3))*(53 + 6))
	end

	bar:UpdateStateDriver()
	bar:Enable()

	self.Bars.SmallActionBar3 = bar


	-- Right Bar 1 (Bottom Right MultiBar, Buttons 7-12)
	-------------------------------------------------------
	local bar = SetObjectScale(ns.ActionBar:Create(BOTTOMRIGHT_ACTIONBAR_PAGE, ns.Prefix.."SmallActionBar4", UIParent))
	bar:SetAttribute("userhidden", true)
	bar:SetFrameStrata("MEDIUM")
	bar:SetSize(162, 112)
	bar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOM", 660, 11)

	local backdrop = bar:CreateTexture(nil, "BACKGROUND", nil, -7)
	backdrop:SetSize(256,256)
	backdrop:SetPoint("CENTER", -1, 0)
	backdrop:SetTexture(GetMedia("bars-floater"))
	bar.Backdrop = backdrop

	for i = 1,6 do
		local button = bar:CreateButton(i + 6)
		button:SetPoint("TOPLEFT", ((i-1)%3)*54, -(math_floor((i-1)/3))*(53 + 6))
	end

	bar:UpdateStateDriver()
	bar:Enable()

	self.Bars.SmallActionBar4 = bar


	-- Right Bar 2 (Right Side MultiBar, Buttons 1-6)
	-------------------------------------------------------
	local bar = SetObjectScale(ns.ActionBar:Create(RIGHT_ACTIONBAR_PAGE, ns.Prefix.."SmallActionBar5", UIParent))
	bar:SetAttribute("userhidden", true)
	bar:SetFrameStrata("MEDIUM")
	bar:SetSize(162, 112)
	bar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOM", 660, 140)

	local backdrop = bar:CreateTexture(nil, "BACKGROUND", nil, -7)
	backdrop:SetSize(256,256)
	backdrop:SetPoint("CENTER", -1, 0)
	backdrop:SetTexture(GetMedia("bars-floater"))
	bar.Backdrop = backdrop

	for i = 1,6 do
		local button = bar:CreateButton(i)
		button:SetPoint("TOPLEFT", ((i-1)%3)*54, -(math_floor((i-1)/3))*(53 + 6))
	end

	bar:UpdateStateDriver()
	bar:Enable()

	self.Bars.SmallActionBar5 = bar


	-- Right Bar 3 (Right Side MultiBar, Buttons 7-12)
	-------------------------------------------------------
	local bar = SetObjectScale(ns.ActionBar:Create(RIGHT_ACTIONBAR_PAGE, ns.Prefix.."SmallActionBar6", UIParent))
	bar:SetAttribute("userhidden", true)
	bar:SetFrameStrata("MEDIUM")
	bar:SetSize(162, 112)
	bar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOM", 660, 269)

	local backdrop = bar:CreateTexture(nil, "BACKGROUND", nil, -7)
	backdrop:SetSize(256,256)
	backdrop:SetPoint("CENTER", -1, 0)
	backdrop:SetTexture(GetMedia("bars-floater"))
	bar.Backdrop = backdrop

	for i = 1,6 do
		local button = bar:CreateButton(i + 6)
		button:SetPoint("TOPLEFT", ((i-1)%3)*54, -(math_floor((i-1)/3))*(53 + 6))
	end

	bar:UpdateStateDriver()
	bar:Enable()

	self.Bars.SmallActionBar6 = bar



	-- Left ToggleButton
	-------------------------------------------------------
	local toggle = SetObjectScale(CreateFrame("CheckButton", nil, UIParent, "SecureHandlerClickTemplate"))
	toggle:RegisterForClicks("AnyUp")
	toggle:SetFrameRef("Bar1", self.Bars.SmallActionBar1)
	toggle:SetFrameRef("Bar2", self.Bars.SmallActionBar2)
	toggle:SetFrameRef("Bar3", self.Bars.SmallActionBar3)
	toggle:SetAttribute("_onclick", [[

		local bar1 = self:GetFrameRef("Bar1");
		local bar2 = self:GetFrameRef("Bar2");
		local bar3 = self:GetFrameRef("Bar3");

		if (button == "LeftButton") then
			if (not bar1:IsShown()) then
				bar1:Show();
			elseif (not bar2:IsShown()) then
				bar2:Show();
			elseif (not bar3:IsShown()) then
				bar3:Show();
			end
		elseif (button == "RightButton") then
			if (bar3:IsShown()) then
				bar3:Hide();
			elseif (bar2:IsShown()) then
				bar2:Hide();
			elseif (bar1:IsShown()) then
				bar1:Hide();
			end
		end

		bar1:UnregisterAutoHide();
		bar2:UnregisterAutoHide();
		bar3:UnregisterAutoHide();

		if (bar1:IsShown()) then

			-- Register autohider for bar1
			bar1:RegisterAutoHide(.75);
			bar1:AddToAutoHide(self);
			for i = 1,6 do
				button = bar1:GetFrameRef("Button"..i);
				if (button:IsShown()) then
					bar1:AddToAutoHide(button);
				end
			end

			if (bar2:IsShown()) then

				-- Add bar2 to bar1's autohider
				bar1:AddToAutoHide(bar2);
				for i = 1,6 do
					button = bar2:GetFrameRef("Button"..i);
					if (button:IsShown()) then
						bar1:AddToAutoHide(button);
					end
				end

				-- Register autohider for bar2, include bar1
				bar2:RegisterAutoHide(.75);
				bar2:AddToAutoHide(self);
				bar2:AddToAutoHide(bar1);
				for i = 1,6 do
					button = bar2:GetFrameRef("Button"..i);
					if (button:IsShown()) then
						bar2:AddToAutoHide(button);
					end
					button = bar1:GetFrameRef("Button"..i);
					if (button:IsShown()) then
						bar2:AddToAutoHide(button);
					end
				end

				if (bar3:IsShown()) then

					-- Add bar3 to bar1 and bar2's autohiders
					bar1:AddToAutoHide(bar3);
					bar2:AddToAutoHide(bar3);
					for i = 1,6 do
						button = bar3:GetFrameRef("Button"..i);
						if (button:IsShown()) then
							bar1:AddToAutoHide(button);
							bar2:AddToAutoHide(button);
						end
					end

					-- Register autohider for bar3, include bar1 and bar2
					bar3:RegisterAutoHide(.75);
					bar3:AddToAutoHide(self);
					bar3:AddToAutoHide(bar1);
					bar3:AddToAutoHide(bar2);
					for i = 1,6 do
						button = bar3:GetFrameRef("Button"..i);
						if (button:IsShown()) then
							bar3:AddToAutoHide(button);
						end
						button = bar2:GetFrameRef("Button"..i);
						if (button:IsShown()) then
							bar3:AddToAutoHide(button);
						end
						button = bar1:GetFrameRef("Button"..i);
						if (button:IsShown()) then
							bar3:AddToAutoHide(button);
						end
					end

				end
			end
		end

	]])

	toggle:SetSize(48,48)
	toggle:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOM", -660 + 54, 11)

	toggle:SetScript("OnEnter", function(self)
		self.mouseOver = true
		self:UpdateAlpha()
	end)

	toggle:SetScript("OnLeave", function(self)
		self.mouseOver = nil
		self:UpdateAlpha()
	end)

	toggle.UpdateAlpha = function(self)
		if (self.mouseOver) or (IsShiftKeyDown() and IsControlKeyDown()) or (self.Bar1:IsShown()) then
			self:SetAlpha(1)
		else
			self:SetAlpha(0)
		end
	end

	toggle:SetAttribute("_onstate-vis", [[
		if (not newstate) then
			return
		end
		if (newstate == "hide") then
			self:Hide();
		else
			self:Show();
			self:RunMethod("UpdateAlpha");
		end
	]])

	toggle:SetScript("OnEvent", toggle.UpdateAlpha)
	toggle:RegisterEvent("MODIFIER_STATE_CHANGED")
	toggle:RegisterEvent("PLAYER_ENTERING_WORLD")

	RegisterStateDriver(toggle, "state-vis", "[petbattle][possessbar][overridebar][vehicleui][target=vehicle,exists]hide;show")

	toggle.Bar1 = self.Bars.SmallActionBar1
	toggle.Bar2 = self.Bars.SmallActionBar2
	toggle.Bar3 = self.Bars.SmallActionBar3
	toggle.Bar1:HookScript("OnHide", function() toggle:UpdateAlpha() end)
	toggle.Bar2:HookScript("OnHide", function() toggle:UpdateAlpha() end)
	toggle.Bar3:HookScript("OnHide", function() toggle:UpdateAlpha() end)

	toggle.Texture = toggle:CreateTexture(nil, "ARTWORK", nil, 0)
	toggle.Texture:SetSize(64,64)
	toggle.Texture:SetPoint("CENTER")
	toggle.Texture:SetTexture(GetMedia("button-toggle-plus"))


	-- Right ToggleButton
	-------------------------------------------------------
	local toggle = SetObjectScale(CreateFrame("CheckButton", nil, UIParent, "SecureHandlerClickTemplate"))
	toggle:RegisterForClicks("AnyUp")
	toggle:SetFrameRef("Bar1", self.Bars.SmallActionBar4)
	toggle:SetFrameRef("Bar2", self.Bars.SmallActionBar5)
	toggle:SetFrameRef("Bar3", self.Bars.SmallActionBar6)
	toggle:SetAttribute("_onclick", [[

		local bar1 = self:GetFrameRef("Bar1");
		local bar2 = self:GetFrameRef("Bar2");
		local bar3 = self:GetFrameRef("Bar3");

		if (button == "LeftButton") then
			if (not bar1:IsShown()) then
				bar1:Show();
			elseif (not bar2:IsShown()) then
				bar2:Show();
			elseif (not bar3:IsShown()) then
				bar3:Show();
			end
		elseif (button == "RightButton") then
			if (bar3:IsShown()) then
				bar3:Hide();
			elseif (bar2:IsShown()) then
				bar2:Hide();
			elseif (bar1:IsShown()) then
				bar1:Hide();
			end
		end

		bar1:UnregisterAutoHide();
		bar2:UnregisterAutoHide();
		bar3:UnregisterAutoHide();

		if (bar1:IsShown()) then
			self:SetAttribute("barsVisible", true);

			-- Register autohider for bar1
			bar1:RegisterAutoHide(.75);
			bar1:AddToAutoHide(self);
			for i = 1,6 do
				button = bar1:GetFrameRef("Button"..i);
				if (button:IsShown()) then
					bar1:AddToAutoHide(button);
				end
			end

			if (bar2:IsShown()) then

				-- Add bar2 to bar1's autohider
				bar1:AddToAutoHide(bar2);
				for i = 1,6 do
					button = bar2:GetFrameRef("Button"..i);
					if (button:IsShown()) then
						bar1:AddToAutoHide(button);
					end
				end

				-- Register autohider for bar2, include bar1
				bar2:RegisterAutoHide(.75);
				bar2:AddToAutoHide(self);
				bar2:AddToAutoHide(bar1);
				for i = 1,6 do
					button = bar2:GetFrameRef("Button"..i);
					if (button:IsShown()) then
						bar2:AddToAutoHide(button);
					end
					button = bar1:GetFrameRef("Button"..i);
					if (button:IsShown()) then
						bar2:AddToAutoHide(button);
					end
				end

				if (bar3:IsShown()) then

					-- Add bar3 to bar1 and bar2's autohiders
					bar1:AddToAutoHide(bar3);
					bar2:AddToAutoHide(bar3);
					for i = 1,6 do
						button = bar3:GetFrameRef("Button"..i);
						if (button:IsShown()) then
							bar1:AddToAutoHide(button);
							bar2:AddToAutoHide(button);
						end
					end

					-- Register autohider for bar3, include bar1 and bar2
					bar3:RegisterAutoHide(.75);
					bar3:AddToAutoHide(self);
					bar3:AddToAutoHide(bar1);
					bar3:AddToAutoHide(bar2);
					for i = 1,6 do
						button = bar3:GetFrameRef("Button"..i);
						if (button:IsShown()) then
							bar3:AddToAutoHide(button);
						end
						button = bar2:GetFrameRef("Button"..i);
						if (button:IsShown()) then
							bar3:AddToAutoHide(button);
						end
						button = bar1:GetFrameRef("Button"..i);
						if (button:IsShown()) then
							bar3:AddToAutoHide(button);
						end
					end

				end
			end
		else
			self:SetAttribute("barsVisible", nil);
		end

	]])

	toggle:SetSize(48,48)
	toggle:SetPoint("BOTTOMLEFT", UIParent, "BOTTOM", 660 - 54, 11)

	toggle:SetScript("OnEnter", function(self)
		self.mouseOver = true
		self:UpdateAlpha()
	end)
	toggle:SetScript("OnLeave", function(self)
		self.mouseOver = nil
		self:UpdateAlpha()
	end)

	toggle.UpdateAlpha = function(self)
		if (self.mouseOver) or (IsShiftKeyDown() and IsControlKeyDown()) or (self.Bar1:IsShown()) then
			self:SetAlpha(1)
		else
			self:SetAlpha(0)
		end
	end

	toggle:SetAttribute("_onstate-vis", [[
		if (not newstate) then
			return
		end
		if (newstate == "hide") then
			self:Hide();
		else
			self:Show();
			self:RunMethod("UpdateAlpha");
		end
	]])

	RegisterStateDriver(toggle, "state-vis", "[petbattle][possessbar][overridebar][vehicleui][target=vehicle,exists]hide;show")

	toggle:SetScript("OnEvent", toggle.UpdateAlpha)
	toggle:RegisterEvent("MODIFIER_STATE_CHANGED")
	toggle:RegisterEvent("PLAYER_ENTERING_WORLD")

	toggle.Bar1 = self.Bars.SmallActionBar4
	toggle.Bar2 = self.Bars.SmallActionBar5
	toggle.Bar3 = self.Bars.SmallActionBar6
	toggle.Bar1:HookScript("OnHide", function() toggle:UpdateAlpha() end)
	toggle.Bar2:HookScript("OnHide", function() toggle:UpdateAlpha() end)
	toggle.Bar3:HookScript("OnHide", function() toggle:UpdateAlpha() end)

	toggle.Texture = toggle:CreateTexture(nil, "ARTWORK", nil, 0)
	toggle.Texture:SetSize(64,64)
	toggle.Texture:SetPoint("CENTER")
	toggle.Texture:SetTexture(GetMedia("button-toggle-plus"))


	-- Inform the environment about the spawned bars
	ns:Fire("ActionBar_Created", ns.Prefix.."PrimaryActionBar")
	ns:Fire("ActionBar_Created", ns.Prefix.."SecondaryActionBar")
	ns:Fire("ActionBar_Created", ns.Prefix.."SmallActionBar1")
	ns:Fire("ActionBar_Created", ns.Prefix.."SmallActionBar2")
	ns:Fire("ActionBar_Created", ns.Prefix.."SmallActionBar3")
	ns:Fire("ActionBar_Created", ns.Prefix.."SmallActionBar4")
	ns:Fire("ActionBar_Created", ns.Prefix.."SmallActionBar5")
	ns:Fire("ActionBar_Created", ns.Prefix.."SmallActionBar6")

end

Bars.SpawnArtwork = function(self)
	if (not self.Artwork) then
		self.Artwork = {}
	end

	local scaffold = SetObjectScale(CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate"))
	scaffold:SetFrameStrata("BACKGROUND")
	scaffold:SetFrameLevel(10)

	local single = scaffold:CreateTexture(nil, "BACKGROUND", nil, -6)
	single:SetSize(1024,256)
	single:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, -10)
	single:SetTexture(GetMedia("bars-single"))
	single:SetAlpha(0)

	local double = scaffold:CreateTexture(nil, "BACKGROUND", nil, -6)
	double:SetSize(1024,256)
	double:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, -10)
	double:SetTexture(GetMedia("bars-double"))
	double:SetAlpha(0)

	local left = scaffold:CreateTexture(nil, "BACKGROUND", nil, -7)
	left:SetSize(128,128)
	left:SetPoint("BOTTOM", UIParent, "BOTTOM", -364, -29)
	left:SetTexture(GetMedia("bars-glow-diabolic"))
	left:SetTexCoord(1,0,0,1)
	left:SetVertexColor(25/255, 20/255, 15/255, 1)

	local right = scaffold:CreateTexture(nil, "BACKGROUND", nil, -7)
	right:SetSize(128,128)
	right:SetPoint("BOTTOM", UIParent, "BOTTOM", 364, -29)
	right:SetTexture(GetMedia("bars-glow-diabolic"))
	right:SetVertexColor(25/255, 20/255, 15/255, 1)

	self.Artwork = scaffold
	self.Artwork.Single = single
	self.Artwork.Double = double
	self.Artwork.LeftFill = left
	self.Artwork.RightFill = right
	self.SpawnArtwork = nil

	RegisterStateDriver(scaffold, "visibility", "[petbattle]hide;show")
end

Bars.SetNumBars = function(self, numBars)
	if (InCombatLockdown()) then
		return
	end
	numBars = tonumber(numBars)
	if (numBars == 1) then
		self:DisableSecondary()
	elseif (numBars == 2) then
		self:EnableSecondary()
	end
end

Bars.EnableSecondary = function(self)
	if (InCombatLockdown()) then
		return
	end
	self.Bars.SecondaryActionBar:Enable()
	ns.db.char.actionbars.enableSecondary = true
end

Bars.DisableSecondary = function(self)
	if (InCombatLockdown()) then
		return
	end
	self.Bars.SecondaryActionBar:Disable()
	ns.db.char.actionbars.enableSecondary = nil
end

Bars.ToggleSecondary = function(self)
	if (InCombatLockdown()) then
		return
	end
	if (ns.db.char.actionbars.enableSecondary) then
		self:DisableSecondary()
	else
		self:EnableSecondary()
	end
end

Bars.HasSecondaryBar = function(self)
	if (not self.Bars) then
		return
	end
	local secondary = self.Bars.SecondaryActionBar
	return secondary and secondary:IsShown()
end

Bars.UpdateArtwork = function(self)
	if (not self.Artwork) then
		return
	end
	local hasSecondary = ActionBars:HasSecondaryBar()
	if (hasSecondary) then
		self.Artwork.Single:SetAlpha(0)
		self.Artwork.Double:SetAlpha(1)
	else
		self.Artwork.Single:SetAlpha(1)
		self.Artwork.Double:SetAlpha(0)
	end
	ns:Fire("ActionBars_Artwork_Updated", hasSecondary)
end

Bars.UpdateBindings = function(self)
	if (not self.Bars) then
		return
	end
	for name,bar in pairs(self.Bars) do
		if (bar.UpdateBindings) then
			bar:UpdateBindings()
		end
	end
end

Bars.UpdateSettings = function(self, event)
	if (not self.Bars) then
		return
	end
	if (ns.db.char.actionbars.enableSecondary) then
		self:EnableSecondary()
	else
		self:DisableSecondary()
	end
end

Bars.OnEvent = function(self, event, ...)
	if (not self.Bars) then
		return
	end
	if (event == "PLAYER_ENTERING_WORLD") then
		local isInitialLogin, isReloadingUi = ...
		if (isInitialLogin or isReloadingUi) then
			self:UpdateSettings()
		end
	end
end

Bars.OnInitialize = function(self)
	self:SpawnBars()
	self:SpawnArtwork()
	self:RegisterChatCommand("setbars", "SetNumBars")
	self:RegisterChatCommand("enablesecondary", "EnableSecondary")
	self:RegisterChatCommand("disablesecondary", "DisableSecondary")
	self:RegisterChatCommand("togglesecondary", "ToggleSecondary")
end

Bars.OnEnable = function(self)
	self:UpdateArtwork()
	self:UpdateBindings()
	self:RegisterEvent("UPDATE_BINDINGS", "UpdateBindings")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
	ns.RegisterCallback(self, "ActionBars_SecondaryBar_Updated", "UpdateArtwork")
	ns.RegisterCallback(self, "Saved_Settings_Updated", "UpdateSettings")
end
