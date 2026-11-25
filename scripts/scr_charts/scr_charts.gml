// ---------------------------------------------------------------------------
// Star charts: one-off special days bought with special-drop tokens.
//   Tokens (RES.COIN, RES.SURVEY, later black boxes etc.) come from rare events.
//   Loose ones are fetched by collectors before anything else (res_special). On
//   the tree screen they buy a star chart, which takes over the NEXT day only.
// Rules:
//   1. Picked in two slots on the tree, paid on play; it replaces the next day (still a
//      normal day for day_count, charge and the threat ramp). A Gold System can carry one
//      surveyed condition; a Pirate System takes both slots.
//   2. A chart day never pays out the token that bought it (no endless loops).
//   3. Cores stay progression-only; charts cost their own tokens.
//   4. Low-roll tokens get a pity counter if needed (coins don't: ~15 rolls a rock).
//   5. A chart only shows on the tree once its token has been banked at least once.
// ---------------------------------------------------------------------------

enum CHART { NONE, GOLD, SURVEY, PIRATE, COUNT }

// Gold Coin -> Gold System
#macro COIN_CHANCE     0.5    // chance each break of a gilded rock (every size, tiny included) drops a coin
#macro GOLD_CHART_COST 10     // coins for the Gold System chart

// Survey Data -> Sector Survey: pick tomorrow's condition (one you've survived) for extra loot.
// Late on, conditions get rare (cond_chance tapers with nodes owned): this buys them back.
// No plot step: the two slots ARE the order. Pressing play pays for whatever they hold
// (survey_commit), and the picks stay set for the days after until changed back to NONE.
// Not enough Survey Data for the picks greys out the play button.
// Survey Data is tiered: a condition takes Survey Data of its tier (cond_min_tier: I, II, III).
// Each tier can also be bought outright on its card above the slots, as often as you like.
#macro SURVEY_PER_DAY     1   // Survey Data (of each condition's tier) for finishing a condition day ("Time up", not abandoned or destroyed)
#macro SURVEY_CHART_COST  3   // Survey Data of the condition's tier, per condition in a Sector Survey (two stacked = 6)
/// Extra drops (asteroids and boss) a surveyed condition adds, by its tier: +25% / +50% / +75%.
/// Two picked conditions stack (a tier 1 and a tier 3 = +100%).
function survey_reward(_cond) { static r = [0, 0.25, 0.5, 0.75]; return r[clamp(survey_tier(_cond), 1, 3)]; }
/// Total bonus from a list of conditions.
function random_reward(_t) { static r = [0, 0.25, 0.5, 0.75]; return r[clamp(_t, 1, 3)]; } // a Random pick pays as its tier
function survey_reward_sum(_l) { var _t = 0; for (var i = 0; i < array_length(_l); i++) _t += survey_reward(_l[i]); return _t; }

// Black Box -> Pirate System (scr_pirates): no asteroids, enemy waves, then the flagship.
#macro PIRATE_CHART_COST  10

/// Survey Data resource for tier _t (1-3), and the tier of a condition.
function survey_res(_t) { static r = [RES.SURVEY, RES.SURVEY, RES.SURVEY2, RES.SURVEY3]; return r[clamp(_t, 1, 3)]; }
function survey_tier(_cond) { return cond_min_tier(_cond); }
function res_is_survey(_r) { return _r == RES.SURVEY || _r == RES.SURVEY2 || _r == RES.SURVEY3; }
// Survey Data is bought on the Exchange screen (scr_exchange ex_rates).

function chart_name(_c) {
    static n = ["", "GOLD SYSTEM", "SECTOR SURVEY", "PIRATE SYSTEM"];
    return n[_c];
}
function chart_desc(_c) {
    static d = ["",
        "Every asteroid is gilded. No boss",
        "Select star system conditions",
        "Pirate waves, then their flagship"];
    return d[_c];
}
function chart_colour(_c) {
    static c = [c_white, make_colour_rgb(255, 205, 50), make_colour_rgb(110, 130, 255), make_colour_rgb(255, 90, 50)];
    return c[_c];
}
/// [token resource, amount] for a chart. A Sector Survey's is per condition.
function chart_cost(_c) {
    static k = [[RES.ORE, 0], [RES.COIN, GOLD_CHART_COST], [RES.SURVEY, SURVEY_CHART_COST], [RES.BOX, PIRATE_CHART_COST]];
    return k[_c];
}

/// Today's chart (CHART.NONE outside a day or on a normal day).
function chart_current() { return instance_exists(obj_game) ? obj_game.chart : CHART.NONE; }

/// Rule 2: false for the token that paid for today's chart. Survey Data also stops when a
/// surveyed condition rode along with a Gold System.
function chart_token_drops(_r) {
    var _c = chart_current();
    if (_c == CHART.NONE) return true;
    var _k = chart_cost(_c);
    if (_k[0] == _r) return false;
    return !(res_is_survey(_r) && array_length(cond_list()) > 0);
}

/// No asteroid boss on these chart days.
function chart_no_boss(_c) { return _c == CHART.GOLD || _c == CHART.PIRATE; }

/// Drop multiplier from today's chart (folded into threat_reward_mult): +25/50/75% per surveyed (by tier)
/// condition. On a chart day every condition was paid for (a Survey, or one paired with Gold).
function chart_reward_mult() { return (chart_current() != CHART.NONE) ? 1 + survey_reward_sum(cond_list()) : 1; }

/// Pressing play: pays for the two slots and plots tomorrow's chart. Returns false (don't
/// launch) if they can't be afforded. Condition picks stay set for the days after; Gold and
/// Pirate are one-offs, so their slot clears once paid.
function survey_commit() {
    if (global.chart_next != CHART.NONE) return true; // already paid for
    slot_tidy();
    var _a = global.survey_sel, _b = global.survey_sel2;
    if (_a == COND.NONE && _b == COND.NONE) return true;
    if (slot_short() >= 0) return false;
    var _need = slot_costs();
    if (!global.free_costs) for (var r = 0; r < RES.COUNT; r++) global.bank[r] -= _need[r];
    var _c = CHART.SURVEY;
    if (_a == SLOT_PIRATE || _b == SLOT_PIRATE)  _c = CHART.PIRATE;
    else if (_a == SLOT_GOLD || _b == SLOT_GOLD) _c = CHART.GOLD;
    // Random picks become a real condition now (an undiscovered one of their tier first)
    var _ca = _a, _cb = _b;
    if (slot_random_tier(_a) > 0) _ca = random_cond(slot_random_tier(_a), survey_valid(_b) ? _b : COND.NONE);
    if (slot_random_tier(_b) > 0) _cb = random_cond(slot_random_tier(_b), cond_real(_ca) ? _ca : COND.NONE);
    var _conds = [];
    if (cond_real(_ca)) array_push(_conds, _ca);
    if (cond_real(_cb) && _cb != _ca) array_push(_conds, _cb);
    global.chart_next  = _c;
    global.chart_cond  = (array_length(_conds) > 0) ? _conds[0] : COND.NONE;
    global.chart_cond2 = (array_length(_conds) > 1) ? _conds[1] : COND.NONE;
    // Conditions and Random picks stay set for the days after; Gold and Pirate are one-offs
    if (!survey_valid(_a) && slot_random_tier(_a) == 0) global.survey_sel  = COND.NONE;
    if (!survey_valid(_b) && slot_random_tier(_b) == 0) global.survey_sel2 = COND.NONE;
    save_game();
    return true;
}
/// Kept name: false when the slots ask for more than you have (play is greyed out).
function survey_affordable() { return global.chart_next != CHART.NONE || slot_short() < 0; }

/// Un-plots a chart paid for but never flown (an old save) and refunds it in full.
/// Its picks go back into the slots. obj_tree calls this on Create.
function chart_cancel() {
    var _c = global.chart_next;
    if (_c == CHART.NONE) return;
    if (cond_real(global.chart_cond)) global.bank[survey_res(survey_tier(global.chart_cond))] += SURVEY_CHART_COST;
    if (cond_real(global.chart_cond2) && global.chart_cond2 != global.chart_cond) global.bank[survey_res(survey_tier(global.chart_cond2))] += SURVEY_CHART_COST;
    if (_c != CHART.SURVEY) { var _k = chart_cost(_c); global.bank[_k[0]] += _k[1]; }
    switch (_c) {
        case CHART.PIRATE: global.survey_sel = SLOT_PIRATE; global.survey_sel2 = COND.NONE; break;
        case CHART.GOLD:   global.survey_sel = SLOT_GOLD;   global.survey_sel2 = global.chart_cond; break;
        default:           global.survey_sel = global.chart_cond; global.survey_sel2 = global.chart_cond2;
    }
    global.chart_next  = CHART.NONE;
    global.chart_cond  = COND.NONE;
    global.chart_cond2 = COND.NONE;
    save_game();
}

/// Today's condition when a chart is active (obj_game Create): a surveyed one, which can
/// ride along with a Gold System. Never on a Pirate System.
function chart_day_condition(_c) {
    return (_c != CHART.PIRATE && cond_real(global.chart_cond)) ? global.chart_cond : COND.NONE; // a Random pick may be undiscovered
}

/// Big name over the station, a moment after the day starts (instead of a condition).
function chart_announce(_c) {
    if (_c == CHART.NONE || !instance_exists(obj_station)) return;
    var _l = cond_list();
    if (_c == CHART.SURVEY) {
        for (var i = 0; i < array_length(_l); i++) cond_announce(_l[i], i);
        float_text(STATION_X, STATION_Y - STATION_RADIUS - 50 + 34 * max(0, array_length(_l) - 1),
                   "SURVEYED: +" + string(round(survey_reward_sum(_l) * 100)) + "% LOOT", chart_colour(_c), 1.8);
        return;
    }
    float_text(STATION_X, STATION_Y - STATION_RADIUS - 90, chart_name(_c), chart_colour(_c), 3);
    for (var i = 0; i < array_length(_l); i++) cond_announce(_l[i], i + 1); // a condition paired with Gold, underneath
    sfx((_c == CHART.PIRATE) ? snd_warning : snd_affirmative, 0.8, 0.8, 0);
    bloom_burst(1.2);
}

/// A gilded rock breaking: COIN_CHANCE of a Gold Coin popping out. Runs in the rock's scope.
function chart_coin_drop() {
    if (!gilded || !chart_token_drops(RES.COIN) || random(1) >= COIN_CHANCE) return;
    var _p = instance_create_layer(x, y, "Instances", obj_pickup);
    _p.set_type(RES.COIN);
    _p.image_xscale = 1.5;
    _p.image_yscale = 1.5;
    var _d = random(360); // flung a little further than normal loot so it reads as special
    _p.vx = lengthdir_x(random_range(3, 5), _d);
    _p.vy = lengthdir_y(random_range(3, 5), _d);
}

/// Day survived (obj_game.end_day, its scope): a condition day records the condition as
/// surveyed and pays Survey Data straight into the bank (shown in the day's haul).
function chart_survey_award() {
    if (condition == COND.NONE) return;
    global.surveyed[condition] = true;
    if (condition2 != COND.NONE) global.surveyed[condition2] = true;
    if (!chart_token_drops(RES.SURVEY)) return;
    var _cs = [condition, condition2];
    for (var i = 0; i < 2; i++) {
        if (_cs[i] == COND.NONE || (i == 1 && _cs[1] == _cs[0])) continue;
        var _r = survey_res(survey_tier(_cs[i]));
        global.bank[_r] += SURVEY_PER_DAY;
        day_haul[_r] += SURVEY_PER_DAY;
        global.found[_r] = true;
    }
}

/// A condition you can survey: a real one you've survived at least once.
function survey_valid(_cond) {
    return _cond > COND.NONE && _cond < COND.COUNT && global.surveyed[_cond];
}

/// Any real condition (a Random pick can land on one you haven't survived yet).
function cond_real(_cond) { return _cond > COND.NONE && _cond < COND.COUNT; }

/// Random I / II / III: tier _t's conditions you haven't discovered (survived) yet, other than
/// _not; once they're all found, any of that tier. Returns COND.NONE only if the tier has none.
function random_cond(_t, _not = COND.NONE) {
    var _new = [], _any = [];
    for (var c = 1; c < COND.COUNT; c++) {
        if (cond_min_tier(c) != _t || c == _not) continue;
        array_push(_any, c);
        if (!global.surveyed[c]) array_push(_new, c);
    }
    if (array_length(_new) > 0) return _new[irandom(array_length(_new) - 1)];
    if (array_length(_any) > 0) return _any[irandom(array_length(_any) - 1)];
    return COND.NONE;
}
/// How many of tier _t's conditions are still undiscovered.
function random_left(_t) {
    var _n = 0;
    for (var c = 1; c < COND.COUNT; c++) if (cond_min_tier(c) == _t && !global.surveyed[c]) _n++;
    return _n;
}

/// Conditions a survey with these two picks carries (0-2).
function survey_count(_a, _b) {
    return (survey_valid(_a) ? 1 : 0) + ((survey_valid(_b) && _b != _a) ? 1 : 0);
}

// --- The two star chart slots ------------------------------------------------------
// global.survey_sel / survey_sel2 each hold COND.NONE, a surveyed condition, SLOT_GOLD or
// SLOT_PIRATE. Gold can pair with a condition; Pirate takes both slots (the other is
// cleared and locked). Everything is paid when play is pressed (survey_commit).
#macro SLOT_GOLD   -1
#macro SLOT_PIRATE -2
#macro SLOT_RAND1  -3   // Random I / II / III: a condition of that tier, rolled when play is pressed
#macro SLOT_RAND2  -4
#macro SLOT_RAND3  -5
#macro SLOT_MIN    -5   // lowest slot value (scr_save clamps to it)

/// Tier (1-3) of a Random pick, or 0 for anything else.
function slot_random_tier(_v) { return (_v <= SLOT_RAND1 && _v >= SLOT_RAND3) ? SLOT_RAND1 + 1 - _v : 0; }
/// The Random pick for tier _t.
function slot_random(_t) { return SLOT_RAND1 + 1 - _t; }

/// A pick that can be made: a surveyed condition, or a chart whose token has been banked.
function slot_valid(_v) {
    if (_v == SLOT_GOLD)   return global.found[RES.COIN];
    if (_v == SLOT_PIRATE) return global.found[RES.BOX];
    var _t = slot_random_tier(_v);
    if (_t > 0) return global.tier >= _t && global.found[survey_res(_t)]; // once you've had that tier's Survey Data
    return survey_valid(_v);
}
function slot_name(_v) {
    if (_v == SLOT_GOLD)   return chart_name(CHART.GOLD);
    if (_v == SLOT_PIRATE) return chart_name(CHART.PIRATE);
    var _rt = slot_random_tier(_v);
    if (_rt > 0) { var _num = ["", "I", "II", "III"]; return "RANDOM " + _num[_rt]; }
    return (_v == COND.NONE) ? "NONE" : cond_name(_v);
}
function slot_colour(_v) {
    if (_v == SLOT_GOLD)   return chart_colour(CHART.GOLD);
    if (_v == SLOT_PIRATE) return chart_colour(CHART.PIRATE);
    if (slot_random_tier(_v) > 0) return res_colour(survey_res(slot_random_tier(_v)));
    return (_v == COND.NONE) ? c_gray : cond_colour(_v);
}
/// [resource, amount] one pick costs ([RES.ORE, 0] for NONE).
function slot_cost(_v) {
    if (_v == SLOT_GOLD)   return chart_cost(CHART.GOLD);
    if (_v == SLOT_PIRATE) return chart_cost(CHART.PIRATE);
    if (slot_random_tier(_v) > 0) return [survey_res(slot_random_tier(_v)), SURVEY_CHART_COST]; // same as picking one
    return survey_valid(_v) ? [survey_res(survey_tier(_v)), SURVEY_CHART_COST] : [RES.ORE, 0];
}

/// Drops picks that are no longer valid, repeats, and anything beside a Pirate System.
function slot_tidy() {
    if (!slot_valid(global.survey_sel)) global.survey_sel = COND.NONE;
    if (!slot_valid(global.survey_sel2) || (global.survey_sel2 == global.survey_sel && slot_random_tier(global.survey_sel) == 0)) global.survey_sel2 = COND.NONE; // two Randoms is fine
    if (global.survey_sel  == SLOT_PIRATE) global.survey_sel2 = COND.NONE;
    if (global.survey_sel2 == SLOT_PIRATE) global.survey_sel  = COND.NONE;
}
function slot_pick(_slot) { slot_tidy(); return (_slot == 1) ? global.survey_sel : global.survey_sel2; }
/// Slot _slot is shut because the other one holds the Pirate System.
function slot_locked(_slot) { return slot_pick(3 - _slot) == SLOT_PIRATE; }

/// What both picks cost together, per resource.
function slot_costs() {
    slot_tidy();
    var _need = array_create(RES.COUNT, 0);
    var _p = [global.survey_sel, global.survey_sel2];
    for (var i = 0; i < 2; i++) { var _k = slot_cost(_p[i]); _need[_k[0]] += _k[1]; }
    return _need;
}
/// First resource the picks need more of than you have, or -1.
function slot_short() {
    if (global.free_costs) return -1;
    var _need = slot_costs();
    for (var r = 0; r < RES.COUNT; r++) if (global.bank[r] < _need[r]) return r;
    return -1;
}

/// Steps slot _slot (1 or 2) to the next (_dir 1) or previous (_dir -1) option:
/// NONE, Gold System, Pirate System, then each surveyed condition. Picking the Pirate
/// System clears the other slot; Gold can't be in both.
function survey_cycle(_slot, _dir) {
    var _cur   = slot_pick(_slot);
    var _other = slot_pick(3 - _slot);
    var _opts = [COND.NONE];
    if (slot_valid(SLOT_GOLD) && _other != SLOT_GOLD) array_push(_opts, SLOT_GOLD);
    if (slot_valid(SLOT_PIRATE)) array_push(_opts, SLOT_PIRATE);
    for (var t = 1; t <= 3; t++) if (slot_valid(slot_random(t))) array_push(_opts, slot_random(t));
    for (var c = 1; c < COND.COUNT; c++) if (survey_valid(c) && c != _other) array_push(_opts, c);
    var _i = 0;
    for (var j = 0; j < array_length(_opts); j++) if (_opts[j] == _cur) _i = j;
    _i = (_i + _dir + array_length(_opts)) mod array_length(_opts);
    var _v = _opts[_i];
    if (_slot == 1) global.survey_sel = _v; else global.survey_sel2 = _v;
    if (_v == SLOT_PIRATE) { if (_slot == 1) global.survey_sel2 = COND.NONE; else global.survey_sel = COND.NONE; }
}

/// "NEXT: GOLD SYSTEM + SOLAR WIND" over the play button ("" with nothing picked).
function slot_next_label() {
    var _a = slot_pick(1), _b = slot_pick(2), _t = "";
    if (_a != COND.NONE) _t = slot_name(_a);
    if (_b != COND.NONE) _t += ((_t == "") ? "" : " + ") + slot_name(_b);
    return (_t == "") ? "" : "NEXT: " + _t;
}
function slot_next_colour() {
    var _a = slot_pick(1), _b = slot_pick(2);
    if (_a == SLOT_PIRATE || _b == SLOT_PIRATE) return chart_colour(CHART.PIRATE);
    if (_a == SLOT_GOLD   || _b == SLOT_GOLD)   return chart_colour(CHART.GOLD);
    return chart_colour(CHART.SURVEY);
}

// --- Tree screen panel (GUI space) -------------------------------------------------
#macro CHART_PANEL_W 340
#macro CHART_ROW_H   30
#macro CHART_ARROW_W 22   // click zones at each end that step the pick

/// The panel shows once there's anything to pick.
function chart_panel_shown() {
    if (slot_valid(SLOT_GOLD) || slot_valid(SLOT_PIRATE)) return true;
    for (var c = 1; c < COND.COUNT; c++) if (survey_valid(c)) return true;
    return false;
}

/// Rectangle [x1, y1, x2, y2] for slot _slot (1 top, 2 bottom), in the bottom-right corner.
function chart_slot_rect(_slot) {
    var _x2 = display_get_gui_width() - 16;
    var _y2 = display_get_gui_height() - 20 - (2 - _slot) * (CHART_ROW_H + 4);
    return [_x2 - CHART_PANEL_W, _y2 - CHART_ROW_H, _x2, _y2];
}

/// Slot under the mouse (1 or 2), or 0. (Survey Data is bought on the Exchange screen now.)
function chart_slot_at(_mx, _my) {
    if (!chart_panel_shown()) return 0;
    for (var s = 1; s <= 2; s++) {
        var _r = chart_slot_rect(s);
        if (point_in_rectangle(_mx, _my, _r[0], _r[1], _r[2], _r[3])) return s;
    }
    return 0;
}

/// Click on a slot: the left end steps back, anywhere else forwards.
function chart_click(_slot, _mx, _my) {
    if (_slot <= 0) return;
    if (slot_locked(_slot)) { sfx(snd_denied, 0.5); return; }
    var _r = chart_slot_rect(_slot);
    survey_cycle(_slot, (_mx < _r[0] + CHART_ARROW_W) ? -1 : 1);
    sfx(snd_ui_click, 0.5, 1, 0.05);
}

/// Draws the two slots and the modifier box above them (no hover tooltips).
function chart_draw_panel(_mx, _my) {
    if (!chart_panel_shown()) return;
    var _top = chart_slot_rect(1);
    draw_set_colour(make_colour_rgb(150, 170, 200));
    draw_set_valign(fa_bottom);
    draw_text_transformed(_top[0], _top[1] - 4, "STAR CHARTS", 0.7, 0.7, 0);
    draw_reset();
    var _hi   = chart_slot_at(_mx, _my);
    chart_draw_modifiers();
    var _need = slot_costs();
    for (var s = 1; s <= 2; s++) {
        var _r = chart_slot_rect(s), _v = slot_pick(s), _lock = slot_locked(s);
        var _col = slot_colour(_v);
        var _cy = (_r[1] + _r[3]) / 2;
        var _bg = make_colour_rgb(18, 22, 30);
        if (_v != COND.NONE) _bg = merge_colour(_col, c_black, 0.8);
        if (_hi == s && !_lock) _bg = merge_colour(_bg, c_white, 0.1);
        draw_set_colour(_bg);
        draw_rectangle(_r[0], _r[1], _r[2], _r[3], false);
        draw_set_colour(_lock ? c_dkgray : merge_colour((_v == COND.NONE) ? c_gray : _col, c_black, 0.3));
        draw_frame(_r[0], _r[1], _r[2], _r[3]);
        var _sx1 = _r[0] + CHART_ARROW_W + 4, _sx2 = _r[2] - CHART_ARROW_W - 4;
        draw_set_valign(fa_middle);
        draw_set_colour(_lock ? c_dkgray : c_gray);
        draw_text_transformed(_sx1, _cy, string(s), 0.6, 0.6, 0);
        if (_lock) {
            draw_set_halign(fa_center);
            draw_text_transformed((_sx1 + _sx2) / 2, _cy, "TAKEN BY PIRATE SYSTEM", 0.6, 0.6, 0);
            draw_reset();
            continue;
        }
        draw_reset();
        // Arrows at each end (the hovered end lights up)
        for (var a = -1; a <= 1; a += 2) {
            var _ax = (a < 0) ? _r[0] + CHART_ARROW_W / 2 : _r[2] - CHART_ARROW_W / 2;
            var _ah = (_hi == s) && ((a < 0) == (_mx < _r[0] + CHART_ARROW_W));
            draw_set_colour(_ah ? c_white : ((_v == COND.NONE) ? c_gray : _col));
            draw_triangle(_ax - 4 * a, _cy - 5, _ax - 4 * a, _cy + 5, _ax + 5 * a, _cy, false);
        }
        // Cost on the right: icon and have/need, red frame if short
        var _tx2 = _sx2;
        if (_v != COND.NONE) {
            var _k  = slot_cost(_v);
            var _ct = string(floor(global.bank[_k[0]])) + "/" + string(_k[1]);
            var _cw = 8 * 1.2 + 6 + string_width(_ct) * 0.96; // matches draw_res_amount at 1.2
            draw_res_amount(_sx2 - _cw, _cy, _k[0], _ct, 1.2);
            _tx2 = _sx2 - _cw - 8;
            if (global.bank[_k[0]] < _need[_k[0]]) { draw_set_colour(c_red); draw_frame(_r[0], _r[1], _r[2], _r[3]); draw_reset(); }
        }
        var _txt = slot_name(_v);
        var _nx  = _sx1 + 16;
        var _ss  = min(0.8, (_tx2 - _nx) / max(1, string_width(_txt)));
        draw_set_valign(fa_middle);
        draw_set_colour(_col);
        draw_text_transformed(_nx, _cy, _txt, _ss, _ss, 0);
        draw_reset();
    }
}

/// "CURRENT MODIFIERS" box above the slots: what the picks will do on the next day.
///   Sticky + Solar Wind Sector
///   Things love to stick to these asteroids
///   A solar gale is blowing through this space
///   Bonus loot: 75%
function chart_draw_modifiers() {
    var _a = slot_pick(1), _b = slot_pick(2);
    var _conds = [], _chart = COND.NONE;
    var _p = [_a, _b];
    var _rand = [];
    for (var i = 0; i < 2; i++) {
        if (_p[i] == SLOT_GOLD || _p[i] == SLOT_PIRATE) _chart = _p[i];
        else if (slot_random_tier(_p[i]) > 0) array_push(_rand, slot_random_tier(_p[i]));
        else if (_p[i] != COND.NONE) array_push(_conds, _p[i]);
    }
    if (_chart == COND.NONE && array_length(_conds) == 0 && array_length(_rand) > 0) _chart = slot_random(_rand[0]); // title colour
    if (_chart == COND.NONE && array_length(_conds) == 0 && array_length(_rand) == 0) return;
    // Title, flavour lines and bonus
    var _sec = "";
    for (var i = 0; i < array_length(_conds); i++) _sec += ((i > 0) ? " + " : "") + cond_short(_conds[i]);
    var _num = ["", "I", "II", "III"];
    for (var i = 0; i < array_length(_rand); i++) _sec += ((_sec != "") ? " + " : "") + "Random " + _num[_rand[i]];
    if (_sec != "") _sec += " Sector";
    var _title = (_chart == SLOT_GOLD || _chart == SLOT_PIRATE) ? ((_chart == SLOT_GOLD) ? "Gold System" : "Pirate System") + ((_sec != "") ? " + " + _sec : "") : _sec;
    var _lines = [];
    if (_chart == SLOT_GOLD)   array_push(_lines, chart_desc(CHART.GOLD));
    if (_chart == SLOT_PIRATE) array_push(_lines, chart_desc(CHART.PIRATE));
    for (var i = 0; i < array_length(_conds); i++) array_push(_lines, cond_desc(_conds[i]));
    for (var i = 0; i < array_length(_rand); i++)
        array_push(_lines, (random_left(_rand[i]) > 0) ? "An undiscovered tier " + _num[_rand[i]] + " condition awaits" : "A random tier " + _num[_rand[i]] + " condition");
    var _bonus = survey_reward_sum(_conds);
    for (var i = 0; i < array_length(_rand); i++) _bonus += random_reward(_rand[i]);
    _bonus = round(_bonus * 100);
    var _tcol = (_chart != COND.NONE) ? slot_colour(_chart) : slot_colour(_conds[0]);
    // Box: same width as the slots, sitting on the STAR CHARTS heading
    var _top = chart_slot_rect(1);
    var _sc = 0.7, _lh = string_height("A") * _sc + 4;
    var _n  = 1 + array_length(_lines) + ((_bonus > 0) ? 1 : 0);
    var _x1 = _top[0], _x2 = _top[2];
    var _y2 = _top[1] - 24, _y1 = _y2 - (_n * _lh + 14);
    draw_set_colour(make_colour_rgb(18, 22, 30));
    draw_rectangle(_x1, _y1, _x2, _y2, false);
    draw_set_colour(merge_colour(_tcol, c_black, 0.3));
    draw_frame(_x1, _y1, _x2, _y2);
    draw_set_colour(make_colour_rgb(150, 170, 200));
    draw_set_valign(fa_bottom);
    draw_text_transformed(_x1, _y1 - 4, "CURRENT MODIFIERS", 0.7, 0.7, 0);
    draw_set_valign(fa_top);
    var _y = _y1 + 7, _w = _x2 - _x1 - 16;
    draw_set_colour(_tcol);
    var _ts = min(0.8, _w / max(1, string_width(_title)));
    draw_text_transformed(_x1 + 8, _y, _title, _ts, _ts, 0);
    _y += _lh;
    draw_set_colour(c_white);
    for (var i = 0; i < array_length(_lines); i++) {
        var _ls = min(_sc, _w / max(1, string_width(_lines[i])));
        draw_text_transformed(_x1 + 8, _y, _lines[i], _ls, _ls, 0);
        _y += _lh;
    }
    if (_bonus > 0) {
        draw_set_colour(make_colour_rgb(150, 255, 110));
        draw_text_transformed(_x1 + 8, _y, "Bonus loot: " + string(_bonus) + "%", _sc, _sc, 0);
    }
    draw_reset();
}
