# Conexion IoT - Parada Inteligente BUSSU

## Componentes necesarios

| Componente | Funcion | Precio aprox. (USD) |
|---|---|---|
| ESP32-C3 DevKit | Microcontrolador principal (BLE + WiFi) | $4-6 |
| HC-SR04 | Sensor ultrasonico (detecta presencia del bus) | $1-2 |
| Power bank 5V | Fuente de alimentacion portatil | $5-10 |
| Cables jumper | Conexiones | $1 |
| Resistencia 1kΩ + 2kΩ | Divisor de voltaje (ECHO 5V→3.3V) | $0.10 |
| Protoboard (opcional) | Para montaje temporal | $2 |

**Total: ~$12-20 USD por parada**

---

## NOTA: Arduino NO es necesario

El ESP32-C3 ya es un microcontrolador completo. No necesitas un Arduino.
El ESP32-C3 reemplaza al Arduino porque tiene:
- WiFi integrado
- BLE integrado
- Suficientes pines GPIO
- Mayor velocidad (240 MHz vs 16 MHz)

Si ya tienes un Arduino y quieres usarlo como "puente" para el power bank,
no funciona asi. El ESP32-C3 se alimenta directamente del power bank.

---

## Esquema de conexion

```
                    ┌─────────────────────────┐
                    │      POWER BANK         │
                    │      (5V / 2A)          │
                    │                         │
                    │   USB ──────────────┐   │
                    └─────────────────────│───┘
                                          │
                                          │ (cable USB a micro-USB)
                                          │
                    ┌─────────────────────▼───────────────────────┐
                    │                ESP32-C3 DevKit               │
                    │                                             │
                    │  VIN/5V ◄────────── USB (5V desde PB)       │
                    │  GND    ──────────► GND comun               │
                    │                                             │
                    │  GPIO 5  ──────────► TRIG (HC-SR04)         │
                    │  GPIO 6  ◄──[DIV]── ECHO (HC-SR04)         │
                    │                                             │
                    │  (BLE scan activo, busca beacons "BUS_*")   │
                    │  (WiFi conectado a internet)                │
                    └─────────────────────────────────────────────┘
                                          │
                                          │ HTTP POST a Supabase
                                          │ "report_stop_arrival"
                                          ▼
                    ┌─────────────────────────────────────────────┐
                    │              HC-SR04                        │
                    │                                             │
                    │  VCC  ◄── 5V (del ESP32-C3 o power bank)    │
                    │  GND  ──► GND comun                        │
                    │  TRIG ◄── GPIO 5 del ESP32-C3              │
                    │  ECHO ──► [DIVISOR DE VOLTAJE] → GPIO 6    │
                    └─────────────────────────────────────────────┘
```

---

## Divisor de voltaje (ECHO 5V → 3.3V)

El HC-SR04 outputa 5V en el pin ECHO. El ESP32-C3工作a a 3.3V.
Sin divisor de voltaje, danas el ESP32-C3 a largo plazo.

```
ECHO (5V) ────┬─── 1kΩ ────┬──── GPIO 6 (3.3V)
              │             │
              └─── 2kΩ ────┘
                          │
                         GND

Calculo: Vout = 5V × (2kΩ / (1kΩ + 2kΩ)) = 3.33V  ✓
```

**Alternativa mas simple:** Usa un modulo HC-SR04 que ya traiga el conversor
a 3.3V integrado (busca "HC-SR04 3.3V compatible" en MercadoLibre/AliExpress).

---

## Funcionamiento del power bank

### Si funciona? SI

Un power bank tipico de 10,000 mAh a 5V/2A alimenta el ESP32-C3 sin problema.

**Consumo estimado del ESP32-C3:**

| Modo | Consumo | Tiempo con PB 10,000mAh |
|---|---|---|
| WiFi activo + BLE scan | ~180 mA | ~55 horas |
| WiFi activo + BLE idle | ~120 mA | ~83 horas |
| Deep sleep (ahorro) | ~10 mA | ~1,000 horas |

**En la practica:** Un power bank de 10,000 mAh dura **2-3 dias** funcionando
24/7 con WiFi + BLE activo. Para una parada permanente, conectalo a corriente
directa (adaptador USB de pared).

### Detalles importantes

1. **Power bank con "auto-off"**: Algunos se apagan si el consumo es muy bajo.
   El ESP32-C3 consume suficiente (~180mA) para que no se apague.
   Si se apaga, pon un LED parpadeando en un pin GPIO para simular carga.

2. **Temperatura**: El power bank no debe estar expuesto al sol directo.
   Usa una caja estanca IP65 con ventilacion.

3. **Carga**: Cuando el power bank se agote, hay que recargarlo.
   Para paradas fijas, usa alimentacion por USB de pared (5V/2A).

---

## Montaje fisico sugerido

```
┌─────────────────────────────────┐
│  CAJA ESTANCA IP65 (20x15x10cm)│
│                                 │
│  ┌───────────┐  ┌────────────┐  │
│  │  ESP32-C3  │  │ Power Bank │  │
│  │  DevKit   │  │  10,000mAh │  │
│  │           │  │            │  │
│  └─────┬─────┘  └─────┬──────┘  │
│        │              │         │
│  ┌─────▼──────────────▼──────┐  │
│  │      Protoboard           │  │
│  │  (divisor voltaje +       │  │
│  │   conexiones)             │  │
│  └───────────┬───────────────┘  │
│              │                  │
│  ┌───────────▼───────────────┐  │
│  │       HC-SR04             │  │
│  │  (pegado al borde de la   │  │
│  │   caja, apuntando a la    │  │
│  │   via del bus)            │  │
│  └───────────────────────────┘  │
│                                 │
│  [LED indicador] [ boton reset]│
└─────────────────────────────────┘
         │
         ▼
    Montado en el poste
    de la parada del bus
    a 30-50cm del suelo
    apuntando horizontal
```

---

## Pasos para armar una parada

### 1. Programar el ESP32-C3
```bash
# Cambiar credenciales en config.h
#define WIFI_SSID       "TU_WIFI"
#define WIFI_PASSWORD   "TU_CLAVE"
#define SUPABASE_URL    "https://tu-proyecto.supabase.co"
#define SUPABASE_ANON_KEY "tu-anon-key"
#define STOP_ID         "stop_parada_central"
```

### 2. Subir el codigo con PlatformIO
```bash
cd lib/esp32-firmware
pio run -t upload
```

### 3. Conectar el hardware
- ESP32-C3 ←USB→ Power Bank
- ESP32-C3 GPIO5 → HC-SR04 TRIG
- ESP32-C3 GPIO6 ← [divisor] ← HC-SR04 ECHO
- HC-SR04 VCC → 5V
- HC-SR04 GND → GND

### 4. Montar en la parada
- Fijar la caja al poste con bridas o cinta adhesiva fuerte
- El HC-SR04 debe apuntar hacia la via del bus
- Altura recomendada: 30-50cm del suelo

### 5. Verificar
- Abrir Monitor Serial a 115200 baudios
- Ver "Parada IoT lista. STOP_ID: stop_parada_central"
- Acercar el celular con una app BLE (nRF Connect) y verificar que detecta

---

## Diagrama de bloques del sistema completo

```
┌──────────────┐    BLE beacon     ┌──────────────┐    HTTP POST    ┌──────────┐
│  BUS         │  "BUS_ABC1234"   │  ESP32-C3 en │ ──────────────► │ SUPABASE │
│  (conductor) │ ───────────────► │  la PARADA   │                 │   RPC    │
│              │                  │              │                 │          │
│  App Flutter │                  │  HC-SR04     │                 │ Realtime │
│  + BLE GPS   │                  │  (confirma)  │                 │          │
└──────────────┘                  └──────────────┘                 └────┬─────┘
                                                                      │
                                                           Supabase Realtime
                                                                      │
                                                                      ▼
                                                              ┌──────────────┐
                                                              │  APP USUARIO │
                                                              │              │
                                                              │ - Mi ubicacion│
                                                              │ - Bus cerca  │
                                                              │ - ETA: 5 min │
                                                              │ - Alertas    │
                                                              └──────────────┘
```

---

## Resumen

| Pregunta | Respuesta |
|---|---|
| Necesito Arduino? | NO, el ESP32-C3 lo reemplaza |
| Funciona con power bank? | SI, dura ~2-3 dias |
| Cuantos pines uso? | 2 pines GPIO (5 y 6) |
| Necesito divisor de voltaje? | SI, para el ECHO del HC-SR04 |
| Cuanto cuesta hardware? | ~$12-20 USD por parada |
| Donde se monta? | En el poste de la parada |
