// All layers are sprites (spr_wh_*: pale copies of the black hole art); edit the art to restyle it.
// Sizes are in multiples of the core's diameter, so the art can be anything.
var _core = WH_CORE * power_now;
if (_core < 1) exit;
var _d = _core * 2;

// Edge of the implosion's reach: faint while it's open, bright as it caves in
draw_sprite_ring(spr_ring_line, 0, x, y, WH_EAT, 2, WH_COLOUR, imploding ? 0.45 : 0.06 * power_now);

// Glow and two counter-turning swirls (additive), then the bright core
// WH_BRIGHT dims the additive layers (less light = less bloom); WH_CORE_BRIGHT the core
gpu_set_blendmode(bm_add);
draw_sprite_sized(spr_wh_glow,  0, x, y, _d * 3,   _d * 3,   0,                c_white, power_now * WH_BRIGHT);
draw_sprite_sized(spr_wh_swirl, 0, x, y, _d * 2.6, _d * 2.6, swirl,            c_white, 0.8 * power_now * WH_BRIGHT);
draw_sprite_sized(spr_wh_swirl, 0, x, y, _d * 2.0, _d * 2.0, swirl * 1.6 + 60, c_white, 0.6 * power_now * WH_BRIGHT);
draw_sprite_sized(spr_wh_core,  0, x, y, _d, _d, 0, c_white, WH_CORE_BRIGHT);
gpu_set_blendmode(bm_normal);
