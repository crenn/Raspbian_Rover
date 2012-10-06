#define CMD_BYTE 0x3F

#include <bcm2835.h>
#include <stdio.h>
#include <string.h>

const char msg[] = "Hello World!"; //Msg size should be 13 ;D

int main (int argc, char *argv[]) {
	char buf[41] = {0x00};
	int i = 0;

	if (!bcm2835_init()) {
		printf("Uh oh! This program needs to be run as root to work.\r\n");
		return 1;
	}

	bcm2835_spi_begin();
	bcm2835_spi_setBitOrder(BCM2835_SPI_BIT_ORDER_MSBFIRST);
	bcm2835_spi_setDataMode(BCM2835_SPI_MODE0);
	bcm2835_spi_setClockDivider(BCM2835_SPI_CLOCK_DIVIDER_65536);
	bcm2835_spi_chipSelect(BCM2835_SPI_CS0);
	bcm2835_spi_setChipSelectPolarity(BCM2835_SPI_CS0, LOW);
	
	buf[0] = CMD_BYTE;
	if (argc == 1) {
		printf("Default message being used.\r\nIf you want to put a custom message, try this:\r\n\n%s \"I like RPis\"\r\n\n", argv[0]);
		for(i=1; i < strlen(msg); i++) {
			buf[i] = msg[i-1];
			if (i == 40) {
				break;
			}
		}
	}
	else if (argc == 2) {
		printf("Custom message being used.\r\n\n", argv[0]);
		for(i=0; i < strlen(argv[1]); i++) {
			buf[i+1] = argv[1][i];
			if ((i+1) == 40) {
				break;
			}
		}
	}

	printf("About to send!\r\n");

	bcm2835_spi_transfern(buf, (i+1));

	bcm2835_spi_end();
	return 0;
}
