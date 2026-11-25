var _input = !transition_active(); // no clicks while the screen is wiping
// A one-off tip is up (scr_tutorial): the world is paused and it takes the input
if (tip != TIP.NONE) { tip_step(_input); _input = false; }
if (state == "playing" || state == "recalling") perf_frame(); // performance log (scr_save)
if (DEBUG_KEYS && keyboard_check_pressed(vk_f2)) perf_overlay = !perf_overlay;
if (DEBUG_KEYS && keyboard_check_pressed(vk_f1)) global.outline_cache_off = !global.outline_cache_off; // compare frame times with the cache off

if (state == "playing" || state == "recalling") {
    var _tick = !world_paused(); // hit-stop / slow motion: timers wait, input still works
    if (_tick) {
        var _pt = perf_t();
        fx_update();
        perf_add("particles", _pt);
        // Overcharge holds the day still, like the frozen rocks: no threat ramp, no boss or swarm
        // schedule, no spawning and no condition timers until it ends (so nothing piles up)
        var _hold = oc_timer > 0;
        if (oc_timer > 0) oc_timer--;
        // Combat HUD: damage this tick folded into a ~2 s moving average of damage per second
        var _dfps = game_get_speed(gamespeed_fps), _dk = 1 / (2 * _dfps);
        dps_main += (dps_acc_main * _dfps - dps_main) * _dk;
        dps_pas  += (dps_acc_pas  * _dfps - dps_pas)  * _dk;
        dps_acc_main = 0;
        dps_acc_pas  = 0;

        // Threat ramps up with time elapsed, recall included; time bonuses don't reset it
        if (!tut_day_on() && !_hold) day_elapsed++; // the day-one tutorial holds the threat, zoom and bosses (scr_tutorial)
        day_progress = day_elapsed / (RAMP_TIME * game_get_speed(gamespeed_fps));
        update_view(); // the camera pulls back a little more
        // 5:00: the singularity ending (scr_threat ENDING_*)
        if (state == "playing" && day_elapsed >= ending_time() * game_get_speed(gamespeed_fps)) singularity_start();

        if (cond_announce_timer > 0) {
            cond_announce_timer--;
            if (cond_announce_timer <= 0) {
                if (chart != CHART.NONE) chart_announce(chart); else cond_announce(condition);
                // Payout / truce news (scr_pirates)
                if (pirate_msg != "") float_text(STATION_X, STATION_Y + STATION_RADIUS + 70, pirate_msg, FLAGSHIP_COLOUR, 1.6);
            }
        }
        warp_tick(); // brings warped rocks back
        if (!_hold) cond_step(); // today's sector condition: rock contacts, black holes, wind, meteors
        pirate_step(); // Pirate System day: waves, then the flagship (scr_pirates)
        missile_tick(); // missile ammo recharge (scr_pirates)

        // Destroyed collectors rebuild; a slot frees up when its timer runs out
        for (var i = array_length(ship_rebuild) - 1; i >= 0; i--) {
            ship_rebuild[i]--;
            if (ship_rebuild[i] <= 0) {
                array_delete(ship_rebuild, i, 1);
                fx_dock(STATION_X, STATION_Y);
                sfx(snd_affirmative, 0.4, 1.3, 0);
            }
        }

        // Docked, damaged collectors patch up very slowly
        for (var i = array_length(hangar) - 1; i >= 0; i--) {
            hangar[i] += SHIP_DOCK_REPAIR / game_get_speed(gamespeed_fps);
            if (hangar[i] >= 1) array_delete(hangar, i, 1);
        }

        // Opening wave: a few rocks on screen from the first frame (not in the Pirate System)
        if (!opening_done && !tut_day_on()) {
            opening_done = true;
            if (chart != CHART.PIRATE) repeat (OPENING_ROCKS) spawn_opening_rock();
        }

        // Asteroids keep coming during the recall too, faster as the day goes on (none in the Pirate System)
        if (chart != CHART.PIRATE && !tut_day_on() && !_hold) spawn_timer--;
        // Swarm: SWARM_SPAWN x as fast for SWARM_TIME s, until SWARM_ROCK_CAP rocks are out; its rocks are tagged
        if (swarm_t > 0 && !_hold) swarm_t--;
        var _swarming = swarm_t > 0 && instance_number(obj_asteroid) < SWARM_ROCK_CAP;
        if (spawn_timer <= 0) {
            var _sa = spawn_asteroid();
            if (swarm_t > 0 && instance_exists(_sa)) _sa.swarm = true;
            spawn_timer = global.stats.spawn_interval / threat_spawn_mult() / (_swarming ? SWARM_SPAWN : 1) * random_range(0.7, 1.3);
        }

        // Bosses and swarms on today's schedule (scr_threat day_schedule; not on Gold or Pirate System days).
        // The last boss is the tier boss (Cores) while it's due; the others drop loot, each bigger and tougher.
        var _elapsed = day_elapsed / game_get_speed(gamespeed_fps);
        if (state == "playing" && !chart_no_boss(chart)) {
            var _sn = array_length(sched);
            // A swarm is announced SWARM_WARN s before it hits
            if (sched_i < _sn && sched[sched_i][1] == EVT.SWARM && swarm_warned != sched_i && _elapsed >= sched[sched_i][0] - SWARM_WARN) {
                swarm_warned = sched_i;
                sfx(snd_alarm_chime, 0.7, 1.3, 0);
                float_text(STATION_X, STATION_Y - STATION_RADIUS - 90, "SWARM", c_red, 2);
            }
            while (sched_i < _sn && _elapsed >= sched[sched_i][0]) {
                var _ev = sched[sched_i][1];
                if (_ev == EVT.SWARM) {
                    swarm_t = SWARM_TIME * game_get_speed(gamespeed_fps);
                    swarm_count++;
                    day_tier_floor = max(day_tier_floor, sched[sched_i][2]); // quietly tougher from here on
                    spawn_timer = min(spawn_timer, 5); // starts straight away
                } else {
                    spawn_boss(boss_count, boss_core_drop(sched[sched_i][2])); // Cores only if you hold none and are below its tier
                    if (boss_count == 0) { boss_spawned = true; dlog.boss_at = round(_elapsed); }
                    boss_count++;
                }
                sched_i++;
            }
        }

        // Enemy collectors: from ENEMY_COLLECTOR_TIER, every so often, to steal loose loot. The more loot is
        // lying loose, the faster the timer runs (scr_enemies ENEMY_COLLECTOR_LOOT_*). Payout days bring
        // more, truce days far fewer (pirate_mult); the Pirate System sends waves instead.
        if (state == "playing" && global.tier >= ENEMY_COLLECTOR_TIER && chart != CHART.PIRATE) {
            enemy_collector_scan--;
            if (enemy_collector_scan <= 0) { enemy_collector_rate = enemy_collector_loot_mult(loose_loot_value()); enemy_collector_scan = ENEMY_COLLECTOR_LOOT_SCAN; }
            enemy_collector_timer -= enemy_collector_rate;
            if (enemy_collector_timer <= 0) {
                spawn_enemy_collector();
                enemy_collector_timer = enemy_collector_interval() / pirate_mult * game_get_speed(gamespeed_fps) * random_range(0.8, 1.2);
            }
        }
        // Enemy fighters: from FIGHTER_TIER, on their own timers (scr_enemies). Hunter pairs come
        // more often the more collection ships you own, and only while one is out; station
        // attackers come more often the more tree nodes you own.
        if (state == "playing" && global.tier >= FIGHTER_TIER && chart != CHART.PIRATE) {
            var _efps = game_get_speed(gamespeed_fps);
            hunter_timer--;
            if (hunter_timer <= 0) {
                if (spawn_hunters()) hunter_timer = hunter_interval() / pirate_mult * _efps * random_range(0.8, 1.2);
                else hunter_timer = _efps; // no ship out: look again in a second
            }
            attacker_timer--;
            if (attacker_timer <= 0) {
                spawn_attacker();
                attacker_timer = attacker_interval() / pirate_mult * _efps * random_range(0.8, 1.2);
            }
        }
    }

    if (state == "playing") {
        if (_tick) {
            // A time bonus soaking in: 1s blasts, and the clock holds until they're all in
            if (time_queue > 0) { time_tick--; if (time_tick <= 0) time_absorb_one(); }
            // The clock waits for the Pirate System flagship, and stands still during Overcharge
            var _clock = !pirate_holds_clock() && !oc_active() && time_queue <= 0 && !tut_day_on();
            if (_clock) day_timer--;
            // Final countdown: a tick and a red pulse on each of the last 5 seconds
            var _fps = game_get_speed(gamespeed_fps);
            if (_clock && day_timer > 0 && day_timer <= 5 * _fps && day_timer mod _fps == 0) {
                countdown_num = day_timer div _fps;
                countdown_pop = 1;
                music_duck(0.45, 3); // the music dips on each tick and swells back, like a sidechain pump
            }
        }
        // Clock ticking under the final countdown (a loop: fades out by itself when the day ends)
        if (!oc_active() && day_timer > 0 && day_timer <= 5 * game_get_speed(gamespeed_fps)) sfx_loop(snd_ticking, 0.5);

        // Left click: launch a collection ship (it sets off towards the cursor, then hunts loot itself)
        // (the day-one tutorial only allows it once it asks for a launch)
        if (_input && mouse_check_button_pressed(mb_left) && tut_launch_ok()) {
            if (can_launch()) {
                launch_collector(); // damaged ships keep their damage (hangar)
                sfx(snd_collection_depart, 0.7);
                dlog.launches++;
            } else {
                sfx(snd_denied, 0.6);
            }
        }
        // Collector AI: a free slot launches itself at the nearest loose loot nobody is fetching
        if (global.stats.ship_ai && state == "playing" && tut_launch_ok()) {
            if (ai_launch_cd > 0) ai_launch_cd--;
            else if (can_launch()) {
                var _loot = noone, _ld = infinity;
                with (obj_pickup) {
                    if (carried || tractored || claimed_by != noone || instance_exists(targeted_by)) continue;
                    if (!in_view(x, y)) continue;
                    var _d = point_distance(x, y, STATION_X, STATION_Y);
                    if (_d < _ld) { _ld = _d; _loot = id; }
                }
                if (_loot != noone) {
                    var _c = launch_collector();
                    _c.dir = point_direction(STATION_X, STATION_Y, _loot.x, _loot.y);
                    sfx(snd_collection_depart, 0.5);
                    dlog.launches++;
                    ai_launch_cd = 20; // a short gap so a burst of loot doesn't empty the hangar in one frame
                }
            }
        }
        // SPACE / middle mouse: fire Overcharge once the charge meter is full
        if (_input && global.oc_ready && (keyboard_check_pressed(vk_space) || mouse_check_button_pressed(mb_middle))) overcharge_start();
        // Right click: missiles once the launcher is owned (click fires, hold keeps firing:
        // scr_pirates), otherwise recall. R always recalls every ship in flight.
        if (_input) {
            if (global.stats.missiles) missile_input();
            else if (mouse_check_button_pressed(mb_right)) with (obj_collector) recall();
        }
        if (_input && keyboard_check_pressed(ord("R"))) with (obj_collector) recall();
        tut_day_step(_input); // day-one tutorial steps (scr_tutorial), after the launch click
        tip_check();          // first Overcharge ready / first time bonus: pause with a tip (scr_tutorial)

        // Time up: ships still out are called home, cargo and all. Asteroids keep
        // spawning but the turret goes quiet - survive until the last ship docks.
        if (day_timer <= 0) {
            day_timer = 0;
            sfx(snd_times_up, 1, 1, 0);
            screen_shake(3);
            if (instance_exists(obj_collector)) {
                state = "recalling";
                with (obj_collector) recall();
            } else {
                end_day("Time up");
            }
        }
    } else if (state == "recalling" && !instance_exists(obj_collector)) {
        end_day("Time up"); // last ship has docked
    }

    // ESC: skips the day-one tutorial while it's showing, otherwise abandons the day
    if (_input && keyboard_check_pressed(vk_escape)) {
        if (tut_day_on()) tut_day_end(true); else end_day("Day abandoned");
    }

    // Debug: F9 cycles today's condition, F8 spawns a gilded and an armoured rock, F7 an enemy collector
    if (DEBUG_KEYS && keyboard_check_pressed(vk_f7)) spawn_enemy_collector();
    // Debug: F10 jumps the day to 4:55 to test the singularity ending (today's bosses are skipped,
    // and the clock gets at least 10 s so time can't run out first)
    if (DEBUG_KEYS && state == "playing" && keyboard_check_pressed(vk_f10)) {
        var _jfps = game_get_speed(gamespeed_fps);
        day_elapsed = max(day_elapsed, (ending_time() - 5) * _jfps);
        day_timer   = max(day_timer, 10 * _jfps);
        sched_i     = array_length(sched); // skip today's bosses and swarms
        boss_spawned = true;
        float_text(STATION_X, STATION_Y - STATION_RADIUS - 90, "5s TO GO", c_white, 2);
    }
    // Debug: F3 cycles the active weapon mid-day (the real picker will be on the tree screen, before launch)
    if (DEBUG_KEYS && keyboard_check_pressed(vk_f3)) {
        float_text(STATION_X, STATION_Y - STATION_RADIUS - 90, "ACTIVE: " + string_upper(wpn_name(wpn_cycle())), c_white, 3);
    }
    if (DEBUG_KEYS && keyboard_check_pressed(vk_f9)) {
        condition = (condition + 1) mod COND.COUNT;
        cond_day_init();
        if (condition == COND.NONE) float_text(STATION_X, STATION_Y - STATION_RADIUS - 90, "NO CONDITION", c_white, 3);
        else cond_announce(condition);
    }
    if (DEBUG_KEYS && keyboard_check_pressed(vk_f8)) {
        var _g = spawn_asteroid(false);
        _g.init(AST.LARGE, _g.type);
        _g.gilded = true;
        var _k = spawn_asteroid(false);
        _k.armoured = true;
    }
} else if (state == "ending") {
    singularity_step(_input); // the 5:00 ending plays out, then end_day("Singularity")
} else {
    over_timer++;
    // Flagship beaten: pick a reward before moving on (scr_pirates)
    if (reward_pending) {
        if (_input && over_timer > 30 && mouse_check_button_pressed(mb_left)) {
            var _pick = pirate_reward_hover(device_mouse_x_to_gui(0), device_mouse_y_to_gui(0));
            if (_pick != "") pirate_reward_apply(_pick);
        }
    } else if (_input && over_timer > 45 && (mouse_check_button_pressed(mb_left) || keyboard_check_pressed(vk_space) || keyboard_check_pressed(vk_enter))) {
        transition_to(rm_tree);
    }
}
