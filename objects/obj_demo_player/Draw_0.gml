/// @description Dibujarse
draw_set_colour(golpe > 0 ? c_red : color);
draw_circle(x, y, 16, false);
draw_set_colour(c_white);
draw_circle(x, y, 16, true);
draw_line(x, y, x + lengthdir_x(22, mira), y + lengthdir_y(22, mira));
draw_set_halign(fa_center);
draw_set_valign(fa_bottom);
draw_text(x, y - 22, nombre + " (tu)");
draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_healthbar(x - 20, y + 22, x + 20, y + 26, vida, c_black, c_red, c_lime, 0, true, true);