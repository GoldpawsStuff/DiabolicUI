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
local Auras = ns:NewModule("Auras", "LibMoreEvents-1.0", "AceTimer-3.0", "AceHook-3.0", "LibSmoothBar-1.0")

-- Lua API
local pairs = pairs
local select = select
local table_insert = table.insert

-- WoW API
local CreateFrame = CreateFrame
local GetInventoryItemTexture = GetInventoryItemTexture
local GetWeaponEnchantInfo = GetWeaponEnchantInfo

-- Addon API
local Colors = ns.Colors
local GetFont = ns.API.GetFont
local GetMedia = ns.API.GetMedia
local RegisterCooldown = ns.Widgets.RegisterCooldown
local SetObjectScale = ns.API.SetObjectScale

-- Aura Template
--------------------------------------------
local Aura = {}

Aura.Style = function(self)

	local icon = self:CreateTexture(nil, "BACKGROUND", nil, 1)
	icon:SetAllPoints()
	icon:SetMask(GetMedia("actionbutton-mask-square"))
	icon:SetVertexColor(.75, .75, .75)
	self.icon = icon

	local border = CreateFrame("Frame", nil, self, ns.BackdropTemplate)
	border:SetBackdrop({ edgeFile = GetMedia("border-aura"), edgeSize = 12 })
	border:SetBackdropBorderColor(Colors.verydarkgray[1], Colors.verydarkgray[2], Colors.verydarkgray[3])
	border:SetPoint("TOPLEFT", -6, 6)
	border:SetPoint("BOTTOMRIGHT", 6, -6)
	border:SetFrameLevel(self:GetFrameLevel() + 2)
	self.border = border

	local count = self.border:CreateFontString(nil, "OVERLAY")
	count:SetFontObject(GetFont(12,true))
	count:SetTextColor(Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3])
	count:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -2, 3)
	self.count = count

	local bar = Auras:CreateSmoothBar(nil, self)
	bar:SetPoint("TOP", self, "BOTTOM", 0, 0)
	bar:SetPoint("LEFT", self, "LEFT", 1, 0)
	bar:SetPoint("RIGHT", self, "RIGHT", -1, 0)
	bar:SetHeight(4)
	bar:SetStatusBarTexture(GetMedia("bar-small"))
	bar:SetStatusBarColor(Colors.xp[1], Colors.xp[2], Colors.xp[3])
	bar.bg = bar:CreateTexture(nil, "BACKGROUND", nil, -7)
	bar.bg:SetPoint("TOPLEFT", -1, 1)
	bar.bg:SetPoint("BOTTOMRIGHT", 1, -1)
	bar.bg:SetColorTexture(.05, .05, .05, .85)
	self.bar = bar

	-- Using a virtual cooldown element with the bar and timer attached,
	-- allowing them to piggyback on oUF's cooldown updates.
	self.cd = RegisterCooldown(bar)

end

Aura.Update = function(self, index)

	local name, icon, count, dispelType, duration, expirationTime, source, isStealable, nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, castByPlayer, nameplateShowAll, timeMod = UnitAura(self:GetParent():GetAttribute("unit"), index, self.filter)

	if (name) then
		self:SetAlpha(1)
		self.icon:SetTexture(icon)
		self.count:SetText((count and count > 1) and count or "")

		if (duration and duration > 0) then
			self.cd:SetCooldown(expirationTime - duration, duration)
			self.cd:Show()
		else
			self.cd:Hide()
			--if (self.bar) then
			--	self.bar:Show()
			--end
		end
	else
		self.icon:SetTexture(nil)
		self.count:SetText("")
		self.cd:Hide()
	end

end

Aura.UpdateTempEnchant = function(self, slot)
	local enchant = (slot == 16 and 2) or 6
	local expiration = select(enchant, GetWeaponEnchantInfo())
	local icon = GetInventoryItemTexture("player", slot)

	if (icon) then
		self:SetAlpha(1)
		self.icon:SetTexture(icon)
		self.count:SetText("")

		if (expiration) then
			self.cd:SetCooldown(GetTime(), expiration / 1e3)
			self.cd:Show()
		else
			self.cd:Hide()
			--if (self.bar) then
			--	self.bar:Show()
			--end
		end
	else
		-- sometimes empty temp enchants are shown
		-- this is a bug in the secure aura headers
		self:SetAlpha(0)
		self.icon:SetTexture(nil)
		self.count:SetText("")
		self.cd:Hide()
	end
end

Aura.UpdateTooltip = function(self)
	if (GameTooltip:IsForbidden()) then return end
	GameTooltip:SetUnitAura(self:GetParent():GetAttribute("unit"), self:GetID(), self.filter)
end

Aura.OnEnter = function(self)
	if (not self:IsVisible()) then return end
	if (GameTooltip:IsForbidden()) then return end
	local p = self:GetParent()
	GameTooltip:SetOwner(self, "ANCHOR_NONE")
	GameTooltip:SetPoint(p.tooltipPoint, self, p.tooltipAnchor, p.tooltipOffsetX, p.tooltipOffsetY)
	self:UpdateTooltip()
end

Aura.OnLeave = function(self)
	if (GameTooltip:IsForbidden()) then return end
	GameTooltip:Hide()
end

Aura.OnAttributeChanged = function(self, attribute, value)
	if (attribute == "index") then
		return self:Update(value)
	elseif(attribute == "target-slot") then
		return self:UpdateTempEnchant(value)
	end
end

Aura.OnInitialize = function(self)
	self:Style()
	self.filter = self:GetParent():GetAttribute("filter")
	self.UpdateTooltip = self.UpdateTooltip
	self:SetScript("OnEnter", self.OnEnter)
	self:SetScript("OnLeave", self.OnLeave)
	self:SetScript("OnAttributeChanged", self.OnAttributeChanged)
end

-- Module API
--------------------------------------------
Auras.Embed = function(self, aura)
	for method,func in pairs(Aura) do
		aura[method] = func
	end
end

Auras.ForAll = function(self, method, ...)
	local window = self.Window
	if (not window) then
		return
	end
	local child = window:GetAttribute("child1")
	local i = 1
	while (child) do
		local func = child[method]
		if (func) then
			func(child, child:GetID(), ...)
		end
		i = i + 1
		child = window:GetAttribute("child" .. i)
	end
end

Auras.OnEvent = function(self, event, ...)
	if (event == "PLAYER_ENTERING_WORLD") then
		local isInitialLogin, isReloadingUi = ...
		if (isInitialLogin or isReloadingUi) then
			self.Window:Show()
		end
		self:ForAll("Update")
	end
end

Auras.OnInitialize = function(self)

	local window = SetObjectScale(CreateFrame("Frame", ns.Prefix.."BuffHeader", UIParent, "SecureAuraHeaderTemplate"))
	window:SetFrameLevel(10)
	window:SetSize(36,36)
	window:SetPoint("TOPRIGHT", -380, -66)
	window:SetAttribute("weaponTemplate", "DiabolicAuraTemplate")
	window:SetAttribute("template", "DiabolicAuraTemplate")
	window:SetAttribute("minHeight", 36)
	window:SetAttribute("minWidth", 36)
	window:SetAttribute("point", "BOTTOMLEFT")
	window:SetAttribute("xOffset", 42)
	window:SetAttribute("yOffset", 0)
	window:SetAttribute("wrapAfter", 8)
	window:SetAttribute("wrapYOffset", 48)
	window:SetAttribute("filter", "HELPFUL")
	window:SetAttribute("includeWeapons", 1)
	window:SetAttribute("sortMethod", "TIME")
	window:SetAttribute("sortDirection", "+")
	window.tooltipPoint = "TOPRIGHT"
	window.tooltipAnchor = "BOTTOMLEFT"
	window.tooltipOffsetX = -10
	window.tooltipOffsetY = -10
	RegisterAttributeDriver(window, "unit", "[vehicleui] vehicle; player")

	self.Window = window
end

Auras.OnEnable = function(self)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
end
