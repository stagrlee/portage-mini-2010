# Copyright 1999-2008 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/sys-fs/udev/udev-132.ebuild,v 1.1 2008/11/14 16:49:03 zzam Exp $

EAPI="1"

inherit eutils flag-o-matic multilib toolchain-funcs linux-info
DESCRIPTION="Linux dynamic and persistent device naming support (aka userspace devfs)"
HOMEPAGE="http://www.kernel.org/pub/linux/utils/kernel/hotplug/udev.html"
PATCHSET="${P}-gentoo-patchset-v1"
SRC_URI="mirror://kernel/linux/utils/kernel/hotplug/${P}.tar.bz2 mirror://gentoo/${PATCHSET}.tar.bz2"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~alpha ~amd64 ~arm ~hppa ~ia64 ~m68k ~mips ~ppc ~ppc64 ~s390 ~sh ~sparc ~x86"
IUSE="selinux extras"

COMMON_DEPEND="selinux? ( sys-libs/libselinux )
	extras? (
		sys-apps/acl
		>=sys-apps/usbutils-0.82
		virtual/libusb:0
		sys-apps/pciutils
		dev-libs/glib:2
	)"
DEPEND="${COMMON_DEPEND} extras? ( dev-util/gperf )"
RDEPEND="${COMMON_DEPEND} !sys-apps/coldplug !<sys-fs/lvm2-2.02.45 !sys-fs/device-mapper >=sys-apps/baselayout-2.1.6"
PROVIDE="virtual/dev-manager"

pkg_setup() {
	udev_libexec_dir="/$(get_libdir)/udev"
}

src_unpack() {
	unpack ${A}

	cd "${S}"

	EPATCH_SOURCE="${WORKDIR}/${PATCHSET}" EPATCH_SUFFIX="patch" EPATCH_FORCE="yes" epatch
	epatch "${FILESDIR}/patches/udev-141-remove-devfs-names.diff"

	# change rules back to group uucp instead of dialout for now
	sed -e 's/GROUP="dialout"/GROUP="uucp"/' -i rules/{rules.d,packages,gentoo}/*.rules || die "failed to change group dialout to uucp"
}

src_compile() {
	filter-flags -fprefetch-loop-arrays

	econf \
		--prefix=/usr \
		--sysconfdir=/etc \
		--sbindir=/sbin \
		--enable-static \
		--libdir=/usr/$(get_libdir) \
		--with-rootlibdir=/$(get_libdir) \
		--libexecdir="${udev_libexec_dir}" \
		--enable-logging \
		$(use_enable extras) \
		$(use_with selinux)

	emake || die "compiling udev failed"
}

src_install() {
	into /
	emake DESTDIR="${D}" install || die "make install failed"

	exeinto "${udev_libexec_dir}"
	local x
	for x in net.sh move_tmp_persistent_rules.sh write_root_link_rule shell-compat.sh shell-compat-addon.sh
	do
		doexe "${FILESDIR}/${PVR}/${x}" || die "${x} not installed properly"
	done

	keepdir "${udev_libexec_dir}"/state
	keepdir "${udev_libexec_dir}"/devices

	# Use Funtoo's "realdev" command to create initial set of device nodes in
	# /lib/udev/devices. This set of device nodes will be copied to /dev when
	# udev starts.

	$ROOT/sbin/realdev ${D}${udev_libexec_dir}/devices || die

	# create symlinks for these utilities to /sbin
	# where multipath-tools expect them to be (Bug #168588)
	dosym "..${udev_libexec_dir}/vol_id" /sbin/vol_id
	dosym "..${udev_libexec_dir}/scsi_id" /sbin/scsi_id

	# Add gentoo stuff to udev.conf
	echo "# If you need to change mount-options, do it in /etc/fstab" >> "${D}"/etc/udev/udev.conf

	# let the dir exist at least
	keepdir /etc/udev/rules.d

	# Now installing rules
	cd "${S}"/rules
	insinto "${udev_libexec_dir}"/rules.d/

	# Our rules files
	doins gentoo/??-*.rules
	doins packages/40-alsa.rules
	doins packages/40-isdn.rules

	# Adding arch specific rules
	if [[ -f packages/40-${ARCH}.rules ]]
	then
		doins "packages/40-${ARCH}.rules"
	fi
	cd "${S}"

	# The udev-post init-script
	local x
	for x in udevd udev-save udev-mount udev-postmount
	do
		newinitd "${FILESDIR}"/${PVR}/${x}.initd ${x} || die "initscript $x install error"
	done
	
	newconfd "${FILESDIR}/${PVR}/udev.confd" udev || die "udev.confd install error"

	insinto /etc/modprobe.d
	newins "${FILESDIR}/${PVR}/blacklist" blacklist.conf
	newins "${FILESDIR}/${PVR}/pnp-aliases" pnp-aliases.conf

	# keep doc in just one directory, Bug #281137
	rm -rf "${D}/usr/share/doc/${PN}"
	if use extras; then
		dodoc extras/keymap/README.keymap.txt || die "failed installing docs"
	fi
	cd docs/writing_udev_rules || die
	mv index.html writing_udev_rules.html
	dohtml *.html

	cd "${S}" || die

	echo "CONFIG_PROTECT_MASK=\"/etc/udev/rules.d\"" > 20udev
	doenvd 20udev
}

modfix() {
	local mod

	# We want to move any old modprobe.d conf files to the new file name so
	# config file protection works correctly.

	for mod in blacklist pnp-aliases 
	do
		if [ -e $ROOT/etc/modprobe.d/$mod ] 
		then
			mv $ROOT/etc/modprobe.d/$mod $ROOT/etc/modprobe.d/${mod}.conf || die "mv failed"
		fi
	done
}

pkg_preinst() {
	modfix

	if [[ -d ${ROOT}/lib/udev-state ]]
	then
		mv -f "${ROOT}"/lib/udev-state/* "${D}"/lib/udev/state/
		rm -r "${ROOT}"/lib/udev-state
	fi

	if [[ -f ${ROOT}/etc/udev/udev.config &&
	     ! -f ${ROOT}/etc/udev/udev.rules ]]
	then
		mv -f "${ROOT}"/etc/udev/udev.config "${ROOT}"/etc/udev/udev.rules
	fi

	rm -f /etc/conf.d/udev #FORCE UPDATE
}

# from the openrc-0.3.0.22081113 ebuild :)
add_init() {
	local runl=$1
	if [ ! -e ${ROOT}/etc/runlevels/${runl} ]
	then
		install -d -m0755 ${ROOT}/etc/runlevels/${runl}
	fi
	for initd in $*
	do
		# if the initscript is not going to be installed and  is not currently installed, return
		[[ -e ${D}/etc/init.d/${initd} || -e ${ROOT}/etc/init.d/${initd} ]] || continue
		[[ -e ${ROOT}/etc/runlevels/${runl}/${initd} ]] && continue
		elog "Auto-adding '${initd}' service to your ${runl} runlevel"
		ln -snf /etc/init.d/${initd} "${ROOT}"/etc/runlevels/${runl}/${initd}
	done
}

pkg_postinst() {
	# disable coldplug script
	rm -f $ROOT/etc/runlevels/*/coldplug

	# disable any old udev script
	rm -f $ROOT/etc/runlevels/*/udev

	rm -f $ROOT/etc/runlevels/*/udev-postmount

	add_init sysinit udev-mount
	add_init sysinit udevd
	add_init boot udev-postmount
	add_init shutdown udev-save

	# requested in Bug #225033:
	elog
	elog "persistent-net does assigning fixed names to network devices."
	elog "If you prefer to disable persistent-net, this can be done via"
	elog "/etc/conf.d/udev."

	ewarn
	ewarn "mount options for directory /dev are no longer"
	ewarn "set in /etc/udev/udev.conf, but in /etc/fstab"
	ewarn "as for other directories."

	elog
	elog "For more information on udev on Gentoo, writing udev rules, and"
	elog "         fixing known issues visit:"
	elog "         http://www.gentoo.org/doc/en/udev-guide.xml"
}
