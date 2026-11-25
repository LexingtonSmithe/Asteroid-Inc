/// Begin Step: decides whether the game world moves this frame (hit-stop, slow motion).
/// Runs before every other Step, so world_paused() is right for the whole frame.
global.world_tick = true;
if (global.hitstop_cd > 0) global.hitstop_cd--;
if (global.hitstop > 0) {
    global.hitstop--;
    global.world_tick = false;
} else if (global.slowmo > 0) {
    global.slowmo--;
    global.world_tick = (global.slowmo mod SLOWMO_RATE == 0);
}
