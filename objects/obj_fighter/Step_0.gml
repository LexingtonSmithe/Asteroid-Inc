if (world_paused()) exit;
var _st = global.stats;
if (flash > 0) flash--;

// Shot down: rebuilding inside the station
if (rebuild > 0) {
    x = STATION_X;
    y = STATION_Y;
    rebuild--;
    if (rebuild <= 0) { hp = max_hp; fx_dock(x, y); }
    exit;
}

retarget--;
if (retarget <= 0 || !instance_exists(target) || target.dead) {
    target = find_target();
    retarget = 20;
}

if (target != noone) {
    // Close in, then circle the target while shooting
    var _d = point_distance(x, y, target.x, target.y);
    if (_d > 180) steer_to(target.x, target.y);
    else {
        var _a = point_direction(target.x, target.y, x, y) + 35 * strafe;
        steer_to(target.x + lengthdir_x(140, _a), target.y + lengthdir_y(140, _a));
    }
    if (_d < PLAYER_FIGHTER_RANGE && burst_left <= 0) {
        fire_timer--;
        if (fire_timer <= 0) { burst_left = _st.fighter_burst; burst_timer = 0; fire_timer = _st.fighter_interval; }
    }
} else {
    // Nothing to fight: patrol around the station
    patrol_angle += 0.8;
    steer_to(STATION_X + lengthdir_x(STATION_RADIUS + 90, patrol_angle), STATION_Y + lengthdir_y(STATION_RADIUS + 90, patrol_angle));
}

// Laser burst: a quick string of bolts aimed at the target
if (burst_left > 0) {
    burst_timer--;
    if (burst_timer <= 0) {
        if (instance_exists(target)) laser_fire(x, y, point_direction(x, y, target.x, target.y) + random_range(-3, 3), "player", _st.fighter_damage * _st.dmg_mult);
        burst_left--;
        burst_timer = 4;
    }
}
