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
local ChatFrames = ns:NewModule("ChatFrames", "LibMoreEvents-1.0", "AceHook-3.0", "AceConsole-3.0", "AceTimer-3.0")

-- Lua API
local _G = _G
local ipairs = ipairs
local pairs = pairs
local string_lower = string.lower

-- WoW API
local FCF_DockFrame = FCF_DockFrame
local FCF_GetChatWindowInfo = FCF_GetChatWindowInfo
local FCF_SetButtonSide = FCF_SetButtonSide
local FCF_SetLocked = FCF_SetLocked
local FCF_SetTabPosition = FCF_SetTabPosition
local FCF_SetWindowAlpha = FCF_SetWindowAlpha
local FCF_SetWindowColor = FCF_SetWindowColor
local FCF_UpdateButtonSide = FCF_UpdateButtonSide
local FCFDock_GetChatFrames = FCFDock_GetChatFrames
local FCFDock_GetInsertIndex = FCFDock_GetInsertIndex
local FCFDock_HideInsertHighlight = FCFDock_HideInsertHighlight
local FCFDock_PlaceInsertHighlight = FCFDock_PlaceInsertHighlight
local GetCursorPosition = GetCursorPosition
local IsMouseButtonDown = IsMouseButtonDown
local UIFrameFadeRemoveFrame = UIFrameFadeRemoveFrame

-- Addon API
local GetFont = ns.API.GetFont
local GetPosition = ns.API.GetPosition
local IsAddOnEnabled = ns.API.IsAddOnEnabled
local SetObjectScale = ns.API.SetObjectScale
local UIHider = ns.Hider

-- Global buttons not unique to any frame
local GLOBAL_BUTTONS = {
	"ChatFrameMenuButton",
	"ChatFrameChannelButton",
	"ChatFrameToggleVoiceDeafenButton",
	"ChatFrameToggleVoiceMuteButton",
	"ChatMenu"
}

-- ChatFrame Texture Suffixes
local TEXTURES = {
	Frame = {
		"Background",
		"TopLeftTexture", "TopRightTexture",
		"BottomLeftTexture", "BottomRightTexture",
		"LeftTexture", "RightTexture",
		"BottomTexture", "TopTexture"
	},
	ButtonFrame = {
		"Background",
		"TopLeftTexture", "TopRightTexture",
		"BottomLeftTexture", "BottomRightTexture",
		"LeftTexture", "RightTexture",
		"BottomTexture", "TopTexture"
	},
	EditBox = {
		"Left", "Mid", "Right",
		"FocusLeft", "FocusMid", "FocusRight",
		"ConversationIcon"
	},
	Tab = {
		"Left", "Middle", "Right",
		"SelectedLeft", "SelectedMiddle", "SelectedRight",
		"HighlightLeft", "HighlightMiddle", "HighlightRight",
		"ActiveLeft", "ActiveMiddle", "ActiveRight" -- 10.0
	}
}

-- Local element cache for lookups without member properties
local Elements = setmetatable({}, { __index = function(t,k) rawset(t,k,{}) return rawget(t,k) end })

local Tab_PostEnter = function(tab)
	local frame = _G["ChatFrame"..tab:GetID()]
	Elements[frame].isMouseOverTab = true
	ChatFrames:UpdateClutter()
end

local Tab_PostLeave = function(tab)
	local frame = _G["ChatFrame"..tab:GetID()]
	Elements[frame].isMouseOverTab = false
	ChatFrames:UpdateClutter()
end

-------------------------------------------------------
-- Custom ChatFrame API
-------------------------------------------------------
local ChatFrame = {}

-- Getters
-------------------------------------------------------
ChatFrame.GetEditBox = function(self)
	if (not Elements[self].editBox) then
		Elements[self].editBox = _G[self:GetName().."EditBox"]
	end
	return Elements[self].editBox
end

ChatFrame.GetButtonFrame = function(self)
	if (not Elements[self].buttonFrame) then
		Elements[self].buttonFrame = _G[self:GetName().."ButtonFrame"]
	end
	return Elements[self].buttonFrame
end

ChatFrame.GetMinimizeButton = function(self)
	if (not Elements[self].minimizeButton) then
		Elements[self].minimizeButton = _G[self:GetName().."ButtonFrameMinimizeButton"]
	end
	return Elements[self].minimizeButton
end

ChatFrame.GetUpButton = function(self)
	if (not Elements[self].upButton) then
		Elements[self].upButton = _G[self:GetName().."ButtonFrameUpButton"]
	end
	return Elements[self].upButton
end

ChatFrame.GetDownButton = function(self)
	if (not Elements[self].downButton) then
		Elements[self].downButton = _G[self:GetName().."ButtonFrameDownButton"]
	end
	return Elements[self].downButton
end

ChatFrame.GetToBottomButton = function(self)
	if (not Elements[self].scrollToBottomButton) then
		Elements[self].scrollToBottomButton = _G[self:GetName().."ButtonFrameBottomButton"]
	end
	return Elements[self].scrollToBottomButton
end

ChatFrame.GetScrollBar = function(self)
	if (not Elements[self].scrollBar) then
		Elements[self].scrollBar = self.ScrollBar
	end
	return Elements[self].scrollBar
end

ChatFrame.GetScrollBarThumbTexture = function(self)
	if (not Elements[self].scrollBarThumbTexture) then
		Elements[self].scrollBarThumbTexture = self.ScrollBar and self.ScrollBar.ThumbTexture
	end
	return Elements[self].scrollBarThumbTexture
end

ChatFrame.GetTab = function(self)
	if (not Elements[self].tab) then
		Elements[self].tab = self.tab or _G[self:GetName() .. "Tab"]
	end
	return Elements[self].tab
end

ChatFrame.GetTabIcon = function(self)
	if (not Elements[self].tabIcon) then
		Elements[self].tabIcon = _G[self:GetName().."TabConversationIcon"]
	end
	return Elements[self].tabIcon
end

ChatFrame.GetTabText = function(self)
	if (not Elements[self].tabText) then
		Elements[self].tabText = _G[self:GetName().."TabText"] or _G[self:GetName().."Tab"].Text -- 10.0.0
	end
	return Elements[self].tabText
end

-- Iterators
-------------------------------------------------------
-- Returns an iterator for the chatframe textures
ChatFrame.GetFrameTextures = function(self)
	local editBox = ChatFrame.GetEditBox(self)
	if (editBox) then
		local counter = 0
		local numEntries = #TEXTURES.Frame
		local name = self:GetName()
		return function()
			local tex
			while (numEntries > counter) do
				counter = counter + 1
				tex = _G[name..TEXTURES.Frame[counter]]
				if (tex) then
					break
				end
			end
			if (counter <= numEntries) then
				return tex
			end
		end
	end
end

-- Returns an iterator for the buttonframe textures
ChatFrame.GetButtonFrameTextures = function(self)
	local buttonFrame = ChatFrame.GetButtonFrame(self)
	if (buttonFrame) then
		local counter = 0
		local numEntries = #TEXTURES.ButtonFrame
		local name = buttonFrame:GetName()
		return function()
			local tex
			while (numEntries > counter) do
				counter = counter + 1
				tex = _G[name..TEXTURES.ButtonFrame[counter]]
				if (tex) then
					break
				end
			end
			if (counter <= numEntries) then
				return tex
			end
		end
	end
end

-- Returns an iterator for the editbox textures
ChatFrame.GetEditBoxTextures = function(self)
	local editBox = ChatFrame.GetEditBox(self)
	if (editBox) then
		local counter = 0
		local numEntries = #TEXTURES.EditBox
		local name = editBox:GetName()
		return function()
			local tex
			while (numEntries > counter) do
				counter = counter + 1
				tex = _G[name..TEXTURES.EditBox[counter]]
				if (tex) then
					break
				end
			end
			if (counter <= numEntries) then
				return tex
			end
		end
	end
end

-- Returns an iterator for the tab textures
ChatFrame.GetTabTextures = function(self)
	local tab = ChatFrame.GetTab(self)
	if (tab) then
		local counter = 0
		local numEntries = #TEXTURES.Tab
		local name = tab:GetName()
		return function()
			local tex
			while (numEntries > counter) do
				counter = counter + 1
				tex = _G[name..TEXTURES.Tab[counter]] or tab[TEXTURES.Tab[counter]] -- 10.0
				if (tex) then
					break
				end
			end
			if (counter <= numEntries) then
				return tex
			end
		end
	end
end

-------------------------------------------------------
-- Module API
-------------------------------------------------------
ChatFrames.StyleFrame = function(self, frame)
	if (frame.isSkinned) then return end

	-- Embed our API
	for method,func in next,ChatFrame do
		frame[method] = func
	end

	if (frame:GetID() == 2) then
		local buttonframe = CombatLogQuickButtonFrame_Custom
		for i = 1, buttonframe:GetNumRegions() do
			local region = select(i, buttonframe:GetRegions())
			if (region and region:GetObjectType() == "Texture") then
				region:SetTexture(nil)
			end
		end
	end

	SetObjectScale(frame)

	-- Kill frame textures.
	for tex in frame:GetFrameTextures() do
		tex:SetTexture(nil)
		tex:SetAlpha(0)
	end

	local buttonFrame = frame:GetButtonFrame()

	-- Take control of the tab's alpha changes
	-- and disable blizzard's own fading.
	--buttonFrame:SetAlpha(1)
	--buttonFrame.SetAlpha = UIFrameFadeRemoveFrame

	-- Kill the button frame textures.
	for tex in frame:GetButtonFrameTextures() do
		tex:SetTexture(nil)
		tex:SetAlpha(0)
	end

	local tab = frame:GetTab()
	local fontObject = GetFont(15,true,"Chat")

	-- Take control of the tab's alpha changes
	-- and disable blizzard's own fading.
	tab:SetNormalFontObject(fontObject)
	--tab:SetAlpha(1)
	--tab.SetAlpha = UIFrameFadeRemoveFrame

	for tex in frame:GetTabTextures() do
		tex:SetTexture(nil)
		tex:SetAlpha(0)
	end

	local tabText = frame:GetTabText()
	tabText:Hide()
	tabText:SetAlpha(.5)
	tabText:SetFontObject(fontObject)

	local tabIcon = frame:GetTabIcon()
	if (tabIcon) then
		tabIcon:Hide()
	end

	-- Toggle tab text visibility on hover
	tab:HookScript("OnEnter", Tab_PostEnter)
	tab:HookScript("OnLeave", Tab_PostLeave)

	local editBox = frame:GetEditBox()
	for tex in frame:GetEditBoxTextures() do
		tex:SetTexture(nil)
		tex:SetAlpha(0)
	end
	editBox:Hide()
	editBox:SetAltArrowKeyMode(false)
	editBox:SetHeight(45)
	editBox:ClearAllPoints()
	editBox:SetPoint("LEFT", frame, "LEFT", -15, 0)
	editBox:SetPoint("RIGHT", frame, "RIGHT", 15, 0)
	editBox:SetPoint("TOP", frame, "BOTTOM", 0, -1)

	self:UpdateChatFont(frame)
	self:SecureHook(frame, "SetFont", "UpdateChatFont")

end

ChatFrames.StyleTempFrame = function(self)
	local frame = FCF_GetCurrentChatFrame()
	if (not frame or frame.isSkinned) then return end
	self:StyleFrame(frame)
end

ChatFrames.SetChatFramePosition = function(self, frame)
	local id = frame:GetID()

	if (id == 1) then
		if (not ns.IsRetail) then
			frame.ignoreFramePositionManager = true
		end

		frame:SetUserPlaced(false)
		frame:SetSize(self:GetDefaultChatFrameSize())
		frame:ClearAllPoints()
		frame:SetPoint(self:GetDefaultChatFramePosition())

		if (ns.IsRetail) then
			hooksecurefunc(frame, "SetPoint", function(frame)
				frame:ClearAllPoints()
				frame:SetPointBase(self:GetDefaultChatFramePosition())
			end)
		end

	else
		-- add back code to fix scale and positions of other frames here. Ignore for now.
	end

end

ChatFrames.SaveChatFramePositionAndDimensions = function(self)
end

ChatFrames.UpdateTabAlpha = function(self, frame)
	local tab = frame:GetTab()
	if (tab.noMouseAlpha == .4 or tab.noMouseAlpha == .2) then
		tab:SetAlpha(0)
		tab.noMouseAlpha = 0
	end
end

ChatFrames.UpdateChatFont = function(self, frame)
	if (not frame) then return end
	local font,_,style = GetFont(14,true,"Chat"):GetFont()
	local currentFont, currentSize, currentStyle = frame:GetFont()
	if (font == currentFont and style == currentStyle) then
		return
	end
	frame:SetFont(font, currentSize, style)
end

ChatFrames.UpdateButtons = function(self, event, ...)

	local atDock
	for _,frameName in pairs(_G.CHAT_FRAMES) do
		local frame = _G[frameName]
		if (frame) then
			local name, fontSize, r, g, b, a, shown, locked, docked, uninteractable = FCF_GetChatWindowInfo(frame:GetID())
			local isMouseOver

			if (frame == ChatFrame2) then
				isMouseOver = frame:IsMouseOver(60,0,-30,30)
			else
				isMouseOver = frame:IsMouseOver(30,0,-30,30)
			end

			if (isMouseOver) and (shown and shown ~= 0) and (not frame.minimized) then
				if (docked or frame == ChatFrame1) then -- dock position or nil
					atDock = true
				end

				if (not Elements[frame].isMouseOver) then

					local buttonFrame = ChatFrame.GetButtonFrame(frame)
					local up = ChatFrame.GetUpButton(frame)
					local down = ChatFrame.GetDownButton(frame)
					local bottom = ChatFrame.GetToBottomButton(frame)

					if (up) then up:SetParent(buttonFrame) end
					if (down) then down:SetParent(buttonFrame) end
					if (bottom) then bottom:SetParent(buttonFrame) end

					local tabText = ChatFrame.GetTabText(frame)
					tabText:Show()

					if (ChatFrame.GetTab(frame):IsMouseOver()) then
						tabText:SetAlpha(.9)
					else
						tabText:SetAlpha(.5)
					end

					Elements[frame].isMouseOver = true
				end
			else
				-- Todo: check out what happens when minimized.
				if (event == "PLAYER_ENTERING_WORLD") or (Elements[frame].isMouseOver) then

					local up = ChatFrame.GetUpButton(frame)
					local down = ChatFrame.GetDownButton(frame)
					local bottom = ChatFrame.GetToBottomButton(frame)

					if (up) then up:SetParent(UIHider) end
					if (down) then down:SetParent(UIHider) end
					if (bottom) then bottom:SetParent(UIHider) end

					ChatFrame.GetTabText(frame):Hide()

					Elements[frame].isMouseOver = false
				end
			end
		end
	end

	if (atDock) then
		for button in self:GetGlobalButtons() do
			button:SetAlpha(1)
		end
	else
		for button in self:GetGlobalButtons() do
			button:SetAlpha(0)
		end
	end

end

ChatFrames.UpdateClutter = function(self, event, ...)
	self:UpdateButtons(event, ...)
end

ChatFrames.GetDefaultChatFrameSize = function(self)
	return 475,228
end

ChatFrames.GetDefaultChatFramePosition = function(self)
	return "BOTTOMLEFT", 54, 310
end

ChatFrames.GetGlobalButtons = function(self)
	local counter = 0
	local numEntries = #GLOBAL_BUTTONS
	return function()
		local button
		while (numEntries > counter) do
			counter = counter + 1
			button = _G[GLOBAL_BUTTONS[counter]]
			if (button) then
				break
			end
		end
		if (counter <= numEntries) then
			return button
		end
	end
end

ChatFrames.OnEvent = function(self, event, ...)
	if (event == "PLAYER_ENTERING_WORLD") then
		local isInitialLogin, isReloadingUi = ...
		if (isInitialLogin or isReloadingUi) then

			for i = 1, NUM_CHAT_WINDOWS do
				local chatFrame = _G["ChatFrame"..i]
				self:StyleFrame(chatFrame)
				self:SetChatFramePosition(chatFrame)
			end

			self:UpdateButtons(event, ...)

			self:SecureHook("FCF_OpenTemporaryWindow", "StyleTempFrame")
			self:ScheduleRepeatingTimer("UpdateClutter", 1/10)

			if (ns.IsRetail) then
				QuickJoinToastButton:UnregisterAllEvents()
				QuickJoinToastButton:SetParent(UIHider)
				QuickJoinToastButton:Hide()
			end

			if (not ns.IsRetail) then
				self:RegisterEvent("UPDATE_FLOATING_CHAT_WINDOWS", "OnEvent")
				self:RegisterEvent("UPDATE_CHAT_WINDOWS", "OnEvent")
				self:RegisterEvent("VARIABLES_LOADED", "OnEvent")
			end

			ChatFrame1:Clear()
		end
	elseif (event == "VARIABLES_LOADED" or event == "UPDATE_CHAT_WINDOWS" or event == "UPDATE_FLOATING_CHAT_WINDOWS") then
		for i = 1, NUM_CHAT_WINDOWS do
			local chatFrame = _G["ChatFrame"..i]
			self:SetChatFramePosition(chatFrame)
		end
	end
end

ChatFrames.OnInitialize = function(self)
	if (IsAddOnEnabled("Prat-3.0") or IsAddOnEnabled("Glass")) then
		return self:Disable()
	end

	local scaffold = SetObjectScale(CreateFrame("Frame", nil, UIParent))
	scaffold:SetSize(self:GetDefaultChatFrameSize())
	scaffold:SetPoint(self:GetDefaultChatFramePosition())
	self.frame = scaffold

	if (CHAT_FONT_HEIGHTS) then
		for i = #CHAT_FONT_HEIGHTS, 1, -1 do
			CHAT_FONT_HEIGHTS[i] = nil
		end
		for i,v in ipairs({ 12, 14, 16, 18, 20, 22, 24, 28, 32 }) do
			CHAT_FONT_HEIGHTS[i] = v
		end
	end

	--self:RegisterChatCommand("resetchat", "ResetChat")

end

ChatFrames.OnEnable = function(self)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
end
