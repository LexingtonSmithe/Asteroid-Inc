if (world_paused() || dead) exit;
orbit += 3;
if (full_flash > 0) full_flash--;
if (flash > 0) flash--;

// Shield recharges after a pause without hits
if (shield_delay > 0) shield_delay--;
else shield = min(max_shield, shield + max_shield * SHIP_SHIELD_REGEN / game_get_speed(gamespeed_fps));

// Charged Collectors: zap whatever is near (offline during the end-of-day recall, like the turret)
if (global.stats.ship_zap && !(instance_exists(obj_game) && obj_game.state == "recalling")) {
    gun_timer--;
    if (gun_timer <= 0) {
        var _pt_g = perf_t();
        var _hit = fire_zap();
        perf_add("ship_zap_scan", _pt_g);
        gun_timer = _hit ? global.stats.ship_zap_interval : 6; // nothing near: look again shortly
    }
}

// Tractor beam: claim loose pickups in range while there's room (still on with a special
// aboard: it grabs what it flies over, it just won't steer towards loot)
magnet_tick = (magnet_tick + 1) mod 3;
if (magnet_tick == 0 && cargo_total + incoming < capacity) {
    var _pt_m = perf_t();
    with (obj_pickup) {
        if (claimed_by == noone && !tractored
            && other.cargo_total + other.incoming < other.capacity
            && point_distance(x, y, other.x, other.y) < other.magnet) {
            claimed_by = other.id;
            other.incoming += value; // a stack fills the hold by its value (it can overfill by one stack)
        }
    }
    perf_add("ship_magnet", _pt_m);
}
var _full = has_special || (cargo_total + incoming) >= capacity; // a special drop counts as a full hold

switch (state) {
    case "harvest":
        if (_full) { release_target(); state = "return"; break; }

        // Re-pick periodically (the current target gets a bonus, so it rarely switches),
        // or straight away when the current target is gone, taken or tractored
        retarget_timer--;
        if (!instance_exists(target) || target.claimed_by != noone || target.tractored) {
            release_target();
            retarget_timer = 0;
        }
        if (retarget_timer <= 0) {
            var _new = find_target();
            if (_new != target) {
                release_target();
                target = _new;
            }
            if (target != noone) target.targeted_by = id;
            retarget_timer = RETARGET_FRAMES;
        }

        if (target != noone) {
            steer_to(target.x, target.y);
            idle_frames = 0;
        } else {
            // Nothing to collect: coast briefly (lets pulled-in loot arrive), then head home
            x += lengthdir_x(spd * 0.5, dir);
            y += lengthdir_y(spd * 0.5, dir);
            if (incoming <= 0) {
                idle_frames++;
                if (idle_frames > 30) state = "return";
            }
        }
        break;

    case "return":
        // Not full and not recalled: divert to any loot released on the way home
        if (!_full && !recalled) {
            retarget_timer--;
            if (retarget_timer <= 0) {
                retarget_timer = RETARGET_FRAMES;
                if (find_target() != noone) {
                    state = "harvest";
                    idle_frames = 0;
                    retarget_timer = 0; // pick the target straight away
                    break;
                }
            }
        }
        steer_to(STATION_X, STATION_Y);
        if (point_distance(x, y, STATION_X, STATION_Y) < STATION_RADIUS && incoming <= 0) {
            var _line = 0;
            for (var r = 0; r < RES.COUNT; r++) {
                if (cargo[r] <= 0) continue;
                global.bank[r] += cargo[r];
                if (instance_exists(obj_game)) obj_game.add_banked(r, cargo[r], x, y, cargo_free[r]);
                float_text(STATION_X, STATION_Y - STATION_RADIUS - 24 - _line * 26,
                           "+" + string(cargo[r]), res_colour(r), 1.6, res_sprite(r));
                _line++;
            }
            if (cargo_total > 0) fx_dock(x, y);
            sfx(snd_collection_returned, 0.8);
            var _me = id;
            with (obj_pickup) if (claimed_by == _me) instance_destroy(); // unload the hold
            if (instance_exists(obj_game)) obj_game.ship_docked(hp / max_hp); // damage stays with the ship
            instance_destroy();
        }
        break;
}
