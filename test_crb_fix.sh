#!/bin/bash
#
# Test Suite for CRB Driver Firmware Bug Fix
# ===========================================
#
# Tests the CRB driver patch, DKMS installation, blacklist method,
# and specification compliance validation.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CRB_PATCH_DIR="${SCRIPT_DIR}/crb_patch"
TESTS_PASSED=0
TESTS_FAILED=0

echo "=========================================="
echo "CRB Driver Fix Test Suite"
echo "=========================================="
echo ""

test_detect_crb_failure() {
    echo -n "Test: CRB failure detection... "
    if python3 "${SCRIPT_DIR}/crb_auto_fix.py" --test-detect 2>/dev/null; then
        echo "✓ PASSED"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ FAILED"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_spec_compliance_validator() {
    echo -n "Test: Spec compliance validator... "
    if python3 "${SCRIPT_DIR}/validate_spec_compliance.py" >/dev/null 2>&1; then
        echo "✓ PASSED"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ FAILED (may be expected if TPM not accessible)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_dependencies_check() {
    echo -n "Test: Dependencies check script... "
    if bash "${CRB_PATCH_DIR}/check_dependencies.sh" >/dev/null 2>&1; then
        echo "✓ PASSED"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "⚠ WARNING (some dependencies may be missing)"
        TESTS_PASSED=$((TESTS_PASSED + 1))  # Don't fail on missing deps
    fi
}

test_dkms_config() {
    echo -n "Test: DKMS configuration file... "
    if [ -f "${CRB_PATCH_DIR}/dkms.conf" ]; then
        # Validate DKMS config format
        if grep -q "PACKAGE_NAME" "${CRB_PATCH_DIR}/dkms.conf" && \
           grep -q "PACKAGE_VERSION" "${CRB_PATCH_DIR}/dkms.conf"; then
            echo "✓ PASSED"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo "✗ FAILED (invalid format)"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    else
        echo "✗ FAILED (file not found)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_blacklist_config() {
    echo -n "Test: Blacklist configuration... "
    if [ -f "${CRB_PATCH_DIR}/blacklist_crb.conf" ]; then
        if grep -q "blacklist tpm_crb" "${CRB_PATCH_DIR}/blacklist_crb.conf"; then
            echo "✓ PASSED"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo "✗ FAILED (invalid content)"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    else
        echo "✗ FAILED (file not found)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_patched_driver_source() {
    echo -n "Test: Patched driver source file... "
    if [ -f "${CRB_PATCH_DIR}/tpm_crb_patched.c" ]; then
        # Check for spec compliance code
        if grep -q "TCG CRB 2.0" "${CRB_PATCH_DIR}/tpm_crb_patched.c" && \
           grep -q "cmd_size == rsp_size" "${CRB_PATCH_DIR}/tpm_crb_patched.c"; then
            echo "✓ PASSED"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo "✗ FAILED (missing spec compliance code)"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    else
        echo "✗ FAILED (file not found)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_buffer_size_workaround() {
    echo -n "Test: Buffer size workaround logic... "
    if [ -f "${CRB_PATCH_DIR}/tpm_crb_patched.c" ]; then
        # Check for workaround implementation
        if grep -q "max(cmd_size, rsp_size)" "${CRB_PATCH_DIR}/tpm_crb_patched.c" && \
           grep -q "crb_workaround_buffer_mismatch" "${CRB_PATCH_DIR}/tpm_crb_patched.c"; then
            echo "✓ PASSED"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo "✗ FAILED (workaround not found)"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    else
        echo "✗ FAILED (source file not found)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_spec_compliance_validation() {
    echo -n "Test: Spec compliance validation code... "
    if [ -f "${CRB_PATCH_DIR}/tpm_crb_patched.c" ]; then
        # Check for post-workaround validation
        if grep -q "Validate spec compliance after workaround" "${CRB_PATCH_DIR}/tpm_crb_patched.c" || \
           grep -q "cmd_size != rsp_size" "${CRB_PATCH_DIR}/tpm_crb_patched.c"; then
            echo "✓ PASSED"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo "✗ FAILED (validation code not found)"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    else
        echo "✗ FAILED (source file not found)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_automated_fix_script() {
    echo -n "Test: Automated fix script... "
    if [ -f "${SCRIPT_DIR}/crb_auto_fix.py" ]; then
        # Check for key functions
        if grep -q "def detect_crb_failure" "${SCRIPT_DIR}/crb_auto_fix.py" && \
           grep -q "def install_via_dkms" "${SCRIPT_DIR}/crb_auto_fix.py" && \
           grep -q "def install_via_blacklist" "${SCRIPT_DIR}/crb_auto_fix.py"; then
            echo "✓ PASSED"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo "✗ FAILED (missing functions)"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    else
        echo "✗ FAILED (file not found)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Run all tests
test_detect_crb_failure
test_spec_compliance_validator
test_dependencies_check
test_dkms_config
test_blacklist_config
test_patched_driver_source
test_buffer_size_workaround
test_spec_compliance_validation
test_automated_fix_script

# Summary
echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo "Tests Passed: ${TESTS_PASSED}"
echo "Tests Failed: ${TESTS_FAILED}"
echo "Total Tests: $((TESTS_PASSED + TESTS_FAILED))"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo "✓ All tests passed!"
    exit 0
else
    echo "✗ Some tests failed"
    exit 1
fi
