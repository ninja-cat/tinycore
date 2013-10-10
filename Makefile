.PHONY: all boot clean distclean superclean

KVM=1
QEMU_ARGS=-net nic -net user,tftp="$$PWD/tftproot",bootfile=/pxelinux.0 -boot order=n
TC_DISTR_URL=http://distro.ibiblio.org/tinycorelinux/4.x/x86_64/
TC_MODULES_URL=http://distro.ibiblio.org/tinycorelinux/4.x/x86_64/tcz/
SYSLINUX_URL=http://www.kernel.org/pub/linux/utils/boot/syslinux/
SYSLINUX_VER=4.05
KERNEL_VER=3.0.21

download=curl -L -\# -o
#download=wget -O
tc_modules=$(shell cat opt/tce/onboot.lst)
opt_files=$(shell find opt -path opt/tce/optional -prune -or -print)
scsi_tcz=scsi-${KERNEL_VER}-tinycore64.tcz
raid_tcz=raid-dm-${KERNEL_VER}-tinycore64.tcz

all: deps tftproot/vmlinuz64 tftproot/corepure64.gz tftproot/pxelinux.0 tftproot/opt.cpio.gz
	@echo "You can boot a VM with 'make boot'"

boot: all
	qemu-system-x86_64 $(QEMU_ARGS)

deps:
	@echo "Processing dependencies for .tcz packages listed in pkgs.lst"
	bash process_deps.sh

tftproot/pxelinux.0: downloads/syslinux-$(SYSLINUX_VER).tar.xz
	tar xOf $^ syslinux-$(SYSLINUX_VER)/core/pxelinux.0 > $@
	sed -e 's/,opt.cpio.gz//' -i tftproot/pxelinux.cfg/default

tftproot/opt.cpio.gz: $(addprefix opt/tce/optional/,$(tc_modules)) $(opt_files)
	find opt | cpio -o -H newc | gzip -9 > "$@"

tftproot/vmlinuz64: downloads/vmlinuz64
	ln -f $^ $@

tftproot/corepure64.gz: downloads/${raid_tcz} downloads/${scsi_tcz} downloads/corepure64.gz tftproot/opt.cpio.gz | opt/bootlocal.sh
	sudo rm -rf corepure64/ squashfs-root/
	mkdir -p corepure64
	cd corepure64 && zcat ../downloads/$(@F) | sudo cpio -i -H newc -d && cd -
	sudo cp $| corepure64/$|
	unsquashfs $<
	sudo cp -R squashfs-root/* corepure64/
	rm -fr squashfs-root/
	unsquashfs $(word 2,$^)
	sudo cp -R squashfs-root/* corepure64/
	sudo cp -R opt corepure64/
	sudo chroot corepure64 depmod -a ${KERNEL_VER}-tinycore64
	cd corepure64 && sudo find | sudo cpio -o -H newc | gzip -9 > ../$(@F) && cd - && mv $(@F) $@

opt/tce/optional/%.tcz: downloads/%.tcz
	ln -f $^ $@

downloads/raid-dm-%.tcz: ROOT_URL=$(TC_MODULES_URL)
downloads/scsi-%.tcz: ROOT_URL=$(TC_MODULES_URL)
downloads/vmlinuz64 downloads/corepure64.gz: ROOT_URL=$(TC_DISTR_URL)
downloads/syslinux-%.tar.xz: ROOT_URL=$(SYSLINUX_URL)
$(addprefix downloads/,$(tc_modules)): ROOT_URL=$(TC_MODULES_URL)

.SECONDARY: downloads/%

downloads/%: | downloads
	$(download) $@ $(patsubst downloads/%,$(ROOT_URL)%,$@)

downloads:
	mkdir downloads

clean: distclean
	sudo rm -rf tftproot/corepure64.gz tftproot/opt.cpio.gz tftproot/pxelinux.0

distclean:
	sudo rm -rf corepure64/ squashfs-root/

superclean: clean
	sudo rm -rf downloads/ opt/tce/optional/* tftproot/vmlinuz64
