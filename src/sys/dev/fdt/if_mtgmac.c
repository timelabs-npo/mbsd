/*
 * Copyright (c) 2026 SA/MIO <sa@mio.local>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

/*
 * MediaTek MT7981 (GL-MT3000) Gigabit MAC (GMAC) driver for OpenBSD.
 * Initial scaffolding for MBSD.
 */

#include <sys/param.h>
#include <sys/systm.h>
#include <sys/device.h>
#include <sys/socket.h>
#include <sys/sockio.h>

#include <net/if.h>
#include <net/if_media.h>
#include <netinet/in.h>
#include <netinet/if_ether.h>

#include <machine/bus.h>
#include <machine/fdt.h>

#include <dev/ofw/openfirm.h>
#include <dev/ofw/ofw_misc.h>
#include <dev/ofw/ofw_pinctrl.h>
#include <dev/ofw/fdt.h>

/* MT7981 specific registers will be mapped here */
#define MTGMAC_REG_SIZE    0x1000

struct mtgmac_softc {
    struct device       sc_dev;
    bus_space_tag_t     sc_iot;
    bus_space_handle_t  sc_ioh;
    
    struct arpcom       sc_ac;
    struct mii_data     sc_mii;
    
    int                 sc_node;
};

int  mtgmac_match(struct device *, void *, void *);
void mtgmac_attach(struct device *, struct device *, void *);

const struct cfattach mtgmac_ca = {
    sizeof(struct mtgmac_softc), mtgmac_match, mtgmac_attach
};

struct cfdriver mtgmac_cd = {
    NULL, "mtgmac", DV_IFNET
};

int
mtgmac_match(struct device *parent, void *match, void *aux)
{
    struct fdt_attach_args *faa = aux;

    /* Match the exact compatible string from our MT7981 DTS */
    return OF_is_compatible(faa->fa_node, "mediatek,mt7981-gmac");
}

void
mtgmac_attach(struct device *parent, struct device *self, void *aux)
{
    struct mtgmac_softc *sc = (struct mtgmac_softc *)self;
    struct fdt_attach_args *faa = aux;
    struct ifnet *ifp;

    sc->sc_node = faa->fa_node;
    sc->sc_iot = faa->fa_iot;

    if (bus_space_map(sc->sc_iot, faa->fa_reg[0].addr,
        faa->fa_reg[0].size, 0, &sc->sc_ioh)) {
        printf(": cannot map registers\n");
        return;
    }

    printf(": MediaTek MT7981 GMAC\n");

    /* Initialize interface */
    ifp = &sc->sc_ac.ac_if;
    strlcpy(ifp->if_xname, sc->sc_dev.dv_xname, IFNAMSIZ);
    ifp->if_softc = sc;
    ifp->if_flags = IFF_BROADCAST | IFF_SIMPLEX | IFF_MULTICAST;
    // ifp->if_ioctl = mtgmac_ioctl;
    // ifp->if_start = mtgmac_start;

    if_attach(ifp);
    ether_ifattach(ifp);
}
