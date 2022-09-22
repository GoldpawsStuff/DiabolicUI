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
local StanceBar = ActionBars:NewModule("StanceBar", "LibMoreEvents-1.0")

-- Lua API
local getmetatable = getmetatable
local ipairs = ipairs
local pairs = pairs
local select = select
local setmetatable = setmetatable
local string_format = string.format
local tostring = tostring
local type = type

-- WoW API
local ClearOverrideBindings = ClearOverrideBindings
local CooldownFrame_Set = CooldownFrame_Set
local CreateFrame = CreateFrame
local GameTooltip_SetDefaultAnchor = GameTooltip_SetDefaultAnchor
local GetBindingKey = GetBindingKey
local GetNumShapeshiftForms = GetNumShapeshiftForms
local GetShapeshiftFormCooldown = GetShapeshiftFormCooldown
local GetShapeshiftFormInfo = GetShapeshiftFormInfo
local InCombatLockdown = InCombatLockdown
local PlaySound = PlaySound
local SetOverrideBindingClick = SetOverrideBindingClick

-- Addon API
local Colors = ns.Colors
local GetFont = ns.API.GetFont
local GetMedia = ns.API.GetMedia
local RegisterCooldown = ns.Widgets.RegisterCooldown
local SetObjectScale = ns.API.SetObjectScale
local UIHider = ns.Hider
local noop = ns.Noop

local style = function(button)

	local bSize,bPad = 51,1

	--button:DisableDragNDrop(true)
	--button:SetAttribute("buttonLock", true)
	button:SetSize(bSize,bSize)

	--local backdrop = button:CreateTexture(nil, "BACKGROUND", nil, -7)
	--backdrop:SetSize(64,64)
	--backdrop:SetPoint("CENTER")
	--backdrop:SetTexture(GetMedia("button-big-circular"))
	--backdrop:SetVertexColor(.8, .76, .72)
	--backdrop:SetTexture(GetMedia("button-big"))

	local backdrop = button:CreateTexture(nil, "BACKGROUND", nil, -7)
	backdrop:SetSize(64,64)
	backdrop:SetPoint("CENTER")
	backdrop:SetTexture(GetMedia("button-big"))

	local name = button:GetName()
	local blankTexture = GetMedia("blank")
	--local maskTexture = GetMedia("actionbutton-mask-circular")
	local maskTexture = GetMedia("actionbutton-mask-square-rounded")

	local cooldown = _G[name.."Cooldown"]
	local count = _G[name.."Count"]
	local flash	= _G[name.."Flash"]
	local hotkey = _G[name.."HotKey"]
	local icon = _G[name.."Icon"]

	button.backdrop = backdrop
	button.cooldown = cooldown
	button.count = count
	button.flash = flash
	button.hotkey = hotkey
	button.icon = icon

	button.normalTexture = button:GetNormalTexture()
	button.normalTexture:SetTexture("")

	button.checkedTexture = button:GetCheckedTexture()
	button.checkedTexture:SetTexture("")

	button.highlightTexture = button:GetHighlightTexture()
	button.highlightTexture:SetTexture("")

	local overlayFrame = CreateFrame("Frame", nil, button)
	overlayFrame:SetFrameLevel(button:GetFrameLevel() + 2)
	overlayFrame:SetAllPoints()

	--local spellHighlight = overlayFrame:CreateTexture(nil, "ARTWORK", nil, -7)
	--spellHighlight:SetTexture(GetMedia("actionbutton-spellhighlight-square-rounded"))
	--spellHighlight:SetSize(92,92)
	--spellHighlight:SetPoint("CENTER", 0, 0)
	--button.SpellHighlight = spellHighlight

	if (icon) then
		icon:SetDrawLayer("BACKGROUND", 1)
		icon:ClearAllPoints()
		icon:SetPoint("TOPLEFT", 3, -3)
		icon:SetPoint("BOTTOMRIGHT", -3, 3)
		icon:SetMask(maskTexture)

		local desaturator = button:CreateTexture(nil, "BACKGROUND", nil, 2)
		desaturator:SetAllPoints(icon)
		desaturator:SetMask(maskTexture)
		desaturator:SetTexture(icon:GetTexture())
		desaturator:SetDesaturated(true)
		desaturator:SetVertexColor(icon:GetVertexColor())
		desaturator:SetAlpha(.2)
		desaturator.alpha = .2
		icon.desaturator = desaturator

		for i,v in pairs((getmetatable(icon).__index)) do
			if (type(v) == "function") then
				local method = v
				if (i == "SetTexture") then
					icon[i] = function(icon, ...)
						method(icon, ...)
						method(desaturator, ...)
						desaturator:SetDesaturated(true)
						desaturator:SetVertexColor(icon:GetVertexColor())
						desaturator:SetAlpha(desaturator.alpha or .2)
					end
				elseif (i == "SetVertexColor") then
					icon[i] = function(icon, r, g, b, a)
						method(icon, r, g, b, a)
						method(desaturator, r, g, b)
					end
				elseif (i == "SetAlpha") then
					icon[i] = function(icon, ...)
						method(icon, ...)
						desaturator:SetAlpha(desaturator.alpha or .2)
					end
				elseif (i ~= "SetDesaturated") then
					icon[i] = function(icon, ...)
						method(icon, ...)
						method(desaturator, ...)
					end
				end
			end
		end

		local darken = button:CreateTexture(nil, "BACKGROUND", nil, 3)
		darken:SetAllPoints(icon)
		darken:SetTexture(maskTexture)
		darken:SetVertexColor(0, 0, 0, .25)

		icon:SetAlpha(.85)

		button:SetScript("OnEnter", function(self)
			darken:SetAlpha(0)
			if (self.OnEnter) then
				self:OnEnter()
			end
		end)

		button:SetScript("OnLeave", function(self)
			darken:SetAlpha(.25)
			if (self.OnLeave) then
				self:OnLeave()
			end
		end)
	end

	if (cooldown) then
		cooldown:ClearAllPoints()
		cooldown:SetAllPoints(icon or button)
		cooldown:SetReverse(false)
		cooldown:SetSwipeTexture(maskTexture)
		cooldown:SetSwipeColor(0, 0, 0, .75)
		cooldown:SetDrawSwipe(true)
		cooldown:SetBlingTexture(blankTexture, 0, 0, 0, 0)
		cooldown:SetDrawBling(false)
		cooldown:SetEdgeTexture(blankTexture)
		cooldown:SetDrawEdge(false)
		cooldown:SetHideCountdownNumbers(true)

		-- Attempting to fix the issue with too opaque swipe textures
		cooldown:HookScript("OnShow", function()
			cooldown:SetSwipeColor(0, 0, 0, .75)
			cooldown:SetDrawSwipe(true)
			cooldown:SetBlingTexture(GetMedia("blank"), 0, 0, 0 , 0)
			cooldown:SetDrawBling(true)
			cooldown:SetHideCountdownNumbers(true)
		end)


		local cooldownCount = overlayFrame:CreateFontString()
		cooldownCount:SetDrawLayer("ARTWORK", 1)
		cooldownCount:SetPoint("CENTER", 1, 0)
		cooldownCount:SetFontObject(GetFont(16,true))
		cooldownCount:SetJustifyH("CENTER")
		cooldownCount:SetJustifyV("MIDDLE")
		cooldownCount:SetShadowOffset(0, 0)
		cooldownCount:SetShadowColor(0, 0, 0, 0)
		cooldownCount:SetTextColor(250/255, 250/255, 250/255, .85)
		button.cooldownCount = cooldownCount

		RegisterCooldown(cooldown, cooldownCount)
	end

	if (count) then
		count:SetParent(overlayFrame)
		count:ClearAllPoints()
		count:SetPoint("BOTTOMRIGHT", 0, 2)
		count:SetFontObject(GetFont(14,true))
	end

	if (hotkey) then
		hotkey:SetParent(overlayFrame)
		hotkey:ClearAllPoints()
		hotkey:SetPoint("TOPRIGHT", 0, -3)
		hotkey:SetFontObject(GetFont(12,true))
		hotkey:SetTextColor(.75, .75, .75)
	end

	if (flash) then
		flash:SetDrawLayer("ARTWORK", 2)
		flash:SetAllPoints(icon or button)
		flash:SetVertexColor(1, 0, 0, .25)
		flash:SetTexture(maskTexture)
		flash:Hide()
	end

	-- We're letting blizzard handle this one,
	-- in order to catch both mouse clicks and keybind clicks.
	local pushedTexture = button:CreateTexture(nil, "ARTWORK", nil, 1)
	pushedTexture:SetVertexColor(1, 1, 1, .05)
	pushedTexture:SetTexture(maskTexture)
	pushedTexture:SetAllPoints(icon)
	button:SetPushedTexture(pushedTexture)
	button:GetPushedTexture():SetBlendMode("ADD")
	button:GetPushedTexture():SetDrawLayer("ARTWORK", 2) -- must be updated after pushed texture has been set

	local checkedTexture = button:CreateTexture(nil, "ARTWORK", nil, 1)
	checkedTexture:SetVertexColor(1, 1, 1, .25)
	checkedTexture:SetTexture(maskTexture)
	checkedTexture:SetAllPoints(icon)
	button:SetCheckedTexture(checkedTexture)
	button:GetCheckedTexture():SetBlendMode("ADD")
	button:GetCheckedTexture():SetDrawLayer("ARTWORK", 1) -- must be updated after pushed texture has been set


	local highlightTexture = button:CreateTexture()
	highlightTexture:SetDrawLayer("BACKGROUND", 1)
	highlightTexture:SetTexture(maskTexture)
	highlightTexture:SetAllPoints(icon)
	highlightTexture:SetVertexColor(1, 1, 1, .1)
	button:SetHighlightTexture(highlightTexture)


	-- We don't want direct external styling of these buttons.
	button.AddToButtonFacade = noop
	button.AddToMasque = noop

	ns.StanceButtons[button] = true

	return button
end

-- StanceButton Template
local Button = CreateFrame("CheckButton")
local Button_MT = {__index = Button}

-- StanceBar Template
local Bar = CreateFrame("Button")
local Bar_MT = {__index = Bar}

ns.StanceButtons = {}
ns.StanceButton = Button
ns.StanceBar = Bar

Button.Create = function(self, id, header, styleFunc)

	local name = ns.Prefix.."StanceButton"..id
	local button = setmetatable(CreateFrame("CheckButton", name, header, "StanceButtonTemplate"), Button_MT)
	if (styleFunc) then
		styleFunc(button)
	end
	button:Hide()
	button:SetID(id)
	button.id = id
	button.parent = header

	button:SetScript("OnEnter", Button.OnEnter)
	button:SetScript("OnLeave", Button.OnLeave)

	return button
end

Button.OnEnter = function(self)
	if (GameTooltip:IsForbidden()) then
		return
	end
	GameTooltip_SetDefaultAnchor(GameTooltip, self)
	GameTooltip:SetShapeshift(self:GetID())
	self.UpdateTooltip = self.OnEnter
end

Button.OnLeave = function(self)
	if (GameTooltip:IsForbidden()) then
		return
	end
	self.UpdateTooltip = nil
	GameTooltip:Hide()
end

Button.Update = function(self)
	if (not self:IsShown()) then
		return
	end
	local id = self:GetID()
	local texture, isActive, isCastable, spellID = GetShapeshiftFormInfo(id)

	self.icon:SetTexture(texture)

	if (texture) then
		self.cooldown:Show()
	else
		self.cooldown:Hide()
	end

	local start, duration, enable = GetShapeshiftFormCooldown(id)
	self.cooldown:SetCooldown(start, duration)

	if (isActive) then
		self:SetChecked(true)
	else
		self:SetChecked(false)
	end

	if (isCastable) then
		self.icon:SetVertexColor(1, 1, 1)
	else
		self.icon:SetVertexColor(.4, .4, .4)
	end

	self:UpdateHotkeys()

end

Button.UpdateHotkeys = function(self)
end

Bar.Create = function(self, name, parent)
	local bar = setmetatable(SetObjectScale(CreateFrame("Frame", name, parent, "SecureHandlerStateTemplate")), Bar_MT)
	bar:SetFrameStrata("BACKGROUND")
	bar:SetFrameLevel(10)
	bar.buttons = {}

	return bar
end

Bar.CreateButton = function(self, id, styleFunc)

	local button = ns.StanceButton:Create(id, self, styleFunc)
	button.keyBoundTarget = string_format("SHAPESHIFTBUTTON%d", id)

	self.buttons[#self.buttons + 1] = button

	return button
end

Bar.ForAll = function(self, method, ...)
	for id,button in self:GetAll() do
		local func = button[method]
		if (func) then
			func(button, ...)
		end
	end
end

Bar.GetAll = function(self)
	return pairs(self.buttons)
end

Bar.Enable = function(self)
	if (InCombatLockdown()) then
		return
	end
	self.enabled = true
	self:UpdateStates()
end

Bar.Disable = function(self)
	if (InCombatLockdown()) then
		return
	end
	self.enabled = false
	UnregisterStateDriver(self, "state-vis")
	self:SetAttribute("state-vis", "0")
	RegisterStateDriver(self, "vis", "hide")
end

Bar.IsEnabled = function(self)
	if (self.enabled) then
		return true
	elseif (self.enabled == false) then
		return false
	else
		return nil
	end
end

Bar.UpdateBackdrop = function(self)
end

Bar.UpdateBindings = function(self)
	if (InCombatLockdown()) then
		return
	end
	if (not self.buttons) then
		return
	end
	ClearOverrideBindings(self)
	for id,button in ipairs(self.buttons) do
		local bindingAction = button.keyBoundTarget
		if (bindingAction) then
			-- iterate through the registered keys for the action
			local buttonName = button:GetName()
			for keyNumber = 1,select("#", GetBindingKey(bindingAction)) do
				-- get a key for the action
				local key = select(keyNumber, GetBindingKey(bindingAction))
				if (key and (key ~= "")) then
					-- this is why we need named buttons
					SetOverrideBindingClick(self, false, key, buttonName) -- assign the key to our own button
				end
			end
		end
	end
end

Bar.UpdateButtons = function(self)
	local buttons = self.buttons
	local numStances = GetNumShapeshiftForms()
	for i = 1, numStances do
		buttons[i]:Show()
		buttons[i]:Update()
	end
	for i = numStances+1, #buttons do
		buttons[i]:Hide()
	end
end

Bar.UpdateStates = function(self)
	if (InCombatLockdown()) then
		return
	end

	self:SetAttribute("_onstate-vis", [[
		if not newstate then return end
		if newstate == "show" then
			self:Show()
		elseif newstate == "hide" then
			self:Hide()
		end
	]])

	UnregisterStateDriver(self, "state-vis")
	self:SetAttribute("state-vis", "0")
	RegisterStateDriver(self, "vis", "[petbattle][possessbar][overridebar][vehicleui][target=vehicle,exists]hide;show")
end

StanceBar.Create = function(self)
	if (not self.Bar) then
		local bar = SetObjectScale(ns.StanceBar:Create(ns.Prefix.."StanceBar", UIParent))
		bar:Hide()
		bar:SetFrameStrata("MEDIUM")

		-- Embed our custom methods.
		--for method,func in pairs(Bar) do
		--	bar[method] = func
		--end

		local button
		for i = 1,10 do
			button = bar:CreateButton(i, style)
			button:SetPoint("BOTTOMLEFT", (i-1)*(54), 0)
			bar:SetFrameRef("Button"..i, button)
		end
		bar:UpdateStates()

		local button = SetObjectScale(CreateFrame("CheckButton", nil, UIParent, "SecureHandlerClickTemplate"))
		button:SetFrameRef("StanceBar", bar)
		button:RegisterForClicks("AnyUp")
		button:SetAttribute("_onclick", [[
			local bar = self:GetFrameRef("StanceBar");
			bar:UnregisterAutoHide();
			bar:Show();

			local button;
			local numButtons = 0;
			for i = 1,10 do
				button = bar:GetFrameRef("Button"..i);
				if (button:IsShown()) then
					numButtons = numButtons + 1;
				end
			end
			if (numButtons > 0) then
				bar:SetWidth(numButtons*53 + (numButtons-1));
				bar:SetHeight(53);
			else
				bar:SetWidth(2);
				bar:SetHeight(2);
			end
			bar:CallMethod("UpdateBackdrop");

			bar:RegisterAutoHide(.75);
			bar:AddToAutoHide(self);

			for i = 1,numButtons do
				button = bar:GetFrameRef("Button"..i);
				if (button:IsShown()) then
					bar:AddToAutoHide(button);
				end
			end
		]])

		button:SetSize(32,32)
		bar:SetPoint("BOTTOM", button, "TOP", 0, 4)

		local backdrop = button:CreateTexture(nil, "BACKGROUND", nil, -7)
		backdrop:SetSize(32,32)
		backdrop:SetPoint("CENTER")
		backdrop:SetTexture(GetMedia("plus"))
		button.Backdrop = backdrop

		-- Called after secure click handler, I think.
		button:HookScript("OnClick", function()
			if (bar:IsShown()) then
				PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON, "SFX")
			else
				PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF, "SFX")
			end
		end)

		button:HookScript("OnEnter", function(self)
		end)

		button:HookScript("OnLeave", function(self)
		end)

		self.Bar = bar
		self.ToggleButton = button

	end
end

StanceBar.ForAll = function(self, method, ...)
	if (self.Bar) then
		self.Bar:ForAll(method, ...)
	end
end

StanceBar.UpdateBindings = function(self)
	if (self.Bar) then
		self.Bar:UpdateBindings()
	end
end

StanceBar.UpdateStanceButtons = function(self)
	if (InCombatLockdown()) then
		self.updateStateOnCombatLeave = true
		return
	end
	if (self.Bar) then
		self.Bar:UpdateButtons()
		local numStances = GetNumShapeshiftForms()
		if (numStances and numStances > 0) then
			self.ToggleButton:Show()
		else
			self.ToggleButton:Hide()
		end
	end
end

StanceBar.UpdateToggleButton = function(self)
	if (not self.ToggleButton) then
		return
	end
	if (ActionBars:HasSecondaryBar()) then
		self.ToggleButton:SetPoint("BOTTOM", 0, 70 + 100)
	else
		self.ToggleButton:SetPoint("BOTTOM", 0, 11 + 100)
	end
end

StanceBar.OnEvent = function(self, event, ...)
	if (event == "UPDATE_SHAPESHIFT_COOLDOWN") then
		self:ForAll("Update")

	elseif (event == "PLAYER_REGEN_ENABLED") then
		if (self.updateStateOnCombatLeave) and (not InCombatLockdown()) then
			self.updateStateOnCombatLeave = nil
			self:UpdateStanceButtons()
		end
	else
		if (event == "PLAYER_ENTERING_WORLD") then
			if (self.Bar) then
				self.Bar:Hide()
			end
			self:UpdateStanceButtons()
			self:UpdateToggleButton()
			return
		end
		if (InCombatLockdown()) then
			self.updateStateOnCombatLeave = true
			self:ForAll("Update")
		else
			self:UpdateStanceButtons()
		end
	end
end

StanceBar.OnInitialize = function(self)
	-- Currently only allowing this for git versions in development mode
	if (not ns.db.global.core.enableDevelopmentMode or not ns.IsDevelopment) then
		self:Disable()
		return
	end
	self:Create()
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
	self:RegisterEvent("UPDATE_BONUS_ACTIONBAR", "OnEvent")
	self:RegisterEvent("ACTIONBAR_PAGE_CHANGED", "OnEvent")
	self:RegisterEvent("UPDATE_SHAPESHIFT_FORM", "OnEvent")
	self:RegisterEvent("UPDATE_SHAPESHIFT_FORMS", "OnEvent")
	self:RegisterEvent("UPDATE_SHAPESHIFT_USABLE", "OnEvent")
	self:RegisterEvent("UPDATE_SHAPESHIFT_COOLDOWN", "OnEvent")
	self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
	self:RegisterEvent("UPDATE_VEHICLE_ACTIONBAR", "OnEvent")
	self:RegisterEvent("UPDATE_OVERRIDE_ACTIONBAR", "OnEvent")
	self:RegisterEvent("UPDATE_POSSESS_BAR", "OnEvent")
	self:RegisterEvent("UPDATE_BINDINGS", "UpdateBindings")
	ns.RegisterCallback(self, "ActionBars_SecondaryBar_Updated", "UpdateToggleButton")
end

StanceBar.OnEnable = function(self)
	self:UpdateBindings()
	self:UpdateToggleButton()
end
