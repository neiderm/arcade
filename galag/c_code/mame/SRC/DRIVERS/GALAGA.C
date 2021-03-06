/***************************************************************************

Galaga memory map (preliminary)

CPU #1:
0000-3fff ROM
CPU #2:
0000-1fff ROM
CPU #3:
0000-1fff ROM
ALL CPUS:
8000-83ff Video RAM
8400-87ff Color RAM
8b80-8bff sprite code/color
9380-93ff sprite position
9b80-9bff sprite control
8800-9fff RAM

read:
6800-6807 dip switches (only bits 0 and 1 are used - bit 0 is DSW1, bit 1 is DSW2)
          dsw1:
            bit 6-7 lives
            bit 3-5 bonus
            bit 0-2 coins per play
		  dsw2: (bootleg version, the original version is slightly different)
		    bit 7 cocktail/upright (1 = upright)
            bit 6 ?
            bit 5 RACK TEST
            bit 4 pause (0 = paused, 1 = not paused)
            bit 3 ?
            bit 2 ?
            bit 0-1 difficulty
7000-     custom IO chip return values
7100      custom IO chip status ($10 = command executed)

write:
6805      sound voice 1 waveform (nibble)
6811-6813 sound voice 1 frequency (nibble)
6815      sound voice 1 volume (nibble)
680a      sound voice 2 waveform (nibble)
6816-6818 sound voice 2 frequency (nibble)
681a      sound voice 2 volume (nibble)
680f      sound voice 3 waveform (nibble)
681b-681d sound voice 3 frequency (nibble)
681f      sound voice 3 volume (nibble)
6820      cpu #1 irq acknowledge/enable
6821      cpu #2 irq acknowledge/enable
6822      cpu #3 nmi acknowledge/enable
6823      if 0, halt CPU #2 and #3
6830      Watchdog reset?
7000-     custom IO chip parameters
7100      custom IO chip command (see machine/galaga.c for more details)
a000-a002 starfield scroll direction/speed (only bit 0 is significant)
a003-a005 starfield blink?
a007      flip screen

Interrupts:
CPU #1 IRQ mode 1
       NMI is triggered by the custom IO chip to signal the CPU to read/write
	       parameters
CPU #2 IRQ mode 1
CPU #3 NMI (@120Hz)

***************************************************************************/

#include "driver.h"
#include "vidhrdw/generic.h"

extern unsigned char *galaga_sharedram;
extern int galaga_sharedram_r(int offset);
extern void galaga_sharedram_w(int offset,int data);
extern int galaga_dsw_r(int offset);
extern void galaga_interrupt_enable_1_w(int offset,int data);
extern void galaga_interrupt_enable_2_w(int offset,int data);
extern void galaga_interrupt_enable_3_w(int offset,int data);
extern void galaga_halt_w(int offset,int data);
extern int galaga_customio_r(int offset);
extern void galaga_customio_w(int offset,int data);
extern int galaga_interrupt_1(void);
extern int galaga_interrupt_2(void);
extern int galaga_interrupt_3(void);

extern unsigned char *galaga_starcontrol;
extern int galaga_vh_start(void);
extern void galaga_vh_screenrefresh(struct osd_bitmap *bitmap);
extern void galaga_vh_convert_color_prom(unsigned char *palette, unsigned char *colortable,const unsigned char *color_prom);

extern void pengo_sound_w(int offset,int data);
extern int rallyx_sh_start(void);
extern void pengo_sh_update(void);
extern unsigned char *pengo_soundregs;



static struct MemoryReadAddress readmem_cpu1[] =
{
	{ 0x8000, 0x9fff, galaga_sharedram_r, &galaga_sharedram },
	{ 0x6800, 0x6807, galaga_dsw_r },
	{ 0x7100, 0x7100, galaga_customio_r },
	{ 0x0000, 0x3fff, MRA_ROM },
	{ -1 }	/* end of table */
};

static struct MemoryReadAddress readmem_cpu2[] =
{
	{ 0x8000, 0x9fff, galaga_sharedram_r },
	{ 0x6800, 0x6807, galaga_dsw_r },
	{ 0x0000, 0x1fff, MRA_ROM },
	{ -1 }	/* end of table */
};

static struct MemoryReadAddress readmem_cpu3[] =
{
	{ 0x8000, 0x9fff, galaga_sharedram_r },
	{ 0x6800, 0x6807, galaga_dsw_r },
	{ 0x0000, 0x1fff, MRA_ROM },
	{ -1 }	/* end of table */
};

static struct MemoryWriteAddress writemem_cpu1[] =
{
	{ 0x8000, 0x9fff, galaga_sharedram_w },
	{ 0x6830, 0x6830, MWA_NOP },
	{ 0x7100, 0x7100, galaga_customio_w },
	{ 0xa000, 0xa005, MWA_RAM, &galaga_starcontrol },
	{ 0x6820, 0x6820, galaga_interrupt_enable_1_w },
	{ 0x6822, 0x6822, galaga_interrupt_enable_3_w },
	{ 0x6823, 0x6823, galaga_halt_w },
	{ 0x8b80, 0x8bff, MWA_RAM, &spriteram },	/* these three are here just to initialize */
	{ 0x9380, 0x93ff, MWA_RAM, &spriteram_2 },	/* the pointers. The actual writes are */
	{ 0x9b80, 0x9bff, MWA_RAM, &spriteram_3 },	/* handled by galaga_sharedram_w() */
	{ 0x8000, 0x83ff, MWA_RAM, &videoram },	/* dirtybuffer[] handling is not needed because */
	{ 0x8400, 0x87ff, MWA_RAM, &colorram },	/* characters are redrawn every frame */
	{ 0x0000, 0x3fff, MWA_ROM },
	{ -1 }	/* end of table */
};

static struct MemoryWriteAddress writemem_cpu2[] =
{
	{ 0x8000, 0x9fff, galaga_sharedram_w },
	{ 0x6821, 0x6821, galaga_interrupt_enable_2_w },
	{ 0x0000, 0x1fff, MWA_ROM },
	{ -1 }	/* end of table */
};

static struct MemoryWriteAddress writemem_cpu3[] =
{
	{ 0x8000, 0x9fff, galaga_sharedram_w },
	{ 0x6800, 0x681f, pengo_sound_w, &pengo_soundregs },
	{ 0x6822, 0x6822, galaga_interrupt_enable_3_w },
	{ 0x0000, 0x1fff, MWA_ROM },
	{ -1 }	/* end of table */
};



static struct InputPort input_ports[] =
{
	{	/* DSW1 */
		0x97,
		{ 0, 0, 0, 0, 0, 0, 0, 0 },
		{ 0, 0, 0, 0, 0, 0, 0, 0 }
	},
	{	/* DSW2 */
		0xf7,
		{ 0, 0, 0, 0, 0, OSD_KEY_F1, 0, 0 },
		{ 0, 0, 0, 0, 0, 0, 0, 0 }
	},
	{	/* IN0 */
		0xff,
		{ 0, OSD_KEY_RIGHT, 0, OSD_KEY_LEFT, OSD_KEY_CONTROL, 0, 0, 0 },
		{ 0, OSD_JOY_RIGHT, 0, OSD_JOY_LEFT, OSD_JOY_FIRE, 0, 0, 0 },
	},
	{ -1 }	/* end of table */
};


static struct KEYSet keys[] =
{
        { 2, 3, "MOVE LEFT"  },
        { 2, 1, "MOVE RIGHT" },
        { 2, 4, "FIRE"       },
        { -1 }
};


static struct DSW galaga_dsw[] =
{
	{ 0, 0xc0, "LIVES", { "2", "4", "3", "5" } },
 	{ 0, 0x38, "BONUS", { "NONE", "30K 100K 100K", "20K 70K 70K", "20K 60K", "20K 60K 60K", "30K 120K 120K", "20K 80K 80K", "30K 80K" }, 1 },
	{ 1, 0x06, "DIFFICULTY", { "MEDIUM", "HARD", "HARDEST", "EASY" }, 1 },
	{ 1, 0x08, "DEMO SOUNDS", { "ON", "OFF" }, 1 },
	{ 1, 0x01, "2 CREDITS GAME", { "1 PLAYER", "2 PLAYERS" }, 1 },
	{ 1, 0x40, "SW7B", { "ON", "OFF" }, 1 },
	{ -1 }
};

static struct DSW galagabl_dsw[] =
{
	{ 0, 0xc0, "LIVES", { "2", "4", "3", "5" } },
 	{ 0, 0x38, "BONUS", { "NONE", "30K 100K 100K", "20K 70K 70K", "20K 60K", "20K 60K 60K", "30K 120K 120K", "20K 80K 80K", "30K 80K" }, 1 },
	{ 1, 0x03, "DIFFICULTY", { "MEDIUM", "HARD", "HARDEST", "EASY" }, 1 },
	{ 1, 0x08, "DEMO SOUNDS", { "ON", "OFF" }, 1 },
	{ 1, 0x04, "SW3B", { "ON", "OFF" }, 1 },
	{ 1, 0x40, "SW7B", { "ON", "OFF" }, 1 },
	{ -1 }
};



static struct GfxLayout charlayout =
{
	8,8,	       /* 8*8 characters */
	128,	       /* 128 characters */
	2,             /* 2 bits per pixel */
	{ 0, 4},       /* the two bitplanes for 4 pixels are packed into one byte */
	{ 7*8, 6*8, 5*8, 4*8, 3*8, 2*8, 1*8, 0*8 },   /* characters are rotated 90 degrees */
	{ 8*8+0, 8*8+1, 8*8+2, 8*8+3, 0, 1, 2, 3 },   /* bits are packed in groups of four */
	16*8	       /* every char takes 16 bytes */
};

static struct GfxLayout charlayout1 =
{
	8,8,	        /* 8*8 characters */
	128,	        /* 128 characters */
	2,	        /* 2 bits per pixel */
	{ 0, 4},	/* the two bitplanes for 4 pixels are packed into one byte */
	{ 7*8, 6*8, 5*8, 4*8, 3*8, 2*8, 1*8, 0*8 }, /* characters are rotated 90 degrees */
	{ 3, 2, 1, 0, 8*8+3, 8*8+2, 8*8+1, 8*8+0 }, /* bits are packed in groups of four */
	16*8	/* every char takes 16 bytes */
};
static struct GfxLayout spritelayout =
{
	16,16,	        /* 16*16 sprites */
	128,	        /* 128 sprites */
	2,	        /* 2 bits per pixel */
	{ 0, 4 },	/* the two bitplanes for 4 pixels are packed into one byte */
	{ 39 * 8, 38 * 8, 37 * 8, 36 * 8, 35 * 8, 34 * 8, 33 * 8, 32 * 8,
			7 * 8, 6 * 8, 5 * 8, 4 * 8, 3 * 8, 2 * 8, 1 * 8, 0 * 8 },
	{ 0, 1, 2, 3, 8*8, 8*8+1, 8*8+2, 8*8+3, 16*8+0, 16*8+1, 16*8+2, 16*8+3,
			24*8+0, 24*8+1, 24*8+2, 24*8+3 },
	64*8	/* every sprite takes 64 bytes */
};
/* there's nothing here, this is just a placeholder to let the video hardware */
/* pick the color table */
static struct GfxLayout starslayout =
{
	1,1,
	0,
	1,	/* 1 star = 1 color */
	{ 0 },
	{ 0 },
	{ 0 },
	0
};



static struct GfxDecodeInfo gfxdecodeinfo[] =
{
	{ 1, 0x0000, &charlayout,       0, 32 },
	{ 1, 0x0000, &charlayout1,      0, 32 },
	{ 1, 0x1000, &spritelayout,  32*4, 32 },
	{ 0, 0,      &starslayout,   64*4, 64 },
	{ -1 } /* end of array */
};



static unsigned char color_prom[] =
{
	/* 5N - palette */
	0xF6,0x07,0x3F,0x27,0x2F,0xC7,0xF8,0xED,0x16,0x38,0x21,0xD8,0xC4,0xC0,0xA0,0x00,
	0xF6,0x07,0x3F,0x27,0x00,0xC7,0xF8,0xE8,0x00,0x38,0x00,0xD8,0xC5,0xC0,0x00,0x00,
	/* 2N - chars */
	0x0F,0x00,0x00,0x06,0x0F,0x0D,0x01,0x00,0x0F,0x02,0x0C,0x0D,0x0F,0x0B,0x01,0x00,
	0x0F,0x01,0x00,0x01,0x0F,0x00,0x00,0x02,0x0F,0x00,0x00,0x03,0x0F,0x00,0x00,0x05,
	0x0F,0x00,0x00,0x09,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x0F,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
	0x0F,0x0B,0x07,0x06,0x0F,0x06,0x0B,0x07,0x0F,0x07,0x06,0x0B,0x0F,0x0F,0x0F,0x01,
	0x0F,0x0F,0x0B,0x0F,0x0F,0x02,0x0F,0x0F,0x0F,0x06,0x06,0x0B,0x0F,0x06,0x0B,0x0B,
	/* 1C - sprites */
	0x0F,0x08,0x0E,0x02,0x0F,0x05,0x0B,0x0C,0x0F,0x00,0x0B,0x01,0x0F,0x01,0x0B,0x02,
	0x0F,0x08,0x0D,0x02,0x0F,0x06,0x01,0x04,0x0F,0x09,0x01,0x05,0x0F,0x07,0x0B,0x01,
	0x0F,0x01,0x06,0x0B,0x0F,0x01,0x0B,0x00,0x0F,0x01,0x02,0x00,0x0F,0x00,0x01,0x06,
	0x0F,0x00,0x00,0x06,0x0F,0x03,0x0B,0x09,0x0F,0x06,0x02,0x00,0x00,0x00,0x00,0x00,
	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
};




/* waveforms for the audio hardware */
static unsigned char samples[8*32] =
{
	0xff,0x11,0x22,0x33,0x44,0x55,0x55,0x66,0x66,0x66,0x55,0x55,0x44,0x33,0x22,0x11,
	0xff,0xdd,0xcc,0xbb,0xaa,0x99,0x99,0x88,0x88,0x88,0x99,0x99,0xaa,0xbb,0xcc,0xdd,

	0xff,0x11,0x22,0x33,0xff,0x55,0x55,0xff,0x66,0xff,0x55,0x55,0xff,0x33,0x22,0x11,
	0xff,0xdd,0xff,0xbb,0xff,0x99,0xff,0x88,0xff,0x88,0xff,0x99,0xff,0xbb,0xff,0xdd,

	0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,
	0x88,0x88,0x88,0x88,0x88,0x88,0x88,0x88,0x88,0x88,0x88,0x88,0x88,0x88,0x88,0x88,

	0x33,0x55,0x66,0x55,0x44,0x22,0x00,0x00,0x00,0x22,0x44,0x55,0x66,0x55,0x33,0x00,
	0xcc,0xaa,0x99,0xaa,0xbb,0xdd,0xff,0xff,0xff,0xdd,0xbb,0xaa,0x99,0xaa,0xcc,0xff,

	0xff,0x22,0x44,0x55,0x66,0x55,0x44,0x22,0xff,0xcc,0xaa,0x99,0x88,0x99,0xaa,0xcc,
	0xff,0x33,0x55,0x66,0x55,0x33,0xff,0xbb,0x99,0x88,0x99,0xbb,0xff,0x66,0xff,0x88,

	0xff,0x66,0x44,0x11,0x44,0x66,0x22,0xff,0x44,0x77,0x55,0x00,0x22,0x33,0xff,0xaa,
	0x00,0x55,0x11,0xcc,0xdd,0xff,0xaa,0x88,0xbb,0x00,0xdd,0x99,0xbb,0xee,0xbb,0x99,

	0xff,0x00,0x22,0x44,0x66,0x55,0x44,0x44,0x33,0x22,0x00,0xff,0xdd,0xee,0xff,0x00,
	0x00,0x11,0x22,0x33,0x11,0x00,0xee,0xdd,0xcc,0xcc,0xbb,0xaa,0xcc,0xee,0x00,0x11,

	0x22,0x44,0x44,0x22,0xff,0xff,0x00,0x33,0x55,0x66,0x55,0x22,0xee,0xdd,0xdd,0xff,
	0x11,0x11,0x00,0xcc,0x99,0x88,0x99,0xbb,0xee,0xff,0xff,0xcc,0xaa,0xaa,0xcc,0xff,
};



static struct MachineDriver machine_driver =
{
	/* basic machine hardware */
	{
		{
			CPU_Z80,
			3125000,	/* 3.125 Mhz */
			0,
			readmem_cpu1,writemem_cpu1,0,0,
			galaga_interrupt_1,1
		},
		{
			CPU_Z80,
			3125000,	/* 3.125 Mhz */
			2,	/* memory region #2 */
			readmem_cpu2,writemem_cpu2,0,0,
			galaga_interrupt_2,1
		},
		{
			CPU_Z80,
			3125000,	/* 3.125 Mhz */
			3,	/* memory region #3 */
			readmem_cpu3,writemem_cpu3,0,0,
			galaga_interrupt_3,2
		}
	},
	60,
	0,

	/* video hardware */
	28*8, 36*8, { 0*8, 28*8-1, 0*8, 36*8-1 },
	gfxdecodeinfo,
	32+64,64*4+64,	/* 32 for the characters, 64 for the stars */
	galaga_vh_convert_color_prom,

	0,
	galaga_vh_start,
	generic_vh_stop,
	galaga_vh_screenrefresh,

	/* sound hardware */
	samples,
	0,
	rallyx_sh_start,
	0,
	pengo_sh_update
};



/***************************************************************************

  Game driver(s)

***************************************************************************/

ROM_START( galaga_rom )
	ROM_REGION(0x10000)	/* 64k for code for the first CPU  */
	ROM_LOAD( "3200a.bin", 0x0000, 0x1000 )
	ROM_LOAD( "3300b.bin", 0x1000, 0x1000 )
	ROM_LOAD( "3400c.bin", 0x2000, 0x1000 )
	ROM_LOAD( "3500d.bin", 0x3000, 0x1000 )

	ROM_REGION(0x3000)	/* temporary space for graphics (disposed after conversion) */
	ROM_LOAD( "2600j_4l.bin", 0x0000, 0x1000 )
	ROM_LOAD( "2800l_4d.bin", 0x1000, 0x1000 )
	ROM_LOAD( "2700k.bin",    0x2000, 0x1000 )

	ROM_REGION(0x10000)	/* 64k for the second CPU */
	ROM_LOAD( "3600e.bin", 0x0000, 0x1000 )

	ROM_REGION(0x10000)	/* 64k for the third CPU  */
	ROM_LOAD( "3700g.bin", 0x0000, 0x1000 )
ROM_END

ROM_START( galagabl_rom )
	ROM_REGION(0x10000)	/* 64k for code for the first CPU  */
	ROM_LOAD( "galagabl.1_1", 0x0000, 0x1000 )
	ROM_LOAD( "galagabl.1_2", 0x1000, 0x1000 )
	ROM_LOAD( "galagabl.1_3", 0x2000, 0x1000 )
	ROM_LOAD( "galagabl.1_4", 0x3000, 0x1000 )

	ROM_REGION(0x3000)	/* temporary space for graphics (disposed after conversion) */
	ROM_LOAD( "galagabl.1_8", 0x0000, 0x1000 )
	ROM_LOAD( "galagabl.1_a", 0x1000, 0x1000 )
	ROM_LOAD( "galagabl.1_9", 0x2000, 0x1000 )

	ROM_REGION(0x10000)	/* 64k for the second CPU */
	ROM_LOAD( "galagabl.1_5", 0x0000, 0x1000 )

	ROM_REGION(0x10000)	/* 64k for the third CPU  */
	ROM_LOAD( "galagabl.1_7", 0x0000, 0x1000 )
ROM_END


static const char *galaga_sample_names[] =
{
	"BANG.SAM",
	0	/* end of array */
};



struct GameDriver galaga_driver =
{
	"galaga",
	&machine_driver,

	galaga_rom,
	0, 0,
	galaga_sample_names,

	input_ports, galaga_dsw, keys,

	color_prom, 0, 0,

	{ 0x00,0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,	/* numbers */
		0x0a,0x0b,0x0c,0x0d,0x0e,0x0f,0x10,0x11,0x12,0x13,0x14,0x15,0x16,	/* letters */
		0x17,0x18,0x19,0x1a,0x1b,0x1c,0x1d,0x1e,0x1f,0x20,0x21,0x22,0x23 },
	1, 5,
	8*11, 8*20, 4,

	0, 0
};

struct GameDriver galagabl_driver =
{
	"galagabl",
	&machine_driver,

	galagabl_rom,
	0, 0,
	galaga_sample_names,

	input_ports, galagabl_dsw, keys,

	color_prom, 0, 0,

	{ 0x00,0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,	/* numbers */
		0x0a,0x0b,0x0c,0x0d,0x0e,0x0f,0x10,0x11,0x12,0x13,0x14,0x15,0x16,	/* letters */
		0x17,0x18,0x19,0x1a,0x1b,0x1c,0x1d,0x1e,0x1f,0x20,0x21,0x22,0x23 },
	1, 5,
	8*11, 8*20, 4,

	0, 0
};
