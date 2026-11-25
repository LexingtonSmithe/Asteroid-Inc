// ---------------------------------------------------------------------------
// Player settings (Options menu). Stored separately from the save game, so
// starting a New Game keeps them.
// ---------------------------------------------------------------------------

#macro SETTINGS_FILE "asteroid_inc_settings.json"

function settings_default() {
    return {
        sfx_volume:    0.8,   // 0-1
        music_volume:  0.6,   // 0-1
        glow:          true,  // neon bloom
        glow_strength: 2.4,   // 0-6
        scanlines:     true,
        screen_shake:  true,
        fullscreen:    false,
        ngplus:        false, // New Game+ unlocked (reached the singularity ending on any save)
    };
}

function settings_load() {
    global.settings = settings_default();
    var _data = json_file_load(SETTINGS_FILE);
    if (!is_struct(_data)) return;
    // Copy only known keys, so old or edited files can't break anything
    var _keys = variable_struct_get_names(global.settings);
    for (var i = 0; i < array_length(_keys); i++) {
        var _k = _keys[i];
        if (variable_struct_exists(_data, _k)) global.settings[$ _k] = _data[$ _k];
    }
    global.settings.sfx_volume    = clamp(global.settings.sfx_volume, 0, 1);
    global.settings.music_volume  = clamp(global.settings.music_volume, 0, 1);
    global.settings.glow_strength = clamp(global.settings.glow_strength, 0, 6);
}

function settings_save() { json_file_save(SETTINGS_FILE, global.settings); }

/// Applies settings that need an engine call (the rest are read live).
function settings_apply() {
    if (window_get_fullscreen() != global.settings.fullscreen) window_set_fullscreen(global.settings.fullscreen);
}

// --- small JSON file helpers (shared with the save game) ---------------------
function json_file_save(_file, _value) {
    var _buf = buffer_create(256, buffer_grow, 1);
    buffer_write(_buf, buffer_string, json_stringify(_value));
    buffer_save(_buf, _file);
    buffer_delete(_buf);
}

function json_file_load(_file) {
    if (!file_exists(_file)) return undefined;
    var _buf = buffer_load(_file);
    var _str = buffer_read(_buf, buffer_string);
    buffer_delete(_buf);
    try { return json_parse(_str); }
    catch (_e) { show_debug_message("Couldn't read " + _file + ": " + string(_e)); return undefined; }
}
