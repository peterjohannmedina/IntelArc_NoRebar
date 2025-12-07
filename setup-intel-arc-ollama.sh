#!/bin/bash
set -e

echo "=== Intel Arc A310 + Ollama Setup Script ==="
echo "This script will install and configure Ollama for Intel Arc GPU"
echo "Works on systems WITHOUT ReBAR support"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)" 
   exit 1
fi

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
else
    echo "Cannot detect OS version"
    exit 1
fi

echo "Detected OS: $OS $VERSION"
echo ""

# Install Intel graphics drivers
echo "Step 1/5: Installing Intel graphics drivers..."
apt-get update
apt-get install -y gpg-agent wget curl

wget -qO - https://repositories.intel.com/gpu/intel-graphics.key | \
  gpg --dearmor --output /usr/share/keyrings/intel-graphics.gpg

echo "deb [arch=amd64 signed-by=/usr/share/keyrings/intel-graphics.gpg] https://repositories.intel.com/gpu/ubuntu jammy client" | \
  tee /etc/apt/sources.list.d/intel-gpu-jammy.list

apt-get update

echo "Installing Intel graphics packages..."
apt-get install -y \
  intel-opencl-icd \
  intel-level-zero-gpu \
  level-zero \
  intel-media-va-driver-non-free \
  libmfx1 \
  libmfxgen1 \
  libvpl2 \
  libegl-mesa0 \
  libegl1-mesa \
  libegl1-mesa-dev \
  libgbm1 \
  libgl1-mesa-dev \
  libgl1-mesa-dri \
  libglapi-mesa \
  libgles2-mesa-dev \
  libglx-mesa0 \
  libigdgmm12 \
  libxatracker2 \
  mesa-va-drivers \
  mesa-vdpau-drivers \
  mesa-vulkan-drivers \
  va-driver-all \
  vainfo \
  hwinfo \
  clinfo \
  vulkan-tools 2>&1 | grep -v "already the newest version" || true

# Install Intel oneAPI
echo ""
echo "Step 2/5: Installing Intel oneAPI runtime..."
wget -O- https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB | \
  gpg --dearmor | tee /usr/share/keyrings/oneapi-archive-keyring.gpg > /dev/null

echo "deb [signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main" | \
  tee /etc/apt/sources.list.d/oneAPI.list

apt-get update
apt-get install -y intel-oneapi-compiler-dpcpp-cpp-runtime-2024.0

# Install Ollama
echo ""
echo "Step 3/5: Installing Ollama..."
if command -v ollama &> /dev/null; then
    echo "Ollama is already installed"
else
    curl -fsSL https://ollama.com/install.sh | sh
fi

# Configure Ollama
echo ""
echo "Step 4/5: Configuring Ollama for Intel Arc GPU..."
mkdir -p /etc/ollama

cat > /etc/ollama/ollama.env <<'EOF'
LD_LIBRARY_PATH=/opt/intel/oneapi/2024.0/lib:/opt/intel/oneapi/compiler/2024.0/lib
ONEAPI_DEVICE_SELECTOR=level_zero
OLLAMA_DEBUG=1
OLLAMA_VULKAN=1
OLLAMA_NUM_GPU=1
OLLAMA_GPU_OVERHEAD=0
OLLAMA_CONTEXT_LENGTH=2048
OLLAMA_NUM_PARALLEL=1
OLLAMA_MAX_LOADED_MODELS=1
EOF

# Check if ollama user exists, if not use root
OLLAMA_USER="ollama"
if ! id "$OLLAMA_USER" &>/dev/null; then
    OLLAMA_USER="root"
    echo "Note: Using root user for Ollama service"
fi

cat > /etc/systemd/system/ollama.service <<EOF
[Unit]
Description=Ollama Service
After=network.target

[Service]
Type=simple
User=$OLLAMA_USER
Group=$OLLAMA_USER
EnvironmentFile=/etc/ollama/ollama.env
ExecStart=/usr/local/bin/ollama serve
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Add ollama user to video/render groups if it exists
if id "ollama" &>/dev/null; then
    usermod -aG video ollama 2>/dev/null || true
    usermod -aG render ollama 2>/dev/null || true
fi

# Restart Ollama
echo ""
echo "Step 5/5: Starting Ollama service..."
systemctl daemon-reload
systemctl restart ollama
systemctl enable ollama

# Wait for service to start
sleep 3

# Verify GPU detection
echo ""
echo "=== Setup Complete! ==="
echo ""
echo "GPU Detection Status:"
journalctl -u ollama -n 50 --no-pager | grep -i "vulkan\|arc\|inference compute" | tail -5 || echo "  (Check logs with: sudo journalctl -u ollama -n 50)"

echo ""
echo "Verify GPU manually:"
echo "  sudo journalctl -u ollama -n 50 | grep -i vulkan"
echo ""
echo "Check OpenCL detection:"
echo "  clinfo | grep -A 3 'Platform Name'"
echo ""
echo "Test inference:"
echo "  ollama pull llama3.2:3b"
echo "  ollama run llama3.2:3b 'What is 2+2?'"
echo ""
echo "Expected GPU: Intel(R) Arc(tm) A310 Graphics (DG2)"
echo "Expected VRAM: ~3.1 GiB available (4GB total)"
echo ""
