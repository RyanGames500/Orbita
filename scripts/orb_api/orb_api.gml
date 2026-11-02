// ======================================================
// ÓRBITA - Funciones para tu juego
// ======================================================

// ---------------- Conexión ----------------

/// Conecta al servidor (crea obj_orb si no existe). Llámala una vez al iniciar el juego.
function orb_connect() {
	__orb_init();
	if (!instance_exists(obj_orb)) {
		instance_create_depth(0, 0, 0, obj_orb);
	} else if (__ORB.status == "off") {
		__ORB.manual_off = false;
		__ORB.fatal = false;
		__orb_open();
	}
}

/// Se desconecta y no reintenta.
function orb_disconnect() {
	__orb_init();
	__ORB.manual_off = true;
	__ORB.want_room = "";
	if (__ORB.status == "connected") __orb_send({ t: "bye" });
	__orb_connection_lost("manual");
}

function orb_is_connected() { __orb_init(); return __ORB.status == "connected"; }
/// "off" | "connecting" | "connected"
function orb_status()       { __orb_init(); return __ORB.status; }
function orb_my_id()        { __orb_init(); return __ORB.my_id; }
/// Ping en milisegundos (-1 si no se sabe)
function orb_ping()         { __orb_init(); return __ORB.ping; }

// ---------------- Salas ----------------

/// Entra a una sala. _max = máximo de jugadores (0 = sin límite; solo cuenta si la sala es nueva).
/// _callback(ok, sala_o_error)  error posible: "room_full"
function orb_join_room(_room, _max = 0, _callback = undefined) {
	__orb_init();
	__ORB.want_room_max = _max;
	if (__ORB.status != "connected") {
		__ORB.want_room = string(_room);
		// Se unirá sola al conectarse (y entonces llamará al callback)
		__ORB.want_room_cb = _callback;
		return;
	}
	__orb_request("join", { rm: string(_room), mx: _max }, _callback);
}

/// Sale de la sala actual (o de la cola de búsqueda).
function orb_leave_room(_callback = undefined) {
	__orb_init();
	__ORB.want_room = "";
	__orb_request("leave", {}, _callback);
}

function orb_room()      { __orb_init(); return __ORB.cur_room; }     // "" si no estás en una sala
function orb_slot()      { __orb_init(); return __ORB.slot; }     // tu puesto en la sala (0, 1, 2...) -> equipo = orb_slot() mod 2
function orb_host_id()   { __orb_init(); return __ORB.host; }
function orb_is_host()   { __orb_init(); return __ORB.host != -1 && __ORB.host == __ORB.my_id; }

/// Saca a un jugador de la sala (solo funciona si eres el host).
function orb_kick(_player) {
	__orb_init();
	var _m = { t: "kick" };
	_m[$ "id"] = _player;
	__orb_send(_m);
}

/// _callback(ok, lista)  lista = [{ id, players, max }, ...]
function orb_list_rooms(_callback) { __orb_init(); __orb_request("rooms", {}, _callback); }

/// _callback(ok, lista_de_ids)
function orb_room_players(_room, _callback) { __orb_init(); __orb_request("players", { rm: string(_room) }, _callback); }

// ---------------- Partida rápida ----------------

/// Busca partida de _size jugadores. Mientras busca llega el evento ORB_EV_QUEUE { count, size }.
/// Cuando se completa, entras solo a la sala (evento ORB_EV_ROOM).
function orb_matchmake(_size, _mode = "default", _callback = undefined) {
	__orb_init();
	__ORB.want_room = "";
	__orb_request("mm", { size: _size, mode: string(_mode) }, _callback);
}

function orb_matchmake_cancel() {
	__orb_init();
	__ORB.in_queue = false;
	__orb_request("mm_cancel", {}, undefined);
}

function orb_in_queue()    { __orb_init(); return __ORB.in_queue; }
function orb_queue_count() { __orb_init(); return __ORB.queue_count; }

// ---------------- Tu estado ----------------
// Pon en global.orb_state lo que los demás deben ver de ti. Se manda solo, únicamente si cambió.
//     global.orb_state = orb_state_from(id);
//     global.orb_state.nombre = "Ana";

/// Copia de una instancia las variables visibles (x, y, sprite, escala, ángulo, color, alpha, visible).
function orb_state_from(_inst) {
	var _s = {};
	if (!instance_exists(_inst)) return _s;
	var _vars = ORB_DEFAULT_SYNC;
	for (var i = 0; i < array_length(_vars); i++) {
		_s[$ _vars[i]] = variable_instance_get(_inst, _vars[i]);
	}
	return _s;
}

/// Datos que el servidor puso para ti (scripts.js -> api.setPlayerData)
function orb_my_data() { __orb_init(); return __ORB.my_data; }

// ---------------- Otros jugadores ----------------

/// Lista de ids de los otros jugadores de tu sala.
function orb_players() {
	__orb_init();
	var _out = [];
	var _keys = variable_struct_get_names(__ORB.players);
	for (var i = 0; i < array_length(_keys); i++) array_push(_out, __ORB.players[$ _keys[i]].pid);
	return _out;
}

function orb_player_count() { __orb_init(); return array_length(variable_struct_get_names(__ORB.players)); }

/// Instancia que representa a ese jugador (noone si no existe).
function orb_player_instance(_player) {
	__orb_init();
	var _pl = __ORB.players[$ string(_player)];
	if (!is_struct(_pl) || !instance_exists(_pl.inst)) return noone;
	return _pl.inst;
}

/// Su global.orb_state (struct vacío si no existe)
function orb_player_state(_player) {
	__orb_init();
	var _pl = __ORB.players[$ string(_player)];
	return is_struct(_pl) ? _pl.s : {};
}

function orb_player_slot(_player) {
	__orb_init();
	var _pl = __ORB.players[$ string(_player)];
	if (is_struct(_pl)) return _pl.slot;
	return (_player == __ORB.my_id) ? __ORB.slot : -1;
}

/// Datos que el servidor puso para ese jugador
function orb_player_data(_player) {
	__orb_init();
	if (_player == __ORB.my_id) return __ORB.my_data;
	var _pl = __ORB.players[$ string(_player)];
	return is_struct(_pl) ? _pl.pd : {};
}

/// Crear o no las instancias de los demás (ponlo en false en el menú, por ejemplo).
function orb_spawn_views(_enabled) {
	__orb_init();
	__ORB.spawn_views = _enabled;
	if (!_enabled) __orb_destroy_views();
}

// ---------------- Entidades (balas, cajas, efectos...) ----------------
// Haz que tu objeto tenga como padre a obj_orb_entity y aparecerá en la pantalla de los demás.
// En su Create llama event_inherited() y, si quieres, cambia:
//     orb_sync  = ["x", "y", "image_angle"];   // qué variables copiar
//     orb_props = { dano: 10 };                // datos extra (los demás los ven en orb_props)

/// Qué objeto usar en los demás para las entidades de cierto tipo.
/// Ejemplo: orb_entity_view("obj_bala", obj_bala_remota)
function orb_entity_view(_object_name, _view_object) {
	__orb_init();
	__ORB.entity_views[$ string(_object_name)] = _view_object;
}

// ---------------- Eventos ----------------

/// Escucha un evento. _fn(data, from)   from = id del que lo mandó (-1 = servidor o sistema)
/// Si la misma instancia vuelve a llamar orb_on con el mismo nombre, se reemplaza (no se duplica).
function orb_on(_name, _fn) {
	__orb_init();
	var _list = __ORB.handlers[$ _name];
	if (!is_array(_list)) _list = [];
	var _owner = is_method(_fn) ? method_get_self(_fn) : undefined;
	var _new = [];
	for (var i = 0; i < array_length(_list); i++) {
		var _f = _list[i];
		if (!__orb_fn_alive(_f)) continue;
		var _o = is_method(_f) ? method_get_self(_f) : undefined;
		if (!is_undefined(_owner) && !is_struct(_owner) && _o == _owner) continue; // reemplazar
		array_push(_new, _f);
	}
	array_push(_new, _fn);
	__ORB.handlers[$ _name] = _new;
}

/// Deja de escuchar un evento (todas las funciones con ese nombre).
function orb_off(_name) {
	__orb_init();
	variable_struct_remove(__ORB.handlers, _name);
}

/// Manda un evento a un jugador.
function orb_send(_player, _name, _data = {}) {
	__orb_init();
	return __orb_send({ t: "ev", to: _player, n: string(_name), d: _data });
}

/// Manda un evento a todos los de tu sala (menos a ti).
function orb_send_room(_name, _data = {}) {
	__orb_init();
	return __orb_send({ t: "ev", to: "room", n: string(_name), d: _data });
}

/// Manda un evento a todos los de tu sala (incluido tú).
function orb_send_all(_name, _data = {}) {
	__orb_init();
	return __orb_send({ t: "ev", to: "all", n: string(_name), d: _data });
}

/// Manda un evento al servidor (scripts.js -> onEvent). Sin respuesta.
function orb_send_server(_name, _data = {}) {
	__orb_init();
	return __orb_send({ t: "sev", n: string(_name), d: _data });
}

/// Pregunta al servidor (scripts.js -> onRequest). _callback(ok, respuesta)
function orb_request_server(_name, _data, _callback) {
	__orb_init();
	__orb_request("server", { n: string(_name), d: _data }, _callback);
}

// ---------------- Base de datos ----------------
// Los datos quedan en el servidor y se separan por ORB_GAME_ID.

/// _callback(ok, valor)   si no existe: ok = false, valor = "not_found"
function orb_db_get(_collection, _key, _callback) {
	__orb_init();
	__orb_request("db_get", { c: string(_collection), k: string(_key) }, _callback);
}

/// Guarda (reemplaza) un valor: número, texto, array o struct. _callback(ok, "")
function orb_db_set(_collection, _key, _value, _callback = undefined) {
	__orb_init();
	__orb_request("db_set", { c: string(_collection), k: string(_key), v: _value }, _callback);
}

/// Mezcla campos en un struct guardado (crea el documento si no existe). _callback(ok, struct_resultante)
function orb_db_merge(_collection, _key, _struct, _callback = undefined) {
	__orb_init();
	__orb_request("db_merge", { c: string(_collection), k: string(_key), v: _struct }, _callback);
}

function orb_db_delete(_collection, _key, _callback = undefined) {
	__orb_init();
	__orb_request("db_delete", { c: string(_collection), k: string(_key) }, _callback);
}

/// _callback(ok, claves)   con _collection = "" devuelve las colecciones
function orb_db_list(_collection, _callback) {
	__orb_init();
	__orb_request("db_list", { c: string(_collection) }, _callback);
}

// ---------------- Objetos del mundo (persistentes) ----------------
// Siguen existiendo en la sala aunque todos se vayan. Aparecen como ORB_WORLD_OBJECT con orb_props.

/// _callback(ok, id_del_objeto)
function orb_world_create(_props, _callback = undefined) {
	__orb_init();
	__orb_request("world_create", { p: _props }, _callback);
}

function orb_world_edit(_world_id, _props) {
	__orb_init();
	var _m = { t: "world_edit", p: _props };
	_m[$ "id"] = _world_id;
	__orb_send(_m);
}

function orb_world_destroy(_world_id) {
	__orb_init();
	var _m = { t: "world_destroy" };
	_m[$ "id"] = _world_id;
	__orb_send(_m);
}

// ---------------- Extras ----------------

/// _callback(ok, milisegundos_unix)
function orb_server_time(_callback) { __orb_init(); __orb_request("time", {}, _callback); }

/// IA en el servidor. _messages = [{ role: "system"|"user"|"assistant", content: "texto" }, ...]
/// _callback(ok, texto_o_error)
function orb_ai(_messages, _temperature, _callback) {
	__orb_init();
	__orb_request("ai", { msgs: _messages, temp: _temperature }, _callback);
}

/// Manda un mensaje a un canal de Discord (el servidor necesita DISCORD_BOT_TOKEN y DISCORD_GUILD_ID).
function orb_discord_send(_channel_id, _text, _callback = undefined) {
	__orb_init();
	__orb_request("discord", { ch: string(_channel_id), msg: string(_text) }, _callback);
}

/// Dibuja el estado de la conexión (útil mientras desarrollas). Úsalo en un Draw GUI.
function orb_debug_draw(_x, _y) {
	__orb_init();
	var _col = (__ORB.status == "connected") ? c_lime : ((__ORB.status == "connecting") ? c_yellow : c_red);
	var _lines = [
		"ORBITA: " + __ORB.status + "  (" + (ORB_SECURE ? "wss://" : "ws://") + ORB_HOST + ":" + string(ORB_PORT) + ")",
		"Mi id: " + string(__ORB.my_id) + "   Ping: " + string(__ORB.ping) + " ms",
		"Sala: " + ((__ORB.cur_room == "") ? "(ninguna)" : __ORB.cur_room) + "   Puesto: " + string(__ORB.slot) + (orb_is_host() ? "   [HOST]" : ""),
		"Jugadores: " + string(orb_player_count() + ((__ORB.cur_room == "") ? 0 : 1)) + (__ORB.in_queue ? ("   Buscando: " + string(__ORB.queue_count) + "/" + string(__ORB.queue_size)) : "")
	];
	draw_set_halign(fa_left);
	draw_set_valign(fa_top);
	for (var i = 0; i < array_length(_lines); i++) {
		draw_set_colour(c_black);
		draw_text(_x + 1, _y + i * 18 + 1, _lines[i]);
		draw_set_colour(i == 0 ? _col : c_white);
		draw_text(_x, _y + i * 18, _lines[i]);
	}
	draw_set_colour(c_white);
}
