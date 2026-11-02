/// @description Entidad de otro jugador (la crea Órbita)
// Variables que pone Órbita:
//   orb_owner      -> id del jugador dueño
//   orb_entity_id  -> id de la entidad
//   orb_kind       -> nombre del objeto original ("obj_bala")
//   orb_entity     -> todo lo que mandó (struct)
//   orb_props      -> sus datos extra (struct)
// Para usar otro objeto según el tipo: orb_entity_view("obj_bala", obj_bala_remota)
if (!variable_instance_exists(id, "orb_owner"))     orb_owner = -1;
if (!variable_instance_exists(id, "orb_entity_id")) orb_entity_id = "";
if (!variable_instance_exists(id, "orb_kind"))      orb_kind = "";
if (!variable_instance_exists(id, "orb_entity"))    orb_entity = {};
orb_props = is_struct(orb_entity[$ "props"]) ? orb_entity[$ "props"] : {};
orb_remote = true;
orb_first = true;
orb_tx = x;
orb_ty = y;
