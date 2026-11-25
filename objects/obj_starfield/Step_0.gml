var _w = room_width, _h = room_height;

// Slow clockwise orbit (GameMaker angles go anticlockwise, so it counts down).
// A time bonus adds rewind, which plays out as a short counter-clockwise turn.
star_spin = global.star_rewind * STAR_REWIND_EASE;
global.star_rewind -= star_spin;
if (global.star_rewind < 0.01) global.star_rewind = 0;
star_rot += star_spin - STAR_ORBIT / game_get_speed(gamespeed_fps);

// Nebulae wander slowly and shift colour; wrap with margin so they never pop
for (var i = 0; i < array_length(nebulae); i++) {
    var _n = nebulae[i];
    _n.x += _n.vx; _n.y += _n.vy;
    _n.hue = (_n.hue + _n.hue_spd) mod 255;
    var _m = _n.r * 1.5; // cloud parts reach past r
    if (_n.x < -_m) _n.x += _w + _m * 2; else if (_n.x > _w + _m) _n.x -= _w + _m * 2;
    if (_n.y < -_m) _n.y += _h + _m * 2; else if (_n.y > _h + _m) _n.y -= _h + _m * 2;
}

// Ion storm sky: fade the extra nebulae in or out, and flicker a cloud now and then
var _storm = instance_exists(obj_game) && cond_active(COND.ION_STORM);
storm_k = clamp(storm_k + (_storm ? STORM_FADE : -STORM_FADE), 0, 1);

// Nebula amount: a clustered field brings in the extras too; a sparse field clears the sky
var _cl = instance_exists(obj_game) && cond_active(COND.CLUSTERED);
var _sp = instance_exists(obj_game) && cond_active(COND.SPARSE);
neb_base_k  = clamp(neb_base_k  + (_sp ? -STORM_FADE : STORM_FADE), 0, 1);
neb_extra_k = clamp(neb_extra_k + ((_storm || (_cl && !_sp)) ? STORM_FADE : -STORM_FADE), 0, 1);

// Star density: clustered fills the sky, sparse empties it
var _dt = 1 / STAR_DENSE_MAX;
if (instance_exists(obj_game)) {
    if (cond_active(COND.CLUSTERED)) _dt = 1;
    else if (cond_active(COND.SPARSE)) _dt = STAR_DENSE_SPARSE;
}
star_density = lerp(star_density, _dt, STAR_DENSE_EASE);

// Nebula theme hue: sticky green, warp purple
var _th = -1;
if (instance_exists(obj_game)) {
    if (cond_active(COND.STICKY)) _th = NEB_HUE_STICKY;
    else if (cond_active(COND.WARP)) _th = NEB_HUE_WARP;
}
if (_th >= 0) neb_tint_hue = _th;
neb_tint_k = clamp(neb_tint_k + (_th >= 0 ? 0.01 : -0.01), 0, 1);

// Sun: upwind of the solar wind
var _windy = global.wind_x != 0 || global.wind_y != 0;
if (_windy) sun_dir = point_direction(0, 0, global.wind_x, global.wind_y) + 180;
sun_k = clamp(sun_k + (_windy ? 0.01 : -0.01), 0, 1);
sky_flash *= 0.9;
flick_glow *= 0.8;
if (_storm && !world_paused()) {
    if (flick_neb < 0) {
        storm_timer--;
        if (storm_timer <= 0) {
            // Light up one cloud with a short burst of 1-3 flashes, and a distant rumble
            flick_neb = irandom(array_length(nebulae) - 1);
            flick_t = 0;
            flick_pulses = [0];
            repeat (irandom(2)) array_push(flick_pulses, flick_pulses[array_length(flick_pulses) - 1] + irandom_range(4, 10));
            storm_timer = random_range(STORM_FLICK_MIN, STORM_FLICK_MAX) * game_get_speed(gamespeed_fps);
            sfx(snd_background_thunder, 0.35, 1, 0.12);
        }
    }
}
if (flick_neb >= 0) {
    for (var i = 0; i < array_length(flick_pulses); i++) if (flick_pulses[i] == flick_t) flick_glow = random_range(0.6, 1);
    flick_t++;
    if (flick_t > flick_pulses[array_length(flick_pulses) - 1] + 20) flick_neb = -1;
}

// Parallax: the field leans gently away from the cursor
var _smx = (mouse_x - view_left()) / view_zoom(), _smy = (mouse_y - view_top()) / view_zoom(); // mouse in screen space (game camera zooms)
par_x = lerp(par_x, _w / 2 - _smx, 0.05);
par_y = lerp(par_y, _h / 2 - _smy, 0.05);

// Shooting stars
shooter_timer--;
if (shooter_timer <= 0) {
    var _dir = random_range(200, 250);
    array_push(shooters, { x: random(_w), y: random(_h * 0.5), dir: _dir, spd: random_range(14, 22), life: 40, life_max: 40 });
    shooter_timer = irandom_range(240, 600); // every 4-10 seconds
}
for (var i = array_length(shooters) - 1; i >= 0; i--) {
    var _sh = shooters[i];
    _sh.x += lengthdir_x(_sh.spd, _sh.dir);
    _sh.y += lengthdir_y(_sh.spd, _sh.dir);
    _sh.life--;
    if (_sh.life <= 0) array_delete(shooters, i, 1);
}
