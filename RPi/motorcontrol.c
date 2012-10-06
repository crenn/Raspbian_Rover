#define CMD_BYTE 0x15
#define RET_BYTE 0x6A

#include <bcm2835.h>
#include <stdio.h>

#define STOP         0x00
#define MOT_FORWARD  0x01
#define MOT_BACKWARD 0x02
#define MOT_LEFT     0x03
#define MOT_RIGHT    0x04

int main (int argc, char *argv[]) {
	char buf[4];
	int numbyte;

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
	numbyte = 2;

	if (argc == 1) {
		printf("Default direction used: FORWARD\r\n");
		buf[1] = MOT_FORWARD;
	}
	else if (argc == 2) {
		printf("Given direction being used.\r\n");
		if (argv[1][0] == 'f') {
			buf[1] = MOT_FORWARD;
		}
		else if (argv[1][0] == 'b') {
			buf[1] = MOT_BACKWARD;
		}
		else if (argv[1][0] == 'l') {
			buf[1] = MOT_LEFT;
		}
		else if (argv[1][0] == 'r') {
			buf[1] = MOT_RIGHT;
		}
		else {
			buf[1] = STOP;
		}
	}
	else if (argc == 3) {
		printf("Given direction being used.\r\n");
		if (argv[1][0] == 'f') {
			buf[1] = MOT_FORWARD;
		}
		else if (argv[1][0] == 'b') {
			buf[1] = MOT_BACKWARD;
		}
		else if (argv[1][0] == 'l') {
			buf[1] = MOT_LEFT;
		}
		else if (argv[1][0] == 'r') {
			buf[1] = MOT_RIGHT;
		}
		else {
			buf[1] = STOP;
		}
	}

	printf("About to send! \r\n");

	bcm2835_spi_transfern(buf, numbyte);

	printf("Return Value was %02X \r\n", buf[1]);

	bcm2835_spi_end();
	return 0;
}
