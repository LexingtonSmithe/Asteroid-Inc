/// Enemy fighter (hunter or attacker). Arrives on its own timer (scr_enemies spawn_hunters /
/// spawn_attacker), not with enemy collectors. Its role, shown by its colour, decides what it goes after:
///   FIGHTER.HUNTER  (purple) comes in a pair locked on to one collection ship: chases and
///                  orbits it firing, and leaves once that ship is gone (destroyed or docked)
///   FIGHTER.ATTACKER (orange) flies straight to the station and orbits it, firing
/// On a Pirate System day every fighter attacks the station (scr_pirates).
event_inherited();
sprite_index = spr_fighter;
radius = 8;
setup(fighter_hp(), fighter_shield());
charge_value = 6 * global.tier;
turn_rate = 7;
fleeing = false;     // flying straight out from the station and away
leaving = false;     // hunter whose collector is gone: carries straight on off-screen (may retarget)
prey = noone;        // what it's chasing (hunter: a collector, attacker: the station)
locked = false;      // hunter: stays on its spawn target and leaves when it's gone (spawn_hunters)
loiter = 0;          // unlocked hunter: frames spent with no collector to chase
strafe = choose(-1, 1); // which way it circles
orbit_jitter = random_range(-25, 25); // so a group doesn't stack on one ring
aim = noone;         // what it's shooting at
fire_timer = irandom(FIGHTER_FIRE);
burst_left = 0;
burst_timer = 0;

set_role = function(_role) {
    role = _role;
    image_blend = fighter_colour(_role);
    spd = fighter_speed(_role);
};
set_role(FIGHTER.ATTACKER); // default if spawned without a role

/// Nearest collection ship in flight (noone if none).
find_collector = function() {
    var _me = id, _best = noone, _bd = infinity;
    with (obj_collector) {
        if (!dead) {
            var _d = point_distance(x, y, _me.x, _me.y);
            if (_d < _bd) { _bd = _d; _best = id; }
        }
    }
    return _best;
};

/// Chase the target, then circle it at _orb px.
chase_orbit = function(_t, _orb) {
    _orb += orbit_jitter;
    if (point_distance(x, y, _t.x, _t.y) > _orb + 80) steer_to(_t.x, _t.y);
    else {
        var _a = point_direction(_t.x, _t.y, x, y) + 30 * strafe;
        steer_to(_t.x + lengthdir_x(_orb, _a), _t.y + lengthdir_y(_orb, _a));
    }
};
