/// Repulsor pulse: a ring that expands all the way round the station. Each asteroid it
/// sweeps over has its heading turned a little away from the station (speed unchanged).
/// The turn scales with size: tiny rocks turn the full `deflect` degrees, big ones much less.
/// The station sets range and deflect.
depth = -8;
range   = 300;
deflect = 20;
r = STATION_RADIUS;     // current radius of the ring
grow = 12;              // px per frame
done = [];              // asteroids already turned by this ring
// Missile shockwaves (scr_pirates missile_blast) reuse this from the blast point:
start_r = STATION_RADIUS; // radius it starts from (its fade runs from here to range)
shove   = 0;              // px/frame push given to enemy ships it sweeps over (0 = rocks only)
ring_w  = 18;             // drawn ring thickness
shoved  = [];             // enemy ships already pushed

// Share of `deflect` each size gets: tiny, small, medium, large. The boss barely notices.
size_turn = [1, 0.6, 0.35, 0.2];
#macro REP_BOSS_TURN 0.05
