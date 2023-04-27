#!/bin/bash

# set to not wait for keypress after partitioning / fstab creation
export NO_INTERACTION=

# The device to install to
export INSTALL_DEV=/dev/sda

# boot partition size in MB
export BOOT_PARTITION_SIZE_MB=1024

# RAM size in GB (for swap calculation)
export RAM_SIZE_GB=1

# intel or amd
export CPU_MANUFACTURER=intel

# hostname
export NEW_HOSTNAME=arch-init-test

# user
export NEW_USER=jigish
export USER_SHELL=/bin/zsh

#-------------------------------------------------------------------------------------------------------------------------------------

# swap should be 1.5*RAM if RAM > 8GB
export SWAP_PARTITION_SIZE_MB=$(( 3 * 1024 * $RAM_SIZE_GB / 2 ))
