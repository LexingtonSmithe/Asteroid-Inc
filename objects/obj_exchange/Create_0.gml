/// Exchange screen: swap resources at fixed rates (scr_exchange). Everything is GUI space.
game_init();
global.frozen = false;

// Picks stay between visits (not saved): quantity index, resource, payment option
if (!variable_global_exists("ex_q")) { global.ex_q = 0; global.ex_r = -1; global.ex_o = 0; }

hov = "";        // under the mouse: "q0".."q3", "r0".., "o0".., "go", "back" or ""
go_flash = 0;    // EXCHANGE pressed: the button flashes

/// Keeps the picks valid: a resource on offer, and an option it has.
tidy = function() {
    var _g = ex_goods();
    if (array_length(_g) == 0) { global.ex_r = -1; return; }
    var _found = false;
    for (var i = 0; i < array_length(_g); i++) if (_g[i] == global.ex_r) _found = true;
    if (!_found) global.ex_r = _g[0];
    global.ex_o = clamp(global.ex_o, 0, max(0, array_length(ex_options(global.ex_r)) - 1));
    global.ex_q = clamp(global.ex_q, 0, 3);
};
tidy();

/// Price of the current picks as [[resource, amount], ...], or undefined if nothing's on offer.
cur_price = function() {
    if (global.ex_r < 0) return undefined;
    var _o = ex_options(global.ex_r);
    if (array_length(_o) == 0) return undefined;
    var _qs = ex_quantities();
    return ex_price(_o[global.ex_o], _qs[global.ex_q]);
};

/// EXCHANGE: trades if the bank covers it. The picks stay, so it can be pressed again.
do_trade = function() {
    var _p = cur_price();
    var _qs = ex_quantities();
    if (_p != undefined && ex_trade(global.ex_r, _qs[global.ex_q], _p)) {
        go_flash = 1;
        sfx(snd_affirmative, 0.7, 1.1, 0.05);
    } else sfx(snd_denied, 0.6);
};
