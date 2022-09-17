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
if (not ns.IsWrath) or (not MultiCastActionBarFrame) or (ns.PlayerClass ~= "SHAMAN") then
	return
end

local ActionBars = ns:GetModule("ActionBars")
local MultiCast = ActionBars:NewModule("MultiCast", "LibMoreEvents-1.0", "AceHook-3.0")

-- WoW API
local CreateFrame = CreateFrame

-- Addon API
local SetObjectScale = ns.API.SetObjectScale

MultiCast.UpdateMultiCastBar = function(self)
	local multicast = MultiCastActionBarFrame
	if (not multicast) then
		return
	end

	if (not self.Bar) then
		local bar = SetObjectScale(CreateFrame("Frame", ns.Prefix.."MultiCastFrame", UIParent), 1.25)
		bar.content = multicast
		bar:SetSize(230,38)
		bar:SetPoint("CENTER", 0, -200)
		self.Bar = bar
	end

	multicast.ignoreFramePositionManager = true
	multicast:SetScript("OnShow", nil)
	multicast:SetScript("OnHide", nil)
	multicast:SetScript("OnUpdate", nil)
	multicast:SetParent(self.Bar)
	multicast:SetFrameLevel(self.Bar:GetFrameLevel() + 1)
	multicast:ClearAllPoints()
	multicast:SetPoint("CENTER", 0, 0)

end

MultiCast.OnInitialize = function(self)
	self:SecureHook("ShowMultiCastActionBar", "UpdateMultiCastBar")
end
