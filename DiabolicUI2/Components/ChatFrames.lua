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
local ChatFrames = ns:NewModule("ChatFrames", "LibMoreEvents-1.0", "AceHook-3.0")

-- Lua API
local _G = _G
local pairs = pairs
local ipairs = ipairs
local string_format = string.format

-- WoW API
local FCF_GetChatWindowInfo = FCF_GetChatWindowInfo
local FCF_SetLocked = FCF_SetLocked
local FCF_SetWindowAlpha = FCF_SetWindowAlpha
local FCF_SetWindowColor = FCF_SetWindowColor
local FCFDock_GetChatFrames = FCFDock_GetChatFrames
local hooksecurefunc = hooksecurefunc
local UIFrameFadeRemoveFrame = UIFrameFadeRemoveFrame

-- Addon API
local GetFont = ns.API.GetFont
local SetObjectScale = ns.API.SetObjectScale
local UIHider = ns.Hider

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
		"HighlightLeft", "HighlightMiddle", "HighlightRight"
	}
}

-- Custom ChatFrame API
-------------------------------------------------------
local ChatFrame = {}
local Elements = setmetatable({}, { __index = function(t,k) rawset(t,k,{}) return rawget(t,k) end })

ChatFrame.GetTextures = function(self)
	local counter = 0
	local name = self:GetName()
	return function()
		counter = counter + 1
		if (TEXTURES.Frame[counter]) then
			local tex = _G[name..TEXTURES.Frame[counter]]
			if (tex) then
				return tex
			end
		end
	end
end

ChatFrame.GetEditBox = function(self)
	if (not Elements[self].editBox) then
		Elements[self].editBox = _G[self:GetName().."EditBox"]
	end
	return Elements[self].editBox
end

ChatFrame.GetEditBoxTextures = function(self)
	local counter = 0
	local editBox = ChatFrame.GetEditBox(self)
	if (editBox) then
		local name = editBox:GetName()
		return function()
			counter = counter + 1
			if (TEXTURES.EditBox[counter]) then
				local tex = _G[name..TEXTURES.EditBox[counter]]
				if tex then
					return tex
				end
			end
		end
	end
end

ChatFrame.GetButtonFrame = function(self)
	if (not Elements[self].buttonFrame) then
		Elements[self].buttonFrame = _G[self:GetName().."ButtonFrame"]
	end
	return Elements[self].buttonFrame
end

ChatFrame.GetButtonFrameTextures = function(self)
	local counter = 0
	local buttonFrame = ChatFrame.GetButtonFrame(self)
	if buttonFrame then
		local name = buttonFrame:GetName()
		return function()
			counter = counter + 1
			if TEXTURES.ButtonFrame[counter] then
				local tex = _G[name..TEXTURES.ButtonFrame[counter]]
				if tex then
					return tex
				end
			end
		end
	end
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
		Elements[self].tab = _G[self:GetName() .. "Tab"]
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
		Elements[self].tabText = _G[self:GetName().."TabText"]
	end
	return Elements[self].tabText
end

ChatFrame.GetTabTextures = function(self)
	local counter = 0
	local tab = ChatFrame.GetTab(self)
	if (tab) then
		local name = tab:GetName()
		return function()
			counter = counter + 1
			if (TEXTURES.Tab[counter]) then
				local tex = _G[name..TEXTURES.Tab[counter]]
				if (tex) then
					return tex
				end
			end
		end
	end
end

ChatFrame.SetFontObject = ChatFrame1.SetFontObject
ChatFrame.UpdateFont = function(self)
	--fontHeight will be 0 if it's still at the default (14)
	local _, fontHeight = FCF_GetChatWindowInfo(self:GetID())
	if (fontHeight == 0) then
		fontHeight = 14
	end

	ChatFrame.SetFontObject(self, GetFont(fontHeight, true, "Chat"))

	self:SetShadowColor(0,0,0,.5)
	self:SetShadowColor(0,0,0,.75)
	self:SetShadowOffset(-.75, -.75)
end

ChatFrames.StyleChat = function(self, frame)
	local name = frame:GetName()
	local id = frame:GetID()

	frame.ignoreFramePositionManager = true
	SetObjectScale(frame)
	frame:SetClampRectInsets(-54, -54, -54, -310)
	frame:SetClampedToScreen(false)
	frame:SetFading(5)
	frame:SetTimeVisible(25)
	frame:SetIndentedWordWrap(false)

	FCF_SetWindowColor(frame, 0, 0, 0, 0)
	FCF_SetWindowAlpha(frame, 0, 1)
	FCFTab_UpdateAlpha(frame)

	if (Elements[frame].styled) then
		return
	end

	local editBox = ChatFrame.GetEditBox(frame)
	local buttonFrame = ChatFrame.GetButtonFrame(frame)
	local minimizeButton = ChatFrame.GetMinimizeButton(frame)
	local bottomButton = ChatFrame.GetToBottomButton(frame)
	local scrollBar = ChatFrame.GetScrollBar(frame)
	local scrollTexture = ChatFrame.GetScrollBarThumbTexture(frame)
	local tab = ChatFrame.GetTab(frame)

	if (buttonFrame) then
		buttonFrame:SetParent(UIHider)
	end

	if (tab) then
		-- Take control of the tab's alpha changes
		-- and disable blizzard's own fading.
		tab:SetAlpha(1)
		tab.SetAlpha = UIFrameFadeRemoveFrame

		-- kill the tab textures
		for tex in ChatFrame.GetTabTextures(frame) do
			tex:SetTexture(nil)
			tex:SetAlpha(0)
		end

		local tabText = ChatFrame.GetTabText(frame)
		if (tabText) then
			tabText:Hide()
		end

		local tabIcon = ChatFrame.GetTabIcon(frame)
		if (tabIcon) then
			tabIcon:Hide()
		end
	end

	if (editBox) then
		for tex in ChatFrame.GetEditBoxTextures(frame) do
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
	end

	ChatFrame.UpdateFont(frame)

	hooksecurefunc(frame, "SetFont", ChatFrame.UpdateFont) -- blizzard use this
	hooksecurefunc(frame, "SetFontObject", ChatFrame.UpdateFont) -- not blizzard

	Elements[frame].styled = true
end

ChatFrames.SetupChatFrames = function(self)
	for _,frameName in ipairs(_G.CHAT_FRAMES) do
		local frame = _G[frameName]
		if (frame) then
			self:StyleChat(frame)
		end
	end

	if (not self.hasFrameLocks) then
		FCF_SetLocked(ChatFrame1, true)
		hooksecurefunc("FCF_ToggleLockOnDockedFrame", function()
			for _, frame in pairs(FCFDock_GetChatFrames(_G.GENERAL_CHAT_DOCK)) do
				FCF_SetLocked(frame, true)
			end
		end)
		self.hasFrameLocks = true
	end

	self:UpdateChatPositions()
end

ChatFrames.UpdateChatPositions = function(self)
	local chatFrame = _G.ChatFrame1
	chatFrame:ClearAllPoints()
	chatFrame:SetAllPoints(self.frame)
end

ChatFrames.OnInitialize = function(self)

	-- Need to set this to avoid frame popping back up
	CHAT_FRAME_BUTTON_FRAME_MIN_ALPHA = 0

	local scaffold = SetObjectScale(CreateFrame("Frame", nil, UIParent))
	scaffold:SetSize(475,228)
	scaffold:SetPoint("BOTTOMLEFT", 54, 310)
	self.frame = scaffold

	-- Just while developing.
	for i,element in ipairs({
		_G.ChatFrameMenuButton,
		_G.ChatFrameChannelButton,
		_G.ChatFrameToggleVoiceDeafenButton,
		_G.ChatFrameToggleVoiceMuteButton
	}) do
		if (element) then
			element:SetParent(UIHider)
		end
	end

	self:RegisterEvent("PLAYER_ENTERING_WORLD", function()
		-- This pops back up on zoning sometimes, so keep removing it
		-- This was called FriendsMicroButton pre-Legion #uselesstrivia
		if (_G.QuickJoinToastButton) then
			QuickJoinToastButton:UnregisterAllEvents()
			QuickJoinToastButton:Hide()
			QuickJoinToastButton:SetAlpha(0)
			QuickJoinToastButton:EnableMouse(false)
			QuickJoinToastButton:SetParent(UIHider)
		end
	end)
end

ChatFrames.OnEnable = function(self)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "SetupChatFrames")
	self:RegisterEvent("UPDATE_CHAT_WINDOWS", "SetupChatFrames")
	self:RegisterEvent("UPDATE_FLOATING_CHAT_WINDOWS", "SetupChatFrames")
	self:SecureHook("FCF_OpenTemporaryWindow", "SetupChatFrames")
end
