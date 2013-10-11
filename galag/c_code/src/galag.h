/*
 * main header file for application interface to MAME code
 */

#ifndef _BUGS_H_
#define _BUGS_H_


/*
 * types
 */
typedef char sint8;
typedef unsigned char uint8;
typedef unsigned short uint16;
typedef signed short sint16;
typedef unsigned int uint32;

// mchn cfg dipswitches

typedef struct {
    uint8 bonus[2];
    uint8 nships;
    uint8 cab_type;
    uint8 rank;

} struct_mchn_cfg;


// 9200[0x80]
// 00-5F:
//   even-bytes, used for object-collision notification to f_1DB3 from cpu1:c_076A
//   odd-bytes are used to implement various loosely related global flags and
//   states... so a separate structure is created to try to clear things up.

typedef struct {
    uint8 game_state; //               01
    uint8 demo_idx; //                 03
    //uint8 b8_demo_scrn_txt_indx; //  05
    uint8 training_mode_flag_07; //    07
    uint8 training_mode_flag_09; //    09
    uint8 flying_bug_attck_condtn; //  0B
    uint8 bug_nest_direction_lr; //    0F: 1:left, 0:right
    uint8 formatn_mv_signage; //       11: sign of formation pulse movement for snd mgr
    uint8 restart_stage; //            13: "end of attack" (all attackers go home)
    uint8 flip_screen; //              15:  0 ...not_flipped
} tstruct_b9200;

typedef struct {
    uint8 num_ships; // mchn_cfg_nships
    uint8 stage_ctr;
    uint8 *p_atkwav_tbl; // &8920[n] (see 2896)
    uint8 nest_lr_flag; // 1 or 0 .. flag to f_2A90, if 1 signifies nest left/right movement should stop
    uint8 not_chllng_stg; // stg_ctr+1%4 (0 if challenge stage)
    uint8 b_attkwv_ctr;
    uint8 plyr_is_2ship; // 1 ...player is two-ship
    uint8 captur_boss_obj_offs; // both ships joined .... offset from 8800[] for active capturing boss
    //   0x09    ; set by cpu-b as capturing boss starts dive  (910D?)
    //   0x0A    ; related to ship-capture status
    uint8 captur_boss_dive_flag; // 1 == capturing boss initiates his dive
    uint8 captur_boss_enable; // only enable every other boss for capture
    uint8 bonus_bee_obj_offs; // offset of object that spawns the bonus bee
    //   0x0E    ; bonus "bee"... flashing color 'A' for bonus bee
    //   0x0F    ; bonus "bee"... flashing color 'B' for bonus bee
    uint8 pbm[0x10]; // array of pointers? ... 8 bytes, "01B501B501B501B5"
    //   0x18-0x1D ?
    uint8 mcfg_bonus0; // mach_cfg_bonus[0]...load at game start ... $9980
    //   0x1F    ; game_tmr_2, player1/2 switch
    uint8 p1or2; // 0==plyr1, 1==plyr2
    uint8 bonus_bee_launch_tmr;
    uint8 b_atk_wv_enbl; // 0 when respawning player ship
    uint8 b_nbugs; // b_bugs_actv_nbr
    //   0x24    ; total_hits
    //   0x26    ; shots_fired
    //   0x28    ; 9AA0[0] ... sound_mgr_status, player1/2 switch

} t_struct_plyr_state;

/*
 * Use this in the reg16 definition below.
 * This one can be used on its own if word access is not required, which
 * would clean up the notation a little bit.
 */
typedef struct struct_pair {
#ifdef LSB_FIRST
    uint8 b0;
    uint8 b1;
#else
    uint8 b1;
    uint8 b0;
#endif
} t_bpair;

/*
 * Use this for byte or word access to 16-bit registers.
 */
typedef union {
    uint16 word;
    t_bpair pair;
} reg16;

/*
 * sprite buffer sizes are doubled, which wastes a little memory but it means
 * that it is not necessary to convert from byte-indexing to t_bpair indexing.
 */
typedef struct struct_mrw_sprite {

    // offset[0]: tile code
    // offset[1]: color map code
    t_bpair cclr[0x80];

    // offset[0]: sx
    // offset[1]: sy, bits 0:7 ... see sprite control offset[1]:0
    t_bpair posn[0x80];

    // offset[0]
    //  0: flipx - flip about the X axis, i.e. "up/down"
    //  1: flipy - flip about the Y axis, i.e. "left/right"
    //  2: dblh - MAME may not do dblh unless dblw is also set... (this may not be true)
    //  3: dblw
    // offset[1]
    //  0: sy, bit-8 ... i.e.  sx += offset[1] & 1 * 0x100
    //  1: enable
    t_bpair ctrl[0x80];

} t_mrw_sprite;

/*
 * "hardware" registers that are implemented in memory that is mapped to
 * areas which are managed by memory and IO handlers in the MAME engine.
 */
extern unsigned char *spriteram;
extern unsigned char *spriteram_2;
extern unsigned char *spriteram_3;

extern unsigned char *videoram;
extern unsigned char *colorram;

#define  m_tile_ram  videoram
#define  m_color_ram colorram

extern t_mrw_sprite mrw_sprite;

extern unsigned char *galaga_starcontrol;
#define  sfr_A000_starctl galaga_starcontrol


// indices for some sprite objects (using rw_sprite type)
#define SPR_IDX_SHIP (0x62)
#define SPR_IDX_RCKT (0x64)
#define SPR_IDX_RCKT0 (SPR_IDX_RCKT)
#define SPR_IDX_RCKT1 (SPR_IDX_RCKT + sizeof(t_bpair))



// Object status structure... 2 bytes per element.
// Order is common to sprite buffer and register banks.

typedef struct object_status {
    uint8 state; //   [ 0 + n ] : object state
    uint8 obj_idx; // [ 1 + n ] : offset into 9100[] .. see 2980... 0x10(ix),a links back to the object offset in 8800
} struct_obj_status;


// array of object movement structures, also temp variables and such.
//  00-07 writes to 92E0, see _2636
//  08-09 ptr to data in cpu-sub-1:4B
//  0D + *(ds_9820_actv_plyr_state + 0x09)
//  10 index/offset of object .... i.e. 8800 etc.
//  11 + offset
//  13 + offset

typedef struct struct_bug_flying_status {
    uint8 b00;
    uint8 b01;
    uint8 b02;
    uint8 b03;
    uint8 b04;
    uint8 b05;
    uint8 b06;
    uint8 b07;
    uint8 const *p08; // flight pattern data table pointer
    uint8 b09; // unused
    uint8 b0A;
    uint8 b0B;
    uint8 b0C;
    uint8 b0D;
    uint8 b0E;
    uint8 b0F;
    uint8 b10;
    uint8 b11;
    uint8 b12;
    uint8 b13;
} t_bug_flying_status;


// lut for setting pointer to flight pattern tables in bug flying queue

typedef struct struct_flite_ptn_cfg {
    uint8 const *p_tbl;
    uint8 idx;
} t_flite_ptn_cfg;



/*
 * extern declarations
 */

/* bugs.c */
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
extern uint8 ds_99B9_star_ctrl[6];
extern uint8 io_input[3];
extern uint8 ds_bug_collsn[0x10];

/* task_man.c */
extern t_struct_plyr_state plyr_state_actv;
extern t_struct_plyr_state plyr_state_susp;
extern uint8 task_actv_tbl_0[32];
extern uint8 task_resv_tbl_0[32];
extern uint8 ds4_game_tmrs[4];
extern uint16 w_bug_flying_hit_cnt;

/* gg1-4.c */
extern struct_mchn_cfg mchn_cfg;

/* gg1-5.c */
// most or all of these data tables need to be referenced by code in cpu0
extern const uint8 dbx001D[];
extern const uint8 dbx0067[];
extern const uint8 dbx009F[];
extern const uint8 dbx00D4[];
extern const uint8 dbx017B[];
extern const uint8 dbx01B0[];
extern const uint8 dbx01E8[];
extern const uint8 dbx01F5[];
extern const uint8 dbx020B[];
extern const uint8 dbx021B[];
extern const uint8 dbx022B[];
extern const uint8 dbx0241[];
extern const uint8 dbx025D[];
extern const uint8 dbx0279[];
extern const uint8 dbx029E[];
extern const uint8 dbx02BA[];
extern const uint8 dbx02D9[];
extern const uint8 dbx02FB[];
extern const uint8 dbx031D[];
extern const uint8 dbx0333[];
extern const uint8 dbx034F[];
extern const uint8 dbx03A9[];
extern const uint8 dbx0FDA[];
extern const uint8 dbx0FF0[];
extern const uint8 dbx022B[];
extern const uint8 dbx025D[];
extern uint8 ds3_92A0_frame_cts[3];
extern uint8 cpu1_task_en[8];
extern uint8 b_bugs_flying_nbr;
extern const uint8 db_obj_home_posn_RC[];
extern uint8 b_9200_obj_collsn_notif[]; // only even-bytes used (uint16?)

/* gg1-7.c */
extern uint8 b_9AA0[0x0020];
extern uint8 b_9A70[0x0010];

/* gg1-2.c */

// combined structure for home position locations
// only 16 bytes are needed in each array, but by using even-bytes and allocating
// 32 bytes, the indexing can be retained while still having separate elements for rel and abs

typedef struct {
    uint8 rel;
    uint8 abs;
} struct_home_posn;

extern struct_home_posn ds_home_posn_loc[];

extern reg16 ds_home_posn_org[];


// object status structure... 2 bytes per element.
extern struct_obj_status b8800_obj_status[];


/* gg1-2_1700.c */
extern uint8 b_92A4_rockt_attribute[];
extern uint8 b_92C0_0[]; // idfk ...  (size <= 10)
extern uint8 b_92C0_A[]; // machine cfg params?

/* gg1-3.c */
extern t_bug_flying_status ds_bug_motion_que[];
extern uint8 b_92E2_stg_parm[2];
extern uint8 b_bugs_actv_nbr;
extern uint8 stg_chllg_rnd_attrib[];

/* new_stage.c */
extern uint8 ds_new_stage_parms[];


/*
 * function prototypes
 */

/* bugs.c*/
int _updatescreen(int);
void c_io_cmd_wait(void);

/* gg1-3.c */
void c_2896(void);
void c_25A2(void);

/* gg1-5.c */
void cpu1_init(void);

/* gg1-4.c */
void cpu0_init(void);
void svc_test_mgr(void);

/* game_ctrl.c */
void j_Game_init(void);
int j_Game_start(void);
int game_state_ready(void);
int game_mode_start(void);
int game_runner(void);
uint16 c_text_out_i_to_d(uint16, uint16);
void c_sctrl_sprite_ram_clr(void);

/* task_man.c */
void cpu0_rst38(void);
void c_textout_1uphighscore_onetime(void);
void c_sctrl_playfld_clr(void);
void c_new_stg_game_only(void);

/* gg1-2.c */
void c_new_level_tokens(uint8);
void c_1230_init_taskman_structs(void);
void sprite_tiles_display(uint8 const *);
void c_133A_show_ship(void);
void c_player_respawn(void);
void c_12C3(uint8);
void c_game_or_demo_init(void);
void c_tdelay_3(void);
void c_1079(uint8, uint8 const *);
void c_1083(uint8, uint8 const *);

/* gg1-5.c */
void cpu1_init(void);
void cpu1_rst38(void);

/* gg1-7.c */
void cpu2_init(void);
void cpu2_NMI(void);

/* pe_string.c */
void c_string_out(uint16, uint8);
uint16 j_string_out_pe(uint8, uint16, uint8);

/* new_stage.c */
void c_2C00_new_stg_setup(void);

enum {
    GAME_ENDED = 0,
    ATTRACT_MODE = 1,
    READY_TO_PLAY_MODE = 2,
    IN_GAME_MODE = 3
};


#endif // _BUGS_H_

