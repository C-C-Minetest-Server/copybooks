local mfu_item_a = "default:meselamp"
if minetest.get_modpath("technic") and technic.mod == "linuxforks" then
	mfu_item_a = "technic:lv_led"
end

local mfu_item_b = "default:book"
if minetest.get_modpath("digilines") then
	mfu_item_b = "digilines:wire_std_00000000"
end

local mfu_item_c = "default:diamond"
if minetest.get_modpath("pipeworks") then
	mfu_item_c = "pipeworks:tube_1"
end


if minetest.get_modpath("technic") then
	minetest.register_craft({
		output = "copybooks:copybooks",
		recipe = {
				{"homedecor:plastic_sheeting", "default:obsidian_glass", "homedecor:plastic_sheeting"},
				{mfu_item_c, mfu_item_a, mfu_item_c},
				{"technic:stainless_steel_ingot", mfu_item_b, "technic:stainless_steel_ingot"},
			}
		})
else
	minetest.register_craft({
		output = "copybooks:copybooks",
		recipe = {
				{"default:copper_ingot", "default:obsidian_glass", "default:copper_ingot"},
				{mfu_item_c, mfu_item_a, mfu_item_c},
				{"default:steel_ingot", mfu_item_b, "default:steel_ingot"},
			}
		})
end

if copybooks.digiline_writer then
	minetest.register_craft({
		output = "copybooks:copybooks",
		recipe = {{"copybooks:digiline_writer"}}
	})
	minetest.register_craft({
		output = "copybooks:digiline_writer",
		recipe = {{"copybooks:copybooks"}}
	})
end
