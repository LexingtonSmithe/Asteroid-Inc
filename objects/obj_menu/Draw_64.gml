var _gw = display_get_gui_width();
var _gh = display_get_gui_height();
draw_reset();

// Dim the drifting asteroids behind the menu
draw_set_alpha(0.45);
draw_set_colour(c_black);
draw_rectangle(0, 0, _gw, _gh, false);
draw_reset();

// Title
var _title = (screen == "main") ? "ASTEROID INC" : "OPTIONS";
var _ty = (screen == "main") ? _gh / 2 - 110 : opt_top() - 40;
draw_set_halign(fa_center);
draw_set_valign(fa_middle);
draw_set_colour(make_colour_rgb(225, 70, 60));
draw_set_alpha(ease_out_cubic(menu_anim * 1.2));
var _ts = min(3, (_gw * 0.8) / string_width("ASTEROID INC")); // fit any font
if (screen != "main") _ts *= 0.6; // smaller heading over the options list
draw_text_transformed(_gw / 2, _ty, _title, _ts, _ts, 0);

// Buttons unfurl from their own centre when a screen appears, staggered per row

if (screen == "main") {
    for (var i = 0; i < array_length(items); i++) {
        var _r = item_rect(i);
        var _ri = clamp(menu_anim * 1.5 - i * 0.12, 0, 1);
        if (_ri <= 0) continue;
        var _ur = unfurl_rect((_r[0] + _r[2]) / 2, (_r[1] + _r[3]) / 2, _r[0], _r[1], _r[2], _r[3], _ri);
        draw_set_alpha(1);
        var _sel = (i == selected);
        var _fill, _text;
        if (!enabled[i])                        { _fill = make_colour_rgb(30, 32, 40);  _text = c_dkgray; }
        else if (_sel && act_is_new(i) && confirm_new) { _fill = make_colour_rgb(150, 50, 40); _text = c_white; }
        else if (_sel)                          { _fill = make_colour_rgb(70, 140, 90);  _text = c_white; }
        else                                    { _fill = make_colour_rgb(35, 60, 50);  _text = c_ltgray; }

        draw_set_colour(_fill);
        draw_rectangle(_ur[0], _ur[1], _ur[2], _ur[3], false);
        draw_set_colour(_sel && enabled[i] ? c_white : c_gray);
        draw_frame(_ur[0], _ur[1], _ur[2], _ur[3]);

        clip_begin(_ur, _r);
        var _label = (_sel && act_is_new(i) && confirm_new) ? "Overwrite?" : items[i];
        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        draw_set_colour(_text);
        draw_text_transformed((_r[0] + _r[2]) / 2, (_r[1] + _r[3]) / 2, _label, MENU_TEXT_SCALE, MENU_TEXT_SCALE, 0);
        clip_end();
    }
} else {
    var _s = global.settings;
    for (var i = 0; i < array_length(opts); i++) {
        var _o = opts[i];
        var _r = opt_rect(i);
        var _ri = clamp(menu_anim * 1.5 - i * 0.1, 0, 1);
        if (_ri <= 0) continue;
        var _ur = unfurl_rect((_r[0] + _r[2]) / 2, (_r[1] + _r[3]) / 2, _r[0], _r[1], _r[2], _r[3], _ri);
        draw_set_alpha(1);
        var _sel = (i == opt_sel);

        draw_set_colour(_sel ? make_colour_rgb(45, 80, 60) : make_colour_rgb(25, 35, 32));
        draw_rectangle(_ur[0], _ur[1], _ur[2], _ur[3], false);
        draw_set_colour(_sel ? c_white : c_gray);
        draw_frame(_ur[0], _ur[1], _ur[2], _ur[3]);

        clip_begin(_ur, _r);
        var _cy = (_r[1] + _r[3]) / 2;
        draw_set_valign(fa_middle);
        draw_set_colour(_sel ? c_white : c_ltgray);
        if (_o.kind == "back") {
            draw_set_halign(fa_center);
            draw_text_transformed((_r[0] + _r[2]) / 2, _cy, _o.label, MENU_TEXT_SCALE, MENU_TEXT_SCALE, 0);
            clip_end();
            continue;
        }
        draw_set_halign(fa_left);
        draw_text_transformed(_r[0] + 16, _cy, _o.label, MENU_TEXT_SCALE, MENU_TEXT_SCALE, 0);

        var _c = ctrl_rect(i);
        if (_o.kind == "slider") {
            var _t = (_s[$ _o.key] - _o.lo) / (_o.hi - _o.lo);
            var _on = !(_o.key == "glow_strength" && !_s.glow); // dim glow power while glow is off
            draw_bar(_c[0], _c[1], _c[2] - _c[0], _c[3] - _c[1], _t, _on ? make_colour_rgb(80, 220, 120) : c_dkgray);
            // Handle
            var _hx = lerp(_c[0], _c[2], _t);
            draw_set_colour(c_white);
            draw_rectangle(_hx - 3, _c[1] - 3, _hx + 3, _c[3] + 3, false);
        } else {
            // Toggle: a switch track with the knob left (off) or right (on)
            var _val = _s[$ _o.key];
            var _sw = 44, _x0 = _c[2] - _sw;
            draw_set_colour(_val ? make_colour_rgb(80, 220, 120) : make_colour_rgb(60, 60, 70));
            draw_rectangle(_x0, _c[1], _c[2], _c[3], false);
            draw_set_colour(c_white);
            draw_frame(_x0, _c[1], _c[2], _c[3]);
            var _kx = _val ? _c[2] - 18 : _x0 + 5;
            draw_rectangle(_kx, _c[1] + 5, _kx + 13, _c[3] - 5, false);
        }
        clip_end();
    }
}
draw_reset();
