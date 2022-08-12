if not minetest.get_modpath("digilines") then
	return
end

copybooks.digiline_writer = true

local S = minetest.get_translator("copybooks")
local F = minetest.formspec_escape

local infotext = S("Digiline Printer")

local function formspec(c)
	return "" ..
		"size[8,9]"..

		"label[0,0;"..S("Inputs").."]"..
		"list[context;input;0,0.5;3,3;]" ..
		"listring[current_player;main]"..

		"button_exit[3,1.5;1,1;quit;" .. S("Quit") .. "]"..
		"button_exit[3,2.5;1,1;set;" .. S("Save") .. "]"..

		"label[6.7,0;"..S("Copies").."]"..
		"list[context;output;4,0.5;4,4;]"..

		"field[0.25,4;4,1;channel;" .. S("Digiline channel:") .. ";" .. F(c or "") .. "]"..

		"list[current_player;main;0,5;8,4;]" ..
		"listring[context;input]"
end

local on_construct = function( pos )
	local meta = minetest.get_meta(pos);
	local inv = meta:get_inventory()

	inv:set_size("input", 9)
	inv:set_size("output", 16)
	inv:set_size("master", 1)
	meta:set_string("channel", "")
	meta:set_string('formspec', formspec())
	meta:set_string('infotext', infotext)
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
	return (inv:is_empty("input") and inv:is_empty("output"))
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

minetest.register_node("copybooks:digiline_writer", {
	description = infotext,
	tiles = {	"mfu_top.png",
			"mfu_bottom.png",
                  "mfu_side.png",
                  "mfu_side.png",
			"mfu_back.png",
                  "mfu_front.png",
			},
	groups = {cracky = 1, tubedevice = 1, tubedevice_receiver = 1},
	allow_metadata_inventory_put = mfu_allow_metadata_inventory_put,
	allow_metadata_inventory_move = mfu_allow_metadata_inventory_move,
	paramtype = "light",
	paramtype2 = "facedir",
	drop = "copybooks:copybooks",
	can_dig = mfu_can_dig,
	tube = mfu_tube,
	on_construct = on_construct,
	digiline = {
		receptor = {},
		effector = {
			action = function(pos,_,channel,msg)
				local meta = minetest.get_meta(pos)
				local listen_on = meta:get_string('channel')
				local inv = meta:get_inventory()

				if listen_on == "" or channel ~= listen_on then
					return
				end

				if type(msg) ~= "table" then
					return
				end

				if msg.command == "STATUS" then
					if not inv:contains_item("input", {name = "default:book", count = 1}) and
						not inv:contains_item("input", {name = "default:paper", count = 3}) then
						digilines.receptor_send(pos, digilines.rules.default, channel, { STATUS = "NO PAPER" })
					elseif not inv:room_for_item("output", {name = "default:book_written", count = 1}) then
						digilines.receptor_send(pos, digilines.rules.default, channel, { STATUS = "OUTPUT FULL" })
					else
						digilines.receptor_send(pos, digilines.rules.default, channel, { STATUS = "IDLE" })
					end
				elseif msg.command == "SUPPLIES" then
					local data = {
						["default:paper"] = 0,
						["default:book"] = 0,
						empty = 0,
					}

					for i = 1,9,1 do
						local s = inv:get_stack("input", i)
						if not s:is_empty() then
							local name = s:get_name()
							data[name] = data[name] + s:get_count()
						else
							data.empty = data.empty + 1
						end
					end

					local message = {
						STATUS = "OK",
						FREE = data.empty,
						PAPER = tonumber(data["default:paper"]),
						BOOKS = tonumber(data["default:book"]),
						COPIES = math.floor(tonumber(data["default:paper"]) / 3) + tonumber(data["default:book"]),
					}

					digilines.receptor_send(pos, digilines.rules.default, channel, message)
				elseif msg.command == "PRINT" then
					local max_text_size = 10000
					local max_title_size = 80
					local short_title_size = 35
					local lpp = 14

					local book = ItemStack({name = "default:book_written", count = 1})
					local data = {}
					data.owner = msg.author and S("@1 (printed)",msg.author) or S("Digiline Printer (automatic)")
					data.title = msg.title and msg.title:sub(1, max_title_size) or S("Untitled")

					local short_title = data.title
					-- Don't bother triming the title if the trailing dots would make it longer
					if #short_title > short_title_size + 3 then
						short_title = short_title:sub(1, short_title_size) .. "..."
					end

					data.description = default.get_translator("\"@1\" by @2", short_title, data.owner)
					data.text = msg.text:sub(1, max_text_size)
					data.text = data.text:gsub("\r\n", "\n"):gsub("\r", "\n")
					data.page = 1
					data.page_max = math.ceil((#data.text:gsub("[^\n]", "") + 1) / lpp)

					if msg.watermark then
						data.watermark = msg.watermark
					end

					book:get_meta():from_table({ fields = data })

					local n = tonumber(msg.copies) or 1

					while inv:room_for_item("output", book) and n > 0 do
						if inv:contains_item("input", {name = "default:book", count = 1}) then
							inv:remove_item("input", {name = "default:book", count = 1})
							inv:add_item("output", book)
							n = n - 1
						elseif inv:contains_item("input", {name = "default:paper", count = 3}) then
							inv:remove_item("input", {name = "default:paper", count = 3})
							inv:add_item("output", book)
							n = n - 1
						else
							break
						end
					end
					if n == 0 then
						digilines.receptor_send(pos, digilines.rules.default, channel, { STATUS = "OK", COUNT = msg.copies })
					else
						digilines.receptor_send(pos, digilines.rules.default, channel, { STATUS = "OUTPUT FULL", COUNT = msg.copies - n, DROPPED = n })
					end
				end
			end,
		},
	},
	on_receive_fields = function(pos, formname, fields, sender)
		if fields.set then
			local meta = minetest.get_meta(pos);
			meta:set_string('channel', fields.channel)
			meta:set_string('formspec', formspec(fields.channel))
		end
	end,
})


