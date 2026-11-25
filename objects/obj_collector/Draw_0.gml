// Faint tractor range (spr_ring_line)
draw_sprite_ring(spr_ring_line, 0, x, y, magnet, UI_LINE, c_lime, 0.06);

// Hull fills up as cargo comes aboard; blinks when full
var _col = (full_flash > 0 && (full_flash div 5) mod 2 == 0) ? c_yellow : c_white;
if (flash > 0) _col = c_red;
draw_sprite_fill(sprite_index, x, y, image_xscale, image_yscale, image_angle, _col, 1, min(1, cargo_total / capacity));

// Shield bubble (spr_shield_player: cyan, so it never reads as an enemy's orange one)
var _rad = sprite_width / 2 + 6;
if (max_shield > 0 && shield > 0) {
    var _f = shield / max_shield;
    draw_sprite_sized(spr_shield_player, 0, x, y, _rad * 2, _rad * 2, 0, c_white, 0.3 + 0.6 * _f);
}

// Hull bar under the ship, only once it's been damaged
if (hp < max_hp) {
    var _bw = 32, _by = y + _rad + 6;
    draw_bar(x - _bw / 2, _by, _bw, 4, hp / max_hp, (hp / max_hp > 0.35) ? c_lime : c_red);
    draw_reset();
}
