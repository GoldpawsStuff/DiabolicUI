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

-- Addon API
local GetFont = ns.API.GetFont
local GetMedia = ns.API.GetMedia
local RegisterCooldown = ns.Widgets.RegisterCooldown

local noop = ns.Noop

ActionBars:RegisterStyle("StanceButton", function(button)

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
end)
