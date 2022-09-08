--[[
Copyright (c) 2010-2021, Hendrik "nevcairiel" Leppkes <h.leppkes@gmail.com>

All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright notice,
      this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright notice,
      this list of conditions and the following disclaimer in the documentation
      and/or other materials provided with the distribution.
    * Neither the name of the developer nor the names of its contributors
      may be used to endorse or promote products derived from this software without
      specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

]]
--[[

	LibActionButton-1.0 Goldpaw Edition

	Based directly on LibActionButton-1.0.81,
	with the following modifications:

		* Disabled most of the standard button elements by default
		* Removed LibButtonGlow integration
		* Removed Masque support completely
		* Removed NewAction highlight functionality
		* Removed NormalTexture texture and texcoord adjustments
		* Removed .Count and .HotKey element font changes
		* Merged all three cooldown types into the same cooldown object
		* Prevented texture changes in various elements
		* Fixed button saturation to always be handled by UpdateUsable

]]
local MAJOR_VERSION = "LibActionButton-1.0-GoldpawEdition"
local MINOR_VERSION = 84

if not LibStub then error(MAJOR_VERSION .. " requires LibStub.") end
local lib, oldversion = LibStub:NewLibrary(MAJOR_VERSION, MINOR_VERSION)
if not lib then return end

-- Lua functions
local type, error, tostring, tonumber, assert, select = type, error, tostring, tonumber, assert, select
local setmetatable, wipe, unpack, pairs, next = setmetatable, wipe, unpack, pairs, next
local str_match, format, tinsert, tremove = string.match, format, tinsert, tremove

local WoWClassic = (WOW_PROJECT_ID == WOW_PROJECT_CLASSIC)
local WoWBCC = (WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC)
local WoWWrath = (WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC)

local KeyBound = LibStub("LibKeyBound-1.0", true)
local CBH = LibStub("CallbackHandler-1.0")

lib.eventFrame = lib.eventFrame or CreateFrame("Frame")
lib.eventFrame:UnregisterAllEvents()

lib.hiderFrame = lib.hiderFrame or CreateFrame("Frame")
lib.hiderFrame:Hide()

lib.buttonRegistry = lib.buttonRegistry or {}
lib.activeButtons = lib.activeButtons or {}
lib.actionButtons = lib.actionButtons or {}
lib.nonActionButtons = lib.nonActionButtons or {}

lib.callbacks = lib.callbacks or CBH:New(lib)

local Generic = CreateFrame("CheckButton")
local Generic_MT = {__index = Generic}

local Action = setmetatable({}, {__index = Generic})
local Action_MT = {__index = Action}

--local PetAction = setmetatable({}, {__index = Generic})
--local PetAction_MT = {__index = PetAction}

local Spell = setmetatable({}, {__index = Generic})
local Spell_MT = {__index = Spell}

local Item = setmetatable({}, {__index = Generic})
local Item_MT = {__index = Item}

local Macro = setmetatable({}, {__index = Generic})
local Macro_MT = {__index = Macro}

local Custom = setmetatable({}, {__index = Generic})
local Custom_MT = {__index = Custom}

local type_meta_map = {
	empty  = Generic_MT,
	action = Action_MT,
	--pet    = PetAction_MT,
	spell  = Spell_MT,
	item   = Item_MT,
	macro  = Macro_MT,
	custom = Custom_MT
}

local ButtonRegistry, ActiveButtons, ActionButtons, NonActionButtons = lib.buttonRegistry, lib.activeButtons, lib.actionButtons, lib.nonActionButtons

local Update, UpdateButtonState, UpdateUsable, UpdateCount, UpdateCooldown, UpdateTooltip
local StartFlash, StopFlash, UpdateFlash, UpdateHotkeys, UpdateRangeTimer, UpdateOverlayGlow
local UpdateFlyout, ShowGrid, HideGrid, UpdateGrid, SetupSecureSnippets, WrapOnClick, PrepareButton
local ShowOverlayGlow, HideOverlayGlow

local InitializeEventHandler, InitializeMaxDps, OnEvent, ForAllButtons, OnUpdate

local function GameTooltip_GetOwnerForbidden()
	if GameTooltip:IsForbidden() then
		return nil
	end
	return GameTooltip:GetOwner()
end

local function IsAddOnEnabled(target)
	target = target:lower()
	for i = 1,GetNumAddOns() do
		local name, title, notes, loadable, reason, security, newVersion = GetAddOnInfo(i)
		if (name:lower() == target) then
			local enabled = not(GetAddOnEnableState(UnitName("player"), i) == 0)
			if (enabled and loadable) then
				return true
			end
		end
	end
end

local DefaultConfig = {
	outOfRangeColoring = "button",
	tooltip = "enabled",
	showGrid = true,
	colors = {
		range = { .75, .15, .15 },
		mana = { .25, .25, .75 }
	},
	hideElements = {
		macro = true,
		hotkey = false,
		equipped = true,
	},
	keyBoundTarget = false,
	clickOnDown = true,
	flyoutDirection = "UP"
}

--- Create a new action button.
-- @param id Internal id of the button (not used by LibActionButton-1.0, only for tracking inside the calling addon)
-- @param name Name of the button frame to be created (not used by LibActionButton-1.0 aside from naming the frame)
-- @param header Header that drives these action buttons (if any)
function lib:CreateButton(id, name, header, config)
	if type(name) ~= "string" then
		error("Usage: CreateButton(id, name. header): Buttons must have a valid name!", 2)
	end
	if not header then
		error("Usage: CreateButton(id, name, header): Buttons without a secure header are not yet supported!", 2)
	end

	if not KeyBound then
		KeyBound = LibStub("LibKeyBound-1.0", true)
	end

	local button = setmetatable(CreateFrame("CheckButton", name, header, "SecureActionButtonTemplate, ActionButtonTemplate"), Generic_MT)
	button:RegisterForDrag("LeftButton", "RightButton")
	button:RegisterForClicks("AnyUp")

	-- Frame Scripts
	button:SetScript("OnEnter", Generic.OnEnter)
	button:SetScript("OnLeave", Generic.OnLeave)
	button:SetScript("PreClick", Generic.PreClick)
	button:SetScript("PostClick", Generic.PostClick)

	button.id = id
	button.header = header
	-- Mapping of state -> action
	button.state_types = {}
	button.state_actions = {}

	-- Store the LAB Version that created this button for debugging
	button.__LAB_Version = MINOR_VERSION

	-- just in case we're not run by a header, default to state 0
	button:SetAttribute("state", 0)

	SetupSecureSnippets(button)
	WrapOnClick(button)
	PrepareButton(button)

	-- Store the button in the registry, needed for event and OnUpdate handling
	if not next(ButtonRegistry) then
		InitializeEventHandler()
	end
	ButtonRegistry[button] = true

	button:UpdateConfig(config)

	-- run an initial update
	button:UpdateAction()
	UpdateHotkeys(button)

	-- somewhat of a hack for the Flyout buttons to not error.
	button.action = 0

	lib.callbacks:Fire("OnButtonCreated", button)

	return button
end

function SetupSecureSnippets(button)
	button:SetAttribute("_custom", Custom.RunCustom)
	-- secure UpdateState(self, state)
	-- update the type and action of the button based on the state
	button:SetAttribute("UpdateState", [[
		local state = ...
		self:SetAttribute("state", state)
		local type, action = (self:GetAttribute(format("labtype-%s", state)) or "empty"), self:GetAttribute(format("labaction-%s", state))

		self:SetAttribute("type", type)
		if type ~= "empty" and type ~= "custom" then
			local action_field = (type == "pet") and "action" or type
			self:SetAttribute(action_field, action)
			self:SetAttribute("action_field", action_field)
		end
		local onStateChanged = self:GetAttribute("OnStateChanged")
		if onStateChanged then
			self:Run(onStateChanged, state, type, action)
		end
	]])

	-- this function is invoked by the header when the state changes
	button:SetAttribute("_childupdate-state", [[
		self:RunAttribute("UpdateState", message)
		self:CallMethod("UpdateAction")
	]])

	-- secure PickupButton(self, kind, value, ...)
	-- utility function to place a object on the cursor
	button:SetAttribute("PickupButton", [[
		local kind, value = ...
		if kind == "empty" then
			return "clear"
		elseif kind == "action" or kind == "pet" then
			local actionType = (kind == "pet") and "petaction" or kind
			return actionType, value
		elseif kind == "spell" or kind == "item" or kind == "macro" then
			return "clear", kind, value
		else
			print("LibActionButton-1.0: Unknown type: " .. tostring(kind))
			return false
		end
	]])

	button:SetAttribute("OnDragStart", [[
		if (self:GetAttribute("buttonlock") and not (IsShiftKeyDown() and IsAltKeyDown() and IsControlKeyDown())) or self:GetAttribute("LABdisableDragNDrop") then return false end
		local state = self:GetAttribute("state")
		local type = self:GetAttribute("type")
		-- if the button is empty, we can't drag anything off it
		if type == "empty" or type == "custom" then
			return false
		end
		-- Get the value for the action attribute
		local action_field = self:GetAttribute("action_field")
		local action = self:GetAttribute(action_field)

		-- non-action fields need to change their type to empty
		if type ~= "action" and type ~= "pet" then
			self:SetAttribute(format("labtype-%s", state), "empty")
			self:SetAttribute(format("labaction-%s", state), nil)
			-- update internal state
			self:RunAttribute("UpdateState", state)
			-- send a notification to the insecure code
			self:CallMethod("ButtonContentsChanged", state, "empty", nil)
		end
		-- return the button contents for pickup
		return self:RunAttribute("PickupButton", type, action)
	]])

	button:SetAttribute("OnReceiveDrag", [[
		if self:GetAttribute("LABdisableDragNDrop") then return false end
		local kind, value, subtype, extra = ...
		if not kind or not value then return false end
		local state = self:GetAttribute("state")
		local buttonType, buttonAction = self:GetAttribute("type"), nil
		if buttonType == "custom" then return false end
		-- action buttons can do their magic themself
		-- for all other buttons, we'll need to update the content now
		if buttonType ~= "action" and buttonType ~= "pet" then
			-- with "spell" types, the 4th value contains the actual spell id
			if kind == "spell" then
				if extra then
					value = extra
				else
					print("no spell id?", ...)
				end
			elseif kind == "item" and value then
				value = format("item:%d", value)
			end

			-- Get the action that was on the button before
			if buttonType ~= "empty" then
				buttonAction = self:GetAttribute(self:GetAttribute("action_field"))
			end

			-- TODO: validate what kind of action is being fed in here
			-- We can only use a handful of the possible things on the cursor
			-- return false for all those we can't put on buttons

			self:SetAttribute(format("labtype-%s", state), kind)
			self:SetAttribute(format("labaction-%s", state), value)
			-- update internal state
			self:RunAttribute("UpdateState", state)
			-- send a notification to the insecure code
			self:CallMethod("ButtonContentsChanged", state, kind, value)
		else
			-- get the action for (pet-)action buttons
			buttonAction = self:GetAttribute("action")
		end
		return self:RunAttribute("PickupButton", buttonType, buttonAction)
	]])

	button:SetScript("OnDragStart", nil)
	-- Wrapped OnDragStart(self, button, kind, value, ...)
	button.header:WrapScript(button, "OnDragStart", [[
		return self:RunAttribute("OnDragStart")
	]])
	-- Wrap twice, because the post-script is not run when the pre-script causes a pickup (doh)
	-- we also need some phony message, or it won't work =/
	button.header:WrapScript(button, "OnDragStart", [[
		return "message", "update"
	]], [[
		self:RunAttribute("UpdateState", self:GetAttribute("state"))
	]])

	button:SetScript("OnReceiveDrag", nil)
	-- Wrapped OnReceiveDrag(self, button, kind, value, ...)
	button.header:WrapScript(button, "OnReceiveDrag", [[
		return self:RunAttribute("OnReceiveDrag", kind, value, ...)
	]])
	-- Wrap twice, because the post-script is not run when the pre-script causes a pickup (doh)
	-- we also need some phony message, or it won't work =/
	button.header:WrapScript(button, "OnReceiveDrag", [[
		return "message", "update"
	]], [[
		self:RunAttribute("UpdateState", self:GetAttribute("state"))
	]])
end

function WrapOnClick(button)
	-- Wrap OnClick, to catch changes to actions that are applied with a click on the button.
	button.header:WrapScript(button, "OnClick", [[
		if self:GetAttribute("type") == "action" then
			local type, action = GetActionInfo(self:GetAttribute("action"))
			return nil, format("%s|%s", tostring(type), tostring(action))
		end
	]], [[
		local type, action = GetActionInfo(self:GetAttribute("action"))
		if message ~= format("%s|%s", tostring(type), tostring(action)) then
			self:RunAttribute("UpdateState", self:GetAttribute("state"))
		end
	]])
end

function PrepareButton(button)
	if (button.SpellHighlightAnim) and (button.SpellHighlightAnim.Stop) then
		button.SpellHighlightAnim:Stop()
	end
	local name = button:GetName()
	for _,element in pairs({
		_G[name.."Border"],
		_G[name.."FloatingBG"],
		_G[name.."Name"],
		_G[name.."NormalTexture"],
		_G[name.."Shine"],
		button.SpellHighlightTexture,
		button.QuickKeybindHighlightTexture,
		button.GetCheckedTexture and button:GetCheckedTexture(),
		button.GetHighlightTexture and button:GetHighlightTexture(),
		button.GetNormalTexture and button:GetNormalTexture(),
	}) do
		if (element) then
			element:SetParent(lib.hiderFrame)
		end
	end
end

-----------------------------------------------------------
--- utility

function lib:GetAllButtons()
	local buttons = {}
	for button in next, ButtonRegistry do
		buttons[button] = true
	end
	return buttons
end

function Generic:ClearSetPoint(...)
	self:ClearAllPoints()
	self:SetPoint(...)
end

function Generic:NewHeader(header)
	self.header = header
	self:SetParent(header)
	SetupSecureSnippets(self)
	WrapOnClick(self)
end


-----------------------------------------------------------
--- state management

function Generic:ClearStates()
	for state in pairs(self.state_types) do
		self:SetAttribute(format("labtype-%s", state), nil)
		self:SetAttribute(format("labaction-%s", state), nil)
	end
	wipe(self.state_types)
	wipe(self.state_actions)
end

function Generic:SetState(state, kind, action)
	if not state then state = self:GetAttribute("state") end
	state = tostring(state)
	-- we allow a nil kind for setting a empty state
	if not kind then kind = "empty" end
	if not type_meta_map[kind] then
		error("SetStateAction: unknown action type: " .. tostring(kind), 2)
	end
	if kind ~= "empty" and action == nil then
		error("SetStateAction: an action is required for non-empty states", 2)
	end
	if kind ~= "custom" and action ~= nil and type(action) ~= "number" and type(action) ~= "string" or (kind == "custom" and type(action) ~= "table") then
		error("SetStateAction: invalid action data type, only strings and numbers allowed", 2)
	end

	if kind == "item" then
		if tonumber(action) then
			action = format("item:%s", action)
		else
			local itemString = str_match(action, "^|c%x+|H(item[%d:]+)|h%[")
			if itemString then
				action = itemString
			end
		end
	end

	self.state_types[state] = kind
	self.state_actions[state] = action
	self:UpdateState(state)
end

function Generic:UpdateState(state)
	if not state then state = self:GetAttribute("state") end
	state = tostring(state)
	self:SetAttribute(format("labtype-%s", state), self.state_types[state])
	self:SetAttribute(format("labaction-%s", state), self.state_actions[state])
	if state ~= tostring(self:GetAttribute("state")) then return end
	if self.header then
		self.header:SetFrameRef("updateButton", self)
		self.header:Execute([[
			local frame = self:GetFrameRef("updateButton")
			control:RunFor(frame, frame:GetAttribute("UpdateState"), frame:GetAttribute("state"))
		]])
	else
	-- TODO
	end
	self:UpdateAction()
end

function Generic:GetAction(state)
	if not state then state = self:GetAttribute("state") end
	state = tostring(state)
	return self.state_types[state] or "empty", self.state_actions[state]
end

function Generic:UpdateAllStates()
	for state in pairs(self.state_types) do
		self:UpdateState(state)
	end
end

function Generic:ButtonContentsChanged(state, kind, value)
	state = tostring(state)
	self.state_types[state] = kind or "empty"
	self.state_actions[state] = value
	lib.callbacks:Fire("OnButtonContentsChanged", self, state, self.state_types[state], self.state_actions[state])
	self:UpdateAction(self)
end

function Generic:DisableDragNDrop(flag)
	if InCombatLockdown() then
		error("LibActionButton-1.0: You can only toggle DragNDrop out of combat!", 2)
	end
	if flag then
		self:SetAttribute("LABdisableDragNDrop", true)
	else
		self:SetAttribute("LABdisableDragNDrop", nil)
	end
end

function Generic:UpdateAlpha()
	UpdateCooldown(self)
end

-----------------------------------------------------------
--- frame scripts

-- copied (and adjusted) from SecureHandlers.lua
local function PickupAny(kind, target, detail, ...)
	if kind == "clear" then
		ClearCursor()
		kind, target, detail = target, detail, ...
	end

	if kind == 'action' then
		PickupAction(target)
	elseif kind == 'item' then
		PickupItem(target)
	elseif kind == 'macro' then
		PickupMacro(target)
	elseif kind == 'petaction' then
		PickupPetAction(target)
	elseif kind == 'spell' then
		PickupSpell(target)
	elseif kind == 'companion' then
		PickupCompanion(target, detail)
	elseif kind == 'equipmentset' then
		PickupEquipmentSet(target)
	end
end

function Generic:OnEnter()
	if self.config.tooltip ~= "disabled" and (self.config.tooltip ~= "nocombat" or not InCombatLockdown()) then
		UpdateTooltip(self)
	end
	if KeyBound then
		KeyBound:Set(self)
	end
end

function Generic:OnLeave()
	if GameTooltip:IsForbidden() then return end
	GameTooltip:Hide()
end

-- Insecure drag handler to allow clicking on the button with an action on the cursor
-- to place it on the button. Like action buttons work.
function Generic:PreClick()
	if self._state_type == "action" or self._state_type == "pet"
	   or InCombatLockdown() or self:GetAttribute("LABdisableDragNDrop")
	then
		return
	end
	-- check if there is actually something on the cursor
	local kind, value, _subtype = GetCursorInfo()
	if not (kind and value) then return end
	self._old_type = self._state_type
	if self._state_type and self._state_type ~= "empty" then
		self._old_type = self._state_type
		self:SetAttribute("type", "empty")
		--self:SetState(nil, "empty", nil)
	end
	self._receiving_drag = true
end

local function formatHelper(input)
	if type(input) == "string" then
		return format("%q", input)
	else
		return tostring(input)
	end
end

function Generic:PostClick()
	UpdateButtonState(self)
	if self._receiving_drag and not InCombatLockdown() then
		if self._old_type then
			self:SetAttribute("type", self._old_type)
			self._old_type = nil
		end
		local oldType, oldAction = self._state_type, self._state_action
		local kind, data, subtype, extra = GetCursorInfo()
		self.header:SetFrameRef("updateButton", self)
		self.header:Execute(format([[
			local frame = self:GetFrameRef("updateButton")
			control:RunFor(frame, frame:GetAttribute("OnReceiveDrag"), %s, %s, %s, %s)
			control:RunFor(frame, frame:GetAttribute("UpdateState"), %s)
		]], formatHelper(kind), formatHelper(data), formatHelper(subtype), formatHelper(extra), formatHelper(self:GetAttribute("state"))))
		PickupAny("clear", oldType, oldAction)
	end
	self._receiving_drag = nil
end

-----------------------------------------------------------
--- configuration

local function merge(target, source, default)
	for k,v in pairs(default) do
		if type(v) ~= "table" then
			if source and source[k] ~= nil then
				target[k] = source[k]
			else
				target[k] = v
			end
		else
			if type(target[k]) ~= "table" then target[k] = {} else wipe(target[k]) end
			merge(target[k], type(source) == "table" and source[k], v)
		end
	end
	return target
end

function Generic:UpdateConfig(config)
	if config and type(config) ~= "table" then
		error("LibActionButton-1.0: UpdateConfig requires a valid configuration!", 2)
	end
	local oldconfig = self.config
	self.config = {}
	-- merge the two configs
	merge(self.config, config, DefaultConfig)

	if self.config.outOfRangeColoring == "button" or (oldconfig and oldconfig.outOfRangeColoring == "button") then
		UpdateUsable(self)
	end
	if self.config.outOfRangeColoring == "hotkey" then
		self.outOfRange = nil
	elseif oldconfig and oldconfig.outOfRangeColoring == "hotkey" then
		self.HotKey:SetVertexColor(0.75, 0.75, 0.75)
	end

	if self.config.hideElements.macro then
		self.Name:Hide()
	else
		self.Name:Show()
	end

	self:SetAttribute("flyoutDirection", self.config.flyoutDirection)

	UpdateHotkeys(self)
	UpdateGrid(self)
	Update(self)
	self:RegisterForClicks(self.config.clickOnDown and "AnyDown" or "AnyUp")
end

-----------------------------------------------------------
--- event handler

function ForAllButtons(method, onlyWithAction)
	assert(type(method) == "function")
	for button in next, (onlyWithAction and ActiveButtons or ButtonRegistry) do
		method(button)
	end
end

function InitializeEventHandler()
	lib.eventFrame:SetScript("OnEvent", OnEvent)
	lib.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	lib.eventFrame:RegisterEvent("ACTIONBAR_SHOWGRID")
	lib.eventFrame:RegisterEvent("ACTIONBAR_HIDEGRID")
	--lib.eventFrame:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
	--lib.eventFrame:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
	lib.eventFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
	lib.eventFrame:RegisterEvent("UPDATE_BINDINGS")
	lib.eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
	lib.eventFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
	if not WoWClassic and not WoWBCC then
		lib.eventFrame:RegisterEvent("UPDATE_VEHICLE_ACTIONBAR")
	end

	lib.eventFrame:RegisterEvent("ACTIONBAR_UPDATE_STATE")
	lib.eventFrame:RegisterEvent("ACTIONBAR_UPDATE_USABLE")
	lib.eventFrame:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
	lib.eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
	lib.eventFrame:RegisterEvent("TRADE_SKILL_SHOW")
	lib.eventFrame:RegisterEvent("TRADE_SKILL_CLOSE")

	lib.eventFrame:RegisterEvent("PLAYER_ENTER_COMBAT")
	lib.eventFrame:RegisterEvent("PLAYER_LEAVE_COMBAT")
	lib.eventFrame:RegisterEvent("START_AUTOREPEAT_SPELL")
	lib.eventFrame:RegisterEvent("STOP_AUTOREPEAT_SPELL")
	lib.eventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
	lib.eventFrame:RegisterEvent("LEARNED_SPELL_IN_TAB")
	lib.eventFrame:RegisterEvent("PET_STABLE_UPDATE")
	lib.eventFrame:RegisterEvent("PET_STABLE_SHOW")
	lib.eventFrame:RegisterEvent("SPELL_UPDATE_CHARGES")
	lib.eventFrame:RegisterEvent("SPELL_UPDATE_ICON")
	if not WoWClassic and not WoWBCC then
		if not WoWWrath then
			lib.eventFrame:RegisterEvent("ARCHAEOLOGY_CLOSED")
			lib.eventFrame:RegisterEvent("UPDATE_SUMMONPETS_ACTION")
			lib.eventFrame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
			lib.eventFrame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
		end
		lib.eventFrame:RegisterEvent("UNIT_ENTERED_VEHICLE")
		lib.eventFrame:RegisterEvent("UNIT_EXITED_VEHICLE")
		lib.eventFrame:RegisterEvent("COMPANION_UPDATE")
	end

	-- With those two, do we still need the ACTIONBAR equivalents of them?
	lib.eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
	lib.eventFrame:RegisterEvent("SPELL_UPDATE_USABLE")
	lib.eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")

	lib.eventFrame:RegisterEvent("LOSS_OF_CONTROL_ADDED")
	lib.eventFrame:RegisterEvent("LOSS_OF_CONTROL_UPDATE")

	if MaxDps then
		InitializeMaxDps()
	elseif IsAddOnEnabled("MaxDps") then
		lib.eventFrame:RegisterEvent("ADDON_LOADED")
	end

	lib.eventFrame:Show()
	lib.eventFrame:SetScript("OnUpdate", OnUpdate)
end

local _lastFormUpdate = GetTime()
function OnEvent(frame, event, arg1, ...)
	if (event == "UNIT_INVENTORY_CHANGED" and arg1 == "player") or event == "LEARNED_SPELL_IN_TAB" then
		local tooltipOwner = GameTooltip_GetOwnerForbidden()
		if tooltipOwner and ButtonRegistry[tooltipOwner] then
			tooltipOwner:SetTooltip()
		end
	elseif event == "ACTIONBAR_SLOT_CHANGED" then
		for button in next, ButtonRegistry do
			if button._state_type == "action" and (arg1 == 0 or arg1 == tonumber(button._state_action)) then
				Update(button)
			end
		end
	elseif event == "PLAYER_ENTERING_WORLD" or event == "UPDATE_VEHICLE_ACTIONBAR" then
		for button in next, ActiveButtons do
			if (button.maxDpsGlowShown) then
				button.maxDpsGlowColor = nil
				button.maxDpsGlowShown = nil
			end
		end
		ForAllButtons(Update)
	elseif event == "UPDATE_SHAPESHIFT_FORM" then
		-- XXX: throttle these updates since Blizzard broke the event and its now extremely spammy in some clients
		local _time = GetTime()
		if (_time - _lastFormUpdate) < 1 then
			return
		end
		_lastFormUpdate = _time

		-- the attack icon can change when shapeshift form changes, so need to do a quick update here
		-- for performance reasons don't run full updates here, though
		for button in next, ActiveButtons do
			local texture = button:GetTexture()
			if texture then
				button.icon:SetTexture(texture)
			end
			if (button.maxDpsGlowShown) then
				button.maxDpsGlowColor = nil
				button.maxDpsGlowShown = nil
			end
		end
	elseif event == "ACTIONBAR_PAGE_CHANGED" or event == "UPDATE_BONUS_ACTIONBAR" then
		-- TODO: Are these even needed?
	elseif event == "ACTIONBAR_SHOWGRID" then
		ShowGrid()
	elseif event == "ACTIONBAR_HIDEGRID" then
		HideGrid()
	elseif event == "UPDATE_BINDINGS" then
		ForAllButtons(UpdateHotkeys)
	elseif event == "PLAYER_TARGET_CHANGED" then
		UpdateRangeTimer()
	elseif (event == "ACTIONBAR_UPDATE_STATE") or
		((event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE") and (arg1 == "player")) or
		((event == "COMPANION_UPDATE") and (arg1 == "MOUNT")) then
		ForAllButtons(UpdateButtonState, true)
	elseif event == "ACTIONBAR_UPDATE_USABLE" then
		for button in next, ActionButtons do
			UpdateUsable(button)
		end
	elseif event == "SPELL_UPDATE_USABLE" then
		for button in next, NonActionButtons do
			UpdateUsable(button)
		end
	elseif event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
		for button in next, ActiveButtons do
			UpdateUsable(button)
		end
	elseif event == "ACTIONBAR_UPDATE_COOLDOWN" then
		for button in next, ActionButtons do
			UpdateCooldown(button)
			if GameTooltip_GetOwnerForbidden() == button then
				UpdateTooltip(button)
			end
		end
	elseif event == "SPELL_UPDATE_COOLDOWN" then
		for button in next, NonActionButtons do
			UpdateCooldown(button)
			if GameTooltip_GetOwnerForbidden() == button then
				UpdateTooltip(button)
			end
		end
	elseif event == "LOSS_OF_CONTROL_ADDED" then
		for button in next, ActiveButtons do
			UpdateCooldown(button)
			if GameTooltip_GetOwnerForbidden() == button then
				UpdateTooltip(button)
			end
		end
	elseif event == "LOSS_OF_CONTROL_UPDATE" then
		for button in next, ActiveButtons do
			UpdateCooldown(button)
		end
	elseif event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_CLOSE"  or event == "ARCHAEOLOGY_CLOSED" then
		ForAllButtons(UpdateButtonState, true)
	elseif event == "PLAYER_ENTER_COMBAT" then
		for button in next, ActiveButtons do
			if button:IsAttack() then
				StartFlash(button)
			end
		end
	elseif event == "PLAYER_LEAVE_COMBAT" then
		for button in next, ActiveButtons do
			if button:IsAttack() then
				StopFlash(button)
			end
		end
	elseif event == "START_AUTOREPEAT_SPELL" then
		for button in next, ActiveButtons do
			if button:IsAutoRepeat() then
				StartFlash(button)
			end
		end
	elseif event == "STOP_AUTOREPEAT_SPELL" then
		for button in next, ActiveButtons do
			if button.flashing == 1 and not button:IsAttack() then
				StopFlash(button)
			end
		end
	elseif event == "PET_STABLE_UPDATE" or event == "PET_STABLE_SHOW" then
		ForAllButtons(Update)
	elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then
		for button in next, ActiveButtons do
			local spellId = button:GetSpellId()
			if spellId and spellId == arg1 then
				ShowOverlayGlow(button)
			else
				if button._state_type == "action" then
					local actionType, id = GetActionInfo(button._state_action)
					if actionType == "flyout" and FlyoutHasSpell(id, arg1) then
						ShowOverlayGlow(button)
					end
				end
			end
		end
	elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
		for button in next, ActiveButtons do
			local spellId = button:GetSpellId()
			if spellId and spellId == arg1 then
				HideOverlayGlow(button)
			else
				if button._state_type == "action" then
					local actionType, id = GetActionInfo(button._state_action)
					if actionType == "flyout" and FlyoutHasSpell(id, arg1) then
						HideOverlayGlow(button)
					end
				end
			end
		end
	elseif event == "PLAYER_EQUIPMENT_CHANGED" then
		for button in next, ActiveButtons do
			if button._state_type == "item" then
				Update(button)
			end
		end
	elseif event == "SPELL_UPDATE_CHARGES" then
		ForAllButtons(UpdateCount, true)
	elseif event == "UPDATE_SUMMONPETS_ACTION" then
		for button in next, ActiveButtons do
			if button._state_type == "action" then
				local actionType, _id = GetActionInfo(button._state_action)
				if actionType == "summonpet" then
					local texture = GetActionTexture(button._state_action)
					if texture then
						button.icon:SetTexture(texture)
					end
				end
			end
		end
	elseif event == "SPELL_UPDATE_ICON" then
		ForAllButtons(Update, true)

	--elseif event == "PLAYER_REGEN_ENABLED" then
	--	for button in next, ActiveButtons do
	--		if (button.maxDpsGlowShown) then
	--			button.maxDpsGlowColor = nil
	--			button.maxDpsGlowShown = nil
	--			UpdateOverlayGlow(button)
	--		end
	--	end

	elseif event == "ADDON_LOADED" then
		if (arg1 == "MaxDps") then
			lib.eventFrame:UnregisterEvent("ADDON_LOADED")
			InitializeMaxDps()
		end
	end
end

local flashTime = 0
local rangeTimer = -1
function OnUpdate(_, elapsed)
	flashTime = flashTime - elapsed
	rangeTimer = rangeTimer - elapsed
	-- Run the loop only when there is something to update
	if rangeTimer <= 0 or flashTime <= 0 then
		for button in next, ActiveButtons do
			-- Flashing
			if button.flashing == 1 and flashTime <= 0 then
				if button.Flash:IsShown() then
					button.Flash:Hide()
				else
					button.Flash:Show()
				end
			end

			-- Range
			if rangeTimer <= 0 then
				local inRange = button:IsInRange()
				local oldRange = button.outOfRange
				button.outOfRange = (inRange == false)
				if oldRange ~= button.outOfRange then
					if button.config.outOfRangeColoring == "button" then
						UpdateUsable(button)
					elseif button.config.outOfRangeColoring == "hotkey" then
						local hotkey = button.HotKey
						if hotkey:GetText() == RANGE_INDICATOR then
							if inRange == false then
								hotkey:Show()
							else
								hotkey:Hide()
							end
						end
						if inRange == false then
							hotkey:SetVertexColor(unpack(button.config.colors.range))
						else
							hotkey:SetVertexColor(0.75, 0.75, 0.75)
						end
					end
				end
			end
		end

		-- Update values
		if flashTime <= 0 then
			flashTime = flashTime + ATTACK_BUTTON_FLASH_TIME
		end
		if rangeTimer <= 0 then
			rangeTimer = TOOLTIP_UPDATE_TIME
		end
	end
end

local gridCounter = 0
function ShowGrid()
	gridCounter = gridCounter + 1
	if gridCounter >= 1 then
		for button in next, ButtonRegistry do
			if button:IsShown() then
				button:SetAlpha(1.0)
			end
		end
	end
end

function HideGrid()
	if gridCounter > 0 then
		gridCounter = gridCounter - 1
	end
	if gridCounter == 0 then
		for button in next, ButtonRegistry do
			if button:IsShown() and not button:HasAction() and not button.config.showGrid then
				button:SetAlpha(0.0)
			end
		end
	end
end

function UpdateGrid(self)
	if self.config.showGrid then
		self:SetAlpha(1.0)
	elseif gridCounter == 0 and self:IsShown() and not self:HasAction() then
		self:SetAlpha(0.0)
	end
end

-----------------------------------------------------------
--- KeyBound integration

function Generic:GetBindingAction()
	return self.config.keyBoundTarget or "CLICK "..self:GetName()..":LeftButton"
end

function Generic:GetHotkey()
	local name = "CLICK "..self:GetName()..":LeftButton"
	local key = GetBindingKey(self.config.keyBoundTarget or name)
	if not key and self.config.keyBoundTarget then
		key = GetBindingKey(name)
	end
	if key then
		return KeyBound and KeyBound:ToShortKey(key) or key
	end
end

local function getKeys(binding, keys)
	keys = keys or ""
	for i = 1, select("#", GetBindingKey(binding)) do
		local hotKey = select(i, GetBindingKey(binding))
		if keys ~= "" then
			keys = keys .. ", "
		end
		keys = keys .. GetBindingText(hotKey)
	end
	return keys
end

function Generic:GetBindings()
	local keys

	if self.config.keyBoundTarget then
		keys = getKeys(self.config.keyBoundTarget)
	end

	keys = getKeys("CLICK "..self:GetName()..":LeftButton", keys)

	return keys
end

function Generic:SetKey(key)
	if self.config.keyBoundTarget then
		SetBinding(key, self.config.keyBoundTarget)
	else
		SetBindingClick(key, self:GetName(), "LeftButton")
	end
	lib.callbacks:Fire("OnKeybindingChanged", self, key)
end

local function clearBindings(binding)
	while GetBindingKey(binding) do
		SetBinding(GetBindingKey(binding), nil)
	end
end

function Generic:ClearBindings()
	if self.config.keyBoundTarget then
		clearBindings(self.config.keyBoundTarget)
	end
	clearBindings("CLICK "..self:GetName()..":LeftButton")
	lib.callbacks:Fire("OnKeybindingChanged", self, nil)
end

-----------------------------------------------------------
--- button management

function Generic:UpdateAction(force)
	local action_type, action = self:GetAction()
	if force or action_type ~= self._state_type or action ~= self._state_action then
		-- type changed, update the metatable
		if force or self._state_type ~= action_type then
			local meta = type_meta_map[action_type] or type_meta_map.empty
			setmetatable(self, meta)
			self._state_type = action_type
		end
		self._state_action = action
		Update(self)
	end
end

function Update(self)

	-- Update Action Text
	if not self:IsConsumableOrStackable() then
		self.Name:SetText(self:GetActionText())
	else
		self.Name:SetText("")
	end

	-- Update icon and hotkey
	local texture = self:GetTexture()

	-- Zone ability button handling
	self.zoneAbilityDisabled = false
	self.icon:SetDesaturated(false)

	if texture then
		self.icon:SetTexture(texture)
		self.icon:Show()
		self.rangeTimer = - 1
	else
		self.icon:Hide()
		self.cooldown:Hide()
		self.rangeTimer = nil
		self.maxDpsGlowColor = nil
		self.maxDpsGlowShown = nil
		if self.HotKey:GetText() == RANGE_INDICATOR then
			self.HotKey:Hide()
		else
			self.HotKey:SetVertexColor(0.75, 0.75, 0.75)
		end
	end

	if self:HasAction() then
		ActiveButtons[self] = true
		if self._state_type == "action" then
			ActionButtons[self] = true
			NonActionButtons[self] = nil
		else
			ActionButtons[self] = nil
			NonActionButtons[self] = true
		end
		self:SetAlpha(1.0)
		UpdateButtonState(self)
		UpdateUsable(self)
		UpdateCooldown(self)
		UpdateFlash(self)
	else
		ActiveButtons[self] = nil
		ActionButtons[self] = nil
		NonActionButtons[self] = nil
		if gridCounter == 0 and not self.config.showGrid then
			self:SetAlpha(0.0)
		end
		self.cooldown:Hide()
		self:SetChecked(false)

		if self.LevelLinkLockIcon then
			self.LevelLinkLockIcon:SetShown(false)
		end
	end

	self:UpdateLocal()
	UpdateCount(self)
	UpdateFlyout(self)
	UpdateOverlayGlow(self)

	if GameTooltip_GetOwnerForbidden() == self then
		UpdateTooltip(self)
	end

	-- this could've been a spec change, need to call OnStateChanged for action buttons, if present
	if not InCombatLockdown() and self._state_type == "action" then
		local onStateChanged = self:GetAttribute("OnStateChanged")
		if onStateChanged then
			self.header:SetFrameRef("updateButton", self)
			self.header:Execute(([[
				local frame = self:GetFrameRef("updateButton")
				control:RunFor(frame, frame:GetAttribute("OnStateChanged"), %s, %s, %s)
			]]):format(formatHelper(self:GetAttribute("state")), formatHelper(self._state_type), formatHelper(self._state_action)))
		end
	end
	lib.callbacks:Fire("OnButtonUpdate", self)
end

function Generic:UpdateLocal()
	-- dummy function the other button types can override for special updating
end

function UpdateButtonState(self)
	if self:IsCurrentlyActive() or self:IsAutoRepeat() then
		self:SetChecked(true)
	else
		self:SetChecked(false)
	end
	lib.callbacks:Fire("OnButtonState", self)
end

function UpdateUsable(self)

	local r, g, b = .4, .36, .32
	if (UnitIsDeadOrGhost("player")) or (UnitOnTaxi("player")) then
		self.icon:SetDesaturated(true)
		self.icon:SetVertexColor(r, g, b)

	elseif (self.outOfRange) then
		self.icon:SetDesaturated(true)
		self.icon:SetVertexColor(1, .15, .15)
	else
		local isUsable, notEnoughMana = self:IsUsable()
		if (isUsable) then
			self.icon:SetDesaturated(false)
			self.icon:SetVertexColor(1, 1, 1)

		elseif (notEnoughMana) then
			self.icon:SetDesaturated(true)
			self.icon:SetVertexColor(.25, .25, 1)
		else
			self.icon:SetDesaturated(true)
			self.icon:SetVertexColor(r, g, b)
		end
	end

	if not WoWClassic and not WoWBCC and not WoWWrath and self._state_type == "action" then
		local isLevelLinkLocked = C_LevelLink.IsActionLocked(self._state_action)
		if not self.icon:IsDesaturated() then
			self.icon:SetDesaturated(isLevelLinkLocked)
			self.icon:SetVertexColor(r, g, b)
		end

		if self.LevelLinkLockIcon then
			self.LevelLinkLockIcon:SetShown(isLevelLinkLocked)
		end
	end

	lib.callbacks:Fire("OnButtonUsable", self)
end

function UpdateCount(self)
	if not self:HasAction() then
		self.Count:SetText("")
		return
	end
	if self:IsConsumableOrStackable() then
		local count = self:GetCount()
		if count > (self.maxDisplayCount or 9999) then
			self.Count:SetText("*")
		else
			self.Count:SetText(count)
		end
	else
		local charges, maxCharges, _chargeStart, _chargeDuration = self:GetCharges()
		if charges and maxCharges and maxCharges > 1 then
			self.Count:SetText(charges)
		else
			self.Count:SetText("")
		end
	end
end

local function OnCooldownDone(self)
	self:SetScript("OnCooldownDone", nil)
	UpdateCooldown(self:GetParent())
end

function UpdateCooldown(self)
	local cooldown = self.cooldown
	if (cooldown) then
		local locStart, locDuration = self:GetLossOfControlCooldown()
		local start, duration, enable, modRate = self:GetCooldown()
		local charges, maxCharges, chargeStart, chargeDuration, chargeModRate = self:GetCharges()

		if (locStart + locDuration) > (start + duration) then
			cooldown:SetSwipeColor(.25, 0, 0, .5)
			CooldownFrame_Set(cooldown, locStart, locDuration, true, true, modRate)
			self.hasCooldown = true
		else
			if locStart > 0 then
				cooldown:SetScript("OnCooldownDone", OnCooldownDone)
			end
			if charges and maxCharges and maxCharges > 1 and charges < maxCharges then
				if charges > 0 then
					cooldown:SetSwipeColor(0, 0, 0, .5)
				else
					cooldown:SetSwipeColor(0, 0, 0, .75)
				end
				CooldownFrame_Set(cooldown, chargeStart, chargeDuration, true, true, chargeModRate)
				self.hasCooldown = true
			else
				cooldown:SetSwipeColor(0, 0, 0, .75)
				CooldownFrame_Set(cooldown, start, duration, enable, false, modRate)
				self.hasCooldown = duration and duration > 0
			end
		end
	end
end

function StartFlash(self)
	self.flashing = 1
	flashTime = 0
	UpdateButtonState(self)
end

function StopFlash(self)
	self.flashing = 0
	self.Flash:Hide()
	UpdateButtonState(self)
end

function UpdateFlash(self)
	if (self:IsAttack() and self:IsCurrentlyActive()) or self:IsAutoRepeat() then
		StartFlash(self)
	else
		StopFlash(self)
	end
end

function UpdateTooltip(self)
	if GameTooltip:IsForbidden() then return end
	if (GetCVar("UberTooltips") == "1") then
		GameTooltip_SetDefaultAnchor(GameTooltip, self);
	else
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	end
	if self:SetTooltip() then
		self.UpdateTooltip = UpdateTooltip
	else
		self.UpdateTooltip = nil
	end
end

function UpdateHotkeys(self)
	local key = self:GetHotkey()
	if not key or key == "" or self.config.hideElements.hotkey then
		self.HotKey:SetText(RANGE_INDICATOR)
		self.HotKey:Hide()
	else
		self.HotKey:SetText(key)
		self.HotKey:Show()
	end
end

function ShowOverlayGlow(self)
	if (self.SpellHighlight) then
		if (self.maxDpsGlowColor) then
			local r, g, b, a = unpack(self.maxDpsGlowColor)
			self.SpellHighlight:SetVertexColor(r, g, b, a or .75)
		else
			--self.SpellHighlight:SetVertexColor(255/255, 225/255, 125/255, .75)
			self.SpellHighlight:SetVertexColor(249/255, 188/255, 65/255, .75)
		end
		self.SpellHighlight:Show()
		lib.callbacks:Fire("OnButtonShowOverlayGlow", self)
	end
end

function HideOverlayGlow(self)
	if (self.SpellHighlight) then
		if (not self.maxDpsGlowShown) then
			self.SpellHighlight:Hide()
			lib.callbacks:Fire("OnButtonHideOverlayGlow", self)
		end
	end
end

function UpdateOverlayGlow(self)
	if (self.maxDpsGlowShown) then
		ShowOverlayGlow(self)
	else
		if (WoWWrath) then
			HideOverlayGlow(self)
		else
			local spellId = self:GetSpellId()
			if spellId and IsSpellOverlayed(spellId) then
				ShowOverlayGlow(self)
			else
				HideOverlayGlow(self)
			end
		end
	end
end

-- Hook UpdateFlyout so we can use the blizzy templates
hooksecurefunc("ActionButton_UpdateFlyout", function(self, ...)
	if ButtonRegistry[self] then
		UpdateFlyout(self)
	end
end)

function UpdateFlyout(self)
	-- disabled FlyoutBorder/BorderShadow, those are not handled by LBF and look terrible
	self.FlyoutBorder:Hide()
	self.FlyoutBorderShadow:Hide()
	if self._state_type == "action" then
		-- based on ActionButton_UpdateFlyout in ActionButton.lua
		local actionType = GetActionInfo(self._state_action)
		if actionType == "flyout" then
			-- Update border and determine arrow position
			local arrowDistance
			if (SpellFlyout and SpellFlyout:IsShown() and SpellFlyout:GetParent() == self) or GetMouseFocus() == self then
				arrowDistance = 5
			else
				arrowDistance = 2
			end

			-- Update arrow
			self.FlyoutArrow:Show()
			self.FlyoutArrow:ClearAllPoints()
			local direction = self:GetAttribute("flyoutDirection");
			if direction == "LEFT" then
				self.FlyoutArrow:SetPoint("LEFT", self, "LEFT", -arrowDistance, 0)
				SetClampedTextureRotation(self.FlyoutArrow, 270)
			elseif direction == "RIGHT" then
				self.FlyoutArrow:SetPoint("RIGHT", self, "RIGHT", arrowDistance, 0)
				SetClampedTextureRotation(self.FlyoutArrow, 90)
			elseif direction == "DOWN" then
				self.FlyoutArrow:SetPoint("BOTTOM", self, "BOTTOM", 0, -arrowDistance)
				SetClampedTextureRotation(self.FlyoutArrow, 180)
			else
				self.FlyoutArrow:SetPoint("TOP", self, "TOP", 0, arrowDistance)
				SetClampedTextureRotation(self.FlyoutArrow, 0)
			end

			-- return here, otherwise flyout is hidden
			return
		end
	end
	self.FlyoutArrow:Hide()
end

function UpdateRangeTimer()
	rangeTimer = -1
end

-----------------------------------------------------------
--- MaxDps integration

function InitializeMaxDps()
	if not MaxDps then
		return
	end

	MaxDps:RegisterLibActionButton(MAJOR_VERSION)

	--lib.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

	lib.MaxDps_GetTexture = lib.MaxDps_GetTexture or MaxDps.GetTexture
	lib.MaxDps_Glow = lib.MaxDps_Glow or MaxDps.Glow
	lib.MaxDps_HideGlow = lib.MaxDps_HideGlow  or MaxDps.HideGlow

	MaxDps.GetTexture = function() end

	MaxDps.Glow = function(this, button, id, texture, type, color)
		if (not ButtonRegistry[button]) then
			return lib.MaxDps_Glow(this, button, id, texture, type, color)
		end
		local col = color and { color.r, color.g, color.b, color.a } or nil
		if (not color) and (type) then
			if (type == "normal") then
				local c = this.db.global.highlightColor
				col = { c.r, c.g, c.b, c.a }

			elseif (type == "cooldown") then
				local c = this.db.global.cooldownColor
				col = { c.r, c.g, c.b, c.a }
			end
		end
		button.maxDpsGlowColor = col
		button.maxDpsGlowShown = true
		UpdateOverlayGlow(button)
	end

	MaxDps.HideGlow = function(this, button, id)
		if (not ButtonRegistry[button]) then
			return lib.MaxDps_HideGlow(this, button, id)
		end
		button.maxDpsGlowColor = nil
		button.maxDpsGlowShown = nil
		UpdateOverlayGlow(button)
	end

end

-----------------------------------------------------------
--- WoW API mapping
--- Generic Button
Generic.HasAction               = function(self) return nil end
Generic.GetActionText           = function(self) return "" end
Generic.GetTexture              = function(self) return nil end
Generic.GetCharges              = function(self) return nil end
Generic.GetCount                = function(self) return 0 end
Generic.GetCooldown             = function(self) return 0, 0, 0 end
Generic.IsAttack                = function(self) return nil end
Generic.IsEquipped              = function(self) return nil end
Generic.IsCurrentlyActive       = function(self) return nil end
Generic.IsAutoRepeat            = function(self) return nil end
Generic.IsUsable                = function(self) return nil end
Generic.IsConsumableOrStackable = function(self) return nil end
Generic.IsUnitInRange           = function(self, unit) return nil end
Generic.IsInRange               = function(self)
	local unit = self:GetAttribute("unit")
	if unit == "player" then
		unit = nil
	end
	local val = self:IsUnitInRange(unit)
	-- map 1/0 to true false, since the return values are inconsistent between actions and spells
	if val == 1 then val = true elseif val == 0 then val = false end
	return val
end
Generic.SetTooltip              = function(self) return nil end
Generic.GetSpellId              = function(self) return nil end
Generic.GetLossOfControlCooldown = function(self) return 0, 0 end

-----------------------------------------------------------
--- Action Button
Action.HasAction               = function(self) return HasAction(self._state_action) end
Action.GetActionText           = function(self) return GetActionText(self._state_action) end
Action.GetTexture              = function(self) return GetActionTexture(self._state_action) end
Action.GetCharges              = function(self) return GetActionCharges(self._state_action) end
Action.GetCount                = function(self) return GetActionCount(self._state_action) end
Action.GetCooldown             = function(self) return GetActionCooldown(self._state_action) end
Action.IsAttack                = function(self) return IsAttackAction(self._state_action) end
Action.IsEquipped              = function(self) return IsEquippedAction(self._state_action) end
Action.IsCurrentlyActive       = function(self) return IsCurrentAction(self._state_action) end
Action.IsAutoRepeat            = function(self) return IsAutoRepeatAction(self._state_action) end
Action.IsUsable                = function(self) return IsUsableAction(self._state_action) end
Action.IsConsumableOrStackable = function(self) return IsConsumableAction(self._state_action) or IsStackableAction(self._state_action) or (not IsItemAction(self._state_action) and GetActionCount(self._state_action) > 0) end
Action.IsUnitInRange           = function(self, unit) return IsActionInRange(self._state_action, unit) end
Action.SetTooltip              = function(self) return GameTooltip:SetAction(self._state_action) end
Action.GetSpellId              = function(self)
	local actionType, id, _subType = GetActionInfo(self._state_action)
	if actionType == "spell" then
		return id
	elseif actionType == "macro" then
		return (GetMacroSpell(id))
	end
end
Action.GetLossOfControlCooldown = function(self) return GetActionLossOfControlCooldown(self._state_action) end

-- Classic overrides for item count breakage
if WoWClassic then
	-- if the library is present, simply use it to override action counts
	local LibClassicSpellActionCount = LibStub("LibClassicSpellActionCount-1.0", true)
	if LibClassicSpellActionCount then
		Action.GetCount = function(self) return LibClassicSpellActionCount:GetActionCount(self._state_action) end
	else
		-- if we don't have the library, only show count for items, like the default UI
		Action.IsConsumableOrStackable = function(self) return IsItemAction(self._state_action) and (IsConsumableAction(self._state_action) or IsStackableAction(self._state_action)) end
	end
end

if WoWClassic or WoWBCC or WoWWrath then
	-- disable loss of control cooldown on classic
	Action.GetLossOfControlCooldown = function(self) return 0,0 end
end

-----------------------------------------------------------
--- Spell Button
Spell.HasAction               = function(self) return true end
Spell.GetActionText           = function(self) return "" end
Spell.GetTexture              = function(self) return GetSpellTexture(self._state_action) end
Spell.GetCharges              = function(self) return GetSpellCharges(self._state_action) end
Spell.GetCount                = function(self) return GetSpellCount(self._state_action) end
Spell.GetCooldown             = function(self) return GetSpellCooldown(self._state_action) end
Spell.IsAttack                = function(self) return IsAttackSpell(FindSpellBookSlotBySpellID(self._state_action), "spell") end -- needs spell book id as of 4.0.1.13066
Spell.IsEquipped              = function(self) return nil end
Spell.IsCurrentlyActive       = function(self) return IsCurrentSpell(self._state_action) end
Spell.IsAutoRepeat            = function(self) return IsAutoRepeatSpell(FindSpellBookSlotBySpellID(self._state_action), "spell") end -- needs spell book id as of 4.0.1.13066
Spell.IsUsable                = function(self) return IsUsableSpell(self._state_action) end
Spell.IsConsumableOrStackable = function(self) return IsConsumableSpell(self._state_action) end
Spell.IsUnitInRange           = function(self, unit) return IsSpellInRange(FindSpellBookSlotBySpellID(self._state_action), "spell", unit) end -- needs spell book id as of 4.0.1.13066
Spell.SetTooltip              = function(self) return GameTooltip:SetSpellByID(self._state_action) end
Spell.GetSpellId              = function(self) return self._state_action end
Spell.GetLossOfControlCooldown = function(self) return GetSpellLossOfControlCooldown(self._state_action) end

-----------------------------------------------------------
--- Item Button
local function getItemId(input)
	return input:match("^item:(%d+)")
end

Item.HasAction               = function(self) return true end
Item.GetActionText           = function(self) return "" end
Item.GetTexture              = function(self) return GetItemIcon(self._state_action) end
Item.GetCharges              = function(self) return nil end
Item.GetCount                = function(self) return GetItemCount(self._state_action, nil, true) end
Item.GetCooldown             = function(self) return GetItemCooldown(getItemId(self._state_action)) end
Item.IsAttack                = function(self) return nil end
Item.IsEquipped              = function(self) return IsEquippedItem(self._state_action) end
Item.IsCurrentlyActive       = function(self) return IsCurrentItem(self._state_action) end
Item.IsAutoRepeat            = function(self) return nil end
Item.IsUsable                = function(self) return IsUsableItem(self._state_action) end
Item.IsConsumableOrStackable = function(self) return IsConsumableItem(self._state_action) end
Item.IsUnitInRange           = function(self, unit) return IsItemInRange(self._state_action, unit) end
Item.SetTooltip              = function(self) return GameTooltip:SetHyperlink(self._state_action) end
Item.GetSpellId              = function(self) return nil end

-----------------------------------------------------------
--- Macro Button
-- TODO: map results of GetMacroSpell/GetMacroItem to proper results
Macro.HasAction               = function(self) return true end
Macro.GetActionText           = function(self) return (GetMacroInfo(self._state_action)) end
Macro.GetTexture              = function(self) return (select(2, GetMacroInfo(self._state_action))) end
Macro.GetCharges              = function(self) return nil end
Macro.GetCount                = function(self) return 0 end
Macro.GetCooldown             = function(self) return 0, 0, 0 end
Macro.IsAttack                = function(self) return nil end
Macro.IsEquipped              = function(self) return nil end
Macro.IsCurrentlyActive       = function(self) return nil end
Macro.IsAutoRepeat            = function(self) return nil end
Macro.IsUsable                = function(self) return nil end
Macro.IsConsumableOrStackable = function(self) return nil end
Macro.IsUnitInRange           = function(self, unit) return nil end
Macro.SetTooltip              = function(self) return nil end
Macro.GetSpellId              = function(self) return nil end

-----------------------------------------------------------
--- Custom Button
Custom.HasAction               = function(self) return true end
Custom.GetActionText           = function(self) return "" end
Custom.GetTexture              = function(self) return self._state_action.texture end
Custom.GetCharges              = function(self) return nil end
Custom.GetCount                = function(self) return 0 end
Custom.GetCooldown             = function(self) return 0, 0, 0 end
Custom.IsAttack                = function(self) return nil end
Custom.IsEquipped              = function(self) return nil end
Custom.IsCurrentlyActive       = function(self) return nil end
Custom.IsAutoRepeat            = function(self) return nil end
Custom.IsUsable                = function(self) return true end
Custom.IsConsumableOrStackable = function(self) return nil end
Custom.IsUnitInRange           = function(self, unit) return nil end
Custom.SetTooltip              = function(self) return GameTooltip:SetText(self._state_action.tooltip) end
Custom.GetSpellId              = function(self) return nil end
Custom.RunCustom               = function(self, unit, button) return self._state_action.func(self, unit, button) end

--- WoW Classic overrides
--if WoWClassic or WoWBCC or WoWWrath then
--	UpdateOverlayGlow = function() end
--end

-----------------------------------------------------------
--- Update old Buttons
if oldversion and next(lib.buttonRegistry) then
	InitializeEventHandler()
	for button in next, lib.buttonRegistry do
		-- this refreshes the metatable on the button
		Generic.UpdateAction(button, true)
		SetupSecureSnippets(button)
	end
end
