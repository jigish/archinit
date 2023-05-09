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

echo "wiping ${INSTALL_DEV}"
sgdisk --zap-all ${INSTALL_DEV}
echo "partitioning ${INSTALL_DEV}"
echo "  -> EFI:         EFI partition (${EFI_PARTITION_SIZE_MB}MB)"
echo "  -> cryptswap:   encrypted swap partition (${SWAP_PARTITION_SIZE_MB}MB)"
echo "  -> cryptsystem: encrypted system partition (rest of the disk)"
sgdisk --clear \
  --new 1:0:+${EFI_PARTITION_SIZE_MB}MiB --typecode=1:ef00 --change-name=1:EFI \
  --new 2:0:+${SWAP_PARTITION_SIZE_MB}MiB --typecode=2:8200 --change-name=2:cryptswap \
  --new 3:0:0                             --typecode=3:8300 --change-name=3:cryptsystem \
  ${INSTALL_DEV}
echo "waiting 5 seconds"
sleep 5
echo

echo "encrypting root partition"
cryptsetup luksFormat /dev/disk/by-partlabel/cryptsystem
cryptsetup open /dev/disk/by-partlabel/cryptsystem system
echo

echo "encrypting swap partition"
cryptsetup open --type plain --key-file /dev/urandom /dev/disk/by-partlabel/cryptswap swap
echo

echo "formatting EFI partition (fat32)"
mkfs.fat -F 32 -n EFI /dev/disk/by-partlabel/EFI
echo
echo "formatting swap partition"
mkswap -L swap /dev/mapper/swap
echo
echo "formatting system partition (btrfs)"
mkfs.btrfs --label system /dev/mapper/system
echo

echo "mounting system partition and creating btrfs subvolumes"
mount -t btrfs LABEL=system /mnt
btrfs su cr /mnt/@
btrfs su cr /mnt/@home
btrfs su cr /mnt/@pkg
btrfs su cr /mnt/@snapshots
echo

echo "unmounting system partition and mounting subvolumes"
umount /mnt
mount -t btrfs -o defaults,noatime,compress=zstd,ssd,subvol=@ LABEL=system /mnt
mkdir /mnt/home
mount -t btrfs -o defaults,noatime,compress=zstd,ssd,subvol=@home LABEL=system /mnt/home
mkdir -p /mnt/var/cache/pacman/pkg
mount -t btrfs -o defaults,noatime,compress=zstd,ssd,subvol=@pkg LABEL=system /mnt/var/cache/pacman/pkg
mkdir /mnt/.snapshots
mount -t btrfs -o defaults,noatime,compress=zstd,ssd,subvol=@snapshots LABEL=system /mnt/.snapshots
echo

echo "mounting EFI partition"
mkdir -p /mnt/boot
mount LABEL=EFI /mnt/boot
echo

echo "mounting swap partition"
swapon -L swap
echo

echo "partitions and filesystem created"
echo
lsblk
fdisk -l
if [[ -z ${NO_INTERACTION} ]]; then
	echo
	echo "please check partitions above"
	echo "press q to exit or anything else to continue"
	read -n 1 r
	if [[ "$r" = "q" ]]; then
		echo "exiting"
		exit 0
	fi
fi
echo

# assume mirror servers are correct

echo "installing base packages"
pacstrap -K /mnt base linux linux-firmware mkinitcpio
echo

echo "creating crypttab"
echo

echo "generating fstab and crypttab"
genfstab -L -p /mnt >> /mnt/etc/fstab
sed -i 's#LABEL=swap#/dev/mapper/swap#g' /mnt/etc/fstab
echo "swap /dev/disk/by-partlabel/cryptswap /dev/urandom swap,cipher=aes-cbc-essiv:sha256,size=256" >> /mnt/etc/crypttab
echo "system /dev/disk/by-partlabel/cryptsystem none timeout=180" >>/mnt/etc/crypttab.initramfs # tpm2-device=auto for tpm2
echo
cat /mnt/etc/fstab
cat /mnt/etc/crypttab
cat /mnt/etc/crypttab.initramfs
if [[ -z ${NO_INTERACTION} ]]; then
	echo
	echo "please check fstab above"
	echo "press q to exit or anything else to continue"
	read -n 1 r
	if [[ "$r" = "q" ]]; then
		echo "exiting"
		exit 0
	fi
fi
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

echo
echo "reboot to continue. good luck."
