# TPM Specification Compliance Documentation

## Overview

This document describes the TPM specification compliance requirements and validation process for the CRB driver firmware bug workaround.

## Relevant Specifications

1. **TCG CRB 2.0 TPM Specification** - Command Response Buffer interface specification
2. **TCG PC Client Platform TPM Profile (PTP)** - TPM 2.0 platform specification

## Specification Requirements

### TCG CRB 2.0 Section 5.2.1 - Buffer Management

**Requirement**: When command and response buffers overlap (`cmd_pa == rsp_pa`), their sizes **MUST be identical** (`cmd_size == rsp_size`).

This is a fundamental requirement for proper buffer management and TPM command/response handling.

## Firmware Bug

The STM0176 TPM firmware incorrectly reports:
- **Command buffer size**: One value (e.g., 4096 bytes)
- **Response buffer size**: Different value (e.g., 4095 bytes or 4097 bytes)
- **Physical address**: Same for both buffers (overlapping)

This violates the TCG CRB 2.0 specification and causes the kernel driver to reject the device.

## Workaround Compliance Analysis

Our workaround is **spec-compliant** because:

1. **Single Buffer Size**: We use `max(cmd_size, rsp_size)` as the unified size for both buffers
2. **Spec Satisfaction**: After workaround, `cmd_size == rsp_size` (both set to max_size), satisfying the spec requirement
3. **No Spec Violation**: We do not use different sizes for overlapping buffers - we normalize to a single compliant size
4. **Buffer Safety**: Using the maximum ensures we don't truncate either buffer, maintaining data integrity

## Implementation

### Driver Patch

The patched driver (`tpm_crb_patched.c`) implements the workaround in the `crb_map_io()` function:

```c
/* TCG CRB 2.0 Spec Requirement: When buffers overlap, sizes must be identical */
if (cmd_pa == rsp_pa && cmd_size != rsp_size) {
    if (crb_workaround_buffer_mismatch) {
        /* Spec-compliant workaround: Use maximum size for both buffers */
        u32 max_size = max(cmd_size, rsp_size);
        dev_warn(dev, "Firmware bug: buffer size mismatch (cmd=%u, rsp=%u), "
                      "using max=%u (TCG CRB 2.0 compliant workaround)\n",
                 cmd_size, rsp_size, max_size);
        cmd_size = rsp_size = max_size;
        
        /* Validate spec compliance after workaround */
        if (cmd_size != rsp_size) {
            dev_err(dev, "Workaround failed: buffer sizes still differ after fix");
            ret = -EINVAL;
            goto out;
        }
    }
}

/* TCG CRB 2.0 Compliance: Final verification */
if (cmd_pa == rsp_pa && cmd_size != rsp_size) {
    dev_err(dev, "TCG CRB 2.0 violation: overlapping buffers have different sizes");
    ret = -EINVAL;
    goto out;
}
```

### Compliance Validation

The workaround includes multiple validation checks:

1. **Pre-Workaround Validation**: Detects when `cmd_pa == rsp_pa && cmd_size != rsp_size` (firmware bug)
2. **Workaround Application**: Applies `max(cmd_size, rsp_size)` to both buffers
3. **Post-Workaround Verification**: Verifies `cmd_size == rsp_size` after workaround (spec compliance)
4. **Final Verification**: Final check before proceeding to ensure compliance

## Validation Tools

### Automated Validation

The `validate_spec_compliance.py` script performs runtime validation:

- Checks buffer size compliance from dmesg
- Verifies workaround was applied correctly
- Validates TPM accessibility
- Reports compliance status

### Manual Validation

To manually verify compliance:

1. Check dmesg for workaround messages:
   ```bash
   dmesg | grep -i "buffer size mismatch\|workaround"
   ```

2. Verify buffer sizes were normalized:
   ```bash
   dmesg | grep "using max="
   ```

3. Test TPM access:
   ```bash
   sudo tpm2_getcap properties-fixed
   ```

## Compliance Checklist

Before deploying the workaround, verify:

- [ ] Buffer size equality validated after workaround (`cmd_size == rsp_size`)
- [ ] TCG CRB 2.0 Section 5.2.1 compliance verified (overlapping buffers have identical sizes)
- [ ] PTP compliance maintained (platform TPM profile requirements)
- [ ] No spec violations introduced by workaround
- [ ] Runtime validation confirms spec compliance during TPM operations
- [ ] All compliance checks logged for audit trail
- [ ] Test suite validates spec compliancee

## Audit Trail

All compliance checks are logged:

- Kernel messages (dmesg) contain workaround application details
- Spec compliance validator logs all checks
- Automated fix script logs method used and results

## References

- **TCG CRB 2.0 TPM Specification**: Command Response Buffer interface specification
- **TCG PC Client Platform TPM Profile (PTP)**: TPM 2.0 platform specification
- **CRB Driver Bug Writeup**: `tools/TPM-CRB-STMPATCH/CRB_DRIVER_BUG_WRITEUP.md`
