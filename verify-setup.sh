#!/bin/bash

echo "=== Intel Arc GPU System Verification ==="
echo ""
echo "This script checks if your Intel Arc GPU is properly configured for Ollama"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "Note: Some checks require root privileges"
   echo "Run with sudo for complete verification"
   echo ""
fi

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

pass() {
    echo -e "${GREEN}✓${NC} $1"
}

fail() {
    echo -e "${RED}✗${NC} $1"
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

echo "1. Checking GPU Hardware Detection..."
if lspci | grep -i "vga.*intel.*arc" > /dev/null 2>&1 || lspci | grep -i "intel.*dg2" > /dev/null 2>&1; then
    GPU_NAME=$(lspci | grep -i "vga.*intel" | cut -d: -f3)
    pass "Intel Arc GPU detected:$GPU_NAME"
else
    fail "Intel Arc GPU not detected in system"
    exit 1
fi

echo ""
echo "2. Checking DRI Devices..."
if [ -d /dev/dri ]; then
    if [ -c /dev/dri/renderD128 ]; then
        pass "/dev/dri/renderD128 exists"
        ls -l /dev/dri/renderD128
    else
        fail "/dev/dri/renderD128 not found"
    fi
    
    if [ -c /dev/dri/card0 ]; then
        pass "/dev/dri/card0 exists"
    else
        warn "/dev/dri/card0 not found"
    fi
else
    fail "/dev/dri directory not found"
fi

echo ""
echo "3. Checking OpenCL Support..."
if command -v clinfo &> /dev/null; then
    if clinfo | grep -i "intel.*opencl" > /dev/null 2>&1; then
        pass "Intel OpenCL detected"
        clinfo | grep -A 2 "Platform Name" | head -5
    else
        fail "Intel OpenCL not detected"
    fi
else
    warn "clinfo not installed (install with: sudo apt-get install clinfo)"
fi

echo ""
echo "4. Checking Vulkan Support..."
if command -v vulkaninfo &> /dev/null; then
    if vulkaninfo --summary 2>/dev/null | grep -i "intel.*arc" > /dev/null 2>&1; then
        pass "Intel Arc Vulkan driver detected"
        vulkaninfo --summary 2>/dev/null | grep -A 2 "GPU" | head -5
    else
        fail "Intel Arc Vulkan driver not detected"
    fi
else
    warn "vulkaninfo not installed (install with: sudo apt-get install vulkan-tools)"
fi

echo ""
echo "5. Checking Intel oneAPI Libraries..."
if [ -d /opt/intel/oneapi ]; then
    pass "Intel oneAPI directory exists"
    
    if [ -f /opt/intel/oneapi/2024.0/lib/libsycl.so.7 ]; then
        pass "libsycl.so.7 found"
    elif [ -f /opt/intel/oneapi/compiler/2024.0/lib/libsycl.so.7 ]; then
        pass "libsycl.so.7 found in compiler directory"
    else
        fail "libsycl.so.7 not found"
    fi
    
    if [ -x /opt/intel/oneapi/compiler/2024.0/bin/sycl-ls ]; then
        pass "sycl-ls tool found"
        echo "   Testing sycl-ls:"
        LD_LIBRARY_PATH=/opt/intel/oneapi/2024.0/lib:/opt/intel/oneapi/compiler/2024.0/lib \
          /opt/intel/oneapi/compiler/2024.0/bin/sycl-ls 2>/dev/null | head -3
    else
        warn "sycl-ls tool not found"
    fi
else
    fail "Intel oneAPI not installed at /opt/intel/oneapi"
fi

echo ""
echo "6. Checking Ollama Installation..."
if command -v ollama &> /dev/null; then
    pass "Ollama is installed"
    OLLAMA_VERSION=$(ollama --version 2>&1 | grep -oP '\d+\.\d+\.\d+' | head -1)
    echo "   Version: $OLLAMA_VERSION"
else
    fail "Ollama is not installed"
fi

echo ""
echo "7. Checking Ollama Service..."
if systemctl is-active --quiet ollama; then
    pass "Ollama service is running"
else
    fail "Ollama service is not running"
    if systemctl is-enabled --quiet ollama; then
        warn "Service is enabled but not running - try: sudo systemctl start ollama"
    fi
fi

echo ""
echo "8. Checking Ollama Configuration..."
if [ -f /etc/ollama/ollama.env ]; then
    pass "Ollama environment file exists"
    
    if grep -q "OLLAMA_VULKAN=1" /etc/ollama/ollama.env; then
        pass "OLLAMA_VULKAN=1 is set"
    else
        fail "OLLAMA_VULKAN=1 is NOT set (required for Intel Arc)"
    fi
    
    if grep -q "LD_LIBRARY_PATH.*oneapi" /etc/ollama/ollama.env; then
        pass "LD_LIBRARY_PATH includes oneAPI libraries"
    else
        fail "LD_LIBRARY_PATH does not include oneAPI libraries"
    fi
    
    echo "   Current configuration:"
    cat /etc/ollama/ollama.env | grep -v "^#" | grep -v "^$"
else
    fail "Ollama environment file not found at /etc/ollama/ollama.env"
fi

echo ""
echo "9. Checking Ollama GPU Detection..."
if [[ $EUID -eq 0 ]]; then
    if journalctl -u ollama -n 100 --no-pager 2>/dev/null | grep -i "vulkan.*arc" > /dev/null; then
        pass "Ollama detected Intel Arc via Vulkan"
        echo "   GPU Info:"
        journalctl -u ollama -n 100 --no-pager 2>/dev/null | grep -i "inference compute.*vulkan" | tail -1
    else
        fail "Ollama did not detect Intel Arc GPU"
        warn "Check logs with: sudo journalctl -u ollama -n 50"
    fi
else
    warn "Skipping (requires root) - run: sudo journalctl -u ollama -n 50 | grep -i vulkan"
fi

echo ""
echo "10. Checking Kernel Driver..."
if lsmod | grep -q "^xe "; then
    pass "Intel xe kernel driver loaded"
elif lsmod | grep -q "^i915 "; then
    warn "i915 driver loaded (xe driver preferred for Arc GPUs)"
else
    fail "No Intel graphics driver loaded"
fi

echo ""
echo "=== Verification Complete ==="
echo ""
echo "Summary:"
echo "--------"

# Count checks
TOTAL=10
if [[ $EUID -ne 0 ]]; then
    warn "Some checks skipped (not running as root)"
fi

echo ""
echo "Next Steps:"
echo "1. If any checks failed, see TROUBLESHOOTING.md"
echo "2. Test inference: ollama pull llama3.2:3b && ollama run llama3.2:3b 'test'"
echo "3. Monitor GPU usage: sudo journalctl -u ollama -f"
echo ""
