/*******************************************************************************
 **  galag: precise re-implementation of a popular space shoot-em-up
 **  gg1-5.s( gg1-5.3f)
 **
 **  sprite movement pipeline
 *******************************************************************************/
/*
 ** header file includes
 */
#include "galag.h"

/*
 ** defines and typedefs
 */

/*
 ** extern declarations of variables defined in other files
 */

/*
 ** non-static external definitions this file or others
 */
#ifdef DEBUG
uint16 dbg_step_cnt;
#endif
uint8 ds3_92A0_frame_cts[3];
uint8 cpu1_task_en[8];
uint8 b_bugs_flying_nbr;


/*
 ** static external definitions in this file
 */
// variables
// this wastes some memory but it its the only way i can think of right
// now to preserve the 16-bit pointers that are embedded in the data
static uint8 flv_data[0x1000];

static const uint8 db_cpu1_task_en_ini[];
static uint8 bugs_flying_cnt;
static uint8 b_bug_que_idx; // tracks consecutive iterations of f_08D3

// function prototypes
static void c_0704_update_rockets(uint8);
static void l_0C05_flite_pth_cont(void);
static void l_0C2D_flite_pth_step(void);
static void flite_pth_exec(uint8, uint8, uint8, uint8);
static void l_0D03_flite_pth_posn_set(uint8);
static uint16 c_0E5B(uint16, uint8, uint8);
static uint16 c_0E97(uint8, uint8);
static uint16 c_0EAA(uint8, uint16);
static void c_076A_rocket_hit_detection(uint8, uint8, uint8);
static uint8 j_07C2(uint8, uint8, uint8);


/*
 if ld new address, hl+=2 ... loads new ptr
 not ld new address, hl+=3 ... skips 16-bit ptr and skips control byte
x=_flite_path_init
.=_next_superloop ($0B87,$0B8B,$0B8C)
/=_flite_path_init ($0BFF)
        $FF  case_0E49   make_object_inactive
/       $FE  case_0B16   HL+=9 ... alien breaks formation to attack ship (level 3+)
x       $FD  case_0B46   inc HL x2 ... alien returns to base from sortie
/       $FC  case_0B4E   inc HL x2 (not ptr) ... yellow alien loopback from dive, or boss left position and start dive
x       $FB  case_0AA0   HL+=1 ... element of convoy formation hits turning point and heads to home
/.      $FA  case_0BD1   inc HL x2, x3, yellow alien passed under bottom of screen and turns for home
.       $F9  case_0B5F   HL+=1 ... yellow alien passed under bottom of screen and turns for home
.       $F8  case_0B87   HL+=1 ... red alien transit to top
x       $F7  case_0B98   inc HL x2, x3, load 16-bit address ... attack convoy
.       $F6  case_0BA8   HL+=1 ... one red alien left in "free flight mode"
x       $F5  case_0942   HL+=1 ... ?
x       $F4  case_0A53   HL+=1 ... capture boss diving
/       $F3  case_0A01   HL+=9 ... diving alien left formation and fired
x       $F2  case_097B   inc HL x3 ... special 3 ship squadron (yellow alien split)
.       $F1  case_0968   HL+=1 ... diving attacks stop and aliens go home
.       $F0  case_0955   inc HL x2, x3: load 16-bit address ... attack convoy
.       $EF  case_094E   inc HL x2, x3: load 16-bit address ... one red alien left in "free flight mode"
*/

/*
 * I think this means word-to-bytes
 */
#define W2B( _arg_ )   (_arg_ & 0x00FF), (_arg_ >> 8)

/*
  flight-data, in groups of 3-byte sets:
   [0]: b0A (lo-nibble), b0B (hi-nibble) ... x and y displacements
   [1]: b0C ... rotation
   [2]: b0D ... duration of flight-step (frame-counts)
 */

static const uint8 flv_d_001d[] =
{
    0x23,0x06,0x16,0x23,0x00,0x19,0xF7,
    W2B(_flv_i_004b),
    0x23,0xF0,0x02,0xF0,
    W2B(_flv_i_005e),
    0x23,0xF0,0x24,0xFB,0x23,0x00,0xFF,0xFF,
};

// Create explicit array, this one is not contiguous with previous! Note the
// naming convention changed on this one - only referenced by init copy to RAM.
static const uint8 flv_p_004b[] =
{
    0x23,0xF0,0x26,0x23,0x14,0x13,0xFE,
    0x0D,0x0B,0x0A,0x08,0x06,0x04,0x03,0x01,0x23,0xFF,
    0xFF,0xFF,
//_flv_i_005e
    0x44,0xE4,0x18,0xFB,0x44,0x00,0xFF,0xFF,
    0xC9 // junk ?
};

static const uint8 flv_d_0067[] =
{
    0x23,0x08,0x08,0x23,0x03,0x1B,0x23,0x08,0x0F,0x23,0x16,0x15,0xF7,
    W2B(_flv_i_0084),
    0x23,0x16,0x03,0xF0,
    W2B(_flv_i_0097),
    0x23,0x16,0x19,0xFB,0x23,0x00,0xFF,0xFF,
//_flv_i_0084
    0x23,0x16,0x01,0xFE,
    0x0D,0x0C,0x0A,0x08,0x06,0x04,0x03,0x01,0x23,0xFC,
    0x30,0x23,0x00,0xFF,
    0xFF,
//_flv_i_0097
    0x44,0x27,0x0E,0xFB,0x44,0x00,0xFF,0xFF
};

static const uint8 flv_d_009f[] =
{
    0x33,0x06,0x18,0x23,0x00,0x18,0xf7,
    W2B(_flv_i_00b6),
    0x23,0xf0,0x08,0xf0,
    W2B(_flv_i_00cc),
    0x23,0xf0,0x20,0xfb,0x23,0x00,0xff,0xff,
// p_flv_00b6:
    0x23,0xf0,0x20,0x23,0x10,0x0d,0xfe,
    0x1a,0x18,0x15,0x10,0x0c,0x08,0x05,0x03,0x23,0xfe,
    0x30,0x23,0x00,0xff,
    0xff,
// p_flv_00cc:
    0x33,0xe0,0x10,0xfb,0x44,0x00,0xff,0xff
};

static const uint8 flv_d_00d4[] =
{
    0x23,0x03,0x18,0x33,0x04,0x10,0x23,0x08,0x0a,0x44,0x16,0x12,0xf7,
    W2B(_flv_i_0160),
    0x44,0x16,0x03,0xf0,
    W2B(_flv_i_0173),// stg 13
    0x44,0x16,0x1d,0xfb,0x23,0x00,0xff,0xff
};

// db_flv_00f1: this one or db_flv_0411 for boss launcher


// Copy of home position LUT from task_man.
const uint8 db_obj_home_posn_RC[] =
{
    0x14, 0x06, 0x14, 0x0c, 0x14, 0x08, 0x14, 0x0a, 0x1c, 0x00, 0x1c, 0x12, 0x1e, 0x00, 0x1e, 0x12,
    0x1c, 0x02, 0x1c, 0x10, 0x1e, 0x02, 0x1e, 0x10, 0x1c, 0x04, 0x1c, 0x0e, 0x1e, 0x04, 0x1e, 0x0e,
    0x1c, 0x06, 0x1c, 0x0c, 0x1e, 0x06, 0x1e, 0x0c, 0x1c, 0x08, 0x1c, 0x0a, 0x1e, 0x08, 0x1e, 0x0a,
    0x16, 0x06, 0x16, 0x0c, 0x16, 0x08, 0x16, 0x0a, 0x18, 0x00, 0x18, 0x12, 0x1a, 0x00, 0x1a, 0x12,
    0x18, 0x02, 0x18, 0x10, 0x1a, 0x02, 0x1a, 0x10, 0x18, 0x04, 0x18, 0x0e, 0x1a, 0x04, 0x1a, 0x0e,
    0x18, 0x06, 0x18, 0x0c, 0x1a, 0x06, 0x1a, 0x0c, 0x18, 0x08, 0x18, 0x0a, 0x1a, 0x08, 0x1a, 0x0a
};

// Create explicit array, this one is not contiguous with previous! Note the
// naming convention changed on this one - only referenced by init copy to RAM.
//static const uint8 flv_p_0160[] =

const uint8 flv_d_017b[] =
{
    0x23,0x06,0x18,0x23,0x00,0x18,0xf7,
    W2B( _flv_i_0192),
    0x44,0xf0,0x08,0xf0,
    W2B( _flv_i_01a8),
    0x44,0xf0,0x20,0xfb,0x23,0x00,0xff,0xff,
//p_flv_0192:
    0x44,0xf0,0x26,0x23,0x10,0x0b,0xfe,
    0x22,0x20,0x1e,0x1b,0x18,0x15,0x12,0x10,0x23,0xfe,
    0x30,0x23,0x00,0xff,
    0xff,
//p_flv_01a8:,
    0x66,0xe0,0x10,0xfb,0x44,0x00,0xff,0xff,
};

const uint8 flv_d_01b0[] =
{
    0x23,0x03,0x20,0x23,0x08,0x0f,0x23,0x16,0x12,0xf7,
    W2B(_flv_i_01ca),
    0x23,0x16,0x03,0xf0,
    W2B(_flv_i_01e0),
    0x23,0x16,0x1d,0xfb,0x23,0x00,0xff,0xff,
// p_flv_01ca:
    0x23,0x16,0x01,0xfe,
    0x0d,0x0c,0x0b,0x09,0x07,0x05,0x03,0x02,0x23,0x02,0x20,0x23,0xfc,
    0x12,0x23,0x00,0xff,
    0xff,
// p_flv_01e0:
    0x44,0x20,0x14,0xfb,0x44,0x00,0xff,0xff
};

static const uint8 flv_d_01E8[] =   // 6: challenge stage convoy
{
    0x23,0x00,0x10,0x23,0x01,0x40,0x22,0x0c,0x37,0x23,0x00,0xff,0xff
};

static const uint8 flv_d_01F5[] =   // 7: challenge stage convoy
{
    0x23,0x02,0x3a,0x23,0x10,0x09,0x23,0x00,0x18,0x23,0x20,0x10,
    0x23,0x00,0x18,0x23,0x20,0x0d,0x23,0x00,0xff,0xff
};

static const uint8 flv_d_020b[] =
{
    0x23,0x00,0x10,0x23,0x01,0x30,0x00,0x40,0x08,0x23,0xff,0x30,0x23,0x00,0xff,0xff,
};

static const uint8 flv_d_021b[] =
{
    0x23,0x00,0x30,0x23,0x05,0x80,0x23,0x05,0x4c,0x23,0x04,0x01,0x23,0x00,0x50,0xff,
};

static const uint8 flv_d_022b[] =
{
    0x23,0x00,0x28,0x23,0x06,0x1d,0x23,0x00,0x11,0x00,0x40,0x08,0x23,0x00,0x11,
    0x23,0xfa,0x1d,0x23,0x00,0x50,0xff,
};

static const uint8 flv_d_0241[] =
{
    0x23,0x00,0x21,0x00,0x20,0x10,0x23,0xf8,0x20,0x23,0xff,0x20,0x23,0xf8,0x1b,
    0x23,0xe8,0x0b,0x23,0x00,0x21,0x00,0x20,0x08,0x23,0x00,0x42,0xff,
};

static const uint8 flv_d_025d[] =
{
    0x23,0x00,0x08,0x00,0x20,0x08,0x23,0xf0,0x20,0x23,0x10,0x20,0x23,0xf0,0x40,
    0x23,0x10,0x20,0x23,0xf0,0x20,0x00,0x20,0x08,0x23,0x00,0x30,0xff,
};

static const uint8 flv_d_0279[] =
{
    0x23,0x10,0x0c,0x23,0x00,0x20,0x23,0xe8,0x10,
    0x23,0xf4,0x10,0x23,0xe8,0x10,0x23,0xf4,0x32,0x23,0xe8,0x10,0x23,0xf4,0x32,
    0x23,0xe8,0x10,0x23,0xf4,0x10,0x23,0xe8,0x0e,0x23,0x02,0x30,0xff,
};

static const uint8 flv_d_029e[] =
{
    0x23,0xf1,0x08,0x23,0x00,0x10,0x23,0x05,0x3c,0x23,0x07,0x42,0x23,0x0a,0x40,
    0x23,0x10,0x2d,0x23,0x20,0x19,0x00,0xfc,0x14,0x23,0x02,0x4a,0xff,
};

static const uint8 flv_d_02ba[] =
{
    0x23,0x04,0x20,0x23,0x00,0x16,0x23,0xf0,0x30,0x23,0x00,0x12,0x23,0x10,0x30,
    0x23,0x00,0x12,0x23,0x10,0x30,0x23,0x00,0x16,0x23,0x04,0x20,0x23,0x00,0x10,0xff,
};

static const uint8 flv_d_02d9[] =
{
    0x23,0x00,0x15,0x00,0x20,0x08,0x23,0x00,0x11,
    0x00,0xe0,0x08,0x23,0x00,0x18,0x00,0x20,0x08,0x23,0x00,0x13,
    0x00,0xe0,0x08,0x23,0x00,0x1f,0x00,0x20,0x08,0x23,0x00,0x30,0xff,
};

static const uint8 flv_d_02fb[] =
{
    0x23,0x02,0x0e,0x23,0x00,0x34,
    0x23,0x12,0x19,0x23,0x00,0x20,0x23,0xe0,0x0e,0x23,0x00,0x12,0x23,0x20,0x0e,
    0x23,0x00,0x0c,0x23,0xe0,0x0e,0x23,0x1b,0x08,0x23,0x00,0x10,0xff,
};

static const uint8 flv_d_031d[] =
{
    0x23,0x00,0x0d,0x00,0xc0,0x04,0x23,0x00,0x21,0x00,0x40,0x06,0x23,0x00,0x51,
    0x00,0xc0,0x06,0x23,0x00,0x73,0xff,
};

static const uint8 flv_d_0333[] =
{
    0x23,0x08,0x20,0x23,0x00,0x16,0x23,0xe0,0x0c,0x23,0x02,0x0b,
    0x23,0x11,0x0c,0x23,0x02,0x0b,0x23,0xe0,0x0c,0x23,0x00,0x16,0x23,0x08,0x20,0xff,
};

static const uint8 flv_d_atk_yllw[] =
{
    0x12,0x18,0x1e,
//};
//static const uint8 _flv_i_0352[] = {
    0x12,0x00,0x34,0x12,0xfb,0x26,
//};
//static const uint8 _flv_i_0358[] = {
    0x12,0x00,0x02,0xfc,
    0x2e,0x12,0xfa,0x3c,0xfa,
    W2B(_flv_i_039e),
//};
//static const uint8 _flv_i_0363[] = {
    0x12,0xf8,0x10,0x12,0xfa,0x5c,0x12,0x00,0x23,
//};
//static const uint8 _flv_i_036c[] = {
    0xf8,0xf9,0xef,
    W2B(_flv_i_037c),
    0xf6,0xab,0x12,0x01,0x28,0x12,0x0a,0x18,0xfd,
    W2B(_flv_i_0352),
//};
//static const uint8 _flv_i_037c[] = {
    0xf6,0xb0,
    0x23,0x08,0x1e,0x23,0x00,0x19,0x23,0xf8,0x16,0x23,0x00,0x02,0xfc,
    0x30,0x23,0xf7,0x26,0xfa,
    W2B(_flv_i_039e),
    0x23,0xf0,0x0a,0x23,0xf5,0x31,0x23,0x00,0x10,0xfd,
    W2B(_flv_i_036c), // oops shot captured fighter
//};
//static const uint8 _flv_i_039e[] = {
    0x12,0xf8,0x10,0x12,0x00,0x40,
    0xfb,0x12,0x00,0xff,0xff
};

static const uint8 flv_d_atk_red[] =
{
    0x12,0x18,0x1d,
//};
//static const uint8 _flv_i_03ac[] = {
    0x12,0x00,0x28,0x12,0xfa,0x02,0xf3,
    0x3f,0x3b,0x36,0x32,0x28,0x26,0x24,0x22,0x12,0x04,0x30,0x12,0xfc,
    0x30,0x12,0x00,0x18,0xf8,0xf9,0xfa,
    W2B(_flv_i_040c),
    0xef,
    W2B(_flv_i_03d7),
//};
//static const uint8 _flv_i_03cc[] = {
    0xf6,0xb0,
    0x12,0x01,0x28,0x12,0x0a,0x15,0xfd,
    W2B(_flv_i_03ac),
//};
//static const uint8 _flv_i_03d7[] = {
    0xf6,0xc0,
    0x23,0x08,0x10,0x23,0x00,0x23,0x23,0xf8,0x0f,0x23,0x00,0x48,0xf8,0xf9,0xfa,
    W2B(_flv_i_040c),
    0xf6,0xb0,
    0x23,0x08,0x20,0x23,0x00,0x08,0x23,0xf8,0x02,0xf3,
    0x34,0x31,0x2d,0x29,0x22,0x26,0x1f,0x18,
    0x23,0x08,0x18,0x23,0xf8,0x18,0x23,0x00,0x10,0xf8,0xf9,0xfd,
    W2B(_flv_i_03cc),
//};
//static const uint8 _flv_i_040c[] = {
    0xfb,0x12,0x00,0xff,0xff,
//flv_d_0411: this one or flv_d_00f1
    0x12,0x18,0x14,
//};
//static const uint8 _flv_i_0414[] = {
    0x12,0x03,0x2a,0x12,0x10,0x40,0x12,0x01,0x20,0x12,0xfe,0x71,
//};
//static const uint8 _flv_i_0420[] = {
    0xf9,0xf1,0xfa,
    W2B(_flv_i_040c),
//};
//static const uint8 _flv_i_0425[] = {
    0xef,
    W2B(_flv_i_0430),
    0xf6,0xab,
    0x12,0x02,0x20,0xfd,
    W2B(_flv_i_0414),
//};
//static const uint8 _flv_i_0430[] = {
    0xf6,0xb0,
    0x23,0x04,0x1a,0x23,0x03,0x1d,0x23,0x1a,0x25,0x23,0x03,0x10,0x23,0xfd,0x48,0xfd,
    W2B(_flv_i_0420),
};


/************************************/
uint8 flv_get_data(uint16 phl)
{
    return flv_data[phl];
}
// this one is separate to allow breakpoint prior to selection of new command token
uint8 flv_get_data_uber(uint16 phl)
{
    return  flv_get_data(phl);
}

// return the next two bytes as a 16-bit address/offset with which to reload the data pointer
uint16  flv_0B46_set_ptr(uint16 u16hl)
{
    reg16 de;

    u16hl += 1;
    de.pair.b0 = flv_get_data(u16hl);
    u16hl += 1;
    de.pair.b1 = flv_get_data(u16hl);

    return de.word;
}

#define FLV_MCPY( _DTBLE_, _ADDR_ ) \
{ \
  int i = 0; \
  for ( i = 0; i < sizeof(_DTBLE_); i++) \
  { \
    flv_data[_ADDR_ + i] = _DTBLE_[i]; \
  } \
}


/*=============================================================================
;; cpu1_init()
;;  Description:
;;
;; IN:
;;
;; OUT:
;;
;; PRESERVES:
;;
;;---------------------------------------------------------------------------*/
void cpu1_init(void)
{
    uint16 BC;

    // Following ROM test, CPU1 loops until CPU0 clears the flag,
    // then enables the Vblank interrupt, and the background task just loops after that.
    /*
    l_0596:
           ld   a,(de)                                ; wait for master to acknowledge/resume (0)
           and  a
           jr   nz,l_0596

           im   1

           xor  a
           ld   (b_89E0),a                            ; 0

    ; set task-enable defaults
           ld   hl,#d_05B7
           ld   de,#ds_cpu1_task_en + 1               ; cp $07 bytes (d_05B7)
           ld   bc,#0x0007
           ldir
     */
    for (BC = 0; BC < 7; BC++)
    {
        cpu1_task_en [1 + BC ] = db_cpu1_task_en_ini[BC];
    }

    /*
               ld   a,#1
               ld   (0x6821),a                            ; cpu #1 irq acknowledge/enable
               ei
     */

    irq_acknowledge_enable_cpu1 = 1; // sfr_6821


    // shouldn't be here
    flv_init_data();
}


/*=============================================================================
;; forward declarations for cpu1 tasks
;;-----------------------------------------------------------------------------*/
void f_05BE(void);
void f_05BF(void);
void f_08D3(void);
void f_05BE(void);
void f_06F5(void);
void f_05EE(void);
void f_05BE(void);
void f_0ECA(void);


/*=============================================================================
; Function pointers for periodic tasks on this CPU (ds_cpu1_task_enbl)
; The following bytes are copied from cpu1_task_en_ini to ds_cpu1_task_enbl[1]
;   0x01,0x01,0x00,0x01,0x01,0x00,0x0A
;;-----------------------------------------------------------------------------*/
void (* const d_cpu1_task_table[])(void) =
{
    f_05BE, // null-task (this is the only slot with a "null" task that is enabled.
    f_05BF, // [1]
    f_08D3, // [2]
    f_05BE, // null-task
    f_06F5, // [4]
    f_05EE, // [5] ... hit-detection: change to f_05BE for invincibility
    f_05BE, // null-task
    f_0ECA  // [7] ... ?
};

/*=============================================================================
;; jp_0513_rst38()
;;  Description:
;;    RST $0038 handler.
;;    The first part uses vsync signal to develop clock references.
;;      ds3_92A0_frame_cts[0]: 60Hz (base rate)
;;      ds3_92A0_frame_cts[1]:  2Hz (div 32)
;;      ds3_92A0_frame_cts[2]:  4Hz (div 16)
;;    The counters are not reset in the course of the game operation.
;;
;;    For efficiency, bit masking is used instead of division so the real base
;;    period is 64 which is close enough to 60Hz.
;;
;;    Note: frame_cts[2] is used as the baserate to 4 Game Timers in
;;    CPU0:f_1DD2 (rescaled to develop a 2Hz clock)
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------*/
void cpu1_rst38(void)
{
    uint8 A, C;

    /*
           xor  a
           ld   (_sfr_6821),a                         ; 0 ...CPU-sub1 IRQ acknowledge/enable
           ld   a,(_sfr_dsw5)                         ; DSWA: freeze video
           and  #0x02                                 ; freeze_ctrl_dsw (6j)
           jp   z,l_0575                              ; if paused, goto 0575 // done
     */
    irq_acknowledge_enable_cpu1 = 0; // sfr_6821

    // frame_cntr++
    ds3_92A0_frame_cts[0]++;

    if ((ds3_92A0_frame_cts[0] & 0x1F) == 1) // if ( cnt % 20 == 1 )
    {
        // l_0536
        ds3_92A0_frame_cts[2]++; // update 4Hz only
    }
    else if ((ds3_92A0_frame_cts[0] & 0x1F) == 0)
    {
        // OR forces H to be ODD when A==0...
        // once the OR is done, H should henceforth be odd when A==0
        ds3_92A0_frame_cts[2] |= 1;

        // update both 4Hz and 2Hz
        ds3_92A0_frame_cts[1]++; // t[1] = L++
        // l_0536:
        ds3_92A0_frame_cts[2]++; // t[2] = H++
    }

    // flag = ( num_bugs < param07 ) & ds_cpu0_task_actv[0x15]

    // find the first ready task.. may run more than one.
    C = 0;
    while (C < 8)
    {
        A = cpu1_task_en[C];
        if (A)
        {
            d_cpu1_task_table[C]();
            C += A;
        }
        else
        {
            C += 1;
        }
    }


    irq_acknowledge_enable_cpu1 = 1; // sfr_6821
}


/*=============================================================================
;;
;; init data for ds_cpu1_task_enbl
;;
;;---------------------------------------------------------------------------*/
static const uint8 db_cpu1_task_en_ini[] =
{
    0x01, 0x01, 0x00, 0x01, 0x01, 0x00, 0x0A
};

/*=============================================================================
;; f_05BE()
;;  Description:
;;   null task
;; IN:
;;  ...
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
void f_05BE(void)
{
    return;
}

/*=============================================================================
;; f_05BF()
;;  Description:
;;   works in conjunction with f_0828 of main CPU to update sprite RAM
;; IN:
;;  ...
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
void f_05BF(void)
{

}

/*=============================================================================
;; f_05EE()
;;  Description:
;;    Manage ship collision detection
;; IN:
;;  ...
;; OUT:
;;  ...
;;----------------------------------------------------------------------------*/
void f_05EE(void)
{

}

/*=============================================================================
;; f_06F5()
;;  Description:
;;    Manage motion of rockets fired from ship(s) and checks them for
;;    hit-detection.
;; IN:
;;  ...
;; OUT:
;;  ...
;;----------------------------------------------------------------------------*/
void f_06F5(void)
{
    c_0704_update_rockets(0);
    c_0704_update_rockets(1);
}

/*=============================================================================
;; c_0704_update_rockets()
;;  Description:
;;   subroutine for f_06F5
;; IN:
;;   DE == pointer to rocket "attribute", e.g. &b_92A0_4[0], &b_92A0_4[1]
;;         Value is E0 if the ship is oriented normally, not rotated.
;;         bit7=orientation, bit6=flipY, bit5=flipX, 1:2=displacement
;;
;; OUT:
;;  ...
;;----------------------------------------------------------------------------*/
static void c_0704_update_rockets(uint8 de)
{
    uint8 AF, A, B;
    uint16 HL;
    // adjust de for rocket 1 or 2,
    uint8 hl = SPR_IDX_RCKT + de * 2; // even indices

    if (0 == mrw_sprite.posn[hl].b0)
        return;

    // else ... this one is active, stash the parameter in B, e.g. $E0
    B = b_92A4_rockt_attribute[de]; // ld   b,a

    // if horizontal orientation, dY = A' ... adusted displacement in dY
    AF = B & 0x07; // I thought it was only bits 1:2 ? ... bit7=orientation, bit6=flipY, bit5=flipX, 1:2=displacement

    // ... and dX == A ... maximum displacement in dX
    A = 6;


    // if ( vertical orientation )
    if (B & 0x80) // bit  7,b
    {
        //  ex   af,af' ... swap
        A = B & 0x07; // ... adusted displacement in dX
        AF = 6; // maximum displacement in dY
    }
    // l_0713:
    if (B & 0x64) // bit  6,b ... flipY
    {
        // .. NOT flipY...negate X offset (non-flipped sprite is left facing)

        // negate and add dX to sprite.sX .. add  a,(hl)
        mrw_sprite.posn[hl].b0 -= A; // neg
    }
    else
    {
        // add dX to sprite.sX ... add  a,(hl)
        mrw_sprite.posn[hl].b0 += A;
    }


    // left/right out of bounds...
    if (mrw_sprite.posn[hl].b0 > 0xF0)
    {
        //l_0763_disable_rocket:
        mrw_sprite.ctrl[hl].b0 = 0;
        return;
    }

    // stash sX for hit-detection parameter
    // ld   ixl,a

    // NOW onto sY...............

    // inc  l ... not needed since the access is thru b1
    HL = mrw_sprite.ctrl[hl].b1 & 0x01; // get sprite.sY<8>
    HL <<= 8; // todo: use tpair
    HL += mrw_sprite.posn[hl].b1;

    if (B & 0x32) // bit  5,b ... flipX
    {
        // negate and add dY to sprite.sY .. add  a,(hl)
        HL -= AF;
    }
    else
    {
        // add dY to sprite.sY .. add  a,(hl)
        HL += AF;
    }

    mrw_sprite.posn[hl].b1 = HL; // lower 8-bits to register

    // determine the sign, toggle position.sy:8 on overflow/carry.
    if (HL > 255)
        mrw_sprite.ctrl[hl].b1 |= 1;
    else
        mrw_sprite.ctrl[hl].b1 &= ~1;

    // ld   ixh,a ... stash sy<1:8> for hit-detection parameter (here, it's in AF)

    // z80 re-scales and drops bit-0, i.e. thresholds are $14 and $9C
    if (HL < 40 || HL > 312) // disable_rocket_wposn
    {
        // l_0760_disable_rocket_wposn:
        mrw_sprite.posn[hl].b0 = 0; // x

        //l_0763_disable_rocket:
        mrw_sprite.ctrl[hl].b0 = 0;

        return;
    }

    // lower-byte of pointer to object/sprite in L is passed through to
    // j_07C2 (odd, i.e. offset to b1)
    //   ld   e,l

    if (0 != task_actv_tbl_0[0x1D]) // ... else _call_hit_detection_all
    {
        // ld   hl,#ds_sprite_posn + 0x08             ; skip first 4 objects...
        // ld   b,#0x30 - 4
        // jr   l_075C_call_hit_detection

        // l_075C_call_hit_detection:
        c_076A_rocket_hit_detection(hl, 0x08, 0x30 - 4);
        return;
    }

    // jr   z,l_0757_call_hit_detection_all

    // l_0757_call_hit_detection_all
    // reset HL and count to check $30 objects
    // hl,#ds_sprite_posn ... i.e. L == 0

    // l_075C_call_hit_detection
    // E=offset_to_rocket_sprite, hl=offset_to_object checked, b==count,
    c_076A_rocket_hit_detection(hl, 0x00, 0x30);

    return;
}

/*=============================================================================
;; c_076A_rocket_hit_detection()
;;  Description:
;;   collision detection... rocket fired from ship.
;; IN:
;;  E == pointer/index to rocket object/sprite passed through to
;;       j_07C2 (odd, i.e. offset to b1)
;;  HL == pointer to sprite.posn[], starting object object to test ... 0, or
;;        +8 skips 4 objects... see explanation at l_0757.
;;  B == count ... $30, or ($30 - 4) as per explanation above.
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
static void c_076A_rocket_hit_detection(uint8 E, uint8 hl, uint8 B)
{
    uint8 IXL, IXH;
    reg16 tmp16;

    // setup rocket.sy<1:8> (scale factor 2 in order to get it in 8-bits)
    tmp16.pair.b0 = mrw_sprite.posn[E].b1;
    tmp16.pair.b1 = mrw_sprite.ctrl[E].b1;
    tmp16.word >>= 1;

    IXL = mrw_sprite.posn[E].b0;
    IXH = tmp16.pair.b0;

    // l_076A_while_object:
    while (B-- > 0)
    {
        uint8 AF;

        // obj_status[L].state<7> ... $80==inactive object
        // b_9200[L].b0 ... $81 = hit notification already in progress

        if (0x80 != (b8800_obj_status[hl].state |
                     b_9200_obj_collsn_notif[hl])) // else  jr   c,l_07B4_next_object
        {
            // check if object status 04 (already exploding) or 05 (bonus bitmap)

            // cp   #4 ... else ... jr   z,l_07B4_next_object
            if (0x04 != b8800_obj_status[hl].state &&
                    0x05 != b8800_obj_status[hl].state)
            {
                reg16 tmpA;

                // test dX and dY for within +/- 6 pixels, using the addition
                // offset with "Cy" so only 1 test needed for ( d>-6 && d<+6 )

                // check Y coordinate

                // set .sY<1:8>
                // inc  l
                tmpA.pair.b1 = mrw_sprite.ctrl[hl].b1; // .sy<8>
                tmpA.pair.b0 = mrw_sprite.posn[hl].b1; // .sy<0:7>
                // dec  l
                tmpA.word >>= 1; // rrc  d ... rra

                // tolerance (3) and offset (6) for hit-check divided by 2 to
                // account for scaling
                // only 1-byte of result needed ( d>-3 && d<+3 )
                tmpA.pair.b0 -= IXH; // sub  ixh ...  -= rocket.sy<1:8>
                tmpA.pair.b0 -= 3;
                tmpA.word += 6; // carry out from 1-byte sets "Cy" in .b1<0>

                if (tmpA.pair.b1) // ... else ... jr   nc,l_07B4_next_object
                {
                    // check X coordinate

                    // ld   a,c ... dec  a ... and  #0xFE ... ex   af,af
                    AF = (b8800_obj_status[hl].state - 1) & 0xFE; // object status to j_07C2

                    if (1 /* ! ds_plyr_actv._b_2ship */) // ... else ... jr   nz,l_07A4
                    {
                        // only 1-byte of result needed ( d>-6 && d<+6 )
                        tmpA.word = mrw_sprite.posn[hl].b0;
                        tmpA.pair.b0 -= IXL; // sub  ixh ...  -= rocket.sy<1:8>
                        tmpA.pair.b0 -= 6;
                        tmpA.pair.b1 = 0; // clear it so we can test for "Cy"
                        tmpA.word += 0x0B; // carry out from 1-byte sets "Cy" in .b1<0>

                        if (tmpA.pair.b1) // ... jr   c,l_07B9_pre_hdl_collsn ...
                        {
                            // l_07B9_pre_hdl_collsn


                            if ( 1 != j_07C2(AF, E, hl) )
                            {
                                return;
                            }
                            // else ... jr   l_07B4_next_object
                        }
                        // else ... jr   l_07B4_next_object
                    }
                    else // ... l_07A4
                    {
                        tmpA.word = mrw_sprite.posn[hl].b0 - IXL; // sub  ixl ... sprite.sx -= rocket.sx
                        tmpA.word -= 0x14;
                        tmpA.pair.b1 = 0; // clear it so we can test for "Cy"
                        tmpA.word += 0x0B;

                        if (!tmpA.pair.b1) // jr   c,l_07B9_pre_hdl_collsn
                        {
                            tmpA.pair.b1 = 0;
                            tmpA.word += 4;
                            if (!tmpA.pair.b1) // jr   c,l_07B4_next_object
                            {

                                tmpA.pair.b1 = 0;
                                tmpA.word += 0x0B;

                                if (!tmpA.pair.b1) // jr   c,l_07B9_pre_hdl_collsn
                                {

                                    // l_07B4_next_object
                                    //hl += 2;
                                    break;
                                }
                                // else ... jr   c,l_07B9_pre_hdl_collsn
                            }
                            else
                            {
                                // jr   c,l_07B4_next_object

                                // l_07B4_next_object:

                                //       inc  l
                                //       inc  l
                                //       djnz l_076A_begin_object_check
                                hl += 2;
                                break;
                            }
                        }


                        // jr   c,l_07B9_pre_hdl_collsn


                        if ( 1 != j_07C2(AF, E, hl) )
                        {
                            return;
                        }

                        return; // j_07C2
                    }

                    // nothing else can go here!
                }
            } // if (0x04) ... else ... jr   z,l_07B4_next_object
        }

        // l_07B4_next_object:

        //       inc  l
        //       inc  l
        //       djnz l_076A_begin_object_check

        hl += 2;

    } // while (B-- > 0)

    //  j_07C2
}

/*=============================================================================
;; j_07C2()
;;  Description:
;;   handle collision.
;;   label for jp from c_06B7 for handling ship+bug collision
;; IN:
;;   AF == (b8800_obj_status[hl].state  - 1) & 0xFE
;;   L == object key, e.g. usually a bug was hit, but could be a bomb
;;   E == offset/index of rocket sprite + 1
;;   E == object key + 0, e.g. 9B62 (the ship?)
;; OUT:
;; RETURN:
;;   1 on jp   l_07B4_next_object
;;   0
;;  ...
;;---------------------------------------------------------------------------*/
static uint8 j_07C2(uint8 AF, uint8 E, uint8 HL)
{
    uint8 A, C;

    mrw_sprite.posn[E].b1 = 0; // ld   (de),a
    mrw_sprite.ctrl[E].b1 = 0; // ld   (de),a

    // inc  l

    C = mrw_sprite.cclr[HL].b1;  // ld   c,a ... save for index to sound

    // jp   z,l_08CA_hit_green_boss
    if (0 == mrw_sprite.cclr[HL].b1)
    {
        // color map 0 is the "green" boss
        // don't delete it from the queue yet

        // l_08CA_hit_green_boss
        mrw_sprite.cclr[HL].b1 += 1; // color blue

        // sound-fx count/enable registers
        b_9AA0[0x04] = mrw_sprite.cclr[HL].b1; // hit_green_boss

        // jp   l_07B4_next_object

        return 1;
    }
    // jr   z,l_0815_bomb_hit_ship
    else if (0x0B == mrw_sprite.cclr[HL].b1)
    {
        // l_0815_bomb_hit_ship
        // color map $B is for "bombs"
        //ld   h,#>ds_sprite_posn                    ; bomb colliding with ship.
        //ld   (hl),#0
        //ld   h,#>b_8800
        //ld   (hl),#0x80

        //ret ..         return!
        return 0; // not jp   l_07B4_next_object
    }

    // rocket or ship collided with bug
    // ex   af,af'
    // jr   nz,l_081E
    if (0 == AF)
    {
        // rocket hit stationary bug
        // ex   af,af'

        // l_07DB:
        b_9200_obj_collsn_notif[HL] = 0x81;

        // l_07DF:
    }
    else
    {
        // l_081E:
        A = b8800_obj_status[ HL ].obj_idx;
        ds_bug_motion_que[A].b13 = 0;

        b_bug_flyng_hits_p_round += 1;

        // non-challenge stage, ctr intialized to 0 at start of round.
        // if 0 == w_bug_flying_hit_cnt ... jr   nz,l_0849
        w_bug_flying_hit_cnt -= 1;

        if ( 0 == w_bug_flying_hit_cnt )
        {
            // splashed all elements of challenge stage convoy
            b_9200_obj_collsn_notif[HL] = stg_chllg_rnd_attrib[1];
            ds_bug_collsn[0x0F] += stg_chllg_rnd_attrib[0];
            // jr   l_07DF
            // l_07DF:
        }
        else
        {
            // l_0849:
            // handle special cases of flying bugs

            // if (hit == captured ship)

            // jr   l_08B0

            // else if ( hit bonus-bee or clone bonus-bee )
            // l_0852:

            // color map 1 ... blue boss hit once
            // else
            if ( 1 != mrw_sprite.cclr[HL].b1 ) // color
            {
                // jp   nz,l_07DB

                // l_07DB:
                b_9200_obj_collsn_notif[HL] = 0x81;

                // l_07DF:
            }
            else // handle blue boss
            {
                // check for captured-fighter

                // jr   nz,l_0899

                //l_0899:
                // lone blue boss killed, or boss killed before pulling the beam all in
                ds4_game_tmrs[0x01] = 6;

                // A = ds_plyr_actv[_ds_array8 + ( hl & 0x07 }]

                // D = ds_plyr_actv[_ds_array8 + ( hl & 0x07 + 1 }]

                // l_08AA:
                ds_bug_collsn[ 0x0F ] += A;

                // jp here if shot the flying captured ship
                // l_08B0:
                b_9200_obj_collsn_notif[HL] = 0xB5;

                // jp   l_07DF
            }
        }
    }

    // l_07DF:
    // if capture boss ...
    //   ld   a,(ds_plyr_actv +_b_cboss_obj)
    //   sub  l
    //   jr   nz,l_07EC
    // ... then ...
    //   ld   (ds_plyr_actv +_b_cboss_dive_start),a ; 0  ... shot the boss that was starting the capture beam
    //   inc  a
    //   ld   (ds_plyr_actv +_b_cboss_obj),a        ; 1  ... invalidate the capture boss object key

    //l_07EC: use the sprite color to get index to sound
    C = mrw_sprite.cclr[HL].b1 - 1; // ld   a,c ... dec  a

    if (7 != C) // jr   nz,l_07F5
    {
        // l_07F5:
        C &= 0x03; // and  #0x03
    }

    // l_07F8:
    b_9AA0[0x01 + C] = 1; // sound_fx_status

    A = mrw_sprite.cclr[HL].b1; // ld   a,c

    if (7 == C) // jr   nz,l_0808
    {
        //   ld   hl,#ds_plyr_actv +_b_cboss_dive_start ; 0
        //   ld   (hl),#0
    }

    // l_0808:
    // ld   hl,#ds_bug_collsn + 0x00              ; missile/bug or ship/bug collision
    // rst  0x10                                  ; HL += A
    // inc  (hl)
    ds_bug_collsn[0x00 + A] += 1; //  missile/bug or ship/bug collision

    // ex   af,af'
    // jr   z,l_0811
    if ( 0 != AF ) // un-stash parameter
    {
        // inc  (hl)
        ds_bug_collsn[0x00 + A] += 1; //  missile/bug or ship/bug collision
    }

    // l_0811:
    //   pop  hl
    //   jp   l_07B4_next_object
    return 1;
}

/*=============================================================================
;; f_08D3()
;;  Description:
;;   Top level task to implement object flying motion.
;; IN:
;;  ...
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
void f_08D3(void)
{
    // nbr of iterations to run per frame (nbr of object structures)
    b_bug_que_idx = 0;

    b_bugs_flying_nbr = bugs_flying_cnt;
    bugs_flying_cnt = 0;

    // traverse the object-motion queue
    // l_08E4_superloop:
    while (b_bug_que_idx < 0x0C)
    {
        uint8 L;

        if (0 == (ds_bug_motion_que[b_bug_que_idx].b13 & 0x01)) // check for activated state
        {
            goto l_0DFB_next_superloop;
        }

        bugs_flying_cnt++;

        L = ds_bug_motion_que[b_bug_que_idx].b10; // object identifier (index)...8800[L]


        // 9 is diving, 7 is spawning, 3 (and 6) idfk
        if ((b8800_obj_status[ L ].state == 3 ||
                b8800_obj_status[ L ].state == 7 ||
                b8800_obj_status[ L ].state == 9))
        {
            // l_0902_9_or_3_or_7:
            ds_bug_motion_que[b_bug_que_idx].b0D--;

            // check for expiration of this token
            // if token not expired, go directly to flite path handler
            if (0 == ds_bug_motion_que[b_bug_que_idx].b0D)
            {
                uint16 pHLdata;
                uint8 get_token, A_token;

                // flight-path vector has expired... setup HL as pointer to next data token
                // ld   l,0x08(ix)
                // ld   h,0x09(ix)
                pHLdata = ds_bug_motion_que[b_bug_que_idx].p08.word;

                // j_090E_flite_path_init ...
                // this do-block allows reading the next token after doing state-selection
                do
                {
                    get_token = 0;

                    // get next token and check if ordinary data or state-selection
                    A_token = flv_get_data_uber(pHLdata);

                    if (A_token >= 0xEF) // ... else ...  jp   c,l_0BDC_flite_pth_load
                    {
                        reg16 pushDE, rBC, rHL, rDE;
                        uint8 A, B, C, D, E, H;

                        // the flag forces repetition of the do-block so that the
                        // next token will be retrieved before continuing to flight-path handler.
                        get_token = 1;

                        // Negated token indexes into jp-tbl for selection of next state.
                        A_token = ~A_token; // cpl

                        // d_0920_jp_tbl
                        switch (A_token)
                        {
                        case 0x00: // _0E49: _inactive
                            //jp   l_0DFB_next_superloop;
                            break;

                        case 0x01: // _0B16: attack elements that break formation to attack ship (level 3+)
                            // jp   l_0BFF
                            return; // tmp
                            break;

                        case 0x02: // _0B46: returning to base: moths or bosses from top of screen, bees from bottom of loop-around.

                            pHLdata = flv_0B46_set_ptr(pHLdata);
                            // jp   j_090E_flite_path_init
                            break;

                        case 0x03: // _0B4E: bee dive and starting loopback, or boss left position and starting dive down
                            pHLdata += 1; // inc  hl
                            ds_bug_motion_que[b_bug_que_idx].b06 = flv_get_data(pHLdata);
                            pHLdata += 1; // inc  hl
                            ds_bug_motion_que[b_bug_que_idx].b07 = 0;
                            ds_bug_motion_que[b_bug_que_idx].b13 |= 0x20; // set  5,0x13(ix)
                            //jp   l_0BFF
                            goto l_0BFF; // gotta get out somehow
                            break;

                        case 0x04: // _0AA0: attack wave element hits turning point and heads to home

                            L = ds_bug_motion_que[b_bug_que_idx].b10;

                            // use byte-pointer as index of pairs:
                            b8800_obj_status[ L ].state = 9; // disposition = 09: diving (or homing?)

                            // should make this one .rowpos and .colpos
                            C = db_obj_home_posn_RC[ L ]; // row index
                            L = db_obj_home_posn_RC[ L + 1 ]; // column index

                            B = ds_home_posn_loc[ L ].rel; // x offset
                            E = ds_home_posn_loc[ L ].abs; // x coordinate

                            L = C;
                            C = ds_home_posn_loc[ L ].rel; // y offset
                            D = ds_home_posn_loc[ L ].abs; // y coordinate

                            pushDE.pair.b0 = E >> 1; // srl ... x coordinate (bits 1:7 in upper-byte)
                            pushDE.pair.b1 = D; // y coordinate (already bits 1:7 in upper-byte)

                            ds_bug_motion_que[b_bug_que_idx].b11 = B; // step x coord, x offset
                            ds_bug_motion_que[b_bug_que_idx].b12 = C; // step y coord, y offset

                            if (glbls9200.flip_screen)
                            {
                                // flipped ... negate the steps
                                B = -B;
                                C = -C;
                            }

                            // l_0ACD:

                            // add y-offset to .b00/.b01 (sra/rr -> 9.7 fixed-point scaling)
                            rHL.pair.b0 = ds_bug_motion_que[b_bug_que_idx].b00; // ld   l
                            rHL.pair.b1 = ds_bug_motion_que[b_bug_que_idx].b01; // ld   h
                            rDE.pair.b1 = C; // ld   d,c
                            rDE.pair.b0 = 0; // ld   e,#0
                            rDE.word >>= 1; // sra  d ... rr  e
                            rHL.word += rDE.word;
                            ds_bug_motion_que[b_bug_que_idx].b00 = rHL.pair.b0; // ld   0x00(ix),l
                            ds_bug_motion_que[b_bug_que_idx].b01 = rHL.pair.b1; // ld   0x01(ix),h

                            E = rHL.pair.b1; // ld   e,h ... y, .b01 (bits<1:8> of integer portion)

                            // add x-offset to .b02/.b03 (sra/rr -> 9.7 fixed-point scaling
                            rHL.pair.b0 = ds_bug_motion_que[b_bug_que_idx].b02; // ld   l
                            rHL.pair.b1 = ds_bug_motion_que[b_bug_que_idx].b03; // ld   h
                            rBC.pair.b0 = 0; // ld   c,#0
                            rBC.pair.b1 = B;
                            rBC.word >>= 1; // sra  b ... rr  c
                            rBC.pair.b1 |= (B & 0x80); // gets the sign extension of sra b
                            rHL.word -= rBC.word; // sbc  hl,bc
                            ds_bug_motion_que[b_bug_que_idx].b02 = rHL.pair.b0; // l
                            ds_bug_motion_que[b_bug_que_idx].b03 = rHL.pair.b1; // h

                            // grab integer portion (bits<1:8>)
                            L = rHL.pair.b1; // ld   l,h ... x, .b01
                            H = E; // ld   h,e ... y, .b01

                            // pop  de ... abs row pix coord & abs col pix coord >> 1
                            rHL.word = c_0E5B(pushDE.word, H, L); // preserves DE & BC
                            rHL.word >>= 1; // srl  h ... rr   l

                            ds_bug_motion_que[b_bug_que_idx].b04 = rHL.pair.b0;
                            ds_bug_motion_que[b_bug_que_idx].b05 = rHL.pair.b1;

                            ds_bug_motion_que[b_bug_que_idx].b06 = pushDE.pair.b1;
                            ds_bug_motion_que[b_bug_que_idx].b07 = pushDE.pair.b0;

                            // if set, flite path handler checks for home
                            ds_bug_motion_que[b_bug_que_idx].b13 |= 0x40; // set  6,0x13(ix)

                            pHLdata += 1; // inc  hl

                            // jp   j_090E_flite_path_init
                            break;

                        case 0x05: // _0BD1: homing, red transit to top, yellow from offscreen at bottom or skip if in continuous mode
                            // ld   a,(b_92A0 + 0x0A) ; flag set when continuous bombing
                            // ld   c,a
                            // ld   a,(ds_cpu0_task_actv + 0x1D)          ; f_2000 (destroyed boss that captured ship)
                            // dec  a
                            // and  c
                            // jr   l_0B9F

                            // l_0B9F:
                            if (0) // if ( 1 == b_92A0_0A && 0 == ds_cpu0_task_actv[0x1D]) // jp   z,l_0B46
                            {
                                pHLdata += 3; // inc  hl (x3)
                                // jp   j_090E_flite_path_init
                            }
                            else
                            {
                                // l_0B46:
                                pHLdata = flv_0B46_set_ptr(pHLdata);
                                // jp   j_090E_flite_path_init
                            }
                            break;

                            // red alien flew through bottom of screen to top, heading for home
                            // yellow alien flew under bottom of screen and now turns for home
                        case 0x06: // _0B5F:
                            E = ds_bug_motion_que[b_bug_que_idx].b10;
                            E = db_obj_home_posn_RC[ E + 1 ]; // column index
                            A = ds_home_posn_org[ E ].pair.b0; // even-bytes: relative offset from absolute coordinate

                            if (0 != glbls9200.flip_screen)
                            {
                                A += 0x0E;
                                A = -A; // neg
                            }

                            //l_0B76
                            ds_bug_motion_que[b_bug_que_idx].b03 =  A >> 1; // srl  a
                            if (0 /* 0 != b_92A0_0A[0]*/) // jp   z,l_0B8B
                            {
                                b_9AA0[0x13] = 1; // non-zero value
                            }

                            //l_0B8B
                            pHLdata += 1; // inc  hl

                            // l_0B8C:
                            ds_bug_motion_que[b_bug_que_idx].p08.word = pHLdata;
                            ds_bug_motion_que[b_bug_que_idx].b0D++; // inc  0x0D(ix)

                            // jp   l_0DFB_next_superloop
                            goto l_0DFB_next_superloop;
                            break;

                            // red alien flew through bottom of screen to top, heading for home
                            // yellow alien flew under bottom of screen and now turns for home
                        case 0x07: // _0B87:
                            ds_bug_motion_que[b_bug_que_idx].b01 = 0x9C; // ld   0x01(ix),#$9C

                            //l_0B8B
                            pHLdata += 1; // inc  hl

                            // l_0B8C:
                            ds_bug_motion_que[b_bug_que_idx].p08.word = pHLdata;
                            ds_bug_motion_que[b_bug_que_idx].b0D++; // inc  0x0D(ix)

                            // jp   l_0DFB_next_superloop
                            goto l_0DFB_next_superloop;
                            break;

                        case 0x08: // _0B98: attack wave
                            // "transient"? ($38, $3A, $3C, $3E)
                            if (0x38 != (0x38 & ds_bug_motion_que[b_bug_que_idx].b10))
                            {
                                pHLdata += 3; // 2 incs to skip address in table
                                // jp   j_090E_flite_path_init
                            }
                            else // jp   z,l_0B46 ... jp if this is a "transient" ($38, $3A, $3C, $3E)
                            {
                                //l_0B46:
                                //       inc  hl
                                //       ld   e,(hl)
                                //       inc  hl
                                //       ld   d,(hl)
                                //       ex   de,hl
                                //       jp   j_090E_flite_path_init
                                pHLdata = flv_0B46_set_ptr(pHLdata);
                            }
                            break;

                        case 0x09: // _0BA8: one red moth left in "free flight mode"
                            break;

                        case 0x0A: // _0942: ?
                            break;

                        case 0x0B: // _0A53: capture boss diving
                            break;

                        case 0x0C: // _0A01: diving elements have left formation (set bomb target?)
                        {
                            reg16 tmpA;

                            // setup horizontal limits for targetting
                            A = mrw_sprite.posn[SPR_IDX_SHIP].b0;
                            if ( A <= 0x1E )
                            {
                                A = 0x1E;
                            }
                            if ( A >= 0xD1 )
                            {
                                A = 0xD1;
                            }

                            // l_0A16:
                            tmpA.word = A;
                            if ( 0 != glbls9200.flip_screen ) // bit  0,c
                            {
                                tmpA.word += 0x0E;
                                tmpA.word = -A; // neg
                            }

                            // l_0A1E:  9.7 fixed-point math
                            tmpA.word >>= 1; // srl  a ... sX<8:1> in tmpA

                            A = ds_bug_motion_que[b_bug_que_idx].b03;
                            tmpA.word -= A;
                            tmpA.word >>= 1; // rra  a ... Cy into <7>
                            tmpA.pair.b1 = 0; // clear it so the overflow condition can be tested

                            // typically .b13 if set then negate data to (ix)0x0C
                            if ( 0 != (ds_bug_motion_que[b_bug_que_idx].b13 & 0x80)) // bit  7,0x13(ix)
                            {
                                tmpA.word = -tmpA.word; // neg
                            }

                            // l_0A2C_:
                            tmpA.word += 0x18;
                            A = tmpA.pair.b0;

                            // is result > $7F ?
                            if (0 != tmpA.pair.b1) // jp   p,l_0A32
                            {
                               A = 0; // xor  a ... S is set (overflow)
                            }

                            //l_0A32:
                            if (A >= 0x30) A = 0x2F;

                            //l_0A38:
                            A = c_0EAA(6, A); // HL = HL / A
                            A += 1;
                            A = flv_get_data(pHLdata + A);
                            ds_bug_motion_que[b_bug_que_idx].b0D = A; // expiration of this data-set
                            pHLdata += 9;
                            // jp   l_0BFF
                            goto l_0BFF; // gotta get out somehow
                        }
                        break;

                        case 0x0D: // _097B: bonus bee
                            break;

                        case 0x0E: // _0968: diving attacks stop and bugs go home
                            break;

                        case 0x0F: // _0955: attack wave
                            // a,(ds_new_stage_parms + 0x08) .. this can be 0 for now
                            if (0 != ds_new_stage_parms[0x08])
                            {
                                // not until stage 8
                                // load a pointer from data tbl into .p08 (09)
                                // jp   l_0B8C
                            }
                            else
                            {
                                // l_0963
                                pHLdata += 2;
                                // jp   l_0B8B

                                //l_0B8B
                                pHLdata += 1; // inc  hl
                            }
                            // l_0B8C:
                            ds_bug_motion_que[b_bug_que_idx].p08.word = pHLdata;
                            ds_bug_motion_que[b_bug_que_idx].b0D++; // inc  0x0D(ix)

                            // jp   l_0DFB_next_superloop
                            goto l_0DFB_next_superloop;
                            break;

                        case 0x10: // _094E: one red moth left in "free flight mode"
                            break;

                        default:
                            break;
                        } // switch
                    } // if (A
                }
                while (0 != get_token);

                // l_0BDC_flite_pth_load
                ds_bug_motion_que[b_bug_que_idx].b0A = A_token & 0x0F;
                ds_bug_motion_que[b_bug_que_idx].b0B = (A_token >> 4) & 0x0F; // rlca * 4

                pHLdata += 1;

                if (0x80 & ds_bug_motion_que[b_bug_que_idx].b13) // bit  7,0x13(ix)
                {
                    uint8 A = flv_get_data(pHLdata);
                    ds_bug_motion_que[b_bug_que_idx].b0C = -A; // -(*pHLdata); // neg
                }
                else
                {
                    //l_0BF7
                    ds_bug_motion_que[b_bug_que_idx].b0C = flv_get_data(pHLdata);
                }
                pHLdata += 1;
                ds_bug_motion_que[b_bug_que_idx].b0D = flv_get_data(pHLdata);
                pHLdata += 1;
l_0BFF:
                ds_bug_motion_que[b_bug_que_idx].p08.word = pHLdata;
            }
            l_0C05_flite_pth_cont();

        } // else ... shot a non-flying capture boss

l_0DFB_next_superloop:
        b_bug_que_idx++;
    } // end while b_bug_que_idx (l_08E4_superloop)
    return;
}

/*=============================================================================
;; l_0C05_flite_pth_cont()
;;  Description:
;;
;; IN:
;;
;; OUT:
;;
;; PRESERVES:
;;
;;---------------------------------------------------------------------------*/
static void l_0C05_flite_pth_cont(void)
{
    // flag is set by case_0AA0 when cylon disposition -> 9
    if (0x40 & ds_bug_motion_que[b_bug_que_idx].b13) // bit  6
    {
        // transitions to the next segment of the flight pattern
        if (ds_bug_motion_que[b_bug_que_idx].b01 ==
                ds_bug_motion_que[b_bug_que_idx].b06
                ||
                (ds_bug_motion_que[b_bug_que_idx].b01 -
                 ds_bug_motion_que[b_bug_que_idx].b06) == 1
                ||
                (ds_bug_motion_que[b_bug_que_idx].b06 -
                 ds_bug_motion_que[b_bug_que_idx].b01) == 1)
        {
            if (ds_bug_motion_que[b_bug_que_idx].b03 ==
                    ds_bug_motion_que[b_bug_que_idx].b07
                    ||
                    (ds_bug_motion_que[b_bug_que_idx].b03 -
                     ds_bug_motion_que[b_bug_que_idx].b07) == 1
                    ||
                    (ds_bug_motion_que[b_bug_que_idx].b07 -
                     ds_bug_motion_que[b_bug_que_idx].b03) == 1)
            {
                uint8 A, L;

                // jp l_0E08 ... creature gets to home-spot
                ds_bug_motion_que[b_bug_que_idx].b13 &= ~0x01; // res  0,0x13(ix) ... mark the flying structure as inactive

                ds_bug_motion_que[b_bug_que_idx].b00 = 0;
                ds_bug_motion_que[b_bug_que_idx].b02 = 0;

                L = ds_bug_motion_que[b_bug_que_idx].b10;
                b8800_obj_status[ L ].state = 2; // disposition = 02: rotating back into position in the collective

                A = mrw_sprite.cclr[L].b1; // sprite color code
                A += 1; // inc  a
                A &= 0x07; // and  #0x07

                if (A >= 5) // ... remaining bonus-bee returns to collective
                {
                }

                // l_0E3A
                // these could be off by one if not already equal
                ds_bug_motion_que[b_bug_que_idx].b01 =
                    ds_bug_motion_que[b_bug_que_idx].b06;

                ds_bug_motion_que[b_bug_que_idx].b03 =
                    ds_bug_motion_que[b_bug_que_idx].b07;

                //almost done ... update the sprite x/y positions
                l_0D03_flite_pth_posn_set(L); // jp   z,l_0D03

                return;
            }
        }
    }

    l_0C2D_flite_pth_step(); //jp l_0C2D

    //almost done ... update the sprite x/y positions
    // l_0D03_flite_pth_posn_set(L); // jp   z,l_0D03

}

/*=============================================================================
;; l_0C2D_flite_pth_step()
;;  Description:
;;
;; IN:
;;
;; OUT:
;;
;; PRESERVES:
;;
;;---------------------------------------------------------------------------*/
static void l_0C2D_flite_pth_step(void)
{
    reg16 temp16;
    uint8 A, B, C, L;
    uint8 E_save_b04, D_save_b05;


    if (0x20 & ds_bug_motion_que[b_bug_que_idx].b13) // bit  5
    {
        if ((ds_bug_motion_que[b_bug_que_idx].b01 ==
                ds_bug_motion_que[b_bug_que_idx].b06)
                ||
                (ds_bug_motion_que[b_bug_que_idx].b01 -
                 ds_bug_motion_que[b_bug_que_idx].b06) == 1
                ||
                (ds_bug_motion_que[b_bug_que_idx].b06 -
                 ds_bug_motion_que[b_bug_que_idx].b01) == 1)
        {
            // set it up to expire on next step
            ds_bug_motion_que[b_bug_que_idx].b0D = 1;
            ds_bug_motion_que[b_bug_que_idx].b13 &= ~0x20; // res  5,0x13(ix)
        }
    }

    // l_0C46
    E_save_b04 = ds_bug_motion_que[b_bug_que_idx].b04;
    D_save_b05 = ds_bug_motion_que[b_bug_que_idx].b05; // need this later ...
    temp16.word = E_save_b04;
    temp16.pair.b1 = D_save_b05;
    temp16.word += (sint8) ds_bug_motion_que[b_bug_que_idx].b0C;
    ds_bug_motion_que[b_bug_que_idx].b04 = temp16.pair.b0;
    ds_bug_motion_que[b_bug_que_idx].b05 = temp16.pair.b1;

    /*
     * determine_sprite_code
     */
    A = E_save_b04; // ld   a,e

    if (0x01 & D_save_b05) // bit  0,c
        A = ~A; // cpl

    // l_0C6D
    temp16.word = A + 0x15;
    A = temp16.pair.b0;
    if (temp16.word & 0x0100)
    {
        // select vertical tile if within 15 degrees of 90 or 270
        B = 6;
        // jr   l_0C81
    }
    else
    {
        // l_0C75
        // divide by 42 ...42 counts per step of rotation (with 24 steps in the circle, 1 step is 15 degrees)
        // Here's the math: A * ( 1/2 + 1/4 ) * ( 1/32 )
        B = A >> 1; // srl  a ... etc
        A = (A >> 1) + (B >> 1); // srl  b
        A = A >> 5; // rlca x3
        B = A & 0x07;
    }

    // l_0C81
    // ld   h,#>_mrw_sprite_code_base
    L = ds_bug_motion_que[b_bug_que_idx].b10;

    A = mrw_sprite.cclr[L].b0 & 0xF8; // base sprite code (multiple of 8)
    mrw_sprite.cclr[L].b0 = A | B;


    // determine_sprite_ctrl( C )
    C = D_save_b05 >> 1; // rrc c
    A = (D_save_b05 ^ C) + 1; // xor c, inc a ... now have bit1
    A = (A << 1) | (C & 0x01); // rrc c ... rla
    mrw_sprite.ctrl[L].b0 = A & 0x03;

    if (0x01 & ds3_92A0_frame_cts[0])
    {
        A = ds_bug_motion_que[b_bug_que_idx].b0A;
    }
    else
    {
        A = ds_bug_motion_que[b_bug_que_idx].b0B;
    }


    // l_0CA7
    if (A)
        flite_pth_exec(A, D_save_b05, E_save_b04, b_bug_que_idx);

    //almost done ... update the sprite x/y positions
    l_0D03_flite_pth_posn_set(L); // jp   z,l_0D03

    return;
}

/*=============================================================================
;; flite_pth_exec()
;;  Description:
;;
;; IN:
;;
;; OUT:
;;
;; PRESERVES:
;;
;;---------------------------------------------------------------------------*/
static void flite_pth_exec(uint8 _A_, uint8 _D_, uint8 _E_, uint8 _b_bug_que_idx)
{
    uint8 * pBx[4]; // only need 2, but use size 4 for indexing
    uint8 *pHL;
    reg16 pushDE, popHL, tmp16, tmpAC, tmpHL;
    uint8 A, B, D, L, Cy;
    uint8 pBidx;

    L = _b_bug_que_idx; // push ix ... pop  hl

    // setup pointers to b0 and b2
    pBx[0] = &ds_bug_motion_que[L].b00;
    pBx[2] = &ds_bug_motion_que[L].b02;
    pBidx = 0;
    pHL = pBx[pBidx]; // pop hl


    B = _A_; // (ix)0x0A or (ix)0x0B

    /*
    ;               90          - angle in degrees
    ;             1  | 0        - quadrant derived from 10-bit angle
    ;          180 --+-- 0      - each tile rotation is 15 degrees (6 tiles per quadrant)
    ;             2  | 3
    ;               270
    ; checking bit-7 against bit-8, looking for orientation near 90 or 270.
    ; must be >= xx80 in quadrant 0 & 2, and < xx80 in quadrant 1 & 3
     */
    A = _D_ & 3; // d saved from 0x05(ix)
    pushDE.pair.b1 = A;
    pushDE.pair.b0 = _E_; // e saved from (ix)0x04
    pushDE.word <<= 1; // rlc, rl ... restores to HL below .....
    pushDE.pair.b0 |= (0 != (_E_ & 0x80)); // Cy from rlc  e

    A ^= pushDE.pair.b1; // xor  d

    // check for Cy shifted into bit7 from rrca
    if (0x00 == (A & 0x01)) // jr   c,l_0CBF
    {
        // update the pointer for horizontal travel
        pBidx += 2; // L == offset to b02
        pHL = pBx[pBidx];
    }

    // l_0CBF
    D = pushDE.pair.b1 + 1; // inc d
    A = B; // ... restore A: 0x0A(ix) or 0x0B(ix)

    if (0x04 & D) // bit  2,d ... jr   z,l_0CC7
        A = -A; // neg

    // l_0CC7
    // A is bits<7:14> of addend, .b00/.b02 is fixed point 9.7
    tmpAC.pair.b0 = 0;
    tmpAC.pair.b1 = A; // ld   c,a ... from 0x0A(ix) or 0x0B(ix)
    tmpAC.word = (sint16) tmpAC.word >> 1; // sra  c ... sign extend and carry out of bit-0 of msb
    tmpHL.pair.b0 = *(pHL + 0);
    tmpHL.pair.b1 = *(pHL + 1);
    tmpHL.word += tmpAC.word; // adc  a,c
    *(pHL + 0) = tmpHL.pair.b0;
    *(pHL + 1) = tmpHL.pair.b1;


    pBidx ^= 0x02; // toggle x/y pointer, .b00 or .b02
    pHL = pBx[pBidx];

    // test if bit-7 of E (pushed from DE above) was set, i.e. if > 0x80
    popHL.word = pushDE.word; // pop  hl ..... 0x04(ix) from push DE above
    Cy = (popHL.pair.b0 & 0x01);
    popHL.pair.b0 >>= 1; // srl  l ... revert to unshifted
    if (Cy)
        popHL.pair.b0 ^= 0x7F; // ld   l,a

    // l_0CE3
    A = B; // ... restore A: 0x0A(ix) or 0x0B(ix)
    B = popHL.pair.b1; // ld   b,h ... msb of adjusted angle
    popHL.word = c_0E97(A, popHL.pair.b0); // HL = L * A

    A = B ^ 0x02; // msb of adjusted angle
    A--; // dec  a

    if (A & 0x04) // bit  2,a ... jr   z,l_0CFA
    {
        //and  a ...  whuuuuuut????
        popHL.word = -popHL.word; // sbc  hl,bc (negate the word)
    }

    // l_0CFA
    // ex   de,hl                                 ; reload the pointer from DE
    // ; *HL += *DE
    tmp16.pair.b0 = *(pHL + 0);
    tmp16.pair.b1 = *(pHL + 1);
    tmp16.word += popHL.word;
    *(pHL + 0) = tmp16.pair.b0;
    *(pHL + 1) = tmp16.pair.b1; // adc  a,(hl)
}

/*=============================================================================
;; l_0D03_flite_pth_posn_set()
;;  Description:
;;
;; IN:
;;
;; OUT:
;;
;; PRESERVES:
;;
;;---------------------------------------------------------------------------*/
static void l_0D03_flite_pth_posn_set(uint8 _L_)
{
    reg16 r16;
    uint16 tmp16;
    uint8 Cy, A, E;
    uint8 L = _L_; // object index

    //mrw_sprite[_L_].posn->b0

    // fixed point 9.7 in .b02.b03 - left shift integer portion into A ... carry
    // in to <0> from .b02<7>
    A = ds_bug_motion_que[b_bug_que_idx].b03 << 1; // rla
    A |= (0 != (0x80 & ds_bug_motion_que[b_bug_que_idx].b02)); // shift in .b02<7>

    if (0 != glbls9200.flip_screen) // bit  0,c
    {
        A = ~(0x0D + A); // add  a,#0x0D ... cpl
    }

    // l_0D1A
    if (0 != (0x40 & ds_bug_motion_que[b_bug_que_idx].b13)) // bit  6,0x13(ix)
    {
        A += ds_bug_motion_que[b_bug_que_idx].b11; // heading home (step x coord)
    }

    // l_0D23
    mrw_sprite.posn[L].b0 = A;

    // inc l

    // set carry-in from .b00<7>
    E = (0 != (0x80 & ds_bug_motion_que[b_bug_que_idx].b00)); // rl   e

    A = ds_bug_motion_que[b_bug_que_idx].b01; // ld   a,b

    if (0 == glbls9200.flip_screen) // bit  0,c
    {
        tmp16 = 0x4F + A;
        A = ~(0x00FF & tmp16); // add  a,#0x4F ... cpl
        E--; // dec  e ... invert bit-0
    }

    // l_0D38:
    Cy = (E & 0x01); // get carry for rla ...
    E = (E >> 1) | (Cy << 7); // rr   e ... gets the Cy flag

    r16.word = (A << 1) | Cy; // rla ... carry rotated into msb - bit-8 rotated into Cy
    A = r16.pair.b0; // rla

    E = r16.pair.b1 & 0x01; // rl   e ... carry-in from rla, bit-8 of sprite_y into e<0>

    if (0 != (0x40 & ds_bug_motion_que[b_bug_que_idx].b13)) // bit  6,0x13(ix)
    {
        // heading home (step y coord)
        r16.word = A + ds_bug_motion_que[b_bug_que_idx].b12; // add  a,0x12(ix)

        A = r16.pair.b0 >> 1;
        A |= (r16.pair.b1 & 0x01) << 7; // rra ... rotate in the Cy from add

        A ^= ds_bug_motion_que[b_bug_que_idx].b12;

        if (0 != (A & 0x80)) // rlca (only need the Cy bit)
            E++;

        A = r16.pair.b0;
    }

    // l_0D50
    mrw_sprite.posn[L].b1 = A; // sprite[n].posn.sy<0:7>
    mrw_sprite.ctrl[L].b1 = (mrw_sprite.ctrl[L].b1 & ~0x01) | (E & 0x01); // sprite[n].posn.sy<8>

    // Once the timer in $0E is reached, then check conditions to enable bomb drop.
    // If bomb is disabled for any reason, the timer is restarted.
    ds_bug_motion_que[b_bug_que_idx].b0E--;


    // jp   nz,l_0DFB_next_superloop
    if (0 != ds_bug_motion_que[b_bug_que_idx].b0E)
    {
        return; // jp   nz,l_0DFB_next_superloop
    }

    Cy = ds_bug_motion_que[b_bug_que_idx].b0F & 0x01;
    ds_bug_motion_que[b_bug_que_idx].b0F >>= 1; // srl  0x0F(ix)

    if (Cy
            &&
            ds_bug_motion_que[b_bug_que_idx].b01 >= 0x4C // cp   #0x4C
            &&
            0 != task_actv_tbl_0[0x15]
            &&
            0 == ds4_game_tmrs[1])
    {
        // get me some bullets
        return;
    }

    // l_0DF5_next_superloop_and_reload_0E
    ds_bug_motion_que[b_bug_que_idx].b0E = b_92E2_stg_parm[0]; // bomb drop counter


    // jp   l_08E4_superloop
    return;
}

/*=============================================================================
;; c_0E5B()
;;  Description:
;;    Determine rotation angle ... (ix)0x04, (ix)0x05
;;    Parameters are all bits<1:8> of the integer portion (upper-byte)
;; IN:
;;  D - abs row pix coord
;;  E - abs col pix coord
;;  H - y, (ix)0x01
;;  L - x, (ix)0x03
;; OUT:
;;  HL
;; PRESERVES:
;;  BC, DE
;;---------------------------------------------------------------------------*/
static uint16 c_0E5B(uint16 _DE_, uint8 _H_, uint8 _L_)
{
    reg16 rDE, rHL;
    uint8 A, B, C, D, E, L, Cy, pushCy;

    rDE.word = _DE_;
    E = rDE.pair.b0; // cX
    D = rDE.pair.b1; // cY

    A = E - _L_; // sub  l
    B = 0;

    if (_L_ > E) // jr   nc,l_0E67
    {
        B = 1; // set  0,b
        A = -A; // neg
    }

    // l_0E67:
    C = A;

    A = D - _H_; // sub  h

    if (_H_ > D) // jr   nc,l_0E76
    {
        B ^= 1; // xor  #0x01
        B |= 2; // or   #0x02

        A = -A; // neg
    }

    // l_0E76:
    Cy = (C > A); // cp   c
    pushCy = Cy; // push af
    Cy ^= B; // rla ... rra
    Cy ^= 1; // ccf
    B <<= 1; // rl   b ...
    B |= (Cy & 0x01); // ... rl   b

    // pop  af

    if (pushCy)
    {
        D = C;
        C = A;
        A = D;
    }

    // l_0E84:
    rHL.pair.b1 = C;
    rHL.pair.b0 = 0;

    rHL.word = c_0EAA(A, rHL.word); // HL = HL / A

    L = rHL.pair.b0;

    A = rHL.pair.b1; // ld   a,h
    A ^= B; // xor  b
    A &= 0x01; // and  #0x01

    // jr   z,l_0E93
    if (A)
    {
        L = ~rHL.pair.b0; // cpl
    }

    // l_0E93
    rHL.pair.b0 = L;
    rHL.pair.b1 = B; // ld   h,b

    return rHL.word;
}

/*=============================================================================
;; c_0E97()
;;  Description:
;;    for f_08D3
;;    HL = HL * A
;; IN:
;;  HL (only L is significant)
;; OUT:
;;  H
;;  L
;; PRESERVES:
;;  DE
;;---------------------------------------------------------------------------*/
static uint16 c_0E97(uint8 _A_, uint8 _L_)
{
    reg16 HL, DE;
    uint8 A;

    A = _A_;
    DE.word = _L_; // ex   de,hl
    HL.word = 0;

    do
    {
        if (A & 0x01) // jr   nc,l_0EA1
            HL.word += DE.word;

        // l_0EA1
        DE.word <<= 1; // sla  e ... rl   d
        A >>= 1; // srl  a
    }
    while (0 != A);

    return HL.word;
}

/*=============================================================================
;; c_0EAA()
;;  Description:
;;   HL = HL / A  ... the hard way
;; IN:
;;  A, HL
;; OUT:
;;  HL
;; PRESERVES:
;;  BC
;;---------------------------------------------------------------------------*/
static uint16 c_0EAA(uint8 _A_, uint16 _HL_)
{
    uint32 Cy16; // carry out from adc hl
    reg16 rA, rHL;
    uint8 B, C;
    uint8 Cy;

    rHL.word = _HL_;
    C = _A_;

    rA.word = 0; // xor  a ... clears Cy
    Cy = 0;

    B = 0; // 0x11;

    // l_0EAF:
    while (B < 17)
    {
        rA.word = rA.pair.b0 + rA.pair.b0 + Cy; // adc  a,a

        // jr   c,l_0EBD
        if (rA.word < 0x0100)
        {
            Cy = 1;
            // cp   c
            // jr   c,l_0EB6
            if (C <= rA.pair.b0)
            {
                Cy = 0;
                rA.pair.b0 -= C;
            }
            // l_0EB6:
            Cy ^= 1; // ccf
        }
        else
        {
            // l_0EBD:
            rA.pair.b0 -= C; // sub  c
            Cy = 1; // scf
            // jp   l_0EB7
        }

        // l_0EB7:
        Cy16 = rHL.word + rHL.word + Cy; // adc  hl,hl
        rHL.word = Cy16;
        Cy = (0 != (Cy16 & 0x00010000)); // overflow out of 16-bits

        B++; // djnz l_0EAF
    }
    // pop  bc
    return rHL.word;
}

/*=============================================================================
;; f_0ECA()
;;  Description:
;;   Reads dsw3 which is doesn't seem to have any function (MAME list as unused).
;;   If the switch were active (0) then the section of code would be reading
;;   from code space locations beyond the $1000. Also odd is the conditional
;;   rst  $00. Maybe a remnant of a piece of code reused from one of the games
;;   on one of the similar NAMCO Z80 platforms (digdig, bosconian etc).
;; IN:
;;  ...
;; OUT:
;;  ...
;;----------------------------------------------------------------------------*/
void f_0ECA(void)
{

}

// additional challenge stage data (see db_2A3C)
static const uint8 flv_d_0fda[] =
{
    0x23,0x00,0x1B,0x23,0xF0,0x40,0x23,0x00,0x09,0x23,0x05,0x11,
    0x23,0x00,0x10,0x23,0x10,0x40,0x23,0x04,0x30,0xFF
};
static const uint8 flv_d_0ff0[] =
{
    0x23,0x02,0x35,0x23,0x08,0x10,
    0x23,0x10,0x3C,0x23,0x00,0xFF,0xFF
};

/************************************/

// offsets from gg1-5 map file - can use t_flv_offs enum in place of hard
// values for what it's worth
void flv_init_data(void)
{
    FLV_MCPY( flv_d_001d      , 0x001D) // stg 1
    FLV_MCPY( flv_p_004b      , 0x004B) // this one is a "jump" but is not contigous with previous so must be copied explicitly
    FLV_MCPY( flv_d_0067      , 0x0067) // stg 1
    FLV_MCPY( flv_d_009f      , 0x009F) // stg 2
//  FLV_MCPY(_flv_i_00b6      , 0x00B6)
//  FLV_MCPY(_flv_i_00cc      , 0x00CC)
    FLV_MCPY( flv_d_00d4      , 0x00D4) // stg 2
//  FLV_MCPY(_flv_i_0160      , 0x0160)
//  FLV_MCPY(_flv_i_0173      , 0x0173)
    FLV_MCPY( flv_d_017b      , 0x017B)
//  FLV_MCPY(_flv_i_0192      , 0x0192)
//  FLV_MCPY(_flv_i_01a8      , 0x01A8)
    FLV_MCPY( flv_d_01b0      , 0x01B0)
//  FLV_MCPY(_flv_i_01ca      , 0x01CA)
//  FLV_MCPY(_flv_i_01e0      , 0x01E0)
    FLV_MCPY( flv_d_01E8      , 0x01E8) // chllg stg (3)
    FLV_MCPY( flv_d_01F5      , 0x01F5) // chllg stg (3)
    FLV_MCPY( flv_d_020b      , 0x020B)
    FLV_MCPY( flv_d_021b      , 0x021B)
    FLV_MCPY( flv_d_022b      , 0x022B)
    FLV_MCPY( flv_d_0241      , 0x0241)
    FLV_MCPY( flv_d_025d      , 0x025D)
    FLV_MCPY( flv_d_0279      , 0x0279)
    FLV_MCPY( flv_d_029e      , 0x029E)
    FLV_MCPY( flv_d_02ba      , 0x02BA)
FLV_MCPY( flv_d_02d9      , 0x02D9)
FLV_MCPY( flv_d_02fb      , 0x02FB)
FLV_MCPY( flv_d_031d      , 0x031D)
FLV_MCPY( flv_d_0333      , 0x0333)
    FLV_MCPY( flv_d_atk_yllw  , 0x034F)
//  FLV_MCPY(_flv_i_0352      , 0x0352)
//  FLV_MCPY(_flv_i_0358      , 0x0358)
//  FLV_MCPY(_flv_i_0363      , 0x0363)
//  FLV_MCPY(_flv_i_036c      , 0x036C)
//  FLV_MCPY(_flv_i_037c      , 0x037C)
//  FLV_MCPY(_flv_i_039e      , 0x039E)
    FLV_MCPY( flv_d_atk_red   , 0x03A9)
//  FLV_MCPY(_flv_i_03ac      , 0x03AC)
//  FLV_MCPY(_flv_i_03cc      , 0x03CC)
//  FLV_MCPY(_flv_i_03d7      , 0x03D7)
//  FLV_MCPY(_flv_i_040c      , 0x040C)
//  FLV_MCPY(_flv_i_0414      , 0x0414)
//  FLV_MCPY(_flv_i_0420      , 0x0420)
//  FLV_MCPY(_flv_i_0425      , 0x0425)
//  FLV_MCPY(_flv_i_0430      , 0x0430)
//  FLV_MCPY( flv_d_cboss      , 0x046B)
//  FLV_MCPY(_flv_i_0499      , 0x0499)
//  FLV_MCPY( flv_d_04c6      , 0x04C6)
//  FLV_MCPY(_flv_i_04c6      , 0x04C6)
//  FLV_MCPY(_flv_i_04cf      , 0x04CF)
//  FLV_MCPY( flv_d_04cf      , 0x04CF)
//  FLV_MCPY( flv_d_04d8      , 0x04D8)
//  FLV_MCPY(_flv_i_04d8      , 0x04D8)
//  FLV_MCPY( flv_d_0502      , 0x0502)
//  FLV_MCPY(_flv_i_0502      , 0x0502)
    FLV_MCPY( flv_d_0fda      , 0x0FDA)
    FLV_MCPY( flv_d_0ff0      , 0x0FF0)
}
