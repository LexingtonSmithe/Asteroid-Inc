if (rebuild > 0) exit; // inside the station
var _col = (flash > 0) ? c_red : make_colour_rgb(110, 255, 230);
draw_sprite_fill(sprite_index, x, y, 1, 1, image_angle, _col, 1, hp / max_hp);
