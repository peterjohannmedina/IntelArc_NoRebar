````markdown
# Intel Arc A310 GPU Setup for Ollama Inference on Linux

## Overview

This guide enables **Intel Arc A310 GPU inference with Ollama** on Linux systems that lack modern BIOS features such as **ReBAR (Resizable BAR)** or **Above 4G Decoding**. Many older motherboards and OEM systems don't support these features, which can limit GPU performance. This solution uses Vulkan as the compute backend, working around these BIOS limitations while still achieving full GPU acceleration for AI inference workloads.

## System Requirements

- **GPU**: Intel Arc A310 (DG2) or compatible Intel discrete GPU
- **OS**: Ubuntu 22.04+ or Debian-based Linux distribution
- **Kernel**: Linux 6.x+ (for `xe` driver support)
- **BIOS**: Works on systems without ReBAR or Above 4G Decoding support

## Quick Installation

Run this one-line command to install all dependencies and configure Ollama for Intel Arc GPU:

```bash
curl -fsSL https://raw.githubusercontent.com/peterjohannmedina/IntelArc_NoRebar/main/setup-intel-arc-ollama.sh | sudo bash
```

## What This Repository Provides

- ✅ Complete setup guide for Intel Arc GPU + Ollama on Linux
- ✅ Works on systems **without ReBAR or Above 4G Decoding** support
- ✅ Automated installation script
- ✅ Configuration templates for environment and systemd service
- ✅ Comprehensive monitoring and troubleshooting guides
- ✅ Verification scripts to test your setup
- ✅ Quick reference guide for daily operations

## Repository Contents

| File | Description |
|------|-------------|
| **README.md** | This file - complete setup guide |
| **OVERVIEW.md** | Quick start and architecture overview |
| **INDEX.md** | Documentation index with file descriptions |
| **setup-intel-arc-ollama.sh** | Automated installation script |
| **verify-setup.sh** | System verification and diagnostic script |
| **ollama.env** | Environment configuration template |
| **ollama.service** | Systemd service unit file template |
| **MONITORING.md** | GPU monitoring guide |
| **TROUBLESHOOTING.md** | Common issues and solutions |
| **QUICK_REFERENCE.md** | Command cheat sheet |
| **SETUP_COMPLETE.md** | Setup completion checklist |
| **GPU_STATUS_UPDATE.md** | Testing results and status |

## Manual Installation

### 1. Install Intel Graphics Drivers

```bash
# Add Intel graphics repository
sudo apt-get install -y gpg-agent wget
wget -qO - https://repositories.intel.com/gpu/intel-graphics.key | \
  sudo gpg --dearmor --output /usr/share/keyrings/intel-graphics.gpg

echo "deb [arch=amd64 signed-by=/usr/share/keyrings/intel-graphics.gpg] https://repositories.intel.com/gpu/ubuntu jammy client" | \
  sudo tee /etc/apt/sources.list.d/intel-gpu-jammy.list

sudo apt-get update

# Install Intel graphics and compute stack
sudo apt-get install -y \
  intel-opencl-icd \
  intel-level-zero-gpu \
  level-zero \
  mesa-vulkan-drivers \
  clinfo \
  vulkan-tools
```

### 2. Install Intel oneAPI Runtime

```bash
# Add Intel oneAPI repository
wget -O- https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB | \
  gpg --dearmor | sudo tee /usr/share/keyrings/oneapi-archive-keyring.gpg > /dev/null

echo "deb [signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main" | \
  sudo tee /etc/apt/sources.list.d/oneAPI.list

sudo apt-get update
sudo apt-get install -y intel-oneapi-compiler-dpcpp-cpp-runtime-2024.0
```

### 3. Install Ollama

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

### 4. Configure Ollama

```bash
# Create configuration directory
sudo mkdir -p /etc/ollama

# Copy environment file
sudo cp ollama.env /etc/ollama/ollama.env

# Copy service file
sudo cp ollama.service /etc/systemd/system/ollama.service

# Add ollama user to required groups
sudo usermod -aG video ollama
sudo usermod -aG render ollama

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable ollama
sudo systemctl restart ollama
```

### 5. Verify Installation

```bash
# Run verification script
bash verify-setup.sh

# Check GPU detection in Ollama logs
sudo journalctl -u ollama -n 50 | grep -i vulkan

# Test inference
ollama pull llama3.2:3b
ollama run llama3.2:3b "What is 2+2?"
```

## How It Works

### Key Components

1. **Vulkan Backend**: Ollama uses Vulkan compute for GPU acceleration, which works without ReBAR
2. **Intel oneAPI Libraries**: Provides the runtime needed for GPU detection and compute
3. **Intel xe Driver**: Modern kernel driver for Intel Arc GPUs
4. **Environment Configuration**: Proper library paths enable GPU discovery

### Why This Works Without ReBAR

- **Vulkan API**: Standard graphics/compute API that doesn't require ReBAR
- **Efficient Memory Management**: Intel Level Zero runtime handles memory transfers efficiently
- **Container Friendly**: Works in LXC containers and Docker with proper device passthrough

## Performance

Tested on Intel Arc A310 (4GB VRAM):

| Model | Performance | Status |
|-------|------------|--------|
| llama3.2:3b | ~40-60 tok/s | ✅ Excellent |
| mistral:7b | ~25-35 tok/s | ✅ Good |
| llama3.1:8b | ~15-25 tok/s | ✅ Usable |

## Supported Hardware

### Tested ✅
- Intel Arc A310 (4GB VRAM)
- Ubuntu 24.04 LTS
- Proxmox LXC containers
- Systems without ReBAR support

### Should Work (Untested)
- Intel Arc A380 (6GB VRAM)
- Intel Arc A750 (8GB VRAM)
- Intel Arc A770 (16GB VRAM)
- Ubuntu 22.04+, Debian 12+

## Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for detailed help with:
- GPU not detected
- Permission issues
- Library path problems
- Performance optimization
- Container-specific issues

## Documentation

- **[OVERVIEW.md](OVERVIEW.md)** - Quick start guide
- **[INDEX.md](INDEX.md)** - Complete file listing and descriptions
- **[MONITORING.md](MONITORING.md)** - GPU monitoring guide
- **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** - Daily command reference
- **[SETUP_COMPLETE.md](SETUP_COMPLETE.md)** - Completion checklist

## Technical Details

### Critical Configuration

The key setting that enables GPU acceleration:
```bash
OLLAMA_VULKAN=1
```

Combined with proper library paths:
```bash
LD_LIBRARY_PATH=/opt/intel/oneapi/2024.0/lib:/opt/intel/oneapi/compiler/2024.0/lib
```

### GPU Detection Verification

Check Ollama logs for successful GPU detection:
```bash
sudo journalctl -u ollama -n 50 | grep "inference compute"
```

Expected output:
```
library=Vulkan name=Vulkan0 
description="Intel(R) Arc(tm) A310 Graphics (DG2)" 
total="4.0 GiB" available="3.1 GiB"
```

## LXC Container Support

For Proxmox LXC containers, configure on the host:

```bash
# In /etc/pve/lxc/XXX.conf
lxc.apparmor.profile: unconfined
lxc.cgroup2.devices.allow: a
lxc.mount.entry: /dev/dri dev/dri none bind,optional,create=dir
```

Inside container:
```bash
# Ensure devices are accessible
ls -la /dev/dri/

# Install and configure as per guide
```

## Contributing

Contributions, issues, and success stories from different hardware configurations are welcome! If you test this on:
- Different Intel Arc models
- Other Linux distributions
- Various container platforms

Please share your results!

## License

This documentation and scripts are provided as-is for educational and personal use.

## Credits

- Intel for Arc GPU drivers and oneAPI toolkit
- Ollama team for Vulkan backend support
- Linux kernel developers for the xe driver
- Community testing and feedback

## Version

- **Version**: 1.0
- **Release Date**: December 7, 2025
- **Tested With**: Ollama 0.13.1+, oneAPI 2024.0
- **Status**: ✅ Production Ready

## Related Links

- [Intel Arc GPU Drivers](https://www.intel.com/content/www/us/en/products/docs/discrete-gpus/arc/software/drivers.html)
- [Intel oneAPI Toolkit](https://www.intel.com/content/www/us/en/developer/tools/oneapi/overview.html)
- [Ollama Documentation](https://github.com/ollama/ollama)
- [Vulkan SDK](https://vulkan.lunarg.com/)

---

**Note**: This repository specifically addresses the lack of ReBAR (Resizable BAR) support, which is a common limitation on older motherboards and enterprise systems. The Vulkan-based approach provides excellent performance without requiring modern BIOS features or hardware modifications.

For questions, issues, or success stories, please open an issue on GitHub.

````
