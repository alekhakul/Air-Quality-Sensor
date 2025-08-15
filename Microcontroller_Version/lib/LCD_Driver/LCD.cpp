#include "LCD.h"

// Define pins
const int RS_PIN = 12;
const int E_PIN = 13;
const int D4_PIN = 14;
const int D5_PIN = 2;
const int D6_PIN = 0;
const int D7_PIN = 15;

namespace {
  void pulseEnable() {
    digitalWrite(E_PIN, LOW);
    delayMicroseconds(1);
    digitalWrite(E_PIN, HIGH);
    delayMicroseconds(1);
    digitalWrite(E_PIN, LOW);
    delayMicroseconds(100);
  }

  void write4(uint8_t value) {
    digitalWrite(D4_PIN, (value >> 0) & 0x01);
    digitalWrite(D5_PIN, (value >> 1) & 0x01);
    digitalWrite(D6_PIN, (value >> 2) & 0x01);
    digitalWrite(D7_PIN, (value >> 3) & 0x01);
    pulseEnable();
  }
}

// Public Functions

void lcd_sendCommand(uint8_t command) {
  digitalWrite(RS_PIN, LOW);
  write4(command >> 4);
  write4(command & 0x0F);
}

void lcd_sendData(uint8_t data) {
  digitalWrite(RS_PIN, HIGH); // Set to data mode
  write4(data >> 4);
  write4(data & 0x0F);
}

void lcd_init() {
  pinMode(RS_PIN, OUTPUT);
  pinMode(E_PIN, OUTPUT);
  pinMode(D4_PIN, OUTPUT);
  pinMode(D5_PIN, OUTPUT);
  pinMode(D6_PIN, OUTPUT);
  pinMode(D7_PIN, OUTPUT);
  delay(50);
  digitalWrite(RS_PIN, LOW);
  write4(0x03);
  delay(5);
  write4(0x03);
  delay(5);
  write4(0x03);
  delay(1);
  write4(0x02);
  lcd_sendCommand(0b00101000); // Function Set: 2 lines, 5x8 font
  lcd_sendCommand(0b00001100); // Display On/Off: Display on, cursor off
  lcd_clear();
  lcd_sendCommand(0b00000110); // Entry Mode Set
}

void lcd_clear() {
  lcd_sendCommand(0b00000001);
  delay(2);
}

void lcd_setCursor(uint8_t col, uint8_t row) {
  const uint8_t row_offsets[] = {0x00, 0x40};
  lcd_sendCommand(0x80 | (col + row_offsets[row]));
}

void lcd_print(const char* str) {
  while (*str) {
    lcd_sendData(*str++);
  }
}