/// HUD: panels, bars and icons; no words during play.
var _gw = display_get_gui_width();
var _gh = display_get_gui_height();
var _st = global.stats;
var _fps = game_get_speed(gamespeed_fps);
draw_reset();
global.hud_rec = (oc_timer > 0) ? [] : undefined; // Overcharge: panels drawn below get lightning round them
if (!transition_active()) hud_open++;              // HUD panels unfurl once the wipe has cleared, staggered
var _hud_t = function(_delay) { return (hud_open - _delay) / UNFURL_FRAMES; };

// --- Damage vignette: red edges flash when the hull is hit -------------------
if (instance_exists(obj_station) && obj_station.hurt_flash > 0) {
    var _a = obj_station.hurt_flash / 8 * 0.35;
    draw_set_alpha(_a);
    draw_set_colour(HUD_HULL);
    draw_frame(0, 0, _gw, _gh, 8);          // solid red band...
    draw_set_alpha(_a * 0.5);
    draw_frame(8, 8, _gw - 8, _gh - 8, 8);  // ...fading inwards
    draw_reset();
}

// --- Top left: hull + shield ------------------------------------------------
if (instance_exists(obj_station)) {
    var _hp = obj_station.hp / _st.max_hp;
    hud_hp_trail = (hud_hp_trail > _hp) ? max(_hp, hud_hp_trail - 0.004) : _hp;
    var _has_sh = _st.max_shield > 0;
    if (panel_unfurl(_hud_t(0), 24, 24, 8, 8, 232, _has_sh ? 60 : 40, HUD_EDGE, 0.55, false)) { // no outline; // grows from the station icon

    // Hull: station icon + bar (pulses when low)
    var _ic = 22 / sprite_get_width(spr_station);
    draw_sprite_ext(spr_station, 0, 24, 24, _ic, _ic, 0, c_white, 1);
    var _hc = HUD_HULL;
    if (_hp < 0.3) _hc = merge_colour(HUD_HULL, c_white, 0.5 + 0.5 * sin(current_time / 90));
    draw_seg_bar(42, 16, 182, 16, _hp, _hc, 10, hud_hp_trail);

    // Shield
    if (_has_sh) {
        // One cell per station side (0 = right, going anticlockwise), dim while recharging
        draw_icon_shield(24, 46, 7, HUD_SHIELD);
        var _cw = 182 / SHIELD_SIDES;
        for (var i = 0; i < SHIELD_SIDES; i++) {
            var _sf = obj_station.shields[i] / _st.max_shield;
            var _scol = (_sf < 1) ? merge_colour(HUD_SHIELD, c_black, 0.4) : HUD_SHIELD;
            var _bx = 42 + i * _cw, _bw = _cw - 3;
            draw_set_alpha(0.6);
            draw_set_colour(c_black);
            draw_rectangle(_bx, 40, _bx + _bw, 50, false);
            draw_set_alpha(1);
            draw_set_colour(_scol);
            if (_sf > 0) draw_rectangle(_bx, 40, _bx + _bw * clamp(_sf, 0, 1), 50, false);
            draw_set_colour(merge_colour(HUD_SHIELD, c_white, 0.3));
            draw_frame(_bx, 40, _bx + _bw, 50, 1);
            draw_reset();
        }
    }
    clip_end();
    }
}

// --- Top centre: day timer (yellow) ------------------------------------------
// 450 px bar, a little left of centre so the "+Ns" label clears the resource list,
// but never into the hull panel (top left, ends at x 232)
var _tw = 450, _tx = max(_gw / 2 - 210, 232 + 12 + 30);
var _tr = _tx + _tw + 8;      // panel right edge
var _timer_on = panel_unfurl(_hud_t(3), _gw / 2, 24, _tx - 30, 2, _tr, 40, HUD_TIME); // grows from the top centre
var _tcol = HUD_TIME;
var _tf = day_timer / day_frames;
if (state == "recalling") {
    // Time's up, ships heading home: flash between yellow and red
    _tcol = merge_colour(HUD_TIME, HUD_HULL, 0.5 + 0.5 * sin(current_time / 120));
    _tf = 1;
} else if (day_timer < 5 * _fps) {
    // Final seconds: flicker
    _tcol = ((day_timer div 8) mod 2 == 0) ? HUD_TIME : c_white;
}
// Time bonus just landed: flash white
hud_time_flash = max(0, hud_time_flash - 0.03);
if (hud_time_flash > 0) _tcol = merge_colour(_tcol, c_white, hud_time_flash);
if (_timer_on) draw_icon_clock(_tx - 14, 21, 9, _tcol);
var _bo = round(4 * hud_time_flash); // time bonus: the bar bounces fat, then settles
if (_timer_on) { draw_seg_bar(_tx, 14 - _bo, _tw, 14 + _bo * 2, _tf, _tcol, 12); clip_end(); }

// Time bonus soaking in: shockwave frames off the panel, "+1"s falling off the bar's end,
// and a "+Ns" counter beside the timer that climbs with each blast
for (var i = array_length(hud_time_rings) - 1; i >= 0; i--) {
    hud_time_rings[i] += 1 / 30;
    var _r = hud_time_rings[i];
    if (_r >= 1) { array_delete(hud_time_rings, i, 1); continue; }
    var _e = ease_out_cubic(_r) * 36;
    draw_set_colour(merge_colour(c_white, HUD_TIME, _r));
    draw_set_alpha(1 - _r);
    draw_frame(_tx - 30 - _e, 2 - _e * 0.5, _tr + _e, 40 + _e * 0.5, max(1, round(6 * (1 - _r))));
    draw_reset();
}
for (var i = array_length(hud_time_pops) - 1; i >= 0; i--) {
    var _p = hud_time_pops[i];
    _p.t += 1 / 40;
    if (_p.t >= 1) { array_delete(hud_time_pops, i, 1); continue; }
    var _ps = 1.6 * (1 + 0.6 * (1 - ease_out_cubic(min(1, _p.t * 3))));
    draw_set_colour(merge_colour(c_white, HUD_TIME, _p.t));
    draw_set_alpha(1 - _p.t * _p.t);
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_text_transformed(_tx + _tw * _tf + _p.dx, 30 + ease_out_cubic(_p.t) * 40, "+1", _ps, _ps, 0);
    draw_reset();
}
if (time_queue > 0) hud_time_label = 1; else hud_time_label = max(0, hud_time_label - 0.012);
if (hud_time_label > 0 && time_got > 0) {
    var _ls = 1.6 + 0.8 * hud_time_flash;
    draw_set_colour(merge_colour(HUD_TIME, c_white, hud_time_flash));
    draw_set_alpha(min(1, hud_time_label * 2));
    draw_set_halign(fa_left);
    draw_set_valign(fa_middle);
    draw_text_transformed(_tr + 10, 24, "+" + string(round(time_got)) + "s", _ls, _ls, 0);
    draw_reset();
}

// Strip under the timer: progress towards the next time bonus (none in the Pirate System)
if (state == "playing" && chart != CHART.PIRATE) {
    var _bf = clamp(bonus_value / bonus_quota(), 0, 1);
    draw_set_colour(merge_colour(HUD_TIME, c_black, 0.75));
    draw_rectangle(_tx, 31, _tx + _tw, 35, false);
    draw_set_colour(merge_colour(HUD_TIME, c_black, 0.25));
    if (_bf > 0) draw_rectangle(_tx, 31, _tx + _tw * _bf, 35, false);
    // Purple strip above the timer: countdown to the next boss on today's schedule. Drains from the
    // previous boss (or the start of the day) and refills when one spawns. Hidden once they're done.
    var _nb = -1, _pt = 0;
    if (!chart_no_boss(chart)) for (var _si = 0; _si < array_length(sched); _si++) {
        if (sched[_si][1] == EVT.SWARM) continue;
        if (_si < sched_i) _pt = sched[_si][0]; else { _nb = _si; break; }
    }
    if (_nb >= 0) {
        var _pc = make_colour_rgb(190, 120, 255);
        var _pf = clamp((sched[_nb][0] * _fps - day_elapsed) / (max(1, sched[_nb][0] - _pt) * _fps), 0, 1);
        draw_set_colour(merge_colour(_pc, c_black, 0.75));
        draw_rectangle(_tx, 7, _tx + _tw, 11, false);
        draw_set_colour(merge_colour(_pc, c_black, 0.25));
        if (_pf > 0) draw_rectangle(_tx, 7, _tx + _tw * _pf, 11, false);
    }
    draw_reset();
}

// Schedule markers on the timer: a magenta diamond for each boss still to come, a red triangle for each
// swarm, shown only once the day is long enough to reach it (bonus time can bring one in)
if (!chart_no_boss(chart)) for (var _bn = sched_i; _bn < array_length(sched); _bn++) {
    // Where the bar will have shrunk to when it arrives (moves right as bonuses add time)
    var _left = day_timer - (sched[_bn][0] * _fps - day_elapsed);
    if (_left <= 0) continue;
    var _mx = _tx + _tw * _left / day_frames;
    if (sched[_bn][1] == EVT.SWARM) {
        draw_set_colour(c_red);
        draw_triangle(_mx - 6, 15, _mx + 6, 15, _mx, 26, false);
    } else {
        draw_set_colour(HUD_TIER);
        draw_triangle(_mx - 5, 21, _mx, 15, _mx + 5, 21, false);
        draw_triangle(_mx - 5, 21, _mx, 27, _mx + 5, 21, false);
    }
    draw_reset();
}

// Boss health bar (centre, under the timer) while a boss is out
var _boss = noone;
with (obj_asteroid) if (is_boss && !dead) _boss = id;
with (obj_flagship) if (!dead) _boss = id; // Pirate System flagship (scr_pirates)
if (_boss != noone) hud_boss_t++; else hud_boss_t = 0;
if (_boss != noone) {
    var _bw = 360, _bx = _gw / 2 - _bw / 2;
    var _pulse = merge_colour(HUD_TIER, c_white, 0.25 + 0.25 * sin(current_time / 150));
    if (panel_unfurl(hud_boss_t / UNFURL_FRAMES, _gw / 2, 42, _bx - 6, 46, _bx + _bw + 6, 66, HUD_TIER)) { // drops out of the timer
        draw_seg_bar(_bx, 50, _bw, 12, _boss.hp / _boss.max_hp, _pulse, 20);
        clip_end();
    }
    // Late-tier boss modifier, named under the bar
    if (_boss.object_index == obj_asteroid && _boss.boss_trait != "") {
        draw_set_halign(fa_center);
        draw_set_colour(_pulse);
        draw_text_transformed(_gw / 2, 76, _boss.boss_trait, 0.6, 0.6, 0);
        draw_reset();
    }
}

// --- Bottom left: missile ammo (scr_pirates): one segment per round, the next one filling as it reloads
if (_st.missiles && state != "over") {
    var _mcol = make_colour_rgb(120, 255, 230);
    var _ready = missile_ammo > 0;
    var _mmax = max(1, _st.missile_ammo);
    var _part = (missile_ammo < _mmax) ? 1 - missile_cd / missile_reload_frames() : 0;
    var _mf = (missile_ammo + _part) / _mmax;
    if (panel_unfurl(_hud_t(9), 24, _gh - 21, 8, _gh - 34, 170, _gh - 8, _ready ? _mcol : HUD_EDGE)) { // grows from its icon
        draw_sprite_ext(spr_bullet, 0, 24, _gh - 21, 2.4, 1.3, 45, _ready ? _mcol : merge_colour(_mcol, c_black, 0.4), 1);
        var _bc = (missile_ammo >= _mmax) ? merge_colour(_mcol, c_white, 0.3 + 0.3 * sin(current_time / 150)) // full: pulses
                : (_ready ? _mcol : merge_colour(_mcol, c_black, 0.4));
        draw_seg_bar(40, _gh - 27, 122, 12, _mf, _bc, _mmax);
        draw_reset();
        clip_end();
    }
}

// --- Bottom left: Combat HUD (node): drawn by draw_combat_hud (obj_game Create). During the
// end-of-day summary it's drawn again over the dim, frozen at the day's final numbers.
if (_st.combat_hud && state != "over") draw_combat_hud(_hud_t(12));

// Charge meter (under the hull panel): fills with charge points, then rattles until Overcharge is fired
hud_charge_flash = max(0, hud_charge_flash - 0.03);
hud_tier_flash  = max(0, hud_tier_flash - 0.02);
hud_charge_jig = max(0, hud_charge_jig - 0.08);
hud_charge_hit = max(0, hud_charge_hit - 0.05);
var _ocy = (_st.max_shield > 0) ? 68 : 48;
hud_oc_tx = 8 + 34 + 182 * clamp(global.charge / charge_needed(), 0.03, 1); // orbs fly into the fill's end
hud_oc_ty = _ocy + 16;
hud_oc_y  = _ocy; // the Overcharge tip lights the bar up here (scr_tutorial)
var _oct = _hud_t(6);
if (_oct > 0) {
    var _ocr = unfurl_rect(24, _ocy + 16, 8, _ocy, 232, _ocy + 32, _oct); // grows from its left end
    clip_begin(_ocr, [8 - 4, _ocy - 3, 232 + 4, _ocy + 35]); // a little slack for its rattle
    draw_oc_bar(8, _ocy, hud_charge_flash, hud_charge_jig, hud_charge_hit);
    clip_end();
}

// --- Bottom right: ship slots (no box) ----------------------------------------
var _slots = _st.ships;
var _ships = [];
with (obj_collector) array_push(_ships, id);
var _slot_w = 26;
var _px2 = _gw - 8;
var _px1 = _px2 - 120; // haul list column (top right)

var _sc = 20 / sprite_get_width(spr_collector);
for (var i = 0; i < _slots; i++) {
    var _sx = _px2 - 16 - i * _slot_w;
    var _sy = _gh - 22;
    if (i < array_length(_ships)) {
        // Out collecting: icon fills with that ship's cargo, yellow when full
        var _c = _ships[i];
        var _full = _c.cargo_total >= _c.capacity;
        draw_sprite_fill(spr_collector, _sx, _sy, _sc, _sc, 0, _full ? c_yellow : c_white, 1, min(1, _c.cargo_total / _c.capacity), 0);
    } else if (i - array_length(_ships) < array_length(ship_rebuild)) {
        // Destroyed, rebuilding: red outline filling up as the rebuild completes
        var _left = ship_rebuild[i - array_length(_ships)];
        var _p = 1 - _left / max(1, _st.ship_rebuild * game_get_speed(gamespeed_fps));
        draw_sprite_fill(spr_collector, _sx, _sy, _sc, _sc, 0, make_colour_rgb(255, 80, 80), 0.8, _p, 0);
    } else {
        // Ready to launch: pulsing outline
        var _pa = 0.6 + 0.4 * sin(current_time / 250 + i);
        draw_sprite_ext(spr_collector, 0, _sx, _sy, _sc, _sc, 0, c_lime, _pa);
    }
}

// Haul list (top right, no box): counts up as the flying icons land, popping each time
var _ly = 24;
hud_row_x = _px1 + 16;
for (var r = 0; r < RES.COUNT; r++) {
    if (state == "over") hud_shown[r] = day_haul[r];
    if (hud_shown[r] > hud_prev[r]) hud_pop[r] = 1;
    hud_prev[r] = hud_shown[r];
    hud_pop[r] = max(0, hud_pop[r] - 0.05);
    if (r != RES.ORE && day_haul[r] <= 0) continue;
    hud_row_y[r] = _ly;
    draw_res_amount(_px1 + 10, _ly, r, string(hud_shown[r]), 1.5 + hud_pop[r] * 0.6);
    _ly += 22;
}

// Flying loot icons: arc from the station to their haul row, then land with a rising tick
if (hud_chain_t > 0) hud_chain_t--; else hud_chain = 0;
for (var i = array_length(hud_fly) - 1; i >= 0; i--) {
    var _f = hud_fly[i];
    _f.t += 1 / 28;
    if (_f.t < 0) continue; // staggered start
    var _e  = ease_out_cubic(_f.t);
    var _tx2 = hud_row_x, _ty2 = hud_row_y[_f.r];
    var _fx = lerp(_f.x0, _tx2, _e) + sin(_f.t * pi) * _f.arc;
    var _fy = lerp(_f.y0, _ty2, _e) - sin(_f.t * pi) * 40;
    if (_f.t >= 1) {
        hud_shown[_f.r] = min(day_haul[_f.r], hud_shown[_f.r] + _f.amt);
        hud_chain++;
        hud_chain_t = 45;
        sfx(snd_pickup, 0.35, min(2.2, 0.9 + hud_chain * 0.05), 0);
        array_delete(hud_fly, i, 1);
        continue;
    }
    var _s = 1.6 + sin(_f.t * pi) * 0.8;
    draw_sprite_ext(res_sprite(_f.r), 0, _fx, _fy, _s, _s, _f.t * 360, c_white, 1);
}

// Bonus charge orbs: burst out of the kill, then home in on the charge meter and pay out there
for (var i = array_length(hud_orbs) - 1; i >= 0; i--) {
    if (i >= array_length(hud_orbs)) continue; // the meter filled and cleared the rest
    var _o = hud_orbs[i];
    _o.life++;
    if (_o.life <= 0) continue; // staggered start
    _o.px = _o.x; _o.py = _o.y;
    var _dx = hud_oc_tx - _o.x, _dy = hud_oc_ty - _o.y;
    var _dd = max(1, point_distance(0, 0, _dx, _dy));
    var _sp = 3 + _o.life * 0.7;                 // speeds up the longer it flies
    var _pull = min(0.35, _o.life / 40);         // burst outwards first, then steer in hard
    _o.vx = lerp(_o.vx * 0.92, _dx / _dd * _sp, _pull);
    _o.vy = lerp(_o.vy * 0.92, _dy / _dd * _sp, _pull);
    _o.x += _o.vx; _o.y += _o.vy;
    if (_dd <= max(10, _sp) || _o.life > 150) {
        array_delete(hud_orbs, i, 1); // out first: filling the meter clears hud_orbs
        add_charge(_o.amt, true);
        hud_charge_hit = 1;
        hud_orb_chain++;
        sfx(snd_pickup, 0.25, min(2.4, 1.3 + hud_orb_chain * 0.04), 0);
        repeat (irandom_range(3, 5)) {
            var _sd = random_range(0, 360), _ss = random_range(1.5, 4);
            array_push(hud_sparks, { x: hud_oc_tx, y: hud_oc_ty, vx: lengthdir_x(_ss, _sd), vy: lengthdir_y(_ss, _sd) - 1, life: irandom_range(14, 24) });
        }
        continue;
    }
    // Short streak behind a bright dot
    draw_set_colour(CHARGE_ORB_COLOUR);
    draw_set_alpha(0.5);
    draw_line_width(_o.px - _o.vx, _o.py - _o.vy, _o.x, _o.y, 3);
    draw_set_alpha(1);
    draw_circle(_o.x, _o.y, 3, false);
    draw_set_colour(c_white);
    draw_circle(_o.x, _o.y, 1, false);
    draw_reset();
}
if (array_length(hud_orbs) == 0 && hud_charge_hit <= 0) hud_orb_chain = 0;
for (var i = array_length(hud_sparks) - 1; i >= 0; i--) {
    var _p = hud_sparks[i];
    _p.life--;
    if (_p.life <= 0) { array_delete(hud_sparks, i, 1); continue; }
    _p.x += _p.vx; _p.y += _p.vy;
    _p.vx *= 0.9; _p.vy = _p.vy * 0.9 + 0.15;
    draw_set_colour(merge_colour(CHARGE_ORB_COLOUR, c_white, min(1, _p.life / 20)));
    draw_set_alpha(min(1, _p.life / 10));
    draw_line_width(_p.x, _p.y, _p.x - _p.vx * 2, _p.y - _p.vy * 2, 2);
    draw_reset();
}

// Overcharge running: yellow lightning crackling round the HUD panels, and a cyan glow round the screen edge
if (is_array(global.hud_rec)) draw_hud_crackle(global.hud_rec);
global.hud_rec = undefined;
if (oc_timer > 0) {
    draw_set_colour(OC_COLOUR);
    draw_set_alpha(0.12 + 0.06 * sin(current_time / 90));
    draw_frame(0, 0, _gw, _gh, 10);
    draw_reset();
}

// Last 5 seconds: red edge pulse and a big fading number on each second
countdown_pop = max(0, countdown_pop - 0.025);
if (state == "playing" && countdown_pop > 0) {
    draw_set_colour(HUD_HULL);
    draw_set_alpha(0.45 * countdown_pop);
    draw_frame(0, 0, _gw, _gh, 6 + 14 * countdown_pop);
    draw_set_alpha(0.7 * countdown_pop);
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    var _cs = 5 + 3 * countdown_pop;
    draw_text_transformed(_gw / 2, _gh / 2 - 130, string(countdown_num), _cs, _cs, 0);
    draw_reset();
}

// --- End of day overlay ------------------------------------------------------
// The singularity ending: fade to black, then the message (the summary later draws over the black)
if (singularity) {
    var _et = ending_t / _fps;
    var _blk = (state == "over") ? 1 : clamp((_et - ENDING_FADE_AT) / ENDING_FADE, 0, 1);
    draw_set_alpha(_blk);
    draw_set_colour(c_black);
    draw_rectangle(0, 0, _gw, _gh, false);
    draw_reset();
    if (state == "ending" && _et >= ENDING_TEXT_AT) {
        var _ta = clamp((_et - ENDING_TEXT_AT) / 1.5, 0, 1);
        var _msg = ending_first
            ? "Congratulations, in your greed you've amassed enough wealth that it has collapsed in on itself and formed a new singularity.\n\nYou are the black hole from which loot cannot escape."
            : "SINGULARITY";
        var _ww = min(_gw * 0.7, 900);
        draw_set_alpha(_ta);
        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        draw_set_colour(c_white);
        draw_text_ext(_gw / 2, _gh / 2 - 30, _msg, string_height("A") + 10, _ww);
        draw_set_colour(HUD_TIME);
        draw_text_transformed(_gw / 2, _gh / 2 + string_height_ext(_msg, string_height("A") + 10, _ww) / 2 + 10,
                              "+" + string(ending_loot) + " swallowed", 0.8, 0.8, 0);
        if (ending_first && !global.settings.ngplus) { // first ever: New Game+ unlocks when the day ends
            draw_set_colour(make_colour_rgb(255, 230, 140));
            draw_text_transformed(_gw / 2, _gh - 110, "NEW GAME+ UNLOCKED", 0.8, 0.8, 0);
        }
        if (_et >= ENDING_CLICK_AT) {
            draw_set_alpha(0.5 + 0.5 * sin(current_time / 300));
            draw_set_colour(c_gray);
            draw_text_transformed(_gw / 2, _gh - 60, "CLICK TO CONTINUE", 0.7, 0.7, 0);
        }
        draw_reset();
    }
}

if (state == "over") {
    // Dim fades in; the summary panel unfurls out of the station at the centre
    var _cy0 = _gh / 2;
    draw_set_alpha(0.7 * (reward_done ? 1 : min(1, over_timer / 15))); // stays dark from the reward choice into the summary
    draw_set_colour(c_black);
    draw_rectangle(0, 0, _gw, _gh, false);
    draw_reset();
    var _ecol = (end_reason == "Station destroyed") ? HUD_HULL : HUD_TIME;
    // Summary, top to bottom (small = resource rows, medium = totals and combat):
    //   end reason / RESOURCES GAINED / fee (if any) / TAKEN BY RAIDERS (if any)
    //   TOTAL / PIRATES SHOT DOWN / COLLECTORS LOST / continue arrow
    var _fee_on = (fee_total > 0);
    var _stl_on = false;
    for (var r = 0; r < RES.COUNT; r++) if (day_stolen[r] > 0) _stl_on = true;
    var _net = array_create(RES.COUNT, 0);
    for (var r = 0; r < RES.COUNT; r++) _net[r] = max(0, day_haul[r] - rebuild_fee[r]);
    var _small = 1.0, _med = 1.4;       // resource row icon scales
    // Heights grow with each row's wrapping (many resource types wrap onto extra lines)
    var _lh_s = 20, _lh_m = 28;          // row line heights at those scales (30 x scale / 1.5)
    var _sec_h = function(_arr, _pre, _lh, _sc) { return 20 + max(1, resource_row_lines(_arr, _pre, 360, _sc)) * _lh; };
    var _hs = [_sec_h(day_haul, "+", _lh_s, _small), _fee_on ? _sec_h(rebuild_fee, "-", _lh_s, _small) : 0,
               _stl_on ? _sec_h(day_stolen, "-", _lh_s, _small) : 0];
    var _tot_h = 26 + max(1, resource_row_lines(_net, "+", 360, _med)) * _lh_m;
    var _h = 50 + _hs[0] + _hs[1] + _hs[2] + _tot_h + 50 + 34;
    var _py1 = _cy0 - _h / 2, _py2 = _cy0 + _h / 2;
    var _hcol = make_colour_rgb(150, 170, 200);
    // Flagship beaten: only the reward choice shows; the summary (with the reward in it) follows
    if (!reward_pending) {
    if (panel_unfurl(over_timer / 20, _gw / 2, _cy0, _gw / 2 - 200, _py1, _gw / 2 + 200, _py2, _ecol)) {
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    var _y = _py1 + 20;
    draw_set_colour(_ecol);
    var _es = min(1.3, 360 / max(1, string_width(end_reason)));
    draw_text_transformed(_gw / 2, _y, end_reason, _es, _es, 0);
    draw_reset();
    _y += 30;
    // Small sections: heading, then its resources
    var _secs = [["RESOURCES GAINED", day_haul, "+", _hcol, true],
                 [fee_label, rebuild_fee, "-", HUD_HULL, _fee_on],
                 ["TAKEN BY RAIDERS", day_stolen, "-", make_colour_rgb(255, 80, 80), _stl_on]];
    for (var i = 0; i < array_length(_secs); i++) {
        var _s = _secs[i];
        if (!_s[4]) continue;
        if (over_timer > 18 + i * 4) {
            draw_set_halign(fa_center); draw_set_valign(fa_middle); draw_set_colour(_s[3]);
            draw_text_transformed(_gw / 2, _y, _s[0], 0.5, 0.5, 0);
            draw_reset();
            draw_resource_row(_gw / 2, _y + 18, _s[1], _s[2], 360, false, _small);
        }
        _y += _hs[i];
    }
    // Total kept: medium
    if (over_timer > 30) {
        draw_set_halign(fa_center); draw_set_valign(fa_middle); draw_set_colour(c_white);
        draw_text_transformed(_gw / 2, _y + 2, "TOTAL", 0.65, 0.65, 0);
        draw_reset();
        draw_resource_row(_gw / 2, _y + 24, _net, "+", 360, false, _med);
    }
    _y += _tot_h;
    // Combat and ships: medium
    if (over_timer > 36) {
        var _lines = [["PIRATES SHOT DOWN", day_downed, make_colour_rgb(255, 215, 0)],
                      ["COLLECTORS LOST",   dlog.ships_lost, (dlog.ships_lost > 0) ? HUD_HULL : c_white]];
        for (var i = 0; i < 2; i++) {
            var _ly = _y + 8 + i * 22;
            draw_set_valign(fa_middle);
            draw_set_halign(fa_right); draw_set_colour(_hcol);
            draw_text_transformed(_gw / 2 + 50, _ly, _lines[i][0], 0.65, 0.65, 0);
            draw_set_halign(fa_left);  draw_set_colour(_lines[i][2]);
            draw_text_transformed(_gw / 2 + 64, _ly, string(_lines[i][1]), 0.8, 0.8, 0);
            draw_reset();
        }
    }
    _y += 50;
    var _arrow = over_timer > 45 && !reward_pending;
    if (_arrow) {
        // Pulsing "continue" arrow
        draw_set_alpha(0.5 + 0.5 * sin(current_time / 200));
        var _cx = _gw / 2, _cy = _y + 10;
        draw_triangle(_cx - 8, _cy - 11, _cx - 8, _cy + 11, _cx + 11, _cy, false);
        draw_reset();
    }
    clip_end();
    }
    }
    // Flagship beaten: reward cards unfurl in the middle of the screen (scr_pirates)
    if (reward_pending && over_timer > 10) pirate_reward_draw(device_mouse_x_to_gui(0), device_mouse_y_to_gui(0));
    if (_st.combat_hud) draw_combat_hud(1); // stays up with the day's final numbers (no longer updating)
}

// Day-one tutorial: step prompt, summary cards, skip chip (scr_tutorial)
tut_day_draw_gui();

// F2 (debug): live performance numbers, top left under the HUD
if (perf_overlay && variable_global_exists("perf")) {
    var _p = global.perf, _lv = _p.live;
    var _txt = "FPS " + string(fps) + "  REAL " + string(round(fps_real)) + "  FRAME " + string(round(delta_time / 100) / 10) + "ms";
    _txt += "\nALL " + string(_lv[$ "all"] ?? 0) + "  PARTICLES " + string(_lv[$ "particles"] ?? 0);
    _txt += "\nROCKS " + string(_lv[$ "asteroids"] ?? 0) + "  LOOT " + string(_lv[$ "pickups"] ?? 0) + "  BULLETS " + string(_lv[$ "bullets"] ?? 0);
    var _f = max(1, _p.frames), _keys = variable_struct_get_names(_p.us);
    for (var i = 0; i < array_length(_keys); i++) _txt += "\n" + string_upper(_keys[i]) + " " + string(round(100 * _p.us[$ _keys[i]] / _f / 1000) / 100) + "ms";
    _txt += "\nOUTLINE CACHE " + (global.outline_cache_off ? "OFF" : "ON") + " [F1]  BUILDS " + string(_p.n[$ "outline_builds"] ?? 0);
    draw_set_colour(c_black); draw_set_alpha(0.6);
    draw_rectangle(10, 150, 10 + string_width(_txt) * 0.6 + 16, 150 + string_height(_txt) * 0.6 + 12, false);
    draw_reset();
    draw_text_transformed(18, 156, _txt, 0.6, 0.6, 0);
}

// One-off tip over everything: dims the screen, lights up its HUD part (scr_tutorial)
tip_draw_gui();
