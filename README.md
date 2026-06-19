# SiI9134 HDMI 发送 FPGA 驱动

**简体中文 | [English](README_EN.md)**

## 简介

本项目为 **SiI9134 HDMI 发送芯片** 的 FPGA 驱动，基于 **SEAL SA5Z-30-D1-8U213C** 开发板验证。
支持 AXI4-Stream 视频接口输入，输出并行 RGB 至 SiI9134，并通过 I2C 完成芯片初始化。

## 硬件平台

- FPGA：SEAL SA5Z-30-D1-8U213C
- HDMI 发送芯片：Silicon Image SiI9134
- 输入时钟：27 MHz 有源晶振
- 输出分辨率：1920×1080 @ 60 Hz（1080p60）

## 功能特性

- 27 MHz 输入时钟通过 PLL 生成 148.5 MHz 像素时钟
- AXI4-Stream 从机接口，支持 `tuser`（帧起始）和 `tlast`（行结束）
- 36-bit RGB 数据格式（12-12-12），与参考设计一致
- 内置彩条测试模式生成器，可直接上板验证
- I2C 初始化序列：`{0x72,0x08,0x35}`、`{0x7A,0x2F,0x00}`
- 参考 OpenCores I2C 主控制器，并融合为单一文件

## 目录结构

```
├── constraints/      # 时序与引脚约束
├── ip/               # PLL IP 核
├── prj/              # HqFpga 工程脚本
├── rtl/              # Verilog RTL 源码
├── sim/              # ModelSim/QuestaSim 仿真脚本
├── syn/              # 综合脚本
├── AGENTS.md         # 智能体行为规范
└── README.md         # 本文件
```

## 快速开始

### 1. 仿真

进入 `sim` 目录，运行 QuestaSim/ModelSim：

```bash
cd sim
vsim -c -do run_sii9134_demo.do
```

仿真预期结果：`Simulation PASSED.`

### 2. 综合与布局布线

使用 HqFpga 工具运行工程脚本：

```bash
cd prj
hqfpga -cmd run_hqprj.tcl
```

成功后将生成 `sii9134_demo.bin`。

### 3. 上板验证

下载 `prj/sii9134_demo.bin` 至开发板，连接 HDMI 显示器即可看到 1080p60 彩条画面。

## 顶层接口

### `sii9134_demo`（可直接上板）

| 信号 | 方向 | 说明 |
|------|------|------|
| `clk_27m` | 输入 | 27 MHz 系统时钟 |
| `rst_n` | 输入 | 低电平有效复位 |
| `sii_pclk` | 输出 | 148.5 MHz 像素时钟 |
| `sii_hsync`/`sii_vsync` | 输出 | 行/场同步 |
| `sii_de` | 输出 | 数据使能 |
| `sii_data[35:0]` | 输出 | 36-bit RGB 视频数据 |
| `sii_scl`/`sii_sda` | 双向 | I2C 总线（开漏，需外部上拉） |
| `i2c_busy`/`i2c_done`/`i2c_error` | 输出 | I2C 初始化状态 |

### `sii9134_top`（AXI4-Stream 用户接口）

| 信号 | 方向 | 说明 |
|------|------|------|
| `clk_27m`/`rst_n` | 输入 | 系统时钟与复位 |
| `s_axis_*` | 输入/输出 | AXI4-Stream 从机视频接口 |
| `sii_*` | 输出/双向 | SiI9134 并行视频与 I2C 接口 |
| `video_*` | 输出 | 视频时序反馈，供外部 AXI-Stream 源同步 |

## 注意事项

- `sii_scl` 与 `sii_sda` 为开漏信号，**必须外接上拉电阻**。
- SiI9134 的 `RESET#` 由板级复位电路控制，本工程未通过 FPGA 驱动该引脚。
- 视频分辨率和时序由像素时钟与 `video_timing_gen` 决定，I2C 仅配置数据格式与音频/HDCP 禁用。
- 仿真使用行为级 PLL 模型 `sim/pll_sii9134_sim.v`；综合使用 `ip/pll_sii9134/pll_sii9134.v`。

## 许可证

详见 [LICENSE](LICENSE) 文件。
