// ---------------------------------------------------------------------------
// Asteroid Inc - core configuration and lookup tables.
// Balance numbers for upgrades live in scr_upgrades -> stats_build().
// ---------------------------------------------------------------------------

// CORE only comes from bosses (never an asteroid type) and pays for the asteroid unlocks.
// From CORE on, every resource is a "special" drop: tokens collectors fetch first (res_special).
// COIN: gilded rock breaks; pays for the Gold System star chart (scr_charts).
// SURVEY: Survey Data, earned by surviving a sector condition day; pays for Sector Survey charts.
// BOX: Black Box, dropped by shot-down enemy ships; pays for the Pirate System chart and missile ranks.
// HAT: Pirate Hat, a trophy for beating the pirate flagship; unlocks the missile launcher (scr_pirates).
enum RES { ORE, ICE, CRYSTAL, PLATINUM, CORE, COIN, SURVEY, BOX, HAT, SURVEY2, SURVEY3, COUNT } // SURVEY = tier I Survey Data
enum AST { TINY, SMALL, MEDIUM, LARGE, COUNT }

#macro SAVE_FILE      "asteroid_inc_save.json"
#macro SAVE_VERSION   3       // 3 = Tech Tree.drawio layout: older saves are wiped on load (the balance log is kept)
#macro DEBUG_KEYS     true    // F11 = wipe save, F12 = costs on/off (tree screen)

#macro BASE_W         1920    // game resolution; rooms are this size
#macro BASE_H         1080
#macro WINDOW_FILL    0.9     // windowed mode fills this fraction of the monitor (F4 = fullscreen)
#macro AST_TINY_THICKEN 0      // tiny rocks' outline thickening (performance: they're most of the field). OUTLINE_THICKEN restores it
#macro OUTLINE_THICKEN 1.5    // world px added around asteroid/ship outlines (0 = art as drawn)
#macro GUI_SCALE      2      // HUD / menu magnification (GUI layer is BASE / GUI_SCALE units)

#macro STATION_X      (room_width / 2)
#macro STATION_Y      (room_height / 2)
#macro STATION_RADIUS (sprite_get_width(spr_station) / 2)  // follows the station art size; the octagon's corners touch this circle
#macro STATION_APOTHEM (STATION_RADIUS * dcos(22.5))       // centre to the middle of each flat side of the octagon

// The hull turns slowly against the starfield's orbit (and against its time-bonus rewinds).
#macro STATION_SPIN   10       // x the starfield's turn rate, in the opposite direction

/// Current hull rotation in degrees (0 if there's no station).
function station_hull_angle() {
    return instance_exists(obj_station) ? obj_station.hull_angle : 0;
}
/// Station side (0-7) facing (_x, _y): side i faces hull angle + i * 45 degrees.
function station_hull_side(_x, _y) {
    var _rel = point_direction(STATION_X, STATION_Y, _x, _y) - station_hull_angle();
    return ((round(_rel / 45) mod 8) + 8) mod 8;
}
/// Outward normal (degrees) of side _side.
function station_side_face(_side) {
    return station_hull_angle() + _side * 45;
}
/// Outward normal (degrees) of the station side facing (_x, _y).
function station_hull_face(_x, _y) {
    return station_side_face(station_hull_side(_x, _y));
}
/// How far (_x, _y) sits outside the station's octagonal hull, measured along the
/// nearest side's outward normal (negative = inside).
function station_hull_depth(_x, _y) {
    var _dir = point_direction(STATION_X, STATION_Y, _x, _y);
    return point_distance(STATION_X, STATION_Y, _x, _y) * dcos(_dir - station_hull_face(_x, _y)) - STATION_APOTHEM;
}

// Shields: one per octagon side, each holding the full max_shield and recharging on its own.
// A side's line is drawn up to SHIELD_PX_MAX px thick (thickness = strength). It regains
// strength one px at a time, and the wait for each px is (SHIELD_PX_MAX - px it has) seconds:
// 5 s for the first, then 4, 3, 2, 1 (15 s from empty to full). A hit restarts that wait.
#macro SHIELD_SIDES   8
#macro SHIELD_PX_MAX  5
#macro SHIELD_GAP     8       // shield lines sit this far outside the hull's flat sides

// Hull sections: each side is drawn as one line HULL_PX_MAX px thick that thins as it wears
// (never below HULL_MIN_PX until it breaks; a broken side shows HULL_BROKEN_PX of stubs).
// A side breaks once it has soaked HULL_SECTION_SHARE of max hull; hits there then do
// HULL_BREACH_MULT x hull damage. The main gun firing over a broken side adds
// HULL_BREACH_SPREAD degrees to its spread cone (the rail gun wobbles by half that).
#macro HULL_PX_MAX        10
#macro HULL_MIN_PX        2
#macro HULL_BROKEN_PX     3
#macro HULL_SECTION_SHARE 0.25
#macro HULL_BREACH_MULT   1.5
#macro HULL_BREACH_SPREAD 30
#macro GUN_SCALE      2       // turret sprite scale (matches the station art scale)

#macro GUN_TURN       10      // max degrees per frame the turret rotates
#macro GUN_LENGTH     ((sprite_get_bbox_right(spr_gun) + 1 - sprite_get_xoffset(spr_gun)) * GUN_SCALE) // muzzle = tip of the barrel art
#macro BURST_GAP      5       // frames between shots inside a burst

// Main weapons: you own every one you've bought, but only the ACTIVE one (picked before
// launch) follows the cursor. The rest are passive: they pick their own targets and are
// debuffed. Gun / Tesla / Laser go for the nearest rock; the Rail goes for the biggest.
enum WPN { GUN, TESLA, LASER, RAIL, COUNT }
#macro PASSIVE_TURN   0.3     // passive mounts turn at this share of GUN_TURN
#macro PASSIVE_ROF    0.6     // passive weapons fire this share as often
#macro PASSIVE_SPREAD 2       // x spread cone on passive guns
#macro PASSIVE_SCALE  0.5     // passive projectiles and effects (bullets, rail trail, bolt) are half size
#macro TARGET_SCAN    4       // passive weapons re-pick their target every this many frames (or when it breaks)
#macro PASSIVE_AIM    6       // a passive mount holds fire until it's within this many degrees of its target
// Weapon mounts: white nested shapes in the station's centre (spr_mount_*), each turning on its
// own. Radius = the shape's corner distance, read from the art (canvas half-width minus a 4 px margin),
// so redrawn art at the same canvas size keeps the muzzles in the right place.
#macro MOUNT_GUN_R    (sprite_get_width(spr_mount_gun) / 2 - 4)    // hexagon: gun fires from a tip
#macro MOUNT_LASER_R  (sprite_get_width(spr_mount_laser) / 2 - 4)  // pentagon: laser fires from a tip
#macro MOUNT_RAIL_R   (sprite_get_width(spr_mount_rail) / 2 - 4)   // square: rail fires from a side...
#macro MOUNT_RAIL_SIDE (MOUNT_RAIL_R * dcos(45))                    // ...this far out (and the side is twice this wide)
#macro MOUNT_TESLA_R  (sprite_get_width(spr_mount_tesla) / 2 - 4)  // triangle: Tesla fires from a tip
#macro MOUNT_PASSIVE_ALPHA 0.55  // passive mounts are drawn dimmer than the active one
// Rail slug intensity: it loses a share of its power with every rock it pierces (its trail
// fades with it) and fizzles out below RAIL_MIN_POWER. Rail Calibre slows the loss.
#macro RAIL_FALLOFF   0.35    // share of the slug's remaining power lost per rock, before Calibre
#macro RAIL_CALIBRE   0.7     // x that loss per Calibre rank (0.35 -> ~0.06 at rank 5)
#macro RAIL_MIN_POWER 0.12    // below this the slug is spent
#macro RAIL_PASSIVE_FALLOFF 3 // a passive slug loses power this many times faster per rock (it pierced too well)
#macro RAIL_PASSIVE_DAMAGE 0.5 // and a passive slug starts with this share of its damage
#macro RAIL_PASSIVE_RATE 0.7  // and a passive rail fires this share as often, on top of the passive fire-rate debuff
// Laser: a continuous beam to the first rock/enemy it meets (or the screen edge). Damage ramps
// up while it stays on the same target, up to a cap, and resets when the target changes.
#macro LASER_ON         1.2   // seconds each beam stays on at base Fire Rate (Fire Rate stretches it)...
#macro LASER_OFF        0.8   // ...then this many seconds off. Each new beam rolls an aim offset from the Accuracy cone
#macro LASER_DPS        30    // damage per second at full heat, before Damage / Amplifier (was 20: the active laser did half the gun's damage)
#macro LASER_HEAT_MIN   0.5   // share of full damage when the beam first lands (sweeping does this; was 0.25, so every new target nearly reset it)
#macro LASER_RAMP_TIME  1.5   // seconds on one target to reach full heat (Focus shortens it)
#macro LASER_WIDTH      8     // beam thickness in px at rank 0 (Laser Width adds to it)
#macro LASER_REFRACT_RANGE 160 // px a refracted beam can reach from the lit rock
#macro LASER_REFRACT_SHARE 0.4 // each refracted beam does this share of the main beam's damage
#macro LASER_ARMOUR     0.5   // laser damage on armoured rocks...
#macro LASER_MELT_ACTIVE  5   // ...until this many seconds of active-laser contact melt the armour off
#macro LASER_MELT_PASSIVE 8   // (passive laser)

// Freeze ray (tier 3 utility): a thin icy blast at the nearest rock that's still moving. No damage;
// each blast takes freeze_blasts(size) of the rock's speed off, so small rocks stop fastest.
#macro FREEZE_INTERVAL  75    // frames between blasts at base (1.25s)
#macro FREEZE_RATE      0.95  // each Cryo Cycler rank: 5% faster (weapon fire-rate ranks are 12-15%)
#macro FREEZE_WIDTH     (LASER_WIDTH / 2) // half the laser's base thickness
#macro FREEZE_SHOW      18    // frames each blast stays drawn
#macro FREEZE_HOLD      3     // seconds a rock stays frozen after its last blast (Cryo Life adds to it)...
#macro FREEZE_THAW      0.1   // ...then it thaws this share of its speed back per second
#macro FREEZE_BOSS_MAX  0.5   // bosses can only be slowed to half speed
/// Blasts to fully freeze a rock of size _s (tiny, small, medium, large).
function freeze_blasts(_s) { static _n = [1, 2, 3, 5]; return _n[clamp(_s, 0, 3)]; }
// Weapon base stats before any multipliers (Damage, Fire Rate, Amplifier, passive nodes).
// Rough first pass at equal power: tune with the per-day balance log.
#macro GUN_DAMAGE     1
#macro GUN_INTERVAL   30      // frames between volleys
#macro GUN_SPREAD     14      // degrees, total cone at Accuracy 0
#macro ZAP_DAMAGE     6
#macro ZAP_INTERVAL   100     // frames between bolts
#macro RAIL_DAMAGE    8       // per slug at full intensity
#macro RAIL_INTERVAL  40      // frames between slugs
#macro ZAP_SCATTER    90      // px: the active Tesla strikes somewhere within this radius of the cursor (Accuracy shrinks it)
#macro ZAP_SPLASH     60      // px: an active strike also hits every rock within this of where it lands...
#macro ZAP_SPLASH_SHARE 0.6   // ...for this share of its damage (the rock it chains from takes full)

#macro RETARGET_FRAMES 15     // how often a collector re-checks for the nearest loot
#macro SHIP_ART_ANGLE 90      // direction the collector sprite faces in the image (90 = up)
#macro NODE_SPACING   96      // pixels between upgrade tree grid cells

// --- Resources --------------------------------------------------------------
function res_name(_r)   { static n = ["Carbon", "Ice", "Silicate", "Metal", "Core", "Gold Coin", "Survey Data I", "Black Box", "Pirate Hat", "Survey Data II", "Survey Data III"]; return n[_r]; }
/// One line for the bank list's hover tooltip (obj_tree).
function res_desc(_r) {
    static d = ["Basic upgrade currency",
                "Mid-tree upgrade currency",
                "Advanced upgrade currency",
                "Top-tier upgrade currency",
                "Boss drop that unlocks new asteroids",
                "Used to pay for star charts",
                "Pays for tier 1 conditions",
                "Used to pay for star charts",
                "Unlocks the missile launcher",
                "Pays for tier 2 conditions",
                "Pays for tier 3 conditions"];
    return d[_r];
}
/// Boss Cores and star chart tokens: collectors go for these before anything else.
function res_special(_r) { return _r >= RES.CORE; }
/// Resource colour. Also tints asteroids of that type, their debris and UI numbers.
function res_colour(_r) {
    static c = [make_colour_rgb(225, 70, 60),   // Ore: red
                make_colour_rgb(80, 160, 255),  // Ice: blue
                make_colour_rgb(190, 90, 255),  // Crystal: purple
                make_colour_rgb(230, 230, 240), // Platinum: white
                make_colour_rgb(255, 70, 210),  // Core: boss magenta
                make_colour_rgb(255, 205, 50),  // Gold Coin
                make_colour_rgb(110, 130, 255), // Survey Data: navy (cyan read as Ice)
                make_colour_rgb(255, 140, 40),  // Black Box: flight-recorder orange
                make_colour_rgb(200, 60, 60),   // Pirate Hat
                make_colour_rgb(150, 255, 110), // Survey Data II: green
                make_colour_rgb(255, 110, 200)];// Survey Data III: pink
    return c[_r];
}
/// What one unit is worth towards time bonuses (rarer = more). Tokens don't count.
function res_value(_r)  { static v = [1, 3, 8, 20, 50, 0, 0, 0, 0, 0, 0]; return v[_r]; }
function res_sprite(_r) { static s = [spr_res_ore, spr_res_ice, spr_res_crystal, spr_res_platinum, spr_res_core, spr_res_coin, spr_res_survey, spr_res_box, spr_res_hat, spr_res_survey2, spr_res_survey3]; return s[_r]; }

/// Whether asteroids of this resource type can spawn yet.
function res_unlocked(_r) {
    var _st = global.stats;
    switch (_r) {
        case RES.ORE:      return true;
        case RES.ICE:      return _st.unlock_ice;
        case RES.CRYSTAL:  return _st.unlock_crystal;
        case RES.PLATINUM: return _st.unlock_platinum;
    }
    // RES.CORE: bosses only
    return false;
}


// --- Asteroids --------------------------------------------------------------
// One sprite (spr_asteroid, 32x32 regular hexagon: frame 0 outline, frame 1 fill)
// scaled per size and tinted per type. Its collision mask is a 28 px circle to match.
function ast_scale(_s)  { static a = [0.5, 1, 2, 4];       return a[_s]; } // 16, 32, 64, 128 px
function ast_hp(_s)     { static a = [1, 4, 10, 25];       return a[_s]; }
function ast_speed(_s)  { static a = [1.6, 1.2, 0.9, 0.6]; return a[_s]; } // px per frame, before threat_speed_mult()
function ast_impact(_s) { static a = [3, 6, 12, 25];       return a[_s]; } // damage to station, before threat_impact_mult()
function ast_radius(_s) { static a = [7, 14, 28, 56];      return a[_s]; } // hexagon spans 13 (flat) to 15 (corner) per unit scale: 14 splits the difference
function ast_spin(_s)   { static a = [3, 2, 1.2, 0.7];     return a[_s]; } // max degrees per frame; each asteroid rolls 30-100% of this

#macro AIM_SPREAD 450   // asteroids aim anywhere within this radius of the station (was ~160)

/// Distance from the station at which asteroids spawn (just off-screen).
function play_radius() { return point_distance(0, 0, view_w(), view_h()) / 2 + ast_radius(AST.LARGE) + 24; }

// --- Day zoom ------------------------------------------------------------------
// The camera pulls back at a fixed rate through the day, centred on the station.
// It reaches ZOOM_MAX at ZOOM_SECS (boss arrival, so the boss enters a wide field)
// and holds there for the rest of the day. A 40s early day ends at ~1.67x.
#macro ZOOM_MAX  2
#macro ZOOM_SECS 200

/// Current zoom-out (1 = normal, ZOOM_MAX = furthest). Set by obj_game.
function view_zoom() { return variable_global_exists("view_zoom") ? global.view_zoom : 1; }
function view_w()    { return room_width  * view_zoom(); }  // world width on screen
function view_h()    { return room_height * view_zoom(); }
function view_left() { return STATION_X - view_w() / 2; }
function view_top()  { return STATION_Y - view_h() / 2; }
/// True if (x, y) is on screen, shrunk by _margin (negative = allow a bit off screen).
function in_view(_x, _y, _margin = 0) {
    var _l = view_left(), _t = view_top();
    return _x > _l + _margin && _y > _t + _margin && _x < _l + view_w() - _margin && _y < _t + view_h() - _margin;
}

// --- Display ----------------------------------------------------------------
/// Sizes the window to WINDOW_FILL of the monitor, keeping the 16:9 game resolution.
function display_setup() {
    var _scale = min(display_get_width() / BASE_W, display_get_height() / BASE_H) * WINDOW_FILL;
    window_set_size(round(BASE_W * _scale), round(BASE_H * _scale));
    call_later(1, time_source_units_frames, function() { window_center(); });
    display_set_gui_size(BASE_W / GUI_SCALE, BASE_H / GUI_SCALE);
}

function toggle_fullscreen() {
    global.settings.fullscreen = !global.settings.fullscreen;
    settings_apply();
    settings_save();
}

/// How many units of its own resource an asteroid of size _s drops when it breaks
/// (or, for tiny, when it's destroyed), including the level/tier reward bonus.
/// Each unit becomes one pickup.
// Loot stacks: each pickup carries a `value` (resources it banks for), so a big drop is a few
// pieces instead of dozens. Thousands of 1-unit pickups were what slowed the late game down.
#macro LOOT_PIECES_MAX  6     // most pickups one break drops (the total is split between them)
#macro LOOT_BOSS_PIECES 24    // bosses and the flagship burst into more
#macro LOOT_SOFT_CAP    600   // above this many pickups on screen, each drop is a single stack

/// Drops _total resources of type _res around (_x, _y) as up to _max stacks, value split evenly.
/// _roll: optional function returning a resource type per stack (boss loot mixes types).
/// _free: special drop (gilded rock, boss, flagship) - never taken by the rebuild fee.
function loot_drop(_x, _y, _res, _total, _spread, _max = LOOT_PIECES_MAX, _roll = undefined, _free = false) {
    _total = round(_total);
    if (_total <= 0) return;
    var _n = (instance_number(obj_pickup) > LOOT_SOFT_CAP) ? 1 : min(_total, _max);
    var _base = _total div _n, _extra = _total mod _n;
    for (var i = 0; i < _n; i++) {
        var _p = instance_create_layer(_x + random_range(-_spread, _spread), _y + random_range(-_spread, _spread), "Instances", obj_pickup);
        _p.set_type((_roll != undefined) ? _roll() : _res);
        _p.set_value(_base + ((i < _extra) ? 1 : 0));
        _p.fee_free = _free;
    }
}

function ast_drop_amount(_s) {
    static base = [0, 1, 1, 2];
    var _b = (_s == AST.TINY) ? global.stats.tiny_yield : base[_s];
    return round_random(_b * threat_reward_mult() * cluster_loot_mult()); // clustered field: half, sparse: double
}

// New-resource rush: for the first few days after buying a resource unlock, that
// resource spawns much more often, easing back to its normal rate, so the first one or
// two nodes it pays for come quickly. Ice, Crystal and Platinum all use it (ast_roll_type).
#macro UNLOCK_BOOST      0.30   // extra share of spawns on the first day after the unlock...
#macro UNLOCK_BOOST_DAYS 5      // ...shrinking evenly to nothing over this many days

/// Extra spawn share from upgrade _id having been bought recently (0 once it's worn off,
/// or for saves from before the unlock day was recorded).
function unlock_boost(_id) {
    var _d = global.unlock_day[$ _id];
    if (_d == undefined) return 0;
    var _since = global.day_count - _d; // 0 on the first day after buying it
    if (_since < 0 || _since >= UNLOCK_BOOST_DAYS) return 0;
    return UNLOCK_BOOST * (1 - _since / UNLOCK_BOOST_DAYS);
}

/// Picks a spawn type. Each rare type has its own spawn chance (global.stats.*_rate,
/// raised by the Prospecting nodes); anything that doesn't roll a rare type is ore.
function ast_roll_type() {
    // Gold System: prospecting and unlock boosts are ignored; spawns split evenly between every
    // unlocked asteroid resource (Carbon only, then half Carbon / half Ice, then thirds, then quarters)
    if (chart_current() == CHART.GOLD) {
        var _ok = [];
        for (var _r = RES.ORE; _r <= RES.PLATINUM; _r++) if (res_unlocked(_r)) array_push(_ok, _r);
        return _ok[irandom(array_length(_ok) - 1)];
    }
    var _st = global.stats;
    // Each rare type gets extra spawns for the first days after its unlock (unlock_boost)
    var _plat    = _st.plat_rate    + unlock_boost("unlock_platinum");
    var _crystal = _st.crystal_rate + unlock_boost("unlock_crystal");
    var _ice     = _st.ice_rate     + unlock_boost("unlock_ice");
    if (res_unlocked(RES.PLATINUM) && random(1) < _plat)           return RES.PLATINUM;
    if (res_unlocked(RES.CRYSTAL)  && random(1) < _crystal)        return RES.CRYSTAL;
    if (res_unlocked(RES.ICE)      && random(1) < _ice)             return RES.ICE;
    return RES.ORE;
}

/// Picks a spawn size. "Bigger Asteroids" shifts weight from small to large.
function ast_roll_size() {
    var _b = global.stats.big_bias;
    var _large = min(0.6, 0.12 + 0.07 * _b + TIER_BIG * (threat_tier() - 1));
    if (cond_active(COND.CLUSTERED)) _large = min(CLUSTER_BIG_MAX, _large + CLUSTER_BIG);
    if (cond_active(COND.SPARSE))    _large = max(SPARSE_BIG_MIN,  _large - SPARSE_BIG);
    var _small = max(0.1, 0.48 - 0.07 * _b);
    var _r = random(1);
    if (_r < _large) return AST.LARGE;
    if (_r < _large + _small) return AST.SMALL;
    return AST.MEDIUM;
}

// Comets: rare small, fast rocks aimed dead at the station. Hard to hit with the
// main gun, so defence (hull, armour, shields, drones, repulsor) earns its keep.
#macro COMET_FIRST_DAY   1     // no comets until this many days have been played (none on the very first day)
#macro COMET_CHANCE      0.08  // share of spawns that are comets from then...
#macro COMET_PER_TIER    0.06  // ...+6% per tier beaten...
#macro COMET_RAMP        0.12  // ...+12% per RAMP_TIME into the day
#macro COMET_MAX         0.3
#macro COMET_SPEED       3.5   // x a normal small asteroid's speed
#macro COMET_IMPACT      2.5   // x a normal small asteroid's impact damage
#macro COMET_LOOT        3     // x drops if you do shoot one down
#macro COMET_TRAIL       14    // streak length in frames

function comet_chance() {
    if (global.day_count < COMET_FIRST_DAY) return 0;
    return min(COMET_MAX, COMET_CHANCE + COMET_PER_TIER * (threat_tier() - 1) + COMET_RAMP * day_progress());
}

/// Spawns one asteroid just off-screen, drifting towards (roughly) the station.
/// _traits = false skips comets and trait rolls (debug spawns set their own).
function spawn_asteroid(_traits = true) {
    if (_traits && random(1) < comet_chance()) return spawn_comet();
    var _ang  = random(360);
    var _dist = play_radius();
    var _x = STATION_X + lengthdir_x(_dist, _ang);
    var _y = STATION_Y + lengthdir_y(_dist, _ang);
    var _a = instance_create_layer(_x, _y, "Instances", obj_asteroid);
    _a.init(ast_roll_size(), ast_roll_type());
    if (_traits) ast_roll_traits(_a); // gilded / armoured / today's condition (scr_conditions)
    // Aim at a random point in a wide disc around the station: some rocks come
    // straight at you, most cross the screen near it, a few barely clip the edge.
    var _aim_a = random(360);
    var _aim_d = AIM_SPREAD * sqrt(random(1)); // sqrt = even spread over the disc
    var _tx = STATION_X + lengthdir_x(_aim_d, _aim_a);
    var _ty = STATION_Y + lengthdir_y(_aim_d, _aim_a);
    var _dir = point_direction(_x, _y, _tx, _ty);
    var _spd = ast_speed(_a.size) * threat_speed_mult() * random_range(0.8, 1.2) * quick_speed_mult(); // quickened sector: 25-75% faster
    _a.vx = lengthdir_x(_spd, _dir);
    _a.vy = lengthdir_y(_spd, _dir);
    return _a;
}

// Opening wave: a few rocks are already drifting across the screen when a day starts, so
// there's something to shoot straight away (rocks from the edge took ~10 s to arrive).
// Rebuild fee: when the station is destroyed, this share of the day's banked ore / ice /
// crystal / platinum is taken back to rebuild it (Cores, special tokens and special drops - gilded rock and boss loot - are never taken).
// Running out of time stays the good way for a day to end.
#macro REBUILD_FEE     0.2
// Abandon fee: the same, but smaller, for quitting mid-shift (ESC while the clock is still running).
// Work a full shift or die trying. Abandoning during the end-of-day recall is free.
#macro ABANDON_FEE     0.1

#macro OPENING_ROCKS   4      // rocks placed on screen at the start of each day
#macro OPENING_NEAR    0.45   // placed between these shares of the distance from the station to the screen edge
#macro OPENING_FAR     0.85
#macro OPENING_MISS    40     // opening rocks' paths pass at least this far outside the hull (no free hits on day start)

/// True if a rock at (_x, _y) heading _dir never comes within _clear of the station centre.
function opening_misses(_x, _y, _dir, _clear) {
    var _dx = dcos(_dir), _dy = -dsin(_dir);
    var _sx = STATION_X - _x, _sy = STATION_Y - _y;
    var _along = _sx * _dx + _sy * _dy;                // how far ahead the closest approach is
    if (_along <= 0) return point_distance(_x, _y, STATION_X, STATION_Y) > _clear; // heading away
    return abs(_sx * _dy - _sy * _dx) > _clear;        // closest-approach distance
}

/// One opening-wave rock: a normal spawn (size, type, traits, speed), moved onto the screen
/// and re-aimed across the station's surroundings.
function spawn_opening_rock() {
    var _a = spawn_asteroid();
    var _ang = random(360);
    var _edge = min(view_w(), view_h()) / 2;
    var _d = _edge * random_range(OPENING_NEAR, OPENING_FAR);
    _a.x = STATION_X + lengthdir_x(_d, _ang);
    _a.y = STATION_Y + lengthdir_y(_d, _ang);
    // Aim across the station's surroundings, but never on a collision course: re-roll until the
    // path passes the hull with room to spare (comets included). Fallback: fly at right angles
    // to the station, which always misses since the rock starts well clear of the hull.
    var _clear = STATION_RADIUS + _a.radius + OPENING_MISS;
    var _dir = point_direction(STATION_X, STATION_Y, _a.x, _a.y) + choose(-90, 90);
    repeat (20) {
        var _aim_a = random(360), _aim_d = AIM_SPREAD * sqrt(random(1));
        var _try = point_direction(_a.x, _a.y, STATION_X + lengthdir_x(_aim_d, _aim_a), STATION_Y + lengthdir_y(_aim_d, _aim_a));
        if (opening_misses(_a.x, _a.y, _try, _clear)) { _dir = _try; break; }
    }
    var _spd = point_distance(0, 0, _a.vx, _a.vy);
    _a.vx = lengthdir_x(_spd, _dir);
    _a.vy = lengthdir_y(_spd, _dir);
    return _a;
}

/// A comet: small, fast, aimed straight at the station (tiny wobble so it isn't perfectly predictable).
function spawn_comet() {
    var _ang = random(360);
    var _x = STATION_X + lengthdir_x(play_radius(), _ang);
    var _y = STATION_Y + lengthdir_y(play_radius(), _ang);
    var _a = instance_create_layer(_x, _y, "Instances", obj_asteroid);
    _a.init(AST.SMALL, ast_roll_type());
    _a.is_comet = true;
    _a.impact *= COMET_IMPACT;
    _a.spin *= 3;
    var _dir = point_direction(_x, _y, STATION_X, STATION_Y) + random_range(-3, 3);
    var _spd = ast_speed(AST.SMALL) * COMET_SPEED * threat_speed_mult();
    _a.vx = lengthdir_x(_spd, _dir);
    _a.vy = lengthdir_y(_spd, _dir);
    return _a;
}
