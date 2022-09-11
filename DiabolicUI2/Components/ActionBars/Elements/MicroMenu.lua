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
local MicroMenu = ActionBars:NewModule("MicroMenu", "LibMoreEvents-1.0", "AceHook-3.0")

-- Lua API
local ipairs = ipairs
local table_insert = table.insert

-- WoW API
--local ActionBarController_GetCurrentActionBarState = ActionBarController_GetCurrentActionBarState
local C_PetBattles = C_PetBattles
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local IsAddOnLoaded = IsAddOnLoaded
--local UpdateMicroButtonsParent = UpdateMicroButtonsParent

-- Addon API
local GetFont = ns.API.GetFont
local GetMedia = ns.API.GetMedia
local SetObjectScale = ns.API.SetObjectScale
local IsAddOnEnabled = ns.API.IsAddOnEnabled

MicroMenu.UpdateMicroButtonsParent = function(self, parent)
	if (parent == self.bar) then
		self.ownedByUI = false
		return
	end
	if parent and (parent == (PetBattleFrame and PetBattleFrame.BottomFrame.MicroButtonFrame)) then
		self.ownedByUI = true
		self:BlizzardBarShow()
		return
	end
	self.ownedByUI = false
	self:MicroMenuBarShow()
end

MicroMenu.MicroMenuBarShow = function(self)
	if (InCombatLockdown()) then
		return
	end
	if (not self.ownedByUI) then

		UpdateMicroButtonsParent(self.bar)

		for i,v in ipairs(self.bar.buttons) do

			-- Show our layers
			local b = self.bar.custom[v]

			-- Hide blizzard layers
			SetObjectScale(v)
			v:SetAlpha(0)
			v:SetSize(b:GetSize())
			v:SetHitRectInsets(0,0,0,0)

			-- Update button layout
			v:ClearAllPoints()
			v:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)

		end
	end
end

MicroMenu.BlizzardBarShow = function(self)

	-- Only reset button positions not set in MoveMicroButtons()
	for i,v in pairs(self.bar.buttons) do
		if (v ~= CharacterMicroButton) and (v ~= LFDMicroButton) then

			-- Restore blizzard button layout
			v:SetIgnoreParentScale(false)
			v:SetScale(1)
			v:SetSize(28,36)
			v:SetHitRectInsets(0,0,0,0)
			v:ClearAllPoints()
			v:SetPoint(unpack(self.bar.anchors[i]))

			-- Show Blizzard style
			v:SetAlpha(1)

			-- Hide our style
			--self.bar.custom[v]:SetAlpha(0)
		end
	end
end

MicroMenu.ActionBarController_UpdateAll = function(self)
	if (self.ownedByUI) and ActionBarController_GetCurrentActionBarState() == LE_ACTIONBAR_STATE_MAIN and not (C_PetBattles and C_PetBattles.IsInBattle()) then
		UpdateMicroButtonsParent(self.bar)
		self:MicroMenuBarShow()
	end
end

MicroMenu.InitializeMicroMenu = function(self)

	if (not self.bar) then
		self.bar = CreateFrame("Frame", ns.Prefix.."MicroMenu", UIParent, "SecureHandlerStateTemplate")
		self.bar:SetFrameStrata("HIGH")
		--self.bar:SetFrameLevel(0)
		self.bar:Hide()

		local backdrop = CreateFrame("Frame", nil, self.bar, ns.BackdropTemplate)
		backdrop:SetFrameLevel(self.bar:GetFrameLevel())
		backdrop:SetBackdrop({
			bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
			edgeSize = 32, edgeFile = GetMedia("border-tooltip"),
			tile = true,
			insets = { left = 8, right = 8, top = 16, bottom = 16 }
		})
		backdrop:SetBackdropColor(.05, .05, .05, .95)
		self.bar.backdrop = backdrop

		self.bar.buttons = {}
		for i,name in ipairs({
			"CharacterMicroButton",
			"SpellbookMicroButton",
			"TalentMicroButton",
			"AchievementMicroButton",
			"QuestLogMicroButton",
			"SocialsMicroButton",
			"PVPMicroButton",
			"LFGMicroButton",
			"WorldMapMicroButton",
			"GuildMicroButton",
			"LFDMicroButton",
			"CollectionsMicroButton",
			"EJMicroButton",
			"StoreMicroButton",
			"MainMenuMicroButton",
			"HelpMicroButton"
		}) do
			local button = _G[name]
			if (button) then
				table_insert(self.bar.buttons, button)
			end
		end

		if (self.bar.buttons[1]:GetParent() ~= MainMenuBarArtFrame) then
			self.ownedByUI = true
		end

		local labels = {
			CharacterMicroButton = CHARACTER_BUTTON,
			SpellbookMicroButton = SPELLBOOK_ABILITIES_BUTTON,
			TalentMicroButton = TALENTS_BUTTON,
			AchievementMicroButton = ACHIEVEMENT_BUTTON,
			QuestLogMicroButton = QUESTLOG_BUTTON,
			SocialsMicroButton = SOCIALS,
			PVPMicroButton = PLAYER_V_PLAYER,
			LFGMicroButton = DUNGEONS_BUTTON,
			WorldMapMicroButton = WORLD_MAP,
			GuildMicroButton = LOOKINGFORGUILD,
			LFDMicroButton = DUNGEONS_BUTTON,
			CollectionsMicroButton = COLLECTIONS,
			EJMicroButton = ADVENTURE_JOURNAL or ENCOUNTER_JOURNAL,
			StoreMicroButton = BLIZZARD_STORE,
			MainMenuMicroButton = MAINMENU_BUTTON,
			HelpMicroButton = HELP_BUTTON
		}

		self.bar.anchors = {}
		self.bar.custom = {}

		for i,v in pairs(self.bar.buttons) do
			self.bar.anchors[i] = { v:GetPoint() }

			v.OnEnter = v:GetScript("OnEnter")
			v.OnLeave = v:GetScript("OnLeave")
			v:SetScript("OnEnter", nil)
			v:SetScript("OnLeave", nil)
			v:SetFrameLevel(self.bar:GetFrameLevel() + 1)

			local b = CreateFrame("Frame", nil, v, "SecureHandlerStateTemplate")
			b:SetMouseMotionEnabled(true)
			b:SetMouseClickEnabled(false)
			b:SetIgnoreParentAlpha(true)
			b:SetAlpha(1)
			b:SetFrameLevel(v:GetFrameLevel() - 1)
			b:SetSize(200,30)
			b:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -26, 64 + 30*(i-1))

			local c = b:CreateTexture(nil, "ARTWORK")
			c:SetPoint("TOPLEFT", 1,-1)
			c:SetPoint("BOTTOMRIGHT", -1,1)
			c:SetColorTexture(1,1,1,.9)

			v:SetScript("OnEnter", function() c:SetVertexColor(.75,.75,.75) end)
			v:SetScript("OnLeave", function() c:SetVertexColor(.1,.1,.1) end)
			v:GetScript("OnLeave")(v)

			local d = b:CreateFontString(nil, "OVERLAY")
			d:SetFontObject(GetFont(13,true))
			d:SetText(labels[v:GetName()])
			d:SetJustifyH("CENTER")
			d:SetJustifyV("MIDDLE")
			d:SetPoint("CENTER")

			self.bar.custom[v] = b
		end

		self.bar.backdrop:ClearAllPoints()
		self.bar.backdrop:SetPoint("RIGHT", self.bar.custom[self.bar.buttons[1]], "RIGHT", 10, 0)
		self.bar.backdrop:SetPoint("BOTTOM", self.bar.custom[self.bar.buttons[1]], "BOTTOM", 0, -18)
		self.bar.backdrop:SetPoint("LEFT", self.bar.custom[self.bar.buttons[#self.bar.buttons]], "LEFT", -10, 0)
		self.bar.backdrop:SetPoint("TOP", self.bar.custom[self.bar.buttons[#self.bar.buttons]], "TOP", 0, 18)
		self.bar:SetAllPoints(self.bar.backdrop)

		-- Create toggle button
		local toggle = SetObjectScale(CreateFrame("CheckButton", nil, UIParent, "SecureHandlerClickTemplate"))
		toggle:RegisterForClicks("AnyUp")
		toggle:SetFrameRef("Bar", self.bar)
		for i,v in ipairs(self.bar.buttons) do
			toggle:SetFrameRef("Button"..i, self.bar.custom[v])
		end
		toggle:SetAttribute("_onclick", [[

			local bar = self:GetFrameRef("Bar");
			if (bar:IsShown()) then
				bar:Hide();
			else
				bar:Show();
			end

			bar:UnregisterAutoHide();

			if (bar:IsShown()) then
				bar:RegisterAutoHide(.75);
				bar:AddToAutoHide(self);

				local i = 1;
				local button = self:GetFrameRef("Button"..i);
				while (button) do
					i = i + 1;
					bar:AddToAutoHide(button);
					button = self:GetFrameRef("Button"..i);
				end
			end

		]])

		toggle:SetSize(48,48)
		toggle:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -11, 11)

		toggle:SetScript("OnEnter", function(self)
			self.mouseOver = true
			self:UpdateAlpha()
		end)

		toggle:SetScript("OnLeave", function(self)
			self.mouseOver = nil
			self:UpdateAlpha()
		end)

		toggle.UpdateAlpha = function(self)
			if (self.mouseOver) or (IsShiftKeyDown() and IsControlKeyDown()) or (self.bar:IsShown()) then
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

		RegisterStateDriver(toggle, "state-vis", "[petbattle]hide;show")

		toggle.bar = self.bar
		toggle.bar:HookScript("OnHide", function() toggle:UpdateAlpha() end)

		toggle.Texture = toggle:CreateTexture(nil, "ARTWORK", nil, 0)
		toggle.Texture:SetSize(64,64)
		toggle.Texture:SetPoint("CENTER")
		toggle.Texture:SetTexture(GetMedia("button-toggle-plus"))


	end

	self:SecureHook("UpdateMicroButtons", "MicroMenuBarShow")
	self:SecureHook("UpdateMicroButtonsParent")
	self:SecureHook("ActionBarController_UpdateAll")

	if (C_PetBattles) then
		self:RegisterEvent("PET_BATTLE_CLOSE", "OnEvent")
	end

	self:MicroMenuBarShow()

end

MicroMenu.HandleBartender = function(self)
	local MicroMenuMod = Bartender4:GetModule("MicroMenu")
	if (not MicroMenuMod) then
		return
	end
	MicroMenuMod:Disable()
	MicroMenuMod:UnhookAll()
end

MicroMenu.OnEvent = function(self, event, ...)
	if (event == "ADDON_LOADED") then
		local addon = ...
		if (addon == "Bartender4") then
			self:HandleBartender()
			self:InitializeMicroMenu()
		end
	elseif (event == "PET_BATTLE_CLOSE") then
		UpdateMicroButtonsParent(self.bar)
		self:MicroMenuBarShow()
	end
end

MicroMenu.OnInitialize = function(self)
	if (IsAddOnEnabled("Bartender4")) then
		if (IsAddOnLoaded("Bartender4")) then
			self:HandleBartender()
			self:InitializeMicroMenu()
		else
			self:RegisterEvent("ADDON_LOADED", "OnEvent")
		end
	else
		self:InitializeMicroMenu()
	end
end
