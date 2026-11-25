// ---------------------------------------------------------------------------
// Game feel: screen shake and room transitions. Both are run by the persistent
// obj_post, so they work the same in every room.
// ---------------------------------------------------------------------------

#macro SHAKE_SCALE   2.5    // master multiplier on every screen_shake() amount: the one number to tune
#macro SHAKE_MAX     16     // cap, in game pixels (was 40: 30 pirate ships hitting at once made the screen unreadable)
#macro SHAKE_DECAY   0.9    // per-frame multiplier
#macro SHAKE_STACK   0.35   // share of a new shake added on top of one already running, so bursts build up
#macro KICK_MAX      14     // cap on directional kick, game pixels (was 24)
#macro KICK_DECAY    0.78   // per-frame multiplier: a kick snaps back fast
#macro HITSTOP_GAP   8      // frames after a hit-stop before a small one can fire again (stops stutter)
#macro SLOWMO_RATE   3      // during slow motion the world moves one frame in every SLOWMO_RATE
#macro TRANS_FRAMES  20     // frames for each half of a transition (cover, then reveal)
#macro TRANS_BANDS   12     // horizontal bands in the wipe

/// Adds random screen shake. _amount is scaled by SHAKE_SCALE (game pixels after scaling).
/// A new shake replaces a smaller one and adds a share on top, so rapid hits build up to SHAKE_MAX.
function screen_shake(_amount) {
    if (!global.settings.screen_shake) return;
    _amount *= SHAKE_SCALE;
    // Stacking eases off as it nears the cap, so a stream of hits settles at a readable rumble
    var _room = max(0, 1 - global.shake / SHAKE_MAX);
    global.shake = min(SHAKE_MAX, max(global.shake + _amount * SHAKE_STACK * _room, _amount));
}

/// Shoves the whole view _amount game pixels towards _dir, then it springs back.
/// Use for punchy one-off hits: rail shots (recoil), big breaks, impacts.
function screen_kick(_dir, _amount) {
    if (!global.settings.screen_shake) return;
    global.kick_x = clamp(global.kick_x + lengthdir_x(_amount, _dir), -KICK_MAX, KICK_MAX);
    global.kick_y = clamp(global.kick_y + lengthdir_y(_amount, _dir), -KICK_MAX, KICK_MAX);
}

/// True when the game world should not move this frame: day over, hit-stop, or a
/// skipped slow-motion frame. Every gameplay Step checks this (obj_post Begin Step sets it).
function world_paused() { return global.frozen || !global.world_tick; }

/// Freezes the world for _frames (2-12). Small stops are skipped for a moment after
/// one fires, so a rail shot through a crowd doesn't stutter.
function hit_stop(_frames) {
    if (global.hitstop_cd > 0 && _frames < 8) return;
    if (_frames >= 6) sfx(snd_thud, min(1, 0.3 + _frames * 0.05), 1, 0.05); // only the big stops get a thump
    global.hitstop    = max(global.hitstop, _frames);
    global.hitstop_cd = global.hitstop + HITSTOP_GAP;
}

/// Runs the world at 1/SLOWMO_RATE speed for _frames real frames.
function slow_mo(_frames) {
    if (global.slowmo <= 0) sfx(snd_thud, 0.8, 0.7, 0); // deep thump as time slows
    global.slowmo = max(global.slowmo, _frames);
}

/// Full-screen flash that fades out (drawn by obj_post over the HUD).
function screen_flash(_alpha, _col = c_white) {
    global.flash_a   = max(global.flash_a, _alpha);
    global.flash_col = _col;
}

/// Temporarily adds to the neon glow strength.
function bloom_burst(_amount) { global.bloom_boost = max(global.bloom_boost, _amount); }

/// Wipes the screen closed, changes room, then wipes it open again.
/// Ignored if a transition is already running, so double clicks are safe.
function transition_to(_room) {
    if (!instance_exists(obj_post)) { room_goto(_room); return; }
    with (obj_post) {
        if (trans_state != "none") break;
        trans_state  = "out";
        trans_t      = 0;
        trans_target = _room;
        sfx(snd_transition, 0.5, 1, 0.03);
    }
}

/// True while a transition is covering or revealing the screen (block input then).
function transition_active() {
    return instance_exists(obj_post) && obj_post.trans_state != "none";
}

/// Smooth 0-1 easing used by UI animations.
function ease_out_cubic(_t) { _t = clamp(_t, 0, 1); return 1 - power(1 - _t, 3); }
