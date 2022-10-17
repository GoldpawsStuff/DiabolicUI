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
local KeyBound = LibStub("LibKeyBound-1.0")

-- Lua API
local select = select
local setmetatable = setmetatable
local string_format = string.format

-- WoW API
local AutoCastShine_AutoCastStart = AutoCastShine_AutoCastStart
local AutoCastShine_AutoCastStop = AutoCastShine_AutoCastStop
local CooldownFrame_Set = CooldownFrame_Set
local GetBindingKey = GetBindingKey
local GetBindingText = GetBindingText
local GetPetActionInfo = GetPetActionInfo
local GetPetActionCooldown = GetPetActionCooldown
local GetPetActionsUsable = GetPetActionsUsable
local InCombatLockdown = InCombatLockdown
local IsAltKeyDown = IsAltKeyDown
local IsControlKeyDown = IsControlKeyDown
local IsModifiedClick = IsModifiedClick
local IsShiftKeyDown = IsShiftKeyDown
local PickupPetAction = PickupPetAction
local SetBinding = SetBinding
local SetDesaturation = SetDesaturation

ns.PetButtons = {}

local OnEnter = function(self, ...)
	self:OnEnter(...)
end

local OnDragStart = function(self)
	if InCombatLockdown() then
		return
	end
	if (IsAltKeyDown() and IsControlKeyDown() or IsShiftKeyDown()) or (IsModifiedClick("PICKUPACTION")) then
		self:SetChecked(false)
		PickupPetAction(self.id)
		self:Update()
	end
end

local OnReceiveDrag = function(self)
	if InCombatLockdown() then return end
	self:SetChecked(false)
	PickupPetAction(self.id)
	self:Update()
end

local PetButton = CreateFrame("CheckButton")
local PetButton_MT = { __index = PetButton }

PetButton.Update = function(self)
	local name, texture, isToken, isActive, autoCastAllowed, autoCastEnabled, spellID = GetPetActionInfo(self.id)

	if not isToken then
		self.icon:SetTexture(texture)
		self.tooltipName = name;
	else
		self.icon:SetTexture(_G[texture])
		self.tooltipName = _G[name]
	end

	self.isToken = isToken
	self:SetChecked(isActive)
	if autoCastAllowed and not autoCastEnabled then
		self.AutoCastable:Show()
		AutoCastShine_AutoCastStop(self.AutoCastShine)
	elseif autoCastAllowed then
		self.AutoCastable:Hide()
		AutoCastShine_AutoCastStart(self.AutoCastShine)
	else
		self.AutoCastable:Hide()
		AutoCastShine_AutoCastStop(self.AutoCastShine)
	end

	if texture then
		if GetPetActionsUsable() then
			SetDesaturation(self.icon, nil)
		else
			SetDesaturation(self.icon, 1)
		end
		self.icon:Show()
		--self.normalTexture:SetTexture("Interface\\Buttons\\UI-Quickslot2")
		--self.normalTexture:SetTexCoord(0, 0, 0, 0)
		self:ShowButton()
		--self.normalTexture:Show()
		if self.overlay then
			self.overlay:Show()
		end
	else
		self.icon:Hide()
		--.normalTexture:SetTexture("Interface\\Buttons\\UI-Quickslot")
		--self.normalTexture:SetTexCoord(-0.1, 1.1, -0.1, 1.12)
		self:HideButton()
		if self.showgrid == 0 and not self.parent.config.showgrid then
			--self.normalTexture:Hide()
			if self.overlay then
				self.overlay:Hide()
			end
		end
	end
	self:UpdateCooldown()
	self:UpdateHotkeys()
end

PetButton.UpdateHotkeys = function(self)
	local key = self:GetHotkey() or ""
	local hotkey = self.HotKey

	if key == "" or self.parent.config.hidehotkey then
		hotkey:Hide()
	else
		hotkey:SetText(key)
		hotkey:Show()
	end
end

PetButton.ShowButton = function(self)
	self.pushedTexture:SetTexture(self.textureCache.pushed)
	self.highlightTexture:SetTexture(self.textureCache.highlight)
	self:SetAlpha(1.0)
end

PetButton.HideButton = function(self)
	self.textureCache.pushed = self.pushedTexture:GetTexture()
	self.textureCache.highlight = self.highlightTexture:GetTexture()

	self.pushedTexture:SetTexture("")
	self.highlightTexture:SetTexture("")

	if self.showgrid == 0 and not self.parent.config.showgrid then
		self:SetAlpha(0.0)
	end
end

PetButton.ShowGrid = function(self)
	self.showgrid = self.showgrid + 1
	--self.normalTexture:Show()
	self:SetAlpha(1.0)
end

PetButton.HideGrid = function(self)
	if self.showgrid > 0 then self.showgrid = self.showgrid - 1 end
	if self.showgrid == 0  and not (GetPetActionInfo(self.id)) and not self.parent.config.showgrid then
		--self.normalTexture:Hide()
		self:SetAlpha(0.0)
	end
end

PetButton.UpdateCooldown = function(self)
	local start, duration, enable = GetPetActionCooldown(self.id)
	CooldownFrame_Set(self.cooldown, start, duration, enable)
end

PetButton.GetHotkey = function(self)
	local key = GetBindingKey(format("BONUSACTIONBUTTON%d", self.id)) or GetBindingKey("CLICK "..self:GetName()..":LeftButton")
	return key and KeyBound:ToShortKey(key)
end

PetButton.GetBindings = function(self)
	local keys, binding = ""

	binding = string_format("BONUSACTIONBUTTON%d", self.id)
	for i = 1, select("#", GetBindingKey(binding)) do
		local hotKey = select(i, GetBindingKey(binding))
		if (keys ~= "") then
			keys = keys .. ", "
		end
		keys = keys .. GetBindingText(hotKey,"KEY_")
	end

	binding = "CLICK "..self:GetName()..":LeftButton"
	for i = 1, select("#", GetBindingKey(binding)) do
		local hotKey = select(i, GetBindingKey(binding))
		if (keys ~= "") then
			keys = keys .. ", "
		end
		keys = keys.. GetBindingText(hotKey,"KEY_")
	end

	return keys
end

PetButton.SetKey = function(self, key)
	SetBinding(key, string_format("BONUSACTIONBUTTON%d", self.id))
end

PetButton.ClearBindings = function(self)
	local binding = string_format("BONUSACTIONBUTTON%d", self:GetID())
	while GetBindingKey(binding) do
		SetBinding(GetBindingKey(binding), nil)
	end

	binding = "CLICK "..self:GetName()..":LeftButton"
	while GetBindingKey(binding) do
		SetBinding(GetBindingKey(binding), nil)
	end
end

ActionBars.CreatePetButton = function(self, id, name, parent)

	local button = setmetatable(CreateFrame("CheckButton", name, parent, "PetActionButtonTemplate"), PetButton_MT)
	button.showgrid = 0
	button.id = id
	button.parent = parent

	button:SetFrameStrata("MEDIUM")
	button:SetID(id)

	button:UnregisterAllEvents()
	button:SetScript("OnEvent", nil)

	button.OnEnter = button:GetScript("OnEnter")
	button:SetScript("OnEnter", OnEnter)
	button:SetScript("OnDragStart", OnDragStart)
	button:SetScript("OnReceiveDrag", OnReceiveDrag)

	button:SetNormalTexture("")

	button.pushedTexture = button:GetPushedTexture()
	button.highlightTexture = button:GetHighlightTexture()

	button.textureCache = {}
	button.textureCache.pushed = button.pushedTexture:GetTexture()
	button.textureCache.highlight = button.highlightTexture:GetTexture()

	return button

end
