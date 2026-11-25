/// Ion storm bolt (spawn_ion_bolt, scr_conditions). points = the ragged path, beyond one screen
/// edge to beyond the other. It flickers faintly for ION_WARN seconds, then strikes: everything
/// within ION_WIDTH of the line is zapped and obj_zap draws the bolt itself.
points = [];
branch = []; // splinter (ION_SPLINTER of bolts): arc from the main line down to the station's hull
warn = round(ION_WARN * game_get_speed(gamespeed_fps));

/// Distance from (_x, _y) to the bolt: the main arc or its splinter, whichever is closer.
bolt_dist = function(_x, _y) { return min(dist_to_path(_x, _y, points), dist_to_path(_x, _y, branch)); };

strike = function() {
    var _pts = points, _me = id;
    // Collect first: a rock that breaks spawns fragments, which mustn't be hit by the same bolt
    var _rocks = [];
    with (obj_asteroid) if (!dead && _me.bolt_dist(x, y) < ION_WIDTH + radius) array_push(_rocks, id);
    var _dmg = ast_hp(AST.SMALL) * ION_ROCK_DMG * threat_hp_mult();
    for (var i = 0; i < array_length(_rocks); i++) {
        var _a = _rocks[i];
        if (!instance_exists(_a)) continue;
        fx_spark(_a.x, _a.y);
        _a.take_hit(_dmg, "zap"); // armour takes half, as from the Tesla
    }
    var _ships = [];
    with (obj_collector) if (!dead && _me.bolt_dist(x, y) < ION_WIDTH + 12) array_push(_ships, id);
    with (obj_fighter)   if (rebuild <= 0 && _me.bolt_dist(x, y) < ION_WIDTH + 12) array_push(_ships, id);
    with (obj_enemy)     if (!dead && _me.bolt_dist(x, y) < ION_WIDTH + 12) array_push(_ships, id);
    for (var i = 0; i < array_length(_ships); i++) {
        var _s = _ships[i];
        if (!instance_exists(_s)) continue;
        fx_spark(_s.x, _s.y);
        _s.take_hit(ION_SHIP_DMG);
    }
    // Station: hit on the side the splinter lands on, or nearest where the main bolt passes (once either way)
    var _splinter = array_length(branch) > 1;
    if (instance_exists(obj_station) && (_splinter || dist_to_path(STATION_X, STATION_Y, _pts) < STATION_RADIUS + ION_WIDTH)) {
        var _nx = _pts[0][0], _ny = _pts[0][1], _nd = infinity;
        if (_splinter) { // the kink before it lands: the end point sits on the hull itself
            var _k = branch[max(0, array_length(branch) - 2)];
            _nx = _k[0]; _ny = _k[1];
        } else for (var i = 0; i < array_length(_pts); i++) {
            var _d = point_distance(_pts[i][0], _pts[i][1], STATION_X, STATION_Y);
            if (_d < _nd) { _nd = _d; _nx = _pts[i][0]; _ny = _pts[i][1]; }
        }
        var _side = station_hull_side(_nx, _ny);
        if (_splinter) fx_spark(branch[array_length(branch) - 1][0], branch[array_length(branch) - 1][1]);
        var _sd = ast_impact(AST.SMALL) * ION_STATION * threat_impact_mult();
        with (obj_station) take_damage(_sd, _side, "ion_bolt");
    }
    var _z = instance_create_depth(0, 0, -12, obj_zap);
    _z.points = _pts;
    _z.width = 11;
    _z.life = 18;
    _z.life_max = 18;
    if (_splinter) { // a slightly thinner fork
        var _zb = instance_create_depth(0, 0, -12, obj_zap);
        _zb.points = branch;
        _zb.width = 8;
        _zb.life = 18;
        _zb.life_max = 18;
    }
    screen_flash(0.15, ION_COLOUR);
    bloom_burst(0.8);
    screen_shake(2);
    sfx(snd_thunder_crack, 0.9, 1, 0.08);
    with (obj_starfield) storm_flash(1); // the clouds behind light up with it
};
