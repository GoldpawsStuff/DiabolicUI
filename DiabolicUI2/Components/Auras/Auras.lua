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
local SetObjectScale = ns.API.SetObjectScale

-- Callbacks
--------------------------------------------
local Toggle_UpdateAlpha = function(self)
	if (self.mouseOver) or (IsShiftKeyDown() and IsControlKeyDown()) or (self.Window:IsShown()) then
		self:SetAlpha(1)
	else
		self:SetAlpha(0)
	end
end

local Toggle_OnEnter = function(self)
	self.mouseOver = true
	self:UpdateAlpha()
end

local Toggle_OnLeave = function(self)
	self.mouseOver = nil
	self:UpdateAlpha()
end

-- Aura Template
--------------------------------------------
local Aura = {}

Aura.Secure_UpdateTooltip = function(self)
	if (GameTooltip:IsForbidden()) then return end
	GameTooltip:SetUnitAura(self:GetParent():GetAttribute("unit"), self:GetID(), self.filter)
end

Aura.Secure_OnEnter = function(self)
	if (not self:IsVisible()) then return end
	if (GameTooltip:IsForbidden()) then return end
	GameTooltip:SetOwner(self, "ANCHOR_NONE")
	GameTooltip:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 0, 16)
	self:UpdateTooltip()
end

Aura.Secure_OnLeave = function(self)
	if (GameTooltip:IsForbidden()) then return end
	GameTooltip:Hide()
end

Aura.OnAttributeChanged = function(self, attribute, value)
	if (attribute == "index") then
		return self:UpdateAura(value)
	elseif(attribute == "target-slot") then
		return self:UpdateTempEnchant(value)
	end
end

Aura.UpdateAura = function(aura, index)

	local name, icon, count, dispelType, duration, expirationTime, source, isStealable, nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, castByPlayer, nameplateShowAll, timeMod = UnitAura(aura:GetParent():GetAttribute("unit"), index, aura.filter)

	if (name) then
		aura:SetAlpha(1)
		aura.icon:SetTexture(icon)
		aura.count:SetText((count and count > 1) and count or "")

		if (duration and duration > 0) then
			aura.cd:SetCooldown(expirationTime - duration, duration)
			aura.cd:Show()
		else
			aura.cd:Hide()
			aura.bar:Show()
		end
	else
		aura.icon:SetTexture(nil)
		aura.count:SetText("")
		aura.cd:Hide()
	end

end

Aura.UpdateTempEnchant = function(aura, slot)
	local enchant = (slot == 16 and 2) or 6
	local expiration = select(enchant, GetWeaponEnchantInfo())
	local icon = GetInventoryItemTexture("player", slot)

	if (icon) then
		aura:SetAlpha(1)
		aura.icon:SetTexture(icon)
		aura.count:SetText("")

		if (expiration) then
			aura.cd:SetCooldown(GetTime(), expiration / 1e3)
			aura.cd:Show()
		else
			aura.cd:Hide()
		end
	else
		-- sometimes empty temp enchants are shown
		-- this is a bug in the secure aura headers
		aura:SetAlpha(0)
		aura.icon:SetTexture(nil)
		aura.count:SetText("")
		aura.cd:Hide()
	end
end

Aura.Style = function(aura)

	local icon = aura:CreateTexture(nil, "BACKGROUND", nil, 1)
	icon:SetAllPoints()
	icon:SetMask(GetMedia("actionbutton-mask-square"))
	aura.icon = icon

	local border = CreateFrame("Frame", nil, aura, ns.BackdropTemplate)
	border:SetBackdrop({ edgeFile = GetMedia("border-aura"), edgeSize = 12 })
	border:SetBackdropBorderColor(Colors.xp[1], Colors.xp[2], Colors.xp[3])
	border:SetPoint("TOPLEFT", -6, 6)
	border:SetPoint("BOTTOMRIGHT", 6, -6)
	border:SetFrameLevel(aura:GetFrameLevel() + 2)
	aura.border = border

	local count = aura.border:CreateFontString(nil, "OVERLAY")
	count:SetFontObject(GetFont(14,true))
	count:SetTextColor(Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3])
	count:SetPoint("BOTTOMRIGHT", aura, "BOTTOMRIGHT", -2, 3)
	aura.count = count

	local time = aura.border:CreateFontString(nil, "OVERLAY")
	time:SetFontObject(GetFont(14,true))
	time:SetTextColor(Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3])
	time:SetPoint("TOPLEFT", aura, "TOPLEFT", -4, 4)
	aura.time = time

	local bar = Auras:CreateSmoothBar(nil, aura)
	bar:SetPoint("TOP", aura, "BOTTOM", 0, 0)
	bar:SetPoint("LEFT", aura, "LEFT", 1, 0)
	bar:SetPoint("RIGHT", aura, "RIGHT", -1, 0)
	bar:SetHeight(6)
	bar:SetStatusBarTexture(GetMedia("bar-small"))
	bar:SetStatusBarColor(Colors.xp[1], Colors.xp[2], Colors.xp[3])
	bar.bg = bar:CreateTexture(nil, "BACKGROUND", nil, -7)
	bar.bg:SetPoint("TOPLEFT", -1, 1)
	bar.bg:SetPoint("BOTTOMRIGHT", 1, -1)
	bar.bg:SetColorTexture(.05, .05, .05, .85)
	aura.bar = bar

	-- Using a virtual cooldown element with the bar and timer attached,
	-- allowing them to piggyback on oUF's cooldown updates.
	aura.cd = ns.Widgets.RegisterCooldown(bar, time)

end

-- Module API
--------------------------------------------
Auras.UpdateAllAuras = function(self)
	local window = self.Window
	if (not window) then
		return
	end
	local child = window:GetAttribute("child1")
	local i = 1
	while (child) do
		Aura.UpdateAura(child, child:GetID())
		i = i + 1
		child = window:GetAttribute("child" .. i)
	end
end

Auras.Embed = function(self, aura)
	for method,func in pairs(Aura) do
		aura[method] = func
	end
end

Auras.SpawnFrames = function(self, name, parent)

	local window = SetObjectScale(CreateFrame("Frame", ns.Prefix.."BuffHeader", UIParent, "SecureAuraHeaderTemplate"))
	window:SetFrameLevel(10)
	window:SetSize(40, 40)
	window:SetPoint("BOTTOMLEFT", 60, 76)
	window:SetAttribute("weaponTemplate", "DiabolicAuraTemplate")
	window:SetAttribute("template", "DiabolicAuraTemplate")
	window:SetAttribute("minHeight", 40)
	window:SetAttribute("minWidth", 40)
	window:SetAttribute("point", "BOTTOMLEFT")
	window:SetAttribute("xOffset", 44)
	window:SetAttribute("yOffset", 0)
	window:SetAttribute("wrapAfter", 4)
	window:SetAttribute("wrapYOffset", 51)
	window:SetAttribute("filter", "HELPFUL")
	window:SetAttribute("includeWeapons", 1)
	window:SetAttribute("sortMethod", "TIME")
	window:SetAttribute("sortDirection", "+")
	window:HookScript("OnHide", function() self.Toggle:UpdateAlpha() end)
	RegisterAttributeDriver(window, "unit", "[vehicleui] vehicle; player")

	local backdrop = CreateFrame("Frame", ns.Prefix.."BuffHeaderBackdrop", window, ns.BackdropTemplate)
	backdrop:SetPoint("TOPLEFT", -18, 22)
	backdrop:SetPoint("BOTTOMRIGHT", 18, -26)
	backdrop:SetFrameStrata(window:GetFrameStrata())
	backdrop:SetFrameLevel(window:GetFrameLevel()-1)
	backdrop:SetBackdrop({
		bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
		edgeSize = 32, edgeFile = GetMedia("border-tooltip"),
		tile = true,
		insets = { left = 8, right = 8, top = 8, bottom = 8 }
	})
	backdrop:SetBackdropColor(.05, .05, .05, .95)

	local toggle = SetObjectScale(CreateFrame("CheckButton", nil, UIParent, "SecureHandlerClickTemplate"))
	toggle.UpdateAlpha = Toggle_UpdateAlpha
	toggle:SetSize(48,48)
	toggle:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 11, 11)
	toggle:RegisterEvent("MODIFIER_STATE_CHANGED")
	toggle:RegisterEvent("PLAYER_ENTERING_WORLD")
	toggle:RegisterForClicks("AnyUp")
	toggle:SetScript("OnEnter", Toggle_OnEnter)
	toggle:SetScript("OnLeave", Toggle_OnLeave)
	toggle:SetScript("OnEvent", Toggle_UpdateAlpha)
	toggle:SetFrameRef("Window", window)
	toggle:SetAttribute("_onclick", [[
		local window = self:GetFrameRef("Window");
		if (window:IsShown()) then
			window:Hide();
			window:UnregisterAutoHide();
		else
			window:Show();
			window:RegisterAutoHide(.75);
			window:AddToAutoHide(self);
		end
	]])

	local texture = toggle:CreateTexture(nil, "ARTWORK", nil, 0)
	texture:SetSize(64,64)
	texture:SetPoint("CENTER")
	texture:SetTexture(GetMedia("button-toggle-plus"))

	self.Window = window
	self.Window.Backdrop = backdrop
	self.Toggle = toggle
	self.Toggle.Window = window
	self.Toggle.Texture = texture

end

Auras.OnInitialize = function(self)
	self:SpawnFrames()
end

Auras.OnEnable = function(self)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateAllAuras")
end
