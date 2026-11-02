/// @description Copia lo que manda el dueño (con suavizado)
orb_first = __orb_apply_struct(id, orb_entity, orb_first);
orb_props = is_struct(orb_entity[$ "props"]) ? orb_entity[$ "props"] : {};
