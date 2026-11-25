/// Persistent animated background, created once by game_init().
/// Drawn in the game layer (depth 50: above the room's background colour, behind
/// everything else), so it picks up the glow and screen shake.
///  - 3 parallax star layers on a very slow clockwise orbit round the screen centre
///    (as if the station turns), twinkling and leaning away from the cursor.
///    Time bonuses wind the field back counter-clockwise for a moment.
///  - slow colour-shifting nebula clouds (kept dim so they don't bloom)
///  - the odd shooting star
depth = 50;

#macro STAR_ORBIT      2   // degrees per second the field turns clockwise
#macro STAR_REWIND     5     // degrees a time bonus winds it back counter-clockwise
#macro STAR_REWIND_EASE 0.05 // share of the remaining rewind used each frame (~1s to settle)
#macro STAR_STREAK     5     // streak length while rewinding, in frames of movement
#macro NEBULA_BRIGHT    38    // 0-255 nebula core brightness (keep under the bloom threshold, ~46)

// Per layer: count, size (px), base alpha, mouse parallax strength
// Counts cover a disc round the centre (so the corners stay full as it turns): ~1.85x the screen area.
layers = [
    { count: 296, size: 1, alpha: 0.35, par: 0.004 },
    { count: 130, size: 2, alpha: 0.6,  par: 0.012 },
    { count: 44,  size: 3, alpha: 0.9,  par: 0.025 },
];

star_rot  = 0;  // current orbit angle (degrees)
star_spin = 0;  // counter-clockwise rewind this frame (drawn as streaks)
var _R = point_distance(0, 0, room_width, room_height) / 2 + 8;
// Star density: STAR_DENSE_MAX x the layer counts are made; each star has a random `keep`
// and only shows while keep < star_density. Normal = 1 / STAR_DENSE_MAX (the layer counts),
// a clustered field fills the sky (all of them), a sparse field thins it right out.
#macro STAR_DENSE_MAX    3
#macro STAR_DENSE_SPARSE 0.08  // share of all stars shown on a sparse field (~a quarter of normal)
#macro STAR_DENSE_EASE   0.02  // share of the gap closed each frame
star_density = 1 / STAR_DENSE_MAX;
stars = [];
for (var l = 0; l < array_length(layers); l++) {
    repeat (layers[l].count * STAR_DENSE_MAX) {
        array_push(stars, {
            keep: random(1),
            r: _R * sqrt(random(1)), a: random(360), layer: l, // polar, round the screen centre
            phase: random(360), tw: random_range(1, 4), // twinkle phase and speed
            tint: choose(c_white, c_white, make_colour_rgb(180, 210, 255), make_colour_rgb(255, 230, 200)),
        });
    }
}

// --- Procedural cloud textures (built once at startup) ---
// 1) A soft gaussian "puff": concentric circles whose weights sum to exp(-4.5 r^2).
var _ps = 64, _pr = _ps / 2 - 1, _steps = 24;
var _surf = surface_create(_ps, _ps);
surface_set_target(_surf);
draw_clear_alpha(c_black, 1);
gpu_set_blendmode(bm_add);
draw_set_circle_precision(64);
draw_set_colour(c_white);
for (var k = _steps; k >= 1; k--) {
    draw_set_alpha(exp(-4.5 * sqr((k - 1) / _steps)) - exp(-4.5 * sqr(k / _steps)));
    draw_circle(_ps / 2, _ps / 2, _pr * k / _steps, false);
}
surface_reset_target();
var _puff = sprite_create_from_surface(_surf, 0, 0, _ps, _ps, false, false, _ps / 2, _ps / 2);
surface_free(_surf);

// 2) Lumpy cloud textures: puffs (some stretched into wisps) clustered round a few
//    random anchors, then a few darker pockets knocked out so it isn't one smooth lump.
//    Black background, so drawing them additively only adds the bright parts.
var _cs = 256, _cc = _cs / 2;
cloud_tex = [];
var _cloud = surface_create(_cs, _cs);
repeat (3) {
    surface_set_target(_cloud);
    draw_clear_alpha(c_black, 1);
    gpu_set_blendmode(bm_add);
    var _anchors = [];
    repeat (3) array_push(_anchors, [random(360), random(_cc * 0.35)]);
    repeat (80) {
        var _an = _anchors[irandom(2)];
        var _ax = lengthdir_x(_an[1], _an[0]), _ay = lengthdir_y(_an[1], _an[0]);
        var _dir = random(360), _off = random(_cc * 0.4) * random(1);
        var _x = _ax + lengthdir_x(_off, _dir), _y = _ay + lengthdir_y(_off, _dir);
        var _d = point_distance(0, 0, _x, _y);
        var _xs = choose(1, 1, random_range(1.4, 2.6)); // some puffs stretched into wisps
        var _rad = random_range(14, 46) * max(0.3, 1 - _d / _cc);
        _rad = min(_rad, (_cc - 4 - _d) / _xs); // never reach the edge (no hard clipping)
        if (_rad < 4) continue;
        draw_sprite_ext(_puff, 0, _cc + _x, _cc + _y, _rad / (_ps / 2) * _xs, _rad / (_ps / 2), random(360), c_white, 0.16);
    }
    gpu_set_blendmode(bm_subtract); // dest * (1 - src): grey puffs carve soft darker pockets
    repeat (14) {
        var _dir = random(360), _off = random(_cc * 0.6);
        draw_sprite_ext(_puff, 0, _cc + lengthdir_x(_off, _dir), _cc + lengthdir_y(_off, _dir),
            random_range(0.3, 0.8) * random_range(1, 2), random_range(0.3, 0.8), random(360), make_colour_rgb(90, 90, 90), 1);
    }
    surface_reset_target();
    array_push(cloud_tex, sprite_create_from_surface(_cloud, 0, 0, _cs, _cs, false, false, _cc, _cc));
}
surface_free(_cloud);
sprite_delete(_puff);
gpu_set_blendmode(bm_normal);
draw_set_circle_precision(24);
draw_set_alpha(1);
draw_set_colour(c_white);
// Stars use spr_star (a soft dot sprite).

// Each nebula is a cluster of overlapping cloud textures that slowly turn and churn
// The first NEBULA_COUNT are always drawn; an ion storm brings in the rest (x NEBULA_STORM in all)
#macro NEBULA_COUNT 5
#macro NEBULA_STORM 3
nebulae = [];
repeat (NEBULA_COUNT * NEBULA_STORM) {
    var _parts = [];
    repeat (irandom_range(4, 6)) {
        array_push(_parts, {
            tex: irandom(array_length(cloud_tex) - 1),
            a: random(360), d: random_range(0, 0.45),            // offset from the nebula centre (x r)
            s: random_range(0.55, 1.0), xs: random_range(0.8, 1.4), // size (x r) and stretch
            rot: random(360), spin: random_range(-1, 1),          // degrees per second
            orbit: random_range(-0.5, 0.5),                       // drift round the centre, deg/s
            hue: random_range(-14, 14),                           // colour variation within the cloud
        });
    }
    array_push(nebulae, {
        x: random(room_width), y: random(room_height),
        r: random_range(260, 520),
        hue: random(255), hue_spd: random_range(0.01, 0.04),
        vx: random_range(-0.08, 0.08), vy: random_range(-0.05, 0.05),
        parts: _parts,
    });
}

// Ion storm sky: extra nebulae fade in, and every few seconds a cloud flickers with
// distant lightning (with a low rumble). A real bolt lights the whole sky (storm_flash).
#macro STORM_FADE      0.01  // share per frame the extra nebulae fade in/out
#macro STORM_FLICK_MIN 3     // seconds between background flickers...
#macro STORM_FLICK_MAX 7
#macro STORM_FLASH_COL make_colour_rgb(150, 175, 255)
storm_k     = 0;   // 0-1: how far the storm sky has faded in (extra nebulae)
neb_base_k  = 1;   // 0-1: the usual nebulae (a sparse field fades them all out)
neb_extra_k = 0;   // 0-1: the extra nebulae (an ion storm or a clustered field brings them in)
storm_timer = 0;   // frames until the next background flicker
flick_neb   = -1;  // nebula lit by the current flicker
flick_t     = 0;   // frames into the current flicker
flick_pulses = []; // frame offsets of each flash within the flicker
flick_glow  = 0;   // current brightness of the flickering cloud (0-1)
sky_flash   = 0;   // whole-sky brightening from a real bolt (0-1)

/// A bolt struck: brighten every cloud for a moment (_k 0-1).
storm_flash = function(_k) { sky_flash = max(sky_flash, _k); };

// Nebula tint: sticky days lean green, warp days lean purple (hue 0-255, as make_colour_hsv)
#macro NEB_HUE_STICKY 80
#macro NEB_HUE_WARP   195
#macro NEB_HUE_PULL   0.8   // how far towards the theme hue at full strength (the rest keeps some variety)
neb_tint_k   = 0;   // 0-1: how strongly today's theme hue applies
neb_tint_hue = 0;

// Solar wind: a sun off screen upwind lights the field, and rocks, ships and the station cast
// shadows downwind (drawn here, behind everything)
// The sun is a point light just past the screen edge; each rock, ship and the station is treated
// as a circle and casts a shadow wedge straight away from it, out past the far edge (2D ray-cast
// style). Shadows are gathered on a surface first so overlaps don't double up, then darken the
// sky, the sun's glow and the stars. Drawn here at depth 50, so they fall behind every object.
#macro SUN_MARGIN     300   // px (screen) past the screen edge the sun sits: well out of sight, only its light shows
#macro SUN_WASH_REACH 1.15  // the light reaches this x the distance to the far corner, so it covers the whole screen
#macro SUN_WASH_ALPHA 0.2   // brightness of the light (strongest on the sun's side, fading across the screen)
#macro SHADOW_ALPHA   0.8   // darkness of a full shadow (0-1)
#macro SUN_BLOOM_MULT 0.2   // x the bloom strength while the sun is up (it adds plenty of light already; obj_post)
#macro SHADOW_SOFT    [0.8, 1, 1.25] // radius multipliers drawn on top of each other for a soft edge
#macro SHADOW_PASS    0.5   // strength of each of those passes
sun_k    = 0;   // 0-1: fades in and out with the wind
sun_dir  = 0;   // direction from the screen centre to the sun
sun_surf = -1;  // shadow mask (white = shadow), screen sized

shooters = [];          // active shooting stars
shooter_timer = 120;
par_x = 0;              // smoothed mouse parallax offset
par_y = 0;
