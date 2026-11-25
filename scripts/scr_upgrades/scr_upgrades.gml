// ---------------------------------------------------------------------------
// Upgrade tree definition and derived stats.
// Grid positions (gx, gy) are in tree cells; (0,0) is the centre.
//   North = weapons, South = defence, East = logistics, West = mining.
// A node becomes visible once every node in `req` has UPG_REVEAL levels (half, rounded down, if it has fewer than 5).
// `tier` is the minimum tier (bosses beaten + 1) needed to buy it.
// `cost` is a list of [resource, base]; every part scales by growth ^ level,
// so rare-resource nodes still need ore and the basic currency never goes stale.
// Pacing was checked with a simple economy model (see balance notes).
// ---------------------------------------------------------------------------

#macro UPG_RANK_MAX 5   // no single node has more than this many levels; longer upgrades get rank II/III nodes

function upgrades_define() {
    global.upgrades = [];
    var O = RES.ORE, I = RES.ICE, C = RES.CRYSTAL, P = RES.PLATINUM, K = RES.CORE; // K = boss Cores

    // upg_add(id, name, desc, cost, growth, max, gx, gy, requires, tier)

    // Generated from Tech Tree.drawio (scratchpad gen_tree.py). Fill colour = cost:
    // red ore, blue +ice, purple +crystal, grey +platinum, green +boss Cores.
    // Multi-rank stats keep the old total levels (Damage 15, Fire Rate 10, Accuracy 5...),
    // split across more nodes, so a maxed station is as strong as before.
    var B = RES.BOX, H = RES.HAT;
    // upg_add(id, name, desc, cost, growth, max, gx, gy, requires, tier)
    upg_add("overcharge",       "Amplifier",               "+1 power to every weapon, active or passive",             [[O, 400], [I, 80], [C, 40], [P, 16], [K, 1]], 1.8  , 5,  -1,  -9, ["railgun"], 4);
    upg_add("firerate4",        "Fire Rate IV",            "+1 fire rate",                                            [[O, 103], [I, 21], [C, 10], [P, 4]],        1.5  , 2,  -3,  -8, ["dmg4"], 4);
    upg_add("dmg4",             "Damage IV",               "+1 damage",                                               [[O, 173], [I, 35], [C, 17], [P, 7]],        1.45 , 3,  -2,  -8, ["railgun"], 4);
    upg_add("rail_size",        "Rail Calibre",            "+1 rail calibre: loses less power per rock",              [[O, 350], [I, 70], [C, 35], [P, 14]],       1.7  , 5,   0,  -8, ["railgun"], 4);
    upg_add("accuracy3",        "Accuracy III",            "+1 accuracy",                                             [[O, 30], [I, 6], [C, 3]],                   1.5  , 1,  -2,  -7, ["dmg3"], 3);
    upg_add("rail_rate",        "Rail Reload",             "+1 rail fire rate",                                       [[O, 400], [I, 80], [C, 40], [P, 16]],       1.7  , 5,   0,  -7, ["railgun"], 4);
    upg_add("laser_refract",    "Refraction",              "Beam splits to +1 nearby rock",                           [[O, 500], [I, 100], [C, 50], [P, 20]],      1.9  , 3,   1,  -7, ["laser_width"], 4);
    upg_add("missile",          "Missile Launcher",        "Right-click fires missiles at the cursor. Hold to keep firing",                       [[H, 1]],                                    1    , 1,  -7,  -6, [], 1);
    // Missiles (Pirate Hat): ammo, hold right-click to keep firing. Blue = ore + ice, purple + crystal, grey + platinum.
    upg_add("msl_reload",       "Auto Loader",             "+1 reload: missile ammo recharges faster",                [[O, 300], [I, 60]],                         1.7  , 5,  -8,  -7, ["missile"], 2);
    upg_add("msl_yield",        "Yield",                   "+1 strength: bigger blast and shockwave",                 [[O, 300], [I, 60]],                         1.7  , 5,  -7,  -7, ["missile"], 2);
    upg_add("msl_speed",        "Boosters",                "+1 speed: missiles fly faster",                           [[O, 200], [I, 40]],                         1.6  , 5,  -6,  -7, ["missile"], 2);
    upg_add("msl_volley",       "Launch Tubes",            "+1 missile ammo",                                         [[O, 400], [I, 80], [C, 40]],                2    , 5,  -8,  -8, ["msl_reload"], 3);
    upg_add("msl_dmg",          "Warheads",                "+1 missile damage",                                       [[O, 300], [I, 60], [C, 30]],                1.7  , 5,  -7,  -8, ["msl_yield"], 3);
    upg_add("msl_compact",      "Compact Tubes",           "+1 missile per launch",                                   [[O, 600], [I, 120], [C, 60], [P, 24]],      2    , 4,  -8,  -9, ["msl_volley"], 4);
    upg_add("msl_cluster",      "Cluster Warheads",        "Each missile bursts into 5 smaller blasts",               [[O, 1500], [I, 300], [C, 150], [P, 60]],    1    , 1,  -7,  -9, ["msl_dmg"], 4);
    upg_add("firerate3",        "Fire Rate III",           "+1 fire rate",                                            [[O, 46], [I, 9], [C, 5]],                   1.5  , 2,  -3,  -6, ["dmg3"], 3);
    upg_add("dmg3",             "Damage III",              "+1 damage",                                               [[O, 39], [I, 8], [C, 4]],                   1.45 , 4,  -2,  -6, ["laser"], 3);
    upg_add("railgun",          "Rail Gun",                "A piercing slug that weakens with every rock it punches through", [[O, 1500], [I, 300], [C, 150], [P, 60]],    1    , 1,  -1,  -6, ["laser"], 4);
    upg_add("laser_focus",      "Laser Focus",             "+1 laser focus",                                          [[O, 300], [I, 60], [C, 30]],                1.7  , 5,   0,  -6, ["laser"], 3);
    upg_add("laser_width",      "Laser Width",             "+1 laser width",                                          [[O, 250], [I, 50], [C, 25]],                1.7  , 5,   1,  -6, ["laser_focus"], 3);
    upg_add("accuracy2",        "Accuracy II",             "+1 accuracy",                                             [[O, 14], [I, 3]],                           1.5  , 2,   2,  -6, ["dmg2"], 2);
    upg_add("passive_dmg3",     "Passive Damage III",      "+1 passive weapon damage",                                [[O, 2684], [I, 537], [C, 268], [P, 107]],   1.6  , 3,  -4,  -5, ["passive_dmg2"], 4);
    upg_add("passive_dmg2",     "Passive Damage II",       "+1 passive weapon damage",                                [[O, 655], [I, 131], [C, 66]],               1.6  , 3,  -3,  -5, ["passive_size"], 3);
    upg_add("laser",            "Laser",                   "A beam that heats up the longer it stays on one target",  [[O, 800], [I, 160], [C, 80]],               1    , 1,  -1,  -5, ["tesla"], 3);
    upg_add("dmg2",             "Damage II",               "+1 damage",                                               [[O, 9], [I, 2]],                            1.45 , 4,   1,  -5, ["tesla"], 2);
    upg_add("firerate2",        "Fire Rate II",            "+1 fire rate",                                            [[O, 14], [I, 3]],                           1.5  , 3,   2,  -5, ["dmg2"], 2);
    upg_add("passive_rate2",    "Passive Fire Rate II",    "+1 passive fire rate",                                    [[O, 590], [I, 118], [C, 59], [P, 24]],      1.7  , 2,  -3,  -4, ["passive_track"], 4);
    upg_add("passive_size",     "Passive Calibre",         "+1 passive shot size",                                    [[O, 200], [I, 40], [C, 20]],                1.7  , 5,  -2,  -4, ["passive_dmg"], 3);
    upg_add("passive_dmg",      "Passive Damage I",        "+1 passive weapon damage",                                [[O, 100], [I, 20]],                         1.6  , 4,  -1,  -4, ["tesla"], 2);
    upg_add("zap_chain",        "Chain Lightning I",       "+1 lightning bounce",                                     [[O, 120], [I, 24]],                         1.9  , 3,   1,  -4, ["tesla"], 2);
    upg_add("zap_jump",         "Arc Reach",               "+1 arc reach",                                            [[O, 100], [I, 20], [C, 10]],                1.7  , 5,   2,  -4, ["zap_chain"], 3);
    upg_add("zap_chain2",       "Chain Lightning II",      "+1 lightning bounce",                                     [[O, 823], [I, 165], [C, 82], [P, 33]],      1.9  , 2,   3,  -4, ["zap_jump"], 4);
    upg_add("oc_time2",         "Overcharge Duration II",  "+1 Overcharge duration",                                  [[O, 197], [I, 39], [C, 20]],                1.7  , 2,   4,  -4, ["oc_zap_chain"], 3);
    upg_add("jump_drive5",      "Jump Drive V",            "Jump to a richer, deadlier sector",                       [[O, 7594], [I, 1519], [C, 759], [P, 304], [K, 4]], 1.5  , 1,  -9,  -3, ["jump_drive4"], 8);
    upg_add("burst2",           "Burst Fire II",           "+1 shot per trigger pull",                                [[O, 125], [I, 25], [C, 12]],                2.5  , 3,  -4,  -3, ["ricochet"], 3);
    upg_add("bullet_speed",     "Bullet Speed",            "+15% bullet speed",                                       [[O, 60], [I, 12]],                          1.6  , 5,  -4,  -4, ["ricochet"], 2);
    upg_add("combat_hud",       "Combat HUD",              "Shows main and passive damage per second",                [[O, 150], [I, 30]],                         1    , 1,   0,  -4, ["tesla"], 2);
    upg_add("ricochet",         "Hard Bullets",            "+1 ricochet",                                             [[O, 60], [I, 12]],                          2.3  , 4,  -3,  -3, ["burst"], 2);
    upg_add("passive_track",    "Passive Tracking",        "+1 passive tracking",                                     [[O, 120], [I, 24], [C, 12]],                1.7  , 5,  -2,  -3, ["passive_rate"], 3);
    upg_add("passive_rate",     "Passive Fire Rate I",     "+1 passive fire rate",                                    [[O, 120], [I, 24]],                         1.7  , 3,  -1,  -3, ["tesla"], 2);
    upg_add("tesla",            "Tesla Coil",              "Lightning: strikes at the cursor when active, the nearest rock when passive", [[O, 200], [I, 40]],                         1    , 1,   0,  -3, ["dmg"], 2);
    upg_add("oc_zap_dmg",       "Overcharge Arcs",         "+1 Overcharge lightning damage",                          [[O, 80], [I, 16]],                          1.7  , 5,   1,  -3, ["oc_size"], 2);
    upg_add("oc_rate",          "Overcharge Fire Rate",    "+1 Overcharge fire rate",                                 [[O, 50]],                                   1.7  , 5,   2,  -3, ["oc_time"], 1);
    upg_add("oc_zap_chain",     "Overcharge Chains",       "+1 Overcharge lightning bounce",                          [[O, 100], [I, 20]],                         1.8  , 5,   3,  -3, ["oc_rate"], 2);
    upg_add("tr_power",         "Tractor Power",           "+1 tractor power",                                        [[O, 40], [I, 8]],                           1.65 , 5,   4,  -3, ["tractor"], 2);
    upg_add("tr_uptime",        "Tractor Uptime",          "+1 tractor uptime",                                       [[O, 60], [I, 12], [C, 6]],                  1.7  , 5,   5,  -3, ["tr_power"], 3);
    upg_add("jump_drive4",      "Jump Drive IV",           "Jump to a richer, deadlier sector",                       [[O, 5062], [I, 1012], [C, 506], [P, 202], [K, 4]], 1.5  , 1,  -9,  -2, ["jump_drive3"], 7);
    upg_add("plat_rate",        "Metal Prospecting",       "+2% metallic asteroids",                                  [[O, 300], [I, 60], [C, 30], [P, 12]],       1.6  , 5,  -5,  -2, ["unlock_platinum"], 4);
    upg_add("crystal_rate",     "Silicate Prospecting",    "+2.5% silicate asteroids",                                [[O, 120], [I, 24], [C, 12]],                1.6  , 5,  -4,  -2, ["unlock_crystal"], 3);
    upg_add("ice_rate",         "Ice Prospecting",         "+3% ice asteroids",                                       [[O, 40], [I, 8]],                           1.6  , 5,  -3,  -2, ["unlock_ice"], 2);
    upg_add("burst",            "Burst Fire",              "+1 shot per trigger pull",                                [[O, 20]],                                   2.5  , 2,  -2,  -2, ["firerate"], 1);
    upg_add("accuracy",         "Accuracy I",              "+1 accuracy",                                             [[O, 6]],                                    1.5  , 2,  -1,  -2, ["firerate"], 1);
    upg_add("oc_size",          "Overcharge Shot Size",    "+1 Overcharge shot size",                                 [[O, 50]],                                   1.7  , 5,   1,  -2, ["oc_time"], 1);
    upg_add("tractor",          "Tractor Beam",            "A beam that hauls loot home",                             [[O, 90], [I, 18]],                          1    , 1,   2,  -2, ["capacity"], 2);
    upg_add("tr_range",         "Tractor Reach",           "+1 tractor reach",                                        [[O, 40], [I, 8]],                           1.65 , 5,   3,  -2, ["tractor"], 2);
    upg_add("tr_width",         "Tractor Spread",          "+1 tractor width",                                        [[O, 40], [I, 8], [C, 4]],                   1.65 , 5,   4,  -2, ["tr_range"], 3);
    upg_add("jump_drive3",      "Jump Drive III",          "Jump to a richer, deadlier sector",                       [[O, 3375], [I, 675], [C, 338], [P, 135], [K, 4]], 1.5  , 1,  -9,  -1, ["jump_drive2"], 6);
    upg_add("jump_drive2",      "Jump Drive II",           "Jump to a richer, deadlier sector",                       [[O, 2250], [I, 450], [C, 225], [P, 90], [K, 4]], 1.5  , 1,  -8,  -1, ["jump_drive"], 5);
    upg_add("jump_drive",       "Jump Drive I",            "Jump to a richer, deadlier sector",                       [[O, 1500], [I, 300], [C, 150], [P, 60], [K, 4]], 1.5  , 1,  -7,  -1, ["unlock_platinum"], 4);
    upg_add("unlock_platinum",  "Sector 4: Contains Metallic Asteroids", "Expand into a new sector: metallic asteroids appear",                               [[O, 400], [I, 80], [C, 40], [K, 1]],        1    , 1,  -5,  -1, ["unlock_crystal"], 3);
    upg_add("unlock_crystal",   "Sector 3: Contains Crystalized Silicate Asteroids", "Expand into a new sector: crystallised silicate asteroids appear",                                [[O, 150], [I, 30], [K, 1]],                 1    , 1,  -4,  -1, ["unlock_ice"], 2);
    upg_add("unlock_ice",       "Sector 2: Contains Ice Asteroids", "Expand into a new sector: ice asteroids appear",                                    [[O, 40], [K, 1]],                           1    , 1,  -3,  -1, ["more_ast"], 1);
    upg_add("bsize",            "Shot Size",               "+1 shot size",                                            [[O, 12]],                                   1.6  , 5,  -2,  -1, ["firerate"], 1);
    upg_add("firerate",         "Fire Rate I",             "+1 fire rate",                                            [[O, 4]],                                    1.5  , 3,  -1,  -1, ["dmg"], 1);
    upg_add("dmg",              "Damage I",                "+1 damage",                                               [[O, 2]],                                    1.45 , 4,   0,  -1, ["core"], 1);
    upg_add("oc_time",          "Overcharge Duration I",   "+1 Overcharge duration",                                  [[O, 40]],                                   1.7  , 3,   1,  -1, ["dmg"], 1);
    upg_add("capacity",         "Cargo Holds I",           "+2 cargo per ship",                                       [[O, 6]],                                    1.5  , 5,   2,  -1, ["ship_speed"], 1);
    upg_add("magnet",           "Magnet Coils",            "Ships pull in loot from further away",                    [[O, 25], [I, 5]],                           1.8  , 5,   3,  -1, ["capacity"], 2);
    upg_add("capacity2",        "Cargo Holds II",          "+2 cargo per ship",                                       [[O, 46], [I, 9]],                           1.5  , 5,   4,  -1, ["magnet"], 2);
    upg_add("fighter_dmg",      "Fighter Damage I",        "+1 fighter damage",                                       [[O, 120], [I, 24], [C, 12]],                1.6  , 5,   5,  -1, ["fighters"], 3);
    upg_add("fighter_burst",    "Burst Lasers",            "+1 laser per burst",                                      [[O, 300], [I, 60], [C, 30], [P, 12]],       2.2  , 3,   6,  -1, ["fighter_dmg"], 4);
    upg_add("fighter_dmg2",     "Fighter Damage II",       "+1 fighter damage",                                       [[O, 1258], [I, 252], [C, 126], [P, 50]],    1.6  , 5,   7,  -1, ["fighter_burst"], 4);
    upg_add("day_length3",      "Long Shift III",          "+8 seconds per day",                                      [[O, 431], [I, 86], [C, 43], [P, 17]],       1.75 , 3,  -6,   0, ["day_length2"], 4);
    upg_add("day_length2",      "Long Shift II",           "+8 seconds per day",                                      [[O, 80], [I, 16], [C, 8]],                  1.75 , 3,  -5,   0, ["overtime2"], 3);
    upg_add("overtime2",        "Overtime II",             "+2s from every time bonus",                               [[O, 568], [I, 114], [C, 57]],               1.7  , 5,  -4,   0, ["quota"], 3);
    upg_add("overtime",         "Overtime I",              "+2s from every time bonus",                               [[O, 40]],                                   1.7  , 5,  -3,   0, ["day_length"], 1);
    upg_add("day_length",       "Long Shift I",            "+8 seconds per day",                                      [[O, 15]],                                   1.75 , 3,  -2,   0, ["more_ast"], 1);
    upg_add("more_ast",         "Lure I",                  "Asteroids arrive 22% more often",                         [[O, 5]],                                    1.5  , 5,  -1,   0, ["core"], 1);
    upg_add("core",             "Command Core",            "Your mining station",                                     [],                                          1    , 1,   0,   0, [], 1);
    upg_add("ship_speed",       "Collector Speed",         "Faster collection ships",                                 [[O, 3]],                                    1.45 , 5,   1,   0, ["core"], 1);
    upg_add("ships",            "Hangar Bay I",            "+1 collection ship",                                      [[O, 40]],                                   2    , 2,   3,   0, ["ship_speed"], 1);
    upg_add("fighters",         "Fighter Bay",             "A fighter that hunts raiders",                            [[O, 400], [I, 80], [C, 40]],                1    , 1,   4,   0, ["ships"], 3);
    upg_add("fighter_count",    "Fighter Bay II",          "+1 fighter",                                              [[O, 500], [I, 100], [C, 50], [P, 20]],      1    , 1,   6,   0, ["fighters"], 4);
    upg_add("fighter_speed",    "Afterburners",            "+1 fighter speed",                                        [[O, 100], [I, 20], [C, 10], [P, 4]],        1.5  , 5,   7,   0, ["fighter_count"], 4);
    upg_add("quota2",           "Lower Quotas II",         "+1 lower quotas: time bonuses need less cargo",           [[O, 710], [I, 142], [C, 71], [P, 28]],      1.7  , 5,  -6,   1, ["time_cap"], 4);
    upg_add("time_cap",         "Extended Contract",       "+1 contract: each time bonus costs less extra than the last", [[O, 60], [I, 12], [C, 6]],                  1.75 , 5,  -5,   1, ["quota"], 3);
    upg_add("quota",            "Lower Quotas I",          "+1 lower quotas: time bonuses need less cargo",           [[O, 50], [I, 10]],                          1.7  , 5,  -4,   1, ["day_length"], 2);
    upg_add("big_break",        "Big Breaker I",           "+1 bonus loot when a large asteroid breaks",              [[O, 20]],                                   1.6  , 5,  -3,   1, ["bigger"], 1);
    upg_add("bigger",           "Heavy Lure I",            "More large asteroids",                                    [[O, 12]],                                   1.65 , 5,  -2,   1, ["more_ast"], 1);
    upg_add("regen",            "Repair Drones I",         "+1 hull repair",                                          [[O, 10]],                                   1.6  , 4,  -1,   1, ["hp"], 1);
    upg_add("hp",               "Hull I",                  "+1 hull",                                                 [[O, 2]],                                    1.4  , 5,   0,   1, ["core"], 1);
    upg_add("regen2",           "Repair Drones II",        "+1 hull repair",                                          [[O, 66], [I, 13]],                          1.6  , 3,   1,   1, ["shield"], 2);
    upg_add("ship_zap_dmg",     "Zap Damage",              "+1 collector zap damage",                                 [[O, 60], [I, 12]],                          1.6  , 5,   2,   1, ["ship_zap"], 2);
    upg_add("ship_zap",         "Charged Collectors",      "Collection ships zap nearby raiders and rocks as they fly", [[O, 150], [I, 30]],                         1    , 1,   3,   1, ["ships"], 2);
    upg_add("ship_rebuild",     "Collector Foundry",       "+1 collector rebuild speed",                              [[O, 90], [I, 18], [C, 9]],                  1.6  , 5,   4,   1, ["ship_zap"], 3);
    upg_add("fighter_hull",     "Fighter Hull",            "+1 fighter hull",                                         [[O, 100], [I, 20], [C, 10]],                1.6  , 5,   5,   1, ["fighters"], 3);
    upg_add("fighter_rate",     "Fighter Cooling",         "+1 fighter fire rate",                                    [[O, 150], [I, 30], [C, 15], [P, 6]],        1.7  , 5,   6,   1, ["fighter_hull"], 4);
    upg_add("more_ast2",        "Lure II",                 "Asteroids arrive 22% more often",                         [[O, 38], [I, 8]],                           1.5  , 5,  -3,   2, ["bigger"], 2);
    upg_add("ram",              "Spiked Hull",             "+1 spike damage to asteroids that hit you",               [[O, 15]],                                   1.6  , 5,  -2,   2, ["armour"], 1);
    upg_add("armour",           "Armour I",                "+1 armour",                                               [[O, 20]],                                   1.65 , 3,  -1,   2, ["hp"], 1);
    upg_add("shield",           "Shield Generator I",      "Regenerating forcefields that protect your station",      [[O, 30], [I, 6]],                           1.7  , 5,   0,   2, ["hp"], 2);
    upg_add("shield2",          "Shield Generator II",     "Regenerating forcefields that protect your station",      [[O, 426], [I, 85], [C, 43]],                1.7  , 5,   1,   2, ["regen2"], 3);
    upg_add("ship_zap_rate",    "Zap Recharge",            "+1 collector zap rate",                                   [[O, 70], [I, 14]],                          1.65 , 5,   2,   2, ["ship_zap"], 2);
    upg_add("ship_hull",        "Armoured Collectors",     "+1 collector hull",                                       [[O, 80], [I, 16], [C, 8]],                  1.6  , 5,   3,   2, ["ship_zap"], 3);
    upg_add("ships2",           "Hangar Bay II",           "+1 collection ship",                                      [[O, 160], [I, 32], [C, 16]],                2    , 1,   4,   2, ["ship_zap"], 3);
    upg_add("ships3",           "Hangar Bay III",          "+1 collection ship",                                      [[O, 320], [I, 64], [C, 32], [P, 13]],       2    , 1,   5,   2, ["ships2"], 4);
    upg_add("tiny_yield",       "Fine Sifting I",          "+1 loot from tiny asteroids",                             [[O, 10], [I, 2]],                           1.6  , 5,  -4,   3, ["more_ast2"], 2);
    upg_add("bigger2",          "Heavy Lure II",           "More large asteroids",                                    [[O, 147], [I, 29], [C, 15]],                1.65 , 5,  -3,   3, ["more_ast2"], 3);
    upg_add("big_break2",       "Big Breaker II",          "+1 bonus loot when a large asteroid breaks",              [[O, 210], [I, 42]],                         1.6  , 5,  -2,   3, ["more_ast2"], 2);
    upg_add("hp2",              "Hull II",                 "+1 hull",                                                 [[O, 11], [I, 2]],                           1.4  , 5,  -1,   3, ["armour"], 2);
    upg_add("freeze",           "Freeze Ray",              "Icy blasts that slow asteroids to a stop. Small rocks freeze fastest", [[O, 300], [I, 60], [C, 30]],                1    , 1,   1,   3, ["shield"], 3);
    upg_add("frz_rate",         "Cryo Cooldown",           "+1 freeze ray fire rate",                                 [[O, 120], [I, 24], [C, 12]],                1.7  , 5,   2,   3, ["freeze"], 3);
    upg_add("frz_life",         "Cryo Life",               "+1 freeze duration",                                      [[O, 120], [I, 24], [C, 12]],                1.7  , 5,   3,   3, ["frz_rate"], 3);
    upg_add("ship_ai",          "Collector AI",            "Collectors launch themselves whenever there's loot to collect", [[O, 1500], [I, 300], [C, 150], [P, 60]],    1    , 1,   5,   3, ["ships2"], 4);
    upg_add("more_ast4",        "Lure IV",                 "Asteroids arrive 22% more often",                         [[O, 2189], [I, 438], [C, 219], [P, 88]],    1.5  , 5,  -5,   4, ["tiny_yield2"], 4);
    upg_add("tiny_yield2",      "Fine Sifting II",         "+1 loot from tiny asteroids",                             [[O, 105], [I, 21], [C, 10], [P, 4]],        1.6  , 5,  -4,   4, ["more_ast3"], 4);
    upg_add("more_ast3",        "Lure III",                "Asteroids arrive 22% more often",                         [[O, 288], [I, 58], [C, 29]],                1.5  , 5,  -3,   4, ["bigger2"], 3);
    upg_add("regen3",           "Repair Drones III",       "+1 hull repair",                                          [[O, 268], [I, 54], [C, 27]],                1.6  , 3,  -2,   4, ["armour2"], 3);
    upg_add("armour2",          "Armour II",               "+1 armour",                                               [[O, 90], [I, 18]],                          1.65 , 2,  -1,   4, ["hp2"], 2);
    upg_add("drones",           "Guard Drone",             "An orbiting drone that rams asteroids",                   [[O, 300], [I, 60], [C, 30]],                1    , 1,   0,   4, ["shield"], 3);
    upg_add("repulsor",         "Repulsor",                "A pulsing ring that turns asteroids away",                [[O, 1200], [I, 240], [C, 120], [P, 48]],    1    , 1,   1,   4, ["freeze"], 4);
    upg_add("rep_range",        "Repulsor Reach",          "+1 repulsor reach",                                       [[O, 350], [I, 70], [C, 35], [P, 14]],       1.7  , 5,   2,   4, ["repulsor"], 4);
    upg_add("rep_power",        "Repulsor Power",          "+1 repulsor power",                                       [[O, 400], [I, 80], [C, 40], [P, 16]],       1.7  , 5,   3,   4, ["rep_range"], 4);
    upg_add("hp3",              "Hull III",                "+1 hull",                                                 [[O, 58], [I, 12], [C, 6]],                  1.4  , 5,  -1,   5, ["armour2"], 3);
    upg_add("drone_count",      "Drone Bay",               "+1 drone",                                                [[O, 150], [I, 30], [C, 15]],                2    , 2,   0,   5, ["drones"], 3);
    upg_add("drone_dmg",        "Drone Spikes",            "+1 drone ram damage",                                     [[O, 100], [I, 20], [C, 10]],                1.7  , 5,   1,   5, ["drones"], 3);
    upg_add("rep_width",        "Repulsor Frequency",      "+1 pulse frequency",                                      [[O, 350], [I, 70], [C, 35], [P, 14]],       1.7  , 5,   2,   5, ["repulsor"], 4);
    upg_add("fortress",         "Fortress Core",           "+1 hull and shield strength",                             [[O, 400], [I, 80], [C, 40], [P, 16]],       1.8  , 5,  -1,   6, ["hp3"], 4);
    upg_add("drone_regen",      "Drone Fabricator",        "+1 drone rebuild speed",                                  [[O, 80], [I, 16], [C, 8], [P, 3]],          1.6  , 5,   0,   6, ["drone_count"], 4);
    upg_add("rep_double",       "Double Pulse",            "Every pulse fires twice",                                 [[O, 1500], [I, 300], [C, 150], [P, 60]],    1    , 1,   2,   6, ["rep_width"], 4);
    upg_add("sink1",            "System Error",            "",                                                        [[O, 3000], [I, 600], [C, 300], [P, 120]],   1    , 1,   5,   7, ["ship_ai"], 4);
    upg_add("sink2",            "Unknown Variable",        "",                                                        [[O, 4500], [I, 900], [C, 450], [P, 180]],   1    , 1,   6,   7, ["sink1"], 4);
    upg_add("sink3",            "Firewall Breached",       "",                                                        [[O, 6750], [I, 1350], [C, 675], [P, 270]],  1    , 1,   7,   7, ["sink2"], 4);
    upg_add("sink4",            "Dumping System Memory",   "",                                                        [[O, 10125], [I, 2025], [C, 1012], [P, 405]], 1    , 1,   8,   7, ["sink3"], 4);
    upg_add("sink5",            "Shutdown Initiated",      "",                                                        [[O, 15188], [I, 3038], [C, 1519], [P, 608]], 1    , 1,   9,   7, ["sink4"], 4);
    upg_add("drone_armour",     "Drone Plating",           "Drones survive +1 hit",                                   [[O, 80], [I, 16], [C, 8], [P, 3]],          1.6  , 5,   0,   7, ["drone_regen"], 4);
    upg_add("sink10",           "£$%^%^&",                 "",                                                        [[O, 115330], [I, 23066], [C, 11533], [P, 4613]], 1    , 1,   5,   8, ["sink9"], 4);
    upg_add("sink9",            "IT IS HERE",              "",                                                        [[O, 76887], [I, 15377], [C, 7689], [P, 3075]], 1    , 1,   6,   8, ["sink8"], 4);
    upg_add("sink8",            "Unknown entity",          "",                                                        [[O, 51258], [I, 10252], [C, 5126], [P, 2050]], 1    , 1,   7,   8, ["sink7"], 4);
    upg_add("sink7",            "System Override",         "",                                                        [[O, 34172], [I, 6834], [C, 3417], [P, 1367]], 1    , 1,   8,   8, ["sink6"], 4);
    upg_add("sink6",            "Unable to shutdown",      "",                                                        [[O, 22781], [I, 4556], [C, 2278], [P, 911]], 1    , 1,   9,   8, ["sink5"], 4);
    upg_add("sink11",           "...",                     "",                                                        [[O, 172995], [I, 34599], [C, 17300], [P, 6920]], 1    , 1,   5,   9, ["sink10"], 4);
    upg_add("sink12",           "Hello...",                "",                                                        [[O, 259493], [I, 51899], [C, 25949], [P, 10380]], 1    , 1,   6,   9, ["sink11"], 4);
    upg_add("sink13",           "...world",                "",                                                        [[O, 389239], [I, 77848], [C, 38924], [P, 15570]], 1    , 1,   7,   9, ["sink12"], 4);

    upg_token("missile", H); // shows once a Pirate Hat has been banked

    // Higher ranks: each also needs the rank before it (UPG_REVEAL levels, an undrawn gate)
    upg_after("firerate4", "firerate3");
    upg_after("dmg4", "dmg3");
    upg_after("accuracy3", "accuracy2");
    upg_after("firerate3", "firerate2");
    upg_after("dmg3", "dmg2");
    upg_after("accuracy2", "accuracy");
    upg_after("passive_dmg3", "passive_dmg2");
    upg_after("passive_dmg2", "passive_dmg");
    upg_after("dmg2", "dmg");
    upg_after("firerate2", "firerate");
    upg_after("passive_rate2", "passive_rate");
    upg_after("zap_chain2", "zap_chain");
    upg_after("oc_time2", "oc_time");
    upg_after("jump_drive5", "jump_drive4");
    upg_after("burst2", "burst");
    upg_after("jump_drive4", "jump_drive3");
    upg_after("jump_drive3", "jump_drive2");
    upg_after("jump_drive2", "jump_drive");
    upg_after("capacity2", "capacity");
    upg_after("fighter_dmg2", "fighter_dmg");
    upg_after("day_length3", "day_length2");
    upg_after("day_length2", "day_length");
    upg_after("overtime2", "overtime");
    upg_after("quota2", "quota");
    upg_after("regen2", "regen");
    upg_after("more_ast2", "more_ast");
    upg_after("shield2", "shield");
    upg_after("ships2", "ships");
    upg_after("ships3", "ships2");
    upg_after("bigger2", "bigger");
    upg_after("big_break2", "big_break");
    upg_after("hp2", "hp");
    upg_after("more_ast4", "more_ast3");
    upg_after("tiny_yield2", "tiny_yield");
    upg_after("more_ast3", "more_ast2");
    upg_after("regen3", "regen2");
    upg_after("armour2", "armour");
    upg_after("hp3", "hp2");

    upg_compute_depths();
}

/// The first level of _id costs _cost (as-is, no scaling) instead of its usual price.
function upg_first(_id, _cost) { upg_get(_id).first_cost = _cost; }
/// _id stays hidden until resource _res has been banked at least once (a trophy token).
function upg_token(_id, _res) { upg_get(_id).token = _res; }

/// Steps along the tree from the Command Core (core = 0, its neighbours = 1...).
/// A node's depth is one more than its shallowest requirement.
function upg_compute_depths() {
    var _n = array_length(global.upgrades);
    for (var i = 0; i < _n; i++) global.upgrades[i].depth = (array_length(global.upgrades[i].req) == 0) ? 0 : infinity;
    var _changed = true;
    while (_changed) {
        _changed = false;
        for (var i = 0; i < _n; i++) {
            var _u = global.upgrades[i];
            for (var j = 0; j < array_length(_u.req); j++) {
                var _d = upg_get(_u.req[j]).depth + 1;
                if (_d < _u.depth) { _u.depth = _d; _changed = true; }
            }
        }
    }
}

/// Adds one node. need_max = the nodes in `req` must be maxed (used by rank II/III), not just owned.
function upg_add(_id, _name, _desc, _cost, _growth, _max, _gx, _gy, _req, _tier = 1, _need_max = false) {
    array_push(global.upgrades, {
        id: _id, name: _name, desc: _desc, cost: _cost, growth: _growth,
        max_level: min(_max, UPG_RANK_MAX), gx: _gx, gy: _gy, req: _req, tier: _tier,
        need_max: _need_max, need_level: 1, gate: [], first_cost: undefined, token: -1,
        rank_prev: ""   // id of the rank before this one ("" if it isn't a rank II/III...)
    });
}

/// Extra condition, not drawn as a line: every node in _ids must be maxed before _id appears.
function upg_gate(_id, _ids) { upg_get(_id).gate = _ids; }

/// Re-routes a higher rank: drawn from _via instead of the rank before it, which must
/// still be maxed (moved into the undrawn gate).
function upg_via(_id, _via) {
    var _u = upg_get(_id);
    if (_u.rank_prev == "") _u.rank_prev = _u.req[0];
    _u.req = [_via];
    _u.need_max = false;
    array_push(_u.gate, _u.rank_prev);
}

/// Marks _id as the rank after _prev: drawn from whatever its `req` says, but it also needs
/// _prev to have its reveal levels (an undrawn gate), and its levels count in upg_level_sum.
function upg_after(_id, _prev) {
    var _u = upg_get(_id);
    _u.rank_prev = _prev;
    array_push(_u.gate, _prev);
}

/// _id appears once each node in its `req` has at least _n levels (instead of 1).
function upg_need_level(_id, _n) { upg_get(_id).need_level = _n; }

/// Adds a long upgrade as a chain of UPG_RANK_MAX-level nodes: "id", "id2", "id3"...
/// Rank N appears once rank N-1 is maxed, and its costs carry on along the same curve.
function upg_ranks(_id, _name, _desc, _cost, _growth, _ranks, _pos, _req, _tiers = []) {
    static roman = ["", " II", " III", " IV"];
    for (var r = 0; r < _ranks; r++) {
        var _mult = power(_growth, UPG_RANK_MAX * r);
        var _c = [];
        for (var i = 0; i < array_length(_cost); i++) array_push(_c, [_cost[i][0], _cost[i][1] * _mult]);
        var _tier = (r < array_length(_tiers)) ? _tiers[r] : 1;
        upg_add(upg_rank_id(_id, r), _name + roman[r], _desc, _c, _growth, UPG_RANK_MAX,
                _pos[r][0], _pos[r][1], (r == 0) ? _req : [upg_rank_id(_id, r - 1)], _tier, r > 0);
        if (r > 0) upg_get(upg_rank_id(_id, r)).rank_prev = upg_rank_id(_id, r - 1);
    }
}

function upg_rank_id(_id, _r) { return (_r == 0) ? _id : _id + string(_r + 1); }

/// Total levels across every rank of an upgrade (dmg + dmg2 + dmg3).
function upg_level_sum(_id) {
    var _t = 0;
    for (var r = 0; r < 5; r++) _t += upg_level(upg_rank_id(_id, r)); // up to rank V (Jump Drive)
    return _t;
}

/// Old saves had single nodes with up to 15 levels: move the overflow into the
/// new rank nodes, and clamp anything above the new caps.
function upg_migrate_levels() {
    for (var i = 0; i < array_length(global.upgrades); i++) {
        var _u = global.upgrades[i];
        var _lvl = upg_level(_u.id);
        if (_lvl <= _u.max_level) continue;
        global.levels[$ _u.id] = _u.max_level;
        for (var j = 0; j < array_length(global.upgrades); j++) {
            var _v = global.upgrades[j];
            if (_v.rank_prev == _u.id) {
                global.levels[$ _v.id] = upg_level(_v.id) + _lvl - _u.max_level;
                break;
            }
        }
    }
}

function upg_get(_id) {
    for (var i = 0; i < array_length(global.upgrades); i++) {
        if (global.upgrades[i].id == _id) return global.upgrades[i];
    }
    return undefined;
}

/// Every upgrade level owned across the tree (sets the charge points a full charge meter needs). Worked out once a frame.
function upg_owned_total() {
    static _t = 0;
    static _f = -1;
    if (_f == current_time) return _t;
    _f = current_time;
    _t = 0;
    for (var i = 0; i < array_length(global.upgrades); i++) _t += upg_level(global.upgrades[i].id);
    return _t;
}

function upg_level(_id)  { return global.levels[$ _id] ?? 0; }
function upg_maxed(_u)   { return upg_level(_u.id) >= _u.max_level; }
/// No tier lock any more: a node's colour-coded cost (ice, crystal, platinum, Cores) already
/// keeps it out of reach until that resource is unlocked. `tier` still sets the tier-2 ore discount.
function upg_tier_ok(_u) { return true; }

// Economy: every node's ore/ice/crystal/platinum cost is multiplied by this.
// Target: a good run buys 2-3 upgrades, a great one up to ~5. Cores are never scaled.
#macro UPG_COST_MULT 4

// Early-game discount: nodes within UPG_EARLY_DEPTH steps of the core get their
// first levels cheaper, so the opening days always have something to buy.
#macro UPG_EARLY_DEPTH 2

// Tier 2 nodes: ore was the bottleneck (ice piled up while ore ran dry), so their
// ore part costs this much. Ice/crystal/Cores unchanged. Was 0.5; set to 1 (23/11/2026)
// once the denser field made Carbon plentiful.
#macro UPG_T2_ORE_MULT 1

// Higher-tier nodes cost more: x UPG_TIER_COST per tier above 1 (1.6 matches TIER_REWARD's
// +60% loot per tier). Tier 1 x1, tier 2 x1.6, tier 3 x2.56, tier 4 x4.1. Cores/tokens unscaled.
#macro UPG_TIER_COST 1.3

/// Cost of the next level as an array of [resource, amount].
function upg_cost(_u) {
    static early_discount = [0.5, 0.5, 0.75]; // price multiplier for levels 1, 2, 3; later levels full price
    var _lvl = upg_level(_u.id);
    if (_lvl == 0 && _u.first_cost != undefined) return _u.first_cost; // e.g. a Black Box for a missile path's first rank
    var _mult = power(_u.growth, _lvl);
    // Rank II/III nodes are mid-game, so they stay full price
    if (_u.rank_prev == "" && !_u.need_max && _u.first_cost == undefined && _u.depth >= 1 && _u.depth <= UPG_EARLY_DEPTH && _lvl < array_length(early_discount)) {
        _mult *= early_discount[_lvl];
    }
    var _out = [];
    for (var i = 0; i < array_length(_u.cost); i++) {
        var _r = _u.cost[i][0];
        var _m = res_special(_r) ? 1 : _mult * UPG_COST_MULT; // Cores and tokens are never scaled
        if (_r == RES.ORE && _u.tier == 2) _m *= UPG_T2_ORE_MULT;
        if (!res_special(_r)) _m *= power(UPG_TIER_COST, max(0, _u.tier - 1)); // pricier the higher the node's tier
        array_push(_out, [_r, max(1, round(_u.cost[i][1] * _m))]);
    }
    return _out;
}

/// The rarest resource a node costs (used for its icon on the tree).
function upg_main_res(_u) {
    var _r = RES.ORE, _c = upg_cost(_u);
    for (var i = 0; i < array_length(_c); i++) _r = max(_r, _c[i][0]);
    return _r;
}

function upg_affordable(_u) {
    if (global.free_costs) return true;
    var _c = upg_cost(_u);
    for (var i = 0; i < array_length(_c); i++) {
        if (global.bank[_c[i][0]] < _c[i][1]) return false;
    }
    return true;
}

// Exploration: what hangs off a node (and the next rank of it) shows once it has this many
// levels. Nodes with fewer than 5 levels need half (rounded down, at least 1): 4 -> 2, 3 -> 1,
// 2 -> 1, 1 -> 1. No need to max a node before moving on; tier
// locks and costs still hold the player back.
#macro UPG_REVEAL 3
function upg_reveal_level(_u) {
    if (_u.max_level >= 5) return UPG_REVEAL;
    return max(1, floor(_u.max_level / 2));
}

function upg_visible(_u) {
    if (!JUMP_DRIVES_ON && string_pos("jump_drive", _u.id) == 1) return false; // switched off for now (scr_threat)
    if (upg_level(_u.id) > 0) return true; // owned nodes always show (old saves bought under older rules)
    if (_u.token >= 0 && !global.found[_u.token]) return false;
    for (var i = 0; i < array_length(_u.req); i++) {
        var _r = _u.req[i];
        if (upg_level(_r) < max(_u.need_level, upg_reveal_level(upg_get(_r)))) return false;
    }
    for (var i = 0; i < array_length(_u.gate); i++) {
        var _g = _u.gate[i];
        // The previous rank only needs the reveal levels; other gates (Rail Gun) still need maxing
        if (_g == _u.rank_prev) { if (upg_level(_g) < upg_reveal_level(upg_get(_g))) return false; }
        else if (!upg_maxed(upg_get(_g))) return false;
    }
    return true;
}

/// Does buying _u raise the tier (a new sector or a Jump Drive)? The tree asks first (obj_tree confirm).
function upg_raises_tier(_u) { return string_pos("unlock_", _u.id) == 1 || string_pos("jump_drive", _u.id) == 1; }

function upg_can_buy(_u) {
    return upg_visible(_u) && upg_tier_ok(_u) && !upg_maxed(_u) && upg_affordable(_u);
}

function upg_buy(_u) {
    if (!upg_can_buy(_u)) return false;
    var _c = upg_cost(_u);
    if (!global.free_costs) for (var i = 0; i < array_length(_c); i++) global.bank[_c[i][0]] -= _c[i][1];
    global.levels[$ _u.id] = upg_level(_u.id) + 1;
    daylog_buy(_u, _c); // balance log (scr_save)
    if (string_pos("unlock_", _u.id) == 1) global.unlock_day[$ _u.id] = global.day_count; // starts its spawn rush (unlock_boost)
    var _old_tier = global.tier;
    stats_build();
    if (global.tier > _old_tier) tier_announce();
    save_game();
    return true;
}

/// Rebuilds global.stats from upgrade levels. All upgrade effects live here;
/// difficulty scaling (ramp, tier) lives in scr_threat.
function stats_build() {
    upg_migrate_levels();
    global.tier  = tier_from_unlocks();                  // tier only rises when you buy a tier unlock
    var L  = upg_level;
    var LS = upg_level_sum; // all ranks of a split upgrade
    var D  = function(_id) { return upg_dim(upg_level(_id)); };      // defence / utility: diminishing returns
    var DS = function(_id) { return upg_dim(upg_level_sum(_id)); };  // same, all ranks of a split upgrade
    var _hull_mult = 1 + 0.2 * D("fortress");
    global.stats = {
        // Main weapon nodes: apply to whichever weapon is ACTIVE (wpn_dmg / wpn_rof / wpn_size)
        act_dmg:        1 + LS("dmg"),                                   // Damage I-IV: 15 levels in all, +1 each
        act_rof:        1 / power(0.88, LS("firerate")),                 // fire-rate multiplier, Fire Rate I-IV: 10 levels, 12% each
        act_size:       1 + 0.4 * L("bsize"),                            // shot size multiplier (bullets, beam, bolt)
        spread:         GUN_SPREAD * power(0.6, LS("accuracy")),         // active cone, degrees; Accuracy I-III: 5 levels
        // Passive weapon nodes: apply to every weapon NOT on the cursor
        pas_dmg:        1 + LS("passive_dmg"),
        pas_rof:        PASSIVE_ROF * (1 + 0.12 * LS("passive_rate")),   // Passive Fire Rate I-II: 5 levels
        pas_turn:       min(1, PASSIVE_TURN + 0.12 * L("passive_track")), // share of full turn speed
        pas_spread:     GUN_SPREAD * PASSIVE_SPREAD * power(0.8, L("passive_track")),
        pas_size:       min(1, PASSIVE_SCALE + 0.1 * L("passive_size")),
        dmg_mult:       1 + 0.25 * L("overcharge"),                      // Amplifier: every weapon, active or passive
        // Gun
        bullet_damage:  GUN_DAMAGE,
        fire_interval:  GUN_INTERVAL,                                    // frames between volleys, before Fire Rate
        bullet_speed:   8 * (1 + 0.15 * L("bullet_speed")),             // Bullet Speed: +15% a level
        combat_hud:     L("combat_hud") > 0,                             // M / P damage-per-second readout (obj_game Draw GUI)
        bullet_scale:   1,
        ricochet:       L("ricochet"),                                   // Harder Bullets: bounces off anything they hit
        burst:          1 + L("burst") + L("burst2"),                    // volleys per trigger pull (Burst Fire I + II)
        // Rail gun
        railgun:        L("railgun") > 0,
        rail_damage:    RAIL_DAMAGE,
        rail_interval:  RAIL_INTERVAL * power(0.85, L("rail_rate")),     // frames, before Fire Rate
        // Laser
        laser:          L("laser") > 0,
        laser_dps:      LASER_DPS * (1 + 0.2 * L("laser_focus")),        // full-heat damage per second
        laser_ramp:     LASER_RAMP_TIME * power(0.85, L("laser_focus")), // seconds to full heat
        laser_width:    LASER_WIDTH + 3 * L("laser_width"),              // px thick
        laser_on:       LASER_ON,                                        // seconds per beam, x Fire Rate (wpn_rof)
        laser_refract:  L("laser_refract"),                              // extra beams split off the lit rock
        rail_falloff:   RAIL_FALLOFF * power(RAIL_CALIBRE, L("rail_size")), // share of power lost per rock pierced (the slug is as wide as the square mount)
        // Overcharge (fired when the charge meter is full, see scr_threat)
        oc_duration:    6 + 2 * LS("oc_time"),                           // seconds; Duration I-II: 5 levels
        oc_rof:         1.5 + 0.2 * L("oc_rate"),                        // fire-rate multiplier
        oc_size:        1.5 + 0.2 * L("oc_size"),                        // bullet size multiplier
        oc_zap_mult:    1 + 0.4 * L("oc_zap_dmg"),                       // lightning damage multiplier while overcharged
        oc_zap_chains:  L("oc_zap_chain"),                               // extra bounces while overcharged
        // Chain lightning
        lightning:      L("tesla") > 0,
        zap_damage:     ZAP_DAMAGE,
        zap_chains:     1 + LS("zap_chain"),                             // bounces after the first target; Chain Lightning I-II: 5 levels
        zap_jump:       140 + 50 * L("zap_jump"),                        // max px per bounce
        zap_interval:   ZAP_INTERVAL,                                    // frames between bolts, before Fire Rate
        zap_scatter:    ZAP_SCATTER * power(0.6, LS("accuracy")),         // active Tesla: strike lands within this many px of the cursor
        // Repulsor wave: slows asteroids it passes through
        repulsor:       L("repulsor") > 0,
        rep_deflect:    20 + 6 * D("rep_power"),                         // degrees a TINY rock's heading turns away per hit (bigger turn less)
        rep_range:      260 + 60 * D("rep_range"),                       // radius the ring reaches
        rep_interval:   round(150 * power(0.85, L("rep_width"))),        // frames between pulses (2.5s -> 1.1s)
        rep_double:     L("rep_double") > 0,                             // a second ring REP_ECHO frames after each pulse
        // Freeze ray: blasts slow rocks, no damage
        freeze:         L("freeze") > 0,
        freeze_interval: max(20, round(FREEZE_INTERVAL * power(FREEZE_RATE, L("frz_rate")))), // frames between blasts (Cryo Cooldown)
        freeze_hold:    FREEZE_HOLD + D("frz_life"),                     // seconds a rock stays frozen (Cryo Life)
        // Tractor wave: drags loose loot towards the station
        tractor:       L("tractor") > 0,
        tr_strength:    4 + 1.5 * D("tr_power"),                         // top speed (px/frame) of loot hauled to the station
        tr_angle:       20 + 8 * D("tr_width"),
        tr_range:       300 + 80 * D("tr_range"),
        tr_pause:       round(120 * (1 - L("tr_uptime") / 5)),           // frames off between 2s beams; 0 = always on
        // Defence
        max_hp:         (50 + 15 * DS("hp")) * _hull_mult,
        regen:          0.5 * DS("regen"),                               // hp per second
        armour:         min(0.6, 0.09 * DS("armour")),                   // fraction of hull damage removed; Armour I-II
        max_shield:     15 * DS("shield") * _hull_mult,
        ram_damage:     2 + 5 * D("ram"),                                // damage an asteroid takes when it hits you
        // Guard drones
        drones:         (L("drones") > 0) ? 1 + L("drone_count") : 0,
        drone_hits:     2 + round(D("drone_armour")),
        drone_rebuild:  12 * power(0.8, L("drone_regen")),               // seconds to rebuild a destroyed drone
        drone_damage:   3 + 3 * D("drone_dmg"),
        // Logistics
        ships:          1 + L("ships") + L("ships2") + L("ships3"),                                  // max ships in flight at once
        ship_speed:     3 + 0.5 * D("ship_speed"),                       // ~5.2 px/frame at rank 5 (was +1.0 a rank: ships outran enemy collectors 3 to 1)
        capacity:       6 + round(3 * DS("capacity")),
        magnet:         28 + 20 * D("magnet"),
        ship_zap:          L("ship_zap") > 0,                           // Charged Collectors: ships zap nearby enemies / rocks
        ship_zap_damage:   SHIP_ZAP_DAMAGE * (1 + 0.5 * D("ship_zap_dmg")),
        ship_zap_interval: max(15, round(SHIP_ZAP_INTERVAL * power(0.85, L("ship_zap_rate")))), // frames
        ship_ai:           L("ship_ai") > 0,                            // Collector AI: ships launch themselves for loose loot
        ship_hp:         12 + 10 * D("ship_hull"),
        ship_shield:     0,                                              // Deflector Field isn't on the tree any more
        ship_rebuild:    15 * power(0.8, L("ship_rebuild")),             // seconds before a destroyed ship's slot is ready again
        // Fighters
        fighters:        (L("fighters") > 0) ? 1 + L("fighter_count") : 0,
        fighter_damage:  3 + 2 * LS("fighter_dmg"),
        fighter_burst:   3 + L("fighter_burst"),                        // lasers per burst
        fighter_interval: max(25, round(80 * power(0.88, L("fighter_rate")))), // frames between bursts
        fighter_hp:      20 + 15 * L("fighter_hull"),
        fighter_speed:   4 + 0.6 * L("fighter_speed"),
        fighter_rebuild: 10,                                             // seconds to rebuild a downed fighter
        // Mining
        spawn_interval: max(10, round(180 * power(0.82, LS("more_ast")))), // frames between spawns (before tier cut, ramp and swarms): 3s base (was 5s: the field was too thin), 1.1s at Lure 5, 0.4s at Lure 10
        big_bias:       0.7 * LS("bigger"),                               // 10 levels reach the 60% large-rock cap
        big_break:      2 * LS("big_break"),                              // extra base loot when a large rock breaks
        day_length:     40 + 8 * LS("day_length"),                     // starting seconds; bosses arrive at 60s elapsed
        time_bonus:     8 + 2 * LS("overtime"),                           // seconds per time bonus
        time_quota_growth: TIME_QUOTA_GROWTH * power(0.8, L("time_cap")), // each bonus costs this much more than the last (25% -> ~8% at Extended Contract 5)
        time_quota_mult: power(0.92, LS("quota")),                        // scales the banked value each bonus needs (-8% a rank; was -3%, too little to notice)
        tiny_yield:     1 + LS("tiny_yield"),   // tinies are most of the drops, so this is the main income lever
        unlock_ice:      L("unlock_ice") > 0,
        unlock_crystal:  L("unlock_crystal") > 0,
        unlock_platinum: L("unlock_platinum") > 0,
        ice_rate:        0.05 + 0.03  * L("ice_rate"),     // share of spawns, once unlocked
        crystal_rate:    0.04 + 0.025 * L("crystal_rate"),
        plat_rate:       0.03 + 0.02  * L("plat_rate"),
        // Missiles (scr_pirates): right-click volleys
        missiles:         L("missile") > 0,
        missile_count:    MISSILE_PER_LAUNCH + L("msl_compact"),            // missiles per launch (Compact Tubes: 2 -> 6)
        missile_ammo:     MISSILE_AMMO + L("msl_volley"),                   // max ammo (Launch Tubes: 5 -> 10); 1 per launch
        missile_reload:   MISSILE_RELOAD * power(0.83, L("msl_reload")),    // seconds per ammo (Auto Loader: 5 -> ~2)
        missile_damage:   MISSILE_DAMAGE + MISSILE_DAMAGE_PER * L("msl_dmg"), // centre of the blast (Warheads: 50 -> 100)
        missile_blast:    MISSILE_BLAST + MISSILE_BLAST_PER * L("msl_yield"), // px radius (Yield)
        missile_push:     MISSILE_PUSH + MISSILE_PUSH_PER * L("msl_yield"),   // shockwave strength (Yield)
        missile_speed:    MISSILE_SPEED * (1 + 0.15 * L("msl_speed")),      // Boosters
        missile_cluster:  L("msl_cluster") > 0,
    };
}

// --- Main weapons: active / passive (see WPN in scr_config) -----------------------
// Every owned weapon fires each day; global.active_weapon (picked before launch) is the
// one on the cursor. The gun is always owned.

/// Does the player own weapon _w?
function wpn_owned(_w) {
    var _st = global.stats;
    switch (_w) {
        case WPN.GUN:   return true;
        case WPN.TESLA: return _st.lightning;
        case WPN.LASER: return _st.laser;
        case WPN.RAIL:  return _st.railgun;
    }
    return false;
}

function wpn_name(_w) {
    switch (_w) {
        case WPN.GUN:   return "Gun";
        case WPN.TESLA: return "Tesla Coil";
        case WPN.LASER: return "Laser";
        case WPN.RAIL:  return "Rail Gun";
    }
    return "?";
}

// --- Diminishing returns (defence and utility) -------------------------------------
// Weapons keep scaling; defence and utility level off, so a maxed station can still be worn
// down and the clock stays the real enemy. The first rank is worth UPG_DIM_BOOST of a full rank,
// each later rank UPG_DIM_FALLOFF of the one before: 1 -> 1.3, 5 -> 4.4, 10 -> 5.8, 15 -> 6.3
// (the most it can ever reach is 6.5). Node text still says "+1 X".
#macro UPG_DIM_BOOST   1.3
#macro UPG_DIM_FALLOFF 0.8
/// How many full ranks _n bought ranks of a defence / utility node are worth.
function upg_dim(_n) { return UPG_DIM_BOOST * (1 - power(UPG_DIM_FALLOFF, _n)) / (1 - UPG_DIM_FALLOFF); }

/// Per-weapon multipliers: main-weapon nodes when _w is active, passive nodes when it isn't.
function wpn_dmg(_w)  { var _s = global.stats; return ((wpn_active() == _w) ? _s.act_dmg : _s.pas_dmg) * _s.dmg_mult; }
function wpn_rof(_w)  { var _s = global.stats; return (wpn_active() == _w) ? _s.act_rof : _s.pas_rof; }   // rate multiplier
function wpn_size(_w) { var _s = global.stats; return (wpn_active() == _w) ? _s.act_size : _s.pas_size; }
function wpn_spread(_w) { var _s = global.stats; return (wpn_active() == _w) ? _s.spread : _s.pas_spread; } // degrees, total cone

/// The weapon on the cursor today: the chosen one, or the gun if that isn't owned.
function wpn_active() {
    var _w = global.active_weapon;
    return (_w >= 0 && _w < WPN.COUNT && wpn_owned(_w)) ? _w : WPN.GUN;
}

/// Picks the next owned weapon after the current active one.
function wpn_cycle() {
    var _w = wpn_active();
    repeat (WPN.COUNT) {
        _w = (_w + 1) mod WPN.COUNT;
        if (wpn_owned(_w)) break;
    }
    global.active_weapon = _w;
    return _w;
}
