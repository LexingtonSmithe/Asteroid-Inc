if (world_paused()) exit;
var _px = x, _py = y;
x += lengthdir_x(LASER_SPEED, dir);
y += lengthdir_y(LASER_SPEED, dir);
life--;

var _hit = noone;
if (side == "player") {
    _hit = collision_line(_px, _py, x, y, obj_enemy, false, true);
    if (_hit == noone) _hit = collision_line(_px, _py, x, y, obj_asteroid, true, true);
    if (_hit != noone && _hit.dead) _hit = noone;
    if (ignore_t > 0) { ignore_t--; if (_hit == ignore) _hit = noone; }
    // Rubber / armoured: bounce off and keep going (worked out before the hit, which may break it)
    if (_hit != noone && bounces > 0 && ast_deflects(_hit)) {
        var _b = ast_bounce(_hit, _px, _py, lengthdir_x(LASER_SPEED, dir), lengthdir_y(LASER_SPEED, dir), 1);
        fx_spark(x, y);
        if (side == "player") dps_hit(false, _hit, damage); // Combat HUD: fighters are passive
        _hit.take_hit(damage);
        bounces--;
        dir = point_direction(0, 0, _b.vx, _b.vy);
        x = _b.x; y = _b.y;
        ignore = _hit;
        ignore_t = 4;
        _hit = noone;
    }
    // Glass: the rock takes part of the bolt, which refracts out of its far side as two weaker
    // beams (worked out before the hit, which may break it). Refracted beams don't split again.
    if (_hit != noone && variable_instance_exists(_hit, "glass") && _hit.glass) {
        var _g = _hit, _gx = _hit.x, _gy = _hit.y, _gr = _hit.radius;
        fx_spark(x, y);
        if (side == "player") dps_hit(false, _g, damage * GLASS_LASER);
        _g.take_hit(damage * GLASS_LASER);
        if (!refracted) {
            for (var s = -1; s <= 1; s += 2) {
                var _d = dir + s * GLASS_SPLIT_ANG;
                var _l = laser_fire(_gx + lengthdir_x(_gr + 4, _d), _gy + lengthdir_y(_gr + 4, _d), _d, "player", damage * GLASS_SPLIT);
                _l.refracted = true;
                _l.bounces = bounces;
                _l.ignore = _g;
                _l.ignore_t = 6;
            }
        }
        instance_destroy();
        exit;
    }
} else {
    _hit = collision_line(_px, _py, x, y, obj_fighter, false, true);
    if (_hit != noone && _hit.rebuild > 0) _hit = noone;
    if (_hit == noone) {
        _hit = collision_line(_px, _py, x, y, obj_collector, false, true);
        if (_hit != noone && _hit.dead) _hit = noone;
    }
    if (_hit == noone && instance_exists(obj_station)) {
        // The shield line in front of that side while it's charged, otherwise the hull itself
        var _side = station_hull_side(x, y);
        var _surf = (obj_station.shields[_side] > 0) ? SHIELD_GAP + obj_station.shield_px(_side) : 0;
        if (station_hull_depth(x, y) < _surf) {
            var _dmg = damage;
            with (obj_station) take_damage(_dmg, _side, "enemy_laser");
            fx_spark(x, y);
            instance_destroy();
            exit;
        }
    }
}
if (_hit != noone) {
    fx_spark(x, y);
    if (side == "player") dps_hit(false, _hit, damage); // Combat HUD: fighters are passive
        _hit.take_hit(damage);
    instance_destroy();
    exit;
}
if (life <= 0 || !in_view(x, y, -64)) instance_destroy();
