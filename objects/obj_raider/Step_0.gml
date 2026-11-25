event_inherited();
if (world_paused() || dead) exit;
orbit += 3;

// Grab loose loot in range while there's room
if (state == "steal" && cargo_total + incoming < capacity) {
    with (obj_pickup) {
        if (claimed_by == noone && !tractored && !magnet // raiders leave Magnets alone
            && other.cargo_total + other.incoming < other.capacity
            && point_distance(x, y, other.x, other.y) < other.magnet) {
            claimed_by = other.id;
            other.incoming += value;
            sfx(snd_raider_grab, 0.45, 1, 0.1);
        }
    }
}

switch (state) {
    case "enter":
        // Straight in towards the station until it's ENEMY_COLLECTOR_ENTRY of the way from the screen edge
        steer_to(STATION_X, STATION_Y);
        var _bear = point_direction(STATION_X, STATION_Y, x, y);
        if (point_distance(x, y, STATION_X, STATION_Y) <= view_edge_dist(_bear) * (1 - ENEMY_COLLECTOR_ENTRY)) {
            state = "steal";
            retarget = 0; // pick its first target straight away
        }
        break;

    case "steal":
        if (cargo_total + incoming >= capacity) { state = "flee"; break; }
        retarget--;
        if (retarget <= 0 || !instance_exists(target) || target.claimed_by != noone) {
            target = find_loot();
            retarget = 20;
        }
        if (target != noone) {
            steer_to(target.x, target.y);
            idle = 0;
        } else {
            // Nothing to steal: loiter for a few seconds, then leave with whatever it has
            steer_to(x + lengthdir_x(100, dir + 3), y + lengthdir_y(100, dir + 3));
            idle++;
            if (idle > 180 && incoming <= 0) state = "flee";
        }
        break;

    case "flee":
        // Straight out, away from the station
        var _out = point_direction(STATION_X, STATION_Y, x, y);
        steer_to(x + lengthdir_x(200, _out), y + lengthdir_y(200, _out));
        if (incoming <= 0 && point_distance(x, y, STATION_X, STATION_Y) > play_radius()) escaped();
        break;
}
