#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;

#include maps\mp\zm_tomb_utility;

main()
{
	replacefunc(maps\mp\zm_tomb_utility::check_solo_status, ::check_solo_status_new);
}

check_solo_status_new()
{
    level.is_forever_solo_game = 1;
}