#!/bin/bash

set -exo pipefail

SCRIPTDIR=$(cd `dirname $0` && pwd)

# this is my version of https://wiki.archlinux.org/title/Installation_guide

[[ ! -f ${SCRIPTDIR}/config.sh ]] && echo "please set up ${SCRIPTDIR}/config.sh" >&2 && exit 1

. ${SCRIPTDIR}/config.sh

# remove git folder if it exists
rm -rf ${SCRIPTDIR}/.git

# no neeed to set up keyboard layout -- i always use qwerty/us

echo "verfying boot mode (uefi)"
ls /sys/firmware/efi/efivars
echo

echo "verifying network"
ip link
ping archlinux.org # need to ctrl-c this
echo

echo "updating system clock"
timedatectl
echo

# TODO dm_crypt
echo "wiping ${INSTALL_DEV}"
wipefs -a /dev/sda
echo "partitioning ${INSTALL_DEV}"
echo "creating boot partition (${BOOT_PARTITION_SIZE_MB}MB)"
sed -e 's/^.*|//' << EOF | fdisk ${INSTALL_DEV}
new empty GPT partition table       |g
new partition                       |n
partition number 1 (boot)           |1
start at beginning of disk          |
boot partition size                 |+${BOOT_PARTITION_SIZE_MB}M
change partition type               |t
type: EFI system                    |uefi
print the in-memory partition table |p
write the partition table and quit  |w
EOF
echo
echo "creating swap partition (${SWAP_PARTITION_SIZE_MB}MB)"
sed -e 's/^.*|//' << EOF | fdisk ${INSTALL_DEV}
new partition                       |n
partition number 2 (swap)           |2
start after preceeding partition    |
swap partition size                 |+${SWAP_PARTITION_SIZE_MB}M
change partition type               |t
choose partition 2                  |2
type: Linux swap                    |swap
print the in-memory partition table |p
write the partition table and quit  |w
EOF
echo
echo "creating arch partition (rest of the disk)"
sed -e 's/^.*|//' << EOF | fdisk ${INSTALL_DEV}
new partition                       |n
partition number 3                  |3
start after preceeding partition    |
end at the end of the disk          |
print the in-memory partition table |p
write the partition table and quit  |w
EOF
echo

echo "formatting ${INSTALL_DEV}1 (fat32)"
mkfs.fat -F 32 ${INSTALL_DEV}1
echo
echo "formatting ${INSTALL_DEV}2 (swap)"
mkswap ${INSTALL_DEV}2
echo
echo "formatting ${INSTALL_DEV}3 (btrfs)"
mkfs.btrfs -L arch-os ${INSTALL_DEV}3
echo

echo "mounting ${INSTALL_DEV}3 and creating btrfs subvolumes"
mount /dev/sda3 /mnt
btrfs su cr /mnt/@
btrfs su cr /mnt/@home
btrfs su cr /mnt/@snapshots
echo

echo "unmounting ${INSTALL_DEV}3 and mounting subvolumes"
umount /mnt
mount -o defaults,noatime,compress=zstd,ssd,subvol=@ ${INSTALL_DEV}3 /mnt
mkdir /mnt/home
mount -o defaults,noatime,compress=zstd,ssd,subvol=@home ${INSTALL_DEV}3 /mnt/home
mkdir /mnt/.snapshots
mount -o defaults,noatime,compress=zstd,ssd,subvol=@snapshots ${INSTALL_DEV}3 /mnt/.snapshots
echo

echo "mounting ${INSTALL_DEV}1 (boot)"
mkdir /mnt/boot
mount ${INSTALL_DEV}1 /mnt/boot
echo

echo "mounting ${INSTALL_DEV}2 (swap)"
swapon ${INSTALL_DEV}2
echo

echo "partitions and filesystem created"
echo
lsblk
fdisk -l
sleep 5
echo

# assume mirror servers are correct

echo "installing base packages"
pacstrap -K /mnt base linux linux-firmware \
	${CPU_MANUFACTURER}-ucode \
	btrfs-progs \
	sof-firmware \
	man-db man-pages texinfo \
	openssh sudo zsh
echo

echo "generating fstab"
genfstab -U /mnt >> /mnt/etc/fstab
echo
cat /mnt/etc/fstab
sleep 5
echo

echo "copying these scripts to /mnt/${SCRIPTDIR} so they are in the chroot"
mkdir -p /mnt/${SCRIPTDIR}
cp -a ${SCRIPTDIR}/* /mnt/${SCRIPTDIR}
echo

echo "chrooting into /mnt"
arch-chroot /mnt bash -c "${SCRIPTDIR}/continue.sh"
echo "chroot exited"
echo

# we keep the scripts from this init around so we know what we init'd with

echo "unmounting /mnt"
umount -R /mnt
echo

echo "rebooting in 5s..."
sleep 1
echo "             4s..."
sleep 1
echo "             3s..."
sleep 1
echo "             2s..."
sleep 1
echo "             1s..."
sleep 1
echo "rebooting now. good luck."
reboot
