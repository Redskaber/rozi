/* path: rozi/days/day03/bootpack.c
 * author: redskaber
 * datetime: 2026-06-05
 * format: tab = 2
 */

/* 告诉 C 编译器，有个函数在别的文件里 */
void io_hlt(void);

void RoziMain(void) {
fin:
  io_hlt(); /* 执行 nasmfunc.nasm 中的 io_hlt */
  goto fin;
}
