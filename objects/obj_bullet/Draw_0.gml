// Tapering trail behind the bullet (spr_trail_bullet, additive), then the bullet
var _sp  = point_distance(0, 0, vx, vy);
var _len = min(_sp * 3, 70);
var _dir = point_direction(0, 0, vx, vy);
gpu_set_blendmode(bm_add);
draw_sprite_line(spr_trail_bullet, 0, x - lengthdir_x(_len, _dir), y - lengthdir_y(_len, _dir), x, y,
                 max(3, radius * 1.6), oc_active() ? OC_COLOUR : c_white, 1); // Overcharge: cyan trails
gpu_set_blendmode(bm_normal);
draw_self();
