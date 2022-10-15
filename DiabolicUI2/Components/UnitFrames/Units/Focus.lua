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
local CreateFrame = CreateFrame

-- Addon API
local GetFont = ns.API.GetFont
local GetMedia = ns.API.GetMedia

UnitStyles["Focus"] = function(self, unit, id)

	self:SetSize(60,72)
	self:SetHitRectInsets(0,0,0,-16)

	local health = self:CreateBar()
	health:SetHeight(9)
	health:SetPoint("TOP", 0, -1)
	health:SetPoint("LEFT", 2, 0)
	health:SetPoint("RIGHT", -2, 0)
	health:SetStatusBarTexture(GetMedia("bar-small"))
	health.colorHealth = true
	health.colorClass = false
	health.colorReaction = true

	self.Health = health
	self.Health.Override = ns.API.UpdateHealth

	local healthBg = health:CreateTexture(nil, "BACKGROUND", nil, -7)
	healthBg:SetPoint("TOPLEFT", -1, 1)
	healthBg:SetPoint("BOTTOMRIGHT", 1, -1)
	healthBg:SetColorTexture(.05, .05, .05, .85)
	self.Health.bg = healthBg

	local name = self:CreateFontString(nil, "OVERLAY", nil, 6)
	name:SetFontObject(GetFont(12,true))
	name:SetJustifyH("CENTER")
	name:SetTextColor(unpack(ns.Colors.offwhite))
	name:SetAlpha(.85)
	name:SetPoint("TOP", self, "BOTTOM", 0, -4)
	name:SetPoint("LEFT", self, -20, 0)
	name:SetPoint("RIGHT", self, 20, 0)
	self:Tag(name, "[Diabolic:Name]")
	self.Name = name

	local portrait = CreateFrame("PlayerModel", nil, self)
	portrait:SetPoint("TOP", 0, -18)
    portrait:SetPoint("BOTTOM", 0, 6)
	portrait:SetPoint("LEFT", 6, 0)
	portrait:SetPoint("RIGHT", -6, 0)
	portrait:SetAlpha(.85)
    self.Portrait = portrait

	local backdrop = portrait:CreateTexture(nil, "BACKGROUND", nil, -7)
	backdrop:SetIgnoreParentAlpha(true)
	backdrop:SetAllPoints()
	backdrop:SetColorTexture(.05, .05, .05, .85)
	self.Portrait.Backdrop = backdrop

	local border = CreateFrame("Frame", nil, portrait, ns.BackdropTemplate)
	border:SetIgnoreParentAlpha(true)
	border:SetBackdrop({ edgeFile = GetMedia("border-aura"), edgeSize = 16 })
	border:SetBackdropBorderColor(unpack(self.colors.cast))
	border:SetPoint("TOPLEFT", -13, 13)
	border:SetPoint("BOTTOMRIGHT", 13, -13)
	border:SetFrameLevel(self:GetFrameLevel() + 2)
	self.Portrait.Border = border

	local cast = self:CreateBar()
	cast:Hide()
	cast:SetFrameLevel(health:GetFrameLevel() + 1)
	cast:SetHeight(9)
	cast:SetPoint("TOP", 0, -1)
	cast:SetPoint("LEFT", 2, 0)
	cast:SetPoint("RIGHT", -2, 0)
	cast:SetStatusBarTexture(GetMedia("bar-small"))
	cast:SetStatusBarColor(1, 1, 1, .25)
	cast:SetSparkTexture(GetMedia("bar-small"))
	cast:DisableSmoothing(true)
	self.Castbar = cast

end