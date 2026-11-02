/// @description Texto de la demo
orb_debug_draw(12, 10);

draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_set_colour(c_ltgray);
var _ayuda = "Flechas/WASD: mover   ESPACIO: disparar   E: saludar   R: dado   T: preguntar   G: guardar   F: bandera   M: partida rapida";
draw_text(12, display_get_gui_height() - 28, _ayuda);

for (var i = 0; i < array_length(mensajes); i++) {
	draw_set_colour(c_black);
	draw_text(display_get_gui_width() - 461, 11 + i * 18, mensajes[i]);
	draw_set_colour(i == 0 ? c_yellow : c_white);
	draw_text(display_get_gui_width() - 462, 10 + i * 18, mensajes[i]);
}
draw_set_colour(c_white);
