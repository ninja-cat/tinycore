#!/bin/bash

set -x

speed=10M

disks_online=`tail -n+3 /proc/partitions |awk '{ print $NF }'|grep -e [[:alpha:]]$`

gateway=`netstat -r | grep ^default | awk '{print $2}'`

DEV=`echo $disks_online|head -n 1`
for i in {1..10} 
do
  echo "Zeroing /dev/$DEV$i"
  parted -s /dev/$DEV$i rm 
done

#parted /dev/$DEV mklabel gpt
parted -s /dev/$DEV mklabel msdos

# create primary /boot partition
parted -s /dev/$DEV mkpart primary 1 50

disk_size=$(parted -slm | grep /dev/$DEV | cut -d':' -f2 | rev | cut -c 3- | rev)

parted -s /dev/$DEV mkpart primary 51 $disk_size

# create fs on boot partition
mkfs.ext4 -q /dev/${DEV}1

pvcreate -ff -y /dev/${DEV}2
vgcreate -y vg /dev/${DEV}2
lvcreate -L 2G -n root vg
lvcreate -L 5G -n temp vg

mkfs.ext4 -q /dev/mapper/vg-temp
mkdir temp_dir
mount /dev/mapper/vg-temp temp_dir
chmod 777 temp_dir
cd temp_dir

tar xf /opt/tce/payload.tar.xz
cd payload

/lib/ld-linux.so.2 --library-path libs ./aria2c --on-bt-download-complete do_provision.sh --event-poll=epoll --file-allocation=falloc --max-upload-limit=$speed --max-download-limit=$speed http://$gateway/torrent.torrent 


