/// White hole (white hole day, scr_conditions). The reverse of the black hole: spews loot and
/// asteroids of every size (some with a modifier, see wh_spew) and never pushes or pulls
/// anything while it's open. When it closes it implodes: rocks and loot within WH_EAT are
/// dragged into the core and destroyed, so whatever drifts past on its way out goes with it.
var _fps = game_get_speed(gamespeed_fps);
age    = 0;
life   = round(WH_LIFE * _fps);
grow   = round(WH_GROW * _fps);
shrink = round(WH_SHRINK * _fps);
power_now = 0;  // 0-1: how open it is (spew and core size)
swirl  = random(360);
spew_t = grow;  // first spew once it's fully open
imploding = false;
thrown = [];    // [instance, cruise vx, cruise vy]: spewed things still being thrown clear of the ring
// Spewing stops this many frames before the implosion, so the last throw clears the ring in time
clear_t = ceil((WH_EAT + ast_radius(AST.LARGE) + 8) / WH_THROW);
// Sounds run in the black hole's order reversed: explode (opening), collapse (implosion starts), open (final pop)
sfx(snd_blackhole_explode, 0.7, 1.2, 0);

/// Final moment: everything still within reach is gone (no loot), then a bright pop.
implode = function() {
    var _me = id;
    var _eat = [];
    with (obj_asteroid) {
        if (dead || is_boss) continue;
        if (point_distance(x, y, _me.x, _me.y) < WH_EAT + radius * 0.5) array_push(_eat, id);
    }
    for (var i = 0; i < array_length(_eat); i++) {
        var _a = _eat[i];
        if (!instance_exists(_a)) continue;
        _a.dead = true;
        with (_a) instance_destroy();
    }
    with (obj_pickup) {
        if (carried || tractored || claimed_by != noone) continue;
        if (point_distance(x, y, _me.x, _me.y) < WH_EAT) instance_destroy();
    }
    fx_blast(x, y, WH_CORE * 2);
    screen_shake(3);
    bloom_burst(WH_BLOOM_BURST);
    sfx(snd_blackhole_open, 0.7, 1.2, 0);
};
