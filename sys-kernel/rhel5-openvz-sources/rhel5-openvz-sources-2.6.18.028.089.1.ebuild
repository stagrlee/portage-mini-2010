# Copyright 1999-2009 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/sys-kernel/openvz-sources/openvz-sources-2.6.18.028.066.7.ebuild,v 1.1 2009/11/26 19:12:49 pva Exp $

EAPI=2
SLOT=$PVR
CKV=2.6.18
OKV=$CKV
OVZ_KERNEL="028stab089"
OVZ_REV="1"
OVZ_KV=${OVZ_KERNEL}.${OVZ_REV}
OVZ_PATCHV="238.9.1.el5.${OVZ_KV}"
KV_FULL=${PN}-${PVR}
EXTRAVERSION=-${OVZ_KV}
KERNEL_ARCHIVE="linux-${CKV}.tar.bz2"
KERNEL_URI="mirror://kernel/linux/kernel/v${KV_MAJOR}.${KV_MINOR}/${KERNEL_ARCHIVE}"
RESTRICT="binchecks strip"

LICENSE="GPL-2"
KEYWORDS=""
IUSE=""
DESCRIPTION="Full Linux kernel sources - RHEL5 kernel with OpenVZ patchset"
HOMEPAGE="http://www.openvz.org"
MAINPATCH="patch-${OVZ_PATCHV}-combined.gz"
SRC_URI="${KERNEL_URI}
	http://download.openvz.org/kernel/branches/rhel5-${CKV}/${OVZ_KV}/configs/kernel-${CKV}-i686-ent.config.ovz -> config-${CKV}-${OVZ_KV}.i686
	http://download.openvz.org/kernel/branches/rhel5-${CKV}/${OVZ_KV}/configs/kernel-${CKV}-x86_64.config.ovz -> config-${CKV}-${OVZ_KV}.x86_64
	http://download.openvz.org/kernel/branches/rhel5-${CKV}/${OVZ_KV}/patches/$MAINPATCH"
S="$WORKDIR/linux-${CKV}"
DEPEND="=sys-devel/gcc-4.1.2*"

K_EXTRAEINFO="
This OpenVZ kernel uses RHEL5 (Red Hat Enterprise Linux 5) patch set.
This patch set is maintained by Red Hat for enterprise use, and contains
further modifications by the OpenVZ development team and the Funtoo
Linux project.

Red Hat typically only ensures that their kernels build using their
own official kernel configurations. Significant variations from these
configurations can result in build failures.

For best results, always start with a .config provided by the OpenVZ 
team from:

http://wiki.openvz.org/Download/kernel/rhel5/${OVZ_KERNEL}.

On amd64 and x86 arches, one of these configurations has automatically been
enabled in the kernel source tree that was just installed for you.

Slight modifications to the kernel configuration necessary for booting
are usually fine. If you are using genkernel, the default configuration
should be sufficient for your needs."

K_EXTRAEWARN="THIS KERNEL MUST BE BUILT WITH GCC-4.1. Makefile will use
gcc-4.1.2 directly."

src_unpack() {
	unpack ${KERNEL_ARCHIVE}
}

apply() {
	p=$1; shift
	case "${p##*.}" in
		gz)
			ca="gzip -dc"
			;;
		bz2)
			ca="bzip2 -dc"
			;;
		xz)
			ca="xz -dc"
			;;
		*)
			ca="cat"
			;;
	esac
	[ ! -e $p ] && die "patch $p not found"
	echo "Applying patch $p"; $ca $p | patch -s $* || die "patch $p failed"
}

pkg_setup() {
	case $ARCH in
		x86)
			defconfig_src=i686
			;;
		amd64)
			defconfig_src=x86_64
			;;
		*)
			die "unsupported ARCH: $ARCH"
			;;
	esac
	defconfig_src="${DISTDIR}/config-${CKV}-${OVZ_KV}.${defconfig_src}"
	unset ARCH; unset LDFLAGS #will interfere with Makefile if set
}

src_prepare() {
	apply $DISTDIR/$MAINPATCH -p1
	apply ${FILESDIR}/${PN}-2.6.18.028.064.7-bridgemac.patch -p1
	apply ${FILESDIR}/uvesafb-0.1-rc3-2.6.18-openvz-028.066.10.patch -p1
	sed -i -e "s:^\(EXTRAVERSION =\).*:\1 ${EXTRAVERSION}:" Makefile || die
	sed	-i -e 's:#export\tINSTALL_PATH:export\tINSTALL_PATH:' Makefile || die
	cp $DISTDIR/config-${CKV}-${OVZ_KV}.i686 arch/i386/defconfig || die
	cp $DISTDIR/config-${CKV}-${OVZ_KV}.x86_64 arch/x86_64/defconfig || die
	for MYARCH in i386 x86_64
	do
		# add missing uvesafb config option (came from our patch) to default config
		echo "CONFIG_FB_UVESA=y" >> "arch/$MYARCH/defconfig" || die "uvesafb config fail"
	done
	rm -f .config >/dev/null
	make -s mrproper || die "make mrproper failed"
	make -s include/linux/version.h || die "make include/linux/version.h failed"
}

src_compile() {
	install -d ${WORKDIR}/out/{lib,boot}
	install -d ${T}/{cache,twork}
	install -d $WORKDIR/build $WORKDIR/out/lib/firmware
	DEFAULT_KERNEL_SOURCE="${S}" INSTALL_FW_PATH=${WORKDIR}/out/lib/firmware CMD_KERNEL_DIR="${S}" genkernel ${GKARGS} \
		--no-save-config \
		--kernel-config="$defconfig_src" \
		--kernname="${PN/-sources/}" \
		--build-src="$S" \
		--build-dst=${WORKDIR}/build \
		--makeopts="${MAKEOPTS}" \
		--firmware-dst=${WORKDIR}/out/lib/firmware \
		--cachedir="${T}/cache" \
		--tempdir="${T}/twork" \
		--logfile="${WORKDIR}/genkernel.log" \
		--bootdir="${WORKDIR}/out/boot" \
		--lvm \
		--luks \
		--iscsi \
		--module-prefix="${WORKDIR}/out" \
		all || die "genkernel failed"
}

src_install() {
	cd ${S}
	make -s clean || die "make clean failed"
	cp -a ${WORKDIR}/out/* ${D}/ || die "couldn't copy output files into place"
	# copy sources into place:
	dodir /usr/src
	cp -a ${S} ${D}/usr/src/linux-${P} || die
	# module symlink fixup:
	rm -f ${D}/lib/modules/*/source || die
	rm -f ${D}/lib/modules/*/build || die
	cd ${D}/lib/modules
	local moddir="$(ls -d 2*)"
	ln -s /usr/src/linux-${P} ${D}/lib/modules/${moddir}/source || die
	ln -s /usr/src/linux-${P} ${D}/lib/modules/${moddir}/build || die
}
