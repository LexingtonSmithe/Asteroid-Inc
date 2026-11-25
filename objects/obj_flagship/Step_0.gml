event_inherited();
if (world_paused() || dead) exit;
var _fps = game_get_speed(gamespeed_fps);
life++;

// Too long on the field: it gives up and leaves (no reward)
if (!retreating && life > FLAGSHIP_RETREAT * _fps) {
    retreating = true;
    float_text(STATION_X, STATION_Y - STATION_RADIUS - 90, "THE FLAGSHIP RETREATS", FLAGSHIP_COLOUR, 2);
}
if (retreating) {
    spd = 2;
    var _out = point_direction(STATION_X, STATION_Y, x, y);
    steer_to(x + lengthdir_x(200, _out), y + lengthdir_y(200, _out));
    if (point_distance(x, y, STATION_X, STATION_Y) > play_radius() + radius) { dead = true; instance_destroy(); }
    exit;
}

// Movement: close in, then work round the standoff ring to face the side it's
// attacking. The ring swings in and out, and it swerves away from the cursor.
var _cur_a = point_direction(STATION_X, STATION_Y, x, y);
var _want_a = target_side * 45;
var _off = angle_difference(_want_a, _cur_a); // how far round the ring it still has to go
var _in_place = abs(_off) < 30;
var _tx, _ty;
if (point_distance(x, y, STATION_X, STATION_Y) > FLAGSHIP_RANGE + FLAGSHIP_WOBBLE + 120) {
    spd = FLAGSHIP_SPEED * 2;
    _tx = STATION_X; _ty = STATION_Y;
} else {
    // Aim a little way round the ring towards the target side; once there, sway either side of it
    var _a = _in_place ? _want_a + 15 * sin(life / 45) : _cur_a + clamp(_off, -35, 35);
    var _r = FLAGSHIP_RANGE + FLAGSHIP_WOBBLE * sin(life / 70);
    _tx = STATION_X + lengthdir_x(_r, _a);
    _ty = STATION_Y + lengthdir_y(_r, _a);
    spd = _in_place ? FLAGSHIP_SPEED : FLAGSHIP_SPEED * 2;
}
// Evade: the closer the cursor is to the hull, the harder it swerves away and the faster it goes
var _md = point_distance(mouse_x, mouse_y, x, y) - radius;
if (_md < FLAGSHIP_DODGE) {
    var _k = 1 - max(0, _md) / FLAGSHIP_DODGE;
    var _away = point_direction(mouse_x, mouse_y, x, y);
    _tx += lengthdir_x(FLAGSHIP_DODGE_PUSH * _k, _away);
    _ty += lengthdir_y(FLAGSHIP_DODGE_PUSH * _k, _away);
    spd = max(spd, FLAGSHIP_SPEED * (2 + 1.5 * _k));
    // Never dodge into the station
    var _sd = point_distance(STATION_X, STATION_Y, _tx, _ty), _min_d = STATION_RADIUS + radius + 60;
    if (_sd < _min_d) {
        var _sa = point_direction(STATION_X, STATION_Y, _tx, _ty);
        _tx = STATION_X + lengthdir_x(_min_d, _sa);
        _ty = STATION_Y + lengthdir_y(_min_d, _sa);
    }
}
steer_to(_tx, _ty);

// Laser broadside at the target side: waits until it's in position, then picks the next side
broadside_t--;
if (broadside_t <= 0) {
    if (_in_place) {
        burst_left = 5; burst_t = 0; broadside_t = FLAGSHIP_BROADSIDE;
        side_hits[target_side]++;
        broadside_side = target_side;
        pick_side();
    } else broadside_t = 1; // still getting round to it
}
if (burst_left > 0) {
    burst_t--;
    if (burst_t <= 0) {
        // Aim at the middle of that side's flat face (spread a little along it)
        var _fa = broadside_side * 45;
        var _fx = STATION_X + lengthdir_x(STATION_APOTHEM, _fa) + lengthdir_x(random_range(-0.3, 0.3) * STATION_RADIUS, _fa + 90);
        var _fy = STATION_Y + lengthdir_y(STATION_APOTHEM, _fa) + lengthdir_y(random_range(-0.3, 0.3) * STATION_RADIUS, _fa + 90);
        var _o = random_range(-radius, radius) * 0.5;
        var _sx = x + lengthdir_x(_o, dir), _sy = y + lengthdir_y(_o, dir);
        laser_fire(_sx, _sy, point_direction(_sx, _sy, _fx, _fy), "enemy", fighter_damage(FIGHTER.ATTACKER) * FLAGSHIP_LASER);
        burst_left--;
        burst_t = 6;
    }
}

// Missile salvo
salvo_t--;
if (salvo_t <= 0) { fire_salvo(); salvo_t = FLAGSHIP_SALVO; }

// Fighter launch: one for the station, one to hunt your ships
launch_t--;
if (launch_t <= 0) {
    pirate_spawn_fighter(FIGHTER.ATTACKER, x, y);
    pirate_spawn_fighter(FIGHTER.HUNTER, x, y);
    launch_t = FLAGSHIP_LAUNCH;
}
