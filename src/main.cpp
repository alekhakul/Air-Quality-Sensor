#include <Arduino.h>
#include <Wire.h>
#include <LiquidCrystal.h>
#include <SensirionI2CSen5x.h>
#include <LCD.h>


// // Initialize LCD with pin numbers
// LiquidCrystal lcd(12, 13, 14, 2, 0, 15);

// Sensor Object
SensirionI2CSen5x sen55;

// Data variables
float massConcentrationPm1p0, massConcentrationPm2p5;
float massConcentrationPm4p0, massConcentrationPm10p0;
float ambientHumidity, ambientTemperature;
float vocIndex, noxIndex;

// void setup() {
//     Serial.begin(9600);

//     Wire.begin();

//     // Initialize LCD
//     lcd.begin(16, 2);
//     lcd.print("Starting...");

//     // Initialize sensor
//     sen55.begin(Wire);

//     // Start measurement, check for errors
//     uint16_t error = sen55.startMeasurement();
//     if (error) {
//         Serial.print("Error starting measurement:");
//         char errorMessage[256];
//         errorToString(error, errorMessage, 256);
//         Serial.println(errorMessage);

//         lcd.clear();
//         lcd.print("Sensor Error");
//         while(true) {}
//     }

//     delay(3000);
// }

// void loop() {
//     // Wait to prepare data
//     delay(3000);

//     // Read measurement data, check for errors
//     uint16_t error = sen55.readMeasuredValues(
//         massConcentrationPm1p0, massConcentrationPm2p5,
//         massConcentrationPm4p0, massConcentrationPm10p0,
//         ambientHumidity, ambientTemperature, vocIndex, noxIndex);
//     // Check for errors
//     if (error) {
//         Serial.print("Error reading vals:");
//         char errorMessage[256];
//         errorToString(error, errorMessage, 256);
//         Serial.println(errorMessage);
//     } else {
//         // Display values
//         lcd.clear();

//         // Temperature
//         lcd.setCursor(0, 0);
//         lcd.print(ambientTemperature);
//         lcd.print((char)223);
//         lcd.print("C ");

//         // Humidity
//         lcd.setCursor(9, 0);
//         lcd.print(ambientHumidity,0);
//         lcd.print("% RH");

//         // Mass Concentration PM2.5
//         lcd.setCursor(0, 1);
//         lcd.print(massConcentrationPm2p5,0);

//         // VOC Index
//         lcd.setCursor(10, 1);
//         lcd.print("VOC:");
//         lcd.print(vocIndex, 0);
//     }
//     Serial.print("Loop\n");
//     Serial.print(ambientHumidity,0);
//     Serial.print("\n");
// }


// LCD Init Code
void setup() {
    Serial.begin(115200);
    Wire.begin();

    lcd_init();
    lcd_print("Starting Sensor...");
}

void loop() {
  // ... (read sensor data here) ...

  lcd_clear();
  lcd_setCursor(0, 0);
  lcd_print("Hello");
  
  lcd_setCursor(0, 1);
  lcd_print("PM2.5: ");


  delay(2000);
}