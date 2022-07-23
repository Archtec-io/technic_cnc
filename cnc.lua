-- Technic CNC v1.0 by kpoppel
-- Based on the NonCubic Blocks MOD v1.4 by yves_de_beck

-- Idea:
--   Somehow have a tabbed/paged panel if the number of shapes should expand
--   beyond what is available in the panel today.
--   I could imagine some form of API allowing modders to come with their own node
--   box definitions and easily stuff it in the this machine for production.

local S = minetest.get_translator("technic_cnc")

local allow_metadata_inventory_put
local allow_metadata_inventory_take
local allow_metadata_inventory_move
local can_dig
local desc_tr = S("CNC Machine")


minetest.register_craft({
	output = 'technic:cnc',
	recipe = {
		{'default:glass',       'default:diamond',    'default:glass'},
		{'basic_materials:ic',  'default:steelblock', 'basic_materials:motor'},
		{'default:steel_ingot', 'default:mese',       'default:steel_ingot'},
	},
})

allow_metadata_inventory_put = function(pos, listname, index, stack, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return 0
	end
	return stack:get_count()
end

allow_metadata_inventory_take = function(pos, listname, index, stack, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return 0
	end
	return stack:get_count()
end

allow_metadata_inventory_move = function(pos, from_list, from_index,
		                                to_list, to_index, count, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return 0
	end
	return count
end

can_dig = function(pos, player)
	if player and minetest.is_protected(pos, player:get_player_name()) then return false end
	local meta = minetest.get_meta(pos);
	local inv = meta:get_inventory()
	return inv:is_empty("dst")
		and inv:is_empty("src")
		and default.can_interact_with_node(player, pos)
end

local onesize_products = {
	pyramid                  = 2,
	spike                    = 1,
	cylinder                 = 2,
	oblate_spheroid          = 1,
	sphere                   = 1,
	stick                    = 8,
	onecurvededge            = 1,
	twocurvededge            = 1,
}
local twosize_products = {
	element_straight         = 2,
	element_end              = 2,
	element_cross            = 1,
	element_t                = 1,
	element_edge             = 2,
}

local cnc_formspec =
	"size[9,9;]"..
	"label[0.5,0;"..S("Choose Milling Program:").."]"..
	"image_button[0.5,0.5;1,1;technic_cnc_pyramid.png;pyramid; ]"..
	"image_button[1.5,0.5;1,1;technic_cnc_spike.png;spike; ]"..
	"image_button[2.5,0.5;1,1;technic_cnc_cylinder.png;cylinder; ]"..
	"image_button[3.5,0.5;1,1;technic_cnc_oblate_spheroid.png;oblate_spheroid; ]"..
	"image_button[4.5,0.5;1,1;technic_cnc_stick.png;stick; ]"..
	"image_button[5.5,0.5;1,1;technic_cnc_sphere.png;sphere; ]"..
	"image_button[6.5,0.5;1,1;technic_cnc_onecurvededge.png;onecurvededge; ]"..
	"image_button[7.5,0.5;1,1;technic_cnc_twocurvededge.png;twocurvededge; ]"..

	"label[0.5,1.5;"..S("Slim Elements half / normal height:").."]"..

	"image_button[0.5,2;1,0.5;technic_cnc_full.png;full; ]"..
	"image_button[0.5,2.5;1,0.5;technic_cnc_half.png;half; ]"..
	"image_button[1.5,2;1,1;technic_cnc_element_straight.png;element_straight; ]"..
	"image_button[2.5,2;1,1;technic_cnc_element_end.png;element_end; ]"..
	"image_button[3.5,2;1,1;technic_cnc_element_cross.png;element_cross; ]"..
	"image_button[4.5,2;1,1;technic_cnc_element_t.png;element_t; ]"..
	"image_button[5.5,2;1,1;technic_cnc_element_edge.png;element_edge; ]"..

	"label[0,3.5;"..S("In:").."]"..
	"list[context;src;0.5,3.5;1,1;]"..
	"label[3.8,3.5;"..S("Out:").."]"..
	"list[context;dst;4.5,3.5;4,1;]"..

	"list[current_player;main;0.5,5;8,4;]"..
	"listring[context;dst]"..
	"listring[current_player;main]"..
	"listring[context;src]"..
	"listring[current_player;main]"

-- The form handler is declared here because we need it in both the inactive and active modes
-- in order to be able to change programs wile it is running.
local function form_handler(pos, formname, fields, sender)
	local meta       = minetest.get_meta(pos)

	-- REGISTER MILLING PROGRAMS AND OUTPUTS:
	------------------------------------------
	-- Program for half/full size
	if fields["full"] then
		meta:set_int("size", 1)
		return
	end

	if fields["half"] then
		meta:set_int("size", 2)
		return
	end

	-- Resolve the node name and the number of items to make
	local inv        = meta:get_inventory()
	local inputstack = inv:get_stack("src", 1)
	local inputname  = inputstack:get_name()
	local multiplier
	local size       = meta:get_int("size")
	if size < 1 then size = 1 end

	for k, _ in pairs(fields) do
		-- Set a multipier for the half/full size capable blocks
		if twosize_products[k] ~= nil then
			multiplier = size * twosize_products[k]
		else
			multiplier = onesize_products[k]
		end

		if onesize_products[k] ~= nil or twosize_products[k] ~= nil then
			meta:set_float( "cnc_multiplier", multiplier)
			meta:set_string("cnc_user", sender:get_player_name())
		end

		if onesize_products[k] ~= nil or (twosize_products[k] ~= nil and size==2) then
			meta:set_string("cnc_product",  inputname .. "_technic_cnc_" .. k)
			--print(inputname .. "_technic_cnc_" .. k)
			break
		end

		if twosize_products[k] ~= nil and size==1 then
			meta:set_string("cnc_product",  inputname .. "_technic_cnc_" .. k .. "_double")
			--print(inputname .. "_technic_cnc_" .. k .. "_double")
			break
		end
	end

	if not technic_cnc.use_technic then
		local result = meta:get_string("cnc_product")

		if not inv:is_empty("src")
		  and minetest.registered_nodes[result]
		  and inv:room_for_item("dst", result) then
			local srcstack = inv:get_stack("src", 1)
			srcstack:take_item()
			inv:set_stack("src", 1, srcstack)
			inv:add_item("dst", result.." "..meta:get_int("cnc_multiplier"))
		end
	end
end

minetest.register_node(":technic:cnc", {
	description = desc_tr,
	tiles       = {"technic_cnc_top.png", "technic_cnc_bottom.png", "technic_cnc_side.png",
	               "technic_cnc_side.png", "technic_cnc_side.png", "technic_cnc_front.png"},
	groups = {cracky=2, technic_machine=1, technic_lv=1},
	connect_sides = {"bottom", "back", "left", "right"},
	paramtype2  = "facedir",
	legacy_facedir_simple = true,
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("infotext", desc_tr)
		meta:set_float("technic_power_machine", 1)
		meta:set_string("formspec", cnc_formspec)
		local inv = meta:get_inventory()
		inv:set_size("src", 1)
		inv:set_size("dst", 4)
	end,
	can_dig = can_dig,
	allow_metadata_inventory_put = allow_metadata_inventory_put,
	allow_metadata_inventory_take = allow_metadata_inventory_take,
	allow_metadata_inventory_move = allow_metadata_inventory_move,
	on_receive_fields = form_handler,
	technic_run = technic_cnc.use_technic and run,
})

minetest.register_alias("technic:cnc_active", "technic:cnc")
