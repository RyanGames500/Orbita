/// @description Dibujo por defecto
if (sprite_exists(sprite_index)) {
	draw_self();
} else {
	var _col = is_numeric(orb_state[$ "color"]) ? orb_state[$ "color"] : c_white;
	draw_set_colour(_col);
	draw_circle(x, y, 16, false);
	draw_set_colour(c_white);
}
var _name = orb_state[$ "name"];
if (is_string(_name)) {
	var _top = sprite_exists(sprite_index) ? bbox_top : y - 18;
	draw_set_halign(fa_center);
	draw_set_valign(fa_bottom);
	draw_text(x, _top - 4, _name);
	draw_set_halign(fa_left);
	draw_set_valign(fa_top);
}
