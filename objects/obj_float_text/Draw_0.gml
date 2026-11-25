var _a = min(1, life / (life_max * 0.4)); // hold, then fade over the last 40%
var _tw = string_width(text) * scale;
var _iw = (icon != -1) ? sprite_get_width(icon) * scale + 4 : 0;
var _x0 = x - (_tw + _iw) / 2; // centre icon + text as one unit

if (icon != -1) draw_sprite_ext(icon, 0, _x0 + _iw / 2 - 2, y, scale, scale, 0, c_white, _a);

draw_set_halign(fa_left);
draw_set_valign(fa_middle);
draw_set_alpha(_a);
draw_set_colour(c_black);
draw_text_transformed(_x0 + _iw + 1, y + 1, text, scale, scale, 0);
draw_set_colour(colour);
draw_text_transformed(_x0 + _iw, y, text, scale, scale, 0);
draw_reset();
