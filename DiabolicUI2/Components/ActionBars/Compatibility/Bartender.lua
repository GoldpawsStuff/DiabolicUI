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
if (not ns.API.IsAddOnEnabled("Bartender4")) then return end

local ActionBars = ns:GetModule("ActionBars")
local Bartender = ActionBars:NewModule("Bartender", "LibMoreEvents-1.0")

-- WoW API
local InCombatLockdown = InCombatLockdown
local UnregisterStateDriver = UnregisterStateDriver

-- Addon API
local IsAddOnLoaded = IsAddOnLoaded
local UIHider = ns.Hider
local noop = ns.Noop

Bartender.HandleMicroMenu = function(self)
	local MicroMenuMod = Bartender4:GetModule("MicroMenu")
	if (not MicroMenuMod) then
		return
	end
	MicroMenuMod:Disable()
	MicroMenuMod:UnhookAll()
end

Bartender.HandlePetBattles = function(self)
	if (Bartender4.petBattleController) then
		UnregisterStateDriver(Bartender4.petBattleController, "petbattle")
		Bartender4.petBattleController:Execute([[ self:ClearBindings(); ]])
	end
	Bartender4.RegisterPetBattleDriver = noop
end

Bartender.HandleVehicle = function(self)
	if (Bartender4.vehicleController) then
		OverrideActionBar:UnregisterAllEvents()
		OverrideActionBar:Hide()
		OverrideActionBar:SetParent(UIHider)
		UnregisterStateDriver(Bartender4.vehicleController, "vehicle")
		Bartender4.vehicleController:Execute([[ self:ClearBindings(); ]])
	end
	Bartender4.UpdateBlizzardVehicle = noop
end

Bartender.HandleBartender = function(self)
	if (InCombatLockdown()) then
		return self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
	end

	self:HandleMicroMenu()
	self:HandlePetBattles()
	self:HandleVehicle()

	ns.BartenderHandled = true
	ns:Fire("Bartender_Handled")
end

Bartender.OnEvent = function(self)
	if (event == "ADDON_LOADED") then
		if ((...) == "Bartender4") then
			self:UnregisterEvent("ADDON_LOADED", "OnEvent")
			self:HandleBartender()
		end
	elseif (event == "PLAYER_REGEN_ENABLED") then
		if (not InCombatLockdown()) then
			self:UnregisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
			self:HandleBartender()
		end
	end
end

Bartender.OnInitialize = function(self)
	if (IsAddOnLoaded("Bartender4")) then
		self:HandleBartender()
	else
		self:RegisterEvent("ADDON_LOADED", "OnEvent")
	end
end
