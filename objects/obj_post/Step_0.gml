/// Global hotkeys (work in every room). Changes are saved like the Options menu.
var _s = global.settings;
var _changed = false;
if (keyboard_check_pressed(vk_f4)) toggle_fullscreen();
if (keyboard_check_pressed(vk_f5)) { _s.glow = !_s.glow;           _changed = true; }
if (keyboard_check_pressed(vk_f6)) { _s.scanlines = !_s.scanlines; _changed = true; }

// Live glow tuning: [ weaker, ] stronger
if (DEBUG_KEYS) {
    var _d = keyboard_check_pressed(221) - keyboard_check_pressed(219); // ] and [
    if (_d != 0) {
        _s.glow_strength = clamp(_s.glow_strength + _d * 0.2, 0, 6);
        tune_text_timer = 120;
        _changed = true;
    }
}
if (_changed) settings_save();
if (tune_text_timer > 0) tune_text_timer--;

// Music follows the room and the state of the day (scr_audio)
music_update();
loops_update(); // looping effects: station hum, low-hull alarm (scr_audio)

// Screen shake decays every frame
global.shake = (global.shake > 0.05) ? global.shake * SHAKE_DECAY : 0;
global.kick_x = (abs(global.kick_x) > 0.05) ? global.kick_x * KICK_DECAY : 0;
global.kick_y = (abs(global.kick_y) > 0.05) ? global.kick_y * KICK_DECAY : 0;
global.flash_a     = (global.flash_a > 0.01) ? global.flash_a * 0.86 : 0;
global.bloom_boost = max(0, global.bloom_boost - 0.06);

// Transition: cover, switch room at full cover, then reveal
switch (trans_state) {
    case "out":
        trans_t = min(1, trans_t + 1 / TRANS_FRAMES);
        if (trans_t >= 1) {
            room_goto(trans_target);
            trans_state = "in";
        }
        break;
    case "in":
        trans_t = max(0, trans_t - 1 / TRANS_FRAMES);
        if (trans_t <= 0) trans_state = "none";
        break;
}
