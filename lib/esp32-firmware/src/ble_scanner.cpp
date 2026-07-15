#include "ble_scanner.h"
#include <NimBLEDevice.h>

static NimBLEScan* pBLEScan;
static bool detectedFlag = false;
static String detectedPlate = "";
static int detectedRssi = 0;

class MyAdvertisedDeviceCallbacks: public NimBLEAdvertisedDeviceCallbacks {
  void onResult(NimBLEAdvertisedDevice* advertisedDevice) override {
    if (!advertisedDevice->haveName()) return;

    std::string name = advertisedDevice->getName();
    int rssi = advertisedDevice->getRSSI();

    if (name.find(BUS_BEACON_PREFIX) == 0 && rssi > RSSI_THRESHOLD) {
      detectedFlag = true;
      detectedPlate = String(name.c_str()).substring(strlen(BUS_BEACON_PREFIX));
      detectedRssi = rssi;
    }
  }
};

static MyAdvertisedDeviceCallbacks* pCallbacks = nullptr;

void bleScannerInit() {
  NimBLEDevice::init("PARADA_ESP32C3");
  pBLEScan = NimBLEDevice::getScan();
  pCallbacks = new MyAdvertisedDeviceCallbacks();
  pBLEScan->setAdvertisedDeviceCallbacks(pCallbacks);
  pBLEScan->setActiveScan(true);
  pBLEScan->setInterval(100);
  pBLEScan->setWindow(99);
}

void bleScannerLoop() {
  detectedFlag = false;
  pBLEScan->start(2, false);
  pBLEScan->clearResults();
}

bool bleBusDetected() { return detectedFlag; }
String bleDetectedPlate() { return detectedPlate; }
int bleDetectedRssi() { return detectedRssi; }
