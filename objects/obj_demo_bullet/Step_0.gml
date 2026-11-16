/// @description Golpear o desaparecer
var _otro = instance_nearest(x, y, obj_orb_player);
if (_otro != noone && point_distance(x, y, _otro.x, _otro.y) < 21) {
	orb_send(_otro.orb_id, "dano", { cantidad: 10 });
	_otro.golpe = 10;   // lo pinto rojo YA en mi pantalla, sin esperar
	instance_destroy();
	exit;
}

vida -= 1;
if (vida <= 0 || x < -20 || y < -20 || x > room_width + 20 || y > room_height + 20) {
	instance_destroy();
}