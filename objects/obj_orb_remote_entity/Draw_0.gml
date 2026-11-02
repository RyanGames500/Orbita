/// @description Dibujo por defecto
if (sprite_exists(sprite_index)) {
	draw_self();
} else {
	var _col = is_numeric(orb_props[$ "color"]) ? orb_props[$ "color"] : c_yellow;
	var _r = is_numeric(orb_props[$ "radius"]) ? orb_props[$ "radius"] : 5;
	draw_set_colour(_col);
	draw_circle(x, y, _r, false);
	draw_set_colour(c_white);
}
