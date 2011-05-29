# Copyright 1999-2009 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=3
inherit autotools mount-boot flag-o-matic toolchain-funcs

BINFONT="grub-unifont-1.0"
SRC_URI="ftp://alpha.gnu.org/gnu/${PN}/${P}.tar.gz binfont? ( http://www.funtoo.org/archive/grub/${BINFONT}.tar.bz2 )"

DESCRIPTION="GNU GRUB 2 boot loader"
HOMEPAGE="http://www.gnu.org/software/grub/"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="amd64 x86"
IUSE="custom-cflags debug static mkfont +binfont"

DEPEND=">=sys-libs/ncurses-5.2-r5 dev-libs/lzo mkfont? ( >=media-libs/freetype-2 )"
RDEPEND="${RDEPEND}"
PDEPEND="sys-boot/boot-update"
PROVIDE="virtual/bootloader"

export STRIP_MASK="*/grub/*/*.mod"
QA_EXECSTACK="sbin/grub-probe sbin/grub-setup sbin/grub-mkdevicemap"

src_compile() {
	use custom-cflags || unset CFLAGS CPPFLAGS LDFLAGS
	use static && append-ldflags -static

	econf \
		--disable-werror \
		--sbindir=/sbin \
		--bindir=/bin \
		--libdir=/$(get_libdir) \
		--disable-efiemu \
		$(use_enable mkfont grub-mkfont ) \
		$(use_enable debug mm-debug) \
		$(use_enable debug grub-emu) \
		$(use_enable debug grub-emu-usb) \
		$(use_enable debug grub-fstest)
	emake -j1 || die "making regular stuff"
	# As of 1.97.1, GRUB still needs -j1 to build. Reason: grub_script.tab.c
}

src_install() {
	emake DESTDIR="${D}" install || die
	for delme in /etc/default /etc/grub.d /sbin/grub-update /sbin/grub-mkconfig 
	do 
		rm -rf ${D}/$delme || die "couldn't remove upstream stuff"
	done
	dodoc AUTHORS ChangeLog NEWS README THANKS TODO

	use binfont && { cd ${D} && tar xf ${DISTDIR}/${BINFONT}.tar.bz2 || die "binfont issue"; }
}
