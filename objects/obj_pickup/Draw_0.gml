// Spawn pop: grows past full size with a little hop and a white flash, then settles
if (age < PICKUP_POP) {
    var _t   = age / PICKUP_POP;
    var _k   = (_t < 0.4) ? lerp(0.3, 1.7, _t / 0.4) : lerp(1.7, 1, (_t - 0.4) / 0.6);
    var _hop = sin(_t * pi) * 10;
    draw_sprite_ext(sprite_index, image_index, x, y - _hop, image_xscale * _k, image_yscale * _k, image_angle, image_blend, image_alpha);
    gpu_set_blendmode(bm_add);
    draw_sprite_ext(sprite_index, image_index, x, y - _hop, image_xscale * _k, image_yscale * _k, image_angle, c_white, 1 - _t);
    gpu_set_blendmode(bm_normal);
} else {
    draw_self();
}
