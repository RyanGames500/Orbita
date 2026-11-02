/// @description Teclas de la demo

// E: saludar a la sala
if (keyboard_check_pressed(ord("E"))) {
	orb_send_room("saludo", { nombre: nombre });
	agregar("Saludaste a la sala");
}

// R: el servidor tira un dado (scripts.js)
if (keyboard_check_pressed(ord("R"))) {
	orb_send_server("tirar_dado", {});
}

// T: preguntarle algo al servidor y esperar respuesta
if (keyboard_check_pressed(ord("T"))) {
	orb_request_server("sumar", { a: 2, b: 3 }, function(_ok, _res) {
		if (_ok) agregar("Servidor: 2 + 3 = " + string(_res));
		else agregar("Servidor no respondio: " + string(_res));
	});
}

// G: base de datos (contador de visitas guardado en el servidor)
if (keyboard_check_pressed(ord("G"))) {
	orb_db_get("demo", "visitas", function(_ok, _valor) {
		// Ojo: una función de adentro NO puede usar las "var" de esta. Por eso se guarda en la instancia.
		visitas = ((_ok && is_numeric(_valor)) ? _valor : 0) + 1;
		orb_db_set("demo", "visitas", visitas, function(_ok2, _r) {
			if (_ok2) agregar("Visitas guardadas en el servidor: " + string(visitas));
			else agregar("No se pudo guardar: " + string(_r));
		});
	});
}

// F: dejar una bandera persistente donde estas
if (keyboard_check_pressed(ord("F")) && instance_exists(obj_demo_player)) {
	orb_world_create({ x: obj_demo_player.x, y: obj_demo_player.y, color: color }, function(_ok, _id) {
		if (_ok) agregar("Bandera creada (id " + string(_id) + "). Queda aunque te vayas.");
		else agregar("No se pudo crear la bandera: " + string(_id));
	});
}

// M: partida rapida de 2 (o cancelar y volver a "demo")
if (keyboard_check_pressed(ord("M"))) {
	if (orb_in_queue()) {
		orb_matchmake_cancel();
		orb_join_room("demo");
		agregar("Busqueda cancelada");
	} else {
		orb_matchmake(2, "demo");
	}
}
