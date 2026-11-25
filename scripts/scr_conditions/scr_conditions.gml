// ---------------------------------------------------------------------------
// Sector conditions and rare asteroid traits: early-game variety.
//   Sector condition: at most one per day, rolled when the day starts and
//   announced over the station. Common on a fresh save, rarer the more upgrade
//   nodes you own (by then weapons, enemies and sheer numbers carry the variety),
//   but never gone completely.
//   Rare traits (gilded, armoured) can turn up on any day, condition or not.
// Each asteroid has at most one trait. Flags live on obj_asteroid: rubber,
// explosive, sticky, gilded, armoured. Fragments inherit their parent's traits (explosive rocks
// don't split; sticky fragments come off clean then can rejoin; occupied only stays on medium
// fragments; breeders don't pass it on).
// obj_game calls cond_day_init() on Create and cond_step() every world tick.
// ---------------------------------------------------------------------------

enum COND { NONE, RUBBER, EXPLOSIVE, STICKY, SOLID, BLACK_HOLE, SOLAR_WIND, METEORS,
             MAGNETIC, CHARGED, GLASS, OCCUPIED, WARP, WHITE_HOLE, ION_STORM, CLUSTERED, SPARSE, BREEDER, QUICKENED, COUNT }
#macro COND_T2_TIER    2      // (kept for reference) condition tiers are set in cond_min_tier

#macro COND_FIRST_DAY  1      // no conditions before this day_count (the very first day stays clean)
#macro COND_CHANCE     0.9    // chance a day has a condition with nothing bought...
#macro COND_FALLOFF    0.06   // ...divided by (1 + this x upgrade nodes owned)...
#macro COND_FLOOR      0.15   // ...but never below this

// Rubber: bullets and lasers deal their damage, then bounce off and carry on
#macro RUBBER_SHARE    0.80    // share of a rubber day's asteroids that are rubber
#macro RUBBER_BOUNCES  2      // ricochets per bullet/laser; every hit deals full damage
#macro RUBBER_COLOUR   make_colour_rgb(110, 255, 150)
#macro RUBBER_ZAP      0.5    // Tesla damage to a rubber rock, and the share of its remaining chain bounces that carry on past one

// Glass vs lasers: the rock takes part of the bolt, which then refracts into two weaker beams
#macro GLASS_LASER     0.5    // x laser damage to a glass rock
#macro GLASS_SPLIT     0.25   // x the original damage, for each of the two refracted beams
#macro GLASS_SPLIT_ANG 25     // degrees each beam bends away from the original line

// Explosive: breaks into a blast instead of fragments
#macro EXPLODE_SHARE   0.80   // share of a volatile day's asteroids that are explosive
#macro EXPLODE_FUSE    6      // frames before a rock caught in a blast goes off (chains ripple outwards)
#macro EXPLODE_PUSH    3      // px/frame shove at the epicentre, down to 30% of that at the edge
#macro EXPLODE_STATION 2      // x impact damage if it reaches the hull (and it goes off there)
#macro EXPLODE_SHIP    6      // damage to a collection ship caught in a blast
#macro EXPLODE_COLOUR  make_colour_rgb(255, 120, 30)
#macro EXPLODE_DISTANT_MIN 2.5 // seconds between distant (off-screen) explosions you only hear...
#macro EXPLODE_DISTANT_MAX 7
#macro EXPLODE_DISTANT_VOL 0.18 // ...at around this volume (+/-50%), pitched down so they sound far off

// Sticky: touching rocks join a clump; the heavier side keeps its heading (momentum by mass)
#macro STICKY_SHARE    0.5    // only half the rocks are sticky, so the field doesn't become one blob
#macro STICKY_MAX      6      // rocks in one clump, centre included
#macro STICKY_COLOUR   make_colour_rgb(205, 235, 60)

// Solid (dense field): rocks bounce off each other and take damage from hard knocks
#macro SOLID_DMG       0.12   // share of max HP lost per px/frame of closing speed (x2 x the other's share of the mass)
#macro SOLID_KEEP      0.85   // bounciness (1 = no speed lost)
#macro SOLID_CD        12     // frames before the same rock can be damaged by another knock
#macro FRAG_NOCOLLIDE  20     // fresh fragments ignore rock contacts this long (they spawn touching)

// Black hole (gravity anomaly): pulls asteroids only, crushes what it catches, then collapses
#macro BH_FIRST        8      // seconds into the day before the first one...
#macro BH_GAP          10     // ...and between one collapsing and the next opening (+/-30%)
#macro BH_LIFE         6     // seconds open
#macro BH_GROW         1.5    // seconds to open fully
#macro BH_SHRINK       0.5    // seconds it caves in before the collapse blast
#macro BH_RANGE        800    // px of pull (also how far the collapse shockwave reaches)
#macro BH_CORE         46     // px: anything this close is caught
#macro BH_PULL         0.16   // px/frame^2 at the core, fading to 0 at BH_RANGE
#macro BH_MAX_SPEED    7      // pulled rocks are capped at this speed
#macro BH_CRUSH        0.35   // share of max HP a caught rock loses each second
#macro BH_BLAST        7      // px/frame shove at the epicentre when it collapses
#macro BH_COLOUR       make_colour_rgb(170, 90, 255)
#macro BH_LOOT_PULL    2      // loose loot is pulled this many times harder than a tiny rock (no damage; sprays out on collapse)

// White hole: spews loot and rocks (some with a modifier) without pushing or pulling anything;
// when it closes it implodes, swallowing whatever is close by (rocks and loot, no drops)
#macro WH_FIRST        6      // seconds into the day before the first one...
#macro WH_GAP          12     // ...and between one closing and the next opening (+/-30%)
#macro WH_LIFE         9      // seconds open
#macro WH_GROW         1      // seconds to open fully
#macro WH_SHRINK       0.8    // seconds of implosion at the end
#macro WH_CORE         40     // px
#macro WH_RATE         0.3    // seconds between spews (+/-50%)
#macro WH_ROCK_CHANCE  0.3    // share of spews that are asteroids (the rest is loot)
#macro WH_GILD_CHANCE  0.15   // chance a spewed asteroid is gilded (rolled first)...
#macro WH_MOD_CHANCE   0.3    // ...otherwise, chance it has another modifier (volatile, dense, infested, armoured)
#macro WH_SPEW_MIN     2      // px/frame loot keeps once it's out of the ring (it slows to a stop from there)...
#macro WH_SPEW_MAX     5
#macro WH_THROW        7      // px/frame everything spewed is thrown at until it's clear of the implosion ring
#macro WH_FAST         1.5    // spewed asteroids cruise at 1x to this x a normal asteroid's speed once clear
#macro WH_EAT          170    // px: the implosion pulls in and destroys rocks and loot this close
#macro WH_COLOUR       make_colour_rgb(210, 235, 255)
#macro WH_BRIGHT       0.5    // x brightness of the glow and swirls (bloom picks up bright additive light; lower = less glow)
#macro WH_CORE_BRIGHT  0.7    // alpha of the white core
#macro WH_BLOOM_BURST  0.4    // extra bloom flash when it implodes (was 1)
#macro DENSE_COLOUR    make_colour_rgb(215, 180, 140)

// Ion storm: every few seconds a jagged bolt of lightning cracks right across the screen and
// zaps everything along its ragged line: asteroids, your ships, enemies and the station.
#macro ION_FIRST       4      // seconds into the day before the first bolt...
#macro ION_EVERY       4      // ...and between bolts
#macro ION_WARN        0.4    // seconds the path flickers faintly before it strikes
#macro ION_WIDTH       22     // px either side of the line that gets hit (plus a rock's radius)
#macro ION_KINK        45     // px: max sideways wander of each kink (it's a ragged line, not a straight one)
#macro ION_STEP_MIN    40     // px between kinks...
#macro ION_STEP_MAX    80
#macro ION_ROCK_DMG    2      // x a small asteroid's base HP (scaled by threat); armour takes half, as from the Tesla
#macro ION_SHIP_DMG    6      // to each ship (yours or enemy) it crosses
#macro ION_STATION     1      // x a small asteroid's station damage (scaled by threat)
#macro ION_SPLINTER    0.33   // chance a bolt throws a splinter from the nearest point of its arc to the station
#macro ION_COLOUR      make_colour_rgb(140, 170, 255)

// Clustered field: twice as many rocks, more of them large, but each has half the HP and drops half the loot
#macro CLUSTER_SPAWN   2.5      // x spawn rate
#macro CLUSTER_BIG     0.25   // + chance a spawn is large...
#macro CLUSTER_BIG_MAX 0.8    // ...up to this (the usual cap is 0.6)
#macro CLUSTER_HP      0.5    // x HP (fragments too)
#macro CLUSTER_LOOT    0.5    // x drops
#macro CLUSTER_COLOUR  make_colour_rgb(180, 150, 120)

// Sparse field: the opposite. Half as many rocks, fewer of them large, but each has double the HP and drops double the loot
#macro SPARSE_SPAWN    0.5    // x spawn rate
#macro SPARSE_BIG      0.25   // - chance a spawn is large...
#macro SPARSE_BIG_MIN  0.03   // ...down to this
#macro SPARSE_HP       2      // x HP (fragments too)
#macro SPARSE_LOOT     2      // x drops
#macro SPARSE_COLOUR   make_colour_rgb(150, 190, 230)

// Breeder (tier 3): rocks that grow a size every few seconds they're left alone. A large one
// splits into three small breeders, which grow again: 1 -> 3 -> 9 ... Only killing it stops it.
#macro BREED_SHARE     0.3    // share of a breeder day's asteroids that breed
#macro BREED_GROW      6      // seconds between growing a size (or, once large, splitting), hit or not
#macro BREED_SPLIT     3      // small breeders a large one splits into
#macro BREED_MAX       45     // breeders alive at once: at the cap a large one holds off splitting
#macro BREED_COLOUR    make_colour_rgb(120, 255, 90)

// Quickened sector (tier 3): every rock is 25-75% faster than normal (rolled per rock; fragments keep the pace)
#macro QUICK_MIN       1.25
#macro QUICK_MAX       1.75
#macro QUICK_COLOUR    make_colour_rgb(255, 150, 210)

// Solar wind: asteroids and loose loot drift one way all day (loot wraps round the screen)
#macro WIND_SPEED      2.5    // px/frame
#macro WIND_COLOUR     make_colour_rgb(255, 230, 150)

// Meteor shower: bursts of tiny fast meteors that hit asteroids and (more lightly than comets) the station
#macro METEOR_FIRST    6      // seconds into the day before the first burst...
#macro METEOR_GAP      11     // ...and between bursts (+/-25%)
#macro METEOR_MIN      28     // meteors per burst
#macro METEOR_MAX      40
#macro METEOR_RAIN     3.5    // seconds a burst rains down over (meteors at random intervals through it)
#macro METEOR_SPEED    8      // px/frame
#macro METEOR_SPREAD   60     // px past the screen edge the rain front reaches (it spans the whole view, whatever the angle)
#macro METEOR_IMPACT   1.5    // x a tiny asteroid's station damage (comets are 2.5 x a small's: ~4x more)
#macro METEOR_DMG      3      // x a small asteroid's base HP (scaled by threat) to an asteroid it hits
#macro METEOR_COLOUR   make_colour_rgb(255, 170, 90)

// --- Tier 2+ conditions ---
// Magnetic: drags loose loot along with it (still collectable, just on the move)
#macro MAG_SHARE       0.8
#macro MAG_RANGE       110    // px beyond the rock's edge that loot gets pulled from
#macro MAG_PULL        0.25   // px/frame^2 towards the rock's surface
#macro MAG_GRIP        0.12   // how quickly caught loot matches the rock's velocity (0-1 per frame)
#macro MAG_COLOUR      make_colour_rgb(255, 90, 90)

// Charged: zaps the nearest ship (yours or enemy) in range, Tesla-style low damage
#macro CHARGE_SHARE    0.8
#macro CHARGE_RANGE    90     // px beyond the rock's edge
#macro CHARGE_DMG      3      // per zap
#macro CHARGE_CD       1.5    // seconds between zaps (+/-30%)
#macro CHARGE_COLOUR   make_colour_rgb(90, 200, 255)

// Glass: black fill, thin grey outline, no glow. Smaller rocks get a whiter outline so they stay findable.
#macro GLASS_SHARE     0.8

// Occupied: a medium or large rock that launches a homing missile at the station every few seconds
#macro OCC_SHARE       0.5    // of medium and large rocks
#macro OCC_RATE        3      // seconds between launches
#macro OCC_DMG         0.5    // x a flagship missile's damage
#macro OCC_COLOUR      make_colour_rgb(255, 60, 60)

// Warp: shrinks to nothing, is gone (untouchable) for a second or two, then grows back further along its path
#macro WARP_SHARE      0.8
#macro WARP_EVERY_MIN  2.5    // seconds between warps...
#macro WARP_EVERY_MAX  5
#macro WARP_FADE       10     // frames to shrink out, and to grow back
#macro WARP_GONE_MIN   1      // seconds gone...
#macro WARP_GONE_MAX   2
#macro WARP_SKIP       2      // x its speed while gone, so it turns up further along than it would have drifted
#macro WARP_COLOUR     make_colour_rgb(200, 120, 255)

// Gilded: rare, large only, triple drops from it and every fragment down to the tiny ones
#macro GILDED_CHANCE   0.005
#macro GILDED_LOOT     3
#macro GILDED_COLOUR   make_colour_rgb(255, 205, 50)

// Armoured: bullets, lasers, drones, rams, blasts, knocks and crushing glance off. Rail does full damage, Tesla half.
#macro ARMOUR_CHANCE   0.01   // at tier 1...
#macro ARMOUR_PER_TIER 0.01   // ...+1% per tier above that
#macro ARMOUR_ZAP      0.5
#macro ARMOUR_PUSH     0.5    // repulsor and blasts still steer it, at this share of the usual effect
#macro ARMOUR_COLOUR   make_colour_rgb(160, 172, 190)

function cond_name(_c) {
    static n = ["", "RUBBER FIELD", "VOLATILE FIELD", "STICKY FIELD", "DENSE FIELD", "GRAVITY ANOMALY", "SOLAR WIND", "METEOR SHOWER",
                "MAGNETIC FIELD", "CHARGED FIELD", "GLASS FIELD", "OCCUPIED FIELD", "WARP FIELD", "WHITE HOLE", "ION STORM", "CLUSTERED FIELD", "SPARSE FIELD", "BREEDER FIELD", "QUICKENED SECTOR"];
    return n[_c];
}
/// Short name for the modifier box: "Sticky", "Solar Wind", "Gravity Anomaly".
function cond_short(_c) {
    static n = ["", "Rubber", "Volatile", "Sticky", "Dense", "Gravity Anomaly", "Solar Wind", "Meteor Shower",
                "Magnetic", "Charged", "Glass", "Occupied", "Warp", "White Hole", "Ion Storm", "Clustered", "Sparse", "Breeder"];
    return n[_c];
}
/// One line of flavour for the modifier box.
function cond_desc(_c) {
    static d = ["",
        "Shots bounce off these asteroids and carry on",
        "These asteroids explode when they break",
        "Things love to stick to these asteroids",
        "Asteroids knock and damage each other",
        "Black holes open and swallow asteroids",
        "A solar gale is blowing through this space",
        "Bursts of meteors rain across the sector",
        "These asteroids drag loot along with them",
        "These asteroids zap nearby ships",
        "Dark asteroids that are hard to see",
        "These asteroids fire missiles at your station",
        "These asteroids blink out and reappear",
        "White holes spew loot and asteroids",
        "Lightning cracks across the sector",
        "Twice the asteroids, half the loot each",
        "Fewer asteroids, double the loot each",
        "Leave these asteroids alone and they multiply"];
    return d[_c];
}
function cond_colour(_c) {
    static c = [c_white, RUBBER_COLOUR, EXPLODE_COLOUR, STICKY_COLOUR, DENSE_COLOUR, BH_COLOUR, WIND_COLOUR, METEOR_COLOUR,
                MAG_COLOUR, CHARGE_COLOUR, make_colour_rgb(200, 200, 200), OCC_COLOUR, WARP_COLOUR, WH_COLOUR, ION_COLOUR, CLUSTER_COLOUR, SPARSE_COLOUR, BREED_COLOUR, QUICK_COLOUR];
    return c[_c];
}
/// Lowest tier a condition can turn up on.
function cond_min_tier(_c) {
    switch (_c) {
        case COND.EXPLOSIVE: case COND.STICKY: case COND.BLACK_HOLE:
        case COND.MAGNETIC: case COND.CHARGED: case COND.ION_STORM:
            return 2;
        case COND.WARP: case COND.GLASS: case COND.OCCUPIED: case COND.BREEDER:
        case COND.QUICKENED:
            return 3;
    }
    return 1; // rubber, dense, solar wind, meteors, white hole, clustered, sparse
}

/// Clustered / sparse field multipliers (1 on any other day): spawn rate, asteroid HP and drops.
/// A survey stacking both cancels out.
function cluster_spawn_mult() { return (cond_active(COND.CLUSTERED) ? CLUSTER_SPAWN : 1) * (cond_active(COND.SPARSE) ? SPARSE_SPAWN : 1); }
function cluster_hp_mult()    { return (cond_active(COND.CLUSTERED) ? CLUSTER_HP    : 1) * (cond_active(COND.SPARSE) ? SPARSE_HP    : 1); }
/// Quickened sector: a fresh rock's speed multiplier (1 on any other day).
function quick_speed_mult() { return cond_active(COND.QUICKENED) ? random_range(QUICK_MIN, QUICK_MAX) : 1; }
function cluster_loot_mult()  { return (cond_active(COND.CLUSTERED) ? CLUSTER_LOOT  : 1) * (cond_active(COND.SPARSE) ? SPARSE_LOOT  : 1); }

/// How readily the black hole drags an asteroid of size _s: smaller rocks are pulled in faster.
function bh_size_mult(_s) { static m = [1.6, 1.2, 0.85, 0.6]; return m[_s]; } // tiny, small, medium, large

/// Upgrade nodes with at least one level bought (the Command Core doesn't count).
function upg_nodes_owned() {
    var _n = 0;
    var _k = variable_struct_get_names(global.levels);
    for (var i = 0; i < array_length(_k); i++) {
        if (_k[i] != "core" && global.levels[$ _k[i]] > 0) _n++;
    }
    return _n;
}

/// Chance the coming day has a sector condition.
function cond_chance() {
    if (global.day_count < COND_FIRST_DAY) return 0;
    return max(COND_FLOOR, COND_CHANCE / (1 + COND_FALLOFF * upg_nodes_owned()));
}

/// Picks today's condition (COND.NONE most days once the tree fills out).
function cond_roll() {
    if (random(1) >= cond_chance()) return COND.NONE;
    var _ok = [];
    for (var c = 1; c < COND.COUNT; c++) if (global.tier >= cond_min_tier(c)) array_push(_ok, c);
    return _ok[irandom(array_length(_ok) - 1)];
}

function cond_current() { return instance_exists(obj_game) ? obj_game.condition : COND.NONE; }

/// True if _c is running today. A Sector Survey can stack two (obj_game.condition and condition2).
function cond_active(_c) {
    return instance_exists(obj_game) && (obj_game.condition == _c || obj_game.condition2 == _c);
}

/// Today's conditions as a list (empty, one or two).
function cond_list() {
    var _l = [];
    if (!instance_exists(obj_game)) return _l;
    if (obj_game.condition  != COND.NONE) array_push(_l, obj_game.condition);
    if (obj_game.condition2 != COND.NONE) array_push(_l, obj_game.condition2);
    return _l;
}

/// Big name over the station, a moment after the day starts. _row 1 = a stacked second condition, just under it.
function cond_announce(_c, _row = 0) {
    if (_c == COND.NONE || !instance_exists(obj_station)) return;
    float_text(STATION_X, STATION_Y - STATION_RADIUS - 90 + 34 * _row, cond_name(_c), cond_colour(_c), 3);
    sfx(snd_warning, 0.6, 0.8, 0);
}

// --- Day controller (runs in obj_game's scope) ---------------------------------

/// Sets up today's condition state. Call again after changing `condition` (debug).
function cond_day_init() {
    var _fps = game_get_speed(gamespeed_fps);
    global.wind_x = 0;
    global.wind_y = 0;
    if (condition == COND.SOLAR_WIND || condition2 == COND.SOLAR_WIND) {
        var _wd = random(360);
        global.wind_x = lengthdir_x(WIND_SPEED, _wd);
        global.wind_y = lengthdir_y(WIND_SPEED, _wd);
    }
    bh_timer     = BH_FIRST * _fps;
    wh_timer     = WH_FIRST * _fps;
    ion_timer    = ION_FIRST * _fps;
    meteor_timer = METEOR_FIRST * _fps;
    meteor_left  = 0;
    meteor_gap   = 0;
    meteor_dir   = 0;
    meteor_step  = 0;            // average frames between meteors in the current burst
    distant_boom = random_range(1, EXPLODE_DISTANT_MAX) * _fps; // volatile: frames to the next off-screen explosion
}

/// Per-tick work for today's condition(s).
function cond_step() {
    cond_step_one(condition);
    if (condition2 != COND.NONE && condition2 != condition) cond_step_one(condition2);
    // Dense rocks (white hole spew) and armoured rocks knock into others on any day (a dense field already does every rock)
    if (!cond_active(COND.SOLID)) {
        var _any = false;
        with (obj_asteroid) if ((dense || armoured) && !dead) { _any = true; break; } // armoured rocks are solid too
        if (_any) ast_contacts(COND.SOLID, true);
    }
}

function cond_step_one(_c) {
    var _fps = game_get_speed(gamespeed_fps);
    switch (_c) {
        case COND.STICKY: ast_contacts(COND.STICKY); break;
        case COND.SOLID:  ast_contacts(COND.SOLID);  break;

        case COND.BLACK_HOLE:
            if (!instance_exists(obj_blackhole)) {
                bh_timer--;
                if (bh_timer <= 0) {
                    spawn_blackhole();
                    bh_timer = BH_GAP * _fps * random_range(0.7, 1.3);
                }
            }
            break;

        case COND.WHITE_HOLE:
            if (!instance_exists(obj_whitehole)) {
                wh_timer--;
                if (wh_timer <= 0) {
                    spawn_hole(obj_whitehole);
                    wh_timer = WH_GAP * _fps * random_range(0.7, 1.3);
                }
            }
            break;

        case COND.ION_STORM:
            ion_timer--;
            if (ion_timer <= 0) {
                spawn_ion_bolt();
                ion_timer = ION_EVERY * _fps;
            }
            break;

        case COND.EXPLOSIVE: // rocks going off somewhere out of sight: heard, not seen
            distant_boom--;
            if (distant_boom <= 0) {
                sfx(snd_explosion, EXPLODE_DISTANT_VOL * random_range(0.5, 1.5), random_range(0.55, 0.8), 0);
                if (random(1) < 0.3) sfx(snd_thud, EXPLODE_DISTANT_VOL * 0.6, random_range(0.5, 0.7), 0); // now and then a low rumble with it
                distant_boom = random_range(EXPLODE_DISTANT_MIN, EXPLODE_DISTANT_MAX) * _fps;
            }
            break;

        case COND.SOLAR_WIND:
            fx_wind(point_direction(0, 0, global.wind_x, global.wind_y));
            break;

        case COND.METEORS:
            meteor_timer--;
            if (meteor_timer <= 0) {
                meteor_left  = irandom_range(METEOR_MIN, METEOR_MAX);
                meteor_dir   = random(360);
                meteor_gap   = 0;
                meteor_step  = METEOR_RAIN * _fps / meteor_left;
                meteor_timer = METEOR_GAP * _fps * random_range(0.75, 1.25);
                sfx(snd_warning, 0.35, 1.3, 0);
            }
            // Rain: one at a time at uneven intervals across the burst (several in a frame if they're due)
            if (meteor_left > 0) {
                meteor_gap--;
                while (meteor_gap <= 0 && meteor_left > 0) {
                    spawn_meteor(meteor_dir);
                    meteor_left--;
                    meteor_gap += meteor_step * random_range(0.2, 1.8);
                }
            }
            break;
    }
}

// --- Traits ----------------------------------------------------------------------

function armour_chance() { return ARMOUR_CHANCE + ARMOUR_PER_TIER * (global.tier - 1); }

/// Gives a freshly spawned asteroid its traits. Gilded only changes the loot, so it stacks
/// with anything (a volatile gold rock still pays out big). Then armour or today's conditions.
function ast_roll_traits(_a) {
    var _gold = chart_current() == CHART.GOLD;
    if (_gold) _a.gilded = true; // Gold System star chart: every rock
    else if (_a.size == AST.LARGE && random(1) < GILDED_CHANCE) _a.gilded = true;
    // A Gold System stays clean: no armour, and only the conditions the player paid to add
    if (!_gold && random(1) < armour_chance()) { _a.armoured = true; return; }
    // Two stacked conditions: each rock rolls for each one separately, so it can carry both
    var _l = cond_list();
    for (var i = 0; i < array_length(_l); i++) switch (_l[i]) {
        case COND.RUBBER:    if (random(1) < RUBBER_SHARE)  _a.rubber    = true; break;
        case COND.EXPLOSIVE: if (random(1) < EXPLODE_SHARE) _a.explosive = true; break;
        case COND.STICKY:    if (random(1) < STICKY_SHARE)  _a.sticky    = true; break;
        case COND.MAGNETIC:  if (random(1) < MAG_SHARE)     _a.magnetic  = true; break;
        case COND.CHARGED:   if (random(1) < CHARGE_SHARE)  _a.charged   = true; break;
        case COND.GLASS:     if (random(1) < GLASS_SHARE)   _a.glass     = true; break;
        case COND.WARP:      if (random(1) < WARP_SHARE)    _a.warp      = true; break;
        case COND.BREEDER:   if (!_a.is_comet && random(1) < BREED_SHARE) _a.breeder = true; break;
        case COND.OCCUPIED:
            if (_a.size >= AST.MEDIUM && !_a.is_comet && random(1) < OCC_SHARE) _a.occupied = true;
            break;
    }
}

/// Staggers the per-rock timers so a field of charged / occupied / warp rocks doesn't fire in step.
function ast_trait_timers(_a) {
    var _fps = game_get_speed(gamespeed_fps);
    _a.charge_t = CHARGE_CD * _fps * random_range(0.3, 1.3);
    _a.occ_t    = OCC_RATE * _fps * random_range(0.4, 1);
    _a.warp_t   = random_range(WARP_EVERY_MIN, WARP_EVERY_MAX) * _fps;
    _a.breed_t  = BREED_GROW * _fps * random_range(0.85, 1.15);
}

/// Breeder: grows a size every BREED_GROW seconds, hit or not; a large one splits into
/// BREED_SPLIT small breeders. Returns true if it split (it's gone: stop its Step).
function ast_breed() {
    if (!entered || anchor != noone || is_boss) return false;
    var _fps = game_get_speed(gamespeed_fps);
    breed_t--;
    if (breed_t > 0) return false;
    breed_t = BREED_GROW * _fps * random_range(0.85, 1.15);
    if (size < AST.LARGE) { // grow, keeping its share of health, heading and spin
        var _f = hp / max_hp, _ang = image_angle, _spin = spin;
        init(size + 1, type);
        hp = max_hp * _f;
        image_angle = _ang;
        spin = _spin;
        squash = 1;
        fx_spark(x, y);
        sfx(snd_sticky, 0.3, 0.7, 0.1); // placeholder: a soft wet swell
        return false;
    }
    var _n = 0;
    with (obj_asteroid) if (breeder && !dead) _n++;
    if (_n - 1 + BREED_SPLIT > BREED_MAX) return false; // field's full: hold off until some are cleared
    var _sp = ast_speed(AST.SMALL) * threat_speed_mult();
    var _d0 = random(360);
    for (var i = 0; i < BREED_SPLIT; i++) {
        var _d = _d0 + i * 360 / BREED_SPLIT;
        var _a = instance_create_layer(x + lengthdir_x(radius * 0.5, _d), y + lengthdir_y(radius * 0.5, _d), "Instances", obj_asteroid);
        _a.init(AST.SMALL, type);
        _a.breeder   = true;
        _a.breed_child = true; // no bonus charge for split-born breeders
        _a.entered   = true;
        _a.nocollide = FRAG_NOCOLLIDE; // they spawn touching
        _a.squash    = 1;
        _a.vx = vx * 0.5 + lengthdir_x(_sp, _d);
        _a.vy = vy * 0.5 + lengthdir_y(_sp, _d);
    }
    fx_spark(x, y);
    sfx(snd_sticky, 0.45, 0.5, 0.1);
    dead = true;
    instance_destroy(); // no loot: it became the three
    return true;
}

// --- Tier 2+ trait behaviour (called from obj_asteroid's Step, in the rock's scope) ---

/// Magnetic: loose loot nearby is pulled to the rock's surface and carried along with it.
function ast_magnet() {
    var _me = id, _r = radius, _reach = radius + MAG_RANGE;
    with (obj_pickup) {
        if (carried || tractored || claimed_by != noone) continue;
        var _d = point_distance(x, y, _me.x, _me.y);
        if (_d > _reach) continue;
        var _dir = point_direction(x, y, _me.x, _me.y);
        var _gap = _d - (_r + 6); // aim for just outside the rock, not its centre
        var _f = MAG_PULL * clamp(_gap / 20, -1, 1) * (1 - 0.5 * _d / _reach);
        vx += lengthdir_x(_f, _dir) + (_me.vx - vx) * MAG_GRIP;
        vy += lengthdir_y(_f, _dir) + (_me.vy - vy) * MAG_GRIP;
    }
}

// --- Magnet pickup ------------------------------------------------------------------
// Each break of a medium or large magnetic rock has a chance to drop a Magnet. Collectors go for it first
// (like a Core); when a ship picks it up, or the tractor beam lands it, every loose
// resource on the field is hauled straight into the station.
#macro MAGNET_CHANCE 0.25
#macro MAGNET_SPEED  9      // top speed (px/frame) of loot the Magnet hauls home

/// Magnetic rock breaking (obj_asteroid.break_apart, the rock's scope).
function magnet_drop() {
    if (!magnetic || size < AST.MEDIUM || random(1) >= MAGNET_CHANCE) return; // medium and large breaks only
    var _p = instance_create_layer(x, y, "Instances", obj_pickup);
    _p.magnet = true;
    _p.sprite_index = spr_res_magnet;
    _p.image_xscale = 1.5;
    _p.image_yscale = 1.5;
    var _d = random(360); // flung a little further than normal loot so it reads as special
    _p.vx = lengthdir_x(random_range(3, 5), _d);
    _p.vy = lengthdir_y(random_range(3, 5), _d);
}

/// Magnet collected at _x, _y: every loose pickup is hauled into the station.
function magnet_trigger(_x, _y) {
    var _n = 0;
    with (obj_pickup) {
        if (magnet || carried || tractored || claimed_by != noone) continue;
        tractored = true;
        mag_pulled = true;
        tr_spd = 1;
        if (instance_exists(targeted_by)) targeted_by.retarget_timer = 0;
        targeted_by = noone;
        _n++;
    }
    fx_spark(_x, _y);
    float_text(_x, _y - 20, "MAGNET" + (_n > 0 ? " +" + string(_n) : ""), MAG_COLOUR, 1.4);
    sfx(snd_repulsor, 0.6, 0.8, 0);
}

/// Charged: every so often, arc to the nearest ship in range (collectors, fighters, enemies).
function ast_charge() {
    if (!in_view(x, y)) return;
    charge_t--;
    if (charge_t > 0) return;
    charge_t = CHARGE_CD * game_get_speed(gamespeed_fps) * random_range(0.7, 1.3);
    var _me = id, _best = noone, _bd = radius + CHARGE_RANGE, _d = 0;
    with (obj_collector) if (!dead)         { _d = point_distance(x, y, _me.x, _me.y); if (_d < _bd) { _bd = _d; _best = id; } }
    with (obj_fighter)   if (rebuild <= 0)  { _d = point_distance(x, y, _me.x, _me.y); if (_d < _bd) { _bd = _d; _best = id; } }
    with (obj_enemy)     if (!dead)         { _d = point_distance(x, y, _me.x, _me.y); if (_d < _bd) { _bd = _d; _best = id; } }
    if (_best == noone) { charge_t = 10; return; } // nothing near: check again soon
    var _z = instance_create_layer(x, y, "Instances", obj_zap);
    _z.points = [[x, y], [_best.x, _best.y]];
    fx_spark(_best.x, _best.y);
    sfx(snd_zap, 0.4, 0.85, 0.1); // a bit lower than the Tesla
    _best.take_hit(CHARGE_DMG);
    charge_flash = 8;
}

/// Occupied: launches a homing missile at the station every OCC_RATE seconds while on screen.
function ast_occupied() {
    if (!in_view(x, y)) return;
    occ_t--;
    if (occ_t > 0) return;
    occ_t = OCC_RATE * game_get_speed(gamespeed_fps);
    var _out = point_direction(STATION_X, STATION_Y, x, y) + random_range(-50, 50); // launches away, then curls round
    var _m = instance_create_layer(x + lengthdir_x(radius, _out), y + lengthdir_y(radius, _out), "Instances", obj_pirate_missile);
    _m.dir = _out;
    _m.image_angle = _out;
    _m.damage *= OCC_DMG;
    sfx(snd_missile_launch, 0.4, 0.8, 0.1);
}

/// Warp: idle -> shrinking -> gone (deactivated by obj_game) -> growing back.
/// Returns true while the rock is mid-warp and shouldn't do anything else this frame.
function ast_warp() {
    switch (warp_phase) {
        case 0:
            if (!entered || !in_view(x, y)) return false;
            warp_t--;
            if (warp_t <= 0) { warp_phase = 1; warp_k = 1; sfx(snd_warp_out, 0.4, 1, 0.05); }
            return false;
        case 1: // shrinking: still moving and still hittable
            warp_k -= 1 / WARP_FADE;
            if (warp_k <= 0) {
                warp_k = 0;
                warp_phase = 2;
                fx_spark(x, y);
                var _gone = round(random_range(WARP_GONE_MIN, WARP_GONE_MAX) * game_get_speed(gamespeed_fps));
                x += vx * _gone * WARP_SKIP; // where it turns up again
                y += vy * _gone * WARP_SKIP;
                if (instance_exists(obj_game)) array_push(obj_game.warped, [id, _gone]);
                instance_deactivate_object(id); // out of existence: nothing can target or hit it
                return true;
            }
            return false;
        case 2: // just reactivated by obj_game: grow back in
            warp_phase = 3;
            fx_spark(x, y);
            sfx(snd_warp_in, 0.4, 1, 0.05);
            return false;
        case 3:
            warp_k += 1 / WARP_FADE;
            if (warp_k >= 1) {
                warp_k = 1;
                warp_phase = 0;
                warp_t = random_range(WARP_EVERY_MIN, WARP_EVERY_MAX) * game_get_speed(gamespeed_fps);
            }
            return false;
    }
    return false;
}

/// obj_game: brings warped rocks back once their time is up. Done every tick, whatever the condition,
/// so changing it (debug) never strands a rock.
function warp_tick() {
    for (var i = array_length(warped) - 1; i >= 0; i--) {
        warped[i][1]--;
        if (warped[i][1] <= 0) {
            instance_activate_object(warped[i][0]);
            array_delete(warped, i, 1);
        }
    }
}

/// Glass outline shade: tiny rocks get the brightest outline, large the dimmest.
/// Glass outline grey by size (tiny to large): dim enough to blend into space and never bloom;
/// smaller rocks a touch lighter so they can still be found. Raise these to make glass easier to spot.
function glass_colour(_s) { static g = [72, 60, 50, 42]; return make_colour_rgb(g[_s], g[_s], g[_s]); }

/// Whether a bullet or laser hitting _hit should ricochet off it.
function ast_deflects(_hit) {
    return _hit.object_index == obj_asteroid && (_hit.rubber || _hit.armoured);
}

/// Reflects a projectile moving (_vx, _vy) off asteroid _a. (_px, _py) = where it was last frame,
/// outside the rock. Returns the new velocity and a position just clear of the surface.
function ast_bounce(_a, _px, _py, _vx, _vy, _r) {
    var _nx = _px - _a.x, _ny = _py - _a.y;
    var _nd = point_distance(0, 0, _nx, _ny);
    if (_nd < 0.001) { _nx = -_vx; _ny = -_vy; _nd = max(0.001, point_distance(0, 0, _nx, _ny)); }
    _nx /= _nd;
    _ny /= _nd;
    var _dot = _vx * _nx + _vy * _ny;
    if (_dot < 0) { _vx -= 2 * _dot * _nx; _vy -= 2 * _dot * _ny; }
    var _off = _a.radius + _r + 1;
    return { vx: _vx, vy: _vy, x: _a.x + _nx * _off, y: _a.y + _ny * _off };
}

function explode_radius(_s) { static a = [40, 70, 110, 170]; return a[_s]; }
function explode_damage(_s) { static a = [3, 8, 18, 40];     return a[_s] * threat_hp_mult(); }

// --- Rock-on-rock contact (sticky and dense days) ---------------------------------

function ast_mass(_a) { return _a.radius * _a.radius; }

/// Checks every pair of on-screen rocks once and sticks or knocks the ones touching.
/// _dense_only: knock only pairs where at least one rock is dense (white hole spew on another day).
function ast_contacts(_mode, _dense_only = false) {
    if (oc_freeze()) return; // frozen rocks don't knock or stick
    var _pt = perf_t();
    var _list = [], _rmax = 1;
    with (obj_asteroid) if (!dead && !is_boss && entered && nocollide <= 0) { array_push(_list, id); _rmax = max(_rmax, radius); }
    var _n = array_length(_list);
    // Spatial grid: cells at least as wide as the biggest touching distance, so a rock only needs
    // checking against the rocks in its own and the 8 neighbouring cells (not every rock on screen)
    var _cell = _rmax * 2, _grid = {}, _cx = array_create(_n), _cy = array_create(_n);
    for (var i = 0; i < _n; i++) {
        _cx[i] = floor(_list[i].x / _cell);
        _cy[i] = floor(_list[i].y / _cell);
        var _k = string(_cx[i]) + "," + string(_cy[i]);
        var _arr = _grid[$ _k];
        if (_arr == undefined) { _arr = []; _grid[$ _k] = _arr; }
        array_push(_arr, i);
    }
    for (var i = 0; i < _n; i++) {
        var _a = _list[i];
        for (var _gx = -1; _gx <= 1; _gx++) for (var _gy = -1; _gy <= 1; _gy++) {
            if (!instance_exists(_a) || _a.dead) break;
            var _cellv = _grid[$ string(_cx[i] + _gx) + "," + string(_cy[i] + _gy)];
            if (_cellv == undefined) continue;
            for (var c = 0; c < array_length(_cellv); c++) {
                var j = _cellv[c];
                if (j <= i) continue; // each pair once
                if (!instance_exists(_a) || _a.dead) break;
                var _b = _list[j];
                if (!instance_exists(_b) || _b.dead) continue;
                var _dx = _b.x - _a.x, _dy = _b.y - _a.y, _rr = _a.radius + _b.radius;
                if (abs(_dx) > _rr || abs(_dy) > _rr) continue;
                var _d = sqrt(_dx * _dx + _dy * _dy);
                if (_d >= _rr) continue;
                if (_dense_only && !_a.dense && !_b.dense && !_a.armoured && !_b.armoured) continue;
                if (_mode == COND.SOLID) ast_knock(_a, _b, _dx, _dy, _d, _rr);
                else ast_stick(_a, _b);
            }
        }
    }
    perf_add("rock_contacts", _pt);
}

/// A sticky or dense boss (late-tier modifier): rocks touching it stick to it or get knocked
/// (ast_contacts leaves bosses out, so this runs from the boss's own Step).
function boss_contacts(_b) {
    with (obj_asteroid) {
        if (dead || is_boss || !entered || nocollide > 0 || anchor == _b) continue;
        var _dx = x - _b.x, _dy = y - _b.y, _rr = radius + _b.radius;
        if (abs(_dx) > _rr || abs(_dy) > _rr) continue;
        var _d = sqrt(_dx * _dx + _dy * _dy);
        if (_d >= _rr) continue;
        if (_b.sticky) ast_stick(_b, id);
        else ast_knock(_b, id, _dx, _dy, _d, _rr);
    }
}

/// Dense field: push two touching rocks apart, bounce them by mass, and damage both by how hard they met.
function ast_knock(_a, _b, _dx, _dy, _d, _rr) {
    if (_d < 0.001) { _dx = 1; _dy = 0; _d = 1; }
    var _nx = _dx / _d, _ny = _dy / _d;
    var _ma = ast_mass(_a), _mb = ast_mass(_b), _mt = _ma + _mb;
    var _over = _rr - _d;
    _a.x -= _nx * _over * _mb / _mt;  _a.y -= _ny * _over * _mb / _mt;
    _b.x += _nx * _over * _ma / _mt;  _b.y += _ny * _over * _ma / _mt;

    var _rel = (_a.vx - _b.vx) * _nx + (_a.vy - _b.vy) * _ny; // closing speed (> 0 = moving together)
    if (_rel <= 0) return;
    var _j = (1 + SOLID_KEEP) * _rel / _mt;
    _a.vx -= _j * _mb * _nx;  _a.vy -= _j * _mb * _ny;
    _b.vx += _j * _ma * _nx;  _b.vy += _j * _ma * _ny;
    fx_spark(_a.x + _nx * _a.radius, _a.y + _ny * _a.radius);
    if (_rel > 1) sfx(snd_bump, min(0.5, 0.1 * _rel), 1, 0.15); // harder knocks are louder

    // The lighter rock comes off worse
    var _da = (_a.knock_cd <= 0) ? _a.max_hp * SOLID_DMG * _rel * 2 * _mb / _mt : 0;
    var _db = (_b.knock_cd <= 0) ? _b.max_hp * SOLID_DMG * _rel * 2 * _ma / _mt : 0;
    if (_da > 0) _a.knock_cd = SOLID_CD;
    if (_db > 0) _b.knock_cd = SOLID_CD;
    if (_a.armoured) _da = 0; // armour takes no knock damage, from any rock (armoured ones included)
    if (_b.armoured) _db = 0;
    if (_da > 0) _a.take_hit(_da, "knock"); // armour already skipped above; "knock" kills pay no charge
    if (_db > 0 && instance_exists(_b)) _b.take_hit(_db, "knock");
}

/// The clump a rock belongs to: its centre rock (itself if it's free or the centre).
function ast_root(_a) { return (_a.anchor != noone && instance_exists(_a.anchor) && !_a.anchor.dead) ? _a.anchor : _a; }

/// Every rock in the clump centred on _root, _root first.
function ast_group(_root) {
    var _g = [_root];
    with (obj_asteroid) if (anchor == _root && !dead) array_push(_g, id);
    return _g;
}

/// Sticky field: if either rock is sticky, the lighter clump joins the heavier one.
function ast_stick(_a, _b) {
    if (!_a.sticky && !_b.sticky) return;
    var _ra = ast_root(_a), _rb = ast_root(_b);
    if (_ra == _rb) return;
    var _ga = ast_group(_ra), _gb = ast_group(_rb);
    if (array_length(_ga) + array_length(_gb) > STICKY_MAX) return; // full: they slide past
    var _ma = 0, _mb = 0;
    for (var i = 0; i < array_length(_ga); i++) _ma += ast_mass(_ga[i]);
    for (var i = 0; i < array_length(_gb); i++) _mb += ast_mass(_gb[i]);
    var _win = (_ma >= _mb) ? _ra : _rb;
    var _gl  = (_ma >= _mb) ? _gb : _ga;

    // Momentum by mass: the clump heads mostly where the heavier side was going
    var _vx = (_ra.vx * _ma + _rb.vx * _mb) / (_ma + _mb);
    var _vy = (_ra.vy * _ma + _rb.vy * _mb) / (_ma + _mb);
    _win.vx = _vx;
    _win.vy = _vy;

    // The lighter clump's rocks pin themselves to the centre rock where they are now
    for (var i = 0; i < array_length(_gl); i++) {
        var _m = _gl[i];
        _m.anchor = _win;
        _m.a_dist = point_distance(_win.x, _win.y, _m.x, _m.y);
        _m.a_dir  = point_direction(_win.x, _win.y, _m.x, _m.y) - _win.image_angle;
        _m.a_ang  = _m.image_angle - _win.image_angle;
        _m.spin_kick = 0;
        _m.squash = 1;
    }
    var _reach = 0;
    with (obj_asteroid) if (anchor == _win) _reach = max(_reach, a_dist + radius);
    _win.reach = _reach;
    _win.squash = 1;
    fx_spark((_a.x + _b.x) / 2, (_a.y + _b.y) / 2);
    sfx(snd_sticky, 0.45, 1, 0.1);
}

// --- Spawners and effects ----------------------------------------------------------

/// Opens a black hole somewhere on screen, clear of the station.
function spawn_blackhole() { return spawn_hole(obj_blackhole); }

/// Opens a black or white hole (_obj) somewhere on screen, clear of the station.
function spawn_hole(_obj) {
    var _ang = random(360);
    var _max = max(340, min(view_w(), view_h()) / 2 - 80);
    var _d   = random_range(320, _max);
    return instance_create_depth(STATION_X + lengthdir_x(_d, _ang), STATION_Y + lengthdir_y(_d, _ang), 20, _obj);
}

/// White hole spew: one piece of loot, or (WH_ROCK_CHANCE) an asteroid of a random size that may
/// carry a modifier. Flies straight out of the core at (_x, _y). Returns [instance, cruise vx, cruise vy]:
/// the hole throws it at WH_THROW until it's clear of the implosion ring, then lets it cruise.
function wh_spew(_x, _y) {
    var _dir = random(360);
    var _sp  = random_range(WH_SPEW_MIN, WH_SPEW_MAX);
    if (random(1) >= WH_ROCK_CHANCE) {
        var _p = instance_create_layer(_x + lengthdir_x(WH_CORE * 0.5, _dir), _y + lengthdir_y(WH_CORE * 0.5, _dir), "Instances", obj_pickup);
        _p.set_type(ast_roll_type());
        _p.vx = lengthdir_x(WH_THROW, _dir);
        _p.vy = lengthdir_y(WH_THROW, _dir);
        return [_p, lengthdir_x(_sp, _dir), lengthdir_y(_sp, _dir)];
    }
    var _s = choose(AST.TINY, AST.TINY, AST.SMALL, AST.SMALL, AST.MEDIUM, AST.LARGE);
    var _a = instance_create_layer(_x + lengthdir_x(WH_CORE, _dir), _y + lengthdir_y(WH_CORE, _dir), "Instances", obj_asteroid);
    _a.init(_s, ast_roll_type());
    _a.entered   = true;            // born on screen: wraps straight away
    _a.nocollide = FRAG_NOCOLLIDE;  // don't knock or stick to its siblings at the mouth
    _a.squash    = 1;
    var _rs = ast_speed(_s) * threat_speed_mult() * random_range(1, WH_FAST) * quick_speed_mult(); // up to 50% faster than normal
    _a.vx = lengthdir_x(WH_THROW, _dir);
    _a.vy = lengthdir_y(WH_THROW, _dir);
    if (random(1) < WH_GILD_CHANCE) _a.gilded = true; // white holes are rich in gilded rocks
    else if (random(1) < WH_MOD_CHANCE) {
        switch (irandom(3)) {
            case 0: _a.explosive = true; break;
            case 1: _a.dense     = true; break;
            case 2: if (_s >= AST.MEDIUM) _a.occupied = true; else _a.armoured = true; break; // infested needs room for a crew
            case 3: _a.armoured  = true; break;
        }
    }
    fx_spark(_a.x, _a.y);
    return [_a, lengthdir_x(_rs, _dir), lengthdir_y(_rs, _dir)];
}

/// Ion storm: one bolt across the screen. A ragged path from beyond one edge to beyond the
/// opposite one, through a random spot on screen; obj_ion_bolt flickers it, then strikes.
function spawn_ion_bolt() {
    var _dir = random(360);
    var _cx = STATION_X + random_range(-0.45, 0.45) * view_w();
    var _cy = STATION_Y + random_range(-0.45, 0.45) * view_h();
    var _half = play_radius();
    var _x = _cx - lengthdir_x(_half, _dir), _y = _cy - lengthdir_y(_half, _dir);
    var _pts = [[_x, _y]];
    var _side = 0; // sideways wander, drifting kink to kink so it zig-zags rather than jitters
    for (var _d = 0; _d < _half * 2; ) {
        _d = min(_half * 2, _d + random_range(ION_STEP_MIN, ION_STEP_MAX));
        _side = clamp(_side + random_range(-ION_KINK, ION_KINK), -ION_KINK * 2, ION_KINK * 2);
        array_push(_pts, [_x + lengthdir_x(_d, _dir) + lengthdir_x(_side, _dir + 90),
                          _y + lengthdir_y(_d, _dir) + lengthdir_y(_side, _dir + 90)]);
    }
    var _b = instance_create_depth(0, 0, -12, obj_ion_bolt);
    _b.points = _pts;
    // Splinter: a second ragged arc from the kink nearest the station down to its hull
    if (instance_exists(obj_station) && random(1) < ION_SPLINTER) {
        var _sx = _pts[0][0], _sy = _pts[0][1], _sd = infinity;
        for (var i = 0; i < array_length(_pts); i++) {
            var _dd = point_distance(_pts[i][0], _pts[i][1], STATION_X, STATION_Y);
            if (_dd < _sd) { _sd = _dd; _sx = _pts[i][0]; _sy = _pts[i][1]; }
        }
        var _to  = point_direction(_sx, _sy, STATION_X, STATION_Y);
        var _len = max(0, _sd - STATION_RADIUS); // ends on the hull, not the centre
        var _br  = [[_sx, _sy]];
        var _wob = 0;
        for (var _d = 0; _d < _len; ) {
            _d = min(_len, _d + random_range(ION_STEP_MIN, ION_STEP_MAX) * 0.6);
            _wob = (_d >= _len) ? 0 : clamp(_wob + random_range(-ION_KINK, ION_KINK) * 0.6, -ION_KINK, ION_KINK);
            array_push(_br, [_sx + lengthdir_x(_d, _to) + lengthdir_x(_wob, _to + 90),
                             _sy + lengthdir_y(_d, _to) + lengthdir_y(_wob, _to + 90)]);
        }
        if (array_length(_br) > 1) _b.branch = _br;
    }
    return _b;
}

/// Distance from (_px, _py) to the segment (_x1, _y1)-(_x2, _y2).
function dist_to_seg(_px, _py, _x1, _y1, _x2, _y2) {
    var _dx = _x2 - _x1, _dy = _y2 - _y1;
    var _l2 = _dx * _dx + _dy * _dy;
    var _t = (_l2 > 0) ? clamp(((_px - _x1) * _dx + (_py - _y1) * _dy) / _l2, 0, 1) : 0;
    return point_distance(_px, _py, _x1 + _t * _dx, _y1 + _t * _dy);
}

/// Distance from (_px, _py) to the nearest point of a polyline [[x, y], ...].
function dist_to_path(_px, _py, _pts) {
    var _best = infinity;
    for (var i = 0; i < array_length(_pts) - 1; i++) {
        _best = min(_best, dist_to_seg(_px, _py, _pts[i][0], _pts[i][1], _pts[i + 1][0], _pts[i + 1][1]));
    }
    return _best;
}

/// One meteor of a burst travelling in direction _dir, on a line offset from the station.
/// The offset covers the view's full width across the direction of travel, so rain from
/// above or below spans the wide screen as well as rain from the side does.
function spawn_meteor(_dir) {
    var _half = view_w() / 2 * abs(dsin(_dir)) + view_h() / 2 * abs(dcos(_dir)) + METEOR_SPREAD;
    var _off = random_range(-_half, _half);
    var _x = STATION_X - lengthdir_x(play_radius(), _dir) + lengthdir_x(_off, _dir + 90);
    var _y = STATION_Y - lengthdir_y(play_radius(), _dir) + lengthdir_y(_off, _dir + 90);
    var _m = instance_create_depth(_x, _y, -4, obj_meteor);
    var _md = _dir + random_range(-3, 3);
    var _sp = METEOR_SPEED * random_range(0.85, 1.15);
    _m.vx = lengthdir_x(_sp, _md);
    _m.vy = lengthdir_y(_sp, _md);
    _m.impact = ast_impact(AST.TINY) * METEOR_IMPACT * threat_impact_mult();
    _m.dmg    = ast_hp(AST.SMALL) * METEOR_DMG * threat_hp_mult();
    return _m;
}
