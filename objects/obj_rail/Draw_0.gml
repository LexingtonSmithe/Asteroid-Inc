// Streak of light from the oldest trail point to the head (spr_beam_rail), with a bright head (spr_rail_head)
var _n = array_length(trail);
if (_n == 0) exit;
// Trail is as wide as the hit path (the square mount's width, half when passive); its alpha
// is the slug's remaining intensity, so it visibly dims with each rock it punches through
draw_sprite_line(spr_beam_rail, 0, trail[0][0], trail[0][1], x, y, width * 2, c_white, intensity);
draw_sprite_sized(spr_rail_head, 0, x, y, width * 0.9, width * 0.9, 0, c_white, intensity);
