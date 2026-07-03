#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm;
#include maps\mp\zombies\_zm_utility;
#include maps\mp\zombies\_zm_weapons;
#include maps\mp\zombies\_zm_equipment;
#include maps\mp\zombies\_zm_laststand;

#include scripts\zm\zm_bo2_bots;

bot_combat_think(damage, attacker, direction)
{
	if(is_true(self.bot.is_throwing_grenade))
		return;
	
	self allowattack(0);
	self pressads(0);
	
	if(!bot_can_do_combat())
		return;
	
	if(self atgoal("flee"))
		self cancelgoal("flee");
	
	if((distancesquared(self.origin, self.bot.threat.position) <= 75625 || isdefined(damage)) && !self hasgoal("wander") && !self hasgoal("revive") && !is_true(self.bot.is_reviving) && !self hasgoal("selfrevive") && !is_true(self.bot.is_selfreviving))
	{
		if(!isdefined(self.bot.next_flee_scan) || gettime() > self.bot.next_flee_scan)
		{
			if(get_players().size > 4)
				self.bot.next_flee_scan = gettime() + 3000;
			else
				self.bot.next_flee_scan = gettime() + 1500;
			
			nodes = getnodesinradiussorted(self.origin, 1024, 256, 512);
			
			nearest = bot_nearest_node(self.origin);
			
			if(isdefined(nearest) && !self hasgoal("flee") && isdefined(nodes))
			{
				foreach(node in nodes)
				{
					if(!nodesvisible(nearest, node) && randomint(100) < 512 && findpath(self.origin, node.origin, undefined, 0, 1))
					{
					    if(self getgoal("wander") || self hasgoal("wander"))
							self cancelgoal("wander");
						
						self addgoal(node.origin, 256, 4, "flee");
						
						break;
					}
				}
			}
		}
	}
	
	if(self getcurrentweapon() == "none")
		return;
	
	sight = self bot_best_enemy();
	
	if(!isdefined(self.bot.threat.entity))
		return;
	
	if(threat_dead())
	{
		self bot_combat_dead();
		
		return;
	}
	
	if(!sight && !self bot_has_enemy())
	{
		self allowattack(0);
		self pressads(0);
		
		return;
	}
	
	self bot_combat_main();
}

bot_combat_main()
{
	if(self bot_should_melee())
	{
		if(!is_true(self.bot.is_meleeing))
			self thread bot_combat_melee();
		
		return;
	}
	
    if(self bot_should_throw_grenade())
    {
		if(!is_true(self.bot.is_throwing_grenade))
			self thread bot_combat_throw_grenade();
        
        return;
    }
	
	weapon = self getcurrentweapon();
	
	// Force bot to finish reloading until clip is full
	if(self isreloading())
	{
		clip = self getweaponammoclip(weapon);
		
		max = weaponclipsize(weapon);

		if(clip < max)
		{
			self.bot.reload_until_full = true;
		}
	}
	
	currentammo = self getweaponammoclip(weapon) + self getweaponammostock(weapon);
	
	if(!currentammo)
	{
		return;
	}
	
	ads = 0;
	
	if(!self bot_should_hip_fire() && self.bot.threat.dot > 0.96)
	{
		ads = 1;
	}
	
	if(ads)
	{
		self pressads(1);
	}
	else
	{
		self pressads(0);
	}
	
	time = gettime();
	
	frames = 4;
	
	if(time >= self.bot.threat.time_aim_correct)
	{
		self.bot.threat.time_aim_correct += self.bot.threat.time_aim_interval;
		
		frac = (time - self.bot.threat.time_first_sight) / 100;
		frac = clamp(frac, 0, 1);
		
		if(!threat_is_player())
		{
			frac = 1;
		}
		
		self.bot.threat.aim_target = self bot_update_aim(frames);
		self.bot.threat.position = self.bot.threat.entity.origin;
		self bot_update_lookat(self.bot.threat.aim_target, frac);
	}
	
	if(isdefined(self.bot.reload_until_full) && self.bot.reload_until_full)
	{
		clip = self getweaponammoclip(weapon);
		
		max = weaponclipsize(weapon);

		// Fail-safe: If the clip is full, or the physical reload was interrupted
		if(clip >= max || !self isreloading())
		{
			self.bot.reload_until_full = undefined;
		}
		else
		{
			// If still actively reloading and not full, keep blocking attack
			self allowattack(0);
			return;
		}
	}
	
	if(self bot_on_target(self.bot.threat.entity.origin, 100))
	{
		self allowattack(1);
	}
	else
	{
		self allowattack(0);
	}
	
	if(is_true(self.stingerlockstarted))
	{
		self allowattack(self.stingerlockfinalized);
		
		return;
	}
}

bot_should_melee()
{
	if(self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
		return false;
	
    if(!self isonground() || self getstance() == "prone")
        return false;
	
	if(is_true(self.bot.is_using_box) || is_true(self.bot.is_buying) || is_true(self.bot.is_reviving) || is_true(self.bot.is_selfreviving))
		return false;
	
    if(self isreloading() || self isswitchingweapons() || self isthrowinggrenade())
        return false;
	
    threat = self.bot.threat.entity;
	
    if(!isdefined(threat) || !isalive(threat))
        return false;
	
    if(!isdefined(threat.health))
        return false;
	
    knife_damage = getdvarintdefault("bot_knife_kill_threshold", 150);
	
    if(!level.zombie_vars[self.team]["zombie_powerup_insta_kill_on"] && !self bot_has_ballistic_knife() && threat.health > knife_damage)
        return false;
	
    melee_range = getdvarfloatdefault("bot_meleedist", 70);
	
    if(distance(self.origin, threat.origin) > melee_range)
        return false;
	
    return true;
}

bot_combat_melee()
{
    self endon("disconnect");
    self endon("death");

    if(is_true(self.bot.is_meleeing))
        return;

    self.bot.is_meleeing = true;

    self allowattack(0);
    self pressads(0);

    threat = self.bot.threat.entity;

    if(isdefined(threat))
        self bot_lookat_entity(threat);

    self pressmelee();

    wait 0.5; // Covers the swing animation so it doesn't spam the button every tick

    self.bot.is_meleeing = undefined;
}

bot_should_throw_grenade()
{
	if(level.round_number < 2)
		return false;
	
	if(self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
		return false;
	
    if(is_true(self.bot.is_using_box) || is_true(self.bot.is_buying) || is_true(self.bot.is_reviving) || is_true(self.bot.is_selfreviving))
        return false;
	
    if(self isreloading() || self isswitchingweapons() || self isthrowinggrenade())
        return false;

    threat = self.bot.threat.entity;
	
    if(!isdefined(threat) || !isalive(threat))
        return false;
	
    has_grenade = self getweaponammoclip("frag_grenade_zm") + self getweaponammostock("frag_grenade_zm");
	
	has_sticky_grenade = self getweaponammoclip("sticky_grenade_zm") + self getweaponammostock("sticky_grenade_zm");
	
    if(!has_grenade && !has_sticky_grenade)
        return false;
	
    if(isdefined(self.bot.next_grenade_throw) && gettime() < self.bot.next_grenade_throw)
        return false;
	
    throw_dist_sq = distancesquared(self.origin, threat.origin);
	
    // Don't throw if is too far
    if(throw_dist_sq > 1000000)
        return false;
	
    cluster_radius_sq = 250000;
	
    cluster_count = 0;
	
    zombies = get_cached_zombies();
	
    foreach(zombie in zombies)
    {
        if(!isalive(zombie))
            continue;
		
        if(distancesquared(threat.origin, zombie.origin) <= cluster_radius_sq)
            cluster_count++;
    }
	
    if(cluster_count < 5)
        return false;
	
    return true;
}

bot_combat_throw_grenade()
{
    self endon("disconnect");
    self endon("death");

    if(is_true(self.bot.is_throwing_grenade))
        return;
	
    self.bot.is_throwing_grenade = true;
	
    self.bot.next_grenade_throw = gettime() + 250;
	
    primaries = self getweaponslistprimaries();
	
    original_weapon = primaries[0];
	
	target = self.bot.threat.entity;
	
    self allowattack(0);
    self pressads(0);
	
    has_frag = self getweaponammoclip("frag_grenade_zm") + self getweaponammostock("frag_grenade_zm");
	
    has_sticky = self getweaponammoclip("sticky_grenade_zm") + self getweaponammostock("sticky_grenade_zm");
	
    if(has_frag)
        self switchtoweapon("frag_grenade_zm");
    else if(has_sticky)
        self switchtoweapon("sticky_grenade_zm");
	
    switch_timeout = gettime() + 1000;
	
    while(self isswitchingweapons() && gettime() < switch_timeout)
        wait 0.05;
	
    // Bail out early if the target died while we were switching weapons
    if(!isdefined(target) || !isalive(target))
    {
		self switchtoweapon(original_weapon);
		
        self.bot.is_throwing_grenade = undefined;
		
        return;
    }
	
	if(isdefined(target))
		self bot_lookat_entity(target);
	
    wait 0.2;
	
    self allowattack(1);
	
    throw_start_timeout = gettime() + 250;
	
    while(!self isthrowinggrenade() && gettime() < throw_start_timeout)
    {
        // Bail out immediately if the target dies before the throw even starts
        if(!isdefined(target) || !isalive(target))
            break;

        wait 0.05;
    }
	
    if(self isthrowinggrenade())
    {
        throw_end_timeout = gettime() + 1000;

        while(self isthrowinggrenade() && gettime() < throw_end_timeout)
            wait 0.05;
    }
	
    self allowattack(0);
	
	self switchtoweapon(original_weapon);
	
	self.bot.is_throwing_grenade = undefined;
}

bot_should_hip_fire()
{
	enemy = self.bot.threat.entity;
	
	weapon = self getcurrentweapon();
	
	if(weapon == "none")
	{
		return 0;
	}
	
	if(weaponisdualwield(weapon))
	{
		return 1;
	}
	
	class = weaponclass(weapon);
	
	if(isplayer(enemy) && class == "spread")
	{
		return 1;
	}
	
	distsq = distancesquared(self.origin, enemy.origin);
	
	distcheck = 0;
	
	switch(class)
	{
		case "rocketlauncher":
			distcheck = 0;
			break;
		
		default:
		case "mg":
		case "rifle":
			distcheck = 200;
			break;
		
		case "spread":
			distcheck = 250;
			break;
		
		case "smg":
			distcheck = 400;
			break;
		
		case "pistol":
			distcheck = 300;
			break;
	}
	
	if(isweaponscopeoverlay(weapon))
	{
		distcheck = 500;
	}
	
	return distsq < (distcheck * distcheck);
}

bot_lookat_entity(entity)
{
	if(isplayer(entity) && entity getstance() != "prone")
	{
		if(distancesquared(self.origin, entity.origin) < 65536)
		{
			origin = entity getcentroid() + vectorscale((0, 0, 1), 10);
			
			self lookat(origin);
			
			return;
		}
	}
	
	offset = target_getoffset(entity);
	
	if(isdefined(offset))
	{
		self lookat(entity.origin + offset);
	}
	else
	{
		self lookat(entity getcentroid());
	}
}

bot_update_lookat(origin, frac)
{
    if(!isdefined(self.bot.threat.entity))
        return;

    self lookat(origin);
}

bot_update_aim(frames)
{
	ent = self.bot.threat.entity;

	if(!isdefined(ent))
		return self.origin;

	distsq = distancesquared(self.origin, ent.origin);
	
	dist = sqrt(distsq);

	// Scale prediction based on distance
	if(dist > 1200) 
		frames = 12;
	else if(dist > 800) 
		frames = 9;
	else if(dist > 400) 
		frames = 6;
	else 
		frames = 4;

	prediction = self predictposition(ent, frames);
	
	// Forward compensation
	vel = ent getvelocity();
	
	prediction += vel * 0.07;
	
	weapon = self getcurrentweapon();
	
	class = weaponclass(weapon);

	if(!threat_is_player())
	{
		centroid = ent getcentroid();
		
		height = centroid[2] - prediction[2];
		
		switch(class)
		{
			default:
			case "rocketlauncher":
				aim_offset = 0;
				break;
			
			case "mg":
			case "rifle":
				aim_offset = 10;
				break;
			
			case "spread":
			case "smg":
			case "pistol":
				aim_offset = 5;
				break;
		}
		
		// Distance correction
		if(dist > 800)
			aim_offset -= 10;
		else if(dist < 600)
			aim_offset += 15;
		
		return prediction + (0, 0, height + aim_offset);
	}
	
	height = ent getplayerviewheight();
	
	return prediction + (0, 0, height);
}

bot_on_target(aim_target, radius)
{
	angles = self getplayerangles();
	
	forward = anglestoforward(angles);
	
	origin = self getplayercamerapos();
	
	len = distance(aim_target, origin);
	
	end = origin + (forward * len);
	
	if(distancesquared(aim_target, end) < (radius * radius))
	{
		return 1;
	}
	
	return 0;
}

bot_dot_product(origin)
{
	angles = self getplayerangles();
	
	forward = anglestoforward(angles);
	
	delta = origin - self getplayercamerapos();
	delta = vectornormalize(delta);
	
	dot = vectordot(forward, delta);
	
	return dot;
}

bot_patrol_near_enemy(damage, attacker, direction)
{
	if(isdefined(attacker))
	{
		self bot_lookat_entity(attacker);
	}
	
	if(!isdefined(attacker))
	{
		attacker = self bot_get_closest_enemy(self.origin);
	}
	
	if(!isdefined(attacker))
	{
		return;
	}
	
	node = bot_nearest_node(attacker.origin);
	
	if(!isdefined(node))
	{
		nodes = getnodesinradiussorted(attacker.origin, 1024, 0, 512, "path", 8);
		
		if(nodes.size)
		{
			node = nodes[0];
		}
	}
	
	if(isdefined(node))
	{
		if(isdefined(damage))
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

bot_select_weapon()
{
	if(!self isonground())
	{
		return;
	}
	
	if(self isreloading() || self isswitchingweapons() || self isthrowinggrenade())
	{
		return;
	}
	
	ent = self.bot.threat.entity;
	
	if(!isdefined(ent))
	{
		return;
	}
	
	primaries = self getweaponslistprimaries();
	
	weapon = self getcurrentweapon();
	
	stock = self getweaponammostock(weapon);
	
	clip = self getweaponammoclip(weapon);
	
	if(weapon == "none")
	{
		return;
	}
	
	if(weapon == "fhj18_mp" && !target_istarget(ent))
	{
		foreach(primary in primaries)
		{
			if(primary != weapon)
			{
				self switchtoweapon(primary);
				
				return;
			}
		}
		
		return;
	}
	
	if(!clip)
	{
		if(stock)
		{
			if(weaponhasattachment(weapon, "fastreload"))
			{
				return;
			}
		}
		
		i = 0;
		
		while(i < primaries.size)
		{
			if(primaries[i] == weapon || primaries[i] == "fhj18_mp")
			{
				i++;
				continue;
			}
			
			if(self getweaponammoclip(primaries[i]))
			{
				self switchtoweapon(primaries[i]);
				
				return;
			}
			i++;
		}
		
		if(self bot_has_lmg())
		{
			i = 0;
			
			while(i < primaries.size)
			{
				if(primaries[i] == weapon || primaries[i] == "fhj18_mp")
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

bot_has_weapon_class(class)
{
	if(self isreloading())
	{
		return 0;
	}
	
	weapon = self getcurrentweapon();
	
	if(weapon == "none")
	{
		return 0;
	}
	
	if(weaponclass(weapon) == class)
	{
		return 1;
	}
	
	return 0;
}

bot_has_lmg()
{
	if(bot_has_weapon_class("mg"))
	{
		return 1;
	}
	
	return 0;
}

bot_has_ballistic_knife()
{
    weapon = self getcurrentweapon();

    if(issubstr(weapon, "ballistic"))
        return true;

    return false;
}

bot_weapon_ammo_frac()
{
	if(self isreloading() || self isswitchingweapons())
	{
		return 0;
	}
	
	weapon = self getcurrentweapon();
	
	if(weapon == "none")
	{
		return 1;
	}
	
	total = weaponclipsize(weapon);
	
	if(total <= 0)
	{
		return 1;
	}
	
	current = self getweaponammoclip(weapon);
	
	return current / total;
}

bot_can_reload()
{
	weapon = self getcurrentweapon();
	
	if(weapon == "none")
	{
		return 0;
	}
	
	if(!self getweaponammostock(weapon))
	{
		return 0;
	}
	
	if(self isreloading() || self isswitchingweapons() || self isthrowinggrenade())
	{
		return 0;
	}
	
	return 1;
}

bot_can_do_combat()
{
	if(self ismantling() || self isonladder())
	{
		return 0;
	}
	
	if(is_true(self.bot.is_using_box))
	{
		return 0;
	}
	
	if(is_true(self.bot.is_reviving))
	{
		return 0;
	}
	
	if(is_true(self.bot.is_selfreviving))
	{
		return 0;
	}
	
	return 1;
}

threat_is_player()
{
	ent = self.bot.threat.entity;
	
	if(isdefined(ent) && isplayer(ent))
	{
		return 1;
	}
	
	return 0;
}

bot_has_enemy()
{
	if(isdefined(self.bot.threat.entity))
	{
		return 1;
	}
	
	return 0;
}

bot_best_enemy()
{
    enemies = get_cached_zombies(); // Use cached array
    enemies = arraysort(enemies, self.origin);
    
    i = 0;
    
    while(i < enemies.size)
    {
        if(threat_should_ignore(enemies[i]))
        {
            i++;
            continue;
        }
        
        wallshoot_range = getdvarfloatdefault("bot_wallshoot_dist", 40000);
        
        if(self botsighttracepassed(enemies[i]) || distancesquared(self.origin, enemies[i].origin) <= wallshoot_range)
        {
            self.bot.threat.entity = enemies[i];
            self.bot.threat.time_first_sight = gettime();
            self.bot.threat.time_recent_sight = gettime();
            self.bot.threat.dot = bot_dot_product(enemies[i].origin);
            self.bot.threat.position = enemies[i].origin;
            
            return 1;
        }
        
        i++;
    }
    
    return 0;
}

threat_should_ignore(entity)
{
	return 0;
}

bot_combat_dead(damage)
{
	wait 0.1;
	
	self allowattack(0);
	
	wait_endon(0.25, "damage");
	
	self bot_clear_enemy();
}

bot_clear_enemy()
{
	self clearlookat();
	
	self.bot.threat.entity = undefined;
}

threat_dead()
{
	if(self bot_has_enemy())
	{
		ent = self.bot.threat.entity;
		
		if(!isalive(ent))
		{
			return 1;
		}
		
		return 0;
	}
	
	return 0;
}