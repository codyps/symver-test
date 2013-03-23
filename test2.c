#include <stdio.h>

void test1(void);
void test1(void)
{
	puts("test1");
}
__asm__(".symver test1,test@VER_0");

void test(void);
void test(void)
{
	puts("test2");
}
