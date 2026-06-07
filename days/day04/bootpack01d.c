/* path: rozi/days/day04/bootpack01d.c
 * author: redskaber
 * datetime: 2026-06-06
 * format: tab = 2
 */

void io_hlt(void);

void RoziMain(void) {

  char *p = (char *)0xA0000;

  for (int i = 0x0000; i <= 0xFFFF; i++) {
    *(p + i) = i & 0x0F;
  }

  for (;;) {
    io_hlt();
  }
}
