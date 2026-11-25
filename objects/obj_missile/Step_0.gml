if (world_paused()) exit;

// Speed builds up after launch
spd = min(top_speed, spd + 0.25);
travelled = min(dist, travelled + spd);
var _t = travelled / dist;

// Sidewinder: a swing either side of the straight line, zero at both ends so it
// leaves the hull cleanly and lands exactly on its point. Short shots swing less.
var _base = point_direction(sx, sy, tx, ty);
var _ph   = travelled / MISSILE_WAVELENGTH * 2 * pi;
var _amp  = min(weave, dist * 0.2) * sin(_t * pi);
var _off  = _amp * sin(_ph) * weave_sign;
var _nx = lerp(sx, tx, _t) + lengthdir_x(_off, _base + 90);
var _ny = lerp(sy, ty, _t) + lengthdir_y(_off, _base + 90);
if (_nx != x || _ny != y) dir = point_direction(x, y, _nx, _ny);
x = _nx;
y = _ny;
scale = (bomblet ? 0.6 : 1) * (1 + 0.22 * cos(_ph) * sin(_t * pi)); // rolls towards and away from you

array_push(trail, [x, y]);
if (array_length(trail) > (bomblet ? 5 : 10)) array_delete(trail, 0, 1);
if (!bomblet) fx_missile_sparks(x, y, dir); // motor sparks

if (_t >= 1) explode();
