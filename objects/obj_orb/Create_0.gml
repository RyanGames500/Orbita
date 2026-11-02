/// @description Órbita: arranca la conexión
// Este objeto lo crea orb_connect() solo. No hace falta ponerlo en las salas.
if (instance_number(obj_orb) > 1) {
	orb_duplicate = true;
	instance_destroy();
	exit;
}
orb_duplicate = false;
__orb_manager_create();
