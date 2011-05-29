# Copyright 1999-2011 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI="2"

DESCRIPTION="GPT fdisk is a text-mode partitioning tool that works on GUID Partition Table (GPT) disks"
HOMEPAGE="http://www.rodsbooks.com/gdisk/"
SRC_URI="mirror://sourceforge/gptfdisk/${P}.tgz"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="amd64 x86 sparc"

DEPEND=">=dev-libs/icu-4.6"
RDEPEND="${DEPEND}"

S="${WORKDIR}/${P}"

src_install() {
    into / 
	for x in gdisk sgdisk fixparts; do
		dosbin "${x}" || die
		doman "${x}.8" || die
	done
	dodoc README NEWS
}
