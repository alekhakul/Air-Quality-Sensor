#ifndef LCD_H
#define LCD_H

#include <Arduino.h>

void lcd_init();
void lcd_sendCommand(uint8_t command);
void lcd_sendData(uint8_t data);
void lcd_print(const char* str);
void lcd_setCursor(uint8_t col, uint8_t row);
void lcd_clear();

#endif