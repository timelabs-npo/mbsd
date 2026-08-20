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

/* 
 * -----------------------------------------------------------------------------
 * DMA RING DESCRIPTORS & HARDWARE REGISTERS FOR MT7981
 * -----------------------------------------------------------------------------
 * NOTHING IS TRUE. EVERYTHING IS PERMITTED.
 * Forcing DMA configuration directly.
 */

#define MTGMAC_PDMA_GLO_CFG     0x204
#define  MTGMAC_TX_DMA_EN       (1 << 0)
#define  MTGMAC_RX_DMA_EN       (1 << 1)

#define MTGMAC_PDMA_RST_IDX     0x208
#define MTGMAC_TX_BASE_PTR0     0x000 /* Ring 0 */
#define MTGMAC_TX_MAX_CNT0      0x004
#define MTGMAC_TX_CTX_IDX0      0x008
#define MTGMAC_RX_BASE_PTR0     0x100
#define MTGMAC_RX_MAX_CNT0      0x104
#define MTGMAC_RX_CRX_IDX0      0x10c

/* Hardware specific Ring limits */
#define MTGMAC_NTXDESC          256
#define MTGMAC_NRXDESC          256

/* Direct Memory Access Write Macro */
#define MTGMAC_WRITE(sc, reg, val) \
    bus_space_write_4((sc)->sc_iot, (sc)->sc_ioh, (reg), (val))

/* Direct Memory Access Read Macro */
#define MTGMAC_READ(sc, reg) \
    bus_space_read_4((sc)->sc_iot, (sc)->sc_ioh, (reg))

/*
 * Bruteforce initialization of the GMAC.
 * If the chip complains, we reset the PDMA and force it anyway.
 */
void
mtgmac_init_locked(struct mtgmac_softc *sc)
{
    /* 1. Stop existing DMA engines */
    MTGMAC_WRITE(sc, MTGMAC_PDMA_GLO_CFG, 0);

    /* 2. Hard Reset the DMA indexes */
    MTGMAC_WRITE(sc, MTGMAC_PDMA_RST_IDX, 0xFFFFFFFF);
    delay(1000); /* Wait for hardware settling */

    /* 3. Re-enable DMA engines (TX and RX) */
    MTGMAC_WRITE(sc, MTGMAC_PDMA_GLO_CFG, MTGMAC_TX_DMA_EN | MTGMAC_RX_DMA_EN);
    
    printf("mtgmac: DMA forced online. Result overrides convention.\n");
}

/* 
 * -----------------------------------------------------------------------------
 * INTERRUPT HANDLING (IRQ via FDT)
 * -----------------------------------------------------------------------------
 */
int
mtgmac_intr(void *arg)
{
    struct mtgmac_softc *sc = arg;
    uint32_t status;

    /* Read interrupt status register (Placeholder offset 0x210) */
    status = MTGMAC_READ(sc, 0x210);
    if (status == 0)
        return (0);

    /* Acknowledge interrupts */
    MTGMAC_WRITE(sc, 0x210, status);

    /* TODO: Trigger RX/TX ring processing here */
    
    return (1);
}

void
mtgmac_setup_irq(struct mtgmac_softc *sc, struct fdt_attach_args *faa)
{
    void *ih;

    /* Establish interrupt handler via Device Tree */
    ih = fdt_intr_establish(faa->fa_node, IPL_NET, mtgmac_intr, sc, sc->sc_dev.dv_xname);
    if (ih == NULL) {
        printf("%s: unable to establish interrupt\n", sc->sc_dev.dv_xname);
        return;
    }
    printf("%s: interrupting at %s\n", sc->sc_dev.dv_xname, fdt_intr_string(faa->fa_node));
}
