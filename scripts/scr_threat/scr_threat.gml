// ---------------------------------------------------------------------------
// Threat: everything that makes asteroids harder over time, and the rewards for it.
//   - In-day ramp: each day starts calm and gets more dangerous every second.
//     It's based on time elapsed (not fraction of the day), so days stretched
//     by time bonuses keep getting harder: that's what stops them running forever.
//   - Overcharge: destroying things earns charge points that fill the charge meter; a full
//     meter readies Overcharge. It doesn't make asteroids harder: only tier does.
//   - Bosses and swarms: a per-tier schedule (day_schedule). The last boss is the tier boss while
//     it's due (it drops Cores); the rest drop loot. Beating the tier boss raises the
//     tier: a big step up in toughness and rewards, and new tree nodes unlock.
// Upgrade effects live in scr_upgrades; this file is the other side of the scale.
// ---------------------------------------------------------------------------

#macro AST_SPEED_MULT 1.6    // base asteroid speed multiplier (so they reach you within a day)
#macro TRACTOR_ON     120    // frames the tractor cone stays on each cycle (see tr_pause)
#macro RAMP_TIME      50     // seconds for the ramp to reach 1; it keeps climbing after that
#macro RAMP_HP        0      // per RAMP_TIME, asteroid HP gain (off 25/11/2026: toughness is set by the tier, the day ramps the numbers)
#macro AST_HP_FLAT    1      // flat rock toughness, all day (1.5 on 25/11/2026 was too tough from the first second)
#macro RAMP_SPAWN     0.6    // per RAMP_TIME, rocks spawn +60% as often (was 0.4: days now build more pressure towards the swarms)...
#macro RAMP_SPEED     0.3    // ...and move +30% faster...
#macro RAMP_SPEED_MAX 1.5    // ...up to this (otherwise late-day rocks reach the station before you can react)

// Time bonuses: banking cargo during a day extends it (see obj_game.add_banked)
#macro TIME_QUOTA_STEP 11    // first time bonus each day needs this x tier SQUARED (tier 1: 11, 2: 44, 3: 99, 4: 176): Lure and the time nodes decide which bosses you see...
#macro TIME_QUOTA_GROWTH 0.35 // ...and each later bonus that day costs this much more than the one before (Extended Contract slows it).
                              // Lower growth makes income (Lure, DPS, logistics) count for more; higher makes every day end about the same.
                              // No cap: late in a long day bonuses get out of reach, and the clock wins
#macro TIME_ABSORB    2      // seconds a time bonus takes to soak into the clock, 1s blast at a time (the clock holds meanwhile)

// Asteroid toughness, speed, impact and drops scale with tier (and the in-day ramp) only.

#macro TIER_MAX       9      // tier 1 + Ice + Crystal + Platinum + 5 Jump Drive levels
#macro JUMP_DRIVES_ON false  // Jump Drives switched off for now (kept for a future endless mode): hidden on the tree,
                             // not counted towards the tier, and no Cores are dropped for them. Set true to bring them back
#macro TIER_HP        2.2    // per tier (compounding)
#macro TIER_SPAWN     0.75   // x spawn rate per tier (compounding): each new sector's Lure nodes buy the field back (was 0.9: Lure I alone carried tier 3)
#macro TIER_SPEED     1.12   // per tier (compounding)
#macro TIER_BIG       0.06   // +6% chance per tier that a spawn is large (more pieces, more HP)
#macro TIER_IMPACT    1.25
#macro TIER_REWARD    0.6    // +60% drops per tier (additive)

// The singularity ending: survive this long in one day and your hoard collapses into a black hole
#macro ENDING_TIME     300   // seconds into the day (5:00)
#macro ENDING_HOLE     3     // the hole is this many times a normal black hole's core
#macro ENDING_GROW     2     // seconds for it to open fully
#macro ENDING_FADE_AT  4     // seconds in, the screen starts fading to black...
#macro ENDING_FADE     2.5   // ...over this long
#macro ENDING_TEXT_AT  7     // then the message fades in
#macro ENDING_CLICK_AT 10    // and from here a click (or Space / Enter) moves on
// Day schedule (day_schedule): bosses and swarms at set times, a different pattern per tier
enum EVT { SWARM, BOSS, TIER_BOSS }
#macro SWARM_TIME     10     // seconds a swarm lasts...
#macro SWARM_SPAWN    3      // ...spawning this many times as fast...
#macro SWARM_ROCK_CAP 200    // ...but adding no more once this many rocks are on screen (performance)
#macro SWARM_LOOT     0.34   // swarm rocks (and their fragments) drop this share of the usual loot
#macro SWARM_WARN     2      // seconds of warning (sound and text) before a swarm
#macro BOSS_TRAIT_TIER 4     // from this tier every boss carries a random modifier
#macro BOSS_GROW      1.5    // each boss that day is this much bigger and tougher than the one before
#macro BOSS_HP        400    // tier 1 boss HP before scaling
#macro BOSS_IMPACT    30
#macro BOSS_SCALE     8      // x the 32 px asteroid sprite = 256 px
#macro BOSS_LOOT      25     // pickups per tier when a boss breaks
// Each boss also drops `tier` Cores (1, then 2, then 3...). Cores pay for the
// Ice / Crystal / Platinum unlocks, so beating bosses is how you progress.
#macro BOUNCE_KEEP    0.75   // speed kept when an asteroid bounces off the station

// Charge points needed to fill the charge meter scale with how built-up the station is, not tier:
// CHARGE_BASE plus CHARGE_PER_UPG for every upgrade level owned across the tree. A stronger station
// kills more, so the meter keeps filling at roughly the same pace as you grow.
#macro CHARGE_BASE    80
#macro CHARGE_PER_UPG 20
function charge_needed() { return round(CHARGE_BASE + CHARGE_PER_UPG * upg_owned_total()); }

// --- Overcharge ------------------------------------------------------------------
// A full charge meter readies Overcharge. While it's ready no charge is earned, so use it:
// SPACE (or middle mouse) fires it for oc_duration seconds of faster, bigger shots,
// a free Tesla Coil (or a stronger one), and hull repair and shield recharge at full rate.
#macro OC_COLOUR     make_colour_rgb(90, 230, 255)
function oc_active() { return instance_exists(obj_game) && obj_game.oc_timer > 0; }
function oc_rof()    { return oc_active() ? global.stats.oc_rof  : 1; } // fire-rate multiplier
#macro OC_FREEZE_COLOUR make_colour_rgb(110, 180, 255) // thin outline on rocks held still by Overcharge
/// Overcharge also freezes every asteroid in place (still hittable); they carry on along their old vectors after.
function oc_freeze() { return oc_active(); }
function oc_size()   { return oc_active() ? global.stats.oc_size : 1; } // bullet size multiplier

/// Threat ramp: 0 at the start of a day, 1 after RAMP_TIME seconds, and still rising after that.
function day_progress() { return instance_exists(obj_game) ? obj_game.day_progress : 0; }

function threat_hp_mult(_with_ramp = true) {
    var _m = power(TIER_HP, threat_tier() - 1);
    return _with_ramp ? _m * AST_HP_FLAT * (1 + RAMP_HP * day_progress()) : _m; // _with_ramp: rocks (and damage scaled to them); bosses and ships use the tier alone
}
function threat_speed_mult()  { return AST_SPEED_MULT * power(TIER_SPEED, threat_tier() - 1) * min(RAMP_SPEED_MAX, 1 + RAMP_SPEED * day_progress()); }
function threat_spawn_mult()  { return power(TIER_SPAWN, threat_tier() - 1) * (1 + RAMP_SPAWN * day_progress()) * cluster_spawn_mult(); } // (the old boss-beaten 3x surge went: bosses now come every day)


/// Today's bosses and swarms: [[seconds, EVT.*, tier], ...] in time order. The same every day:
///   boss 1:30 (tier 2), swarm 2:00 (tier 2), boss 3:00 (tier 3), swarm 3:30 (tier 3),
///   boss 4:00 (tier 4), swarm 4:30 (tier 4), singularity 5:00
/// Swarm: its tier is a floor that quietly raises today's difficulty (threat_tier) for the rest of the day.
/// Boss: always drops loot; it also drops Cores (boss_core_drop) only if you hold none and haven't yet
/// reached its tier, so Cores can't be farmed.
function day_schedule() {
    return [[90, EVT.BOSS, 2], [120, EVT.SWARM, 2], [180, EVT.BOSS, 3], [210, EVT.SWARM, 3],
            [240, EVT.BOSS, 4], [270, EVT.SWARM, 4]];
}

/// Cores you have anywhere: banked, loose on screen, or in a ship's hold.
function cores_held() {
    var _n = global.bank[RES.CORE];
    with (obj_pickup) if (res == RES.CORE && !magnet) _n += value;
    with (obj_collector) _n += cargo[RES.CORE];
    return _n;
}

/// Cores a boss for tier _target drops: enough for the next tier unlock, but only when you hold
/// none and are still below _target. Otherwise 0 (it just drops loot).
function boss_core_drop(_target) {
    if (cores_held() > 0 || global.tier >= _target) return 0;
    return max(1, cores_for_next_tier());
}

/// Tier the asteroids are tough to today: the real tier, or a swarm's floor if that's higher (rewards
/// stay at the real tier).
function threat_tier() {
    var _f = instance_exists(obj_game) ? obj_game.day_tier_floor : 0;
    return max(global.tier, _f);
}

/// Seconds into the day the singularity ending comes: always 5:00.
function ending_time() { return ENDING_TIME; }

/// Seconds into the day of today's first boss (music riser), or a huge number if there's none.
function boss_time() {
    var _s = day_schedule();
    for (var i = 0; i < array_length(_s); i++) if (_s[i][1] != EVT.SWARM) return _s[i][0];
    return 99999;
}

/// One boss per tier: once it's beaten it doesn't return until the tier goes up.
/// Safety net: if its Cores were lost (raided, or never docked) and you can't afford
/// the next tier unlock, the boss comes back on a later day.
function boss_due() {
    if (global.tier >= TIER_MAX) return false;
    return global.boss_tier < global.tier || global.bank[RES.CORE] < cores_for_next_tier();
}

/// Cores the next tier unlock costs (Ice, Crystal, Platinum, then Jump Drive levels).
function cores_for_next_tier() {
    static _ids = ["unlock_ice", "unlock_crystal", "unlock_platinum", "jump_drive", "jump_drive2", "jump_drive3", "jump_drive4", "jump_drive5"];
    var _n = JUMP_DRIVES_ON ? array_length(_ids) : 3; // switched off: Ice, Crystal and Platinum only
    for (var i = 0; i < _n; i++) {
        var _u = upg_get(_ids[i]);
        if (_u == undefined || upg_maxed(_u)) continue;
        var _c = upg_cost(_u);
        for (var j = 0; j < array_length(_c); j++) if (_c[j][0] == RES.CORE) return _c[j][1];
        return 0;
    }
    return 0;
}

function threat_impact_mult() { return power(TIER_IMPACT, threat_tier() - 1); }
function threat_reward_mult() { return (1 + TIER_REWARD * (global.tier - 1)) * chart_reward_mult(); }

/// Rounds a fractional amount randomly (2.3 -> 2 or 3, averaging 2.3).
function round_random(_v) { var _f = floor(_v); return _f + (random(1) < _v - _f ? 1 : 0); }

// --- Bonus charge -----------------------------------------------------------------
// Comets, special rocks (any trait), enemy ships and bosses pay extra charge on top of the
// usual: a burst of purple orbs flies from the kill into the charge meter and the charge
// lands with them. Amounts are a share of a full meter, so they stay useful.
#macro CHARGE_BONUS_COMET    0.15  // comet (the "meteor" you can shoot)
#macro CHARGE_BONUS_SPECIAL  0.0125 // special rock, x (size + 1): tiny 1.25%, large 5% (halved 22/11/2026: trait days kept Overcharge up nonstop)
#macro CHARGE_BONUS_ENEMY    0.12  // any enemy ship
#macro CHARGE_BONUS_BOSS     0.4   // asteroid boss or pirate flagship
#macro CHARGE_ORB_COLOUR     make_colour_rgb(190, 120, 255)

/// Does this rock carry a trait? (A Gold System gilds every rock, so gilded doesn't count there.)
function ast_is_special(_a) {
    with (_a) return rubber || explosive || armoured || sticky || magnetic || charged || glass
                  || occupied || warp || dense || (gilded && chart_current() != CHART.GOLD);
    return false;
}

/// Bonus charge from a kill at world position _x, _y: _frac of a full meter, carried by orbs.
function charge_bonus(_x, _y, _frac) {
    if (global.oc_ready || oc_active() || !instance_exists(obj_game)) return; // ready or running: no charge
    var _amt = _frac * charge_needed();
    with (obj_game) charge_orbs_spawn(_x, _y, _amt, clamp(round(_frac * 60), 3, 16));
}

/// Charge points come from the base HP of what you destroy, so bigger rocks are worth more.
/// _bonus = true when it's bonus charge arriving with its orbs (the meter reacts to those itself).
function add_charge(_amount, _bonus = false) {
    // No charge while Overcharge is ready (use it first) or running (it starts the meter from empty)
    if (global.oc_ready || oc_active()) return;
    global.charge += _amount;
    if (!_bonus && instance_exists(obj_game)) obj_game.hud_charge_jig = 1; // regular charge: the meter jiggles a little
    if (global.charge < charge_needed()) return;
    global.charge = 0;           // meter full: Overcharge is ready
    global.oc_ready = true;
    if (instance_exists(obj_game)) obj_game.hud_orbs = []; // orbs still flying would refill it
    if (instance_exists(obj_station)) {
        float_text(STATION_X, STATION_Y - STATION_RADIUS - 70, "OVERCHARGE READY", OC_COLOUR, 2.8);
    }
    sfx(snd_level_up, 0.6, 1, 0);
    if (instance_exists(obj_game)) obj_game.hud_charge_flash = 1;
}

/// Tier = 1 + tier unlocks owned (Ice, Crystal, Platinum, then Jump Drive levels).
/// Bosses drop the Cores that pay for them, so: beat boss -> buy unlock -> next tier.
function tier_from_unlocks() {
    var _t = 1 + (upg_level("unlock_ice") > 0) + (upg_level("unlock_crystal") > 0)
               + (upg_level("unlock_platinum") > 0) + (JUMP_DRIVES_ON ? upg_level_sum("jump_drive") : 0); // Jump Drive I-V (when switched on)
    return min(TIER_MAX, _t);
}

/// Fanfare when a purchase raises the tier (called from upg_buy, on the tree screen).
function tier_announce() {
    sfx(snd_times_up, 1, 0.7, 0);
    music_sting("mus_sting_tier");
    music_duck(0.4, 60);
}

/// Boss loot type: any unlocked asteroid resource, rarer ones favoured (Cores are dropped separately).
function boss_loot_type() {
    var _r = irandom(RES.PLATINUM);
    while (_r > 0 && !res_unlocked(_r)) _r--;
    return _r;
}

/// Spawns today's boss number _n (0 = first) off-screen, heading for the station. Each one is
/// BOSS_GROW bigger and tougher than the last. _tier_boss: this one drops the Cores.
function spawn_boss(_n = 0, _cores = 0) {
    var _ang  = random(360);
    var _dist = play_radius() + BOSS_SCALE * power(BOSS_GROW, _n) * 16;
    var _b = instance_create_layer(STATION_X + lengthdir_x(_dist, _ang), STATION_Y + lengthdir_y(_dist, _ang), "Instances", obj_asteroid);
    _b.init_boss(_n, _cores > 0);
    _b.cores_drop = _cores;
    if (global.tier >= BOSS_TRAIT_TIER) boss_roll_trait(_b); // endless tiers: every boss carries a modifier
    var _dir = point_direction(_b.x, _b.y, STATION_X, STATION_Y);
    _b.vx = lengthdir_x(0.8, _dir);
    _b.vy = lengthdir_y(0.8, _dir);
    screen_shake(6);
    screen_kick(_dir + 180, 14); // lurch towards the boss
    sfx(snd_boss_arrival, 1, 1, 0);
    music_sting("mus_sting_boss");
    music_duck(0.35, 200); // hold the music down under the ~4 s arrival sound
    return _b;
}

/// A random modifier for a late-tier boss. Only ones that suit a huge rock: not volatile (a boss-sized
/// blast), warp or glass. Sets the trait and a label for the boss health bar.
function boss_roll_trait(_b) {
    static t = ["armoured", "dense", "sticky", "rubber", "magnetic", "charged", "occupied", "gilded"];
    var _k = t[irandom(array_length(t) - 1)];
    variable_instance_set(_b, _k, true);
    _b.boss_trait = string_upper(_k);
}
