.PHONY: all boot clean distclean superclean

KVM=1
QEMU_ARGS=-net nic -net user,tftp="$$PWD/tftproot",bootfile=/pxelinux.0 -boot order=n
TC_DISTR_URL=http://distro.ibiblio.org/tinycorelinux/4.x/x86/release/distribution_files/
TC_MODULES_URL=http://distro.ibiblio.org/tinycorelinux/4.x/x86_64/tcz/
SYSLINUX_URL=http://www.kernel.org/pub/linux/utils/boot/syslinux/
SYSLINUX_VER=4.05
SCSI_VER=3.0.21

download=curl -L -\# -o
#download=wget -O
tc_modules=$(shell cat opt/tce/onboot.lst)
opt_files=$(shell find opt -path opt/tce/optional -prune -or -print)
scsi_tcz=scsi-${SCSI_VER}-tinycore64.tcz

all: tftproot/vmlinuz64 tftproot/core64.gz tftproot/pxelinux.0 tftproot/opt.cpio.gz
	@echo "You can boot a VM with 'make boot'"

boot: all
	qemu-system-x86_64 $(QEMU_ARGS)

tftproot/pxelinux.0: downloads/syslinux-$(SYSLINUX_VER).tar.xz
	tar xOf $^ syslinux-$(SYSLINUX_VER)/core/pxelinux.0 > $@
	sed -e 's/,opt.cpio.gz//' -i tftproot/pxelinux.cfg/default

tftproot/opt.cpio.gz: $(addprefix opt/tce/optional/,$(tc_modules)) $(opt_files)
	find opt | cpio -o -H newc | gzip -9 > "$@"

tftproot/vmlinuz64: downloads/vmlinuz64
	ln -f $^ $@

tftproot/core64.gz: downloads/${scsi_tcz} downloads/core64.gz tftproot/opt.cpio.gz | opt/bootlocal.sh
	sudo rm -rf core64/ squashfs-root/
	mkdir -p core64
	cd core64 && zcat ../downloads/$(@F) | sudo cpio -i -H newc -d && cd -
	sudo cp $| core64/$|
	unsquashfs $<
	sudo cp -R squashfs-root/* core64/
	sudo cp -R opt core64/
	sudo chroot core64 depmod -a ${SCSI_VER}-tinycore64
	cd core64 && sudo find | sudo cpio -o -H newc | gzip -2 > ../$(@F) && cd - && mv $(@F) $@

opt/tce/optional/%.tcz: downloads/%.tcz
	ln -f $^ $@

downloads/scsi-%.tcz: ROOT_URL=$(TC_MODULES_URL)
downloads/vmlinuz64 downloads/core64.gz: ROOT_URL=$(TC_DISTR_URL)
downloads/syslinux-%.tar.xz: ROOT_URL=$(SYSLINUX_URL)
$(addprefix downloads/,$(tc_modules)): ROOT_URL=$(TC_MODULES_URL)

.SECONDARY: downloads/%

downloads/%: | downloads
	$(download) $@ $(patsubst downloads/%,$(ROOT_URL)%,$@)

downloads:
	mkdir downloads

clean: distclean
	sudo rm -rf tftproot/core64.gz tftproot/opt.cpio.gz tftproot/pxelinux.0

distclean:
	sudo rm -rf core64/ squashfs-root/

superclean: clean
	sudo rm -rf downloads/ opt/tce/optional/* tftproot/vmlinuz64
