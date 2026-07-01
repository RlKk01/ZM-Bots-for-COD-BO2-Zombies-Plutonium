init()
{
	level thread onplayerconnect();
}

onplayerconnect()
{
	self endon("disconnect");
	
	level endon("end_game");
	
	for(;;)
	{
		level waittill("connected", player);
		
		player thread onplayerspawned();
	}
}

onplayerspawned()
{
	self endon("disconnect");
	
	level endon("end_game");
	
	for(;;)
	{
		self waittill("spawned_player");
		
		self thread maxammo();
	}
}

maxammo()
{
	self endon("disconnect");
	
	level endon("end_game");
	
	for(;;) 
	{
		self waittill("zmb_max_ammo");
		
		weaps = self getweaponslist(1);
		
		foreach(weap in weaps) 
		{
			self setweaponammoclip(weap, weaponclipsize(weap));
		}
	}
}