````markdown
# Intel Arc A310 + Ollama - Quick Reference

## Container Access
```bash
# From Windows PC to Proxmox node 233
ssh root@192.168.1.233

# Access container 206
pct enter 206
# OR
pct exec 206 -- bash
```

## Service Management
```bash
# Check Ollama status
systemctl status ollama

# Restart Ollama
systemctl restart ollama

# View live logs
journalctl -u ollama -f

# Check recent GPU detection
journalctl -u ollama -n 50 --no-pager | grep "inference compute"
```

## Run Inference
```bash
# Interactive mode
ollama run llama3.2:3b

# One-shot command
ollama run llama3.2:3b "Your prompt here"

# List available models
ollama list
```

## GPU Monitoring
```bash
# Real-time GPU stats
intel_gpu_top -l

# Or use convenience wrapper
monitor-gpu

# Check current GPU frequency
cat /sys/class/drm/card0/gt/gt0/freq_cur_mhz

# Verify GPU is being used (definitive)
journalctl -u ollama -n 100 --no-pager | grep "runner.vram"
# Should show: runner.vram="2.3 GiB" or similar
```

## GPU Detection Check
```bash
# OpenCL
clinfo | grep "Device Name"

# Level Zero
sycl-ls | grep Arc

# PCI device
lspci | grep -i vga

# Ollama GPU info
journalctl -u ollama -n 50 --no-pager | grep Vulkan
```

## Troubleshooting
```bash
# If GPU not detected by Ollama
cat /etc/ollama/ollama.env | grep OLLAMA_VULKAN
# Must show: OLLAMA_VULKAN=1

# If wrong, fix and restart
echo 'OLLAMA_VULKAN=1' | tee -a /etc/ollama/ollama.env
systemctl restart ollama

# Check environment is loaded
systemctl show ollama | grep OLLAMA_VULKAN

# Verify library paths
systemctl show ollama | grep LD_LIBRARY_PATH
```

## Model Management
```bash
# Pull new model
ollama pull llama3.2:1b

# Remove model
ollama rm llama3.2:1b

# Check model sizes
ollama list

# Model storage location
ls -lh /root/.ollama/models/
```

## Performance Tips
```bash
# Monitor VRAM during inference
# Terminal 1:
journalctl -u ollama -f | grep vram

# Terminal 2:
ollama run llama3.2:3b "test prompt"
```

## Key Files
| File | Purpose |
|------|---------|  
| `/etc/ollama/ollama.env` | Environment variables (OLLAMA_VULKAN=1) |
| `/etc/systemd/system/ollama.service` | Service configuration |
| `/usr/local/bin/monitor-gpu` | GPU monitoring wrapper |
| `/root/.ollama/models/` | Downloaded models storage |

## Container Info
- **Name:** compossure-GPU-Intel
- **ID:** 206
- **Node:** 233
- **IP:** (check with `ip a`)
- **GPU:** Intel Arc A310 (4GB)

## Quick Tests
```bash
# 1. GPU hardware test
lspci | grep -i intel | grep -i vga

# 2. GPU driver test
ls -la /dev/dri/

# 3. OpenCL test
clinfo | head -20

# 4. Ollama service test
systemctl is-active ollama

# 5. GPU detection in Ollama
journalctl -u ollama -n 50 --no-pager | grep "4.0 GiB"

# 6. Quick inference test
echo "hi" | ollama run llama3.2:3b
```

## Expected Outputs

### GPU Detection (Success)
```
library=Vulkan name=Vulkan0 
description="Intel(R) Arc(tm) A310 Graphics (DG2)" 
total="4.0 GiB" available="3.1 GiB"
```

### Model Running (Success)
```
runner.inference="[{Library:Vulkan}]"
runner.vram="2.3 GiB"
```

### GPU Idle (Normal)
```
intel_gpu_top output:
Freq MHz: 0 (req), 0 (act)
RC6: 99-100%
```
**Note:** This is NORMAL. Check Ollama logs for actual VRAM usage.

## Common Issues

### "GPU not found"
- Check: `cat /etc/ollama/ollama.env | grep OLLAMA_VULKAN`
- Should be: `OLLAMA_VULKAN=1`
- Fix: Add/edit the line, then `systemctl restart ollama`

### "Out of memory"
- Model too large for 4GB VRAM
- Try: `ollama run llama3.2:1b` (smaller model)
- Check: `journalctl -u ollama -n 50 | grep available`

### "intel_gpu_top shows 0 MHz"
- This is NORMAL (Intel power management)
- Verify GPU usage in Ollama logs instead
- Check: `journalctl -u ollama -n 50 | grep vram`

## Documentation
- **Full Setup:** See `SETUP_COMPLETE.md`
- **Monitoring:** See `MONITORING.md`
- **Troubleshooting:** See `TROUBLESHOOTING.md` (if exists)

## Support Commands
```bash
# Full system info
neofetch

# GPU info detailed
intel_gpu_top -l -s 1000 | head -20

# Ollama debug logs
journalctl -u ollama -n 200 --no-pager

# Environment check
env | grep -E "OLLAMA|LD_LIBRARY|ONEAPI"
```

---
**Status:** ✅ Operational  
**Last Updated:** December 7, 2025

````