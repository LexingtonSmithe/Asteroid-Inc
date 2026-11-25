// ---------------------------------------------------------------------------
// Enemies. Terms used for the tuning numbers below:
//   ENEMY_*            every enemy: collectors, hunters, attackers (and the pirate boss)
//   ENEMY_COLLECTOR_*  enemy collectors (obj_raider): steal loose loot and run
//   FIGHTER_*          hunters and attackers together (obj_raider_escort)
//   HUNTER_*           hunters only (purple): pairs locked on to one of your collectors
//   ATTACKER_*         attackers only (orange): go for the station
//   PLAYER_FIGHTER_*   your own fighters (obj_fighter), not enemies
// The pirate boss (obj_flagship) and the Pirate System day are tuned in scr_pirates.
//
//   - Enemy collectors appear from ENEMY_COLLECTOR_TIER. They fly in ENEMY_COLLECTOR_ENTRY
//     of the way before grabbing uncollected loot, then fly off-screen with it once full.
//     Shoot them down and the loot drops back into space. They come more often the more
//     loot is lying loose (ENEMY_COLLECTOR_LOOT_*).
//   - Fighters appear from FIGHTER_TIER, each kind on its own timer:
//       purple  hunter    in pairs, both locked on to one collection ship: they chase and
//                         orbit it firing, and leave once it is gone (destroyed or docked).
//                         More often the more collection ships you own.
//       orange  attacker  flies straight at the station and orbits it, firing.
//                         More often the more tree nodes you own.
//   - Health scales like asteroids (tier); shields grow with tier.
// ---------------------------------------------------------------------------

// --- Every enemy -----------------------------------------------------------------
#macro ENEMY_SHIELD_TIER   2     // shields grow for each tier above this...
#macro ENEMY_SHIELD_MAX    2     // ...up to this x HP

// --- Enemy collectors ------------------------------------------------------------
#macro ENEMY_COLLECTOR_TIER     2      // they appear from this tier
#macro ENEMY_COLLECTOR_FIRST    12     // seconds into the day before the first one
#macro ENEMY_COLLECTOR_INTERVAL 18     // seconds between them at ENEMY_COLLECTOR_TIER...
#macro ENEMY_COLLECTOR_INTERVAL_PER_TIER 3 // ...this many fewer for each tier above it...
#macro ENEMY_COLLECTOR_INTERVAL_MIN 8  // ...but never less than this (all before the loose-loot speed-up)
#macro ENEMY_COLLECTOR_HP       10     // before threat scaling (was 40: faster ones are harder to hit, so they are frailer)
#macro ENEMY_COLLECTOR_SHIELD   0.4    // shield = this x HP for each tier above ENEMY_SHIELD_TIER
#macro ENEMY_COLLECTOR_SPEED    6      // px per frame at ENEMY_COLLECTOR_TIER...
#macro ENEMY_COLLECTOR_SPEED_PER_TIER 0.4 // ...+ this per tier above it
#macro ENEMY_COLLECTOR_CAPACITY 6      // loot each can carry...
#macro ENEMY_COLLECTOR_CAPACITY_PER_TIER 4 // ...+ this per tier
// More loose loot, more of them: their timer runs (1 + loose value / LOOT_STEP) times as fast, capped
#macro ENEMY_COLLECTOR_LOOT_STEP 50     // 50 loose = twice as often
#macro ENEMY_COLLECTOR_LOOT_MAX  4      // at most this many times the base rate
#macro ENEMY_COLLECTOR_LOOT_SCAN 30     // frames between recounts of the loose loot
// They fly at least this share of the way from the screen edge to the station before they
// start looting, so they are always in range for a while
#macro ENEMY_COLLECTOR_ENTRY     0.4

// --- Fighters (hunters and attackers) --------------------------------------------
enum FIGHTER { HUNTER, ATTACKER, COUNT }
#macro FIGHTER_TIER      3      // fighters appear from this tier
#macro FIGHTER_TIER_RATE 0.85   // hunter and attacker intervals x this for each tier above FIGHTER_TIER
#macro FIGHTER_HP        15     // before threat scaling
#macro FIGHTER_SHIELD    0.2    // shield = this x HP for each tier above ENEMY_SHIELD_TIER
#macro FIGHTER_BURST     3      // lasers per burst
#macro FIGHTER_FIRE      100    // frames between bursts
#macro FIGHTER_RANGE     340    // px: they open fire inside this

// --- Hunters ---------------------------------------------------------------------
// A pair every HUNTER_INTERVAL seconds with one collection ship owned; each extra ship owned
// makes them come HUNTER_PER_SHIP more often (6 ships: 2.5x). They only launch while one of
// your ships is out (otherwise the timer waits).
#macro HUNTER_FIRST      20     // seconds into the day before the first pair
#macro HUNTER_INTERVAL   45
#macro HUNTER_PER_SHIP   0.3
#macro HUNTER_SPEED      6    // px per frame
#macro HUNTER_DAMAGE    3      // per laser, before threat_impact_mult()
#macro HUNTER_ORBIT     110    // px: they circle their collector at this distance
#macro HUNTER_TAIL       70     // px: how far behind a homeward-bound collector they follow (until it docks)
#macro HUNTER_RETARGET   60     // px: leaving after their collector is gone, they switch to any collector this close
#macro HUNTER_LOITER    4      // seconds an unlocked hunter waits for a collector before leaving

// --- Attackers -------------------------------------------------------------------
// One every ATTACKER_INTERVAL seconds, more often with every tree node owned
// (1 + nodes / ATTACKER_NODE_STEP times, capped at ATTACKER_MAX)
#macro ATTACKER_FIRST     25    // seconds into the day before the first one
#macro ATTACKER_INTERVAL  40
#macro ATTACKER_NODE_STEP 30    // 30 nodes owned = twice as often
#macro ATTACKER_MAX       4
#macro ATTACKER_SPEED     3.4   // px per frame
#macro ATTACKER_DAMAGE   15     // per laser, before threat_impact_mult() (the pirate boss's lasers are a multiple of this)
#macro ATTACKER_ORBIT    150   // px: they circle this far outside the station's hull

// --- Your fighters (obj_fighter) and every laser bolt ----------------------------
#macro PLAYER_FIGHTER_RANGE  300 // they open fire inside this distance
#macro PLAYER_FIGHTER_PATROL 320 // idle, they shoot asteroids within this distance of the station
#macro LASER_SPEED           18

/// Total value of loose loot nobody is collecting or hauling (drives enemy collector spawns).
function loose_loot_value() {
    var _v = 0;
    with (obj_pickup) if (claimed_by == noone && !tractored && !carried && !magnet) _v += value;
    return _v;
}
function enemy_collector_loot_mult(_loose) { return min(ENEMY_COLLECTOR_LOOT_MAX, 1 + _loose / ENEMY_COLLECTOR_LOOT_STEP); }

/// Distance from the station to the visible screen edge along direction _dir.
function view_edge_dist(_dir) {
    var _c = abs(dcos(_dir)), _s = abs(dsin(_dir));
    var _hw = view_w() / 2, _hh = view_h() / 2;
    return min((_c > 0.0001) ? _hw / _c : infinity, (_s > 0.0001) ? _hh / _s : infinity);
}

/// Shield multiplier for an enemy: _per x HP for each tier above ENEMY_SHIELD_TIER, capped.
function enemy_shield_mult(_per) { return min(ENEMY_SHIELD_MAX, _per * max(0, global.tier - ENEMY_SHIELD_TIER)); }

// Enemy collectors
/// Seconds between enemy collectors (before the loose-loot speed-up).
function enemy_collector_interval() { return max(ENEMY_COLLECTOR_INTERVAL_MIN, ENEMY_COLLECTOR_INTERVAL - ENEMY_COLLECTOR_INTERVAL_PER_TIER * (global.tier - ENEMY_COLLECTOR_TIER)); }
function enemy_collector_hp()       { return ENEMY_COLLECTOR_HP * threat_hp_mult(false); }
function enemy_collector_shield()   { return enemy_collector_hp() * enemy_shield_mult(ENEMY_COLLECTOR_SHIELD); }
function enemy_collector_speed()    { return ENEMY_COLLECTOR_SPEED + ENEMY_COLLECTOR_SPEED_PER_TIER * max(0, global.tier - ENEMY_COLLECTOR_TIER); }
function enemy_collector_capacity() { return ENEMY_COLLECTOR_CAPACITY + ENEMY_COLLECTOR_CAPACITY_PER_TIER * global.tier; }

// Fighters
/// Seconds between hunter pairs / attackers (before payout / truce).
function hunter_interval()   { return HUNTER_INTERVAL / (1 + HUNTER_PER_SHIP * max(0, global.stats.ships - 1)) * power(FIGHTER_TIER_RATE, max(0, global.tier - FIGHTER_TIER)); }
function attacker_interval() { return ATTACKER_INTERVAL / min(ATTACKER_MAX, 1 + upg_nodes_owned() / ATTACKER_NODE_STEP) * power(FIGHTER_TIER_RATE, max(0, global.tier - FIGHTER_TIER)); }
function fighter_hp()       { return FIGHTER_HP * threat_hp_mult(false); }
function fighter_shield()   { return fighter_hp() * enemy_shield_mult(FIGHTER_SHIELD); }
/// Speed for a hunter or attacker. Pirate day: they all fight as attackers, so all fly at attacker speed.
function fighter_speed(_role) { return (_role == FIGHTER.HUNTER && chart_current() != CHART.PIRATE) ? HUNTER_SPEED : ATTACKER_SPEED; }
/// Laser damage for a hunter or attacker (_role: FIGHTER.HUNTER / FIGHTER.ATTACKER).
function fighter_damage(_role) { return ((_role == FIGHTER.HUNTER) ? HUNTER_DAMAGE : ATTACKER_DAMAGE) * threat_impact_mult(); }
function fighter_colour(_role) {
    static c = [make_colour_rgb(190, 90, 255),   // hunter: purple
                make_colour_rgb(255, 120, 30)];  // attacker: orange
    return c[_role];
}

/// Fires one laser bolt. _side = "player" (hits enemies and asteroids) or "enemy" (hits fighters, collectors and the station).
function laser_fire(_x, _y, _dir, _side, _dmg) {
    var _l = instance_create_layer(_x, _y, "Instances", obj_laser);
    _l.dir = _dir;
    _l.side = _side;
    _l.damage = _dmg;
    _l.image_angle = _dir;
    if (_side == "player") sfx(snd_laser, 0.25, 1.2, 0.08);
    else sfx(snd_laser_shot, 0.35, 1, 0.08); // enemy bolts: a heavier sound, so you hear incoming fire
    return _l;
}

/// An enemy collector arrives from just off-screen.
function spawn_enemy_collector() {
    var _ang = random(360);
    var _dist = play_radius() - 40;
    var _r = instance_create_layer(STATION_X + lengthdir_x(_dist, _ang), STATION_Y + lengthdir_y(_dist, _ang), "Instances", obj_raider);
    _r.no_box = pirate_extra_roll(); // payout days: the extra ones drop no Black Boxes (scr_pirates)
    sfx(snd_warning, 0.6, 1, 0); // enemy collector inbound
    return _r;
}

/// One fighter (FIGHTER.HUNTER or FIGHTER.ATTACKER), from just off-screen at angle _ang (or from (_x, _y)).
function spawn_fighter(_role, _ang = random(360), _x = undefined, _y = undefined) {
    if (_x == undefined) {
        var _dist = play_radius() - 40;
        _x = STATION_X + lengthdir_x(_dist, _ang);
        _y = STATION_Y + lengthdir_y(_dist, _ang);
    }
    var _e = instance_create_layer(_x, _y, "Instances", obj_raider_escort);
    _e.set_role(_role);
    _e.dir = point_direction(_x, _y, STATION_X, STATION_Y);
    return _e;
}

/// A pair of hunters, both locked on to one of your collection ships in flight (picked at
/// random), arriving from the screen edge beyond it. False if no ship is out.
function spawn_hunters() {
    var _ships = [];
    with (obj_collector) if (!dead) array_push(_ships, id);
    if (array_length(_ships) == 0) return false;
    var _prey = _ships[irandom(array_length(_ships) - 1)];
    var _ang = point_direction(STATION_X, STATION_Y, _prey.x, _prey.y) + random_range(-40, 40);
    var _nb = pirate_extra_roll();
    for (var i = 0; i < 2; i++) {
        var _e = spawn_fighter(FIGHTER.HUNTER, _ang + (i == 0 ? -4 : 4)); // side by side
        _e.prey = _prey;
        _e.locked = true;
        _e.no_box = _nb;
        _e.strafe = (i == 0) ? 1 : -1; // they circle it from opposite sides
    }
    sfx(snd_warning, 0.6, 1.15, 0);
    return true;
}

/// One attacker from a random edge.
function spawn_attacker() {
    var _e = spawn_fighter(FIGHTER.ATTACKER);
    _e.no_box = pirate_extra_roll();
    sfx(snd_warning, 0.5, 0.85, 0);
    return _e;
}
