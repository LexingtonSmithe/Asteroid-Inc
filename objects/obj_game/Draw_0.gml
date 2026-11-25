// Outline cache warm-up (scr_ui): a few per frame until every asteroid scale is built
if (!global.outline_cache_off && !(variable_global_exists("outline_warm_done") && global.outline_warm_done)) {
    var _wn = global.perf.n[$ "outline_builds"] ?? 0, _wt = global.perf.us[$ "outline_build"] ?? 0;
    global.outline_warm_done = outline_warm_step();
    global.perf.n[$ "outline_builds"] = _wn; global.perf.us[$ "outline_build"] = _wt; // warm-up isn't a mid-day hitch
}
// The launch reticle is now the mouse cursor itself (spr_cursor, drawn by obj_post),
// tinted lime/red while playing to show whether a ship can launch.

pirate_drain_draw(); // Pirate System: the flagship's charge-drain beam before the final wave (scr_pirates)

// The singularity ending: a black hole ENDING_HOLE x the usual size opens on the station (same art as
// obj_blackhole: glow, two swirls, core), over everything at this depth
if (singularity) {
    var _fps = game_get_speed(gamespeed_fps);
    var _open = min(1, ending_t / _fps / ENDING_GROW);
    var _e = 1 - power(1 - _open, 3); // eases out as it opens
    var _dd = BH_CORE * ENDING_HOLE * _e * 2;
    if (_dd >= 1) {
        gpu_set_blendmode(bm_add);
        draw_sprite_sized(spr_bh_glow,  0, STATION_X, STATION_Y, _dd * 3,   _dd * 3,   0,                         c_white, _e);
        draw_sprite_sized(spr_bh_swirl, 0, STATION_X, STATION_Y, _dd * 2.6, _dd * 2.6, ending_swirl,              c_white, 0.8 * _e);
        draw_sprite_sized(spr_bh_swirl, 0, STATION_X, STATION_Y, _dd * 2.0, _dd * 2.0, ending_swirl * 1.6 + 60,   c_white, 0.6 * _e);
        gpu_set_blendmode(bm_normal);
        draw_sprite_sized(spr_bh_core, 0, STATION_X, STATION_Y, _dd, _dd, 0, c_white, 1);
    }
}

// Day-one tutorial markers on the rock and the loot (scr_tutorial)
tut_day_draw_world();
