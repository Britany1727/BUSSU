#ifndef BLE_SCANNER_H
#define BLE_SCANNER_H

#include <Arduino.h>
#include "config.h"

void bleScannerInit();
void bleScannerLoop();

bool bleBusDetected();
String bleDetectedPlate();
int bleDetectedRssi();

#endif
