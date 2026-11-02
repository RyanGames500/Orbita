/// @description Entidad que se ve en la pantalla de los demás
// Pon este objeto como PADRE de tus balas, cajas, efectos...
// En el Create de tu objeto llama event_inherited() y después, si quieres:
//   orb_sync  = ["x", "y", "image_angle"];   // qué variables copiar (por defecto: ORB_DEFAULT_SYNC)
//   orb_props = { dano: 10 };                // datos extra que verán los demás
// Cuando la instancia se destruye, desaparece sola en los demás.
__orb_init();
orb_entity_id = __ORB.next_entity;
__ORB.next_entity += 1;
orb_sync = ORB_DEFAULT_SYNC;
orb_props = {};
