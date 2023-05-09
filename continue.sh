#!/bin/bash

set -exo pipefail

SCRIPTDIR=$(cd `dirname $0` && pwd)

# this is my version of https://wiki.archlinux.org/title/Installation_guide inside the chroot

[[ ! -f ${SCRIPTDIR}/config.sh ]] && echo "please set up ${SCRIPTDIR}/config.sh" >&2 && exit 1

. ${SCRIPTDIR}/config.sh

echo "symlinking /etc/localtime"
ln -sf /usr/share/zoneinfo/America/Los_Angeles /etc/localtime
echo

echo "generating /etc/adjtime"
hwclock --systohc
echo

echo "generating locale configs"
sed -i -e 's/^.*en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' >/etc/locale.conf
echo 'KEYMAP=us' > /etc/vconsole.conf
echo

echo "installing packages"
ADDITIONAL_PACKAGES=(
  "${CPU_MANUFACTURER}-ucode"
  "btrfs-progs"
  "man-db"
  "man-pages"
  "opendoas"
  "openssh"
  "sof-firmware"
  "texinfo"
  "zsh"
)
if [[ -n "${LAPTOP}" ]]; then
  ADDITIONAL_PACKAGES+=("networkmanager")
fi
pacman -Sy ${ADDITIONAL_PACKAGES[@]}
echo

echo "setting up network"
if [[ -z "${LAPTOP}" ]]; then
  # use systemd-networkd and systemd-resolved since we're a static ethernet connection
  echo "${NEW_HOSTNAME}" >/etc/hostname
  cp ${SCRIPTDIR}/20-ethernet.network /etc/systemd/network/
  systemctl enable systemd-networkd.service
  systemctl enable systemd-resolved.service
  echo
else
  # use NetworkManager since laptops move around a lot. should have been installed via pacstrap.
  systemctl enable systemd-resolved.service
  systemctl enable NetworkManager.service
  echo
fi

echo "initramfs"
sed -i 's/BINARIES=()/BINARIES=(btrfs)/' /etc/mkinitcpio.conf
sed -i 's/^HOOKS=.*/HOOKS=(base systemd autodetect modconf kms keyboard sd-vconsole block filesystems btrfs sd-encrypt fsck)/' /etc/mkinitcpio.conf
mkinitcpio -P
echo

echo "setting up systemd-boot"
bootctl --path=/boot install
cat >/boot/loader/loader.conf <<EOF
default      arch.conf
timeout      3
console-mode max
editor       no
EOF
cat >/boot/loader/entries/arch.conf <<EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /${CPU_MANUFACTURER}-ucode.img
initrd  /initramfs-linux.img
options root=LABEL=system rootflags=subvol=@ rd.luks.allow-discards rw
EOF
echo

echo "setting up user '${NEW_USER}'"
cat >/etc/doas.conf <<EOF
permit nopass setenv { XAUTHORITY LANG LC_ALL } :wheel
EOF
useradd -m -G wheel -s ${USER_SHELL} ${NEW_USER}
echo

echo "please create the password for '${NEW_USER}'"
passwd ${NEW_USER}
echo

echo "locking root"
passwd -l root
echo

echo "exiting chroot"
exit
