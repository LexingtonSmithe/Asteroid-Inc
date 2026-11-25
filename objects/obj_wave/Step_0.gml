if (world_paused()) exit;
var _r0 = r;
r += grow;
var _me = id;
var _frozen = oc_freeze(); // Overcharge: frozen rocks keep their headings

with (obj_asteroid) {
    if (dead || _frozen || array_contains(_me.done, id)) continue;
    var _d = point_distance(_me.x, _me.y, x, y);
    if (_d < _r0 - radius || _d > _me.r + radius) continue; // not in the band swept this frame
    array_push(_me.done, id);

    // Turn the heading towards straight-out-from-the-station, by at most this rock's share
    var _sp = point_distance(0, 0, vx, vy);
    if (_sp <= 0) continue;
    var _dir  = point_direction(0, 0, vx, vy);
    var _out  = point_direction(_me.x, _me.y, x, y);
    var _turn = _me.deflect * (is_boss ? REP_BOSS_TURN : _me.size_turn[size]) * (armoured ? ARMOUR_PUSH : 1);
    _dir += clamp(angle_difference(_out, _dir), -_turn, _turn);
    vx = lengthdir_x(_sp, _dir);
    vy = lengthdir_y(_sp, _dir);
    flash = 3;
}

// Missile shockwave: shove the ships it sweeps over outwards (stronger near the blast).
// The flagship is too big to move.
if (shove > 0) {
    with (obj_enemy) {
        if (dead || object_index == obj_flagship || array_contains(_me.shoved, id)) continue;
        var _d = point_distance(_me.x, _me.y, x, y);
        if (_d < _r0 - radius || _d > _me.r + radius) continue;
        array_push(_me.shoved, id);
        var _p = _me.shove * (1 - 0.5 * _d / max(1, _me.range));
        var _out = point_direction(_me.x, _me.y, x, y);
        push_x += lengthdir_x(_p, _out);
        push_y += lengthdir_y(_p, _out);
    }
}

if (r > range) instance_destroy();
