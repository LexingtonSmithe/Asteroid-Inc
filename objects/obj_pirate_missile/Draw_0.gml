if (wait > 0) exit; // still in the launch tube
// Exhaust trail (spr_trail_soft, tinted orange), then the body
var _n = array_length(trail);
var _ex = make_colour_rgb(255, 170, 60);
for (var i = 1; i < _n; i++) {
    draw_sprite_line(spr_trail_soft, 0, trail[i - 1][0], trail[i - 1][1], trail[i][0], trail[i][1], 1.5 + i / _n * 3, _ex, i / _n * 0.6);
}
draw_sprite_ext(sprite_index, 0, x, y, image_xscale, image_yscale, image_angle, (flash > 0) ? c_white : image_blend, 1);
