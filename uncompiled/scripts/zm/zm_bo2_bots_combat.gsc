#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_laststand;

#include scripts\zm\zm_bo2_bots;

bot_combat_think(damage, attacker, direction)
{
	if(is_true(self.bot.is_throwing_grenade))
		return;
	
	if(is_true(self.bot.is_getting_shield))
	{
		self allowattack(0);
		self pressads(0);
		
		return;
	}
	
	self allowattack(0);
	self pressads(0);
	
	if(!bot_can_do_combat())
		return;
	
	if(self atgoal("flee"))
		self cancelgoal("flee");
	
	self bot_update_panic_state();
	
	if(is_true(self.bot.is_panicking))
	{
		self bot_panic_evade();
	}
	else if(!self hasgoal("wander") && !self hasgoal("revive") && !is_true(self.bot.is_reviving) && !self hasgoal("selfrevive") && !is_true(self.bot.is_selfreviving))
	{
		handled = false;
		
		if(isdefined(level.bot_train_leader))
		{
			if(level.bot_train_leader == self)
				handled = self bot_leader_kite_update();
			else
				handled = self bot_maintain_kiting_formation();
		}
		
		if(!handled && (distancesquared(self.origin, self.bot.threat.position) <= 75625 || isdefined(damage)))
		{
			if(!isdefined(self.bot.next_flee_scan) || gettime() > self.bot.next_flee_scan)
			{
				if(get_players().size > 4)
					self.bot.next_flee_scan = gettime() + 3000;
				else
					self.bot.next_flee_scan = gettime() + 1500;
				
				location = get_random_walkable_location(self.origin, 3000, self);
				
				if(!self hasgoal("flee") && isdefined(location) && location != self.origin)
				{
					if(self getgoal("wander") || self hasgoal("wander"))
						self cancelgoal("wander");
					
					self addgoal(location, 1000, 4, "flee");
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
	
	time = gettime();
	
	panicking = is_true(self.bot.is_panicking);
	
	if(!panicking && !self bot_should_hip_fire() && self.bot.threat.dot > 0.96)
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
	
	frames = 4;
	
	if(time >= self.bot.threat.time_aim_correct)
	{
		self.bot.threat.time_aim_correct += self.bot.threat.time_aim_interval;
		
		frac = (time - self.bot.threat.time_first_sight) / 50;
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

		if(clip >= max || !self isreloading())
		{
			self.bot.reload_until_full = undefined;
		}
		else
		{
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

bot_leader_kite_update()
{
	nearby = self bot_count_nearby_zombies(500);
	
	if(nearby < 3)
		return false;
	
	if(isdefined(self.bot.next_kite_scan) && gettime() < self.bot.next_kite_scan)
		return self hasgoal("flee");
	
	self.bot.next_kite_scan = gettime() + 600;
	
	horde_center = self bot_get_zombie_cluster_center(500);
	
	if(!isdefined(horde_center))
		return false;
	
	to_leader = self.origin - horde_center;
	
	if(length(to_leader) < 1)
		to_leader = (1, 0, 0);
	else
		to_leader = vectornormalize(to_leader);
	
	tangent = (-to_leader[1], to_leader[0], 0);
	
	if(!isdefined(self.bot.kite_direction))
		self.bot.kite_direction = (randomint(2) == 0) ? 1 : -1;
	
	if(!isdefined(self.bot.next_kite_flip) || gettime() > self.bot.next_kite_flip)
	{
		self.bot.next_kite_flip = gettime() + randomintrange(8000, 16000);
		
		if(randomint(100) < 20)
			self.bot.kite_direction *= -1;
	}
	
	candidate = self.origin + (tangent * 220 * self.bot.kite_direction) + (to_leader * 80);
	
	location = get_random_walkable_location(candidate, 150, self);
	
	if(!isdefined(location) || !findpath(self.origin, location, undefined, 0, 1))
		return false;
	
	if(self getgoal("wander") || self hasgoal("wander"))
		self cancelgoal("wander");
	
	self cancelgoal("flee");
	
	self addgoal(location, 200, 4, "flee");
	
	return true;
}

bot_maintain_kiting_formation()
{
	leader = level.bot_train_leader;
	
	if(!isdefined(leader) || !isalive(leader))
		return false;
	
	horde_center = self bot_get_zombie_cluster_center(500);
	
	if(!isdefined(horde_center))
		return false;
	
	leader_dist = distance(leader.origin, horde_center);
	
	self_dist = distance(self.origin, horde_center);
	
	if(self_dist >= leader_dist - 50)
		return false;
	
	if(isdefined(self.bot.next_formation_scan) && gettime() < self.bot.next_formation_scan)
		return self hasgoal("flee");
	
	self.bot.next_formation_scan = gettime() + 500;
	
	away = self.origin - horde_center;
	
	if(length(away) < 1)
		away = (1, 0, 0);
	else
		away = vectornormalize(away);
	
	candidate = self.origin + (away * 200);
	
	location = get_random_walkable_location(candidate, 130, self);
	
	if(!isdefined(location) || !findpath(self.origin, location, undefined, 0, 1))
		return false;
	
	if(self getgoal("wander") || self hasgoal("wander"))
		self cancelgoal("wander");
	
	self cancelgoal("flee");
	
	self addgoal(location, 150, 2, "flee");
	
	return true;
}

bot_update_panic_state()
{
	if(!isdefined(self.health) || !isdefined(self.maxhealth) || self.maxhealth <= 0)
	{
		self.bot.is_panicking = false;
		
		return;
	}
	
	health_frac = self.health / self.maxhealth;
	
	nearby_close = self bot_count_nearby_zombies(150);
	
	surrounded = self bot_count_nearby_zombies(200) >= 4;
	
	self.bot.is_panicking = (health_frac <= 0.3 && nearby_close >= 1) || surrounded;
}

bot_panic_evade()
{
	if(isdefined(self.bot.next_panic_scan) && gettime() < self.bot.next_panic_scan)
		return self hasgoal("flee");
	
	self.bot.next_panic_scan = gettime() + 120;
	
	zombies = get_cached_zombies();
	
	if(!isdefined(zombies))
		return false;
	
	push = (0, 0, 0);
	
	found_any = false;
	
	foreach(zombie in zombies)
	{
		if(!isalive(zombie))
			continue;
		
		d_sq = distancesquared(self.origin, zombie.origin);
		
		if(d_sq > 250000)
			continue;
		
		found_any = true;
		
		away = self.origin - zombie.origin;
		
		d = sqrt(d_sq);
		
		if(d < 1)
			away = (1, 0, 0);
		else
			away = away / d;
		
		weight = 1;
		
		if(d < 150)
			weight = 3;
		else if(d < 300)
			weight = 1.5;
		
		push += away * weight;
	}
	
	if(!found_any)
		return false;
	
	if(length(push) < 0.01)
		push = (1, 0, 0);
	else
		push = vectornormalize(push);
	
	candidate = self.origin + (push * 450);
	
	location = get_random_walkable_location(candidate, 200, self);
	
	if(!isdefined(location) || !findpath(self.origin, location, undefined, 0, 1))
		return false;
	
	if(self getgoal("wander") || self hasgoal("wander"))
		self cancelgoal("wander");
	
	self cancelgoal("flee");
	
	self addgoal(location, 300, 5, "flee");
	
	return true;
}

bot_has_ballistic_knife()
{
    weapon = self getcurrentweapon();

    if(issubstr(weapon, "ballistic"))
        return true;

    return false;
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
	
	if(is_true(self.bot.is_panicking))
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

    wait 0.5;

    self.bot.is_meleeing = undefined;
}

bot_should_throw_grenade()
{
	if(self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
		return false;
	
	if(isdefined(level.round_number) && level.round_number <= 2)
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
	
	weapon = self getcurrentweapon();
	
	if(issubstr(weapon, "minigun"))
		return false;
	
    if(isdefined(self.bot.next_grenade_throw) && gettime() < self.bot.next_grenade_throw)
        return false;
	
    throw_dist_sq = distancesquared(self.origin, threat.origin);
	
    if(throw_dist_sq > 1000000)
        return false;
	
    cluster_radius_sq = 1000000;
	
    cluster_count = 0;
	
    zombies = get_cached_zombies();
	
    foreach(zombie in zombies)
    {
        if(!isalive(zombie))
            continue;
		
        if(distancesquared(threat.origin, zombie.origin) <= cluster_radius_sq)
            cluster_count++;
    }
	
	round_number = isdefined(level.round_number) ? level.round_number : 3;
	
	required_cluster = 6 + int(round_number / 5);
	
    if(cluster_count < required_cluster)
        return false;
	
	throw_chance = 35 - min(round_number, 27);
	
	if(throw_chance < 8)
		throw_chance = 8;
	
	if(randomint(100) >= throw_chance)
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
	
	round_number = isdefined(level.round_number) ? level.round_number : 1;
	
    self.bot.next_grenade_throw = gettime() + randomintrange(20000, 32000) + (round_number * 500);
	
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
	
    switch_timeout = gettime() + 1500;
	
    while(self isswitchingweapons() && gettime() < switch_timeout)
        wait 0.05;
	
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
		distcheck = 400;
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

	if(!isdefined(ent.origin))
		return self.origin;

	distsq = distancesquared(self.origin, ent.origin);
	
	dist = sqrt(distsq);

	if(dist > 1200) 
		frames = 12;
	else if(dist > 800) 
		frames = 9;
	else if(dist > 400) 
		frames = 6;
	else 
		frames = 4;

	prediction = self predictposition(ent, frames);
	
	vel = ent getvelocity();
	
	prediction += vel * 0.07;
	
	if(!threat_is_player())
	{
		centroid = ent getcentroid();
		
		height = centroid[2] - prediction[2];
		
		aim_offset = 5;

		if(dist > 800)
			aim_offset -= 5;
		else if(dist < 400)
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

bot_can_do_combat()
{
	if(self ismantling() || self isonladder())
	{
		return 0;
	}
	
	if(is_true(self.bot.is_getting_shield))
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
    enemies = get_cached_zombies();
    
    if(!isdefined(enemies) || enemies.size == 0)
    {
        self bot_expire_stale_threat();
		
        return 0;
    }
    
    wallshoot_range = getdvarfloatdefault("bot_wallshoot_dist", 200);
    
    revive_point = undefined;
    
    if(maps\mp\zombies\_zm_laststand::player_any_player_in_laststand())
        revive_point = self get_active_revive_point();
    
    best = undefined;
	
    best_score = -999999999;
    
    foreach(zombie in enemies)
    {
        if(threat_should_ignore(zombie))
            continue;
        
        dist = distance(self.origin, zombie.origin);
        
        if(!self botsighttracepassed(zombie) && dist > wallshoot_range)
            continue;
        
        score = 2000 - dist;
        
        if(dist < 100)
            score += 500;
        
        if(isdefined(revive_point))
        {
            dist_to_downed = distance(zombie.origin, revive_point.origin);
            
            if(dist_to_downed < 400)
                score += 600;
            else if(dist_to_downed < 800)
                score += 250;
        }
        
        if(score > best_score)
        {
            best_score = score;
			
            best = zombie;
        }
    }
    
    if(!isdefined(best))
    {
        self bot_expire_stale_threat();
		
        return 0;
    }
    
    self.bot.threat.entity = best;
    self.bot.threat.time_first_sight = gettime();
    self.bot.threat.time_recent_sight = gettime();
    self.bot.threat.dot = bot_dot_product(best.origin);
    self.bot.threat.position = best.origin;
    
    return 1;
}

bot_expire_stale_threat()
{
    if(!isdefined(self.bot.threat.entity))
        return;
    
    memory_window = 350;
    
    if(isdefined(self.bot.threat.time_recent_sight) && gettime() - self.bot.threat.time_recent_sight <= memory_window)
        return;
    
    self bot_clear_enemy();
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