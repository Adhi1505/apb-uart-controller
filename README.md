# APB-Based UART Controller (Verilog)

This repository contains an APB-compliant UART controller implemented in Verilog as part of an academic and industry-oriented RTL design project.

## Overview
The design integrates a UART peripheral into an SoC environment using the AMBA APB protocol. It supports serial transmission, reception, configurable baud rate, and interrupt signaling.

## Features
- AMBA APB compliant slave interface
- UART transmitter and receiver
- Configurable baud rate generator
- Register-mapped control and status
- Loopback verification support

## Verification
- Verified using a loopback-based testbench
- Waveform-based debugging using ModelSim
- Protocol timing validated through simulation

- ## Synthesis
- The RTL design was synthesized using Intel Quartus Prime to verify hardware feasibility.
- Synthesis outputs were reviewed to ensure the design is free of latches and is fully synthesizable.
- No board-level deployment or timing optimization was performed.


## Tools Used
- Verilog HDL
- ModelSim
- Icarus Verilog
- GTKWave

## Author
Adhithyan Pillai
