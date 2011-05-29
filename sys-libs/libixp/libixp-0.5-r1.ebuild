# Copyright 1999-2011 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI="3"

inherit eutils multilib toolchain-funcs

DESCRIPTION="Standalone client/server 9P library"
HOMEPAGE="http://libs.suckless.org/libixp"
SRC_URI="http://code.suckless.org/dl/libs/${P}.tar.gz"

LICENSE="MIT"
SLOT="0"
KEYWORDS="amd64 ~hppa ~ppc64 x86"
IUSE=""

src_prepare() {
	epatch "${FILESDIR}"/${P}-gentoo.diff
	sed -i -e "s:(PREFIX)/lib:(PREFIX)/$(get_libdir):" config.mk || die
}

src_compile() {
	tc-export CC
	emake CC="${CC}" LD="${CC}" || die
}

src_install() {
	emake DESTDIR="${D}" install || die
	dolib.so lib/*.so* || die
	dosym libixp.so.${PV} /usr/$(get_libdir)/libixp.so
	dosym libixp_pthread.so.${PV} /usr/$(get_libdir)/libixp_pthread.so
}
