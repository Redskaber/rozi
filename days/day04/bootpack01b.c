/* path: rozi/days/day04/bootpack02b.c
 * author: redskaber
 * datetime: 2026-06-06
 * format: tab = 2
 */

void io_hlt(void);
void write_mem8(int addr, int data);

void RoziMain(void) {

  int i;

  for (i = 0xA0000; i <= 0xAFFFF; i++) {
    write_mem8(i, i & 0x0F);
  }

  for (;;) {
    io_hlt();
  }
}
