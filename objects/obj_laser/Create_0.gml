/// Laser bolt: a short, fast streak of light.
/// side "player" hits enemy ships and asteroids; side "enemy" hits fighters, collection ships and the station.
depth = -7;
side = "player";
damage = 1;
dir = 0;
life = 45;   // frames
len = 22;    // length of the drawn streak
bounces = RUBBER_BOUNCES; // ricochets left off rubber/armoured asteroids (scr_conditions)
ignore = noone;
ignore_t = 0;
refracted = false; // a beam split off a glass rock (scr_conditions GLASS_*): won't split again
