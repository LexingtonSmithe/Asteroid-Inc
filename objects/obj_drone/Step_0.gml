if (world_paused()) exit;
var _st = global.stats;
orbit_angle += orbit_speed;
x = STATION_X + lengthdir_x(orbit_radius, orbit_angle);
y = STATION_Y + lengthdir_y(orbit_radius, orbit_angle);
image_angle = orbit_angle;
if (flash > 0) flash--;
if (hit_cd > 0) hit_cd--;

// Knocked out: rebuild, then come back at full strength
if (rebuild > 0) {
    rebuild--;
    if (rebuild <= 0) { hits = max_hits; fx_dock(x, y); }
    exit;
}
if (hit_cd > 0) exit;

var _a = collision_circle(x, y, sprite_width / 2, obj_asteroid, true, true);
if (_a != noone && !_a.dead) {
    // Knock the asteroid away from the drone
    var _nx = _a.x - x, _ny = _a.y - y;
    var _nd = max(1, point_distance(0, 0, _nx, _ny));
    _nx /= _nd; _ny /= _nd;
    var _dot = _a.vx * _nx + _a.vy * _ny;
    if (_dot < 0) {
        _a.vx = (_a.vx - 2 * _dot * _nx) * BOUNCE_KEEP;
        _a.vy = (_a.vy - 2 * _dot * _ny) * BOUNCE_KEEP;
    }
    fx_spark(x + _nx * sprite_width / 2, y + _ny * sprite_width / 2);
    sfx(snd_bump, 0.35, 1.3, 0.1);
    hits--;
    hit_cd = 15;
    flash = 6;
    if (hits <= 0) {
        rebuild = round(_st.drone_rebuild * game_get_speed(gamespeed_fps));
        fx_hurt(x, y);
    }
    dps_hit(false, _a, _st.drone_damage); // Combat HUD: drones are passive
    _a.take_hit(_st.drone_damage); // last: may break the asteroid
}
