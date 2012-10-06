#include <stdio.h>
#include <string.h>

int main (int argc, char *argv[]) {
	int i,j;
	printf("I got this many argcs : %d\r\n",argc);
	for (i=0; i < argc; i++) {
		printf("argv[%d] Contained : ", i);
		for (j=0; j < strlen(argv[i]); j++) {
			printf("%c", argv[i][j]);
		}
		printf("\r\n");
	}
	return 0;
}