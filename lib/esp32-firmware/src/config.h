#ifndef CONFIG_H
#define CONFIG_H

// ─── WiFi ──────────────────────────────────────────────────────────
#define WIFI_SSID       "LA-REDuio-Davila"
#define WIFI_PASSWORD   "@1002344503"

// ─── Supabase ──────────────────────────────────────────────────────
#define SUPABASE_URL    "https://jzymlturrbekpwomiifc.supabase.co"
#define SUPABASE_ANON_KEY "sb_publishable_JQ0biNHe3HpByYwPF--Lyw_IVMUxyKE"

// ─── Identificador de esta parada ──────────────────────────────────
// Código legible de la parada (debe existir en la tabla `stops.code`).
// Ejemplo: "PARADA_001", "MI_PARADA", etc.
// NO usar UUIDs — el ESP32-C3 no maneja strings tan largos.
#define STOP_CODE       "PARADA_001"

// ─── BLE Scanner ───────────────────────────────────────────────────
// Prefijo del beacon BLE que transmiten los buses: "BUS_<placa>"
#define BUS_BEACON_PREFIX   "BUS_"

// RSSI minimo para considerar un bus cercano (dBm)
// -70 = cercano, -80 = medio, -90 = lejos
#define RSSI_THRESHOLD      -75

// ─── Reporte ───────────────────────────────────────────────────────
// Cooldown para no reportar el mismo bus repetidamente (ms)
#define COOLDOWN_MS         30000

#endif
