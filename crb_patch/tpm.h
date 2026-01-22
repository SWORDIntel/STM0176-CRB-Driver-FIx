/* SPDX-License-Identifier: GPL-2.0-only */
/*
 * Complete TPM header for patched CRB driver
 * Provides all necessary definitions when building as external module
 */

#ifndef _TPM_H
#define _TPM_H

#include <linux/device.h>
#include <linux/module.h>
#include <linux/acpi.h>
#include <linux/types.h>
#include <linux/io.h>

/* TPM header size */
#define TPM_HEADER_SIZE 10

/* TPM2 timeout values */
#define TPM2_TIMEOUT_A 750
#define TPM2_TIMEOUT_B 2000
#define TPM2_TIMEOUT_C 750
#define TPM2_TIMEOUT_D 750

/* TPM chip flags */
#define TPM_CHIP_FLAG_TPM2		BIT(0)
#define TPM_CHIP_FLAG_HWRNG_DISABLED	BIT(1)

/* TPM operations flags */
#define TPM_OPS_AUTO_STARTUP		BIT(0)

/* ACPI TPM2 start method constants - from include/acpi/actbl3.h */
#ifndef ACPI_TPM2_START_METHOD
#define ACPI_TPM2_START_METHOD		2
#endif
#ifndef ACPI_TPM2_MEMORY_MAPPED
#define ACPI_TPM2_MEMORY_MAPPED		6
#endif
#ifndef ACPI_TPM2_COMMAND_BUFFER
#define ACPI_TPM2_COMMAND_BUFFER	7
#endif
#ifndef ACPI_TPM2_COMMAND_BUFFER_WITH_START_METHOD
#define ACPI_TPM2_COMMAND_BUFFER_WITH_START_METHOD	8
#endif
#ifndef ACPI_TPM2_COMMAND_BUFFER_WITH_ARM_SMC
#define ACPI_TPM2_COMMAND_BUFFER_WITH_ARM_SMC	11
#endif
#ifndef ACPI_TPM2_COMMAND_BUFFER_WITH_PLUTON
#define ACPI_TPM2_COMMAND_BUFFER_WITH_PLUTON	13
#endif
#ifndef ACPI_TPM2_CRB_WITH_ARM_FFA
#define ACPI_TPM2_CRB_WITH_ARM_FFA	15
#endif

/* Forward declarations */
struct tpm_chip;
struct tpm_class_ops;

/* TPM chip structure */
struct tpm_chip {
	struct device dev;
	acpi_handle acpi_dev_handle;
	unsigned int flags;
	int locality;
	const struct tpm_class_ops *ops;
};

/* TPM class operations */
struct tpm_class_ops {
	unsigned int flags;
	u8 (*status)(struct tpm_chip *chip);
	int (*recv)(struct tpm_chip *chip, u8 *buf, size_t count);
	int (*send)(struct tpm_chip *chip, u8 *buf, size_t bufsiz, size_t len);
	void (*cancel)(struct tpm_chip *chip);
	bool (*req_canceled)(struct tpm_chip *chip, u8 status);
	int (*go_idle)(struct tpm_chip *chip);
	int (*cmd_ready)(struct tpm_chip *chip);
	int (*request_locality)(struct tpm_chip *chip, int loc);
	int (*relinquish_locality)(struct tpm_chip *chip, int loc);
	u8 req_complete_mask;
	u8 req_complete_val;
};

/* TPM functions - these will be provided by the kernel TPM subsystem */
struct tpm_chip *tpmm_chip_alloc(struct device *dev,
				 const struct tpm_class_ops *ops);
int tpm_chip_bootstrap(struct tpm_chip *chip);
int tpm_chip_register(struct tpm_chip *chip);
void tpm_chip_unregister(struct tpm_chip *chip);
int tpm_pm_suspend(struct device *dev);
int tpm_pm_resume(struct device *dev);

/* Helper to get driver data - use kernel's dev_get_drvdata */
#ifndef dev_get_drvdata
#define dev_get_drvdata(dev) ((dev) ? dev_get_drvdata(dev) : NULL)
#endif

#endif /* _TPM_H */
