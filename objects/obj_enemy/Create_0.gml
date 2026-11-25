/// Parent of every hostile ship (obj_raider, obj_raider_escort).
/// Bullets, rail slugs and player lasers hit anything that inherits from this.
/// Children call event_inherited(), then setup(hp, shield).
depth = -9;
image_speed = 0;      // frame 0 = outline, frame 1 = fill (drawn by remaining hull)
dead = false;
hp = 1;
max_hp = 1;
shield = 0;
max_shield = 0;
shield_delay = 0;     // frames before the shield recharges after a hit
radius = 12;
flash = 0;
squash = 0;           // 0-1: squash-and-pop when hit
spd = 2;
dir = 0;
turn_rate = 5;
charge_value = 10;
no_box = false;       // payout days: an "extra" enemy that drops no Black Box (scr_pirates)
push_x = 0;           // shove from a missile shockwave (obj_wave), px per frame, decaying
push_y = 0;

setup = function(_hp, _shield) {
    hp = _hp; max_hp = _hp;
    shield = _shield; max_shield = _shield;
};

take_hit = function(_amount, _src = "") { // _src unused: matches obj_asteroid's take_hit so shared hit lists compile
    if (dead) return;
    flash = 4;
    squash = 1;
    shield_delay = 180;
    if (shield > 0) {
        var _a = min(shield, _amount);
        shield -= _a;
        _amount -= _a;
        if (_amount <= 0) return;
    }
    hp -= _amount;
    if (hp <= 0) {
        hp = 0;
        dead = true;
        destroyed();
    }
};

/// Shot down. Loot an enemy collector was carrying drops back into space on its own
/// (pickups whose ship no longer exists are released).
destroyed = function() {
    fx_hurt(x, y);
    fx_spark(x, y);
    sfx(snd_ship_destroyed, 0.6);
    screen_shake(2);
    hit_stop(3);
    add_charge(charge_value);
    charge_bonus(x, y, CHARGE_BONUS_ENEMY);
    if (object_index != obj_pirate_missile && instance_exists(obj_game)) obj_game.day_downed++; // end-of-day "PIRATES SHOT DOWN"
    enemy_down_drops(); // maybe a Black Box; salvage on a pirate day (scr_pirates)
    instance_destroy();
};

/// Turn towards a point (limited turn rate) and fly forward.
steer_to = function(_tx, _ty) {
    var _want = point_direction(x, y, _tx, _ty);
    dir += clamp(angle_difference(_want, dir), -turn_rate, turn_rate);
    x += lengthdir_x(spd, dir);
    y += lengthdir_y(spd, dir);
    image_angle = dir - SHIP_ART_ANGLE;
};
