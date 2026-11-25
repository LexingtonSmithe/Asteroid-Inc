// Hot streak through recent positions (spr_trail_soft, tinted), then the head (spr_meteor)
var _n = array_length(trail);
gpu_set_blendmode(bm_add);
for (var i = 1; i < _n; i++) {
    var _f = i / _n;
    draw_sprite_line(spr_trail_soft, 0, trail[i - 1][0], trail[i - 1][1], trail[i][0], trail[i][1], 1 + _f * radius, METEOR_COLOUR, _f * 0.9);
}
gpu_set_blendmode(bm_normal);
draw_sprite_sized(spr_meteor, 0, x, y, radius * 2, radius * 2, 0, c_white, 1);
