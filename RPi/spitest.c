#define CMD_BYTE 0x3F
#define RET_BYTE 0x6A

#include <bcm2835.h>
#include <stdio.h>

int main (int argc, char **argv) {
	char buf[2] = {CMD_BYTE, 0xFF};
	int tries = 0;

	if (!bcm2835_init()) {
		return 1;
	}

	bcm2835_spi_begin();
	bcm2835_spi_setBitOrder(BCM2835_SPI_BIT_ORDER_MSBFIRST);
	bcm2835_spi_setDataMode(BCM2835_SPI_MODE0);
	bcm2835_spi_setClockDivider(BCM2835_SPI_CLOCK_DIVIDER_65536);
	bcm2835_spi_chipSelect(BCM2835_SPI_CS0);
	bcm2835_spi_setChipSelectPolarity(BCM2835_SPI_CS0, LOW);

	printf("About to send! \r\n");

	while (tries < 10) {

		bcm2835_spi_transfern(buf, 2);

		printf("Return Value was %02X \r\n", buf[1]);
		
		buf[0] = (char)CMD_BYTE;
		buf[1] = 0xFF;
		tries++;
	}

	bcm2835_spi_end();
	return 0;
}
