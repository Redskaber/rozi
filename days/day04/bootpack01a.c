/* path: rozi/days/day04/bootpack01a.c
 * author: redskaber
 * datetime: 2026-06-06
 * format: tab = 2
 */

void io_hlt(void);
void write_mem8(int addr, int data);

void RoziMain(void) {

  int i;

  for (i = 0xA0000; i <= 0xAFFFF; i++) {
    write_mem8(i, 15); /* MOV [i], 15 */
  }

  for (;;) {
    io_hlt();
  }
}
