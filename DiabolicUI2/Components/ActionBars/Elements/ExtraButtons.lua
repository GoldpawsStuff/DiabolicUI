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
local ExtraButtons = ActionBars:NewModule("ExtraButtons", "LibMoreEvents-1.0", "AceHook-3.0")

-- Lua API
local pairs = pairs
local string_find = string.find

-- WoW API
local GetBindingKey = GetBindingKey
local hooksecurefunc = hooksecurefunc

-- Addon API
local Colors = ns.Colors
local GetFont = ns.API.GetFont
local GetMedia = ns.API.GetMedia
local SetObjectScale = ns.API.SetObjectScale
local noop = ns.Noop

ExtraButtons.UpdateButton = function(self, button)

	local name = button:GetName()
	if (name and string_find(name, "ExtraActionButton%d+")) then
		if (not self.ExtraButtons) then
			self.ExtraButtons = {}
		end
		self.ExtraButtons[button] = true
	end

	button:SetSize(80,80)

	if (button:GetNormalTexture()) then
		button:GetNormalTexture():SetTexture(nil)
	end

	if (button.icon or button.Icon) then (button.icon or button.Icon):SetAlpha(0) end
	if (button.NormalTexture) then button.NormalTexture:SetAlpha(0) end -- Zone
	if (button.Flash) then button.Flash:SetTexture(nil) end -- Extra
	if (button.style) then button.style:SetAlpha(0) end -- Extra

	local cooldown = button.cooldown or button.Cooldown
	if (cooldown) then
		cooldown:SetSize(58,58)
		cooldown:ClearAllPoints()
		cooldown:SetPoint("CENTER", 0, 0)
		cooldown:SetSwipeTexture(GetMedia("actionbutton-mask-circular"))
		cooldown:SetSwipeColor(0, 0, 0, .75)
		cooldown:SetDrawSwipe(true)
		cooldown:SetBlingTexture(GetMedia("blank"), 0, 0, 0 , 0)
		cooldown:SetDrawBling(true)
		cooldown:SetHideCountdownNumbers(true)

		-- Attempting to fix the issue with too opaque swipe textures
		if (not cooldown.__GP_Swipe) then
			cooldown.__GP_Swipe = function()
				cooldown:SetSwipeColor(0, 0, 0, .75)
				cooldown:SetDrawSwipe(true)
				cooldown:SetBlingTexture(GetMedia("blank"), 0, 0, 0 , 0)
				cooldown:SetDrawBling(true)
				cooldown:SetHideCountdownNumbers(true)
			end
			cooldown:HookScript("OnShow", cooldown.__GP_Swipe)
		end
	end

	local count = button.Count
	if (count) then
		count:ClearAllPoints()
		count:SetPoint("BOTTOMRIGHT", -11, 11)
		count:SetFontObject(GetFont(14, true))
		count:SetJustifyH("RIGHT")
		count:SetJustifyV("BOTTOM")
	end

	local keybind = button.HotKey
	if (keybind) then
		keybind:ClearAllPoints()
		keybind:SetPoint("TOPRIGHT", -11, -11)
		keybind:SetFontObject(GetFont(12, true))
		keybind:SetJustifyH("CENTER")
		keybind:SetJustifyV("BOTTOM")
		keybind:SetShadowOffset(0, 0)
		keybind:SetShadowColor(0, 0, 0, 1)
		keybind:SetTextColor(Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3], .75)
		--keybind:SetText(GetBindingKey(button:GetName()))
	end

	if (button:GetObjectType() == "CheckButton") then
		if (not button.__GP_Checked) then
			if (button:GetCheckedTexture()) then
				button:GetCheckedTexture():SetTexture(nil)
			end

			local checkedTexture = button:CreateTexture()
			checkedTexture:SetDrawLayer("BACKGROUND", 2)
			checkedTexture:SetMask(GetMedia("actionbutton-mask-circular"))
			checkedTexture:SetColorTexture(.9, .8, .1, .3)
			button.__GP_Checked = checkedTexture

			button:SetCheckedTexture(checkedTexture)
		end
	end

	-- This crazy stunt is needed to be able
	-- to set a mask at all on the Extra buttons.
	-- I honestly have no idea why. Somebody tell me?
	if (not button.__GP_Icon) then
		local newIcon = button:CreateTexture()
		newIcon:SetPoint("TOPLEFT", button, 11, -11)
		newIcon:SetPoint("BOTTOMRIGHT", button, -11, 11)
		newIcon:SetMask(GetMedia("actionbutton-mask-circular"))
		newIcon:SetAlpha(.85)
		button.__GP_Icon = newIcon

		local oldIcon = button.icon or button.Icon

		button.__UpdateGPIcon = function() button.__GP_Icon:SetTexture(oldIcon:GetTexture()) end
		button:__UpdateGPIcon() -- Fix the empty border on reload problem.

		hooksecurefunc(oldIcon, "SetTexture", button.__UpdateGPIcon)
		hooksecurefunc(oldIcon, "Show", button.__UpdateGPIcon)
	end

	if (not button.__GP_Highlight) then
		local highlightTexture = button:CreateTexture()
		highlightTexture:SetDrawLayer("BACKGROUND", 1)
		highlightTexture:SetTexture(GetMedia("actionbutton-mask-circular"))
		highlightTexture:SetAllPoints(button.__GP_Icon)
		highlightTexture:SetVertexColor(1, 1, 1, .1)
		button.__GP_Highlight = highlightTexture

		if (button:GetHighlightTexture()) then
			button:GetHighlightTexture():SetTexture(nil)
		end

		button:SetHighlightTexture(button.__GP_Highlight)
	end

	if (not button.__GP_Border) then
		local border = button:CreateTexture(nil, "BACKGROUND", nil, -7)
		border:SetTexture(GetMedia("button-big-circular"))
		border:SetVertexColor(.8, .76, .72)
		border:SetAllPoints()
		button.__GP_Border = border
	end

end

ExtraButtons.UpdateExtraButtons = function(self)
	local frame = ExtraActionBarFrame
	if (not frame) then
		return
	end
	for i = 1, frame:GetNumChildren() do
		local button = _G["ExtraActionButton"..i]
		if (button) then
			self:UpdateButton(button)
		end
	end
end

ExtraButtons.UpdateZoneButtons = function(self)
	local frame = ZoneAbilityFrame
	if (not frame) then
		return
	end
	if (frame.Style) then
		frame.Style:SetAlpha(0)
	end
	if (frame.SpellButtonContainer) then
		for button in frame.SpellButtonContainer:EnumerateActive() do
			if (button) then
				self:UpdateButton(button)
			end
		end
	end
end

ExtraButtons.UpdateBindings = function(self)
	if (self.ExtraButtons) then
		for button in pairs(self.ExtraButtons) do
			if (button.HotKey) then
				button.HotKey:SetText(GetBindingKey(button:GetName()))
			end
		end
	end
end

ExtraButtons.OnInitialize = function(self)

	local ExtraAbilityContainer, ExtraActionBarFrame = SetObjectScale(ExtraAbilityContainer), SetObjectScale(ExtraActionBarFrame)
	if (ExtraAbilityContainer and ExtraActionBarFrame) then
		local extraScaffold = SetObjectScale(CreateFrame("Frame", nil, UIParent))
		extraScaffold:SetFrameStrata("LOW")
		extraScaffold:SetFrameLevel(10)
		extraScaffold:SetPoint("BOTTOM", -546, 156)
		extraScaffold:SetSize(64,64)

		-- This might go away in Dragonflight,
		-- as it's moved to a filed called UIParentOld.lua
		if (UIPARENT_MANAGED_FRAME_POSITIONS) then
			UIPARENT_MANAGED_FRAME_POSITIONS.ExtraAbilityContainer = nil
		end
		--ExtraAbilityContainer.SetSize = noop -- taints the editmode
		ExtraAbilityContainer:SetFrameStrata("LOW")
		ExtraAbilityContainer:SetFrameLevel(10)
		ExtraAbilityContainer.ignoreFramePositionManager = true
		ExtraActionBarFrame:SetParent(extraScaffold)
		ExtraActionBarFrame:ClearAllPoints()
		ExtraActionBarFrame:SetAllPoints()
		ExtraActionBarFrame:EnableMouse(false)
		ExtraActionBarFrame.ignoreInLayout = true
		ExtraActionBarFrame.ignoreFramePositionManager = true

		self.ExtraScaffold = extraScaffold
	end

	local ZoneAbilityFrame = SetObjectScale(ZoneAbilityFrame)
	if (ZoneAbilityFrame) then
		local zoneScaffold = SetObjectScale(CreateFrame("Frame", nil, UIParent))
		zoneScaffold:SetFrameStrata("LOW")
		zoneScaffold:SetFrameLevel(10)
		zoneScaffold:SetPoint("BOTTOM", 558, 162)
		zoneScaffold:SetSize(64,64)

		ZoneAbilityFrame.SpellButtonContainer.holder = zoneScaffold
		ZoneAbilityFrame.SpellButtonContainer:SetFrameStrata("LOW")
		ZoneAbilityFrame:SetParent(zoneScaffold)
		ZoneAbilityFrame:ClearAllPoints()
		ZoneAbilityFrame:SetAllPoints()
		ZoneAbilityFrame:EnableMouse(false)
		ZoneAbilityFrame.ignoreInLayout = true
		ZoneAbilityFrame.ignoreFramePositionManager = true

		self.ZoneScaffold = zoneScaffold
		self:SecureHook(ZoneAbilityFrame, "UpdateDisplayedZoneAbilities", "UpdateZoneButtons")
	end

	if (not self.ExtraScaffold) and (not self.ZoneScaffold) then
		self:Disable()
	end
end

ExtraButtons.OnEnable = function(self)
	if (not self.ExtraScaffold) and (not self.ZoneScaffold) then
		return
	end
	self:UpdateExtraButtons()
	self:UpdateZoneButtons()
	self:UpdateBindings()
	self:RegisterEvent("UPDATE_BINDINGS", "UpdateBindings")
end
