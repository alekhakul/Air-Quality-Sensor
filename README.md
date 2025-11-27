# Embedded Air Quality Monitor & FPGA Controller

## Project Overview
This project is a comprehensive exploration of embedded systems and digital logic design, centered around building a practical air quality sensor for a woodworking environment. The system monitors airborne particulates (PM2.5), Volatile Organic Compounds (VOCs), temperature, and humidity.

The project is divided into two major implementations:
1.  **Software Prototype:** A functional system built with a microcontroller and C++.
2.  **Hardware Implementation:** A custom digital logic implementation using an FPGA and Verilog HDL.

This repository demonstrates the learning transition from high-level software abstraction to low-level hardware description.

---

## Part 1: Microcontroller Implementation (Firmware)
*Directory: `/Microcontroller_Version`*

The air quality monitor was first prototyped using an ESP8266-based microcontroller. While initially built with standard libraries, the drivers were rewritten in C++ without external libraries to understand the low-level communication protocols before porting them to hardware.

### Features
* **Sensor Interface:** Reads and processes data from a Sensirion SEN55 (I²C) and Bosch BMV080.
* **Display:** Outputs Temperature, Humidity, PM2.5, and VOC Index to a 16x2 character LCD.
* **Custom Drivers:** Includes a custom, library-free C++ driver for the HD44780 LCD to demonstrate direct hardware control.

### Hardware
* **Processor:** Adafruit Feather HUZZAH (ESP8266)
* **Sensors:** Sensirion SEN55 / Bosch BMV080
* **Display:** Standard 16x2 Character LCD (HD44780)

---

## Part 2: FPGA Implementation (Verilog)
*Directory: `/FPGA_Version`*

This directory contains the Verilog source code and simulation files. The goal is to replace the microcontroller entirely with custom digital logic running on a Lattice iCE40 FPGA.

### Current Progress

#### 1. LCD Controller (HD44780)
* **Status:** Design & Simulation Complete
* Implemented a Finite State Machine (FSM) to handle the precise timing of the LCD's 4-bit interface.
* Handles the "Magic Initialization" sequence required by the datasheet.
* Verified via GTKWave analysis to ensure setup and hold times are met.

#### 2. I2C Master Controller
* **Status:** Design & Simulation Complete
* Designed a custom **I2C Master FSM** from scratch (no IP blocks).
* **Tristate Logic:** Implemented manual open-drain logic (`assign sda = enable ? 0 : 1'bz`) to handle bidirectional communication.
* **Clock Generation:** Created logic to oversample the I2C bus (400kHz FSM tick for 100kHz SCL) to ensure data stability during clock edges.
* **Verification:** Verified using a testbench that mimics a slave device acknowledging (ACK) the address and data bytes.

### Tools & Stack
* **FPGA Board:** iCEBreaker v1.1a (Lattice iCE40)
* **HDL:** Verilog
* **Simulation:** Icarus Verilog (iverilog) & GTKWave
* **Synthesis/PnR:** Yosys & nextpnr

---

## How to Run Simulations
To verify the logic using the open-source toolchain:

**1. Simulate the LCD Controller:**
```bash
iverilog -o lcd_sim lcd.v lcd_tb.v
vvp lcd_sim
gtkwave lcd_tb.vcd
```

**2. Simulate the I2C Master:**
```bash
iverilog -o i2c_sim i2c_master.v i2c_master_tb.v
vvp i2c_sim
gtkwave i2c_tb.vcd
```

## Roadmap & Next Steps
* **Hardware Synthesis:** Synthesize the verified LCD controller and program it onto the physical iCEBreaker board.
* **Sensor Integration:** Connect the physical SGP40/BMV080 sensors to the FPGA and verify I2C ACK on the logic analyzer.
* **System Top-Level:** Create a `top.v` module to bridge the I2C data (input) to the LCD display (output), converting the binary sensor values to ASCII for display.

---

## Author
**Alex Lekhakul**
*Electrical and Computer Engineering, UT Austin*
[LinkedIn](https://linkedin.com/in/alex-lekhakul/)
