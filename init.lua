local S = minetest.get_translator("copybooks")
local F = minetest.formspec_escape

local status_idle = S("Book Copier Idle")
local status_active = S("Book Copier Active")
local status_full = S("Book Copier Full")
local status_nopaper = S("Book Copier No Paper")

local copybooks_formspec = function(status)
	return "" ..
		"size[8,9]"..

		"label[0,0;"..S("Inputs").."]"..
		"list[context;input;0,0.5;3,3;]" ..
		"listring[current_player;main]"..

		"label[2.9,0;"..S("Master").."]"..
		"list[context;master;3,0.5;1,1;]"..

		"label[0.25,4;" .. status .. "]" ..

		"button_exit[3,1.5;1,1;quit;" .. S("Quit") .. "]"..

		"label[6.7,0;"..S("Copies").."]"..
		"list[context;output;4,0.5;4,4;]"..

		"list[current_player;main;0,5;8,4;]" ..
		"listring[context;input]"
end

local on_construct = function( pos )
	local meta = minetest.get_meta(pos);
	local inv = meta:get_inventory()

	inv:set_size("input", 9)
	inv:set_size("output", 16)
	inv:set_size("master", 1)
	meta:set_string('formspec', copybooks_formspec(status_idle))
	meta:set_string('infotext', status_idle)
end

local mfu_allow_metadata_inventory_put = function(pos, listname, index, stack, player)
	local iname = stack:get_name()
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()

	if listname == "input" then
		if iname == "default:book" or iname == "default:paper" then
			return inv:room_for_item("input", stack) and stack:get_count() or 0
		else
			return 0
		end
	elseif listname == "output" then
		return 0
	elseif listname == "master" then
		if iname == "default:book_written" and inv:room_for_item("master", stack) then
			return 1
		else
			return 0
		end
	end
	return 0
end

local mfu_allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
	if to_list == "input" then
		return -1
	else
		return 0
	end
end

local mfu_can_dig = function(pos, player)
	local name = player:get_player_name()
	if minetest.is_protected(pos, name) then
		minetest.record_protection_violation(pos, name)
		return false
	end
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	return (inv:is_empty("input") and inv:is_empty("output") and inv:is_empty("master"))
end

local mfu_tube = minetest.get_modpath("pipeworks") and {
		-- using a different stack from defaut when inserting
		insert_object = function(pos, node, stack, direction)
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			return inv:add_item("input", stack)
		end,
		can_insert = function(pos, node, stack, direction)
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			if stack:get_name() == "default:paper" or stack:get_name() == "default:book" then
				return inv:room_for_item("input", stack)
			else
				return false
			end
		end,
		-- the default stack, from which objects will be taken
		input_inventory = "output",
		connect_sides = {left = 1, right = 1, back = 1, bottom = 1,}
	} or nil

minetest.register_node("copybooks:copybooks_active", {
	description = S("Book Copier"),
	tiles = {	{name="mfu_top_active.png",
				animation={type="vertical_frames",
				aspect_w=32,
				aspect_h=32,
				length=3}},
			"mfu_bottom.png",
                  "mfu_side.png",
                  "mfu_side.png",
			"mfu_back.png",
                  "mfu_front_active.png",
			},
	groups = {cracky = 1, not_in_creative_inventory = 1, tubedevice = 1, tubedevice_receiver = 1, copybooks = 1},
	light_source = 3,
	allow_metadata_inventory_put = mfu_allow_metadata_inventory_put,
	allow_metadata_inventory_move = mfu_allow_metadata_inventory_move,
	paramtype = "light",
	paramtype2 = "facedir",
	drop = "copybooks:copybooks",
	can_dig = mfu_can_dig,
	tube = mfu_tube,
})

minetest.register_node("copybooks:copybooks", {
	description = S("Book Copier"),
	tiles = {	"mfu_top.png",
			"mfu_bottom.png",
                  "mfu_side.png",
                  "mfu_side.png",
			"mfu_back.png",
                  "mfu_front.png",
			},
	groups = {cracky = 1, tubedevice = 1, tubedevice_receiver = 1, copybooks = 1},
	allow_metadata_inventory_put = mfu_allow_metadata_inventory_put,
	allow_metadata_inventory_move = mfu_allow_metadata_inventory_move,
	paramtype = "light",
	paramtype2 = "facedir",
	drop = "copybooks:copybooks",
	can_dig = mfu_can_dig,
	tube = mfu_tube,
	on_construct = on_construct,
})

local function inactive_state(pos,meta,state)
	minetest.swap_node(pos,{name="copybooks:copybooks"})
	meta:set_string("infotext",state or status_idle)
	meta:set_string("formspec",copybooks_formspec(state or status_idle))
end

local function active_state(pos,meta)
	minetest.swap_node(pos,{name="copybooks:copybooks_active"})
	meta:set_string("infotext",status_active)
	meta:set_string("formspec",copybooks_formspec(status_active))
end

minetest.register_abm({
	label = "copybooks:copy",
	nodenames = {"group:copybooks"},
	interval = 1.0,
	chance = 1,
	catch_up = true,
	action = function(pos, node, active_object_count, active_object_count_wider)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		if inv:is_empty("master") then
			inactive_state(pos,meta)
			return
		elseif inv:is_empty("input") then
			inactive_state(pos,meta,status_nopaper)
			return
		end

		local input = inv:get_list("input")
		local output = inv:get_list("output")
		local master = inv:get_list("master")

		local master_copy = inv:get_stack("master", 1)
		local master_contents = master_copy:get_meta():to_table()

		master_contents.fields.owner = S("@1 (copy)",master_contents.fields.owner or "???")

		local copy = ItemStack({name = "default:book_written", count = 1})
		copy:get_meta():from_table(master_contents)

		if inv:room_for_item("output", copy) then
			if inv:contains_item("input", {name = "default:book", count = 1}) then
				inv:remove_item("input", {name = "default:book", count = 1})
				inv:add_item("output", copy)
			elseif inv:contains_item("input", {name = "default:paper", count = 3}) then
				inv:remove_item("input", {name = "default:paper", count = 3})
				inv:add_item("output", copy)
			else
				inactive_state(pos,meta,status_nopaper)
				return
			end
			active_state(pos,meta)
		else
			inactive_state(pos,meta,status_full)
		end
	end,
})


