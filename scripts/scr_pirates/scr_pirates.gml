// ---------------------------------------------------------------------------
// Pirates: Black Box drops, the Pirate System star chart, the flagship, the
// reward choice after beating it, and the payout / truce aftermath.
//   - Shot-down enemy ships can drop a Black Box (enemy collectors more often than fighters,
//     with a pity counter). 10 buy the Pirate System chart (scr_charts).
//   - Pirate System day: no asteroids. Waves of 10, 20, then 30 fighters, all attacking
//     the station (enemy collectors on even waves, to steal the salvage), then the flagship with
//     10 more. Each wave waits until the last one is wiped out. Before the flagship
//     arrives its green beam drains the charge meter for PIRATE_DRAIN seconds. Passive weapons target
//     ships today (obj_station target_nearest / target_biggest). The clock holds until
//     the flagship is beaten or retreats, then PIRATE_WRAP_UP seconds to collect.
//   - Beat it and the end-of-day screen offers: MISSILES (first time only: a Pirate
//     Hat, which unlocks the missile tree), PAYOUT (a bounty, but +25% enemies for
//     10 days; the extra ones drop no Black Boxes) or TRUCE (a quarter of the
//     bounty; enemy spawns -75%, easing 5% a day to -25%, then "the truce has ended").
// Enemy objects: obj_flagship and obj_pirate_missile are obj_enemy children, so the
// turret, rail gun, fighters and missiles can all hit them.
// ---------------------------------------------------------------------------

enum PIRATE_FX { NONE, PAYOUT, TRUCE }

// Black Boxes
#macro BOX_CHANCE_ENEMY_COLLECTOR  0.3
#macro BOX_CHANCE_FIGHTER  0.2
#macro BOX_PITY           6      // enemies downed without a box before the next one is guaranteed

// Pirate System day
#macro PIRATE_WAVES       4      // the last wave is the flagship plus PIRATE_BOSS_FIGHTERS fighters
#macro PIRATE_WAVE_SIZE   10     // fighters in wave n = this x n (10, 20, 30)
#macro PIRATE_BOSS_FIGHTERS 10    // fighters arriving with the flagship
#macro PIRATE_TRICKLE     8      // frames between fighters arriving within a wave (30 take 4s)
#macro PIRATE_FIGHTER_DMG 0.15   // pirate-day fighters' laser damage x this (there are so many of them)
#macro PIRATE_ORBIT_SPREAD 170   // pirate-day fighters circle up to this much further out (so they don't bunch)
#macro PIRATE_DRAIN       5      // seconds the flagship's beam drains the charge meter before the final wave
#macro PIRATE_DRAIN_COLOUR make_colour_rgb(90, 255, 120)
#macro PIRATE_WAVE_FIRST  3     // seconds before the first wave
#macro PIRATE_WAVE_GAP    3      // seconds after a wave is wiped out before the next one
#macro PIRATE_SALVAGE     3      // pickups each downed ship drops on a pirate day (asteroid types you've unlocked)
#macro PIRATE_WRAP_UP     10     // seconds left on the clock once the flagship is beaten or gone

// Flagship
#macro FLAGSHIP_HP        450    // before threat scaling (a tier 1 asteroid boss is 400). Was 1200: ~3 min to kill at tier 2
#macro FLAGSHIP_SHIELD    0.2    // x HP
#macro FLAGSHIP_RANGE     430    // standoff distance from the station centre...
#macro FLAGSHIP_WOBBLE    70     // ...swinging in and out by this much
#macro FLAGSHIP_SPEED     1.0    // cruising round the ring (x2 when repositioning, more when dodging)
#macro FLAGSHIP_TURN      2.5    // degrees per frame
#macro FLAGSHIP_DODGE     280    // px: the cursor this close to the hull makes it swerve away...
#macro FLAGSHIP_DODGE_PUSH 240   // ...by up to this much
#macro FLAGSHIP_LASER     1.5    // x an attacker laser (ATTACKER_DAMAGE; was 2.5, all on one side)
#macro FLAGSHIP_BROADSIDE 150    // frames between laser bursts
#macro FLAGSHIP_SALVO     540    // frames between missile salvos
#macro FLAGSHIP_LAUNCH    900    // frames between fighter launches
#macro FLAGSHIP_RETREAT   120    // seconds on the field before it gives up and leaves (no reward)
#macro FLAGSHIP_COLOUR    make_colour_rgb(255, 90, 50)
#macro PMISSILE_DMG       4     // per pirate missile, before threat_impact_mult
#macro PMISSILE_HP        3      // x threat_hp_mult(false): shootable

// Rewards and aftermath
#macro PIRATE_EFFECT_DAYS 10     // payout: days of extra enemies
#macro PAYOUT_SPAWN       1.25   // payout: enemy spawn rate
#macro TRUCE_SHARE        0.25   // truce: share of the bounty
#macro TRUCE_START        0.75   // truce: spawn reduction on its first day...
#macro TRUCE_STEP         0.05   // ...shrinking this much a day...
#macro TRUCE_FLOOR        0.25   // ...down to this, then it ends

// Player missiles (stats in scr_upgrades -> stats_build; obj_missile). All the tuning is here.
//   Right-click fires one launch (1 ammo) at the cursor; holding it fires another every
//   MISSILE_HOLD seconds until the ammo runs out. Ammo recharges one at a time.
//   Missiles fly over everything in a sidewinder weave and only go off at their target point.
// Ammo and launches
#macro MISSILE_AMMO       5      // max ammo before Launch Tubes (+1 each)
#macro MISSILE_RELOAD     5      // seconds per ammo before Auto Loader (x0.83 each: ~2 s at 5)
#macro MISSILE_HOLD       0.5    // seconds between launches while right-click is held
#macro MISSILE_PER_LAUNCH 2      // missiles per launch before Compact Tubes (+1 each, 4 ranks: 6)
#macro MISSILE_SPREAD     0.6    // several missiles land in a ring this x blast radius round the cursor
// Blast: damage falls off in four rings from the centre (100 / 75 / 50 / 25%)
#macro MISSILE_DAMAGE     50     // centre damage before Warheads (about a Tesla strike)...
#macro MISSILE_DAMAGE_PER 10     // ...+ this per Warheads rank (100 at 5)
#macro MISSILE_BLAST      50     // px blast radius before Yield (the Tesla's splash is 60)...
#macro MISSILE_BLAST_PER  10     // ...+ this per Yield rank (100 at 5)
// Shockwave: a small repulsor ring from the blast
#macro MISSILE_PUSH       25     // degrees it turns a tiny asteroid away (bigger turn less) before Yield...
#macro MISSILE_PUSH_PER   6      // ...+ this per Yield rank
#macro MISSILE_WAVE       1.8    // the ring reaches this x the blast radius
#macro MISSILE_SHOVE      0.6    // enemy ships it passes are shoved push x this px per frame (decaying)
// Flight
#macro MISSILE_SPEED      8      // top speed before Boosters (+15% each)
#macro MISSILE_WEAVE      36     // px: sidewinder swing either side of the straight line (0 at launch and target)
#macro MISSILE_WAVELENGTH 240    // px travelled per full swing
// Cluster Warheads: the missile bursts into bomblets instead of one blast
#macro CLUSTER_COUNT      5
#macro CLUSTER_SIZE       0.55   // each bomblet's blast radius and push, x the missile's
#macro CLUSTER_DAMAGE     0.5    // each bomblet's damage, x the missile's
#macro CLUSTER_SPREAD     1.1    // bomblets land in a ring this x the missile's blast radius

// --- Black Boxes -------------------------------------------------------------------

/// An enemy was shot down (obj_enemy.destroyed, its scope): salvage on a pirate day, maybe a Black Box.
function enemy_down_drops() {
    if (object_index == obj_pirate_missile || object_index == obj_flagship) return;
    if (chart_current() == CHART.PIRATE) {
        repeat (PIRATE_SALVAGE) {
            var _s = instance_create_layer(x + random_range(-8, 8), y + random_range(-8, 8), "Instances", obj_pickup);
            _s.set_type(boss_loot_type());
        }
    }
    if (no_box || !chart_token_drops(RES.BOX)) return;
    var _chance = (object_index == obj_raider) ? BOX_CHANCE_ENEMY_COLLECTOR : BOX_CHANCE_FIGHTER;
    if (global.box_pity >= BOX_PITY || random(1) < _chance) {
        global.box_pity = 0;
        var _p = instance_create_layer(x, y, "Instances", obj_pickup);
        _p.set_type(RES.BOX);
        _p.image_xscale = 1.5;
        _p.image_yscale = 1.5;
        var _d = random(360);
        _p.vx = lengthdir_x(random_range(3, 5), _d);
        _p.vy = lengthdir_y(random_range(3, 5), _d);
    } else {
        global.box_pity++;
    }
}

/// Today's enemy spawn multiplier from a payout or truce (1 = normal).
function pirate_spawn_mult() { return instance_exists(obj_game) ? obj_game.pirate_mult : 1; }

/// Payout days: true for the share of enemies that are "extra" (they drop no Black Boxes).
function pirate_extra_roll() {
    var _m = pirate_spawn_mult();
    return _m > 1 && random(1) < 1 - 1 / _m;
}

// --- Day start (obj_game scope) ----------------------------------------------------

/// Works out today's payout / truce effect and the pirate day state.
function pirate_day_init() {
    pirate_mult = 1;
    pirate_msg  = "";
    switch (global.pirate_fx) {
        case PIRATE_FX.PAYOUT:
            if (global.pirate_days >= PIRATE_EFFECT_DAYS) { global.pirate_fx = PIRATE_FX.NONE; pirate_msg = "PIRATES BACK TO NORMAL"; }
            else pirate_mult = PAYOUT_SPAWN;
            break;
        case PIRATE_FX.TRUCE:
            var _red = TRUCE_START - TRUCE_STEP * global.pirate_days;
            if (_red < TRUCE_FLOOR - 0.001) { global.pirate_fx = PIRATE_FX.NONE; pirate_msg = "THE TRUCE HAS ENDED"; }
            else pirate_mult = 1 - _red;
            break;
    }
    if (global.pirate_fx != PIRATE_FX.NONE) global.pirate_days++;

    pirate_phase    = (chart == CHART.PIRATE) ? "waves" : "none"; // "waves" -> "flagship" -> "done"
    pirate_wave     = 0;
    pirate_queue    = 0;      // fighters still to arrive this wave
    pirate_q_timer  = 0;
    drain_t         = 0;      // charge-drain beam before the final wave (pirate_drain_start)
    drain_total     = 1;
    drain_ang       = 0;
    drain_from      = 0;
    pirate_timer    = PIRATE_WAVE_FIRST * game_get_speed(gamespeed_fps);
    pirate_won      = false;  // the flagship went down today
    reward_pending  = false;  // end-of-day screen is waiting for a reward choice
    missile_ammo    = global.stats.missile_ammo; // every day starts with full ammo
    missile_cd      = missile_reload_frames();   // frames until the next ammo is back
    missile_hold    = 0;      // frames until the next launch while right-click is held
}

/// The clock holds on a pirate day until the flagship is beaten or gone.
function pirate_holds_clock() { return pirate_phase == "waves" || pirate_phase == "drain" || pirate_phase == "flagship"; }

// --- Pirate System day (obj_game scope, every world tick) -----------------------------

function pirate_step() {
    if (pirate_phase == "none" || pirate_phase == "done") return;
    var _fps = game_get_speed(gamespeed_fps);
    // A wave's fighters arrive one at a time from all round the screen
    if (pirate_queue > 0) {
        pirate_q_timer--;
        if (pirate_q_timer <= 0) {
            pirate_spawn_fighter(irandom(FIGHTER.COUNT - 1)); // colour is just for show: they all attack the station today
            pirate_queue--;
            pirate_q_timer = PIRATE_TRICKLE;
        }
    }
    if (pirate_phase == "waves") {
        // The next wave waits until every ship of this one is down (or gone), then a short breather
        var _cleared = pirate_queue <= 0 && !instance_exists(obj_enemy);
        if (pirate_wave > 0 && !_cleared) pirate_timer = PIRATE_WAVE_GAP * _fps;
        pirate_timer--;
        if (pirate_timer <= 0) {
            if (pirate_wave + 1 >= PIRATE_WAVES) pirate_drain_start(); // the flagship drains the charge meter first
            else { pirate_wave++; pirate_spawn_wave(pirate_wave); }
        }
    } else if (pirate_phase == "drain") {
        // The beam empties the charge meter over PIRATE_DRAIN seconds (it fires the full
        // time even if the meter was already empty), then the flagship arrives
        drain_t--;
        global.oc_ready = false;
        global.charge = drain_from * max(0, drain_t) / drain_total;
        hud_orbs = []; // no charge earned meanwhile
        if (drain_t mod 4 == 0) {
            var _hx = STATION_X + lengthdir_x(STATION_APOTHEM, drain_ang), _hy = STATION_Y + lengthdir_y(STATION_APOTHEM, drain_ang);
            fx_spark(_hx, _hy, 3);
            screen_shake(1);
        }
        if (drain_t mod 8 == 0) sfx(snd_laser, 0.25, 0.5, 0.1); // a low buzz while it holds
        if (drain_t <= 0) {
            global.charge = 0;
            pirate_wave++;
            pirate_queue += PIRATE_BOSS_FIGHTERS; // the last wave: the flagship and a few fighters
            pirate_q_timer = 0;
            pirate_spawn_flagship(drain_ang);   // it comes in along its beam
            pirate_phase = "flagship";
        }
    } else if (!instance_exists(obj_flagship)) {
        pirate_queue = 0; // flagship gone: the rest of the fleet doesn't come
        pirate_phase = "done";
        day_timer = min(day_timer, PIRATE_WRAP_UP * _fps); // time to bring the salvage home
    }
}

/// A fighter from just off-screen (or from (_x, _y)), on a pirate day.
function pirate_spawn_fighter(_role, _x = undefined, _y = undefined) {
    var _e = spawn_fighter(_role, random(360), _x, _y); // scr_enemies
    // Each circles at its own distance and pace, so a wave spreads out instead of
    // bunching into one ring (still inside laser range of the station)
    _e.orbit_jitter = random_range(-40, PIRATE_ORBIT_SPREAD);
    _e.spd *= random_range(0.8, 1.2);
    return _e;
}

/// Wave _n: PIRATE_WAVE_SIZE x _n fighters, queued to trickle in (pirate_step). Every
/// one attacks the station today. Even waves also bring an enemy collector to steal the salvage.
function pirate_spawn_wave(_n) {
    pirate_queue += PIRATE_WAVE_SIZE * _n;
    pirate_q_timer = 0;
    if (_n mod 2 == 0) spawn_enemy_collector(); else sfx(snd_warning, 0.6, 1, 0);
    float_text(STATION_X, STATION_Y - STATION_RADIUS - 90, "WAVE " + string(_n), FLAGSHIP_COLOUR, 2);
}

/// Before the final wave: a green beam from the unseen flagship drains the charge meter
/// (a full, unused Overcharge included). Fire Overcharge before it hits to make use of it.
function pirate_drain_start() {
    pirate_phase = "drain";
    drain_total = round(PIRATE_DRAIN * game_get_speed(gamespeed_fps));
    drain_t     = drain_total;
    drain_ang   = random(360);  // the flagship is out there, off-screen, along this line
    drain_from  = global.oc_ready ? charge_needed() : global.charge;
    global.oc_ready = false;
    hud_orbs = [];
    screen_shake(4);
    screen_flash(0.25, PIRATE_DRAIN_COLOUR);
    sfx(snd_warning, 0.8, 0.7, 0);
    float_text(STATION_X, STATION_Y - STATION_RADIUS - 90, "CHARGE DRAIN", PIRATE_DRAIN_COLOUR, 2.4);
}

/// The drain beam (obj_game Draw, world space): off-screen source to the station hull.
function pirate_drain_draw() {
    if (pirate_phase != "drain") return;
    var _sx = STATION_X + lengthdir_x(play_radius() + 100, drain_ang), _sy = STATION_Y + lengthdir_y(play_radius() + 100, drain_ang);
    var _hx = STATION_X + lengthdir_x(STATION_APOTHEM, drain_ang),     _hy = STATION_Y + lengthdir_y(STATION_APOTHEM, drain_ang);
    var _el = drain_total - drain_t, _fade = 12; // frames to fade in at the start and out at the end
    var _a = clamp(min(_el, drain_t) / _fade, 0, 1);
    var _w = 16 + 5 * sin(current_time / 35);   // the beam throbs
    gpu_set_blendmode(bm_add);
    draw_sprite_line(spr_beam_drain, 0, _sx, _sy, _hx, _hy, _w * 2.5, PIRATE_DRAIN_COLOUR, 0.35 * _a);
    draw_sprite_line(spr_beam_drain, 0, _sx, _sy, _hx, _hy, _w,       PIRATE_DRAIN_COLOUR, _a);
    draw_sprite_line(spr_beam_drain, 0, _sx, _sy, _hx, _hy, _w * 0.35, c_white, _a);
    gpu_set_blendmode(bm_normal);
}

function pirate_spawn_flagship(_ang = random(360)) {
    var _dist = play_radius() + STATION_RADIUS;
    var _f = instance_create_layer(STATION_X + lengthdir_x(_dist, _ang), STATION_Y + lengthdir_y(_dist, _ang), "Instances", obj_flagship);
    screen_shake(6);
    screen_kick(_ang, 14);
    sfx(snd_boss_arrival, 1, 0.85, 0);
    music_sting("mus_sting_boss");
    music_duck(0.35, 200);
    float_text(STATION_X, STATION_Y - STATION_RADIUS - 90, "PIRATE FLAGSHIP", FLAGSHIP_COLOUR, 3);
    return _f;
}

// --- Reward choice (end-of-day screen, obj_game scope) ---------------------------------

/// "missile" (until it's been taken once), "payout", "truce".
function pirate_reward_options() {
    var _o = [];
    if (!global.hat_taken) array_push(_o, "missile");
    array_push(_o, "payout", "truce");
    return _o;
}

/// Bounty in each asteroid resource you've unlocked, x _share.
function pirate_payout(_share) {
    static base = [150, 40, 15, 6]; // ore, ice, crystal, platinum, per tier
    var _out = array_create(RES.COUNT, 0);
    for (var r = RES.ORE; r <= RES.PLATINUM; r++) {
        if (res_unlocked(r)) _out[r] = round(base[r] * global.tier * threat_reward_mult() * _share);
    }
    return _out;
}

function pirate_reward_title(_o) {
    switch (_o) { case "missile": return "MISSILES"; case "payout": return "PAYOUT"; }
    return "TRUCE";
}
function pirate_reward_desc(_o) {
    switch (_o) {
        case "missile": return "Unlocks the missile tree";
        case "payout":  return "Full bounty, but more pirates for 10 days";
    }
    return "Quarter bounty, but fewer pirates for a while";
}

function pirate_reward_apply(_o) {
    var _pay = undefined;
    switch (_o) {
        case "missile":
            global.bank[RES.HAT] += 1;
            day_haul[RES.HAT] += 1;
            global.found[RES.HAT] = true;
            global.hat_taken = true;
            break;
        case "payout":
            _pay = pirate_payout(1);
            global.pirate_fx = PIRATE_FX.PAYOUT;
            global.pirate_days = 0;
            break;
        case "truce":
            _pay = pirate_payout(TRUCE_SHARE);
            global.pirate_fx = PIRATE_FX.TRUCE;
            global.pirate_days = 0;
            break;
    }
    if (_pay != undefined) {
        for (var r = 0; r < RES.COUNT; r++) {
            global.bank[r] += _pay[r]; day_haul[r] += _pay[r];
            if (global.last_day != undefined) global.last_day.haul[r] += _pay[r]; // the tree's "last day" row includes it
        }
    }
    if (_o == "missile" && global.last_day != undefined) global.last_day.haul[RES.HAT] += 1;
    reward_pending = false;
    reward_done = true;
    over_timer = 0; // the summary unfurls now, with the reward in the totals (and the click can't skip it)
    sfx(snd_affirmative, 0.9);
    save_game();
}

#macro REWARD_W 196
#macro REWARD_H 118
/// Card rectangle for option _i of _n, centred on screen (the summary waits until one's picked).
function pirate_reward_rect(_i, _n) {
    var _gw = display_get_gui_width(), _gh = display_get_gui_height();
    var _x = _gw / 2 - (_n * REWARD_W + (_n - 1) * 12) / 2 + _i * (REWARD_W + 12);
    var _y = _gh / 2 - REWARD_H / 2 + 12;
    return [_x, _y, _x + REWARD_W, min(_gh - 4, _y + REWARD_H)];
}

/// Option under the mouse, or "".
function pirate_reward_hover(_mx, _my) {
    var _o = pirate_reward_options(), _n = array_length(_o);
    for (var i = 0; i < _n; i++) {
        var _r = pirate_reward_rect(i, _n);
        if (point_in_rectangle(_mx, _my, _r[0], _r[1], _r[2], _r[3])) return _o[i];
    }
    return "";
}

function pirate_reward_draw(_mx, _my) {
    var _o = pirate_reward_options(), _n = array_length(_o);
    var _hov = pirate_reward_hover(_mx, _my);
    var _r0 = pirate_reward_rect(0, _n);
    draw_set_halign(fa_center);
    draw_set_valign(fa_bottom);
    draw_set_colour(FLAGSHIP_COLOUR);
    draw_text_transformed(display_get_gui_width() / 2, _r0[1] - 4, "CHOOSE YOUR REWARD", 0.8, 0.8, 0);
    draw_reset();
    for (var i = 0; i < _n; i++) {
        var _r = pirate_reward_rect(i, _n);
        var _h = (_o[i] == _hov);
        // Each card unfurls from its own centre, one after another
        var _ct = (over_timer - 10 - i * 5) / UNFURL_FRAMES;
        if (!panel_unfurl(_ct, (_r[0] + _r[2]) / 2, (_r[1] + _r[3]) / 2, _r[0], _r[1], _r[2], _r[3], _h ? c_white : FLAGSHIP_COLOUR)) continue;
        draw_set_halign(fa_center);
        draw_set_colour(_h ? c_white : FLAGSHIP_COLOUR);
        draw_text_transformed((_r[0] + _r[2]) / 2, _r[1] + 6, pirate_reward_title(_o[i]), 0.9, 0.9, 0);
        draw_set_colour(c_white);
        draw_text_ext_transformed((_r[0] + _r[2]) / 2, _r[1] + 26, pirate_reward_desc(_o[i]), -1, (REWARD_W - 16) / 0.6, 0.6, 0.6, 0);
        draw_reset();
        // What it pays: two columns of icon + number
        var _pay = undefined;
        if (_o[i] == "missile") { _pay = array_create(RES.COUNT, 0); _pay[RES.HAT] = 1; }
        else _pay = pirate_payout((_o[i] == "truce") ? TRUCE_SHARE : 1);
        var _k = 0;
        for (var r = 0; r < RES.COUNT; r++) {
            if (_pay[r] <= 0) continue;
            draw_res_amount(_r[0] + 10 + (_k mod 2) * (REWARD_W / 2), _r[1] + 74 + (_k div 2) * 18, r, string(_pay[r]), 1);
            _k++;
        }
        clip_end();
    }
}

// --- Player missiles (obj_game scope) ---------------------------------------------------

function missile_reload_frames() { return max(1, round(global.stats.missile_reload * game_get_speed(gamespeed_fps))); }

/// Every world tick: ammo comes back one at a time while it's below the max.
function missile_tick() {
    if (!global.stats.missiles) return;
    if (missile_hold > 0) missile_hold--;
    if (missile_ammo >= global.stats.missile_ammo) { missile_cd = missile_reload_frames(); return; } // full: the next one starts fresh
    missile_cd -= oc_active() ? 2 : 1; // Overcharge: reloads twice as fast
    if (missile_cd <= 0) { missile_ammo++; missile_cd = missile_reload_frames(); }
}

/// Right-click input: fire on the click, then every MISSILE_HOLD seconds while it's held.
function missile_input() {
    if (mouse_check_button_pressed(mb_right)) {
        if (missile_ammo > 0) missile_fire(); else sfx(snd_denied, 0.5);
    } else if (mouse_check_button(mb_right) && missile_ammo > 0 && missile_hold <= 0) {
        missile_fire();
    }
}

/// One launch (1 ammo): missile_count missiles leave the side of the station facing the
/// cursor, fanned a little, and weave in to a small ring round the point clicked.
function missile_fire() {
    var _st = global.stats, _n = _st.missile_count;
    var _tx = mouse_x, _ty = mouse_y;
    var _base = point_direction(STATION_X, STATION_Y, _tx, _ty);
    var _ring = (_n > 1) ? _st.missile_blast * MISSILE_SPREAD : 0;
    var _rot = random(360);
    for (var i = 0; i < _n; i++) {
        var _a = _base + (i - (_n - 1) / 2) * 14; // launch points fanned across the facing side
        var _m = instance_create_layer(STATION_X + lengthdir_x(STATION_RADIUS + 6, _a), STATION_Y + lengthdir_y(STATION_RADIUS + 6, _a), "Instances", obj_missile);
        var _pa = _rot + i * 360 / _n;
        _m.launch(_tx + lengthdir_x(_ring, _pa), _ty + lengthdir_y(_ring, _pa), (i mod 2 == 0) ? 1 : -1); // alternate weaves braid
    }
    missile_ammo--;
    missile_hold = round(MISSILE_HOLD * game_get_speed(gamespeed_fps));
    sfx(snd_missile_launch, 0.6, random_range(0.95, 1.1), 0.05);
    screen_shake(1);
}

/// A missile (or bomblet) going off at (_x, _y): radius _r, centre damage _dmg, shockwave _push.
/// Damage falls off in four rings measured to each target's edge: 100 / 75 / 50 / 25%.
function missile_blast(_x, _y, _r, _dmg, _push) {
    fx_blast(_x, _y, _r);
    sfx(snd_explosion, 0.35, random_range(1.15, 1.35), 0.1);
    screen_shake(1.5);
    // Collect first, then hit: breaking rocks spawns fragments mid-loop
    var _hits = [];
    with (obj_asteroid) if (!dead && point_distance(x, y, _x, _y) - radius < _r) array_push(_hits, id);
    with (obj_enemy)    if (!dead && point_distance(x, y, _x, _y) - radius < _r) array_push(_hits, id);
    for (var i = 0; i < array_length(_hits); i++) {
        var _h = _hits[i];
        if (!instance_exists(_h) || _h.dead) continue;
        var _edge = max(0, point_distance(_h.x, _h.y, _x, _y) - _h.radius);
        var _ring = clamp(floor(_edge / _r * 4), 0, 3);
        var _amt = _dmg * (1 - 0.25 * _ring);
        if (object_index == obj_missile) dps_hit(true, _h, _amt); // Combat HUD: your missiles count as main
        if (_h.object_index == obj_asteroid) _h.take_hit(_amt, "missile"); else _h.take_hit(_amt); // missiles crack armour
    }
    // Shockwave: a small repulsor ring that also shoves surviving ships outwards
    var _w = instance_create_layer(_x, _y, "Instances", obj_wave);
    _w.r = 0;
    _w.start_r = 0;
    _w.range = _r * MISSILE_WAVE;
    _w.deflect = _push;
    _w.shove = _push * MISSILE_SHOVE;
    _w.grow = 7;
    _w.ring_w = 10;
}
