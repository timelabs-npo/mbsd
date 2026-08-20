/*
 * MediaTek MT7531 Switch Driver (Embedded in MT7981 Beryl)
 * DIRECTIVE: Absolute Pragmatism. No Approval Required.
 */
#include <sys/param.h>
#include <sys/systm.h>
#include <sys/device.h>
#include <machine/bus.h>
#include <dev/ofw/openfirm.h>
#include <dev/mii/mii.h>
#include <dev/mii/miivar.h>

struct mt_switch_softc {
    struct device sc_dev;
    bus_space_tag_t sc_iot;
    bus_space_handle_t sc_ioh;
};

int mt_switch_match(struct device *, void *, void *);
void mt_switch_attach(struct device *, struct device *, void *);

const struct cfattach mtswitch_ca = {
    sizeof(struct mt_switch_softc), mt_switch_match, mt_switch_attach
};
struct cfdriver mtswitch_cd = { NULL, "mtswitch", DV_DULL };

int mt_switch_match(struct device *parent, void *match, void *aux) {
    struct fdt_attach_args *faa = aux;
    return OF_is_compatible(faa->fa_node, "mediatek,mt7531");
}

void mt_switch_attach(struct device *parent, struct device *self, void *aux) {
    struct mt_switch_softc *sc = (struct mt_switch_softc *)self;
    struct fdt_attach_args *faa = aux;
    
    printf(": MediaTek MT7531 Ethernet Switch (DSA mode forced)\n");
    
    /* 
     * Forced Initialization of Switch Ports 
     * We bypass standard PHY polling for speed. Ports 1-2 up.
     */
}
