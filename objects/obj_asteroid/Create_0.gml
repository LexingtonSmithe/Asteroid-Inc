/// Asteroid. Call init(size, type) or init_boss() straight after creating.
/// size = AST.* (sets scale/health), type = RES.* (sets colour and what it drops).
/// HP scales with the threat (in-day ramp, tier) at the moment it's created.
image_speed = 0; // frame 0 = outline, frame 1 = fill (drawn by remaining health)
vx = 0;
vy = 0;
spin  = 0;
flash = 0;
squash = 0;     // 0-1: squash-and-pop when hit
spin_kick = 0;  // extra spin that dies away (fresh fragments tumble)
dead  = false;
last_src = "";   // source of the latest hit (take_hit): environmental kills pay no charge
is_boss = false;
bounce_cd = 0;   // frames before it can hit the station again
is_comet = false; // rare fast rock aimed straight at the station (see spawn_comet)
trail = [];       // comet only: recent positions for the streak
entered = false;  // has come on screen: from then on it wraps at the edges instead of leaving
tut = false;      // day-one tutorial rock: breaks into TUT_LOOT and no fragments (scr_tutorial)
chill   = 0;      // freeze ray: 0 moving freely .. 1 frozen still (scales its movement, vx/vy are kept)
chill_t = 0;      // frames before it starts to thaw

/// Freeze ray blast: takes 1/freeze_blasts(size) of its speed off. No damage.
freeze_hit = function() {
    chill   = min(is_boss ? FREEZE_BOSS_MAX : 1, chill + 1 / freeze_blasts(size));
    chill_t = global.stats.freeze_hold * game_get_speed(gamespeed_fps); // Cryo Life
    squash  = max(squash, 0.4);
}

// Traits (scr_conditions): at most one, set by spawn_asteroid after init(); fragments inherit them
rubber    = false; // bullets and lasers bounce off after dealing damage
explosive = false; // breaks into a blast instead of fragments
gilded    = false; // triple drops, all the way down
armoured  = false; // only rail (full) and Tesla (half) hurt it
sticky    = false; // joins rocks it touches into a clump (sticky field)
anchor    = noone; // the clump's centre rock this one is stuck to
a_dist    = 0;     // where it sits on that centre rock: distance, direction and turn relative to its angle
a_dir     = 0;
a_ang     = 0;
reach     = 0;     // centre rock: how far its clump sticks out (for the wrap margin)
nocollide = 0;     // frames left ignoring rock contacts (fresh fragments start touching)
knock_cd  = 0;     // dense field: frames before another knock can damage it
crush_t   = 0;     // frames spent in a black hole's core
fuse      = 0;     // explosive caught in another blast: frames until it goes off
wobble    = 0;     // rubber: jelly wobble after a hit (0-1)
wobble_t  = 0;
pulse_phase = random(2 * pi); // explosive glow: each rock pulses out of step with the others
// Tier 2+ traits
magnetic  = false; // drags loose loot along with it
charged   = false; // zaps the nearest ship in range
glass     = false; // near-invisible: black fill, thin grey outline
occupied  = false; // launches missiles at the station (not passed to fragments)
warp      = false; // blinks out of existence and back further along its path
breeder   = false; // grows a size every few seconds left alone; a large one splits into three small breeders
breed_t   = 0;
breed_child = false; // born from a split: pays no bonus charge (there'd be no end to them)
dense     = false; // knocks into other rocks on any day (white hole spew; a dense field does it for every rock)
warp_phase = 0;    // 0 idle, 1 shrinking, 2 just back, 3 growing (ast_warp)
warp_k    = 1;     // draw scale while warping
charge_flash = 0;  // frames of glow after a zap
ast_trait_timers(id); // charge_t, occ_t, warp_t: staggered start times

init = function(_size, _type) {
    size   = _size;
    type   = _type;
    sprite_index = spr_asteroid;
    image_xscale = ast_scale(size);
    image_yscale = image_xscale;
    image_blend  = res_colour(type);
    hp     = ast_hp(size) * threat_hp_mult() * cluster_hp_mult(); // clustered field: half, sparse: double
    max_hp = hp;
    radius = ast_radius(size);
    impact = ast_impact(size) * threat_impact_mult();
    image_angle = random(360);
    spin = choose(-1, 1) * ast_spin(size) * random_range(0.3, 1); // degrees per frame
};

boss_n    = 0;     // which of today's bosses (0 = first)
boss_trait = "";  // late-tier boss modifier, for the health bar (boss_roll_trait)
no_loot   = false; // drops nothing at all (unused by the schedule now; kept for anything that wants it)
cores_drop = 0;    // Cores this boss drops (boss_core_drop, scr_threat)
swarm     = false; // spawned by a swarm: drops SWARM_LOOT of the usual loot (fragments too)
tier_boss = false; // drops the Cores that pay for the next tier
init_boss = function(_n = 0, _tier_boss = true) {
    is_boss = true;
    boss_n = _n;
    tier_boss = _tier_boss;
    var _g = power(BOSS_GROW, _n); // each later boss: bigger and tougher
    size   = AST.LARGE;               // for sounds/debris
    type   = boss_loot_type();
    sprite_index = spr_asteroid;
    image_xscale = BOSS_SCALE * _g;
    image_yscale = BOSS_SCALE * _g;
    image_blend  = make_colour_rgb(255, 70, 210);
    hp     = BOSS_HP * threat_hp_mult(false) * _g;
    max_hp = hp;
    radius = BOSS_SCALE * _g * 14; // same hexagon fit as ast_radius()
    impact = BOSS_IMPACT * threat_impact_mult() * _g;
    image_angle = random(360);
    spin = choose(-1, 1) * 0.3;
};

laser_melt = 0; // seconds of laser contact towards melting armour off (obj_station)
/// _src: "rail", "zap" or "laser" where it matters (armour); anything else is a plain hit.
take_hit = function(_amount, _src = "") {
    if (dead) return;
    last_src = _src; // what dealt the latest damage: a rock broken by the field itself pays no charge (break_apart)
    if (armoured) {
        if (_src == "zap") _amount *= ARMOUR_ZAP;
        else if (_src == "laser") _amount *= LASER_ARMOUR; // the laser burns through slowly (and melts it off: obj_station laser)
        else if (_src != "rail" && _src != "missile") { // glances off: a clink and a flicker, no damage (rail and missiles get through)
            flash = 2;
            squash = max(squash, 0.3);
            sfx(snd_ricochet, 0.3, 1, 0.15);
            return;
        }
    }
    hp -= _amount;
    flash = 4;
    squash = 1;
    if (rubber) wobble = 1;
    if (hp <= 0) {
        if (is_boss) boss_destroyed(); else break_apart();
    }
};

/// _loot = false when it dies against the hull (an explosive that reached you pays nothing).
break_apart = function(_loot = true) {
    dead = true;
    if (instance_exists(obj_game)) obj_game.dlog.kills[size]++; // balance log
    fx_break(x, y, size, type);
    sfx_asteroid_break(size);
    static _shake = [0, 0.6, 1.5, 3.5]; // tiny, small, medium, large
    screen_shake(_shake[size]);
    if (size >= AST.MEDIUM) screen_kick(point_direction(STATION_X, STATION_Y, x, y), size == AST.LARGE ? 6 : 3);
    if (size == AST.LARGE) hit_stop(3);

    // Day-one tutorial rock: a fixed pile of loot and no fragments (scr_tutorial)
    if (tut) {
        if (_loot) {
            add_charge(ast_hp(size));
            loot_drop(x, y, type, TUT_LOOT, radius / 2, TUT_LOOT_PIECES);
        }
        instance_destroy();
        return;
    }

    // Drop loot of this asteroid's type
    if (_loot) {
        // Broken by rock-on-rock knocks or meteor-shower meteors, not by you: loot, but no charge
        var _env = (last_src == "knock" || last_src == "meteor");
        if (!_env) add_charge(ast_hp(size));
        if (_env) { /* no bonus charge either */ }
        else if (is_comet) charge_bonus(x, y, CHARGE_BONUS_COMET);
        else if (ast_is_special(id)) charge_bonus(x, y, CHARGE_BONUS_SPECIAL * (size + 1));
        else if (breeder && size == AST.LARGE && !breed_child) charge_bonus(x, y, CHARGE_BONUS_SPECIAL * (size + 1)); // original breeders only, once large
        var _drops = ast_drop_amount(size), _pieces = 1;
        // Big Breaker: bonus loot when a large rock first breaks up (its fragments don't get it)
        if (size == AST.LARGE && !is_boss) _drops += round_random(global.stats.big_break * threat_reward_mult());
        // Gilded promises loot all the way down. An explosive one never splits, so its blast
        // pays out for every fragment it would have broken into (and rolls a coin for each).
        if (gilded && explosive && !is_comet) {
            var _n = 2;
            for (var s = size - 1; s >= AST.TINY; s--) { _drops += _n * ast_drop_amount(s); _pieces += _n; _n *= 2; }
        }
        var _spread = (_pieces > 1) ? radius * 1.5 : radius / 2;
        loot_drop(x, y, type, _drops * (is_comet ? COMET_LOOT : 1) * (gilded ? GILDED_LOOT : 1) * (swarm ? SWARM_LOOT : 1), _spread, LOOT_PIECES_MAX, undefined, gilded && chart_current() != CHART.GOLD); // a few stacks (scr_config). Gilded is fee-free only as a rare drop: on a Gold System day it's the norm, so the rebuild fee applies
        repeat (_pieces) chart_coin_drop(); // gilded: a chance of a Gold Coin (scr_charts)
        magnet_drop(); // magnetic: a chance of a Magnet (scr_conditions)
    }

    // Explosive: a blast instead of fragments
    if (explosive) {
        detonate();
        instance_destroy();
        return;
    }

    // Split into two of the next size down, same type
    if (size > AST.TINY && !is_comet) { // comets shatter completely
        var _child = size - 1;
        var _base  = point_direction(0, 0, vx, vy);
        var _spd   = max(point_distance(0, 0, vx, vy), ast_speed(_child) * threat_speed_mult());
        for (var j = 0; j < 2; j++) {
            var _dir = _base + (j == 0 ? -35 : 35) + random_range(-15, 15);
            var _off = ast_radius(_child);
            var _a = instance_create_layer(x + lengthdir_x(_off, _dir), y + lengthdir_y(_off, _dir), "Instances", obj_asteroid);
            _a.init(_child, type);
            var _s = _spd * random_range(0.9, 1.2);
            _a.vx = lengthdir_x(_s, _dir);
            _a.vy = lengthdir_y(_s, _dir);
            _a.bounce_cd = bounce_cd; // children of a bounce don't instantly re-hit
            _a.spin_kick = choose(-1, 1) * random_range(5, 10);
            _a.squash = 1;
            _a.rubber   = rubber;
            _a.gilded   = gilded;
            _a.armoured = armoured;
            _a.swarm    = swarm;
            _a.magnetic = magnetic;
            _a.charged  = charged;
            _a.glass    = glass;
            _a.warp     = warp;
            _a.dense    = dense;
            _a.sticky   = sticky;    // still sticky, but comes off the clump clean (no anchor) and can rejoin later
            _a.occupied = occupied && _child >= AST.MEDIUM; // the crew needs a medium or large rock to fire from
            _a.entered  = entered; // fragments of an on-screen rock wrap straight away
            _a.nocollide = FRAG_NOCOLLIDE; // fresh fragments ignore rock contacts for a moment (so sticky ones don't re-glue at once)
            // breeder isn't passed on: killing a breeder is the only way to stop it
        }
    }
    instance_destroy();
};

/// Explosive's blast: damages and shoves every asteroid in range, sets off other
/// explosives on a short fuse, hurts enemy and collection ships, scatters loose loot.
detonate = function() {
    var _r   = explode_radius(size);
    var _dmg = explode_damage(size);
    var _me  = id;
    fx_blast(x, y, _r);
    sfx(snd_explosion, 0.7);
    screen_shake(1 + size);

    // Collect first, then act: hits split asteroids and spawn new ones mid-loop
    var _hits = [];
    with (obj_asteroid) {
        if (id == _me || dead) continue;
        if (point_distance(x, y, _me.x, _me.y) < _r + radius) array_push(_hits, id);
    }
    for (var i = 0; i < array_length(_hits); i++) {
        var _h = _hits[i];
        if (!instance_exists(_h) || _h.dead) continue;
        if (!_h.is_boss) {
            var _f = 1 - clamp(point_distance(x, y, _h.x, _h.y) / (_r + _h.radius), 0, 1);
            var _dir = point_direction(x, y, _h.x, _h.y);
            var _push = EXPLODE_PUSH * (0.3 + 0.7 * _f) * (_h.armoured ? ARMOUR_PUSH : 1);
            _h.vx += lengthdir_x(_push, _dir);
            _h.vy += lengthdir_y(_push, _dir);
        }
        if (_h.explosive) { if (_h.fuse <= 0) _h.fuse = EXPLODE_FUSE; } // chain: goes off a moment later
        else _h.take_hit(_dmg, "blast"); // last: may split it (fragments keep the shove)
    }

    // Ships: enemies take the full blast, your collectors a fixed knock
    var _ships = [];
    with (obj_enemy)     if (!dead && point_distance(x, y, _me.x, _me.y) < _r) array_push(_ships, [id, _dmg]);
    with (obj_collector) if (!dead && point_distance(x, y, _me.x, _me.y) < _r) array_push(_ships, [id, EXPLODE_SHIP]);
    for (var i = 0; i < array_length(_ships); i++) {
        if (instance_exists(_ships[i][0])) _ships[i][0].take_hit(_ships[i][1]);
    }

    // Loose loot gets blown outwards
    with (obj_pickup) {
        if (carried || tractored || claimed_by != noone) continue;
        var _d = point_distance(x, y, _me.x, _me.y);
        if (_d < _r) {
            var _pd = point_direction(_me.x, _me.y, x, y);
            vx += lengthdir_x(EXPLODE_PUSH * (1 - _d / _r), _pd);
            vy += lengthdir_y(EXPLODE_PUSH * (1 - _d / _r), _pd);
        }
    }
};

boss_destroyed = function() {
    dead = true;
    // A ring of debris bursts and a big loot shower
    for (var i = 0; i < 8; i++) {
        var _a = i * 45;
        fx_break(x + lengthdir_x(radius * 0.6, _a), y + lengthdir_y(radius * 0.6, _a), AST.LARGE, type);
    }
    sfx(snd_station_destroyed, 1, 1.3, 0);
    // The big moment: freeze, white flash, glow burst, then a stretch of slow motion
    hit_stop(10);
    slow_mo(75);
    screen_flash(0.85);
    bloom_burst(3);
    music_duck(0.3, 90);
    add_charge(BOSS_HP / 4);
    charge_bonus(x, y, CHARGE_BONUS_BOSS);
    if (!no_loot) loot_drop(x, y, RES.ORE, BOSS_LOOT * global.tier * threat_reward_mult() * power(BOSS_GROW, boss_n), radius * 0.7, LOOT_BOSS_PIECES, boss_loot_type, true);
    if (instance_exists(obj_game)) obj_game.dlog.bosses_beaten++;
    if (gilded && !no_loot) repeat (12) chart_coin_drop(); // gilded boss: a fistful of Gold Coin chances
    if (!tier_boss) { // no Cores this time (you hold some, or you're already at its tier): loot only
        float_text(STATION_X, STATION_Y - STATION_RADIUS - 90, "BOSS DOWN", make_colour_rgb(255, 70, 210), 3);
        screen_shake(SHAKE_MAX);
        instance_destroy();
        return;
    }
    // Cores: the progression currency. Big and bright, and every collection ship
    // goes for them before anything else (see obj_collector.find_target).
    repeat (cores_drop) {
        var _k = instance_create_layer(x + random_range(-20, 20), y + random_range(-20, 20), "Instances", obj_pickup);
        _k.set_type(RES.CORE);
        _k.image_xscale = 2;
        _k.image_yscale = 2;
        var _kd = random(360); // Cores spill out further than normal loot
        _k.vx = lengthdir_x(random_range(4, 6), _kd);
        _k.vy = lengthdir_y(random_range(4, 6), _kd);
    }
    // No tier change here: the Cores pay for the next tier unlock on the upgrade tree
    float_text(STATION_X, STATION_Y - STATION_RADIUS - 90, "CORES DROPPED", make_colour_rgb(255, 70, 210), 3);
    sfx(snd_times_up, 1, 0.7, 0);
    screen_shake(SHAKE_MAX);
    global.boss_tier = max(global.boss_tier, global.tier); // no more bosses until the tier rises
    save_game();
    if (instance_exists(obj_game)) obj_game.boss_beaten = true;
    instance_destroy();
};

init(AST.SMALL, RES.ORE);
