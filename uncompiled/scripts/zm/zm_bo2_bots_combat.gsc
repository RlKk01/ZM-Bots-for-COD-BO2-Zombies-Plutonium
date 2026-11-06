#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_laststand;

#include scripts\zm\zm_bo2_bots;

bot_combat_think(damage, attacker, direction)
{
	if(is_true(self.bot.is_getting_shield) || is_true(self.bot.is_throwing_grenade))
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
	
	follow_mode = isdefined(level.bot_command_mode) && level.bot_command_mode == "follow" && isdefined(level.bot_commander);
	
	if(follow_mode && (self getgoal("flee") || self hasgoal("flee")))
		self cancelgoal("flee");
	
	if(!follow_mode && (isdefined(self.bot.threat.entity) && distancesquared(self.origin, self.bot.threat.position) <= 5625 || isdefined(damage)) && !self hasgoal("flee") && !is_true(self.bot.is_buying) && !self hasgoal("boxbuy") && !is_true(self.bot.is_using_box) && !self hasgoal("revive") && !is_true(self.bot.is_reviving) && !self hasgoal("selfrevive") && !is_true(self.bot.is_selfreviving))
	{
        if(!isdefined(self.bot.next_flee_scan) || gettime() > self.bot.next_flee_scan)
        {
            if(get_players().size > 4)
                self.bot.next_flee_scan = gettime() + 3000;
            else
                self.bot.next_flee_scan = gettime() + 1500;

            self bot_flee_goal();
        }
	}
	
	if(self getcurrentweapon() == "none")
		return;
	
	sight = self bot_best_enemy();
	
	if(!sight && !self bot_has_enemy())
	{
		self allowattack(0);
		self pressads(0);
		
		return;
	}
	
	if(!isdefined(self.bot.threat.entity))
		return;
	
	if(threat_dead())
	{
		self bot_combat_dead();
		
		return;
	}
	
	self bot_combat_main();
}

bot_get_flee_goal(max_dist)
{
    candidate = [];

    zombies = get_cached_zombies();

    if(!isdefined(zombies))
        return candidate;

    max_dist_sq = max_dist * max_dist;

    foreach(zombie in zombies)
    {
        if(!isdefined(zombie) || !isalive(zombie))
            continue;

        if(distancesquared(self.origin, zombie.origin) > max_dist_sq)
            continue;

        candidate[candidate.size] = zombie;
    }

    return candidate;
}

bot_flee_goal()
{
    nearest = bot_nearest_node(self.origin);

    if(!isdefined(nearest))
        return;

    nodes = getnodesinradiussorted(self.origin, 1024, 640, 512);

    if(!isdefined(nodes) || nodes.size == 0)
        return;

    zombies = self bot_get_flee_goal(1400);

    threat_pos = undefined;
	
    closest_sq = 99999999;

    foreach(zombie in zombies)
    {
        d = distancesquared(self.origin, zombie.origin);

        if(d < closest_sq)
        {
            closest_sq = d;
			
            threat_pos = zombie.origin;
        }
    }

    if(!isdefined(threat_pos) && isdefined(self.bot.threat.entity) && isdefined(self.bot.threat.position))
        threat_pos = self.bot.threat.position;

    threat_dir = undefined;

    if(isdefined(threat_pos) && distance2d(self.origin, threat_pos) > 1)
    {
        to_threat = (threat_pos[0] - self.origin[0], threat_pos[1] - self.origin[1], 0);

        threat_dir = vectornormalize(to_threat);
    }

    cand_nodes = [];
	
    cand_scores = [];

    checked = 0;

    foreach(node in nodes)
    {
        if(checked >= 40)
            break;

        checked++;

        if(nodesvisible(nearest, node))
            continue;

        score = self bot_score_flee_node(node, zombies, threat_dir);

        if(!isdefined(score))
            continue;

        cand_nodes[cand_nodes.size] = node;
		
        cand_scores[cand_scores.size] = score;
    }

    max_score = 400;

    path_checks = 0;

    while(path_checks < 4 && cand_nodes.size > 0)
    {
        best = 0;

        for(i = 1; i < cand_nodes.size; i++)
        {
            if(cand_scores[i] < cand_scores[best])
                best = i;
        }

        if(cand_scores[best] > max_score)
            break;

        best_node = cand_nodes[best];

        cand_scores[best] = 99999;

        path_checks++;

        if(findpath(self.origin, best_node.origin, undefined, 0, 1))
        {
            self addgoal(best_node.origin, 50, 4, "flee");

            self.bot.flee_goal_time = gettime();

            return;
        }
    }
}

bot_score_flee_node(node, zombies, threat_dir)
{
    node_dist = distance2d(self.origin, node.origin);

    if(node_dist < 1)
        return undefined;

    node_point = (node.origin[0] - self.origin[0], node.origin[1] - self.origin[1], 0);

    dir = vectornormalize(node_point);

    score = node_dist * 0.1;

    if(isdefined(threat_dir))
        score += vectordot(dir, threat_dir) * 200;

    foreach(zombie in zombies)
    {
        node_gap = distance2d(zombie.origin, node.origin);

        if(node_gap < 200)
            return undefined;

        if(node_gap < 350)
            score += (350 - node_gap) * 0.6;

        zombie_pos = (zombie.origin[0] - self.origin[0], zombie.origin[1] - self.origin[1], 0);

        along = vectordot(dir, zombie_pos);

        if(along > 0 && along < node_dist + 100)
        {
            zombie_dist = distance2d(self.origin, zombie.origin);

            lateral_sq = zombie_dist * zombie_dist - along * along;

            if(lateral_sq < 0)
                lateral_sq = 0;

            lateral = sqrt(lateral_sq);

            if(lateral < 110)
                return undefined;

            if(lateral < 250)
                score += (250 - lateral) * 0.7;
        }
    }

    return score;
}

bot_flee_goal_unsafe()
{
    goal = self getgoal("flee");

    if(!isdefined(goal))
        return false;

    goal_dist = distance2d(self.origin, goal);

    if(goal_dist < 1)
        return false;

    goal_point = (goal[0] - self.origin[0], goal[1] - self.origin[1], 0);

    dir = vectornormalize(goal_point);

    zombies = self bot_get_flee_goal(1200);

    foreach(zombie in zombies)
    {
        if(distance2d(zombie.origin, goal) < 150)
            return true;

        zombie_pos = (zombie.origin[0] - self.origin[0], zombie.origin[1] - self.origin[1], 0);

        along = vectordot(dir, zombie_pos);

        if(along > 50 && along < goal_dist)
        {
            zombie_dist = distance2d(self.origin, zombie.origin);

            lateral_sq = zombie_dist * zombie_dist - along * along;

            if(lateral_sq < 0)
                lateral_sq = 0;

            if(sqrt(lateral_sq) < 90)
                return true;
        }
    }

    return false;
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
		
		frac = (time - self.bot.threat.time_first_sight) / 50;
		frac = clamp(frac, 0, 1);
		
		if(!threat_is_player())
		{
			frac = 1;
		}
		
		self.bot.threat.aim_target = self bot_update_aim(frames);
		self.bot.threat.position = self.bot.threat.entity.origin;
		self bot_combat_lookat(self.bot.threat.aim_target, frac);
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
	
	aim_point = self.bot.threat.aim_target;
	
	if(!isdefined(aim_point))
	{
		aim_point = self.bot.threat.entity.origin;
	}
	
	if(self bot_on_target(aim_point, self bot_get_fire_radius(aim_point)))
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
	
	if(is_true(self.bot.is_buying) || is_true(self.bot.is_using_box) || is_true(self.bot.is_reviving) || is_true(self.bot.is_selfreviving))
		return false;
	
    if(self isreloading() || self isswitchingweapons() || self isthrowinggrenade())
        return false;
	
    threat = self.bot.threat.entity;
	
    if(!isdefined(threat) || !isalive(threat))
        return false;
	
    if(!isdefined(threat.health))
        return false;
	
    knife_damage = getdvarintdefault("bot_knife_kill_threshold", 150);
	
    insta_kill_on = level.zombie_vars[self.team]["zombie_powerup_insta_kill_on"];
	
    has_ballistic_knife = self bot_has_ballistic_knife();
	
	if(!insta_kill_on && !has_ballistic_knife && !is_true(threat.isscreecher) && !is_true(threat.is_avogadro) && threat.health > knife_damage)
        return false;
	
	if(is_true(threat.is_brutus) || is_true(threat.is_mechz))
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

    if(isdefined(level.round_number) && level.round_number < 2)
        return false;

    if(is_true(self.bot.is_buying) || is_true(self.bot.is_using_box) || is_true(self.bot.is_reviving) || is_true(self.bot.is_selfreviving))
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

    if(throw_dist_sq < 40000 || throw_dist_sq > 1000000)
        return false;

    required_cluster = 5;
	
    cluster_radius_sq = 600 * 600;
	
    cluster_count = 0;

    zombies = get_cached_zombies();

    foreach(zombie in zombies)
    {
        if(!isalive(zombie))
            continue;

        if(threat_should_ignore(zombie))
            continue;

        if(distancesquared(threat.origin, zombie.origin) <= cluster_radius_sq)
            cluster_count++;
    }

    return cluster_count >= required_cluster;
}

bot_combat_throw_grenade()
{
    self endon("disconnect");
    self endon("death");

    if(is_true(self.bot.is_throwing_grenade))
        return;

    self.bot.is_throwing_grenade = true;

    round_number = isdefined(level.round_number) ? level.round_number : 1;
	
    self.bot.next_grenade_throw = gettime() + randomintrange(5000, 30000) + (round_number * 500);

    target = self.bot.threat.entity;
	
    weapon = undefined;

    if(self getweaponammoclip("frag_grenade_zm") + self getweaponammostock("frag_grenade_zm") > 0)
        weapon = "frag_grenade_zm";
    else if(self getweaponammoclip("sticky_grenade_zm") + self getweaponammostock("sticky_grenade_zm") > 0)
        weapon = "sticky_grenade_zm";

    if(isdefined(weapon) && isdefined(target) && isalive(target))
    {
        if(self throwgrenade(weapon, target.origin))
        {
            end_time = gettime() + 2000;

            while(self isthrowinggrenade() && gettime() < end_time)
                wait 0.05;
        }
    }

    self.bot.is_throwing_grenade = undefined;
}

bot_should_hip_fire()
{
	weapon = self getcurrentweapon();
	
	if(weapon == "none")
	{
		return 0;
	}
	
	if(weaponisdualwield(weapon))
	{
		return 1;
	}
	
	enemy = self.bot.threat.entity;
	
	class = weaponclass(weapon);
	
	if(isplayer(enemy) && class == "spread")
	{
		return 1;
	}
	
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
	
	distsq = distancesquared(self.origin, enemy.origin);
	
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

bot_combat_lookat(origin, frac)
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

	dist = distance(self.origin, ent.origin);

	prediction = self predictposition(ent, frames);
	
	if(!threat_is_player())
	{
		centroid = ent getcentroid();
		
		height = centroid[2] - prediction[2];
		
		aim_offset = 0;
		
		if(dist < 300)
			aim_offset += 25;
		
		return prediction + (0, 0, height + aim_offset);
	}

	height = ent getplayerviewheight();
	
	return prediction + (0, 0, height);
}

bot_get_fire_radius(aim_point)
{
	dist = distance(self getplayercamerapos(), aim_point);

	radius = dist * 0.05;

	return clamp(radius, 18, 40);
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
	
	if(is_true(self.bot.is_throwing_grenade) || is_true(self.bot.is_getting_shield) || is_true(self.bot.is_grabbing_box) || is_true(self.bot.is_reviving) || is_true(self.bot.is_selfreviving))
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
	
    current = self.bot.threat.entity;
    
    current_score = undefined;
    
    best = undefined;
	
    best_score = -999999999;
	
	foreach(zombie in enemies)
    {
        if(!isdefined(zombie) || !isalive(zombie))
            continue;
		
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
		
        if(isdefined(current) && zombie == current)
            current_score = score;
        
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
	
	switch_objective = 150;
	
    if(isdefined(current_score) && best != current && (best_score - current_score) < switch_objective)
        best = current;
    
    if(!isdefined(current) || best != current)
        self.bot.threat.time_first_sight = gettime();
    
    self.bot.threat.entity = best;
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
	if(is_true(self.bot.is_getting_shield))
	{
		return 1;
	}
	
    if(is_true(entity.is_avogadro) && isdefined(entity.state))
    {
        if(entity.state == "cloud" || entity.state == "exiting" || entity.state == "phasing")
            return 1;
    }

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