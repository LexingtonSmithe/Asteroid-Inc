var _gw = display_get_gui_width();
var _gh = display_get_gui_height();
var _mx = device_mouse_x_to_gui(0);
var _my = device_mouse_y_to_gui(0);
draw_reset();

var _n = array_length(global.upgrades);

// Connection lines (drawn first so nodes sit on top)
for (var i = 0; i < _n; i++) {
    var _u = global.upgrades[i];
    var _hidden = !upg_visible(_u);
    if (_hidden && !show_all) continue;
    var _p = node_pos(_u);
    draw_set_alpha(_hidden ? 0.3 : reveal_of(_u));
    for (var j = 0; j < array_length(_u.req); j++) {
        var _r = upg_get(_u.req[j]);
        if (_r == undefined) continue;
        var _q = node_pos(_r);
        draw_set_colour(upg_level(_u.id) > 0 ? c_white : c_dkgray);
        draw_line_width(_p[0], _p[1], _q[0], _q[1], max(UI_LINE, 4 * zoom));
    }
}
draw_set_alpha(1);

// Link pulses: a bright block runs from the parent into the node just bought
for (var i = 0; i < array_length(link_pulses); i++) {
    var _lp = link_pulses[i];
    var _a = upg_get(_lp.from), _b = upg_get(_lp.to);
    if (_a == undefined || _b == undefined) continue;
    var _pa = node_pos(_a), _pb = node_pos(_b);
    var _e = ease_out_cubic(_lp.t);
    var _lx = lerp(_pa[0], _pb[0], _e), _ly = lerp(_pa[1], _pb[1], _e);
    var _lx0 = lerp(_pa[0], _pb[0], max(0, _e - 0.25)), _ly0 = lerp(_pa[1], _pb[1], max(0, _e - 0.25));
    draw_set_colour(make_colour_rgb(120, 255, 140));
    draw_line_width(_lx0, _ly0, _lx, _ly, max(UI_LINE + 3, 8 * zoom));
    draw_set_colour(c_white);
    draw_rectangle(_lx - 4, _ly - 4, _lx + 4, _ly + 4, false);
}
draw_reset();

// Nodes
for (var i = 0; i < _n; i++) {
    var _u = global.upgrades[i];
    var _hidden = !upg_visible(_u);
    if (_hidden && !show_all) continue;
    var _p = node_pos(_u);
    var _lvl = upg_level(_u.id);
    var _col;
    var _rv = _hidden ? 1 : reveal_of(_u);       // newly revealed nodes fade and grow in
    draw_set_alpha(_hidden ? 0.35 : _rv);        // undiscovered (F9 preview): faded grey
    if (_hidden)              _col = make_colour_rgb(70, 70, 78);
    else if (upg_maxed(_u))   _col = make_colour_rgb(255, 210, 80);  // maxed: gold
    else if (upg_can_buy(_u)) _col = make_colour_rgb(120, 255, 140); // affordable: green
    else if (_lvl > 0)        _col = make_colour_rgb(150, 170, 200); // owned, can't afford next
    else                      _col = make_colour_rgb(90, 90, 100);   // not yet affordable
    var _scale = (hover == _u) ? 1.15 : 1;
    var _bf = (buy_flash > 0 && buy_flash_id == _u.id) ? buy_flash / 16 : 0;
    _scale += _bf * 0.5;                         // just bought: pops big, settles back
    _scale *= zoom * (0.4 + 0.6 * _rv);
    draw_sprite_ext(spr_node, 0, _p[0], _p[1], _scale, _scale, 0, _col, draw_get_alpha());
    if (_bf > 0) {
        gpu_set_blendmode(bm_add);
        draw_sprite_ext(spr_node, 0, _p[0], _p[1], _scale, _scale, 0, c_white, _bf);
        gpu_set_blendmode(bm_normal);
        draw_set_colour(_col);
        draw_set_alpha(_bf);
        draw_ring(_p[0], _p[1], (18 + (1 - _bf) * 34) * zoom, max(UI_LINE, 4 * _bf * zoom)); // expanding shockwave
        draw_set_alpha(1);
    }

    // Resource pip: the rarest thing this node costs
    if (!upg_maxed(_u) && array_length(_u.cost) > 0) draw_sprite_ext(res_sprite(upg_main_res(_u)), 0, _p[0] + 12 * zoom, _p[1] - 12 * zoom, zoom, zoom, 0, c_white, draw_get_alpha());

    // Level pips under the node
    if (_u.max_level > 1) {
        var _pw = 4 * zoom, _gap = 2 * zoom;
        var _total = _u.max_level * (_pw + _gap) - _gap;
        var _px = _p[0] - _total / 2;
        var _py = _p[1] + 22 * zoom;
        for (var k = 0; k < _u.max_level; k++) {
            draw_set_colour(k < _lvl ? c_white : c_dkgray);
            draw_rectangle(_px + k * (_pw + _gap), _py, _px + k * (_pw + _gap) + _pw - 1, _py + 3 * zoom, false);
        }
    }
}
draw_reset();

// Purchase burst particles
for (var i = 0; i < array_length(tree_parts); i++) {
    var _q = tree_parts[i];
    draw_set_alpha(min(1, _q.life / 12));
    draw_set_colour(_q.col);
    draw_rectangle(_q.x - _q.size / 2, _q.y - _q.size / 2, _q.x + _q.size / 2, _q.y + _q.size / 2, false);
}
draw_reset();

// F9 preview indicator
if (show_all) {
    draw_set_halign(fa_center);
    draw_set_colour(c_gray);
    draw_text_transformed(_gw / 2, _gh - btn_h - 40, "FULL TREE [F9]", 0.7, 0.7, 0);
    draw_reset();
}
if (global.free_costs) {
    draw_set_halign(fa_center);
    draw_set_colour(make_colour_rgb(255, 120, 60));
    draw_text_transformed(_gw / 2, _gh - btn_h - 58, "COSTS OFF [F12]", 0.7, 0.7, 0);
    draw_reset();
}

// Bank (top left)
bank_rows = draw_resource_list(20, 24, global.bank); // rows kept for the hover tooltip below
// EXCHANGE button just under it: opens the Exchange screen (scr_exchange)
ex_draw_button(ex_tree_button_rect(), "EXCHANGE", make_colour_rgb(255, 205, 50), true, ex_hov);

// Last day's haul (top centre)
if (global.last_day != undefined) draw_resource_row(_gw / 2, 24, global.last_day.haul);

// Tier and charge meter (top right)
draw_threat_badges(_gw - 16, 16, 0, 0);

// Launch button: play triangle
var _bx = _gw / 2 - btn_w / 2;
var _by = _gh - btn_h - 20;
var _over = over_button(_mx, _my);
var _go = survey_affordable(); // survey picks it can't pay for lock the button
if (_go) draw_set_colour(_over ? make_colour_rgb(70, 140, 90) : make_colour_rgb(40, 90, 60));
else draw_set_colour(make_colour_rgb(40, 42, 48));
draw_rectangle(_bx, _by, _bx + btn_w, _by + btn_h, false);
draw_set_colour(_go ? c_white : c_dkgray);
draw_frame(_bx, _by, _bx + btn_w, _by + btn_h);
var _cx = _bx + btn_w / 2, _cy = _by + btn_h / 2;
draw_triangle(_cx - 9, _cy - 12, _cx - 9, _cy + 12, _cx + 13, _cy, false);
draw_reset();
// Star chart slot picks (paid on launch): named over the launch button
var _next = slot_next_label();
if (_next != "") {
    var _sr = slot_short();
    var _txt = _go ? string_replace_all(_next, " + ", "\n+ ") // two picks stack instead of running wide
                   : "NOT ENOUGH " + string_upper(res_name(_sr)) + (res_is_survey(_sr) ? "" : ((_sr == RES.BOX) ? "ES" : "S"));
    // Stay clear of the star charts panel on the right (shrink if it still doesn't fit)
    var _pr = chart_slot_rect(1);
    var _room = (chart_panel_shown() ? _pr[0] : _gw) - 16 - _gw / 2;
    var _ts = min(0.8, 2 * _room / max(1, string_width(_txt)));
    draw_set_halign(fa_center);
    draw_set_valign(fa_bottom);
    draw_set_colour(_go ? slot_next_colour() : c_red);
    draw_text_transformed(_gw / 2, _by - 6, _txt, _ts, _ts, 0);
    draw_reset();
}

// Star charts (bottom right) and their tooltip
chart_draw_panel(_mx, _my);
// Weapon picker (bottom left)
wpn_draw_panel(_mx, _my);

// Tree tutorial prompts (scr_tutorial), under the tooltips
tut_tree_draw();

// Bank list hover: the material's name and what it's for
if (hover == undefined && chart_hov == 0 && wpn_hov < 0 && !ex_hov) {
    for (var i = 0; i < array_length(bank_rows); i++) {
        var _br = bank_rows[i];
        if (point_in_rectangle(_mx, _my, 14, _br[1] - 12, _br[2] + 6, _br[1] + 12)) {
            draw_tip(_mx, _my, res_name(_br[0]), res_colour(_br[0]), res_desc(_br[0]), 32, _br[1]); // unfurls from the row's icon
            break;
        }
    }
}

// Tooltip: name, description, tier requirement, costs (icon + number each)
#macro TIP_WRAP 300
if (hover != undefined) {
    var _u = hover;
    var _maxed = upg_maxed(_u);
    var _lh = string_height("A") + 4;
    var _cost = _maxed ? [] : upg_cost(_u);
    // Description wraps at TIP_WRAP px so long text never makes a huge box
    var _wrap = min(TIP_WRAP, _gw - 24);
    var _dw = min(string_width(_u.desc), _wrap);
    var _dh = string_height_ext(_u.desc, _lh, _wrap);
    var _tw = max(string_width(_u.name), _dw, 60) + 16;
    var _th = _lh + _dh + 10 + array_length(_cost) * 24;
    var _tx = max(4, min(_mx + 18, _gw - _tw - 4));
    var _ty = max(4, min(_my + 18, _gh - _th - 4));

    var _np = node_pos(_u);
    tip_open("node:" + _u.id, _np[0], _np[1], _tx, _ty, _tx + _tw, _ty + _th); // unfurls from the node

    draw_set_colour(make_colour_rgb(255, 230, 140));
    draw_text(_tx + 8, _ty + 5, _u.name);
    draw_set_colour(c_white);
    draw_text_ext(_tx + 8, _ty + 5 + _lh, _u.desc, _lh, _wrap);
    var _cy2 = _ty + 5 + _lh + _dh;
    for (var c = 0; c < array_length(_cost); c++) {
        var _r = _cost[c][0], _amt = _cost[c][1];
        var _cyc = _cy2 + 12 + c * 24;
        var _end = draw_res_amount(_tx + 8, _cyc, _r, string(_amt), 1.2);
        if (global.bank[_r] < _amt) {
            // Can't afford this part: strike it through
            draw_set_colour(make_colour_rgb(255, 110, 110));
            draw_line_width(_tx + 6, _cyc, _end + 2, _cyc, UI_LINE);
        }
    }
    draw_reset();
    tip_close();
}

// Star chart tip, over everything (scr_tutorial)
ctip_draw();

// Tier warning modal, over everything (obj_tree Step handles its input)
if (confirm_u != undefined) {
    var _gw2 = display_get_gui_width(), _gh2 = display_get_gui_height();
    var _cr = confirm_rects(), _p = _cr.panel;
    draw_set_colour(c_black); draw_set_alpha(0.65);
    draw_rectangle(0, 0, _gw2, _gh2, false);
    draw_set_alpha(1);
    draw_set_colour(make_colour_rgb(18, 22, 30));
    draw_rectangle(_p[0], _p[1], _p[2], _p[3], false);
    draw_set_colour(make_colour_rgb(255, 170, 60));
    draw_frame(_p[0], _p[1], _p[2], _p[3]);
    // Node name, then the warning, wrapped to the panel
    var _tw = _p[2] - _p[0] - 48;
    draw_set_halign(fa_center);
    draw_set_colour(make_colour_rgb(255, 230, 140));
    draw_text_transformed((_p[0] + _p[2]) / 2, _p[1] + 22, confirm_u.name, 0.9, 0.9, 0);
    draw_set_colour(c_white);
    var _ws = 0.75;
    draw_text_ext_transformed((_p[0] + _p[2]) / 2, _p[1] + 70, TIER_WARNING, (string_height("A") + 6), _tw / _ws, _ws, _ws, 0);
    // Buttons: NOT YET (left), ENTER (right)
    var _btns = [[_cr.no, "NOT YET", 2, make_colour_rgb(50, 54, 64), make_colour_rgb(80, 86, 100)],
                 [_cr.yes, "ENTER", 1, make_colour_rgb(40, 90, 60), make_colour_rgb(70, 140, 90)]];
    draw_set_valign(fa_middle);
    for (var b = 0; b < 2; b++) {
        var _r = _btns[b][0], _on = (confirm_hov == _btns[b][2]);
        draw_set_colour(_on ? _btns[b][4] : _btns[b][3]);
        draw_rectangle(_r[0], _r[1], _r[2], _r[3], false);
        draw_set_colour(c_white);
        draw_frame(_r[0], _r[1], _r[2], _r[3]);
        draw_text_transformed((_r[0] + _r[2]) / 2, (_r[1] + _r[3]) / 2, _btns[b][1], 0.8, 0.8, 0);
    }
    draw_reset();
}
