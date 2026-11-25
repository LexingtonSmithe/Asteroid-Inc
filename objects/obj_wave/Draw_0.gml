// An expanding ring (spr_shockwave wrapped round the circle), fading as it reaches its range
var _f = 1 - (r - start_r) / max(1, range - start_r);
draw_sprite_ring(spr_shockwave, 0, x, y, r, ring_w, c_white, _f * 0.5);
