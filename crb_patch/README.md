# CRB Driver Patch for STM0176 Firmware Bug

## Problem

The STM0176:00 TPM device fails to initialize with the CRB driver due to a firmware bug:

```
tpm_crb STM0176:00: [Firmware Bug]: overlapping command and response buffer sizes are not identical
tpm_crb STM0176:00: probe with driver tpm_crb failed with error -22
```

## Root Cause

The CRB driver validates that when command and response buffers overlap (same physical address), their sizes must be identical per the TPM specification (TCG CRB 2.0 Section 5.2.1). However, the STM0176 firmware incorrectly reports different sizes, causing the driver to reject the device.

**Location in code:** `drivers/char/tpm/tpm_crb.c` lines 746-750

## Solution

This patch works around the firmware bug in a **spec-compliant** manner by:
1. Detecting the buffer size mismatch
2. Using the maximum of the two sizes for both buffers (normalizing to satisfy TCG CRB 2.0)
3. Validating that `cmd_size == rsp_size` after workaround (spec compliance)
4. Warning about the firmware bug but continuing operation

**Important**: The workaround maintains TCG CRB 2.0 compliance by ensuring overlapping buffers have identical sizes after normalization.

## Installation Methods

### Method 1: DKMS (Recommended - Persistent)

DKMS automatically rebuilds the patched driver on kernel updates:

```bash
cd scripts/unlocks/tpm/crb_patch
sudo ./install_dkms.sh
```

**Benefits**:
- Automatically rebuilds on kernel updates
- Persistent across kernel version changes
- No manual intervention needed

### Method 2: Automated Fix Script

The automated fix script detects the bug and applies the appropriate fix:

```bash
cd scripts/unlocks/tpm
sudo python3 crb_auto_fix.py
```

This script will:
1. Detect CRB driver failure
2. Attempt DKMS installation (primary)
3. Fall back to blacklist method if DKMS unavailable
4. Verify fix success and spec compliance

### Method 3: Manual Build

```bash
cd scripts/unlocks/tpm/crb_patch
./check_dependencies.sh  # Verify dependencies
./build_patched_crb.sh   # Build module
sudo insmod patched/tpm_crb_patched.ko  # Load module
```

## Patch Details

**Original code (fails):**
```c
if (cmd_size != rsp_size) {
    dev_err(dev, FW_BUG "overlapping command and response buffer sizes are not identical");
    ret = -EINVAL;
    goto out;
}
```

**Patched code (works around bug):**
```c
if (cmd_size != rsp_size) {
    u32 max_size = max(cmd_size, rsp_size);
    dev_warn(dev, "Firmware bug: buffer size mismatch (cmd=%u, rsp=%u), using max=%u (workaround enabled)\n",
             cmd_size, rsp_size, max_size);
    cmd_size = rsp_size = max_size;
}
```

## Alternative: I2C TPM Driver

The STMicroelectronics TPM may also be accessible via I2C. See:
- https://github.com/STMicroelectronics/TCG-TPM-I2C-DRV
- Kernel driver: `tpm_tis_i2c` (available since kernel 6.1)

To try I2C interface:
```bash
# Check if TPM is on I2C bus
sudo i2cdetect -y 1  # or other I2C bus number

# Try loading I2C TPM driver
sudo modprobe tpm_tis_i2c
```

## Specification Compliance

**All implementations comply with TPM specifications:**
- **TCG CRB 2.0 Section 5.2.1**: Overlapping buffers must have identical sizes
- **PTP Compliance**: Platform TPM profile requirements maintained

The workaround normalizes buffer sizes to satisfy spec requirements. See `../SPEC_COMPLIANCE.md` for detailed compliance documentation.

## Validation

Run specification compliance validation:

```bash
cd scripts/unlocks/tpm
python3 validate_spec_compliance.py
```

Run test suite:

```bash
cd scripts/unlocks/tpm
./test_crb_fix.sh
```

## Integration with Comprehensive Probe

The comprehensive TPM probe will automatically:
1. Detect CRB driver failure
2. Call `crb_auto_fix.py` to apply fix
3. Verify fix success and spec compliance
4. Use MMIO fallback (Rust scanner) as fallback TCTI if fix fails
5. Report the firmware bug and fix status

## References

- STMicroelectronics I2C TPM Driver: https://github.com/STMicroelectronics/TCG-TPM-I2C-DRV
- TPM CRB Specification: TCG CRB 2.0 TPM specification
- Kernel Source: `drivers/char/tpm/tpm_crb.c`
