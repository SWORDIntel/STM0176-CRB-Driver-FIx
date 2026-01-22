# Makefile for Patched CRB Driver
# =================================

obj-m := tpm_crb_patched.o

PWD := $(shell pwd)
KERNEL_VERSION := $(shell uname -r)
KDIR := /lib/modules/$(KERNEL_VERSION)/build

# Default target
all:
	@echo "Building patched CRB driver for kernel $(KERNEL_VERSION)..."
	$(MAKE) -C $(KDIR) M=$(PWD) modules

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean
	rm -f *.ko *.o *.mod.c *.mod *.symvers *.order

install: all
	@if [ ! -f tpm_crb_patched.ko ]; then \
		echo "ERROR: Module not built. Run 'make' first."; \
		exit 1; \
	fi
	@echo "Installing patched CRB driver..."
	sudo insmod tpm_crb_patched.ko crb_workaround_buffer_mismatch=1
	@echo "✓ Patched CRB driver loaded"
	@dmesg | tail -10

help:
	@echo "Available targets:"
	@echo "  make          - Build the patched CRB driver module"
	@echo "  make clean    - Clean build artifacts"
	@echo "  make install  - Build and load the module"
	@echo "  make help     - Show this help message"

.PHONY: all clean install help
