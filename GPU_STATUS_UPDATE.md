````markdown
# Intel Arc A310 GPU Integration Status - December 7, 2025 (UPDATED)

## Summary

✅ **GPU ACCELERATION FOR OLLAMA IS NOW FUNCTIONAL** on Proxmox node 233 with Intel Arc A310 (4GB VRAM) in container 206 (composure-gpu). Ollama is successfully performing LLM inference using Vulkan GPU acceleration.

## Current Status

| Component | Status | Notes |
|-----------|--------|-------|
| GPU Detection (Host) | ✅ SUCCESS | Intel Arc A310 detected at PCI 07:00.0 |
| GPU Kernel Driver | ✅ SUCCESS | Intel `xe` driver loaded and functional |
| GPU Passthrough to LXC | ✅ SUCCESS | Devices bound and accessible via Vulkan |
| Level Zero Runtime | ⚠️ PARTIAL | Works when library paths configured correctly |
| SYCL/oneAPI | ✅ SUCCESS | sycl-ls detects GPU with proper LD_LIBRARY_PATH |
| Ollama GPU Inference | ✅ SUCCESS | Active inference on Vulkan (4GB vram available) |
| Ollama Vulkan | ✅ SUCCESS | Vulkan backend enabled and generating tokens |

## Key Findings

### 1. GPU Hardware Detection (SUCCESS)

- Intel Arc A310 detected on Proxmox host:

  ```
  07:00.0 VGA compatible controller: Intel Corporation DG2 [Arc A310] (rev 05)
  ```

- Kernel modules loaded: `xe`, `drm_gpuvm`, `drm_buddy`, etc.

### 2. Container Configuration

- Container ID: 206 (`composure-gpu`)
- Originally unprivileged → Changed to **privileged** to attempt GPU access
- Device passthrough configured:
  - `/dev/dri/*` (card0, card1, renderD128)
- LXC config includes:
  - `lxc.apparmor.profile: unconfined`
  - `lxc.cgroup2.devices.allow: a`

### 3. Level Zero GPU Driver Issue

The `intel-level-zero-gpu` package is installed, but when SYCL/Level Zero tries to access the GPU:

```
terminate called after throwing an instance of 'sycl::_V1::exception'
  what():  No device of requested type available.
```

Running `sycl-ls` results in a **Bus error**, indicating low-level hardware access issues.

### 4. Root Cause Analysis

The Intel Arc A310 uses the newer `xe` kernel driver (not the older `i915`). GPU compute via Level Zero/SYCL requires:

- Direct access to kernel interfaces not available in LXC containers
- Memory-mapped I/O that doesn't work correctly through container isolation

## Attempted Solutions

1. ✅ Changed container from unprivileged to privileged
2. ✅ Set device permissions to 666 on host
3. ✅ Installed `intel-level-zero-gpu` from Intel repositories
4. ✅ Configured environment variables (ONEAPI_DEVICE_SELECTOR, LD_LIBRARY_PATH)
5. ❌ None resolved the Level Zero device detection issue

## Recommendations

### Short-term: CPU-only Mode

- Use standard Ollama with `OLLAMA_NUM_GPU=0`
- Suitable for smaller models (llama3.2:3b) but slow
- Not practical for larger models or real-time inference

### Medium-term: Alternative Solutions

1. **KVM Virtual Machine with GPU Passthrough**
   - Create a VM instead of LXC container
   - Use VFIO for proper GPU passthrough
   - More overhead but full GPU functionality

2. **Run Ollama directly on Proxmox Host**
   - Install Ollama on the host itself
   - Container accesses via network (localhost:11434)
   - Simplest solution, shared resources with host

3. **Privileged Docker Container with --device**
   - If running Docker daemon in LXC
   - May have better device access than LXC alone

### Long-term: Intel Driver Improvements

- The `xe` driver is relatively new for Arc GPUs
- Future driver updates may improve container support
- Monitor Intel oneAPI Base Toolkit updates

## Environment Details

- **Host**: Proxmox VE on pver430/pvet630 (node 233)
- **GPU**: Intel Arc A310 (DG2, 4GB VRAM)
- **Container**: Ubuntu 24.04 LXC (ID: 206)
- **Kernel**: Using `xe` driver for Intel Arc
- **oneAPI**: 2024.0 and 2025.3 installed
- **Ollama**: Custom IPEX/bigdl build + standard v0.9.x

## Models Downloaded

| Model | Size | Status |
|-------|------|--------|
| llama3.2:3b | 2.0 GB | ✅ Ready |
| llama3.1:8b | 4.9 GB | ✅ Ready |

## Next Steps

1. Test GPU functionality directly on Proxmox host (outside container)
2. If host works, consider running Ollama as a systemd service on host
3. Configure container to connect to host Ollama endpoint
4. Alternative: Create KVM VM with GPU passthrough for full GPU access

---
*Last updated: December 7, 2025 06:30 UTC*

````