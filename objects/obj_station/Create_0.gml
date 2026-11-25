/// Central station: health, shields, and the auto-firing turret.
depth = -20;
var _st = global.stats;
hp     = _st.max_hp;
// Per-side shields (see SHIELD_SIDES in scr_config). shields[i] is in shield points,
// out of max_shield; shield_wait[i] counts frames towards that side's next px.
shields     = array_create(SHIELD_SIDES, _st.max_shield);
shield_wait = array_create(SHIELD_SIDES, 0);
shield_hit  = array_create(SHIELD_SIDES, 0); // frames of white flash after a side absorbs a hit
shield = _st.max_shield * SHIELD_SIDES;      // total across all sides (HUD and quick checks)
hull_angle   = 0;   // octagon rotation (degrees), set from the starfield in Step
hurt_flash   = 0;
dead = false;

// Hull sections (see HULL_PX_MAX in scr_config): hull_sec[i] is side i's condition,
// 1 = intact, 0 = broken. hull_hit[i] = frames of red flash after side i takes hull damage.
hull_sec = array_create(SHIELD_SIDES, 1);
hull_hit = array_create(SHIELD_SIDES, 0);

/// Wears side _side down by _dmg hull damage; breaks it when it runs out.
wear_section = function(_side, _dmg) {
    if (hull_sec[_side] <= 0) return;
    hull_sec[_side] = max(0, hull_sec[_side] - _dmg / max(1, global.stats.max_hp * HULL_SECTION_SHARE));
    if (hull_sec[_side] <= 0) {
        // Side breaks: burst of sparks along it, a heavy clunk and a shake
        var _a = station_side_face(_side), _r = STATION_APOTHEM - 6;
        for (var k = -1; k <= 1; k++) {
            var _p = _a + k * 15;
            fx_hurt(x + lengthdir_x(_r, _p), y + lengthdir_y(_r, _p));
        }
        sfx(snd_station_hit, 1, 0.6, 0);
        screen_shake(4);
        hit_stop(5);
    }
};

/// True if the main barrel pointing at _a would lie over a broken side.
gun_blocked = function(_a) {
    for (var i = 0; i < SHIELD_SIDES; i++) {
        if (hull_sec[i] <= 0 && abs(angle_difference(_a, hull_angle + i * 45)) < 22.5) return true;
    }
    return false;
};
/// Extra spread (degrees, total cone) while a barrel at _a sits over a broken side: the mount is loose.
gun_breach_spread = function(_a = undefined) {
    _a ??= gun_angle;
    return gun_blocked(_a) ? HULL_BREACH_SPREAD : 0;
};
/// How far out weapon _w's shots leave: the tip of the barrel when it's the active weapon
/// (the original turret sprite), otherwise the tip or side of its passive shape.
muzzle_dist = function(_w) {
    if (wpn_active() == _w) return GUN_LENGTH;
    switch (_w) {
        case WPN.GUN:   return MOUNT_GUN_R;
        case WPN.LASER: return MOUNT_LASER_R;
        case WPN.RAIL:  return MOUNT_RAIL_SIDE;
        case WPN.TESLA: return MOUNT_TESLA_R;
    }
    return 0;
};
/// Returns mount angle _ang turned towards _target: GUN_TURN degrees a frame when it's
/// the active weapon, stats.pas_turn of that when passive (Passive Tracking).
mount_turn = function(_ang, _target, _active) {
    var _t = GUN_TURN * (_active ? 1 : global.stats.pas_turn);
    return _ang + clamp(angle_difference(_target, _ang), -_t, _t);
};

// --- Weapon targeting (passive weapons pick their own) ---------------------------
/// Nearest live on-screen asteroid to (_x, _y), or noone. On a Pirate System day (no
/// asteroids) passive weapons hunt the enemy ships instead: hunters, attackers, enemy collectors, missiles, flagship.
target_nearest = function(_x, _y) {
    var _best = noone, _bd = infinity;
    with (obj_asteroid) {
        if (dead || !in_view(x, y)) continue;
        var _d = point_distance(x, y, _x, _y);
        if (_d < _bd) { _bd = _d; _best = id; }
    }
    if (chart_current() == CHART.PIRATE) {
        with (obj_enemy) {
            if (dead || !in_view(x, y)) continue;
            var _d = point_distance(x, y, _x, _y);
            if (_d < _bd) { _bd = _d; _best = id; }
        }
    }
    return _best;
};
/// Live asteroid covering point (_x, _y) (nearest centre if several), or noone.
target_at = function(_x, _y) {
    var _best = noone, _bd = infinity;
    with (obj_asteroid) {
        if (dead) continue;
        var _d = point_distance(x, y, _x, _y);
        if (_d < radius && _d < _bd) { _bd = _d; _best = id; }
    }
    return _best;
};
/// Raycast helper: if instance _i (centre, radius) lies on the current laser ray closer than
/// the best so far, it becomes the hit. Ray: laser_x1/y1 along unit (_dx, _dy), _half = beam half-width.
laser_consider = function(_i, _dx, _dy, _half) {
    var _rx = _i.x - laser_x1, _ry = _i.y - laser_y1;
    var _t  = _rx * _dx + _ry * _dy;          // distance along the ray to the closest approach
    var _r  = _i.radius + _half;
    var _p2 = _rx * _rx + _ry * _ry - _t * _t; // squared distance from the ray
    if (_p2 > _r * _r) return;
    var _te = _t - sqrt(_r * _r - _p2);       // where the beam first touches it
    if (_t < 0 && _te < 0) return;            // behind the muzzle
    _te = max(0, _te);
    if (_te < laser_cast_t) { laser_cast_t = _te; laser_cast_hit = _i; }
};
/// Fires the laser for one frame along laser_angle: the beam stops at the first asteroid or enemy
/// it meets, else at the screen edge. Damage ramps with heat while it stays on one target.
beam_fire = function(_passive) { // not laser_fire: that name is the global bolt function in scr_enemies
    var _st  = global.stats;
    var _fps = game_get_speed(gamespeed_fps);
    var _md  = muzzle_dist(WPN.LASER);
    laser_passive = _passive;
    laser_x1 = x + lengthdir_x(_md, laser_angle);
    laser_y1 = y + lengthdir_y(_md, laser_angle);
    var _dx = dcos(laser_angle), _dy = -dsin(laser_angle);
    var _half = _st.laser_width * wpn_size(WPN.LASER) * oc_size() / 2;
    // Distance to the screen edge along the ray
    var _l = view_left(), _t = view_top(), _r = _l + view_w(), _b = _t + view_h();
    var _edge = infinity;
    if (_dx > 0.0001) _edge = min(_edge, (_r - laser_x1) / _dx); else if (_dx < -0.0001) _edge = min(_edge, (_l - laser_x1) / _dx);
    if (_dy > 0.0001) _edge = min(_edge, (_b - laser_y1) / _dy); else if (_dy < -0.0001) _edge = min(_edge, (_t - laser_y1) / _dy);
    if (_edge == infinity || _edge < 0) _edge = 0;
    laser_cast_t = _edge;
    laser_cast_hit = noone;
    var _me = id;
    with (obj_asteroid) if (!dead) _me.laser_consider(id, _dx, _dy, _half);
    with (obj_enemy)    if (!dead) _me.laser_consider(id, _dx, _dy, _half);
    var _hit = laser_cast_hit;
    laser_x2 = laser_x1 + _dx * laser_cast_t;
    laser_y2 = laser_y1 + _dy * laser_cast_t;
    laser_refr = [];
    // Heat: builds while the beam rests on the same target, resets when it moves on (passive ramps slower)
    if (_hit != laser_target) { laser_target = _hit; laser_heat = 0; }
    else if (_hit != noone) laser_heat = min(1, laser_heat + (_passive ? _st.pas_rof : 1) / (_st.laser_ramp * _fps));
    if (_hit == noone) return;
    var _dmg = _st.laser_dps / _fps * wpn_dmg(WPN.LASER) * oc_rof() * lerp(LASER_HEAT_MIN, 1, laser_heat) * (_passive ? _st.pas_rof : 1);
    var _is_rock = (_hit.object_index == obj_asteroid);
    // Armour melts off after enough contact (active laser faster than passive)
    if (_is_rock && _hit.armoured) {
        _hit.laser_melt += 1 / _fps;
        if (_hit.laser_melt >= (_passive ? LASER_MELT_PASSIVE : LASER_MELT_ACTIVE)) {
            _hit.armoured = false;
            repeat (3) fx_spark(_hit.x + random_range(-_hit.radius, _hit.radius), _hit.y + random_range(-_hit.radius, _hit.radius));
            sfx(snd_ricochet, 0.6, 0.6, 0.1);
        }
    }
    // Refraction: the lit rock splits the beam on to the nearest other rocks
    if (_is_rock && _st.laser_refract > 0) {
        var _done = [_hit];
        repeat (_st.laser_refract) {
            var _nx = noone, _nd = LASER_REFRACT_RANGE, _ex = laser_x2, _ey = laser_y2;
            with (obj_asteroid) {
                if (dead || array_contains(_done, id)) continue;
                var _d = point_distance(x, y, _ex, _ey) - radius;
                if (_d < _nd) { _nd = _d; _nx = id; }
            }
            if (_nx == noone) break;
            array_push(_done, _nx);
            array_push(laser_refr, [laser_x2, laser_y2, _nx.x, _nx.y]);
        }
        for (var i = 1; i < array_length(_done); i++) if (instance_exists(_done[i])) {
            dlog_wpn(WPN.LASER, _done[i], _dmg * LASER_REFRACT_SHARE); // balance log
            _done[i].take_hit(_dmg * LASER_REFRACT_SHARE, "laser");
        }
    }
    dlog_wpn(WPN.LASER, _hit, _dmg); // balance log
    if (_is_rock) _hit.take_hit(_dmg, "laser"); else _hit.take_hit(_dmg);
    // Sparks where it burns
    laser_spark--;
    if (laser_spark <= 0) { fx_spark(laser_x2, laser_y2); laser_spark = 5; }
};
/// Nearest loose pickup the tractor could grab (not carried, hauled or claimed by a ship), or noone.
target_loot = function() {
    var _best = noone, _bd = infinity, _me = id;
    with (obj_pickup) {
        if (carried || tractored || claimed_by != noone) continue;
        var _d = point_distance(x, y, _me.x, _me.y);
        if (_d < _bd) { _bd = _d; _best = id; }
    }
    return _best;
};
/// Live asteroid whose edge is nearest (_x, _y), within _r px of it, or noone.
target_near = function(_x, _y, _r) {
    var _best = noone, _bd = _r;
    with (obj_asteroid) {
        if (dead) continue;
        var _d = point_distance(x, y, _x, _y) - radius;
        if (_d < _bd) { _bd = _d; _best = id; }
    }
    with (obj_enemy) { // enemy collectors, hunters, attackers and the flagship can be struck too
        if (dead) continue;
        var _d = point_distance(x, y, _x, _y) - radius;
        if (_d < _bd) { _bd = _d; _best = id; }
    }
    return _best;
};
/// Rubber rocks soak up lightning (enemies have no rubber).
zap_rubber = function(_i) { return _i.object_index == obj_asteroid && _i.rubber; };
/// Lightning damage on asteroid or enemy (asteroids get the "zap" source for armour).
zap_hit = function(_i, _amount) {
    if (!instance_exists(_i)) return;
    if (zap_rubber(_i)) _amount *= RUBBER_ZAP;
    fx_spark(_i.x, _i.y);
    dlog_wpn(WPN.TESLA, _i, _amount); // balance log
    if (_i.object_index == obj_asteroid) _i.take_hit(_amount, "zap"); else _i.take_hit(_amount);
};
/// Biggest live on-screen asteroid (by radius), nearest the station on a tie, or noone.
target_biggest = function() {
    var _best = noone, _br = -1, _bd = infinity, _me = id;
    with (obj_asteroid) {
        if (dead || !in_view(x, y)) continue;
        var _d = point_distance(x, y, _me.x, _me.y);
        if (radius > _br || (radius == _br && _d < _bd)) { _br = radius; _bd = _d; _best = id; }
    }
    // Pirate System day: the biggest ship (the flagship once it's here), else the nearest one
    if (_best == noone && chart_current() == CHART.PIRATE) {
        with (obj_enemy) {
            if (dead || !in_view(x, y)) continue;
            var _d = point_distance(x, y, _me.x, _me.y);
            if (radius > _br || (radius == _br && _d < _bd)) { _br = radius; _bd = _d; _best = id; }
        }
    }
    return _best;
};

/// How many px thick side _i's shield line is right now (0 to SHIELD_PX_MAX, fractional).
shield_px = function(_i) {
    var _max = global.stats.max_shield;
    return (_max > 0) ? SHIELD_PX_MAX * shields[_i] / _max : 0;
};

gun_angle  = 90;
gun_aim    = 90;     // where the gun mount is heading (cursor when active, its target when passive)
gun_ready  = true;   // passive: lined up on a target, so it may fire
zap_angle  = 90;     // Tesla mount (phase 2 draws it; bolts still leave from the centre)
rail_angle = 90;     // rail gun mount: its own barrel now, firing alongside the gun
rail_aim   = 90;
tr_dir     = 90;     // tractor cone heading (follows the cursor on its own mount)
rail_recoil = 0;
rail_muzzle = 0;
zap_recoil  = 0;
zap_muzzle  = 0;
// Laser: beam state, rebuilt every frame it fires (drawn in Draw)
laser_angle  = 90;
laser_aim    = 90;
laser_on     = false;
laser_passive = false;
laser_x1 = 0; laser_y1 = 0; laser_x2 = 0; laser_y2 = 0;
laser_target = noone;  // what the beam is resting on (heat builds while this stays the same)
laser_heat   = 0;      // 0..1: how far up the damage ramp
laser_refr   = [];     // refracted beams this frame: [[x1, y1, x2, y2], ...]
laser_spark  = 0;
laser_cast_t = 0;      // raycast scratch (laser_consider)
laser_cast_hit = noone;
laser_firing = false;  // on/off cycle: beam phase or cool-down phase
laser_cycle  = 0;      // frames left in the current phase
laser_offset = 0;
// Passive targets, re-picked every TARGET_SCAN frames (scanning every rock every frame was costly)
gun_tgt = noone; zap_tgt = noone; laser_tgt = noone; rail_tgt = noone;
scan_tick = 0;
/// True if _t is still a live asteroid worth aiming at.
tgt_ok = function(_t) { return instance_exists(_t) && !_t.dead; };      // degrees off the aim, rolled from the Accuracy cone when each beam starts
recoil      = 0;  // px the barrel is pushed back (springs forward)
muzzle      = 0;  // muzzle flash frames left
shot_size   = 1;  // muzzle flash scale for the main gun, from bullet size (fire_volley)
fire_timer = 0;
burst_left = 0;
burst_timer = 0;

/// _side = which octagon side was struck (station_hull_side). Only that side's shield
/// absorbs it; -1 goes straight to the hull.
take_damage = function(_dmg, _side = -1, _src = "other") {
    if (dead) return;
    if (instance_exists(obj_game)) { // balance log: total, and by source
        obj_game.dlog.dmg_in += _dmg;
        obj_game.dlog.dmg_src[$ _src] = (obj_game.dlog.dmg_src[$ _src] ?? 0) + _dmg;
    }
    if (oc_active()) { // Overcharge: untouchable, hits just spark off
        if (_side >= 0) shield_hit[_side] = 6;
        sfx(snd_shield_hit, 0.4, 1.4, 0.1);
        return;
    }
    // Only hits on a side's shield restart its recharge wait. Once it's down, hull hits
    // don't hold it back: it comes back on its own timer whatever state the hull is in.
    if (_side >= 0 && shields[_side] > 0) {
        shield_wait[_side] = 0;
        shield_hit[_side]  = 6;
        var _absorb = min(shields[_side], _dmg);
        shields[_side] -= _absorb;
        shield         -= _absorb;
        _dmg           -= _absorb;
    }
    if (_dmg <= 0) {
        sfx(snd_shield_hit, 0.6);
        screen_shake(1.5);
        return;
    }
    _dmg *= (1 - global.stats.armour);
    // Hull sections: a broken side lets the hit through harder; otherwise the side wears down.
    // Hits with no side (-1) wear every side a little.
    if (_side >= 0) {
        if (hull_sec[_side] <= 0) _dmg *= HULL_BREACH_MULT;
        else wear_section(_side, _dmg);
        hull_hit[_side] = 8;
    } else {
        for (var i = 0; i < SHIELD_SIDES; i++) { wear_section(i, _dmg / SHIELD_SIDES); hull_hit[i] = 8; }
    }
    if (instance_exists(obj_game)) obj_game.dlog.hull_lost += min(_dmg, hp);
    var _low = global.stats.max_hp * 0.25;
    var _was_ok = (hp >= _low);
    hp -= _dmg;
    if (_was_ok && hp < _low && hp > 0) sfx(snd_alarm_chime, 0.8, 1, 0); // hull just dropped below 25% (the alarm loop takes over in Step)
    hurt_flash = 8;
    fx_hurt(x, y);
    if (hp <= 0) {
        hp = 0;
        dead = true;
        sfx(snd_station_destroyed, 1, 1, 0);
        hit_stop(12);
        screen_flash(0.6, HUD_HULL);
        music_sting("mus_sting_lose");
        music_duck(0.15, 90);
        screen_shake(SHAKE_MAX);
        with (obj_game) end_day("Station destroyed");
    } else {
        sfx(snd_station_hit, 0.8);
        hit_stop(4);
        screen_shake(2 + _dmg * 0.25); // bigger hits shake harder
    }
};

zap_timer = 30;

/// Chain lightning. Passive: hits _first (the rock nearest the station). Active: strikes the
/// point (_sx, _sy) near the cursor and hits whatever rock is there, or nothing (a miss).
/// A hit bounces to the nearest un-hit asteroid within zap_jump, up to zap_chains times.
/// _passive draws a thinner bolt.
fire_zap = function(_first, _passive = false, _sx = undefined, _sy = undefined) {
    var _st = global.stats;
    if (_sx == undefined && !instance_exists(_first)) return false;
    // Bolts leave from the barrel tip when active, the triangle's tip when passive
    var _zd = muzzle_dist(WPN.TESLA);
    var _tx = x + lengthdir_x(_zd, zap_angle), _ty = y + lengthdir_y(_zd, zap_angle);
    zap_recoil = 4;
    zap_muzzle = 4;
    if (_sx != undefined) fx_blast(_sx, _sy, ZAP_SPLASH); // active strike: shows the splash it deals
    if (!instance_exists(_first)) { // active strike into empty space: the bolt still lands
        var _zm = instance_create_layer(x, y, "Instances", obj_zap);
        _zm.points = [[_tx, _ty], [_sx, _sy]];
        sfx(snd_zap, 0.4, 1.1);
        return true;
    }

    var _hits = [_first];
    var _pts  = [[_tx, _ty], [_sx ?? _first.x, _sy ?? _first.y]];
    var _cur  = _first;
    var _left = _st.zap_chains + (oc_active() ? _st.oc_zap_chains : 0);
    if (zap_rubber(_first)) _left = floor(_left * RUBBER_ZAP); // rubber soaks up the arc: half the bounces carry on
    while (_left > 0) {
        _left--;
        var _next = noone, _nd = _st.zap_jump, _cx = _cur.x, _cy = _cur.y;
        with (obj_asteroid) {
            if (!dead && !array_contains(_hits, id)) {
                var _d = point_distance(x, y, _cx, _cy);
                if (_d < _nd) { _nd = _d; _next = id; }
            }
        }
        with (obj_enemy) { // the arc jumps to enemy ships as well
            if (!dead && !array_contains(_hits, id)) {
                var _d = point_distance(x, y, _cx, _cy);
                if (_d < _nd) { _nd = _d; _next = id; }
            }
        }
        if (_next == noone) break;
        array_push(_hits, _next);
        array_push(_pts, [_next.x, _next.y]);
        _cur = _next;
        if (zap_rubber(_next)) _left = floor(_left * RUBBER_ZAP);
    }

    // Damage after the chain is built, since hits can destroy and split asteroids
    var _dmg = _st.zap_damage * wpn_dmg(WPN.TESLA) * (oc_active() ? _st.oc_zap_mult : 1);
    // Active strike splash: every other rock within ZAP_SPLASH of where it landed takes a share
    if (_sx != undefined) {
        var _splash = [];
        with (obj_asteroid) {
            if (!dead && !array_contains(_hits, id) && point_distance(x, y, _sx, _sy) - radius < ZAP_SPLASH) array_push(_splash, id);
        }
        with (obj_enemy) {
            if (!dead && !array_contains(_hits, id) && point_distance(x, y, _sx, _sy) - radius < ZAP_SPLASH) array_push(_splash, id);
        }
        for (var i = 0; i < array_length(_splash); i++) zap_hit(_splash[i], _dmg * ZAP_SPLASH_SHARE);
    }
    for (var i = 0; i < array_length(_hits); i++) zap_hit(_hits[i], _dmg); // half through armour, half into rubber
    var _z = instance_create_layer(x, y, "Instances", obj_zap);
    _z.points = _pts;
    _z.width *= wpn_size(WPN.TESLA);
    sfx(snd_zap, 0.5);
    screen_shake(1);
    return true;
};

fire_volley = function() {
    var _st = global.stats;
    var _passive = (wpn_active() != WPN.GUN);
    // Meatiness follows bullet size (Bullet Size, Overcharge): deeper and louder shot,
    // harder barrel kick, bigger flash, and a nudge to the screen once rounds are big
    var _bs = _st.bullet_scale * oc_size() * wpn_size(WPN.GUN);
    sfx(snd_shoot, 0.35 * power(_bs, 0.4), power(_bs, -0.35), 0.1); // once per volley, not per bullet
    recoil = max(recoil, 4 * power(_bs, 0.6));
    muzzle = 3;
    shot_size = power(_bs, 0.7);
    if (_bs > 1) screen_kick(gun_angle + 180, 0.4 * (_bs - 1));
    var _md = muzzle_dist(WPN.GUN); // barrel tip when active, hexagon tip when passive
    var _mx = x + lengthdir_x(_md, gun_angle);
    var _my = y + lengthdir_y(_md, gun_angle);
    var _spr = wpn_spread(WPN.GUN) + gun_breach_spread(); // firing over a broken side throws shots wide
    var _dir = gun_angle + random_range(-_spr / 2, _spr / 2);
    var _b = instance_create_layer(_mx, _my, "Instances", obj_bullet);
    _b.vx = lengthdir_x(_st.bullet_speed, _dir);
    _b.vy = lengthdir_y(_st.bullet_speed, _dir);
    _b.damage = _st.bullet_damage * wpn_dmg(WPN.GUN);
    _b.image_xscale = _bs;
    _b.image_yscale = _bs;
    _b.radius = 2 * _bs;
    _b.image_angle = _dir;
    _b.ricochets = _st.ricochet; // Harder Bullets
    _b.track = 1; // balance log: main turret accuracy
    if (instance_exists(obj_game)) obj_game.dlog.shots += 1;
};

// --- Extra weapons ------------------------------------------------------------
rail_timer = 30;
rep_timer  = 60;
tr_timer   = 0;     // frames left in the current tractor phase
tr_on      = true;  // tractor cone is beaming (on/off cycle unless it's always on)
tr_target  = noone; // loot the cone is turning towards (re-picked every few frames)
tr_scan    = 0;

/// Rail gun: one huge piercing slug down its own barrel (rail_angle). Passive: half-width
/// slug and a lighter kick.
fire_rail = function() {
    var _st = global.stats;
    var _passive = (wpn_active() != WPN.RAIL);
    var _md = muzzle_dist(WPN.RAIL); // barrel tip when active, square's front side when passive
    var _r = instance_create_layer(x + lengthdir_x(_md, rail_angle), y + lengthdir_y(_md, rail_angle), "Instances", obj_rail);
    var _wob  = gun_breach_spread(rail_angle) / 4; // over a broken side the slug wobbles off line
    _r.dir    = rail_angle + random_range(-_wob, _wob);
    _r.damage = _st.rail_damage * wpn_dmg(WPN.RAIL) * (_passive ? RAIL_PASSIVE_DAMAGE : 1);
    _r.width  = MOUNT_RAIL_SIDE * oc_size() * (_passive ? _st.pas_size : 1); // hit radius: the path is as wide as the square (passive: Passive Calibre, half at rank 0)
    _r.falloff = min(0.95, _st.rail_falloff * (_passive ? RAIL_PASSIVE_FALLOFF : 1));
    sfx(snd_rail, _passive ? 0.5 : 0.8, 1, 0.05);
    screen_shake(_passive ? 1.5 : 3);
    rail_recoil = 14;
    rail_muzzle = 6;
    screen_kick(rail_angle + 180, _passive ? 4 : 10); // recoil
};

/// Tractor cone: while on, every loose pickup inside the cone is caught and hauled home.
tractor_beam = function() {
    var _st = global.stats;
    var _me = id;
    with (obj_pickup) {
        if (carried || tractored || claimed_by != noone) continue;
        if (point_distance(_me.x, _me.y, x, y) > _st.tr_range) continue;
        if (abs(angle_difference(point_direction(_me.x, _me.y, x, y), _me.tr_dir)) > _st.tr_angle) continue;
        tractored = true; // obj_pickup flies it home and banks it
        tr_spd = 1;
        if (instance_exists(targeted_by)) targeted_by.retarget_timer = 0; // that ship should look elsewhere
        targeted_by = noone;
    }
};

/// Freeze ray: a thin icy blast from the station's edge at the nearest on-screen rock that's
/// heading in and not frozen yet. No damage: the rock loses part of its speed (freeze_hit).
/// Returns false if there was nothing to blast.
frz_timer = 30;
frz_show  = 0;   // frames left drawing the last blast
frz_x1 = 0; frz_y1 = 0; frz_x2 = 0; frz_y2 = 0;
fire_freeze = function() {
    var _best = noone, _bd = infinity, _me = id;
    with (obj_asteroid) {
        if (dead || !in_view(x, y)) continue;
        if (chill >= (is_boss ? FREEZE_BOSS_MAX : 1) - 0.001) continue;
        // incoming only: moving towards the station (the dot of its heading and the way home)
        if (vx * (_me.x - x) + vy * (_me.y - y) <= 0) continue;
        var _d = point_distance(_me.x, _me.y, x, y);
        if (_d < _bd) { _bd = _d; _best = id; }
    }
    if (_best == noone) return false;
    var _dir = point_direction(x, y, _best.x, _best.y);
    frz_x1 = x + lengthdir_x(STATION_RADIUS, _dir);
    frz_y1 = y + lengthdir_y(STATION_RADIUS, _dir);
    frz_x2 = _best.x;
    frz_y2 = _best.y;
    frz_show = FREEZE_SHOW;
    _best.freeze_hit();
    sfx(snd_ice_beam, 0.4, 1, 0.05);
    return true;
};

/// Repulsor pulse: a ring that expands all the way round the station.
/// With Double Pulse a second ring follows REP_ECHO frames later.
#macro REP_ECHO 14
rep_echo = 0;
fire_wave = function(_echo = false) {
    var _st = global.stats;
    var _w = instance_create_layer(x, y, "Instances", obj_wave);
    _w.range   = _st.rep_range;
    _w.deflect = _st.rep_deflect;
    sfx(snd_repulsor, _echo ? 0.3 : 0.5, _echo ? 1.15 : 1, 0.05); // the echo is a lighter, higher copy
    if (!_echo && _st.rep_double) rep_echo = REP_ECHO;
};

// Your fighters: launch themselves, hunt enemies, rebuild inside the station when shot down
repeat (_st.fighters) instance_create_layer(x, y, "Instances", obj_fighter);

// Guard drones, spread evenly around the orbit
for (var i = 0; i < _st.drones; i++) {
    var _d = instance_create_layer(x, y, "Instances", obj_drone);
    _d.orbit_angle = i * 360 / _st.drones;
}

// Repair drones: tiny dots (spr_repair_drone) that buzz in and around the station while
// it's mending. Positions are offsets from the station centre. Moved in Step, drawn in Draw.
#macro REPAIR_BOTS_PER_RANK 3     // dots per 0.5 hp/s of regen
#macro REPAIR_BOTS_MAX      12
#macro REPAIR_BOT_RANGE     1.3   // how far out they wander, x STATION_RADIUS
#macro REPAIR_BOT_SPEED     1.6   // top speed, px/frame
repair_bots = [];
