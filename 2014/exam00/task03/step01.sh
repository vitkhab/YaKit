#!/bin/bash

# Install essentials
apt-get update
apt-get install -y mdadm ssh

# Copy partition table
sfdisk -d /dev/sda | sfdisk --force /dev/sdb

# Create RAID partitions for boot and LVM
mdadm --create --level=1 /dev/md127 --raid-devices=2 --metadata=0.90 /dev/sdb1 missing
mdadm --create --level=1 /dev/md126 --raid-devices=2 --metadata=1.2 /dev/sdb5 missing

# Create root partition on LVM
pvcreate /dev/md127
fullname=`uname -n`; order=`echo ${fullname: -1}`
vgcreate yakit-z0$order-vg-new /dev/md126
lvsize=`lvdisplay | awk '/root/ {found=1}; /LV Size/ && found {print $3$4; exit}'`
lvcreate -n root -L$lvsize yakit-z0$order-vg-new

# Copy boot partition
mkfs.ext2 /dev/md127
mount /dev/md127 /mnt/
rsync -a /boot/ /mnt/
umount /boot/
umount /mnt/
mount /dev/md127 /boot/

# Change partitions to be mount
bootuuid=`blkid /dev/md127 | awk -F'"' '{print $2}'`
sed -i "s#\(^[^#].*\)/boot\(.*\)#UUID=$bootuuid /boot\2#" /etc/fstab
sed -i "s#\yakit--z0$order--vg-root#yakit--z0$order--vg--new-root#" /etc/fstab

# Fixing error "Diskfilter writes are not supported" during boot
sed -i 's#quick_boot="1"#quick_boot="0"#' /etc/grub.d/10_linux

# Change grub settings
oldvguuid=`vgdisplay yakit-z0$order-vg | awk '/VG UUID/ {print $3}'`
oldlvuuid=`lvdisplay /dev/yakit-z0$order-vg/root | awk '/LV UUID/ {print $3}'`
newvguuid=`vgdisplay yakit-z0$order-vg-new | awk '/VG UUID/ {print $3}'`
newlvuuid=`lvdisplay /dev/yakit-z0$order-vg-new/root | awk '/LV UUID/ {print $3}'`
sed -i "s#$oldvguuid/$oldlvuuid#$newvguuid/$newlvuuid#g" /boot/grub/grub.cfg
sed -i "s#\yakit--z0$order--vg-root#yakit--z0$order--vg--new-root#g" /boot/grub/grub.cfg

# Adding spare disk to boot raid
mdadm --manage /dev/md127 --add /dev/sda1