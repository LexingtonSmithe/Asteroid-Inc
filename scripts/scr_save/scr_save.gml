// ---------------------------------------------------------------------------
// Global state, save and load.
// ---------------------------------------------------------------------------

/// Call from any controller's Create event. Only runs once per game session.
function game_init() {
    if (variable_global_exists("initialised")) return;
    global.initialised = true;
    global.frozen      = false;
    global.outline_cache_off = false; // debug (F1 in a day): draw thick outlines as 9 copies instead of the cache
    global.free_costs  = false; // debug (F12 on the tree): nothing costs anything. Not saved.
    global.bank        = array_create(RES.COUNT, 0);
    global.levels      = {};
    global.day_count   = 0;
    global.charge      = 0;     // charge points in the charge meter (scr_threat)
    global.tier        = 1;     // bosses beaten + 1
    global.chart_next  = CHART.NONE; // star chart plotted for the next day (scr_charts)
    global.found       = array_create(RES.COUNT, false); // resources ever banked (shows their star charts)
    global.chart_cond  = COND.NONE; // condition a plotted Sector Survey brings...
    global.chart_cond2 = COND.NONE; // ...and the optional second one stacked with it
    global.surveyed    = array_create(COND.COUNT, false); // conditions survived at least once (surveyable)
    global.survey_sel  = COND.NONE; // conditions picked in the tree's two survey slots (paid on launch, kept between days)
    global.survey_sel2 = COND.NONE;
    global.pirate_fx   = PIRATE_FX.NONE; // payout / truce aftermath of beating the flagship (scr_pirates)
    global.pirate_days = 0;     // days of that effect already started
    global.box_pity    = 0;     // enemies downed since the last Black Box
    global.hat_taken   = false; // the missile reward has been chosen once
    global.endings     = 0;     // times the 5:00 singularity ending has been reached on this save
    global.active_weapon = WPN.GUN; // main weapon on the cursor (scr_upgrades wpn_*), picked before launch
    global.tutorial    = 0;     // 0 = day one to teach, 1 = tree to teach, 2 = done (scr_tutorial)
    global.tip_oc      = false; // the first-Overcharge tip has been shown (scr_tutorial tip_*)
    global.tip_time    = false; // the first-time-bonus tip has been shown
    global.tip_cond    = false; // the first-condition star chart tip (tree) has been shown
    global.last_day    = undefined;
    global.day_log     = [];    // balance log: one record per day played (daylog_record)
    global.log_buys    = [];    // upgrades bought since the last day ended (go into the next record)
    global.run_id      = 1;     // which playthrough: a Reset keeps the log and starts run+1
    global.fx_ps       = undefined;
    global.shake       = 0;     // current screen shake, game pixels (scr_juice)
    global.kick_x      = 0;     // directional kick offset (scr_juice)
    global.kick_y      = 0;
    global.oc_ready    = false; // Overcharge charged and waiting (scr_threat)
    global.unlock_day  = {};    // day_count each resource unlock was bought (unlock_boost, scr_config)
    global.boss_tier   = 0;     // highest tier whose boss has been beaten: no boss again until the tier rises
    global.view_zoom   = 1;     // day zoom-out (scr_config)
    global.world_tick  = true;  // false on hit-stop / skipped slow-mo frames (scr_juice)
    global.hitstop     = 0;
    global.hitstop_cd  = 0;
    global.slowmo      = 0;
    global.flash_a     = 0;     // full-screen flash
    global.flash_col   = c_white;
    global.bloom_boost = 0;     // extra glow for big moments
    global.wind_x      = 0;     // solar wind drift, px/frame (scr_conditions)
    global.wind_y      = 0;
    global.star_rewind = 0;     // degrees the starfield still has to wind back (time bonus)
    settings_load();            // volume, glow, scanlines, shake, fullscreen (scr_settings)
    music_init();               // finds whichever mus_* tracks exist (scr_audio)
    if (!instance_exists(obj_post)) instance_create_depth(0, 0, 0, obj_post);           // post-processing, shake, transitions
    if (!instance_exists(obj_starfield)) instance_create_depth(0, 0, 50, obj_starfield); // animated background
    window_set_cursor(cr_none);  // hide the Windows cursor; obj_post draws spr_cursor instead
    display_setup();
    settings_apply();
    draw_set_font(fnt_main);
    upgrades_define();
    load_game();
    global.levels[$ "core"] = 1; // root node is always owned
    stats_build();
}

function save_game() {
    var _data = { version: SAVE_VERSION, bank: global.bank, levels: global.levels, day_count: global.day_count,
                  charge: global.charge, tier: global.tier,
                  chart_next: global.chart_next, found: global.found,
                  chart_cond: global.chart_cond, chart_cond2: global.chart_cond2, surveyed: global.surveyed,
                  survey_sel: global.survey_sel, survey_sel2: global.survey_sel2,
                  pirate_fx: global.pirate_fx, pirate_days: global.pirate_days,
                  box_pity: global.box_pity, hat_taken: global.hat_taken, oc_ready: global.oc_ready, endings: global.endings,
                  active_weapon: global.active_weapon, tutorial: global.tutorial,
                  tip_oc: global.tip_oc, tip_time: global.tip_time, tip_cond: global.tip_cond,
                  unlock_day: global.unlock_day, boss_tier: global.boss_tier,
                  run_id: global.run_id, log_buys: global.log_buys, day_log: global.day_log };
    var _buf = buffer_create(256, buffer_grow, 1);
    buffer_write(_buf, buffer_string, json_stringify(_data));
    buffer_save(_buf, SAVE_FILE);
    buffer_delete(_buf);
}

function load_game() {
    if (!file_exists(SAVE_FILE)) return;
    var _buf = buffer_load(SAVE_FILE);
    var _str = buffer_read(_buf, buffer_string);
    buffer_delete(_buf);
    try {
        var _data = json_parse(_str);
        // Saves from before the weapon rework don't fit the new tree: start fresh, but keep the
        // balance log and count it as a new run (as Reset does)
        if ((_data[$ "version"] ?? 1) < SAVE_VERSION) {
            if (is_array(_data[$ "day_log"])) global.day_log = _data.day_log;
            global.run_id = (_data[$ "run_id"] ?? 1) + 1;
            show_debug_message("Old save version: starting a fresh game");
            return;
        }
        if (is_array(_data[$ "bank"])) {
            var _n = min(array_length(_data.bank), RES.COUNT);
            for (var i = 0; i < _n; i++) global.bank[i] = _data.bank[i];
        }
        if (is_struct(_data[$ "levels"])) global.levels = _data.levels;
        global.day_count = _data[$ "day_count"] ?? 0;
        global.charge    = _data[$ "charge"] ?? _data[$ "xp"] ?? 0; // older saves called it xp
        global.tier      = _data[$ "tier"] ?? 1;
        global.chart_next = clamp(_data[$ "chart_next"] ?? CHART.NONE, 0, CHART.COUNT - 1);
        if (is_array(_data[$ "found"])) {
            var _nf = min(array_length(_data.found), RES.COUNT);
            for (var i = 0; i < _nf; i++) global.found[i] = _data.found[i];
        }
        for (var i = 0; i < RES.COUNT; i++) if (global.bank[i] > 0) global.found[i] = true; // saves from before tokens existed
        global.chart_cond = clamp(_data[$ "chart_cond"] ?? COND.NONE, 0, COND.COUNT - 1);
        global.chart_cond2 = clamp(_data[$ "chart_cond2"] ?? COND.NONE, 0, COND.COUNT - 1);
        if (is_array(_data[$ "surveyed"])) {
            var _ns = min(array_length(_data.surveyed), COND.COUNT);
            for (var i = 0; i < _ns; i++) global.surveyed[i] = _data.surveyed[i];
        }
        global.survey_sel  = clamp(_data[$ "survey_sel"]  ?? COND.NONE, SLOT_MIN, COND.COUNT - 1); // also Gold / Pirate / Random (scr_charts)
        global.survey_sel2 = clamp(_data[$ "survey_sel2"] ?? COND.NONE, SLOT_MIN, COND.COUNT - 1);
        global.pirate_fx   = clamp(_data[$ "pirate_fx"] ?? PIRATE_FX.NONE, PIRATE_FX.NONE, PIRATE_FX.TRUCE);
        global.pirate_days = _data[$ "pirate_days"] ?? 0;
        global.box_pity    = _data[$ "box_pity"] ?? 0;
        global.hat_taken   = _data[$ "hat_taken"] ?? false;
        global.endings     = _data[$ "endings"] ?? 0;
        global.active_weapon = clamp(_data[$ "active_weapon"] ?? WPN.GUN, 0, WPN.COUNT - 1);
        global.tutorial  = clamp(_data[$ "tutorial"] ?? 2, 0, 2); // saves from before the tutorial: already playing
        global.tip_oc    = _data[$ "tip_oc"] ?? false;
        global.tip_time  = _data[$ "tip_time"] ?? false;
        global.tip_cond  = _data[$ "tip_cond"] ?? false;
        global.oc_ready    = _data[$ "oc_ready"] ?? false;
        if (is_struct(_data[$ "unlock_day"])) global.unlock_day = _data.unlock_day;
        global.boss_tier = _data[$ "boss_tier"] ?? 0;
        global.run_id = _data[$ "run_id"] ?? 1;
        if (is_array(_data[$ "log_buys"])) global.log_buys = _data.log_buys;
        if (is_array(_data[$ "day_log"]))  global.day_log  = _data.day_log;
    } catch (_e) {
        show_debug_message("Save file unreadable, starting fresh: " + string(_e));
    }
}

#macro NGPLUS_ORE 500   // New Game+ starts with these in the bank
#macro NGPLUS_ICE 50

/// New Game+: a fresh save (like New Game) with a head start in the bank.
function new_game_plus() {
    reset_save();
    global.tutorial = 2; // New Game+ players have seen it all
    global.tip_oc   = true;
    global.tip_time = true;
    global.tip_cond = true;
    global.bank[RES.ORE] = NGPLUS_ORE;
    global.bank[RES.ICE] = NGPLUS_ICE;
    global.found[RES.ORE] = true;
    global.found[RES.ICE] = true;
    save_game();
}

function reset_save() {
    if (file_exists(SAVE_FILE)) file_delete(SAVE_FILE);
    // The balance log survives a reset (it's rewritten with the next save); the new run gets the next number
    global.run_id += 1;
    global.log_buys = [];
    global.bank      = array_create(RES.COUNT, 0);
    global.levels    = { core: 1 };
    global.endings   = 0;
    global.active_weapon = WPN.GUN;
    global.tutorial  = 0;     // a New Game teaches day one and the tree again (scr_tutorial)
    global.tip_oc    = false;
    global.tip_time  = false;
    global.tip_cond  = false;
    global.day_count = 0;
    global.charge    = 0;
    global.tier      = 1;
    global.chart_next = CHART.NONE;
    global.found     = array_create(RES.COUNT, false);
    global.chart_cond = COND.NONE;
    global.chart_cond2 = COND.NONE;
    global.surveyed  = array_create(COND.COUNT, false);
    global.survey_sel = COND.NONE;
    global.survey_sel2 = COND.NONE;
    global.pirate_fx = PIRATE_FX.NONE;
    global.pirate_days = 0;
    global.unlock_day = {};
    global.boss_tier  = 0;
    global.box_pity  = 0;
    global.hat_taken = false;
    global.last_day  = undefined;
    stats_build();
    if (array_length(global.day_log) > 0) save_game(); // keep the balance log on disk straight away
}

// ---------------------------------------------------------------------------
// Balance log: every day played is appended to day_log in the save file, so
// tuning can be checked against real runs. obj_game.dlog holds today's counters
// (shots, hits, damage, kills...); upgrades bought on the tree between days are
// kept in log_buys and attached to the next day's record as "bought_before".
// Read it from %LOCALAPPDATA%\Asteroid_Inc\asteroid_inc_save.json.
// ---------------------------------------------------------------------------
#macro DAYLOG_MAX 3000 // oldest records drop off past this (each is well under 1 KB)

/// [[res, amount], ...] -> { Ore: 40, Ice: 6 } (only non-zero entries)
function daylog_res(_list) {
    var _o = {};
    for (var i = 0; i < array_length(_list); i++) _o[$ res_name(_list[i][0])] = _list[i][1];
    return _o;
}
/// A RES.COUNT array -> { Ore: 120, Ice: 4 } (only non-zero entries)
function daylog_res_arr(_a) {
    var _o = {};
    for (var r = 0; r < min(array_length(_a), RES.COUNT); r++) if (_a[r] != 0) _o[$ res_name(r)] = _a[r];
    return _o;
}

/// Balance log: main weapon _w is about to hit _target for _amount. Counts what the target
/// had left at most (no overkill). Armour is ignored, so a gun bullet glancing off counts too.
function dlog_wpn(_w, _target, _amount) {
    if (!instance_exists(obj_game) || !instance_exists(_target)) return;
    obj_game.dlog.wpn_dmg[_w] += clamp(_target.hp, 0, _amount);
    dps_hit(_w == wpn_active(), _target, _amount); // Combat HUD: the weapon on the cursor is main, the rest passive
}

/// Combat HUD: _target is about to take _amount. _main = the main weapon (on the cursor, or a
/// missile); otherwise passive (passive weapons, collectors, drones, fighters, the rear gun).
/// Counts what it had left at most (no overkill). obj_game smooths it into dps_main / dps_pas.
function dps_hit(_main, _target, _amount) {
    if (!instance_exists(obj_game) || !instance_exists(_target)) return;
    var _d = clamp(_target.hp, 0, _amount);
    if (_main) { obj_game.dps_acc_main += _d; obj_game.dps_tot_main += _d; }
    else       { obj_game.dps_acc_pas  += _d; obj_game.dps_tot_pas  += _d; }
}

/// Per-weapon part of a day record: names keyed by weapon, owned weapons only.
function daylog_weapons(_d, _secs) {
    var _dmg = {}, _dps = {}, _own = [];
    for (var w = 0; w < WPN.COUNT; w++) {
        if (!wpn_owned(w)) continue;
        var _n = wpn_name(w);
        array_push(_own, _n);
        _dmg[$ _n] = round(_d.wpn_dmg[w]);
        _dps[$ _n] = (_secs > 0) ? round(10 * _d.wpn_dmg[w] / _secs) / 10 : 0;
    }
    return { active: wpn_name(wpn_active()), owned: _own, dmg: _dmg, dps: _dps };
}

/// Called by upg_buy after the level goes up. _cost = what was paid.
function daylog_buy(_u, _cost) {
    array_push(global.log_buys, { id: _u.id, name: _u.name, level: upg_level(_u.id), tier: _u.tier,
                                  cost: daylog_res(_cost) });
}

/// Called by obj_game.end_day (before save_game). _g = the obj_game instance.
function daylog_record(_g, _reason) {
    var _d = _g.dlog, _fps = game_get_speed(gamespeed_fps);
    var _conds = [];
    if (_g.condition  != COND.NONE) array_push(_conds, cond_name(_g.condition));
    if (_g.condition2 != COND.NONE) array_push(_conds, cond_name(_g.condition2));
    static fx = ["", "payout", "truce"];
    var _hull = -1, _hull_max = global.stats.max_hp;
    if (instance_exists(obj_station)) _hull = obj_station.hp;
    var _haul_total = 0;
    for (var r = 0; r < RES.COUNT; r++) _haul_total += _g.day_haul[r];
    var _lv = 0, _names = variable_struct_get_names(global.levels);
    for (var i = 0; i < array_length(_names); i++) _lv += global.levels[$ _names[i]];
    var _rec = {
        run: global.run_id,
        day: global.day_count,                  // already counted (1 = first day)
        result: _reason,                        // Time up / Station destroyed / Day abandoned / Singularity
        swallowed: _g.ending_loot,              // Singularity: resources the hole banked
        tier: global.tier,
        overcharges: _g.oc_count,               // Overcharges fired today
        chart: chart_name(_g.chart),            // "" = normal day
        conditions: _conds,                     // sector conditions (empty = none)
        pirate_fx: fx[clamp(global.pirate_fx, 0, 2)],
        secs: round(_g.day_elapsed / _fps),     // how long the day lasted, recall included
        base_secs: global.stats.day_length,
        bonus_secs: _g.bonus_secs, bonuses: _g.bonus_count,
        quota_next: round(_g.bonus_quota()),   // value the next time bonus would have needed: where the clock won
        haul: daylog_res_arr(_g.day_haul), haul_total: _haul_total,
        stolen: daylog_res_arr(_g.day_stolen),         // taken by raiders: escaped with, or still holding at the end
        rebuild_fee: daylog_res_arr(_g.rebuild_fee), // taken back when the station was destroyed or the day abandoned mid-shift
        bank_start: daylog_res_arr(_d.bank_start), bank_end: daylog_res_arr(global.bank),
        shots: _d.shots, hits: _d.hits,
        accuracy: (_d.shots > 0) ? round(100 * _d.hits / _d.shots) : -1, // % of main turret bullets that hit
        kills: { tiny: _d.kills[AST.TINY], small: _d.kills[AST.SMALL], medium: _d.kills[AST.MEDIUM], large: _d.kills[AST.LARGE] },
        dmg_in: round(_d.dmg_in), hull_lost: round(_d.hull_lost),
        dmg_src: _d.dmg_src,                           // dmg_in by source
        hull_end: round(max(0, _hull)), hull_max: round(_hull_max),
        ships: global.stats.ships, capacity: global.stats.capacity,
        launches: _d.launches, ships_lost: _d.ships_lost,
        boss_at: _d.boss_at, boss_beaten: _g.boss_beaten, bosses: _g.boss_count, bosses_beaten: _d.bosses_beaten, swarms: _g.swarm_count,
        weapons: daylog_weapons(_d, _g.day_elapsed / _fps), // active weapon, and damage / damage per second by weapon
        perf: daylog_perf(),                    // frame times, instance counts, time in heavy blocks
        upgrade_levels: _lv,                    // total levels owned across the tree
        bought_before: global.log_buys          // bought on the tree since the previous day
    };
    array_push(global.day_log, _rec);
    if (array_length(global.day_log) > DAYLOG_MAX) array_delete(global.day_log, 0, array_length(global.day_log) - DAYLOG_MAX);
    global.log_buys = [];
}

// --- Performance log -------------------------------------------------------------------
// Every frame of a day: frame time (delta_time), how fast the CPU could have run it (fps_real),
// instance counts, and the time spent in a few known-heavy blocks (perf_add). Written into each
// day's balance record as `perf`. F2 in a day shows the live numbers (obj_game Draw GUI).
#macro PERF_SLOW 1.1   // a frame counts as slow above this x the target frame time...
#macro PERF_VSLOW 2    // ...and very slow above this

/// Objects whose numbers are tracked (peak and average per frame).
function perf_objects() {
    static o = [["asteroids", obj_asteroid], ["pickups", obj_pickup], ["bullets", obj_bullet], ["rail", obj_rail],
                ["zaps", obj_zap], ["lasers", obj_laser], ["ships", obj_collector], ["drones", obj_drone],
                ["fighters", obj_fighter], ["enemies", obj_enemy], ["float_text", obj_float_text],
                ["meteors", obj_meteor], ["missiles", obj_missile], ["waves", obj_wave]];
    return o;
}

function perf_reset() {
    global.perf = { frames: 0, dt_sum: 0, dt_max: 0, slow: 0, vslow: 0, fpsr_sum: 0, fpsr_min: infinity,
                    us: {}, peak: {}, sum: {}, live: {}, n: {} };
}

/// Counts an event for the performance log (e.g. outline sprites built mid-day).
function perf_count(_key) {
    if (!variable_global_exists("perf")) return;
    global.perf.n[$ _key] = (global.perf.n[$ _key] ?? 0) + 1;
}

/// Start timing a block: var _t = perf_t(); ... perf_add("name", _t);
function perf_t() { return get_timer(); }
function perf_add(_key, _t0) {
    if (!variable_global_exists("perf")) return;
    global.perf.us[$ _key] = (global.perf.us[$ _key] ?? 0) + (get_timer() - _t0);
}

/// Once per frame (obj_game Step): frame time, fps_real and instance counts.
function perf_frame() {
    if (!variable_global_exists("perf")) perf_reset();
    var _p = global.perf;
    var _target = 1000000 / game_get_speed(gamespeed_fps); // microseconds per frame at full speed
    _p.frames++;
    _p.dt_sum += delta_time;
    _p.dt_max = max(_p.dt_max, delta_time);
    if (delta_time > _target * PERF_SLOW)  _p.slow++;
    if (delta_time > _target * PERF_VSLOW) _p.vslow++;
    _p.fpsr_sum += fps_real;
    _p.fpsr_min = min(_p.fpsr_min, fps_real);
    var _o = perf_objects();
    for (var i = 0; i < array_length(_o); i++) {
        var _k = _o[i][0], _n = instance_number(_o[i][1]);
        _p.live[$ _k] = _n;
        _p.peak[$ _k] = max(_p.peak[$ _k] ?? 0, _n);
        _p.sum[$ _k]  = (_p.sum[$ _k] ?? 0) + _n;
    }
    var _all = instance_count, _parts = (global.fx_ps != undefined) ? part_particles_count(global.fx_ps) : 0;
    _p.live[$ "all"] = _all;            _p.peak[$ "all"] = max(_p.peak[$ "all"] ?? 0, _all);             _p.sum[$ "all"] = (_p.sum[$ "all"] ?? 0) + _all;
    _p.live[$ "particles"] = _parts;    _p.peak[$ "particles"] = max(_p.peak[$ "particles"] ?? 0, _parts); _p.sum[$ "particles"] = (_p.sum[$ "particles"] ?? 0) + _parts;
}

/// Summary for the day record.
function daylog_perf() {
    if (!variable_global_exists("perf") || global.perf.frames <= 0) return {};
    var _p = global.perf, _f = _p.frames;
    var _ms = {}, _keys = variable_struct_get_names(_p.us);
    for (var i = 0; i < array_length(_keys); i++) _ms[$ _keys[i]] = round(100 * _p.us[$ _keys[i]] / _f / 1000) / 100; // ms per frame
    var _avg = {}, _ck = variable_struct_get_names(_p.sum);
    for (var i = 0; i < array_length(_ck); i++) _avg[$ _ck[i]] = round(_p.sum[$ _ck[i]] / _f);
    return {
        frames: _f,
        frame_ms_avg: round(100 * _p.dt_sum / _f / 1000) / 100,
        frame_ms_worst: round(_p.dt_max / 100) / 10,
        slow_pct: round(1000 * _p.slow / _f) / 10,     // % of frames over PERF_SLOW x target
        vslow_pct: round(1000 * _p.vslow / _f) / 10,   // % over PERF_VSLOW x target
        fps_real_avg: round(_p.fpsr_sum / _f),         // how fast the CPU could have run (higher = more headroom)
        fps_real_min: round(_p.fpsr_min),
        block_ms: _ms,                                 // ms per frame spent in timed blocks
        counts: _p.n,                                  // events counted today (outline_builds: hitch-prone cache misses)
        peak: _p.peak, avg: _avg                       // instance / particle counts
    };
}
