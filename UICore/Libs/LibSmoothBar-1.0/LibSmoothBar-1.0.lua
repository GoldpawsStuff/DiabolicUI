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
local MAJOR_VERSION = "LibSmoothBar-1.0"
local MINOR_VERSION = 3

if (not LibStub) then
	error(MAJOR_VERSION .. " requires LibStub.")
end

local lib, oldversion = LibStub:NewLibrary(MAJOR_VERSION, MINOR_VERSION)
if (not lib) then
	return
end

-- Lua API
local getmetatable = getmetatable
local math_abs = math.abs
local math_floor = math.floor
local pairs = pairs
local setmetatable = setmetatable
local tonumber = tonumber
local type = type

-- WoW API
local CreateFrame = CreateFrame
local GetTime = GetTime

-- Library registries
lib.bars = lib.bars or {}
lib.textures = lib.textures or {}
lib.embeds = lib.embeds or {}

----------------------------------------------------------------
-- BarTexture template
----------------------------------------------------------------
-- Need to borrow some methods here
local Texture = CreateFrame("StatusBar"):CreateTexture()
local Texture_MT = { __index = Texture }

-- Grab some of the original methods before we change them
Texture.RawGetTexCoord = getmetatable(Texture).__index.GetTexCoord
Texture.RawSetTexCoord = getmetatable(Texture).__index.SetTexCoord

-- Mad scientist stuff.
-- What we basically do is to apply texcoords to texcoords,
-- to get an inner fraction of the already cropped texture. Awesome! :)
Texture.SetRelativeTexCoord = function(self, ...)

	-- The displayed fraction of the full texture
	local fractionLeft, fractionRight, fractionTop, fractionBottom = ...

	local fullCoords = self._tex -- "full" / original texcoords
	local fullWidth = fullCoords[2] - fullCoords[1] -- full width of the original texcoord area
	local fullHeight = fullCoords[4] - fullCoords[3] -- full height of the original texcoord area

	local displayedLeft = fullCoords[1] + fractionLeft*fullWidth
	local displayedRight = fullCoords[2] - (1-fractionRight)*fullWidth
	local displayedTop = fullCoords[3] + fractionTop*fullHeight
	local displayedBottom = fullCoords[4] - (1-fractionBottom)*fullHeight

	-- Store the real coords (re-use old table, as this is called very often)
	local texCoords = self._data.texCoords
	texCoords[1] = displayedLeft
	texCoords[2] = displayedRight
	texCoords[3] = displayedTop
	texCoords[4] = displayedBottom

	-- Calculate the new area and apply it with the real blizzard method
	self:RawSetTexCoord(displayedLeft, displayedRight, displayedTop, displayedBottom)

	-- Allow modules to hook into this
	local onTexCoordChanged = self._data.scripts.OnTexCoordChanged
	if (onTexCoordChanged) then
		onTexCoordChanged(self, displayedLeft, displayedRight, displayedTop, displayedBottom)
	end
end

Texture.SetTexCoord = function(self, ...)
	local tex = self._tex
	tex[1], tex[2], tex[3], tex[4] = ...
	tex._update(tex._owner)
end

Texture.GetTexCoord = function(self)
	local tex = self._tex
	return tex[1], tex[2], tex[3], tex[4]
end

----------------------------------------------------------------
-- StatusBar template
----------------------------------------------------------------
local StatusBar = CreateFrame("StatusBar")
local StatusBar_MT = { __index = StatusBar }

-- We can not allow the statusbar to get its scripts overwritten
local protectedScripts = {
	["OnUpdate"] = true,
	["OnTexCoordChanged"] = true,
	["OnDisplayValueChanged"] = true
}

-- Noop out the old blizzard methods.
local noop = function() end
StatusBar.GetFillStyle = noop
StatusBar.GetMinMaxValues = noop
StatusBar.GetOrientation = noop
StatusBar.GetReverseFill = noop
StatusBar.GetRotatesTexture = noop
StatusBar.GetStatusBarAtlas = noop
StatusBar.GetStatusBarColor = noop
StatusBar.GetStatusBarTexture = noop
StatusBar.GetValue = noop
StatusBar.SetFillStyle = noop
StatusBar.SetMinMaxValues = noop
StatusBar.SetOrientation = noop
StatusBar.SetReverseFill = noop
StatusBar.SetValue = noop
StatusBar.SetRotatesTexture = noop
StatusBar.SetStatusBarAtlas = noop
StatusBar.SetStatusBarColor = noop
StatusBar.SetStatusBarTexture = noop

-- Grab some of the original methods before we change them
StatusBar.RawGetScript = getmetatable(StatusBar).__index.GetScript
StatusBar.RawSetScript = getmetatable(StatusBar).__index.SetScript

StatusBar.SetTexCoord = function(self, ...)
	local tex = self._tex
	tex[1], tex[2], tex[3], tex[4] = ...
	tex._update(self, true)
end

StatusBar.GetTexCoord = function(self)
	local tex = self._tex
	return tex[1], tex[2], tex[3], tex[4]
end

StatusBar.GetRealTexCoord = function(self)
	local texCoords = self._data.texCoords
	return texCoords[1], texCoords[2], texCoords[3], texCoords[4]
end

StatusBar.GetSparkTexture = function(self)
	return self._data.spark:GetTexture()
end

StatusBar.DisableSmoothing = function(self, disableSmoothing)
	self._data.disableSmoothing = disableSmoothing
end

StatusBar.SetValue = function(self, value, overrideSmoothing)
	local data = self._data
	local min, max = data.barMin, data.barMax
	if (value > max) then
		value = max
	elseif (value < min) then
		value = min
	end
	data.barValue = value
	if overrideSmoothing then
		data.barDisplayValue = value
	end
	if (not data.disableSmoothing) then
		if (data.barDisplayValue > max) then
			data.barDisplayValue = max
		elseif (data.barDisplayValue < min) then
			data.barDisplayValue = min
		end
		data.smoothingInitialValue = data.barDisplayValue
		data.smoothingStart = GetTime()
	end
	if (value ~= data.barDisplayValue) then
		data.smoothing = true
	end
	if (data.smoothing or (data.barDisplayValue > min) or (data.barDisplayValue < max)) then
		data.updatesRunning = true
		return
	end
	data._update(self)
end

StatusBar.Clear = function(self)
	local data = self._data
	data.barValue = data.barMin
	data.barDisplayValue = data.barMin
	data._update(self)
end

StatusBar.SetMinMaxValues = function(self, min, max, overrideSmoothing)
	local data = self._data
	if (data.barMin == min) and (data.barMax == max) then
		return
	end
	if (data.barValue > max) then
		data.barValue = max
	elseif (data.barValue < min) then
		data.barValue = min
	end
	if (overrideSmoothing) then
		data.barDisplayValue = data.barValue
	else
		if (data.barDisplayValue > max) then
			data.barDisplayValue = max
		elseif (data.barDisplayValue < min) then
			data.barDisplayValue = min
		end
	end
	data.barMin = min
	data.barMax = max
	data.update(self)
end

StatusBar.SetStatusBarColor = function(self, ...)
	self._data.bar:SetVertexColor(...)
	self._data.spark:SetVertexColor(...)
end

StatusBar.SetStatusBarTexture = function(self, ...)
	local arg = ...
	if (type(arg) == "number") then
		self._data.bar:SetColorTexture(...)
	else
		self._data.bar:SetTexture(...)
	end
	self._data.update(self, true)
end

StatusBar.SetFlippedHorizontally = function(self, reversed)
	self._data.reversedH = reversed
end

StatusBar.SetFlippedVertically = function(self, reversed)
	self._data.reversedV = reversed
end

StatusBar.IsFlippedHorizontally = function(self)
	return self._data.reversedH
end

StatusBar.IsFlippedVertically = function(self)
	return self._data.reversedV
end

StatusBar.SetSparkMap = function(self, sparkMap)
	self._data.sparkMap = sparkMap
end

StatusBar.SetSparkTexture = function(self, ...)
	local arg = ...
	if (type(arg) == "number") then
		self._data.spark:SetColorTexture(...)
	else
		self._data.spark:SetTexture(...)
	end
end

StatusBar.SetSparkColor = function(self, ...)
	self._data.spark:SetVertexColor(...)
end

StatusBar.SetSparkMinMaxPercent = function(self, min, max)
	local data = self._data
	data.sparkMinPercent = min
	data.sparkMinPercent = max
end

StatusBar.SetSparkBlendMode = function(self, blendMode)
	self._data.spark:SetBlendMode(blendMode)
end

StatusBar.SetSparkFlash = function(self, durationIn, durationOut, minAlpha, maxAlpha)
	local data = self._data
	data.sparkDurationIn = durationIn
	data.sparkDurationOut = durationOut
	data.sparkMinAlpha = minAlpha
	data.sparkMaxAlpha = maxAlpha
	data.sparkDirection = "IN"
	data.spark:SetAlpha(minAlpha)
end

StatusBar.SetOrientation = function(self, orientation)
	local data = self._data
	if (orientation == "HORIZONTAL") then
		if (data.barBlizzardReverseFill) then
			return self:SetGrowth("LEFT")
		else
			return self:SetGrowth("RIGHT")
		end

	elseif (orientation == "VERTICAL") then
		if (data.barBlizzardReverseFill) then
			return self:SetGrowth("DOWN")
		else
			return self:SetGrowth("UP")
		end

	elseif (orientation == "LEFT") or (orientation == "RIGHT") or (orientation == "UP") or (orientation == "DOWN") then
		return self:SetGrowth(orientation)
	end
end

StatusBar.SetGrowth = function(self, orientation)
	local data = self._data
	if (orientation == "LEFT") then
		data.spark:SetTexCoord(0, 1, 3/32, 28/32)
		data.barOrientation = "LEFT"
		data.barBlizzardOrientation = "HORIZONTAL"
		data.barBlizzardReverseFill = true

	elseif (orientation == "RIGHT") then
		data.spark:SetTexCoord(0, 1, 3/32, 28/32)
		data.barOrientation = "RIGHT"
		data.barBlizzardOrientation = "HORIZONTAL"
		data.barBlizzardReverseFill = false

	elseif (orientation == "UP") then
		data.spark:SetTexCoord(1,11/32,0,11/32,1,19/32,0,19/32)
		data.barOrientation = "UP"
		data.barBlizzardOrientation = "VERTICAL"
		data.barBlizzardReverseFill = false

	elseif (orientation == "DOWN") then
		data.spark:SetTexCoord(1,11/32,0,11/32,1,19/32,0,19/32)
		data.barOrientation = "DOWN"
		data.barBlizzardOrientation = "VERTICAL"
		data.barBlizzardReverseFill = true
	end
end

StatusBar.GetGrowth = function(self, direction)
	return self._data.barOrientation
end

StatusBar.GetOrientation = function(self)
	return self._data.barBlizzardOrientation
end

StatusBar.SetReverseFill = function(self, state)
	local data = self._data
	data.barBlizzardReverseFill = state and true or false
end

StatusBar.GetReverseFill = function(self, state)
	return self._data.barBlizzardReverseFill
end

StatusBar.SetScript = function(self, ...)
	local scriptHandler, func = ...
	if (protectedScripts[scriptHandler]) then
		self._data.scripts[scriptHandler] = func
	else
		self:RawSetScript(scriptHandler,func)
	end
end

StatusBar.GetScript = function(self, ...)
	local scriptHandler = ...
	if (protectedScripts[scriptHandler]) then
		return self._data.scripts[scriptHandler]
	else
		return self:RawGetScript(scriptHandler)
	end
end

StatusBar.GetValue = function(self)
	return self._data.barValue
end

StatusBar.GetDisplayValue = function(self)
	return self._data.barDisplayValue
end

StatusBar.GetMinMaxValues = function(self)
	return self._data.barMin, self._data.barMax
end

StatusBar.GetStatusBarColor = function(self)
	return self._data.bar:GetVertexColor()
end

StatusBar.GetStatusBarTexture = function(self)
	return self._data.bar
end

StatusBar.GetAnchor = function(self) return self._data.bar end
StatusBar.GetObjectType = function(self) return "StatusBar" end
StatusBar.IsObjectType = function(self, type) return type == "SmartBar" or type == "StatusBar" or type == "Frame" end
StatusBar.IsForbidden = function(self) return true end

-- The actual statusbar graphical update function
local Update = function(self, elapsed)
	local data = self._data

	local value = data.disableSmoothing and data.barValue or data.barDisplayValue
	local min, max = data.barMin, data.barMax
	local width, height = data.statusbar:GetSize()
	local orientation = data.barOrientation
	local bar = data.bar
	local spark = data.spark

	if (value > max) then
		value = max
	elseif (value < min) then
		value = min
	end

	if (value == min) or (max == min) then
		bar:Hide()
	else

		-- Ok, here's the problem:
		-- Textures sizes can't be displayed accurately as fractions of a pixel.
		-- This causes the bar to "wobbble" when attempting to size it
		-- according to its much more accurate tex coords.
		-- Only solid workaround is to keep the textures at integer values,
		-- And fake the movement by moving the blurry spark at subpixels instead.
		local displaySize, mult
		if (value > min) then
			mult = (value-min)/(max-min)
			local fullSize = (orientation == "RIGHT" or orientation == "LEFT") and width or height
			displaySize = math_floor(mult * fullSize)
			if (displaySize < .01) then
				displaySize = .01
			end
			mult = displaySize/fullSize
		else
			mult = .01
			displaySize = .01
		end

		-- if there's a sparkmap, let's apply it!
		local sparkBefore, sparkAfter = 0,0
		local sparkMap = data.sparkMap
		if sparkMap then
			local sparkPercentage = mult
			if data.reversedH and ((orientation == "LEFT") or (orientation == "RIGHT")) then
				sparkPercentage = 1 - mult
			end
			if data.reversedV and ((orientation == "UP") or (orientation == "DOWN")) then
				sparkPercentage = 1 - mult
			end
			if (sparkMap.top and sparkMap.bottom) then

				-- Iterate through the map to figure out what points we are between
				-- *There's gotta be a more elegant way to do this...
				local topBefore, topAfter = 1, #sparkMap.top
				local bottomBefore, bottomAfter = 1, #sparkMap.bottom

				-- Iterate backwards to find the first top point before our current bar value
				for i = topAfter,topBefore,-1 do
					if sparkMap.top[i].keyPercent > sparkPercentage then
						topAfter = i
					end
					if sparkMap.top[i].keyPercent < sparkPercentage then
						topBefore = i
						break
					end
				end
				-- Iterate backwards to find the first bottom point before our current bar value
				for i = bottomAfter,bottomBefore,-1 do
					if sparkMap.bottom[i].keyPercent > sparkPercentage then
						bottomAfter = i
					end
					if sparkMap.bottom[i].keyPercent < sparkPercentage then
						bottomBefore = i
						break
					end
				end

				-- figure out the offset at our current position
				-- between our upper and lover points
				local belowPercentTop = sparkMap.top[topBefore].keyPercent
				local abovePercentTop = sparkMap.top[topAfter].keyPercent

				local belowPercentBottom = sparkMap.bottom[bottomBefore].keyPercent
				local abovePercentBottom = sparkMap.bottom[bottomAfter].keyPercent

				local currentPercentTop = (sparkPercentage - belowPercentTop)/(abovePercentTop-belowPercentTop)
				local currentPercentBottom = (sparkPercentage - belowPercentBottom)/(abovePercentBottom-belowPercentBottom)

				-- difference between the points
				local diffTop = sparkMap.top[topAfter].offset - sparkMap.top[topBefore].offset
				local diffBottom = sparkMap.bottom[bottomAfter].offset - sparkMap.bottom[bottomBefore].offset

				sparkBefore = (sparkMap.top[topBefore].offset + diffTop*currentPercentTop) --* height
				sparkAfter = (sparkMap.bottom[bottomBefore].offset + diffBottom*currentPercentBottom) --* height
			else
				-- iterate through the map to figure out what points we are between
				-- gotta be a more elegant way to do this
				local below, above = 1,#sparkMap
				for i = above,below,-1 do
					if sparkMap[i].keyPercent > sparkPercentage then
						above = i
					end
					if sparkMap[i].keyPercent < sparkPercentage then
						below = i
						break
					end
				end

				-- figure out the offset at our current position
				-- between our upper and lover points
				local belowPercent = sparkMap[below].keyPercent
				local abovePercent = sparkMap[above].keyPercent
				local currentPercent = (sparkPercentage - belowPercent)/(abovePercent-belowPercent)

				-- difference between the points
				local diffTop = sparkMap[above].topOffset - sparkMap[below].topOffset
				local diffBottom = sparkMap[above].bottomOffset - sparkMap[below].bottomOffset

				sparkBefore = (sparkMap[below].topOffset + diffTop*currentPercent) --* height
				sparkAfter = (sparkMap[below].bottomOffset + diffBottom*currentPercent) --* height
			end
		end

		if (orientation == "RIGHT") then
			if data.reversedH then
				-- bar grows from the left to right
				-- and the bar is also flipped horizontally
				-- (e.g. target absorbbar)
				bar:SetRelativeTexCoord(1, 1-mult, 0, 1)
			else
				-- bar grows from the left to right
				-- (e.g. player healthbar)
				bar:SetRelativeTexCoord(0, mult, 0, 1)
			end

			bar:ClearAllPoints()
			bar:SetPoint("TOP")
			bar:SetPoint("BOTTOM")
			bar:SetPoint("LEFT")
			bar:SetSize(displaySize, height)

			spark:ClearAllPoints()
			spark:SetPoint("TOP", bar, "TOPRIGHT", 0, sparkBefore*height)
			spark:SetPoint("BOTTOM", bar, "BOTTOMRIGHT", 0, -sparkAfter*height)
			spark:SetSize(data.sparkThickness, height - (sparkBefore + sparkAfter)*height)

		elseif (orientation == "LEFT") then
			if data.reversedH then
				-- bar grows from the right to left
				-- and the bar is also flipped horizontally
				-- (e.g. target healthbar)
				bar:SetRelativeTexCoord(mult, 0, 0, 1)
			else
				-- bar grows from the right to left
				-- (e.g. player absorbbar)
				bar:SetRelativeTexCoord(1-mult, 1, 0, 1)
			end

			bar:ClearAllPoints()
			bar:SetPoint("TOP")
			bar:SetPoint("BOTTOM")
			bar:SetPoint("RIGHT")
			bar:SetSize(displaySize, height)

			spark:ClearAllPoints()
			spark:SetPoint("TOP", bar, "TOPLEFT", 0, sparkBefore*height)
			spark:SetPoint("BOTTOM", bar, "BOTTOMLEFT", 0, -sparkAfter*height)
			spark:SetSize(data.sparkThickness, height - (sparkBefore + sparkAfter)*height)

		elseif (orientation == "UP") then
			if data.reversed then
				bar:SetRelativeTexCoord(1, 0, 1-mult, 1)
				sparkBefore, sparkAfter = sparkAfter, sparkBefore
			else
				bar:SetRelativeTexCoord(0, 1, 1-mult, 1)
			end

			bar:ClearAllPoints()
			bar:SetPoint("LEFT")
			bar:SetPoint("RIGHT")
			bar:SetPoint("BOTTOM")
			bar:SetSize(width, displaySize)

			spark:ClearAllPoints()
			spark:SetPoint("LEFT", bar, "TOPLEFT", -sparkBefore*width, 0)
			spark:SetPoint("RIGHT", bar, "TOPRIGHT", sparkAfter*width, 0)
			spark:SetSize(width - (sparkBefore + sparkAfter)*width, data.sparkThickness)

		elseif (orientation == "DOWN") then
			if data.reversed then
				bar:SetRelativeTexCoord(1, 0, 0, mult)
				sparkBefore, sparkAfter = sparkAfter, sparkBefore
			else
				bar:SetRelativeTexCoord(0, 1, 0, mult)
			end

			bar:ClearAllPoints()
			bar:SetPoint("LEFT")
			bar:SetPoint("RIGHT")
			bar:SetPoint("TOP")
			bar:SetSize(width, displaySize)

			spark:ClearAllPoints()
			spark:SetPoint("LEFT", bar, "BOTTOMLEFT", -sparkBefore*width, 0)
			spark:SetPoint("RIGHT", bar, "BOTTOMRIGHT", sparkAfter*width, 0)
			spark:SetSize(width - (sparkBefore + sparkAfter*width), data.sparkThickness)
		end
		if (not bar:IsShown()) then
			bar:Show()
		end
		if (data.scripts.OnDisplayValueChanged) then
			data.scripts.OnDisplayValueChanged(self, value)
		end
	end

	-- Spark alpha animation
	if ((value == max) or (value == min) or (value/max >= data.sparkMaxPercent) or (value/max <= data.sparkMinPercent)) then
		if spark:IsShown() then
			spark:Hide()
			spark:SetAlpha(data.sparkMinAlpha)
			data.sparkDirection = "IN"
		end
	else
		if (elapsed and tonumber(elapsed)) then
			local currentAlpha = spark:GetAlpha()
			local targetAlpha = data.sparkDirection == "IN" and data.sparkMaxAlpha or data.sparkMinAlpha
			local range = data.sparkMaxAlpha - data.sparkMinAlpha
			local alphaChange = elapsed/(data.sparkDirection == "IN" and data.sparkDurationIn or data.sparkDurationOut) * range
			if data.sparkDirection == "IN" then
				if currentAlpha + alphaChange < targetAlpha then
					currentAlpha = currentAlpha + alphaChange
				else
					currentAlpha = targetAlpha
					data.sparkDirection = "OUT"
				end
			elseif data.sparkDirection == "OUT" then
				if currentAlpha + alphaChange > targetAlpha then
					currentAlpha = currentAlpha - alphaChange
				else
					currentAlpha = targetAlpha
					data.sparkDirection = "IN"
				end
			end
			spark:SetAlpha(currentAlpha)
		end
		if (not spark:IsShown()) then
			spark:Show()
		end
	end
end

-- Bar smoothing settings
local smoothingMinValue = .3 -- if a value is lower than this, we won't smoothe
local smoothingFrequency = .5 -- default duration of smooth transitions
local smartSmoothingDownFrequency = .15 -- duration of smooth reductions in smart mode
local smartSmoothingUpFrequency = .75 -- duration of smooth increases in smart mode
local smoothingLimit = 1/120 -- max updates per second

-- The running updater for the visible bar
-- *calculates values and calls the actual update function.
-- *user registered OnUpdate handlers are called after the above.
local OnUpdate = function(self, elapsed)
	local data = self._data
	data.elapsed = (data.elapsed or 0) + elapsed
	if (data.elapsed < smoothingLimit) then
		return
	end

	if (data.updatesRunning) then
		if (data.disableSmoothing) then
			if (data.barValue <= data.barMin) or (data.barValue >= data.barMax) then
				data.updatesRunning = nil
			end
		elseif (data.smoothing) then
			if (math_abs(data.barDisplayValue - data.barValue) < smoothingMinValue) then
				data.barDisplayValue = data.barValue
				data.smoothing = nil
			else
				-- The fraction of the total bar this total animation should cover
				local animsize = (data.barValue - data.smoothingInitialValue)/(data.barMax - data.barMin)

				local smoothSpeed
				if data.barValue > data.barDisplayValue then
					smoothSpeed = smartSmoothingUpFrequency
				elseif data.barValue < data.barDisplayValue then
					smoothSpeed = smartSmoothingDownFrequency
				else
					smoothSpeed = data.smoothingFrequency or smoothingFrequency
				end

				-- Points per second on average for the whole bar
				local pps = (data.barMax - data.barMin)/smoothSpeed

				-- Position in time relative to the length of the animation, scaled from 0 to 1
				local position = (GetTime() - data.smoothingStart)/smoothSpeed
				if (position < 1) then
					-- The change needed when using average speed
					local average = pps * animsize * data.elapsed -- can and should be negative

					-- Tha change relative to point in time and distance passed
					local change = 2*(3 * ( 1 - position )^2 * position) * average*2 --  y = 3 * (1 − t)^2 * t  -- quad bezier fast ascend + slow descend

					-- If there's room for a change in the intended direction, apply it, otherwise finish the animation
					if ( (data.barValue > data.barDisplayValue) and (data.barValue > data.barDisplayValue + change) )
					or ( (data.barValue < data.barDisplayValue) and (data.barValue < data.barDisplayValue + change) ) then
						data.barDisplayValue = data.barDisplayValue + change
					else
						data.barDisplayValue = data.barValue
						data.smoothing = nil
					end
				else
					data.barDisplayValue = data.barValue
					data.smoothing = nil
				end
			end
		else
			if (data.barDisplayValue <= data.barMin) or (data.barDisplayValue >= data.barMax) or (not data.smoothing) then
				data.updatesRunning = nil
			end
		end

		-- Call the actual graphical updates
		data._update(self, data.elapsed)
	end

	-- call module OnUpdate handler
	if (data.scripts.OnUpdate) then
		data.scripts.OnUpdate(data.statusbar, data.elapsed)
	end

	-- only reset this at the very end, as calculations above need it
	data.elapsed = 0
end

lib.CreateSmoothBar = function(self, name, parent, template)

	-- The virtual bar returned to the user
	local statusbar = setmetatable(CreateFrame("Frame", name, parent, template), StatusBar_MT)
	statusbar:SetSize(1,1)

	-- The statusbar's texture object
	local bar = setmetatable(statusbar:CreateTexture(), Texture_MT)
	bar:SetDrawLayer("BORDER", 0)
	bar:SetPoint("TOP")
	bar:SetPoint("BOTTOM")
	bar:SetPoint("LEFT")
	bar:SetWidth(statusbar:GetWidth())

	-- Rare gem of a texture, works nicely on bars smaller than 256px in effective width
	bar:SetTexture([[Interface\FontStyles\FontStyleMetal]])

	-- The spark texture
	local spark = statusbar:CreateTexture()
	spark:SetDrawLayer("BORDER", 1)
	spark:SetPoint("CENTER", bar, "RIGHT", 0, 0)
	spark:SetSize(1,1)
	spark:SetAlpha(.6)
	spark:SetBlendMode("ADD")
	spark:SetTexture([[Interface\CastingBar\UI-CastingBar-Spark]]) -- 32x32, centered vertical spark being 32x9px, from 0,11px to 32,19px
	spark:SetTexCoord(0, 1, 25/80, 55/80)

	-- Can we somehow drop this?
	local data = {}
	data.bar = bar
	data.spark = spark
	data.statusbar = statusbar

	-- Bar settings
	data.barMin = 0 -- min value
	data.barMax = 1 -- max value
	data.barValue = 0 -- real value
	data.barDisplayValue = 0 -- displayed value while smoothing
	data.barOrientation = "RIGHT" -- direction the bar is growing in

	-- Spark settings
	data.sparkThickness = 8
	data.sparkOffset = 1/32
	data.sparkDirection = "IN"
	data.sparkDurationIn = .75
	data.sparkDurationOut = .55
	data.sparkMinAlpha = .25
	data.sparkMaxAlpha = .95
	data.sparkMinPercent = 1/100
	data.sparkMaxPercent = 99/100

	-- Blizz API compatibility
	data.barBlizzardOrientation = "HORIZONTAL"
	data.barBlizzardReverseFill = false

	-- The real texcoords of the bar texture
	data.texCoords = { 0, 1, 0, 1 }

	-- Virtual texcoord handling
	local tex = { 0, 1, 0, 1 }
	tex._owner = statusbar

	bar._data = data
	bar._tex = tex
	bar._update = Update

	statusbar._data = data
	statusbar._tex = tex
	statusbar._update = Update

	lib.bars[bar] = data
	lib.bars[statusbar] = data
	lib.textures[bar] = tex
	lib.textures[statusbar] = tex

	-- Run an initial update
	data._update(statusbar)

	-- Apply our custom OnUpdate handler.
	-- This needs to be running at all times.
	statusbar:RawSetScript("OnUpdate", OnUpdate)

	return statusbar
end

local mixins = {
	CreateSmoothBar = true
}

lib.Embed = function(self, target)
	for method in pairs(mixins) do
		target[method] = self[method]
	end
	self.embeds[target] = true
	return target
end

-- Upgrade old embeds
for target in pairs(lib.embeds) do
	lib:Embed(target)
end

-- Upgrade old bars
if (oldversion == 1) then
	for bar,data in pairs(lib.bars) do
		bar._data = data
		bar._update = Update
		if (bar == data.bar) then
			setmetatable(bar, Texture_MT)
		elseif (bar == data.statusbar) then
			setmetatable(bar, StatusBar_MT)
		end
	end
	for bar,tex in pairs(lib.textures) do
		bar._tex = tex
	end
end
