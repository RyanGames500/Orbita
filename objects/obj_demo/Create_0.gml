/// @description Demo de Órbita: conecta, entra a la sala "demo" y crea tu jugador
randomize();

nombre = "Jugador" + string(irandom_range(100, 999));
color  = make_colour_hsv(irandom(255), 190, 255);
mensajes = [];
visitas = 0;

agregar = function(_texto) {
	array_insert(mensajes, 0, _texto);
	if (array_length(mensajes) > 7) array_resize(mensajes, 7);
};

orb_connect();
orb_join_room("demo");   // si todavía no conecta, entra sola al conectarse

instance_create_depth(random_range(120, room_width - 120), random_range(180, room_height - 80), 0, obj_demo_player, {
	nombre: nombre,
	color:  color
});

// --- Eventos del sistema ---
orb_on(ORB_EV_CONNECTED, function(_d, _from) {
	agregar("Conectado. Mi id: " + string(_d.my_id));
});
orb_on(ORB_EV_DISCONNECTED, function(_d, _from) {
	agregar("Desconectado (" + string(_d.reason) + "). Reintentando...");
});
orb_on(ORB_EV_ROOM, function(_d, _from) {
	if (_d.name == "") agregar("Saliste de la sala");
	else agregar("Sala: " + _d.name + "  (tu puesto: " + string(_d.slot) + ")");
});
orb_on(ORB_EV_JOINED, function(_d, _from) {
	agregar("Entro el jugador " + string(_d.player));
});
orb_on(ORB_EV_LEFT, function(_d, _from) {
	agregar("Salio el jugador " + string(_d.player));
});
orb_on(ORB_EV_HOST, function(_d, _from) {
	agregar("Nuevo host: " + string(_d.player));
});
orb_on(ORB_EV_QUEUE, function(_d, _from) {
	agregar("Buscando partida: " + string(_d.count) + "/" + string(_d.size));
});
orb_on(ORB_EV_ERROR, function(_d, _from) {
	agregar("Error: " + string(_d.msg));
});

// --- Eventos de la demo ---
orb_on("saludo", function(_d, _from) {
	agregar(string(_d.nombre) + " saluda!");
});
orb_on("resultado_dado", function(_d, _from) {
	agregar("El servidor tiro un dado para " + string(_d.jugador) + ": " + string(_d.valor));
});
