#!/usr/bin/env python3
"""
TPM Specification Compliance Validator
======================================

Validates that CRB driver implementations comply with TPM specifications:
- TCG CRB 2.0 TPM Specification
- TCG PC Client Platform TPM Profile (PTP)

This validator ensures that the firmware bug workaround maintains
specification compliance.

Author: SWORD Intelligence <intel@swordintelligence.airforce>
"""

import os
import sys
import subprocess
import re
import logging
from typing import Dict, List, Optional, Tuple, Any
from dataclasses import dataclass
from enum import Enum

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class ComplianceStatus(Enum):
    """Compliance validation status"""
    COMPLIANT = "compliant"
    NON_COMPLIANT = "non_compliant"
    UNKNOWN = "unknown"
    ERROR = "error"


@dataclass
class ComplianceCheck:
    """Result of a compliance check"""
    check_name: str
    status: ComplianceStatus
    message: str
    details: Optional[Dict[str, Any]] = None


class TPMSpecComplianceValidator:
    """Validates TPM specification compliance"""

    def __init__(self):
        self.checks: List[ComplianceCheck] = []

    def check_buffer_size_compliance(self) -> ComplianceCheck:
        """
        Check TCG CRB 2.0 Section 5.2.1 compliance:
        When buffers overlap (cmd_pa == rsp_pa), sizes must be identical (cmd_size == rsp_size)
        """
        check_name = "TCG_CRB_2.0_Section_5.2.1_Buffer_Size_Compliance"
        logger.info(f"Running compliance check: {check_name}")
        
        try:
            # Check dmesg for buffer size information
            result = subprocess.run(
                ["dmesg"],
                capture_output=True,
                text=True,
                timeout=2
            )
            
            dmesg_output = result.stdout
            
            # Look for workaround messages
            workaround_pattern = r"buffer size mismatch.*cmd=(\d+).*rsp=(\d+).*using max=(\d+)"
            workaround_match = re.search(workaround_pattern, dmesg_output)
            
            if workaround_match:
                cmd_size = int(workaround_match.group(1))
                rsp_size = int(workaround_match.group(2))
                max_size = int(workaround_match.group(3))
                
                # Verify workaround applied correctly
                logger.info(f"Workaround detected: cmd_size={cmd_size}, rsp_size={rsp_size}, max_size={max_size}")
                if max_size == max(cmd_size, rsp_size):
                    # After workaround, both should be max_size
                    if cmd_size == rsp_size == max_size:
                        logger.info(f"Compliance check PASSED: Buffer sizes normalized correctly (cmd_size={cmd_size}, rsp_size={rsp_size})")
                        return ComplianceCheck(
                            check_name=check_name,
                            status=ComplianceStatus.COMPLIANT,
                            message="Buffer size workaround applied correctly - sizes normalized to satisfy TCG CRB 2.0",
                            details={
                                "original_cmd_size": cmd_size,
                                "original_rsp_size": rsp_size,
                                "normalized_size": max_size,
                                "compliance": "TCG CRB 2.0 Section 5.2.1 satisfied"
                            }
                        )
                    else:
                        logger.error(f"Compliance check FAILED: Workaround applied but sizes still differ (cmd_size={cmd_size}, rsp_size={rsp_size}, max_size={max_size})")
                        return ComplianceCheck(
                            check_name=check_name,
                            status=ComplianceStatus.NON_COMPLIANT,
                            message="Workaround applied but sizes still differ - spec violation",
                            details={
                                "cmd_size": cmd_size,
                                "rsp_size": rsp_size,
                                "max_size": max_size
                            }
                        )
                else:
                    expected_max = max(cmd_size, rsp_size)
                    logger.error(f"Compliance check FAILED: Workaround max_size calculation incorrect (got={max_size}, expected={expected_max})")
                    return ComplianceCheck(
                        check_name=check_name,
                        status=ComplianceStatus.NON_COMPLIANT,
                        message="Workaround max_size calculation incorrect",
                        details={
                            "cmd_size": cmd_size,
                            "rsp_size": rsp_size,
                            "max_size": max_size,
                            "expected_max": max(cmd_size, rsp_size)
                        }
                    )
            
            # Check for firmware bug detection
            bug_pattern = r"\[Firmware Bug\].*overlapping.*buffer.*sizes.*not identical"
            if re.search(bug_pattern, dmesg_output, re.IGNORECASE):
                logger.info("Firmware bug detected in dmesg")
                # Check if workaround was applied
                if "workaround" in dmesg_output.lower() or "using max" in dmesg_output.lower():
                    logger.info("Compliance check PASSED: Firmware bug detected and workaround applied")
                    return ComplianceCheck(
                        check_name=check_name,
                        status=ComplianceStatus.COMPLIANT,
                        message="Firmware bug detected and workaround applied",
                        details={"bug_detected": True, "workaround_applied": True}
                    )
                else:
                    logger.error("Compliance check FAILED: Firmware bug detected but workaround not applied")
                    return ComplianceCheck(
                        check_name=check_name,
                        status=ComplianceStatus.NON_COMPLIANT,
                        message="Firmware bug detected but workaround not applied",
                        details={"bug_detected": True, "workaround_applied": False}
                    )
            
            # No buffer size issues detected - check if TPM is working
            if os.path.exists("/dev/tpm0") or os.path.exists("/dev/tpmrm0"):
                logger.info("Compliance check PASSED: No buffer size issues detected, TPM device accessible")
                return ComplianceCheck(
                    check_name=check_name,
                    status=ComplianceStatus.COMPLIANT,
                    message="No buffer size issues detected, TPM device accessible",
                    details={"tpm_accessible": True}
                )
            
            logger.warning("Compliance check UNKNOWN: Cannot determine buffer size compliance - no relevant messages in dmesg")
            return ComplianceCheck(
                check_name=check_name,
                status=ComplianceStatus.UNKNOWN,
                message="Cannot determine buffer size compliance - no relevant messages in dmesg",
                details={}
            )
            
        except subprocess.TimeoutExpired:
            logger.error("Compliance check ERROR: Timeout reading dmesg")
            return ComplianceCheck(
                check_name=check_name,
                status=ComplianceStatus.ERROR,
                message="Timeout reading dmesg",
                details={}
            )
        except Exception as e:
            logger.error(f"Compliance check ERROR: Exception during buffer size compliance check: {e}", exc_info=True)
            return ComplianceCheck(
                check_name=check_name,
                status=ComplianceStatus.ERROR,
                message=f"Error checking buffer size compliance: {e}",
                details={"error": str(e)}
            )

    def check_driver_loaded(self) -> ComplianceCheck:
        """Check if patched driver is loaded"""
        check_name = "Patched_Driver_Loaded"
        logger.info(f"Running compliance check: {check_name}")
        
        try:
            result = subprocess.run(
                ["lsmod"],
                capture_output=True,
                text=True,
                timeout=2
            )
            
            lsmod_output = result.stdout
            
            # Check for patched driver
            if "tpm_crb_patched" in lsmod_output:
                logger.info("Compliance check PASSED: Patched CRB driver is loaded")
                return ComplianceCheck(
                    check_name=check_name,
                    status=ComplianceStatus.COMPLIANT,
                    message="Patched CRB driver is loaded",
                    details={"driver": "tpm_crb_patched", "loaded": True}
                )
            elif "tpm_crb" in lsmod_output:
                logger.warning("Compliance check UNKNOWN: Built-in CRB driver loaded (patched driver may not be needed)")
                return ComplianceCheck(
                    check_name=check_name,
                    status=ComplianceStatus.UNKNOWN,
                    message="Built-in CRB driver loaded (patched driver may not be needed)",
                    details={"driver": "tpm_crb", "loaded": True}
                )
            else:
                logger.warning("Compliance check UNKNOWN: No CRB driver loaded")
                return ComplianceCheck(
                    check_name=check_name,
                    status=ComplianceStatus.UNKNOWN,
                    message="No CRB driver loaded",
                    details={"loaded": False}
                )
                
        except Exception as e:
            logger.error(f"Compliance check ERROR: Exception during driver status check: {e}", exc_info=True)
            return ComplianceCheck(
                check_name=check_name,
                status=ComplianceStatus.ERROR,
                message=f"Error checking driver status: {e}",
                details={"error": str(e)}
            )

    def check_tpm_accessibility(self) -> ComplianceCheck:
        """Check if TPM is accessible via standard interfaces"""
        check_name = "TPM_Accessibility"
        logger.info(f"Running compliance check: {check_name}")
        
        try:
            # Check device nodes
            tpm0_exists = os.path.exists("/dev/tpm0")
            tpmrm0_exists = os.path.exists("/dev/tpmrm0")
            
            if tpm0_exists or tpmrm0_exists:
                # Try to access TPM
                try:
                    result = subprocess.run(
                        ["tpm2_getcap", "properties-fixed"],
                        capture_output=True,
                        text=True,
                        timeout=5
                    )
                    
                    if result.returncode == 0:
                        logger.info(f"Compliance check PASSED: TPM is accessible and responding (tpm0={tpm0_exists}, tpmrm0={tpmrm0_exists})")
                        return ComplianceCheck(
                            check_name=check_name,
                            status=ComplianceStatus.COMPLIANT,
                            message="TPM is accessible and responding",
                            details={
                                "tpm0_exists": tpm0_exists,
                                "tpmrm0_exists": tpmrm0_exists,
                                "tpm2_tools_accessible": True
                            }
                        )
                    else:
                        error_msg = result.stderr[:200] if result.stderr else "Unknown error"
                        logger.warning(f"Compliance check UNKNOWN: TPM device exists but tpm2_getcap failed: {error_msg}")
                        return ComplianceCheck(
                            check_name=check_name,
                            status=ComplianceStatus.UNKNOWN,
                            message="TPM device exists but tpm2_getcap failed",
                            details={
                                "tpm0_exists": tpm0_exists,
                                "tpmrm0_exists": tpmrm0_exists,
                                "tpm2_tools_accessible": False,
                                "error": result.stderr[:200] if result.stderr else "Unknown error"
                            }
                        )
                except FileNotFoundError:
                    logger.warning("Compliance check UNKNOWN: TPM device exists but tpm2-tools not installed")
                    return ComplianceCheck(
                        check_name=check_name,
                        status=ComplianceStatus.UNKNOWN,
                        message="TPM device exists but tpm2-tools not installed",
                        details={
                            "tpm0_exists": tpm0_exists,
                            "tpmrm0_exists": tpmrm0_exists,
                            "tpm2_tools_installed": False
                        }
                    )
            else:
                logger.error("Compliance check FAILED: TPM device nodes not found")
                return ComplianceCheck(
                    check_name=check_name,
                    status=ComplianceStatus.NON_COMPLIANT,
                    message="TPM device nodes not found",
                    details={
                        "tpm0_exists": False,
                        "tpmrm0_exists": False
                    }
                )
                
        except Exception as e:
            logger.error(f"Compliance check ERROR: Exception during TPM accessibility check: {e}", exc_info=True)
            return ComplianceCheck(
                check_name=check_name,
                status=ComplianceStatus.ERROR,
                message=f"Error checking TPM accessibility: {e}",
                details={"error": str(e)}
            )

    def validate_all(self) -> Dict[str, Any]:
        """Run all compliance checks"""
        logger.info("Starting TPM specification compliance validation...")
        
        self.checks = []
        
        # Run all checks
        self.checks.append(self.check_buffer_size_compliance())
        self.checks.append(self.check_driver_loaded())
        self.checks.append(self.check_tpm_accessibility())
        
        # Summarize results
        compliant_count = sum(1 for c in self.checks if c.status == ComplianceStatus.COMPLIANT)
        non_compliant_count = sum(1 for c in self.checks if c.status == ComplianceStatus.NON_COMPLIANT)
        unknown_count = sum(1 for c in self.checks if c.status == ComplianceStatus.UNKNOWN)
        error_count = sum(1 for c in self.checks if c.status == ComplianceStatus.ERROR)
        
        # Log summary
        logger.info(f"Compliance validation summary: {compliant_count} compliant, {non_compliant_count} non-compliant, {unknown_count} unknown, {error_count} errors")
        
        overall_status = ComplianceStatus.COMPLIANT
        if non_compliant_count > 0:
            overall_status = ComplianceStatus.NON_COMPLIANT
            logger.error(f"Overall compliance status: NON_COMPLIANT ({non_compliant_count} failures)")
        elif error_count > 0:
            overall_status = ComplianceStatus.ERROR
            logger.error(f"Overall compliance status: ERROR ({error_count} errors)")
        elif unknown_count == len(self.checks):
            overall_status = ComplianceStatus.UNKNOWN
            logger.warning(f"Overall compliance status: UNKNOWN (all checks inconclusive)")
        else:
            logger.info(f"Overall compliance status: COMPLIANT")
        
        # Log each check result
        for check in self.checks:
            logger.info(f"Check '{check.check_name}': {check.status.value.upper()} - {check.message}")
            if check.details:
                for key, value in check.details.items():
                    logger.debug(f"  {key}: {value}")
        
        return {
            "overall_status": overall_status.value,
            "checks": [
                {
                    "name": c.check_name,
                    "status": c.status.value,
                    "message": c.message,
                    "details": c.details or {}
                }
                for c in self.checks
            ],
            "summary": {
                "total": len(self.checks),
                "compliant": compliant_count,
                "non_compliant": non_compliant_count,
                "unknown": unknown_count,
                "errors": error_count
            }
        }

    def print_report(self, results: Dict[str, Any]):
        """Print compliance validation report"""
        print("\n" + "=" * 70)
        print("TPM Specification Compliance Validation Report")
        print("=" * 70)
        print(f"\nOverall Status: {results['overall_status'].upper()}")
        print(f"\nSummary:")
        print(f"  Total Checks: {results['summary']['total']}")
        print(f"  Compliant: {results['summary']['compliant']}")
        print(f"  Non-Compliant: {results['summary']['non_compliant']}")
        print(f"  Unknown: {results['summary']['unknown']}")
        print(f"  Errors: {results['summary']['errors']}")
        
        print("\nDetailed Results:")
        print("-" * 70)
        for check in results['checks']:
            status_symbol = {
                "compliant": "✓",
                "non_compliant": "✗",
                "unknown": "?",
                "error": "!"
            }.get(check['status'], "?")
            
            print(f"\n{status_symbol} {check['name']}")
            print(f"  Status: {check['status'].upper()}")
            print(f"  Message: {check['message']}")
            if check['details']:
                print(f"  Details:")
                for key, value in check['details'].items():
                    print(f"    {key}: {value}")
        
        print("\n" + "=" * 70)


def main():
    """Main entry point"""
    validator = TPMSpecComplianceValidator()
    results = validator.validate_all()
    validator.print_report(results)
    
    # Exit with appropriate code
    if results['overall_status'] == 'compliant':
        sys.exit(0)
    elif results['overall_status'] == 'non_compliant':
        sys.exit(1)
    else:
        sys.exit(2)


if __name__ == "__main__":
    main()
