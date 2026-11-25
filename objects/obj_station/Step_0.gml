// Hull counter-spins to the starfield (mirrors its slow orbit and its time-bonus rewinds)
if (instance_exists(obj_starfield)) hull_angle = -obj_starfield.star_rot * STATION_SPIN;

// Looping sounds (before the pause check, so hit-stop doesn't make them dip)
if (!dead) {
    sfx_loop(snd_station_hum, 0.25);
    if (!global.frozen && hp < global.stats.max_hp * 0.25) sfx_loop(snd_alarm, 0.3);
}

if (world_paused() || dead) exit;

var _st  = global.stats;
var _fps = game_get_speed(gamespeed_fps);

// Passive hull regeneration
var _oc = oc_active();
// Overcharge: hull and shields climb steadily to full over the whole Overcharge. Each frame
// adds the gap divided by the frames left, which is a constant rate landing on full at the end.
var _oc_left = _oc ? max(1, obj_game.oc_timer) : 1;
if (_oc) hp = min(_st.max_hp, hp + max(_st.regen / _fps, (_st.max_hp - hp) / _oc_left));
else     hp = min(_st.max_hp, hp + _st.regen / _fps);

// Each side's shield regains one px at a time: (SHIELD_PX_MAX - px held) seconds per px,
// so 5, 4, 3, 2, 1 s from empty to full. A partly-damaged px is topped up to the next whole one.
shield = 0;
for (var i = 0; i < SHIELD_SIDES; i++) {
    if (shield_hit[i] > 0) shield_hit[i]--;
    if (_st.max_shield <= 0) { shields[i] = 0; continue; }
    var _have = floor(shield_px(i) + 0.0001); // whole px held (tolerance for float drift)
    if (_oc) { // Overcharge: climbs steadily to full by the time it ends, no per-px wait
        shields[i] = min(_st.max_shield, shields[i] + (_st.max_shield - shields[i]) / _oc_left);
        shield_wait[i] = 0;
    } else if (_have >= SHIELD_PX_MAX) {
        shields[i] = _st.max_shield; // also catches up after a max_shield upgrade
        shield_wait[i] = 0;
    } else {
        shield_wait[i]++;
        if (shield_wait[i] >= (SHIELD_PX_MAX - _have) * _fps) {
            shields[i] = _st.max_shield * (_have + 1) / SHIELD_PX_MAX;
            shield_wait[i] = 0;
        }
    }
    shield += shields[i];
}
// Hull sections: regen repairs worn sides at the hull bar's rate (as a share of max hull);
// broken sides stay broken. Overcharge rebuilds every side by the time it ends.
for (var i = 0; i < SHIELD_SIDES; i++) {
    if (hull_hit[i] > 0) hull_hit[i]--;
    if (_oc) hull_sec[i] = min(1, hull_sec[i] + (1 - hull_sec[i]) / _oc_left);
    else if (hull_sec[i] > 0) hull_sec[i] = min(1, hull_sec[i] + _st.regen / max(1, _st.max_hp) / _fps);
}
// Repair drones: buzz about while there's hull to mend, then head home and fade out
var _mending = (hp < _st.max_hp);
for (var i = 0; i < SHIELD_SIDES; i++) if (hull_sec[i] > 0 && hull_sec[i] < 1) _mending = true;
_mending = _mending && _st.regen > 0;
var _want = _mending ? min(REPAIR_BOTS_MAX, ceil(_st.regen / 0.5) * REPAIR_BOTS_PER_RANK) : 0;
while (array_length(repair_bots) < _want) {
    array_push(repair_bots, { ox: 0, oy: 0, vx: random_range(-1, 1), vy: random_range(-1, 1), tx: 0, ty: 0, a: 0 });
}
var _reach = STATION_RADIUS * REPAIR_BOT_RANGE;
for (var i = array_length(repair_bots) - 1; i >= 0; i--) {
    var _b = repair_bots[i];
    var _busy = (i < _want);
    if (!_busy) { _b.tx = 0; _b.ty = 0; } // surplus or done: fly back inside
    else if (point_distance(_b.ox, _b.oy, _b.tx, _b.ty) < 4) {
        var _r = _reach * sqrt(random(1)), _d = random(360); // next random spot in and around the hull
        _b.tx = lengthdir_x(_r, _d);
        _b.ty = lengthdir_y(_r, _d);
    }
    // Steer towards the spot with a little jitter, capped at top speed
    _b.vx += (_b.tx - _b.ox) * 0.01 + random_range(-0.25, 0.25);
    _b.vy += (_b.ty - _b.oy) * 0.01 + random_range(-0.25, 0.25);
    var _sp = point_distance(0, 0, _b.vx, _b.vy);
    if (_sp > REPAIR_BOT_SPEED) { _b.vx *= REPAIR_BOT_SPEED / _sp; _b.vy *= REPAIR_BOT_SPEED / _sp; }
    _b.ox += _b.vx;
    _b.oy += _b.vy;
    if (_busy) _b.a = min(1, _b.a + 0.08);
    else {
        _b.a -= 0.04;
        if (_b.a <= 0) array_delete(repair_bots, i, 1);
    }
}
if (hurt_flash > 0) hurt_flash--;
recoil *= 0.7;      rail_recoil *= 0.7;
if (muzzle > 0) muzzle--;
if (rail_muzzle > 0) rail_muzzle--;
zap_recoil *= 0.7;
if (zap_muzzle > 0) zap_muzzle--;

// --- Aiming: the active weapon follows the cursor; passive ones find their own targets,
// turn slower and only fire once lined up (PASSIVE_* in scr_config) ---
var _pt_aim = perf_t(); // performance log: weapon targeting scans
scan_tick = (scan_tick + 1) mod TARGET_SCAN;
var _rescan = (scan_tick == 0);
var _act    = wpn_active();
var _cursor = point_direction(x, y, mouse_x, mouse_y);
// Gun (over a broken hull side it fires wide: see gun_breach_spread)
if (_act == WPN.GUN) { gun_aim = _cursor; gun_ready = true; }
else {
    if (_rescan || !tgt_ok(gun_tgt)) gun_tgt = target_nearest(x, y);
    var _gt = gun_tgt;
    if (_gt != noone) gun_aim = point_direction(x, y, _gt.x, _gt.y);
    gun_ready = (_gt != noone) && abs(angle_difference(gun_aim, gun_angle)) < PASSIVE_AIM;
}
gun_angle = mount_turn(gun_angle, gun_aim, _act == WPN.GUN);
// Tesla: active always strikes at the cursor (no targeting); passive zaps the rock nearest the station
var _zt = noone, _zap_ready = false;
if (_act == WPN.TESLA) {
    zap_angle  = mount_turn(zap_angle, _cursor, true);
    _zap_ready = true;
} else if (_st.lightning || _oc) { // Overcharge lends a Tesla Coil if you don't own one
    if (_rescan || !tgt_ok(zap_tgt)) zap_tgt = target_nearest(x, y);
    _zt = zap_tgt;
    if (_zt != noone) {
        var _za = point_direction(x, y, _zt.x, _zt.y);
        zap_angle  = mount_turn(zap_angle, _za, _act == WPN.TESLA);
        _zap_ready = (_act == WPN.TESLA) || abs(angle_difference(_za, zap_angle)) < PASSIVE_AIM;
    }
}
// Rail: active follows the cursor and fires on its timer; passive hunts the biggest rock
var _rail_ready = true;
if (_st.railgun) {
    if (_act == WPN.RAIL) rail_aim = _cursor;
    else {
        if (_rescan || !tgt_ok(rail_tgt)) rail_tgt = target_biggest();
        var _rt = rail_tgt;
        if (_rt != noone) rail_aim = point_direction(x, y, _rt.x, _rt.y);
        _rail_ready = (_rt != noone) && abs(angle_difference(rail_aim, rail_angle)) < PASSIVE_AIM;
    }
    rail_angle = mount_turn(rail_angle, rail_aim, _act == WPN.RAIL);
}
// Laser: beams on, then off. Fire Rate (and Overcharge) make each beam last longer; passive
// beams are shorter. Each beam rolls an offset inside the Accuracy cone and keeps it, so it
// tracks the cursor (active) or its target (passive) that many degrees off for that beam.
var _laser_go = false;
if (_st.laser) {
    var _lpass = (_act != WPN.LASER);
    if (laser_cycle > 0) laser_cycle--;
    if (laser_cycle <= 0) {
        laser_firing = !laser_firing;
        if (laser_firing) {
            laser_cycle = max(1, round(_st.laser_on * _fps * oc_rof() * wpn_rof(WPN.LASER)));
            var _lspr = wpn_spread(WPN.LASER);
            laser_offset = random_range(-_lspr / 2, _lspr / 2);
        } else laser_cycle = max(1, round(LASER_OFF * _fps));
    }
    if (!_lpass) { laser_aim = _cursor + laser_offset; _laser_go = laser_firing; }
    else {
        if (_rescan || !tgt_ok(laser_tgt)) laser_tgt = target_nearest(x, y);
        var _lt = laser_tgt;
        if (_lt != noone) { laser_aim = point_direction(x, y, _lt.x, _lt.y) + laser_offset; _laser_go = laser_firing; }
    }
    laser_angle = mount_turn(laser_angle, laser_aim, !_lpass);
}
laser_on = false;
perf_add("station_aim", _pt_aim);
// Tractor cone: turns towards the nearest loose loot on its own (holds its heading when there's none)
if (_st.tractor) {
    // Re-pick every 6 frames, or straight away once the current target is taken
    tr_scan--;
    if (tr_scan <= 0 || !instance_exists(tr_target) || tr_target.carried || tr_target.tractored || tr_target.claimed_by != noone) {
        var _pt_tr = perf_t();
        tr_target = target_loot();
        tr_scan = 6;
        perf_add("tractor_aim", _pt_tr);
    }
    var _tl = tr_target;
    if (_tl != noone) tr_dir = mount_turn(tr_dir, point_direction(x, y, _tl.x, _tl.y), true);
}

// Weapons are offline during the end-of-day recall
if (instance_exists(obj_game) && obj_game.state == "recalling") exit;

// Laser: a continuous beam, so it fires every frame it's on
if (_laser_go) {
    laser_on = true;
    var _pt_l = perf_t();
    beam_fire(_act != WPN.LASER);
    perf_add("laser", _pt_l);
    sfx_loop(snd_laser_beam, (_act == WPN.LASER) ? 0.45 : 0.2);
} else laser_target = noone;

// Chain lightning (Tesla Coil): fires on its own timer at its target
if (_st.lightning || _oc) {
    if (zap_timer > 0) zap_timer--;
    if (zap_timer <= 0 && _zap_ready) {
        if (_act == WPN.TESLA) {
            // Strike lands at a random point within zap_scatter of the cursor; whatever rock is there takes it
            var _sr = _st.zap_scatter * sqrt(random(1)), _sd = random(360);
            var _sx = mouse_x + lengthdir_x(_sr, _sd), _sy = mouse_y + lengthdir_y(_sr, _sd);
            fire_zap(target_near(_sx, _sy, ZAP_SPLASH), false, _sx, _sy); // nearest rock the splash reaches
            zap_timer = round(_st.zap_interval / wpn_rof(WPN.TESLA));
        } else if (fire_zap(_zt, true)) zap_timer = round(_st.zap_interval / wpn_rof(WPN.TESLA));
    }
}

// Repulsor and tractor pulses come out of the gun
if (_st.repulsor) {
    rep_timer--;
    if (rep_timer <= 0) { fire_wave(); rep_timer = _st.rep_interval; }
    if (rep_echo > 0) { rep_echo--; if (rep_echo <= 0) fire_wave(true); }
}
// Freeze ray: a blast every freeze_interval frames; with nothing to freeze it checks again shortly
if (frz_show > 0) frz_show--;
if (_st.freeze && !oc_freeze()) {
    frz_timer--;
    if (frz_timer <= 0) frz_timer = fire_freeze() ? _st.freeze_interval : 6;
}
// Tractor cone: on for TRACTOR_ON frames, off for tr_pause frames (0 = always on)
if (_st.tractor) {
    if (_st.tr_pause <= 0) tr_on = true;
    else {
        tr_timer--;
        if (tr_timer <= 0) {
            tr_on = !tr_on;
            tr_timer = tr_on ? TRACTOR_ON : _st.tr_pause;
        }
    }
    if (tr_on) tractor_beam();
}


// Rail gun: its own barrel, firing alongside the gun
if (_st.railgun) {
    if (rail_timer > 0) rail_timer--;
    if (rail_timer <= 0 && _rail_ready) {
        fire_rail();
        rail_timer = round(_st.rail_interval / oc_rof() / wpn_rof(WPN.RAIL) / ((_act == WPN.RAIL) ? 1 : RAIL_PASSIVE_RATE));
    }
}

// Automatic fire: every fire_interval frames, fire a burst of `burst` volleys
// (a passive gun waits until it's lined up on a target, and fires less often)
if (burst_left <= 0) {
    if (fire_timer > 0) fire_timer--;
    if (fire_timer <= 0 && gun_ready) {
        burst_left  = _st.burst;
        burst_timer = 0;
        fire_timer  = max(2, round(_st.fire_interval / oc_rof() / wpn_rof(WPN.GUN)));
    }
}
if (burst_left > 0) {
    burst_timer--;
    if (burst_timer <= 0) {
        fire_volley();
        burst_left--;
        burst_timer = BURST_GAP;
    }
}
