#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include maps\mp\zombies\_zm_weapons;

#include scripts\zm\zm_bo2_bots;

bot_combat_think(damage, attacker, direction)
{
    self endon("disconnect");
    self endon("death");

    if (self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
    {
        self.bot.is_meleeing = undefined;
        return;
    }
    
    if (!bot_can_do_combat())
    {
        return;
    }
	
    if(self atgoal("flee"))
        self cancelgoal("flee");

    if((distancesquared(self.origin, self.bot.threat.position) <= 40000 || isdefined(damage)) && !self hasgoal("revive") && !is_true(self.bot.is_reviving))
    {
        if (!isDefined(self.bot.next_flee_scan) || getTime() > self.bot.next_flee_scan)
        {
            self.bot.next_flee_scan = getTime() + 2000;
            nodes = getnodesinradiussorted(self.origin, 1024, 256, 512);
            
            nearest = bot_nearest_node(self.origin);
            if (isDefined(nearest) && !self hasgoal("flee") && isDefined(nodes))
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
    }
    
    if(self GetCurrentWeapon() == "none")
    {
        return;
    }
    
    sight = self bot_best_enemy();
	
	if(!isdefined(self.bot.threat.entity))
    {
        return;
    }
    
    if (threat_dead())
    {
        self bot_combat_dead();
        return;
    }
	
    if (!sight && !self bot_has_enemy())
    {
        self allowattack(0);
        return;
    }
    
    self bot_combat_main();
    self bot_melee();
}

bot_combat_main() //checked partially changed to match cerberus output changed at own discretion
{
	if (is_true(self.bot.is_meleeing))
	{
		return;
	}

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

		// Fail-safe: If the clip is full, OR the physical reload was interrupted
		if (clip >= max || !self isreloading())
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

bot_melee()
{
	if (!isDefined(self.bot.next_melee_time))
		self.bot.next_melee_time = 0;

	if (GetTime() < self.bot.next_melee_time)
		return;
	
	if (is_true(self.bot.is_meleeing))
		return;
	
	melee_weapon = "knife_zm";
	enemy_health = 150;
	
	if (self HasWeapon("tazer_knuckles_zm"))
	{
		melee_weapon = "tazer_knuckles_zm";
		enemy_health = 6000;
	}
	
	else if (self HasWeapon("bowie_knife_zm"))
	{
		melee_weapon = "bowie_knife_zm";
		enemy_health = 1000;
	}
	
	needs_to_melee = false;
	enemy = undefined;
	
	nearby_count = 0;
	cached = get_cached_zombies();
	
	foreach (z in cached)
	{
		if (isDefined(z) && isAlive(z) && DistanceSquared(self.origin, z.origin) <= 40000)
			nearby_count++;
	}
	if (nearby_count > 1)
		return;
	
	if (isDefined(self.bot.threat.entity) && isAlive(self.bot.threat.entity))
	{
		enemy = self.bot.threat.entity;
		
		if (DistanceSquared(self.origin, enemy.origin) <= 4096)
		{
			if (enemy.health <= enemy_health)
			{
				needs_to_melee = true;
			}
		}
	}

	if (needs_to_melee && isDefined(enemy))
	{
		current_weapon = self GetCurrentWeapon();
		
		if (current_weapon == "none" || current_weapon == "revive_weapon_zm" || current_weapon == melee_weapon)
			return;

		self.bot.next_melee_time = GetTime() + 1500;
		
		self thread perform_bot_melee(enemy, current_weapon, melee_weapon);
	}
}

perform_bot_melee(enemy, current_weapon, melee_weapon)
{
	self endon("disconnect");
	self endon("death");
	
	self.bot.is_meleeing = true;
	
	self thread perform_bot_melee_cleanup(current_weapon);
	
	self allowattack(0);
	
	self SwitchToWeapon(melee_weapon);
	
	while(self GetCurrentWeapon() != melee_weapon)
	{
		wait 0.05;
	}
	
	wait 0.1;
	
	if(isDefined(enemy) && isAlive(enemy) && !self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
	{
		self lookat(enemy.origin + (0, 0, 40));
		
		forward = anglesToForward(self getplayerangles());
		
		self setVelocity(self getVelocity() + (forward * 150));
		
		self allowattack(1);
		
		wait 0.6; 
	}
	
	self allowattack(0);
	
	if (!self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
	{
		self SwitchToWeapon(current_weapon);
	
		while(self GetCurrentWeapon() != current_weapon)
		{
			wait 0.05;
		}
	}
	
	self.bot.is_meleeing = undefined;
	
	// Fallback: re-enable attack if enemy is still valid
	if (isDefined(self.bot.threat.entity) && isAlive(self.bot.threat.entity))
	{
		self allowattack(1);
	}
}

perform_bot_melee_cleanup(current_weapon)
{
	self endon("disconnect");
	
	self waittill("death");
	
	self.bot.is_meleeing = undefined;
	
	self allowattack(0);
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

bot_update_lookat(origin, frac) //checked matches cerberus output
{
    if (!isDefined(self.bot.threat.entity))
        return;

    self lookat(origin);
}

bot_update_aim(frames) //checked matches cerberus output
{
	ent = self.bot.threat.entity;
	
	weapon = self GetCurrentWeapon();

	if (!isDefined(ent.origin))
		return self.origin;

	distsq = distancesquared(self.origin, ent.origin);
	dist = sqrt(distsq);

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

	if (!threat_is_player())
	{
		centroid = ent getcentroid();
		height = centroid[2] - prediction[2];
		
		aim_offset = bot_get_weapon_aim_offset(weapon, dist);

		return prediction + (0, 0, height + aim_offset);
	}

	height = ent getplayerviewheight();
	return prediction + (0, 0, height);
}

// New helper function - weapon aim offset lookup
bot_get_weapon_aim_offset(weapon, dist)
{
	aim_offset = 20; // Default offset
	
	if (isSubStr(weapon, "staff") || isSubStr(weapon, "blunder") || 
		isSubStr(weapon, "slowgun") || isSubStr(weapon, "slipgun"))
	{
		aim_offset = 10;
	}
	else if (isSubStr(weapon, "srm1216") || isSubStr(weapon, "saiga12") || 
			 isSubStr(weapon, "ksg") || isSubStr(weapon, "870mcs") || 
			 isSubStr(weapon, "rottweil") || isSubStr(weapon, "judge"))
	{
		aim_offset = 15;
	}
	else if (isSubStr(weapon, "ray_gun") || isSubStr(weapon, "usrpg") || isSubStr(weapon, "m32") || weapon == "m1911_upgraded_zm")
	{
		aim_offset = 0;
	}

	// Distance correction
	if (dist >= 1200)
		aim_offset += 4;
	else if (dist >= 400)
		aim_offset += 5;

	return aim_offset;
}

bot_on_target(aim_target, radius) //checked matches cerberus output
{
	angles = self getplayerangles();
	forward = anglesToForward(angles);
	origin = self getplayercamerapos();
	len = distance(aim_target, origin);
	end = origin + (forward * len);
	
	if (distancesquared(aim_target, end) < (radius * radius))
	{
		return 1;
	}
	return 0;
}

bot_best_enemy() //checked partially changed to match cerberus output
{
	enemies = get_cached_zombies();
	
	i = 0;
	while (i < enemies.size)
	{
		if (distancesquared(self.origin, enemies[i].origin) > 4000000)
		{
			i++;
			continue;
		}
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

bot_can_do_combat() //checked matches cerberus output
{
	if (self ismantling() || self isonladder())
	{
		return 0;
	}
	
	if (is_true(self.bot.is_reviving))
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

bot_has_enemy() //checked changed at own discretion
{
	if (isDefined(self.bot.threat.entity))
	{
		return 1;
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