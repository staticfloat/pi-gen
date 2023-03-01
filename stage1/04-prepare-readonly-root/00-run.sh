#!/bin/bash -e

# Create the mountpoints, also check the `fstab` entry that creates a tmpfs
mkdir -p "${ROOTFS_DIR}/var/lib/systemd/timesync"
mkdir -p "${ROOTFS_DIR}/var/lib/systemd-logind"

# Also install our `ro` and `rw` scripts
install -m 755 files/ro "${ROOTFS_DIR}/usr/local/bin/ro"
install -m 755 files/rw "${ROOTFS_DIR}/usr/local/bin/rw"

# Install some scripts we run during startup
install -m 755 files/grow_data_partition "${ROOTFS_DIR}/usr/lib/grow_data_partition"
install -m 755 files/regenerate_ssh_host_keys "${ROOTFS_DIR}/usr/lib/regenerate_ssh_host_keys"
install -m 755 files/qemu_customize "${ROOTFS_DIR}/usr/lib/qemu_customize"
install -m 644 files/grow_data_partition.service "${ROOTFS_DIR}/lib/systemd/system/grow_data_partition.service"
