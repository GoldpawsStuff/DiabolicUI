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

-- Addon version
------------------------------------------------------
-- Keyword substitution requires the packager,
-- and does not affect direct GitHub repo pulls.
local version = "@project-version@"
if (version:find("project%-version")) then
	version = "Development"
end
ns.Private.Version = version
ns.Private.IsDevelopment = version == "Development"
ns.Private.IsAlpha = string.find(version, "%-Alpha$")
ns.Private.IsBeta = string.find(version, "%-Beta$")
ns.Private.IsRC = string.find(version, "%-RC$")
ns.Private.IsRelease = string.find(version, "%-Release$")

-- WoW client version
------------------------------------------------------
local patch, build = GetBuildInfo()
local major, minor = string.split(".", patch)

ns.Private.ClientPatch = patch
ns.Private.ClientMajor = tonumber(major)
ns.Private.ClientMinor = tonumber(minor)
ns.Private.ClientBuild = tonumber(build)

-- Simple flags for client version checks
ns.Private.IsClassic = ns.Private.ClientMajor == 1
ns.Private.IsTBC = ns.Private.ClientMajor == 2
ns.Private.IsWrath = ns.Private.ClientMajor == 3
ns.Private.IsRetail = ns.Private.ClientMajor >= 9
ns.Private.IsShadowlands = ns.Private.ClientMajor == 9
ns.Private.IsDragonflight = ns.Private.ClientMajor == 10

-- Prefix for frame names
------------------------------------------------------
ns.Private.Prefix = string.gsub(Addon, "UI(%d*)", "")

-- Scaling Constants
------------------------------------------------------
ns.UIScale = 768/1080
ns.Private.UIDefaultScale = 768/1080
