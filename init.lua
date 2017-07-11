-- Vars

local speed = tonumber(minetest.settings:get("sprint_speed")) or 1.3
local jump = tonumber(minetest.settings:get("sprint_jump")) or 1.1
local key = minetest.settings:get("sprint_key") or "Use"
local dir = minetest.settings:get_bool("sprint_forward_only")
local particles = tonumber(minetest.settings:get("sprint_particles")) or 2
local stamina = minetest.settings:get_bool("sprint_stamina") or true
local stamina_drain = tonumber(minetest.settings:get("sprint_stamina_drain")) or 2
local replenish = tonumber(minetest.settings:get("sprint_stamina_replenish")) or 2
local starve = minetest.settings:get_bool("sprint_starve") or true
local starve_drain = minetest.settings:get("sprint_starve_drain") or 0.5

local sprint_timer_step = 0.5
local sprint_timer = 0
local player_stamina = 20
local stamina_timer = 0

if dir == nil then dir = true end
if stamina ~= false then stamina = true end
if starve == nil then starve = true end
if not minetest.get_modpath("hudbars") then hudbars = false end
if not minetest.get_modpath("hbhunger") then starve = false end
if not minetest.get_modpath("player_monoids") then monoids = false end

-- Functions

local function start_sprint(player)
	if monoids then
		player_monoids.speed:add_change(player, speed, "sprint:sprint")
		player_monoids.jump:add_change(player, jump, "sprint:jump")
	else
		player:set_physics_override({speed = speed, jump = jump})
	end
end

local function stop_sprint(player)
	if monoids then
		player_monoids.speed:del_change(player, "sprint:sprint")
		player_monoids.jump:del_change(player, "sprint:jump")
	else
		player:set_physics_override({speed = 1, jump = 1})
	end
end

local function drain_stamina(player)
	player_stamina = tonumber(player:get_attribute("stamina"))
	if player_stamina > 0 then
		player:set_attribute("stamina", player_stamina - stamina_drain)
	end
	if hudbars then
		if player_stamina < 20 then hb.unhide_hudbar(player, "stamina") end
		hb.change_hudbar(player, "stamina", player_stamina)
	end
end

local function replenish_stamina(player)
	player_stamina = tonumber(player:get_attribute("stamina"))
	if player_stamina < 20 then
		player:set_attribute("stamina", player_stamina + stamina_drain)
	end
	if hudbars then
		hb.change_hudbar(player, "stamina", player_stamina)
		if player_stamina == 20 then hb.hide_hudbar(player, "stamina") end
	end
end

local function drain_hunger(player, hunger, name)
	if hunger > 0 then
		hbhunger.hunger[name] = hunger - starve_drain
		hbhunger.set_hunger_raw(player)
	end
end

local function create_particles(player, name, pos, ground)
	if ground and ground.name ~= "air" and ground.name ~= "ignore" then
		local def = minetest.registered_nodes[ground.name]
		local tile = def.tiles[1] or def.inventory_image or ""
		if type(tile) == "string" then
			for i = 1, particles do
				minetest.add_particle({
					pos = {x = pos.x + math.random(-1,1) * math.random() / 2, y = pos.y + 0.1, z = pos.z + math.random(-1,1) * math.random() / 2},
					velocity = {x = 0, y = 5, z = 0},
					acceleration = {x = 0, y = -13, z = 0},
					expirationtime = math.random(),
					size = math.random() + 0.5,
					vertical = false,
					texture = tile,
				})
			end
		end
	end
end

-- Registrations

if minetest.get_modpath("hudbars") ~= nil and stamina then
	hb.register_hudbar("stamina",
		0xFFFFFF,
		"Stamina",
		{ bar = "sprint_stamina_bar.png", icon = "sprint_stamina_icon.png" },
		player_stamina, player_stamina,
		false, "%s: %.1f/%.1f")
	hudbars = true
	hb.hide_hudbar(player, "stamina")
end

minetest.register_on_joinplayer(function(player)
	if hudbars and stamina then hb.init_hudbar(player, "stamina") end
	player:set_attribute("stamina", 20)
end)

minetest.register_globalstep(function(dtime)
	sprint_timer = sprint_timer + dtime
	stamina_timer = stamina_timer + dtime
	if sprint_timer >= sprint_timer_step then
		for _,player in ipairs(minetest.get_connected_players()) do
			local ctrl = player:get_player_control()
			local key_press = false
			if key == "Use" and dir then
				key_press = ctrl.aux1 and ctrl.up and not ctrl.left and not ctrl.right
			elseif key == "Use" and not dir then
				key_press = ctrl.aux1
			end

			-- if key == "W" and dir then
			-- 	key_press = ctrl.aux1 and ctrl.up or key_press and ctrl.up
			-- elseif key == "W" then
			-- 	key_press = ctrl.aux1 or key_press and key_tap
			-- end

			if key_press then
				local name = player:get_player_name()
				local hunger = 30
				local pos = player:get_pos()
				local ground = minetest.get_node_or_nil({x=pos.x, y=pos.y-1, z=pos.z})
				local walkable = false
				if starve then
					hunger = tonumber(hbhunger.hunger[name])
				end
				if ground ~= nil then
					walkable = minetest.registered_nodes[ground.name].walkable
				end
				if player_stamina > 0 and hunger > 9 and walkable then --AND IF NOT WATER!
					start_sprint(player)
					if stamina then drain_stamina(player) end
					if starve then drain_hunger(player, hunger, name) end
					if particles then create_particles(player, name, pos, ground) end
				end
			else
				stop_sprint(player)
				if stamina_timer >= replenish then
					if stamina then replenish_stamina(player) end
					stamina_timer = 0
				end
			end
		end
		sprint_timer = 0
	end
end)