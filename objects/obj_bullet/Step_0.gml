if (world_paused()) exit;

var _px = x, _py = y;
x += vx;
y += vy;

// Circle check for the bullet's size, line check so fast bullets can't skip tiny asteroids
// Asteroids check precisely: their mask is a circle fitted to the hexagon, not the sprite box
var _hit = collision_circle(x, y, radius, obj_asteroid, true, true);
if (_hit == noone) _hit = collision_line(_px, _py, x, y, obj_asteroid, true, true);
if (_hit == noone) _hit = collision_circle(x, y, radius, obj_enemy, false, true);
if (_hit == noone) _hit = collision_line(_px, _py, x, y, obj_enemy, false, true);
if (_hit != noone && _hit.dead) _hit = noone;
if (ignore_t > 0) { ignore_t--; if (_hit == ignore) _hit = noone; }
if (_hit != noone) {
    fx_spark(x, y, round(2 * max(2, radius))); // bigger rounds throw more sparks (radius 2 = the usual 4)
    if (track > 0 && !scored && instance_exists(obj_game)) { // balance log: accuracy
        scored = true;
        if (track == 1) obj_game.dlog.hits++;
    }
    // Rubber / armoured rocks bounce it for free; otherwise Harder Bullets spends a ricochet.
    // Worked out before the hit, which may break the rock.
    var _b = undefined;
    if (bounces > 0 && ast_deflects(_hit)) { _b = ast_bounce(_hit, _px, _py, vx, vy, radius); bounces--; }
    else if (ricochets > 0) {
        _b = ast_bounce(_hit, _px, _py, vx, vy, radius); // reflects off the hit's surface (rock or ship)
        ricochets--;
        sfx(snd_ricochet, 0.2, 1.2, 0.15);
    }
    if (track == 1) dlog_wpn(WPN.GUN, _hit, damage); // balance log (and Combat HUD)
    else dps_hit(false, _hit, damage);              // rear turret, escort guns: passive
    _hit.take_hit(damage); // armour shrugs it off inside take_hit
    if (_b == undefined) { instance_destroy(); exit; }
    vx = _b.vx; vy = _b.vy;
    x  = _b.x;  y  = _b.y;
    image_angle = point_direction(0, 0, vx, vy);
    ignore = _hit;
    ignore_t = 4;
}

if (!in_view(x, y, -32)) instance_destroy();
