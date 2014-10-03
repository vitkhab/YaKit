#!/bin/bash

vgname=`lvs | grep root | awk '{print $2; exit}'`; order=`echo ${vgname: -4:1}`
dd if=/dev/yakit-z0$order-vg/root of=/dev/yakit-z0$order-vg-new/root
fsck -f /dev/yakit-z0$order-vg-new/root
bootraid=`blkid | grep -E 'md.*ext2' | awk -F: '{print $1}'`
fsck -f $bootraid
vgchange yakit-z0$order-vg -a n
vgremove yakit-z0$order-vg --force
lvmraid=`blkid | grep -E 'md.*LVM' | awk -F: '{print $1}'`
mdadm --manage $lvmraid --add /dev/sda5