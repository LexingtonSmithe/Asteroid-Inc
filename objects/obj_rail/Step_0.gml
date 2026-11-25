if (world_paused()) exit;
var _px = x, _py = y;
x += lengthdir_x(spd, dir);
y += lengthdir_y(spd, dir);
array_push(trail, [_px, _py]);
if (array_length(trail) > 6) array_delete(trail, 0, 1);

// Hit every asteroid or enemy ship whose edge comes within `width` of the path travelled this frame.
// Collect first, damage after: breaking an asteroid spawns new ones mid-loop.
var _me = id, _new = [];
with (all) {
    if (object_index != obj_asteroid && !object_is_ancestor(object_index, obj_enemy)) continue;
    if (dead || array_contains(_me.hit, id)) continue;
    // distance from the asteroid centre to the segment (_px,_py)-(x,y)
    var _dx = _me.x - _px, _dy = _me.y - _py;
    var _len2 = max(1, _dx * _dx + _dy * _dy);
    var _t = clamp(((x - _px) * _dx + (y - _py) * _dy) / _len2, 0, 1);
    var _d = point_distance(x, y, _px + _dx * _t, _py + _dy * _t);
    if (_d < radius + _me.width) array_push(_new, id);
}
// Nearest first, so the slug weakens in the order it actually passes through them
var _order = [];
for (var i = 0; i < array_length(_new); i++) array_push(_order, [point_distance(_px, _py, _new[i].x, _new[i].y), _new[i]]);
array_sort(_order, function(_p, _q) { return _p[0] - _q[0]; });
for (var i = 0; i < array_length(_order); i++) {
    var _a = _order[i][1];
    array_push(hit, _a);
    if (instance_exists(_a)) {
        fx_spark(_a.x, _a.y);
        dlog_wpn(WPN.RAIL, _a, damage * intensity); // balance log
        if (_a.object_index == obj_asteroid) _a.take_hit(damage * intensity, "rail"); // rail cracks armour
        else _a.take_hit(damage * intensity);
    }
    intensity *= 1 - falloff; // each rock pierced saps the slug (Rail Calibre slows this)
}
if (intensity < RAIL_MIN_POWER) { instance_destroy(); exit; } // spent

if (!in_view(x, y, -200)) instance_destroy();
