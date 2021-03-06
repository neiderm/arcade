/***************************************************************************

Vanguard memory map (preliminary)

Note that this memory map is very similar to Nibbler

0000-03ff RAM
0400-07ff Video RAM 1
0800-0bff Video RAM 2
0c00-0fff Color RAM
1000-1fff Character mapped RAM
4000-bfff ROM

read:
3104      IN0
3105      IN1
3106      DSW ??
3107      IN2

write
3200      y scroll register
3300      x scroll register

***************************************************************************/

#include "driver.h"
#include "vidhrdw/generic.h"


extern unsigned char *vanguard_videoram2;
extern unsigned char *vanguard_characterram;

extern int vanguard_interrupt(void);
void vanguard_videoram2_w(int offset,int data);
void vanguard_scrollx_w (int offset,int data);
void vanguard_scrolly_w (int offset,int data);
extern int vanguard_vh_init(void);
extern int vanguard_vh_start(void);
extern void vanguard_vh_stop(void);
void vanguard_convert_color_prom(unsigned char *palette, unsigned char *colortable,const unsigned char *color_prom);
extern void vanguard_vh_screenrefresh(struct osd_bitmap *bitmap);
extern void vanguard_characterram_w(int offset,int data);

unsigned char colortable[64];
unsigned char palette[768];

unsigned char intensity4[] = { 0, 127, 191, 255 };
unsigned char intensity8[] = { 0, 63, 95, 127, 159, 191, 223, 255 };

unsigned char color_prom[] = 
{
	0x00, 0x80, 0x3f, 0xc6,
	0xef, 0xc6, 0x2f, 0xf8,
	0xfe, 0xc6, 0xe7, 0xc0,
	0xff, 0x2f, 0x38, 0xc6,
	0x00, 0x07, 0x80, 0x2f,
	0xef, 0x07, 0xf8, 0xff,
	0xfe, 0xff, 0xf8, 0xc0,
	0xff, 0xe7, 0xc6, 0xf4,
	0x00, 0x2f, 0xf4, 0xff,
	0xef, 0xf8, 0xff, 0x07,
	0xfe, 0xc0, 0x07, 0x3f,
	0xff, 0x3f, 0xc6, 0xc0,
	0x00, 0x38, 0xe7, 0x07,
	0xef, 0xc0, 0xf4, 0xff,
	0xfe, 0xff, 0xf8, 0xc0,
	0xff, 0xc6, 0xe7, 0xc0,
};


static struct MemoryReadAddress readmem[] =
{
	{ 0x0000, 0x1fff, MRA_RAM },
	{ 0x4000, 0xbfff, MRA_ROM },
	{ 0xf000, 0xffff, MRA_ROM },	/* for the reset / interrupt vectors */
	{ 0x3104, 0x3104, input_port_0_r },	/* IN0 */
	{ 0x3105, 0x3105, input_port_1_r },	/* IN1 */
	{ 0x3106, 0x3106, input_port_2_r },	/* DSW ?? */
	{ 0x3107, 0x3107, input_port_3_r },	/* IN2 */
	{ -1 }	/* end of table */
};

static struct MemoryWriteAddress writemem[] =
{
	{ 0x0000, 0x03ff, MWA_RAM },
	{ 0x0400, 0x07ff, videoram_w, &videoram },
	{ 0x0800, 0x0bff, vanguard_videoram2_w, &vanguard_videoram2 },
	{ 0x0c00, 0x0fff, colorram_w, &colorram },
	{ 0x1000, 0x1fff, vanguard_characterram_w, &vanguard_characterram },
	{ 0x3300, 0x3300, vanguard_scrollx_w },
	{ 0x3200, 0x3200, vanguard_scrolly_w },
	{ 0x4000, 0xbfff, MWA_ROM },
	{ -1 }	/* end of table */
};


void vanguard_convert_color_prom(unsigned char *palette, unsigned char *colortable,const unsigned char *color_prom)
{
	int i;
	unsigned char b = 0;
	for (i=0; i<256; i++)
      {
	   palette[i*3] = intensity8[b&0x7];
           palette[i*3+1] = intensity8[(b&0x38)>>3];
	   palette[i*3+2] = intensity4[(b&0xc0)>>6];
	   b++;
      }
   for (i=0; i<16; i++)
      {
      colortable[i*4] = 0;
      colortable[i*4+1] = color_prom[i*4+1];
      colortable[i*4+2] = color_prom[i*4+2];
      colortable[i*4+3] = color_prom[i*4+3];
      }
}


static struct InputPort input_ports[] =
{
	{	/* IN0 */
		0x00,
		{ OSD_KEY_D, OSD_KEY_E, OSD_KEY_F, OSD_KEY_S,
			OSD_KEY_DOWN, OSD_KEY_UP, OSD_KEY_RIGHT, OSD_KEY_LEFT },
		{ OSD_JOY_FIRE3, OSD_JOY_FIRE2, OSD_JOY_FIRE4, OSD_JOY_FIRE1,
			OSD_JOY_DOWN, OSD_JOY_UP, OSD_JOY_RIGHT, OSD_JOY_LEFT }
	},
	{	/* IN1 */
		0x00,
		{ OSD_KEY_D, OSD_KEY_E, OSD_KEY_F, OSD_KEY_S,
			OSD_KEY_DOWN, OSD_KEY_UP, OSD_KEY_RIGHT, OSD_KEY_LEFT },
		{ OSD_JOY_FIRE3, OSD_JOY_FIRE2, OSD_JOY_FIRE4, OSD_JOY_FIRE1,
			OSD_JOY_DOWN, OSD_JOY_UP, OSD_JOY_RIGHT, OSD_JOY_LEFT }
	},
	{	/* DSW ?? */
		0x00,
		{ 0, 0, 0, 0, OSD_KEY_F1, 0, 0, 0 },
		{ 0, 0, 0, 0, 0, 0, 0, 0 }
	},
	{	/* IN2 */
		0x00,
		{ 0, 0, 0, 0, 0, 0, OSD_KEY_2, OSD_KEY_1 },
		{ 0, 0, 0, 0, 0, 0, 0, 0 }
	},
	{ -1 }	/* end of table */
};


static struct KEYSet keys[] =
{
        { 0, 5, "MOVE UP" },
        { 0, 7, "MOVE LEFT"  },
        { 0, 6, "MOVE RIGHT" },
        { 0, 4, "MOVE DOWN" },
        { 0, 1, "FIRE UP" },
        { 0, 3, "FIRE LEFT"  },
        { 0, 2, "FIRE RIGHT" },
        { 0, 0, "FIRE DOWN" },
        { -1 }
};



static struct DSW dsw[] =
{
	{ 2, 0x03, "LIVES", { "3", "4", "5", "6" } },
	{ 2, 0x04, "DIFFICULTY", { "EASY", "HARD" } },
	{ -1 }
};



struct GfxLayout vanguard_charlayout =
{
        8,8,    /* 8*8 characters */
        256,    /* 256 characters */
        2,      /* 2 bits per pixel */
        { 0, 256*8*8 }, /* the two bitplanes are separated */
        { 7*8, 6*8, 5*8, 4*8, 3*8, 2*8, 1*8, 0*8 },
        { 0, 1, 2, 3, 4, 5, 6, 7 },
        8*8     /* every char takes 8 consecutive bytes */
};

static struct GfxLayout charlayout2 =
{
	8,8,	/* 8*8 characters */
	256,	/* 256 characters */
	2,	/* 2 bits per pixel */
	{ 0, 256*8*8 },	/* the two bitplanes are separated */
	{ 7*8, 6*8, 5*8, 4*8, 3*8, 2*8, 1*8, 0*8 },
	{ 0, 1, 2, 3, 4, 5, 6, 7 },
	8*8	/* every char takes 8 consecutive bytes */
};



static struct GfxDecodeInfo gfxdecodeinfo[] =
{
	{ 0, 0xf000, &vanguard_charlayout,  32, 16 },	/* the game dynamically modifies this */
	{ 1, 0x0000, &charlayout2,        	0,  16 },
	{ -1 } /* end of array */
};





static struct MachineDriver machine_driver =
{
	/* basic machine hardware */
	{
		{
			CPU_M6502,
			1000000,	/* 1 Mhz ???? */
			0,
			readmem,writemem,0,0,
			vanguard_interrupt,1
		}
	},
	60,
	0,

	/* video hardware */
	32*8, 32*8, { 2*8, 30*8-1, 0*8, 32*8-1 },
	gfxdecodeinfo,
	256, 64,
	vanguard_convert_color_prom,

	0,
	generic_vh_start,
	generic_vh_stop,
	vanguard_vh_screenrefresh,

	/* sound hardware */
	0,
	0,
	0,
	0,
	0
};



/***************************************************************************

  Game driver(s)

***************************************************************************/

ROM_START( vanguard_rom )
	ROM_REGION(0x10000)	/* 64k for code */
	ROM_LOAD( "sk4_ic07.bin", 0x4000, 0x1000 )
	ROM_LOAD( "sk4_ic08.bin", 0x5000, 0x1000 )
	ROM_LOAD( "sk4_ic09.bin", 0x6000, 0x1000 )
	ROM_LOAD( "sk4_ic10.bin", 0x7000, 0x1000 )
	ROM_LOAD( "sk4_ic13.bin", 0x8000, 0x1000 )
	ROM_LOAD( "sk4_ic14.bin", 0x9000, 0x1000 )
	ROM_LOAD( "sk4_ic15.bin", 0xa000, 0x1000 )
	ROM_LOAD( "sk4_ic16.bin", 0xb000, 0x1000 )
	ROM_LOAD( "sk4_ic13.bin", 0xf000, 0x1000 )	/* for the reset and interrupt vectors */

	ROM_REGION(0x1000)	/* temporary space for graphics (disposed after conversion) */
	ROM_LOAD( "sk5_ic50.bin", 0x0000, 0x0800 )
	ROM_LOAD( "sk5_ic51.bin", 0x0800, 0x0800 )
ROM_END



struct GameDriver vanguard_driver =
{
	"vanguard",
	&machine_driver,

	vanguard_rom,
	0, 0,
	0,

	input_ports, dsw, keys,

	color_prom, palette, colortable,
	{ 0x00,0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,	/* numbers */
		0x0a,0x0b,0x0c,0x0d,0x0e,0x0f,0x10,0x11,0x12,0x13,0x14,0x15,0x16,	/* letters */
		0x17,0x18,0x19,0x1a,0x1b,0x1c,0x1d,0x1e,0x1f,0x20,0x21,0x22,0x23 },
	0x06, 0x04,
	8*13, 8*16, 0x00,

	0, 0
};
