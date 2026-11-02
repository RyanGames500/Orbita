/// @description Otro jugador (lo crea Órbita)
// Variables que pone Órbita:
//   orb_id     -> id del jugador
//   orb_slot   -> su puesto en la sala (0, 1, 2...)
//   orb_state  -> su global.orb_state (struct)
//   orb_data   -> datos que el servidor puso para él (struct)
// Puedes crear un hijo de este objeto y ponerlo en ORB_PLAYER_OBJECT (orb_config).
// Si el hijo tiene Create, Step o Draw propios, llama event_inherited() al principio.
if (!variable_instance_exists(id, "orb_id"))    orb_id = -1;
if (!variable_instance_exists(id, "orb_slot"))  orb_slot = -1;
if (!variable_instance_exists(id, "orb_state")) orb_state = {};
if (!variable_instance_exists(id, "orb_data"))  orb_data = {};
orb_remote = true;
orb_first = true;
orb_tx = x;
orb_ty = y;
