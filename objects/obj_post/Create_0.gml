/// Persistent post-processing, created once by game_init().
///  - Neon glow: bright parts of the game layer are blurred and added back (bloom).
///  - Scanlines: CRT-style dark rows over everything, including the HUD.
/// F5 toggles glow, F6 toggles scanlines. Falls back to a plain draw if shaders fail.

#macro BLOOM_DOWNSCALE   4     // blur works on a 1/4-size copy: cheaper and wider glow
#macro BLOOM_THRESHOLD   0.18  // 0-1: how bright a colour must be to glow

#macro BLOOM_PASSES      4     // more passes = softer, wider glow
#macro BLOOM_SPREAD      1.6   // blur sample distance multiplier: higher = wider halo
#macro VIGNETTE          0.35  // edge darkening, 0 = off
#macro SCANLINE_ROWS     360   // roughly how many scanlines span the window height
#macro SCANLINE_STRENGTH 0.28  // 0-1 darkness of each scanline

application_surface_draw_enable(false); // we draw it ourselves in Post Draw

bloom_a = -1;
bloom_b = -1;

tune_text_timer = 0; // shows the current strength briefly after a live tweak

// Room transitions (see transition_to in scr_juice)
trans_state  = "none"; // "none" | "out" (covering) | "in" (revealing)
trans_t      = 0;      // 0 = open, 1 = fully covered
trans_target = noone;

/// Where to draw the game layer this frame: window rect, nudged and slightly
/// enlarged by screen shake so the edges never show through.
shake_rect = function() {
    var _pos = application_get_position();
    var _x = _pos[0], _y = _pos[1], _w = _pos[2] - _pos[0], _h = _pos[3] - _pos[1];
    var _kick = max(abs(global.kick_x), abs(global.kick_y));
    if (global.shake > 0.05 || _kick > 0.05) {
        var _k = _w / surface_get_width(application_surface); // window px per game px
        var _m = (global.shake + _kick) * _k;                 // margin so edges never show
        _x += (random_range(-global.shake, global.shake) + global.kick_x) * _k - _m;
        _y += (random_range(-global.shake, global.shake) + global.kick_y) * _k - _m;
        _w += _m * 2;
        _h += _m * 2;
    }
    return [_x, _y, _w, _h];
};

shaders_ok = shaders_are_supported()
    && shader_is_compiled(sh_bright) && shader_is_compiled(sh_blur)
    && shader_is_compiled(sh_composite) && shader_is_compiled(sh_scanlines);
if (!shaders_ok) show_debug_message("obj_post: shaders unavailable, post-processing off");

u_threshold   = shader_get_uniform(sh_bright, "u_threshold");
u_texel       = shader_get_uniform(sh_blur, "u_texel");
u_bloom       = shader_get_sampler_index(sh_composite, "u_bloom");
u_strength    = shader_get_uniform(sh_composite, "u_bloom_strength");
u_vignette    = shader_get_uniform(sh_composite, "u_vignette");
u_period      = shader_get_uniform(sh_scanlines, "u_period");
u_sl_strength = shader_get_uniform(sh_scanlines, "u_strength");
u_time        = shader_get_uniform(sh_scanlines, "u_time");

/// (Re)creates a surface if it's missing or the wrong size. Surfaces can be lost at any time.
ensure_surface = function(_surf, _w, _h) {
    if (surface_exists(_surf)) {
        if (surface_get_width(_surf) == _w && surface_get_height(_surf) == _h) return _surf;
        surface_free(_surf);
    }
    return surface_create(_w, _h);
};
