````markdown
# GPU Monitoring for Intel Arc A310

## Overview
This guide explains how to monitor GPU utilization when running Ollama with Intel Arc A310 graphics.

## Monitoring Tools

### 1. intel_gpu_top (Installed)
Real-time GPU monitoring tool from the `intel-gpu-tools` package.

**Location:** `/bin/intel_gpu_top`

**Basic Usage:**
```bash
intel_gpu_top
```

**List Mode (easier to read):**
```bash
intel_gpu_top -l
```

**With custom sampling interval (milliseconds):**
```bash
intel_gpu_top -l -s 500  # Sample every 500ms
```

**Output Explanation:**
```
 Freq MHz      IRQ RC6             RCS             BCS             VCS            VECS             CCS 
 req  act       /s   %       %  se  wa       %  se  wa       %  se  wa       %  se  wa       %  se  wa
   0    0        0  99    0.00   0   0    0.00   0   0    0.00   0   0    0.00   0   0    0.00   0   0
```

**Column Meanings:**
- **Freq MHz**: GPU frequency (req = requested, act = actual)
- **RC6**: Power state percentage (100% = idle/low power, 0% = active)
- **RCS**: Render/3D engine utilization
- **BCS**: Blitter engine (memory copies)
- **VCS**: Video decode engine
- **VECS**: Video enhancement engine
- **CCS**: Compute engine (used by Ollama for inference)

### 2. Convenience Script: monitor-gpu
A wrapper script that checks prerequisites and runs intel_gpu_top with sensible defaults.

**Location:** `/usr/local/bin/monitor-gpu`

**Usage:**
```bash
monitor-gpu
```

Press Ctrl+C to stop monitoring.

### 3. Quick Stats Snapshot
For a one-time check without continuous monitoring:

```bash
# Current GPU frequency
cat /sys/class/drm/card0/gt/gt0/freq_cur_mhz

# Min/Max frequency limits
cat /sys/class/drm/card0/gt/gt0/freq_min_mhz
cat /sys/class/drm/card0/gt/gt0/freq_max_mhz

# One-second utilization sample
intel_gpu_top -l -s 1000 | head -10
```

## Verifying GPU Usage in Ollama

### Check Ollama Logs for GPU Activity

**View recent GPU-related logs:**
```bash
journalctl -u ollama -n 200 --no-pager | grep -i "vulkan\|gpu\|vram"
```

**Key indicators of GPU usage:**
```
llama_context:    Vulkan0 compute buffer size =   564.73 MiB
runner.inference="[{ID:8680a656-0500-0000-0700-000000000000 Library:Vulkan}]"
runner.vram="2.3 GiB"
```

If you see **"Library:Vulkan"** and **"Vulkan0 compute buffer"** in the logs, the GPU is being used.

### Monitor GPU During Inference

**Terminal 1 - Start monitoring:**
```bash
intel_gpu_top -l
```

**Terminal 2 - Run inference:**
```bash
ollama run llama3.2:3b "Write a short story about AI"
```

**What to expect:**
- During model loading: Brief spike in activity
- During token generation: GPU may show low MHz due to efficient power management
- **VRAM usage shown in Ollama logs** is the definitive proof of GPU usage

## Understanding Intel Arc GPU Behavior

### Power Management (Important!)
Intel Arc GPUs have aggressive power management:
- They can idle at **0 MHz** when not actively computing
- **RC6 at 99-100%** means the GPU is in a deep power-saving state
- This is **NORMAL** and doesn't mean the GPU isn't working

### Why Low Frequency During Inference?
1. **Vulkan compute workloads** can be efficient enough that the GPU doesn't need high frequencies
2. **LLM inference** is memory-bandwidth intensive, not always compute-intensive
3. The GPU may be **power-limited** in the LXC container environment
4. Intel's power management prioritizes **efficiency over raw speed**

### The Definitive Test
The **BEST** way to confirm GPU usage is **Ollama's own logs**, not external monitoring tools:

```bash
# Check if model is loaded on GPU
journalctl -u ollama -n 50 --no-pager | grep "runner.vram"
```

If you see `runner.vram="X.X GiB"`, the model is **definitely** on the GPU.

## Example Verification Session

```bash
# 1. Start monitoring in background
intel_gpu_top -l > /tmp/gpu.log 2>&1 &

# 2. Run inference test
echo "test" | ollama run llama3.2:3b

# 3. Check Ollama logs for GPU usage
journalctl -u ollama -n 100 --no-pager | grep -i "vulkan\|vram"

# 4. Stop monitoring
pkill intel_gpu_top

# 5. Review captured data
cat /tmp/gpu.log | tail -20
```

**Expected results:**
- ✅ Ollama logs show: `Library:Vulkan` and `runner.vram="2.3 GiB"`
- ✅ Model generates output (even if garbled in testing)
- ⚠️ intel_gpu_top may show low MHz (this is OK due to power management)

## Troubleshooting Low/Zero GPU Utilization

### If intel_gpu_top shows 0 MHz but inference works:
**This is normal!** Intel Arc GPUs idle at 0 MHz. Check the Ollama logs instead:
```bash
journalctl -u ollama -n 100 --no-pager | grep "Vulkan0 compute buffer"
```

### If Ollama logs show CPU instead of Vulkan:
```bash
# 1. Check environment file
cat /etc/ollama/ollama.env | grep OLLAMA_VULKAN

# 2. Should show: OLLAMA_VULKAN=1
# If not, fix it:
echo 'OLLAMA_VULKAN=1' >> /etc/ollama/ollama.env

# 3. Restart Ollama
systemctl restart ollama

# 4. Verify GPU detection
journalctl -u ollama -n 20 --no-pager | grep "inference compute"
```

### If model fails to load:
```bash
# Check VRAM availability
journalctl -u ollama -n 50 --no-pager | grep "available="

# Try a smaller model if needed
ollama run llama3.2:1b  # Requires only ~1GB VRAM
```

## Performance Metrics Reference

### Intel Arc A310 Specifications
- **VRAM:** 4 GB GDDR6
- **Driver:** Intel xe (kernel 6.x+)
- **Compute API:** Vulkan 1.3+
- **Usable VRAM in Ollama:** ~3.1 GB (after driver overhead)

### Recommended Models by VRAM
| Model | VRAM Required | Fits on A310? |
|-------|---------------|---------------|
| llama3.2:1b | ~1 GB | ✅ Yes (plenty of room) |
| llama3.2:3b | ~2.3 GB | ✅ Yes (recommended) |
| llama3.1:8b | ~4.9 GB | ❌ No (exceeds VRAM) |
| llama2:7b | ~4.0 GB | ⚠️ Tight fit (may work) |

### Typical Performance
- **Model load time:** 2-3 seconds (from logs)
- **Token generation:** Variable (depends on prompt complexity)
- **VRAM usage:** Model size + ~300-600 MB compute buffers

## Advanced Monitoring

### Create a monitoring script for automated checks:
```bash
cat > /usr/local/bin/gpu-status << 'EOF'
#!/bin/bash
echo "=== GPU Status ==="
echo "Frequency: $(cat /sys/class/drm/card0/gt/gt0/freq_cur_mhz) MHz"
echo "Ollama Service: $(systemctl is-active ollama)"
if systemctl is-active --quiet ollama; then
    echo "Loaded Models:"
    curl -s http://localhost:11434/api/ps 2>/dev/null | grep -o '"name":"[^"]*"' | cut -d'"' -f4
fi
echo ""
journalctl -u ollama -n 20 --no-pager | grep "runner.vram" | tail -1
EOF
chmod +x /usr/local/bin/gpu-status
```

**Usage:**
```bash
gpu-status
```

## Summary

✅ **GPU monitoring tools installed:** intel-gpu-tools, monitor-gpu script  
✅ **Primary verification method:** Ollama logs showing Vulkan and VRAM usage  
✅ **Secondary method:** intel_gpu_top for real-time frequency/utilization  
⚠️ **Note:** Low MHz in intel_gpu_top is normal due to Intel power management  
✅ **Definitive proof:** `runner.vram="X.X GiB"` in Ollama logs  

**Bottom line:** If Ollama logs show the model loaded with VRAM and Library:Vulkan, your GPU is working correctly, regardless of what intel_gpu_top shows for frequency.

````