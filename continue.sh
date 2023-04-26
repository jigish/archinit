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
# no neeed to set up keyboard layout -- i always use qwerty/us
echo

echo "settng up network"
echo "${NEW_HOSTNAME}" >/etc/hostname
cp ${SCRIPTDIR}/20-ethernet.network /etc/systemd/network/
systemctl enable systemd-networkd.service
systemctl enable systemd-resolved.service
echo

echo "setting up user '${NEW_USER}'"
cat <<EOF >/etc/doas.conf
permit nopass setenv { XAUTHORITY LANG LC_ALL } :wheel
EOF
useradd -m -G wheel -s ${USER_SHELL} ${NEW_USER}
echo
cat /etc/sudoers |grep wheel
echo
echo "please create the password for '${NEW_USER}'"
passwd jigish
echo

echo "initramfs"
mkinitcpio -P
echo

echo "please create the root password"
passwd
echo

echo "setting up systemd-boot"
bootctl --path=/boot install
cp ${SCRIPTDIR}/loader.conf /boot/loader/loader.conf
cp ${SCRIPTDIR}/arch.conf /boot/loader/entries/arch.conf
sed -i -e "s/__CPU_MANUFACTURER__/${CPU_MANUFACTURER}/g" /boot/loader/entries/arch.conf
echo

echo "exiting chroot"
exit
