#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include maps\mp\zombies\_zm_score;
#include maps\mp\zombies\_zm_laststand;
#include maps\mp\zombies\_zm_weapons;
#include maps\mp\zombies\_zm_blockers;
#include maps\mp\zombies\_zm_powerups;

#include scripts\zm\zm_bo2_bots_combat;

// Bot action constants
#define BOT_ACTION_STAND "stand"
#define BOT_ACTION_CROUCH "crouch"
#define BOT_ACTION_PRONE "prone"

// New function to handle bot stance actions
botaction(stance)
{
    // Handle different stance actions for the bot
    switch(stance)
    {
        case BOT_ACTION_STAND:
            self allowstand(true);
            self allowcrouch(false);
            self allowprone(false);
            break;
        
        case BOT_ACTION_CROUCH:
            self allowstand(false);
            self allowcrouch(true);
            self allowprone(false);
            break;
            
        case BOT_ACTION_PRONE:
            self allowstand(false);
            self allowcrouch(false);
            self allowprone(true);
            break;
            
        default:
            // Reset to allow all stances
            self allowstand(true);
            self allowcrouch(true);
            self allowprone(true);
            break;
    }
}

init()
{
    bot_set_skill();
    
    flag_wait("initial_blackscreen_passed");

    if(!isdefined(level.using_bot_weapon_logic))
        level.using_bot_weapon_logic = 1;
	
    if(!isdefined(level.using_bot_revive_logic))
        level.using_bot_revive_logic = 1;

    // Initialize box usage variables
    level.box_in_use_by_bot = undefined;
	
    if(!isDefined(level.door_being_opened))
        level.door_being_opened = false;
	
    if(!isDefined(level.mystery_box_teddy_locations))
        level.mystery_box_teddy_locations = [];

    // Setup bot tracking array
    if (!isdefined(level.bots))
        level.bots = [];
	
    // Initialize all caches
    init_vending_cache();
    init_door_cache();
    init_debris_cache();
	init_zombie_cache();

    bot_amount = GetDvarIntDefault("zm_bots", 0);

    for(i=0; i<bot_amount; i++)
    {
        bot_entity = spawn_bot();
		
        level.bots[level.bots.size] = bot_entity;
		
        wait 1;
    }
	
    // Thread manual teleport monitor for each real (non-bot) player
    foreach(player in get_players())
    {
        if(!isDefined(player.pers["isBot"]))
            player thread manual_bot_teleport_monitor();
    }
}

// Vending machine cache
init_vending_cache()
{
    if (!isDefined(level.vending_cache))
    {
        level.vending_cache = getEntArray("zombie_vending", "targetname");
        level.vending_cache_time = 0;
        level.vending_cache_refresh = 5000; // Refresh every 5 seconds
    }
}

get_cached_vending_machines()
{
    init_vending_cache();
    
    current_time = getTime();
    
    // Refresh cache if expired
    if (current_time - level.vending_cache_time > level.vending_cache_refresh)
    {
        level.vending_cache = getEntArray("zombie_vending", "targetname");
        level.vending_cache_time = current_time;
    }
    
    return level.vending_cache;
}

// Door cache
init_door_cache()
{
    if (!isDefined(level.door_cache))
    {
        level.door_cache = getEntArray("zombie_door", "targetname");
        level.door_cache_time = 0;
        level.door_cache_refresh = 10000; // Refresh every 10 seconds
    }
}

get_cached_doors()
{
    init_door_cache();
    
    current_time = getTime();
    
    if (current_time - level.door_cache_time > level.door_cache_refresh)
    {
        level.door_cache = getEntArray("zombie_door", "targetname");
        level.door_cache_time = current_time;
    }
    
    return level.door_cache;
}

// Debris cache
init_debris_cache()
{
    if (!isDefined(level.debris_cache))
    {
        level.debris_cache = getEntArray("zombie_debris", "targetname");
        level.debris_cache_time = 0;
        level.debris_cache_refresh = 10000; // Refresh every 10 seconds
    }
}

get_cached_debris()
{
    init_debris_cache();
    
    current_time = getTime();
    
    if (current_time - level.debris_cache_time > level.debris_cache_refresh)
    {
        level.debris_cache = getEntArray("zombie_debris", "targetname");
        level.debris_cache_time = current_time;
    }
    
    return level.debris_cache;
}

// Zombie cache
init_zombie_cache()
{
	if (!isDefined(level.zombie_cache))
	{
		level.zombie_cache = [];
		level.zombie_cache_time = 0;
		level.zombie_cache_refresh = 1000; // Refresh every 1 second
	}
}

get_cached_zombies()
{
	init_zombie_cache();
	
	current_time = getTime();
	
	// Refresh cache if expired
	if (current_time - level.zombie_cache_time > level.zombie_cache_refresh)
	{
		level.zombie_cache = undefined;
		level.zombie_cache = getaispeciesarray(level.zombie_team, "all");
		level.zombie_cache_time = current_time;
	}
	
	return level.zombie_cache;
}

bot_set_skill()
{
	setdvar("bot_MinDeathTime", "250");
	setdvar("bot_MaxDeathTime", "500");
	setdvar("bot_MinFireTime", "100");
	setdvar("bot_MaxFireTime", "250");
	setdvar("bot_PitchUp", "-5");
	setdvar("bot_PitchDown", "10");
	setdvar("bot_Fov", "160");
	setdvar("bot_MinAdsTime", "3000");
	setdvar("bot_MaxAdsTime", "5000");
	setdvar("bot_MinCrouchTime", "100");
	setdvar("bot_MaxCrouchTime", "400");
	setdvar("bot_TargetLeadBias", "2");
	setdvar("bot_MinReactionTime", "40");
	setdvar("bot_MaxReactionTime", "70");
	setdvar("bot_StrafeChance", "1");
	setdvar("bot_MinStrafeTime", "3000");
	setdvar("bot_MaxStrafeTime", "6000");
	setdvar("scr_help_dist", "512");
	setdvar("bot_AllowGrenades", "1");
	setdvar("bot_MinGrenadeTime", "1500");
	setdvar("bot_MaxGrenadeTime", "4000");
	setdvar("bot_MeleeDist", "70");
	setdvar("bot_YawSpeed", "4");
	setdvar("bot_SprintDistance", "256");
}

spawn_bot()
{
    bot = addtestclient();
    if(!isDefined(bot))
    {
        return;
    }
    
    bot waittill("spawned_player");
    
    bot thread maps\mp\zombies\_zm::spawnspectator();
    if(isDefined(bot))
    {
        bot.pers["isBot"] = 1;
        bot thread onspawn();
    }
    
    wait 1;
    
    if(isDefined(level.spawnplayer))
        bot [[level.spawnplayer]]();
}

onspawn()
{
	self endon("disconnect");
	level endon("end_game");
	
	// Clean up box usage if this bot disconnects
    self thread bot_cleanup_on_disconnect();
	
	while(1)
	{
		self waittill("spawned_player");
		self thread bot_spawn();
		self thread bot_perks();
	}
}

// New function to clean up resources when a bot disconnects
bot_cleanup_on_disconnect()
{
    self waittill("disconnect");
    
    // If this bot was using the box, clear the flag
    if(isDefined(level.box_in_use_by_bot) && level.box_in_use_by_bot == self)
    {
        level.box_in_use_by_bot = undefined;
    }
}

bot_spawn()
{
    self bot_spawn_init();
    self thread bot_main();
    self thread bot_check_player_blocking();
	self thread bot_weapon_failsafe_monitor();
}

bot_perks()
{
    self endon("disconnect");
    self endon("death");

    wait 1;
    while(1)
    {
        if(self hasPerk("specialty_armorvest"))
        {
            self SetNormalHealth(3000);
            self SetMaxHealth(3000);
        }
        else
        {
            self SetNormalHealth(1500);
            self SetMaxHealth(1500);
        }
        wait 1;
    }
}

bot_spawn_init()
{
	if(level.script == "zm_tomb")
	{
		self SwitchToWeapon("c96_zm");
		self SetSpawnWeapon("c96_zm");
	}
	self SwitchToWeapon("m1911_zm");
	self SetSpawnWeapon("m1911_zm");
	
	time = getTime();
	
	if (!isDefined(self.bot))
	{
		self.bot = spawnstruct();
		self.bot.threat = spawnstruct();
	}
	
	self.bot.powerup_check_time = 0;
    self.bot.wallbuy_check_time = 0;
	
	self.bot.glass_origin = undefined;
	self.bot.ignore_entity = [];
	self.bot.previous_origin = self.origin;
	self.bot.time_ads = 0;
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
	self endon("death");
	self endon("disconnect");
	level endon("game_ended");

	self thread bot_wakeup_think();
	self thread bot_damage_think();
	self thread bot_give_ammo();
	self thread bot_reset_flee_goal();
	self thread bot_update_wander();
	
	for (;;)
	{
		self waittill("wakeup", damage, attacker, direction);
		
		if(self isremotecontrolling())
			continue;
		
		if(isDefined(self.bot.is_using_box) && self.bot.is_using_box)
		{
			// Actively stop all shooting/aiming every tick while using the box
			self allowattack(0);
			self pressads(0);
			
			// Force stop any movement goals every frame
			if(self hasgoal("boxBuy"))
				self cancelgoal("boxBuy");

			if(self hasgoal("boxGrab"))
				self cancelgoal("boxGrab");
				
			if(self hasgoal("wander"))
				self cancelgoal("wander");
			
			wait 0.05;
			continue;
		}
		
		self bot_combat_think(damage, attacker, direction);
		self bot_update_lookat();
		self bot_stand_fix();
		
		if(is_true(level.using_bot_weapon_logic))
		{
			self bot_buy_perks();
			self bot_buy_wallbuy();
			self bot_pack_gun();
		}
		
		if(is_true(level.using_bot_revive_logic))
		{
			self bot_revive_teammates();
		}
		
		self bot_pickup_powerup(); // Added pickup powerup functionality
		self bot_buy_door();  // Added door buying functionality
		self bot_clear_debris();  // Added debris clearing functionality
		self bot_buy_box();  // Added box buying functionality
		
		wait 0.05;
	}
}

bot_buy_perks()
{
	if(level.round_number <= 5)
		return;
	
    if (!isDefined(self.bot.perk_purchase_time) || GetTime() > self.bot.perk_purchase_time)
    {
        // Only attempt to buy perks every 30 seconds
        self.bot.perk_purchase_time = GetTime() + 30000;
        
        if(self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
            return;
		
		perks = array("specialty_quickrevive", "specialty_armorvest", "specialty_fastreload", "specialty_rof", "specialty_movefaster", "specialty_nomotionsensor", "specialty_deadshot", "specialty_flakjacket", "specialty_grenadepulldeath");
		costs = array(1500, 2500, 3000, 2000, 2500, 3000, 1500, 2000, 2000);
		
        machines = get_cached_vending_machines(); // Use cached array
        nearby_machines = [];
		
        foreach(machine in machines)
        {
            if(DistanceSquared(machine.origin, self.origin) <= 999999999)
            {
                nearby_machines[nearby_machines.size] = machine;
            }
        }
		
        // Check each nearby machine
        foreach(machine in nearby_machines)
        {
            if(!isDefined(machine.script_noteworthy))
                continue;
                
            // Find matching perk
            for(i = 0; i < perks.size; i++)
            {
                if(machine.script_noteworthy == perks[i])
                {
                    // Only try to buy if we don't have it and can afford it
                    if(!self HasPerk(perks[i]) && self.score >= costs[i])
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

bot_revive_teammates()
{
    if(isDefined(self.bot.next_revive_check) && GetTime() < self.bot.next_revive_check)
        return;
        
    self.bot.next_revive_check = GetTime() + 2000;
    
    if(!maps\mp\zombies\_zm_laststand::player_any_player_in_laststand() || self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
    {
        if(self hasgoal("revive"))
        {
            // Release this bot's claim slot when it stops going for the revive
            if(isDefined(self.bot.revive_target))
            {
                if(isDefined(self.bot.revive_target.revive_claimer_count) && self.bot.revive_target.revive_claimer_count > 0)
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
		
        // CLAIM a slot for this bot (up to 2 bots can assist the same player)
        if(!isDefined(teammate.revive_claimer_count))
            teammate.revive_claimer_count = 0;
        teammate.revive_claimer_count++;
        self.bot.revive_target = teammate; 
        
        self AddGoal(teammate.origin, 50, 3, "revive");
    }
    else
    {
        // If the teammate we claimed somehow got revived or died before we got there
        if(isDefined(self.bot.revive_target) && !self.bot.revive_target maps\mp\zombies\_zm_laststand::player_is_in_laststand())
        {
             if(isDefined(self.bot.revive_target.revive_claimer_count) && self.bot.revive_target.revive_claimer_count > 0)
                 self.bot.revive_target.revive_claimer_count--;
             self.bot.revive_target = undefined;
             self cancelgoal("revive");
             return;
        }
	
        if(self AtGoal("revive") || DistanceSquared(self.origin, self GetGoal("revive")) < 5625)
        {
            teammate = self.bot.revive_target;
            
            if(!isdefined(teammate))
            {
                self cancelgoal("revive");
                return;
            }
            self thread bot_simulate_revive(teammate);
        }
    }
}

bot_simulate_revive(teammate)
{
    self endon("death");
    self endon("disconnect");
    
    teammate endon("death");
    teammate endon("disconnect");
    
    // 1. SAVE the current weapon so we can give it back later
    current_weapon = self getCurrentWeapon();
    
    if (current_weapon == "none" || current_weapon == "revive_weapon_zm")
    {
        weapons = self getweaponslistprimaries();
        if (isDefined(weapons) && weapons.size > 0)
            current_weapon = weapons[0];
    }
    
    // Lock bot and teammate state
    self.bot.is_reviving = true;
    teammate.being_revived = true;
    
    // Watcher runs on level so it won't be killed by bot/teammate endon events
    level thread bot_revive_cleanup_watcher(self, teammate);
    
    self cancelgoal("revive");
	
    if(self hasgoal("wander"))
        self cancelgoal("wander");
    
    if(self hasgoal("flee"))
        self cancelgoal("flee");
    
    self lookat(teammate.origin);
    
    while(teammate maps\mp\zombies\_zm_laststand::player_is_in_laststand() && !self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
    {
        self allowattack(0);
		self pressads(0);
		
        // Completely ignore zombies for the duration of the revive:
        // clear the tracked threat so bot_combat_think has nothing to aim at,
        // and cancel any movement goal that could pull the bot away.
		
        self bot_clear_enemy();
		
        if(self hasgoal("flee"))
            self cancelgoal("flee");
		
        if(self hasgoal("enemy_patrol"))
            self cancelgoal("enemy_patrol");
		
        if(self hasgoal("wander"))
            self cancelgoal("wander");
	
        if(DistanceSquared(self.origin, teammate.origin) > 10000)
            break;
        
        self lookat(teammate.origin);
        self pressusebutton(2); 
        wait 0.05;
    }
    
    // 2. RESTORE the weapon
    wait 0.6;
    
    if (isDefined(current_weapon) && current_weapon != "none")
        self switchtoweapon(current_weapon);
    
    // Clear flags on normal exit
    teammate.being_revived = false;
    self.bot.is_reviving = false;
}

// Runs on level so it survives bot/teammate death or disconnect.
// Clears being_revived immediately if the reviving bot dies mid-revive.
bot_revive_cleanup_watcher(reviving_bot, teammate)
{
    while(true)
    {
        wait 0.1;
        
        // If the bot is gone or dead, clear both the claim and the reviving flag
        if(!isDefined(reviving_bot) || !isAlive(reviving_bot))
        {
            if(isDefined(teammate))
            {
                teammate.being_revived = false;
                if(isDefined(teammate.revive_claimer_count) && teammate.revive_claimer_count > 0)
                    teammate.revive_claimer_count--;
            }
            return;
        }
        
        // If the teammate is gone or back up, clear everything
        if(!isDefined(teammate) || !teammate maps\mp\zombies\_zm_laststand::player_is_in_laststand())
        {
            if(isDefined(teammate))
            {
                teammate.being_revived = false;
                if(isDefined(teammate.revive_claimer_count) && teammate.revive_claimer_count > 0)
                    teammate.revive_claimer_count--;
            }
            return;
        }
        
        // If the bot finishes the revive or cancels it
        if(!is_true(reviving_bot.bot.is_reviving) && !reviving_bot hasgoal("revive"))
        {
            if(isDefined(teammate))
            {
                if(isDefined(teammate.revive_claimer_count) && teammate.revive_claimer_count > 0)
                    teammate.revive_claimer_count--;
            }
            return;
        }
    }
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
            // Allow up to 2 bots to assist the same downed player,
            // or always include a player this bot has already claimed.
            claimer_count = isDefined(player.revive_claimer_count) ? player.revive_claimer_count : 0;
            if(claimer_count < 2 || self.bot.revive_target == player)
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

bot_pickup_powerup()
{
    if (GetTime() < self.bot.powerup_check_time)
        return;
	
    self.bot.powerup_check_time = GetTime() + 2000;

	powerups = maps\mp\zombies\_zm_powerups::get_powerups(self.origin, 1000);

	if(!isDefined(powerups) || powerups.size == 0)
	{
		self CancelGoal("powerup");
		return;
	}

	foreach(powerup in powerups)
	{
        // Skip checks if the bot is currently reviving someone
        if(is_true(self.bot.is_reviving))
            continue;
		
		// Make the bot avoid picking up the nuke powerup
		if(isDefined(powerup.powerup_name) && powerup.powerup_name == "nuke")
			continue;
		
		if(getDvar("mapname") == "zm_prison" && is_in_cell_block(powerup.origin))
			continue;

		if(DistanceSquared(self.origin, powerup.origin) > 1000000)
			continue;

		if(!FindPath(self.origin, powerup.origin, undefined, 0, 1))
			continue;

		self AddGoal(powerup.origin, 25, 2, "powerup");

		if(self AtGoal("powerup") || DistanceSquared(self.origin, powerup.origin) < 2500)
			self CancelGoal("powerup");

		return;
	}
}

is_in_cell_block(origin)
{
	// Central point of the cell block
	cell_1 = (1548.58, 10476.6, 1336.13);
	cell_2 = (1425.54, 9251.54, 1336.13);
	cell_3 = (1474.05, 9555.64, 1336.13);

	if(Distance(origin, cell_1) < 100)
		return true;
	
	if(Distance(origin, cell_2) < 100)
		return true;
	
	if(Distance(origin, cell_3) < 100)
		return true;

	return false;
}

manual_bot_teleport_monitor()
{
    self endon("death");
    self endon("disconnect");
    level endon("end_game");
	
    self notifyOnPlayerCommand("teleport_bots_pressed", "+actionslot 3");
	
    while(true)
    {
        // Wait until the player presses the keybind
        self waittill("teleport_bots_pressed");
		
        // Safety check: Only teleport bots if the player is safely on the ground
        if(self IsOnGround())
        {
            // Collect all bots first
            bots_to_teleport = [];
            players = get_players();
            
            foreach(player in players)
            {
                if(isDefined(player.bot))
                    bots_to_teleport[bots_to_teleport.size] = player;
            }
            
            if(bots_to_teleport.size > 0)
            {
                // Spread offsets so bots don't stack on each other
                offsets = [];
                offsets[0] = (50,   0,  0);
                offsets[1] = (-50,  0,  0);
                offsets[2] = (0,   50,  0);
                offsets[3] = (0,  -50,  0);
                
                teleport_player = self; // Capture caller for the thread
                
                // Thread the staggered teleport so the monitor loop stays responsive
                teleport_player thread bot_staggered_teleport(bots_to_teleport, offsets);
            }
        }
        else 
        {
            self iprintln("You must be on the ground to teleport bots.");
        }
        // Small wait to prevent the script from spamming if the button is held down
        wait 0.5;
    }
}

bot_staggered_teleport(bots_to_teleport, offsets)
{
    self endon("death");
    self endon("disconnect");
    level endon("end_game");
    
    teleported = 0;
    
    for(i = 0; i < bots_to_teleport.size; i++)
    {
        bot = bots_to_teleport[i];
        
        if(!isDefined(bot))
            continue;
        
        // Pick the offset for this bot, cycling back if more bots than offsets
        offset = offsets[i % offsets.size];
        
        bot SetOrigin(self.origin + offset);
        teleported++;
        
        // Cooldown between each bot teleport (skip wait after the last one)
        if(i < bots_to_teleport.size - 1)
            wait randomfloatrange(1.0, 1.2);
    }
    
    if(teleported > 0)
        self iprintln("Bots Teleported! (" + teleported + "/" + bots_to_teleport.size + ")");
}

bot_stand_fix()
{
	self endon("death");
	self endon("disconnect");
	level endon("end_game");
	
	if (self isonground() && (self getstance() == "crouch" || self getstance() == "prone"))
	{
		self botaction(BOT_ACTION_STAND);
	}
}

bot_check_player_blocking()
{
    self endon("death");
    self endon("disconnect");
    level endon("game_ended");
    
    while(1)
    {
        wait randomfloatrange(0.8, 1.5);
        
        // Skip checks if bot is in last stand
        if(self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
            continue;
		
        // Skip checks if the bot is currently reviving someone
        // This ensures they stay perfectly still during the revive process
        if(is_true(self.bot.is_reviving))
            continue;
        
        foreach(player in get_players())
        {
            if(player == self || !isPlayer(player) || player maps\mp\zombies\_zm_laststand::player_is_in_laststand())
				continue;
                
            // Check if bot is too close to player and potentially blocking
            distance_sq = DistanceSquared(self.origin, player.origin);
            if(distance_sq < 1600) // Square of 40
            {
                // Calculate direction to move away from player
                dir = VectorNormalize(self.origin - player.origin);
                
                // Try different ways to move the bot away safely
                // Method 1: Use AddGoal to navigate properly
                if(!self hasgoal("avoid_player"))
                {
                    // Try to find a valid position in the direction away from player
                    try_pos = self.origin + (dir * 60);
                    
                    // Check for valid path to new position
                    if(FindPath(self.origin, try_pos, undefined, 0, 1))
                    {
                        self AddGoal(try_pos, 20, 2, "avoid_player"); // Higher priority
                        wait 0.5; // Give bot time to start moving
                        continue;
                    }
                    
                    // Method 2: Look for nearby node if direct movement failed
                    nearest_node = GetNearestNode(self.origin);
                    if(isDefined(nearest_node))
                    {
                        // Try to find nodes away from the player
                        nodes = GetNodesInRadius(self.origin, 200, 0);
                        best_node = undefined;
                        best_dist_sq = 0;
                        
                        if(isDefined(nodes) && nodes.size > 0)
                        {
                            foreach(node in nodes)
                            {
                                // Calculate which node is furthest from player but still reachable
                                if(NodeVisible(nearest_node.origin, node.origin))
                                {
                                    node_to_player_dist_sq = DistanceSquared(node.origin, player.origin);
                                    if(node_to_player_dist_sq > best_dist_sq)
                                    {
                                        best_node = node;
                                        best_dist_sq = node_to_player_dist_sq;
                                    }
                                }
                            }
                            
                            // If we found a good node, move there
                            if(isDefined(best_node))
                            {
                                self AddGoal(best_node.origin, 20, 2, "avoid_player");
                                wait 0.5; // Give bot time to start moving
                                continue;
                            }
                        }
                    }
                    
                    // Method 3 (fallback): Small teleport as last resort, but only if on ground
                    if(self IsOnGround())
                    {
                        // Verify new position is valid before moving
                        new_pos = self.origin + (dir * 50);
                        
                        // Do trace checks to make sure we're not teleporting into walls
                        if(!SightTracePassed(new_pos, new_pos + (0, 0, 30), true, self) && 
                           SightTracePassed(new_pos, new_pos - (0, 0, 50), false, self))
                        {
                            // Cancel any box purchase to prevent getting stuck again
							
                            goal_names = array("boxBuy");
                            foreach(goal_name in goal_names)
                            {
								if(self hasgoal(goal_name))
									self cancelgoal(goal_name);
                            }
                            
                            // Teleport as last resort
                            self SetOrigin(new_pos);
                        }
                    }
                }
            }
            else
            {
                // If far enough, cancel avoid goal
                if(self hasgoal("avoid_player"))
                    self cancelgoal("avoid_player");
            }
        }
    }
}

bot_pack_gun()
{
	if(level.round_number <= 9)
		return;
		
	if(!self bot_should_pack())
		return;
		
	if(!isDefined(self.bot.pap_check_time) || GetTime() > self.bot.pap_check_time)
	{
		self.bot.pap_check_time = GetTime() + 3000;
		
		machines = get_cached_vending_machines(); // Use cached array
		
		foreach(pack in machines)
		{
			if(pack.script_noteworthy != "specialty_weapupgrade" && pack.script_noteworthy != "pack_a_punch" && !isDefined(pack.is_pap))
				continue;
				
			if(Distance(pack.origin, self.origin) < 99999 && self.score >= 5000)
			{
				weapon = self GetCurrentWeapon();
				upgrade_name = maps\mp\zombies\_zm_weapons::get_upgrade_weapon(weapon);
				
				if(isSubStr(weapon, "blunder") && !isSubStr(weapon, "upgraded") && weapon == upgrade_name)
					upgrade_name = "blundergat_upgraded_zm";
				
				if(isSubStr(weapon, "slipgun") && !isSubStr(weapon, "upgraded") && weapon == upgrade_name)
					upgrade_name = "slipgun_upgraded_zm";
				
				// Check if weapon is already upgraded (prevent double PaP)
				if(weapon == upgrade_name)
					return;
				
				// Stop shooting and aiming before the weapon swap to prevent losing the weapon
				self allowattack(0);
				self pressads(0);
				
				self maps\mp\zombies\_zm_score::minus_to_player_score(5000);
				self TakeWeapon(weapon); // Only take the gun they are currently holding
				self GiveWeapon(upgrade_name);
				self GiveMaxAmmo(upgrade_name); // Good practice for PaP
				self SwitchToWeapon(upgrade_name); // Force them to pull it out
				self SetSpawnWeapon(upgrade_name);
				return;
			}
		}
	}
}

bot_buy_box()
{
	// Only try to access the box on a timed interval
    if (!isDefined(self.bot.box_purchase_time) || GetTime() > self.bot.box_purchase_time)
    {
        self.bot.box_purchase_time = GetTime() + 3000;

        // Don't try if we're in last stand or can't afford it
        if(self maps\mp\zombies\_zm_laststand::player_is_in_laststand() || self.score < 950)
            return;
		
		weapon = self GetCurrentWeapon();
		
		// Don't spend points on the box if they have wonder weapons
		if(isSubStr(weapon, "staff") || isSubStr(weapon, "blunder") || 
		   isSubStr(weapon, "slowgun") || isSubStr(weapon, "slipgun") || 
		   isSubStr(weapon, "mark2") || isSubStr(weapon, "ray_gun"))
		{
			if(self hasgoal("boxBuy"))
				self CancelGoal("boxBuy");
			return;
		}

        // Check global box usage tracker
        if(isDefined(level.box_in_use_by_bot) && level.box_in_use_by_bot != self)
        {
            if(self hasgoal("boxBuy"))
				self cancelgoal("boxBuy");
			
            if(self hasgoal("boxGrab"))
				self cancelgoal("boxGrab");
            return;
        }
		
        // Round-based cooldowns
        if (level.round_number <= 8)
		{
            if (isDefined(self.bot.last_box_interaction_time) && (GetTime() - self.bot.last_box_interaction_time < 120000))
				return;
        }
		else if (level.round_number <= 15)
		{
            if (isDefined(self.bot.last_box_interaction_time) && (GetTime() - self.bot.last_box_interaction_time < 180000))
				return;
        }
		else if (level.round_number <= 25)
		{
            if (isDefined(self.bot.last_box_interaction_time) && (GetTime() - self.bot.last_box_interaction_time < 210000))
				return;
        }
		else
		{
            if (isDefined(self.bot.last_box_interaction_time) && (GetTime() - self.bot.last_box_interaction_time < 300000))
				return;
        }
        
        // Check if we already paid and are waiting for the animation
        if(is_true(self.bot.waiting_for_box_animation))
        {
            if((!isDefined(self.bot.box_payment_time) || (GetTime() - self.bot.box_payment_time > 10000))) 
            {
                self.bot.waiting_for_box_animation = undefined;
                self.bot.current_box = undefined;
                self.bot.is_using_box = undefined;
                if(level.box_in_use_by_bot == self)
				level.box_in_use_by_bot = undefined;
            }
            return;
        }

        // Make sure boxes exist and index is valid
        if(!isDefined(level.chests) || level.chests.size == 0 || !isDefined(level.chest_index) || level.chest_index >= level.chests.size)
            return;

        current_box = level.chests[level.chest_index];
        if(!isDefined(current_box) || !isDefined(current_box.origin))
            return;

        // Check if box is available
        if(is_true(current_box._box_open) || 
		flag("moving_chest_now") || 
		(isDefined(current_box.is_locked) && current_box.is_locked) || 
		(isDefined(current_box.chest_user) && current_box.chest_user != self) || 
		(isDefined(level.mystery_box_teddy_locations) && fast_array_contains(level.mystery_box_teddy_locations, current_box.origin))) 
        {
            return; 
        }

        dist_sq = DistanceSquared(self.origin, current_box.origin);
        interaction_dist_sq = 22500;
        detection_dist_sq = 4000000;
        
        if (getDvar("mapname") == "zm_transit" || getDvar("mapname") == "zm_highrise" || getDvar("mapname") == "zm_buried")
        {
            detection_dist_sq = 640000;
        }

        if(self.score >= 950 && dist_sq < detection_dist_sq)
        {
            if(FindPath(self.origin, current_box.origin, undefined, 0, 1))
            {
                if(dist_sq > interaction_dist_sq)
                {
                    if(!self hasgoal("boxBuy") || DistanceSquared(self GetGoal("boxBuy"), current_box.origin) > 22500)
                        self AddGoal(current_box.origin, 125, 2, "boxBuy");
                    return;
                }

                // --- Use the box when close enough ---
                if(self hasgoal("boxBuy")) self cancelgoal("boxBuy");
                
                aim_offset = (randomfloatrange(-5,5), randomfloatrange(-5,5), randomfloatrange(-5,5));
                self lookat(current_box.origin + aim_offset);
                wait randomfloatrange(0.3, 0.8);

                if(self.score < 950 || is_true(current_box._box_open) || 
				flag("moving_chest_now") || 
				(isDefined(current_box.is_locked) && current_box.is_locked) || 
				self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
                {
                    return;
                }

                // Setup state
                level.box_in_use_by_bot = self;
                current_box.chest_user = self; 
                self.bot.current_box = current_box;
                self.bot.is_using_box = true;
				
				// Stop shooting immediately upon deciding to use the box
				self allowattack(0);
				self pressads(0);
				
                self.bot.waiting_for_box_animation = true;
                self.bot.box_payment_time = GetTime();

                // Buy box
                self maps\mp\zombies\_zm_score::minus_to_player_score(0);
                self PlaySound("zmb_cha_ching");

                if(isDefined(current_box.unitrigger_stub) && isDefined(current_box.unitrigger_stub.trigger))
                    current_box.unitrigger_stub.trigger notify("trigger", self);
                else if(isDefined(current_box.use_trigger))
                     current_box.use_trigger notify("trigger", self);
                else
                    current_box notify("trigger", self);

                // Start the monitor thread
                self thread bot_monitor_box_animation(current_box);
                return; 
            }
        }

        if(self hasgoal("boxBuy") || self hasgoal("boxGrab"))
        {
            self cancelgoal("boxBuy");
            self cancelgoal("boxGrab");
        }
    }
}

bot_monitor_box_animation(box)
{
    self endon("disconnect");
    self endon("death");
    self endon("box_usage_complete");
    
    wait 5;
    
    self.bot.waiting_for_box_animation = undefined;

    // Verify box is still valid and player isn't downed
    if(!isDefined(box) || self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
    {
        self.bot.current_box = undefined;
        self.bot.is_using_box = undefined;
        if(level.box_in_use_by_bot == self)
		level.box_in_use_by_bot = undefined;
        self notify("box_usage_complete");
        return;
    }

    // Teddy Bear Check: If the box has closed after 5 seconds, it was a teddy
    if(!is_true(box._box_open))
    {
        if(!isDefined(level.mystery_box_teddy_locations))
            level.mystery_box_teddy_locations = [];
            
        if(!fast_array_contains(level.mystery_box_teddy_locations, box.origin))
            level.mystery_box_teddy_locations[level.mystery_box_teddy_locations.size] = box.origin;
            
        self.bot.current_box = undefined;
        self.bot.is_using_box = undefined;
        if(level.box_in_use_by_bot == self)
		level.box_in_use_by_bot = undefined;
        self notify("box_usage_complete");
        return;
    }

    // Commit to evaluation (stop movement/goals)
    self cancelgoal("boxBuy");
    self cancelgoal("boxGrab");
    self cancelgoal("wander");
    
    box.chest_user = self;
    self lookat(box.origin);
    wait 0.2;

    // --- WEAPON EVALUATION ---
    
    // Try to get the weapon string from the box
    box_weapon = undefined;
    if(isDefined(box.zbarrier) && isDefined(box.zbarrier.weapon_string))
    {
        box_weapon = box.zbarrier.weapon_string;
    }
    else if(isDefined(box.weapon_string))
    {
        box_weapon = box.weapon_string;
    }

    // Find the bot's worst weapon to replace
    weapons = self GetWeaponsListPrimaries();
    worst_weapon = weapons[0];
    worst_score = 999;
    
    if(isDefined(weapons) && weapons.size > 0)
    {
        foreach(weap in weapons)
        {
            score = bot_get_weapon_score(weap);
            if(score < worst_score)
            {
                worst_score = score;
                worst_weapon = weap;
            }
        }
    }

    // Make the bot switch to their worst weapon so it gets traded
    if(isDefined(worst_weapon) && self GetCurrentWeapon() != worst_weapon)
    {
        self SwitchToWeapon(worst_weapon);
        wait 0.5; // Give it time to switch
    }

    // Check if the bot should actually take the weapon
    if(bot_should_take_weapon(box_weapon, worst_weapon))
    {
        // Retry grab multiple times for reliability
        for(attempt = 0; attempt < 3; attempt++)
        {
            if(is_true(box._box_open))
            {
                if(isDefined(box.unitrigger_stub) && isDefined(box.unitrigger_stub.trigger))
                    box.unitrigger_stub.trigger notify("trigger", self);
                else if(isDefined(box.use_trigger))
                    box.use_trigger notify("trigger", self);
				else
				{
					box notify("trigger", self);
					self UseButtonPressed();
				}
                wait 0.5;
                
                // Check if weapon was actually taken
                if(!is_true(box._box_open))
                    break;
            }
            else
            {
                break;
            }
        }
    }
    
    // Cleanup
    self.bot.last_box_interaction_time = GetTime();
    self.bot.current_box = undefined;
    self.bot.is_using_box = undefined;
    
    if(isDefined(box.chest_user) && box.chest_user == self)
        box.chest_user = undefined;
        
    if(level.box_in_use_by_bot == self)
        level.box_in_use_by_bot = undefined;
        
    self notify("box_usage_complete");
}

bot_should_take_weapon(boxWeapon, currentWeapon)
{
    // Failsafe for custom mods: If we can't read the box weapon, take it to be safe
    if(!isDefined(boxWeapon))
		return true; 

    score_box = bot_get_weapon_score(boxWeapon);
    score_current = bot_get_weapon_score(currentWeapon);

    // Take it if it's a better tier, or equal
    return score_box >= score_current;
}

bot_get_weapon_score(weapon)
{
    if(!isDefined(weapon) || weapon == "none")
		return 0;
    
    // Wonder Weapons
    if(IsSubStr(weapon, "ray_gun") || 
		IsSubStr(weapon, "mark2") || 
		IsSubStr(weapon, "slipgun") || 
		IsSubStr(weapon, "slowgun") || 
		IsSubStr(weapon, "blundergat") || 
		IsSubStr(weapon, "blundersplat") || 
		IsSubStr(weapon, "staff") || 
		
    // LMGs & Special Weapons
		IsSubStr(weapon, "mg08") || 
		IsSubStr(weapon, "hamr") || 
		IsSubStr(weapon, "lsat") || 
		IsSubStr(weapon, "mk48") || 
		IsSubStr(weapon, "qbb95") || 
		IsSubStr(weapon, "minigun") || 
		IsSubStr(weapon, "titus") || 
    
    // Assault Rifles
		IsSubStr(weapon, "mp44") || 
		IsSubStr(weapon, "ak47") || 
		IsSubStr(weapon, "hk416") || 
		IsSubStr(weapon, "scar") || 
		IsSubStr(weapon, "an94") || 
		IsSubStr(weapon, "tar21") || 
		IsSubStr(weapon, "type95")) 
		return 100;
    
    // SMGs / Shotguns / Handguns
    if(IsSubStr(weapon, "pdw57") || 
		IsSubStr(weapon, "mp7") || 
		IsSubStr(weapon, "vector_extclip") || 
		IsSubStr(weapon, "evoskorpion") || 
		IsSubStr(weapon, "peacekeeper") || 
		IsSubStr(weapon, "ak74u_extclip") || 
		IsSubStr(weapon, "uzi") || 
		IsSubStr(weapon, "thompson") || 
		IsSubStr(weapon, "mp40_stalker") || 
		IsSubStr(weapon, "ksg") || 
		IsSubStr(weapon, "870mcs") || 
		IsSubStr(weapon, "saiga12") || 
		IsSubStr(weapon, "srm1216") || 
		IsSubStr(weapon, "fivesevendw") || 
		IsSubStr(weapon, "judge")) 
			return 70;
		
	// Explosives Weapons
	if(IsSubStr(weapon, "m32") || 
		IsSubStr(weapon, "usrpg"))
		return 60;
	
	// Weapons that it shouldn't be take it from the box
	if(IsSubStr(weapon, "knife_ballistic") || 
		IsSubStr(weapon, "willy_pete") || 
		IsSubStr(weapon, "time_bomb") || 
		IsSubStr(weapon, "emp_grenade") || 
		IsSubStr(weapon, "cymbal_monkey"))
			return 0;

    // Unknown/Custom weapons default to a mid-tier score
    return 20; 
}

bot_buy_wallbuy()
{
	self endon("death");
	self endon("disconnect");
	level endon("end_game");
	
    if (GetTime() < self.bot.wallbuy_check_time)
        return;
	
    self.bot.wallbuy_check_time = GetTime() + 3000;

	weapon = self GetCurrentWeapon();
	upgrade_name = maps\mp\zombies\_zm_weapons::get_upgrade_weapon(weapon);
	
	if(level.round_number <= 3)
		return;
	
	if(self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
	{
		self CancelGoal("weaponBuy");
		return;
	}
	
	if (isSubStr(weapon, "staff") || isSubStr(weapon, "blunder") || isSubStr(weapon, "slowgun") || 
		isSubStr(weapon, "slipgun") || isSubStr(weapon, "mark2") || isSubStr(weapon, "ray_gun") || 
		
		isSubStr(weapon, "minigun") || isSubStr(weapon, "usrpg") || isSubStr(weapon, "m32") || 
		isSubStr(weapon, "titus") || isSubStr(weapon, "crossbow") || 
		
		isSubStr(weapon, "srm1216") || isSubStr(weapon, "ksg") || 
		isSubStr(weapon, "saiga12") || isSubStr(weapon, "870mcs") || 
		
		isSubStr(weapon, "hamr") || isSubStr(weapon, "lsat") || 
		isSubStr(weapon, "mk48") || isSubStr(weapon, "qbb95") || 
		isSubStr(weapon, "rpd") || isSubStr(weapon, "mg08") || 
		
		isSubStr(weapon, "hk416") || isSubStr(weapon, "scar") || isSubStr(weapon, "an94") || 
		isSubStr(weapon, "tar21") || isSubStr(weapon, "type95") || isSubStr(weapon, "sig556") || 
		isSubStr(weapon, "ak47") || isSubStr(weapon, "mp44") || 
		
		isSubStr(weapon, "peacekeeper") || isSubStr(weapon, "evoskorpion") || isSubStr(weapon, "mp7") || 
		isSubStr(weapon, "pdw57") || isSubStr(weapon, "vector_extclip") || isSubStr(weapon, "insas") || 
		isSubStr(weapon, "ak74u_extclip") || isSubStr(weapon, "uzi") || 
		isSubStr(weapon, "thompson") || isSubStr(weapon, "mp40_stalker") || 
		
		isSubStr(weapon, "dsr50") || isSubStr(weapon, "svu") || isSubStr(weapon, "as50") || 
		isSubStr(weapon, "fivesevendw") || isSubStr(weapon, "judge") || isSubStr(weapon, "rnma"))
	{
		self CancelGoal("weaponBuy");
		return;
	}
	
	weaponToBuy = undefined;
	wallbuys = array_randomize(level._spawned_wallbuys);
	
	foreach(wallbuy in wallbuys)
	{
		if(DistanceSquared(wallbuy.origin, self.origin) <= 9000000 && wallbuy.trigger_stub.cost <= self.score)
		{
			if(bot_best_gun(wallbuy.trigger_stub.zombie_weapon_upgrade, weapon) && 
			   weapon != wallbuy.trigger_stub.zombie_weapon_upgrade && 
			   !is_offhand_weapon(wallbuy.trigger_stub.zombie_weapon_upgrade))
			{
				if(weapon == upgrade_name)
					return;
				
				if(!isdefined(wallbuy.trigger_stub))
					return;
			
				if(!isdefined(wallbuy.trigger_stub.zombie_weapon_upgrade))
					return;
			
				weaponToBuy = wallbuy;
				break;
			}
		}
	}
	
	if(!isdefined(weaponToBuy)) 
		return;
	
	self AddGoal(weaponToBuy.origin, 3000, 2, "weaponBuy");
	
	while(!self AtGoal("weaponBuy") && !DistanceSquared(self.origin, weaponToBuy.origin) <= 9000000)
	{
		wait 1;
		if(self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
		{
			self cancelgoal("weaponBuy");
			return;
		}
	}
	
	self cancelgoal("weaponBuy");
	
	// Stop shooting and aiming before the weapon swap to prevent losing the weapon
	self allowattack(0);
	self pressads(0);
	
	self maps\mp\zombies\_zm_score::minus_to_player_score(weaponToBuy.trigger_stub.cost);
	self TakeWeapon(weapon); // Only take the gun they are currently holding
	self GiveWeapon(weaponToBuy.trigger_stub.zombie_weapon_upgrade);
	self GiveMaxAmmo(weaponToBuy.trigger_stub.zombie_weapon_upgrade); 
	self SwitchToWeapon(weaponToBuy.trigger_stub.zombie_weapon_upgrade); // Force them to pull it out
	self SetSpawnWeapon(weaponToBuy.trigger_stub.zombie_weapon_upgrade);
}

bot_best_gun(buyingweapon, currentweapon)
{
    // Priority weapons based on round number
    if(level.round_number >= 8)
    {
        priority_weapons = array("lsat_zm", "870mcs_zm", "an94_zm", "sig556_zm", "mp44_zm", "pdw57_zm", "insas_zm", "vector_zm", "thompson_zm", "mp40_zm");
        foreach(weapon in priority_weapons)
        {
            if(buyingweapon == weapon)
                return true;
        }
    }
    else if(level.round_number <= 5)
    {
        if(buyingweapon == "pdw57_zm" || buyingweapon == "insas_zm")
            return true;
    }
	
    // Consider weapon cost as fallback
    if(maps\mp\zombies\_zm_weapons::get_weapon_cost(buyingweapon) > maps\mp\zombies\_zm_weapons::get_weapon_cost(currentweapon))
        return true;
        
    return false;
}

bot_weapon_failsafe_monitor()
{
    self endon("death");
    self endon("disconnect");
    
    for(;;)
    {
        wait 1; 
        
        // Skip checking if the bot is reviving or doing box stuff
        if(is_true(self.bot.is_reviving) || is_true(self.bot.is_using_box))
            continue;

        weapon = self GetCurrentWeapon();
        primaries = self GetWeaponsListPrimaries();
        
        // If they somehow have no current weapon, or their primary inventory is completely empty
        if (weapon == "none" || !isDefined(primaries) || primaries.size == 0)
        {
            // Wait a short moment to rule out a mid-transition false positive
            // (e.g. right after a box grab when the engine is switching weapons)
            wait 0.5;

            // Re-check after the buffer
            weapon = self GetCurrentWeapon();
            primaries = self GetWeaponsListPrimaries();

            if (weapon != "none" && isDefined(primaries) && primaries.size > 0)
                continue; // Weapon transition completed fine, no fallback needed

            fallback_weapon = "galil_zm";
            
            // Check if the map is Origins
            if (getDvar("mapname") == "zm_tomb")
            {
                fallback_weapon = "mp44_zm";
            }
            
            self GiveWeapon(fallback_weapon);
            self GiveMaxAmmo(fallback_weapon);
            self SwitchToWeapon(fallback_weapon);
            self SetSpawnWeapon(fallback_weapon);
        }
    }
}

bot_buy_door()
{
    if (!isDefined(self.bot.door_purchase_time) || GetTime() > self.bot.door_purchase_time)
    {
        // Only attempt to purchase doors every 5 seconds
        self.bot.door_purchase_time = GetTime() + 5000;

        // Get all potential doors
        doors = get_cached_doors(); // Use cached doors
        
        // Find the closest valid door
        closestDoor = undefined;
        closestDistSq = 90000; // Reduced max distance for realism
		
		if(self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
			return;

        foreach(door in doors)
        {
            // Skip if door is already opened
            if(isDefined(door._door_open) && door._door_open)
                continue;
                
            if(isDefined(door.has_been_opened) && door.has_been_opened)
                continue;

            // Set default cost if not defined
            if(!isDefined(door.zombie_cost))
                door.zombie_cost = 1000;

            // Skip doors we can't afford
            if(self.score < door.zombie_cost)
                continue;

            // Handle electric doors
            if(isDefined(door.script_noteworthy))
            {
                if(door.script_noteworthy == "electric_door" || door.script_noteworthy == "local_electric_door")
                {
                    if(!flag("power_on"))
                        continue;
                }
            }

            // Check distance
            dist_sq = DistanceSquared(self.origin, door.origin);
            if(dist_sq < closestDistSq)
            {
                closestDoor = door;
                closestDistSq = dist_sq;
            }
        }

        // If we found a valid door and we're close enough, try to buy it
        if(isDefined(closestDoor))
        {
            // Deduct points first
            self maps\mp\zombies\_zm_score::minus_to_player_score(closestDoor.zombie_cost);
            
            // Try to call door_buy first, if that function exists on the door
            if(isDefined(closestDoor.door_buy))
            {
                closestDoor thread door_buy();
            }
			
            // Otherwise fallback to direct door_opened call
            else
            {
                closestDoor thread maps\mp\zombies\_zm_blockers::door_opened(closestDoor.zombie_cost);
            }
            
            // Mark door as opened
            closestDoor._door_open = 1;
            closestDoor.has_been_opened = 1;
            
            // Play purchase sound
            self PlaySound("zmb_cha_ching");
            return true;
        }
    }
    return false;
}

bot_clear_debris()
{
    if (!isDefined(self.bot.debris_purchase_time) || GetTime() > self.bot.debris_purchase_time)
    {
		// Skip Buried Map
		if(getDvar("mapname") == "zm_buried")
		{
			return;
		}
		
        // Only attempt to clear debris every 5 seconds
        self.bot.debris_purchase_time = GetTime() + 5000;
        
        // Get all potential debris piles
        debris = get_cached_debris(); // Use cached debris
        
        if(debris.size == 0)
            return false;
        
        // Find the closest valid debris pile
        closestDebris = undefined;
        closestDistSq = 250000; // Reduced max distance for realism
		
		if(self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
			return;
        
        foreach(pile in debris)
        {
            // Skip if pile is not defined
            if(!isDefined(pile))
                continue;
                
            // Skip if origin is not defined
            if(!isDefined(pile.origin))
                continue;
            
            // Skip if debris is already cleared
            if(isDefined(pile._door_open) && pile._door_open)
                continue;
            
            if(isDefined(pile.has_been_opened) && pile.has_been_opened)
                continue;
            
            // Set default cost if not defined
            if(!isDefined(pile.zombie_cost))
                pile.zombie_cost = 1000;
            
            // Skip if we can't afford it
            if(self.score < pile.zombie_cost)
                continue;
            
            // Get nearby nodes for path finding
            nearbyNodes = GetNodesInRadius(pile.origin, 150, 0);
            if(!isDefined(nearbyNodes) || nearbyNodes.size == 0)
            {
                // Try direct path if no nodes found
                if(FindPath(self.origin, pile.origin, undefined, 0, 1))
                    pathFound = true;
                else 
                    continue;
            }
            else
            {
                // Try path to closest node first
                pathFound = false;
                
                foreach(node in nearbyNodes)
                {
                    if(FindPath(self.origin, node.origin, undefined, 0, 1))
                    {
                        pathFound = true;
                        break;
                    }
                }
                
                if(!pathFound)
                {
                    // Try multiple height offsets as fallback
                    offsets = array(0, 30, -30, 50, -50);
                    foreach(offset in offsets)
                    {
                        offsetOrigin = pile.origin + (0, 0, offset);
                        if(FindPath(self.origin, offsetOrigin, undefined, 0, 1))
                        {
                            pathFound = true;
                            break;
                        }
                    }
                }
            }
            
            if(!pathFound)
                continue;
            
            // Check distance first
            dist_sq = DistanceSquared(self.origin, pile.origin);
            if(dist_sq < closestDistSq)
            {
                closestDebris = pile;
                closestDistSq = dist_sq;
            }
        }
        
        // If we found valid debris, try to clear it
        if(isDefined(closestDebris))
        {
            // Move toward the debris if not close enough
            if(closestDistSq > 90000) // Reduced interaction range
            {
                self AddGoal(closestDebris.origin, 300, 2, "debrisClear");
                return false;
            }
            
            // Deduct points and clear debris
            self maps\mp\zombies\_zm_score::minus_to_player_score(closestDebris.zombie_cost);
            junk = getentarray(closestDebris.target, "targetname");
			
            // Mark the debris as cleared
            closestDebris._door_open = 1;
            closestDebris.has_been_opened = 1;
            
            // Try multiple methods to trigger debris removal
            closestDebris notify("trigger", self);
            if(isDefined(closestDebris.trigger))
                closestDebris.trigger notify("trigger", self);
                
            // Activate any associated triggers
            if(isDefined(closestDebris.target))
            {
                targets = GetEntArray(closestDebris.target, "targetname");
                foreach(target in targets)
                {
                    if(isDefined(target))
                    {
                        target notify("trigger", self);
                    }
                }
            }
            
            // Update flags if specified
            if(isDefined(closestDebris.script_flag))
            {
                tokens = strtok(closestDebris.script_flag, ",");
                for(i = 0; i < tokens.size; i++)
                {
                    flag_set(tokens[i]);
                }
            }

            play_sound_at_pos("purchase", closestDebris.origin);
            level notify("junk purchased");

			// Process each piece of debris
            foreach(chunk in junk)
            {
                chunk connectpaths();
                
                if(isDefined(chunk.script_linkto))
                {
                    struct = getstruct(chunk.script_linkto, "script_linkname");
                    if(isDefined(struct))
                    {
                        chunk thread maps\mp\zombies\_zm_blockers::debris_move(struct);
                    }
                    else
                        chunk delete();
                    continue;
                }
                
                chunk delete();
            }

            // Delete the triggers
            all_trigs = getentarray(closestDebris.target, "target");
            foreach(trig in all_trigs)
                trig delete();
            
            // Clean up goals
            if(self hasgoal("debrisClear"))
                self cancelgoal("debrisClear");
			
            // Update stats
            self maps\mp\zombies\_zm_stats::increment_client_stat("doors_purchased");
            self maps\mp\zombies\_zm_stats::increment_player_stat("doors_purchased");
            
            return true;
        }
        
        if(self hasgoal("debrisClear"))
            self cancelgoal("debrisClear");
    }
    return false;
}

bot_update_wander()
{
	self endon("death");
	self endon("disconnect");
	level endon("game_ended");

	for(;;)
	{
		wait 0.1;
		
        if(is_true(self.bot.is_reviving) || (isDefined(level.box_in_use_by_bot) && level.box_in_use_by_bot == self))
            continue;
		
		players = get_players();
		
		if(players.size == 0)
            continue;
		
		player = players[0];
		
        if(!isDefined(player) || player maps\mp\zombies\_zm_laststand::player_is_in_laststand())
            continue;
		
		dist_sq = DistanceSquared(self.origin, player.origin);
		
		if(dist_sq > 1440000)
		{
			self.bot.is_following = true;
		}

		if(self.bot.is_following)
		{
			self AddGoal(player.origin, 100, 1, "wander");
			
			if(dist_sq < 22500)
			{
				self.bot.is_following = false;
				self CancelGoal("wander");
			}
		}
		else
		{
			if(self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
				continue;
			
			if(self HasGoal("wander") && !isdefined(self.bot.threat.entity) && !isAlive(self.bot.threat.entity))
				self pressads(0);
			
			if(!isDefined(self.bot.last_wander_pos))
			{
				self.bot.last_wander_pos = self.origin;
				self.bot.wander_stay_time = getTime();
			}
			
			if(DistanceSquared(self.origin, self.bot.last_wander_pos) > 256) 
			{
				self.bot.last_wander_pos = self.origin;
				self.bot.wander_stay_time = getTime();
			}
			
			time_at_point = (getTime() - self.bot.wander_stay_time) / 1000;
			
			if(!self HasGoal("wander") || self AtGoal("wander") || time_at_point >= 2)
			{
				location = get_random_walkable_location(player.origin, 800, self);

				if(isDefined(location))
				{
					self CancelGoal("wander");
					
					self AddGoal(location, 100, 1, "wander");
					
					self.bot.last_wander_pos = self.origin;
					self.bot.wander_stay_time = getTime();
				}
			}
		}
	}
}

get_random_walkable_location(origin, range, player)
{
	tries = 0;
	
	for(;;)
	{
		x = origin[0] + randomintrange(range * -1, range);
		y = origin[1] + randomintrange(range * -1, range);
		z = origin[2] + randomintrange(range * -1, range);
		
		if(check_point_in_playable_area((x,y,z)))
			return (x,y,z);
		
		if(tries >= 15)
		{
			return origin;
		}
		
		tries ++;
		
		wait 0.05;
	}
}

NodeVisible(origin1, origin2)
{
	// Add small vertical offset to account for ground level
	origin1 = origin1 + (0, 0, 10);
	origin2 = origin2 + (0, 0, 10);

	// Check line of sight between points
	return SightTracePassed(origin1, origin2, false, undefined);
}

// Optimized array contains - using direct index instead of loop for common case
fast_array_contains(array, value)
{
	if(!isDefined(array) || !array.size)
		return false;
	
	// Quick check for exact match first
	foreach(item in array)
	{
		if(item == value)
			return true;
		// Compare origins with a small tolerance
		if(distancesquared(item, value) < 100)
			return true;
	}
	
	return false;
}

bot_should_pack()
{
	weapon = self GetCurrentWeapon();

	if(maps\mp\zombies\_zm_weapons::can_upgrade_weapon(weapon))
		return 1;
	
	if(isSubStr(weapon, "blunder") && !isSubStr(weapon, "upgraded"))
		return 1;
	
	if(isSubStr(weapon, "slipgun") && !isSubStr(weapon, "upgraded"))
		return 1;
	
	return 0;
}

bot_reset_flee_goal()
{
	self endon("death");
	self endon("disconnect");
	level endon("end_game");
	
	while(1)
	{
		self CancelGoal("flee");
		wait 2;
	}
}

bot_wakeup_think()
{
	self endon("death");
	self endon("disconnect");
	level endon("game_ended");
	
	for (;;)
	{
		wait self.bot.think_interval;
		wait (randomfloat(0.05));
		
		self notify("wakeup");
	}
}

bot_damage_think()
{
	self notify("bot_damage_think");
	self endon("bot_damage_think");
	
	self endon("disconnect");
	level endon("game_ended");
	
	for (;;)
	{
		self waittill("damage", damage, attacker, direction, point, mod, unused1, unused2, unused3, unused4, weapon, flags, inflictor);
		
		self.bot.attacker = attacker;
		
		self notify("wakeup", damage, attacker, direction);
	}
}

bot_update_lookat()
{
	path = 0;
	
	if (isDefined(self getlookaheaddir()))
		path = 1;

	if (!path && getTime() > self.bot.update_idle_lookat)
	{
		origin = bot_get_look_at();
		
		if (!isDefined(origin))
			return;

		self lookat(origin + vectorScale((0, 0, 1), 16));
		self.bot.update_idle_lookat = getTime() + randomintrange(1500, 3000);
	}
	else if (path && self.bot.update_idle_lookat > 0)
	{
		self clearlookat();
		self.bot.update_idle_lookat = 0;
	}
}

bot_get_look_at()
{
	enemy = bot_get_closest_enemy(self.origin);
	
	if (isDefined(enemy))
	{
		node = getvisiblenode(self.origin, enemy.origin);
		
		if (isDefined(node) && distancesquared(self.origin, node.origin) > 1048576)
		{
			return node.origin;
		}
	}
	
	spawn = self getgoal("wander");
	
	if (isDefined(spawn))
	{
		node = getvisiblenode(self.origin, spawn);
	}
	
	if (isDefined(node) && distancesquared(self.origin, node.origin) > 1048576)
	{
		return node.origin;
	}
	
	return undefined;
}

bot_get_closest_enemy(origin)
{
	enemies = get_cached_zombies(); // Use cached array
    
    closestEnemy = undefined;
    closestDistSq = 100000000; // Large number

    foreach(enemy in enemies)
    {
        if(!isDefined(enemy) || !isAlive(enemy))
			continue;
        
        distSq = DistanceSquared(origin, enemy.origin);
		
        if(distSq < closestDistSq)
        {
            closestDistSq = distSq;
            closestEnemy = enemy;
        }
    }
	return closestEnemy;
}

bot_update_weapon()
{
	weapon = self GetCurrentWeapon();
	
	primaries = self getweaponslistprimaries();
	
	foreach (primary in primaries)
	{
		if (primary != weapon)
		{
			self switchtoweapon(primary);
			return;
		}
		i++;
	}
}

bot_give_ammo()
{
	self endon("disconnect");
	self endon("death");
	level endon("game_ended");
	
	for(;;)
	{
		primary_weapons = self GetWeaponsListPrimaries();
		
		j=0;
		
		while(j <primary_weapons.size)
		{
			self GiveMaxAmmo(primary_weapons[j]);
			j++;
		}
		wait 1;
	}
}

bot_update_failsafe()
{
	time = getTime();
	
	if ((time - self.spawntime) < 7500)
	{
		return;
	}
	
	if (time < self.bot.update_failsafe)
	{
		return;
	}
	
	if (!self atgoal() && distancesquared(self.bot.previous_origin, self.origin) < 256)
	{
		nodes = getnodesinradius(self.origin, 512, 0);
		nodes = array_randomize(nodes);
		nearest = bot_nearest_node(self.origin);
		
		failsafe = 0;
		
		if (isDefined(nearest))
		{
			i = 0;
			while (i < nodes.size)
			{
				if (!bot_failsafe_node_valid(nearest, nodes[i]))
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
		else if (!failsafe && nodes.size)
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
	
	self.bot.update_failsafe = getTime() + 3500;
	self.bot.previous_origin = self.origin;
}

bot_failsafe_node_valid(nearest, node)
{
	if (isDefined(node.script_noteworthy))
	{
		return 0;
	}
	
	if ((node.origin[2] - self.origin[2]) > 18)
	{
		return 0;
	}
	
	if (nearest == node)
	{
		return 0;
	}
	
	if (!nodesvisible(nearest, node))
	{
		return 0;
	}
	
	if (isDefined(level.spawn_all) && level.spawn_all.size > 0)
	{
		spawns = arraysort(level.spawn_all, node.origin);
	}
	else if (isDefined(level.spawnpoints) && level.spawnpoints.size > 0)
	{
		spawns = arraysort(level.spawnpoints, node.origin);
	}
	else if (isDefined(level.spawn_start) && level.spawn_start.size > 0)
	{
		spawns = arraycombine(level.spawn_start["allies"], level.spawn_start["axis"], 1, 0);
		spawns = arraysort(spawns, node.origin);
	}
	else
	{
		return 0;
	}
	
	goal = bot_nearest_node(spawns[0].origin);
	
	if (isDefined(goal) && findpath(node.origin, goal.origin, undefined, 0, 1))
	{
		return 1;
	}
	
	return 0;
}

bot_nearest_node(origin)
{
	node = getnearestnode(origin);
	
	if (isDefined(node))
	{
		return node;
	}
	
	nodes = getnodesinradiussorted(origin, 256, 0, 256);
	
	if (nodes.size)
	{
		return nodes[0];
	}
	
	return undefined;
}