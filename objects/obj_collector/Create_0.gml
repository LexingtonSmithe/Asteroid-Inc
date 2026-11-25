/// Collection ship. Launches towards the cursor and steers itself to loot (see find_target:
/// close and ahead of it first, and it leaves loot near the station to the tractor beam).
/// Heads home when full, once it holds a special drop, or when there's nothing left to collect; if new loot appears
/// on the way home (and it isn't full or recalled) it turns back to collect it.
/// Right click recalls it for good. Ignores asteroids entirely.
/// Cargo is lost if the day ends before it docks.
depth = -10;
image_speed = 0; // frame 0 = outline, frame 1 = fill (drawn by cargo)
var _st = global.stats;
spd      = _st.ship_speed;
capacity = _st.capacity;
magnet   = _st.magnet;
magnet_tick = irandom(2); // the loot grab scans every 3rd frame, ships staggered (performance)
turn_rate = max(6, spd * 3); // degrees per frame; scales with speed so it never orbits its target

state = "harvest"; // "harvest" -> "return"
dir = point_direction(STATION_X, STATION_Y, mouse_x, mouse_y); // initial heading
image_angle = dir - SHIP_ART_ANGLE;
target = noone;          // pickup we're steering towards
retarget_timer = 0;
cargo = array_create(RES.COUNT, 0);
cargo_free = array_create(RES.COUNT, 0); // the part of cargo that came from special drops
cargo_total = 0;
incoming = 0;            // pickups claimed and flying towards us
idle_frames = 0;         // frames spent with nothing to collect
recalled = false;        // right-click recall: go straight home, no detours
orbit = 0;               // spins the visible cargo cluster
full_flash = 0;          // blinks the ship when the hold fills
has_special = false;     // carrying a special drop (Core, chart token): head straight home

// Hull and shield: enemy hunters go after collectors. Destroyed, the ship explodes and
// scatters everything it carried; its slot rebuilds at the station (obj_game.ship_lost).
#macro SHIP_SHIELD_DELAY  180   // frames without a hit before the shield recharges
#macro SHIP_SHIELD_REGEN  0.2   // fraction of max shield per second while recharging
#macro SHIP_SCATTER_MIN   5     // px/frame: loot from a wrecked ship flies out this fast...
#macro SHIP_SCATTER_MAX   14    // ...up to this (drag 0.95 -> travels about 20x its speed)
dead = false;
max_hp = _st.ship_hp;
hp = max_hp;
max_shield = _st.ship_shield;
shield = max_shield;
shield_delay = 0;
flash = 0;

take_hit = function(_dmg) {
    if (dead) return;
    flash = 4;
    shield_delay = SHIP_SHIELD_DELAY;
    if (shield > 0) {
        var _a = min(shield, _dmg);
        shield -= _a;
        _dmg -= _a;
        if (_dmg <= 0) { sfx(snd_shield_hit, 0.3, 1.4, 0.1); return; }
    }
    hp -= _dmg;
    if (hp <= 0) destroyed();
};

/// Blown apart: cargo (in the hold and still being reeled in) sprays out over a wide area.
destroyed = function() {
    dead = true;
    var _me = id;
    with (obj_pickup) {
        if (claimed_by != _me) continue;
        claimed_by = noone;
        targeted_by = noone;
        carried = false;
        pull_spd = 1;
        image_xscale = 1;
        image_yscale = 1;
        var _a = random(360), _s = random_range(SHIP_SCATTER_MIN, SHIP_SCATTER_MAX);
        vx = lengthdir_x(_s, _a);
        vy = lengthdir_y(_s, _a);
        age = 0; // replay the spawn pop
    }
    fx_hurt(x, y);
    fx_spark(x, y);
    fx_break(x, y, AST.MEDIUM, RES.ORE);
    sfx(snd_ship_destroyed, 0.6, 1.1, 0.05);
    screen_shake(4);
    hit_stop(4);
    float_text(x, y - 30, "Ship lost", make_colour_rgb(255, 80, 80), 1.4);
    if (instance_exists(obj_game)) obj_game.ship_lost();
    instance_destroy();
};

add_cargo = function(_r, _v = 1, _free = false) {
    cargo[_r] += _v;
    if (_free) cargo_free[_r] += _v; // special drop: the rebuild fee never takes it
    cargo_total += _v;
    incoming = max(0, incoming - _v);
    if (res_special(_r)) has_special = true; // don't risk it: bring it home now
    if (cargo_total >= capacity || has_special) full_flash = 30;
};

/// Turn towards a point (limited turn rate) and fly forward.
steer_to = function(_tx, _ty) {
    var _want = point_direction(x, y, _tx, _ty);
    dir += clamp(angle_difference(_want, dir), -turn_rate, turn_rate);
    var _s = min(spd, point_distance(x, y, _tx, _ty));
    x += lengthdir_x(_s, dir);
    y += lengthdir_y(_s, dir);
    image_angle = dir - SHIP_ART_ANGLE;
};

release_target = function() {
    if (instance_exists(target) && target.targeted_by == id) target.targeted_by = noone;
    target = noone;
};

recall = function() {
    release_target();
    recalled = true;
    state = "return";
};

// Target scoring: lowest "cost" wins. Cost = distance from the ship, made worse by
//  - how far it has to turn (no sharp U-turns while there's loot ahead),
//  - lying inside the tractor's reach (the beam will haul it; ships work further out),
// and made better for the current target (stops it flip-flopping between two pickups).
#macro SHIP_TURN_COST   1.5   // a pickup directly behind costs 1 + this times its distance
#macro SHIP_INNER_COST  2.5   // x cost for loot the tractor can reach (only once you own it)
#macro SHIP_KEEP_BONUS  0.6   // x cost for the pickup we're already chasing

/// Best loot to chase that isn't being pulled in, tractored, or another ship's target.
/// Special drops (boss Cores, star chart tokens) come before everything: the nearest
/// loose one, and several ships may chase it.
find_target = function() {
    var _me = id;
    var _best = noone;
    var _bc = infinity;
    with (obj_pickup) {
        if ((!res_special(res) && !magnet) || claimed_by != noone || tractored) continue; // Magnets share top priority
        var _d = point_distance(_me.x, _me.y, x, y);
        if (_d < _bc) { _bc = _d; _best = id; }
    }
    if (_best != noone) return _best;
    _bc = infinity;
    var _inner = global.stats.tractor ? global.stats.tr_range * 0.7 : 0;
    with (obj_pickup) {
        if (claimed_by != noone || tractored) continue;
        if (targeted_by != noone && targeted_by != _me && instance_exists(targeted_by)) continue;
        var _d = point_distance(_me.x, _me.y, x, y);
        var _turn = abs(angle_difference(point_direction(_me.x, _me.y, x, y), _me.dir)) / 180;
        var _c = _d * (1 + SHIP_TURN_COST * _turn);
        if (point_distance(x, y, STATION_X, STATION_Y) < _inner) _c *= SHIP_INNER_COST;
        if (id == _me.target) _c *= SHIP_KEEP_BONUS;
        if (_c < _bc) { _bc = _c; _best = id; }
    }
    return _best;
};

// Charged Collectors: a small Tesla zap at whatever is closest, enemies first (they're the
// ones chasing it), so ships can fight back before Fighters are unlocked.
gun_timer = irandom(20);
#macro SHIP_ZAP_RANGE    200   // px from the ship
#macro SHIP_ZAP_DAMAGE   2     // base, x Zap Damage and the Amplifier
#macro SHIP_ZAP_INTERVAL 60    // frames between zaps at base (Zap Recharge shortens it)

/// Zaps the nearest enemy in range, else the nearest rock. False if there's nothing.
fire_zap = function() {
    var _me = id, _best = noone, _bd = SHIP_ZAP_RANGE;
    with (obj_enemy) {
        if (dead) continue;
        var _d = point_distance(x, y, _me.x, _me.y);
        if (_d < _bd) { _bd = _d; _best = id; }
    }
    if (_best == noone) {
        _bd = SHIP_ZAP_RANGE;
        with (obj_asteroid) {
            if (dead) continue;
            var _d = point_distance(x, y, _me.x, _me.y) - radius;
            if (_d < _bd) { _bd = _d; _best = id; }
        }
    }
    if (_best == noone) return false;
    var _st = global.stats;
    var _z = instance_create_layer(x, y, "Instances", obj_zap);
    _z.points = [[x, y], [_best.x, _best.y]];
    fx_spark(_best.x, _best.y);
    dps_hit(false, _best, _st.ship_zap_damage * _st.dmg_mult); // Combat HUD: collectors are passive
    if (_best.object_index == obj_asteroid) _best.take_hit(_st.ship_zap_damage * _st.dmg_mult, "zap");
    else _best.take_hit(_st.ship_zap_damage * _st.dmg_mult);
    sfx(snd_zap, 0.2, 1.4, 0.1);
    return true;
};
