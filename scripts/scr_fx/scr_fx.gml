// ---------------------------------------------------------------------------
// Particles and floating text. Each particle's look is a sprite (spr_fx_*): edit the art to restyle it.
// The sprites are white so the colours below tint them. Sizes are scales of the sprite (1 = its own size).
// obj_game calls fx_init() on Create, fx_update() in Step, fx_cleanup() on Clean Up.
// ---------------------------------------------------------------------------

function fx_init() {
    fx_cleanup();
    global.fx_ps = part_system_create();
    part_system_depth(global.fx_ps, -15);
    part_system_automatic_update(global.fx_ps, false); // updated manually so it pauses with the game
    global.fx_em = part_emitter_create(global.fx_ps);

    // Bullet impact sparks
    var _t = part_type_create();
    part_type_sprite(_t, spr_fx_spark, false, false, false); // 8 px dot
    part_type_size(_t, 0.25, 0.375, 0, 0);
    part_type_colour2(_t, make_colour_rgb(255, 245, 160), make_colour_rgb(255, 140, 40));
    part_type_alpha2(_t, 1, 0);
    part_type_speed(_t, 1.5, 4, -0.15, 0);
    part_type_direction(_t, 0, 359, 0, 0);
    part_type_life(_t, 8, 16);
    global.fx_spark = _t;

    // Asteroid debris, one particle type per resource so it matches the asteroid's colour
    global.fx_debris = array_create(RES.COUNT);
    for (var s = 0; s < RES.COUNT; s++) {
        _t = part_type_create();
        part_type_sprite(_t, spr_fx_debris, false, false, false); // 8 px chip
        part_type_size(_t, 0.25, 0.625, -0.004, 0);
        part_type_colour2(_t, res_colour(s), merge_colour(res_colour(s), c_black, 0.5));
        part_type_alpha2(_t, 1, 0);
        part_type_speed(_t, 0.5, 3, -0.04, 0);
        part_type_direction(_t, 0, 359, 0, 0);
        part_type_orientation(_t, 0, 359, 3, 0, false);
        part_type_life(_t, 20, 50);
        global.fx_debris[s] = _t;
    }

    // Station hit
    _t = part_type_create();
    part_type_sprite(_t, spr_fx_spark, false, false, false);
    part_type_size(_t, 0.25, 0.5, 0, 0);
    part_type_colour2(_t, c_white, make_colour_rgb(255, 60, 60));
    part_type_alpha2(_t, 1, 0);
    part_type_speed(_t, 2, 5, -0.2, 0);
    part_type_direction(_t, 0, 359, 0, 0);
    part_type_life(_t, 12, 24);
    global.fx_hurt = _t;

    // Ship docking sparkle
    _t = part_type_create();
    part_type_sprite(_t, spr_fx_spark, false, false, false);
    part_type_size(_t, 0.25, 0.375, 0, 0);
    part_type_colour2(_t, c_lime, c_white);
    part_type_alpha2(_t, 1, 0);
    part_type_speed(_t, 1, 2.5, -0.05, 0);
    part_type_direction(_t, 0, 359, 0, 0);
    part_type_life(_t, 15, 30);
    global.fx_dock = _t;

    // Explosive asteroid shockwave ring (fx_blast sets its size per blast)
    _t = part_type_create();
    part_type_sprite(_t, spr_fx_ring, false, false, false); // 64 px ring
    part_type_colour2(_t, make_colour_rgb(255, 220, 120), make_colour_rgb(255, 80, 20));
    part_type_alpha2(_t, 0.9, 0);
    part_type_blend(_t, true);
    part_type_life(_t, BLAST_LIFE, BLAST_LIFE);
    global.fx_ring = _t;

    // Solar wind dust: faint streaks (fx_wind sets the direction)
    _t = part_type_create();
    part_type_sprite(_t, spr_fx_dust, false, false, false); // 64 px streak
    part_type_size(_t, 0.15, 0.35, 0, 0);
    part_type_colour1(_t, make_colour_rgb(255, 230, 150));
    part_type_alpha3(_t, 0, 0.3, 0);
    part_type_speed(_t, 7, 11, 0, 0);
    part_type_life(_t, 50, 90);
    global.fx_dust = _t;

    // Missile exhaust: short-lived hot sparks shed behind the motor (fx_missile_sparks)
    _t = part_type_create();
    part_type_sprite(_t, spr_fx_spark, false, false, false);
    part_type_size(_t, 0.2, 0.4, -0.01, 0);
    part_type_colour3(_t, make_colour_rgb(255, 250, 200), make_colour_rgb(255, 170, 60), make_colour_rgb(200, 50, 20));
    part_type_alpha2(_t, 1, 0);
    part_type_speed(_t, 0.3, 1.4, -0.03, 0);
    part_type_life(_t, 10, 24);
    part_type_blend(_t, true);
    global.fx_missile_spark = _t;
}

function fx_update() {
    if (variable_global_exists("fx_ps") && global.fx_ps != undefined) part_system_update(global.fx_ps);
}

function fx_cleanup() {
    if (!variable_global_exists("fx_ps") || global.fx_ps == undefined) return;
    part_type_destroy(global.fx_spark);
    part_type_destroy(global.fx_hurt);
    part_type_destroy(global.fx_dock);
    part_type_destroy(global.fx_ring);
    part_type_destroy(global.fx_dust);
    part_type_destroy(global.fx_missile_spark);
    for (var s = 0; s < RES.COUNT; s++) part_type_destroy(global.fx_debris[s]);
    part_system_destroy(global.fx_ps); // also frees the emitter
    global.fx_ps = undefined;
}

function fx_ready() { return variable_global_exists("fx_ps") && global.fx_ps != undefined; }

function fx_spark(_x, _y, _n = 4) { if (fx_ready()) part_particles_create(global.fx_ps, _x, _y, global.fx_spark, _n); }
function fx_hurt(_x, _y)   { if (fx_ready()) part_particles_create(global.fx_ps, _x, _y, global.fx_hurt, 14); }
function fx_dock(_x, _y)   { if (fx_ready()) part_particles_create(global.fx_ps, _x, _y, global.fx_dock, 16); }

#macro BLAST_LIFE 16 // frames the shockwave ring takes to reach full size and fade

/// Shockwave ring growing to radius _r, with a burst of sparks. spr_fx_ring is
/// 64 px across at size 1, so size _r / 32 reaches radius _r.
function fx_blast(_x, _y, _r) {
    if (!fx_ready()) return;
    var _end = _r / 32, _start = _end * 0.15;
    part_type_size(global.fx_ring, _start, _start, (_end - _start) / BLAST_LIFE, 0);
    part_particles_create(global.fx_ps, _x, _y, global.fx_ring, 1);
    part_particles_create(global.fx_ps, _x, _y, global.fx_spark, 12 + round(_r / 8));
}

/// Sparks shed from a missile's tail (_x, _y) as it flies along _dir.
function fx_missile_sparks(_x, _y, _dir) {
    if (!fx_ready()) return;
    var _back = _dir + 180;
    part_type_direction(global.fx_missile_spark, _back - 25, _back + 25, 0, 0);
    part_particles_create(global.fx_ps, _x + lengthdir_x(8, _back), _y + lengthdir_y(8, _back), global.fx_missile_spark, irandom_range(1, 2));
}

/// Solar wind: a couple of dust streaks a frame, blowing across the screen in direction _dir.
function fx_wind(_dir) {
    if (!fx_ready()) return;
    part_type_direction(global.fx_dust, _dir - 2, _dir + 2, 0, 0);
    part_type_orientation(global.fx_dust, _dir, _dir, 0, 0, false);
    repeat (2) {
        part_particles_create(global.fx_ps, view_left() + random(view_w()), view_top() + random(view_h()), global.fx_dust, 1);
    }
}

/// Debris burst spread across the asteroid's area
function fx_break(_x, _y, _size, _type) {
    if (!fx_ready()) return;
    var _r = ast_radius(_size);
    part_emitter_region(global.fx_ps, global.fx_em, _x - _r, _x + _r, _y - _r, _y + _r, ps_shape_ellipse, ps_distr_linear);
    part_emitter_burst(global.fx_ps, global.fx_em, global.fx_debris[_type], 6 + _size * 8);
}

/// Floating text that rises and fades, with an optional icon to its left.
function float_text(_x, _y, _text, _col, _scale = 1, _icon = -1) {
    var _f = instance_create_layer(_x, _y, "Instances", obj_float_text);
    _f.text   = string(_text);
    _f.colour = _col;
    _f.scale  = _scale;
    _f.icon   = _icon;
    return _f;
}

// ---------------------------------------------------------------------------
// Sprite drawing helpers. Every world effect is a sprite; these just place,
// stretch or wrap it. To change how something looks, edit its sprite, not the code.
//   draw_sprite_sized  - a sprite scaled to a size in px (e.g. a glow 3x the core)
//   draw_sprite_line   - stretched from one point to another. Art: left = tail,
//                        right = head, top-to-bottom = across the line. Origin left-middle.
//   draw_sprite_ring   - wrapped round a circle. Art: top = outer edge, bottom = inner edge,
//                        left-to-right repeats round the ring.
//   draw_sprite_quad   - mapped onto four corners (top-left, top-right, bottom-right, bottom-left)
//   draw_sprite_sector - a wedge. Art: left = the point, right = the rim, top/bottom = the sides.
// Ring/quad/sector sprites need "Separate Texture Page" ticked so the whole image is used.
// ---------------------------------------------------------------------------

function draw_sprite_sized(_spr, _sub, _x, _y, _w, _h, _ang, _col, _alpha) {
    draw_sprite_ext(_spr, _sub, _x, _y, _w / sprite_get_width(_spr), _h / sprite_get_height(_spr), _ang, _col, _alpha);
}

function draw_sprite_line(_spr, _sub, _x1, _y1, _x2, _y2, _w, _col, _alpha) {
    var _len = point_distance(_x1, _y1, _x2, _y2);
    if (_len <= 0) return;
    draw_sprite_ext(_spr, _sub, _x1, _y1, _len / sprite_get_width(_spr), _w / sprite_get_height(_spr),
                    point_direction(_x1, _y1, _x2, _y2), _col, _alpha);
}

function draw_sprite_ring(_spr, _sub, _x, _y, _r, _w, _col, _alpha) {
    var _uv = sprite_get_uvs(_spr, _sub);
    var _ro = _r + _w / 2, _ri = max(0, _r - _w / 2);
    var _n = clamp(round(_r / 6), 24, 128) * 2; // even, so the mirrored repeats meet up
    draw_primitive_begin_texture(pr_trianglestrip, sprite_get_texture(_spr, _sub));
    for (var i = 0; i <= _n; i++) {
        var _a = 360 * i / _n;
        var _u = (i mod 2 == 0) ? _uv[0] : _uv[2];
        draw_vertex_texture_colour(_x + lengthdir_x(_ro, _a), _y + lengthdir_y(_ro, _a), _u, _uv[1], _col, _alpha);
        draw_vertex_texture_colour(_x + lengthdir_x(_ri, _a), _y + lengthdir_y(_ri, _a), _u, _uv[3], _col, _alpha);
    }
    draw_primitive_end();
}

function draw_sprite_quad(_spr, _sub, _x1, _y1, _x2, _y2, _x3, _y3, _x4, _y4, _col, _alpha) {
    var _uv = sprite_get_uvs(_spr, _sub);
    draw_primitive_begin_texture(pr_trianglestrip, sprite_get_texture(_spr, _sub));
    draw_vertex_texture_colour(_x1, _y1, _uv[0], _uv[1], _col, _alpha);
    draw_vertex_texture_colour(_x2, _y2, _uv[2], _uv[1], _col, _alpha);
    draw_vertex_texture_colour(_x4, _y4, _uv[0], _uv[3], _col, _alpha);
    draw_vertex_texture_colour(_x3, _y3, _uv[2], _uv[3], _col, _alpha);
    draw_primitive_end();
}

/// Wedge from (_x, _y) out to radius _r, centred on _dir, _half degrees either side.
function draw_sprite_sector(_spr, _sub, _x, _y, _r, _dir, _half, _col, _alpha) {
    var _uv = sprite_get_uvs(_spr, _sub);
    var _n = max(6, round(_half * 2 / 3));
    draw_primitive_begin_texture(pr_trianglestrip, sprite_get_texture(_spr, _sub));
    for (var i = 0; i <= _n; i++) {
        var _t = i / _n;
        var _a = _dir + _half - 2 * _half * _t; // top of the art = anticlockwise side
        var _v = lerp(_uv[1], _uv[3], _t);
        draw_vertex_texture_colour(_x, _y, _uv[0], _v, _col, _alpha);
        draw_vertex_texture_colour(_x + lengthdir_x(_r, _a), _y + lengthdir_y(_r, _a), _uv[2], _v, _col, _alpha);
    }
    draw_primitive_end();
}
