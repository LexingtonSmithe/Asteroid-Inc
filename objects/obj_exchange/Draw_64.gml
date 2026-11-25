var _gw = display_get_gui_width();
var _goods = ex_goods();
var _opts  = (global.ex_r >= 0) ? ex_options(global.ex_r) : [];
var _L = ex_layout(_goods, array_length(_opts));
var _head = make_colour_rgb(150, 170, 200);
var _gold = make_colour_rgb(255, 205, 50);
var _qs = ex_quantities();

// Bank (top left, same place as on the tree)
draw_resource_list(20, 24, global.bank);

// Title
draw_set_halign(fa_center);
draw_set_valign(fa_middle);
draw_set_colour(_gold);
draw_text_transformed(_L.lx + _L.cw + EX_GAP / 2, 56, "EXCHANGE", 1.6, 1.6, 0); // centred over the two columns
draw_reset();

// Headings
draw_set_colour(_head);
draw_set_valign(fa_bottom);
draw_text_transformed(_L.lx, EX_TOP + 16, "QUANTITY", 0.7, 0.7, 0);
draw_text_transformed(_L.lx, EX_TOP + 96, "RESOURCE", 0.7, 0.7, 0);
draw_text_transformed(_L.rx, EX_TOP + 16, "PRICE", 0.7, 0.7, 0);
draw_reset();

// Quantity buttons
for (var i = 0; i < array_length(_L.qty); i++) ex_draw_button(_L.qty[i], string(_qs[i]), c_white, true, hov == "q" + string(i), global.ex_q == i);

// Resource buttons: icon + name in its colour
for (var i = 0; i < array_length(_goods); i++) {
    var _r = _L.res[i], _g = _goods[i], _col = res_colour(_g), _sel = (global.ex_r == _g);
    ex_draw_button(_r, "", _col, true, hov == "r" + string(i), _sel);
    var _cy = (_r[1] + _r[3]) / 2;
    draw_sprite_ext(res_sprite(_g), 0, _r[0] + 20, _cy, 1.6, 1.6, 0, c_white, 1);
    var _nm = string_upper(res_name(_g));
    var _s = min(0.8, (_r[2] - _r[0] - 48) / max(1, string_width(_nm)));
    draw_set_valign(fa_middle);
    draw_set_colour(_sel ? c_white : _col);
    draw_text_transformed(_r[0] + 38, _cy, _nm, _s, _s, 0);
    draw_reset();
}
if (array_length(_goods) == 0) {
    draw_set_colour(c_gray);
    draw_text_transformed(_L.lx, EX_TOP + 112, "Nothing to exchange yet", 0.7, 0.7, 0);
    draw_reset();
}

// Right: what you get, then every way to pay (pick one), then EXCHANGE
if (global.ex_r >= 0) {
    var _q = _qs[global.ex_q];
    draw_res_amount(_L.rx, EX_TOP + 40, global.ex_r, "+" + string(_q) + " " + string_upper(res_name(global.ex_r)), 1.6);
    for (var i = 0; i < array_length(_opts); i++) {
        var _r = _L.opt[i], _p = ex_price(_opts[i], _q), _sel = (global.ex_o == i);
        var _ok = ex_affordable(_p);
        ex_draw_button(_r, "", _ok ? _gold : c_red, true, hov == "o" + string(i), _sel);
        if (i > 0) { // "OR" between the options
            draw_set_halign(fa_center);
            draw_set_valign(fa_middle);
            draw_set_colour(_head);
            draw_text_transformed((_r[0] + _r[2]) / 2, _r[1] - 6, "OR", 0.55, 0.55, 0);
            draw_reset();
        }
        // Radio dot, then each part of the price (struck through in red where short)
        var _cy = (_r[1] + _r[3]) / 2;
        draw_set_colour(_sel ? c_white : c_gray);
        draw_circle(_r[0] + 18, _cy, 7, !_sel);
        draw_reset();
        var _x = _r[0] + 36;
        for (var j = 0; j < array_length(_p); j++) {
            var _short = !global.free_costs && global.bank[_p[j][0]] < _p[j][1];
            var _end = draw_res_amount(_x, _cy, _p[j][0], num_short(_p[j][1]), 1.3);
            if (_short) { draw_set_colour(c_red); draw_line(_x - 2, _cy, _end + 2, _cy); draw_reset(); }
            _x = _end + 22;
        }
    }
}
var _price = cur_price();
var _can = (_price != undefined) && ex_affordable(_price);
ex_draw_button(_L.go, "EXCHANGE", make_colour_rgb(120, 255, 140), _can, hov == "go", false, 1);
if (go_flash > 0) {
    draw_set_alpha(go_flash * 0.5);
    draw_set_colour(c_white);
    draw_rectangle(_L.go[0], _L.go[1], _L.go[2], _L.go[3], false);
    draw_reset();
}

// Back to the tree (ESC too)
ex_draw_button(_L.back, "BACK", c_white, true, hov == "back");
