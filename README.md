# RaspSetup

> **RaspSetup** — A lightweight automation script for **Raspberry Pi OS**  
> Update your system, install essential tools, and configure services via an interactive Whiptail menu.

---

## 📌 Overview

RaspSetup is a simple automation tool designed to speed up the initial setup of **Raspberry Pi OS**.  
With just a few commands, you can:

- Update and upgrade your system packages  
- Install common benchmarking and utility tools (Sysbench, Stress-ng, etc.)  
- Enable SSH / VNC / raspi-config from one place  
- Use an **interactive Whiptail menu** instead of manual commands  
- Get your Raspberry Pi ready for projects faster and easier  

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| **System update & upgrade** | Keeps your Raspberry Pi OS up to date |
| **Essential tools installation** | Benchmarking and stress-testing tools out of the box |
| **Whiptail interactive menu** | Easy-to-use text UI for setup options |
| **Service configuration** | Enable SSH, VNC, and run `raspi-config` directly |
| **Lightweight & fast** | Minimal dependencies, suitable for low-resource Pi devices |

---

## 🚀 Quick Start

> ⚠️ **Note**: You’ll need `sudo` privileges since the script modifies system configurations.

```bash
# Step 1: Clone the repository
git clone https://github.com/123Labs-96/RaspSetup.git
cd RaspSetup

# Step 2: Make the script executable and run it
sudo chmod +x raspsetup.sh
./raspsetup.sh
