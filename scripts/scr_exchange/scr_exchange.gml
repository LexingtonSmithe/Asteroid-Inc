// ---------------------------------------------------------------------------
// Exchange (rm_exchange / obj_exchange): swap resources at fixed rates.
// Pick a quantity (1 / 100 / 500 / 1000) and a resource; every way of paying for it
// is listed on the right and the player picks one. EXCHANGE trades and keeps the
// picks, so it can be pressed again while the bank still covers it.
// Ore, Ice, Crystal and Platinum trade both ways at the same rates (1 Ice = 3 Ore, so
// 100 Ore costs 34 Ice: fractions round up). Boss Cores and Pirate Hats can't be bought here.
// ---------------------------------------------------------------------------

/// Quantities on the quantity buttons.
function ex_quantities() { static q = [1, 100, 500, 1000]; return q; }

/// Basic resources: what ONE of _r costs in each lower resource (the rates as given).
/// The same rates run backwards: ONE Ore costs 1/3 Ice, and so on (ex_rates).
function ex_basic_rates(_r) {
    switch (_r) {
        case RES.ICE:      return [[RES.ORE, 3]];
        case RES.CRYSTAL:  return [[RES.ICE, 10], [RES.ORE, 30]];
        case RES.PLATINUM: return [[RES.CRYSTAL, 20], [RES.ICE, 400], [RES.ORE, 1200]];
    }
    return [];
}
function ex_is_basic(_r) { return _r == RES.ORE || _r == RES.ICE || _r == RES.CRYSTAL || _r == RES.PLATINUM; }

/// Ways to pay for ONE of resource _r: an array of options, each [[resource, amount], ...].
/// Amounts can be fractions for basic resources bought with a richer one (ex_price rounds up).
function ex_rates(_r) {
    if (ex_is_basic(_r)) {
        var _out = [];
        // Paying with a cheaper resource: the rates as given
        var _down = ex_basic_rates(_r);
        for (var i = 0; i < array_length(_down); i++) array_push(_out, [_down[i]]);
        // Paying with a richer one: the same rate reversed
        var _rich = [RES.ICE, RES.CRYSTAL, RES.PLATINUM];
        for (var k = 0; k < array_length(_rich); k++) {
            var _up = ex_basic_rates(_rich[k]);
            for (var i = 0; i < array_length(_up); i++) if (_up[i][0] == _r) array_push(_out, [[_rich[k], 1 / _up[i][1]]]);
        }
        return _out;
    }
    switch (_r) {
        case RES.BOX:      return [ [[RES.ORE, 200]], [[RES.ICE, 75]], [[RES.CRYSTAL, 50]] ];
        case RES.COIN:     return [ [[RES.ORE, 500]], [[RES.ICE, 250]], [[RES.CRYSTAL, 150]] ];
        case RES.SURVEY:   return [ [[RES.ORE, 100]], [[RES.BOX, 3]] ];
        case RES.SURVEY2:  return [ [[RES.ORE, 200], [RES.ICE, 100]], [[RES.BOX, 6]] ];
        case RES.SURVEY3:  return [ [[RES.ORE, 400], [RES.ICE, 200], [RES.CRYSTAL, 100]], [[RES.BOX, 9]] ];
    }
    return [];
}

/// The player knows about resource _r: ore always, asteroid types once unlocked, tokens once banked.
function ex_known(_r) {
    if (_r == RES.ORE) return true;
    if (_r == RES.ICE || _r == RES.CRYSTAL || _r == RES.PLATINUM) return res_unlocked(_r) || global.found[_r];
    return global.found[_r];
}

/// Resources on offer, in button order. Black Boxes and Gold Coins once discovered;
/// Survey Data for each tier reached (1-3).
function ex_goods() {
    var _g = [];
    var _all = [RES.ORE, RES.ICE, RES.CRYSTAL, RES.PLATINUM, RES.BOX, RES.COIN];
    for (var i = 0; i < array_length(_all); i++) if (ex_known(_all[i])) array_push(_g, _all[i]);
    var _st = [RES.SURVEY, RES.SURVEY2, RES.SURVEY3];
    for (var t = 1; t <= clamp(global.tier, 1, 3); t++) array_push(_g, _st[t - 1]);
    return _g;
}

/// Payment options for _r that only use resources the player knows about.
function ex_options(_r) {
    var _all = ex_rates(_r), _out = [];
    for (var i = 0; i < array_length(_all); i++) {
        var _ok = true;
        for (var j = 0; j < array_length(_all[i]); j++) if (!ex_known(_all[i][j][0])) _ok = false;
        if (_ok) array_push(_out, _all[i]);
    }
    return _out;
}

/// Total price of option _opt (from ex_options) for _qty units: [[resource, amount], ...].
function ex_price(_opt, _qty) {
    var _p = [];
    // Fractions (a reversed rate) round up, so a trade never comes out cheaper than the rate
    for (var i = 0; i < array_length(_opt); i++) array_push(_p, [_opt[i][0], ceil(_opt[i][1] * _qty - 0.0001)]);
    return _p;
}

/// Bank covers price _p (always, with debug free costs on).
function ex_affordable(_p) {
    if (global.free_costs) return true;
    for (var i = 0; i < array_length(_p); i++) if (global.bank[_p[i][0]] < _p[i][1]) return false;
    return true;
}

/// Trades: pays _p and banks _qty of _r. False if it can't be afforded.
function ex_trade(_r, _qty, _p) {
    if (!ex_affordable(_p)) return false;
    if (!global.free_costs) for (var i = 0; i < array_length(_p); i++) global.bank[_p[i][0]] -= _p[i][1];
    global.bank[_r] += _qty;
    global.found[_r] = true;
    save_game();
    return true;
}

// --- Tree screen: the EXCHANGE button under the bank list ---------------------------
#macro EX_BTN_W 180
#macro EX_BTN_H 36

/// [x1, y1, x2, y2] of the tree's EXCHANGE button, just under the bank list (drawn at 20, 24).
function ex_tree_button_rect() {
    var _y1 = resource_list_bottom(24, global.bank) + 14;
    return [16, _y1, 16 + EX_BTN_W, _y1 + EX_BTN_H];
}

/// Simple button: dark fill, coloured frame, centred label. _on = clickable, _hov = under the mouse.
function ex_draw_button(_r, _label, _col, _on, _hov, _sel = false, _scale = 0.8) {
    var _bg = make_colour_rgb(18, 22, 30);
    if (_sel) _bg = merge_colour(_col, c_black, 0.65);
    if (_hov && _on) _bg = merge_colour(_bg, c_white, 0.12);
    draw_set_colour(_bg);
    draw_rectangle(_r[0], _r[1], _r[2], _r[3], false);
    draw_set_colour(_on ? (_sel ? _col : merge_colour(_col, c_black, 0.3)) : c_dkgray);
    draw_frame(_r[0], _r[1], _r[2], _r[3], _sel ? 2 : 1);
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_set_colour(_on ? (_sel ? c_white : _col) : c_dkgray);
    var _s = min(_scale, (_r[2] - _r[0] - 12) / max(1, string_width(_label)));
    draw_text_transformed((_r[0] + _r[2]) / 2, (_r[1] + _r[3]) / 2, _label, _s, _s, 0);
    draw_reset();
}

/// Right edge (GUI x) of the bank list drawn at (20, 24): widest number, or the STAR CHARTS heading.
function ex_bank_right() {
    var _w = string_width("STAR CHARTS") * 0.7;
    for (var r = 0; r < RES.COUNT; r++) {
        if (r != RES.ORE && global.bank[r] <= 0) continue;
        _w = max(_w, 8 * 1.5 + 6 + string_width(string(floor(global.bank[r]))) * 1.2); // draw_res_amount at 1.5
    }
    return 20 + _w;
}

// --- Exchange screen layout (GUI space), shared by obj_exchange Step and Draw GUI ----
#macro EX_COL_W   400    // widest a column gets (the GUI is only 960 x 540: they shrink to fit)
#macro EX_GAP     32     // between the two columns
#macro EX_TOP     110
#macro EX_RES_H   40
#macro EX_OPT_H   44

/// { qty: [rects], res: [rects] (one per good), opt: [rects] (one per payment option of
///   the selected good), go: rect, back: rect, lx, rx, cw } as [x1, y1, x2, y2].
/// Two columns between the bank list (top left) and the right edge, centred when there's room.
/// BACK sits under the left column on the same row as EXCHANGE under the right.
function ex_layout(_goods, _nopt) {
    var _gw = display_get_gui_width();
    var _min = ex_bank_right() + 24;                                   // clear of the bank list
    var _cw  = min(EX_COL_W, (_gw - 16 - _min - EX_GAP) / 2);          // column width that fits
    var _lx  = max(_min, (_gw - (2 * _cw + EX_GAP)) / 2);
    var _rx  = _lx + _cw + EX_GAP;
    var _L = { qty: [], res: [], opt: [], lx: _lx, rx: _rx, cw: _cw };
    var _qw = (_cw - 3 * 6) / 4;
    for (var i = 0; i < 4; i++) {
        var _x = _lx + i * (_qw + 6);
        array_push(_L.qty, [_x, EX_TOP + 20, _x + _qw, EX_TOP + 56]);
    }
    var _rw = (_cw - 6) / 2, _ry = EX_TOP + 100;
    var _rows = ceil(array_length(_goods) / 2);
    for (var i = 0; i < array_length(_goods); i++) {
        var _x = _lx + (i mod 2) * (_rw + 6), _y = _ry + (i div 2) * (EX_RES_H + 6);
        array_push(_L.res, [_x, _y, _x + _rw, _y + EX_RES_H]);
    }
    var _oy = EX_TOP + 76;
    for (var i = 0; i < _nopt; i++) {
        var _y = _oy + i * (EX_OPT_H + 12);
        array_push(_L.opt, [_rx, _y, _rx + _cw, _y + EX_OPT_H]);
    }
    // Bottom row: under whichever column runs longer (room for three options on the right)
    var _gy = max(_ry + max(1, _rows) * (EX_RES_H + 6) - 6, _oy + 3 * (EX_OPT_H + 12) - 12) + 18;
    _L.go   = [_rx, _gy, _rx + _cw, _gy + 48];
    _L.back = [_lx, _gy, _lx + _cw, _gy + 48];
    return _L;
}
