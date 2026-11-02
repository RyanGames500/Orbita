event_inherited();   // dibuja el círculo y el nombre como siempre

var _vida = orb_state[$ "vida"];
if (is_numeric(_vida)) {
    draw_healthbar(x - 20, y + 22, x + 20, y + 26, _vida, c_black, c_red, c_lime, 0, true, true);
}