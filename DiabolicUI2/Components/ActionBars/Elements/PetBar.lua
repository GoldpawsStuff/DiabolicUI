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
local PetBar = ActionBars:NewModule("PetBar", "LibMoreEvents-1.0")

-- Lua API
local pairs = pairs
local select = select
local setmetatable = setmetatable

-- WoW API
local ClearOverrideBindings = ClearOverrideBindings
local CreateFrame = CreateFrame
local GetBindingKey = GetBindingKey
local InCombatLockdown = InCombatLockdown
local SetOverrideBindingClick = SetOverrideBindingClick

-- Addon API
local GetMedia = ns.API.GetMedia
local SetObjectScale = ns.API.SetObjectScale

local style = function(button)
end

PetBar.SpawnBar = function(self)
	if (not self.Bar) then

		local bar = SetObjectScale(ns.PetBar:Create(ns.Prefix.."PetActionBar", UIParent))
		bar:Hide()
		bar:SetFrameStrata("MEDIUM")
		bar:SetPoint("CENTER", 0, -200)
		bar:SetWidth(11*54 - 1)
		bar:SetHeight(54)

		local button
		for id = 1,10 do
			button = bar:CreateButton(id, bar:GetName().."Button"..id)
			button:SetPoint("BOTTOMLEFT", (id-1)*(54), 0)
			bar:SetFrameRef("Button"..id, button)
			style(button)
		end

		bar:UpdateVisibilityDriver()
		bar:Enable()

		self.Bar = bar
	end
end

PetBar.ForAll = function(self, method, ...)
	if (self.Bar) then
		self.Bar:ForAll(method, ...)
	end
end

PetBar.GetAll = function(self)
	if (self.Bar) then
		return self.Bar:GetAll()
	end
end

PetBar.UpdateBindings = function(self)
	if (self.Bar) then
		self.Bar:UpdateBindings()
	end
end

PetBar.OnEvent = function(self)

	if event == "PET_BAR_UPDATE" or event == "PET_BAR_UPDATE_USABLE" or event == "PET_SPECIALIZATION_CHANGED" or
	  (event == "UNIT_PET" and arg1 == "player") or
	 ((event == "UNIT_FLAGS" or event == "UNIT_AURA") and arg1 == "pet") or
	   event == "PLAYER_CONTROL_LOST" or event == "PLAYER_CONTROL_GAINED" or event == "PLAYER_FARSIGHT_FOCUS_CHANGED" or
	   event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_MOUNT_DISPLAY_CHANGED"
	then
		self:ForAll("Update")

	elseif (event == "PET_BAR_UPDATE_COOLDOWN") then
		self:ForAll("UpdateCooldown")

	elseif (event == "PET_BAR_SHOWGRID") then
		self:ForAll("ShowGrid")

	elseif (event == "PET_BAR_HIDEGRID") then
		self:ForAll("HideGrid")
	end
end

PetBar.OnInitialize = function(self)
	if (not ns.db.global.core.enableDevelopmentMode or not ns.IsDevelopment) then
		self:Disable()
		return
	end
	self:SpawnBar()
end

PetBar.OnEnable = function(self)

	self:RegisterEvent("PLAYER_CONTROL_LOST", "OnEvent")
	self:RegisterEvent("PLAYER_CONTROL_GAINED", "OnEvent")
	self:RegisterEvent("PLAYER_FARSIGHT_FOCUS_CHANGED", "OnEvent")
	self:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED", "OnEvent")
	self:RegisterEvent("PLAYER_TARGET_CHANGED", "OnEvent")
	self:RegisterEvent("UNIT_PET", "OnEvent")
	self:RegisterEvent("UNIT_FLAGS", "OnEvent")
	self:RegisterEvent("UNIT_AURA", "OnEvent")
	self:RegisterEvent("PET_BAR_UPDATE", "OnEvent")
	self:RegisterEvent("PET_BAR_UPDATE_COOLDOWN", "OnEvent")
	self:RegisterEvent("PET_BAR_UPDATE_USABLE", "OnEvent")
	self:RegisterEvent("PET_BAR_SHOWGRID", "OnEvent")
	self:RegisterEvent("PET_BAR_HIDEGRID", "OnEvent")

	if (not ns.IsClassic) then
		self:RegisterEvent("PET_SPECIALIZATION_CHANGED", "OnEvent")
	end

	self:RegisterEvent("UPDATE_BINDINGS", "UpdateBindings")
	self:UpdateBindings()

end
