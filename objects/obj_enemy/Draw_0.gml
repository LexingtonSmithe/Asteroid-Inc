// Shield bubble (spr_shield_enemy), then the hull filled by remaining health
if (max_shield > 0 && shield > 0) {
    var _f = shield / max_shield;
    var _d = (radius + 6) * 2;
    draw_sprite_sized(spr_shield_enemy, 0, x, y, _d, _d, 0, c_white, 0.35 + 0.65 * _f);
}
draw_sprite_fill(sprite_index, x, y, image_xscale * (1 + 0.25 * squash), image_yscale * (1 - 0.18 * squash), image_angle, (flash > 0) ? c_white : image_blend, 1, hp / max_hp);
