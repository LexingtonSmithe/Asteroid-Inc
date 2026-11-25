/// Enemy collector. Flies ENEMY_COLLECTOR_ENTRY of the way in, then steals loose loot (the same way your ships
/// collect it), and escapes off-screen once full or once there's nothing left.
/// Shoot it down and everything it was carrying drops back into space.
event_inherited();
sprite_index = spr_raider;
image_blend = make_colour_rgb(255, 215, 0);   // enemies are yellow: nothing else in the world is
radius = 16;
setup(enemy_collector_hp(), enemy_collector_shield());
charge_value = 15 * global.tier;
spd = enemy_collector_speed();
turn_rate = 4;
dir = point_direction(x, y, STATION_X, STATION_Y);
image_angle = dir - SHIP_ART_ANGLE;

capacity = enemy_collector_capacity();
cargo_total = 0;
incoming = 0;        // pickups being pulled in
orbit = 0;           // spins the stolen loot around the hull (obj_pickup reads this)
magnet = 40;
state = "enter";     // "enter" -> "steal" -> "flee". Enter: flies in ENEMY_COLLECTOR_ENTRY of the way from
                     // the screen edge to the station before it touches any loot (time to shoot it)
target = noone;
retarget = 0;
idle = 0;

/// Called by obj_pickup when a stolen pickup arrives.
add_cargo = function(_r, _v = 1, _free = false) {
    cargo_total += _v;
    incoming = max(0, incoming - _v);
};

/// Nearest loose pickup nobody has claimed yet.
find_loot = function() {
    var _me = id, _best = noone, _bd = infinity;
    with (obj_pickup) {
        if (claimed_by == noone && !tractored && !magnet) {
            var _d = point_distance(x, y, _me.x, _me.y);
            if (_d < _bd) { _bd = _d; _best = id; }
        }
    }
    return _best;
};

/// Made it off-screen: the loot is gone for good.
escaped = function() {
    var _me = id;
    with (obj_pickup) if (claimed_by == _me) {
        if (instance_exists(obj_game)) obj_game.day_stolen[res] += value; // "TAKEN BY RAIDERS" on the end-of-day panel
        instance_destroy();
    }
    if (cargo_total > 0) {
        float_text(clamp(x, view_left() + 60, view_left() + view_w() - 60), clamp(y, view_top() + 60, view_top() + view_h() - 60), "-" + string(cargo_total), make_colour_rgb(255, 80, 80), 1.6);
        sfx(snd_denied, 0.5, 0.8);
    }
    dead = true;
    instance_destroy();
};
