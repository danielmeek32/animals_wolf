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
		self.object:set_properties({textures = {"animals_wolf.png"}})
	else
		self.object:set_properties({textures = {"animals_wolf.png^animals_wolf_collar_" .. self.collar_colour .. ".png"}})
	end
end

local def = {
	name = "animals:wolf",
	stats = {
		hp = 20,
		lifetime = 450, -- 7.5 Minutes
		jump_height = 1.0,
		follow_items = {"animals:flesh","animals:meat"},
		follow_speed = 4.0,
		follow_radius = 6,
		follow_stop_distance = 3.0,
		tame_items = {"animals:flesh","animals:meat"},
	},

	model = {
		mesh = "animals_wolf.b3d",
		textures = {"animals_wolf.png"},
		collisionbox = {-0.4, 0, -0.4, 0.4, 1.25, 0.4},
		scale = {x = 10, y = 10},
		rotation = -90.0,
		collide_with_objects = true,
		animations = {
			idle = {start = 0, stop = 1, speed = 1},
			howl = {start = 70, stop = 90, speed = 5, loop = false},
			walk = {start = 20, stop = 29, speed = 13},
			walk_long = {start = 20, stop = 29, speed = 13},
			sit = {start = 10, stop = 11, speed = 1},
			follow = {start = 40, stop = 59, speed = 40},
			death = {start = 100, stop = 110, speed = 20, loop = false, duration = 1.0},
		},
	},

	sounds = {
		on_damage = {name = "animals_wolf_whimper", gain = 1.0, distance = 10},
		on_death = {name = "animals_wolf_whimper", gain = 1.0, distance = 10},
		swim = {name = "animals_splash", gain = 1.0, distance = 10},
		random = {},
	},

	modes = {
		idle = {chance = 0.23, duration = 2, update_yaw = 8},
		howl = {chance = 0.02, duration = 4},
		walk = {chance = 0.375, duration = 2, moving_speed = 1.3},
		walk_long = {chance = 0.375, duration = 4, moving_speed = 1.3, update_yaw = 5},
		sit = {chance = 0.0, duration = 0, moving_speed = 0.0},
	},

	drops = {},

	spawning = {
		abm_nodes = {
			spawn_on = {"default:dirt_with_snow", "default:snowblock"},
		},
		abm_interval = 120,
		abm_chance = 12288,
		max_number = 1,
		number = {min = 3, max = 4},
		time_range = {min = 0, max = 24000},
		light = {min = 0, max = 15},
		height_limit = {min = 0, max = 64},
	},

	get_staticdata = function(self)
		return {
			collar_colour = self.collar_colour,
		}
	end,

	on_activate = function(self, staticdata)
		self.player_search_time = 0
		self.was_seeking_player = false
		self.previous_mode = ""

		if self.collar_colour == nil then
			self.collar_colour = "none"
		end
		update_collar(self)
	end,

	on_rightclick = function(self, clicker)
		if self.tamed == true then
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
						if not core.setting_getbool("creative_mode") then
							item:set_count(item:get_count() - 1)
							clicker:set_wielded_item(item)
						end
					end
				end

				-- drop the old collar
				local drop_item_name = "animals_wolf:collar_" .. self.collar_colour
				if drop_item_name ~= "animals_wolf:collar_none" then
					animals.dropItems(self.object:getpos(), {{drop_item_name}})
				end

				-- set the new collar
				self.collar_colour = new_colour
				update_collar(self)
			else	-- sit
				if self.mode ~= "sit" then
					self.mode = "sit"
					self.target = nil
				else
					self.mode = ""
					self.target = nil
				end
			end
		end
		return false
	end,

	on_step = function(self, dtime)
		if self.mode == "howl" and self.previous_mode ~= self.mode then
			core.sound_play("animals_wolf_howl", {pos = self.object:getpos(), gain = 1.0, max_hear_distance = 64})
		end
		self.previous_mode = self.mode

		if self.tamed == true then
			if self.object:get_hp() < 20 then
				self.object:set_hp(20)
			end
			if self.mode ~= "sit" then
				self.player_search_time = self.player_search_time + dtime
				if self.player_search_time > 1.0 then
					self.player_search_time = 0

					local inner_players
					if self.was_seeking_player == true then
						inner_players = animals.findTarget(self.object, self.object:getpos(), 6, "player", self.owner_name, true)
					else
						inner_players = animals.findTarget(self.object, self.object:getpos(), 12, "player", self.owner_name, true)
					end
					local outer_players = animals.findTarget(self.object, self.object:getpos(), 32, "player", self.owner_name, true)
					if #inner_players == 1 and self.was_seeking_player == true then	-- owner within range: idling
						self.was_seeking_player = false
						self.mode = ""
						self.target = nil
					elseif #inner_players == 0 and #outer_players == 1 and self.was_seeking_player == false then	-- owner too far away: following
						self.was_seeking_player = true
						self.mode = "follow"
						self.target = outer_players[1]
					elseif #outer_players == 0 then	-- owner too far away: sitting
						self.was_seeking_player = false
						self.mode = "sit"
						self.target = nil
					end
				end
			end
		end
		return false
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

animals.registerMob(def)
