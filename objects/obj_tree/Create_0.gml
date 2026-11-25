/// Upgrade tree hub. Everything here is drawn in GUI space.
game_init();
global.frozen = false;

cam_x = 0;          // pan offset
cam_y = 0;
zoom = 1;           // tree zoom (mouse wheel / Q E / + -), Home resets the view
show_all = false;   // F9 (debug): show the whole tree, undiscovered nodes greyed out
#macro TREE_ZOOM_MIN 0.4
#macro TREE_ZOOM_MAX 2.5
dragging = false;
drag_x = 0;
drag_y = 0;
hover = undefined;  // upgrade struct under the mouse
wpn_hov = -1;           // weapon picker row under the mouse (WPN.*), or -1 (scr_ui)
chart_hov = 0;          // star chart slot under the mouse: 1, 2 or 0 (scr_charts)
ex_hov = false;         // EXCHANGE button under the bank list is under the mouse (scr_exchange)
bank_rows = [];         // bank list rows as drawn: [resource, y, right edge] (Draw GUI fills it)
chart_cancel();         // a chart paid for but never flown (old save): refunded, picks back in the slots
buy_flash = 0;
buy_flash_id = "";
tree_parts = [];    // purchase burst particles (GUI space)
link_pulses = [];   // bright dots running down the links into a node just bought
// Nodes fade and grow in when they're first revealed; everything visible now starts shown
reveal = {};
for (var i = 0; i < array_length(global.upgrades); i++) {
    if (upg_visible(global.upgrades[i])) reveal[$ global.upgrades[i].id] = 1;
}
reveal_of = function(_u) { var _v = reveal[$ _u.id]; return (_v == undefined) ? 0 : ease_out_cubic(_v); };

// Tier warning: buying a new sector (or a Jump Drive) asks first (Draw GUI draws it)
#macro TIER_WARNING "Warning: By expanding your reach you raise the risk: Asteroids are sturdier, faster but also richer... you may want to purchase more upgrades before you enter this space."
confirm_u   = undefined; // the tier-raising node waiting for a yes, or undefined
confirm_hov = 0;         // button under the mouse: 1 = enter, 2 = not yet

/// Modal layout: { panel, yes, no } as [x1, y1, x2, y2].
confirm_rects = function() {
    var _gw = display_get_gui_width(), _gh = display_get_gui_height();
    var _w = min(640, _gw - 40), _h = 300;
    var _x1 = (_gw - _w) / 2, _y1 = (_gh - _h) / 2;
    var _bw = 210, _bh = 50, _by = _y1 + _h - _bh - 22, _cx = _x1 + _w / 2;
    return { panel: [_x1, _y1, _x1 + _w, _y1 + _h],
             no:  [_cx - 12 - _bw, _by, _cx - 12, _by + _bh],
             yes: [_cx + 12, _by, _cx + 12 + _bw, _by + _bh] };
};

/// Buys _u with the usual flash, burst and sound (or the "no" sound).
try_buy = function(_u) {
    if (upg_buy(_u)) {
        buy_flash = 16;
        buy_flash_id = _u.id;
        buy_fx(_u);
        sfx(snd_affirmative, 0.7);
        return true;
    }
    sfx(snd_denied, 0.6); // can't afford or maxed
    return false;
};

/// Purchase burst: particles from the node, and a pulse down each link into it.
buy_fx = function(_u) {
    var _p = node_pos(_u);
    var _col = upg_maxed(_u) ? make_colour_rgb(255, 210, 80) : make_colour_rgb(120, 255, 140);
    repeat (22) {
        var _d = random(360), _s = random_range(2, 6);
        array_push(tree_parts, { x: _p[0], y: _p[1], vx: lengthdir_x(_s, _d), vy: lengthdir_y(_s, _d),
                                 life: irandom_range(18, 32), size: irandom_range(3, 5), col: choose(_col, c_white) });
    }
    for (var j = 0; j < array_length(_u.req); j++) array_push(link_pulses, { from: _u.req[j], to: _u.id, t: 0 });
};

// Launch button rectangle (GUI space)
btn_w = 220;
btn_h = 44;

node_pos = function(_u) {
    return [display_get_gui_width() / 2 + cam_x + _u.gx * NODE_SPACING * zoom,
            display_get_gui_height() / 2 + cam_y + _u.gy * NODE_SPACING * zoom];
};

/// Zoom by _factor, keeping the tree point under (_mx, _my) fixed on screen.
zoom_at = function(_factor, _mx, _my) {
    var _new = clamp(zoom * _factor, TREE_ZOOM_MIN, TREE_ZOOM_MAX);
    var _cx = display_get_gui_width() / 2, _cy = display_get_gui_height() / 2;
    var _wx = (_mx - _cx - cam_x) / zoom; // tree-space point under the cursor
    var _wy = (_my - _cy - cam_y) / zoom;
    zoom  = _new;
    cam_x = _mx - _cx - _wx * zoom;
    cam_y = _my - _cy - _wy * zoom;
};

/// Play: pays for any survey picks first; refused (greyed button) if they can't be afforded.
launch_day = function() {
    if (transition_active()) return;
    if (!survey_commit()) { sfx(snd_denied, 0.6); return; }
    tut_tree_end(); // the tree tutorial ends with the launch (scr_tutorial)
    transition_to(rm_game);
};

over_button = function(_mx, _my) {
    var _bx = display_get_gui_width() / 2 - btn_w / 2;
    var _by = display_get_gui_height() - btn_h - 20;
    return point_in_rectangle(_mx, _my, _bx, _by, _bx + btn_w, _by + btn_h);
};

// Tree tutorial after day one: bank, buy Damage, the Asteroid Lure warning, launch (scr_tutorial)
tut_tree_init();
ctip_init(); // first sector condition survived: star charts explained (scr_tutorial)
