// ---------------------------------------------------------------------------
// Drawing helpers shared by the HUD, the upgrade tree and in-world objects.
// UI rule: prefer icons, bars and numbers over words.
// Style rule: chunky and solid. No 1px lines anywhere: outlines use draw_frame,
// circles use draw_ring, lines use draw_line_width at UI_LINE or thicker.
// ---------------------------------------------------------------------------

#macro CURSOR_SCALE 0.65 // cursor sprite size on screen (before the day zoom shrinks it further)
#macro UI_LINE 3   // standard border / line thickness (GUI units, also used in world px)

/// Solid border drawn inside the rectangle, _t thick (replaces draw_rectangle(..., true)).
function draw_frame(_x1, _y1, _x2, _y2, _t = UI_LINE) {
    _t = max(1, min(_t, (_x2 - _x1) / 2, (_y2 - _y1) / 2));
    draw_rectangle(_x1, _y1, _x2, _y1 + _t - 1, false);
    draw_rectangle(_x1, _y2 - _t + 1, _x2, _y2, false);
    draw_rectangle(_x1, _y1, _x1 + _t - 1, _y2, false);
    draw_rectangle(_x2 - _t + 1, _y1, _x2, _y2, false);
}

/// Solid ring centred on radius _r, _t thick (replaces draw_circle(..., true)).
/// Uses the current draw colour and alpha.
function draw_ring(_x, _y, _r, _t = UI_LINE) {
    var _ri = max(0, _r - _t / 2), _ro = _r + _t / 2;
    var _n = clamp(round(_ro / 3), 16, 64);
    draw_primitive_begin(pr_trianglestrip);
    for (var i = 0; i <= _n; i++) {
        var _a = 360 * i / _n;
        draw_vertex(_x + lengthdir_x(_ro, _a), _y + lengthdir_y(_ro, _a));
        draw_vertex(_x + lengthdir_x(_ri, _a), _y + lengthdir_y(_ri, _a));
    }
    draw_primitive_end();
}

/// Plain bar, no text.
function draw_bar(_x, _y, _w, _h, _frac, _col) {
    _frac = clamp(_frac, 0, 1);
    draw_set_alpha(0.6);
    draw_set_colour(c_black);
    draw_rectangle(_x, _y, _x + _w, _y + _h, false);
    draw_set_alpha(1);
    draw_set_colour(_col);
    if (_frac > 0) draw_rectangle(_x, _y, _x + _w * _frac, _y + _h, false);
    draw_set_colour(c_white);
    draw_frame(_x, _y, _x + _w, _y + _h);
}

/// Resource icon followed by a number. Returns the x just past the text.
function draw_res_amount(_x, _y, _r, _text, _scale = 1.5) {
    var _icon = 8 * _scale;
    draw_sprite_ext(res_sprite(_r), 0, _x + _icon / 2, _y, _scale, _scale, 0, c_white, 1);
    draw_set_valign(fa_middle);
    draw_set_halign(fa_left);
    draw_set_colour(res_colour(_r));
    draw_text_transformed(_x + _icon + 6, _y, _text, _scale * 0.8, _scale * 0.8, 0);
    var _end = _x + _icon + 6 + string_width(_text) * _scale * 0.8;
    draw_reset();
    return _end;
}

/// Vertical list of icon + number. Shows ore always, other resources once non-zero.
/// Materials first, then the star chart tokens under a "STAR CHARTS" heading.
/// Returns the rows drawn as [resource, centre y, right edge x] (for hover tooltips).
function draw_resource_list(_x, _y, _amounts) {
    static mats   = [RES.ORE, RES.ICE, RES.CRYSTAL, RES.PLATINUM, RES.CORE, RES.HAT];
    static tokens = [RES.SURVEY, RES.SURVEY2, RES.SURVEY3, RES.COIN, RES.BOX];
    var _rows = [];
    for (var i = 0; i < array_length(mats); i++) {
        var r = mats[i];
        if (r != RES.ORE && _amounts[r] <= 0) continue;
        array_push(_rows, [r, _y, draw_res_amount(_x, _y, r, string(floor(_amounts[r])))]);
        _y += 24;
    }
    var _head = false;
    for (var i = 0; i < array_length(tokens); i++) {
        var r = tokens[i];
        if (_amounts[r] <= 0) continue;
        if (!_head) {
            _head = true;
            _y += 4;
            draw_set_colour(make_colour_rgb(150, 170, 200));
            draw_set_valign(fa_middle);
            draw_text_transformed(_x, _y, "STAR CHARTS", 0.7, 0.7, 0);
            draw_reset();
            _y += 22;
        }
        array_push(_rows, [r, _y, draw_res_amount(_x, _y, r, string(floor(_amounts[r])))]);
        _y += 24;
    }
    return _rows;
}

/// Bottom edge (GUI y) of draw_resource_list at _y with these amounts, without drawing it.
function resource_list_bottom(_y, _amounts) {
    static mats   = [RES.ORE, RES.ICE, RES.CRYSTAL, RES.PLATINUM, RES.CORE, RES.HAT];
    static tokens = [RES.SURVEY, RES.SURVEY2, RES.SURVEY3, RES.COIN, RES.BOX];
    for (var i = 0; i < array_length(mats); i++) if (mats[i] == RES.ORE || _amounts[mats[i]] > 0) _y += 24;
    var _head = false;
    for (var i = 0; i < array_length(tokens); i++) {
        if (_amounts[tokens[i]] <= 0) continue;
        if (!_head) { _head = true; _y += 26; }
        _y += 24;
    }
    return _y - 12; // _y is now one row past the last; rows are 24 tall, centred
}

// --- Boxes that unfurl -------------------------------------------------------------
// Panels, buttons and tooltips grow out of the thing they belong to: a thin bar sweeps out
// sideways from an anchor point, then drops open (with a little overshoot). Whatever's
// drawn between clip_begin and clip_end only shows inside the box as it opens.
#macro UNFURL_FRAMES 16   // frames for a panel to open fully (tooltips use TIP_FRAMES)

function ease_out_back(_t) { _t = clamp(_t, 0, 1) - 1; return 1 + 2.70158 * _t * _t * _t + 1.70158 * _t * _t; }

/// The box [x1, y1, x2, y2] at progress _t (0-1) of unfurling from (_ax, _ay) into its final rect.
function unfurl_rect(_ax, _ay, _x1, _y1, _x2, _y2, _t) {
    var _ex = ease_out_cubic(_t / 0.55);         // sideways first...
    var _ey = ease_out_back((_t - 0.3) / 0.7);   // ...then it drops open
    var _l = lerp(_ax, _x1, _ex), _r = lerp(_ax, _x2, _ex);
    var _u = lerp(_ay, _y1, _ey), _d = lerp(_ay, _y2, _ey);
    if (_d - _u < 8) { var _m = (_u + _d) / 2; _u = _m - 4; _d = _m + 4; } // the bar has some body
    return [_l, _u, _r, _d];
}

/// Everything drawn until clip_end() lands on a GUI-sized surface, and only the part inside
/// _rect (and the final rect _final) is shown. Does nothing once the box covers _final.
function clip_begin(_rect, _final) {
    if (!variable_global_exists("clip_surf")) { global.clip_surf = -1; global.clip_on = false; }
    global.clip_rect  = _rect;
    global.clip_final = _final;
    global.clip_on = !(_rect[0] <= _final[0] && _rect[1] <= _final[1] && _rect[2] >= _final[2] && _rect[3] >= _final[3]);
    if (!global.clip_on) return;
    var _gw = display_get_gui_width(), _gh = display_get_gui_height();
    if (!surface_exists(global.clip_surf) || surface_get_width(global.clip_surf) != _gw || surface_get_height(global.clip_surf) != _gh) {
        if (surface_exists(global.clip_surf)) surface_free(global.clip_surf);
        global.clip_surf = surface_create(_gw, _gh);
    }
    surface_set_target(global.clip_surf);
    draw_clear_alpha(c_black, 0);
}

function clip_end() {
    if (!variable_global_exists("clip_on") || !global.clip_on) return;
    global.clip_on = false;
    surface_reset_target();
    draw_reset();
    var _r = global.clip_rect, _f = global.clip_final;
    var _l = max(_r[0], _f[0]), _u = max(_r[1], _f[1]);
    var _w = min(_r[2], _f[2]) - _l, _h = min(_r[3], _f[3]) - _u;
    if (_w > 0 && _h > 0) draw_surface_part(global.clip_surf, _l, _u, _w, _h, _l, _u);
}

/// A HUD panel unfurling from (_ax, _ay) at progress _t, then starts clipping its contents.
/// Returns false before it has started: skip the contents (no clip_end needed then).
function panel_unfurl(_t, _ax, _ay, _x1, _y1, _x2, _y2, _edge = HUD_EDGE, _alpha = 0.55, _frame = true) {
    if (_t <= 0) return false;
    var _r = unfurl_rect(_ax, _ay, _x1, _y1, _x2, _y2, _t);
    draw_panel(_r[0], _r[1], _r[2], _r[3], _edge, _alpha, _frame);
    clip_begin(_r, [_x1, _y1, _x2, _y2]);
    return true;
}

// Tooltips use the same unfurl, keyed by what's hovered. Usage:
//   tip_open(key, anchor_x, anchor_y, x1, y1, x2, y2);  // box + frame, starts the content
//   ...draw the content at its final position...
//   tip_close();                                        // shows the content inside the box
// The key says which thing is hovered: a new key (or a gap in hovering) replays the unfurl.
#macro TIP_FRAMES 12   // frames to open fully

function tip_open(_key, _ax, _ay, _x1, _y1, _x2, _y2) {
    if (!variable_global_exists("tip_key")) { global.tip_key = ""; global.tip_t = 0; global.tip_seen = 0; }
    if (_key != global.tip_key || current_time - global.tip_seen > 80) { global.tip_key = _key; global.tip_t = 0; }
    global.tip_seen = current_time;
    global.tip_t = min(1, global.tip_t + 1 / TIP_FRAMES);
    var _ur = unfurl_rect(_ax, _ay, _x1, _y1, _x2, _y2, global.tip_t);
    var _l = _ur[0], _u = _ur[1], _r = _ur[2], _d = _ur[3];
    draw_set_alpha(0.9);
    draw_set_colour(make_colour_rgb(20, 22, 30));
    draw_rectangle(_l, _u, _r, _d, false);
    draw_set_alpha(1);
    draw_set_colour(c_white);
    draw_frame(_l, _u, _r, _d);
    draw_reset();
    clip_begin(_ur, [_x1, _y1, _x2, _y2]);
}

function tip_close() { clip_end(); }

/// Small tooltip box: a coloured title and a line (or a few) of text, near the mouse.
/// It unfurls from (_ax, _ay), the thing it describes (the mouse if not given).
function draw_tip(_mx, _my, _title, _tcol, _desc, _ax = undefined, _ay = undefined) {
    _ax ??= _mx;
    _ay ??= _my;
    var _lh = string_height("A") + 4;
    var _wrap = 300;
    var _dh = string_height_ext(_desc, _lh, _wrap);
    var _tw = max(string_width(_title), min(string_width(_desc), _wrap)) + 16;
    var _th = _lh + _dh + 10;
    var _tx = max(4, min(_mx + 18, display_get_gui_width() - _tw - 4));
    var _ty = max(4, min(_my + 18, display_get_gui_height() - _th - 4));
    tip_open("tip:" + _title, _ax, _ay, _tx, _ty, _tx + _tw, _ty + _th);
    draw_set_colour(_tcol);
    draw_text(_tx + 8, _ty + 5, _title);
    draw_set_colour(c_white);
    draw_text_ext(_tx + 8, _ty + 5 + _lh, _desc, _lh, _wrap);
    draw_reset();
    tip_close();
}

/// Horizontal row of icon + "+n" for non-zero amounts, centred on _cx.
/// Compact HUD numbers: 950, 1.2k, 14.5k, 145k, 1.2m, 3.4b (one decimal under 100, trailing .0 dropped).
function num_compact(_v) {
    _v = max(0, round(_v));
    if (_v < 1000) return string(_v);
    static _u = ["k", "m", "b", "t"];
    var _i = -1;
    while (_v >= 1000 && _i < array_length(_u) - 1) { _v /= 1000; _i++; }
    var _s = (_v < 100) ? string_format(floor(_v * 10) / 10, 1, 1) : string(floor(_v));
    if (string_copy(_s, string_length(_s) - 1, 2) == ".0") _s = string_copy(_s, 1, string_length(_s) - 2);
    return _s + _u[_i];
}

/// Big numbers shortened so they fit: 9999, then 12.3K, 4.56M, 1.2B.
function num_short(_v) {
    _v = floor(_v);
    if (_v < 10000) return string(_v);
    static _units = ["K", "M", "B", "T"];
    var _i = -1;
    while (_v >= 1000 && _i < array_length(_units) - 1) { _v /= 1000; _i++; }
    var _dp = (_v < 10) ? 2 : ((_v < 100) ? 1 : 0);
    var _s = string_format(_v, 1, _dp);
    // drop trailing zeros ("12.0K" -> "12K")
    if (_dp > 0) {
        while (string_char_at(_s, string_length(_s)) == "0") _s = string_delete(_s, string_length(_s), 1);
        if (string_char_at(_s, string_length(_s)) == ".") _s = string_delete(_s, string_length(_s), 1);
    }
    return _s + _units[_i];
}

/// Centred row(s) of icon + amount. Wraps onto extra rows when wider than _max_w;
/// _mid = true centres the block of rows on _y, otherwise rows run down from _y.
/// How many rows draw_resource_row will wrap onto with the same arguments (0 if nothing to show).
function resource_row_lines(_amounts, _prefix = "+", _max_w = 360, _scale = 1.5) {
    var _k = _scale / 1.5, _lines = 0, _wid = 0;
    for (var r = 0; r < RES.COUNT; r++) {
        if (_amounts[r] <= 0) continue;
        var _w = 8 * _scale + 6 + string_width(_prefix + num_short(_amounts[r])) * _scale * 0.8;
        if (_lines == 0) { _lines = 1; _wid = _w; continue; }
        if (_wid + 24 * _k + _w > _max_w) { _lines++; _wid = _w; } else _wid += 24 * _k + _w;
    }
    return _lines;
}

function draw_resource_row(_cx, _y, _amounts, _prefix = "+", _max_w = 360, _mid = false, _scale = 1.5) {
    var _k = _scale / 1.5; // spacing scales with the icons
    var _rows = [[]], _widths = [0];
    for (var r = 0; r < RES.COUNT; r++) {
        if (_amounts[r] <= 0) continue;
        var _t = _prefix + num_short(_amounts[r]);
        var _w = 8 * _scale + 6 + string_width(_t) * _scale * 0.8; // matches draw_res_amount
        var _n = array_length(_rows) - 1;
        var _gap = (array_length(_rows[_n]) > 0) ? 24 * _k : 0;
        if (_widths[_n] + _gap + _w > _max_w && array_length(_rows[_n]) > 0) {
            array_push(_rows, []); array_push(_widths, 0);
            _n++; _gap = 0;
        }
        array_push(_rows[_n], [r, _t]);
        _widths[_n] += _gap + _w;
    }
    var _lh = 30 * _k;
    var _y0 = _mid ? _y - (array_length(_rows) - 1) * _lh / 2 : _y;
    for (var j = 0; j < array_length(_rows); j++) {
        var _x = _cx - _widths[j] / 2;
        var _row = _rows[j];
        for (var i = 0; i < array_length(_row); i++) {
            _x = draw_res_amount(_x, _y0 + j * _lh, _row[i][0], _row[i][1], _scale) + 24 * _k;
        }
    }
}

/// Two-frame "fill" sprites: frame 1 (fill) is drawn from the sprite's bottom edge
/// up to _frac of its height, then frame 0 (outline) on top. Rotates with _ang.
/// Sprites with a single frame are simply drawn whole.
/// _thicken (world px) redraws the outline around itself to make it bolder, so it
/// stays visible at small scales and feeds the neon glow. 0 = art as drawn.
function draw_sprite_fill(_spr, _x, _y, _xs, _ys, _ang, _col, _alpha, _frac, _thicken = OUTLINE_THICKEN) {
    if (sprite_get_number(_spr) >= 2) {
        _frac = clamp(_frac, 0, 1);
        var _w  = sprite_get_width(_spr);
        var _h  = sprite_get_height(_spr);
        var _ph = round(_h * _frac);
        if (_ph > 0) {
            var _top = _h - _ph;
            // Offset of the part's top-left corner from the origin, rotated into world space
            var _dx = -sprite_get_xoffset(_spr) * _xs;
            var _dy = (_top - sprite_get_yoffset(_spr)) * _ys;
            var _c = dcos(_ang), _s = dsin(_ang);
            var _px = _x + _dx * _c + _dy * _s;
            var _py = _y - _dx * _s + _dy * _c;
            if (_ph >= _h) draw_sprite_ext(_spr, 1, _x, _y, _xs, _ys, _ang, _col, _alpha); // full health: a plain draw
            else draw_sprite_general(_spr, 1, 0, _top, _w, _ph, _px, _py, _xs, _ys, _ang, _col, _col, _col, _col, _alpha);
        }
    }
    // Bold outline: 8 offset copies of the outline frame plus the original. Baked once per
    // sprite / scale / thickness into a cached sprite (outline_cached), so it's 1 draw, not 9.
    if (_thicken > 0) {
        var _sc = max(0.25, round((abs(_xs) + abs(_ys)) * 2) / 4); // average scale, in 0.25 steps
        var _o  = global.outline_cache_off ? -1 : outline_cached(_spr, _sc, _thicken); // F1 (debug) compares with the cache off
        if (_o != -1) {
            draw_sprite_ext(_o, 0, _x, _y, _xs / _sc, _ys / _sc, _ang, _col, _alpha);
            return;
        }
        for (var _a = 0; _a < 360; _a += 45) { // no cache (surface failed): draw the copies
            draw_sprite_ext(_spr, 0, _x + lengthdir_x(_thicken, _a), _y + lengthdir_y(_thicken, _a), _xs, _ys, _ang, _col, _alpha);
        }
    }
    draw_sprite_ext(_spr, 0, _x, _y, _xs, _ys, _ang, _col, _alpha);
}

/// Sprite of _spr's outline frame drawn at scale _sc and thickened by _thick px (8 offset
/// copies + the original), made once and reused. Built from the art at runtime, so editing
/// the sprite still changes it. Returns -1 if it can't be made right now.
function outline_cached(_spr, _sc, _thick) {
    if (!variable_global_exists("outline_cache")) global.outline_cache = {};
    var _key = string(_spr) + ":" + string(_sc) + ":" + string(_thick);
    var _hit = global.outline_cache[$ _key];
    if (_hit != undefined) return _hit;
    var _pt = perf_t();
    var _pad = ceil(_thick) + 2;
    var _w = ceil(sprite_get_width(_spr) * _sc) + _pad * 2;
    var _h = ceil(sprite_get_height(_spr) * _sc) + _pad * 2;
    var _ox = sprite_get_xoffset(_spr) * _sc + _pad, _oy = sprite_get_yoffset(_spr) * _sc + _pad;
    var _surf = surface_create(_w, _h);
    if (!surface_exists(_surf)) return -1;
    surface_set_target(_surf);
    draw_clear_alpha(c_white, 0); // transparent white: soft edges fade to white, not a dark fringe
    for (var _a = 0; _a < 360; _a += 45) draw_sprite_ext(_spr, 0, _ox + lengthdir_x(_thick, _a), _oy + lengthdir_y(_thick, _a), _sc, _sc, 0, c_white, 1);
    draw_sprite_ext(_spr, 0, _ox, _oy, _sc, _sc, 0, c_white, 1);
    surface_reset_target();
    var _new = sprite_create_from_surface(_surf, 0, 0, _w, _h, false, false, _ox, _oy);
    surface_free(_surf);
    global.outline_cache[$ _key] = _new;
    if (instance_exists(obj_game)) { perf_count("outline_builds"); perf_add("outline_build", _pt); } // mid-day builds stall the GPU
    return _new;
}

// Outline cache warm-up: every asteroid scale (0.25 steps up to OUTLINE_WARM_MAX) at the normal and the
// trait-rim thickness, built a few per frame at the start of the first day so none are built mid-fight.
#macro OUTLINE_WARM_MAX     5.5
#macro OUTLINE_WARM_PER_FRAME 6
/// Builds the next few warm-up outlines; call from a Draw event. Returns true once they're all done.
function outline_warm_step() {
    if (!variable_global_exists("outline_warm_i")) global.outline_warm_i = 0;
    var _steps = round(OUTLINE_WARM_MAX * 4);
    var _total = _steps * 2;
    repeat (OUTLINE_WARM_PER_FRAME) {
        if (global.outline_warm_i >= _total) return true;
        var _i = global.outline_warm_i;
        outline_cached(spr_asteroid, ((_i mod _steps) + 1) / 4, (_i < _steps) ? OUTLINE_THICKEN : OUTLINE_THICKEN * 2);
        global.outline_warm_i++;
    }
    return global.outline_warm_i >= _total;
}

// --- HUD pieces ---------------------------------------------------------------
#macro HUD_HULL    make_colour_rgb(235, 60, 60)
#macro HUD_SHIELD  make_colour_rgb(80, 180, 255)
#macro HUD_TIME    make_colour_rgb(255, 210, 40)
#macro HUD_EDGE    make_colour_rgb(90, 200, 255)

/// Dark translucent panel with a solid neon edge.
// Overcharge HUD lightning: while global.hud_rec is an array, every draw_panel adds its
// rectangle to it, and draw_hud_crackle() then runs bolts round them all.
#macro HUD_ZAP_COLOUR  make_colour_rgb(255, 225, 70)
#macro HUD_ZAP_BOLTS   2     // bolts per panel per frame (each flickers on about half the time)

/// _alpha: background opacity (tutorial and tip panels use TUT_PANEL_ALPHA so their text reads clearly).
function draw_panel(_x1, _y1, _x2, _y2, _edge = HUD_EDGE, _alpha = 0.55, _frame = true) {
    if (variable_global_exists("hud_rec") && is_array(global.hud_rec)) array_push(global.hud_rec, [_x1, _y1, _x2, _y2]);
    draw_set_alpha(_alpha);
    draw_set_colour(make_colour_rgb(6, 10, 22));
    draw_rectangle(_x1, _y1, _x2, _y2, false);
    if (_frame) {
        draw_set_alpha(0.8);
        draw_set_colour(_edge);
        draw_frame(_x1, _y1, _x2, _y2);
    }
    draw_reset();
}

/// Segmented bar: _frac filled, optional _trail (recently lost amount shown in white).
function draw_seg_bar(_x, _y, _w, _h, _frac, _col, _segments = 10, _trail = 0) {
    _frac  = clamp(_frac, 0, 1);
    _trail = clamp(_trail, _frac, 1);
    draw_set_alpha(0.7);
    draw_set_colour(c_black);
    draw_rectangle(_x, _y, _x + _w, _y + _h, false);
    draw_set_alpha(1);
    if (_trail > _frac) {
        draw_set_colour(c_white);
        draw_rectangle(_x + _w * _frac, _y, _x + _w * _trail, _y + _h, false);
    }
    if (_frac > 0) {
        draw_set_colour(_col);
        draw_rectangle(_x, _y, _x + _w * _frac, _y + _h, false);
        // highlight strip along the top for a bit of depth
        draw_set_colour(merge_colour(_col, c_white, 0.45));
        draw_rectangle(_x, _y, _x + _w * _frac, _y + max(1, _h * 0.25), false);
    }
    // segment notches
    draw_set_colour(c_black);
    for (var i = 1; i < _segments; i++) {
        var _sx = round(_x + _w * i / _segments);
        draw_rectangle(_sx - 1, _y, _sx, _y + _h, false); // 2-wide notch
    }
    draw_set_colour(merge_colour(_col, c_white, 0.3));
    draw_frame(_x, _y, _x + _w, _y + _h, min(UI_LINE, max(2, _h / 4)));
    draw_reset();
}

#macro HUD_TIER   make_colour_rgb(255, 80, 220)
#macro HUD_CHARGE make_colour_rgb(190, 120, 255)

/// In-game charge meter, the same size as the hull bar: a bolt icon and a bar that fills
/// with charge points. Full: Overcharge ready, pulsing and shaking hard until SPACE fires it.
/// Active: drains. _flash (0-1) brightens it when the meter fills. _jig (0-1): a small wobble
/// when regular charge comes in. _hit (0-1): a bonus charge orb just landed, so it shakes and lights up.
function draw_oc_bar(_x, _y, _flash = 0, _jig = 0, _hit = 0) {
    var _ready = global.oc_ready && !oc_active();
    // Pirate flagship's drain beam: the meter flashes green, rattles and empties (scr_pirates)
    var _drain = instance_exists(obj_game) && obj_game.pirate_phase == "drain";
    var _sx = 0, _sy = 0;
    if (_ready || _drain) { _sx = irandom_range(-3, 3); _sy = irandom_range(-2, 2); } // violent rattle
    else {
        _sy = round(sin(current_time / 30) * 1.5 * _jig);                   // regular charge: slight jiggle
        _sx += round(random_range(-3, 3) * _hit);                            // bonus orb: a sharp shake
        _sy += round(random_range(-2, 2) * _hit);
        _flash = max(_flash, _hit * 0.8);                                    // ...and it lights up
        _flash = max(_flash, _jig * 0.3);                                    // regular charge: a small flash
    }
    var _pulse = 0.5 + 0.5 * sin(current_time / 70);
    var _x1 = _x + _sx, _y1 = _y + _sy;

    var _edge = _ready ? merge_colour(OC_COLOUR, c_white, _pulse * 0.6) : (oc_active() ? OC_COLOUR : HUD_CHARGE);
    if (_drain) _edge = merge_colour(PIRATE_DRAIN_COLOUR, c_white, _pulse * 0.6);
    draw_panel(_x1, _y1, _x1 + 224, _y1 + 32, merge_colour(_edge, c_white, _flash), 0.55, false); // no outline

    // Bolt icon
    draw_set_colour(_drain ? PIRATE_DRAIN_COLOUR : (_ready || oc_active() ? OC_COLOUR : HUD_CHARGE));
    var _ix = _x1 + 16, _iy = _y1 + 16;
    draw_triangle(_ix + 2, _iy - 9, _ix - 5, _iy + 1, _ix + 1, _iy + 1, false);
    draw_triangle(_ix - 1, _iy - 1, _ix + 5, _iy - 1, _ix - 2, _iy + 9, false);
    draw_reset();

    var _bx = _x1 + 34, _by = _y1 + 8, _bw = 182, _bh = 16;
    if (oc_active()) {
        draw_seg_bar(_bx, _by, _bw, _bh, obj_game.oc_timer / obj_game.oc_frames, OC_COLOUR, 10);
    } else if (_drain) {
        draw_seg_bar(_bx, _by, _bw, _bh, global.charge / charge_needed(), merge_colour(PIRATE_DRAIN_COLOUR, c_white, _pulse * 0.7), 10);
    } else if (_ready) {
        draw_seg_bar(_bx, _by, _bw, _bh, 1, merge_colour(OC_COLOUR, c_white, _pulse * 0.7), 10);
        // "SPACE" pulses under the bar, steady (it doesn't shake with the bar, so it stays readable)
        var _ks = 1 + 0.12 * _pulse;
        draw_set_colour(merge_colour(OC_COLOUR, c_white, _pulse * 0.5));
        draw_set_alpha(0.55 + 0.45 * _pulse);
        draw_set_halign(fa_center);
        draw_set_valign(fa_top);
        draw_text_transformed(_x + 34 + _bw / 2, _y + 38, "SPACE", _ks, _ks, 0);
        draw_reset();
    } else {
        draw_seg_bar(_bx, _by, _bw, _bh, global.charge / charge_needed(), merge_colour(HUD_CHARGE, c_white, _flash), 10);
    }
    return _y + 32;
}

function draw_threat_badges(_rx, _y, _charge_flash = 0, _tier_flash = 0) {
    var _pad = 6;
    var _tt = "T" + string(global.tier);
    var _h  = string_height("A") * 0.7 + 8;
    var _tw = string_width(_tt) * 0.7 + _pad * 2;
    var _bw = 110;                 // charge meter width (the tier badge sits right-aligned above it)
    var _tx = _rx - _tw;

    draw_panel(_tx, _y, _rx, _y + _h, merge_colour(HUD_TIER, c_white, _tier_flash));
    draw_set_valign(fa_middle);
    draw_set_halign(fa_center);
    draw_set_colour(merge_colour(HUD_TIER, c_white, _tier_flash));
    draw_text_transformed(_tx + _tw / 2, _y + _h / 2 + 1, _tt, 0.7, 0.7, 0);
    draw_reset();

    // Charge meter: purple as charge points build. Ready: full, pulsing cyan, with the key
    // to press. Active: cyan, draining.
    var _by = _y + _h + 4;
    var _bx = _rx - _bw;
    if (oc_active()) {
        draw_seg_bar(_bx, _by, _bw, 9, obj_game.oc_timer / obj_game.oc_frames, OC_COLOUR, 1);
    } else if (global.oc_ready) {
        var _pulse = 0.5 + 0.5 * sin(current_time / 120);
        draw_seg_bar(_bx, _by, _bw, 9, 1, merge_colour(OC_COLOUR, c_white, _pulse * 0.5), 1);
        if (instance_exists(obj_game)) {
            draw_set_colour(OC_COLOUR);
            draw_set_alpha(0.6 + 0.4 * _pulse);
            draw_set_halign(fa_center);
            draw_text_transformed(_bx + _bw / 2, _by + 20, "SPACE", 0.6, 0.6, 0);
            draw_reset();
        }
    } else {
        draw_seg_bar(_bx, _by, _bw, 9, global.charge / charge_needed(), merge_colour(HUD_CHARGE, c_white, _charge_flash), 1);
    }
    return _by + 9;
}

function draw_icon_clock(_x, _y, _r, _col) {
    draw_set_colour(_col);
    draw_ring(_x, _y, _r - 1.5, UI_LINE);
    var _a = -current_time / 10; // sweeping hand
    draw_line_width(_x, _y, _x + lengthdir_x(_r - 4, _a), _y + lengthdir_y(_r - 4, _a), 2);
    draw_line_width(_x, _y, _x, _y - (_r - 4), 2);
    draw_reset();
}

function draw_icon_shield(_x, _y, _r, _col) {
    draw_set_colour(_col);
    draw_triangle(_x - _r, _y - _r * 0.6, _x + _r, _y - _r * 0.6, _x, _y + _r, false); // solid body
    draw_triangle(_x - _r, _y - _r * 0.6, _x + _r, _y - _r * 0.6, _x, _y - _r, false);  // solid cap
    draw_reset();
}

/// Muzzle flash (spr_muzzle_flash, pointing right from its origin): a tinted flash with a
/// smaller white-hot copy on top. _f = 1 fresh, 0 gone; _size scales it.
function draw_muzzle_flash(_x, _y, _dir, _f, _size, _col) {
    var _sc = _size * (0.6 + 0.4 * _f);
    gpu_set_blendmode(bm_add);
    draw_sprite_ext(spr_muzzle_flash, 0, _x, _y, _sc, _sc, _dir, _col, _f);
    draw_sprite_ext(spr_muzzle_flash, 0, _x, _y, _sc * 0.45, _sc * 0.45, _dir, c_white, _f);
    gpu_set_blendmode(bm_normal);
}

function draw_reset() {
    draw_set_font(fnt_main); // SDF font: stays sharp at any scale
    draw_set_colour(c_white);
    draw_set_alpha(1);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
}

/// Point at distance _t round the perimeter of rectangle _r ([x1, y1, x2, y2]), clockwise from the top left.
function rect_perimeter_point(_r, _t) {
    var _w = _r[2] - _r[0], _h = _r[3] - _r[1];
    _t = ((_t mod (2 * (_w + _h))) + 2 * (_w + _h)) mod (2 * (_w + _h));
    if (_t < _w) return [_r[0] + _t, _r[1]];
    _t -= _w;
    if (_t < _h) return [_r[2], _r[1] + _t];
    _t -= _h;
    if (_t < _w) return [_r[2] - _t, _r[3]];
    _t -= _w;
    return [_r[0], _r[3] - _t];
}

/// Crackling yellow lightning crawling along the edges of every recorded HUD panel (Overcharge).
/// Re-jittered every frame; each bolt is a chain of stretched spr_beam_spark (yellow glow, white core).
function draw_hud_crackle(_rects) {
    gpu_set_blendmode(bm_add);
    for (var i = 0; i < array_length(_rects); i++) {
        var _r = _rects[i];
        var _per = 2 * ((_r[2] - _r[0]) + (_r[3] - _r[1]));
        repeat (HUD_ZAP_BOLTS) {
            if (random(1) < 0.45) continue; // flicker
            var _t0  = random(_per);
            var _len = random_range(30, 90);
            var _segs = max(3, round(_len / 7));
            var _p = rect_perimeter_point(_r, _t0);
            var _px = _p[0], _py = _p[1];
            for (var s = 1; s <= _segs; s++) {
                var _q = rect_perimeter_point(_r, _t0 + _len * s / _segs);
                var _j = (s == _segs) ? 0 : 3.5;
                var _nx = _q[0] + random_range(-_j, _j), _ny = _q[1] + random_range(-_j, _j);
                draw_sprite_line(spr_beam_spark, 0, _px, _py, _nx, _ny, 6, c_white, random_range(0.6, 1));
                _px = _nx; _py = _ny;
            }
            // Occasional spark arcing off the panel
            if (random(1) < 0.15) {
                var _a = random(360);
                draw_sprite_line(spr_beam_spark, 0, _px, _py, _px + lengthdir_x(10, _a), _py + lengthdir_y(10, _a), 4, c_white, 0.8);
            }
        }
    }
    gpu_set_blendmode(bm_normal);
}

// --- Weapon picker (tree screen, bottom left) ------------------------------------------
// Pick the ACTIVE weapon before launch: it goes on the cursor, the rest turn passive.
// Shown once you own two or more weapons. Can't be changed mid-day.
#macro WPN_PANEL_W 230
#macro WPN_ROW_H   30

/// Owned weapons in tier order (gun, Tesla, laser, rail).
function wpn_owned_list() {
    var _l = [];
    for (var w = 0; w < WPN.COUNT; w++) if (wpn_owned(w)) array_push(_l, w);
    return _l;
}
function wpn_panel_shown() { return array_length(wpn_owned_list()) >= 2; }

/// Rectangle [x1, y1, x2, y2] for row _i (0 = top) of _n rows, stacked up from the bottom-left corner.
function wpn_row_rect(_i, _n) {
    var _x1 = 16;
    var _y2 = display_get_gui_height() - 20 - (_n - 1 - _i) * (WPN_ROW_H + 4);
    return [_x1, _y2 - WPN_ROW_H, _x1 + WPN_PANEL_W, _y2];
}

/// Weapon (WPN.*) whose row is under the mouse, or -1.
function wpn_row_at(_mx, _my) {
    if (!wpn_panel_shown()) return -1;
    var _l = wpn_owned_list(), _n = array_length(_l);
    for (var i = 0; i < _n; i++) {
        var _r = wpn_row_rect(i, _n);
        if (point_in_rectangle(_mx, _my, _r[0], _r[1], _r[2], _r[3])) return _l[i];
    }
    return -1;
}

/// The white mount shape that stands for weapon _w.
function wpn_icon(_w) {
    switch (_w) {
        case WPN.GUN:   return spr_mount_gun;
        case WPN.TESLA: return spr_mount_tesla;
        case WPN.LASER: return spr_mount_laser;
        case WPN.RAIL:  return spr_mount_rail;
    }
    return spr_mount_gun;
}

/// Draws the picker: one row per owned weapon, the active one lit up.
function wpn_draw_panel(_mx, _my) {
    if (!wpn_panel_shown()) return;
    var _l = wpn_owned_list(), _n = array_length(_l);
    var _act = wpn_active(), _hi = wpn_row_at(_mx, _my);
    var _top = wpn_row_rect(0, _n);
    draw_set_colour(make_colour_rgb(150, 170, 200));
    draw_set_valign(fa_bottom);
    draw_text_transformed(_top[0], _top[1] - 4, "ACTIVE WEAPON", 0.7, 0.7, 0);
    draw_reset();
    for (var i = 0; i < _n; i++) {
        var _w = _l[i], _r = wpn_row_rect(i, _n), _on = (_w == _act);
        var _cy = (_r[1] + _r[3]) / 2;
        var _bg = _on ? make_colour_rgb(40, 70, 55) : make_colour_rgb(18, 22, 30);
        if (_hi == _w && !_on) _bg = merge_colour(_bg, c_white, 0.1);
        draw_set_colour(_bg);
        draw_rectangle(_r[0], _r[1], _r[2], _r[3], false);
        draw_set_colour(_on ? make_colour_rgb(120, 230, 150) : c_gray);
        draw_frame(_r[0], _r[1], _r[2], _r[3]);
        // Shape icon, then the name; passive ones dimmer, like on the station
        var _spr = wpn_icon(_w), _sc = 24 / sprite_get_width(_spr); // every icon the same size
        draw_sprite_ext(_spr, 0, _r[0] + 20, _cy, _sc, _sc, 90, c_white, _on ? 1 : MOUNT_PASSIVE_ALPHA);
        draw_set_valign(fa_middle);
        draw_set_colour(_on ? c_white : c_gray);
        draw_text_transformed(_r[0] + 40, _cy, string_upper(wpn_name(_w)), 0.7, 0.7, 0);
        if (!_on) {
            draw_set_halign(fa_right);
            draw_set_colour(make_colour_rgb(110, 120, 140));
            draw_text_transformed(_r[2] - 8, _cy, "PASSIVE", 0.55, 0.55, 0);
        }
        draw_reset();
    }
}
