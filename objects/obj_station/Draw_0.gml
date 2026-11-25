// Tractor cone: faint green wedge (spr_tractor_cone) with arcs (spr_tractor_arc) flowing in towards the station
if (global.stats.tractor && tr_on && !(instance_exists(obj_game) && obj_game.state == "recalling")) {
    var _st = global.stats;
    var _steps = max(6, round(_st.tr_angle / 3));
    draw_sprite_sector(spr_tractor_cone, 0, x, y, _st.tr_range, tr_dir, _st.tr_angle, c_white, 0.035);
    // three arcs sliding inwards, each a chain of short sprite segments
    var _t = (current_time / 900) mod 1;
    for (var k = 0; k < 3; k++) {
        var _f = 1 - frac(_t + k / 3);
        var _r = STATION_RADIUS + (_st.tr_range - STATION_RADIUS) * _f;
        var _al = (0.45 * (1 - _f) + 0.1) * 0.5;
        var _px = x + lengthdir_x(_r, tr_dir - _st.tr_angle), _py = y + lengthdir_y(_r, tr_dir - _st.tr_angle);
        for (var i = 1; i <= _steps; i++) {
            var _ang = tr_dir - _st.tr_angle + 2 * _st.tr_angle * i / _steps;
            var _nx = x + lengthdir_x(_r, _ang), _ny = y + lengthdir_y(_r, _ang);
            draw_sprite_line(spr_tractor_arc, 0, _px, _py, _nx, _ny, 3, c_white, _al);
            _px = _nx; _py = _ny;
        }
    }
}

// Shields: a band in front of each flat side, as many px thick as that side's strength.
// spr_station_shield is mapped onto each band (top of the art = outer edge); frame 1 is the hit flash.
if (global.stats.max_shield > 0) {
    var _in = STATION_APOTHEM + SHIELD_GAP;    // inner edge, parallel to the hull side
    var _k  = 1 / dcos(22.5);                   // side's normal distance -> corner distance
    for (var i = 0; i < SHIELD_SIDES; i++) {
        var _a  = hull_angle + i * 45;
        var _px = shield_px(i);
        var _w  = (_px > 0) ? max(1, ceil(_px - 0.0001)) : 0; // whole px, never thinner than 1
        var _al = (_w <= 0) ? 0.12 : 0.55 + 0.4 * _px / SHIELD_PX_MAX; // empty side: a faint 1 px trace
        _w = max(_w, 1);
        var _out = _in + _w;
        var _ox1 = x + lengthdir_x(_out * _k, _a + 22.5), _oy1 = y + lengthdir_y(_out * _k, _a + 22.5);
        var _ox2 = x + lengthdir_x(_out * _k, _a - 22.5), _oy2 = y + lengthdir_y(_out * _k, _a - 22.5);
        var _ix2 = x + lengthdir_x(_in  * _k, _a - 22.5), _iy2 = y + lengthdir_y(_in  * _k, _a - 22.5);
        var _ix1 = x + lengthdir_x(_in  * _k, _a + 22.5), _iy1 = y + lengthdir_y(_in  * _k, _a + 22.5);
        draw_sprite_quad(spr_station_shield, 0, _ox1, _oy1, _ox2, _oy2, _ix2, _iy2, _ix1, _iy1, c_white, _al);
        if (shield_hit[i] > 0 && _px > 0) {
            draw_sprite_quad(spr_station_shield, 1, _ox1, _oy1, _ox2, _oy2, _ix2, _iy2, _ix1, _iy1, c_white, _al * shield_hit[i] / 6);
        }
    }
}

// Overcharge aura: a pulsing cyan ring round the hull
if (oc_active()) {
    draw_set_colour(OC_COLOUR);
    draw_set_alpha(0.35 + 0.25 * sin(current_time / 70));
    draw_ring(x, y, STATION_RADIUS + 14 + 4 * sin(current_time / 110), 5);
    draw_reset();
}
// Hull: each side is one thick line (spr_station_hull mapped onto a mitred band, outer edge on
// the octagon). Hits thin it from the inside out (HULL_PX_MAX px at full, never under
// HULL_MIN_PX), shifting it from white through amber to red, with cracks (frame 1) below half.
// A broken side is just ragged stubs (frame 2) flickering on the outer edge. Hull hits flash
// the struck side red.
{
    var _k = 1 / dcos(22.5);                      // side's normal distance -> corner distance
    var _amber = make_colour_rgb(255, 170, 60);
    for (var i = 0; i < SHIELD_SIDES; i++) {
        var _a = hull_angle + i * 45;
        var _sec = hull_sec[i];
        var _w, _sub, _col, _al;
        if (_sec <= 0) {
            _w = HULL_BROKEN_PX; _sub = 2; _al = 0.45 + 0.3 * abs(sin(current_time / 140 + i));
            _col = HUD_HULL;
        } else {
            _w = clamp(ceil(_sec * HULL_PX_MAX - 0.0001), HULL_MIN_PX, HULL_PX_MAX); // whole px
            _sub = (_sec < 0.5) ? 1 : 0;
            _al = 1;
            if (_sec >= 0.5) _col = merge_colour(_amber, c_white, (_sec - 0.5) * 2);
            else _col = merge_colour(HUD_HULL, _amber, _sec * 2);
        }
        if (dead) _col = c_dkgray;
        {
            var _out = STATION_APOTHEM;
            var _in  = _out - _w;
            var _ox1 = x + lengthdir_x(_out * _k, _a + 22.5), _oy1 = y + lengthdir_y(_out * _k, _a + 22.5);
            var _ox2 = x + lengthdir_x(_out * _k, _a - 22.5), _oy2 = y + lengthdir_y(_out * _k, _a - 22.5);
            var _ix2 = x + lengthdir_x(_in  * _k, _a - 22.5), _iy2 = y + lengthdir_y(_in  * _k, _a - 22.5);
            var _ix1 = x + lengthdir_x(_in  * _k, _a + 22.5), _iy1 = y + lengthdir_y(_in  * _k, _a + 22.5);
            draw_sprite_quad(spr_station_hull, _sub, _ox1, _oy1, _ox2, _oy2, _ix2, _iy2, _ix1, _iy1, _col, _al);
            if (hull_hit[i] > 0) {
                gpu_set_blendmode(bm_add);
                draw_sprite_quad(spr_station_hull, _sub, _ox1, _oy1, _ox2, _oy2, _ix2, _iy2, _ix1, _iy1, c_red, 0.6 * hull_hit[i] / 8);
                gpu_set_blendmode(bm_normal);
            }
        }
    }
}

// Repair drones (spr_repair_drone): tiny dots buzzing over the hull while it mends
if (!dead) for (var i = 0; i < array_length(repair_bots); i++) {
    var _b = repair_bots[i];
    draw_sprite_ext(spr_repair_drone, 0, x + _b.ox, y + _b.oy, 1, 1, 0, c_white, _b.a);
}

// Weapon mounts. Passive weapons are nested white shapes in the centre, outermost first
// (hexagon gun, pentagon laser, square rail, triangle Tesla), drawn dimmer. The ACTIVE weapon
// is always the original turret barrel (spr_gun) on top, so it's easy to see where you're aiming.
// Each mount turns to its own aim and kicks back when it fires.
var _act = wpn_active();
var _pa  = MOUNT_PASSIVE_ALPHA;
var _railch = global.stats.railgun ? clamp(1 - rail_timer / max(1, global.stats.rail_interval), 0, 1) : 1;
// Over a broken hull side a mount flickers amber: its shots are going wide
var _amber = merge_colour(c_white, make_colour_rgb(255, 170, 60), 0.5 + 0.5 * abs(sin(current_time / 90)));
// Gun (hexagon)
if (_act != WPN.GUN) {
    var _gx = x - lengthdir_x(recoil, gun_angle), _gy = y - lengthdir_y(recoil, gun_angle);
    draw_sprite_ext(spr_mount_gun, 0, _gx, _gy, 1, 1, gun_angle, (gun_breach_spread(gun_angle) > 0) ? _amber : c_white, _pa);
    if (muzzle > 0) draw_muzzle_flash(_gx + lengthdir_x(MOUNT_GUN_R, gun_angle), _gy + lengthdir_y(MOUNT_GUN_R, gun_angle), gun_angle, muzzle / 3, shot_size, make_colour_rgb(255, 230, 140));
}
// Laser beam (under the mounts): thicker and brighter as it heats up on one target, half width
// when passive. Refracted beams split off the lit rock, thinner.
if (laser_on) {
    var _lw = global.stats.laser_width * wpn_size(WPN.LASER) * oc_size();
    var _hw = _lw * (0.7 + 0.6 * laser_heat);
    var _la = 0.6 + 0.4 * laser_heat;
    draw_sprite_line(spr_beam_laser_player, 0, laser_x1, laser_y1, laser_x2, laser_y2, _hw, c_white, _la);
    for (var i = 0; i < array_length(laser_refr); i++) {
        var _rf = laser_refr[i];
        draw_sprite_line(spr_beam_laser_player, 0, _rf[0], _rf[1], _rf[2], _rf[3], _hw * 0.5, c_white, _la * 0.8);
    }
    if (laser_target != noone) draw_muzzle_flash(laser_x2, laser_y2, laser_angle + 180, 0.5 + 0.5 * laser_heat, 0.6 + laser_heat, c_white);
}
// Freeze ray blast: the laser beam's look in ice blue (spr_beam_freeze), half as thick, fading out
if (frz_show > 0) {
    var _fa = frz_show / FREEZE_SHOW;
    draw_sprite_line(spr_beam_freeze, 0, frz_x1, frz_y1, frz_x2, frz_y2, FREEZE_WIDTH * (0.6 + 0.4 * _fa), c_white, _fa);
}
// Laser (pentagon): once the laser exists
if (wpn_owned(WPN.LASER) && _act != WPN.LASER) {
    draw_sprite_ext(spr_mount_laser, 0, x, y, 1, 1, laser_angle, c_white, _pa);
}
// Rail (square): greys out after a shot and brightens back to white as it recharges
if (global.stats.railgun && _act != WPN.RAIL) {
    var _rx = x - lengthdir_x(rail_recoil, rail_angle), _ry = y - lengthdir_y(rail_recoil, rail_angle);
    draw_sprite_ext(spr_mount_rail, 0, _rx, _ry, 1, 1, rail_angle, merge_colour(c_dkgray, c_white, _railch), _pa);
    if (rail_muzzle > 0) draw_muzzle_flash(_rx + lengthdir_x(MOUNT_RAIL_SIDE, rail_angle), _ry + lengthdir_y(MOUNT_RAIL_SIDE, rail_angle), rail_angle, rail_muzzle / 6, 1.5, make_colour_rgb(120, 220, 255));
}
// Tesla (triangle): also appears while Overcharge lends one
if ((global.stats.lightning || oc_active()) && _act != WPN.TESLA) {
    var _zx = x - lengthdir_x(zap_recoil, zap_angle), _zy = y - lengthdir_y(zap_recoil, zap_angle);
    draw_sprite_ext(spr_mount_tesla, 0, _zx, _zy, 1, 1, zap_angle, c_white, _pa);
    if (zap_muzzle > 0) draw_muzzle_flash(_zx + lengthdir_x(MOUNT_TESLA_R, zap_angle), _zy + lengthdir_y(MOUNT_TESLA_R, zap_angle), zap_angle, zap_muzzle / 4, 1, make_colour_rgb(140, 230, 255));
}
// Active weapon: the original barrel, tinted per weapon, on top of the shapes
var _aa = gun_angle, _ar = recoil, _af = muzzle / 3, _fs = shot_size, _fc = make_colour_rgb(255, 230, 140), _tint = c_white;
switch (_act) {
    case WPN.RAIL:  // cyan, glowing brighter as it charges
        _aa = rail_angle; _ar = rail_recoil; _af = rail_muzzle / 6; _fs = 3; _fc = make_colour_rgb(120, 220, 255);
        _tint = merge_colour(make_colour_rgb(60, 140, 200), c_white, _railch);
        break;
    case WPN.LASER: // warm pink, glowing hotter with the beam's heat
        _aa = laser_angle; _ar = 0; _af = 0;
        _tint = merge_colour(make_colour_rgb(255, 140, 170), c_white, laser_heat);
        break;
    case WPN.TESLA: // pale electric blue
        _aa = zap_angle; _ar = zap_recoil; _af = zap_muzzle / 4; _fs = 1; _fc = make_colour_rgb(140, 230, 255);
        _tint = make_colour_rgb(170, 235, 255);
        break;
}
if (gun_breach_spread(_aa) > 0) _tint = _amber;
var _bx = x - lengthdir_x(_ar, _aa), _by = y - lengthdir_y(_ar, _aa);
draw_sprite_ext(spr_gun, 0, _bx, _by, GUN_SCALE, GUN_SCALE, _aa, _tint, 1);
if (_af > 0) draw_muzzle_flash(_bx + lengthdir_x(GUN_LENGTH, _aa), _by + lengthdir_y(GUN_LENGTH, _aa), _aa, _af, _fs, _fc);
