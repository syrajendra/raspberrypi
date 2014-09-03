#include <stdio.h>
#include <stdlib.h>

#define IS_ALIGNED(val) ((val&3) == 0)

unsigned int align_address(unsigned int addr)
{
	unsigned int i, cnt = 2;
	if(IS_ALIGNED(addr)) return addr;
	addr &= ~3;
	while(addr&(1<<cnt)) addr &= ~(1<<cnt++);
	addr |= (1<<cnt);
	return addr;
}

int main(int argc, char *argv[])
{
	unsigned int rand_addr, i;
	for (i=0; i<10; i++) {
		rand_addr = rand();
		printf("Random address:  0x%x\n", rand_addr);
		printf("Aligned address: 0x%x\n\n", align_address(rand_addr));
	}
	return 0;
}
