/// @description Moverse, disparar y compartir el estado
var _h = (keyboard_check(vk_right) || keyboard_check(ord("D"))) - (keyboard_check(vk_left) || keyboard_check(ord("A")));
var _v = (keyboard_check(vk_down)  || keyboard_check(ord("S"))) - (keyboard_check(vk_up)   || keyboard_check(ord("W")));

if (_h != 0 || _v != 0) {
	mira = point_direction(0, 0, _h, _v);
	x += lengthdir_x(velocidad, mira);
	y += lengthdir_y(velocidad, mira);
}
x = clamp(x, 16, room_width - 16);
y = clamp(y, 80, room_height - 50);

if (recarga > 0) recarga -= 1;
if (keyboard_check(vk_space) && recarga <= 0) {
	recarga = 8;
	var _b = instance_create_depth(x + lengthdir_x(20, mira), y + lengthdir_y(20, mira), 0, obj_demo_bullet);
	_b.direction = mira;
	_b.speed = 9;
	_b.orb_props = { color: color, radius: 5 };
}

if (golpe > 0) golpe -= 1;

// Lo que los demás ven de ti
global.orb_state = orb_state_from(id);
global.orb_state.name = nombre;
global.orb_state.color = color;
global.orb_state.vida = vida;