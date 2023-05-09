#!/bin/bash

# set to not wait for keypress after partitioning / fstab creation
export NO_INTERACTION=

# The device to install to
export INSTALL_DEV=/dev/sda

# efi partition size in MB
export EFI_PARTITION_SIZE_MB=1024

# RAM size in GB (for swap calculation)
export RAM_SIZE_GB=1

# intel or amd
export CPU_MANUFACTURER=intel

# hostname
export NEW_HOSTNAME=arch-init-test

# user
export NEW_USER=jigish
export USER_SHELL=/bin/zsh

# Laptop -- used for network setup NetworkManager vs systemd-*. Unset for desktop.
export LAPTOP=true

#-------------------------------------------------------------------------------------------------------------------------------------

# swap should be RAM/4 for RAM<16 and RAM/8 for RAM>16 (we don't hibernate)
# https://itsfoss.com/swap-size/
export SWAP_PARTITION_SIZE_MB=$(( 1024 * ${RAM_SIZE_GB} / 4 ))
