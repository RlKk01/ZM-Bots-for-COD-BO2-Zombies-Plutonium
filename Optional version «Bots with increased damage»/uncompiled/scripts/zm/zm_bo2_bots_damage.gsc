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
	// Never touch melee damage.
	if(meansofdeath == "MOD_MELEE")
		return damage;

	// Only normalize damage coming from our bots, not real players.
	if(!isdefined(attacker) || !isplayer(attacker))
		return damage;

	if(!isdefined(attacker.pers["isbot"]) || !attacker.pers["isbot"])
		return damage;

	// Only normalize damage against zombie-team AI.
	if(!isdefined(self.team) || self.team != level.zombie_team)
		return damage;

	if(!isdefined(self.health) || !isdefined(self.maxhealth) || self.maxhealth <= 0)
		return damage;

	// Leave boss-type units alone - their health is usually a fixed
	// encounter value, not the normal per-round scaling curve.
	if(isdefined(self.animname) && (self.animname == "brutus_zm" || self.animname == "panzer_zm" || self.animname == "avogadro_zm"))
		return damage;
	
	// Only normalize from round 10 onward. Rounds 1-9 use the flat
	// +100/round health curve, which is fine at vanilla damage. Round 10+
	// switches to the 1.1x/round exponential curve, which is what we
	// actually want to cancel out.
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
	// Bucket by whatever most reliably distinguishes enemy types on
	// your setup. Model name is usually the most reliable signal
	// (regular zombie vs. dog vs. boss all use different models).
	if(isdefined(self.model))
		return self.model;

	if(isdefined(self.classname))
		return self.classname;

	return "default";
}