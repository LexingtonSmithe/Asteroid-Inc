// All layers are sprites; edit the art to restyle the black hole.
// Sizes are in multiples of the core's diameter, so the art can be anything.
var _core = BH_CORE * power_now;
if (_core < 1) exit;
var _d = _core * 2;

// Faint edge of the pull (spr_ring_line wrapped round the range)
draw_sprite_ring(spr_ring_line, 0, x, y, BH_RANGE, 2, BH_COLOUR, 0.07 * power_now);

// Glow and swirling accretion disc (additive). Two copies of the swirl turning at different speeds.
gpu_set_blendmode(bm_add);
draw_sprite_sized(spr_bh_glow,  0, x, y, _d * 3,   _d * 3,   0,                c_white, power_now);
draw_sprite_sized(spr_bh_swirl, 0, x, y, _d * 2.6, _d * 2.6, swirl,            c_white, 0.8 * power_now);
draw_sprite_sized(spr_bh_swirl, 0, x, y, _d * 2.0, _d * 2.0, swirl * 1.6 + 60, c_white, 0.6 * power_now);
gpu_set_blendmode(bm_normal);

// The hole itself (spr_bh_core fills its sprite edge to edge = the catch radius)
draw_sprite_sized(spr_bh_core, 0, x, y, _d, _d, 0, c_white, 1);
