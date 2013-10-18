#!/bin/bash
set -x
disks_online=`tail -n+3 /proc/partitions |awk '{ print $NF }'|grep -e [[:alpha:]]$`

path=$3
dir=`dirname $path`
DEV=`echo $disks_online|head -n 1`

UUID=$(blkid /dev/${DEV}1 | cut -d' ' -f2 | cut -d'"' -f2)

mkdir /mnt/boot
mount /dev/${DEV}1 /mnt/boot
mkdir /mnt/boot/extlinux
cp $dir/vmlinuz /mnt/boot/extlinux
cp $dir/initrd /mnt/boot/extlinux

cat > /mnt/boot/extlinux/syslinux.cfg << EOF
DEFAULT linux
LABEL linux
  SAY WOW LOOK Now booting the kernel from EXTLINUX
  KERNEL vmlinuz
  INITRD initrd
  APPEND rootfstype=ext4 lvm root=/dev/mapper/vg-root ro
EOF

/lib/ld-linux.so.2 --library-path libs ./extlinux --install /mnt/boot/extlinux

cat mbr.bin > /dev/$DEV

dd if=$dir/partition of=/dev/mapper/vg-root bs=16M

boot_part="UUID=$UUID /boot           ext4    defaults        0       2"
root_part="/dev/mapper/vg-root /               ext4    errors=remount-ro 0       1"
proc_part="proc            /proc           proc    nodev,noexec,nosuid 0       0"

mkdir tmp_root
mount /dev/mapper/vg-root tmp_root

echo $proc_part > tmp_root/etc/fstab
echo $boot_part >> tmp_root/etc/fstab
echo $root_part >> tmp_root/etc/fstab


ip_addr=$(ifconfig | grep "inet addr:" | grep -v "127.0.0.1" | grep -Eo '[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}' | head -1)

HOSTNAME=${ip_addr//./-}.provisioned.so

echo $HOSTNAME > tmp_root/etc/hostname

umount tmp_root

gateway=`netstat -r | grep ^default | awk '{print $2}'`
macaddr=`ifconfig eth0 | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}'`
wget http://$gateway/$macaddr.provisioned

#wget --post-data "macaddr=$MACADDR&status=ready"

sleep 10

####reboot



