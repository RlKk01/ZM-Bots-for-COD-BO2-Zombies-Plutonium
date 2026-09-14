#include common_scripts\utility;

#include scripts\zm\zm_bo2_bots;
#include scripts\zm\zm_bo2_bots_combat;

init()
{
	level.bot_dmg_norm_baseline = [];

	level.bot_dmg_norm_original_callback = level.callbackactordamage;
	
	level.callbackactordamage = ::bot_dmg_norm_actor_damage_override;
}

bot_dmg_norm_actor_damage_override(inflictor, attacker, damage, flags, meansofdeath, weapon, vpoint, vdir, shitloc, psoffsettime, boneindex)
{
	damage = bot_dmg_norm_get_scaled_damage(attacker, damage, meansofdeath);

	return [[level.bot_dmg_norm_original_callback]](inflictor, attacker, damage, flags, meansofdeath, weapon, vpoint, vdir, shitloc, psoffsettime, boneindex);
}

bot_dmg_norm_get_scaled_damage(attacker, damage, meansofdeath)
{
	if(meansofdeath == "MOD_MELEE")
		return damage;

	if(!isdefined(attacker) || !isplayer(attacker))
		return damage;

	if(!isdefined(attacker.pers["isbot"]) || !attacker.pers["isbot"])
		return damage;

	if(!isdefined(self.team) || self.team != level.zombie_team)
		return damage;

	if(!isdefined(self.health) || !isdefined(self.maxhealth) || self.maxhealth <= 0)
		return damage;

	if(isdefined(self.animname) && (self.animname == "brutus_zm" || self.animname == "panzer_zm" || self.animname == "avogadro_zm"))
		return damage;
	
	if(!isdefined(level.round_number) || level.round_number < 10)
		return damage;
	
	species_key = bot_dmg_norm_get_species_key();

	if(!isdefined(level.bot_dmg_norm_baseline[species_key]))
	{
		level.bot_dmg_norm_baseline[species_key] = self.maxhealth;
	}

	baseline = level.bot_dmg_norm_baseline[species_key];

	if(!isdefined(baseline) || baseline <= 0)
		return damage;

	scale = self.maxhealth / baseline;

	scaled_damage = int(damage * scale + 0.5);

	if(scaled_damage < 1)
		scaled_damage = 1;

	return scaled_damage;
}

bot_dmg_norm_get_species_key()
{
	if(isdefined(self.model))
		return self.model;

	if(isdefined(self.classname))
		return self.classname;

	return "default";
}