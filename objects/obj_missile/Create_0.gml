/// Player missile (right-click, scr_pirates missile_fire). Flies from the station to the
/// point it was given in a sidewinder weave (a corkscrew round the straight line, settling
/// onto the target), over everything in the way. Goes off only on arrival: one blast
/// (missile_blast), or with Cluster Warheads a burst of bomblets that each blast.
/// Tuning: MISSILE_* and CLUSTER_* in scr_pirates.
depth = -9;
var _st = global.stats;
dir = 0;
sx = x; sy = y;     // launch point
tx = x; ty = y;     // target point
dist = 1;           // straight-line length of the flight
travelled = 0;      // distance along that line so far
weave_sign = 1;     // which way the weave swings first (alternates within a launch)
weave = MISSILE_WEAVE;
spd = 2;
top_speed = _st.missile_speed;
damage = _st.missile_damage * _st.dmg_mult;
blast = _st.missile_blast;
push = _st.missile_push;
cluster = _st.missile_cluster;
bomblet = false;    // a Cluster Warheads bomblet: short straight hop, no further split
scale = 1;          // corkscrew depth: the body swells and shrinks as it rolls
trail = [];
image_blend = make_colour_rgb(120, 255, 230);

/// Sets the target (_tx, _ty) from where it is now; _sign = first swing direction.
launch = function(_tx, _ty, _sign) {
    sx = x; sy = y;
    tx = _tx; ty = _ty;
    dist = max(1, point_distance(sx, sy, tx, ty));
    travelled = 0;
    weave_sign = _sign;
    dir = point_direction(sx, sy, tx, ty);
};

explode = function() {
    if (cluster && !bomblet) {
        // Cluster Warheads: no main blast - it bursts into bomblets that hop out and go off
        fx_spark(x, y, 8);
        sfx(snd_missile_launch, 0.35, 1.6, 0.1);
        var _rot = random(360);
        for (var i = 0; i < CLUSTER_COUNT; i++) {
            var _a = _rot + i * 360 / CLUSTER_COUNT;
            var _b = instance_create_layer(x, y, "Instances", obj_missile);
            _b.bomblet = true;
            _b.cluster = false;
            _b.weave = 0;
            _b.damage = damage * CLUSTER_DAMAGE;
            _b.blast = blast * CLUSTER_SIZE;
            _b.push = push * CLUSTER_SIZE;
            _b.spd = 5;
            _b.top_speed = max(top_speed, 9);
            _b.launch(x + lengthdir_x(blast * CLUSTER_SPREAD * random_range(0.8, 1.1), _a),
                      y + lengthdir_y(blast * CLUSTER_SPREAD * random_range(0.8, 1.1), _a), 1);
        }
    } else {
        missile_blast(x, y, blast, damage, push);
    }
    instance_destroy();
};
