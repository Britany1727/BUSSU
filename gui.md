# Guia del Proyecto Bussu

Sistema de gestion y monitoreo de transporte publico.
Flutter + Supabase + Riverpod + Flutter Map + MQTT/IoT.

---

## Raiz del Proyecto

| Archivo/Carpeta | Descripcion |
|---|---|
| `pubspec.yaml` | Dependencias, metadatos del paquete, config de Flutter/Dart |
| `analysis_options.yaml` | Reglas de linting strict (334 lineas) |
| `main.dart` | Punto de entrada: inicializa Supabase, DI, entorno, ejecuta `runApp()` |
| `app.dart` | Widget raiz `MaterialApp.router` con GoRouter + Riverpod |
| `.env` | Variables de entorno (Supabase URL/key, ORS, MQTT) |
| `android/` | Plataforma Android (Kotlin, Gradle KTS) |
| `ios/` | Plataforma iOS (Swift, Xcode) |
| `web/` | Plataforma Web |
| `windows/` | Plataforma Windows |
| `linux/` | Plataforma Linux |
| `macos/` | Plataforma macOS |
| `test/` | Pruebas unitarias (19 archivos) |
| `scripts/` | Scripts de build, deploy y validacion |
| `supabase/` | Migraciones SQL, Edge Functions, seed data, firmware ESP32 |
| `.github/workflows/ci.yml` | Pipeline CI/CD |

---

## `lib/` - Estructura Principal

```
lib/
  main.dart              # Entry point
  app.dart               # MaterialApp.router widget
  core/                  # Infraestructura compartida
  shared/                # Entidades, modelos y widgets compartidos entre features
  features/              # Feature-first: auth, usuario, conductor, cooperativa, admin_municipal, chat
  esp32-firmware/         # Firmware C++ del ESP32 (dentro de lib/ por monorepo)
```

---

## `lib/core/` - Infraestructura

### `core/config/`

| Archivo | Que hace |
|---|---|
| `app_config.dart` | Constantes de configuracion: MQTT, reconexion, geolocalizacion, timeouts |
| `env.dart` | Variables de entorno compiladas: URL de Supabase, API key, clave ORS, credenciales MQTT |

### `core/constants/`

| Archivo | Que hace |
|---|---|
| `app_roles.dart` | Enum `UserRole`: `usuario`, `conductor`, `cooperativaAdmin`, `municipalAdmin` |
| `mqtt_topics.dart` | Constructores de topics MQTT: `bus/{id}/telemetry`, `/status`, `/command`, `/alerts` |

### `core/di/`

| Archivo | Que hace |
|---|---|
| `injection_container.dart` | Configuracion de GetIt + Riverpod: registra todos los repositorios, servicios y datasources (296 lineas) |
| `mock_repositories.dart` | Repositorios mock para desarrollo/testing (296 lineas) |

### `core/error/`

| Archivo | Que hace |
|---|---|
| `exceptions.dart` | Excepciones personalizadas: `ServerException`, `NetworkException`, `AuthException`, etc. |
| `failures.dart` | Clase sellada `Failure`: `NetworkFailure`, `AuthFailure`, `ValidationFailure`, etc. para manejo funcional de errores |

### `core/geocoding/`

| Archivo | Que hace |
|---|---|
| `nominatim_service.dart` | Cliente de geocoding OpenStreetMap (Nominatim): busqueda por texto y reversa (lat/lng a direccion), con cache y retry |

### `core/iot/`

| Archivo | Que hace |
|---|---|
| `device_registry_service.dart` | Registro de dispositivos ESP32: tracks estado conectado/desconectado |
| `hardware_validator.dart` | Validacion HMAC-SHA256 de telemetria ESP32 para garantizar autenticidad |
| `iot_config.dart` | Configuracion del broker MQTT, parametros de dispositivo, timeouts |
| `mqtt_bridge_monitor.dart` | Health check del servicio bridge MQTT-a-Supabase |

### `core/maps/`

| Archivo | Que hace |
|---|---|
| `map_controller_service.dart` | Wrapper del `MapController` de flutter_map |
| `map_service.dart` | Fachada que combina MarkerService + PolylineService |
| `marker_service.dart` | Crea marcadores de bus, parada y usuario en el mapa |
| `polyline_service.dart` | Crea polilineas de rutas con estilos |
| `tile_cache_service.dart` | Cache de tiles en memoria (200) y disco (5000) |
| `tile_provider.dart` | Configuracion de tiles OpenStreetMap (URL + user agent) |

### `core/navigation/`

| Archivo | Que hace |
|---|---|
| `ors_service.dart` | Cliente OpenRouteService API: calcula rutas, direcciones, con cache |

### `core/network/`

| Archivo | Que hace |
|---|---|
| `connectivity_service.dart` | Monitoreo de estado de red (online/offline) |
| `edge_functions_client.dart` | Invocaciones a Edge Functions de Supabase (binding de dispositivo, push, reportes) |
| `mqtt_service.dart` | Cliente MQTT con reconexion automatica, suscripciones, publicacion (302 lineas) |
| `supabase_client.dart` | Factory singleton del cliente Supabase |
| `websocket_service.dart` | Cliente WebSocket con reconexion y backoff (222 lineas) |

### `core/notifications/`

| Archivo | Que hace |
|---|---|
| `push_service.dart` | Interfaz abstracta para notificaciones push |
| `push_service_impl.dart` | Implementacion basada en broadcast de Supabase Realtime |

### `core/payments/`

| Archivo | Que hace |
|---|---|
| `payment_gateway_service.dart` | Interfaz abstracta de pagos |
| `payment_gateway_service_impl.dart` | Placeholder para Stripe/MercadoPago/Niubiz |

### `core/routing/`

| Archivo | Que hace |
|---|---|
| `app_router.dart` | Configuracion de GoRouter con todas las rutas, redirects por rol y verificacion de permisos (285 lineas) |
| `role_guard.dart` | Providers Riverpod de estado de auth y guards por rol |

### `core/security/`

| Archivo | Que hace |
|---|---|
| `certificate_pinner.dart` | Certificate pinning HTTP para prevenir ataques MITM |
| `device_binding_service.dart` | Interfaz abstracta de vinculacion dispositivo-cuenta |
| `device_binding_service_impl.dart` | Validacion de dispositivo basada en fingerprint de hardware |
| `output_sanitizer.dart` | Prevencion de XSS/injection en datos mostrados (80 lineas) |
| `rate_limiter.dart` | Algoritmo token bucket para prevenir abuso de API |
| `secure_logger.dart` | Logging seguro: PII-safe en debug, production-safe en release |
| `secure_storage.dart` | Wrapper de Keychain/EncryptedSharedPreferences |

### `core/services/`

| Archivo | Que hace |
|---|---|
| `auth_session_manager.dart` | Escucha cambios de estado de Supabase Auth |
| `location_service.dart` | Interfaz abstracta de GPS + entidad `LocationData` |
| `location_service_impl.dart` | Implementacion GPS basada en Geolocator |
| `log_service.dart` | Enum `LogLevel` + servicio de logging estructurado |
| `permission_service.dart` | Checks y requests de permisos de ubicacion y notificaciones (permission_handler) |
| `storage_service.dart` | Interfaz abstracta de almacenamiento key-value |

### `core/theme/`

| Archivo | Que hace |
|---|---|
| `app_theme.dart` | Colores (#001B44 primario, #FED000 secundario), tipografia, temas claro/oscuro (141 lineas) |

### `core/utils/`

| Archivo | Que hace |
|---|---|
| `date_formatter.dart` | Formateo de fechas relativas, duracion (locale es_PE) |
| `device_fingerprint.dart` | ID de dispositivo basado en hardware via SHA-256 |
| `eta_calculator.dart` | Suavizado EMA, proyeccion en polilinea, calculo de ETA (298 lineas) |
| `extensions.dart` | Extensiones `BuildContextX`: theme, colorScheme, mediaQuery, helpers de dialogos |
| `result_mapper.dart` | Mapeo centralizado de Exception a Failure para flujos Either |
| `validators.dart` | Validadores de email, telefono, placa, lat/lng, UUID |

---

## `lib/shared/` - Compartido entre Features

### `shared/data/models/`

| Archivo | Que hace |
|---|---|
| `bus_model.dart` | Serializacion de `BusEntity` para Supabase Realtime |
| `route_model.dart` | Serializacion de `RouteEntity` |
| `stop_model.dart` | Serializacion de `StopEntity` |

### `shared/domain/entities/`

| Archivo | Que hace |
|---|---|
| `bus_entity.dart` | Entidad Bus: id, placa, cooperativa, ruta, capacidad, GPS, velocidad, device ID (108 lineas) |
| `directions_entity.dart` | Entidad direcciones: polilinea, distancia en metros, duracion en segundos |
| `geocoding_entity.dart` | Entidad geocoding + resultados: lat/lng, nombre, partes de direccion |
| `route_entity.dart` | Entidad Ruta: id, nombre, color, polilinea, paradas, cooperativa |
| `stop_entity.dart` | Entidad Parada: id, nombre, lat/lng, orden, distancia a lo largo de ruta |
| `user_entity.dart` | Entidad Usuario publico: id, nombre, rol, isPremium |

### `shared/domain/enums/`

| Archivo | Que hace |
|---|---|
| `trip_status.dart` | Enum `TripStatus`: scheduled, active, completed, cancelled |

### `shared/domain/repositories/`

| Archivo | Que hace |
|---|---|
| `directions_repository.dart` | Interfaz abstracta `getDirections` |
| `geocoding_repository.dart` | Interfaz abstracta `search` + `reverseGeocode` |

### `shared/presentation/pages/`

| Archivo | Que hace |
|---|---|
| `unified_profile_page.dart` | Pagina de perfil unificada: config, logout, links de ayuda, segun rol |
| `help_page.dart` | Pagina de ayuda (version corta/legacy) |
| `help/help_page.dart` | Pagina de ayuda (version completa, 155 lineas) |
| `privacy_agreement_page.dart` | Politica de privacidad (version corta/legacy) |
| `help/privacy_agreement_page.dart` | Politica de privacidad (version completa, 146 lineas) |

### `shared/presentation/providers/`

| Archivo | Que hace |
|---|---|
| `location_provider.dart` | Provider Riverpod de `LocationServiceImpl` |

### `shared/presentation/widgets/`

| Archivo | Que hace |
|---|---|
| `bus_marker_animator.dart` | Animacion de movimiento de marcador de bus en el mapa (109 lineas) |
| `live_map_widget.dart` | Widget de mapa en vivo con buses, paradas y usuario (189 lineas) |
| `role_scaffold.dart` | Scaffold generico con NavigationBar segun rol |
| `map/marker_manager.dart` | Cache y gestion de marcadores |
| `map/polyline_cache.dart` | Cache de polilineas para performance |

---

## `lib/features/auth/` - Autenticacion

### `auth/data/`

| Archivo | Que hace |
|---|---|
| `datasources/auth_remote_datasource.dart` | Operaciones Supabase Auth: signIn, signUp, signOut, escuchar cambios de estado |
| `models/auth_user_model.dart` | Serializacion `AppUserModel` <-> Supabase |
| `repositories/auth_repository_impl.dart` | Implementacion real de auth con Supabase (121 lineas) |
| `repositories/mock_auth_repository.dart` | Auth mock para dev: cualquier email + password `12345678` |

### `auth/domain/`

| Archivo | Que hace |
|---|---|
| `entities/auth_user.dart` | Entidad `AppUser`: id, email, nombre, rol, isPremium, deviceId |
| `enums/auth_event_type.dart` | Enum `AuthEventType`: signedIn, signedOut, tokenRefreshed, passwordRecovery |
| `repositories/auth_repository.dart` | Interfaz abstracta: signIn, signUp, signOut, getCurrentUser, refreshSession, etc. |
| `usecases/login_usecase.dart` | Valida credenciales + llama signIn |
| `usecases/logout_usecase.dart` | Ejecuta signOut |
| `usecases/recover_password_usecase.dart` | Valida email + envia recovery |
| `usecases/refresh_session.dart` | Refresh manual de token |
| `usecases/register_usecase.dart` | Valida campos + llama signUp con rol |

### `auth/presentation/`

| Archivo | Que hace |
|---|---|
| `pages/login_page.dart` | Formulario de login con validacion (303 lineas) |
| `pages/register_page.dart` | Formulario completo de registro con seleccion de rol (252 lineas) |
| `pages/permissions_request_page.dart` | Flujo de permisos GPS + notificaciones post-login (237 lineas) |
| `pages/recover_password_page.dart` | Input de email para reset de contrasena |
| `providers/auth_provider.dart` | `AuthNotifier`: gestion de estado auth (login, register, logout, refresh) (260 lineas) |

---

## `lib/features/usuario/` - Pasajero

### `usuario/data/datasources/`

| Archivo | Que hace |
|---|---|
| `beacon_local_datasource.dart` | Escaneo BLE de beacons para paradas cercanas (simulacion) |
| `bus_tracking_remote_datasource.dart` | Streams de Supabase Realtime para posiciones de buses en vivo |
| `directions_remote_datasource.dart` | Obtencion de direcciones desde ORS API |
| `eta_remote_datasource.dart` | RPC de Supabase para datos de ETA bus/parada (133 lineas) |
| `geocoding_remote_datasource.dart` | Wrapper de busqueda/reversa Nominatim |

### `usuario/data/repositories/`

| Archivo | Que hace |
|---|---|
| `bus_tracking_repository_impl.dart` | Posicion de buses en tiempo real via Supabase Realtime |
| `directions_repository_impl.dart` | Direcciones desde ORS |
| `eta_repository_impl.dart` | Calculo de ETA con EtaCalculator (134 lineas) |
| `favorites_repository_impl.dart` | Favoritos mock para demo |
| `geocoding_repository_impl.dart` | Geocoding con Nominatim |
| `tickets_repository_impl.dart` | Tickets mock para demo |
| `trip_history_repository_impl.dart` | Historial mock para demo |

### `usuario/domain/`

| Archivo | Que hace |
|---|---|
| `entities/favorite_entity.dart` | Entidad Favorito: rutas/paradas guardadas (enum `FavoriteType`) |
| `repositories/bus_tracking_repository.dart` | Interfaz: watchBusPosition, watchMultipleBuses, getAllStops |
| `repositories/eta_repository.dart` | Interfaz: calculateEta, getRoute, getStop, watchBusPosition |
| `repositories/favorites_repository.dart` | Interfaz: getFavorites |
| `repositories/tickets_repository.dart` | Interfaz: getTickets |
| `repositories/trip_history_repository.dart` | Interfaz: getTripHistory |
| `usecases/calculate_eta_usecase.dart` | Combina repos de tracking + ETA |
| `usecases/detect_nearby_stop_usecase.dart` | Encuentra la parada mas cercana usando EtaCalculator |
| `usecases/get_directions_usecase.dart` | Valida coordenadas + obtiene direcciones |
| `usecases/get_favorites_usecase.dart` | Obtiene favoritos del usuario |
| `usecases/get_tickets_usecase.dart` | Obtiene tickets del usuario |
| `usecases/get_user_trip_history_usecase.dart` | Obtiene historial de viajes |
| `usecases/reverse_geocode_usecase.dart` | lat/lng a nombre de lugar |
| `usecases/search_places_usecase.dart` | Busqueda de lugares por texto |
| `usecases/upgrade_to_premium_usecase.dart` | Flujo de upgrade a premium via pasarela de pago |
| `usecases/watch_bus_position_usecase.dart` | Stream de posicion de bus en tiempo real |

### `usuario/presentation/pages/`

| Archivo | Que hace |
|---|---|
| `u_scaffold.dart` | Scaffold del pasajero con tabs: Mapa, Rutas, Tickets, Alertas, Perfil |
| `map_page.dart` | Pagina principal del mapa en vivo con tracking de buses (155 lineas) |
| `routes_page.dart` | Explorar rutas con mapa + ETA (287 lineas) |
| `tickets_page.dart` | Display de tickets digitales |
| `alerts_page.dart` | Alertas del sistema para el pasajero |
| `favorites_page.dart` | Rutas/paradas favoritas con ETA |
| `premium_upgrade_page.dart` | Planes de suscripcion premium |
| `profile_page.dart` | Perfil del usuario + toggle de notificaciones |
| `trip_history_page.dart` | Lista de viajes anteriores |

### `usuario/presentation/providers/`

| Archivo | Que hace |
|---|---|
| `directions_provider.dart` | Providers de OrsService, repository, use case |
| `eta_provider.dart` | Providers de repository, ruta seleccionada, calculo ETA |
| `favorites_provider.dart` | Providers de repository, use case, FutureProvider de favoritos |
| `geocoding_provider.dart` | Providers de Nominatim, repository, busqueda/reversa |
| `live_map_provider.dart` | Providers de tracking repository, watch de posicion |
| `premium_provider.dart` | `PremiumNotifier`: estado de upgrade premium |
| `tickets_provider.dart` | Providers de repository, use case, FutureProvider de tickets |
| `trip_history_provider.dart` | Providers de repository, use case, FutureProvider de historial |

---

## `lib/features/conductor/` - Conductor/Chofer

### `conductor/data/datasources/`

| Archivo | Que hace |
|---|---|
| `ir_passenger_counter_datasource.dart` | Sensor IR/ToF para conteo de pasajeros via Supabase (61 lineas) |
| `obd_telemetry_datasource.dart` | Telemetria OBD del bus via Supabase (137 lineas) |
| `stops_remote_datasource.dart` | CRUD de solicitudes de parada via Supabase |
| `trip_remote_datasource.dart` | CRUD de viajes, insercion de telemetria via Supabase (90 lineas) |

### `conductor/data/repositories/`

| Archivo | Que hace |
|---|---|
| `stops_repository_impl.dart` | Solicitud de parada + obtencion de paradas de ruta |
| `trip_repository_impl.dart` | Inicio/fin de viaje, telemetria, historial (171 lineas) |

### `conductor/domain/`

| Archivo | Que hace |
|---|---|
| `entities/trip_entity.dart` | Entidad Viaje: id, bus, ruta, conductor, estado, timestamps, GPS, velocidad, ocupacion (92 lineas) |
| `repositories/stops_repository.dart` | Interfaz: requestNewStop |
| `repositories/trip_repository.dart` | Interfaz: startTrip, endTrip, publishTelemetry, watchTrip, getHistory |
| `usecases/end_trip_usecase.dart` | Finaliza viaje activo |
| `usecases/publish_telemetry_usecase.dart` | Valida + publica GPS/velocidad (42 lineas) |
| `usecases/request_new_stop_usecase.dart` | Valida coordenadas + solicita parada (35 lineas) |
| `usecases/start_trip_usecase.dart` | Inicia nuevo viaje con bus/ruta/conductor |

### `conductor/presentation/pages/`

| Archivo | Que hace |
|---|---|
| `c_scaffold.dart` | Scaffold del conductor con tabs: Dashboard, Viaje Activo, Paradas, Chat, Perfil |
| `driver_dashboard_page.dart` | Vista principal del conductor: iniciar/finalizar viaje (101 lineas) |
| `active_trip_page.dart` | Mapa en vivo del viaje activo con posicion del bus + paradas (218 lineas) |
| `occupancy_page.dart` | Display en vivo de conteo de pasajeros |
| `bus_status_page.dart` | Estado de telemetria actual del bus |
| `stop_request_page.dart` | Solicitar nueva parada con mapa (87 lineas) |
| `conductor_alerts_page.dart` | Alertas para el conductor |
| `incident_report_page.dart` | Reportar incidentes con pin en mapa (160 lineas) |
| `trip_history_page.dart` | Viajes anteriores del conductor |

### `conductor/presentation/providers/`

| Archivo | Que hace |
|---|---|
| `trip_provider.dart` | `TripNotifier`: estado de viaje activo, inicio/fin/telemetria/solicitudes (85 lineas) |

---

## `lib/features/cooperativa/` - Cooperativa

### `cooperativa/data/`

| Archivo | Que hace |
|---|---|
| `datasources/fleet_remote_datasource.dart` | CRUD completo Supabase: drivers, buses, rutas, paradas, salud (253 lineas) |
| `repositories/fleet_repository_impl.dart` | Gestion de flota via Supabase (242 lineas) |
| `repositories/coop_trip_history_repository_impl.dart` | Historial de viajes mock |

### `cooperativa/domain/`

| Archivo | Que hace |
|---|---|
| `entities/driver_entity.dart` | Entidad Conductor: id, nombre, email, licencia, bus asignado, activo |
| `entities/fleet_health.dart` | Salud de flota: total buses, activos, inactivos, alertas, ocupacion promedio |
| `entities/route_performance.dart` | Rendimiento de ruta: viajes, ocupacion, velocidad, pasajeros |
| `repositories/fleet_repository.dart` | Interfaz: CRUD de drivers/buses/rutas/paradas, salud, rendimiento, asignar driver |
| `repositories/coop_trip_history_repository.dart` | Interfaz: getTripHistory |
| `usecases/assign_driver_usecase.dart` | Valida + asigna conductor a bus |
| `usecases/get_fleet_health_usecase.dart` | Obtiene metricas de salud de flota |
| `usecases/get_route_performance_usecase.dart` | Obtiene reportes de rendimiento de ruta |
| `usecases/get_coop_trip_history_usecase.dart` | Obtiene historial de viajes de la cooperativa |

### `cooperativa/presentation/pages/`

| Archivo | Que hace |
|---|---|
| `coop_scaffold.dart` | Scaffold de cooperativa con tabs: Dashboard, Conductores, Paradas, Solicitudes, Reportes, Chat, Perfil |
| `fleet_dashboard_page.dart` | Dashboard de flota con metricas |
| `buses_management_page.dart` | CRUD de buses |
| `coop_drivers_page.dart` | Gestion de conductores con Supabase |
| `routes_management_page.dart` | CRUD de rutas con edicion de polilinea (174 lineas) |
| `coop_stops_page.dart` | Gestion de paradas con mapa (228 lineas) |
| `coop_stop_requests_page.dart` | Aprobar/rechazar solicitudes de parada |
| `coop_analytics_page.dart` | Analiticas de rendimiento de rutas |
| `reports_page.dart` | Reportes de rendimiento + historial de viajes |
| `coop_alerts_page.dart` | Alertas para la cooperativa |
| `coop_trip_history_page.dart` | Historial completo de viajes de la cooperativa |

### `cooperativa/presentation/providers/`

| Archivo | Que hace |
|---|---|
| `fleet_provider.dart` | Providers de driver/bus/ruta/parada/salud/rendimiento (87 lineas) |
| `coop_trip_history_provider.dart` | Providers de historial de viajes |

---

## `lib/features/admin_municipal/` - Administrador Municipal

### `admin_municipal/data/`

| Archivo | Que hace |
|---|---|
| `datasources/network_monitor_remote_datasource.dart` | Queries Supabase: overview, cooperativas, alertas, usuarios (241 lineas) |
| `repositories/network_monitor_repository_impl.dart` | Monitoreo municipal (157 lineas) |

### `admin_municipal/domain/`

| Archivo | Que hace |
|---|---|
| `entities/municipal_overview.dart` | Metricas a nivel ciudad: cooperativas, buses, pasajeros, salud |
| `entities/cooperativa_status.dart` | Estado de cooperativa: RUC, buses, conductores, ocupacion, alertas, viajes |
| `entities/system_alert.dart` | Alerta del sistema: alcance, severidad, titulo, descripcion, coordenadas, timestamps (58 lineas) |
| `repositories/network_monitor_repository.dart` | Interfaz: overview, cooperativas, alertas, usuarios, reportes |
| `usecases/get_all_cooperativas_status_usecase.dart` | Obtiene estado de todas las cooperativas |
| `usecases/get_system_alerts_usecase.dart` | Obtiene alertas del sistema |
| `usecases/generate_public_report_usecase.dart` | Genera reporte publico |

### `admin_municipal/presentation/pages/`

| Archivo | Que hace |
|---|---|
| `admin_scaffold.dart` | Scaffold de admin municipal con tabs: Overview, Usuarios, Incidentes, Chat, Perfil |
| `admin_overview_page.dart` | Dashboard municipal completo con mapa (293 lineas) |
| `user_management_page.dart` | Gestion de usuarios: 4 categorias (Usuarios/Conductores/Coop Admin/Municipal) (122 lineas) |
| `incidents_page.dart` | CRUD de alertas del sistema con mapa (186 lineas) |
| `cooperativas_crud_page.dart` | CRUD de cooperativas (156 lineas) |
| `premium_management_page.dart` | Gestion de suscripciones premium (165 lineas) |
| `municipal_config_page.dart` | Configuracion del sistema: geocerca, telemetria, retencion, etc. |
| `municipal_notifications_page.dart` | Configuracion de notificaciones |
| `municipal_reports_page.dart` | Display de reportes publicos |

### `admin_municipal/presentation/providers/`

| Archivo | Que hace |
|---|---|
| `system_alerts_provider.dart` | Providers de overview, alertas, cooperativas, usuarios, reportes (81 lineas) |

---

## `lib/features/chat/` - Chat en Vivo

### `chat/data/`

| Archivo | Que hace |
|---|---|
| `datasources/chat_remote_datasource.dart` | Chat via Supabase Realtime: mensajes, conversaciones |
| `repositories/chat_repository_impl.dart` | Chat con suscripciones Realtime (116 lineas) |

### `chat/domain/`

| Archivo | Que hace |
|---|---|
| `entities/chat_conversation.dart` | Entidad Conversacion: id, driver, coop, ultimo mensaje, no leidos, online (72 lineas) |
| `entities/chat_message.dart` | Entidad Mensaje: id, roomId, senderId, contenido, timestamp, leido (48 lineas) |
| `repositories/chat_repository.dart` | Interfaz: getMessages, watchMessages, sendMessage, listConversations |
| `usecases/list_conversations_usecase.dart` | Lista conversaciones |
| `usecases/send_message_usecase.dart` | Envia mensaje |
| `usecases/watch_conversation_usecase.dart` | Escucha mensajes en tiempo real |

### `chat/presentation/`

| Archivo | Que hace |
|---|---|
| `pages/chat_page.dart` | UI de chat en tiempo real (37 lineas) |
| `providers/chat_provider.dart` | Providers de conversaciones/mensajes (58 lineas) |

---

## `lib/esp32-firmware/` - Firmware ESP32

| Archivo | Que hace |
|---|---|
| `platformio.ini` | Configuracion PlatformIO: target ESP32-C3 |
| `src/main.cpp` | Entry point del firmware |
| `src/config.h` | Configuracion de hardware: WiFi, MQTT, pines |
| `src/ble_scanner.cpp/.h` | Implementacion de escaneo BLE |
| `conexion_iot.md` | Documentacion de conexion IoT |

---

## Flujo de Datos

```
ESP32 (MQTT) --> Edge Function --> Supabase DB --> Flutter App (Realtime)
                                                     |
Flutter App --> Supabase Auth --> Supabase DB <-- Flutter App
                                                     |
Flutter App --> ORS API (rutas/direcciones)
Flutter App --> Nominatim (geocoding)
```

## Roles y Permisos

| Rol | Que puede hacer |
|---|---|
| **usuario** | Ver mapa en vivo, buscar rutas, gestionar tickets/favoritos, ver alertas, upgrade premium |
| **conductor** | Iniciar/finalizar viajes, publicar telemetria GPS, solicitar paradas, reportar incidentes, ver ocupacion |
| **cooperativaAdmin** | Gestionar flota (buses/conductores/rutas/paradas), ver analiticas, aprobar solicitudes, chat |
| **municipalAdmin** | Supervisar toda la red, gestionar cooperativas/usuarios/premium, crear alertas del sistema, ver reportes |

## Dependencias Principales

| Paquete | Para que |
|---|---|
| `flutter_riverpod` | State management reactivo |
| `go_router` | Navegacion declarativa por roles |
| `get_it` | Service locator / DI |
| `supabase_flutter` | Backend: auth, DB, realtime, storage |
| `flutter_map` + `latlong2` | Mapas OpenStreetMap |
| `mqtt_client` | Comunicacion IoT con ESP32 |
| `dartz` | Programacion funcional: `Either<Failure, T>` |
| `geolocator` | GPS / geolocalizacion |
| `permission_handler` | Permisos de dispositivo |
| `flutter_secure_storage` | Almacenamiento seguro |
| `freezed_annotation` + `json_annotation` | Code generation para modelos |
