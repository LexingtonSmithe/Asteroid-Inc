depth = -5;
vx = 0;
vy = 0;
damage = 1;
radius = 2;
bounces = RUBBER_BOUNCES; // ricochets left off rubber/armoured asteroids (scr_conditions)
ricochets = 0;            // Harder Bullets: bounces left off anything it hits (rock or ship)
ignore = noone;           // the rock it just bounced off, skipped for a few frames
ignore_t = 0;
track = 0;     // balance log: 1 = main turret, 2 = rear turret, 0 = not counted (escort guns etc.)
scored = false; // already counted as a hit
