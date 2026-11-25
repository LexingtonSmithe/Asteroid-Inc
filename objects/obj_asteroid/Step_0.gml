if (world_paused() || dead) exit;

// Explosive caught in a blast: flickers, then goes off itself
if (fuse > 0) {
    fuse--;
    flash = 2;
    if (fuse <= 0) { break_apart(); exit; }
}
if (wobble > 0.01) { wobble *= 0.94; wobble_t++; } else wobble = 0;
// Overcharge: frozen in place, traits and all. It can still be shot; vx/vy are kept for afterwards.
if (oc_freeze()) {
    squash *= 0.72;
    if (flash > 0) flash--;
    exit;
}
if (gilded && random(1) < 0.08) fx_spark(x + random_range(-radius, radius) * 0.7, y + random_range(-radius, radius) * 0.7);
if (warp && anchor == noone && ast_warp()) exit; // just blinked out of existence
if (breeder && ast_breed()) exit; // split into three
if (magnetic) ast_magnet();
if (charged)  ast_charge();
if (occupied && !is_comet) ast_occupied();
if (charge_flash > 0) charge_flash--;
if (nocollide > 0) nocollide--;
if (knock_cd > 0) knock_cd--;

// Stuck to a clump (sticky field): ride along with its centre rock. Touching the hull knocks it loose.
if (anchor != noone) {
    if (!instance_exists(anchor) || anchor.dead) {
        anchor = noone; // centre rock destroyed: drift off on its last heading
        nocollide = FRAG_NOCOLLIDE;
        var _kd = random(360);
        vx += lengthdir_x(0.6, _kd);
        vy += lengthdir_y(0.6, _kd);
    } else {
        var _ad = anchor.image_angle + a_dir;
        x = anchor.x + lengthdir_x(a_dist, _ad);
        y = anchor.y + lengthdir_y(a_dist, _ad);
        image_angle = anchor.image_angle + a_ang;
        vx = anchor.vx;
        vy = anchor.vy;
        squash *= 0.72;
        if (flash > 0) flash--;
        if (is_comet) { // a stuck comet's streak follows it (and shrinks into it), not left hanging where it stuck
            array_push(trail, [x, y]);
            if (array_length(trail) > COMET_TRAIL) array_delete(trail, 0, 1);
        }
        var _free = true;
        if (instance_exists(obj_station)) {
            var _ks = station_hull_side(x, y);
            var _ksurf = (obj_station.shields[_ks] > 0) ? SHIELD_GAP + obj_station.shield_px(_ks) : 0;
            if (station_hull_depth(x, y) - _ksurf < radius) _free = false;
        }
        if (_free) exit;
        anchor = noone; // hit the hull: the normal bounce below takes over
        nocollide = FRAG_NOCOLLIDE;
    }
}

// The boss keeps steering back towards the station, so it rams again and again
if (is_boss) {
    if (sticky || dense) boss_contacts(id); // late-tier modifier: rocks stick to it or bounce off
    var _to = point_direction(x, y, STATION_X, STATION_Y);
    vx += lengthdir_x(0.025, _to);
    vy += lengthdir_y(0.025, _to);
    var _sp = point_distance(0, 0, vx, vy);
    if (_sp > 1.3) { vx *= 1.3 / _sp; vy *= 1.3 / _sp; }
}

// Freeze ray: held still for a moment after the last blast, then thaws back to full speed
if (chill > 0) {
    if (chill_t > 0) chill_t--;
    else chill = max(0, chill - FREEZE_THAW / game_get_speed(gamespeed_fps));
}
var _move = 1 - chill;
x += (vx + global.wind_x) * _move; // wind is zero except on solar wind days
y += (vy + global.wind_y) * _move;
if (is_comet) {
    array_push(trail, [x, y]);
    if (array_length(trail) > COMET_TRAIL) array_delete(trail, 0, 1);
}
image_angle += (spin + spin_kick) * _move;
spin_kick *= 0.93;
squash *= 0.72;
if (flash > 0) flash--;
if (bounce_cd > 0) bounce_cd--;

var _d = point_distance(x, y, STATION_X, STATION_Y);

// Hit the station's octagonal hull, or the shield line in front of the side it's
// heading for while that side is charged: both take damage and the asteroid bounces
// off the flat side.
var _hit = false, _nx = 0, _ny = 0, _push = 0, _sx = x, _sy = y, _side = -1;
if (bounce_cd <= 0 && instance_exists(obj_station)) {
    _side = station_hull_side(x, y);
    var _surf = (obj_station.shields[_side] > 0) ? SHIELD_GAP + obj_station.shield_px(_side) : 0; // outer edge of that side's shield line
    var _depth = station_hull_depth(x, y) - _surf;
    if (_depth < radius) {
        _hit = true;
        var _face = station_side_face(_side);
        _nx = lengthdir_x(1, _face);
        _ny = lengthdir_y(1, _face);
        _push = radius + 1 - _depth;
        _sx = x - _nx * radius;
        _sy = y - _ny * radius;
    }
}
if (_hit) {

    // Reflect the velocity off the station's surface
    var _dot = vx * _nx + vy * _ny;
    if (_dot < 0) {
        vx = (vx - 2 * _dot * _nx) * BOUNCE_KEEP;
        vy = (vy - 2 * _dot * _ny) * BOUNCE_KEEP;
    }
    // Always leave with some speed so nothing sticks to the hull
    var _out_sp = point_distance(0, 0, vx, vy);
    if (_out_sp < 1) { vx += _nx; vy += _ny; }

    // Push clear of the hull
    x += _nx * _push;
    y += _ny * _push;
    bounce_cd = 20;

    var _dmg = impact * (explosive ? EXPLODE_STATION : 1);
    screen_kick(point_direction(x, y, STATION_X, STATION_Y), 8); // impact shoves the view
    var _src = "rock_tiny";
    if (size == AST.SMALL) _src = "rock_small"; else if (size == AST.MEDIUM) _src = "rock_medium"; else if (size == AST.LARGE) _src = "rock_large";
    if (explosive) _src = "explosion";
    if (is_comet)  _src = "comet";
    if (is_boss)   _src = "boss";
    with (obj_station) take_damage(_dmg, _side, _src);
    fx_spark(_sx, _sy);
    if (explosive) { // goes off against the hull: no loot
        break_apart(false);
        exit;
    }
    if (is_comet) { // comets burst on impact: no loot, no bounce
        dead = true;
        fx_break(x, y, size, type);
        sfx_asteroid_break(size);
        screen_shake(2);
        instance_destroy();
        exit;
    }
    take_hit(global.stats.ram_damage); // may break it; the pieces carry the bounce velocity
    exit;
}

// Screen wrap. Rocks spawn off-screen, so they only start wrapping once they've come
// into view; the margin keeps the jump hidden (fully off one edge, fully off the other).
// The boss doesn't wrap: it steers back to the station on its own.
if (is_boss) exit;
var _m = max(radius * 1.5, reach + 4) + 4; // a clump wraps once all of it is off screen
if (!entered) {
    if (in_view(x, y, -_m)) entered = true;
    else if (_d > play_radius() + 100) instance_destroy(); // never made it on screen
    exit;
}
var _l = view_left() - _m, _r = view_left() + view_w() + _m;
var _t = view_top()  - _m, _b = view_top()  + view_h() + _m;
var _wrapped = false;
while (x < _l) { x += _r - _l; _wrapped = true; } // while: a warp can jump it more than a screen
while (x > _r) { x -= _r - _l; _wrapped = true; }
while (y < _t) { y += _b - _t; _wrapped = true; }
while (y > _b) { y -= _b - _t; _wrapped = true; }
if (_wrapped) trail = []; // comet streak would otherwise draw across the whole screen
