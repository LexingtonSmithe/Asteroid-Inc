// ---------------------------------------------------------------------------
// Audio: sound effects and music.
//
// Sound effects all go through sfx() so volume, variation and voice limiting
// live in one place. Volume comes from global.settings.sfx_volume.
//
// MUSIC is made of songs, each a set of stems found automatically by name:
//   track_<n>_<layer>   in-game songs. Each day starts on the next one in a shuffled
//                       order; when a song ends it fades out and the next one plays.
//   menu_<layer>        main menu (and the tree screen if there's no tree song)
//   tree_<layer>        upgrade tree screen (optional)
//   boss_<layer>        takes over while a boss is alive; the next track follows it
// A song's stems all start together and play as written (the song's own arrangement
// does the building up). Stems can be different lengths: shorter ones repeat, on
// whole multiples of the song's shortest stem, so everything stays in time.
// A song shorter than MUSIC_MIN_SONG repeats until it's at least that long.
//
// <layer> names matter in two cases:
//   contains "riser"   if it doesn't fit the loop length, it's a one-shot played
//                      so it ends just as the boss arrives
//   no bass/drum/perc/beat/arp/lead/melody/riser in the name (pads, keys...)
//                      = a "base" layer: the only ones left (quieter) during the
//                      end-of-day recall and on the results screen
// Use tools/import_stems.py to turn files in stems/ into sound assets.
//
// One-shot stings (optional, looked up by name):
//   mus_sting_boss / mus_sting_tier / mus_sting_lose
// Volume comes from global.settings.music_volume.
// ---------------------------------------------------------------------------
// --- Sound effects -----------------------------------------------------------

#macro SFX_MAX_VOICES 4     // copies of one sound playing at once; the oldest is cut for a new one
#macro SFX_MIN_GAP_MS 35    // repeats of one sound closer than this are skipped (unless louder)
#macro SFX_CROWD      0.2   // each copy already playing turns a new one down a bit

/// Plays a sound with a little random pitch so repeats don't sound identical.
/// Stops pile-ups: when dozens of shots or breaks land together they'd clip and phase.
function sfx(_snd, _gain = 1, _pitch = 1, _pitch_var = 0.06) {
    static voices = {}; // sound name -> instances still playing
    static last   = {}; // sound name -> { t, gain } of the latest play
    var _vol = global.settings.sfx_volume;
    if (_vol <= 0) return -1;

    var _key = audio_get_name(_snd);
    var _now = current_time;
    var _l = last[$ _key];
    if (_l != undefined && _now - _l.t < SFX_MIN_GAP_MS && _gain <= _l.gain) return -1;

    var _v = voices[$ _key];
    if (_v == undefined) _v = [];
    for (var i = array_length(_v) - 1; i >= 0; i--) {
        if (!audio_is_playing(_v[i])) array_delete(_v, i, 1);
    }
    if (array_length(_v) >= SFX_MAX_VOICES) {
        audio_stop_sound(_v[0]);
        array_delete(_v, 0, 1);
    }

    var _crowd = 1 / (1 + SFX_CROWD * array_length(_v));
    var _p = _pitch * random_range(1 - _pitch_var, 1 + _pitch_var);
    var _inst = audio_play_sound(_snd, 10, false, _gain * _crowd * _vol, 0, _p);

    array_push(_v, _inst);
    voices[$ _key] = _v;
    last[$ _key] = { t: _now, gain: _gain };
    return _inst;
}

/// Asteroid break: bigger rocks are deeper and louder.
function sfx_asteroid_break(_size) {
    static pitch = [1.45, 1.2, 1.0, 0.8];
    static gain  = [0.35, 0.5, 0.7, 0.9];
    sfx(snd_asteroid_destroyed, gain[_size], pitch[_size]);
}

// --- Loops ---------------------------------------------------------------------
// Call sfx_loop(snd, gain) EVERY FRAME while a loop should be heard (station hum,
// low-hull alarm...). It fades in, and fades out by itself once nothing asks for it,
// so there is nothing to stop. loops_update() runs them (called by obj_post).

#macro LOOP_FADE 0.04   // gain per frame (about 0.4 s for a full fade at 60 fps)

function sfx_loop(_snd, _gain = 1) {
    if (!variable_global_exists("sfx_loops")) global.sfx_loops = {};
    var _key = audio_get_name(_snd);
    var _l = global.sfx_loops[$ _key];
    if (_l == undefined) {
        _l = { snd: _snd, inst: -1, gain: 0, want: 0 };
        global.sfx_loops[$ _key] = _l;
    }
    _l.want = max(_l.want, _gain);
}

function loops_update() {
    if (!variable_global_exists("sfx_loops")) return;
    var _vol  = global.settings.sfx_volume;
    var _keys = variable_struct_get_names(global.sfx_loops);
    for (var i = 0; i < array_length(_keys); i++) {
        var _l = global.sfx_loops[$ _keys[i]];
        _l.gain = (_l.want > _l.gain) ? min(_l.want, _l.gain + LOOP_FADE) : max(_l.want, _l.gain - LOOP_FADE);
        _l.want = 0; // has to be asked for again next frame
        if (_l.gain <= 0) {
            if (_l.inst != -1) { audio_stop_sound(_l.inst); _l.inst = -1; }
            continue;
        }
        if (_l.inst == -1 || !audio_is_playing(_l.inst)) _l.inst = audio_play_sound(_l.snd, 20, true, 0);
        audio_sound_gain(_l.inst, _l.gain * _vol, 0);
    }
}

// --- Music -------------------------------------------------------------------

#macro MUSIC_MIN_SONG    60     // seconds: shorter songs repeat until they're at least this long
#macro MUSIC_SONG_FADE   4      // seconds: a song fades out over its last few seconds, then the next starts
#macro MUSIC_XFADE       1      // seconds: crossfade when the scene changes (menu -> game, boss arrives...)
#macro MUSIC_LAYER_FADE  1.5    // seconds: layers dropping out for the recall / results screen
#macro MUSIC_RECALL_BASE 0.6    // time up, waiting for ships: base layers only, a bit quieter
#macro MUSIC_OVER_BASE   0.3    // day over screen
#macro MUSIC_RISER_GAIN  0.9
#macro MUSIC_DUCK_RETURN 0.9    // per second: how fast ducked music comes back up

/// Finds every song. Called once from game_init().
function music_init() {
    global.music = {
        tracks:  [],         // in-game songs, sorted by number
        menu:    undefined,  // songs for the other scenes (undefined if there isn't one)
        tree:    undefined,
        boss:    undefined,
        players: [],         // songs playing or fading: see music_play()
        bag:     [],         // shuffled track indexes still to come
        track:   -1,         // index of the current/last in-game track
        scene:   "",         // "menu" | "tree" | "game"
        boss_on: false,      // a boss was alive last frame
        riser_boss: false,   // today's boss riser has played
        duck:    1,          // multiplier, pulled down briefly by big moments
        duck_hold: 0,        // seconds before the duck starts to recover
    };
    var _m = global.music;

    // Group sounds into songs by name: track_<n>_<layer>, menu_<layer>, tree_<layer>, boss_<layer>
    var _groups = {};
    var _keys = [];
    var _ids = asset_get_ids(asset_sound);
    for (var i = 0; i < array_length(_ids); i++) {
        var _name = audio_get_name(_ids[i]);
        var _key = "", _layer = "";
        if (string_copy(_name, 1, 6) == "track_") {
            var _rest = string_delete(_name, 1, 6);
            var _us = string_pos("_", _rest);
            if (_us <= 1) continue;
            _key   = "track_" + string_copy(_rest, 1, _us - 1);
            _layer = string_delete(_rest, 1, _us);
        } else {
            var _us2 = string_pos("_", _name);
            if (_us2 <= 1) continue;
            _key = string_copy(_name, 1, _us2 - 1);
            if (_key != "menu" && _key != "tree" && _key != "boss") continue;
            _layer = string_delete(_name, 1, _us2);
        }
        if (_groups[$ _key] == undefined) { _groups[$ _key] = []; array_push(_keys, _key); }
        array_push(_groups[$ _key], { snd: _ids[i], layer: _layer });
    }

    for (var i = 0; i < array_length(_keys); i++) {
        var _song = music_build_song(_keys[i], _groups[$ _keys[i]]);
        if (_song == undefined) continue;
        switch (_keys[i]) {
            case "menu": _m.menu = _song; break;
            case "tree": _m.tree = _song; break;
            case "boss": _m.boss = _song; break;
            default:     array_push(_m.tracks, _song); break;
        }
    }
    array_sort(_m.tracks, function(_a, _b) { return _a.num - _b.num; });
    show_debug_message("Music: " + string(array_length(_m.tracks)) + " track(s), menu " + string(_m.menu != undefined)
        + ", tree " + string(_m.tree != undefined) + ", boss " + string(_m.boss != undefined));
}

/// Builds a song from its stems. Every looping stem is trimmed to a whole number of
/// the shortest stem's length, so when they repeat they stay in time.
function music_build_song(_key, _parts) {
    var _unit = infinity;
    for (var i = 0; i < array_length(_parts); i++) {
        if (music_layer_role(_parts[i].layer) != "riser") _unit = min(_unit, audio_sound_length(_parts[i].snd));
    }
    if (_unit == infinity) return undefined; // only a riser: nothing to play

    var _song = {
        key: _key, num: 0, layers: [], riser: -1, len: 0,
    };
    if (string_copy(_key, 1, 6) == "track_") _song.num = real(string_delete(_key, 1, 6));

    for (var i = 0; i < array_length(_parts); i++) {
        var _snd  = _parts[i].snd;
        var _len  = audio_sound_length(_snd);
        var _role = music_layer_role(_parts[i].layer);
        var _k    = _len / _unit;
        var _fits = abs(_k - round(_k)) < 0.02 && round(_k) >= 1;
        if (_role == "riser" && !_fits) { _song.riser = _snd; continue; } // one-shot
        var _loop = max(1, floor(_k + 0.02)) * _unit; // whole multiples of the unit
        if (_loop > _len) _loop = _len;
        array_push(_song.layers, { snd: _snd, role: _role, len: _len, loop: _loop });
        _song.len = max(_song.len, _loop);
    }
    return _song;
}

/// The sound asset with this name, or -1 if there isn't one (yet).
function music_asset(_name) {
    if (asset_get_type(_name) != asset_sound) return -1;
    return asset_get_index(_name);
}

/// What a stem is, from its layer name (see the top of this file).
function music_layer_role(_layer) {
    _layer = string_lower(_layer);
    var _has = function(_s, _words) {
        for (var i = 0; i < array_length(_words); i++) if (string_pos(_words[i], _s) > 0) return true;
        return false;
    };
    if (_has(_layer, ["riser"]))                    return "riser";
    if (_has(_layer, ["arp", "lead", "melody"]))    return "lead";
    if (_has(_layer, ["drum", "perc", "beat"]))     return "drums";
    if (_has(_layer, ["bass"]))                     return "bass";
    return "base";
}

/// The next in-game track: shuffled, never the same twice running.
function music_next_track() {
    var _m = global.music;
    var _n = array_length(_m.tracks);
    if (_n == 0) return undefined;
    if (array_length(_m.bag) == 0) {
        for (var i = 0; i < _n; i++) array_push(_m.bag, i);
        array_shuffle_ext(_m.bag);
        if (_n > 1 && _m.bag[0] == _m.track) { _m.bag[0] = _m.bag[_n - 1]; _m.bag[_n - 1] = _m.track; }
    }
    _m.track = _m.bag[0];
    array_delete(_m.bag, 0, 1);
    return _m.tracks[_m.track];
}

/// Starts a song (after _delay seconds), fading the current one out.
/// Returns the new player: { song, kind, insts, mix, gain, target, rate_in, rate_out, t, dur, delay }.
function music_play(_song, _kind, _delay = 0) {
    var _m = global.music;
    music_fade_all(MUSIC_XFADE);
    if (_song == undefined) return undefined;
    var _dur = -1; // endless
    if (_kind == "game") _dur = max(1, ceil(MUSIC_MIN_SONG / _song.len)) * _song.len;
    var _gain = 0;
    if (_delay > 0) _gain = 1; // after a fade-out gap, start at full (the song has its own intro)
    var _p = {
        song: _song, kind: _kind, insts: [], mix: [],
        gain: _gain, target: 1,
        rate_in: 1 / MUSIC_XFADE, rate_out: 1 / MUSIC_XFADE,
        t: 0, dur: _dur, delay: _delay, ending: false,
    };
    for (var i = 0; i < array_length(_song.layers); i++) { array_push(_p.insts, -1); array_push(_p.mix, 1); }
    array_push(_m.players, _p);
    if (_delay <= 0) music_start_player(_p);
    return _p;
}

/// Starts all of a player's stems on the same frame.
function music_start_player(_p) {
    var _layers = _p.song.layers;
    for (var i = 0; i < array_length(_layers); i++) {
        var _l = _layers[i];
        var _inst = audio_play_sound(_l.snd, 100, true, 0);
        if (_l.loop < _l.len - 0.01) audio_sound_loop_end(_inst, _l.loop);
        _p.insts[i] = _inst;
    }
}

/// Fades out everything playing, over _secs.
function music_fade_all(_secs) {
    var _pl = global.music.players;
    for (var i = 0; i < array_length(_pl); i++) {
        _pl[i].target = 0;
        _pl[i].rate_out = 1 / _secs;
    }
}

/// The player that's playing (not fading out), or undefined.
function music_current() {
    var _pl = global.music.players;
    for (var i = array_length(_pl) - 1; i >= 0; i--) if (_pl[i].target > 0) return _pl[i];
    return undefined;
}

/// Briefly turns the music down (0-1) for a big moment, holding it for _frames.
function music_duck(_amount, _frames) {
    if (!variable_global_exists("music")) return;
    global.music.duck = min(global.music.duck, _amount);
    global.music.duck_hold = max(global.music.duck_hold, _frames / game_get_speed(gamespeed_fps));
}

/// Plays a one-shot music sting if it exists, ducking the music under it.
function music_sting(_name, _gain = 1) {
    var _snd = music_asset(_name);
    if (_snd == -1 || global.settings.music_volume <= 0) return;
    audio_play_sound(_snd, 90, false, _gain * global.settings.music_volume);
    music_duck(0.35, round(audio_sound_length(_snd) * game_get_speed(gamespeed_fps)));
}

/// Decides what should be playing: called every frame by music_update().
function music_direct() {
    var _m = global.music;
    var _cur = music_current();

    var _scene = "menu";
    if (room == rm_game) _scene = "game";
    else if (room == rm_tree) _scene = "tree";
    var _scene_changed = (_scene != _m.scene);
    _m.scene = _scene;

    if (_scene != "game") {
        _m.boss_on = false;
        var _want = (_scene == "tree" && _m.tree != undefined) ? _m.tree : _m.menu;
        if (_cur == undefined || _cur.song != _want) music_play(_want, "menu");
        return;
    }

    // In game
    if (_scene_changed) {
        _m.riser_boss = false;
        _m.boss_on = false;
        music_play(music_next_track(), "game");
        return;
    }
    if (!instance_exists(obj_game)) return;

    var _boss = false;
    with (obj_asteroid) if (is_boss && !dead) _boss = true;
    if (_boss != _m.boss_on) {
        _m.boss_on = _boss;
        if (_m.boss != undefined) {
            if (_boss) music_play(_m.boss, "boss");
            else music_play(music_next_track(), "game"); // boss beaten (or the day ended): on to the next track
            return;
        }
    }

    // Song finished: fade out its last few seconds, then the next one starts
    if (_cur != undefined && _cur.kind == "game" && !_cur.ending && _cur.dur > 0 && _cur.t >= _cur.dur - MUSIC_SONG_FADE) {
        var _next = music_next_track();
        music_fade_all(MUSIC_SONG_FADE);
        _cur.ending = true;
        music_play(_next, "game", MUSIC_SONG_FADE);
        // music_play fades everything at the crossfade rate: restore the slow song-end fade
        _cur.rate_out = 1 / MUSIC_SONG_FADE;
        _cur.target = 0;
    }

    // Recall and results screen: only the base layers carry on, quieter
    _cur = music_current();
    if (_cur != undefined && _cur.kind != "menu") {
        var _state = obj_game.state;
        var _base = 1, _rest = 1;
        if (_state == "recalling") { _base = MUSIC_RECALL_BASE; _rest = (_cur.kind == "boss") ? MUSIC_RECALL_BASE : 0; }
        else if (_state == "over") { _base = MUSIC_OVER_BASE; _rest = 0; }
        _cur.layer_target = [_base, _rest];
    }

    // Boss riser: starts so it ends as the boss arrives (only if the day will last that long)
    if (_cur != undefined && _cur.kind == "game" && _cur.song.riser != -1 && !_m.riser_boss && obj_game.state == "playing") {
        var _fps = game_get_speed(gamespeed_fps);
        var _elapsed = obj_game.day_elapsed / _fps;
        var _start = boss_time() - audio_sound_length(_cur.song.riser);
        var _due = !obj_game.boss_spawned && !chart_no_boss(obj_game.chart) && _elapsed + obj_game.day_timer / _fps >= boss_time(); // first boss of the day
        if (_due && _elapsed >= _start && _elapsed < _start + 0.5) {
            audio_play_sound(_cur.song.riser, 95, false, MUSIC_RISER_GAIN * global.settings.music_volume);
            _m.riser_boss = true;
        }
    }
}

/// Runs the music every frame (called from obj_post's Step, in every room).
function music_update() {
    if (!variable_global_exists("music")) return;
    var _m = global.music;
    var _dt = min(delta_time / 1000000, 0.1); // real seconds, so lag doesn't drift song timing much

    music_direct();

    if (_m.duck_hold > 0) _m.duck_hold -= _dt;
    else _m.duck = min(1, _m.duck + MUSIC_DUCK_RETURN * _dt);
    var _vol = global.settings.music_volume * _m.duck;

    var _pl = _m.players;
    for (var i = array_length(_pl) - 1; i >= 0; i--) {
        var _p = _pl[i];
        if (_p.delay > 0) {
            _p.delay -= _dt;
            if (_p.delay > 0) continue;
            music_start_player(_p);
        }
        _p.t += _dt;
        if (_p.target > _p.gain) _p.gain = min(_p.target, _p.gain + _p.rate_in * _dt);
        else _p.gain = max(_p.target, _p.gain - _p.rate_out * _dt);

        if (_p.gain <= 0 && _p.target <= 0) {
            for (var j = 0; j < array_length(_p.insts); j++) if (_p.insts[j] != -1) audio_stop_sound(_p.insts[j]);
            array_delete(_pl, i, 1);
            continue;
        }

        var _lt = variable_struct_exists(_p, "layer_target") ? _p.layer_target : [1, 1];
        var _layers = _p.song.layers;
        for (var j = 0; j < array_length(_layers); j++) {
            var _want = (_layers[j].role == "base") ? _lt[0] : _lt[1];
            if (_want > _p.mix[j]) _p.mix[j] = min(_want, _p.mix[j] + _dt / MUSIC_LAYER_FADE);
            else _p.mix[j] = max(_want, _p.mix[j] - _dt / MUSIC_LAYER_FADE);
            if (_p.insts[j] != -1) audio_sound_gain(_p.insts[j], _p.gain * _p.mix[j] * _vol, 0);
        }
    }
}
