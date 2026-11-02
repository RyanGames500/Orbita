/// @description Objeto del mundo (persistente en la sala del servidor)
// Variables que pone Órbita:
//   orb_world_id -> id del objeto (para orb_world_edit / orb_world_destroy)
//   orb_props    -> sus datos (struct). Si tiene x, y, sprite_index... se aplican solos.
if (!variable_instance_exists(id, "orb_world_id")) orb_world_id = -1;
if (!variable_instance_exists(id, "orb_props"))    orb_props = {};
orb_remote = true;
orb_first = true;
orb_tx = x;
orb_ty = y;
