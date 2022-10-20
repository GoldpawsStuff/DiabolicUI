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
local Auras = ns:NewModule("Auras", "LibMoreEvents-1.0", "AceTimer-3.0", "AceHook-3.0", "AceConsole-3.0", "LibSmoothBar-1.0")

-- Lua API
local math_ceil = math.ceil
local pairs = pairs
local select = select
local string_format = string.format
local string_lower = string.lower
local table_insert = table.insert

-- WoW API
local CreateFrame = CreateFrame
local GetInventoryItemTexture = GetInventoryItemTexture
local GetTime = GetTime
local GetWeaponEnchantInfo = GetWeaponEnchantInfo
local InCombatLockdown = InCombatLockdown

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

	local time = self.border:CreateFontString(nil, "OVERLAY")
	time:Hide()
	time:SetFontObject(GetFont(18,true))
	time:SetTextColor(Colors.red[1], Colors.red[2], Colors.red[3])
	time:SetPoint("CENTER")
	time:SetIgnoreParentAlpha(true)
	time:SetAlpha(.85)
	--hooksecurefunc(time, "SetFormattedText", function(self)
	--	if (self:GetParent():GetParent():GetParent():GetAlpha() > .1) then
	--		self:SetAlpha(.85)
	--	else
	--		self:SetAlpha(0)
	--	end
	--end)
	self.time = time

	local bar = Auras:CreateSmoothBar(nil, self)
	bar:SetPoint("TOP", self, "BOTTOM", 0, 0)
	bar:SetPoint("LEFT", self, "LEFT", 1, 0)
	bar:SetPoint("RIGHT", self, "RIGHT", -1, 0)
	bar:SetHeight(4)
	bar:SetStatusBarTexture(GetMedia("bar-small"))
	bar:SetStatusBarColor(Colors.xp[1], Colors.xp[2], Colors.xp[3])
	--bar:SetStatusBarColor(Colors.quest.green[1], Colors.quest.green[2], Colors.quest.green[3])
	bar.bg = bar:CreateTexture(nil, "BACKGROUND", nil, -7)
	bar.bg:SetPoint("TOPLEFT", -1, 1)
	bar.bg:SetPoint("BOTTOMRIGHT", 1, -1)
	bar.bg:SetColorTexture(.05, .05, .05, .85)
	self.bar = bar

	local fadeAnimation = self:CreateAnimationGroup()
	fadeAnimation:SetLooping("BOUNCE")

	local fade = fadeAnimation:CreateAnimation("Alpha")
	fade:SetFromAlpha(1)
	fade:SetToAlpha(.5)
	fade:SetDuration(.6)
	fade:SetSmoothing("IN_OUT")

	self.fadeAnimation = fadeAnimation

	-- Using a virtual cooldown element with the bar and timer attached,
	-- allowing them to piggyback on oUF's cooldown updates.
	self.cd = RegisterCooldown(bar, time)

end

Aura.Update = function(self, index)

	local name, icon, count, dispelType, duration, expirationTime, source, isStealable, nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, castByPlayer, nameplateShowAll, timeMod = UnitAura(self:GetParent():GetAttribute("unit"), index, self.filter)

	if (name) then
		self:SetAlpha(1)
		self.icon:SetTexture(icon)
		self.count:SetText((count and count > 1) and count or "")

		if (duration and duration > 0 and expirationTime) then
			self.cd:SetCooldown(expirationTime - duration, duration)
			self.cd:Show()

			local timeLeft = expirationTime - GetTime()

			self.timeLeft = timeLeft
			self:SetScript("OnUpdate", Auras.OnUpdate)

			-- Fade short duration auras in and out
			if (timeLeft < 10) then
				if (not self.fadeAnimation:IsPlaying()) then
					self.fadeAnimation:Play()
				end
				self.time:Show()
			else
				if (self.fadeAnimation:IsPlaying()) then
					self.fadeAnimation:Stop()
				end
				self.time:Hide()
			end

		else
			self.cd:Hide()
			self.time:Hide()
			if (self.fadeAnimation:IsPlaying()) then
				self.fadeAnimation:Stop()
			end
			self:SetScript("OnUpdate", nil)
			self.timeLeft = nil
		end
	else
		self.icon:SetTexture(nil)
		self.count:SetText("")
		self.cd:Hide()
		self.time:Hide()
		if (self.fadeAnimation:IsPlaying()) then
			self.fadeAnimation:Stop()
		end
		self:SetScript("OnUpdate", nil)
		self.timeLeft = nil
	end

end

Aura.UpdateTempEnchant = function(self, slot)
	local enchant = (slot == 16 and 2) or 6
	local expiration = select(enchant, GetWeaponEnchantInfo())
	local icon = GetInventoryItemTexture("player", slot)

	if (icon) then
		self:SetAlpha(1)
		self.icon:SetTexture(icon)
	else
		-- sometimes empty temp enchants are shown
		-- this is a bug in the secure aura headers
		self:SetAlpha(0)
		self.icon:SetTexture(nil)
	end

	if (expiration) then
		self.enchant = enchant
		self.cd:SetCooldown(GetTime(), expiration / 1e3)
		self.cd:Show()
		self:SetScript("OnUpdate", Auras.OnUpdate)
	else
		self.cd:Hide()
		self.enchant = nil
		self.timeLeft = nil
		self:SetScript("OnUpdate", nil)
	end

	self.count:SetText("")

end

Aura.UpdateTooltip = function(self)
	if (GameTooltip:IsForbidden()) then return end
	GameTooltip:SetUnitAura(self:GetParent():GetAttribute("unit"), self:GetID(), self.filter)
end

Auras.OnUpdate = function(self, elapsed)
	self.elapsed = (self.elapsed or 0) - elapsed
	if (self.elapsed > 0) then
		return
	end
	self.elapsed = .01

	local timeLeft
	if (self.enchant) then
		local expiration = select(enchant, GetWeaponEnchantInfo())
		timeLeft = expiration and (expiration / 1e3) or 0
	else
		timeLeft = self.timeLeft - elapsed
	end
	self.timeLeft = timeLeft

	if (timeLeft > 0) then
		if (timeLeft < 10) then
			if (not self.fadeAnimation:IsPlaying()) then
				self.fadeAnimation:Play()
			end
			self.time:Show()
		else
			if (self.fadeAnimation:IsPlaying()) then
				self.fadeAnimation:Stop()
			end
			self.time:Hide()
		end
	else
		self.timeLeft = nil
		self:SetScript("OnUpdate", nil)
	end

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
	local buffs = self.Buffs
	if (not buffs) then
		return
	end
	local child = buffs:GetAttribute("child1")
	local i = 1
	while (child) do
		local func = child[method]
		if (func) then
			func(child, child:GetID(), ...)
		end
		i = i + 1
		child = buffs:GetAttribute("child" .. i)
	end
end

Auras.UpdateConsolidationCount = function(self)
	local buffs = self.Buffs
	if (not buffs) then
		return
	end
	local numChild, child = 0
	repeat
		numChild = numChild + 1
		child = buffs.consolidation:GetAttribute("child" .. numChild)
	until not(child and child:IsShown())
	buffs.proxy.count:SetText(numChild - 1)
end

Auras.UpdateSettings = function(self)
	local visibility = self.Visibility
	if (not visibility) then
		return
	end

	local db = ns.db.char.auras
	if (db.alwaysHideAuras) then
		visibility:SetAttribute("auraMode", -1)
	elseif (db.alwaysShowAuras) then
		visibility:SetAttribute("auraMode", 1)
	else
		visibility:SetAttribute("auraMode", 0)
	end

	visibility:Execute([[ self:RunAttribute("UpdateDriver"); ]])
end

Auras.OnChatCommand = function(self, input)
	if (InCombatLockdown()) then
		return
	end

	local arg1, arg2 = self:GetArgs(string_lower(input))
	local db = ns.db.char.auras

	if (arg1 == "show") then
		db.alwaysShowAuras = true
		db.alwaysHideAuras = false
	elseif (arg1 == "hide") then
		db.alwaysShowAuras = false
		db.alwaysHideAuras = true
	elseif (arg1 == "auto") then
		db.alwaysShowAuras = false
		db.alwaysHideAuras = false
	end

	self:UpdateSettings()
end

Auras.OnEvent = function(self, event, ...)
	if (event == "PLAYER_ENTERING_WORLD") then
		local isInitialLogin, isReloadingUi = ...
		if (isInitialLogin or isReloadingUi) then

		end
		self:ForAll("Update")
		self:UpdateConsolidationCount()

	elseif (event == "UNIT_AURA") then
		self:UpdateConsolidationCount()
	end
end

Auras.OnInitialize = function(self)

	-----------------------------------------
	-- Header
	-----------------------------------------

	local buffs = SetObjectScale(CreateFrame("Frame", ns.Prefix.."BuffHeader", UIParent, "SecureAuraHeaderTemplate"))
	buffs:SetFrameLevel(10)
	buffs:SetSize(36,36)
	buffs:SetPoint("TOPRIGHT", -380, -66)
	buffs:SetAttribute("weaponTemplate", "DiabolicAuraTemplate")
	buffs:SetAttribute("template", "DiabolicAuraTemplate")
	buffs:SetAttribute("minHeight", 36)
	buffs:SetAttribute("minWidth", 36)
	buffs:SetAttribute("point", "TOPRIGHT")
	buffs:SetAttribute("xOffset", -42)
	buffs:SetAttribute("yOffset", 0)
	buffs:SetAttribute("wrapAfter", 6)
	buffs:SetAttribute("wrapXOffset", 0)
	buffs:SetAttribute("wrapYOffset", -48)
	buffs:SetAttribute("filter", "HELPFUL")
	buffs:SetAttribute("includeWeapons", 1)
	buffs:SetAttribute("sortMethod", "TIME")
	buffs:SetAttribute("sortDirection", "-")

	buffs.tooltipPoint = "TOPRIGHT"
	buffs.tooltipAnchor = "BOTTOMLEFT"
	buffs.tooltipOffsetX = -10
	buffs.tooltipOffsetY = -10
	RegisterAttributeDriver(buffs, "unit", "[vehicleui] vehicle; player")

	-----------------------------------------
	-- Consolidation
	-----------------------------------------
	if (ns.IsWrath) then

		buffs.proxy = CreateFrame("Button", buffs:GetName().."ProxyButton", buffs, "SecureUnitButtonTemplate, SecureHandlerEnterLeaveTemplate")
		buffs.proxy:Hide()
		buffs.proxy:SetSize(36,36)
		buffs.proxy:SetIgnoreParentAlpha(true)
		buffs.proxy.texture = buffs.proxy:CreateTexture(nil, "BACKGROUND")
		buffs.proxy.texture:SetSize(64,64)
		buffs.proxy.texture:SetPoint("CENTER")
		buffs.proxy.texture:SetTexture(GetMedia("chatbutton-maximize"))
		buffs.proxy.count = buffs.proxy:CreateFontString(nil, "OVERLAY")
		buffs.proxy.count:SetFontObject(GetFont(12,true))
		buffs.proxy.count:SetTextColor(Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3])
		buffs.proxy.count:SetPoint("BOTTOMRIGHT", -2, 3)

		self:SecureHookScript(buffs.proxy, "OnShow", "UpdateConsolidationCount")

		buffs.consolidation = CreateFrame("Frame", buffs:GetName().."Consolidation", buffs.proxy, "SecureFrameTemplate")
		buffs.consolidation:Hide()
		buffs.consolidation:SetIgnoreParentAlpha(true)
		buffs.consolidation:SetSize(36, 36)
		--buffs.consolidation:SetPoint("TOPRIGHT", buffs.proxy, "BOTTOMRIGHT", 0, -8)
		buffs.consolidation:SetPoint("TOPLEFT", buffs.proxy, "TOPRIGHT", 6, 0)
		buffs.consolidation:SetAttribute("minHeight", nil)
		buffs.consolidation:SetAttribute("minWidth", nil)
		buffs.consolidation:SetAttribute("point", "TOPRIGHT")
		buffs.consolidation:SetAttribute("template", buffs:GetAttribute("template"))
		buffs.consolidation:SetAttribute("weaponTemplate", buffs:GetAttribute("weaponTemplate"))
		buffs.consolidation:SetAttribute("xOffset", buffs:GetAttribute("xOffset"))
		buffs.consolidation:SetAttribute("yOffset", buffs:GetAttribute("yOffset"))
		buffs.consolidation:SetAttribute("wrapAfter", 6)
		buffs.consolidation:SetAttribute("wrapYOffset", buffs:GetAttribute("wrapYOffset"))
		buffs.consolidation.tooltipPoint = buffs.tooltipPoint
		buffs.consolidation.tooltipAnchor = buffs.tooltipAnchor
		buffs.consolidation.tooltipOffsetX = buffs.tooltipOffsetX
		buffs.consolidation.tooltipOffsetY = buffs.tooltipOffsetY

		buffs.dropdown = CreateFrame("Button", "$parentDropDown", buffs.proxy, "SecureHandlerClickTemplate")
		buffs.dropdown:SetAllPoints()
		buffs.dropdown:SetFrameRef("buffs", buffs)
		buffs.dropdown:SetFrameRef("consolidation", buffs.consolidation)
		buffs.dropdown:RegisterForClicks("AnyUp")
		buffs.dropdown:SetAttribute("_onclick", [[
			local consolidation = self:GetFrameRef("consolidation")
			local buffs = self:GetFrameRef("buffs")
			if consolidation:IsShown() then
				consolidation:Hide()
				buffs:SetAlpha(1)
			else
				consolidation:Show()
				buffs:SetAlpha(.5)
			end
		]])

		buffs:SetAttribute("consolidateTo", -1)
		buffs:SetAttribute("consolidateProxy", buffs.proxy)
		buffs:SetAttribute("consolidateHeader", buffs.consolidation)

		-- Auras with less remaining duration than
		-- this many seconds should not be consolidated.
		buffs:SetAttribute("consolidateThreshold", 10) -- default 10

		-- The minimum total duration an aura should
		-- have to be considered for consolidation.
		buffs:SetAttribute("consolidateDuration", 10) -- default 30

		-- The fraction of remaining duration a buff
		-- should still have to be eligible for consolidation.
		buffs:SetAttribute("consolidateFraction", .1) -- default .10

		RegisterAttributeDriver(buffs.consolidation, "unit", "[vehicleui] vehicle; player")

		Auras:RegisterUnitEvent("UNIT_AURA", "UpdateConsolidationCount", "player", "vehicle")
	end

	-----------------------------------------
	-- Visibility
	-----------------------------------------
	local visibility = CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate")
	visibility:SetFrameRef("Buffs", buffs)

	visibility:SetAttribute("UpdateVisibility", [[
		local visdriver = self:GetAttribute("visdriver");
		if (not visdriver) then
			return
		end
		local buffs = self:GetFrameRef("Buffs");
		local shouldhide = SecureCmdOptionParse(visdriver) == "hide";
		local isshown = buffs:IsShown();
		if (shouldhide and isshown) then
			buffs:Hide();
		elseif (not shouldhide and not isshown) then
			buffs:Show();
		end
	]])

	local autodriver = "[petbattle]hide;"
	if (ns.IsWrath) then
		autodriver = autodriver .. "[group,nocombat]show;"
	end
	autodriver = autodriver .. "[mod:ctrl/shift]show;"
	autodriver = autodriver .. "hide"

	visibility:SetAttribute("UpdateDriver", string_format([[
		local visdriver;
		local buffs = self:GetFrameRef("Buffs");
		local auraMode = self:GetAttribute("auraMode");
		if (auraMode == -1) then
			visdriver = "hide";
		elseif (auraMode == 1) then
			visdriver = "[petbattle]hide;show";
		else
			visdriver = "%s";
		end
		self:SetAttribute("visdriver", visdriver);
		UnregisterStateDriver(self, "vis");
		RegisterStateDriver(self, "vis", visdriver);
	]], autodriver))

	visibility:SetAttribute("_onstate-vis", [[
		self:RunAttribute("UpdateVisibility");
	]])


	self.Buffs = buffs
	self.Visibility = visibility

	--self:HookScript(self.Buffs, "OnShow", "UpdateConsolidationCount")

	self:RegisterChatCommand("auras", "OnChatCommand")
end

Auras.OnEnable = function(self)
	self:UpdateSettings()
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
end
