// ---------------------------------------------------------------------------
// Tutorial: a new game's first day, then the tree screen after it.
// global.tutorial (saved): 0 = day one still to teach, 1 = tree still to teach, 2 = done.
// ESC skips whichever part is showing (skipping the day skips the tree part too).
//
// Day one (obj_game: tut, tut_t...): the clock, spawns, threat and zoom are held while
// one rock sits beside the station. Steps wait for the player:
//   AIM     cursor onto the rock (or the gun hits it)
//   SHOOT   the rock's pips drain until it breaks (it drops TUT_LOOT and doesn't split)
//   LOOT    a short beat with markers on the stacks
//   COLLECT left click launches a ship; moves on when it docks
//   BANKED  a short beat on the banked number
//   SUMMARY shoot / collect / survive cards; a click starts the real day (TUT_DAY_MULT long)
// Tree (obj_tree: ttut...): BANK (your ore) -> DAMAGE (buy it) -> LURE (warning) -> LAUNCH.
// Day one uses single verbs and icons (UI rule in scr_ui); the tree steps use short sentences. World markers are
// sprites (spr_tut_*), drawn with the scr_fx helpers.
// ---------------------------------------------------------------------------

enum TUT   { AIM, SHOOT, LOOT, COLLECT, BANKED, SUMMARY, OFF }
enum TTREE { BANK, DAMAGE, LURE, LAUNCH, OFF }

#macro TUT_ROCK_DIST   330    // the tutorial rock sits this far from the station...
#macro TUT_ROCK_DIR    35     // ...in this direction (degrees)
#macro TUT_LOOT        8      // ore it drops (enough for the first Damage level)
#macro TUT_LOOT_PIECES 4      // in this many stacks
#macro TUT_LOOT_SECS   1.6    // LOOT beat before the launch prompt
#macro TUT_BANKED_SECS 1.2    // BANKED beat before the summary
#macro TUT_ICON        28     // icon size in prompt panels (GUI px)
#macro TUT_PANEL_ALPHA 0.9    // background opacity of tutorial / tip panels (HUD panels are 0.55)
#macro TUT_DAY_MULT    0.5    // day one (with the tutorial) runs this share of the usual day length
#macro TUT_HOVER_SECS  1      // tree: hover the ore row this long to move on
#macro TUT_COL   make_colour_rgb(120, 255, 140) // prompts and markers
#macro TUT_WARN  make_colour_rgb(255, 90, 70)   // the Asteroid Lure warning

// --- Shared drawing --------------------------------------------------------

/// A sprite fitted into a _size px square and centred on (_x, _y), whatever its origin.
function tut_icon(_spr, _sub, _x, _y, _size, _col) {
    var _sw = sprite_get_width(_spr), _sh = sprite_get_height(_spr);
    var _k = _size / max(_sw, _sh);
    var _ox = (sprite_get_xoffset(_spr) - _sw / 2) * _k, _oy = (sprite_get_yoffset(_spr) - _sh / 2) * _k;
    draw_sprite_ext(_spr, _sub, _x + _ox, _y + _oy, _k, _k, 0, _col, draw_get_alpha());
}

/// Prompt panel centred on (_cx, _cy): icons, then an optional word, then an optional
/// pulsing "continue" triangle. _icons: [[sprite, subimage, colour], ...]; an entry whose
/// first item is a string is drawn as text ("+", "+8") in its colour.
function tut_panel(_cx, _cy, _icons, _word, _col, _open, _cont = false, _ts = 0.9) {
    var _ww = (_word == "") ? 0 : string_width(_word) * _ts;
    var _w = 16; // left margin
    for (var i = 0; i < array_length(_icons); i++) {
        var _ic = _icons[i];
        _w += (is_string(_ic[0]) ? string_width(_ic[0]) * _ts : TUT_ICON) + 8;
    }
    _w += _ww + (_cont ? 28 : 0) + ((_ww > 0) ? 16 : 8);
    var _h = TUT_ICON + 20;
    var _x1 = _cx - _w / 2, _y1 = _cy - _h / 2;
    if (!panel_unfurl(_open, _cx, _cy, _x1, _y1, _x1 + _w, _y1 + _h, _col, TUT_PANEL_ALPHA)) return;
    var _x = _x1 + 16;
    draw_set_valign(fa_middle);
    draw_set_halign(fa_left);
    for (var i = 0; i < array_length(_icons); i++) {
        var _ic = _icons[i];
        if (is_string(_ic[0])) {
            draw_set_colour(_ic[2]);
            draw_text_transformed(_x, _cy, _ic[0], _ts, _ts, 0);
            _x += string_width(_ic[0]) * _ts + 8;
        } else {
            var _isz = TUT_ICON * ((array_length(_ic) > 3) ? _ic[3] : 1); // optional 4th item: size multiplier
            tut_icon(_ic[0], _ic[1], _x + TUT_ICON / 2, _cy, _isz, _ic[2]);
            _x += TUT_ICON + 8;
        }
    }
    if (_ww > 0) {
        draw_set_colour(_col);
        draw_text_transformed(_x, _cy, _word, _ts, _ts, 0);
        _x += _ww + 8;
    }
    if (_cont) {
        draw_set_colour(c_white);
        draw_set_alpha(0.5 + 0.5 * sin(current_time / 200));
        draw_triangle(_x + 2, _cy - 9, _x + 2, _cy + 9, _x + 18, _cy, false);
    }
    draw_reset();
    clip_end();
}

/// Small "ESC >>" chip: the skip key. (_x, _y) = its top-left corner.
function tut_skip_chip(_x, _y) {
    var _ts = 0.6, _tw = string_width("ESC") * _ts;
    var _w = _tw + 44, _h = 26;
    draw_panel(_x, _y, _x + _w, _y + _h, c_gray, TUT_PANEL_ALPHA);
    draw_set_valign(fa_middle);
    draw_set_colour(c_ltgray);
    draw_text_transformed(_x + 8, _y + _h / 2, "ESC", _ts, _ts, 0);
    var _ax = _x + _tw + 16, _cy = _y + _h / 2;
    draw_triangle(_ax, _cy - 6, _ax, _cy + 6, _ax + 9, _cy, false);
    draw_triangle(_ax + 9, _cy - 6, _ax + 9, _cy + 6, _ax + 18, _cy, false);
    draw_reset();
}

/// Arrow sprite pointing at (_x, _y) from direction _from, bobbing in and out (GUI or world).
function tut_arrow_at(_x, _y, _from, _gap, _size, _col) {
    var _d = _gap + 8 * (0.5 + 0.5 * sin(current_time / 140));
    var _k = _size / sprite_get_width(spr_tut_arrow);
    draw_sprite_ext(spr_tut_arrow, 0, _x + lengthdir_x(_d, _from), _y + lengthdir_y(_d, _from), _k, _k, _from + 180, _col, 1);
}

// --- Day one (runs in obj_game's scope unless noted) -----------------------

/// obj_game Create (at the end): starts the tutorial on a new game's first day.
function tut_day_init() {
    tut = (global.tutorial == 0 && global.day_count == 0 && chart == CHART.NONE) ? TUT.AIM : TUT.OFF;
    tut_t = 0;          // frames in the current step
    tut_open = 0;       // prompt panel unfurl (0-1), replays each step
    tut_launched = false;
    tut_rock = noone;
    if (tut == TUT.OFF) return;
    // A shorter first day: the clock starts after the tutorial, at TUT_DAY_MULT of the usual length
    day_frames = round(day_frames * TUT_DAY_MULT);
    day_timer  = day_frames;
    var _x = STATION_X + lengthdir_x(TUT_ROCK_DIST, TUT_ROCK_DIR);
    var _y = STATION_Y + lengthdir_y(TUT_ROCK_DIST, TUT_ROCK_DIR);
    tut_rock = instance_create_layer(_x, _y, "Instances", obj_asteroid);
    tut_rock.init(AST.MEDIUM, RES.ORE);
    tut_rock.tut = true;      // no fragments, fixed loot (obj_asteroid break_apart)
    tut_rock.entered = true;  // it's on screen already
}

/// Anywhere: is the day-one tutorial running?
function tut_day_on() { return instance_exists(obj_game) && obj_game.tut != TUT.OFF; }

/// Left click may launch a ship (only once the tutorial asks for it).
function tut_launch_ok() { return !tut_day_on() || obj_game.tut == TUT.COLLECT; }

function tut_next(_step) {
    tut = _step;
    tut_t = 0;
    tut_open = 0;
    sfx(snd_ui_hover, 0.5, 1.2, 0);
}

/// obj_game Step, each frame while playing (after the launch click, so the summary's
/// closing click doesn't also launch a ship).
function tut_day_step(_input) {
    if (tut == TUT.OFF) return;
    tut_t++;
    tut_open = min(1, tut_open + 1 / UNFURL_FRAMES);
    var _fps = game_get_speed(gamespeed_fps);
    switch (tut) {
        case TUT.AIM:
            if (!instance_exists(tut_rock)) { tut_next(TUT.LOOT); break; }
            if (tut_rock.hp < tut_rock.max_hp
                || point_distance(mouse_x, mouse_y, tut_rock.x, tut_rock.y) < tut_rock.radius * 1.3) tut_next(TUT.SHOOT);
            break;
        case TUT.SHOOT:
            if (!instance_exists(tut_rock) || tut_rock.dead) tut_next(TUT.LOOT);
            break;
        case TUT.LOOT:
            if (tut_t >= TUT_LOOT_SECS * _fps) tut_next(TUT.COLLECT);
            break;
        case TUT.COLLECT:
            if (instance_exists(obj_collector)) tut_launched = true;
            // Docked with nothing (the loot went elsewhere): move on rather than get stuck
            if (tut_launched && !instance_exists(obj_collector) && !instance_exists(obj_pickup)) tut_next(TUT.SUMMARY);
            break;
        case TUT.BANKED:
            if (tut_t >= TUT_BANKED_SECS * _fps) tut_next(TUT.SUMMARY);
            break;
        case TUT.SUMMARY:
            if (_input && tut_t > 30 && (mouse_check_button_pressed(mb_left) || keyboard_check_pressed(vk_space) || keyboard_check_pressed(vk_enter))) tut_day_end(false);
            break;
    }
}

/// obj_game add_banked: a ship docked with cargo.
function tut_day_banked() {
    if (tut == TUT.COLLECT) tut_next(TUT.BANKED);
}

/// The real day starts. _skipped (ESC): the tree part is skipped too.
function tut_day_end(_skipped) {
    tut = TUT.OFF;
    global.tutorial = _skipped ? 2 : 1; // saved at the end of the day
    if (instance_exists(tut_rock)) tut_rock.tut = false; // just a rock from now on
    tut_rock = noone;
    spawn_timer = 30;
    sfx(snd_affirmative, 0.6, 1, 0);
}

/// obj_game Draw: markers on the rock and the loot (world space, sprites).
function tut_day_draw_world() {
    if (tut == TUT.OFF) return;
    var _p = 0.5 + 0.5 * sin(current_time / 160);
    if ((tut == TUT.AIM || tut == TUT.SHOOT) && instance_exists(tut_rock)) {
        var _r = tut_rock, _rx = _r.x, _ry = _r.y;
        if (tut == TUT.AIM) {
            var _sz = (_r.radius * 2 + 40) * (1 + 0.12 * _p);
            draw_sprite_sized(spr_tut_marker, 0, _rx, _ry, _sz, _sz, current_time / 30, TUT_COL, 0.9);
            tut_arrow_at(_rx, _ry, point_direction(_rx, _ry, STATION_X, STATION_Y), _r.radius + 36, 40, TUT_COL);
        } else {
            var _sz = _r.radius * 2 + 24; // brackets lock on once it's hit
            draw_sprite_sized(spr_tut_marker, 0, _rx, _ry, _sz, _sz, 0, TUT_COL, 0.9);
            // Health pips over the rock
            var _n = 10, _pw = 10, _gap = 4;
            var _lit = ceil(clamp(_r.hp / _r.max_hp, 0, 1) * _n);
            var _x0 = _rx - (_n * (_pw + _gap) - _gap) / 2 + _pw / 2, _py = _ry - _r.radius - 30;
            for (var i = 0; i < _n; i++) {
                draw_sprite_sized(spr_tut_pip, 0, _x0 + i * (_pw + _gap), _py, _pw, _pw * 1.4, 0,
                                  (i < _lit) ? HUD_HULL : c_dkgray, 1);
            }
        }
    }
    if (tut == TUT.LOOT || tut == TUT.COLLECT) {
        with (obj_pickup) {
            if (carried || magnet) continue;
            var _s = 26 * stack_scale + 10 * _p;
            draw_sprite_sized(spr_tut_marker, 0, x, y, _s, _s, 0, TUT_COL, 0.8);
        }
    }
}

/// obj_game Draw GUI: the prompt for the step, the summary cards and the skip chip.
function tut_day_draw_gui() {
    if (tut == TUT.OFF || state != "playing") return;
    var _gw = display_get_gui_width(), _gh = display_get_gui_height();
    var _cx = _gw / 2, _cy = _gh - 48;
    var _gun = wpn_icon(wpn_active());
    switch (tut) {
        case TUT.AIM:
            tut_panel(_cx, _cy, [[spr_tut_mouse, 0, c_white], [spr_tut_arrow, 0, TUT_COL], [spr_tut_marker, 0, TUT_COL]], "AIM", TUT_COL, tut_open);
            break;
        case TUT.SHOOT:
            tut_panel(_cx, _cy, [[_gun, 0, c_white], [spr_tut_arrow, 0, TUT_COL], [spr_asteroid, 0, HUD_HULL]], "SHOOT", TUT_COL, tut_open);
            break;
        case TUT.LOOT:
            tut_panel(_cx, _cy, [[spr_asteroid, 0, res_colour(RES.ORE)], [spr_tut_arrow, 0, TUT_COL], [spr_res_ore, 0, c_white]], "LOOT", TUT_COL, tut_open);
            break;
        case TUT.COLLECT:
            tut_panel(_cx, _cy, [[spr_tut_mouse, 1, c_white], [spr_tut_arrow, 0, TUT_COL], [spr_collector, 0, c_lime, 0.7], [spr_res_ore, 0, c_white, 1.3]], "COLLECT", TUT_COL, tut_open);
            break;
        case TUT.BANKED:
            tut_panel(_cx, _cy, [[spr_res_ore, 0, c_white], ["+" + string(day_haul[RES.ORE]), 0, res_colour(RES.ORE)]], "", TUT_COL, tut_open);
            break;
        case TUT.SUMMARY:
            tut_summary_draw(_gw, _gh);
            break;
    }
    tut_skip_chip(_gw - 92, _gh - 38);
}

/// The three rules of the job, one card each, then a pulsing "continue" triangle.
function tut_summary_draw(_gw, _gh) {
    // Each card: word, edge colour, then its picture
    var _cards = [["SHOOT", HUD_EDGE], ["COLLECT", c_lime], ["SURVIVE", HUD_TIME]];
    var _w = 120, _h = 110, _gap = 16;
    var _x0 = _gw / 2 - (3 * _w + 2 * _gap) / 2, _y1 = _gh * 0.22;
    for (var i = 0; i < 3; i++) {
        var _c = _cards[i];
        var _x1 = _x0 + i * (_w + _gap), _mx = _x1 + _w / 2, _iy = _y1 + 42;
        if (!panel_unfurl((tut_t - i * 8) / UNFURL_FRAMES, _mx, _y1 + _h / 2, _x1, _y1, _x1 + _w, _y1 + _h, _c[1], TUT_PANEL_ALPHA)) continue;
        switch (i) {
            case 0: // the gun and a red rock
                tut_icon(wpn_icon(wpn_active()), 0, _mx - 22, _iy, 36, c_white);
                tut_icon(spr_asteroid, 0, _mx + 22, _iy, 36, HUD_HULL);
                break;
            case 1: // a small ship and a big ore
                tut_icon(spr_collector, 0, _mx - 22, _iy, 26, c_lime);
                tut_icon(spr_res_ore, 0, _mx + 18, _iy, 40, c_white);
                break;
            case 2: // last until the clock runs out
                draw_icon_clock(_mx, _iy, 22, HUD_TIME);
                break;
        }
        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        draw_set_colour(_c[1]);
        draw_text_transformed(_mx, _y1 + _h - 20, _c[0], 0.8, 0.8, 0);
        draw_reset();
        clip_end();
    }
    if (tut_t > 30) {
        var _cx = _gw / 2, _cy = _y1 + _h + 30;
        draw_set_alpha(0.5 + 0.5 * sin(current_time / 200));
        draw_triangle(_cx - 10, _cy - 14, _cx - 10, _cy + 14, _cx + 14, _cy, false);
        draw_reset();
    }
}

// --- Tree (runs in obj_tree's scope) ----------------------------------------

/// obj_tree Create: the tree part, once day one has been taught.
function tut_tree_init() {
    ttut = (global.tutorial == 1) ? TTREE.BANK : TTREE.OFF;
    ttut_t = 0;
    ttut_open = 0;
    ttut_hover = 0; // frames the ore row has been hovered (BANK step)
}

function tut_tree_next(_step) {
    ttut = _step;
    ttut_t = 0;
    ttut_open = 0;
    sfx(snd_ui_hover, 0.5, 1.2, 0);
}

/// Done or skipped: never shown again on this save.
function tut_tree_end() {
    if (ttut == TTREE.OFF) return;
    ttut = TTREE.OFF;
    global.tutorial = 2;
    save_game();
}


/// The ore row of the bank list as drawn: [x1, y1, x2, y2], or undefined.
function tut_ore_row() {
    for (var i = 0; i < array_length(bank_rows); i++) {
        var _br = bank_rows[i];
        if (_br[0] == RES.ORE) return [12, _br[1] - 16, _br[2] + 10, _br[1] + 16];
    }
    return undefined;
}

/// obj_tree Step, each frame (after hover, before clicks).
function tut_tree_step() {
    if (ttut == TTREE.OFF) return;
    ttut_t++;
    ttut_open = min(1, ttut_open + 1 / UNFURL_FRAMES);
    switch (ttut) {
        case TTREE.BANK: {
            // Hovering the ore row (its tooltip shows) for TUT_HOVER_SECS moves on
            var _r = tut_ore_row();
            var _on = (_r != undefined) && point_in_rectangle(device_mouse_x_to_gui(0), device_mouse_y_to_gui(0), _r[0], _r[1], _r[2], _r[3]);
            ttut_hover = _on ? ttut_hover + 1 : max(0, ttut_hover - 2);
            if (ttut_hover >= TUT_HOVER_SECS * game_get_speed(gamespeed_fps)) tut_tree_next(TTREE.DAMAGE);
            break;
        }
        case TTREE.DAMAGE: {
            var _d = upg_get("dmg");
            // Bought it, or can't (abandoned day one with no ore): on to the warning
            if (_d == undefined || upg_level("dmg") > 0 || !upg_can_buy(_d)) tut_tree_next(TTREE.LURE);
            break;
        }
    }
}

/// obj_tree left click: true if the tutorial took the click (nothing else happens).
function tut_tree_click() {
    switch (ttut) {
        case TTREE.BANK:   return true; // the bank isn't clickable: hovering moves on
        case TTREE.DAMAGE: return (hover == undefined || hover.id != "dmg"); // only the Damage node buys
        case TTREE.LURE:   if (ttut_t > 10) tut_tree_next(TTREE.LAUNCH); return true; // anywhere dismisses it
    }
    return false; // LAUNCH / OFF: the tree works as normal
}

/// obj_tree SPACE / ENTER: true if the tutorial took the key (no launch).
function tut_tree_key() {
    switch (ttut) {
        case TTREE.BANK:   return true;
        case TTREE.DAMAGE: return true;
        case TTREE.LURE:   if (ttut_t > 10) tut_tree_next(TTREE.LAUNCH); return true;
    }
    return false;
}

/// A pulsing ring round a tree node, in GUI space. Returns the node's position (or undefined).
function tut_node_ring(_id, _col) {
    var _u = upg_get(_id);
    if (_u == undefined) return undefined;
    var _p = node_pos(_u);
    draw_set_colour(_col);
    draw_set_alpha(0.6 + 0.4 * sin(current_time / 160));
    draw_ring(_p[0], _p[1], (26 + 4 * sin(current_time / 160)) * zoom, max(UI_LINE, 4 * zoom));
    draw_reset();
    return _p;
}

/// obj_tree Draw GUI (before the tooltips).
function tut_tree_draw() {
    if (ttut == TTREE.OFF) return;
    var _gw = display_get_gui_width(), _gh = display_get_gui_height();
    var _cx = _gw / 2, _cy = _gh - btn_h - 64; // just above the launch button
    switch (ttut) {
        case TTREE.BANK: {
            // Frame round the ore row, arrow pointing in from the right; the frame fills as it's hovered
            var _r = tut_ore_row();
            if (_r != undefined) {
                draw_set_colour(TUT_COL);
                draw_set_alpha(0.6 + 0.4 * sin(current_time / 160));
                draw_frame(_r[0], _r[1], _r[2], _r[3], UI_LINE);
                draw_reset();
                var _f = clamp(ttut_hover / (TUT_HOVER_SECS * game_get_speed(gamespeed_fps)), 0, 1);
                if (_f > 0) {
                    draw_set_colour(TUT_COL);
                    draw_rectangle(_r[0], _r[3] + 3, lerp(_r[0], _r[2], _f), _r[3] + 7, false);
                    draw_reset();
                }
                tut_arrow_at(_r[2], (_r[1] + _r[3]) / 2, 0, 22, 28, TUT_COL);
            }
            break;
        }
        case TTREE.DAMAGE: {
            var _p = tut_node_ring("dmg", TUT_COL);
            if (_p != undefined) tut_arrow_at(_p[0], _p[1], 90, 34 * zoom + 10, 32, TUT_COL);
            tut_panel(_cx, _cy, [], "Click to buy a damage upgrade", TUT_COL, ttut_open, false, 0.7);
            break;
        }
        case TTREE.LURE: {
            // A red circle with an exclamation mark over Asteroid Lure (spr_tut_warning)
            var _u = upg_get("more_ast");
            if (_u != undefined) {
                var _p = node_pos(_u);
                var _k = (34 + 4 * sin(current_time / 120)) / sprite_get_width(spr_tut_warning);
                draw_sprite_ext(spr_tut_warning, 0, _p[0], _p[1] - 30 * zoom - 18, _k, _k, 0, TUT_WARN, 1);
            }
            tut_panel(_cx, _cy, [], "Warning! Ensure you are prepared before luring more asteroids", TUT_WARN, ttut_open, ttut_t > 10, 0.7);
            break;
        }
        case TTREE.LAUNCH: {
            var _bx = _gw / 2 - btn_w / 2, _by = _gh - btn_h - 20;
            draw_set_colour(TUT_COL);
            draw_set_alpha(0.6 + 0.4 * sin(current_time / 160));
            draw_frame(_bx - 6, _by - 6, _bx + btn_w + 6, _by + btn_h + 6, UI_LINE + 1);
            draw_reset();
            tut_arrow_at(_bx + btn_w / 2, _by - 6, 90, 20, 32, TUT_COL);
            var _txt = (upg_level("dmg") > 0) ? "Ready to try out that damage increase? To go again click here"
                                              : "Ready to go again? Click here";
            tut_panel(_cx, _by - 86, [], _txt, TUT_COL, ttut_open, false, 0.7);
            break;
        }
    }
    tut_skip_chip(16, _gh - 38);
}

// --- One-off tips (obj_game's scope) -----------------------------------------
// The first time Overcharge is ready, and the first time bonus, on a save: the game pauses
// (global.frozen) behind a short explanation. Seen flags are saved (global.tip_oc, global.tip_time).
// Overcharge: SPACE fires it and closes the tip; a click / ENTER / ESC just closes it.
// Time bonus: any of those closes it. Never during the day-one tutorial.

enum TIP { NONE, OVERCHARGE, TIME }
#macro TIP_OC_WAIT    30   // frames after "OVERCHARGE READY" before the pause (lets the moment land)
#macro TIP_TIME_WAIT  45   // frames after the time bonus lands
#macro TIP_MIN_FRAMES 20   // input ignored this long after the tip opens (no accidental closes)
#macro TIP_W          430  // panel width (GUI px)
#macro TIP_TEXT       0.62 // text scale

/// obj_game Create.
function tip_init() {
    tip = TIP.NONE;
    tip_t = 0;
    tip_wait = -1;       // frames until tip_next opens
    tip_next = TIP.NONE;
    hud_oc_y = 48;       // where the Overcharge bar is (set by Draw GUI)
}

/// obj_game Step, while playing: opens a tip the first time its moment comes round.
function tip_check() {
    if (tip != TIP.NONE || state != "playing" || tut_day_on()) return;
    if (tip_wait > 0) {
        tip_wait--;
        if (tip_wait == 0) {
            // Already fired it during the wait: they've found it, no need to explain
            if (tip_next == TIP.OVERCHARGE && (!global.oc_ready || oc_active())) global.tip_oc = true;
            else tut_tip_open(tip_next);
        }
        return;
    }
    if (!global.tip_oc && global.oc_ready && !oc_active()) { tip_next = TIP.OVERCHARGE; tip_wait = TIP_OC_WAIT; }
    else if (!global.tip_time && bonus_count > 0)          { tip_next = TIP.TIME;       tip_wait = TIP_TIME_WAIT; }
}

function tut_tip_open(_k) {
    tip = _k;
    tip_t = 0;
    tip_wait = -1;
    if (_k == TIP.OVERCHARGE) global.tip_oc = true; else global.tip_time = true; // saved at the end of the day
    global.frozen = true;
    sfx(snd_ui_click, 0.6, 1, 0);
}

function tut_tip_close() {
    tip = TIP.NONE;
    global.frozen = false;
    sfx(snd_ui_click, 0.5, 1.2, 0);
}

/// obj_game Step, first thing while a tip is up (the caller then ignores input this frame).
function tip_step(_input) {
    tip_t++;
    if (!_input || tip_t < TIP_MIN_FRAMES) return;
    var _space = keyboard_check_pressed(vk_space);
    var _close = mouse_check_button_pressed(mb_left) || keyboard_check_pressed(vk_enter) || keyboard_check_pressed(vk_escape);
    if (tip == TIP.OVERCHARGE && _space) {
        tut_tip_close();
        if (global.oc_ready) overcharge_start();
    } else if (_space || _close) tut_tip_close();
}

/// Wrapped text at (_x, _y), _w wide. Returns the y just below it.
function tip_text(_x, _y, _txt, _w, _col) {
    var _sep = string_height("A") + 2;
    draw_set_colour(_col);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_text_ext_transformed(_x, _y, _txt, _sep, _w / TIP_TEXT, TIP_TEXT, TIP_TEXT, 0);
    var _h = string_height_ext(_txt, _sep, _w / TIP_TEXT) * TIP_TEXT;
    draw_reset();
    return _y + _h;
}

/// obj_game Draw GUI (last): dims the screen, lights up what the tip is about, shows the panel.
function tip_draw_gui() {
    if (tip == TIP.NONE) return;
    var _gw = display_get_gui_width(), _gh = display_get_gui_height();
    var _open = min(1, tip_t / UNFURL_FRAMES);
    draw_set_colour(c_black);
    draw_set_alpha(0.5 * _open);
    draw_rectangle(0, 0, _gw, _gh, false);
    draw_reset();
    var _pulse = 0.5 + 0.5 * sin(current_time / 140);
    var _tw = TIP_W - 32;

    if (tip == TIP.OVERCHARGE) {
        // The bar again, on top of the dimming, ringed and pointed at
        var _y = hud_oc_y;
        draw_oc_bar(8, _y);
        draw_set_colour(OC_COLOUR);
        draw_set_alpha(0.5 + 0.5 * _pulse);
        draw_frame(2, _y - 6, 238, _y + 38, UI_LINE + 1);
        draw_reset();
        tut_arrow_at(238, _y + 16, 0, 14, 32, OC_COLOUR);
        // Panel
        var _x1 = 24, _y1 = _y + 70;
        var _body = "You've collected enough charge from destroying things. Your \"Overcharge\" is ready: press [SPACE] to activate it. While active, you gain the following:";
        var _perks = ["Big damage", "Fast repairs", "Freeze time"];
        var _sep = string_height("A") * TIP_TEXT + 6;
        var _h = 16 + string_height_ext(_body, string_height("A") + 2, _tw / TIP_TEXT) * TIP_TEXT + 10 + 3 * _sep + 70;
        if (!panel_unfurl(_open, 240, _y + 16, _x1, _y1, _x1 + TIP_W, _y1 + _h, OC_COLOUR, TUT_PANEL_ALPHA)) return;
        var _ty = tip_text(_x1 + 16, _y1 + 14, _body, _tw, c_white) + 10;
        for (var i = 0; i < 3; i++) {
            draw_set_colour(OC_COLOUR);
            draw_rectangle(_x1 + 22, _ty + _sep / 2 - 6, _x1 + 30, _ty + _sep / 2 + 2, false); // chunky bullet
            draw_reset();
            tip_text(_x1 + 40, _ty, _perks[i], _tw - 24, OC_COLOUR);
            _ty += _sep;
        }
        // The SPACE key, rattling ominously
        var _kx = _x1 + TIP_W / 2 + irandom_range(-2, 2) * (0.5 + _pulse), _ky = _ty + 32 + irandom_range(-1, 1);
        var _ks = 1 + 0.1 * _pulse, _kw = 130 * _ks, _kh = 36 * _ks;
        draw_panel(_kx - _kw / 2, _ky - _kh / 2, _kx + _kw / 2, _ky + _kh / 2, merge_colour(OC_COLOUR, c_white, _pulse * 0.6), TUT_PANEL_ALPHA);
        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        draw_set_colour(merge_colour(OC_COLOUR, c_white, _pulse * 0.5));
        draw_text_transformed(_kx, _ky, "SPACE", 0.9 * _ks, 0.9 * _ks, 0);
        draw_reset();
        clip_end();
    } else {
        // The time-bonus strip under the timer, framed and pointed at
        var _sw = 300, _sx = _gw / 2 - _sw / 2;
        var _bf = clamp(bonus_value / bonus_quota(), 0, 1);
        draw_set_colour(merge_colour(HUD_TIME, c_black, 0.6));
        draw_rectangle(_sx, 31, _sx + _sw, 35, false);
        draw_set_colour(HUD_TIME);
        if (_bf > 0) draw_rectangle(_sx, 31, _sx + _sw * _bf, 35, false);
        draw_set_alpha(0.5 + 0.5 * _pulse);
        draw_frame(_sx - 6, 25, _sx + _sw + 6, 41, UI_LINE);
        draw_reset();
        tut_arrow_at(_gw / 2, 41, 270, 14, 32, HUD_TIME);
        // Panel
        var _x1 = _gw / 2 - TIP_W / 2, _y1 = 110;
        var _a = "You've collected enough resources to earn some extra time in the day. You can track your next time bonus here.";
        var _b = "If you stay out long enough, who knows what else might turn up...";
        var _sep = string_height("A") + 2;
        var _h = 16 + (string_height_ext(_a, _sep, _tw / TIP_TEXT) + string_height_ext(_b, _sep, _tw / TIP_TEXT)) * TIP_TEXT + 12 + 40;
        if (!panel_unfurl(_open, _gw / 2, 60, _x1, _y1, _x1 + TIP_W, _y1 + _h, HUD_TIME, TUT_PANEL_ALPHA)) return;
        var _ty = tip_text(_x1 + 16, _y1 + 14, _a, _tw, c_white) + 12;
        tip_text(_x1 + 16, _ty, _b, _tw, merge_colour(HUD_TIME, c_gray, 0.4));
        clip_end();
    }
    // Pulsing "continue" triangle, bottom right of the panel area
    if (tip_t >= TIP_MIN_FRAMES) {
        var _cx = (tip == TIP.OVERCHARGE) ? 24 + TIP_W - 24 : _gw / 2 + TIP_W / 2 - 24;
        var _cy = (tip == TIP.OVERCHARGE) ? hud_oc_y + 70 + 18 : 110 + 18;
        draw_set_alpha(0.4 + 0.6 * _pulse);
        draw_triangle(_cx - 6, _cy - 9, _cx - 6, _cy + 9, _cx + 9, _cy, false);
        draw_reset();
    }
}

// --- Tree tip: the first sector condition survived (obj_tree's scope) ----------
// Back on the tree after surviving a condition for the first time (global.surveyed), three
// pages explain star charts. Page 2 puts that condition in star chart slot 1 to show it off;
// page 3 points at the greyed play button and the short "1/3" cost. Closing (or ESC) clears
// the slots back to NONE. Seen flag: global.tip_cond (saved).

#macro CTIP_MIN_FRAMES 15  // input ignored this long after each page opens

/// obj_tree Create (after tut_tree_init).
function ctip_init() {
    ctip = 0;               // page showing: 0 = none, 1-3
    ctip_t = 0;
    ctip_cond = COND.NONE;  // the condition survived
}

function ctip_page(_p) {
    ctip = _p;
    ctip_t = 0;
    if (_p == 2) { global.survey_sel = ctip_cond; global.survey_sel2 = COND.NONE; } // prefill slot 1
    sfx(snd_ui_hover, 0.5, 1.2, 0);
}

function ctip_close() {
    ctip = 0;
    global.survey_sel  = COND.NONE;
    global.survey_sel2 = COND.NONE;
    global.tip_cond = true;
    save_game();
    sfx(snd_ui_click, 0.5, 1.2, 0);
}

/// obj_tree Step, after hover detection. True while the tip is up (the tree takes no input).
function ctip_step() {
    if (ctip == 0) {
        if (global.tip_cond || ttut != TTREE.OFF || transition_active()) return false;
        for (var c = 1; c < COND.COUNT; c++) if (global.surveyed[c]) { ctip_cond = c; break; }
        if (ctip_cond == COND.NONE) return false;
        ctip_page(1);
        sfx(snd_ui_click, 0.6, 1, 0);
        return true;
    }
    ctip_t++;
    if (ctip_t < CTIP_MIN_FRAMES) return true;
    if (keyboard_check_pressed(vk_escape)) { ctip_close(); return true; }
    if (mouse_check_button_pressed(mb_left) || keyboard_check_pressed(vk_space) || keyboard_check_pressed(vk_enter)) {
        if (ctip == 1) ctip_page(2);
        else if (ctip == 2 && slot_short() >= 0) ctip_page(3); // only if they really can't pay yet
        else ctip_close();
    }
    return true;
}

/// Pulsing frame round [x1, y1, x2, y2] (GUI).
function ctip_frame(_r, _col) {
    draw_set_colour(_col);
    draw_set_alpha(0.6 + 0.4 * sin(current_time / 140));
    draw_frame(_r[0], _r[1], _r[2], _r[3], UI_LINE + 1);
    draw_reset();
}

/// obj_tree Draw GUI (last, over everything).
function ctip_draw() {
    if (ctip == 0) return;
    var _gw = display_get_gui_width(), _gh = display_get_gui_height();
    var _col = chart_colour(CHART.SURVEY);
    var _s1 = chart_slot_rect(1), _s2 = chart_slot_rect(2);
    switch (ctip) {
        case 1: { // the star charts panel: both slots and their heading
            var _r = [_s1[0] - 8, _s1[1] - 28, _s1[2] + 8, _s2[3] + 8];
            ctip_frame(_r, _col);
            tut_arrow_at(_r[0], (_r[1] + _r[3]) / 2, 180, 14, 32, _col);
            break;
        }
        case 2: // slot 1, now holding the condition survived
            ctip_frame([_s1[0] - 6, _s1[1] - 6, _s1[2] + 6, _s1[3] + 6], _col);
            tut_arrow_at(_s1[0], (_s1[1] + _s1[3]) / 2, 180, 14, 32, _col);
            break;
        case 3: { // the greyed play button and slot 1's have/need figure
            var _bx = _gw / 2 - btn_w / 2, _by = _gh - btn_h - 20;
            ctip_frame([_bx - 6, _by - 6, _bx + btn_w + 6, _by + btn_h + 6], c_red);
            tut_arrow_at(_bx + btn_w / 2, _by - 6, 90, 14, 32, c_red);
            var _cx2 = _s1[2] - CHART_ARROW_W - 2;
            var _cr = [_cx2 - 74, _s1[1] - 4, _cx2 + 2, _s1[3] + 4];
            ctip_frame(_cr, c_red);
            tut_arrow_at((_cr[0] + _cr[2]) / 2, _cr[1], 90, 14, 32, c_red);
            break;
        }
    }
    // The message panel, centred, with page pips and a "continue" triangle
    static pages = ["You just faced a sector condition and lived!\nYour survey data can buy you star charts.",
                    "Every time you survive one of these deadly encounters, it becomes available to seek out, and you can earn bonus rewards!",
                    "But you'll have to collect some more before you can do that."];
    var _txt = pages[ctip - 1];
    var _tw = TIP_W - 32, _sep = string_height("A") + 2;
    var _h = 16 + string_height_ext(_txt, _sep, _tw / TIP_TEXT) * TIP_TEXT + 34;
    var _x1 = _gw / 2 - TIP_W / 2, _y1 = _gh * 0.3;
    if (!panel_unfurl(ctip_t / UNFURL_FRAMES, _gw / 2, _y1 + _h / 2, _x1, _y1, _x1 + TIP_W, _y1 + _h, _col, TUT_PANEL_ALPHA)) return;
    tip_text(_x1 + 16, _y1 + 14, _txt, _tw, c_white);
    var _py = _y1 + _h - 16;
    for (var i = 0; i < 3; i++) {
        draw_set_colour((i + 1 == ctip) ? _col : c_dkgray);
        draw_rectangle(_x1 + 16 + i * 14, _py - 4, _x1 + 24 + i * 14, _py + 4, false);
    }
    if (ctip_t >= CTIP_MIN_FRAMES) {
        var _cx = _x1 + TIP_W - 24;
        draw_set_colour(c_white);
        draw_set_alpha(0.4 + 0.6 * (0.5 + 0.5 * sin(current_time / 140)));
        draw_triangle(_cx - 6, _py - 9, _cx - 6, _py + 9, _cx + 9, _py, false);
    }
    draw_reset();
    clip_end();
}
