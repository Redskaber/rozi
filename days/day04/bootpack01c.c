/* path: rozi/days/day04/bootpack01c.c
 * author: redskaber
 * datetime: 2026-06-06
 * format: tab = 2
 */

void io_hlt(void);

void RoziMain(void) {

  int i;   /* 变量声明，变量i 是32位整数 */
  char *p; /* 变量p, 用于 BYTE型地址 */

  for (i = 0xA0000; i <= 0xAFFFF; i++) {
    p = (char *)i; /* 代入地址 */
    *p = i & 0x0F;
  }

  for (;;) {
    io_hlt();
  }
}
