/// Day controller: timer, spawning, ship launches, end of day.
game_init();
stats_build();
global.frozen = false;
fx_init();

var _fps   = game_get_speed(gamespeed_fps);
day_frames = global.stats.day_length * _fps;
day_timer  = day_frames;
spawn_timer = 30;
opening_done = false; // opening wave of rocks placed on the first frame (spawn_opening_rock)
day_progress = 0;     // threat ramp (scr_threat): elapsed seconds / RAMP_TIME, uncapped
day_elapsed  = 0;     // frames since the day began (keeps counting through the recall)

// Time bonuses: banking cargo extends the day (weighted by res_value, quota x tier)
bonus_value = 0;      // banked value towards the next bonus
bonus_count = 0;      // bonuses earned today (each one raises the next quota)
bonus_secs  = 0;      // seconds added today by time bonuses
hud_time_flash = 0;   // timer flashes when a bonus lands
// A time bonus isn't added at once: it's queued and blasted into the clock 1s at a time
// over TIME_ABSORB seconds, and the clock doesn't run down while that's happening.
time_queue = 0;       // seconds still to add
time_tick  = 0;       // frames to the next 1s blast
time_gap   = 1;       // frames between blasts for the current bonus
time_got   = 0;       // seconds blasted in so far (the "+Ns" counter by the timer)
hud_time_label = 0;   // 0-1: that counter's visibility / pop
hud_time_rings = [];  // shockwave frames bursting out of the timer panel (0-1 each)
hud_time_pops  = [];  // "+1" numbers falling off the bar
boss_spawned = false; // today's first boss has arrived
boss_count   = 0;     // bosses spawned today
sched        = day_schedule(); // today's bosses and swarms [[seconds, EVT.*], ...] (scr_threat)
sched_i      = 0;     // next event to fire
swarm_t      = 0;     // frames left in the current swarm
swarm_count  = 0;     // swarms today
swarm_warned = -1;    // schedule index of the swarm already warned about
day_tier_floor = 0;   // swarms raise today's difficulty to at least their tier (threat_tier, scr_threat)
boss_beaten  = false;
enemy_collector_timer = ENEMY_COLLECTOR_FIRST * _fps; // enemy collectors only come from ENEMY_COLLECTOR_TIER (scr_enemies)
enemy_collector_rate  = 1;     // how fast enemy_collector_timer runs: more loose loot, more enemy collectors (enemy_collector_loot_mult)
enemy_collector_scan  = 0;     // frames until the loose loot is recounted
hunter_timer   = HUNTER_FIRST * _fps;   // enemy fighters have their own timers, from FIGHTER_TIER (scr_enemies)
attacker_timer = ATTACKER_FIRST * _fps;
day_haul    = array_create(RES.COUNT, 0); // resources banked by ships this day
dps_main = 0;      // Combat HUD: smoothed damage per second, main weapon...
dps_pas  = 0;      // ...and everything passive
dps_acc_main = 0;  // damage dealt since the last world tick (dps_hit)
dps_acc_pas  = 0;
dps_tot_main = 0;  // Combat HUD: damage dealt today, main weapon (MT)...
dps_tot_pas  = 0;  // ...and passive (PT)

/// Combat HUD panel (bottom left, above the missile ammo), unfurled to _t (0-1):
///   M:  main DPS          P:  passive DPS
///   MT: main total today  PT: passive total today
draw_combat_hud = function(_t) {
    var _gh = display_get_gui_height();
    var _cy2 = _gh - 8 - (global.stats.missiles ? 32 : 0); // sits on top of the missile panel when there is one
    var _cy1 = _cy2 - 40;
    var _x1 = 8, _x2 = 212, _colw = (_x2 - _x1 - 16) / 2;
    if (!panel_unfurl(_t, 24, (_cy1 + _cy2) / 2, _x1, _cy1, _x2, _cy2, HUD_EDGE)) return;
    var _mc = make_colour_rgb(255, 230, 120), _pc = make_colour_rgb(120, 220, 255);
    var _cells = [["M:",  dps_main,     _mc], ["P:",  dps_pas,     _pc],
                  ["MT:", dps_tot_main, _mc], ["PT:", dps_tot_pas, _pc]];
    var _lw = string_width("MT:") * 0.6 + 5; // labels share one width so the numbers line up
    draw_set_valign(fa_middle);
    draw_set_halign(fa_left);
    for (var i = 0; i < 4; i++) {
        var _x = _x1 + 8 + (i mod 2) * _colw, _y = _cy1 + 11 + (i div 2) * 18;
        var _num = num_compact(_cells[i][1]);
        var _ns = min(0.7, (_colw - _lw - 8) / max(1, string_width(_num))); // never runs into the next column
        draw_set_colour(merge_colour(_cells[i][2], c_black, 0.3));
        draw_text_transformed(_x, _y, _cells[i][0], 0.6, 0.6, 0);
        draw_set_colour(_cells[i][2]);
        draw_text_transformed(_x + _lw, _y, _num, _ns, _ns, 0);
    }
    draw_reset();
    clip_end();
};
day_downed  = 0;     // enemy ships shot down today (end-of-day panel; missiles don't count)
day_stolen  = array_create(RES.COUNT, 0); // loot enemy collectors escaped with this day (end-of-day panel)
day_free    = array_create(RES.COUNT, 0); // part of day_haul from special drops (gilded, bosses): no rebuild fee
rebuild_fee = array_create(RES.COUNT, 0); // taken back when the station is destroyed (REBUILD_FEE) or the day abandoned (ABANDON_FEE)
fee_total   = 0;
fee_label   = "REBUILD FEE"; // or "ABANDON FEE": what the end panel calls it
ship_rebuild = [];    // frames left on each destroyed collector's slot (it can't launch until 0)
// Damaged collectors keep their damage when they dock: each one waiting in the hangar is listed
// here by hull left (0-1). They patch up very slowly while docked (SHIP_DOCK_REPAIR) and are
// only sent out once no undamaged ship is free. A new day starts with every ship repaired.
#macro SHIP_DOCK_REPAIR 0.01  // share of max hull repaired per second while docked
hangar = [];
chart = global.chart_next; // star chart bought on the tree takes over today (scr_charts)
global.chart_next = CHART.NONE;
// Today's sector condition (scr_conditions), COND.NONE most days later on. A chart day has
// none, except the surveyed ones bought with it (a Sector Survey, or one paired with Gold).
condition  = (chart != CHART.NONE) ? chart_day_condition(chart) : cond_roll();
condition2 = (chart != CHART.PIRATE && cond_real(global.chart_cond2) && global.chart_cond2 != condition) ? global.chart_cond2 : COND.NONE; // a survey can stack a second
global.chart_cond  = COND.NONE;
global.chart_cond2 = COND.NONE;
pirate_day_init(); // payout / truce effect, Pirate System waves, missile launcher (scr_pirates)
if (chart != CHART.NONE || global.pirate_fx != PIRATE_FX.NONE || pirate_msg != "") save_game(); // chart spent, effect day counted
cond_announce_timer = 40; // frames into the day before its name is shown
warped = [];             // warp-field rocks currently out of existence: [id, frames left] (warp_tick)
cond_day_init();          // wind, black hole and meteor timers for today's condition

state      = "playing"; // "playing" | "recalling" (time up, waiting for ships) | "over"

// Balance log (scr_save daylog_*): counters for today, written to the save at end_day
dlog = {
    shots: 0, hits: 0,           // main turret bullets fired / that hit something (a ricochet counts once)
    dmg_in: 0,                   // raw damage the station was hit for (before shields and armour)
    dmg_src: {},                 // dmg_in by source (rock_large, boss, comet, explosion, enemy_laser...): what's killing the station
    hull_lost: 0,                // hull actually lost (after shields and armour)
    launches: 0, ships_lost: 0,
    kills: array_create(AST.COUNT, 0), // asteroids broken, by size (tiny, small, medium, large)
    boss_at: -1,                 // seconds into the day the first boss arrived (-1 = no boss)
    bosses_beaten: 0,            // bosses destroyed today (any of the three)
    wpn_dmg: array_create(WPN.COUNT, 0), // damage dealt by each main weapon (dlog_wpn), to compare their power
    bank_start: array_create(RES.COUNT, 0)
};
array_copy(dlog.bank_start, 0, global.bank, 0, RES.COUNT);
end_reason = "";
// The singularity ending (ENDING_* in scr_threat)
singularity  = false; // today ended in the singularity (the hole and black screen stay up behind the summary)
ending_t     = 0;     // frames since it began
ending_first = false; // first time on this save: the full message
ending_loot  = 0;     // resources the hole swallowed (banked)
ending_swirl = 0;

/// 5:00 reached: everything stops, rocks and enemies vanish, every bit of loot on screen (and in
/// the ships' holds) is banked, and a huge black hole opens on the station to swallow it.
singularity_start = function() {
    state = "ending";
    singularity  = true;
    ending_t     = 0;
    ending_first = (global.endings == 0);
    global.frozen = true; // the world stops; the ending moves the loot itself
    depth = -100;         // the hole draws over the station
    var _me = id;
    // Ships' holds: banked as they are (their carried pickups are just the picture of it)
    with (obj_collector) {
        for (var r = 0; r < RES.COUNT; r++) if (cargo[r] > 0) {
            global.bank[r] += cargo[r];
            _me.add_banked(r, cargo[r], x, y, cargo_free[r]);
            _me.ending_loot += cargo[r];
        }
        cargo = array_create(RES.COUNT, 0);
        cargo_free = array_create(RES.COUNT, 0);
        cargo_total = 0;
    }
    // Everything else loose or in flight (enemy collectors' stolen loot included) is banked too
    with (obj_pickup) {
        if (magnet) { instance_destroy(); continue; }
        var _held = carried && instance_exists(claimed_by) && claimed_by.object_index == obj_collector;
        if (!_held) {
            global.bank[res] += value;
            _me.add_banked(res, value, x, y, fee_free ? value : 0);
            _me.ending_loot += value;
        }
        carried = false; claimed_by = noone; tractored = false;
    }
    // Rocks burst (a capped number of effects), enemies, ships and shots vanish
    var _n = 0;
    with (obj_asteroid) {
        if (_n < 40) fx_break(x, y, size, type);
        _n++;
        dead = true;
        instance_destroy();
    }
    var _gone = [obj_enemy, obj_raider, obj_raider_escort, obj_flagship, obj_collector, obj_drone, obj_fighter,
                 obj_bullet, obj_rail, obj_zap, obj_laser, obj_meteor, obj_missile, obj_pirate_missile,
                 obj_wave, obj_blackhole, obj_whitehole, obj_ion_bolt];
    for (var i = 0; i < array_length(_gone); i++) with (_gone[i]) instance_destroy();
    sfx(snd_blackhole_open, 1, 0.6, 0);
    screen_flash(0.8);
    bloom_burst(3);
    screen_shake(SHAKE_MAX);
    music_duck(0.1, 600);
};

/// Each frame of the ending: the hole opens, loot spirals in, the screen fades, the message shows.
singularity_step = function(_input) {
    var _fps = game_get_speed(gamespeed_fps);
    ending_t++;
    var _t = ending_t / _fps;
    fx_update();
    var _open = min(1, _t / ENDING_GROW);
    ending_swirl += 2 + 6 * _open;
    if (ending_t == round(ENDING_FADE_AT * _fps)) sfx(snd_blackhole_collapse, 1, 0.5, 0);
    // Loot spirals into the hole, faster and faster, and is gone at its edge
    var _core = BH_CORE * ENDING_HOLE * _open;
    with (obj_pickup) {
        var _d = point_distance(STATION_X, STATION_Y, x, y);
        var _a = point_direction(STATION_X, STATION_Y, x, y) + 3 + 400 / max(40, _d);
        _d = max(0, _d - (2 + 10 * _t));
        x = STATION_X + lengthdir_x(_d, _a);
        y = STATION_Y + lengthdir_y(_d, _a);
        image_xscale = stack_scale * clamp(_d / 200, 0.2, 1);
        image_yscale = image_xscale;
        if (_d <= _core * 0.6) instance_destroy();
    }
    if (_t >= ENDING_CLICK_AT && _input && (mouse_check_button_pressed(mb_left) || keyboard_check_pressed(vk_space) || keyboard_check_pressed(vk_enter))) {
        end_day("Singularity");
    }
};
perf_reset();            // performance log for this day (scr_save)
perf_overlay = false;   // F2: live performance numbers
over_timer = 0;
reward_done = false; // pirate reward picked: the summary then unfurls with it included

instance_create_layer(STATION_X, STATION_Y, "Instances", obj_station);

// Day zoom: a camera centred on the station that slowly pulls back (scr_config)
global.view_zoom = 1;
zoom_secs = ZOOM_SECS;
view_enabled = true;
view_visible[0] = true;
view_xport[0] = 0;
view_yport[0] = 0;
view_wport[0] = room_width;   // the game surface stays the same size; the world shrinks into it
view_hport[0] = room_height;
view_camera[0] = camera_create_view(0, 0, room_width, room_height);
update_view = function() {
    var _t = day_elapsed / (zoom_secs * game_get_speed(gamespeed_fps));
    global.view_zoom = 1 + (ZOOM_MAX - 1) * clamp(_t, 0, 1);
    camera_set_view_size(view_camera[0], view_w(), view_h());
    camera_set_view_pos(view_camera[0], view_left(), view_top());
};
update_view();

// HUD animation state
hud_hp_trail = 1;                          // lagging hull fraction (white "damage taken" segment)
hud_pop      = array_create(RES.COUNT, 0); // 0-1 pop when a banked total goes up
hud_prev     = array_create(RES.COUNT, 0);
hud_charge_flash = 0;                      // pulses the charge meter when it fills
hud_tier_flash  = 0;
hud_shown    = array_create(RES.COUNT, 0); // haul as shown: counts up as flying icons land
hud_fly      = [];                         // loot icons flying from the station to the haul list
hud_row_y    = array_create(RES.COUNT, 58);// where each haul row sits (set by Draw GUI)
hud_row_x    = 0;
hud_chain    = 0;                          // icons landed in a row: each one plays a little higher
hud_chain_t  = 0;
countdown_num = 0;                         // last 5 seconds: number shown and its pop (0-1)
countdown_pop = 0;
hud_open  = 0;                             // frames since the screen wipe ended: HUD panels unfurl in
hud_boss_t = 0;                            // frames the boss bar has been out (it unfurls from the timer)
ai_launch_cd = 0;                          // Collector AI: frames before it may launch another ship
oc_timer  = 0;                             // Overcharge frames left (scr_threat)
oc_frames = 1;
oc_count  = 0;                             // Overcharges fired today (balance log)
hud_orbs   = [];                           // bonus charge orbs flying into the charge meter (charge_bonus)
hud_sparks = [];                           // sparks thrown off where an orb lands
hud_oc_tx  = 0;                            // where orbs aim: the end of the bar's fill (set by Draw GUI)
hud_oc_ty  = 0;
hud_charge_jig = 0;                        // 0-1: small jiggle when regular charge comes in
hud_charge_hit = 0;                            // 0-1: shake and light-up when a bonus orb lands
hud_orb_chain = 0;                         // orbs landed in a row: each one plays a little higher

/// Bonus charge orbs burst out of a kill (world _x, _y) and home in on the charge meter.
charge_orbs_spawn = function(_x, _y, _amt, _n) {
    var _k = display_get_gui_width() / view_w(); // world -> GUI (through the zoomed camera)
    var _gx = (_x - view_left()) * _k, _gy = (_y - view_top()) * _k;
    for (var i = 0; i < _n; i++) {
        var _d = random(360), _s = random_range(3, 7);
        array_push(hud_orbs, { x: _gx, y: _gy, px: _gx, py: _gy,
                               vx: lengthdir_x(_s, _d), vy: lengthdir_y(_s, _d),
                               life: -irandom(6), amt: _amt / _n });
    }
};

/// Pays out any orbs still in flight (the day is ending).
charge_orbs_flush = function() {
    for (var i = 0; i < array_length(hud_orbs); i++) add_charge(hud_orbs[i].amt, true);
    hud_orbs = [];
};

/// Fire Overcharge (SPACE / middle mouse once the charge meter is full).
overcharge_start = function() {
    global.oc_ready = false;
    global.charge = 0; // the meter starts from empty
    hud_orbs = [];
    oc_count++;
    oc_frames = global.stats.oc_duration * game_get_speed(gamespeed_fps);
    oc_timer  = oc_frames;
    screen_flash(0.35, OC_COLOUR);
    bloom_burst(1.5);
    screen_shake(4);
    sfx(snd_boss_arrival, 0.6, 1.5, 0);
    float_text(STATION_X, STATION_Y - STATION_RADIUS - 60, "OVERCHARGE", OC_COLOUR, 2.2);
};

/// Banked value needed for the next time bonus.
bonus_quota = function() {
    // First bonus each day needs TIME_QUOTA_STEP x tier. Each later bonus costs TIME_QUOTA_GROWTH more than the last (compounding, no cap), so a
    // long day eventually outruns what you can bank. Lower Quotas cuts the whole curve; Extended
    // Contract slows the growth.
    var _st = global.stats;
    var _first = TIME_QUOTA_STEP * sqr(global.tier); // grows with the tier squared: loot is worth more, and each sector has more Lure to buy
    return max(1, _first * power(1 + _st.time_quota_growth, bonus_count) * _st.time_quota_mult);
};

/// Called when a ship docks: counts towards the haul and, while the day is still
/// running, towards time bonuses.
add_banked = function(_r, _n, _x = STATION_X, _y = STATION_Y, _free = 0) {
    tut_day_banked(); // day-one tutorial: the ship's docked (scr_tutorial)
    day_haul[_r] += _n;
    day_free[_r] += _free; // special drops: exempt from the rebuild fee
    global.found[_r] = true; // star charts appear on the tree once their token has been banked
    // Icons fly from where it was banked to the haul list; the number counts up as they land
    var _k  = display_get_gui_width() / view_w();   // world -> GUI (through the zoomed camera)
    _x -= view_left();
    _y -= view_top();
    var _ic = min(_n, 6);
    for (var i = 0; i < _ic; i++) {
        var _amt = (_n div _ic) + (i < _n mod _ic ? 1 : 0);
        array_push(hud_fly, { r: _r, amt: _amt, x0: _x * _k + random_range(-6, 6), y0: _y * _k + random_range(-6, 6),
                              t: max(-2, -(i * 4 + array_length(hud_fly) * 2) / 28), arc: random_range(-60, 60) });
    }
    if (state != "playing") return;
    if (chart == CHART.PIRATE) return; // no time bonuses in the Pirate System (they'd only drag out the wrap-up)
    var _st = global.stats;
    bonus_value += _n * res_value(_r);
    while (bonus_value >= bonus_quota()) {
        bonus_value -= bonus_quota();
        bonus_count++;
        var _add = _st.time_bonus;
        bonus_secs += _add;
        if (time_queue <= 0) time_got = 0; // a fresh bonus: the counter starts again
        time_queue += _add;                 // blasted into the clock by time_absorb_one (Step)
        time_gap = max(1, floor(TIME_ABSORB * game_get_speed(gamespeed_fps) / max(1, ceil(time_queue))));
        if (time_tick <= 0) time_tick = 1;  // first blast next frame
        hud_time_flash = 1;
        hud_time_label = 1;
        global.star_rewind += STAR_REWIND; // the stars wind back: time going backwards
        bloom_burst(1.2);
        screen_flash(0.2, HUD_TIME);
        music_duck(0.5, 30);
        float_text(STATION_X, STATION_Y - STATION_RADIUS - 50, "+" + string(_add) + "s", HUD_TIME, 2.6);
        sfx(snd_extra_time, 0.7, 1, 0);
    }
};

/// One blast of a time bonus: up to 1s goes on the clock with a shockwave off the timer.
time_absorb_one = function() {
    var _s = min(1, time_queue);
    time_queue = max(0, time_queue - _s);
    time_got  += _s;
    var _f = _s * game_get_speed(gamespeed_fps);
    day_timer  += _f;
    day_frames += _f;
    time_tick = time_gap;
    hud_time_flash = 1;
    hud_time_label = 1;
    array_push(hud_time_rings, 0);
    array_push(hud_time_pops, { t: 0, dx: random_range(-12, 12) });
    screen_shake(1.5);
    bloom_burst(0.4);
    sfx(snd_extra_time, 0.4, min(2, 0.9 + 0.08 * time_got), 0.03); // climbs with each second
};

/// Ships can launch freely, up to the number allowed in flight at once.
/// A destroyed ship's slot stays empty while it rebuilds.
can_launch = function() { return instance_number(obj_collector) + array_length(ship_rebuild) < global.stats.ships; };

/// Launch a collector from a free slot: an undamaged ship if there is one, otherwise the
/// healthiest damaged one (it flies with the hull it came home with). Returns the ship.
launch_collector = function() {
    var _docked = global.stats.ships - instance_number(obj_collector) - array_length(ship_rebuild);
    var _c = instance_create_layer(STATION_X, STATION_Y, "Instances", obj_collector);
    if (_docked <= array_length(hangar) && array_length(hangar) > 0) { // every free ship is damaged
        var _best = 0;
        for (var i = 1; i < array_length(hangar); i++) if (hangar[i] > hangar[_best]) _best = i;
        _c.hp = max(1, _c.max_hp * hangar[_best]);
        array_delete(hangar, _best, 1);
    }
    return _c;
};

/// A collector docked: if it's damaged, it waits in the hangar with that damage.
ship_docked = function(_frac) { if (_frac < 1) array_push(hangar, _frac); };

/// A collector was shot down: its slot rebuilds over stats.ship_rebuild seconds.
ship_lost = function() {
    dlog.ships_lost++;
    array_push(ship_rebuild, round(global.stats.ship_rebuild * game_get_speed(gamespeed_fps)));
};

end_day = function(_reason) {
    if (state == "over") return;
    var _mid_shift = (state == "playing"); // the clock was still running (not the end-of-day recall)
    state = "over";
    end_reason = _reason;
    charge_orbs_flush(); // bonus charge still flying lands now
    // Loot raiders are still holding (or pulling in) when the day ends is lost with them:
    // it counts as "TAKEN BY RAIDERS", same as if they'd escaped (the singularity ending
    // releases and banks it first, so it isn't counted there)
    var _me = id;
    with (obj_pickup) if (instance_exists(claimed_by) && claimed_by.object_index == obj_raider) _me.day_stolen[res] += value;
    if (_reason == "Station destroyed") {
        global.charge = 0; global.oc_ready = false; // dying: charge meter emptied, unused Overcharge lost
    }
    // Rebuild fee (destroyed) / abandon fee (quit mid-shift): a share of today's ore / ice /
    // crystal / platinum is taken back. Special drops (gilded rocks, bosses) are left out.
    var _rate = 0;
    if (_reason == "Station destroyed") _rate = REBUILD_FEE;
    else if (_reason == "Day abandoned" && _mid_shift) { _rate = ABANDON_FEE; fee_label = "ABANDON FEE"; }
    if (_rate > 0) {
        for (var _r = RES.ORE; _r <= RES.PLATINUM; _r++) {
            var _fee = min(global.bank[_r], round(max(0, day_haul[_r] - day_free[_r]) * _rate));
            rebuild_fee[_r] = _fee;
            global.bank[_r] -= _fee;
            fee_total += _fee;
        }
    }
    global.frozen = true;
    if (_reason != "Day abandoned") sfx(snd_day_end, 0.7, 1, 0); // shift's over (time up, or the station's gone)
    global.day_count += 1;
    if (_reason == "Time up" || _reason == "Singularity") chart_survey_award(); // survived a condition day: Survey Data (scr_charts)
    if (_reason == "Singularity") {
        global.endings += 1;
        if (!global.settings.ngplus) { global.settings.ngplus = true; settings_save(); } // unlocks New Game+ on the menu
    }
    reward_pending = pirate_won; // flagship beaten: the summary waits for a reward choice (scr_pirates)
    var _net = array_create(RES.COUNT, 0); // what the day actually kept, after any rebuild fee
    for (var _r = 0; _r < RES.COUNT; _r++) _net[_r] = day_haul[_r] - rebuild_fee[_r];
    global.last_day = { reason: _reason, haul: _net, day: global.day_count };
    daylog_record(id, _reason); // balance log (scr_save)
    save_game();
};

// Day-one tutorial (scr_tutorial): one rock beside the station, the clock held until it ends
tut_day_init();
tip_init(); // one-off pause tips: first Overcharge ready, first time bonus (scr_tutorial)
