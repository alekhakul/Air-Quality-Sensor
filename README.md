Embedded Air Quality Monitor & FPGA Controller
This project is a comprehensive exploration of embedded systems and digital logic design, centered around building a practical air quality sensor for a woodworking environment. The system is designed to monitor airborne particulates (PM2.5), Volatile Organic Compounds (VOCs), temperature, and humidity.

The project is divided into two major implementations:

A complete, functional system built with a microcontroller and standard C++ libraries.

An ongoing hardware-level implementation using an FPGA and the Verilog HDL, designed to replace the software libraries with custom digital logic.

This repository serves as a portfolio piece for my work as an Electrical and Computer Engineering student at UT Austin,
demonstrating my progress learning Verilog and FPGA implementation
following my freshman year of college.

Part 1: Microcontroller Implementation
This directory contains a fully functional air quality monitor built using an ESP8266-based microcontroller.
The air quality monitor was first successfully implemented using pre-made libraries as a starting
point. The microcontroller code and hardware drivers were then remade without the use of libraries to later 
be converted to a Verilog implementation.

Features
Reads and processes data from a Sensirion SEN55 I²C sensor.

Displays Temperature, Humidity, PM2.5, and VOC Index on a 16x2 character LCD.

Includes a custom, library-free C++ driver for the HD44780 LCD to demonstrate direct, low-level hardware control.

Hardware Components
Processor: Adafruit Feather HUZZAH (ESP8266)

Sensor: Sensirion SEN55 (Particle, VOC, Humidity, Temperature)

Display: Standard 16x2 Character LCD (HD44780)

Tools Used
IDE: Visual Studio Code with PlatformIO

Schematic Design: KiCad

Language: C++ (Arduino Framework)

Part 2: FPGA Implementation (In Progress)
This directory contains the Verilog source code and simulation files for a hardware-level implementation of the system's peripheral controllers on an FPGA. The goal is to replace the pre-built software libraries from the microcontroller version with custom, from-scratch digital logic.

Current Progress: LCD Controller Complete
A complete Verilog controller for the HD44780 LCD has been designed and fully verified.

The controller is implemented as a finite state machine (FSM) that handles the precise timing for the 4-bit interface, including the magic initialization sequence specified in the datasheet and standard write cycles.

Functional verification was performed using a Verilog testbench, with waveform analysis conducted in GTKWave to confirm timing requirements were met.

Hardware & Tools
FPGA Board: iCEBreaker v1.1a (Lattice iCE40)

HDL: Verilog

Toolchain: Open-source (Yosys for synthesis, nextpnr for place-and-route, iverilog for simulation, GTKWave for analysis)

Next Steps
Synthesize LCD Controller: Program the verified Verilog module onto the physical iCEBreaker FPGA and display text on the connected LCD.

Design I²C Controller: Design and simulate a new Verilog FSM to act as an I²C master, capable of communicating with the SEN55 sensor.

System Integration: Create a top-level Verilog module to integrate the I²C and LCD controllers, replicating the full functionality of the original microcontroller system entirely in hardware.
