#include <Arduino.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include "config.h"
#include "ble_scanner.h"

#define LED_PIN 9

static String ultimaPlacaReportada = "";
static unsigned long ultimoReporteMs = 0;
static bool wifiOk = false;

void blink(int times, int ms) {
  for (int i = 0; i < times; i++) {
    digitalWrite(LED_PIN, LOW);
    delay(ms);
    digitalWrite(LED_PIN, HIGH);
    delay(ms);
  }
}

void reportarLlegada(String busPlate, int rssi) {
  if (WiFi.status() != WL_CONNECTED) {
    wifiOk = false;
    return;
  }
  HTTPClient http;
  String url = String(SUPABASE_URL) + "/rpc/report_stop_arrival";
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("apikey", SUPABASE_ANON_KEY);
  http.addHeader("Authorization", "Bearer " + String(SUPABASE_ANON_KEY));
  String json = "{\"stop_code_param\":\"" + String(STOP_CODE) +
                "\",\"bus_plate_param\":\"" + busPlate +
                "\",\"rssi_param\":" + String(rssi) + "}";
  http.POST(json);
  http.end();
}

void setup() {
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, HIGH);

  digitalWrite(LED_PIN, LOW);
  delay(1000);
  digitalWrite(LED_PIN, HIGH);
  delay(500);

  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  int intentos = 0;
  while (WiFi.status() != WL_CONNECTED && intentos < 40) {
    delay(500);
    intentos++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    wifiOk = true;
    blink(3, 200);
  } else {
    blink(5, 100);
  }

  bleScannerInit();
  blink(2, 200);

  digitalWrite(LED_PIN, LOW);
  delay(2000);
  digitalWrite(LED_PIN, HIGH);
}

void loop() {
  bleScannerLoop();

  if (bleBusDetected()) {
    String placa = bleDetectedPlate();
    int rssi = bleDetectedRssi();

    unsigned long ahora = millis();
    bool repetido =
        (placa == ultimaPlacaReportada) && (ahora - ultimoReporteMs < COOLDOWN_MS);

    if (!repetido) {
      for (int i = 0; i < 6; i++) {
        digitalWrite(LED_PIN, LOW); delay(50);
        digitalWrite(LED_PIN, HIGH); delay(50);
      }

      if (wifiOk) {
        reportarLlegada(placa, rssi);
        digitalWrite(LED_PIN, LOW); delay(1000); digitalWrite(LED_PIN, HIGH);
      }

      ultimaPlacaReportada = placa;
      ultimoReporteMs = ahora;
    }
  }

  static unsigned long lastBlink = 0;
  if (millis() - lastBlink > 5000) {
    lastBlink = millis();
    digitalWrite(LED_PIN, LOW); delay(50); digitalWrite(LED_PIN, HIGH);
  }

  delay(200);
}
