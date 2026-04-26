#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include maps\mp\zombies\_zm_weapons;

#include scripts\zm\zm_bo2_bots;
#include scripts\zm\zm_bo2_bots_utility;

bot_combat_think(damage, attacker, direction)
{
	self allowattack(0);
	self pressads(0);
	
	for (;;)
	{
		if (!bot_can_do_combat())
		{
			return;
		}
		if(self atgoal("flee"))
			self cancelgoal("flee");
		//FLEE CODE. IF ZOMBIE IS CLOSE TO BOT, BOT WILL TRY TO FIND A PLACE TO RUN AWAY
		//LOOKING FOR ANOTHER ALTERNATIVE IF DOORS ARE CLOSED AND THE BOT CAN NOT REACH SAID PATH.
		if(Distance(self.origin, self.bot.threat.position) <= 75 || isdefined(damage))
		{
			if (!isDefined(self.bot.next_flee_scan) || getTime() > self.bot.next_flee_scan)
			{
				self.bot.next_flee_scan = getTime() + 500;

				nodes = getnodesinradiussorted(self.origin, 1024, 256, 512);
			}
			else
			{
				nodes = [];
			}
			nearest = bot_nearest_node(self.origin);
			if (isDefined(nearest) && !self hasgoal("flee"))
			{
				foreach (node in nodes)
				{
					if (!nodesvisible(nearest, node) && randomint(100) < 25 && FindPath(self.origin, node.origin, undefined, 0, 1))
					{
						self addgoal(node.origin, 24, 4, "flee");
						break;
					}
				}
			}
		}
		if(self GetCurrentWeapon() == "none")
			return;
		
		sight = self bot_best_enemy();
		
		if(!isdefined(self.bot.threat.entity))
			return;
		
		if (threat_dead())
		{
			self bot_combat_dead();
			return;
		}
		//ADD OTHER COMBAT TASKS HERE.
		self bot_combat_main();
		self bot_pickup_powerup();

		// Initialize door coordination and mystery box tracking variables if not defined
		if(!isDefined(level.door_being_opened))
			level.door_being_opened = false;
			
		if(!isDefined(level.mystery_box_teddy_locations))
			level.mystery_box_teddy_locations = [];
		
		if (!isDefined(self.bot.next_interact_time) || getTime() > self.bot.next_interact_time)
		{
			self.bot.next_interact_time = getTime() + 1000; // once per second
	
			self bot_safely_interact_with_doors();
			self bot_safely_use_mystery_box();
		}
		
		if(is_true(level.using_bot_revive_logic))
		{
			self bot_revive_teammates();
		}
		wait 0.5;
	}
}

init_door_triggers()
{
	if (!isDefined(level.cached_door_triggers))
	{
		triggers = getEntArray("zombie_door", "targetname");
		triggers = array_combine(triggers, getEntArray("zombie_debris", "targetname"));
		triggers = array_combine(triggers, getEntArray("zombie_airlock_buy", "targetname"));
		level.cached_door_triggers = triggers;
	}
}

// Prevents multiple bots from trying to open the same door at once
bot_safely_interact_with_doors()
{
	if (isDefined(self.bot.last_door_use_time))
	{
		if (getTime() - self.bot.last_door_use_time < 2000)
			return;
	}
	
	// Don't try to open doors if another bot is already doing it
	if(is_true(level.door_being_opened))
		return;

	init_door_triggers();
	door_triggers = level.cached_door_triggers;
	
	closest_dist = 999999;
	closest_door = undefined;
	
	foreach(door in door_triggers)
	{
		if(!isDefined(door))
			continue;
			
		dist = Distance(self.origin, door.origin);
		if(dist < closest_dist && dist < 80) // Only consider doors within 80 units
		{
			closest_dist = dist;
			closest_door = door;
		}
	}
	
	// If we're near a door, try to open it safely
	if(isDefined(closest_door))
	{
		// Set global flag to prevent other bots from trying at the same time
		level.door_being_opened = true;
		
		// Try to open the door
		self UseButtonPressed();
		
		// Wait a bit for door to process
		wait 1;
		
		// Reset flag so other bots can try later
		level.door_being_opened = false;
	}
	self.bot.last_door_use_time = getTime();
}

init_box_triggers()
{
	if (!isDefined(level.cached_box_triggers))
	{
		level.cached_box_triggers = getEntArray("treasure_chest_use", "targetname");
	}
}

// Prevents bots from using mystery boxes that have teddy bears
bot_safely_use_mystery_box()
{
	// Find closest mystery box
	init_box_triggers();
	box_triggers = level.cached_box_triggers;
	
	closest_dist = 999999;
	closest_box = undefined;
	
	foreach(box in box_triggers)
	{
		if(!isDefined(box))
			continue;
			
		dist = Distance(self.origin, box.origin);
		if(dist < closest_dist && dist < 80) // Only consider boxes within 80 units
		{
			closest_dist = dist;
			closest_box = box;
		}
	}
	
	// If we found a box and we're close to it
	if(isDefined(closest_box))
	{
		// Check if this box has a teddy bear
		box_location = closest_box.origin;
		if(array_contains(level.mystery_box_teddy_locations, box_location))
		{
			// Don't use this box, it has a teddy bear
			return;
		}
		
		// Watch for teddy bear notifications
		if (!isDefined(self.bot.watching_box) || !self.bot.watching_box)
		{
			self.bot.watching_box = true;
			if (!isDefined(self.bot.watching_box_thread))
			{
				self.bot.watching_box_thread = true;
				self thread watch_for_box_teddy(closest_box);
			}
		}
		
		if (isDefined(self.bot.last_box_use_time))
		{
			if (getTime() - self.bot.last_box_use_time < 2000)
				return;
		}
		
		// Use the box
		self UseButtonPressed();
	}
	self.bot.last_box_use_time = getTime();
}

// Monitor box for teddy bear
watch_for_box_teddy(box)
{
	self endon("disconnect");

	level waittill_any("weapon_fly_away_start", "teddy_bear", "box_moving");

	if (isDefined(box) && isDefined(box.origin))
	{
		if(!array_contains(level.mystery_box_teddy_locations, box.origin))
		{
			if (level.mystery_box_teddy_locations.size < 32)
			{			
				level.mystery_box_teddy_locations[level.mystery_box_teddy_locations.size] = box.origin;
			}
		}
	}

	// IMPORTANT: release the lock so it can run again later
	self.bot.watching_box = false;
	
	self.bot.watching_box_thread = undefined;
}

// Check if an array contains a specific value (origin)
array_contains(array, value)
{
	if(!isDefined(array) || !array.size)
		return false;
		
	foreach(item in array)
	{
		// Compare origins with a small tolerance
		if(Distance(item, value) < 10)
			return true;
	}
	
	return false;
}

// Helper function to combine arrays
array_combine(array1, array2)
{
	if(!isDefined(array1))
		return array2;
	
	if(!isDefined(array2))
		return array1;
		
	combined = [];
	foreach(item in array1)
	{
		combined[combined.size] = item;
	}
	
	foreach(item in array2)
	{
		combined[combined.size] = item;
	}
	
	return combined;
}

bot_combat_main() //checked partially changed to match cerberus output changed at own discretion
{
	weapon = self getcurrentweapon();
	
	// Force bot to finish reloading until clip is full
	if (self isreloading())
	{
		clip = self getweaponammoclip(weapon);
		max = weaponclipsize(weapon);

		if (clip < max)
		{
			self.bot.reload_until_full = true;
		}
	}
	currentammo = self getweaponammoclip(weapon) + self getweaponammostock(weapon);
	if (!currentammo)
	{
		return;
	}
	ads = 0;
	time = getTime();
	if (!self bot_should_hip_fire() && self.bot.threat.dot > 0.85)
	{
		ads = 1;
	}
	if (ads)
	{
		self pressads(1);
	}
	else
	{
		self pressads(0);
	}
	frames = 4;
	if (time >= self.bot.threat.time_aim_correct)
	{
		self.bot.threat.time_aim_correct += self.bot.threat.time_aim_interval;
		frac = (time - self.bot.threat.time_first_sight) / 100;
		frac = clamp(frac, 0, 1);
		if (!threat_is_player())
		{
			frac = 1;
		}
		self.bot.threat.aim_target = self bot_update_aim(frames);
		self.bot.threat.position = self.bot.threat.entity.origin;
		self bot_update_lookat(self.bot.threat.aim_target, frac);
	}
	if (isDefined(self.bot.reload_until_full) && self.bot.reload_until_full)
	{
		clip = self getweaponammoclip(weapon);
		max = weaponclipsize(weapon);

		// If still not full, keep blocking attack
		if (clip < max)
		{
			self allowattack(0);
			return;
		}
		else
		{
			self.bot.reload_until_full = undefined;
		}
	}
	if (self bot_on_target(self.bot.threat.aim_target, 100))
	{
		self allowattack(1);
	}
	else
	{
		self allowattack(0);
	}
	if (is_true(self.stingerlockstarted))
	{
		self allowattack(self.stingerlockfinalized);
		return;
	}
}

bot_combat_dead(damage) //checked matches cerberus output
{
	wait 0.1;
	self allowattack(0);
	wait_endon(0.25, "damage");
	self bot_clear_enemy();
}

bot_should_hip_fire() //checked matches cerberus output
{
	enemy = self.bot.threat.entity;
	weapon = self getcurrentweapon();
	if (weapon == "none")
	{
		return 0;
	}
	if (weaponisdualwield(weapon))
	{
		return 1;
	}
	class = weaponclass(weapon);
	if (isplayer(enemy) && class == "spread")
	{
		return 1;
	}
	distsq = distancesquared(self.origin, enemy.origin);
	distcheck = 0;
	switch(class)
	{
		case "mg":
			distcheck = 250;
			break;
		case "smg":
			distcheck = 350;
			break;
		case "spread":
			distcheck = 400;
			break;
		case "pistol":
			distcheck = 200;
			break;
		case "rocketlauncher":
			distcheck = 0;
			break;
		case "rifle":
		default:
			distcheck = 300;
			break;
	}
	if (isweaponscopeoverlay(weapon))
	{
		distcheck = 500;
	}
	return distsq < (distcheck * distcheck);
}

bot_patrol_near_enemy(damage, attacker, direction) //checked matches cerberus output
{
	if (isDefined(attacker))
	{
		self bot_lookat_entity(attacker);
	}
	if (!isDefined(attacker))
	{
		attacker = self bot_get_closest_enemy(self.origin);
	}
	if (!isDefined(attacker))
	{
		return;
	}
	node = bot_nearest_node(attacker.origin);
	if (!isDefined(node))
	{
		nodes = getnodesinradiussorted(attacker.origin, 1024, 0, 512, "Path", 8);
		if (nodes.size)
		{
			node = nodes[0];
		}
	}
	if (isDefined(node))
	{
		if (isDefined(damage))
		{
			self addgoal(node, 24, 4, "enemy_patrol");
			return;
		}
		else
		{
			self addgoal(node, 24, 2, "enemy_patrol");
		}
	}
}

bot_lookat_entity(entity) //checked matches cerberus output
{
	if (isplayer(entity) && entity getstance() != "prone")
	{
		if (distancesquared(self.origin, entity.origin) < 65536)
		{
			origin = entity getcentroid() + vectorScale((0, 0, 1), 10);
			self lookat(origin);
			return;
		}
	}
	offset = target_getoffset(entity);
	if ( isDefined(offset))
	{
		self lookat(entity.origin + offset);
	}
	else
	{
		self lookat(entity getcentroid());
	}
}

bot_update_lookat(origin, frac) //checked matches cerberus output
{
    if (!isDefined(self.bot.threat.entity))
        return;

    self lookat(origin);
}

bot_update_aim(frames) //checked matches cerberus output
{
	ent = self.bot.threat.entity;
	
	weapon = self getcurrentweapon();

    if (!isDefined(ent.origin))
        return self.origin;

	dist = Distance(self.origin, ent.origin);

	// Scale prediction based on distance
    if (dist > 1200)
        frames = 12;
    else if (dist > 800)
        frames = 9;
    else if (dist > 400)
        frames = 6;
    else
        frames = 4;

	prediction = self predictposition(ent, frames);
	
	// Forward compensation
    vel = ent getvelocity();
    prediction += vel * 0.07;

	//Wonder Weapons
	has_blundersplat = self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("blundersplat_zm");
	has_blundergat = self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("blundergat_zm");
	has_slowgun = self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("slowgun_zm");
	has_slipgun = 	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("slipgun_zm");
	has_raygun_mk2 = self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("raygun_mark2_zm");
	has_raygun = self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("ray_gun_zm");
	//

	//Wonder Staffs
	has_wonder_staffs = 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("staff_water_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("staff_air_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("staff_fire_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("staff_lightning_zm");
	//

	//Explosives Weapons
	has_explosive_weapon = 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("usrpg_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("m32_zm");
	//

	//Snipers
	has_sniper = 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("barretm82_zm");
	//

	//Shotguns
	has_shotgun = 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("srm1216_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("ksg_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("saiga12_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("870mcs_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("rottweil72_zm");
	//
	
	//Assault Rifles
	has_assault_rifle = 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("type95_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("tar21_zm") || 
	
	weapon == "an94_zm";
	//
	
	//SMGs
	has_smg = 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("evoskorpion_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("mp5k_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("ak74u_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("ak74u_extclip_zm");
	//
	
	//Revolvers/Magnum
	has_revolver = 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("python_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("rnma_zm");
	
	has_executioner = self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("judge_zm");
	//
	
	//Other Weapons
	has_smr = weapon == "saritch_zm";
	has_m16_PaP = weapon == "m16_upgraded_zm";
	has_m14 = self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("m14_zm");
	has_m1911_PaP = weapon == "m1911_upgraded_zm";
	//

	if (!threat_is_player())
	{
        centroid = ent getcentroid();
		height = centroid[2] - prediction[2];
		
		if (has_wonder_staffs || has_blundersplat || has_slowgun || has_slipgun || has_raygun_mk2 || has_executioner)
		aim_offset = 10;
		
		else if (has_blundergat || has_shotgun || has_assault_rifle || has_smg || has_smr || has_m16_PaP || has_m14 || has_revolver)
		aim_offset = 20;
		
		else if (has_raygun || has_explosive_weapon || has_m1911_PaP || has_sniper)
		aim_offset = 0;
		
		else
		aim_offset = 25;

        // Distance correction
        if (dist > 1200)
            aim_offset -= 5;
        else if (dist > 800)
            aim_offset -= 4;

		return prediction + (0, 0, height + aim_offset);
	}

	height = ent getplayerviewheight();
    return prediction + (0, 0, height);
}

bot_on_target(aim_target, radius) //checked matches cerberus output
{
	angles = self getplayerangles();
	forward = anglesToForward(angles);
	origin = self getplayercamerapos();
	len = distance(aim_target, origin);
	end = origin + (forward * len);
	if (distance2dsquared(aim_target, end) < (radius * radius))
	{
		return 1;
	}
	return 0;
}

bot_get_aim_error() //checked changed at own discretion
{
	return 0;
}

bot_has_lmg() //checked changed at own discretion
{
	if (bot_has_weapon_class("mg"))
	{
		return 1;
	}
	return 0;
}

bot_has_weapon_class(class) //checked changed at own discretion
{
	if (self isreloading())
	{
		return 0;
	}
	weapon = self getcurrentweapon();
	if (weapon == "none")
	{
		return 0;
	}
	if (weaponclass(weapon) == class)
	{
		return 1;
	}
	return 0;
}

bot_can_reload() //checked changed to match cerberus output
{
	weapon = self getcurrentweapon();
	if (weapon == "none")
	{
		return 0;
	}
	if (!self getweaponammostock(weapon))
	{
		return 0;
	}
	if (self isreloading() || self isswitchingweapons() || self isthrowinggrenade())
	{
		return 0;
	}
	return 1;
}

bot_best_enemy() //checked partially changed to match cerberus output did not change while loop to foreach see github for more info
{
	enemies = getaispeciesarray(level.zombie_team, "all");
	enemies = arraysort(enemies, self.origin);
	i = 0;
	while (i < enemies.size)
	{
		if (threat_should_ignore(enemies[i]))
		{
			i++;
			continue;
		}
		if (self botsighttracepassed(enemies[i]))
		{
			self.bot.threat.entity = enemies[i];
			self.bot.threat.time_first_sight = getTime();
			self.bot.threat.time_recent_sight = getTime();
			self.bot.threat.dot = bot_dot_product(enemies[i].origin);
			self.bot.threat.position = enemies[i].origin;
			return 1;
		}
		i++;
	}
	return 0;
}

bot_weapon_ammo_frac() //checked matches cerberus output
{
	if (self isreloading() || self isswitchingweapons())
	{
		return 0;
	}
	weapon = self getcurrentweapon();
	if (weapon == "none")
	{
		return 1;
	}
	total = weaponclipsize(weapon);
	if (total <= 0)
	{
		return 1;
	}
	current = self getweaponammoclip(weapon);
	return current / total;
}

bot_select_weapon() //checked partially changed to match cerberus output did not change while loop to foreach see github for more info
{
	if (self isthrowinggrenade() || self isswitchingweapons() || self isreloading())
	{
		return;
	}
	if (!self isonground())
	{
		return;
	}
	ent = self.bot.threat.entity;
	if (!isDefined(ent))
	{
		return;
	}
	primaries = self getweaponslistprimaries();
	weapon = self getcurrentweapon();
	stock = self getweaponammostock(weapon);
	clip = self getweaponammoclip(weapon);
	if (weapon == "none")
	{
		return;
	}
	if (weapon == "fhj18_mp" && !target_istarget(ent))
	{
		foreach (primary in primaries)
		{
			if (primary != weapon)
			{
				self switchtoweapon(primary);
				return;
			}
		}
		return;
	}
	if (!clip)
	{
		if (stock)
		{
			if (weaponhasattachment(weapon, "fastreload"))
			{
				return;
			}
		}
		i = 0;
		while (i < primaries.size)
		{
			if (primaries[i] == weapon || primaries[i] == "fhj18_mp")
			{
				i++;
				continue;
			}
			if (self getweaponammoclip(primaries[i]))
			{
				self switchtoweapon(primaries[i]);
				return;
			}
			i++;
		}
		if (self bot_has_lmg())
		{
			i = 0;
			while (i < primaries.size)
			{
				if (primaries[i] == weapon || primaries[i] == "fhj18_mp")
				{
					i++;
					continue;
				}
				else
				{
					self switchtoweapon(primaries[i]);
					return;
				}
				i++;
			}
		}
	}
}

bot_can_do_combat() //checked matches cerberus output
{
	if (self ismantling() || self isonladder())
	{
		return 0;
	}
	return 1;
}

bot_dot_product(origin) //checked matches cerberus output
{
	angles = self getplayerangles();
	forward = anglesToForward(angles);
	delta = origin - self getplayercamerapos();
	delta = vectornormalize(delta);
	dot = vectordot(forward, delta);
	return dot;
}

threat_should_ignore(entity) //checked matches cerberus output
{
	return 0;
}

bot_clear_enemy() //checked matches cerberus output
{
	self clearlookat();
	self.bot.threat.entity = undefined;
}

bot_has_enemy() //checked changed at own discretion
{
	if (isDefined(self.bot.threat.entity))
	{
		return 1;
	}
	return 0;
}

threat_dead() //checked changed at own discretion
{
	if (self bot_has_enemy())
	{
		ent = self.bot.threat.entity;
		if (!isalive(ent))
		{
			return 1;
		}
		return 0;
	}
	return 0;
}

threat_is_player() //checked changed at own discretion
{
	ent = self.bot.threat.entity;
	if (isDefined(ent) && isplayer(ent))
	{
		return 1;
	}
	return 0;
}