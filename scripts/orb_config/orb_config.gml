// ======================================================
// ÓRBITA - Configuración
// Lo único que normalmente tienes que cambiar está aquí.
// ======================================================

// --- Servidor ---
// En tu PC (npm start):        "127.0.0.1", 3000, false
// En Render u otro hosting:    "tu-servicio.onrender.com", 443, true
#macro ORB_HOST            "127.0.0.1"
#macro ORB_PORT            3000
#macro ORB_SECURE          false        // true = wss (obligatorio en hostings con https)

// --- Juego ---
#macro ORB_GAME_ID         "MiJuego"    // separa los datos de cada juego en el mismo servidor
#macro ORB_GAME_KEY        ""           // si el servidor tiene GAME_KEY, pon la misma aquí

// --- Red ---
#macro ORB_SEND_EVERY      2            // cada cuántos frames se manda tu estado (2 = 30 veces/seg a 60fps)
#macro ORB_AUTO_RECONNECT  true         // reconectar solo si se cae el internet
#macro ORB_REQUEST_TIMEOUT 10000        // ms para dar por fallida una petición (base de datos, IA...)

// --- Instancias de los demás ---
#macro ORB_PLAYER_OBJECT   obj_otro_jugador        // objeto para los otros jugadores (puede ser un hijo tuyo)
#macro ORB_ENTITY_OBJECT   obj_orb_remote_entity  // objeto por defecto para entidades de otros
#macro ORB_WORLD_OBJECT    obj_orb_world          // objeto para los objetos del mundo (persistentes)
#macro ORB_VIEW_DEPTH      0                       // profundidad a la que se crean
#macro ORB_SMOOTH          0.35                    // suavizado de movimiento (0 = sin suavizar, 1 = instantáneo)
#macro ORB_SNAP_DISTANCE   250                     // si la diferencia es mayor, se teletransporta

// --- Variables que se copian por defecto (estado y entidades) ---
#macro ORB_DEFAULT_SYNC    ["x", "y", "sprite_index", "image_index", "image_xscale", "image_yscale", "image_angle", "image_blend", "image_alpha", "visible"]

// --- Mensajes de depuración en la consola ---
#macro ORB_DEBUG           true

// --- Nombres de los eventos del sistema (para orb_on) ---
#macro ORB_EV_CONNECTED    "orb:connected"     // data: { my_id }
#macro ORB_EV_DISCONNECTED "orb:disconnected"  // data: { reason }
#macro ORB_EV_ROOM         "orb:room"          // data: { name, host, slot }   name = "" si saliste
#macro ORB_EV_JOINED       "orb:player_joined" // data: { player, slot }
#macro ORB_EV_LEFT         "orb:player_left"   // data: { player }
#macro ORB_EV_HOST         "orb:host"          // data: { player }
#macro ORB_EV_QUEUE        "orb:queue"         // data: { count, size }
#macro ORB_EV_PLAYER_DATA  "orb:player_data"   // data: { player }
#macro ORB_EV_KICKED       "orb:kicked"        // data: { by }
#macro ORB_EV_DISCORD      "orb:discord"       // data: { channel, user, user_id, msg }
#macro ORB_EV_ERROR        "orb:error"         // data: { code, msg }
