all: image

SRCDIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

# Let's goooo
IMG_NAME := lilisound
IMG_VERSION := v2


build:
	@mkdir -p $@

config: config.template
	@IMG_NAME="$(IMG_NAME)" IMG_VERSION="$(IMG_VERSION)" envsubst <"$<" >"$@"


IMG_BUILD_PATH := deploy/${IMG_NAME}-${IMG_VERSION}-qemu.img
$(IMG_BUILD_PATH): config
	@sudo ./build.sh

# This is used for qemu-based booting
BOOT_DIR := work/$(IMG_NAME)/stage2/rootfs/boot/

build/$(IMG_NAME)-$(IMG_VERSION).img: $(IMG_BUILD_PATH) | build
	cp $< $@
	power2g() { echo "x=(l($$1/(1024^3)))/l(2); scale=0; 2^((x+1)/1)" | bc -l; }; \
	IMG_SIZE_BYTES=$$(stat -c '%s' $<); \
	qemu-img resize -f raw $@ $$(power2g $${IMG_SIZE_BYTES})G

debug-image: build/$(IMG_NAME)-$(IMG_VERSION).img
	cp -f $< build/debug.img
	-$(call qemu_run,build/debug.img,/bin/bash)
	rm -f build/debug.img

# The base image that will be customized in the future
image: build/$(IMG_NAME)-$(IMG_VERSION).img
clean-image:
	sudo rm -f $(IMG_BUILD_PATH)
cleanall: clean-image



# This gets called with the following parameters:
#  $(1) - A `.img` to boot
#  $(2) - An optional `init` executable within that `.img`
#  $(3) - An optional TFTP directory
define qemu_run
	qemu-system-aarch64 \
		-M raspi3b \
		-smp 4 \
		-cpu cortex-a72 \
		-dtb $(BOOT_DIR)/bcm2710-rpi-3-b-plus.dtb \
		-kernel $(BOOT_DIR)/kernel8.img \
		-append "ro earlyprintk console=ttyAMA0,115200 root=/dev/mmcblk0p2 rootdelay=1 kernel.panic=-1 $(if $(2),init=$(2),)" \
		-drive file=$(1),if=sd,format=raw \
		-netdev user,id=net0,$(if $(3),tftp=$(3),) \
		-device usb-net,netdev=net0 \
		-serial mon:stdio \
		-no-reboot \
		-nographic
endef


# This gets called with a config name
define bootstrap_builder
build/bootstrap-staging-$(1) build/bootstrap-tftp-$(1):
	@mkdir -p $$@

build/bootstrap-staging-$(1)/bootstrap.sh: bootstrap.sh | build/bootstrap-staging-$(1)
	@CONFIG_NAME="$(1)" \
	envsubst '$$$${CONFIG_NAME}' <bootstrap.sh >"$$@"
	@chmod +x "$$@"

build/bootstrap-staging-$(1)/config: | build/bootstrap-staging-$(1)
	@rm -f $$@
	@ln -s ../../bootstrap_configs/$(1) $$@

build/bootstrap-tftp-$(1)/bootstrap.tar.gz: build/bootstrap-staging-$(1)/bootstrap.sh \
                                            build/bootstrap-staging-$(1)/config \
											$(wildcard bootstrap_configs/$(1)/*) \
											| build/bootstrap-tftp-$(1)
	@echo "Building bootstrap staging tarball $$(notdir $$@)..."
	@tar -chzf $$@ -C build/bootstrap-staging-$(1) .

build/$(IMG_NAME)-$(IMG_VERSION)-$(1).img: build/bootstrap-tftp-$(1)/bootstrap.tar.gz build/$(IMG_NAME)-$(IMG_VERSION).img
	cp build/$(IMG_NAME)-$(IMG_VERSION).img $$@.precustomize
	$$(call qemu_run,$$@.precustomize,/usr/lib/qemu_customize,build/bootstrap-tftp-$(1))
	mv $$@.precustomize $$@

customize-$(1): build/$(IMG_NAME)-$(IMG_VERSION)-$(1).img
customize-all: customize-$(1)

debug-$(1): build/$(IMG_NAME)-$(IMG_VERSION)-$(1).img
	$$(call qemu_run,build/$(IMG_NAME)-$(IMG_VERSION)-$(1).img,/bin/bash)

run-$(1): build/$(IMG_NAME)-$(IMG_VERSION)-$(1).img
	$$(call qemu_run,build/$(IMG_NAME)-$(IMG_VERSION)-$(1).img)

clean-image-$(1):
	rm -f build/$(IMG_NAME)-$(IMG_VERSION)-$(1).img
cleanall: clean-image-$(1)
clean: clean-image-$(1)
endef


BOOTSTRAP_CONFIGS := $(notdir $(wildcard bootstrap_configs/*))
$(foreach BOOTSTRAP_CONFIG,$(BOOTSTRAP_CONFIGS),$(eval $(call bootstrap_builder,$(BOOTSTRAP_CONFIG))))

cleanall:
	rm -rf build
	sudo bash -c "source scripts/common && unmount work"
	sudo rm -rf work
	sudo rm -rf deploy

print-%:
	@echo "$*=$($*)"
