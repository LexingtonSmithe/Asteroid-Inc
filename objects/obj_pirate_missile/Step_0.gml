event_inherited();
if (world_paused() || dead) exit;
if (wait > 0) { wait--; exit; }
life++;
array_push(trail, [x, y]);
if (array_length(trail) > 8) array_delete(trail, 0, 1);
fx_missile_sparks(x, y, dir); // trail of sparks from the motor

// Speeds up and turns harder as it goes: a wide arc that tightens onto the station
spd = min(6, spd + 0.08);
turn_rate = min(5, 1.5 + life * 0.03);
steer_to(STATION_X, STATION_Y);
image_angle = dir - 90; // spr_missile points up (90 degrees)

// Strike: the shield line on that side while it's charged, otherwise the hull
if (instance_exists(obj_station)) {
    var _side = station_hull_side(x, y);
    var _surf = (obj_station.shields[_side] > 0) ? SHIELD_GAP + obj_station.shield_px(_side) : 0;
    if (station_hull_depth(x, y) < _surf) {
        var _dmg = damage;
        with (obj_station) take_damage(_dmg, _side, "pirate_missile");
        fx_blast(x, y, 24);
        dead = true;
        instance_destroy();
        exit;
    }
}
if (life > 10 * game_get_speed(gamespeed_fps)) { dead = true; fx_spark(x, y); instance_destroy(); }
