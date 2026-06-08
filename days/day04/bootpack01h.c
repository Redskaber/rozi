/* path: rozi/days/day04/bootpack01h.c
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
 *
 *
 * 320 * 200 = 64 000
 * (x, y) = 0xA0000 + x + y * 320
 */

/* define */
#define COL8_000000 0
#define COL8_FF0000 1
#define COL8_00FF00 2
#define COL8_FFFF00 3
#define COL8_0000FF 4
#define COL8_FF00FF 5
#define COL8_00FFFF 6
#define COL8_FFFFFF 7
#define COL8_C6C6C6 8
#define COL8_840000 9
#define COL8_008400 10
#define COL8_848400 11
#define COL8_000084 12
#define COL8_840084 13
#define COL8_008484 14
#define COL8_848484 15

/* nasm export */
void io_hlt(void);
void io_cli(void);
void io_out8(int port, int data);
void io_store_eflags(int eflags);
int io_load_eflags(void);

/* decra */
void init_palette(void);
void set_palette(int start, int end, unsigned char *rgb);
void boxfill8(unsigned char *vram, int xsize, unsigned char c, int x0, int y0,
              int x1, int y1);

void RoziMain(void) {

  unsigned char *vram = (unsigned char *)0xA0000;
  int xsize = 320;
  int ysize = 200;

  init_palette(); /* 设定调色板 */

  boxfill8(vram, xsize, COL8_008484, 0, 0, xsize - 1, ysize - 29);
  boxfill8(vram, xsize, COL8_C6C6C6, 0, ysize - 28, xsize - 1, ysize - 28);
  boxfill8(vram, xsize, COL8_FFFFFF, 0, ysize - 27, xsize - 1, ysize - 27);
  boxfill8(vram, xsize, COL8_C6C6C6, 0, ysize - 26, xsize - 1, ysize - 1);
  boxfill8(vram, xsize, COL8_FFFFFF, 3, ysize - 24, 59, ysize - 24);
  boxfill8(vram, xsize, COL8_FFFFFF, 2, ysize - 24, 2, ysize - 4);
  boxfill8(vram, xsize, COL8_848484, 3, ysize - 4, 59, ysize - 4);
  boxfill8(vram, xsize, COL8_848484, 59, ysize - 23, 59, ysize - 5);
  boxfill8(vram, xsize, COL8_000000, 2, ysize - 3, 59, ysize - 3);
  boxfill8(vram, xsize, COL8_000000, 60, ysize - 24, 60, ysize - 3);
  boxfill8(vram, xsize, COL8_848484, xsize - 47, ysize - 24, xsize - 4,
           ysize - 24);
  boxfill8(vram, xsize, COL8_848484, xsize - 47, ysize - 23, xsize - 47,
           ysize - 4);
  boxfill8(vram, xsize, COL8_FFFFFF, xsize - 47, ysize - 3, xsize - 4,
           ysize - 3);
  boxfill8(vram, xsize, COL8_FFFFFF, xsize - 3, ysize - 24, xsize - 3,
           ysize - 3);

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

void boxfill8(unsigned char *vram, int xsize, unsigned char c, int x0, int y0,
              int x1, int y1) {
  int x, y;
  for (y = y0; y <= y1; y++) {
    for (x = x0; x <= x1; x++)
      vram[y * xsize + x] = c;
  }
  return;
}
