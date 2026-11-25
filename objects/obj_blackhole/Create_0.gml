/// Black hole (gravity anomaly day, scr_conditions). Pulls asteroids only - not bullets,
/// ships, loot or the station. Rocks that reach the core are held and crushed a bit every
/// second; the loot crushed out of them is swallowed. After BH_LIFE seconds it caves in
/// and collapses: a shockwave throws everything outwards and the swallowed loot sprays out.
var _fps = game_get_speed(gamespeed_fps);
age    = 0;
life   = round(BH_LIFE * _fps);
grow   = round(BH_GROW * _fps);
shrink = round(BH_SHRINK * _fps);
power_now = 0;  // 0-1: how open it is (pull strength and core size)
swirl  = random(360);
held   = [];    // loot it has swallowed: [resource, stack value, fee_free] each
sfx(snd_blackhole_open, 0.6, 1, 0);

collapse = function() {
    var _me = id;
    fx_blast(x, y, BH_RANGE * 0.6);
    fx_blast(x, y, BH_CORE * 2);
    screen_shake(5);
    bloom_burst(1.2);
    sfx(snd_blackhole_explode, 0.9, 1, 0);

    // Shockwave: a one-off shove straight out from the centre, strongest close in
    with (obj_asteroid) {
        if (dead || is_boss || anchor != noone) continue; // clumps move as one, via their centre rock
        var _d = point_distance(_me.x, _me.y, x, y);
        if (_d > BH_RANGE) continue;
        var _dir = (_d < 4) ? random(360) : point_direction(_me.x, _me.y, x, y);
        var _f = BH_BLAST * (1 - 0.7 * _d / BH_RANGE);
        vx += lengthdir_x(_f, _dir);
        vy += lengthdir_y(_f, _dir);
        crush_t = 0;
        spin_kick = choose(-1, 1) * random_range(4, 8);
    }
    with (obj_pickup) {
        if (carried || tractored || claimed_by != noone) continue;
        var _d = point_distance(_me.x, _me.y, x, y);
        if (_d > BH_RANGE) continue;
        var _dir = point_direction(_me.x, _me.y, x, y);
        var _f = BH_BLAST * (1 - 0.7 * _d / BH_RANGE);
        vx += lengthdir_x(_f, _dir);
        vy += lengthdir_y(_f, _dir);
    }
    // Everything it swallowed sprays back out
    for (var i = 0; i < array_length(held); i++) {
        var _p = instance_create_layer(x, y, "Instances", obj_pickup);
        _p.set_type(held[i][0]);
        _p.set_value(held[i][1]);
        _p.fee_free = held[i][2];
        var _pd = random(360), _ps = BH_BLAST * random_range(0.6, 1.4);
        _p.vx = lengthdir_x(_ps, _pd);
        _p.vy = lengthdir_y(_ps, _pd);
    }
};
