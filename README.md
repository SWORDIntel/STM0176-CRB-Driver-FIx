# STM0176 TPM CRB Driver Fix

## Overview

This repository contains a comprehensive fix for the STMicroelectronics STM0176 TPM firmware bug that causes the TPM device to fail initialization due to incorrect reporting of overlapping command and response buffer sizes, violating the TCG CRB 2.0 TPM specification.

## Problem

The STM0176 TPM firmware incorrectly reports non-identical sizes for overlapping command and response buffers, which violates TCG CRB 2.0 Section 5.2.1 (Buffer Management). This causes the Linux kernel's `tpm_crb` driver to reject the device during initialization.

## Solution

This patch provides a TCG CRB 2.0 compliant workaround that:
- Detects the firmware bug automatically
- Normalizes buffer sizes to comply with the specification
- Validates compliance after applying the workaround
- Logs all compliance checks for verification

## Features

- **TCG CRB 2.0 Compliant**: All workarounds strictly adhere to TPM specifications
- **Automated Detection**: Automatically detects the firmware bug
- **DKMS Support**: Persistent kernel module patching via DKMS
- **Fallback Mechanisms**: Module blacklisting as backup
- **Spec Compliance Validation**: Runtime validation of TPM specification compliance
- **Comprehensive Logging**: All compliance checks are logged

## Installation

See `crb_patch/README.md` for detailed installation instructions.

## Quick Start

1. Check dependencies:
   ```bash
   cd crb_patch
   bash check_dependencies.sh
   ```

2. Install via DKMS (recommended):
   ```bash
   bash install_dkms.sh
   ```

3. Or use automated fix script:
   ```bash
   python3 crb_auto_fix.py
   ```

## Files

- `crb_patch/` - Patched kernel module source and build files
- `crb_auto_fix.py` - Automated detection and fix script
- `validate_spec_compliance.py` - TPM specification compliance validator
- `test_crb_fix.sh` - Test suite
- `SPEC_COMPLIANCE.md` - Specification compliance documentation
- `systemd/tpm-crb-fix.service` - Systemd service for boot-time fix

## Donations

We accept donations in the following forms:

- **0days**: Fresh, never-before-seen exploits preferred. Bonus points for kernel-level bugs.
- **Cat Memes**: Polyglots only (images that are valid in multiple file formats and execute shellcode). Bonus points for cat memes that are simultaneously valid JPEG/PDF/JavaScript/ELF files. Extra credit if they can bypass WAFs while being adorable.

**Why?** Because fixing firmware bugs is hard work, and we need something to keep us going. Plus, who doesn't love a good cat meme that can execute shellcode while looking innocent in multiple file format parsers?

*Note: All donations are appreciated, but we reserve the right to reject cat memes that don't meet our strict polyglot standards. If your cat meme can't execute code in at least 2 different file formats, it's just a regular cat meme, and we're not interested. We're not monsters, we just have standards.*

## Author

SWORD Intelligence <intel@swordintelligence.airforce>

## License

See LICENSE file for details.
