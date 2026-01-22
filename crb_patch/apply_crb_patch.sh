#!/bin/bash
#
# Apply CRB Driver Patch for STM0176 Firmware Bug
# ================================================
#
# This script creates a patched CRB driver that works around the firmware bug
# where overlapping command and response buffer sizes are not identical.
#
# The patch modifies the buffer size validation to use the maximum size instead
# of failing when sizes differ.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KERNEL_VERSION=$(uname -r)
KERNEL_SOURCE="/lib/modules/${KERNEL_VERSION}/build"

echo "=========================================="
echo "CRB Driver Patch for STM0176 Firmware Bug"
echo "=========================================="
echo ""
echo "Kernel Version: ${KERNEL_VERSION}"
echo "Kernel Source: ${KERNEL_SOURCE}"
echo ""

# Check if kernel source exists
if [ ! -d "$KERNEL_SOURCE" ]; then
    echo "ERROR: Kernel source not found at: $KERNEL_SOURCE"
    echo ""
    echo "Options:"
    echo "  1. Install kernel headers: sudo apt install linux-headers-${KERNEL_VERSION}"
    echo "  2. Or specify kernel source: export KERNELDIR=/path/to/kernel/source"
    exit 1
fi

# Find the CRB driver source
CRB_SOURCE="${KERNEL_SOURCE}/../source/drivers/char/tpm/tpm_crb.c"
if [ ! -f "$CRB_SOURCE" ]; then
    # Try alternative locations
    CRB_SOURCE=$(find /usr/src -name "tpm_crb.c" 2>/dev/null | head -1)
    if [ -z "$CRB_SOURCE" ]; then
        echo "ERROR: tpm_crb.c source not found"
        echo "Please locate the kernel source and set KERNELDIR"
        exit 1
    fi
fi

echo "Found CRB driver source: $CRB_SOURCE"
echo ""

# Create patched version
PATCHED_DIR="${SCRIPT_DIR}/patched"
mkdir -p "$PATCHED_DIR"

echo "Creating patched CRB driver..."
cp "$CRB_SOURCE" "${PATCHED_DIR}/tpm_crb.c"

# Apply patch: Replace the buffer size check
echo "Applying patch..."

# The problematic code is around line 746-750
# We'll use sed to replace the strict check with a workaround

sed -i '746,750c\
	if (cmd_size != rsp_size) {\
		u32 max_size = max(cmd_size, rsp_size);\
		dev_warn(dev, "Firmware bug: buffer size mismatch (cmd=%u, rsp=%u), using max=%u (workaround enabled)\\n",\
			 cmd_size, rsp_size, max_size);\
		cmd_size = rsp_size = max_size;\
	}' "${PATCHED_DIR}/tpm_crb.c"

echo "✓ Patch applied"
echo ""

# Create Makefile for building the patched module
cat > "${PATCHED_DIR}/Makefile" << 'EOF'
obj-m := tpm_crb_patched.o

PWD := $(shell pwd)
KERNEL_VERSION := $(shell uname -r)
KDIR := /lib/modules/$(KERNEL_VERSION)/build

all:
	@echo "Building patched CRB driver for kernel $(KERNEL_VERSION)..."
	$(MAKE) -C $(KDIR) M=$(PWD) modules

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean

install:
	@if [ ! -f tpm_crb_patched.ko ]; then \
		echo "ERROR: Module not built. Run 'make' first."; \
		exit 1; \
	fi
	sudo insmod tpm_crb_patched.ko crb_workaround_buffer_mismatch=1
	@echo "✓ Patched CRB driver loaded"
	dmesg | tail -10

EOF

# Rename the patched source
mv "${PATCHED_DIR}/tpm_crb.c" "${PATCHED_DIR}/tpm_crb_patched.c"

echo "Patched driver created in: ${PATCHED_DIR}"
echo ""
echo "To build and load:"
echo "  cd ${PATCHED_DIR}"
echo "  make"
echo "  sudo make install"
echo ""
echo "This will create a loadable module that can override the builtin CRB driver"
echo "behavior, allowing the TPM to work despite the firmware bug."
