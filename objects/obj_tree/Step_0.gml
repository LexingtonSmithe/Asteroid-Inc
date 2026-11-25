// Effects keep animating even while the screen wipes
for (var i = array_length(tree_parts) - 1; i >= 0; i--) {
    var _q = tree_parts[i];
    _q.x += _q.vx; _q.y += _q.vy;
    _q.vx *= 0.9;  _q.vy *= 0.9;
    _q.life -= 1;
    if (_q.life <= 0) array_delete(tree_parts, i, 1);
}
for (var i = array_length(link_pulses) - 1; i >= 0; i--) {
    link_pulses[i].t += 1 / 14;
    if (link_pulses[i].t >= 1) array_delete(link_pulses, i, 1);
}
for (var i = 0; i < array_length(global.upgrades); i++) {
    var _ru = global.upgrades[i];
    if (!upg_visible(_ru)) continue;
    var _rv = reveal[$ _ru.id];
    reveal[$ _ru.id] = (_rv == undefined) ? 0 : min(1, _rv + 0.04); // newly revealed: fades in
}

if (transition_active()) exit; // no input while the screen is wiping

var _mx = device_mouse_x_to_gui(0);
var _my = device_mouse_y_to_gui(0);

// Tier warning modal: nothing else takes input while it's up
if (confirm_u != undefined) {
    hover = undefined; chart_hov = 0; wpn_hov = -1; ex_hov = false; dragging = false;
    var _cr = confirm_rects(), _prev_c = confirm_hov;
    confirm_hov = point_in_rectangle(_mx, _my, _cr.yes[0], _cr.yes[1], _cr.yes[2], _cr.yes[3]) ? 1
                : (point_in_rectangle(_mx, _my, _cr.no[0], _cr.no[1], _cr.no[2], _cr.no[3]) ? 2 : 0);
    if (confirm_hov != 0 && confirm_hov != _prev_c) sfx(snd_ui_hover, 0.3, 1, 0.05);
    var _yes = keyboard_check_pressed(vk_enter) || (mouse_check_button_pressed(mb_left) && confirm_hov == 1);
    var _no  = keyboard_check_pressed(vk_escape) || (mouse_check_button_pressed(mb_left) && confirm_hov == 2)
            || (mouse_check_button_pressed(mb_left) && !point_in_rectangle(_mx, _my, _cr.panel[0], _cr.panel[1], _cr.panel[2], _cr.panel[3]));
    if (_yes) { try_buy(confirm_u); confirm_u = undefined; }
    else if (_no) { sfx(snd_ui_click, 0.5, 0.9, 0.05); confirm_u = undefined; }
    exit;
}

// Pan: right-drag, WASD or arrow keys
if (mouse_check_button_pressed(mb_right)) { dragging = true; drag_x = _mx; drag_y = _my; }
if (mouse_check_button_released(mb_right)) dragging = false;
if (dragging) {
    cam_x += _mx - drag_x;
    cam_y += _my - drag_y;
    drag_x = _mx;
    drag_y = _my;
}
var _k = 8;
cam_x += (keyboard_check(vk_left) || keyboard_check(ord("A"))) * _k - (keyboard_check(vk_right) || keyboard_check(ord("D"))) * _k;
cam_y += (keyboard_check(vk_up)   || keyboard_check(ord("W"))) * _k - (keyboard_check(vk_down)  || keyboard_check(ord("S"))) * _k;

// Zoom: mouse wheel zooms around the cursor; Q/E or +/- zoom around the centre
if (mouse_wheel_up())   zoom_at(1.15, _mx, _my);
if (mouse_wheel_down()) zoom_at(1 / 1.15, _mx, _my);
var _gcx = display_get_gui_width() / 2, _gcy = display_get_gui_height() / 2;
if (keyboard_check(ord("E")) || keyboard_check(vk_add)      || keyboard_check(187)) zoom_at(1.02, _gcx, _gcy); // 187 = =/+ key
if (keyboard_check(ord("Q")) || keyboard_check(vk_subtract) || keyboard_check(189)) zoom_at(1 / 1.02, _gcx, _gcy); // 189 = -/_ key
if (keyboard_check_pressed(vk_home)) { zoom = 1; cam_x = 0; cam_y = 0; }

// Hover detection: star chart rows (bottom right) sit above the tree
var _prev_hover = hover, _prev_chart = chart_hov;
chart_hov = chart_slot_at(_mx, _my);
var _prev_wpn = wpn_hov;
wpn_hov = wpn_row_at(_mx, _my);
var _prev_ex = ex_hov;
var _exr = ex_tree_button_rect();
ex_hov = point_in_rectangle(_mx, _my, _exr[0], _exr[1], _exr[2], _exr[3]);
if (ex_hov && !_prev_ex) sfx(snd_ui_hover, 0.3, 1, 0.05);
hover = undefined;
var _half = 16 * zoom;
if (chart_hov == 0 && wpn_hov < 0 && !ex_hov) for (var i = 0; i < array_length(global.upgrades); i++) {
    var _u = global.upgrades[i];
    if (!upg_visible(_u) && !show_all) continue;
    var _p = node_pos(_u);
    if (abs(_mx - _p[0]) <= _half && abs(_my - _p[1]) <= _half) { hover = _u; break; }
}
if ((hover != undefined && hover != _prev_hover) || (chart_hov != 0 && chart_hov != _prev_chart) || (wpn_hov >= 0 && wpn_hov != _prev_wpn)) sfx(snd_ui_hover, 0.3, 1, 0.05);

// Tree tutorial (scr_tutorial): moves on when Damage is bought; may take the click below
tut_tree_step();
// First condition survived: a three-page star chart tip that takes all input while it's up
if (ctip_step()) { hover = undefined; chart_hov = 0; wpn_hov = -1; ex_hov = false; exit; }

// Clicks
if (mouse_check_button_pressed(mb_left)) {
    if (tut_tree_click()) {
        // the tutorial took it (continue, or a click away from the node it's pointing at)
    } else if (ex_hov) {
        sfx(snd_ui_click, 0.5, 1, 0.05);
        transition_to(rm_exchange); // the Exchange screen (scr_exchange)
    } else if (chart_hov != 0) {
        chart_click(chart_hov, _mx, _my); // steps that star chart slot's pick (scr_charts)
    } else if (wpn_hov >= 0) {
        // Weapon picker: this one goes on the cursor for the next day
        if (wpn_hov != wpn_active()) {
            global.active_weapon = wpn_hov;
            save_game();
            sfx(snd_ui_click, 0.6, 1, 0.05);
        }
    } else if (over_button(_mx, _my)) {
        launch_day();
    } else if (hover != undefined) {
        // A new sector (or Jump Drive) raises the tier: warn first
        if (upg_raises_tier(hover) && upg_can_buy(hover)) { confirm_u = hover; confirm_hov = 0; sfx(snd_ui_click, 0.6, 0.8, 0.05); }
        else try_buy(hover);
    }
}
if ((keyboard_check_pressed(vk_space) || keyboard_check_pressed(vk_enter)) && !tut_tree_key()) launch_day();
// ESC: skips the tree tutorial while it's showing, otherwise back to the menu
if (keyboard_check_pressed(vk_escape)) { if (ttut != TTREE.OFF) tut_tree_end(); else transition_to(rm_menu); }
if (buy_flash > 0) buy_flash--;

// Debug helpers
if (DEBUG_KEYS) {
    if (keyboard_check_pressed(vk_f9)) show_all = !show_all;
    if (keyboard_check_pressed(vk_f11)) reset_save();
    // F10: every node to max (performance / "everything firing" stress test). Overwrites the save.
    // Tier unlocks and the Jump Drive are left alone, so the tier (and asteroid toughness) stays
    // where it was: maxing those too jumps to tier 9, where rocks have ~550x the HP.
    if (keyboard_check_pressed(vk_f10)) {
        for (var i = 0; i < array_length(global.upgrades); i++) {
            var _fu = global.upgrades[i];
            if (string_pos("unlock_", _fu.id) == 1 || _fu.id == "jump_drive") continue;
            global.levels[$ _fu.id] = _fu.max_level;
        }
        stats_build();
        save_game();
        sfx(snd_affirmative, 0.7);
    }
    // F12: costs on/off (upgrades, Survey Data, star charts). Not saved: resets when the game restarts.
    if (keyboard_check_pressed(vk_f12)) {
        global.free_costs = !global.free_costs;
        sfx(global.free_costs ? snd_affirmative : snd_denied, 0.7);
    }
}
