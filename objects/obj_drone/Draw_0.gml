if (rebuild > 0) {
    // Offline: faint outline that fills back in as it rebuilds
    var _p = 1 - rebuild / max(1, global.stats.drone_rebuild * game_get_speed(gamespeed_fps));
    draw_sprite_fill(sprite_index, x, y, 1, 1, image_angle, c_dkgray, 0.5, _p);
    exit;
}
var _col = (flash > 0) ? c_red : make_colour_rgb(255, 200, 90);
draw_sprite_fill(sprite_index, x, y, 1, 1, image_angle, _col, 1, hits / max_hits);
