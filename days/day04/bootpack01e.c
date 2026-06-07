/* path: rozi/days/day04/bootpack01e.c
 * author: redskaber
 * datetime: 2026-06-06
 * format: tab = 2
 */

void io_hlt(void);

void RoziMain(void) {

  char *p = (char *)0xA0000;

  for (int i = 0x0000; i <= 0xFFFF; i++) {
    p[i] = i & 0x0F; /* [i]p 也可以，他不是数组, 本质是基址与地址偏移的组合
                        p + i*b = i*b + p */
  }

  for (;;) {
    io_hlt();
  }
}
