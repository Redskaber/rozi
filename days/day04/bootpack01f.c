/* path: rozi/days/day04/bootpack01f.c
 * author: redskaber
 * datetime: 2026-06-06
 * format: tab = 2
 *
 * TODO: 色号和颜色处理
 *
 * 只要有以下这16种颜色就足够了。所以这次我们也使用这16种颜色，并给它们编上号码0-15:
 *  #000000: 黑     #00ffff: 浅亮蓝     #000084: 暗蓝
 *  #ff0000: 亮红   #ffffff: 白         #840084: 暗紫
 *  #00ff00: 亮绿   #c6c6c6: 亮灰       #008484: 浅暗蓝
 *  #ffff00: 亮黄   #840000: 暗红       #848484: 暗灰
 *  #0000ff: 亮蓝   #008400: 暗绿
 *  #ff00ff: 亮紫   #848400: 暗黄
 *
 * http://community.osdev.info/?VGA
 * IN / OUT
 * CLI / STI
 * EFLAGS 寄存器 from FLAGS (16 bits) extra to (32 bits)
 * FLAGS (进位标志位，中断标志位，...)
 *  进位标志位 => JC  || JNC (0 | 1)
 *  中断标志位 => readto EFLAGS AND  check bit 9 value (0 | 1)
 *
 * 15  14  13-12   11   10   09   08   07   06   05   04   03   02   01   00
 *[ ] [NT] [IOPL] [OF] [DF] [IF] [TF] [SF] [ZF] [  ] [AF] [  ] [PF] [  ] [CF]
 */

/* nasm export */
void io_hlt(void);
void io_cli(void);
void io_out8(int port, int data);
void io_store_eflags(int eflags);
int io_load_eflags(void);

/* decra */
void init_palette(void);
void set_palette(int start, int end, unsigned char *rgb);

void RoziMain(void) {

  char *p = (char *)0xA0000;

  init_palette(); /* 设定调色板 */

  for (int i = 0x0000; i <= 0xFFFF; i++) {
    p[i] = i & 0x0F;
  }

  for (;;) {
    io_hlt();
  }
}

void init_palette(void) {
  static unsigned char table_rgb[16 * 3] = {
      0x00, 0x00, 0x00, /* 0: 黑   */
      0xFF, 0x00, 0x00, /* 1: 亮红 */
      0x00, 0xFF, 0x00, /* 2: 亮绿 */
      0xFF, 0xFF, 0x00, /* 3: 亮黄 */
      0x00, 0x00, 0xFF, /* 4: 亮蓝 */
      0xFF, 0x00, 0xFF, /* 5: 亮紫 */
      0x00, 0xFF, 0xFF, /* 6: 浅亮蓝 */
      0xFF, 0xFF, 0xFF, /* 7: 白 */
      0xC6, 0xC6, 0xC6, /* 8: 亮灰 */
      0x84, 0x00, 0x00, /* 9: 暗红 */
      0x00, 0x84, 0x00, /* 10: 暗绿 */
      0x84, 0x84, 0x00, /* 11: 暗黄 */
      0x00, 0x00, 0x84, /* 12: 暗青 */
      0x84, 0x00, 0x84, /* 13: 暗紫 */
      0x00, 0x84, 0x84, /* 14: 浅暗蓝 */
      0x84, 0x84, 0x84, /* 15: 暗灰 */
  };

  set_palette(0, 15, table_rgb);
  return;
  /* C语言中的static char语句只能用于数据，相当于汇编中的DB指令 */
}

void set_palette(int start, int end, unsigned char *rgb) {
  int eflags = io_load_eflags(); /* 记录中断许可标志的值*/
  io_cli();                      /* 将中断许可标志置为0，禁止中断 */
  io_out8(0x03C8, start);
  for (int i = start; i <= end; i++) {
    io_out8(0x03C9, rgb[0] / 4);
    io_out8(0x03C9, rgb[1] / 4);
    io_out8(0x03C9, rgb[2] / 4);
    rgb += 3;
  }
  io_store_eflags(eflags); /* 复原中断许可标志 */
  return;
}
