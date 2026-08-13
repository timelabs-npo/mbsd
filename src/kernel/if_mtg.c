/*
 * MediaTek MT7981 Ethernet MAC (GMAC) stub driver
 */

#include <sys/param.h>
#include <sys/systm.h>
#include <sys/device.h>
#include <machine/bus.h>
#include <machine/fdt.h>
#include <dev/ofw/openfirm.h>
#include <dev/ofw/fdt.h>

struct mtg_softc {
	struct device		sc_dev;
	bus_space_tag_t		sc_iot;
	bus_space_handle_t	sc_ioh;
};

int	mtg_match(struct device *, void *, void *);
void	mtg_attach(struct device *, struct device *, void *);

const struct cfattach mtg_ca = {
	sizeof(struct mtg_softc), mtg_match, mtg_attach
};

struct cfdriver mtg_cd = {
	NULL, "mtg", DV_IFNET
};

int
mtg_match(struct device *parent, void *match, void *aux)
{
	struct fdt_attach_args *faa = aux;

	if (OF_is_compatible(faa->fa_node, "mediatek,mt7981-eth"))
		return 1;

	return 0;
}

void
mtg_attach(struct device *parent, struct device *self, void *aux)
{
	struct mtg_softc *sc = (struct mtg_softc *)self;
	struct fdt_attach_args *faa = aux;

	sc->sc_iot = faa->fa_iot;
	if (bus_space_map(sc->sc_iot, faa->fa_reg[0].addr,
	    faa->fa_reg[0].size, 0, &sc->sc_ioh)) {
		printf(": can't map registers\n");
		return;
	}

	printf(": MT7981 GMAC (stub)\n");
}
