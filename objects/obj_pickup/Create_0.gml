/// Loose resource. Only counts once a collection ship brings it home.
depth = 10;
res = RES.ORE;
var _dir = random(360);
var _spd = random_range(1.5, 4); // pops out of the asteroid
vx = lengthdir_x(_spd, _dir);
vy = lengthdir_y(_spd, _dir);
spin = random_range(-4, 4);
claimed_by  = noone; // collector currently pulling this in
targeted_by = noone; // collector currently flying towards this
carried = false;
tractored = false;  // caught by the tractor wave: flies straight into the station
tr_spd = 0;     // true once it's in a ship's hold (still visible, follows the ship)
slot = 0;            // position in the hold cluster
age = 0;             // frames alive: drives the spawn pop and hop
pull_spd = 1;        // speeds up while a ship's magnet reels it in
magnet = false;      // a Magnet drop (scr_conditions magnet_drop): never banked, pulls in all loose loot instead
mag_pulled = false;
fee_free = false;    // special drop (gilded rock, boss): the rebuild fee never takes it (loot_drop)  // being hauled home by a collected Magnet (flies faster than the tractor)
#macro PICKUP_POP 16  // frames of the spawn pop

set_type = function(_r) {
    res = _r;
    sprite_index = res_sprite(_r);
};

// Stack: how many resources this piece banks for (loot_drop in scr_config). Bigger stacks are drawn bigger.
value = 1;
stack_scale = 1;
set_value = function(_v) {
    value = max(1, _v);
    stack_scale = min(2.2, 1 + 0.35 * (sqrt(value) - 1)); // 1 -> 1, 4 -> 1.35, 9 -> 1.7, 25+ -> 2.2
    image_xscale = stack_scale;
    image_yscale = stack_scale;
};
