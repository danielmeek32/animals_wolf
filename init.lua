--= Wolf for Animals mod =--
-- Copyright (c) 2017 Daniel <https://github.com/danielmeek32>
--
-- init.lua
--

local function register_collar(name, colour)
	minetest.register_craftitem("animals_wolf:collar_" .. colour, {
		description = name,
		inventory_image = "animals_wolf_collar_item_" .. colour .. ".png",
		groups = {animals_wolf_collar = 1}
	})
	minetest.register_craft({
		type = "shapeless",
		output = "animals_wolf:collar_" .. colour,
		recipe = {"group:animals_wolf_collar", "dye:" .. colour}
	})
end

local function update_collar(self)
	if self.collar_colour == "none" then
		self:get_luaentity():set_properties({textures = {"animals_wolf.png"}})
	else
		self:get_luaentity():set_properties({textures = {"animals_wolf.png^animals_wolf_collar_" .. self.collar_colour .. ".png"}})
	end
end

local def = {
	name = "animals:wolf",
	parameters = {
		hp = 20,
		life_time = 450, -- 7.5 Minutes
		follow_items = {"animals:flesh", "animals:meat"},
		follow_speed = 4.0,
		follow_distance = 6,
		follow_stop_distance = 3.0,
		tame_items = {"animals:flesh", "animals:meat"},
		death_duration = 1.0,
	},

	model = {
		mesh = "animals_wolf.b3d",
		textures = {"animals_wolf.png"},
		collisionbox = {-0.4, 0, -0.4, 0.4, 1.25, 0.4},
		scale = {x = 10, y = 10},
		rotation = -90.0,
		collide_with_objects = true,
	},

	animations = {
		idle = {start = 0, stop = 1, speed = 1},
		howl = {start = 70, stop = 90, speed = 5, loop = false},
		walk = {start = 20, stop = 29, speed = 13},
		walk_long = {start = 20, stop = 29, speed = 13},
		sit = {start = 10, stop = 11, speed = 1},
		follow = {start = 40, stop = 59, speed = 40},
		death = {start = 100, stop = 110, speed = 20, loop = false},
	},

	sounds = {
		damage = {name = "animals_wolf_whimper", gain = 1.0, max_hear_distance = 10},
		death = {name = "animals_wolf_whimper", gain = 1.0, max_hear_distance = 10},
		swim = {name = "animals_splash", gain = 1.0, max_hear_distance = 10},
		howl = {name = "animals_wolf_howl", gain = 1.0, max_hear_distance = 64, play_on_mode_change = true},
	},

	modes = {
		idle = {chance = 0.23, min_duration = 2, max_duration = 3},
		howl = {chance = 0.02, duration = 4},
		walk = {chance = 0.375, duration = 2, moving_speed = 1.3, change_direction_on_mode_change = true},
		walk_long = {chance = 0.375, duration = 4, moving_speed = 1.3, change_direction_on_mode_change = true, min_direction_change_interval = 2, max_direction_change_interval = 3},
		sit = {chance = 0.0, moving_speed = 0.0},
	},

	drops = {},

	spawning = {
		nodes = {"default:dirt_with_snow", "default:snowblock"},
		interval = 60,
		chance = 32768,
		surrounding_distance = 64,
		max_surrounding_count = 0,
		min_spawn_count = 3,
		max_spawn_count = 4,
		spawn_area = 8,
	},

	get_staticdata = function(self)
		return {
			sitting = (self:get_mode() == "sit"),
			collar_colour = self.collar_colour,
		}
	end,

	on_activate = function(self, staticdata)
		self.owner_search_time = 0
		self.seeking_owner = false

		local table = minetest.deserialize(staticdata)
		if table and type(table) == "table" then
			self.collar_colour = table.collar_colour
			if table.sitting == true then
				self:set_mode("sit")
			end
		end
		if self.collar_colour == nil then
			self.collar_colour = "none"
		end
		update_collar(self)
	end,

	on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, dir)
		-- block punch if tamed
		return self:is_tame()
	end,

	on_rightclick = function(self, clicker)
		if self:is_tame() == true then
			if clicker:get_player_control().sneak == true then	-- change collar
				-- determine the new collar
				local item = clicker:get_wielded_item()
				local new_colour = "none"
				if item then
					local name = item:get_name()
					if string.match(name, "^animals_wolf:collar_") then
						new_colour = string.gsub(name, "animals_wolf:collar_", "")
					end
					if new_colour ~= "none" then
						if not minetest.setting_getbool("creative_mode") then
							item:take_item()
							clicker:set_wielded_item(item)
						end
					end
				end

				-- drop the old collar
				local drop_item_name = "animals_wolf:collar_" .. self.collar_colour
				if drop_item_name ~= "animals_wolf:collar_none" then
					self:drop_items({{name = drop_item_name}})
				end

				-- set the new collar
				self.collar_colour = new_colour
				update_collar(self)
			else	-- sit
				if self:get_mode() ~= "sit" then
					self:set_mode("sit")
				else
					self:choose_random_mode()
				end
			end
		end
		return false
	end,

	on_step = function(self, dtime)
		if self:is_tame() == true then
			if self:get_mode() ~= "sit" then
				self.owner_search_time = self.owner_search_time + dtime
				if self.owner_search_time > 1.0 then
					self.owner_search_time = 0

					local inner_objects
					if self.seeking_owner == true then
						inner_objects = self:find_objects(6, "owner", true)
					else
						inner_objects = self:find_objects(12, "owner", true)
					end
					local outer_objects = self:find_objects(32, "owner", true)
					if #inner_objects == 1 and self.seeking_owner == true then	-- owner within range: idling
						self.seeking_owner = false
						self:choose_random_mode()
					elseif #inner_objects == 0 and #outer_objects == 1 and self.seeking_owner == false then	-- owner too far away: following
						self.seeking_owner = true
						self:follow(outer_objects[1])
					elseif #outer_objects == 0 then	-- owner too far away: sitting
						self.seeking_owner = false
						self:set_mode("sit")
					end
				end
			end
		end
		return false
	end,

	on_tame = function(self, owner_name)
		self:get_luaentity():set_hp(20)
		return true
	end,
}

register_collar("Red Collar", "red");
register_collar("Orange Collar", "orange");
register_collar("Yellow Collar", "yellow");
register_collar("Lime Collar", "lime");
register_collar("Green Collar", "green");
register_collar("Aqua Collar", "aqua");
register_collar("Cyan Collar", "cyan");
register_collar("Sky Blue Collar", "skyblue");
register_collar("Blue Collar", "blue");
register_collar("Violet Collar", "violet");
register_collar("Magenta Collar", "magenta");
register_collar("Red-violet Collar", "redviolet");
register_collar("Black Collar", "black");
register_collar("Dark Grey Collar", "dark_grey");
register_collar("Light Grey Collar", "light_grey");
register_collar("White Collar", "white");

minetest.register_craft({
	output = "animals_wolf:collar_white",
	recipe = {
		{"wool:white", "wool:white", "wool:white"},
		{"wool:white", "", "wool:white"},
		{"wool:white", "default:steel_ingot", "wool:white"},
	}
})

animals.register(def)
