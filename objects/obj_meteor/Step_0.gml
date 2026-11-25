if (world_paused()) exit;
var _px = x, _py = y;
x += vx;
y += vy;
age++;
array_push(trail, [x, y]);
if (array_length(trail) > 8) array_delete(trail, 0, 1);

// Asteroids (line check too: it's fast enough to skip tiny ones)
var _hit = collision_circle(x, y, radius, obj_asteroid, true, true);
if (_hit == noone) _hit = collision_line(_px, _py, x, y, obj_asteroid, true, true);
if (_hit != noone && !_hit.dead) {
    fx_spark(x, y);
    sfx(snd_bump, 0.25, 1.5, 0.15);
    _hit.take_hit(dmg, "meteor"); // armour shrugs it off
    instance_destroy();
    exit;
}

// Station: the shield line in front of that side while it's charged, otherwise the hull
if (instance_exists(obj_station)) {
    var _side = station_hull_side(x, y);
    var _surf = (obj_station.shields[_side] > 0) ? SHIELD_GAP + obj_station.shield_px(_side) : 0;
    if (station_hull_depth(x, y) - _surf < radius) {
        var _dmg = impact;
        with (obj_station) take_damage(_dmg, _side, "meteor");
        fx_spark(x, y);
        screen_kick(point_direction(x, y, STATION_X, STATION_Y), 3);
        instance_destroy();
        exit;
    }
}

// Gone once it has crossed the screen (or never arrived)
if (in_view(x, y, -40)) entered = true;
else if (entered || age > 600) instance_destroy();
