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
local UnitFrames = ns:NewModule("UnitFrames", "LibMoreEvents-1.0")
local oUF = ns.oUF

-- Globally available registries
ns.UnitStyles = {}
ns.NamePlates = {}

-- Lua API
local string_format = string.format
local string_match = string.match
local table_insert = table.insert

-- WoW API
local C_NamePlate = C_NamePlate
local CreateFrame = CreateFrame
local hooksecurefunc = hooksecurefunc
local InCombatLockdown = InCombatLockdown
local IsInInstance = IsInInstance
local SetCVar = SetCVar
local UnitIsUnit = UnitIsUnit

-- Addon API
local SetObjectScale = ns.API.SetObjectScale
local SetEffectiveObjectScale = ns.API.SetEffectiveObjectScale
local IsAddOnEnabled = ns.API.IsAddOnEnabled

-- NamePlates
-----------------------------------------------------
local cvars = {
	-- Visibility
	-- *Don't adjust these, let the user decide.
	--["nameplateShowAll"] = 1, -- 0 = only in combat, 1 = always
	--["nameplateShowEnemies"] = 1, -- applies to all enemies and players
	--["nameplateShowEnemyGuardians"] = 0,
	--["nameplateShowEnemyMinions"] = 0,
	--["nameplateShowEnemyMinus"] = 1, -- Small azerite oozes and similar. useful.
	--["nameplateShowEnemyPets"] = 0,
	--["nameplateShowEnemyTotems"] = 0,
	--["nameplateShowFriends"] = 0, -- applies to all friendly units
	--["nameplateShowFriendlyPets"] = 0,
	--["nameplateShowFriendlyGuardians"] = 0,
	--["nameplateShowFriendlyMinions"] = 0,
	--["nameplateShowFriendlyTotems"] = 0,
	--["nameplateShowFriendlyNPCs"] = 1,
	--["nameplateOtherAtBase"] = 0,
	--["showVKeyCastbarOnlyOnTarget"] = 0, -- blizzard nameplate castbars. we use others.

	-- Personal Resource Display
	-- *Don't adjust these, let the user decide.
	--["nameplateShowSelf"] = 0, -- Show the Personal Resource Display
	--["NameplatePersonalShowAlways"] = 0, -- Determines if the the personal nameplate is always shown.
	--["NameplatePersonalShowInCombat"] = 0, -- Determines if the the personal nameplate is shown when you enter combat.
	--["NameplatePersonalShowWithTarget"] = 0, -- 0 = targeting has no effect, 1 = show on hostile target, 2 = show on any target
	--["nameplateResourceOnTarget"] = 0, -- Nameplate class resource overlay mode. 0=self, 1=target

	-- If these are enabled the GameTooltip will become protected,
	-- and all sort of taints and bugs will occur.
	-- This happens on specs that can dispel when hovering over nameplate auras.
	-- We create our own auras anyway, so we don't need these.
	["nameplateShowDebuffsOnFriendly"] = 0,

	["nameplateLargeTopInset"] = .25, -- default .1
	["nameplateOtherTopInset"] = .25, -- default .08
	["nameplateLargeBottomInset"] = .15, -- default .15
	["nameplateOtherBottomInset"] = .15, -- default .1
	["nameplateClassResourceTopInset"] = 0,

	-- new CVar July 14th 2020. Wohoo! Thanks torhaala for telling me! :)
	-- *has no effect in retail. probably for the classics only.
	["clampTargetNameplateToScreen"] = 1,

	-- Nameplate scale
	["nameplateMinScale"] = .6, -- .8
	["nameplateMaxScale"] = 1,
	["nameplateLargerScale"] = 1, -- Scale modifier for large plates, used for important monsters
	["nameplateGlobalScale"] = 1,
	["NamePlateHorizontalScale"] = 1,
	["NamePlateVerticalScale"] = 1,

	["nameplateOccludedAlphaMult"] = .15, -- .4
	["nameplateSelectedAlpha"] = 1, -- 1

	-- The maximum distance from the camera where plates will still have max scale and alpha
	["nameplateMaxScaleDistance"] = 10, -- 10

	-- The distance from the max distance that nameplates will reach their minimum scale.
	-- *seems to be a limit on how big this can be, too big resets to 1 it seems?
	["nameplateMinScaleDistance"] = 10, -- 10

	-- The minimum alpha of nameplates.
	["nameplateMinAlpha"] = .4, -- 0.6

	-- The distance from the max distance that nameplates will reach their minimum alpha.
	["nameplateMinAlphaDistance"] = 10, -- 10

	-- 	The max alpha of nameplates.
	["nameplateMaxAlpha"] = 1, -- 1

	-- The distance from the camera that nameplates will reach their maximum alpha.
	["nameplateMaxAlphaDistance"] = 30, -- 40

	-- Show nameplates above heads or at the base (0 or 2,
	["nameplateOtherAtBase"] = 0,

	-- Scale and Alpha of the selected nameplate (current target,
	["nameplateSelectedScale"] = 1, -- 1.2

	-- The max distance to show nameplates.
	--["nameplateMaxDistance"] = 60, -- 20 is classic upper limit, 60 is BfA default

	-- The max distance to show the target nameplate when the target is behind the camera.
	["nameplateTargetBehindMaxDistance"] = 15 -- 15
}

local callback = function(self, event, unit)
	if (event == "PLAYER_TARGET_CHANGED") then
	elseif (event == "NAME_PLATE_UNIT_ADDED") then
		self.isPRD = UnitIsUnit(unit, "player")
		ns.NamePlates[self] = true
	elseif (event == "NAME_PLATE_UNIT_REMOVED") then
		self.isPRD = nil
	end
end

local UnitSpecific = function(self, unit)
	local id, style
	if (unit == "player") then
		style = "Player"

	elseif (unit == "target") then
		style = "Target"

	elseif (unit == "targettarget") then
		style = "ToT"

	elseif (unit == "pet") then
		style = "Pet"

	elseif (unit == "focus") then
		style = "Focus"

	elseif (unit == "focustarget") then
		style = "FocusTarget"

	elseif (string_match(unit, "party%d?$")) then
		id = string_match(unit, "party(%d)")
		style = "Party"

	elseif (string_match(unit, "raid%d+$")) then
		id = string_match(unit, "raid(%d+)")
		style = "Raid"

	elseif (string_match(unit, "boss%d?$")) then
		id = string_match(unit, "boss(%d)")
		style = "Boss"

	elseif (string_match(unit, "arena%d?$")) then
		id = string_match(unit, "arena(%d)")
		style = "Arena"

	elseif (string_match(unit, "nameplate%d+$")) then
		id = string_match(unit, "nameplate(%d+)")
		style = "NamePlate"
	end

	if (style and ns.UnitStyles[style]) then
		return ns.UnitStyles[style](self, unit, id)
	end
end

local OnEnter = function(self, ...)
	self.isMouseOver = true
	if (self.OnEnter) then
		self:OnEnter(...)
	end
	if (self.isUnitFrame) then
		return _G.UnitFrame_OnEnter(self, ...)
	end
end

local OnLeave = function(self, ...)
	self.isMouseOver = nil
	if (self.OnLeave) then
		self:OnLeave(...)
	end
	if (self.isUnitFrame) then
		return _G.UnitFrame_OnLeave(self, ...)
	end
end

local OnHide = function(self, ...)
	self.isMouseOver = nil
	if (self.OnHide) then
		self:OnHide(...)
	end
end

UnitFrames.RegisterStyles = function(self)

	oUF:RegisterStyle("Diabolic", function(self, unit)

		SetObjectScale(self)

		self:RegisterForClicks("LeftButtonDown", "RightButtonDown")
		self:SetScript("OnEnter", OnEnter)
		self:SetScript("OnLeave", OnLeave)
		self:SetScript("OnHide", OnHide)
		self.colors = ns.Colors
		self.isUnitFrame = true

		return UnitSpecific(self, unit)
	end)

	oUF:RegisterStyle("DiabolicNamePlates", function(self, unit)

		SetEffectiveObjectScale(self)

		self:SetPoint("CENTER",0,0)
		self.colors = ns.Colors
		self.isNamePlate = true

		return UnitSpecific(self, unit)
	end)

end

UnitFrames.RegisterMetaFunctions = function(self)
	local LibSmoothBar = LibStub("LibSmoothBar-1.0")
	local LibOrb = LibStub("LibOrb-1.0")

	oUF:RegisterMetaFunction("CreateBar", function(self, name, parent, ...)
		return LibSmoothBar:CreateSmoothBar(name, parent or self, ...)
	end)

	oUF:RegisterMetaFunction("CreateOrb", function(self, name, parent, ...)
		return LibOrb:CreateOrb(name, parent or self, ...)
	end)
end

UnitFrames.GetDockManager = function(self)
	if (not self.dockManager) then

		local dockManager = CreateFrame("Frame", ns.Prefix.."UnitFrameDockManager", UIParent, "SecureHandlerAttributeTemplate")
		dockManager:Execute([=[ Frames = table.new(); ]=])
		dockManager:SetAttribute("_onattributechanged", [=[

			if (strfind(name, "state%-dock")) then

				-- Retrieve current layout data.
				local initialX, initialY = self:GetAttribute("initialX") or 0, self:GetAttribute("initialY") or 0;
				local paddingX, paddingY = self:GetAttribute("paddingX") or 0, self:GetAttribute("paddingY") or 0;
				local maxRows, maxCols = self:GetAttribute("maxRows") or 0, self:GetAttribute("maxCols") or 0;

				-- Figure out initial growth direction.
				local growthDirection = self:GetAttribute("growthDirection");
				if (not growthDirection) or (growthDirection == "smart") then
					local groupType = PlayerInGroup();
					if (groupType) then
						growthDirection = "horizontal";
					else
						growthDirection = "vertical";
					end
				end

				--local hasPet;
				local col, row = 1, 1;

				for _,ref in ipairs(Frames) do
					local frame = self:GetFrameRef(ref);

					-- This will happen prior to unitwatch doing the showing/hiding.
					local unit = frame:GetAttribute("unit");

					-- Might be caught between unit swaps,
					-- so let's just check those using the same frame.
					local exists = UnitExists(unit);
					if (not exists) then
						if (unit == "pet") then
							exists = UnitExists("vehicle");
						elseif (unit == "vehicle") then
							exists = UnitExists("pet");
						end
					end
					if (exists) then

						--local skip;
						--if (unit == "pet") or (unit == "vehicle") then
						--	skip = hasPet;
						--	hasPet = true;
						--end

						--if (not skip) then
							-- Place the current frame in our grid.
							local offsetX = initialX + ((col-1) * paddingX);
							local offsetY = initialY + ((row-1) * paddingY);

							-- Anchorpoint is required when inside the restricted environment.
							frame:ClearAllPoints();
							frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", offsetX, offsetY);

							-- Decide growth by the group status.
							-- *Note that only the maximum for
							-- the growth direction will be obeyed.
							if (growthDirection == "vertical") then
								row = row + 1;
								if (row > maxRows) then
									col = col + 1;
									row = 0;
								end
							else
								col = col + 1;
								if (col > maxCols) then
									row = row + 1;
									col = 0;
								end
							end
						--end
					end
				end
			end
		]=])

		RegisterAttributeDriver(dockManager, "state-dock-group", "[group:party]party;[group:raid]raid;[nogroup]solo")

		self.dockManager = dockManager
	end
	return self.dockManager
end

UnitFrames.SpawnUnitFrames = function(self)


	oUF:Factory(function(oUF)
		oUF:SetActiveStyle("Diabolic")

		local prefix = ns.Prefix.."UnitFrame"

		-- Spawn the individual frames.
		oUF:Spawn("player", prefix.."Player"):SetPoint("BOTTOM", -440, 6)
		oUF:Spawn("target", prefix.."Target"):SetPoint("TOP", 0, -40)
		oUF:Spawn("targettarget", prefix.."TargetOfTarget"):SetPoint("CENTER", _G[prefix.."Target"], "CENTER", 0, -24)
		--oUF:Spawn("targettarget", prefix.."TargetOfTarget"):SetPoint("LEFT", _G[prefix.."Target"], "RIGHT", 0, 0)
		oUF:Spawn("pet", prefix.."Pet")
		oUF:Spawn("focus", prefix.."Focus")

		-- Retrieve the dock manager.
		local dockManager = self:GetDockManager()

		-- Set basic layout values.
		dockManager:SetAttribute("initialX", 40)
		dockManager:SetAttribute("initialY", -40)
		dockManager:SetAttribute("paddingX", 60)
		dockManager:SetAttribute("paddingY", -102)
		dockManager:SetAttribute("maxRows", 4)
		dockManager:SetAttribute("maxCols", 6)

		-- Reference the frames to be docked.
		dockManager:SetFrameRef("Pet", _G[prefix.."Pet"])
		dockManager:SetFrameRef("Focus", _G[prefix.."Focus"])

		-- Append the frames to the layout cache.
		-- The order we insert them into the table
		-- decides the order in which they are placed.
		dockManager:Execute([=[
			table.insert(Frames, "Pet");
			table.insert(Frames, "Focus");
		]=])

		-- Register macro conditionals to inform the dock manager about changes requiring updates.
		RegisterAttributeDriver(dockManager, "state-dock-pet", "[@vehicle,exists][@pet,exists]show;hide")
		RegisterAttributeDriver(dockManager, "state-dock-focus", "[@focus,exists]show;hide")

		-- Inform the environment that frames have been created and initialized.
		-- We're intentionally starting with the dock manager to allow changes to it prior to the dockable frames.
		ns:Fire("UnitFrame_DockManager_Initialized", ns.Prefix.."UnitFrameDockManager")
		ns:Fire("UnitFrame_Created", "player", prefix.."Player")
		ns:Fire("UnitFrame_Created", "target", prefix.."Target")
		ns:Fire("UnitFrame_Created", "targettarget", prefix.."TargetOfTarget")
		ns:Fire("UnitFrame_Created", "pet", prefix.."Pet")
		ns:Fire("UnitFrame_Created", "focus", prefix.."Focus")

	end)
end

UnitFrames.SpawnGroupFrames = function(self)
	oUF:Factory(function(oUF)
		oUF:SetActiveStyle("Diabolic")

		-- oUF:SpawnHeader(overrideName, overrideTemplate, visibility, attributes ...)
		--local party = oUF:SpawnHeader(nil, nil, "raid,party,solo",
		--		-- http://wowprogramming.com/docs/secure_template/Group_Headers
		--		-- Set header attributes
		--		"showParty", true,
		--		"showPlayer", true,
		--		"yOffset", -20
		--)
		--party:SetPoint("TOPLEFT", 30, -30)
	end)
end

UnitFrames.SpawnNamePlates = function(self)
	-- Bail out if any known nameplate addon is enabled.
	for addon in pairs({
		["Kui_Nameplates"] = true,
		["NamePlateKAI"] = true,
		["NeatPlates"] = true,
		["Plater"] = true,
		["SimplePlates"] = true,
		["TidyPlates"] = true,
		["TidyPlates_ThreatPlates"] = true,
		["TidyPlatesContinued"] = true
	}) do
		if (IsAddOnEnabled(addon)) then
			return
		end
	end
	oUF:Factory(function(oUF)
		oUF:SetActiveStyle("DiabolicNamePlates")
		oUF:SpawnNamePlates(ns.Prefix, callback, cvars)
		self:KillNamePlateClutter()
	end)
end

UnitFrames.KillNamePlateClutter = function(self)
	local NamePlateDriverFrame = _G.NamePlateDriverFrame
	if (not NamePlateDriverFrame) then
		return
	end

	local BlizzPlateManaBar = ClassNameplateManaBarFrame -- NamePlateDriverFrame.classNamePlatePowerBar
	if (BlizzPlateManaBar) then
		--BlizzPlateManaBar:Hide()
		--BlizzPlateManaBar:UnregisterAllEvents()
		BlizzPlateManaBar:SetAlpha(0)
	end

	if (NamePlateDriverFrame.UpdateNamePlateOptions) then
		hooksecurefunc(NamePlateDriverFrame, "UpdateNamePlateOptions", self.SetNamePlateSizes)
	end

	--if (NamePlateDriverFrame.SetupClassNameplateBars) then
	--	hooksecurefunc(NamePlateDriverFrame, "SetupClassNameplateBars", function(frame)
	--		if (not frame) or (frame:IsForbidden()) then
	--			return
	--		end
	--		if (frame.classNamePlateMechanicFrame) then
	--			frame.classNamePlateMechanicFrame:Hide()
	--		end
	--		if (frame.classNamePlatePowerBar) then
	--			frame.classNamePlatePowerBar:Hide()
	--			frame.classNamePlatePowerBar:UnregisterAllEvents()
	--		end
	--	end)
	--end
end

UnitFrames.SetNamePlateSizes = function()
	if (InCombatLockdown()) then return end

	local w,h = 90,45 -- 110,45
	C_NamePlate.SetNamePlateFriendlySize(w,h)
	C_NamePlate.SetNamePlateEnemySize(w,h)
	C_NamePlate.SetNamePlateSelfSize(w,h)
end

--UnitFrames.SetNamePlateDistance = function(self, event, ...)
--	if (InCombatLockdown()) then
--		return self:RegisterEvent("PLAYER_REGEN_ENABLED", "SetNamePlateDistance")
--	end
--	if (event == "PLAYER_REGEN_ENABLED") then
--		self:UnregisterEvent("PLAYER_REGEN_ENABLED", "SetNamePlateDistance")
--	end
--	local _, instanceType = IsInInstance()
--	if (instanceType == "none") then
--		SetCVar("nameplateMaxDistance", 30)
--		SetCVar("nameplateMaxScaleDistance", 15)
--	else
--		SetCVar("nameplateMaxDistance", 45)
--		SetCVar("nameplateMaxScaleDistance", 30)
--	end
--end

UnitFrames.UpdateScale = function(self)
	for namePlate in pairs(ns.NamePlates) do
		SetEffectiveObjectScale(namePlate)
	end
end

UnitFrames.OnEvent = function(self, event, ...)
	if (event == "PLAYER_ENTERING_WORLD") or (event == "VARIABLES_LOADED") then
		--self:SetNamePlateDistance()
		self:UpdateScale()
	elseif (event == "UI_SCALE_CHANGED") or (event == "DISPLAY_SIZE_CHANGED") then
		self:UpdateScale()
	end
end

UnitFrames.OnInitialize = function(self)

	self:RegisterMetaFunctions()
	self:RegisterStyles()
	self:SpawnUnitFrames()
	self:SpawnGroupFrames()
	self:SpawnNamePlates()

end

UnitFrames.OnEnable = function(self)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
	self:RegisterEvent("DISPLAY_SIZE_CHANGED", "OnEvent")
	self:RegisterEvent("UI_SCALE_CHANGED", "OnEvent")
	self:RegisterEvent("VARIABLES_LOADED", "OnEvent")
end
