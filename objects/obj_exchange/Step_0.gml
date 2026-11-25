go_flash = max(0, go_flash - 0.06);
if (transition_active()) exit; // no input while the screen is wiping

var _mx = device_mouse_x_to_gui(0), _my = device_mouse_y_to_gui(0);
tidy();
var _goods = ex_goods();
var _opts  = (global.ex_r >= 0) ? ex_options(global.ex_r) : [];
var _L = ex_layout(_goods, array_length(_opts));

// Under the mouse
var _prev = hov;
hov = "";
for (var i = 0; i < array_length(_L.qty); i++) { var _r = _L.qty[i]; if (point_in_rectangle(_mx, _my, _r[0], _r[1], _r[2], _r[3])) hov = "q" + string(i); }
for (var i = 0; i < array_length(_L.res); i++) { var _r = _L.res[i]; if (point_in_rectangle(_mx, _my, _r[0], _r[1], _r[2], _r[3])) hov = "r" + string(i); }
for (var i = 0; i < array_length(_L.opt); i++) { var _r = _L.opt[i]; if (point_in_rectangle(_mx, _my, _r[0], _r[1], _r[2], _r[3])) hov = "o" + string(i); }
if (point_in_rectangle(_mx, _my, _L.go[0], _L.go[1], _L.go[2], _L.go[3]))         hov = "go";
if (point_in_rectangle(_mx, _my, _L.back[0], _L.back[1], _L.back[2], _L.back[3])) hov = "back";
if (hov != "" && hov != _prev) sfx(snd_ui_hover, 0.3, 1, 0.05);

// Clicks
if (mouse_check_button_pressed(mb_left) && hov != "") {
    if (hov == "back") {
        sfx(snd_ui_click, 0.5, 0.9, 0.05);
        transition_to(rm_tree);
    } else if (hov == "go") {
        do_trade();
    } else {
        var _kind = string_char_at(hov, 1);
        var _n = real(string_delete(hov, 1, 1));
        if (_kind == "q") global.ex_q = _n;
        else if (_kind == "r") { if (global.ex_r != _goods[_n]) { global.ex_r = _goods[_n]; global.ex_o = 0; } }
        else if (_kind == "o") global.ex_o = _n;
        sfx(snd_ui_click, 0.5, 1, 0.05);
    }
}
if (keyboard_check_pressed(vk_enter) || keyboard_check_pressed(vk_space)) do_trade();
if (keyboard_check_pressed(vk_escape)) transition_to(rm_tree);
