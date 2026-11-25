if (world_paused()) exit;
age++;
swirl -= 3 + 5 * power_now; // turns the other way to the black hole

// Opens over `grow` frames, implodes over the last `shrink`, then it's gone
var _left = life - age;
power_now = min(1, age / grow) * clamp(_left / shrink, 0, 1);
if (_left <= 0) {
    implode();
    instance_destroy();
    exit;
}

// Spewed things fly out at WH_THROW until they're clear of the implosion ring, then cruise
// (rocks at up to WH_FAST x normal speed, loot slowing to a stop). Only what was already
// about, or is still inside the ring when it caves in, gets taken.
for (var i = array_length(thrown) - 1; i >= 0; i--) {
    var _t = thrown[i], _o = _t[0];
    if (!instance_exists(_o)) { array_delete(thrown, i, 1); continue; }
    var _loot = _o.object_index == obj_pickup;
    // Caught by a ship's tractor or stuck to another rock on the way out: let it go
    if (_loot ? (_o.carried || _o.tractored || _o.claimed_by != noone) : (_o.dead || _o.anchor != noone)) { array_delete(thrown, i, 1); continue; }
    var _r = _loot ? 8 : _o.radius;
    var _dir = point_direction(x, y, _o.x, _o.y);
    if (point_distance(x, y, _o.x, _o.y) > WH_EAT + _r + 8) {
        _o.vx = _t[1];
        _o.vy = _t[2];
        array_delete(thrown, i, 1);
    } else {
        _o.vx = lengthdir_x(WH_THROW, _dir);
        _o.vy = lengthdir_y(WH_THROW, _dir);
    }
}

// Open: spew loot and rocks. Nothing nearby is pushed or pulled.
if (_left > shrink) {
    spew_t--;
    if (spew_t <= 0 && _left > shrink + clear_t) {
        array_push(thrown, wh_spew(x, y));
        spew_t = WH_RATE * game_get_speed(gamespeed_fps) * random_range(0.5, 1.5);
    }
    exit;
}

// Implosion: rocks and loot within WH_EAT are dragged into the core (destroyed in implode())
if (!imploding) {
    imploding = true;
    sfx(snd_blackhole_collapse, 0.7, 1.3, 0);
}
var _me = id;
var _k = 1 - _left / shrink; // 0 -> 1 over the implosion: the drag gets harder
var _frozen = oc_freeze();
with (obj_asteroid) {
    if (dead || is_boss || anchor != noone || _frozen) continue;
    if (point_distance(x, y, _me.x, _me.y) > WH_EAT + radius * 0.5) continue;
    x = lerp(x, _me.x, 0.08 + 0.25 * _k);
    y = lerp(y, _me.y, 0.08 + 0.25 * _k);
    vx *= 0.8;
    vy *= 0.8;
}
with (obj_pickup) {
    if (carried || tractored || claimed_by != noone) continue;
    if (point_distance(x, y, _me.x, _me.y) > WH_EAT) continue;
    x = lerp(x, _me.x, 0.1 + 0.3 * _k);
    y = lerp(y, _me.y, 0.1 + 0.3 * _k);
}
