// Beam sprite stretched from the tail to the head (glow and core are in the art)
var _spr = (side == "player") ? spr_beam_laser_player : spr_beam_laser_enemy;
var _tx = x - lengthdir_x(len, dir), _ty = y - lengthdir_y(len, dir);
draw_sprite_line(_spr, 0, _tx, _ty, x, y, 7, c_white, 1);
