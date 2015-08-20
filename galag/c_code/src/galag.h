/*
 * main header file for application interface to MAME code
 */
#ifndef _GALAG_H_
#define _GALAG_H_

/*
 * "hardware" registers managed by memory and IO handlers in the MAME engine
 */
extern unsigned char *spriteram;
extern unsigned char *spriteram_2;
extern unsigned char *spriteram_3;

extern unsigned char *videoram;
extern unsigned char *colorram;

#define  m_tile_ram  videoram
#define  m_color_ram colorram

extern unsigned char *galaga_starcontrol;
#define  sfr_A000_starctl galaga_starcontrol

/*
 * basic types
 */
typedef char sint8;
typedef unsigned char uint8;
typedef unsigned short uint16;
typedef signed short sint16;
typedef unsigned int uint32;

/*
 * generic type for "registers"
 */
typedef struct
{
#ifdef LSB_FIRST
    uint8 b0;
    uint8 b1;
#else
    uint8 b1;
    uint8 b0;
#endif
} bpair_t;

/*
 * byte or word access to 16-bit registers
 */
typedef union
{
    uint16 word;
    bpair_t pair;
} r16_t;

typedef     struct
{
#ifdef LSB_FIRST
        r16_t w0;
        r16_t w1;
#else
        r16_t w1;
        r16_t w0;
#endif
} wpair_t;

typedef union
{
    wpair_t wpair;
    uint32 u32; // as long as there could possibly need to be in this system
} r32_t;


/*
 * bmbr boss slot
 */
typedef struct
{
    uint8 obj_idx;
    uint8 unused; // even alignment probably forced anyway
    uint16 vectr;
} bmbr_boss_slot_t;

/*
 * mchn cfg dipswitches
 */
typedef struct
{
    uint8 bonus[2];
    uint8 nships;
    uint8 cab_type;
    uint8 rank;

} mchn_cfg_t;

/*
 * states for gctl_game_state
 */
enum {
    GAME_ENDED = 0,
    ATTRACT_MODE = 1,
    READY_TO_PLAY_MODE = 2,
    IN_GAME_MODE = 3
};

/*
 * various globals lumped together in spare bytes of $9200[]
 */
typedef struct
{
    uint8 game_state; //               01
    uint8 attmode_idx; //              03
    uint8 glbl_enemy_enbl; //          0B: global enable for enemy operations
    uint8 bug_nest_direction_lr; //    0F: 1:left, 0:right
    uint8 formatn_mv_signage; //       11: sign of formation pulse movement for snd mgr
    uint8 restart_stage; //            13: "end of attack" (all attackers go home)
    uint8 flip_screen; //              15:  0 ...not_flipped
} tstruct_b9200;

/*
 * Missiles, bombs, fighters, enemey aliens ... all are derived from this
 * machine's equivalent concept of a sprite object. This typedef is obviously
 * nothing more than a simple index, but any given sprite has several
 * attibute fields (x/y location, tile-date index, color) accessed at banks
 * of memory-mapped hardware registers sharing a common index.
 */
typedef uint8 gspr_t;

/*
 * player context: all the state information needed to alternate between player 1 & 2
 */
typedef struct
{
    uint8 fghtrs_resv;        // fighters remaining in reserve
    uint8 stg_ct;
    uint8 *p_atkwav_tbl;      // &8920[n] (see 2896)
    uint8 convlr_inh;         // 1 or 0 .. flag to f_2A90: if 1, convoy left/right movement should stop
    uint8 not_chllng_stg;     // stg_ctr+1%4 (0 if challenge stage)
    uint8 attkwv_ct;
    uint8 dblfghtr;           // 1 ...player is two-ship
    gspr_t bmbr_boss_captr;   // object/index of active capturing boss
    //   0x09    ; set by cpu-b as capturing boss starts dive  (910D?)
    //   0x0A    ; related to ship-capture status
    uint8 bmbr_boss_cflag;    // 1 == suppress select capture boss (force wingman)
    uint8 bmbr_boss_escort;   // boss is escort, not capturing

    gspr_t squad_lead;        // parent object of a special (three ship) attack squadron
    //   0x0E    ; flashing color 'A' for special attack squadrons
    //   0x0F    ; flashing color 'B' for special attack squadrons

    uint8 bmbr_boss_scode[8]; // bonus code/score attributes e.g. "01B501B501B501B5"... 8 bytes, "01B501B501B501B5"
    //   unused 0x18-0x1D
    uint8 mcfg_bonus;         // mach_cfg_bonus[0]...load at game start ... $9980
    uint8 plyr_swap_tmr;      // game_tmr_2, player1/2 switch
    uint8 plyr_nbr;           // 0==plyr1, 1==plyr2
    uint8 squad_launch_tmr;   // timer for launching special (three ship) attack squadron
    uint8 atkwv_enbl;         // 0 when respawning fighter
    uint8 enmy_ct;            // b_bugs_actv_nbr
    uint16 hit_ct;            // total hits
    uint16 shot_ct;           // total shots
    uint8 snd_flag;           // fx count/enable regs (pulsing formation sound effect)

} t_plyr_state;

/*
 * sprite registers organized as a struct of arrays to align data with z80
 */
typedef struct
{
    // offset[0]: tile code
    // offset[1]: color map code
    bpair_t cclr[0x80];

    // offset[0]: sx
    // offset[1]: sy, bits 0:7 ... see sprite control offset[1]:0
    bpair_t posn[0x80];

    // offset[0]
    //  0: flipx - flip about the X axis, i.e. "up/down"
    //  1: flipy - flip about the Y axis, i.e. "left/right"
    //  2: dblh - MAME may not do dblh unless dblw is also set... (this may not be true)
    //  3: dblw
    // offset[1]
    //  0: sy, bit-8 ... i.e.  sx += offset[1] & 1 * 0x100
    //  1: enable
    bpair_t ctrl[0x80];

} sprt_regs_t;

/*
 * Combined array of 2-byte structures for pix coordinates of sprites at home
 * positions ... 10 column coordinates followed by 6 row coordinates, organized
 * as structures of (double-sized) arrays to keep indexing consistent with z80.
 */
typedef struct
{
  // pixel coordinates (9-bit integer) which are copied directly to sprite regs
  // for objects in stand-by positions.
  r16_t spcoords[16 * 2];
  uint8 offs[16 * 2]; // current pixel offset of each row and column

} fmtn_hpos_t;

/*
 Sprite object state and index to associated slot in mctl pool ... 2 bytes
 per element paired together in order to align data for reference to z80.

 The index of each array element corresponds to the assigned location in sprite
 registers, however only the first $30 elements are tracked in sprt_hit_notif[].

 memory structure of the formation in standby positions:

             00 04 06 02         ; captured fighters (00, 02, 04 fighter icons on push-start-btn screen)
             30 34 36 32
       40 48 50 58 5A 52 4A 42
       44 4C 54 5C 5E 56 4E 46
    08 10 18 20 28 2A 22 1A 12 0A
    0C 14 1C 24 2C 2E 26 1E 16 0E
*/
typedef struct
{
    uint8 state;     // [ 0 + n ] : object state/disposition
    uint8 mctl_idx;  // [ 1 + n ] : index of slot in motion control (see f_2916)
                     //              ... object index copied to mctrl_que.b10
} sprt_mctl_obj_t;

// state of sprt_mctl_obj_t
typedef enum
{
    STAND_BY = 1,   // in formation position (preceeded by "rotating")
    HOME_RTN,       // arrived into home position and rotating
    PTRN_CTL,       // pattern control ... follows spawning
    EXPLODING,      // dying
    SCORE_BITM,     // showing score bitmap
    BOMB,           // special state if sprite used as bomb
    SPAWNING,       // precedes pattern control
    ROGUE_FGHTR,    // non-pilot controlled fighter (rogue or exploding)
    HOMING,         // moving to specific point location i.e. homing or diving attack
    INACTIVE = 0x80 // (also for fighter)
}
sprt_mctl_obj_state_t;

// indices for some sprite objects
#define SPR_IDX_SHIP  (0x62)
#define SPR_IDX_RCKT  (0x64)
#define SPR_IDX_RCKT0 (SPR_IDX_RCKT)
#define SPR_IDX_RCKT1 (SPR_IDX_RCKT0 + sizeof(bpair_t))
#define SPR_IDX_BOMB0 (SPR_IDX_RCKT1 + sizeof(bpair_t))

/*
 * struct type for motion control pool
 *  00-07 writes to 92E0, see _2636
 *  08-09 ptr to data in cpu-sub-1:4B
 *  0D + *(ds_9820_actv_plyr_state + 0x09)
 *  10 index/offset of object .... i.e. 8800 etc.
 *  11 + offset
 *  13 + offset
 */
typedef struct
{
    r16_t cy; // current Y (adjusted for formation offset if homing)
    r16_t cx; // current X (adjusted for formation offset if homing)
    r16_t ang; // 10-bit rotation angle
    uint8 b06; // origin home position Y (bits 15:8)
    uint8 b07; // origin home position X (bits 15:8)
    r16_t p08; // flight pattern data table pointer ... treat as uint16
    //uint8 b09
    uint8 b0A; // displacement vector
    uint8 b0B; // displacement vector
    uint8 b0C; // rotation increment
    uint8 b0D; // flight path step counter/timer
    uint8 b0E; // bomb drop counter
    uint8 b0F; // bomb drop enable flag
    uint8 b10; // index to sprt_mctl_objs[]
    uint8 b11; // step X coord
    uint8 b12; // step Y coord
    uint8 b13; // status flags ...
    /*
        0x01 check for activated state
        0x02
        0x04
        0x08
        0x10
        0x20 check for yellow-alien or boss dive
        0x40 heading home (formation offset)
        0x80 if set then negate data
    */
} mctl_pool_t;

/*
 * 16-bit offsets for flite vector data, used for _flite_ptn_cfg:p_tble
 * don't exceed 2^16 entries in this table ;)
 */
typedef enum
{
    _flv_d_001d      = 0x001D,
    _flv_d_00f1      = 0x00F1,
    _flv_i_004b      = 0x004B,
    _flv_i_005e      = 0x005E,
    _flv_d_0067      = 0x0067,
    _flv_i_0084      = 0x0084,
    _flv_i_0097      = 0x0097,
    _flv_d_009f      = 0x009F,
    _flv_i_00b6      = 0x00B6,
    _flv_i_00cc      = 0x00CC,
    _flv_d_00d4      = 0x00D4,
    _flv_i_0160      = 0x0160,
    _flv_i_0173      = 0x0173,
    _flv_d_017b      = 0x017B,
    _flv_i_0192      = 0x0192,
    _flv_i_01a8      = 0x01A8,
    _flv_d_01b0      = 0x01B0,
    _flv_i_01ca      = 0x01CA,
    _flv_i_01e0      = 0x01E0,
    _flv_d_01e8      = 0x01E8,
    _flv_d_01f5      = 0x01F5,
    _flv_d_020b      = 0x020B,
    _flv_d_021b      = 0x021B,
    _flv_d_022b      = 0x022B,
    _flv_d_0241      = 0x0241,
    _flv_d_025d      = 0x025D,
    _flv_d_0279      = 0x0279,
    _flv_d_029e      = 0x029E,
    _flv_d_02ba      = 0x02BA,
    _flv_d_02d9      = 0x02D9,
    _flv_d_02fb      = 0x02FB,
    _flv_d_031d      = 0x031D,
    _flv_d_0333      = 0x0333,
    _flv_d_atk_yllw  = 0x034F,
    _flv_i_0352      = 0x0352,
//  _flv_i_0358      = 0x0358,
//  _flv_i_0363      = 0x0363,
    _flv_i_036c      = 0x036C,
    _flv_i_037c      = 0x037C,
    _flv_i_039e      = 0x039E,
    _flv_d_atk_red   = 0x03A9,
    _flv_i_03ac      = 0x03AC,
    _flv_i_03cc      = 0x03CC,
    _flv_i_03d7      = 0x03D7,
    _flv_i_040c      = 0x040C,
    _flv_d_0411      = 0x0411,
    _flv_i_0414      = 0x0414,
    _flv_i_0420      = 0x0420,
    _flv_i_0425      = 0x0425,
    _flv_i_0430      = 0x0430,
    _flv_d_0454      = 0x0454,
//  _flv_d_cboss     = 0x046B,
//  _flv_i_0499      = 0x0499,
//  _flv_d_04c6      = 0x04C6,
//  _flv_i_04c6      = 0x04C6,
//  _flv_i_04cf      = 0x04CF,
//  _flv_d_04cf      = 0x04CF,
//  _flv_d_04d8      = 0x04D8,
//  _flv_i_04d8      = 0x04D8,
//  _flv_d_0502      = 0x0502,
//  _flv_i_0502      = 0x0502,
    _flv_d_0fda      = 0x0FDA,
    _flv_d_0ff0      = 0x0FF0,
//
} t_flv_offs;


/*
 * text string with color and screen-position encoded within
 */
typedef struct
{
    // posn is not absolute, but an offset into "tileram"
    uint16 posn;
    uint8 color; // color code
    const char *chars; // terminated string
} str_pe_t;

/*
 * extern declarations
 */

/* galag.c */
extern uint8 irq_acknowledge_enable_cpu0;
extern uint8 irq_acknowledge_enable_cpu1;
extern uint8 nmi_acknowledge_enable_cpu2;

extern uint8 _sfr_dsw1; //  $$6800
extern uint8 _sfr_dsw2; //  $$6801
extern uint8 _sfr_dsw3; //  $$6802
extern uint8 _sfr_dsw4; //  $$6803
extern uint8 _sfr_dsw5; //  $$6804
extern uint8 _sfr_dsw6; //  $$6805
extern uint8 _sfr_dsw7; //  $$6806
extern uint8 _sfr_dsw8; //  $$6807

extern uint8 _sfr_6820; //  $$6820  ; maincpu IRQ acknowledge/enable
extern uint8 _sfr_6821; //  $$6821  ; CPU-sub1 IRQ acknowledge/enable)
extern uint8 _sfr_6822; //  $$6822  ; CPU-sub2 nmi acknowledge/enable
extern uint8 _sfr_6823; //  $$6823  ; 0:halt 1:enable CPU-sub1 and CPU-sub2

extern uint8 _sfr_watchdog; // $$6830


/* game_ctrl.c */
extern uint8 b_bug_flyng_hits_p_round;
extern tstruct_b9200 glbls9200;
extern uint8 ds_99B9_star_ctrl[];
extern uint8 io_input[];
extern uint8 ds_bug_collsn[];

extern uint8 fmtn_mv_tmr; // 99B4_bugnest_onoff_scrn_tmr
/* task_man.c */
extern t_plyr_state plyr_actv;
extern t_plyr_state plyr_susp;
extern uint8 task_actv_tbl_0[];
extern uint8 task_resv_tbl_0[];
extern uint8 ds4_game_tmrs[];
extern uint16 w_bug_flying_hit_cnt;

/* gg1-4.c */
extern mchn_cfg_t mchn_cfg;

/* gg1-5.c */
extern uint8 ds3_92A0_frame_cts[];
extern uint8 cpu1_task_en[];
extern uint8 b_bugs_flying_nbr;
extern const uint8 sprt_fmtn_hpos_ord_lut[];
extern uint8 sprt_hit_notif[];
extern uint8 bmbr_cont_flag;

/* gg1-7.c */
extern uint8 b_9AA0[];
extern uint8 b_9A70[];

/* gg1-2.c */
extern const uint8 fmtn_hpos_orig[];
extern fmtn_hpos_t fmtn_hpos;

// object status structure... 2 bytes per element.
extern sprt_mctl_obj_t sprt_mctl_objs[];


/* gg1-2_1700.c */
extern sprt_regs_t mrw_sprite;
extern uint8 b_92A4_rockt_attribute[];
extern uint8 b_92C0_0[];
extern bmbr_boss_slot_t bmbr_boss_pool[];
extern r16_t bomb_hrates[];

/* gg1-3.c */
extern mctl_pool_t mctl_mpool[];
extern uint8 b_92E2_stg_parm[];
extern uint8 b_bugs_actv_nbr;
extern uint8 stg_chllg_rnd_attrib[];

/* new_stage.c */
extern uint8 ds_new_stage_parms[];


/*
 * function prototypes
 */

/* galag.c */
int _updatescreen(int);
void c_io_cmd_wait(void);

/* gg1-3.c */
void gctl_stg_new_etypes_init(void);
void gctl_stg_new_atk_wavs_init(void);

/* game_ctrl.c */
uint16 c_text_out_i_to_d(uint16, uint16);
void c_sctrl_sprite_ram_clr(void);

/* task_man.c */
void cpu0_rst38(void); //
void gctl_1uphiscore_displ(void);
void c_sctrl_playfld_clr(void);
void stg_init_splash(void);

/* gg1-2.c */
void gctl_stg_tokens(uint8);
void g_taskman_init(void);
void sprite_tiles_display(uint8 const *);
void fghtr_onscreen(void);
void gctl_plyr_respawn_fghtr(void);
void gctl_stg_fmtn_hpos_init(uint8);
void g_mssl_init(void);
void c_tdelay_3(void);
void bmbr_setup_fltq_boss(uint8, uint16);
void bmbr_setup_fltq_drone(uint8, uint16);
void c_player_active_switch(void);
void fghtr_resv_draw(void);

/* gg1-5.c */
void cpu1_rst38(void); //

/* gg1-7.c */
void cpu2_init(void); //
void cpu2_NMI(void); //

/* pe_string.c */
void c_string_out(uint16, uint8);
uint16 j_string_out_pe(uint8, uint16, uint8);

/* new_stage.c */
void stg_bombr_setparms(void);


#endif // _GALAG_H_

