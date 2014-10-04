#!/bin/bash

# Copy root partition to LVM raid
vgname=`lvs | grep root | awk '{print $2; exit}'`; order=`echo ${vgname: -4:1}`
dd if=/dev/yakit-z0$order-vg/root of=/dev/yakit-z0$order-vg-new/root bs=8M

# Force check boot and root partitions
fsck -f -y /dev/yakit-z0$order-vg-new/root
bootraid=`blkid | grep -E 'md.*ext2' | awk -F: '{print $1}'`
fsck -f -y $bootraid

# Remove old LVM volume group
vgchange yakit-z0$order-vg -a n
vgremove yakit-z0$order-vg --force

# Add spare disk to LVM raid
lvmraid=`blkid | grep -E 'md.*LVM' | awk -F: '{print $1}'`
mdadm --manage $lvmraid --add /dev/sda5