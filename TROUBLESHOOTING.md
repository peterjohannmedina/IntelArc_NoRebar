````markdown
# Intel Arc GPU Troubleshooting Guide

## Quick Diagnostics

### Check GPU Detection
```bash
# Verify GPU is visible to system
lspci | grep VGA
# Expected: Intel Corporation DG2 [Arc A310]

# Check DRI devices
ls -la /dev/dri/
# Should show: card0, card1, renderD128

# Test OpenCL
clinfo | grep -A 5 "Platform Name"
# Expected: Intel(R) OpenCL Graphics

# Test Vulkan
vulkaninfo | grep "deviceName"
# Expected: Intel(R) Arc(TM) A310 Graphics
```

### Check Ollama Service
```bash
# Service status
sudo systemctl status ollama

# View logs
sudo journalctl -u ollama -n 100 --no-pager

# Check for GPU detection in logs
sudo journalctl -u ollama | grep -i "vulkan\|arc\|inference compute"
```

## Common Issues

### 1. GPU Not Detected by Ollama

**Symptoms:**
- Logs show: `inference compute" id=cpu library=cpu`
- No Vulkan device detected
- VRAM shows "0 B"

**Solutions:**

Check environment variables:
```bash
cat /etc/ollama/ollama.env
# Must include: OLLAMA_VULKAN=1
```

Verify library paths:
```bash
ls -la /opt/intel/oneapi/2024.0/lib/libsycl.so*
# Should exist
```

Restart service with proper environment:
```bash
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

### 2. libsycl.so.7: Cannot Open Shared Object File

**Symptoms:**
- Error: `error while loading shared libraries: libsycl.so.7`
- sycl-ls fails to run

**Solutions:**

Find the library:
```bash
sudo find /opt/intel -name "libsycl.so*"
```

Update environment file:
```bash
sudo nano /etc/ollama/ollama.env
# Add the directory containing libsycl.so.7 to LD_LIBRARY_PATH
```

Test manually:
```bash
LD_LIBRARY_PATH=/opt/intel/oneapi/2024.0/lib:/opt/intel/oneapi/compiler/2024.0/lib \
  /opt/intel/oneapi/compiler/2024.0/bin/sycl-ls
```

### 3. Permission Denied on /dev/dri/renderD128

**Symptoms:**
- Ollama fails to access GPU
- Permission errors in logs

**Solutions:**

Check device permissions:
```bash
ls -la /dev/dri/renderD128
# Should be: crw-rw---- 1 root video 226, 128
```

Add ollama user to video group:
```bash
sudo usermod -aG video ollama
sudo usermod -aG render ollama
sudo systemctl restart ollama
```

For LXC containers, on host:
```bash
chmod 666 /dev/dri/renderD128
```

### 4. Vulkan Support Disabled

**Symptoms:**
- Logs show: `experimental Vulkan support disabled`
- GPU not used even though detected

**Solutions:**

Enable Vulkan in environment:
```bash
sudo nano /etc/ollama/ollama.env
# Ensure this line exists:
OLLAMA_VULKAN=1
```

Restart:
```bash
sudo systemctl restart ollama
```

Verify:
```bash
sudo journalctl -u ollama -n 50 | grep OLLAMA_VULKAN
# Should show: OLLAMA_VULKAN:true
```

### 5. AppArmor Conflicts (LXC Containers)

**Symptoms:**
- Docker/containers fail to start
- AppArmor profile errors in logs

**Solutions:**

Remove AppArmor from container:
```bash
sudo apt-get remove -y apparmor
sudo systemctl restart docker  # if using docker
```

Or configure container (on Proxmox host):
```bash
# Edit /etc/pve/lxc/XXX.conf
lxc.apparmor.profile: unconfined
lxc.cgroup2.devices.allow: a
```

### 6. Model Fails to Load / OOM Errors

**Symptoms:**
- Model loading fails
- Out of memory errors with 4GB VRAM

**Solutions:**

Reduce context length:
```bash
sudo nano /etc/ollama/ollama.env
# Change to:
OLLAMA_CONTEXT_LENGTH=2048  # or 1024 for larger models
```

Use smaller models:
```bash
# Instead of llama3.1:8b, use:
ollama pull llama3.2:3b
ollama pull mistral:7b
```

### 7. Slow Inference / Not Using GPU

**Symptoms:**
- Inference is very slow
- CPU usage high, GPU idle

**Solutions:**

Verify GPU is actually being used:
```bash
# Check logs during inference
sudo journalctl -u ollama -f

# Run test and watch
ollama run llama3.2:3b "test" &
sudo journalctl -u ollama | tail -20
```

Look for:
- `library=Vulkan` (not `library=cpu`)
- `type=discrete total="4.0 GiB"`

If using CPU, check:
```bash
# Ensure OLLAMA_NUM_GPU is not 0
grep OLLAMA_NUM_GPU /etc/ollama/ollama.env
# Should be: OLLAMA_NUM_GPU=1 or OLLAMA_NUM_GPU=999
```

## Verification Commands

### Full System Check
```bash
#!/bin/bash
echo "=== Intel Arc GPU System Check ==="
echo ""

echo "1. GPU Hardware Detection:"
lspci | grep VGA
echo ""

echo "2. DRI Devices:"
ls -la /dev/dri/
echo ""

echo "3. OpenCL Detection:"
clinfo | grep -A 3 "Platform Name" | head -10
echo ""

echo "4. Vulkan Detection:"
vulkaninfo --summary | grep -A 2 "GPU"
echo ""

echo "5. Intel oneAPI Libraries:"
ls -la /opt/intel/oneapi/2024.0/lib/libsycl.so* 2>/dev/null || echo "  Not found"
echo ""

echo "6. Ollama Service Status:"
systemctl status ollama | head -5
echo ""

echo "7. Ollama Environment:"
cat /etc/ollama/ollama.env
echo ""

echo "8. GPU Detection in Ollama Logs:"
journalctl -u ollama -n 100 --no-pager | grep -i "vulkan\|arc\|inference compute" | tail -5
```

### Test Inference
```bash
# Pull test model
ollama pull llama3.2:3b

# Run test query
time ollama run llama3.2:3b "What is 2+2? Answer with just the number."

# Check logs immediately after
sudo journalctl -u ollama -n 30 | grep -i "library\|vram"
```

## Performance Expectations

### Intel Arc A310 (4GB VRAM)

| Model | Status | Tokens/sec | Notes |
|-------|--------|------------|-------|
| llama3.2:3b | ✅ Excellent | ~40-60 | Fully fits in VRAM |
| mistral:7b | ✅ Good | ~25-35 | Some layers in RAM |
| llama3.1:8b | ⚠️ Slow | ~15-25 | Significant RAM usage |
| llama2:13b | ❌ Too Large | ~5-10 | Mostly CPU fallback |

### Expected GPU Metrics
- **Total VRAM**: 4.0 GiB
- **Available VRAM**: ~3.1 GiB (after OS reservation)
- **Compute Type**: Vulkan discrete GPU
- **Driver**: Intel xe kernel module

## Advanced Debugging

### Enable Maximum Debug Logging
```bash
sudo nano /etc/ollama/ollama.env
# Set:
OLLAMA_DEBUG=1

sudo systemctl restart ollama
sudo journalctl -u ollama -f
```

### Test Components Individually

**Test OpenCL:**
```bash
clinfo
```

**Test Vulkan:**
```bash
vulkaninfo
vkcube  # Visual test (requires X11)
```

**Test Level Zero:**
```bash
LD_LIBRARY_PATH=/opt/intel/oneapi/2024.0/lib:/opt/intel/oneapi/compiler/2024.0/lib \
  /opt/intel/oneapi/compiler/2024.0/bin/sycl-ls
# Should show: [ext_oneapi_level_zero:gpu:0] Intel(R) Arc(TM) A310
```

### Monitor GPU Usage
```bash
# Intel GPU top (if available)
intel_gpu_top

# Watch GPU frequency
watch -n 1 'cat /sys/class/drm/card0/gt/gt0/freq_cur_mhz'
```

## Getting Help

If issues persist:

1. Gather system info:
```bash
uname -a
cat /etc/os-release
lspci | grep VGA
ollama --version
```

2. Collect logs:
```bash
sudo journalctl -u ollama -n 200 > ollama_logs.txt
dmesg | grep -i "drm\|xe\|i915" > kernel_logs.txt
```

3. Check Intel Arc driver status:
```bash
lsmod | grep xe
modinfo xe
```

4. Verify no conflicting drivers:
```bash
lsmod | grep -E "nvidia|amdgpu"
# Should be empty for Intel-only system
```

## Container-Specific Issues

### Proxmox LXC
```bash
# On Proxmox host, check container config
cat /etc/pve/lxc/XXX.conf | grep -E "lxc.mount|lxc.cgroup|lxc.apparmor"

# Ensure GPU passthrough
lxc.mount.entry: /dev/dri dev/dri none bind,optional,create=dir

# Inside container, verify
ls -la /dev/dri/
```

### Docker Container
```bash
# Run with GPU access
docker run -it --device=/dev/dri:/dev/dri \
  -v /etc/ollama:/etc/ollama \
  -e LD_LIBRARY_PATH=/opt/intel/oneapi/2024.0/lib \
  ollama/ollama
```

## Reset to Defaults

If all else fails, reset configuration:
```bash
# Stop service
sudo systemctl stop ollama

# Remove configuration
sudo rm -rf /etc/ollama

# Reinstall
curl -fsSL https://ollama.com/install.sh | sh

# Reconfigure using setup script
sudo bash setup-intel-arc-ollama.sh
```

````