#!/bin/bash
#
# Install Patched CRB Driver via DKMS
# ===================================
#
# This script installs the patched CRB driver using DKMS for persistent
# kernel module patching across kernel updates.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KERNEL_VERSION=$(uname -r)
DKMS_NAME="tpm-crb-patched"
DKMS_VERSION="1.0"
DKMS_DIR="/usr/src/${DKMS_NAME}-${DKMS_VERSION}"

echo "=========================================="
echo "Installing Patched CRB Driver via DKMS"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root (use sudo)"
    exit 1
fi

# Check dependencies
echo "Checking dependencies..."
if ! command -v dkms >/dev/null 2>&1; then
    echo "ERROR: DKMS is not installed"
    echo "Install with: sudo apt install dkms"
    exit 1
fi

# Check if DKMS module already installed
if dkms status | grep -q "^${DKMS_NAME}"; then
    echo "DKMS module ${DKMS_NAME} is already installed"
    echo "Removing existing installation..."
    dkms remove "${DKMS_NAME}/${DKMS_VERSION}" --all 2>/dev/null || true
fi

# Create DKMS source directory
echo "Creating DKMS source directory..."
mkdir -p "${DKMS_DIR}"

# Copy source files
echo "Copying source files..."
cp "${SCRIPT_DIR}/tpm_crb_patched.c" "${DKMS_DIR}/"
cp "${SCRIPT_DIR}/dkms.conf" "${DKMS_DIR}/"

# Create Makefile for DKMS
cat > "${DKMS_DIR}/Makefile" << 'EOF'
obj-m := tpm_crb_patched.o

PWD := $(shell pwd)
KERNEL_VERSION := $(shell uname -r)
KDIR := /lib/modules/$(KERNEL_VERSION)/build

all:
	$(MAKE) -C $(KDIR) M=$(PWD) modules

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean
EOF

# Copy header files if needed (they should be in kernel source)
# For now, we'll rely on kernel headers being installed

# Add module to DKMS
echo "Adding module to DKMS..."
dkms add "${DKMS_NAME}/${DKMS_VERSION}"

# Build module
echo "Building module..."
dkms build "${DKMS_NAME}/${DKMS_VERSION}"

# Install module
echo "Installing module..."
dkms install "${DKMS_NAME}/${DKMS_VERSION}"

# Create modprobe configuration to load module
echo "Configuring module loading..."
cat > /etc/modprobe.d/tpm-crb-patched.conf << 'EOF'
# Load patched CRB driver
install tpm_crb_patched /sbin/modprobe --ignore-install tpm_crb_patched; /sbin/modprobe tpm_crb_patched
EOF

echo ""
echo "✓ DKMS installation complete!"
echo ""
echo "The patched CRB driver will:"
echo "  - Automatically rebuild on kernel updates"
echo "  - Load automatically on boot"
echo ""
echo "To verify installation:"
echo "  dkms status"
echo "  lsmod | grep tpm_crb"
echo ""
echo "To uninstall:"
echo "  sudo dkms remove ${DKMS_NAME}/${DKMS_VERSION} --all"
