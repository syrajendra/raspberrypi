#include <stdio.h>
#include <stdlib.h>

#define IS_ALIGNED(val) ((val&3) == 0)

unsigned int word_align1(unsigned int addr)
{
	unsigned int i, cnt = 2;
	if(IS_ALIGNED(addr)) return addr;
	addr &= ~3;
	while(addr&(1<<cnt)) addr &= ~(1<<cnt++);
	addr |= (1<<cnt);
	return addr;
}

unsigned int word_align2(unsigned int addr)
{
	while (addr%4) addr++;
	return addr;
}

int main(int argc, char *argv[])
{
	unsigned int rand_addr, i;
	for (i=0; i<10; i++) {
		rand_addr = rand();
		printf("Random address:  	0x%x\n", rand_addr);
		printf("Aligned address 1: 	0x%x\n", word_align1(rand_addr));
		printf("Aligned address 2: 	0x%x\n\n", word_align2(rand_addr));
	}
	return 0;
}
