if (world_paused()) exit;
age++;
image_angle += spin;

// Tractor beam: fly straight home, banking on arrival
if (tractored) {
    var _d = point_distance(x, y, STATION_X, STATION_Y);
    if (_d < STATION_RADIUS) {
        if (magnet) { magnet_trigger(x, y); instance_destroy(); exit; } // a Magnet isn't banked: it pulls everything in
        global.bank[res] += value;
        if (instance_exists(obj_game)) obj_game.add_banked(res, value, x, y, fee_free ? value : 0);
        fx_spark(x, y);
        instance_destroy();
        exit;
    }
    tr_spd = min(tr_spd + 0.3, mag_pulled ? max(global.stats.tr_strength, MAGNET_SPEED) : global.stats.tr_strength);
    var _dir = point_direction(x, y, STATION_X, STATION_Y);
    x += lengthdir_x(min(_d, tr_spd), _dir);
    y += lengthdir_y(min(_d, tr_spd), _dir);
    exit;
}

if (claimed_by != noone) {
    if (!instance_exists(claimed_by)) {
        // Ship gone: drop back into space
        claimed_by = noone;
        carried = false;
        pull_spd = 1;
    } else {
        var _c = claimed_by;

        // Already in the hold: cluster around the ship so the load is visible
        if (carried) {
            var _a = slot * 137.5 + _c.orbit;
            var _r = _c.sprite_width / 2 + 4 + 3 * sqrt(slot); // just outside the ship art
            x = lerp(x, _c.x + lengthdir_x(_r, _a), 0.35);
            y = lerp(y, _c.y + lengthdir_y(_r, _a), 0.35);
            exit;
        }

        // Being pulled in by the tractor beam
        var _d = point_distance(x, y, _c.x, _c.y);
        if (_d < 8) {
            if (magnet) { // picked up: the Magnet goes off here instead of going in the hold
                _c.incoming = max(0, _c.incoming - value);
                magnet_trigger(x, y);
                instance_destroy();
                exit;
            }
            slot = _c.cargo_total;
            _c.add_cargo(res, value, fee_free);
            carried = true;
            image_xscale = 0.75 * stack_scale;
            image_yscale = 0.75 * stack_scale;
            exit;
        }
        var _dir = point_direction(x, y, _c.x, _c.y);
        pull_spd = min(pull_spd + 0.6, _c.spd + 9); // accelerates into the ship
        var _spd = min(_d, pull_spd);
        x += lengthdir_x(_spd, _dir);
        y += lengthdir_y(_spd, _dir);
        exit;
    }
}

// Free drift with drag. Loose loot stays until the day ends.
x += vx + global.wind_x; // wind is zero except on solar wind days
y += vy + global.wind_y;
vx *= 0.95;
vy *= 0.95;
if (global.wind_x != 0 || global.wind_y != 0) {
    // Solar wind: blown loot wraps round the screen instead of piling up on one edge
    var _l = view_left() - 8, _w = view_w() + 16;
    var _t = view_top()  - 8, _h = view_h() + 16;
    if (x < _l) x += _w; else if (x > _l + _w) x -= _w;
    if (y < _t) y += _h; else if (y > _t + _h) y -= _h;
} else {
    x = clamp(x, view_left() + 8, view_left() + view_w() - 8); // never drift out of reach
    y = clamp(y, view_top() + 8, view_top() + view_h() - 8);
}
