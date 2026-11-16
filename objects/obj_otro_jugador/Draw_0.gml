event_inherited();

if (golpe > 0) {
	draw_set_colour(c_red);
	draw_circle(x, y, 16, false);
	draw_set_colour(c_white);
}

var _vida = orb_state[$ "vida"];
if (is_numeric(_vida)) {
	draw_healthbar(x - 20, y + 22, x + 20, y + 26, _vida, c_black, c_red, c_lime, 0, true, true);
}