#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm;
#include maps\mp\zombies\_zm_utility;
#include maps\mp\zombies\_zm_stats;
#include maps\mp\zombies\_zm_score;
#include maps\mp\zombies\_zm_perks;
#include maps\mp\zombies\_zm_weapons;
#include maps\mp\zombies\_zm_equipment;
#include maps\mp\zombies\_zm_powerups;
#include maps\mp\zombies\_zm_blockers;
#include maps\mp\zombies\_zm_laststand;
#include maps\mp\zombies\_zm_afterlife;

#include scripts\zm\zm_bo2_bots_combat;

main()
{
	replacefunc(maps\mp\zombies\_zm_utility::track_players_intersection_tracker, ::track_players_intersection_tracker);
	
	level thread bot_train_leader_coordinator();
}

bot_train_leader_coordinator()
{
	level endon("end_game");
	
	level.bot_train_leader = undefined;
	
	for(;;)
	{
		wait 0.75;
		
		bots = [];
		
		foreach(player in get_players())
		{
			if(!isdefined(player.pers["isbot"]) || !isalive(player) || player maps\mp\zombies\_zm_laststand::player_is_in_laststand())
				continue;
			
			bots[bots.size] = player;
		}
		
		if(bots.size <= 1)
		{
			level.bot_train_leader = undefined;
			
			continue;
		}
		
		best = undefined;
		
		best_count = -1;
		
		foreach(bot in bots)
		{
			count = bot bot_count_nearby_zombies(600);
			
			if(isdefined(level.bot_train_leader) && level.bot_train_leader == bot)
				count += 2;
			
			if(count > best_count)
			{
				best_count = count;
				
				best = bot;
			}
		}
		
		if(best_count < 3)
		{
			level.bot_train_leader = undefined;
			
			continue;
		}
		
		level.bot_train_leader = best;
	}
}

bot_count_nearby_zombies(radius)
{
	zombies = get_cached_zombies();
	
	if(!isdefined(zombies))
		return 0;
	
	radius_sq = radius * radius;
	
	count = 0;
	
	foreach(zombie in zombies)
	{
		if(!isalive(zombie))
			continue;
		
		if(distancesquared(self.origin, zombie.origin) <= radius_sq)
			count++;
	}
	
	return count;
}

bot_get_zombie_cluster_center(radius)
{
	zombies = get_cached_zombies();
	
	if(!isdefined(zombies))
		return undefined;
	
	radius_sq = radius * radius;
	
	sum = (0, 0, 0);
	
	count = 0;
	
	foreach(zombie in zombies)
	{
		if(!isalive(zombie))
			continue;
		
		if(distancesquared(self.origin, zombie.origin) > radius_sq)
			continue;
		
		sum = sum + zombie.origin;
		
		count++;
	}
	
	if(count == 0)
		return undefined;
	
	return sum / count;
}

track_players_intersection_tracker()
{
    self endon("disconnect");
    self endon("death");
	
    level endon("end_game");
	
    wait 5;

    while(true)
    {
        killed_players = 0;
		
        players = get_players();

        for(i = 0; i < players.size; i++)
        {
            if(players[i] maps\mp\zombies\_zm_laststand::player_is_in_laststand() || "playing" != players[i].sessionstate)
                continue;

            for(j = 0; j < players.size; j++)
            {
                if(i == j || players[j] maps\mp\zombies\_zm_laststand::player_is_in_laststand() || "playing" != players[j].sessionstate)
                    continue;

                if(isdefined(level.player_intersection_tracker_override))
                {
                    if(players[i] [[level.player_intersection_tracker_override]](players[j]))
                        continue;
                }

                playeri_origin = players[i].origin;
				
                playerj_origin = players[j].origin;

                if(abs(playeri_origin[2] - playerj_origin[2]) > 60)
                    continue;

                distance_apart = distance2d(playeri_origin, playerj_origin);

                if(abs(distance_apart) > 18)
                    continue;

                if(getdvarint("kill_overlapping_players") == 0)
                {
                    return;
                }

                players[i] dodamage(1000, (0, 0, 0));
				
                players[j] dodamage(1000, (0, 0, 0));

                if(!killed_players)
                    players[i] playlocalsound(level.zmb_laugh_alias);

                players[i] maps\mp\zombies\_zm_stats::increment_map_cheat_stat("cheat_too_friendly");
                players[i] maps\mp\zombies\_zm_stats::increment_client_stat("cheat_too_friendly", 0);
                players[i] maps\mp\zombies\_zm_stats::increment_client_stat("cheat_total", 0);
                players[j] maps\mp\zombies\_zm_stats::increment_map_cheat_stat("cheat_too_friendly");
                players[j] maps\mp\zombies\_zm_stats::increment_client_stat("cheat_too_friendly", 0);
                players[j] maps\mp\zombies\_zm_stats::increment_client_stat("cheat_total", 0);
				
                killed_players = 1;
            }
        }

        wait 0.5;
    }
}

#define bot_action_stand "stand"
#define bot_action_crouch "crouch"
#define bot_action_prone "prone"

botaction(stance)
{
    switch(stance)
    {
        case bot_action_stand:
            self allowstand(true);
            self allowcrouch(false);
            self allowprone(false);
            break;
        
        case bot_action_crouch:
            self allowstand(false);
            self allowcrouch(true);
            self allowprone(false);
            break;
            
        case bot_action_prone:
            self allowstand(false);
            self allowcrouch(false);
            self allowprone(true);
            break;
            
        default:
            self allowstand(true);
            self allowcrouch(true);
            self allowprone(true);
            break;
    }
}

init()
{
	setdvar("kill_overlapping_players", 0);
	
	bot_set_dvars();
	
	flag_wait("initial_blackscreen_passed");
	
	if(!isdefined(level.using_bot_weapon_logic))
		level.using_bot_weapon_logic = 1;
	
	if(!isdefined(level.using_bot_revive_logic))
		level.using_bot_revive_logic = 1;
	
    if(!isdefined(level.mystery_box_teddy_locations))
        level.mystery_box_teddy_locations = [];
	
    level.box_in_use_by_bot = undefined;
	
	init_zombie_cache();
    init_vending_cache();
    init_door_cache();
    init_debris_cache();
	
	bot_amount = getdvarintdefault("zm_bots", 7);
	
	for(i = 0; i < bot_amount; i++)
		spawn_bot();
	
    foreach(player in get_players())
    {
        if(!isdefined(player.pers["isbot"]))
        {
            player thread manual_bot_teleport_monitor();
            player thread bot_command_mode_monitor();
        }
    }
}

spawn_bot()
{
	bot = addtestclient();
	
	bot waittill("spawned_player");
	
	bot thread maps\mp\zombies\_zm::spawnspectator();
	
	if(isdefined(bot))
	{
		bot.pers["isbot"] = 1;
		
		bot thread onspawn();
	}
	
	wait 1;
	
	bot [[level.spawnplayer]]();
}

onspawn()
{
	self endon("disconnect");
	
	level endon("end_game");
	
    self thread bot_cleanup_on_disconnect();
	
	while(1)
	{
		self waittill("spawned_player");
		
		self notify("bot_relife");
		
		self thread bot_spawn();
		self thread bot_set_perks();
	}
}

bot_cleanup_on_disconnect()
{
    self waittill("disconnect");
    
    if(isdefined(level.box_in_use_by_bot) && level.box_in_use_by_bot == self)
    {
        level.box_in_use_by_bot = undefined;
    }
}

bot_spawn()
{
	self bot_spawn_init();
	
	self thread bot_main();
	self thread bot_shield_sync_think();
	self thread bot_weapon_switch_think();
	self thread bot_weapon_failsafe_monitor();
}

bot_set_perks()
{
	self endon("disconnect");
	self endon("bot_relife");
	self endon("death");
	
	level endon("end_game");
	
	self.bot.is_on_survival_gamemode = (getdvar("g_gametype") == "zstandard") || (isdefined(level.scr_zm_ui_gametype_group) && level.scr_zm_ui_gametype_group == "zsurvival");
	
	wait 1;
	
	while(1)
	{
		bot_count = 0;
		
		players = get_players();
		
		foreach(player in players)
		{
			if(isdefined(player.pers["isbot"]))
				bot_count++;
		}
		
		if(self.bot.is_on_survival_gamemode || bot_count > 4)
		{
			self setnormalhealth(1500);
			self setmaxhealth(1500);
		}
		else
		{
			self setnormalhealth(3000);
			self setmaxhealth(3000);
		}
		
		self setperk("specialty_rof");
		self setperk("specialty_deadshot");
		self setperk("specialty_flakjacket");
		self setperk("specialty_unlimitedsprint");
		
		self waittill("player_revived");
	}
}

init_zombie_cache()
{
	if(!isdefined(level.zombie_cache))
	{
		level.zombie_cache = [];
		
		level.zombie_cache_time = 0;
		
		level.zombie_cache_refresh = 1000;
	}
}

get_cached_zombies()
{
	init_zombie_cache();
	
	current_time = gettime();
	
	if(current_time - level.zombie_cache_time > level.zombie_cache_refresh)
	{
		level.zombie_cache = undefined;
		
		level.zombie_cache = getaispeciesarray(level.zombie_team, "all");
		
		level.zombie_cache_time = current_time;
	}
	
	return level.zombie_cache;
}

init_vending_cache()
{
    if(!isdefined(level.vending_cache))
    {
        level.vending_cache = getentarray("zombie_vending", "targetname");
		
        level.vending_cache_time = 0;
		
        level.vending_cache_refresh = 5000;
    }
}

get_cached_vending_machines()
{
    init_vending_cache();
    
    current_time = gettime();
    
    if(current_time - level.vending_cache_time > level.vending_cache_refresh)
    {
        level.vending_cache = getentarray("zombie_vending", "targetname");
		
        level.vending_cache_time = current_time;
    }
    
    return level.vending_cache;
}

init_door_cache()
{
    if(!isdefined(level.door_cache))
    {
        level.door_cache = getentarray("zombie_door", "targetname");
		
        level.door_cache_time = 0;
		
        level.door_cache_refresh = 10000;
    }
}

get_cached_doors()
{
    init_door_cache();
    
    current_time = gettime();
    
    if(current_time - level.door_cache_time > level.door_cache_refresh)
    {
        level.door_cache = getentarray("zombie_door", "targetname");
		
        level.door_cache_time = current_time;
    }
    
    return level.door_cache;
}

init_debris_cache()
{
    if(!isdefined(level.debris_cache))
    {
        level.debris_cache = getentarray("zombie_debris", "targetname");
		
        level.debris_cache_time = 0;
		
        level.debris_cache_refresh = 10000;
    }
}

get_cached_debris()
{
    init_debris_cache();
    
    current_time = gettime();
    
    if(current_time - level.debris_cache_time > level.debris_cache_refresh)
    {
        level.debris_cache = getentarray("zombie_debris", "targetname");
		
        level.debris_cache_time = current_time;
    }
    
    return level.debris_cache;
}

bot_set_dvars()
{
	setdvar("g_playercollision", "nobody");
	setdvar("g_playerejection", "nobody");
	
	setdvar("bot_mindeathtime", "250");
	setdvar("bot_maxdeathtime", "500");
	setdvar("bot_minfiretime", "100");
	setdvar("bot_maxfiretime", "250");
	setdvar("bot_pitchup", "-5");
	setdvar("bot_pitchdown", "10");
	setdvar("bot_fov", "160");
	setdvar("bot_minadstime", "3000");
	setdvar("bot_maxadstime", "5000");
	setdvar("bot_mincrouchtime", "100");
	setdvar("bot_maxcrouchtime", "400");
	setdvar("bot_targetleadbias", "2");
	setdvar("bot_minreactiontime", "40");
	setdvar("bot_maxreactiontime", "70");
	setdvar("bot_strafechance", "1");
	setdvar("bot_minstrafetime", "3000");
	setdvar("bot_maxstrafetime", "6000");
	setdvar("scr_help_dist", "512");
	setdvar("bot_allowgrenades", "1");
	setdvar("bot_meleedist", "70");
	setdvar("bot_yawspeed", "4");
	setdvar("bot_sprintdistance", "256");
}

bot_spawn_init()
{
	if(level.script == "zm_tomb")
	{
		self switchtoweapon("c96_zm");
		self setspawnweapon("c96_zm");
	}
	
	self switchtoweapon("m1911_zm");
	self setspawnweapon("m1911_zm");
	
	time = gettime();
	
	if(!isdefined(self.bot))
	{
		self.bot = spawnstruct();
		
		self.bot.threat = spawnstruct();
	}
	
	self.bot.glass_origin = undefined;
	self.bot.ignore_entity = [];
	self.bot.previous_origin = self.origin;
	self.bot.time_ads = 0;
	self.bot.is_meleeing = undefined;
	self.bot.is_getting_shield = undefined;
	self.bot.is_throwing_grenade = undefined;
	self.bot.update_c4 = time + randomintrange(1000, 3000);
	self.bot.update_crate = time + randomintrange(1000, 3000);
	self.bot.update_crouch = time + randomintrange(1000, 3000);
	self.bot.update_failsafe = time + randomintrange(1000, 3000);
	self.bot.update_idle_lookat = time + randomintrange(1000, 3000);
	self.bot.update_killstreak = time + randomintrange(1000, 3000);
	self.bot.update_lookat = time + randomintrange(1000, 3000);
	self.bot.update_objective = time + randomintrange(1000, 3000);
	self.bot.update_objective_patrol = time + randomintrange(1000, 3000);
	self.bot.update_patrol = time + randomintrange(1000, 3000);
	self.bot.update_toss = time + randomintrange(1000, 3000);
	self.bot.update_launcher = time + randomintrange(1000, 3000);
	self.bot.update_weapon = time + randomintrange(1000, 3000);
	self.bot.think_interval = 0.1;
	self.bot.fov = -0.9396;
	self.bot.threat.entity = undefined;
	self.bot.threat.position = (0, 0, 0);
	self.bot.threat.time_first_sight = 0;
	self.bot.threat.time_recent_sight = 0;
	self.bot.threat.time_aim_interval = 0;
	self.bot.threat.time_aim_correct = 0;
	self.bot.threat.update_riotshield = 0;
}

bot_main()
{
	self endon("disconnect");
	self endon("bot_relife");
	self endon("death");
	
	level endon("end_game");

	self thread bot_wakeup_think();
	self thread bot_damage_think();
	self thread bot_give_ammo();
	self thread bot_reset_flee_goal();
	self thread bot_update_wander();
	self thread bot_failsafe_watchdog();
	
	for(;;)
	{
		self waittill("wakeup", damage, attacker, direction);
		
		if(self isremotecontrolling())
			continue;
		
		if(isdefined(self.bot.is_using_box) && self.bot.is_using_box)
		{
			self allowattack(0);
			self pressads(0);
			
			if(self getgoal("wander") || self hasgoal("wander"))
				self cancelgoal("wander");
			
			wait 0.05;
			
			continue;
		}
		
		self bot_combat_think(damage, attacker, direction);
		self bot_update_lookat();
		self bot_stand_fix();
		
		if(is_true(level.using_bot_weapon_logic))
		{
            self bot_force_door_nearby();
			self bot_buy_wallbuy();
			self bot_pap_guns();
			self bot_buy_perks();
		}
		
		if(is_true(level.using_bot_revive_logic))
		{
			self bot_revive_teammates();
			self bot_self_revive_afterlife();
		}
		
		self bot_pickup_powerup();
		self bot_buy_box();
		
		if(!isdefined(self.bot.next_door_check) || gettime() > self.bot.next_door_check)
		{
			self.bot.next_door_check = gettime() + 800;
			
			self bot_buy_door();
			self bot_clear_debris();
		}
		
		wait 0.05;
	}
}

bot_pickup_powerup()
{
	powerups = maps\mp\zombies\_zm_powerups::get_powerups(self.origin, 1000);
	
	if(!isdefined(powerups) || powerups.size == 0)
	{
		self cancelgoal("powerup");
		
		return;
	}
	
	foreach(powerup in powerups)
	{
		if(is_true(self.bot.is_using_box) || is_true(self.bot.is_buying) || is_true(self.bot.is_reviving) || is_true(self.bot.is_selfreviving))
		{
			self cancelgoal("powerup");
			
			continue;
		}
		
		if(isdefined(powerup.powerup_name) && (powerup.powerup_name == "double_points" || powerup.powerup_name == "insta_kill"))
		{
			zombies_left = level.zombie_total > 0 || get_current_zombie_count() > 0;
			
			if(!zombies_left)
			{
				self cancelgoal("powerup");
				
				continue;
			}
		}
		
		if(isdefined(powerup.powerup_name) && powerup.powerup_name == "nuke")
		{
			zombies_left = level.zombie_total > 0 || get_current_zombie_count() > 0;
			
			if(zombies_left)
			{
				self cancelgoal("powerup");
				
				continue;
			}
		}
		
		if(getdvar("mapname") == "zm_prison" && is_in_cell_block(powerup.origin))
		{
			self cancelgoal("powerup");
			
			continue;
		}
		
		if(distancesquared(self.origin, powerup.origin) > 1000000)
		{
			self cancelgoal("powerup");
			
			continue;
		}
		
		if(!findpath(self.origin, powerup.origin, undefined, 0, 1))
		{
			self cancelgoal("powerup");
			
			continue;
		}
		
		self addgoal(powerup.origin, 25, 2, "powerup");
		
		if(self atgoal("powerup") || distancesquared(self.origin, powerup.origin) < 25)
			self cancelgoal("powerup");
		
		return;
	}
}

is_in_cell_block(origin)
{
	cell_1 = (1548.58, 10476.6, 1336.13);
	cell_2 = (1425.54, 9251.54, 1336.13);
	cell_3 = (1474.05, 9555.64, 1336.13);

	if(distance(origin, cell_1) < 100)
		return true;
	
	if(distance(origin, cell_2) < 100)
		return true;
	
	if(distance(origin, cell_3) < 100)
		return true;

	return false;
}

bot_get_weapon_score(weapon)
{
    if(!isdefined(weapon) || weapon == "none")
		return 0;
    
	if(issubstr(weapon, "metalstorm") || 
	   issubstr(weapon, "willy_pete") || 
	   issubstr(weapon, "time_bomb") || 
	   issubstr(weapon, "emp_grenade") || 
	   issubstr(weapon, "cymbal_monkey"))
	
	   return 0;
	
    if(issubstr(weapon, "ray_gun") || 
	   issubstr(weapon, "mark2") || 
	   issubstr(weapon, "freezegun") || 
	   issubstr(weapon, "tesla") || 
	   issubstr(weapon, "thunder") || 
	   issubstr(weapon, "slipgun") || 
	   issubstr(weapon, "slowgun") || 
	   issubstr(weapon, "blunder") || 
	   issubstr(weapon, "staff"))
	
	   return 100;
		
	if(issubstr(weapon, "minigun") || 
	   issubstr(weapon, "titus"))
	
	   return 99;
	
	if(issubstr(weapon, "mg08") || 
	   issubstr(weapon, "rpd") || 
	   issubstr(weapon, "hamr") || 
	   issubstr(weapon, "lsat") || 
	   issubstr(weapon, "mk48") || 
	   issubstr(weapon, "qbb95") || 
	   
	   issubstr(weapon, "ksg") || 
	   issubstr(weapon, "srm1216"))
	
	   return 95;
    
	if(issubstr(weapon, "mp44") || 
	   issubstr(weapon, "ak47") || 
	   issubstr(weapon, "galil") || 
	   issubstr(weapon, "scar") || 
	   issubstr(weapon, "an94") || 
	   issubstr(weapon, "hk416") || 
	
	   issubstr(weapon, "870mcs") || 
	   issubstr(weapon, "saiga12"))
	
	   return 90;
	
    if(issubstr(weapon, "mp40_stalker") || 
	   issubstr(weapon, "thompson") || 
	   issubstr(weapon, "ak74u_extclip") || 
	   issubstr(weapon, "uzi") || 
	   issubstr(weapon, "mp5") || 
	   issubstr(weapon, "insas") || 
	   issubstr(weapon, "pdw57") || 
	   issubstr(weapon, "mp7") || 
	   issubstr(weapon, "vector_extclip") || 
	   issubstr(weapon, "evoskorpion") || 
	   issubstr(weapon, "peacekeeper") || 
	   
	   issubstr(weapon, "fivesevendw") || 
	   issubstr(weapon, "beretta93r_extclip") || 
	   issubstr(weapon, "rnma") || 
	   issubstr(weapon, "judge"))
	   
	   return 75;
	
	if(issubstr(weapon, "ballistic") || 
	   issubstr(weapon, "m14") || 
	   issubstr(weapon, "fal") || 
	   issubstr(weapon, "rottweil72") || 
	   issubstr(weapon, "barretm82") || 
	   issubstr(weapon, "saritch") || 
	   issubstr(weapon, "ballista") || 
	   issubstr(weapon, "dsr50") || 
	   issubstr(weapon, "m32"))
	   
	   return 50;
	
    switch(weaponclass(weapon))
    {
		default:
		case "mg":
		case "spread":
			return 90;
		case "rifle":
			return 75;
		case "smg":
			return 70;
		case "rocketlauncher":
			return 60;
		case "pistol":
			return 50;
    }
}

bot_should_visit_box()
{
	weapons = self getweaponslistprimaries();
	
	if(!isdefined(weapons) || weapons.size == 0)
		return true;
	
	weapon_score = 999;
	
	all_wonder_or_top = true;
	
	foreach(weap in weapons)
	{
		s = bot_get_weapon_score(weap);
		
		if(s < weapon_score)
			weapon_score = s;
		
		if(s < 95)
			all_wonder_or_top = false;
	}
	
	if(all_wonder_or_top)
		return false;
	
	if(weapons.size < 2 || (self hasperk("specialty_additionalprimaryweapon") && weapons.size < 3))
		return weapon_score < 90;
	
	return weapon_score < 75;
}

bot_buy_box()
{
	needs_weapon_urgently = bot_get_weapon_score(self getcurrentweapon()) <= 0;
	
	box_cushion = needs_weapon_urgently ? 950 : 1200;
	
    if(self maps\mp\zombies\_zm_laststand::player_is_in_laststand() || self.score < box_cushion || !self bot_should_visit_box())
    {
        if(self getgoal("boxbuy") || self hasgoal("boxbuy"))
            self cancelgoal("boxbuy");
		
        return;
    }
	
	if(isdefined(self.bot.last_box_interaction_time) && (gettime() - self.bot.last_box_interaction_time < self.bot.box_cooldown_duration))
		return;
	
	if(isdefined(level.bot_last_team_box_use) && gettime() - level.bot_last_team_box_use < 20000)
		return;
    
    if(is_true(self.bot.waiting_for_box_animation))
    {
        if((!isdefined(self.bot.box_payment_time) || (gettime() - self.bot.box_payment_time > 10000))) 
        {
            self.bot.waiting_for_box_animation = undefined;
            self.bot.current_box = undefined;
            self.bot.is_using_box = undefined;
			
            if(level.box_in_use_by_bot == self)
				level.box_in_use_by_bot = undefined;
        }
		
        return;
    }
	
    if(!isdefined(level.chests) || level.chests.size == 0 || !isdefined(level.chest_index) || level.chest_index >= level.chests.size)
        return;
	
    if(!isdefined(level.bot_check_chest_index))
        level.bot_check_chest_index = level.chest_index;
	
    if(level.bot_check_chest_index != level.chest_index)
    {
        level.mystery_box_teddy_locations = [];
		
        level.bot_check_chest_index = level.chest_index;
    }
	
    current_box = level.chests[level.chest_index];
	
    if(!isdefined(current_box) || !isdefined(current_box.origin))
        return;
	
    if(is_true(current_box._box_open) || is_true(current_box._box_opened_by_fire_sale) || 
	   flag("moving_chest_now") || 
	  (isdefined(current_box.is_locked) && current_box.is_locked) || 
	  (isdefined(current_box.chest_user) && current_box.chest_user != self) || 
	  (isdefined(level.box_in_use_by_bot) && level.box_in_use_by_bot != self) || 
	  (isdefined(level.mystery_box_teddy_locations) && array_contains(level.mystery_box_teddy_locations, current_box.origin))) 
    {
        if(self getgoal("boxbuy") || self hasgoal("boxbuy"))
            self cancelgoal("boxbuy");
		
        return;
    }
	
    dist_sq = distancesquared(self.origin, current_box.origin);
    
	detection_dist_sq = 1000000;
	
	interaction_dist_sq = 30625;
	
    if(self.score >= 950 && dist_sq < detection_dist_sq)
    {
        if(findpath(self.origin, current_box.origin, undefined, 0, 1))
        {
			if(!findpath(self.origin, current_box.origin, undefined, 0, 1))
			{
				if(self getgoal("boxbuy") || self hasgoal("boxbuy"))
					self cancelgoal("boxbuy");
				
				return;
			}
			
			if(is_true(self.bot.is_buying) || is_true(self.bot.is_reviving) || is_true(self.bot.is_selfreviving) || is_true(self.bot.is_throwing_grenade))
			{
				if(self getgoal("boxbuy") || self hasgoal("boxbuy"))
					self cancelgoal("boxbuy");
				
				return;
			}
			
            if(dist_sq > interaction_dist_sq)
            {
                if(!self hasgoal("boxbuy") || distancesquared(self getgoal("boxbuy"), current_box.origin) > 30625)
                {
                    self addgoal(current_box.origin, 150, 2, "boxbuy");
                }
				
                return;
            }
			
            if(self hasgoal("boxbuy"))
				self cancelgoal("boxbuy");
            
            aim_offset = (randomfloatrange(-5,5), randomfloatrange(-5,5), randomfloatrange(-5,5));
			
            self lookat(current_box.origin + aim_offset);
			
            wait randomfloatrange(0.3, 0.8);
			
            if(self maps\mp\zombies\_zm_laststand::player_is_in_laststand() || self.score < 950 || 
			   is_true(current_box._box_open) || is_true(current_box._box_opened_by_fire_sale) || 
			   flag("moving_chest_now") || 
			  (isdefined(current_box.is_locked) && current_box.is_locked))
			{
				if(self getgoal("boxbuy") || self hasgoal("boxbuy"))
					self cancelgoal("boxbuy");
				
				return;
			}
			
            self.bot.current_box = current_box;
            self.bot.is_using_box = true;
			current_box.chest_user = self;
            level.box_in_use_by_bot = self;
			level.bot_last_team_box_use = gettime();
			
			self allowattack(0);
			self pressads(0);
			
			self.bot.waiting_for_box_animation = true;
			
            self.bot.box_payment_time = gettime();
			
            self maps\mp\zombies\_zm_score::minus_to_player_score();
			
            self playsound("zmb_cha_ching");
			
            if(isdefined(current_box.unitrigger_stub) && isdefined(current_box.unitrigger_stub.trigger))
                current_box.unitrigger_stub.trigger notify("trigger", self);
            else if(isdefined(current_box.use_trigger))
                current_box.use_trigger notify("trigger", self);
            else
                current_box notify("trigger", self);
			
            self thread bot_monitor_box_animation(current_box);
			
            return; 
        }
    }
	
    if(self hasgoal("boxbuy"))
        self cancelgoal("boxbuy");
}

bot_monitor_box_animation(box)
{
    self endon("disconnect");
    self endon("death");
	
	level endon("end_game");
	
    self endon("box_usage_complete");
	
    level thread bot_box_cleanup_watcher(self, box);
    
    wait 5;
    
    self.bot.waiting_for_box_animation = undefined;

    if(!isdefined(box) || self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
    {
        self.bot.current_box = undefined;
        self.bot.is_using_box = undefined;
		
        if(level.box_in_use_by_bot == self)
			level.box_in_use_by_bot = undefined;
		
        self notify("box_usage_complete");
		
        return;
    }

    if(!is_true(box._box_open))
    {
        if(!isdefined(level.mystery_box_teddy_locations))
            level.mystery_box_teddy_locations = [];
            
        if(!array_contains(level.mystery_box_teddy_locations, box.origin))
            level.mystery_box_teddy_locations[level.mystery_box_teddy_locations.size] = box.origin;
            
        self.bot.current_box = undefined;
        self.bot.is_using_box = undefined;
		
        if(level.box_in_use_by_bot == self)
			level.box_in_use_by_bot = undefined;
		
        self notify("box_usage_complete");
		
        return;
    }

	if(self getgoal("wander") || self hasgoal("wander"))
		self cancelgoal("wander");
    
    box.chest_user = self;
	
    self lookat(box.origin);
	
    wait 0.2;
    
    box_weapon = undefined;
	
    if(isdefined(box.zbarrier) && isdefined(box.zbarrier.weapon_string))
    {
        box_weapon = box.zbarrier.weapon_string;
    }
    else if(isdefined(box.weapon_string))
    {
        box_weapon = box.weapon_string;
    }

    weapons = self getweaponslistprimaries();
	
    worst_weapon = weapons[0];
	
    weapon_score = 999;
    
    if(isdefined(weapons) && weapons.size > 0)
    {
        foreach(weap in weapons)
        {
            score = bot_get_weapon_score(weap);
			
            if(score < weapon_score)
            {
                weapon_score = score;
				
                worst_weapon = weap;
            }
        }
    }

    if(isdefined(worst_weapon) && self getcurrentweapon() != worst_weapon)
    {
        self switchtoweapon(worst_weapon);
		
        wait 2;
    }

    if(bot_should_take_weapon(box_weapon, worst_weapon))
    {
        for(attempt = 0; attempt < 3; attempt++)
        {
			if(is_true(box._box_open) && !self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
            {
                if(isdefined(box.unitrigger_stub) && isdefined(box.unitrigger_stub.trigger))
                    box.unitrigger_stub.trigger notify("trigger", self);
                else if(isdefined(box.use_trigger))
                    box.use_trigger notify("trigger", self);
				else
					box notify("trigger", self);
				
                wait 0.5;
                
                if(!is_true(box._box_open))
                    break;
            }
            else
            {
                break;
            }
        }
    }
    
    if(!isdefined(box_weapon))
    {
        received_weapon = self getcurrentweapon();
        
        new_weapons = self getweaponslistprimaries();
        
        if(isdefined(new_weapons))
        {
            foreach(weap in new_weapons)
            {
                if(weap != worst_weapon && !array_contains(weapons, weap))
                {
                    received_weapon = weap;
					
                    break;
                }
            }
        }
        
        self.bot.last_box_weapon_score = bot_get_weapon_score(received_weapon);
    }
    else
    {
        self.bot.last_box_weapon_score = bot_get_weapon_score(box_weapon);
    }
    
	self.bot.last_box_interaction_time = gettime();
	
	if(level.round_number <= 8)
		self.bot.box_cooldown_duration = randomintrange(90000, 180000);
	else if(level.round_number <= 15)
		self.bot.box_cooldown_duration = randomintrange(240000, 450000);
	else
		self.bot.box_cooldown_duration = randomintrange(480000, 900000);
	
	if(isdefined(self.bot.last_box_weapon_score) && self.bot.last_box_weapon_score < 75)
		self.bot.box_cooldown_duration = int(self.bot.box_cooldown_duration / 2);
	
	self clearlookat();
	
	self.bot.current_box = undefined;
	self.bot.is_using_box = undefined;
    
    if(isdefined(box.chest_user) && box.chest_user == self)
        box.chest_user = undefined;
        
    if(level.box_in_use_by_bot == self)
        level.box_in_use_by_bot = undefined;
        
    self notify("box_usage_complete");
}

bot_box_cleanup_watcher(zm_bot, box)
{
	zm_bot endon("disconnect");
	
	level endon("end_game");
	
    zm_bot endon("box_usage_complete");
	
    zm_bot waittill("death");
	
	zm_bot.bot.waiting_for_box_animation = undefined;
	zm_bot.bot.current_box = undefined;
    zm_bot.bot.is_using_box = undefined;
	
    if(isdefined(box) && isdefined(box.chest_user) && box.chest_user == zm_bot)
        box.chest_user = undefined;
	
    if(isdefined(level.box_in_use_by_bot) && level.box_in_use_by_bot == zm_bot)
        level.box_in_use_by_bot = undefined;
}

bot_should_take_weapon(boxweapon, currentweapon)
{
	weapons = self getweaponslistprimaries();
	
    score_current = bot_get_weapon_score(currentweapon);
    
    if(score_current >= 100)
    {
        if(isdefined(boxweapon) && bot_get_weapon_score(boxweapon) >= 100)
            return true;
            
        return false;
    }
    
    if(score_current >= 90)
    {
        if(isdefined(boxweapon) && bot_get_weapon_score(boxweapon) >= 90 && self.score >= 1200)
            return true;
        
        return false;
    }

    if(!isdefined(boxweapon))
    {
        if(score_current >= 90)
            return false;
            
        return true;
    }
	
	if(isdefined(weapons))
	{
		if(self hasperk("specialty_additionalprimaryweapon") && weapons.size < 3)
		{
			if(bot_get_weapon_score(boxweapon) >= 75)
				return true;
			
			return false;
		}
		else if(weapons.size < 2)
		{
			if(bot_get_weapon_score(boxweapon) >= 50)
				return true;
			
			return false;
		}
	}
	
    score_box = bot_get_weapon_score(boxweapon);

    return score_box >= score_current;
}

bot_buy_wallbuy()
{
	self endon("disconnect");
	self endon("death");
	
	level endon("end_game");
	
    if(self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
	{
		self cancelgoal("weaponbuy");
		
		return;
	}
	
	weapon = self getcurrentweapon();
	
	upgrade_name = maps\mp\zombies\_zm_weapons::get_upgrade_weapon(weapon);
	
    if(bot_get_weapon_score(weapon) >= 75)
    {
        self cancelgoal("weaponbuy");
		
        return;
    }
	
	if(isdefined(self.bot.next_wallbuy_scan) && gettime() < self.bot.next_wallbuy_scan)
		return;
	
	self.bot.next_wallbuy_scan = gettime() + 2500;
	
	weapontobuy = undefined;
	
	if(!isdefined(level._spawned_wallbuys) || level._spawned_wallbuys.size == 0)
		return;
	
	wallbuys = array_randomize(level._spawned_wallbuys);
	
	foreach(wallbuy in wallbuys)
	{
		if(distancesquared(wallbuy.origin, self.origin) < 250000 && 
		   wallbuy.trigger_stub.cost != 500 && 
		   wallbuy.trigger_stub.cost <= self.score && 
		   bot_best_gun(wallbuy.trigger_stub.zombie_weapon_upgrade, weapon) && 
		   findpath(self.origin, wallbuy.origin, undefined, 0, 1) && 
		   weapon != wallbuy.trigger_stub.zombie_weapon_upgrade && 
		   !is_offhand_weapon(wallbuy.trigger_stub.zombie_weapon_upgrade))
		{
			if(weapon == upgrade_name)
				return;
			
			if(!isdefined(wallbuy.trigger_stub))
				return;
			
			if(!isdefined(wallbuy.trigger_stub.zombie_weapon_upgrade))
				return;
			
			if(!findpath(self.origin, wallbuy.origin, undefined, 0, 1))
			{
				self cancelgoal("weaponbuy");
				return;
			}
			
			weapontobuy = wallbuy;
			
			break;
		}
	}
	
	if(!isdefined(weapontobuy))
		return;
	
	if(isdefined(self.bot.wallbuy_nav_expiry) && gettime() < self.bot.wallbuy_nav_expiry)
		return;
	
	if(bot_get_weapon_score(weapon) >= 50)
	{
		door_reserve = bot_get_nearest_door_cost();
		
		if(isdefined(door_reserve) && self.score - weapontobuy.trigger_stub.cost < door_reserve)
			return;
	}
	
	self thread bot_navigate_and_buy_wallbuy(weapontobuy);
}

bot_get_nearest_door_cost()
{
	doors = get_cached_doors();
	
	if(!isdefined(doors))
		return undefined;
	
	best = undefined;
	
	best_dist_sq = 999999999;
	
	foreach(door in doors)
	{
		if(!isdefined(door) || !isdefined(door.origin) || !isdefined(door.zombie_cost) || door.zombie_cost <= 0)
			continue;
		
		if(isdefined(door._door_open) && door._door_open)
			continue;
		
		if(isdefined(door.has_been_opened) && door.has_been_opened)
			continue;
		
		d = distancesquared(self.origin, door.origin);
		
		if(d >= best_dist_sq)
			continue;
		
		if(!findpath(self.origin, door.origin, undefined, 0, 1))
			continue;
		
		best_dist_sq = d;
		
		best = door.zombie_cost;
	}
	
	return best;
}

bot_navigate_and_buy_wallbuy(weapontobuy)
{
	self endon("disconnect");
	self endon("death");
	
	level endon("end_game");
	
	self.bot.wallbuy_nav_expiry = gettime() + 10000;
	
	self addgoal(weapontobuy.origin, 100, 2, "weaponbuy");
	
	maxtime = gettime() + randomintrange(10000, 15000);
	
	while(!self atgoal("weaponbuy") && distancesquared(self.origin, weapontobuy.origin) > 10000)
	{
		wait 1;
		
        if(getdvar("mapname") == "zm_prison" && is_true(self.afterlife))
		{
			self cancelgoal("weaponbuy");
			
			return;
		}
		
		if(self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
		{
			self cancelgoal("weaponbuy");
			
			return;
		}
		
        if(!self isonground())
		{
			self cancelgoal("weaponbuy");
			
			return;
		}
		
		if(gettime() > maxtime)
		{
			self cancelgoal("weaponbuy");
			
			return;
		}
		
        if(is_true(self.bot.is_using_box) || is_true(self.bot.is_buying) || is_true(self.bot.is_reviving) || is_true(self.bot.is_selfreviving) || is_true(self.bot.is_throwing_grenade))
		{
			self cancelgoal("weaponbuy");
			
			return;
		}
	}
	
	self cancelgoal("weaponbuy");
	
	weapons = self getweaponslistprimaries();
	
	weapon = self getcurrentweapon();
	
	if(weapon == "none")
		return;
	
	if(!isdefined(weapontobuy.trigger_stub))
		return;
	
	if(!isdefined(weapontobuy.trigger_stub.zombie_weapon_upgrade))
		return;
	
	if(self.score < weapontobuy.trigger_stub.cost)
		return;
	
	self.bot.is_buying = true;
	
	self allowattack(0);
	self pressads(0);
	
	self maps\mp\zombies\_zm_score::minus_to_player_score(weapontobuy.trigger_stub.cost);
	
	if(isdefined(weapons))
	{
		if(self hasperk("specialty_additionalprimaryweapon") && weapons.size >= 3)
			self takeweapon(weapon);
		else if(weapons.size >= 2)
			self takeweapon(weapon);
	}
	
	self giveweapon(weapontobuy.trigger_stub.zombie_weapon_upgrade);
	self switchtoweapon(weapontobuy.trigger_stub.zombie_weapon_upgrade);
	self setspawnweapon(weapontobuy.trigger_stub.zombie_weapon_upgrade);
	
	self.bot.is_buying = undefined;
}

bot_best_gun(buyingweapon, currentweapon)
{
    if(maps\mp\zombies\_zm_weapons::get_weapon_cost(buyingweapon) > maps\mp\zombies\_zm_weapons::get_weapon_cost(currentweapon))
        return true;
        
    return false;
}

bot_pap_guns()
{
	if(level.round_number >= 10)
	{
		if(self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
			return;
		
		if(!self bot_should_pack() || self.score < 5000)
		{
			if(self getgoal("pap") || self hasgoal("pap"))
				self cancelgoal("pap");
			
			return;
		}
		
		if(is_true(self.bot.is_using_box) || is_true(self.bot.is_buying) || is_true(self.bot.is_reviving) || is_true(self.bot.is_selfreviving) || is_true(self.bot.is_throwing_grenade))
			return;
		
		if(isdefined(self.bot.next_pap_scan) && gettime() < self.bot.next_pap_scan)
			return;
		
		self.bot.next_pap_scan = gettime() + 5000;
		
		machines = get_cached_vending_machines();
		
		pack = undefined;
		
		foreach(machine in machines)
		{
			if(machine.script_noteworthy != "specialty_weapupgrade" && machine.script_noteworthy != "pack_a_punch" && !isdefined(machine.is_pap))
				continue;
			
			pack = machine;
			
			break;
		}
		
		if(!isdefined(pack) || !isdefined(pack.origin))
		{
			if(self getgoal("pap") || self hasgoal("pap"))
				self cancelgoal("pap");
			
			return;
		}
		
		weapon = self getcurrentweapon();
		
		upgrade_name = maps\mp\zombies\_zm_weapons::get_upgrade_weapon(weapon);
		
		if(issubstr(weapon, "slipgun") && !issubstr(weapon, "upgraded") && weapon == upgrade_name)
			upgrade_name = "slipgun_upgraded_zm";
		
		if(issubstr(weapon, "blunder") && !issubstr(weapon, "upgraded") && weapon == upgrade_name)
			upgrade_name = "blundergat_upgraded_zm";
		
		if(weapon == upgrade_name)
		{
			if(self getgoal("pap") || self hasgoal("pap"))
				self cancelgoal("pap");
			
			return;
		}
		
		dist_sq = distancesquared(self.origin, pack.origin);
		
		detection_dist_sq = 1000000;
		
		interaction_dist_sq = 10000;
		
		if(dist_sq >= detection_dist_sq)
		{
			if(self getgoal("pap") || self hasgoal("pap"))
				self cancelgoal("pap");
			
			return;
		}
		
		has_path = findpath(self.origin, pack.origin, undefined, 0, 1);
		
		if(!has_path)
		{
			self bot_pap_gun(weapon, upgrade_name);
			
			return;
		}
		
		if(dist_sq > interaction_dist_sq)
		{
			if(!self hasgoal("pap") || distancesquared(self getgoal("pap"), pack.origin) > 10000)
				self addgoal(pack.origin, 100, 3, "pap");
			
			return;
		}
		
		if(self hasgoal("pap"))
			self cancelgoal("pap");
		
		self lookat(pack.origin);
		
		wait randomfloatrange(0.3, 0.6);
		
		self bot_pap_gun(weapon, upgrade_name);
	}
}

bot_pap_gun(weapon, upgrade_name)
{
	self.bot.is_buying = true;
	
	self allowattack(0);
	self pressads(0);
	
	self maps\mp\zombies\_zm_score::minus_to_player_score(5000);
	
	self takeweapon(weapon);
	self giveweapon(upgrade_name, 0, self maps\mp\zombies\_zm_weapons::get_pack_a_punch_weapon_options(upgrade_name));
	self switchtoweapon(upgrade_name);
	self setspawnweapon(upgrade_name);
	
	self.bot.is_buying = undefined;
	
	self clearlookat();
}

bot_should_pack()
{
	weapon = self getcurrentweapon();

	if(maps\mp\zombies\_zm_weapons::can_upgrade_weapon(weapon))
		return 1;
	
	if(issubstr(weapon, "slipgun") && !issubstr(weapon, "upgraded"))
		return 1;
	
	if(issubstr(weapon, "blunder") && !issubstr(weapon, "upgraded"))
		return 1;
	
	return 0;
}

bot_buy_perks()
{
    if(!isdefined(self.bot.perk_purchase_time) || gettime() > self.bot.perk_purchase_time)
    {
        self.bot.perk_purchase_time = gettime() + 30000;
        
        if(self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
            return;
		
		if(level.round_number >= 8)
		{
			if(level.perk_purchase_limit == 4)
			{
				if(getdvar("mapname") == "zm_transit" || getdvar("mapname") == "zm_highrise" || getdvar("mapname") == "zm_buried")
				{
					perks = array("specialty_quickrevive", "specialty_fastreload", "specialty_rof", "specialty_longersprint", "specialty_movefaster");
					
					costs = array(1500, 3000, 2000, 2000, 2500);
				}
				else if(getdvar("mapname") == "zm_prison")
				{
					perks = array("specialty_fastreload", "specialty_rof", "specialty_grenadepulldeath", "specialty_deadshot");
					
					costs = array(3000, 2000, 2000, 1500);
				}
				else if(getdvar("mapname") == "zm_tomb")
				{
					perks = array("specialty_quickrevive", "specialty_fastreload", "specialty_longersprint", "specialty_movefaster", "specialty_additionalprimaryweapon");
					
					costs = array(1500, 3000, 2000, 2500, 4000);
				}
			}
			else
			{
				perks = array("specialty_quickrevive", "specialty_fastreload", "specialty_rof", "specialty_longersprint", "specialty_movefaster", "specialty_nomotionsensor", "specialty_deadshot", "specialty_additionalprimaryweapon", "specialty_flakjacket", "specialty_grenadepulldeath");
				
				costs = array(1500, 3000, 2000, 2000, 2500, 3000, 1500, 4000, 2000, 2000);
			}
			
			machines = get_cached_vending_machines();
			
			nearby_machines = [];
			
			foreach(machine in machines)
			{
				if(distancesquared(machine.origin, self.origin) < 1000000)
				{
					nearby_machines[nearby_machines.size] = machine;
				}
			}
			
			foreach(machine in nearby_machines)
			{
				if(!isdefined(machine.script_noteworthy))
					continue;
                
				for(i = 0; i < perks.size; i++)
				{
					if(machine.script_noteworthy == perks[i])
					{
						if(!self hasperk(perks[i]) && self.score >= costs[i])
						{
							self maps\mp\zombies\_zm_score::minus_to_player_score(costs[i]);
							
							self thread maps\mp\zombies\_zm_perks::give_perk(perks[i]);
							
							return;
						}
					}
				}
			}
		}
	}
}

bot_force_door_nearby()
{
    if(self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
        return;
    
    if(isdefined(self.bot.next_force_door_check) && gettime() < self.bot.next_force_door_check)
        return;
    
    self.bot.next_force_door_check = gettime() + 250;
    
    doors = get_cached_doors();
	
    if(!isdefined(doors))
        return;
    
    closest = undefined;
	
    closestDistSq = 160000;
    
    foreach(door in doors)
    {
        if(!isdefined(door) || !isdefined(door.origin))
            continue;
		
        if(isdefined(door._door_open) && door._door_open)
            continue;
		
        if(isdefined(door.has_been_opened) && door.has_been_opened)
            continue;
		
        if(!isdefined(door.zombie_cost) || door.zombie_cost <= 0 || self.score < door.zombie_cost)
            continue;
        
        if(isdefined(door.bot_door_claimer) && door.bot_door_claimer != self && isalive(door.bot_door_claimer))
            continue;
        
        d = distancesquared(self.origin, door.origin);
		
        if(d < closestDistSq)
        {
            closestDistSq = d;
			
            closest = door;
        }
    }
    
    if(!isdefined(closest))
        return;
    
    if(self getgoal("wander") || self hasgoal("wander"))
        self cancelgoal("wander");
	
    if(self getgoal("flee") || self hasgoal("flee"))
        self cancelgoal("flee");
    
    if(closestDistSq <= 90000)
    {
        closest.bot_door_claimer = self;
		
        closest.bot_door_claim_time = gettime();
        
        self maps\mp\zombies\_zm_score::minus_to_player_score(closest.zombie_cost);
		
        if(isdefined(closest.door_buy))
            closest thread door_buy();
        else
            closest thread maps\mp\zombies\_zm_blockers::door_opened(closest.zombie_cost);
        
        closest._door_open = 1;
		
        closest.has_been_opened = 1;
		
        closest.bot_door_claimer = undefined;
		
        self playsound("zmb_cha_ching");
    }
    else
    {
        closest.bot_door_claimer = self;
		
        closest.bot_door_claim_time = gettime();
        
        if(!self hasgoal("forced_door") || distancesquared(self getgoal("forced_door"), closest.origin) > 2500)
        {
            self cancelgoal("forced_door");
			
            self addgoal(closest.origin, 80, 1, "forced_door");
        }
    }
}

bot_buy_door()
{
    doors = get_cached_doors();
	
    if(doors.size == 0)
        return false;
    
    closestdoor = undefined;
	
    closestdistsq = 250000;
	
    foreach(door in doors)
    {
		if(self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
			continue;
		
        if(!isdefined(door))
            continue;
		
        if(!isdefined(door.origin))
            continue;
		
        if(isdefined(door._door_open) && door._door_open)
            continue;
        
        if(isdefined(door.has_been_opened) && door.has_been_opened)
            continue;
		
		if(!isdefined(door.zombie_cost) || door.zombie_cost <= 0)
			continue;
		
        if(self.score < door.zombie_cost)
            continue;
		
		if(isdefined(door.bot_door_claimer) && isdefined(door.bot_door_claimer) && door.bot_door_claimer != self)
		{
			if(!isalive(door.bot_door_claimer) || (isdefined(door.bot_door_claim_time) && gettime() - door.bot_door_claim_time > 4000))
			{
				door.bot_door_claimer = undefined;
			}
			else
			{
				continue;
			}
		}
		
        dist_sq = distancesquared(self.origin, door.origin);
		
        if(dist_sq < closestdistsq)
        {
            closestdoor = door;
			
            closestdistsq = dist_sq;
        }
    }
	
    if(isdefined(closestdoor))
    {
		closestdoor.bot_door_claimer = self;
		
		closestdoor.bot_door_claim_time = gettime();
		
		if((isdefined(closestdoor._door_open) && closestdoor._door_open) || (isdefined(closestdoor.has_been_opened) && closestdoor.has_been_opened))
		{
			closestdoor.bot_door_claimer = undefined;
			
			return false;
		}
		
        self maps\mp\zombies\_zm_score::minus_to_player_score(closestdoor.zombie_cost);
        
        closestdoor thread bot_finish_door_open();
        
        self playsound("zmb_cha_ching");
		
        return true;
    }
	
	return false;
}

bot_finish_door_open()
{
    self endon("death");
    
    if(isdefined(self.door_buy))
    {
        self door_buy();
    }
    else
    {
        self maps\mp\zombies\_zm_blockers::door_opened(self.zombie_cost);
    }
    
    self._door_open = 1;
	
    self.has_been_opened = 1;
	
	self.bot_door_claimer = undefined;
}

bot_clear_debris()
{
	if(getdvar("mapname") == "zm_buried")
		return;
	
    debris = get_cached_debris();
    
    if(debris.size == 0)
        return false;
    
    closestdebris = undefined;
	
    closestdistsq = 90000;
    
    foreach(pile in debris)
    {
		if(self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
			continue;
		
        if(!isdefined(pile))
            continue;
		
        if(!isdefined(pile.origin))
            continue;
        
        if(isdefined(pile._door_open) && pile._door_open)
            continue;
        
        if(isdefined(pile.has_been_opened) && pile.has_been_opened)
            continue;
		
		if(!isdefined(pile.zombie_cost) || pile.zombie_cost <= 0)
			continue;
        
        if(self.score < pile.zombie_cost)
            continue;
        
        dist_sq = distancesquared(self.origin, pile.origin);
		
        if(dist_sq < closestdistsq)
        {
            closestdebris = pile;
			
            closestdistsq = dist_sq;
        }
    }
    
    if(isdefined(closestdebris))
    {
        self maps\mp\zombies\_zm_score::minus_to_player_score(closestdebris.zombie_cost);
        
        closestdebris notify("trigger", self);
		
        if(isdefined(closestdebris.trigger))
            closestdebris.trigger notify("trigger", self);
        
        if(isdefined(closestdebris.target))
        {
            targets = getentarray(closestdebris.target, "targetname");
			
            foreach(target in targets)
            {
                if(isdefined(target))
                {
                    target notify("trigger", self);
                }
            }
        }
        
        if(isdefined(closestdebris.script_flag))
        {
            tokens = strtok(closestdebris.script_flag, ",");
			
            for(i = 0; i < tokens.size; i++)
            {
                flag_set(tokens[i]);
            }
        }
		
        play_sound_at_pos("purchase", closestdebris.origin);
		
		junk = getentarray(closestdebris.target, "targetname");
		
        level notify("junk purchased");
		
        foreach(chunk in junk)
        {
            chunk connectpaths();
            
            if(isdefined(chunk.script_linkto))
            {
                struct = getstruct(chunk.script_linkto, "script_linkname");
				
                if(isdefined(struct))
                {
                    chunk thread maps\mp\zombies\_zm_blockers::debris_move(struct);
                }
                else
                    chunk delete();
				
                continue;
            }
            
            chunk delete();
        }
		
        all_trigs = getentarray(closestdebris.target, "target");
		
        foreach(trig in all_trigs)
            trig delete();
        
        closestdebris._door_open = 1;
		
        closestdebris.has_been_opened = 1;
        
        return true;
    }
	
    return false;
}

bot_revive_teammates()
{
    if(!maps\mp\zombies\_zm_laststand::player_any_player_in_laststand() || self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
    {
        if(self getgoal("revive") || self hasgoal("revive"))
        {
            if(isdefined(self.bot.revive_target))
            {
                if(isdefined(self.bot.revive_target.revive_claimer_count) && self.bot.revive_target.revive_claimer_count > 0)
                    self.bot.revive_target.revive_claimer_count--;
				
                self.bot.revive_target = undefined;
            }
                
            self cancelgoal("revive");
        }
            
        self.bot.is_reviving = false;
		
        return;
    }
    
    if(is_true(self.bot.is_reviving))
        return;
    
    if(!self hasgoal("revive"))
    {
        teammate = self get_closest_downed_teammate();
        
        if(!isdefined(teammate))
            return;

        if(isdefined(self.bot.revive_claim_blocked_until) && gettime() < self.bot.revive_claim_blocked_until)
		{
			if(distancesquared(self.origin, teammate.origin) < 160000)
				self.bot.revive_claim_blocked_until = 0;
			else
	            return;
		}
		
        if(!isdefined(teammate.revive_claimer_count))
            teammate.revive_claimer_count = 0;
		
        teammate.revive_claimer_count++;
		
		teammate.revive_last_claim_time = gettime();
		
        self.bot.revive_target = teammate;
		
        self.bot.revive_last_dist = undefined;
        
        self addgoal(teammate.origin, 50, 3, "revive");
    }
    else
    {
        if(isdefined(self.bot.revive_target) && !self.bot.revive_target maps\mp\zombies\_zm_laststand::player_is_in_laststand())
        {
            if(isdefined(self.bot.revive_target.revive_claimer_count) && self.bot.revive_target.revive_claimer_count > 0)
				self.bot.revive_target.revive_claimer_count--;
			
            self.bot.revive_target = undefined;
			
            self cancelgoal("revive");
			
            return;
        }
		
		if(isdefined(self.bot.revive_target) && !is_true(self.bot.is_reviving))
		{
			real_player_reviving = isdefined(self.bot.revive_target.revivetrigger) && is_true(self.bot.revive_target.revivetrigger.beingrevived);
			
			if(is_true(self.bot.revive_target.being_revived) || real_player_reviving)
			{
				if(isdefined(self.bot.revive_target.revive_claimer_count) && self.bot.revive_target.revive_claimer_count > 0)
					self.bot.revive_target.revive_claimer_count--;
				
				self.bot.revive_target = undefined;
				
				self cancelgoal("revive");
				
				return;
			}
		}
		
        if(self atgoal("revive") || distancesquared(self.origin, self getgoal("revive")) < 5625)
        {
            teammate = self.bot.revive_target;
            
            if(!isdefined(teammate))
            {
                self cancelgoal("revive");
				
                return;
            }
			
            self thread bot_simulate_revive(teammate);
			
			return;
        }
		
		if(!isdefined(self.bot.revive_progress_check_time) || gettime() >= self.bot.revive_progress_check_time)
		{
			self.bot.revive_progress_check_time = gettime() + 2000;
			
			teammate = self.bot.revive_target;
			
			if(isdefined(teammate))
			{
				current_dist = distance(self.origin, teammate.origin);
				
				made_progress = !isdefined(self.bot.revive_last_dist) || current_dist < self.bot.revive_last_dist - 100;
				
				self.bot.revive_last_dist = current_dist;
				
				surrounded = self bot_count_nearby_zombies(200) >= 3;
				
				if(!made_progress && surrounded)
				{
					if(isdefined(teammate.revive_claimer_count) && teammate.revive_claimer_count > 0)
						teammate.revive_claimer_count--;
					
					self.bot.revive_target = undefined;
					
					self.bot.revive_last_dist = undefined;
					
					self.bot.revive_claim_blocked_until = gettime() + 3000;
					
					self cancelgoal("revive");
					
					return;
				}
			}
		}
    }
}

bot_simulate_revive(teammate)
{
    self endon("disconnect");
	self endon("death");
	
	level endon("end_game");
    
    teammate endon("disconnect");
	teammate endon("death");
    
    current_weapon = self getcurrentweapon();
    
    if(current_weapon == "none" || current_weapon == "revive_weapon_zm")
    {
        weapons = self getweaponslistprimaries();
		
        if(isdefined(weapons) && weapons.size > 0)
            current_weapon = weapons[0];
    }
    
    self.bot.is_reviving = true;
	
    teammate.being_revived = true;
    
    level thread bot_revive_cleanup_watcher(self, teammate);
    
    self cancelgoal("revive");
	
    if(self getgoal("flee") || self hasgoal("flee"))
        self cancelgoal("flee");
	
    if(self getgoal("wander") || self hasgoal("wander"))
        self cancelgoal("wander");
    
    self lookat(teammate.origin);
    
    while(teammate maps\mp\zombies\_zm_laststand::player_is_in_laststand() && !self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
    {
        self allowattack(0);
		self pressads(0);
		
        self bot_clear_enemy();
		
        if(self getgoal("flee") || self hasgoal("flee"))
            self cancelgoal("flee");
		
        if(self getgoal("wander") || self hasgoal("wander"))
            self cancelgoal("wander");
	
        if(distancesquared(self.origin, teammate.origin) > 10000)
            break;
        
        self lookat(teammate.origin);
		
        self pressusebutton(2);
		
        wait 0.05;
    }
    
    wait 0.6;
    
    if(isdefined(current_weapon) && current_weapon != "none")
        self switchtoweapon(current_weapon);
    
    teammate.being_revived = false;
	
    self.bot.is_reviving = false;
	
	self clearlookat();
}

bot_revive_cleanup_watcher(reviving_bot, teammate)
{
	level endon("end_game");
	
    while(true)
    {
        wait 0.1;
        
        if(!isdefined(reviving_bot) || !isalive(reviving_bot))
        {
            if(isdefined(teammate))
            {
                teammate.being_revived = false;
				
                if(isdefined(teammate.revive_claimer_count) && teammate.revive_claimer_count > 0)
                    teammate.revive_claimer_count--;
            }
			
            return;
        }
        
        if(!isdefined(teammate) || !teammate maps\mp\zombies\_zm_laststand::player_is_in_laststand())
        {
            if(isdefined(teammate))
            {
                teammate.being_revived = false;
				
                if(isdefined(teammate.revive_claimer_count) && teammate.revive_claimer_count > 0)
                    teammate.revive_claimer_count--;
            }
			
            return;
        }
        
        if(!is_true(reviving_bot.bot.is_reviving) && !reviving_bot hasgoal("revive"))
        {
            if(isdefined(teammate))
            {
                if(isdefined(teammate.revive_claimer_count) && teammate.revive_claimer_count > 0)
                    teammate.revive_claimer_count--;
            }
			
            return;
        }
    }
}

get_active_revive_point()
{
	if(!maps\mp\zombies\_zm_laststand::player_any_player_in_laststand())
		return undefined;

	best = undefined;
	
	best_distsq = 999999999;

	foreach(player in get_players())
	{
		if(!player maps\mp\zombies\_zm_laststand::player_is_in_laststand())
			continue;

		distsq = distancesquared(self.origin, player.origin);

		if(distsq < best_distsq)
		{
			best_distsq = distsq;
			
			best = player;
		}
	}

	return best;
}

get_closest_downed_teammate()
{
    if(!maps\mp\zombies\_zm_laststand::player_any_player_in_laststand())
        return;
    
    downed_players = [];
    
    foreach(player in get_players())
    {
        if(player maps\mp\zombies\_zm_laststand::player_is_in_laststand())
        {
            if((is_true(player.being_revived) || (isdefined(player.revivetrigger) && is_true(player.revivetrigger.beingrevived))) && self.bot.revive_target != player)
                continue;
            
            time_since_last_claim = gettime() - (isdefined(player.revive_last_claim_time) ? player.revive_last_claim_time : 0);
            
            claimer_count = isdefined(player.revive_claimer_count) ? player.revive_claimer_count : 0;
			
            if(claimer_count < 2 || self.bot.revive_target == player || time_since_last_claim > 10000)
            {
                downed_players[downed_players.size] = player;
            }
        }
    }
    
    if(downed_players.size == 0)
        return;
    
    downed_players = arraysort(downed_players, self.origin);
	
    return downed_players[0];
}

bot_self_revive_afterlife()
{
    if(!is_true(self.afterlife) || !isdefined(self.e_afterlife_corpse))
    {
        if(self getgoal("selfrevive") || self hasgoal("selfrevive"))
            self cancelgoal("selfrevive");

        self.bot.is_selfreviving = false;

        return;
    }

    if(is_true(self.bot.is_selfreviving))
        return;

    corpse = self.e_afterlife_corpse;

    if(!self hasgoal("selfrevive"))
    {
        self addgoal(corpse.origin, 50, 3, "selfrevive");
		
        return;
    }

    if(self atgoal("selfrevive") || distancesquared(self.origin, self getgoal("selfrevive")) < 5625)
    {
        self thread bot_simulate_self_revive(corpse);
    }
}

bot_simulate_self_revive(corpse)
{
    self endon("disconnect");
    self endon("death");

    level endon("end_game");

    self.bot.is_selfreviving = true;

    self cancelgoal("selfrevive");
	
    if(self getgoal("flee") || self hasgoal("flee"))
        self cancelgoal("flee");
	
    if(self getgoal("wander") || self hasgoal("wander"))
        self cancelgoal("wander");
	
    self lookat(corpse.origin);

    while(is_true(self.afterlife) && isdefined(self.e_afterlife_corpse) && self.e_afterlife_corpse == corpse)
    {
        self bot_clear_enemy();

        if(self getgoal("flee") || self hasgoal("flee"))
            self cancelgoal("flee");

        if(self getgoal("wander") || self hasgoal("wander"))
            self cancelgoal("wander");

        if(distancesquared(self.origin, corpse.origin) > 10000)
            break;

        self lookat(corpse.origin);

        self pressusebutton(2);

        wait 0.05;
    }
	
    self.bot.is_selfreviving = false;
	
    self clearlookat();
}

bot_get_hunt_target()
{
	zombies = get_cached_zombies();
	
	if(!isdefined(zombies) || zombies.size == 0)
		return undefined;
	
	alive_count = 0;
	
	foreach(zombie in zombies)
	{
		if(isalive(zombie))
			alive_count++;
	}
	
	if(alive_count == 0)
		return undefined;
	
	nearest = undefined;
	
	if(alive_count <= 3)
		nearest_dist_sq = 999999999;
	else
		nearest_dist_sq = 16000000;
	
	foreach(zombie in zombies)
	{
		if(!isalive(zombie))
			continue;
		
		d = distancesquared(self.origin, zombie.origin);
		
		if(d < nearest_dist_sq)
		{
			nearest_dist_sq = d;
			
			nearest = zombie;
		}
	}
	
	if(!isdefined(nearest))
		return undefined;
	
	if(!findpath(self.origin, nearest.origin, undefined, 0, 1))
		return undefined;
	
	return nearest.origin;
}

bot_update_wander()
{
	self endon("disconnect");
	self endon("bot_relife");
	self endon("death");
	
	level endon("end_game");
	
	for(;;)
	{
		wait 0.1;
		
		if(self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
		{
			if(self getgoal("wander") || self hasgoal("wander"))
				self cancelgoal("wander");
			
			wait 0.05;
			
			continue;
		}
		
        if(is_true(self.bot.is_using_box) || is_true(self.bot.is_buying) || is_true(self.bot.is_reviving) || is_true(self.bot.is_selfreviving))
		{
			if(self getgoal("wander") || self hasgoal("wander"))
				self cancelgoal("wander");
			
			wait 0.05;
			
			continue;
		}
		
		if(self getgoal("flee") || self hasgoal("flee"))
		{
			if(self getgoal("wander") || self hasgoal("wander"))
				self cancelgoal("wander");
			
			wait 0.05;
			
			continue;
		}
		
		if(self getgoal("boxbuy") || self hasgoal("boxbuy"))
		{
			if(self getgoal("wander") || self hasgoal("wander"))
				self cancelgoal("wander");
			
			wait 0.05;
			
			continue;
		}
		
		if(isdefined(level.bot_command_mode) && level.bot_command_mode != "wander")
		{
			if(level.bot_command_mode == "stay" && isdefined(level.bot_commander) && isalive(level.bot_commander))
			{
				if(self getgoal("wander") || self hasgoal("wander"))
					self cancelgoal("wander");
				
				wait 0.05;
				
				continue;
			}
		}
		
		downed = self get_active_revive_point();
		
		is_revive_claimer = isdefined(self.bot.revive_target) && isdefined(downed) && self.bot.revive_target == downed;
		
		if(isdefined(downed) && !is_revive_claimer)
		{
			guard_count = isdefined(downed.guard_claimer_count) ? downed.guard_claimer_count : 0;
			
			already_guarding_this = isdefined(self.bot.guard_target) && self.bot.guard_target == downed;
			
			if((guard_count < 2 || already_guarding_this) && distancesquared(self.origin, downed.origin) < 1000000)
			{
				if(!already_guarding_this)
				{
					if(isdefined(self.bot.guard_target) && isdefined(self.bot.guard_target.guard_claimer_count) && self.bot.guard_target.guard_claimer_count > 0)
						self.bot.guard_target.guard_claimer_count--;
					
					self.bot.guard_target = downed;
					
					downed.guard_claimer_count = guard_count + 1;
				}
				
				if(!isdefined(self.bot.guard_offset) || self.bot.guard_target != downed)
				{
					angle = randomfloatrange(0, 360);
					
					self.bot.guard_offset = (cos(angle) * 150, sin(angle) * 150, 0);
				}
				
				guard_spot = downed.origin + self.bot.guard_offset;
				
				if(!self hasgoal("wander") || distancesquared(self getgoal("wander"), guard_spot) > 40000)
				{
					self cancelgoal("wander");
					
					self addgoal(guard_spot, 100, 2, "wander");
				}
				
				wait 0.05;
				
				continue;
			}
		}
		else if(isdefined(self.bot.guard_target))
		{
			if(isdefined(self.bot.guard_target.guard_claimer_count) && self.bot.guard_target.guard_claimer_count > 0)
				self.bot.guard_target.guard_claimer_count--;
			
			self.bot.guard_target = undefined;
			
			self.bot.guard_offset = undefined;
		}
		
		if(!self bot_has_enemy())
		{
			if(!isdefined(self.bot.next_hunt_scan) || gettime() >= self.bot.next_hunt_scan)
			{
				self.bot.next_hunt_scan = gettime() + 750;
				
				self.bot.hunt_target = self bot_get_hunt_target();
			}
			
			if(isdefined(self.bot.hunt_target))
			{
				if(!self hasgoal("wander") || distancesquared(self getgoal("wander"), self.bot.hunt_target) > 250000)
				{
					self cancelgoal("wander");
					
					self addgoal(self.bot.hunt_target, 100, 2, "wander");
				}
				
				self.bot.is_following = false;
				
				wait 0.05;
				
				continue;
			}
		}
		
		player = undefined;
		
		foreach(candidate in get_players())
		{
			if(!isdefined(candidate) || !isdefined(candidate.origin))
				continue;
			
			if((isdefined(candidate.pers) && isdefined(candidate.pers["isbot"])) || isdefined(candidate.bot))
				continue;
			
			if(!isalive(candidate))
				continue;
			
			player = candidate;
			
			break;
		}
		
		if(isdefined(level.bot_command_mode) && level.bot_command_mode != "wander")
		{
			if(level.bot_command_mode == "follow" && isdefined(level.bot_commander) && isalive(level.bot_commander))
			{
				if(isdefined(player))
				{
					dist_sq = distancesquared(self.origin, player.origin);
					
					if(!isdefined(self.bot.follow_blocked) || gettime() >= self.bot.follow_blocked)
						self.bot.is_following = true;
					else
						self.bot.is_following = false;
					
					if(self.bot.is_following)
					{
						if(!findpath(self.origin, player.origin, undefined, 0, 1))
						{
							self.bot.is_following = false;
							
							self.bot.follow_blocked = gettime() + 5000;
						}
						else
							self.bot.is_following = true;
						
						self addgoal(player.origin, 100, 1, "wander");
						
						if(dist_sq < 22500)
						{
							self.bot.is_following = false;
							
							self cancelgoal("wander");
						}
						
						wait 0.05;
						
						continue;
					}
				}
			}
		}
		
		if(isdefined(level.bot_command_mode) && level.bot_command_mode == "wander")
		{
			if(level.bot_command_mode == "wander" && isdefined(level.bot_commander) && isalive(level.bot_commander))
			{
				if(!isdefined(self.bot.last_wander_pos))
				{
					self.bot.last_wander_pos = self.origin;
					
					self.bot.wander_stay_time = gettime();
				}
				
				if(distancesquared(self.origin, self.bot.last_wander_pos) > 256) 
				{
					self.bot.last_wander_pos = self.origin;
					
					self.bot.wander_stay_time = gettime();
				}
				
				time_at_point = (gettime() - self.bot.wander_stay_time) / 1000;
				
				if(!self hasgoal("wander") || self atgoal("wander") || time_at_point >= 2)
				{
					location = get_random_walkable_location(self.origin, 800, self);
					
					if(isdefined(location))
					{
						self cancelgoal("wander");
						
						self addgoal(location, 100, 1, "wander");
						
						self.bot.last_wander_pos = self.origin;
						
						self.bot.wander_stay_time = gettime();
					}
				}
			}
		}
	}
}

get_random_walkable_location(origin, range, player)
{
	tries = 0;
	
	min_dist_sq = (range * 0.4) * (range * 0.4);
	
	for(;;)
	{
		x = origin[0] + randomintrange(range * -1, range);
		y = origin[1] + randomintrange(range * -1, range);
		
		trace_start = (x, y, origin[2] + 500);
		
		trace_end = (x, y, origin[2] - 500);
		
		ground_trace = bullettrace(trace_start, trace_end, 0, undefined);
		
		current_min_dist_sq = min_dist_sq * (1 - (tries / 15));
		
		candidate = ground_trace["position"];
		
		if(distancesquared(origin, candidate) >= current_min_dist_sq && check_point_in_playable_area(candidate))
			return candidate;
		
		if(tries >= 15)
		{
			return origin;
		}
		
		tries ++;
		
		wait 0.05;
	}
	
	return origin;
}

manual_bot_teleport_monitor()
{
    self endon("disconnect");
	self endon("death");
	
    level endon("end_game");
    
    self notifyonplayercommand("teleport_pressed", "+actionslot 3");
    
    last_press_time = 0;
    
    for(;;)
    {
        self waittill("teleport_pressed");
        
        current_time = gettime();
        
        if(current_time - last_press_time < 500)
        {
            self execute_bot_teleport();
            
            last_press_time = 0;
			
            wait 1; 
        }
        else
        {
            last_press_time = current_time;
        }
    }
}

execute_bot_teleport()
{
    if(self isonground())
    {
        bots_to_teleport = [];
		
        players = get_players();
        
        foreach(player in players)
        {
            if(isdefined(player.bot))
                bots_to_teleport[bots_to_teleport.size] = player;
        }
        
        if(bots_to_teleport.size > 0)
        {
            offsets = [];
			
            offsets[0] = (50,   0,  0);
            offsets[1] = (-50,  0,  0);
            offsets[2] = (0,   50,  0);
            offsets[3] = (0,  -50,  0);
            
            self thread bot_staggered_teleport(bots_to_teleport, offsets);
        }
    }
    else 
    {
        self iprintln("You must be on the ground to teleport the Bots.");
    }
}

bot_staggered_teleport(bots_to_teleport, offsets)
{
	self endon("disconnect");
    self endon("death");
	
    level endon("end_game");
    
    teleported = 0;
    
    for(i = 0; i < bots_to_teleport.size; i++)
    {
        bot = bots_to_teleport[i];
        
        if(!isdefined(bot))
            continue;
        
        offset = offsets[i % offsets.size];
        
        bot setorigin(self.origin + offset);
		
        teleported++;
        
        if(i < bots_to_teleport.size - 1)
            wait randomfloatrange(0.2, 0.4);
    }
    
    if(teleported > 0)
        self iprintln("Bots teleported! (" + teleported + "/" + bots_to_teleport.size + ")");
}

bot_command_mode_monitor()
{
    self endon("disconnect");
    self endon("death");
    level endon("end_game");

    self.combo_last_use = 0;

    self notifyonplayercommand("command_pressed", "+actionslot 2");

    for(;;)
    {
        self waittill("command_pressed");

        current_time = gettime();

        if(current_time - self.combo_last_use < 1000)
            continue;

        self.combo_last_use = current_time;
		
        self bot_cycle_command_mode();
    }
}

bot_cycle_command_mode()
{
    if(!isdefined(level.bot_command_mode))
        level.bot_command_mode = "wander";

    if(level.bot_command_mode == "wander")
        level.bot_command_mode = "follow";
    else if(level.bot_command_mode == "follow")
        level.bot_command_mode = "stay";
    else
        level.bot_command_mode = "wander";

    level.bot_commander = self;

    self iprintlnbold("Bots: " + level.bot_command_mode);
}

bot_shield_sync_think()
{
	self endon("disconnect");
	self endon("death");
	
	level endon("end_game");
	
	wait randomfloatrange(2.0, 4.0);
	
	for(;;)
	{
		wait 1;
		
		has_shield_weapon = self hasweapon("riotshield_zm") || self hasweapon("alcatraz_shield_zm") || self hasweapon("tomb_shield_zm");
		
		shield_is_broken = isdefined(self.shielddamagetaken) && isdefined(level.zombie_vars["riotshield_hit_points"]) && self.shielddamagetaken >= level.zombie_vars["riotshield_hit_points"];
		
		if(has_shield_weapon && !shield_is_broken)
			continue;
		
		if(is_true(self.bot.is_getting_shield))
		{
			if(isdefined(self.bot.shield_grant_started) && (gettime() - self.bot.shield_grant_started) > 5000)
				self.bot.is_getting_shield = undefined;
			
			continue;
		}
		
		if(!bot_has_shield())
			continue;
		
		self thread bot_give_shield();
	}
}

bot_has_shield()
{
	players = get_players();
	
	foreach(player in players)
	{
		if(!isdefined(player) || isdefined(player.pers["isbot"]))
			continue;
		
		if(!isalive(player))
			continue;
		
		if(player hasweapon("riotshield_zm") || player hasweapon("alcatraz_shield_zm") || player hasweapon("tomb_shield_zm"))
			return true;
	}
	
	return false;
}

bot_give_shield()
{
	self endon("disconnect");
	self endon("death");
	
	if(is_true(self.bot.is_getting_shield))
		return;
	
	if((self hasweapon("riotshield_zm") || self hasweapon("alcatraz_shield_zm") || self hasweapon("tomb_shield_zm")) && 
	   (!isdefined(self.shielddamagetaken) || !isdefined(level.zombie_vars["riotshield_hit_points"]) || 
	    self.shielddamagetaken < level.zombie_vars["riotshield_hit_points"]))
	
	return;
	
	self.bot.is_getting_shield = true;
	
	self.bot.shield_grant_started = gettime();
	
    while(is_true(self.afterlife))
	{
		wait 0.05;
	}
	
	while(self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
	{
		wait 0.05;
	}
	
	while(!self isonground())
	{
		wait 0.05;
	}
	
	while(self isreloading() || self isswitchingweapons() || self isthrowinggrenade())
	{
		wait 0.05;
	}
	
	while(is_true(self.bot.is_using_box) || is_true(self.bot.is_buying) || is_true(self.bot.is_reviving) || is_true(self.bot.is_selfreviving) || is_true(self.bot.is_throwing_grenade) || is_true(self.bot.is_meleeing))
	{
		wait 0.05;
	}
	
	if((self hasweapon("riotshield_zm") || self hasweapon("alcatraz_shield_zm") || self hasweapon("tomb_shield_zm")) && 
	   (!isdefined(self.shielddamagetaken) || !isdefined(level.zombie_vars["riotshield_hit_points"]) || 
        self.shielddamagetaken < level.zombie_vars["riotshield_hit_points"]))
	{
		self.bot.is_getting_shield = undefined;
		
		return;
	}
	
	current_weapon = self getcurrentweapon();
	
	if(current_weapon == "none")
	{
		primaries = self getweaponslistprimaries();
		
		if(isdefined(primaries) && primaries.size > 0)
			current_weapon = primaries[0];
	}
	
	if(getdvar("mapname") == "zm_transit")
	{
		if(self hasweapon("riotshield_zm"))
			self takeweapon("riotshield_zm");
		
		self giveweapon("riotshield_zm");
		
		self.shielddamagetaken = 0;
		
		self allowattack(0);
		self pressads(0);
		
		self switchtoweapon("riotshield_zm");
		
		switch_timeout = gettime() + 1000;
		
		while(self isswitchingweapons() && gettime() < switch_timeout)
			wait 0.05;
		
		wait 0.75;
		
		if(isdefined(current_weapon) && current_weapon != "none" && current_weapon != "riotshield_zm")
		{
			self allowattack(0);
			self pressads(0);
			
			self switchtoweapon(current_weapon);
			
			switch_timeout = gettime() + 1000;
			
			while(self isswitchingweapons() && gettime() < switch_timeout)
				wait 0.05;
		}
	}
	
	if(getdvar("mapname") == "zm_prison")
	{
		if(self hasweapon("alcatraz_shield_zm"))
			self takeweapon("alcatraz_shield_zm");
		
		self giveweapon("alcatraz_shield_zm");
		
		self.shielddamagetaken = 0;
		
		self allowattack(0);
		self pressads(0);
		
		self switchtoweapon("alcatraz_shield_zm");
		
		switch_timeout = gettime() + 1000;
		
		while(self isswitchingweapons() && gettime() < switch_timeout)
			wait 0.05;
		
		wait 0.75;
		
		if(isdefined(current_weapon) && current_weapon != "none" && current_weapon != "alcatraz_shield_zm")
		{
			self allowattack(0);
			self pressads(0);
			
			self switchtoweapon(current_weapon);
			
			switch_timeout = gettime() + 1000;
			
			while(self isswitchingweapons() && gettime() < switch_timeout)
				wait 0.05;
		}
	}
	
	if(getdvar("mapname") == "zm_tomb")
	{
		if(self hasweapon("tomb_shield_zm"))
			self takeweapon("tomb_shield_zm");
		
		self giveweapon("tomb_shield_zm");
		
		self.shielddamagetaken = 0;
		
		self allowattack(0);
		self pressads(0);
		
		self switchtoweapon("tomb_shield_zm");
		
		switch_timeout = gettime() + 1000;
		
		while(self isswitchingweapons() && gettime() < switch_timeout)
			wait 0.05;
		
		wait 0.75;
		
		if(isdefined(current_weapon) && current_weapon != "none" && current_weapon != "tomb_shield_zm")
		{
			self allowattack(0);
			self pressads(0);
			
			self switchtoweapon(current_weapon);
			
			switch_timeout = gettime() + 1000;
			
			while(self isswitchingweapons() && gettime() < switch_timeout)
				wait 0.05;
		}
	}
	
	self.bot.is_getting_shield = undefined;
}

bot_weapon_switch_think()
{
    self endon("disconnect");
	self endon("bot_relife");
	self endon("death");
	
    level endon("end_game");

    wait randomfloatrange(3.0, 4.0);

    for(;;)
    {
        wait randomfloatrange(6.0, 8.0);
		
        if(getdvar("mapname") == "zm_prison" && is_true(self.afterlife))
		{
			wait 0.05;
			
			continue;
		}
		
		if(self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
		{
			wait 0.05;
			
			continue;
		}
		
        if(!self isonground())
		{
			wait 0.05;
			
			continue;
		}

        if(is_true(self.bot.is_using_box) || is_true(self.bot.is_buying) || is_true(self.bot.is_reviving) || is_true(self.bot.is_selfreviving) || is_true(self.bot.is_throwing_grenade))
		{
			wait 0.05;
			
			continue;
		}

        if(self isreloading() || self isswitchingweapons() || self isthrowinggrenade())
		{
			wait 0.05;
			
			continue;
		}

        if(isdefined(self.bot.next_weapon_switch) && gettime() < self.bot.next_weapon_switch)
            continue;

        primaries = self getweaponslistprimaries();

        if(!isdefined(primaries) || primaries.size < 2)
            continue;

        current = self getcurrentweapon();

        if(current == "none")
            continue;

        weapon = bot_switch_weapon(current, primaries);

        if(isdefined(weapon) && weapon != current)
        {
            self allowattack(0);
            self pressads(0);
			
            self switchtoweapon(weapon);
			
            self.bot.next_weapon_switch = gettime() + randomintrange(45000, 90000);
        }
    }
}

bot_switch_weapon(current_weapon, primaries)
{
    decent = [];
	
    weak = [];
    
    foreach(weapon in primaries)
    {
        if(weapon == current_weapon)
            continue;

        clip = self getweaponammoclip(weapon);
		
        stock = self getweaponammostock(weapon);
		
        if(!clip && !stock)
            continue;

        score = bot_get_weapon_score(weapon);
		
        if(score >= 50)
            decent[decent.size] = weapon;
        else
            weak[weak.size] = weapon;
    }
    
    if(decent.size > 0)
        return decent[randomint(decent.size)];
    else if(weak.size > 0)
        return weak[randomint(weak.size)];
    
    return undefined;
}

bot_weapon_failsafe_monitor()
{
    self endon("disconnect");
	self endon("bot_relife");
	self endon("death");
	
	level endon("end_game");
    
    for(;;)
    {
        wait 1;
		
        if(getdvar("mapname") == "zm_prison" && is_true(self.afterlife))
		{
			wait 0.05;
			
			continue;
		}
		
		if(self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
		{
			wait 0.05;
			
			continue;
		}
		
        if(!self isonground())
		{
			wait 0.05;
			
			continue;
		}
        
        if(is_true(self.bot.is_using_box) || is_true(self.bot.is_buying) || is_true(self.bot.is_reviving) || is_true(self.bot.is_selfreviving) || is_true(self.bot.is_throwing_grenade))
		{
			wait 0.05;
			
			continue;
		}
		
        if(self isreloading() || self isswitchingweapons() || self isthrowinggrenade())
		{
			wait 0.05;
			
			continue;
		}

        weapon = self getcurrentweapon();
		
        primaries = self getweaponslistprimaries();
        
        if(weapon == "none" || !isdefined(primaries) || primaries.size == 0)
        {
            wait 5;

            weapon = self getcurrentweapon();
			
            primaries = self getweaponslistprimaries();

            if(weapon != "none" && isdefined(primaries) && primaries.size > 0)
                continue;

            fallback_weapon = "ray_gun_zm";
            
			if(weapon != "none")
				self takeweapon(weapon);
			
			if(isdefined(primaries) && primaries.size > 0)
			{
				for(i = 0; i < primaries.size; i++)
					self takeweapon(primaries[i]);
			}
			
			self giveweapon(fallback_weapon);
			self switchtoweapon(fallback_weapon);
			self setspawnweapon(fallback_weapon);
        }
    }
}

bot_give_ammo()
{
	self endon("disconnect");
	self endon("bot_relife");
	self endon("death");
	
	level endon("end_game");
	
	for(;;)
	{
		primary_weapons = self getweaponslistprimaries();
		
		j = 0;
		
		while(j < primary_weapons.size)
		{
			self givemaxammo(primary_weapons[j]);
			
			j++;
		}
		
		wait 1;
	}
}

bot_stand_fix()
{
	if(self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
		return;
	
	if(self isonground() && (self getstance() == "crouch" || self getstance() == "prone"))
	{
		self botaction(bot_action_stand);
	}
}

array_contains(array, value)
{
	if(!isdefined(array) || !array.size)
		return false;
	
	foreach(item in array)
	{
		if(item == value)
			return true;
		
		if(distancesquared(item, value) < 100)
			return true;
	}
	
	return false;
}

bot_wakeup_think()
{
	self endon("disconnect");
	self endon("bot_relife");
	self endon("death");
	
	level endon("end_game");
	
	for(;;)
	{
		wait self.bot.think_interval;
		
		self notify("wakeup");
	}
}

bot_damage_think()
{
	self notify("bot_damage_think");
	
	self endon("bot_damage_think");
	
	self endon("bot_relife");
	
	self endon("disconnect");
	self endon("death");
	
	level endon("end_game");
	
	for(;;)
	{
		self waittill("damage", damage, attacker, direction, point, mod, unused1, unused2, unused3, weapon, flags, inflictor);
		
		self.bot.attacker = attacker;
		
		self notify("wakeup", damage, attacker, direction);
	}
}

bot_reset_flee_goal()
{
	self endon("disconnect");
	self endon("bot_relife");
	self endon("death");
	
	level endon("end_game");
	
	while(1)
	{
		self cancelgoal("flee");
		
		wait 2;
	}
}

bot_get_closest_enemy(origin)
{
	enemies = get_cached_zombies();
	enemies = arraysort(enemies, origin);
	
	if(enemies.size >= 1)
	{
		return enemies[0];
	}
	
	return undefined;
}

bot_update_lookat()
{
	path = 0;
	
	if(isdefined(self getlookaheaddir()))
	{
		path = 1;
	}
	
	if(!path && gettime() > self.bot.update_idle_lookat)
	{
		origin = bot_get_look_at();
		
		if(!isdefined(origin))
		{
			return;
		}
		
		self lookat(origin + vectorscale((0, 0, 1), 16));
		
		self.bot.update_idle_lookat = gettime() + randomintrange(1500, 3000);
	}
	else if(path && self.bot.update_idle_lookat > 0)
	{
		self clearlookat();
		
		self.bot.update_idle_lookat = 0;
	}
}

bot_get_look_at()
{
	enemy = bot_get_closest_enemy(self.origin);
	
	if(isdefined(enemy))
	{
		node = getvisiblenode(self.origin, enemy.origin);
		
		if(isdefined(node) && distancesquared(self.origin, node.origin) > 1024)
		{
			return node.origin;
		}
	}
	
	spawn = self getgoal("wander");
	
	if(isdefined(spawn))
	{
		node = getvisiblenode(self.origin, spawn);
	}
	
	if(isdefined(node) && distancesquared(self.origin, node.origin) > 1024)
	{
		return node.origin;
	}
	
	return undefined;
}

bot_failsafe_watchdog()
{
	self endon("disconnect");
	self endon("bot_relife");
	self endon("death");
	
	level endon("end_game");
	
	while(1)
	{
		wait 4;
		
		self bot_update_failsafe();
	}
}

bot_update_failsafe()
{
	time = gettime();
	
	if((time - self.spawntime) < 7500)
	{
		return;
	}
	
	if(time < self.bot.update_failsafe)
	{
		return;
	}
	
	if(!self atgoal() && distance2dsquared(self.bot.previous_origin, self.origin) < 256)
	{
		nodes = getnodesinradius(self.origin, 512, 0);
		nodes = array_randomize(nodes);
		
		if(nodes.size > 48)
		{
			capped_nodes = [];
			
			for(cap_i = 0; cap_i < 48; cap_i++)
				capped_nodes[capped_nodes.size] = nodes[cap_i];
			
			nodes = capped_nodes;
		}
		
		nearest = bot_nearest_node(self.origin);
		
		failsafe = 0;
		
		if(isdefined(nearest))
		{
			i = 0;
			
			while(i < nodes.size)
			{
				if(!bot_failsafe_node_valid(nearest, nodes[i]))
				{
					i++;
					
					continue;
				}
				else
				{
					self botsetfailsafenode(nodes[i]);
					
					wait 0.5;
					
					self.bot.update_idle_lookat = 0;
					
					self bot_update_lookat();
					
					self cancelgoal("enemy_patrol");
					
					self wait_endon(4, "goal");
					
					self botsetfailsafenode();
					
					self bot_update_lookat();
					
					failsafe = 1;
					
					break;
				}
				
				i++;
			}
		}
		else if(!failsafe && nodes.size)
		{
			node = random(nodes);
			
			self botsetfailsafenode(node);
			
			wait 0.5;
			
			self.bot.update_idle_lookat = 0;
			
			self bot_update_lookat();
			
			self cancelgoal("enemy_patrol");
			
			self wait_endon(4, "goal");
			
			self botsetfailsafenode();
			
			self bot_update_lookat();
		}
	}
	
	self.bot.update_failsafe = gettime() + 3500;
	
	self.bot.previous_origin = self.origin;
}

bot_failsafe_node_valid(nearest, node)
{
	if(isdefined(node.script_noteworthy))
	{
		return 0;
	}
	
	if((node.origin[2] - self.origin[2]) > 18)
	{
		return 0;
	}
	
	if(nearest == node)
	{
		return 0;
	}
	
	if(!nodesvisible(nearest, node))
	{
		return 0;
	}
	
	if(isdefined(level.spawn_all) && level.spawn_all.size > 0)
	{
		spawns = arraysort(level.spawn_all, node.origin);
	}
	else if(isdefined(level.spawnpoints) && level.spawnpoints.size > 0)
	{
		spawns = arraysort(level.spawnpoints, node.origin);
	}
	else if(isdefined(level.spawn_start) && level.spawn_start.size > 0)
	{
		spawns = arraycombine(level.spawn_start["allies"], level.spawn_start["axis"], 1, 0);
		spawns = arraysort(spawns, node.origin);
	}
	else
	{
		return 0;
	}
	
	goal = bot_nearest_node(spawns[0].origin);
	
	if(isdefined(goal) && findpath(node.origin, goal.origin, undefined, 0, 1))
	{
		return 1;
	}
	
	return 0;
}

bot_nearest_node(origin)
{
	node = getnearestnode(origin);
	
	if(isdefined(node))
	{
		return node;
	}
	
	nodes = getnodesinradiussorted(origin, 256, 0, 32);
	
	if(nodes.size)
	{
		return nodes[0];
	}
	
	return undefined;
}