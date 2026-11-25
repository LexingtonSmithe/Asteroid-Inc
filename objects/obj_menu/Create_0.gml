/// Main menu + Options screen. Mouse or keyboard (Up/Down/W/S, Left/Right/A/D, Enter/Space, Esc).
quitting = false; // set as the game closes: the rest of that Step must not create anything
game_init();
global.frozen = false;

screen = "main"; // "main" | "options"
menu_anim = 0;   // 0-1 slide/fade-in when a screen appears

set_screen = function(_s) {
    screen = _s;
    menu_anim = 0;
    dragging = false;
};

// --- Main screen -------------------------------------------------------------
has_save = file_exists(SAVE_FILE);
// New Game+ appears once the singularity ending has been reached (settings, so it survives a wipe)
items    = global.settings.ngplus ? ["Continue", "New Game", "New Game+", "Options", "Exit"] : ["Continue", "New Game", "Options", "Exit"];
acts     = global.settings.ngplus ? ["continue", "new", "ngplus", "options", "exit"] : ["continue", "new", "options", "exit"];
enabled  = array_create(array_length(items), true);
enabled[0] = has_save;
selected = has_save ? 0 : 1;
confirm_new = false;     // New Game / New Game+ over an existing save needs a second click
/// Row of menu action _a ("options" etc.).
act_index = function(_a) { for (var i = 0; i < array_length(acts); i++) if (acts[i] == _a) return i; return 0; };
/// Does row _i start a new game (and so need the overwrite confirm)?
act_is_new = function(_i) { return acts[_i] == "new" || acts[_i] == "ngplus"; };

// --- Options screen ----------------------------------------------------------
// kind: "slider" (key, min, max, step), "toggle" (key), "back"
opts = [
    { label: "Sound",      kind: "slider", key: "sfx_volume",    lo: 0, hi: 1, step: 0.1 },
    { label: "Music",      kind: "slider", key: "music_volume",  lo: 0, hi: 1, step: 0.1 }, // heard live: music_update reads it every frame
    { label: "Glow",       kind: "toggle", key: "glow" },
    { label: "Glow Power", kind: "slider", key: "glow_strength", lo: 0, hi: 6, step: 0.2 },
    { label: "Scanlines",  kind: "toggle", key: "scanlines" },
    { label: "Shake",      kind: "toggle", key: "screen_shake" },
    { label: "Fullscreen", kind: "toggle", key: "fullscreen" },
    { label: "Back",       kind: "back" },
];
opt_sel  = 0;
dragging = false;        // holding the mouse on a slider

// --- Layout (sized from the current font) -----------------------------------
#macro MENU_TEXT_SCALE 1
draw_set_font(fnt_main);
btn_w = 0;
for (var i = 0; i < array_length(items); i++) btn_w = max(btn_w, string_width(items[i]));
btn_w = max(btn_w, string_width("Overwrite?")) * MENU_TEXT_SCALE + 40;
btn_h   = string_height("A") * MENU_TEXT_SCALE + 16;
btn_gap = 10;

label_w  = 0;
for (var i = 0; i < array_length(opts); i++) label_w = max(label_w, string_width(opts[i].label));
ctrl_w   = 160;          // slider / toggle area
opt_h    = 34;           // options rows are compact so they all fit
opt_gap  = 6;
row_w    = label_w + 30 + ctrl_w + 32;

spawn_timer = 0;         // decorative asteroids drifting behind the menu

item_rect = function(_i) {
    var _x = display_get_gui_width() / 2 - btn_w / 2;
    var _y = display_get_gui_height() / 2 - 20 + _i * (btn_h + btn_gap);
    return [_x, _y, _x + btn_w, _y + btn_h];
};

/// Options rows, centred vertically (a little below centre to leave room for the title).
opt_top = function() {
    var _total = array_length(opts) * (opt_h + opt_gap) - opt_gap;
    return display_get_gui_height() / 2 - _total / 2 + 24;
};

opt_rect = function(_i) {
    var _x = display_get_gui_width() / 2 - row_w / 2;
    var _y = opt_top() + _i * (opt_h + opt_gap);
    return [_x, _y, _x + row_w, _y + opt_h];
};

/// Slider/toggle area inside an options row.
ctrl_rect = function(_i) {
    var _r = opt_rect(_i);
    return [_r[2] - 16 - ctrl_w, _r[1] + 8, _r[2] - 16, _r[3] - 8];
};

move_selection = function(_dir) {
    var _n = array_length(items);
    var _i = selected;
    repeat (_n) {
        _i = (_i + _dir + _n) mod _n;
        if (enabled[_i]) { selected = _i; break; }
    }
    confirm_new = false;
};

activate = function(_i) {
    if (!enabled[_i]) return;
    sfx(snd_ui_click, 0.6, 1, 0);
    switch (acts[_i]) {
        case "continue":
            transition_to(rm_tree);
            break;
        case "new":
            if (has_save && !confirm_new) { confirm_new = true; break; }
            reset_save();
            transition_to(rm_game); // straight into day one and its tutorial (scr_tutorial)
            break;
        case "ngplus": // fresh save with NGPLUS_ORE / NGPLUS_ICE in the bank (scr_save)
            if (has_save && !confirm_new) { confirm_new = true; break; }
            new_game_plus();
            transition_to(rm_tree);
            break;
        case "options":
            set_screen("options");
            opt_sel = 0;
            break;
        case "exit":
            quitting = true;
            game_end();
            break;
    }
};

/// Sets a setting, applies and saves it, with audio feedback.
set_option = function(_o, _value) {
    var _s = global.settings;
    if (_o.kind == "slider") _value = clamp(round(_value / _o.step) * _o.step, _o.lo, _o.hi);
    if (_s[$ _o.key] == _value) return;
    _s[$ _o.key] = _value;
    settings_apply();
    settings_save();
    if (_o.key == "sfx_volume") sfx(snd_collection_returned, 0.8, 1.2, 0); // preview the new volume
};

/// Left/Right or Enter on an option row.
adjust_option = function(_i, _dir) {
    var _o = opts[_i];
    switch (_o.kind) {
        case "slider": set_option(_o, global.settings[$ _o.key] + _dir * _o.step); break;
        case "toggle": set_option(_o, !global.settings[$ _o.key]); sfx(snd_ui_click, 0.6, 1, 0); break;
        case "back":   if (_dir == 0) { set_screen("main"); selected = act_index("options"); sfx(snd_ui_click, 0.6, 0.85, 0); } break;
    }
};
