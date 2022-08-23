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

-- Lua API
local getmetatable = getmetatable
local pairs = pairs
local setmetatable = setmetatable
local type = type

-- WoW API
local CooldownFrame_Set = CooldownFrame_Set
local CreateFrame = CreateFrame
local GameTooltip_SetDefaultAnchor = GameTooltip_SetDefaultAnchor
local GetShapeshiftFormCooldown = GetShapeshiftFormCooldown
local GetShapeshiftFormInfo = GetShapeshiftFormInfo

-- Addon API
local Colors = ns.Colors
local GetFont = ns.API.GetFont
local GetMedia = ns.API.GetMedia
local RegisterCooldown = ns.Widgets.RegisterCooldown

local UIHider = ns.Hider
local noop = ns.Noop

local Button = CreateFrame("CheckButton")
local Button_MT = {__index = Button}

ns.StanceButton = Button 
ns.StanceButtons = {}

Button.Create = function(self, id, header, styleFunc)

	local name = ns.Prefix.."StanceButton"..id
	local button = setmetatable(CreateFrame("CheckButton", name, header, "StanceButtonTemplate"), Button_MT)
	if (styleFunc) then
		styleFunc(button)
	end
	button:Hide()
	button:SetID(id)
	button.id = id
	button.parent = header

	button:SetScript("OnEnter", Button.OnEnter)
	button:SetScript("OnLeave", Button.OnLeave)

	return button
end

Button.OnEnter = function(self)
	if (GameTooltip:IsForbidden()) then
		return
	end
	GameTooltip_SetDefaultAnchor(GameTooltip, self)
	GameTooltip:SetShapeshift(self:GetID())
	self.UpdateTooltip = self.OnEnter
end

Button.OnLeave = function(self)
	if (GameTooltip:IsForbidden()) then
		return
	end
	self.UpdateTooltip = nil
	GameTooltip:Hide()
end

Button.Update = function(self)
	if (not self:IsShown()) then 
		return 
	end
	local id = self:GetID()
	local texture, isActive, isCastable, spellID = GetShapeshiftFormInfo(id)

	self.icon:SetTexture(texture)

	if (texture) then
		self.cooldown:Show()
	else
		self.cooldown:Hide()
	end

	local start, duration, enable = GetShapeshiftFormCooldown(id)
	CooldownFrame_Set(self.cooldown, start, duration, enable)

	if (isActive) then
		self:SetChecked(true)
	else
		self:SetChecked(false)
	end

	if (isCastable) then
		self.icon:SetVertexColor(1, 1, 1)
	else
		self.icon:SetVertexColor(.4, .4, .4)
	end

	self:UpdateHotkeys()

end

Button.UpdateHotkeys = function(self)
end

