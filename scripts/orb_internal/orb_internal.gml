// ======================================================
// ÓRBITA - Núcleo interno
// No necesitas llamar estas funciones: usa las de orb_api.
// ======================================================

#macro __ORB          global.__orb_core
#macro __ORB_PROTOCOL 1

// Variables globales del motor (se crean una sola vez)
function __orb_init() {
	if (variable_global_exists("__orb_core") && is_struct(global.__orb_core)) return;

	global.__orb_core = {
		socket:          -1,
		buffer:          buffer_create(1024, buffer_grow, 1),
		status:          "off",      // "off" | "connecting" | "connected"
		my_id:           -1,
		cur_room:        "",
		want_room:       "",         // sala a la que volver si se reconecta
		want_room_max:   0,
		want_room_cb:    undefined,  // callback de orb_join_room llamado antes de conectar
		host:            -1,
		slot:            -1,
		ping:            -1,
		my_data:         {},
		in_queue:        false,
		queue_count:     0,
		queue_size:      0,

		players:         {},         // "id" -> { pid, slot, s, pd, e: { "eid" -> props }, inst, ents: { "eid" -> inst } }
		world:           {},         // "id" -> { wid, p, inst }
		entity_views:    {},         // "obj_bala" -> objeto que representa esa entidad en los demás
		spawn_views:     true,

		handlers:        {},         // nombre de evento -> [funciones]
		pending:         {},         // "r" -> { fn, time }
		next_request:    1,
		next_entity:     1,

		last_state_json: "",
		entity_cache:    {},         // "eid" -> último JSON mandado
		send_timer:      0,

		manual_off:      false,      // true si llamaste orb_disconnect()
		fatal:           false,      // true si el servidor nos rechazó (clave o versión)
		retry_at:        -1,
		retry_delay:     2000,
		connect_started: 0,
		last_ping_sent:  0,
		last_pong:       0
	};

	if (!variable_global_exists("orb_state") || !is_struct(global.orb_state)) {
		global.orb_state = {};
	}
}

function __orb_log(_text) {
	if (ORB_DEBUG) show_debug_message("[Órbita] " + string(_text));
}

// ¿La función sigue viva? (si fue creada por una instancia que ya no existe, no se llama)
function __orb_fn_alive(_fn) {
	if (is_undefined(_fn)) return false;
	if (!is_method(_fn)) return true;
	var _self = method_get_self(_fn);
	if (is_undefined(_self)) return true;
	if (is_struct(_self)) return true;
	return instance_exists(_self);
}

function __orb_call(_fn, _a, _b) {
	if (!__orb_fn_alive(_fn)) return;
	_fn(_a, _b);
}

// Llama a todos los orb_on de ese nombre
function __orb_dispatch(_name, _data, _from) {
	var _list = __ORB.handlers[$ _name];
	if (!is_array(_list)) return;

	// Copia: un handler puede llamar orb_on/orb_off mientras recorremos
	var _copy = [];
	array_copy(_copy, 0, _list, 0, array_length(_list));

	var _alive = [];
	for (var i = 0; i < array_length(_copy); i++) {
		var _fn = _copy[i];
		if (__orb_fn_alive(_fn)) {
			array_push(_alive, _fn);
			_fn(_data, _from);
		}
	}
	// Quitar los handlers de instancias destruidas (si nadie cambió la lista mientras tanto)
	if (__ORB.handlers[$ _name] == _list && array_length(_alive) != array_length(_list)) {
		__ORB.handlers[$ _name] = _alive;
	}
}

// ------------------------------------------------------
// Conexión
// ------------------------------------------------------
function __orb_open() {
	__orb_close_socket();
	__ORB.status = "connecting";
	__ORB.connect_started = current_time;
	__ORB.retry_at = -1;

	__ORB.socket = network_create_socket(ORB_SECURE ? network_socket_wss : network_socket_ws);
	if (__ORB.socket < 0) {
		__orb_log("No se pudo crear el socket");
		__orb_connection_lost("socket_error");
		return;
	}
	var _res = network_connect_raw_async(__ORB.socket, ORB_HOST, ORB_PORT);
	if (_res < 0) {
		__orb_log("No se pudo iniciar la conexión a " + ORB_HOST + ":" + string(ORB_PORT));
		__orb_connection_lost("connect_error");
		return;
	}
	__orb_log("Conectando a " + (ORB_SECURE ? "wss://" : "ws://") + ORB_HOST + ":" + string(ORB_PORT) + " ...");
}

function __orb_close_socket() {
	if (__ORB.socket >= 0) {
		network_destroy(__ORB.socket);
		__ORB.socket = -1;
	}
}

function __orb_connection_lost(_reason) {
	var _was_connected = (__ORB.status == "connected");
	__orb_close_socket();
	__ORB.status = "off";
	__ORB.my_id = -1;
	__ORB.host = -1;
	__ORB.slot = -1;
	__ORB.ping = -1;
	__ORB.cur_room = "";
	__ORB.in_queue = false;
	__orb_clear_remote();
	__orb_fail_pending("disconnected");

	if (ORB_AUTO_RECONNECT && !__ORB.manual_off && !__ORB.fatal) {
		__ORB.retry_at = current_time + __ORB.retry_delay;
		__orb_log("Conexión perdida (" + string(_reason) + "). Reintentando en " + string(__ORB.retry_delay / 1000) + " s");
		__ORB.retry_delay = min(__ORB.retry_delay * 2, 10000);
	} else {
		__ORB.retry_at = -1;
	}
	if (_was_connected) __orb_dispatch(ORB_EV_DISCONNECTED, { reason: _reason }, -1);
}

function __orb_fail_pending(_reason) {
	var _keys = variable_struct_get_names(__ORB.pending);
	var _list = [];
	for (var i = 0; i < array_length(_keys); i++) array_push(_list, __ORB.pending[$ _keys[i]]);
	__ORB.pending = {};
	for (var i = 0; i < array_length(_list); i++) __orb_call(_list[i].fn, false, _reason);
}

// ------------------------------------------------------
// Envío
// ------------------------------------------------------
function __orb_send(_msg) {
	if (__ORB.socket < 0) return false;
	if (__ORB.status != "connected" && _msg.t != "hello") return false;

	var _txt = json_stringify(_msg);
	var _buf = __ORB.buffer;
	buffer_seek(_buf, buffer_seek_start, 0);
	buffer_write(_buf, buffer_text, _txt);
	network_send_raw(__ORB.socket, _buf, buffer_tell(_buf), network_send_text);
	return true;
}

// Petición con respuesta: _fn(ok, data)
function __orb_request(_op, _args, _fn) {
	if (__ORB.status != "connected") {
		__orb_call(_fn, false, "not_connected");
		return -1;
	}
	var _r = __ORB.next_request;
	__ORB.next_request += 1;
	_args.t = "req";
	_args.r = _r;
	_args.op = _op;
	if (!is_undefined(_fn)) __ORB.pending[$ string(_r)] = { fn: _fn, time: current_time };
	__orb_send(_args);
	return _r;
}

// ------------------------------------------------------
// Objeto manager (obj_orb): Create / Step / Async / CleanUp
// ------------------------------------------------------
function __orb_manager_create() {
	__orb_init();
	__ORB.manual_off = false;
	__ORB.fatal = false;
	__ORB.retry_delay = 2000;
	__orb_open();
}

function __orb_manager_step() {
	var _now = current_time;

	// Reintentar conexión
	if (__ORB.status == "off" && __ORB.retry_at >= 0 && _now >= __ORB.retry_at) {
		__orb_open();
	}

	// Tiempo máximo para conectar
	if (__ORB.status == "connecting" && _now - __ORB.connect_started > 8000) {
		__orb_connection_lost("timeout");
	}

	if (__ORB.status == "connected") {
		// Ping cada segundo; si en 15 s no responde, la conexión está muerta
		if (_now - __ORB.last_ping_sent >= 1000) {
			__ORB.last_ping_sent = _now;
			__orb_send({ t: "ping", c: _now });
		}
		if (_now - __ORB.last_pong > 15000) {
			__orb_connection_lost("no_response");
			exit;
		}

		// Mandar estado y entidades
		__ORB.send_timer++;
		if (__ORB.send_timer >= ORB_SEND_EVERY) {
			__ORB.send_timer = 0;
			__orb_send_state();
		}
	}

	// Peticiones vencidas
	var _keys = variable_struct_get_names(__ORB.pending);
	for (var i = 0; i < array_length(_keys); i++) {
		var _p = __ORB.pending[$ _keys[i]];
		if (_now - _p.time > ORB_REQUEST_TIMEOUT) {
			variable_struct_remove(__ORB.pending, _keys[i]);
			__orb_call(_p.fn, false, "timeout");
		}
	}

	// Crear las instancias de los demás si no existen (por ejemplo, después de un room_goto)
	__orb_sync_views();
}

function __orb_manager_cleanup() {
	if (!variable_global_exists("__orb_core") || !is_struct(global.__orb_core)) return;
	if (__ORB.status == "connected") __orb_send({ t: "bye" });
	__ORB.manual_off = true;
	__orb_close_socket();
	__ORB.status = "off";
}

function __orb_manager_async() {
	if (__ORB.socket < 0) exit;
	if (async_load[? "id"] != __ORB.socket) exit; // mensajes de otros sockets (Gamdato, GGMR...) no son nuestros

	var _type = async_load[? "type"];

	if (_type == network_type_non_blocking_connect) {
		if (async_load[? "succeeded"]) {
			__orb_log("Conectado. Saludando al servidor...");
			__orb_send({
				t: "hello",
				proto: __ORB_PROTOCOL,
				game: ORB_GAME_ID,
				key: (ORB_GAME_KEY == "") ? "" : md5_string_utf8(ORB_GAME_KEY)
			});
		} else {
			__orb_connection_lost("connect_failed");
		}
		exit;
	}

	if (_type == network_type_disconnect) {
		__orb_connection_lost("server_closed");
		exit;
	}

	if (_type == network_type_data) {
		var _buf = async_load[? "buffer"];
		buffer_seek(_buf, buffer_seek_start, 0);
		var _txt = buffer_read(_buf, buffer_text);
		if (buffer_exists(_buf)) buffer_delete(_buf);

		var _msg;
		try {
			_msg = json_parse(_txt);
		} catch (_e) {
			__orb_log("Mensaje inválido del servidor");
			exit;
		}
		if (!is_struct(_msg) || !is_string(_msg[$ "t"])) exit;
		__orb_handle(_msg);
	}
}

// ------------------------------------------------------
// Mensajes del servidor
// ------------------------------------------------------
function __orb_handle(_m) {
	switch (_m.t) {

		case "welcome":
			__ORB.status = "connected";
			__ORB.my_id = _m[$ "id"];
			__ORB.last_pong = current_time;
			__ORB.last_ping_sent = 0;
			__ORB.retry_delay = 2000;
			__ORB.last_state_json = "";
			__ORB.entity_cache = {};
			__orb_log("Listo. Mi id es " + string(__ORB.my_id));
			__orb_dispatch(ORB_EV_CONNECTED, { my_id: __ORB.my_id }, -1);
			// Volver a la sala si nos habíamos desconectado (y el juego no pidió otra cosa)
			if (__ORB.cur_room == "" && __ORB.want_room != "") {
				var _cb = __ORB.want_room_cb;
				__ORB.want_room_cb = undefined;
				__orb_request("join", { rm: __ORB.want_room, mx: __ORB.want_room_max }, _cb);
			}
		break;

		case "err":
			__orb_log("Error del servidor: " + string(_m[$ "msg"]));
			if (_m[$ "code"] == "bad_key" || _m[$ "code"] == "bad_protocol") __ORB.fatal = true;
			__orb_dispatch(ORB_EV_ERROR, { code: _m[$ "code"], msg: _m[$ "msg"] }, -1);
		break;

		case "pong":
			__ORB.last_pong = current_time;
			if (is_numeric(_m[$ "c"])) __ORB.ping = current_time - _m[$ "c"];
		break;

		case "res":
			var _key = string(_m[$ "r"]);
			var _p = __ORB.pending[$ _key];
			if (is_struct(_p)) {
				variable_struct_remove(__ORB.pending, _key);
				__orb_call(_p.fn, (_m[$ "ok"] == true), _m[$ "d"]);
			}
		break;

		case "room":
			__orb_clear_remote();
			__ORB.cur_room = is_string(_m[$ "id"]) ? _m[$ "id"] : "";
			__ORB.host = _m[$ "host"];
			__ORB.slot = _m[$ "slot"];
			__ORB.last_state_json = "";   // reenviar todo a la sala nueva
			__ORB.entity_cache = {};
			if (__ORB.cur_room != "") {
				__ORB.in_queue = false;
				__ORB.want_room = __ORB.cur_room; // si se cae el internet, volvemos aquí
			} else {
				__ORB.want_room = "";
			}

			var _list = _m[$ "players"];
			if (is_array(_list)) {
				for (var i = 0; i < array_length(_list); i++) __orb_add_player(_list[i]);
			}
			var _wl = _m[$ "world"];
			if (is_array(_wl)) {
				for (var i = 0; i < array_length(_wl); i++) {
					var _w = _wl[i];
					__ORB.world[$ string(_w[$ "id"])] = { wid: _w[$ "id"], p: _w[$ "p"], inst: noone };
				}
			}
			__orb_dispatch(ORB_EV_ROOM, { name: __ORB.cur_room, host: __ORB.host, slot: __ORB.slot }, -1);
		break;

		case "join":
			__orb_add_player(_m);
			__orb_dispatch(ORB_EV_JOINED, { player: _m[$ "id"], slot: _m[$ "slot"] }, -1);
		break;

		case "leave":
			__orb_remove_player(_m[$ "id"]);
			__orb_dispatch(ORB_EV_LEFT, { player: _m[$ "id"] }, -1);
		break;

		case "host":
			__ORB.host = _m[$ "id"];
			__orb_dispatch(ORB_EV_HOST, { player: __ORB.host }, -1);
		break;

		case "queue":
			__ORB.in_queue = true;
			__ORB.queue_count = _m[$ "count"];
			__ORB.queue_size = _m[$ "size"];
			__orb_dispatch(ORB_EV_QUEUE, { count: __ORB.queue_count, size: __ORB.queue_size }, -1);
		break;

		case "st":
			var _pl = __ORB.players[$ string(_m[$ "id"])];
			if (!is_struct(_pl)) break;
			if (is_struct(_m[$ "s"])) {
				_pl.s = _m[$ "s"];
				if (instance_exists(_pl.inst)) _pl.inst.orb_state = _pl.s;
			}
			var _es = _m[$ "e"];
			if (is_struct(_es)) {
				var _ek = variable_struct_get_names(_es);
				for (var i = 0; i < array_length(_ek); i++) {
					var _props = _es[$ _ek[i]];
					_pl.e[$ _ek[i]] = _props;
					var _ei = _pl.ents[$ _ek[i]];
					if (!is_undefined(_ei) && instance_exists(_ei)) _ei.orb_entity = _props;
				}
			}
			var _ds = _m[$ "d"];
			if (is_array(_ds)) {
				for (var i = 0; i < array_length(_ds); i++) __orb_remove_entity(_pl, string(_ds[i]));
			}
		break;

		case "pd":
			var _pid = _m[$ "id"];
			var _pdata = is_struct(_m[$ "d"]) ? _m[$ "d"] : {};
			if (_pid == __ORB.my_id) {
				__ORB.my_data = _pdata;
			} else {
				var _pp = __ORB.players[$ string(_pid)];
				if (is_struct(_pp)) {
					_pp.pd = _pdata;
					if (instance_exists(_pp.inst)) _pp.inst.orb_data = _pdata;
				}
			}
			__orb_dispatch(ORB_EV_PLAYER_DATA, { player: _pid }, -1);
		break;

		case "ev":
			var _n = _m[$ "n"];
			if (_n == ORB_EV_KICKED) __ORB.want_room = "";
			__orb_dispatch(_n, _m[$ "d"], _m[$ "from"]);
		break;

		case "world":
			var _wkey = string(_m[$ "id"]);
			var _wo = __ORB.world[$ _wkey];
			if (is_struct(_wo)) {
				_wo.p = _m[$ "p"];
				if (instance_exists(_wo.inst)) _wo.inst.orb_props = _wo.p;
			} else {
				__ORB.world[$ _wkey] = { wid: _m[$ "id"], p: _m[$ "p"], inst: noone };
			}
		break;

		case "world_del":
			var _dkey = string(_m[$ "id"]);
			var _dw = __ORB.world[$ _dkey];
			if (is_struct(_dw)) {
				if (instance_exists(_dw.inst)) instance_destroy(_dw.inst);
				variable_struct_remove(__ORB.world, _dkey);
			}
		break;

		case "discord":
			__orb_dispatch(ORB_EV_DISCORD, { channel: _m[$ "ch"], user: _m[$ "user"], user_id: _m[$ "user_id"], msg: _m[$ "msg"] }, -1);
		break;
	}
}

// ------------------------------------------------------
// Jugadores remotos (datos)
// ------------------------------------------------------
function __orb_add_player(_info) {
	var _id = _info[$ "id"];
	if (_id == __ORB.my_id) return;
	var _key = string(_id);
	var _old = __ORB.players[$ _key];
	if (is_struct(_old)) __orb_remove_player(_id);

	__ORB.players[$ _key] = {
		pid:  _id,
		slot: _info[$ "slot"],
		s:    is_struct(_info[$ "s"]) ? _info[$ "s"] : {},
		pd:   is_struct(_info[$ "pd"]) ? _info[$ "pd"] : {},
		e:    is_struct(_info[$ "e"]) ? _info[$ "e"] : {},
		inst: noone,
		ents: {}
	};
}

function __orb_remove_player(_id) {
	var _key = string(_id);
	var _pl = __ORB.players[$ _key];
	if (!is_struct(_pl)) return;
	var _ek = variable_struct_get_names(_pl.ents);
	for (var i = 0; i < array_length(_ek); i++) {
		var _inst = _pl.ents[$ _ek[i]];
		if (instance_exists(_inst)) instance_destroy(_inst);
	}
	if (instance_exists(_pl.inst)) instance_destroy(_pl.inst);
	variable_struct_remove(__ORB.players, _key);
}

function __orb_remove_entity(_pl, _ekey) {
	var _inst = _pl.ents[$ _ekey];
	if (!is_undefined(_inst) && instance_exists(_inst)) instance_destroy(_inst);
	variable_struct_remove(_pl.ents, _ekey);
	variable_struct_remove(_pl.e, _ekey);
}

function __orb_clear_remote() {
	var _keys = variable_struct_get_names(__ORB.players);
	for (var i = 0; i < array_length(_keys); i++) __orb_remove_player(__ORB.players[$ _keys[i]].pid);
	__ORB.players = {};

	var _wk = variable_struct_get_names(__ORB.world);
	for (var i = 0; i < array_length(_wk); i++) {
		var _w = __ORB.world[$ _wk[i]];
		if (instance_exists(_w.inst)) instance_destroy(_w.inst);
	}
	__ORB.world = {};
}

function __orb_destroy_views() {
	var _keys = variable_struct_get_names(__ORB.players);
	for (var i = 0; i < array_length(_keys); i++) {
		var _pl = __ORB.players[$ _keys[i]];
		if (instance_exists(_pl.inst)) instance_destroy(_pl.inst);
		_pl.inst = noone;
		var _ek = variable_struct_get_names(_pl.ents);
		for (var j = 0; j < array_length(_ek); j++) {
			var _ei = _pl.ents[$ _ek[j]];
			if (instance_exists(_ei)) instance_destroy(_ei);
		}
		_pl.ents = {};
	}
	var _wk = variable_struct_get_names(__ORB.world);
	for (var i = 0; i < array_length(_wk); i++) {
		var _w = __ORB.world[$ _wk[i]];
		if (instance_exists(_w.inst)) instance_destroy(_w.inst);
		_w.inst = noone;
	}
}

// ------------------------------------------------------
// Instancias de los demás (vista): se crean si faltan
// ------------------------------------------------------
function __orb_sync_views() {
	if (!__ORB.spawn_views) return;

	var _keys = variable_struct_get_names(__ORB.players);
	for (var i = 0; i < array_length(_keys); i++) {
		var _pl = __ORB.players[$ _keys[i]];

		if (!instance_exists(_pl.inst)) {
			var _sx = is_numeric(_pl.s[$ "x"]) ? _pl.s[$ "x"] : -10000;
			var _sy = is_numeric(_pl.s[$ "y"]) ? _pl.s[$ "y"] : -10000;
			_pl.inst = instance_create_depth(_sx, _sy, ORB_VIEW_DEPTH, ORB_PLAYER_OBJECT, {
				orb_remote: true,
				orb_id:     _pl.pid,
				orb_slot:   _pl.slot,
				orb_state:  _pl.s,
				orb_data:   _pl.pd
			});
		}

		var _ek = variable_struct_get_names(_pl.e);
		for (var j = 0; j < array_length(_ek); j++) {
			var _ei = _pl.ents[$ _ek[j]];
			if (is_undefined(_ei) || !instance_exists(_ei)) {
				var _props = _pl.e[$ _ek[j]];
				var _kind = is_string(_props[$ "kind"]) ? _props[$ "kind"] : "";
				var _obj = __ORB.entity_views[$ _kind];
				if (is_undefined(_obj)) _obj = ORB_ENTITY_OBJECT;
				var _ex = is_numeric(_props[$ "x"]) ? _props[$ "x"] : -10000;
				var _ey = is_numeric(_props[$ "y"]) ? _props[$ "y"] : -10000;
				_pl.ents[$ _ek[j]] = instance_create_depth(_ex, _ey, ORB_VIEW_DEPTH, _obj, {
					orb_remote:    true,
					orb_owner:     _pl.pid,
					orb_entity_id: _ek[j],
					orb_kind:      _kind,
					orb_entity:    _props
				});
			}
		}
	}

	var _wk = variable_struct_get_names(__ORB.world);
	for (var i = 0; i < array_length(_wk); i++) {
		var _w = __ORB.world[$ _wk[i]];
		if (!instance_exists(_w.inst)) {
			var _p = is_struct(_w.p) ? _w.p : {};
			var _wx = is_numeric(_p[$ "x"]) ? _p[$ "x"] : 0;
			var _wy = is_numeric(_p[$ "y"]) ? _p[$ "y"] : 0;
			_w.inst = instance_create_depth(_wx, _wy, ORB_VIEW_DEPTH, ORB_WORLD_OBJECT, {
				orb_remote:   true,
				orb_world_id: _w.wid,
				orb_props:    _p
			});
		}
	}
}

// ------------------------------------------------------
// Mandar mi estado y mis entidades (solo lo que cambió)
// ------------------------------------------------------
function __orb_send_state() {
	if (__ORB.cur_room == "") return;

	var _msg = { t: "st" };
	var _any = false;

	if (!is_struct(global.orb_state)) global.orb_state = {};
	var _sj = json_stringify(global.orb_state);
	if (_sj != __ORB.last_state_json) {
		__ORB.last_state_json = _sj;
		_msg.s = global.orb_state;
		_any = true;
	}

	var _changed = {};
	var _seen = {};
	var _cache = __ORB.entity_cache;
	var _has_changes = false;

	with (obj_orb_entity) {
		if (variable_instance_exists(id, "orb_remote")) continue;
		if (!variable_instance_exists(id, "orb_entity_id")) {
			orb_entity_id = __ORB.next_entity;
			__ORB.next_entity += 1;
		}
		if (!variable_instance_exists(id, "orb_sync"))      orb_sync = ORB_DEFAULT_SYNC;
		if (!variable_instance_exists(id, "orb_props"))     orb_props = {};

		var _data = { kind: object_get_name(object_index), props: orb_props };
		for (var i = 0; i < array_length(orb_sync); i++) {
			var _var = orb_sync[i];
			if (variable_instance_exists(id, _var)) _data[$ _var] = variable_instance_get(id, _var);
		}

		var _ekey = string(orb_entity_id);
		var _json = json_stringify(_data);
		_seen[$ _ekey] = true;
		if (_cache[$ _ekey] != _json) {
			_cache[$ _ekey] = _json;
			_changed[$ _ekey] = _data;
			_has_changes = true;
		}
	}

	if (_has_changes) {
		_msg.e = _changed;
		_any = true;
	}

	// Entidades que ya no existen
	var _dead = [];
	var _ck = variable_struct_get_names(_cache);
	for (var i = 0; i < array_length(_ck); i++) {
		if (!variable_struct_exists(_seen, _ck[i])) {
			array_push(_dead, _ck[i]);
			variable_struct_remove(_cache, _ck[i]);
		}
	}
	if (array_length(_dead) > 0) {
		_msg.d = _dead;
		_any = true;
	}

	if (_any) __orb_send(_msg);
}

// ------------------------------------------------------
// Aplicar datos a una instancia remota (lo usan los objetos vista)
// ------------------------------------------------------
function __orb_apply_struct(_inst, _data, _first) {
	if (!is_struct(_data)) return _first;
	var _keys = variable_struct_get_names(_data);
	for (var i = 0; i < array_length(_keys); i++) {
		var _k = _keys[i];
		var _v = _data[$ _k];
		switch (_k) {
			case "x":
				if (!is_numeric(_v)) break;
				_inst.orb_tx = _v;
				if (_first || abs(_inst.x - _v) > ORB_SNAP_DISTANCE) _inst.x = _v;
				else _inst.x = lerp(_inst.x, _v, ORB_SMOOTH);
			break;
			case "y":
				if (!is_numeric(_v)) break;
				_inst.orb_ty = _v;
				if (_first || abs(_inst.y - _v) > ORB_SNAP_DISTANCE) _inst.y = _v;
				else _inst.y = lerp(_inst.y, _v, ORB_SMOOTH);
			break;
			case "sprite_index":
				// Respaldo: algunas versiones convierten el sprite a texto ("ref sprite 12")
				if (is_string(_v)) {
					var _digits = string_digits(_v);
					_v = (_digits == "") ? -1 : real(_digits);
				}
				if (is_numeric(_v) && (_v < 0 || sprite_exists(_v))) _inst.sprite_index = _v;
			break;
			case "image_index":
				if (is_numeric(_v)) { _inst.image_index = _v; _inst.image_speed = 0; }
			break;
			case "image_xscale":
			case "image_yscale":
			case "image_angle":
			case "image_blend":
			case "image_alpha":
				if (is_numeric(_v)) variable_instance_set(_inst, _k, _v);
			break;
			case "visible":
				if (is_numeric(_v) || is_bool(_v)) _inst.visible = _v;
			break;
		}
	}
	return false;
}
