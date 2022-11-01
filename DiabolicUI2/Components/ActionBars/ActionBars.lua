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
local ActionBars = ns:NewModule("ActionBars", "LibMoreEvents-1.0")

---------------------------------------------
-- Proxy Calls
---------------------------------------------
-- Returns 'true' if the secondary bar is currently visible.
ActionBars.HasSecondaryBar = function(self)
	local Bars = self:GetModule("Bars", true)
	return Bars and Bars:HasSecondaryBar()
end

-- Returns the secondary action bar.
ActionBars.GetSecondaryBar = function(self)
	local Bars = self:GetModule("Bars", true)
	return Bars and Bars:GetSecondaryBar()
end

-- Returns the currently valid vertical offset
-- for items positioned above the action bars.
ActionBars.GetBarOffset = function(self)
	local Bars = self:GetModule("Bars", true)
	return Bars and Bars:GetBarOffset()
end

-- Returns the value used in the GetBarOffset
-- when the secondary bar is visible.
ActionBars.GetSecondaryBarOffset = function(self)
	local Bars = self:GetModule("Bars", true)
	return Bars and Bars:GetSecondaryBarOffset()
end
