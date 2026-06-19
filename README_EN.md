# SiI9134 HDMI TX FPGA Driver

**[简体中文](README.md) | English**

## Overview

This project provides an FPGA driver for the **SiI9134 HDMI transmitter**, verified on the **SEAL SA5Z-30-D1-8U213C** board.
It accepts an AXI4-Stream video interface, outputs parallel RGB to the SiI9134, and initializes the chip via I2C.

## Hardware Platform

- FPGA: SEAL SA5Z-30-D1-8U213C
- HDMI TX IC: Silicon Image SiI9134
- Input clock: 27 MHz oscillator
- Output resolution: 1920×1080 @ 60 Hz (1080p60)

## Features

- 27 MHz input clock generates 148.5 MHz pixel clock via PLL
- AXI4-Stream slave interface with `tuser` (start-of-frame) and `tlast` (end-of-line)
- 36-bit RGB data format (12-12-12), consistent with the reference design
- Built-in expanding-ring test pattern generator for board-level verification
- I2C init sequence: `{0x72,0x08,0x35}`, `{0x7A,0x2F,0x00}`
- Reference OpenCores I2C master controller merged into a single file

## Directory Structure

```
├── constraints/      # Timing and pin constraints
├── ip/               # PLL IP core
├── prj/              # HqFpga project scripts
├── rtl/              # Verilog RTL source
├── sim/              # ModelSim/QuestaSim simulation scripts
├── syn/               # Synthesis scripts
├── AGENTS.md         # Agent guidelines
└── README.md         # This file (Chinese)
```

## Quick Start

### 1. Simulation

Enter the `sim` directory and run QuestaSim/ModelSim:

```bash
cd sim
vsim -c -do run_sii9134_demo.do
```

Expected result: `Simulation PASSED.`

### 2. Synthesis and Implementation

Run the project script with HqFpga:

```bash
cd prj
hqfpga -cmd run_hqprj.tcl
```

Upon success, `sii9134_demo.bin` is generated.

### 3. Board Verification

Download `prj/sii9134_demo.bin` to the board and connect an HDMI monitor to see the 1080p60 expanding-ring pattern.

## Top-Level Interfaces

### `sii9134_demo` (ready for board download)

| Signal | Direction | Description |
|--------|-----------|-------------|
| `clk_27m` | Input | 27 MHz system clock |
| `rst_n` | Input | Active-low reset |
| `sii_pclk` | Output | 148.5 MHz pixel clock |
| `sii_hsync`/`sii_vsync` | Output | Horizontal/vertical sync |
| `sii_de` | Output | Data enable |
| `sii_data[35:0]` | Output | 36-bit RGB video data |
| `sii_scl`/`sii_sda` | Bidirectional | I2C bus (open-drain, external pull-ups required) |
| `i2c_busy`/`i2c_done`/`i2c_error` | Output | I2C init status |

### `sii9134_top` (AXI4-Stream user interface)

| Signal | Direction | Description |
|--------|-----------|-------------|
| `clk_27m`/`rst_n` | Input | System clock and reset |
| `s_axis_*` | Input/Output | AXI4-Stream slave video interface |
| `sii_*` | Output/Bidirectional | SiI9134 parallel video and I2C interface |
| `video_*` | Output | Video timing feedback for external AXI-Stream source sync |

## Notes

- `sii_scl` and `sii_sda` are open-drain; **external pull-up resistors are required**.
- The SiI9134 `RESET#` is controlled by board-level reset circuitry; this project does not drive it from the FPGA.
- Video resolution and timing are determined by the pixel clock and `video_timing_gen`; I2C only configures the data format and disables audio/HDCP.
- Simulation uses the behavioral PLL model `sim/pll_sii9134_sim.v`; synthesis uses `ip/pll_sii9134/pll_sii9134.v`.

## License

See the [LICENSE](LICENSE) file for details.
