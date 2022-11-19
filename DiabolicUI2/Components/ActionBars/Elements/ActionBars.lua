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
local LAB = LibStub("LibActionButton-1.0")

-- Lua API
local math_floor = math.floor
local next = next
local pairs = pairs
local select = select
local string_format = string.format
local tonumber = tonumber

-- WoW API
local CreateFrame = CreateFrame
local GetBindingKey = GetBindingKey
local InCombatLockdown = InCombatLockdown
local IsControlKeyDown = IsControlKeyDown
local IsShiftKeyDown = IsShiftKeyDown
local PetDismiss = PetDismiss
local RegisterStateDriver = RegisterStateDriver
local UnitExists = UnitExists
local VehicleExit = VehicleExit

-- Addon API
local Colors = ns.Colors
local GetFont = ns.API.GetFont
local GetMedia = ns.API.GetMedia
local RegisterCooldown = ns.Widgets.RegisterCooldown
local SetObjectScale = ns.API.SetObjectScale
local UIHider = ns.Hider
local noop = ns.Noop

-- Constants
local playerClass = ns.PlayerClass
local BOTTOMLEFT_ACTIONBAR_PAGE = BOTTOMLEFT_ACTIONBAR_PAGE
local BOTTOMRIGHT_ACTIONBAR_PAGE = BOTTOMRIGHT_ACTIONBAR_PAGE
local RIGHT_ACTIONBAR_PAGE = RIGHT_ACTIONBAR_PAGE
local LEFT_ACTIONBAR_PAGE = LEFT_ACTIONBAR_PAGE

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

local toggleOnEnter = function(self)
	self.mouseOver = true
	self:UpdateAlpha()
end

local toggleOnLeave = function(self)
	self.mouseOver = nil
	self:UpdateAlpha()
end

local toggleUpdateAlpha = function(self)
	if (self.mouseOver) or (IsShiftKeyDown() and IsControlKeyDown()) or (self.Bar1:IsShown()) then
		self:SetAlpha(1)
	else
		self:SetAlpha(0)
	end
end

local style = function(button)

	-- Clean up the button template
	for _,i in next,{ "AutoCastShine", "Border", "Name", "NewActionTexture", "NormalTexture", "SpellHighlightAnim", "SpellHighlightTexture",
		--[[ WoW10 ]] "CheckedTexture", "HighlightTexture", "BottomDivider", "RightDivider", "SlotArt", "SlotBackground" } do
		if (button[i] and button[i].Stop) then button[i]:Stop() elseif button[i] then button[i]:SetParent(UIHider) end
	end

	local m = GetMedia("actionbutton-mask-square-rounded")
	local b = GetMedia("blank")

	button:SetAttribute("buttonLock", true)
	button:SetSize(53,53)
	button:SetNormalTexture("")
	button:SetHighlightTexture("")
	button:SetCheckedTexture("")

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
	--hooksecurefunc(cooldown, "SetSwipeColor", function(c,r,g,b,a) if not a or a>.76 then c:SetSwipeColor(r,g,b,.75) end end)
	hooksecurefunc(cooldown, "SetDrawSwipe", function(c,h) if not h then c:SetDrawSwipe(true) end end)
	hooksecurefunc(cooldown, "SetDrawBling", function(c,h) if h then c:SetDrawBling(false) end end)
	hooksecurefunc(cooldown, "SetDrawEdge", function(c,h) if h then c:SetDrawEdge(false) end end)
	hooksecurefunc(cooldown, "SetHideCountdownNumbers", function(c,h) if not h then c:SetHideCountdownNumbers(true) end end)
	hooksecurefunc(cooldown, "SetCooldown", function(c) c:SetAlpha(.75) end)

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
		texture = --[[(ns.IsWrath) and ]][[Interface\Icons\achievement_bg_kill_carrier_opposing_flagroom]]
			   --or [[Interface\Icons\INV_Pet_ExitBattle]]
	}

	for i = 1,12 do
		local button = bar:CreateButton(i)
		button:SetPoint("BOTTOMLEFT", (i-1)*(53+1), 0)
		if (i == 12) then
			button:SetState(11, "custom", exitButton)
			button:SetState(12, "custom", exitButton)
		end
		style(button)
	end

	bar:UpdateStateDriver()

	self.Bars.PrimaryActionBar = bar


	-- Pet Battle Keybind Fixer
	-------------------------------------------------------
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

	self.Bars.PrimaryActionBar.Controller = controller


	-- Secondary ActionBar (Bottom Left MultiBar)
	-------------------------------------------------------
	local bar = SetObjectScale(ns.ActionBar:Create(BOTTOMLEFT_ACTIONBAR_PAGE, ns.Prefix.."ActionBar2", UIParent))
	bar:SetPoint("BOTTOM", -1, 11 + self:GetSecondaryBarOffset())
	bar:SetSize(647, 53)
	bar:Hide()
	--bar:SetAttribute("userhidden", true)

	for i = 1,12 do
		local button = bar:CreateButton(i)
		button:SetPoint("BOTTOMLEFT", (i-1)*54, 0)
		style(button)
	end

	bar:UpdateStateDriver()

	local onVisibility = function(self)
		ns:Fire("ActionBars_SecondaryBar_Updated", self:IsShown() and true or false)
	end
	bar:HookScript("OnHide", onVisibility)
	bar:HookScript("OnShow", onVisibility)

	self.Bars.SecondaryActionBar = bar


	-- Small Action Bars
	-------------------------------------------------------
	-- 1: Left Bar 1 (Bottom Right 1-6)
	-- 2: Left Bar 2 (Left Side 1-6)
	-- 3: Left Bar 3 (Left Side 7-12)
	-- 4: Right Bar 1 (Bottom Right 7-12)
	-- 5: Right Bar 2 (Right Side 1-6)
	-- 6: Right Bar 3 (Right Side 7-12)
	-------------------------------------------------------
	for i = 1,6 do

		local name = "SmallActionBar"..i
		local barID
		if (i == 1 or i == 4) then
			barID = BOTTOMRIGHT_ACTIONBAR_PAGE
		elseif (i == 2 or i == 3) then
			barID = LEFT_ACTIONBAR_PAGE
		elseif (i == 5 or i == 6) then
			barID = RIGHT_ACTIONBAR_PAGE
		end

		local bar = SetObjectScale(ns.ActionBar:Create(barID, ns.Prefix..name, UIParent))
		bar:SetAttribute("userhidden", true)
		bar:SetFrameStrata("HIGH")
		bar:SetSize(162, 112)

		if (i > 3) then
			bar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOM", 660, 11 + (i-4)*129)
		else
			bar:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOM", -660, 11 + (i-1)*129)
		end

		local backdrop = bar:CreateTexture(nil, "BACKGROUND", nil, -7)
		backdrop:SetSize(256,256)
		backdrop:SetPoint("CENTER", -1, 0)
		backdrop:SetTexture(GetMedia("bars-floater"))
		bar.Backdrop = backdrop

		local buttonOffset = (i == 3 or i == 4 or i == 6) and 6 or 0
		for j = 1,6 do
			local button = bar:CreateButton(j + buttonOffset)
			button:SetPoint("TOPLEFT", ((j-1)%3)*54, -(math_floor((j-1)/3))*(53 + 6))
			style(button)
		end

		bar:UpdateStateDriver()
		bar:Enable()

		self.Bars[name] = bar
	end

	-- ToggleButtons
	-------------------------------------------------------
	for i = 1,2 do

		local name = ns.Prefix..(i == 1 and "Left" or "Right").."SmallBarToggleButton"

		local toggle = SetObjectScale(CreateFrame("CheckButton", name, UIParent, "SecureHandlerClickTemplate"))
		toggle:SetFrameStrata("HIGH")
		toggle:RegisterForClicks("AnyUp")
		toggle:SetSize(48,48)
		toggle.OnEnter = toggleOnEnter
		toggle.OnLeave = toggleOnLeave
		toggle.UpdateAlpha = toggleUpdateAlpha

		if (i == 1) then
			toggle:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOM", -660 + 54, 11)
		else
			toggle:SetPoint("BOTTOMLEFT", UIParent, "BOTTOM", 660 - 54, 11)
		end

		local texture = toggle:CreateTexture(nil, "ARTWORK", nil, 0)
		texture:SetSize(64,64)
		texture:SetPoint("CENTER")
		texture:SetTexture(GetMedia("button-toggle-plus"))
		toggle.texture = texture

		for j = 1,3 do
			local barKey, smallBarKey = "Bar"..j, "SmallActionBar"..((i-1)*3 + j)
			toggle:SetFrameRef(barKey, self.Bars[smallBarKey])
			toggle[barKey] = self.Bars[smallBarKey]
			toggle[barKey]:HookScript("OnHide", function() toggle:UpdateAlpha() end)
		end

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

		toggle:SetScript("OnEnter", toggle.OnEnter)
		toggle:SetScript("OnLeave", toggle.OnLeave)
		toggle:SetScript("OnEvent", toggle.UpdateAlpha)
		toggle:RegisterEvent("MODIFIER_STATE_CHANGED")
		toggle:RegisterEvent("PLAYER_ENTERING_WORLD")

		RegisterStateDriver(toggle, "state-vis", "[petbattle][possessbar][overridebar][vehicleui][@vehicle,exists]hide;show")

	end

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

Bars.GetSecondaryBar = function(self)
	if (not self.Bars) then
		return
	end
	local secondary = self.Bars.SecondaryActionBar
	return secondary and secondary:IsShown()
end

Bars.GetSecondaryBarOffset = function(self)
	return 59
end

Bars.GetBarOffset = function(self)
	return self:GetSecondaryBar() and self:GetSecondaryBarOffset() or 0
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
	elseif (event == "OnButtonUpdate") then
		local button = ...
		button.cooldown:ClearAllPoints()
		button.cooldown:SetAllPoints(button.icon)
		button.icon:RemoveMaskTexture(button.IconMask)
		button.icon:SetMask(GetMedia("actionbutton-mask-square-rounded"))
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

	if (ns.IsRetail) then
		LAB.RegisterCallback(self, "OnButtonUpdate", "OnEvent")
	end
end
