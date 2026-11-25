// Shared by all enemies: hit flash and shield recharge (10% of max per second after a pause)
if (world_paused() || dead) exit;
if (flash > 0) flash--;
squash *= 0.72;
// Shoved by a missile shockwave (obj_wave): drifts outwards, easing off
if (push_x != 0 || push_y != 0) {
    x += push_x; y += push_y;
    push_x *= 0.88; push_y *= 0.88;
    if (abs(push_x) + abs(push_y) < 0.05) { push_x = 0; push_y = 0; }
}
if (shield_delay > 0) shield_delay--;
else shield = min(max_shield, shield + max_shield * 0.1 / game_get_speed(gamespeed_fps));
