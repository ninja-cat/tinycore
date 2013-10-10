#!/bin/sh

disks_online=`tail -n+3 /proc/partitions |awk '{ print $NF }'|grep -e [[:alpha:]]$`

for i in $disks_online
do
  echo "Zeroing /dev/$i"
  `dd if=/dev/zero of=/dev/$i bs=4k`
done

#poweroff
