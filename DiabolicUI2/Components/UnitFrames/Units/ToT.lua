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
local UnitStyles = ns.UnitStyles
if (not UnitStyles) then
	return
end

-- WoW API
local UnitIsUnit = UnitIsUnit

-- Addon API
local AbbreviateTime = ns.API.AbbreviateTimeShort
local Colors = ns.Colors
local GetFont = ns.API.GetFont
local GetMedia = ns.API.GetMedia


-- Callbacks
--------------------------------------------
local PostUpdate = function(self)
	local unit = self.unit
	if (not unit) then
		return
	end
	-- Avoid double units.
	-- We don't need to see somebody targeting themselves.
	-- *Will comment this out during development.
	self:SetAlpha((UnitIsUnit(unit, "target") or UnitIsUnit(unit, "player")) and 0 or 1)
end


UnitStyles["ToT"] = function(self, unit, id)

	self:SetFrameLevel(self:GetFrameLevel() + 10)
	self:SetSize(134,24)

	local Bg = self:CreateTexture(nil, "BACKGROUND", nil, -1)
	Bg:SetSize(164,44) -- 164,46
	Bg:SetPoint("CENTER")
	Bg:SetTexture(GetMedia("tot-diabolic"))
	Bg:SetAlpha(1)
	self.Bg = Bg

	local health = self:CreateBar()
	health:SetSize(116,9)
	health:SetPoint("CENTER")
	health:SetStatusBarTexture(GetMedia("statusbars-tot-diabolic"))
	health:GetStatusBarTexture():SetTexCoord(36/256, 220/256, 0/16, 16/16)
	health:SetSparkTexture(GetMedia("blank"))
	health.colorDisconnected = true
	health.colorTapping = true
	health.colorClass = true
	health.colorReaction = true
	health.colorThreat = true
	health.colorHealth = true
	self.Health = health
	self.Health.Override = ns.API.UpdateHealth

	local healthValue = health:CreateFontString(nil, "OVERLAY", nil, 0)
	healthValue:SetFontObject(GetFont(13,true))
	healthValue:SetTextColor(unpack(self.colors.offwhite))
	healthValue:SetAlpha(.85)
	healthValue:SetPoint("CENTER", 0, 0)
	self:Tag(healthValue, "[Diabolic:Health:Smart]")
	self.Health.Value = healthValue

	self.PostUpdate = PostUpdate
	self:RegisterEvent("PLAYER_TARGET_CHANGED", PostUpdate, true)

end
