/// Post Draw: draw the game layer to the window, with neon bloom and screen shake.
var _r = shake_rect(); // [x, y, w, h] including screen shake

gpu_set_blendenable(false);

if (!shaders_ok || !global.settings.glow) {
    draw_surface_stretched(application_surface, _r[0], _r[1], _r[2], _r[3]);
    gpu_set_blendenable(true);
    exit;
}

var _bw = max(1, surface_get_width(application_surface) div BLOOM_DOWNSCALE);
var _bh = max(1, surface_get_height(application_surface) div BLOOM_DOWNSCALE);
bloom_a = ensure_surface(bloom_a, _bw, _bh);
bloom_b = ensure_surface(bloom_b, _bw, _bh);

gpu_set_texfilter(true);

// 1. Bright pass into a small surface
surface_set_target(bloom_a);
shader_set(sh_bright);
shader_set_uniform_f(u_threshold, BLOOM_THRESHOLD);
draw_surface_stretched(application_surface, 0, 0, _bw, _bh);
shader_reset();
surface_reset_target();

// 2. Blur: horizontal into b, vertical back into a
shader_set(sh_blur);
repeat (BLOOM_PASSES) {
    surface_set_target(bloom_b);
    shader_set_uniform_f(u_texel, BLOOM_SPREAD / _bw, 0);
    draw_surface(bloom_a, 0, 0);
    surface_reset_target();

    surface_set_target(bloom_a);
    shader_set_uniform_f(u_texel, 0, BLOOM_SPREAD / _bh);
    draw_surface(bloom_b, 0, 0);
    surface_reset_target();
}
shader_reset();
gpu_set_texfilter(false); // keep the scene itself pixel-crisp

// 3. Composite scene + glow to the window
shader_set(sh_composite);
texture_set_stage(u_bloom, surface_get_texture(bloom_a));
gpu_set_tex_filter_ext(u_bloom, true);
// Solar wind: the sun already floods the screen with light, so the bloom is turned down to match
var _sun = instance_exists(obj_starfield) ? obj_starfield.sun_k : 0;
shader_set_uniform_f(u_strength, global.settings.glow_strength * lerp(1, SUN_BLOOM_MULT, _sun) + global.bloom_boost);
shader_set_uniform_f(u_vignette, VIGNETTE);
draw_surface_stretched(application_surface, _r[0], _r[1], _r[2], _r[3]);
shader_reset();

gpu_set_blendenable(true);
