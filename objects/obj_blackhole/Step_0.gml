if (world_paused()) exit;
age++;
swirl += 3 + 5 * power_now;

// Opens over `grow` frames, caves in over the last `shrink`, then collapses
var _left = life - age;
power_now = min(1, age / grow) * clamp(_left / shrink, 0, 1);
if (_left == shrink) sfx(snd_blackhole_collapse, 0.7, 1, 0); // starts caving in
if (_left <= 0) {
    collapse();
    instance_destroy();
    exit;
}

var _fps  = game_get_speed(gamespeed_fps);
var _pw   = power_now; // locals: inside with() below, bare names belong to the asteroid
var _core = BH_CORE * _pw;
var _me   = id;
var _crush = [];

// Pull: asteroids only. Clumps are pulled through their centre rock.
var _frozen = oc_freeze(); // Overcharge: rocks hold still, the pull waits
with (obj_asteroid) {
    if (dead || is_boss || anchor != noone || _frozen) continue;
    var _d = point_distance(x, y, _me.x, _me.y);
    if (_d > BH_RANGE) { crush_t = 0; continue; }
    if (_d < _core + radius * 0.5) {
        // Caught: spring towards the centre and get crushed once a second
        vx = vx * 0.85 + (_me.x - x) * 0.02;
        vy = vy * 0.85 + (_me.y - y) * 0.02;
        crush_t++;
        if (crush_t >= _fps) { crush_t = 0; array_push(_crush, id); }
    } else {
        crush_t = 0;
        var _sm = bh_size_mult(size); // smaller rocks are dragged in faster
        var _a = BH_PULL * _pw * (1 - _d / BH_RANGE) * _sm;
        var _dir = point_direction(x, y, _me.x, _me.y);
        vx += lengthdir_x(_a, _dir);
        vy += lengthdir_y(_a, _dir);
        var _cap = BH_MAX_SPEED * _sm;
        var _sp = point_distance(0, 0, vx, vy);
        if (_sp > _cap) { vx *= _cap / _sp; vy *= _cap / _sp; }
    }
}
// Crush after the loop: breaking a rock spawns its fragments (and loot) right here in the core
for (var i = 0; i < array_length(_crush); i++) {
    var _r = _crush[i];
    if (instance_exists(_r) && !_r.dead) _r.take_hit(_r.max_hp * BH_CRUSH, "crush");
}

// Loose loot is sucked in too (lighter than any rock, so fastest of all), swallowed at the core
// without harm, and sprayed back out when it collapses
var _lcap = BH_MAX_SPEED * bh_size_mult(AST.TINY) * 1.2;
with (obj_pickup) {
    if (carried || tractored || claimed_by != noone) continue;
    var _d = point_distance(x, y, _me.x, _me.y);
    if (_d < _core) {
        if (magnet) continue; // a Magnet isn't swallowed (it would come back out as ore)
        array_push(_me.held, [res, value, fee_free]);
        instance_destroy();
        continue;
    }
    if (_d > BH_RANGE) continue;
    var _a = BH_PULL * _pw * (1 - _d / BH_RANGE) * bh_size_mult(AST.TINY) * BH_LOOT_PULL;
    var _dir = point_direction(x, y, _me.x, _me.y);
    vx += lengthdir_x(_a, _dir);
    vy += lengthdir_y(_a, _dir);
    var _sp = point_distance(0, 0, vx, vy);
    if (_sp > _lcap) { vx *= _lcap / _sp; vy *= _lcap / _sp; }
}
