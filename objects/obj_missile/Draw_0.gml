// Bright trail (spr_trail_soft, tinted), then the body (spr_missile)
var _n = array_length(trail);
for (var i = 1; i < _n; i++) {
    draw_sprite_line(spr_trail_soft, 0, trail[i - 1][0], trail[i - 1][1], trail[i][0], trail[i][1], 1.5 + i / _n * 3.75, image_blend, i / _n * 0.7);
}
draw_sprite_ext(spr_missile, 0, x, y, scale, scale, dir - 90, c_white, 1); // the art points up, so turn it a quarter; scale = corkscrew roll
