menu_anim = min(1, menu_anim + 1 / 14);
if (transition_active()) exit; // no input while the screen is wiping
var _prev_screen = screen, _prev_sel = selected, _prev_opt = opt_sel; // for the hover blip below

var _mx = device_mouse_x_to_gui(0);
var _my = device_mouse_y_to_gui(0);
var _up    = keyboard_check_pressed(vk_up)    || keyboard_check_pressed(ord("W"));
var _down  = keyboard_check_pressed(vk_down)  || keyboard_check_pressed(ord("S"));
var _left  = keyboard_check_pressed(vk_left)  || keyboard_check_pressed(ord("A"));
var _right = keyboard_check_pressed(vk_right) || keyboard_check_pressed(ord("D"));
var _ok    = keyboard_check_pressed(vk_enter) || keyboard_check_pressed(vk_space);

if (screen == "main") {
    // Mouse hover selects, click activates
    for (var i = 0; i < array_length(items); i++) {
        var _r = item_rect(i);
        if (enabled[i] && point_in_rectangle(_mx, _my, _r[0], _r[1], _r[2], _r[3])) {
            if (selected != i) confirm_new = false;
            selected = i;
            if (mouse_check_button_pressed(mb_left)) activate(i);
        }
    }
    if (_up)   move_selection(-1);
    if (_down) move_selection(1);
    if (_ok)   activate(selected);
    if (keyboard_check_pressed(vk_escape)) {
        if (confirm_new) confirm_new = false; else { quitting = true; game_end(); }
    }
} else {
    // Options: hover selects a row; click toggles, or drag a slider
    var _n = array_length(opts);
    if (!dragging) {
        for (var i = 0; i < _n; i++) {
            var _r = opt_rect(i);
            if (point_in_rectangle(_mx, _my, _r[0], _r[1], _r[2], _r[3])) {
                opt_sel = i;
                if (mouse_check_button_pressed(mb_left)) {
                    if (opts[i].kind == "slider") dragging = true;
                    else adjust_option(i, 0);
                }
            }
        }
    }
    if (dragging) {
        var _o = opts[opt_sel];
        var _c = ctrl_rect(opt_sel);
        var _t = clamp((_mx - _c[0]) / (_c[2] - _c[0]), 0, 1);
        set_option(_o, lerp(_o.lo, _o.hi, _t));
        if (!mouse_check_button(mb_left)) dragging = false;
    }

    if (_up)    opt_sel = (opt_sel - 1 + _n) mod _n;
    if (_down)  opt_sel = (opt_sel + 1) mod _n;
    if (_left)  adjust_option(opt_sel, -1);
    if (_right) adjust_option(opt_sel, 1);
    if (_ok)    adjust_option(opt_sel, 0);
    if (keyboard_check_pressed(vk_escape)) { set_screen("main"); selected = act_index("options"); }
}

/// Blip when the highlighted item changes (mouse or keys)
if (screen == _prev_screen && (selected != _prev_sel || opt_sel != _prev_opt)) sfx(snd_ui_hover, 0.4, 1, 0.05);

// Background asteroids (none once the game is closing: instances made after game_end() skip their Create)
if (quitting) exit;
spawn_timer--;
if (spawn_timer <= 0) {
    var _a = spawn_asteroid();
    _a.vx *= 0.5;
    _a.vy *= 0.5;
    spawn_timer = irandom_range(40, 90);
}
