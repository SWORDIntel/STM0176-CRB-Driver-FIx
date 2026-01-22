#!/bin/bash
#
# Build Patched CRB Driver Module
# ================================
#
# Builds a loadable CRB driver module with firmware bug workaround.
# Since tpm_crb is builtin, this creates an alternative implementation.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KERNEL_VERSION=$(uname -r)
KERNEL_SOURCE="/lib/modules/${KERNEL_VERSION}/build"

echo "=========================================="
echo "Building Patched CRB Driver"
echo "=========================================="
echo ""

if [ ! -d "$KERNEL_SOURCE" ]; then
    echo "ERROR: Kernel source not found"
    echo "Install: sudo apt install linux-headers-${KERNEL_VERSION}"
    exit 1
fi

# Create build directory
BUILD_DIR="${SCRIPT_DIR}/build"
mkdir -p "$BUILD_DIR"

# Copy CRB driver source and apply patch
echo "Preparing patched source..."
CRB_SOURCE=$(find /usr/src -name "tpm_crb.c" 2>/dev/null | head -1)
if [ -z "$CRB_SOURCE" ]; then
    echo "ERROR: tpm_crb.c not found in /usr/src"
    echo "Please install kernel source"
    exit 1
fi

cp "$CRB_SOURCE" "${BUILD_DIR}/tpm_crb_patched.c"

# Apply patch using sed
echo "Applying firmware bug workaround..."
sed -i '743,750c\
	/* According to the PTP specification, overlapping command and response\
	 * buffer sizes must be identical.\
	 */\
	/* WORKAROUND: STM0176 firmware bug - buffer sizes differ but TPM works */\
	if (cmd_size != rsp_size && cmd_pa == rsp_pa) {\
		u32 max_size = max(cmd_size, rsp_size);\
		dev_warn(dev, "Firmware bug: buffer size mismatch (cmd=%u, rsp=%u), using max=%u\\n",\
			 cmd_size, rsp_size, max_size);\
		cmd_size = rsp_size = max_size;\
	}\
\
	if (cmd_size != rsp_size) {\
		dev_err(dev, FW_BUG "overlapping command and response buffer sizes are not identical");\
		ret = -EINVAL;\
		goto out;\
	}' "${BUILD_DIR}/tpm_crb_patched.c"

# Create Makefile
cat > "${BUILD_DIR}/Makefile" << EOF
obj-m := tpm_crb_patched.o

PWD := \$(shell pwd)
KDIR := ${KERNEL_SOURCE}

tpm_crb_patched-objs := tpm_crb_patched.o

all:
	@echo "Building patched CRB driver..."
	\$(MAKE) -C \$(KDIR) M=\$(PWD) modules

clean:
	\$(MAKE) -C \$(KDIR) M=\$(PWD) clean
	rm -f *.ko *.o *.mod.c *.mod *.symvers *.order

EOF

# Build
echo "Building module..."
cd "$BUILD_DIR"
make

if [ -f "tpm_crb_patched.ko" ]; then
    echo ""
    echo "✓ Patched CRB driver built successfully!"
    echo "  Module: ${BUILD_DIR}/tpm_crb_patched.ko"
    echo ""
    echo "To load (WARNING: This may conflict with builtin driver):"
    echo "  sudo insmod ${BUILD_DIR}/tpm_crb_patched.ko"
    echo ""
    echo "NOTE: Since tpm_crb is builtin, you may need to:"
    echo "  1. Blacklist the builtin driver in kernel config"
    echo "  2. Or rebuild kernel with this patch applied"
    echo "  3. Or use I2C TPM driver instead (if TPM supports I2C)"
else
    echo "✗ Build failed"
    exit 1
fi
