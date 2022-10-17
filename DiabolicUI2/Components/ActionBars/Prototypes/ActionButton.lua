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
local LAB10GE = LibStub("LibActionButton-1.0-GoldpawEdition")

-- Addon API
local GetFont = ns.API.GetFont
local GetMedia = ns.API.GetMedia
local SetObjectScale = ns.API.SetObjectScale
local RegisterCooldown = ns.Widgets.RegisterCooldown
local UIHider = ns.Hider
local noop = ns.Noop

local ActionButton = {}
ns.ActionButton = ActionButton
ns.ActionButtons = {}

local Button_OnEnter = function(self)
	self.icon.darken:SetAlpha(0)
	if (self.OnEnter) then
		self:OnEnter()
	end
end

local Button_OnLeave = function(self)
	self.icon.darken:SetAlpha(.1)
	if (self.OnLeave) then
		self:OnLeave()
	end
end

local Icon_PostSetShown = function(self, isShown)
	self.desaturator:SetShown(isShown)
end

local Icon_PostShow = function(self)
	self.desaturator:Show()
end

local Icon_PostHide = function(self)
	self.desaturator:Hide()
end

local Icon_PostSetAlpha = function(self, alpha)
	self.desaturator:SetAlpha(self.desaturator.alpha or .2)
end

local Icon_PostSetVertexColor = function(self, r, g, b, a)
	self.desaturator:SetVertexColor(r, g, b)
end

local Icon_PostSetTexture = function(self, ...)
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

-- Constructor
ActionButton.Create = function(self, id, name, header, config)

	local button = LAB10GE:CreateButton(id, name, header, config)

	button.icon = button.icon
	button.cooldown = button.cooldown
	button.count = button.Count
	button.hotkey = button.HotKey
	button.macro = button.Name
	button.flash = button.Flash
	--button.flyoutArrowContainer = button.FlyoutArrowContainer -- WoW10
	--button.flyoutBorder = button.FlyoutBorder
	--button.flyoutBorderShadow = button.FlyoutBorderShadow
	--button.levelLinkLockIcon = button.LevelLinkLockIcon -- Retail

	button.AutoCastShine:SetParent(UIHider)
	button.Border:SetParent(UIHider)
	button.NewActionTexture:SetParent(UIHider)
	button.NormalTexture:SetParent(UIHider)
	button.SpellHighlightAnim:Stop()
	button.SpellHighlightTexture:SetParent(UIHider)

	if (button.QuickKeybindHighlightTexture) then
		button.QuickKeybindHighlightTexture:SetParent(UIHider)
	end

	if (ns.WoW10) then
		button.CheckedTexture:SetParent(UIHider)
		button.HighlightTexture:SetParent(UIHider)
		button.BottomDivider:SetParent(UIHider)
		button.RightDivider:SetParent(UIHider)
		button.SlotArt:SetParent(UIHider)
		button.SlotBackground:SetParent(UIHider)
	end

	button:SetAttribute("buttonLock", true)
	button:SetSize(53,53)

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
	button:SetScript("OnEnter", Button_OnEnter)
	button:SetScript("OnLeave", Button_OnLeave)

	hooksecurefunc(button.icon, "SetShown",Icon_PostSetShown)
	hooksecurefunc(button.icon, "Show", Icon_PostShow)
	hooksecurefunc(button.icon, "Hide", Icon_PostHide)
	hooksecurefunc(button.icon, "SetAlpha", Icon_PostSetAlpha)
	hooksecurefunc(button.icon, "SetVertexColor", Icon_PostSetVertexColor)
	hooksecurefunc(button.icon, "SetTexture", Icon_PostSetTexture)

	RegisterCooldown(button.cooldown, button.cooldownCount)

	button.AddToButtonFacade = noop
	button.AddToMasque = noop
	button.SetNormalTexture = noop
	button.SetHighlightTexture = noop
	button.SetCheckedTexture = noop

	ns.ActionButtons[button] = true

	return button
end
