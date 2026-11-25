event_inherited();
if (world_paused() || dead) exit;

// Hunter whose collector docked or was shot down: carries straight on until it's off-screen,
// but switches to any other collector that comes within HUNTER_RETARGET px on the way out
if (leaving) {
    var _me = id, _near = noone, _nd = HUNTER_RETARGET;
    with (obj_collector) {
        if (dead) continue;
        var _d = point_distance(x, y, _me.x, _me.y);
        if (_d < _nd) { _nd = _d; _near = id; }
    }
    if (_near != noone) {
        prey = _near;
        leaving = false; // back on the hunt (still locked: it leaves again once this one is gone)
    } else {
        x += lengthdir_x(spd, dir);
        y += lengthdir_y(spd, dir);
        image_angle = dir - SHIP_ART_ANGLE;
        if (!in_view(x, y, -60)) { dead = true; instance_destroy(); }
        exit;
    }
}

// Leaving (it gave up waiting, or the flagship fell): straight out from the station
if (fleeing) {
    var _out = point_direction(STATION_X, STATION_Y, x, y);
    steer_to(x + lengthdir_x(200, _out), y + lengthdir_y(200, _out));
    if (point_distance(x, y, STATION_X, STATION_Y) > play_radius()) { dead = true; instance_destroy(); }
    exit;
}

aim = noone;
// Pirate System day: every fighter goes for the station, whatever its colour
var _pirate = (chart_current() == CHART.PIRATE);
switch (_pirate ? FIGHTER.ATTACKER : role) {
    case FIGHTER.HUNTER:
        // Locked on (spawn_hunters): once its collector is gone - shot down or docked - it
        // carries on forwards and off-screen (see leaving above) rather than hunting another.
        // Unlocked (e.g. launched by the flagship): the nearest collector.
        var _gone = !instance_exists(prey) || prey.dead;
        if (locked && _gone) { leaving = true; prey = noone; break; }
        if (_gone) prey = find_collector();
        if (prey != noone) {
            loiter = 0;
            if (prey.state == "return") {
                // Heading home: tail it all the way to the station (circling a ship this fast
                // just falls behind). Each of the pair sits off to its own side, behind it.
                var _bx = prey.x - lengthdir_x(HUNTER_TAIL, prey.dir) + lengthdir_x(HUNTER_TAIL * 0.4 * strafe, prey.dir + 90);
                var _by = prey.y - lengthdir_y(HUNTER_TAIL, prey.dir) + lengthdir_y(HUNTER_TAIL * 0.4 * strafe, prey.dir + 90);
                steer_to(_bx, _by);
            } else chase_orbit(prey, HUNTER_ORBIT);
            if (point_distance(x, y, prey.x, prey.y) < FIGHTER_RANGE) aim = prey;
        } else {
            // Nothing to hunt: drift in a lazy circle, then give up
            steer_to(x + lengthdir_x(100, dir + 3 * strafe), y + lengthdir_y(100, dir + 3 * strafe));
            loiter++;
            if (loiter > HUNTER_LOITER * game_get_speed(gamespeed_fps)) fleeing = true;
        }
        break;

    case FIGHTER.ATTACKER:
        if (instance_exists(obj_station)) {
            prey = obj_station.id;
            chase_orbit(prey, STATION_RADIUS + ATTACKER_ORBIT);
            if (point_distance(x, y, STATION_X, STATION_Y) < FIGHTER_RANGE + STATION_RADIUS) aim = prey;
        }
        break;
}

// Laser bursts at whatever it's aiming at
if (aim != noone && burst_left <= 0) {
    fire_timer--;
    if (fire_timer <= 0) { burst_left = FIGHTER_BURST; burst_timer = 0; fire_timer = FIGHTER_FIRE; }
}
if (burst_left > 0) {
    burst_timer--;
    if (burst_timer <= 0) {
        if (instance_exists(aim)) laser_fire(x, y, point_direction(x, y, aim.x, aim.y) + random_range(-4, 4), "enemy", fighter_damage(_pirate ? FIGHTER.ATTACKER : role) * (_pirate ? PIRATE_FIGHTER_DMG : 1)); // pirate day: they all fight as attackers
        burst_left--;
        burst_timer = 5;
    }
}
