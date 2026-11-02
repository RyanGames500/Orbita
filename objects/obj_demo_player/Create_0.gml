/// @description Tu jugador
if (!variable_instance_exists(id, "nombre")) nombre = "Jugador";
if (!variable_instance_exists(id, "color"))  color = c_white;
velocidad = 4;
mira = 0;
recarga = 0;

vida = 100;
golpe = 0;

orb_on("dano", function(_d, _from) {
	vida -= _d.cantidad;
	golpe = 10;
	if (vida <= 0) {
		x = random_range(50, room_width - 50);
		y = random_range(100, room_height - 70);
		vida = 100;
	}
});