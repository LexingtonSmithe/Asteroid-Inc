/// Player fighter. Launches from the station automatically and hunts enemy ships
/// with laser bursts; with no enemies about, it patrols near the station and
/// shoots asteroids that come close. Shot down, it rebuilds inside the station.
depth = -11;
image_speed = 0;          // frame 0 = outline, frame 1 = fill (drawn by remaining hull)
var _st = global.stats;
max_hp = _st.fighter_hp;
hp = max_hp;
spd = _st.fighter_speed;
turn_rate = 6;
dir = random(360);
x = STATION_X;
y = STATION_Y;
target = noone;
retarget = 0;
fire_timer = irandom(30);
burst_left = 0;
burst_timer = 0;
rebuild = 0;              // frames until it's flying again (0 = active)
flash = 0;
patrol_angle = random(360);
strafe = choose(-1, 1);   // which way it circles a target

take_hit = function(_dmg) {
    if (rebuild > 0) return;
    hp -= _dmg;
    flash = 4;
    if (hp <= 0) {
        fx_hurt(x, y);
        sfx(snd_ship_destroyed, 0.4, 1.3, 0.1); // small ship: lighter, higher
        rebuild = round(global.stats.fighter_rebuild * game_get_speed(gamespeed_fps));
        burst_left = 0;
        target = noone;
    }
};

steer_to = function(_tx, _ty) {
    var _want = point_direction(x, y, _tx, _ty);
    dir += clamp(angle_difference(_want, dir), -turn_rate, turn_rate);
    x += lengthdir_x(spd, dir);
    y += lengthdir_y(spd, dir);
    image_angle = dir - SHIP_ART_ANGLE;
};

/// Nearest enemy ship anywhere; failing that, the nearest asteroid near the station.
find_target = function() {
    var _me = id, _best = noone, _bd = infinity;
    with (obj_enemy) {
        if (!dead) {
            var _d = point_distance(x, y, _me.x, _me.y);
            if (_d < _bd) { _bd = _d; _best = id; }
        }
    }
    if (_best != noone) return _best;
    _bd = infinity;
    with (obj_asteroid) {
        if (!dead && point_distance(x, y, STATION_X, STATION_Y) < PLAYER_FIGHTER_PATROL + STATION_RADIUS) {
            var _d = point_distance(x, y, _me.x, _me.y);
            if (_d < _bd) { _bd = _d; _best = id; }
        }
    }
    return _best;
};
