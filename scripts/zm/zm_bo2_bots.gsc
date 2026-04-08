#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include maps\mp\zombies\_zm_score;
#include maps\mp\zombies\_zm_laststand;
#include maps\mp\zombies\_zm_weapons;
#include maps\mp\zombies\_zm_blockers;
#include maps\mp\zombies\_zm_powerups;
#include scripts\zm\zm_bo2_bots_combat;
#include scripts\zm\zm_bo2_bots_utility;

// Bot action constants
#define BOT_ACTION_STAND "stand"
#define BOT_ACTION_CROUCH "crouch"
#define BOT_ACTION_PRONE "prone"

main()
{
	init_dvars();
}

bot_spawn()
{
    self bot_spawn_init();
    self thread bot_main();
    //self thread bot_check_player_blocking();
}

array_combine(array1, array2)
{
    if (!isDefined(array1))
        array1 = [];
    if (!isDefined(array2))
        array2 = [];

    foreach (item in array2)
    {
        array1[array1.size] = item;
    }

    return array1;
}

init()
{
    bot_set_skill();
    
    // Add debug
    iprintln("^3Waiting for initial blackscreen...");
    flag_wait("initial_blackscreen_passed");
    iprintln("^2Blackscreen passed, continuing bot setup...");

    if(!isdefined(level.using_bot_weapon_logic))
        level.using_bot_weapon_logic = 1;
    if(!isdefined(level.using_bot_revive_logic))
        level.using_bot_revive_logic = 1;

    // Initialize box usage variables
    level.box_in_use_by_bot = undefined;

    // Setup bot tracking array
    if (!isdefined(level.bots))
        level.bots = [];

    bot_amount = GetDvarIntDefault("zm_bots", 0);

    iprintln("^2Spawning " + bot_amount + " bots...");

    for(i=0; i<bot_amount; i++)
    {
        iprintln("^3Spawning bot " + (i+1));
        // Track spawned bot entities
        bot_entity = spawn_bot();
        level.bots[level.bots.size] = bot_entity;
        wait 1; // Add a brief pause between bot spawns
    }
}

create_dvar(dvar, set)
{
    if(getDvar(dvar) == "")
		setDvar(dvar, set);
}

init_dvars()
{
	create_dvar("bots_stay", 0);
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
	setDvar("g_playerCollision", "nobody");
	setDvar("g_playerEjection", "nobody");
}

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

bot_get_closest_enemy(origin)
{
	enemies = getaispeciesarray(level.zombie_team, "all");
	enemies = arraysort(enemies, origin);
	if (enemies.size >= 1)
	{
		return enemies[0];
	}
	return undefined;
}

spawn_bot()
{
    iprintln("^3Adding test client...");
    bot = addtestclient();
    if(!isDefined(bot))
    {
        iprintln("^1Failed to add test client!");
        return;
    }
    
    iprintln("^3Waiting for bot to spawn...");
    bot waittill("spawned_player");
    iprintln("^2Bot spawned, configuring...");
    
    bot thread maps\mp\zombies\_zm::spawnspectator();
    if(isDefined(bot))
    {
        bot.pers["isBot"] = 1;
        bot thread onspawn();
    }
    
    wait 1;
    iprintln("^3Spawning bot as player...");
    
    if(isDefined(level.spawnplayer))
        bot [[level.spawnplayer]]();
    else
        iprintln("^1ERROR: level.spawnplayer not defined!");
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
	
	for (;;)
	{
		self waittill("wakeup", damage, attacker, direction);
		if(self isremotecontrolling())
		{
			continue;
		}
		else
		{
			if(isDefined(self.bot.is_using_box) && self.bot.is_using_box)
			{
				// Force stop any movement goals every frame
				if(self hasgoal("boxBuy"))
					self cancelgoal("boxBuy");

				if(self hasgoal("boxGrab"))
					self cancelgoal("boxGrab");

				wait 0.05;
				continue;
			}
			self bot_combat_think(damage, attacker, direction);
			//self bot_update_follow_host();
			self bot_update_wander();
			self bot_update_lookat();
			self bot_stand_fix();
			self bot_teleport_think();
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
			self bot_buy_box();  // Added upgraded box buying functionality
		}	
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
            
        perks = array("specialty_quickrevive", "specialty_fastreload", "specialty_rof", "specialty_longersprint", "specialty_finalstand", "specialty_nomotionsensor", "specialty_deadshot", "specialty_flakjacket", "specialty_grenadepulldeath", "grenadepulldeath");
        costs = array(1500, 3000, 2000, 2000, 2000, 3000, 1500, 2000, 2000, 2000);
        
        machines = GetEntArray("zombie_vending", "targetname");
        nearby_machines = [];
        foreach(machine in machines)
        {
            if(Distance(machine.origin, self.origin) <= 99999)
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
	if(!maps\mp\zombies\_zm_laststand::player_any_player_in_laststand() || self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
	{
		self cancelgoal("revive");
		return;
	}
	if(!self hasgoal("revive"))
	{
		teammate = self get_closest_downed_teammate();
		if(!isdefined(teammate))
			return;
		self AddGoal(teammate.origin, 50, 3, "revive");
	}
	else
	{
		if(self AtGoal("revive") || Distance(self.origin, self GetGoal("revive")) < 75)
		{
			teammate = self get_closest_downed_teammate();
			teammate.revivetrigger disable_trigger();
			wait 0.75;
			teammate.revivetrigger enable_trigger();
			if(!self maps\mp\zombies\_zm_laststand::player_is_in_laststand() && teammate maps\mp\zombies\_zm_laststand::player_is_in_laststand())
			{
				teammate maps\mp\zombies\_zm_laststand::auto_revive( self );
			}
		}
	}
}

bot_pickup_powerup()
{
	if(maps\mp\zombies\_zm_powerups::get_powerups(self.origin, 1000).size == 0)
	{
		self CancelGoal("powerup");
		return;
	}
	if(getDvar("mapname") == "zm_prison")
	{
		self CancelGoal("powerup");
		return;
	}
	powerups = maps\mp\zombies\_zm_powerups::get_powerups(self.origin, 1000);
	foreach(powerup in powerups)
	{
		if(FindPath(self.origin, powerup.origin, undefined, 0, 1))
		{
			self AddGoal(powerup.origin, 25, 2, "powerup");
			if(self AtGoal("powerup") || Distance(self.origin, powerup.origin) < 50)
			{
				self CancelGoal("powerup");
			}
			return;
		}
	}
}

bot_teleport_think()
{
	self endon("death");
	self endon("disconnect");
	level endon("end_game");
	
	players = get_players();
	
	if(Distance(self.origin, players[0].origin) > 12500 && players[0] IsOnGround())
	{
		self SetOrigin(players[0].origin + (0,50,0));
	}
}

bot_stand_fix()
{
	self endon("death");
	self endon("disconnect");
	level endon("end_game");
	
	if (self isonground() && self getstance() != "prone")
	{
		wait 0.2;
		self botaction(BOT_ACTION_STAND);
	}
	else
	{
		if (self isonground() && self getstance() != "crouch")
		{
			wait 0.2;
			self botaction(BOT_ACTION_STAND);
		}
	}
}

bot_check_player_blocking()
{
    self endon("death");
    self endon("disconnect");
    level endon("game_ended");
    
    while(1)
    {
        wait 0.8; // Slightly reduced check frequency for better performance
        
        // Skip checks if bot is in last stand
        if(self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
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
                        best_dist = 0;
                        
                        if(isDefined(nodes) && nodes.size > 0)
                        {
                            foreach(node in nodes)
                            {
                                // Calculate which node is furthest from player but still reachable
                                if(NodeVisible(nearest_node.origin, node.origin))
                                {
                                    node_to_player_dist = Distance(node.origin, player.origin);
                                    if(node_to_player_dist > best_dist)
                                    {
                                        best_node = node;
                                        best_dist = node_to_player_dist;
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
                            // Cancel any door/weapon purchase goals to prevent getting stuck again
							
                            //goal_names = array("boxBuy", "papBuy", "weaponBuy", "doorBuy");
                            //foreach(goal_name in goal_names)
                            //{
                            //    if(self hasgoal(goal_name))
                            //        self cancelgoal(goal_name);
                            //}
                            
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

get_closest_downed_teammate()
{
	if(!maps\mp\zombies\_zm_laststand::player_any_player_in_laststand())
		return;
	downed_players = [];
	foreach(player in get_players())
	{
		if(player maps\mp\zombies\_zm_laststand::player_is_in_laststand())
		downed_players[downed_players.size] = player;
	}
	downed_players = arraysort(downed_players, self.origin);
	return downed_players[0];
}

bot_pack_gun()
{
	if(level.round_number <= 9)
		return;
		
	if(!self bot_should_pack())
		return;
		
	if(!isDefined(self.bot.pap_check_time) || GetTime() > self.bot.pap_check_time)
	{
		self.bot.pap_check_time = GetTime() + 500;
		
		machines = GetEntArray("zombie_vending", "targetname");
		
		foreach(pack in machines)
		{
			if(pack.script_noteworthy != "specialty_weapupgrade" && pack.script_noteworthy != "pack_a_punch" && !isDefined(pack.is_pap))
				continue;
				
			if(Distance(pack.origin, self.origin) < 99999 && self.score >= 5000)
			{
				weapon = self GetCurrentWeapon();
				upgrade_name = maps\mp\zombies\_zm_weapons::get_upgrade_weapon(weapon);
				
				// Check if weapon is already upgraded (prevent double PaP)
				if(weapon == upgrade_name)
					return;
				
				self maps\mp\zombies\_zm_score::minus_to_player_score(5000);
				self TakeAllWeapons();
				self GiveWeapon(upgrade_name);
				self SetSpawnWeapon(upgrade_name);
				return;
			}
		}
	}
}

bot_buy_box()
{
	// Don't spend points on the box if they have wonder weapons
	if(self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("raygun_mark2_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("slipgun_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("slowgun_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("blundergat_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("blundersplat_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("staff_water_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("staff_fire_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("staff_lightning_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("staff_air_zm"))
	{
		self CancelGoal("boxBuy");
		return;
	}
	
    // Only try to access the box on a timed interval
    if (!isDefined(self.bot.box_purchase_time) || GetTime() > self.bot.box_purchase_time)
    {
        self.bot.box_purchase_time = GetTime() + 1500; // Try every 1.5 seconds

        // Don't try if we're in last stand
        if(self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
            return;

        // Don't try if we can't afford it (use 950 cost)
        if(self.score < 950)
            return;

        // Check global box usage tracker to prevent multiple bots using box simultaneously
        if(isDefined(level.box_in_use_by_bot) && level.box_in_use_by_bot != self)
        {
            // Another bot is using the box, wait your turn
            return;
        }
		
		if (level.round_number <= 1)
		{
			if (isDefined(self.bot.last_box_interaction_time) && (GetTime() - self.bot.last_box_interaction_time < 15000))
				return;
		}
		else if (level.round_number <= 8)
		{
			if (isDefined(self.bot.last_box_interaction_time) && (GetTime() - self.bot.last_box_interaction_time < 45000))
				return;
		}
		else if (level.round_number <= 15)
		{
			if (isDefined(self.bot.last_box_interaction_time) && (GetTime() - self.bot.last_box_interaction_time < 180000))
				return;
		}
		else if (level.round_number <= 25)
		{
			if (isDefined(self.bot.last_box_interaction_time) && (GetTime() - self.bot.last_box_interaction_time < 300000))
				return;
		}
		else if (level.round_number <= 30)
		{
			if (isDefined(self.bot.last_box_interaction_time) && (GetTime() - self.bot.last_box_interaction_time < 600000))
				return;
		}

        // --- Start: Logic to grab from an already open box (Kept from original) ---
        if(!isDefined(self.bot.grab_weapon_time) || GetTime() > self.bot.grab_weapon_time)
        {
            activeBox = undefined;
            closestOpenBoxDist = 99999;

            // Find the closest open box with a weapon ready to grab
            foreach(box in level.chests)
            {
                if(!isDefined(box))
                    continue;

                // Check if the box is open with a weapon ready
                if(isDefined(box._box_open) && box._box_open &&
                   isDefined(box.weapon_out) && box.weapon_out &&
                   isDefined(box.zbarrier) && isDefined(box.zbarrier.weapon_model))
                {
                    dist = Distance(self.origin, box.origin);
                    if(dist < closestOpenBoxDist)
                    {
                        // Check if path exists before considering it
                        if(FindPath(self.origin, box.origin, undefined, 0, 1))
                        {
                            closestOpenBoxDist = dist;
                            activeBox = box;
                        }
                    }
                }
            }

            // If we found an open box with a weapon
            if(isDefined(activeBox))
            {
                // If close enough, grab it
                if(closestOpenBoxDist < 175) // Interaction distance
                {
                    // Cancel any existing goal
                    if(self hasgoal("boxGrab") || self hasgoal("boxBuy"))
                    {
                        self cancelgoal("boxGrab");
                        self cancelgoal("boxBuy");
                    }

                    // Mark that we're trying to grab the weapon
                    self.bot.grab_weapon_time = GetTime() + 5000; // Cooldown before trying to grab again

                    // Look at the box
                    aim_offset = (randomfloatrange(-5,5), randomfloatrange(-5,5), randomfloatrange(-5,5));
                    self lookat(activeBox.origin + aim_offset);
                    wait randomfloatrange(0.3, 0.8); // Simulate reaction

                    // Re-validate box state
                    if(!isDefined(activeBox) || !isDefined(activeBox._box_open) || !activeBox._box_open ||
                       !isDefined(activeBox.weapon_out) || !activeBox.weapon_out ||
                       self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
                    {
                        return; // State changed, abort grab
                    }

                    // --- Weapon Decision Logic ---
                    currentWeapon = self GetCurrentWeapon();
                    boxWeapon = activeBox.zbarrier.weapon_string;
                    shouldTake = bot_should_take_weapon(boxWeapon, currentWeapon);
                    // --- End Weapon Decision Logic ---

					if(shouldTake)
					{
						// Commit to grab
						self cancelgoal("boxBuy");
						self cancelgoal("boxGrab");

						self lookat(activeBox.origin);
						wait 0.2;

						for(attempt = 0; attempt < 3; attempt++)
						{
							if(!isDefined(activeBox) || !activeBox._box_open || !activeBox.weapon_out)
								break;

							if(isDefined(activeBox.unitrigger_stub) && isDefined(activeBox.unitrigger_stub.trigger))
								activeBox.unitrigger_stub.trigger notify("trigger", self);
							else
								activeBox notify("trigger", self);

							wait 0.25;
						}
					}
                    else
                    {
                        // Bot decided not to take, add longer cooldown
                        self.bot.grab_weapon_time = GetTime() + 7000;
                    }

                    // Set last interaction time
                    self.bot.last_box_interaction_time = GetTime();
                    if(isDefined(activeBox.chest_user) && activeBox.chest_user == self)
                        activeBox.chest_user = undefined;

                    return; // Finished grab attempt
                }
                // If not close enough, move towards it
                else if (closestOpenBoxDist < 99999) // Detection range
                {
                    if(!self hasgoal("boxGrab")) // Only set goal if not already moving
                    {
                         self AddGoal(activeBox.origin, 175, 3, "boxGrab"); // High priority grab goal
                    }
                    return; // Wait until closer
                }
            }
        }
        // --- End: Logic to grab from an already open box ---


        // --- Start: Logic to buy a new box spin (Based on user request) ---

        // Check if we already paid and are waiting for the animation
        if(is_true(self.bot.waiting_for_box_animation))
        {
            // Add a timeout check in case monitor thread fails
            if((!isDefined(self.bot.box_payment_time) || (GetTime() - self.bot.box_payment_time > 10000))) // 10 second timeout
            {
                self.bot.waiting_for_box_animation = undefined;
                self.bot.current_box = undefined;
				self.bot.is_using_box = undefined;
                if(level.box_in_use_by_bot == self)
                    level.box_in_use_by_bot = undefined;
            }
            else
            {
                return; // Still waiting, do nothing
            }
        }

        // Make sure boxes exist and index is valid
        if(!isDefined(level.chests) || level.chests.size == 0 || !isDefined(level.chest_index) || level.chest_index >= level.chests.size)
            return;

        // Get the currently active box based on index
        current_box = level.chests[level.chest_index];
        if(!isDefined(current_box) || !isDefined(current_box.origin))
            return;

        // Check if box is available (not open, not moving, not locked, not teddy'd)
        if(is_true(current_box._box_open) ||
           flag("moving_chest_now") ||
           (isDefined(current_box.is_locked) && current_box.is_locked) ||
           (isDefined(current_box.chest_user) && current_box.chest_user != self) ||
           (isDefined(level.mystery_box_teddy_locations) && array_contains(level.mystery_box_teddy_locations, current_box.origin))) // Avoid teddy locations
        {
            return; // Box is not available
        }

        dist = Distance(self.origin, current_box.origin);
        interaction_dist = 175; // Distance to interact
        detection_dist = 99999; // Distance to start moving towards

        // Only try to use box if we have enough points and it's reasonably close
        if(self.score >= 950 && dist < detection_dist)
        {
            // Check if a path exists
            if(FindPath(self.origin, current_box.origin, undefined, 0, 1))
            {
                // Move to box if not already close enough
                if(dist > interaction_dist)
                {
                    // Only set goal if not already pathing to this box
                    if(!self hasgoal("boxBuy") || Distance(self GetGoal("boxBuy"), current_box.origin) > 175)
                    {
                        self AddGoal(current_box.origin, 175, 2, "boxBuy"); // Normal priority buy goal
                    }
                    return; // Wait until closer
                }

                // --- Use the box when close enough ---
                if(self hasgoal("boxBuy")) // Cancel movement goal upon arrival
                    self cancelgoal("boxBuy");

                // Look at the box
                aim_offset = (randomfloatrange(-5,5), randomfloatrange(-5,5), randomfloatrange(-5,5));
                self lookat(current_box.origin + aim_offset);
                wait randomfloatrange(0.5, 1.0); // Simulate reaction

                // Final check before spending points
                if(self.score < 950 ||
                   is_true(current_box._box_open) ||
                   flag("moving_chest_now") ||
                   (isDefined(current_box.is_locked) && current_box.is_locked) ||
                   (isDefined(current_box.chest_user) && current_box.chest_user != self) ||
                   self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
                {
                    return; // Conditions changed, abort
                }

                // Set global usage flag
                level.box_in_use_by_bot = self;
                current_box.chest_user = self; // Mark user on the box

                // Store state for monitoring
                self.bot.current_box = current_box;
				self.bot.is_using_box = true;
                self.bot.waiting_for_box_animation = true;
                self.bot.box_payment_time = GetTime();

                // Deduct points
                self maps\mp\zombies\_zm_score::minus_to_player_score(0);
                self PlaySound("zmb_cha_ching");

                // Set cooldown times
                self.bot.last_box_interaction_time = GetTime();

                // Trigger the box using multiple methods for reliability
                if(isDefined(current_box.unitrigger_stub) && isDefined(current_box.unitrigger_stub.trigger))
                    current_box.unitrigger_stub.trigger notify("trigger", self);
                else if(isDefined(current_box.use_trigger))
                     current_box.use_trigger notify("trigger", self);
                else
                    current_box notify("trigger", self); // Generic trigger

                // Start the monitor thread (handles waiting and weapon grabbing/decision)
                self thread bot_monitor_box_animation(current_box);

                return; // Monitor thread will handle the rest
            }
        }

        // Clean up any remaining box goal if we decided not to proceed
        if(self hasgoal("boxBuy") || self hasgoal("boxGrab"))
        {
            self cancelgoal("boxBuy");
            self cancelgoal("boxGrab");
        }
        // --- End: Logic to buy a new box spin ---
    }
}

bot_monitor_box_animation(box)
{
    self endon("disconnect");
    self endon("death");
    
    // Make sure this bot is removed from the usage tracker when done or disconnected
    self endon("box_usage_complete");
    
    // Wait for the box to start opening animation
    started = false;
    
    // Check for up to 3 seconds
    for(i = 0; i < 15; i++) 
    {
        wait 0.2;
        
        // Box is no longer valid
        if(!isDefined(box))
        {
            self.bot.waiting_for_box_animation = undefined;
            self.bot.current_box = undefined;
			self.bot.is_using_box = undefined;
            // Clear global usage flag when done
            if(level.box_in_use_by_bot == self)
                level.box_in_use_by_bot = undefined;
            self notify("box_usage_complete");
            return;
        }
        
        // Box has started opening
        if(isDefined(box._box_open) && box._box_open)
        {
            started = true;
            // Stay in the monitoring loop to wait for weapon
            break;
        }
    }
    
    // Box animation didn't start after payment
    if(!started)
    {
        self.bot.waiting_for_box_animation = undefined;
        self.bot.current_box = undefined;
		self.bot.is_using_box = undefined;
        // Clear global usage flag when done
        if(level.box_in_use_by_bot == self)
            level.box_in_use_by_bot = undefined;
        self notify("box_usage_complete");
        return;
    }
    
    // Now wait for the weapon to appear
    weaponAppeared = false;
    
    // Wait up to 6 more seconds for the weapon
    for(i = 0; i < 30; i++)
    {
        wait 0.2;
        
        // Box is no longer valid or has closed
        if(!isDefined(box) || !isDefined(box._box_open) || !box._box_open)
        {
            self.bot.waiting_for_box_animation = undefined;
            self.bot.current_box = undefined;
			self.bot.is_using_box = undefined;
            // Clear global usage flag when done
            if(level.box_in_use_by_bot == self)
                level.box_in_use_by_bot = undefined;
            self notify("box_usage_complete");
            return;
        }
        
        // Check if the weapon is ready
        if(isDefined(box.weapon_out) && box.weapon_out && 
           isDefined(box.zbarrier) && isDefined(box.zbarrier.weapon_model))
        {
            weaponAppeared = true;
            break;
        }
        
        // Check if the box is showing a teddy bear
        if(isDefined(box.zbarrier) && isDefined(box.zbarrier.state) && box.zbarrier.state == "teddy_bear")
        {
            // Remember this position had a teddy to prevent future use
            if(!isDefined(level.mystery_box_teddy_locations))
                level.mystery_box_teddy_locations = [];
                
            if(!array_contains(level.mystery_box_teddy_locations, box.origin))
                level.mystery_box_teddy_locations[level.mystery_box_teddy_locations.size] = box.origin;
                
            // No weapon is coming, so exit
            self.bot.waiting_for_box_animation = undefined;
            self.bot.current_box = undefined;
			self.bot.is_using_box = undefined;
            if(level.box_in_use_by_bot == self)
                level.box_in_use_by_bot = undefined;
            self notify("box_usage_complete");
            return;
        }
    }
    
    // Clear waiting flags
    self.bot.waiting_for_box_animation = undefined;
    
    // If weapon didn't appear, stop monitoring
    if(!weaponAppeared)
    {
        self.bot.current_box = undefined;
        // Clear global usage flag when done
        if(level.box_in_use_by_bot == self)
            level.box_in_use_by_bot = undefined;
        self notify("box_usage_complete");
        return;
    }
    
    // Wait a random amount of time before grabbing
    wait randomfloatrange(0.5, 1.5);
    
    // Make sure the box and player are still valid
    if(!isDefined(box) || 
       !isDefined(box._box_open) || 
       !box._box_open ||
       !isDefined(box.weapon_out) ||
       !box.weapon_out ||
       self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
    {
        self.bot.current_box = undefined;
        // Clear global usage flag when done
        if(level.box_in_use_by_bot == self)
            level.box_in_use_by_bot = undefined;
        self notify("box_usage_complete");
        return;
    }
    
    // Get weapon info for decision making
    boxWeapon = undefined;
    if(isDefined(box.zbarrier) && isDefined(box.zbarrier.weapon_string))
    {
        boxWeapon = box.zbarrier.weapon_string;
    }
    
    currentWeapon = self GetCurrentWeapon();
    shouldTake = bot_should_take_weapon(boxWeapon, currentWeapon);
    
    // Look at the box again with slight jitter
    aim_offset = (randomfloatrange(-5,5), randomfloatrange(-5,5), randomfloatrange(-5,5));
    self lookat(box.origin + aim_offset);
    
	// Try to grab the weapon based on decision
	if(shouldTake)
	{
		// Commit to grab (stop movement/goals)
		self cancelgoal("boxBuy");
		self cancelgoal("boxGrab");

		// Face the box directly (no jitter now)
		self lookat(box.origin);

		// Small stabilization delay
		wait 0.2;

		// Retry grab multiple times for reliability
		for(attempt = 0; attempt < 3; attempt++)
		{
			if(!isDefined(box) || !box._box_open || !box.weapon_out)
				break;

			if(isDefined(box.unitrigger_stub) && isDefined(box.unitrigger_stub.trigger))
				box.unitrigger_stub.trigger notify("trigger", self);
			else
				box notify("trigger", self);

			wait 0.25;
		}
	}
    
    // Clear the reference to this box
    self.bot.current_box = undefined;
    
    // Clear box user reference
    if(isDefined(box.chest_user) && box.chest_user == self)
        box.chest_user = undefined;
    
    // Clear global usage flag when done
    if(level.box_in_use_by_bot == self)
        level.box_in_use_by_bot = undefined;
    
	self.bot.is_using_box = undefined;
    self notify("box_usage_complete");
}

// Improved weapon selection logic
bot_should_take_weapon(boxWeapon, currentWeapon)
{
    if(!isDefined(boxWeapon))
        return false;
    
    // Check if we already have this weapon
    if(self HasWeapon(boxWeapon))
        return false;
        
    // Always take wonder weapons
    if(IsSubStr(boxWeapon, "ray_gun") || 
       IsSubStr(boxWeapon, "raygun_mark2") || 
	   IsSubStr(boxWeapon, "slipgun") || 
	   IsSubStr(boxWeapon, "slowgun") || 
	   IsSubStr(boxWeapon, "blundergat") || 
	   IsSubStr(boxWeapon, "staff_water") || 
	   IsSubStr(boxWeapon, "staff_fire") || 
	   IsSubStr(boxWeapon, "staff_air") || 
	   IsSubStr(boxWeapon, "staff_lightning"))
    {
        return true;
    }
    
    // Define weapon tiers for better decision making
    tier1_weapons = array("staff_water", "staff_air", "staff_fire", "staff_lightning", "blundersplat", "blundergat", "slipgun", "slowgun", "raygun_mark2", "ray_gun");
	tier2_weapons = array("titus6", "usrpg", "srm1216", "svu", "minigun_alcatraz", "m1911_upgraded", "c96_upgraded");
	tier3_weapons = array("saiga12", "as50", "barretm82", "lsat", "hamr", "mk48", "rpd", "mg08", "rnma");
    tier4_weapons = array("dsr50", "scar", "hk416", "an94", "tar21", "galil", "ak47", "mp44", "peacekeeper", "evoskorpion", "pdw57", "mp7", "vector", "thompson", "fivesevendw");
    tier5_weapons = array("ksg", "870mcs", "sa58", "type95", "xm8", "sig556", "m16", "insas", "mp5k", "ak74u_extclip", "mp40", "beretta93r_extclip");
    tier6_weapons = array("fnfal", "qcw05", "ak74u", "beretta93r", "fiveseven", "judge", "python");
	tier7_weapons = array("m32", "rottweil72", "metalstorm_mms", "ballista", "saritch", "m14", "uzi", "m1911", "c96", "knife_ballistic");
    
    // Track if current weapon is in specific tier
    currentIsTier1 = false;
    currentIsTier2 = false;
    currentIsTier3 = false;
	currentIsTier4 = false;
	currentIsTier5 = false;
	currentIsTier6 = false;
	currentIsTier7 = false;
    
    // Check current weapon tier
    foreach(weapon in tier1_weapons)
    {
        if(IsSubStr(currentWeapon, weapon))
        {
            currentIsTier1 = true;
            break;
        }
    }
    
    if(!currentIsTier1)
    {
        foreach(weapon in tier2_weapons)
        {
            if(IsSubStr(currentWeapon, weapon))
            {
                currentIsTier2 = true;
                break;
            }
        }
    }
    
    if(!currentIsTier1 && !currentIsTier2)
    {
        foreach(weapon in tier3_weapons)
        {
            if(IsSubStr(currentWeapon, weapon))
            {
                currentIsTier3 = true;
                break;
            }
        }
    }
	
	if(!currentIsTier1 && !currentIsTier2 && !currentIsTier3)
    {
        foreach(weapon in tier4_weapons)
        {
            if(IsSubStr(currentWeapon, weapon))
            {
                currentIsTier4 = true;
                break;
            }
        }
    }
	
	if(!currentIsTier1 && !currentIsTier2 && !currentIsTier3 && !currentIsTier4)
    {
        foreach(weapon in tier5_weapons)
        {
            if(IsSubStr(currentWeapon, weapon))
            {
                currentIsTier5 = true;
                break;
            }
        }
    }
	
	if(!currentIsTier1 && !currentIsTier2 && !currentIsTier3 && !currentIsTier4 && !currentIsTier5)
    {
        foreach(weapon in tier6_weapons)
        {
            if(IsSubStr(currentWeapon, weapon))
            {
                currentIsTier6 = true;
                break;
            }
        }
    }

	if(!currentIsTier1 && !currentIsTier2 && !currentIsTier3 && !currentIsTier4 && !currentIsTier5 && !currentIsTier6)
    {
        foreach(weapon in tier7_weapons)
        {
            if(IsSubStr(currentWeapon, weapon))
            {
                currentIsTier7 = true;
                break;
            }
        }
    }
    
    // Don't take bugged weapons or useless weapons
    if(IsSubStr(boxWeapon, "time_bomb") || 
	   IsSubStr(boxWeapon, "emp_grenade") || 
	   IsSubStr(boxWeapon, "cymbal_monkey") || 
	   IsSubStr(boxWeapon, "knife_ballistic"))
    {
        return (randomfloat(1) < 0); // 0% chance
    }
	
    // Check box weapon tier
    boxIsTier2 = false;
    boxIsTier3 = false;
    boxIsTier4 = false;
	boxIsTier5 = false;
	boxIsTier6 = false;
	boxIsTier7 = false;
    
    foreach(weapon in tier2_weapons)
    {
        if(IsSubStr(boxWeapon, weapon))
        {
            boxIsTier2 = true;
            break;
        }
    }
    
    if(!boxIsTier2)
    {
        foreach(weapon in tier3_weapons)
        {
            if(IsSubStr(boxWeapon, weapon))
            {
                boxIsTier3 = true;
                break;
            }
        }
    }
    
    if(!boxIsTier2 && !boxIsTier3)
    {
        foreach(weapon in tier4_weapons)
        {
            if(IsSubStr(boxWeapon, weapon))
            {
                boxIsTier4 = true;
                break;
            }
        }
    }
	
	if(!boxIsTier2 && !boxIsTier3 && !boxIsTier4)
    {
        foreach(weapon in tier5_weapons)
        {
            if(IsSubStr(boxWeapon, weapon))
            {
                boxIsTier5 = true;
                break;
            }
        }
    }
	
	if(!boxIsTier2 && !boxIsTier3 && !boxIsTier4 && !boxIsTier5)
    {
        foreach(weapon in tier6_weapons)
        {
            if(IsSubStr(boxWeapon, weapon))
            {
                boxIsTier6 = true;
                break;
            }
        }
    }

	if(!boxIsTier2 && !boxIsTier3 && !boxIsTier4 && !boxIsTier5 && !boxIsTier6)
    {
        foreach(weapon in tier7_weapons)
        {
            if(IsSubStr(boxWeapon, weapon))
            {
                boxIsTier7 = true;
                break;
            }
        }
    }
    
    // Decision logic based on tiers and round number
    if(currentIsTier1)
    {
        // Already have a wonder weapon, only take another if it's a different one
        // For example, allow taking blundergat when already having raygun
        foreach(weapon in tier1_weapons)
        {
            if(IsSubStr(boxWeapon, weapon) && !IsSubStr(currentWeapon, weapon))
            {
                // 90% chance to take another wonder weapon
                return (randomfloat(1) < 0.9);
            }
        }
        return false; // Don't replace wonder weapon with non-wonder weapon
    }
    
    // Have tier 2 weapon already
    if(currentIsTier2)
    {
        if(boxIsTier2)
        {
            // 20% chance to swap between tier 2 weapons for variety
            return (randomfloat(1) < 0.2);
        }
        else if(boxIsTier3 || boxIsTier4 || boxIsTier5 || boxIsTier6)
        {
            // Never downgrade from tier 2
            return (randomfloat(1) < 0);
        }
        return (randomfloat(1) < 0);
    }
    
    // Have tier 3 weapon already
    if(currentIsTier3)
    {
        if(boxIsTier2)
        {
            // Always upgrade to tier 2
            return true;
        }
        else if(boxIsTier3)
        {
            // 60% chance to swap between tier 3 for variety
            return (randomfloat(1) < 0.6);
        }
        else if(boxIsTier4)
        {
            // Don't downgrade
            return (randomfloat(1) < 0);
        }
		else if(boxIsTier5)
        {
            // Don't downgrade
            return (randomfloat(1) < 0);
        }
		else if(boxIsTier6)
        {
            // Don't downgrade
            return (randomfloat(1) < 0);
        }
		else if(boxIsTier7)
        {
            // Don't downgrade
            return (randomfloat(1) < 0);
        }
    }
    
	    // Round-based logic - in early rounds take most weapons
    if(level.round_number <= 8)
    {
        return true;
    }
    // Mid rounds - prefer at least tier 3
    else if(level.round_number <= 15)
    {
        if(boxIsTier2 || boxIsTier3)
            return true;
        else
            return (randomfloat(1) < 0.5); // 50% chance for other weapons
    }
    // Late rounds - generally only take tier 2
    else
    {
        if(boxIsTier2)
            return true;
        else if(boxIsTier3)
            return (randomfloat(1) < 0.7); // 70% chance for tier 3
        else
            return (randomfloat(1) < 0.2); // 20% chance for other weapons
    }
    // Default case - 50/50 chance
    return (randomfloat(1) < 0.5);
}

bot_buy_wallbuy()
{
	self endon("death");
	self endon("disconnect");
	level endon("end_game");
	
	weapon = self GetCurrentWeapon();
	upgrade_name = maps\mp\zombies\_zm_weapons::get_upgrade_weapon(weapon);
	weaponToBuy = undefined;
	wallbuys = array_randomize(level._spawned_wallbuys);
	
	if(level.round_number <= 2)
		return;
	
	if(self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("870mcs_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("saiga12_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("ksg_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("srm1216_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("mp40_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("ak74u_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("ak74u_extclip_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("thompson_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("mp5k_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("pdw57_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("evoskorpion_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("an94_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("galil_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("scar_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("hk416_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("mp44_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("tar21_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("type95_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("ak47_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("m16_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("mg08_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("hamr_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("lsat_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("rpd_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("minigun_alcatraz_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("usrpg_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("m32_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("barretm82_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("dsr50_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("svu_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("judge_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("python_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("rnma_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("fivesevendw_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("metalstorm_mms_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("titus6_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("insas_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("vector_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("mp7_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("peacekeeper_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("sig556_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("sa58_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("mk48_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("as50_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("ray_gun_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("raygun_mark2_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("slipgun_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("slowgun_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("blundergat_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("blundersplat_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("staff_water_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("staff_fire_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("staff_lightning_zm") || 
	self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade("staff_air_zm") || 
	self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
	{
		self CancelGoal("weaponBuy");
		return;
	}
	foreach(wallbuy in wallbuys)
	{
		if(Distance(wallbuy.origin, self.origin) < 500 && wallbuy.trigger_stub.cost <= self.score && bot_best_gun(wallbuy.trigger_stub.zombie_weapon_upgrade, weapon) && FindPath(self.origin, wallbuy.origin, undefined, 0, 1) && weapon != wallbuy.trigger_stub.zombie_weapon_upgrade && !is_offhand_weapon(wallbuy.trigger_stub.zombie_weapon_upgrade))
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
	if(!isdefined(weaponToBuy))
		return;
	self AddGoal(weaponToBuy.origin, 99999, 2, "weaponBuy");
	//IPrintLn(weaponToBuy.zombie_weapon_upgrade);
	while(!self AtGoal("weaponBuy") && !Distance(self.origin, weaponToBuy.origin) < 99999)
	{
		wait 1;
		if(self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
		{
			self cancelgoal("weaponBuy");
			return;
		}
	}
	
	self cancelgoal("weaponBuy");
	self maps\mp\zombies\_zm_score::minus_to_player_score(weaponToBuy.trigger_stub.cost);
	self TakeAllWeapons();
	self GiveWeapon(weaponToBuy.trigger_stub.zombie_weapon_upgrade);
	self SetSpawnWeapon(weaponToBuy.trigger_stub.zombie_weapon_upgrade);
	//IPrintLn("Bot Bought Weapon");
}

bot_best_gun(buyingweapon, currentweapon)
{
    // Priority weapons based on round number
    if(level.round_number >= 10)
    {
        priority_weapons = array("lsat_zm", "an94_zm", "mp44_zm", "870mcs_zm", "m16_zm", "thompson_zm", "mp40_zm", "mp5k_zm", "pdw57_zm", "ak74u_zm");
        foreach(weapon in priority_weapons)
        {
            if(buyingweapon == weapon)
                return true;
        }
    }
    else if(level.round_number >= 5)
    {
        if(buyingweapon == "pdw57_zm" || buyingweapon == "mp5k_zm")
            return true;
    }
    else
    {
        if(buyingweapon == "mp5k_zm")
            return true;
    }
	
    // Consider weapon cost as fallback
    if(maps\mp\zombies\_zm_weapons::get_weapon_cost(buyingweapon) > maps\mp\zombies\_zm_weapons::get_weapon_cost(currentweapon))
        return true;
        
    return false;
}

bot_buy_door()
{
    if (!isDefined(self.bot.door_purchase_time) || GetTime() > self.bot.door_purchase_time)
    {
        // Only attempt to purchase doors every 5 seconds
        self.bot.door_purchase_time = GetTime() + 5000;

        // Get all potential doors
        doors = getEntArray("zombie_door", "targetname");
        
        // Find the closest valid door
        closestDoor = undefined;
        closestDist = 300; // Reduced max distance for realism

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
            dist = Distance(self.origin, door.origin);
            if(dist < closestDist)
            {
                closestDoor = door;
                closestDist = dist;
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
        // Only attempt to clear debris every 4 seconds
        self.bot.debris_purchase_time = GetTime() + 4000;
        
        // Get all potential debris piles
        debris = getEntArray("zombie_debris", "targetname");
        
        if(debris.size == 0)
            return false;
        
        // Find the closest valid debris pile
        closestDebris = undefined;
        closestDist = 500; // Reduced max distance for realism
        
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
            
            // Check distance first
            dist = Distance(self.origin, pile.origin);
            
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
                nearbyNodes = ArraySort(nearbyNodes, pile.origin);
                
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
            
            if(dist < closestDist)
            {
                closestDebris = pile;
                closestDist = dist;
            }
        }
        
        // If we found valid debris, try to clear it
        if(isDefined(closestDebris))
        {
            // Move toward the debris if not close enough
            if(closestDist > 300) // Reduced interaction range
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

bot_should_pack()
{
	if(maps\mp\zombies\_zm_weapons::can_upgrade_weapon(self GetCurrentWeapon()))
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

bot_give_ammo()
{
	self endon("disconnect");
	self endon("death");
	level endon("game_ended");
	
	for(;;)
	{
		primary_weapons = self GetWeaponsListPrimaries();
		j=0;
		while(j<primary_weapons.size)
		{
			self GiveMaxAmmo(primary_weapons[j]);
			j++;
		}
		wait 1;
	}
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
		self thread bot_perks_origins();
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

bot_perks()
{
	self endon("disconnect");
	self endon("death");
	
	wait 1;
	while(1)
	{
		self SetNormalHealth(6000);
		self SetmaxHealth(6000);
		self waittill("player_revived");
	}
}

bot_perks_origins()
{
	self endon("disconnect");
	self endon("death");
	
	if (getDvar("mapname") == "zm_tomb")
	{
		self SetPerk("specialty_rof");
		self SetPerk("specialty_flakjacket");
		self SetPerk("specialty_deadshot");
		self waittill("player_revived");
	}
}

bot_update_follow_host()
{
	if(self AddGoal(get_players()[0].origin, 75, 1, "wander") * getDvarInt("bots_stay"))
	{
		self CancelGoal("wander");
	}
}

bot_update_wander()
{
    players = get_players();
    player = players[0];

    location = get_random_walkable_location(player.origin, 1000, self);

    self AddGoal(location, 100, 1, "wander");

    if(distance(self.origin, player.origin) > 1000)
    {
        self AddGoal(player.origin, 100, 1, "wander");
        return;
    }
}

bot_update_lookat()
{
	path = 0;
	if (isDefined(self getlookaheaddir()))
	{
		path = 1;
	}
	if (!path && getTime() > self.bot.update_idle_lookat)
	{
		origin = bot_get_look_at();
		if (!isDefined(origin))
		{
			return;
		}
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
		if (isDefined(node) && distancesquared(self.origin, node.origin) > 1024)
		{
			return node.origin;
		}
	}
	spawn = self getgoal("wander");
	if (isDefined(spawn))
	{
		node = getvisiblenode(self.origin, spawn);
	}
	if (isDefined(node) && distancesquared(self.origin, node.origin) > 1024)
	{
		return node.origin;
	}
	return undefined;
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
	if (!self atgoal() && distance2dsquared(self.bot.previous_origin, self.origin) < 256)
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
				if (!bot_failsafe_node_valid(nearest, nodes[ i ]))
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