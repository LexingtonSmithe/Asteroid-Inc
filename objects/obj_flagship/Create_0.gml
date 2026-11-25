/// Pirate flagship: the Pirate System day's boss (scr_pirates). As big as the station.
/// Comes in to a standoff ring and circles it: laser broadsides, missile salvos (obj_pirate_missile,
/// shootable) and fighter launches. Leaves after FLAGSHIP_RETREAT seconds if it isn't beaten.
event_inherited();
sprite_index = spr_raider;
var _sc = STATION_RADIUS * 2 / sprite_get_width(spr_raider);
image_xscale = _sc;
image_yscale = _sc;
image_blend = FLAGSHIP_COLOUR;
radius = STATION_RADIUS;
var _hp = FLAGSHIP_HP * threat_hp_mult(false);
setup(_hp, _hp * FLAGSHIP_SHIELD);
charge_value = 100 * global.tier;
spd = FLAGSHIP_SPEED * 2;
turn_rate = FLAGSHIP_TURN;
dir = point_direction(x, y, STATION_X, STATION_Y);
image_angle = dir - SHIP_ART_ANGLE;
broadside_t = 90;
salvo_t = 240;
launch_t = 420;
burst_left = 0;
burst_t = 0;
life = 0;
retreating = false;

// Spreading the damage: it counts the broadsides each station side has taken and
// works its way round to the nearest side that has had the fewest (ties picked at random),
// so it sweeps round the station rather than crossing the map between bursts.
side_hits = array_create(SHIELD_SIDES, 0);
target_side = 0;     // side it's heading round to
broadside_side = 0;  // side the current burst is aimed at
pick_side = function() {
    var _min = infinity;
    for (var i = 0; i < SHIELD_SIDES; i++) _min = min(_min, side_hits[i]);
    var _here = point_direction(STATION_X, STATION_Y, x, y);
    var _opts = [], _best = infinity;
    for (var i = 0; i < SHIELD_SIDES; i++) {
        if (side_hits[i] > _min) continue;
        var _d = round(abs(angle_difference(i * 45, _here)) / 45); // sides away round the ring
        if (_d < _best) { _best = _d; _opts = []; }
        if (_d == _best) array_push(_opts, i);
    }
    target_side = _opts[irandom(array_length(_opts) - 1)];
};
pick_side();

/// Missiles launch from both flanks, alternating, then home on the station.
fire_salvo = function() {
    var _n = 4 + global.tier;
    for (var i = 0; i < _n; i++) {
        var _side = (i mod 2 == 0) ? 90 : -90;
        var _a = dir + _side + random_range(-25, 25);
        var _m = instance_create_layer(x + lengthdir_x(radius * 0.6, _a), y + lengthdir_y(radius * 0.6, _a), "Instances", obj_pirate_missile);
        _m.dir = _a;
        _m.wait = i * 4; // ripple out one after another
    }
    sfx(snd_warning, 0.7, 0.7, 0);
};

destroyed = function() {
    // Big finish: ring of blasts, freeze, flash, slow motion, salvage shower
    for (var i = 0; i < 8; i++) {
        var _a = i * 45;
        fx_blast(x + lengthdir_x(radius * 0.6, _a), y + lengthdir_y(radius * 0.6, _a), 50);
    }
    sfx(snd_station_destroyed, 1, 1.3, 0);
    sfx(snd_ship_destroyed, 1, 0.7, 0); // layered under: a big ship going down
    hit_stop(10);
    slow_mo(75);
    screen_flash(0.85);
    bloom_burst(3);
    music_duck(0.3, 90);
    screen_shake(SHAKE_MAX);
    add_charge(charge_value);
    charge_bonus(x, y, CHARGE_BONUS_BOSS);
    loot_drop(x, y, RES.ORE, BOSS_LOOT * global.tier * threat_reward_mult(), radius * 0.7, LOOT_BOSS_PIECES, boss_loot_type, true);
    float_text(STATION_X, STATION_Y - STATION_RADIUS - 90, "FLAGSHIP DOWN", FLAGSHIP_COLOUR, 3);
    if (instance_exists(obj_game)) obj_game.pirate_won = true;
    with (obj_raider_escort) fleeing = true; // the rest of the fleet scatters
    with (obj_pirate_missile) { dead = true; fx_spark(x, y); instance_destroy(); }
    instance_destroy();
};
