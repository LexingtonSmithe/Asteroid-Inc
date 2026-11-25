// Jagged bolt between each pair of points, re-jittered every frame so it crackles.
// Each kink is a stretched spr_beam_zap (cyan glow, white core: bright enough to bloom).
var _a = life / life_max;
var _n = array_length(points);
for (var i = 0; i < _n - 1; i++) {
    var _x1 = points[i][0], _y1 = points[i][1];
    var _x2 = points[i + 1][0], _y2 = points[i + 1][1];
    var _len = point_distance(_x1, _y1, _x2, _y2);
    var _dir = point_direction(_x1, _y1, _x2, _y2);
    var _segs = max(3, round(_len / 18));
    var _px = _x1, _py = _y1;
    for (var s = 1; s <= _segs; s++) {
        var _t = s / _segs;
        var _off = (s == _segs) ? 0 : random_range(-10, 10); // ends stay pinned to the targets
        var _nx = lerp(_x1, _x2, _t) + lengthdir_x(_off, _dir + 90);
        var _ny = lerp(_y1, _y2, _t) + lengthdir_y(_off, _dir + 90);
        draw_sprite_line(spr_beam_zap, 0, _px, _py, _nx, _ny, width, c_white, _a);
        _px = _nx; _py = _ny;
    }
}
