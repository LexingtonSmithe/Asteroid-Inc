/// Draw GUI End: screen flash, transition wipe, then scanlines over everything.

// Screen flash (boss kill, station destroyed)
if (global.flash_a > 0) {
    draw_set_alpha(global.flash_a);
    draw_set_colour(global.flash_col);
    draw_rectangle(0, 0, display_get_gui_width(), display_get_gui_height(), false);
    draw_reset();
}

// Transition: horizontal bands close from their centres (staggered top to bottom),
// each with a neon edge while it's moving.
if (trans_t > 0) {
    var _gw = display_get_gui_width(), _gh = display_get_gui_height();
    var _bh = _gh / TRANS_BANDS;
    for (var i = 0; i < TRANS_BANDS; i++) {
        var _p = ease_out_cubic(trans_t * 1.6 - (i / TRANS_BANDS) * 0.6);
        if (_p <= 0) continue;
        var _cy = (i + 0.5) * _bh;
        var _hh = _bh * 0.5 * _p + 0.5;
        draw_set_colour(make_colour_rgb(4, 6, 14));
        draw_rectangle(0, _cy - _hh, _gw, _cy + _hh, false);
        if (_p < 1) {
            draw_set_colour(HUD_EDGE);
            draw_rectangle(0, _cy - _hh - UI_LINE, _gw, _cy - _hh, false);
            draw_rectangle(0, _cy + _hh, _gw, _cy + _hh + UI_LINE, false);
        }
    }
    draw_reset();
}

if (shaders_ok && global.settings.scanlines) {
    shader_set(sh_scanlines);
    shader_set_uniform_f(u_period, max(2, window_get_height() / SCANLINE_ROWS));
    shader_set_uniform_f(u_sl_strength, SCANLINE_STRENGTH);
    shader_set_uniform_f(u_time, current_time / 1000);
    draw_rectangle(0, 0, display_get_gui_width(), display_get_gui_height(), false);
    shader_reset();
}

// Live-tuning readout
if (tune_text_timer > 0) {
    draw_reset();
    draw_set_halign(fa_center);
    draw_set_alpha(min(1, tune_text_timer / 30));
    draw_text(display_get_gui_width() / 2, display_get_gui_height() - 40, "GLOW " + string_format(global.settings.glow_strength, 1, 1));
    draw_reset();
}

// Mouse cursor: drawn last so it sits above the HUD, wipe and scanlines.
// The Windows cursor is hidden in game_init(). Tint: lime/red = can/can't launch a ship.
if (window_has_focus()) {
    var _col = c_white;
    if (instance_exists(obj_game) && obj_game.state == "playing") _col = obj_game.can_launch() ? c_lime : c_red;
    var _cz = 1 / view_zoom(); // in the game the cursor is part of the world: it shrinks as the camera pulls back
    _cz *= CURSOR_SCALE;
    draw_sprite_ext(spr_cursor, 0, device_mouse_x_to_gui(0), device_mouse_y_to_gui(0), _cz, _cz, 0, _col, 1);
}
