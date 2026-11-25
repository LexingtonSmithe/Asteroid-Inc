var _pt_draw = perf_t(); // performance log: asteroid drawing (CPU side)
// Comet streak: a tapering line through recent positions
if (is_comet) {
    var _n = array_length(trail);
    for (var i = 1; i < _n; i++) {
        var _f = i / _n;
        draw_sprite_line(spr_trail_soft, 0, trail[i - 1][0], trail[i - 1][1], trail[i][0], trail[i][1], 1 + _f * radius * 0.9, merge_colour(c_white, image_blend, _f), _f * 0.8);
    }
}
// Tinted by type (gilded overrides it); fill shows remaining health
var _col  = gilded ? GILDED_COLOUR : image_blend;
var _frac = hp / max_hp;
var _xs = image_xscale * (1 + 0.22 * squash) * warp_k; // squash wide and flat, then spring back
var _ys = image_yscale * (1 - 0.16 * squash) * warp_k;
if (_xs <= 0.01) { perf_add("ast_draw", _pt_draw); exit; } // fully warped out

// Glass: a black body and a thin grey line, nothing bright enough to glow. A hit still flashes it.
// It hides every other trait too, warnings included: stacking glass on a survey is a choice.
if (glass) {
    draw_sprite_fill(sprite_index, x, y, _xs, _ys, image_angle, c_black, 1, 1, 0);
    draw_sprite_fill(sprite_index, x, y, _xs, _ys, image_angle, gilded ? merge_colour(GILDED_COLOUR, c_black, 0.7) : glass_colour(size), 1, 0, 0);
    if (flash > 0) draw_sprite_fill(sprite_index, x, y, _xs, _ys, image_angle, c_white, 0.35, 0, 0);
    if (oc_freeze()) draw_sprite_fill(sprite_index, x, y, _xs * 1.08, _ys * 1.08, image_angle, OC_FREEZE_COLOUR, 0.9, 0, 0);
    else if (chill > 0) draw_sprite_fill(sprite_index, x, y, _xs * 1.08, _ys * 1.08, image_angle, OC_FREEZE_COLOUR, 0.9 * chill, 0, 0);
    perf_add("ast_draw", _pt_draw);
    exit;
}

// Warp: a violet shimmer while it folds out or back in
if (warp && warp_phase != 0) draw_sprite_fill(sprite_index, x, y, _xs * 1.3, _ys * 1.3, image_angle, WARP_COLOUR, 1 - warp_k, 0);
if (wobble > 0) { // rubber: jelly wobble that rings on after the hit
    var _w = 0.25 * wobble * sin(wobble_t * 0.7);
    _xs *= 1 + _w;
    _ys *= 1 - _w;
}

// Trait rims sit just outside the rock (outline only: frac 0)
if (armoured) draw_sprite_fill(sprite_index, x, y, _xs * 1.22, _ys * 1.22, image_angle, ARMOUR_COLOUR, 1, 0, OUTLINE_THICKEN * 2);
if (sticky)   draw_sprite_fill(sprite_index, x, y, _xs * 1.12, _ys * 1.12, image_angle, STICKY_COLOUR, 0.7, 0, OUTLINE_THICKEN * 2);
if (rubber)   draw_sprite_fill(sprite_index, x, y, _xs * 1.15, _ys * 1.15, image_angle, RUBBER_COLOUR, 0.6, 0);
if (magnetic) draw_sprite_fill(sprite_index, x, y, _xs * 1.15, _ys * 1.15, image_angle, MAG_COLOUR, 0.6, 0);
if (warp)     draw_sprite_fill(sprite_index, x, y, _xs * 1.12, _ys * 1.12, image_angle, WARP_COLOUR, 0.5, 0);
if (occupied) draw_sprite_fill(sprite_index, x, y, _xs * 1.15, _ys * 1.15, image_angle, OCC_COLOUR, 0.6, 0);
if (breeder)  draw_sprite_fill(sprite_index, x, y, _xs * 1.12, _ys * 1.12, image_angle, BREED_COLOUR, 0.5, 0);
if (dense)    draw_sprite_fill(sprite_index, x, y, _xs * 1.15, _ys * 1.15, image_angle, DENSE_COLOUR, 0.8, 0, OUTLINE_THICKEN * 2);
if (charged) { // crackling rim, brighter just after a zap, and a faint ring showing its reach
    var _cj = (charge_flash > 0) ? 1 : 0.4 + random(0.3);
    draw_sprite_fill(sprite_index, x + random_range(-1, 1), y + random_range(-1, 1), _xs * 1.15, _ys * 1.15, image_angle, CHARGE_COLOUR, _cj, 0);
    draw_sprite_ring(spr_ring_line, 0, x, y, radius + CHARGE_RANGE, 2, CHARGE_COLOUR, 0.08);
}

// Tiny rocks (the most numerous) skip the thickened outline: at day zoom it's under a pixel anyway
draw_sprite_fill(sprite_index, x, y, _xs, _ys, image_angle, _col, 1, _frac, (size == AST.TINY && !is_boss) ? AST_TINY_THICKEN : OUTLINE_THICKEN);

// Explosive: pulsing hot core and a faint ring showing the blast reach
if (explosive) {
    var _p = 0.5 + 0.5 * sin(current_time / 110 + pulse_phase);
    gpu_set_blendmode(bm_add);
    draw_sprite_fill(sprite_index, x, y, _xs * 0.6, _ys * 0.6, image_angle, EXPLODE_COLOUR, 0.35 + 0.4 * _p, 1, 0);
    gpu_set_blendmode(bm_normal);
    draw_sprite_ring(spr_ring_line, 0, x, y, explode_radius(size), 2, EXPLODE_COLOUR, 0.08 + 0.06 * _p);
}

// Breeder: a green core that swells and pulses faster as it nears its next growth
if (breeder) {
    var _g = clamp(1 - breed_t / (BREED_GROW * game_get_speed(gamespeed_fps)), 0, 1);
    var _bp = 0.5 + 0.5 * sin(current_time / (260 - 180 * _g) + pulse_phase);
    gpu_set_blendmode(bm_add);
    draw_sprite_fill(sprite_index, x, y, _xs * (0.3 + 0.35 * _g), _ys * (0.3 + 0.35 * _g), image_angle, BREED_COLOUR, 0.25 + 0.45 * _bp, 1, 0);
    gpu_set_blendmode(bm_normal);
}

// Occupied: a red beacon on the hull that blinks faster as the next launch nears
if (occupied) {
    var _due = 1 - occ_t / (OCC_RATE * game_get_speed(gamespeed_fps));
    if (sin(current_time / (180 - 140 * _due)) > 0) {
        var _bx = x + lengthdir_x(radius * 0.45 * warp_k, image_angle + 40);
        var _by = y + lengthdir_y(radius * 0.45 * warp_k, image_angle + 40);
        draw_sprite_sized(spr_beacon, 0, _bx, _by, 6, 6, 0, OCC_COLOUR, 1);
    }
}

if (flash > 0) {
    gpu_set_blendmode(bm_add);
    draw_sprite_fill(sprite_index, x, y, _xs, _ys, image_angle, c_white, 0.5, _frac);
    gpu_set_blendmode(bm_normal);
}

// Frozen by Overcharge: a thin blue outline
if (oc_freeze()) draw_sprite_fill(sprite_index, x, y, _xs * 1.08, _ys * 1.08, image_angle, OC_FREEZE_COLOUR, 0.9, 0, 0);
// Freeze ray: an icy frost that thickens with each blast, and the same blue outline once it's at a stop
if (chill > 0) {
    draw_sprite_fill(sprite_index, x, y, _xs, _ys, image_angle, OC_FREEZE_COLOUR, 0.5 * chill, 1, 0);
    draw_sprite_fill(sprite_index, x, y, _xs * 1.08, _ys * 1.08, image_angle, OC_FREEZE_COLOUR, 0.9 * chill, 0, 0);
}
perf_add("ast_draw", _pt_draw);
