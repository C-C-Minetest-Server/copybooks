copybooks = {}
local MN = minetest.get_current_modname()
local MP = minetest.get_modpath(MN)
local function require(name)
	dofile(MP .. "/src/" .. name .. ".lua")
end

require("copybooks")
require("digiline_writers")
require("crafting")
