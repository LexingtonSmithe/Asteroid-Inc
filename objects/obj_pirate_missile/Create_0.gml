/// Flagship missile: launches off its flank, then curls round and homes on the station.
/// An obj_enemy child with a little health, so the turret, fighters and missiles can shoot it down.
event_inherited();
sprite_index = spr_missile; // art points up; Step turns it to the heading
image_blend = make_colour_rgb(255, 150, 90); // tints the white body orange so it reads as hostile
image_xscale = 1;    // also sizes the collision mask the turret and lasers hit
image_yscale = 1;
radius = 9;
setup(PMISSILE_HP * threat_hp_mult(false), 0);
charge_value = 1;
spd = 1.5;
turn_rate = 1.5;
dir = 0;            // set by the flagship
wait = 0;           // frames before it launches (a salvo ripples out)
damage = PMISSILE_DMG * threat_impact_mult();
life = 0;
trail = [];

destroyed = function() {
    fx_spark(x, y);
    sfx(snd_shield_hit, 0.3, 1.6, 0.1);
    add_charge(charge_value);
    instance_destroy();
};
