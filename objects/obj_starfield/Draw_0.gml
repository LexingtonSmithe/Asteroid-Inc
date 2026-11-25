var _w = room_width, _h = room_height;
// The game camera zooms out during a day; the stars shouldn't. Map star space onto the view.
var _z = view_zoom();
if (_z != 1) matrix_set(matrix_world, matrix_build(view_left(), view_top(), 0, 0, 0, 0, _z, _z, 1));
var _t = current_time / 1000;
var _cx = _w / 2, _cy = _h / 2;

// Nebulae: clusters of soft cloud textures, added on top of each other, slowly turning
// and churning. Dim enough to stay below the bloom threshold.
gpu_set_blendmode(bm_add);
var _tf = gpu_get_texfilter();
gpu_set_texfilter(true); // the 256px textures are scaled up a lot; keep them smooth
var _nn = (neb_extra_k > 0) ? array_length(nebulae) : NEBULA_COUNT; // the extras only show in an ion storm or clustered field
for (var i = 0; i < _nn; i++) {
    var _n = nebulae[i];
    var _na_k = (i < NEBULA_COUNT) ? neb_base_k : neb_extra_k; // sparse fades the usual ones out; storm / clustered fade the extras in
    if (_na_k <= 0) continue;
    var _glow = sky_flash * 0.5 + ((i == flick_neb) ? flick_glow : 0); // lightning lighting the cloud from inside
    var _nd = point_distance(_cx, _cy, _n.x, _n.y), _na = point_direction(_cx, _cy, _n.x, _n.y) + star_rot; // turns with the stars
    var _nx = _cx + lengthdir_x(_nd, _na) + par_x * 0.002 * _n.r / 100;
    var _ny = _cy + lengthdir_y(_nd, _na) + par_y * 0.002 * _n.r / 100;
    for (var j = 0; j < array_length(_n.parts); j++) {
        var _p = _n.parts[j];
        var _pa = _p.a + _t * _p.orbit + star_rot;
        var _sc = _n.r * 2 * _p.s / 256;
        var _hue = (_n.hue + _p.hue + 255) mod 255;
        if (neb_tint_k > 0) { // lean towards today's theme hue the short way round the wheel, keeping each part's own shade
            var _want = (neb_tint_hue + _p.hue * 1.5 + 255) mod 255;
            var _dh = ((_want - _hue + 382.5) mod 255) - 127.5;
            _hue = (_hue + _dh * NEB_HUE_PULL * neb_tint_k + 255) mod 255;
        }
        var _col = make_colour_hsv(_hue, 170, NEBULA_BRIGHT);
        var _px = _nx + lengthdir_x(_p.d * _n.r, _pa), _py = _ny + lengthdir_y(_p.d * _n.r, _pa);
        var _pr = _p.rot + _t * _p.spin + star_rot;
        draw_sprite_ext(cloud_tex[_p.tex], 0, _px, _py, _sc * _p.xs, _sc, _pr, _col, 0.45 * _na_k);
        if (_glow > 0.01) draw_sprite_ext(cloud_tex[_p.tex], 0, _px, _py, _sc * _p.xs, _sc, _pr, STORM_FLASH_COL, 0.25 * _glow * _na_k);
    }
}
// Stars: orbit position, parallax and twinkle. While rewinding, each leaves a short
// arc behind it (longer further out), showing the counter-clockwise turn.
// Drawn additively as soft round dots (still smoothed), so the glow isn't square.
var _streak = star_spin > 0.02;
for (var i = 0; i < array_length(stars); i++) {
    var _s = stars[i];
    var _dk = clamp((star_density - _s.keep) * 40, 0, 1); // fades in/out as the density passes it
    if (_dk <= 0) continue;
    var _L = layers[_s.layer];
    var _ang = _s.a + star_rot;
    var _ox = par_x * _L.par, _oy = par_y * _L.par;
    var _sx = _cx + lengthdir_x(_s.r, _ang) + _ox;
    var _sy = _cy + lengthdir_y(_s.r, _ang) + _oy;
    if (_sx < -4 || _sy < -4 || _sx > _w + 4 || _sy > _h + 4) continue; // outside the screen
    var _a = _L.alpha * (0.65 + 0.35 * sin(_t * _s.tw + _s.phase)) * _dk;
    if (_streak) {
        var _ang0 = _ang - star_spin * STAR_STREAK;
        draw_sprite_line(spr_trail_soft, 0, _cx + lengthdir_x(_s.r, _ang0) + _ox, _cy + lengthdir_y(_s.r, _ang0) + _oy, _sx, _sy, max(2, _L.size) * 2, _s.tint, _a);
    }
    var _ssc = (0.15 + 0.15 * _L.size) * 16 / sprite_get_width(spr_star); // ~2px across at size 1, ~4px at size 3
    draw_sprite_ext(spr_star, 0, _sx, _sy, _ssc, _ssc, 0, _s.tint, _a);
}
gpu_set_texfilter(_tf);
gpu_set_blendmode(bm_normal);

// Shooting stars (spr_shooting_star): a bright head with a fading tail (additive, so the tail fades to nothing)
gpu_set_blendmode(bm_add);
for (var i = 0; i < array_length(shooters); i++) {
    var _sh = shooters[i];
    var _f = _sh.life / _sh.life_max;
    var _tx = _sh.x - lengthdir_x(_sh.spd * 6, _sh.dir);
    var _ty = _sh.y - lengthdir_y(_sh.spd * 6, _sh.dir);
    draw_sprite_line(spr_shooting_star, 0, _tx, _ty, _sh.x, _sh.y, 6, c_white, _f);
}
gpu_set_blendmode(bm_normal);
draw_set_alpha(1);
draw_set_colour(c_white);
matrix_set(matrix_world, matrix_build_identity());

// Solar wind: the sun and its shadows (world space)
if (sun_k > 0) {
    var _z  = view_zoom();
    var _vl = view_left(), _vt = view_top(), _vw = view_w(), _vh = view_h();
    var _vx = _vl + _vw / 2, _vy = _vt + _vh / 2;
    // Sun: just past the screen edge, upwind
    var _ux = lengthdir_x(1, sun_dir), _uy = lengthdir_y(1, sun_dir);
    var _edge = min(abs(_ux) > 0.001 ? (_vw / 2) / abs(_ux) : infinity, abs(_uy) > 0.001 ? (_vh / 2) / abs(_uy) : infinity);
    var _lx = _vx + _ux * (_edge + SUN_MARGIN * _z), _ly = _vy + _uy * (_edge + SUN_MARGIN * _z);
    var _diag = point_distance(0, 0, _vw, _vh);
    // Light only (no visible sun): one soft wash centred on the hidden sun, big enough to reach the far corner
    var _reach = max(point_distance(_lx, _ly, _vl, _vt), point_distance(_lx, _ly, _vl + _vw, _vt),
                     point_distance(_lx, _ly, _vl, _vt + _vh), point_distance(_lx, _ly, _vl + _vw, _vt + _vh)) * SUN_WASH_REACH;
    var _wsc = _reach * 2 / sprite_get_width(spr_star);
    gpu_set_blendmode(bm_add);
    draw_sprite_ext(spr_star, 0, _lx, _ly, _wsc, _wsc, 0, WIND_COLOUR, SUN_WASH_ALPHA * sun_k);
    gpu_set_blendmode(bm_normal);

    // Shadow mask: black = lit, white = shadow (screen-sized surface, world mapped onto it)
    if (!surface_exists(sun_surf) || surface_get_width(sun_surf) != _w || surface_get_height(sun_surf) != _h) {
        if (surface_exists(sun_surf)) surface_free(sun_surf);
        sun_surf = surface_create(_w, _h);
    }
    surface_set_target(sun_surf);
    draw_clear(c_black);
    matrix_set(matrix_world, matrix_build(-_vl / _z, -_vt / _z, 0, 0, 0, 0, 1 / _z, 1 / _z, 1));
    var _far = _diag * 2 + SUN_MARGIN * _z * 2; // every shadow runs off the far side of the screen
    var _casters = [];
    // [x, y, radius, silhouette sprite, frame, x scale, y scale, angle]: the art is hollow, so its
    // filled silhouette goes into the shadow too (otherwise the wedge's start line shows through it)
    with (obj_asteroid) if (!dead && warp_k > 0) array_push(_casters, [x, y, radius * warp_k, sprite_index, 1, image_xscale * warp_k, image_yscale * warp_k, image_angle]);
    with (obj_enemy)     if (!dead && sprite_index >= 0) array_push(_casters, [x, y, radius, sprite_index, sprite_get_number(sprite_index) - 1, image_xscale, image_yscale, image_angle]);
    with (obj_collector) if (!dead) array_push(_casters, [x, y, sprite_width / 2, sprite_index, sprite_get_number(sprite_index) - 1, image_xscale, image_yscale, image_angle]);
    with (obj_fighter)   if (rebuild <= 0) array_push(_casters, [x, y, sprite_width / 2, sprite_index, sprite_get_number(sprite_index) - 1, 1, 1, image_angle]);
    with (obj_station)   array_push(_casters, [x, y, STATION_RADIUS, -1, 0, 1, 1, hull_angle]); // its art is an outline: an octagon is drawn instead
    var _soft = SHADOW_SOFT;
    var _core = 1 - power(1 - SHADOW_PASS, array_length(_soft)); // mask value where every soft pass overlaps
    for (var i = 0; i < array_length(_casters); i++) {
        var _cx2 = _casters[i][0], _cy2 = _casters[i][1];
        var _d = point_distance(_lx, _ly, _cx2, _cy2);
        var _back = point_direction(_cx2, _cy2, _lx, _ly); // from the caster towards the sun
        for (var k = 0; k < array_length(_soft); k++) {
            var _r = abs(_casters[i][2]) * _soft[k];
            if (_d <= _r + 1) continue;
            var _t = darccos(_r / _d); // tangent points sit this far round from the sun-facing side
            var _ax = _cx2 + lengthdir_x(_r, _back + _t), _ay = _cy2 + lengthdir_y(_r, _back + _t);
            var _bx = _cx2 + lengthdir_x(_r, _back - _t), _by = _cy2 + lengthdir_y(_r, _back - _t);
            var _da = point_direction(_lx, _ly, _ax, _ay), _db = point_direction(_lx, _ly, _bx, _by);
            draw_sprite_quad(spr_sun_shadow, 0, _ax, _ay, _bx, _by,
                _bx + lengthdir_x(_far, _db), _by + lengthdir_y(_far, _db),
                _ax + lengthdir_x(_far, _da), _ay + lengthdir_y(_far, _da), c_white, SHADOW_PASS);
        }
    }
    // Each silhouette is stamped over its own wedge at exactly the full-shadow value (replace, not
    // add), so the inside of the hollow art is one even shade, starting from the side facing the sun
    var _cv = 255 * _core;
    gpu_set_blendmode_ext(bm_one, bm_zero);
    gpu_set_alphatestenable(true);
    gpu_set_alphatestref(8); // rock fills are see-through, but still count as solid
    for (var i = 0; i < array_length(_casters); i++) {
        var _cs = _casters[i];
        if (_cs[3] >= 0) { draw_sprite_ext(_cs[3], _cs[4], _cs[0], _cs[1], _cs[5], _cs[6], _cs[7], make_colour_rgb(_cv, _cv, _cv), 1); continue; }
        for (var k = 0; k < 8; k++) { // station: filled octagon, corners on STATION_RADIUS
            var _a1 = _cs[7] + k * 45 + 22.5, _a2 = _a1 + 45;
            var _p1x = _cs[0] + lengthdir_x(_cs[2], _a1), _p1y = _cs[1] + lengthdir_y(_cs[2], _a1);
            var _p2x = _cs[0] + lengthdir_x(_cs[2], _a2), _p2y = _cs[1] + lengthdir_y(_cs[2], _a2);
            draw_sprite_quad(spr_sun_shadow, 0, _cs[0], _cs[1], _p1x, _p1y, _p2x, _p2y, _cs[0], _cs[1], make_colour_rgb(_cv, _cv, _cv), 1);
        }
    }
    gpu_set_alphatestenable(false);
    gpu_set_blendmode(bm_normal);
    matrix_set(matrix_world, matrix_build_identity());
    surface_reset_target();
    // dest x (1 - mask): shadowed sky goes dark, lit sky keeps its glow
    var _v = 255 * SHADOW_ALPHA * sun_k;
    gpu_set_blendmode(bm_subtract);
    draw_surface_ext(sun_surf, _vl, _vt, _z, _z, 0, make_colour_rgb(_v, _v, _v), 1);
    gpu_set_blendmode(bm_normal);
} else if (surface_exists(sun_surf)) {
    surface_free(sun_surf);
    sun_surf = -1;
}
