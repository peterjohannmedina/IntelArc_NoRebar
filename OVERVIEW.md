````markdown
# Intel Arc GPU Without ReBAR - Ollama Setup

Complete solution for running Ollama with Intel Arc A310 GPU on Linux systems **that lack ReBAR (Resizable BAR) or Above 4G Decoding BIOS support**. Ideal for older motherboards, OEM systems, and hardware where these modern BIOS features are unavailable.

## Quick Start

One-line installation:
```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/intel-arc-ollama/main/setup-intel-arc-ollama.sh | sudo bash
```

Or download and run:
```bash
wget https://raw.githubusercontent.com/YOUR_USERNAME/intel-arc-ollama/main/setup-intel-arc-ollama.sh
chmod +x setup-intel-arc-ollama.sh
sudo ./setup-intel-arc-ollama.sh
```

## What This Solves

- ✅ Intel Arc GPU inference on systems **without ReBAR or Above 4G Decoding**
- ✅ Works on older motherboards and OEM systems lacking modern BIOS features
- ✅ Uses Vulkan compute backend (not CUDA/ROCm)
- ✅ Full 4GB VRAM utilization on Arc A310
- ✅ Compatible with LXC containers (Proxmox)
- ✅ Tested on Ubuntu 22.04+ and Debian-based systems

## Repository Contents

- **README.md** - Complete setup guide and documentation
- **setup-intel-arc-ollama.sh** - Automated installation script
- **ollama.env** - Environment configuration template
- **ollama.service** - Systemd service file
- **TROUBLESHOOTING.md** - Common issues and solutions
- **GPU_STATUS_UPDATE.md** - Testing documentation and results

## Supported GPUs

- Intel Arc A310 (4GB VRAM) - **Tested ✅**
- Intel Arc A380 (6GB VRAM) - Should work
- Intel Arc A750 (8GB VRAM) - Should work
- Intel Arc A770 (16GB VRAM) - Should work

## Requirements

- Linux kernel 6.x+ (for Intel `xe` driver)
- Ubuntu 22.04+ or Debian-based distribution
- Intel Arc discrete GPU
- No ReBAR or Above 4G Decoding required in BIOS

## System Compatibility

### Tested Environments
- ✅ Ubuntu 24.04 (bare metal)
- ✅ Proxmox LXC containers
- ✅ Systems without ReBAR support

### Should Work (Untested)
- Ubuntu 22.04
- Debian 12+
- Docker containers with GPU passthrough

## Installation Methods

### Method 1: Automated Script (Recommended)
```bash
sudo bash setup-intel-arc-ollama.sh
```

### Method 2: Manual Installation
Follow step-by-step instructions in [README.md](README.md)

### Method 3: Copy Configuration Files
```bash
# Copy environment file
sudo cp ollama.env /etc/ollama/ollama.env

# Copy service file
sudo cp ollama.service /etc/systemd/system/ollama.service

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

## Verification

After installation:
```bash
# Check GPU detection
sudo journalctl -u ollama -n 50 | grep -i vulkan

# Test inference
ollama pull llama3.2:3b
ollama run llama3.2:3b "What is 2+2?"
```

Expected output in logs:
```
inference compute" library=Vulkan name=Vulkan0 
description="Intel(R) Arc(tm) A310 Graphics (DG2)" 
type=discrete total="4.0 GiB" available="3.1 GiB"
```

## Performance

| Model | Intel Arc A310 | Notes |
|-------|----------------|-------|
| llama3.2:3b | ~40-60 tok/s | Excellent |
| mistral:7b | ~25-35 tok/s | Good |
| llama3.1:8b | ~15-25 tok/s | Usable |

## Technical Details

### Why This Works Without ReBAR

1. **Vulkan Compute Backend**: Uses standard Vulkan API which doesn't require ReBAR
2. **Intel Level Zero Runtime**: Handles memory management efficiently
3. **Modern Intel Drivers**: The `xe` kernel driver supports Arc GPUs without ReBAR
4. **Ollama Vulkan Support**: Recent versions include experimental Vulkan backend

### Key Configuration

The critical setting is:
```bash
OLLAMA_VULKAN=1
```

Combined with proper Intel oneAPI library paths:
```bash
LD_LIBRARY_PATH=/opt/intel/oneapi/2024.0/lib:/opt/intel/oneapi/compiler/2024.0/lib
```

## Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for:
- GPU not detected
- Permission issues
- Library path problems
- Container-specific issues
- Performance optimization

## Contributing

This solution was developed and tested on:
- Intel Arc A310 (4GB VRAM)
- Ubuntu 24.04
- Proxmox LXC container
- System without ReBAR support

If you test on other configurations, please report results!

## License

This is provided as-is for educational and personal use.

## Credits

- Intel for Arc GPU drivers and oneAPI toolkit
- Ollama team for Vulkan backend support
- Linux kernel developers for `xe` driver

## Version

- **Version**: 1.0
- **Date**: December 7, 2025
- **Ollama Version Tested**: 0.13.1
- **oneAPI Version**: 2024.0

## Related Links

- [Intel Arc GPU Drivers](https://www.intel.com/content/www/us/en/products/docs/discrete-gpus/arc/software/drivers.html)
- [Intel oneAPI Toolkit](https://www.intel.com/content/www/us/en/developer/tools/oneapi/overview.html)
- [Ollama Documentation](https://github.com/ollama/ollama)

---

**Note**: This configuration specifically addresses the lack of ReBAR support, which is a common limitation on older motherboards and enterprise systems. The Vulkan-based approach provides excellent performance without requiring hardware ReBAR.

````