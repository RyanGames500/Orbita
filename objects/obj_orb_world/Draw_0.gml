/// @description Dibujo por defecto
if (sprite_exists(sprite_index)) {
	draw_self();
} else {
	var _col = is_numeric(orb_props[$ "color"]) ? orb_props[$ "color"] : c_aqua;
	draw_set_colour(_col);
	draw_rectangle(x - 10, y - 10, x + 10, y + 10, false);
	draw_set_colour(c_white);
}
