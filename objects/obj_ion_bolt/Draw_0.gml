// Warning: the path flickers faintly before it strikes (spr_beam_zap, same art as the bolt)
if (random(1) < 0.35) exit; // flicker
var _a = random_range(0.1, 0.3);
for (var i = 0; i < array_length(points) - 1; i++) {
    draw_sprite_line(spr_beam_zap, 0, points[i][0], points[i][1], points[i + 1][0], points[i + 1][1], 2, ION_COLOUR, _a);
}
for (var i = 0; i < array_length(branch) - 1; i++) { // the splinter's path to the station too
    draw_sprite_line(spr_beam_zap, 0, branch[i][0], branch[i][1], branch[i + 1][0], branch[i + 1][1], 2, ION_COLOUR, _a);
}
