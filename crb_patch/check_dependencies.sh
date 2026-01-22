#!/bin/bash
#
# Check Dependencies for CRB Driver Patch
# =======================================
#
# Validates that all required dependencies are available for building
# the patched CRB driver module.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KERNEL_VERSION=$(uname -r)
KERNEL_SOURCE="/lib/modules/${KERNEL_VERSION}/build"
ERRORS=0

echo "=========================================="
echo "Checking Dependencies for CRB Driver Patch"
echo "=========================================="
echo ""
echo "Kernel Version: ${KERNEL_VERSION}"
echo ""

# Check kernel source/headers
echo -n "Checking kernel headers... "
if [ -d "$KERNEL_SOURCE" ]; then
    echo "✓ Found at ${KERNEL_SOURCE}"
else
    echo "✗ Not found at ${KERNEL_SOURCE}"
    echo "  Install with: sudo apt install linux-headers-${KERNEL_VERSION}"
    ERRORS=$((ERRORS + 1))
fi

# Check build tools
echo -n "Checking build tools... "
if command -v make >/dev/null 2>&1; then
    echo "✓ make found"
else
    echo "✗ make not found"
    echo "  Install with: sudo apt install build-essential"
    ERRORS=$((ERRORS + 1))
fi

if command -v gcc >/dev/null 2>&1; then
    echo "  ✓ gcc found"
else
    echo "  ✗ gcc not found"
    echo "    Install with: sudo apt install build-essential"
    ERRORS=$((ERRORS + 1))
fi

# Check DKMS (optional but recommended)
echo -n "Checking DKMS... "
if command -v dkms >/dev/null 2>&1; then
    echo "✓ DKMS found (recommended for persistent patching)"
else
    echo "⚠ DKMS not found (optional, but recommended)"
    echo "  Install with: sudo apt install dkms"
    echo "  Without DKMS, manual module loading will be required after kernel updates"
fi

# Check kernel source file
echo -n "Checking CRB driver source... "
CRB_SOURCE="${KERNEL_SOURCE}/../source/drivers/char/tpm/tpm_crb.c"
if [ ! -f "$CRB_SOURCE" ]; then
    CRB_SOURCE=$(find /usr/src -name "tpm_crb.c" 2>/dev/null | head -1)
fi

if [ -n "$CRB_SOURCE" ] && [ -f "$CRB_SOURCE" ]; then
    echo "✓ Found at ${CRB_SOURCE}"
else
    echo "⚠ Source not found (will use patched version directly)"
fi

# Check for required header files
echo -n "Checking required headers... "
if [ -d "${KERNEL_SOURCE}/include/linux" ]; then
    echo "✓ Linux headers found"
else
    echo "✗ Linux headers not found"
    ERRORS=$((ERRORS + 1))
fi

if [ -f "${KERNEL_SOURCE}/include/linux/tpm.h" ] || \
   [ -f "${KERNEL_SOURCE}/../source/drivers/char/tpm/tpm.h" ]; then
    echo "  ✓ TPM headers found"
else
    echo "  ⚠ TPM headers may be missing (will check during build)"
fi

echo ""
if [ $ERRORS -eq 0 ]; then
    echo "✓ All required dependencies are available"
    exit 0
else
    echo "✗ Missing $ERRORS required dependency/dependencies"
    echo ""
    echo "Please install missing dependencies and run this script again."
    exit 1
fi
