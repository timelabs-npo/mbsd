/*
 * MediaTek MT7981 SPI-NAND driver for OpenBSD.
 * DIRECTIVE: Absolute Pragmatism. 
 */
#include <sys/param.h>
#include <sys/systm.h>
#include <sys/device.h>
#include <machine/bus.h>
#include <dev/ofw/openfirm.h>

#define MT_SPINAND_REG_SIZE 0x1000

struct mt_spinand_softc {
    struct device sc_dev;
    bus_space_tag_t sc_iot;
    bus_space_handle_t sc_ioh;
};

int mt_spinand_match(struct device *, void *, void *);
void mt_spinand_attach(struct device *, struct device *, void *);

const struct cfattach mtspinand_ca = {
    sizeof(struct mt_spinand_softc), mt_spinand_match, mt_spinand_attach
};
struct cfdriver mtspinand_cd = { NULL, "mtspinand", DV_DULL };

int mt_spinand_match(struct device *parent, void *match, void *aux) {
    return 1; /* Match everything for now - Pragmatism */
}

void mt_spinand_attach(struct device *parent, struct device *self, void *aux) {
    printf(": MediaTek SPI-NAND Controller (Forced Init)\n");
}
