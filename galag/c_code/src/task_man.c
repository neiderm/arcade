/*******************************************************************************
 **  galag: precise re-implementation of a popular space shoot-em-up
 **  task_man.s (gg1-1.3p)
 **
 **  The "task manager" is triggered by the v-blank interrupt (RST 38)
 **  thus the base execution rate is 60Hz. Some tasks will implement
 **  their own sub-rates (e.g. 1 Hz, 4 Hz etc) by checking a global timer.
 **
 **  ds_cpu0_task_activ ($20 bytes) is indexed by order of the
 **  function pointers in d_cpu0_task_table. Periodic tasks can be prioritized,
 **  enabled and disabled by changing the appropriate index in the table.
 **  The task enable table is accessed globally allowing one task to enable or
 **  disable another task. At startup, actv_task_tbl ($20 bytes) is loaded with
 **  a default configuration from ROM.
 **
 **  In ds_cpu0_task_activ the following values are used:
 **   $00 - will skip first entry ($0873) but continue with second
 **   $01
 **   $1f - execute first then skip to last? (but it sets to $00 again?)
 **   $20 - will execute $0873 (empty task) then immediately exit scheduler
 **
 *******************************************************************************/
/*
 ** header file includes
 */
#include <string.h> // memset
#include "galag.h"
#include "task_man.h"

/*
 ** defines and typedefs
 */

/*
 ** extern declarations of variables defined in other files
 */

/*
 ** non-static external definitions this file or others
 */
t_plyr_state plyr_actv;
t_plyr_state plyr_susp;
uint8 task_actv_tbl_0[32]; // active plyr task tbl cpu0
uint8 task_resv_tbl_0[32]; // suspended plyr task tbl cpu0
uint8 ds4_game_tmrs[4];
uint16 w_bug_flying_hit_cnt;


/*
 ** static external definitions in this file
 */

// variables
static uint8 d_str20000[];
static uint8 d_strSCORE[];

// function prototypes
static void stg_init_env();


/**********************************************************************
;; d_cpu0_task_table
;;  Description:
;;   jump table for functions called by task manager.
;;   32 entries
 **********************************************************************/
void (* const d_cpu0_task_table[]) (void) =
{
    f_0827,
    f_0828,
    f_17B2,
    f_1700,
    f_1A80,
    f_0857,
    f_0827,
    f_0827,

    f_2916,
    f_1DE6,
    f_2A90,
    f_1DB3,
    f_23DD,
    f_1EA4,
    f_1D32,
    f_0935,

    f_1B65,
    f_19B2,
    f_1D76,
    f_0827,
    f_1F85,
    f_1F04,
    f_0827,
    f_1DD2,

    f_2222,
    f_21CB,
    f_0827,
    f_0827,
    f_20F2,
    f_2000,
    f_0827,
    f_0977
};

// helper macro for table size
#define SZ_TASK_TBL  sizeof(d_cpu0_task_table) / sizeof(void *)

/*=============================================================================*/
// string "1UP    HIGH SCORE"  (reversed)
static const uint8 d_str1UPHIGHSCORE[] =
{
    0x0E, 0x1B, 0x18, 0x0C, 0x1C, 0x24, 0x11, 0x10, 0x12, 0x11, 0x24, 0x24, 0x24, 0x24, 0x19, 0x1E, 0x01
};

/*=============================================================================
;; gctl_1uphiscore_displ()
;;  Description:
;;   display score text top of screen (1 time only in runtime init)
;; IN:
;;  ...
;; OUT:
;;  ...
-----------------------------------------------------------------------------*/
void gctl_1uphiscore_displ(void)
{
    int bc;

    bc = 6; //sizeof (d_str20000 - 1)

    while (bc > 0)
    {
        m_tile_ram [ 0x03E0 + 0x0D + bc - 1 ] = d_str20000[ bc - 1 ];
        bc--;
    }

    bc = 17; //sizeof (d_str1UPHIGHSCORE) - 1

    while (bc > 0)
    {
        m_tile_ram [ 0x03C0 + 0x0B + bc - 1 ] = d_str1UPHIGHSCORE[ bc - 1 ];
        bc--;
    }
}


/*=============================================================================
;; c_sctrl_playfld_clr()
;;  Description:
;;    Clears playfield tileram (not the score and credit texts at top & bottom).
;;
;;    Tile RAM layout (color RAM is same, starting at 8400):
;;     Tile rows  0-1:   $8300 - 803F
;;     Playfield area:   $8040 - 83BF
;;     Tile rows 34-35:  $83C0 - 83FF
;;
;;     2 bytes at each end of tile rows 0,1,34,35 are not visible.
;;
;;     2 bytes |                                     | 2 bytes (not visible)
;;    ----------------------------------------------------
;;    .3DF     .3DD                              .3C2  .3C0     <- Row 0
;;    .3FF     .3FD                              .3E2  .3E0     <- Row 1
;;             .3A0-------------------------.060 .040
;;               |                             |   |
;;             .3BF-------------------------.07F .05F
;;    .01F     .01D                              .002  .000     <- Row 34
;;    .03F     .03D                              .022  .020     <- Row 35
;;
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------*/
void c_sctrl_playfld_clr(void)
{
    uint16 BC;

    for (BC = 0; BC < 0x0380; BC++)
    {
        m_tile_ram[ 0x0040 + BC ] = 0x24;
    }

    for (BC = 0; BC < 0x0380; BC++)
    {
        m_color_ram[ 0x0040 + BC ] = 0;
    }

    // HL==87bf
    // Set the color (red) of the topmost row: let the pointer in HL wrap
    // around to the top row fom where it left off from the loop above.
    memset(m_color_ram + 0x03BF, 4, 0x20);

    // HL==87df
    // Set color of 2nd row from top, again retaining pointer value from.
    // previous loop. Why $4E? I don't know but it ends up white.
    memset(m_color_ram + 0x03DF, 0x4E, 0x20);
}

/*=============================================================================
;; init_splash()
;;  Description:
;;   clears a stage (on two-player game, runs at the first turn of each player)
;;   Increments stage_ctr (and dedicated challenge stage %4 indicator)
;;   Blocks on busy-loop.
;; IN:
;;  ...
;; OUT:
;;  ...
;;   Need to return int to handle ESC
;;-----------------------------------------------------------------------------*/
void stg_init_splash(void)
{
    uint8 Cy;

    plyr_actv.stg_ct += 1;

    // determine stage count modulus ... gives 0 for challenge stage
    plyr_actv.not_chllng_stg = (plyr_actv.stg_ct + 1) & 0x03; // 0 if challenge stage

    if (0 != plyr_actv.not_chllng_stg)
    {
        uint16 HL;
        HL = j_string_out_pe(1, -1, 0x06); // string_out_pe "STAGE "

        // Print "X" of STAGE X. ...HL == $81B0
        c_text_out_i_to_d(plyr_actv.stg_ct, HL);

        // l_01AC: ; start value for wave_bonus_ctr (decremented by cpu-b when bug destroyed)
        w_bug_flying_hit_cnt = 0; // irrelevant if !challenge stage
    }
    else
    {
        // l_01A2_set_challeng_stg:
        j_string_out_pe(1, -1, 0x07); // "CHALLENGING STAGE"

        b_9AA0[0x0D] = 1; // sound-fx count/enable registers, start challenge stage

        // l_01AC: ; start value for wave_bonus_ctr (decremented by cpu-b when bug destroyed)
        w_bug_flying_hit_cnt = 8; // 8 for challenge stage (else 0 i.e. don't care)
    }

    // set the timer to synchronize finish of gctl_stg_tokens
    ds4_game_tmrs[2] = 3;

    glbls9200.glbl_enemy_enbl = 3; // 3 (begin round ... use 3 for optimization, but merely needs to be !0)

    /*
      Set Cy to inhibit sound clicks for level tokens at challenge stage.
      Argument "A" (loaded from plyr_actv.b_not_chllg_stg) not used here
      to pass to c_build_token_1 (sets b_9AA0[0x15] sound count/enable)
     */
    Cy = (0 == plyr_actv.not_chllng_stg); // 1211

    //  and  a ... if A != 0, clear Cy
    //  ex   af,af' ... Cy' == 1 if inhibit sound clicks
    gctl_stg_tokens(Cy); // A' == 0 if challenge stg, else non-zero (stage_ct + 1)

    // l_01BF:
    while (0 != ds4_game_tmrs[2])
    {
        // can't getout on ESC during part of the intro music
        if (0 != _updatescreen(1))
        {
            ; // get out
        }
    }

    stg_init_env();
}

/*=============================================================================
;; init_env()
;;  Description:
;;   Initialize new stage environment and handle rack-advance if enabled.
;;   This section is broken out so that splash screen can be skipped in demo.
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------*/
static void stg_init_env(void)
{
    uint8 B;

    ds4_game_tmrs[2] = 120;

    gctl_stg_new_etypes_init(); // intialize attack wave enemies by type
    gctl_stg_new_atk_wavs_init(); // build attack wave sequence table

    ds4_game_tmrs[0] = 2;

    gctl_stg_fmtn_hpos_init(0); // set origin coordinates of formation elements

    for (B = 0; B < 0x60; B += 2)
    {
        sprt_hit_notif[B] = 0;
    }

    task_actv_tbl_0[0x09] = 0; // f_1DE6 enemy convoy movement
    task_actv_tbl_0[0x10] = 0; // f_1B65 enemy diving attack
    task_actv_tbl_0[0x04] = 0; // f_1A80 special-bonus drones

    b_bug_flyng_hits_p_round = 0;

    plyr_actv.cboss_enable = 0; // disable demo boss capture overide
    plyr_actv.bonus_bee_launch_tmr = 0;
    plyr_actv.b_atk_wv_enbl = 0;
    plyr_actv.b_attkwv_ctr = 0;
    //b8_99B0_X3attackcfg_ct = 0;
    plyr_actv.nest_lr_flag = 0;

    plyr_actv.bonus_bee_obj_offs = 1;
    plyr_susp.bonus_bee_obj_offs = 1;
    plyr_susp.bmbr_boss_cobj = 1;

    task_actv_tbl_0[0x0B] = 1; // f_1DB3 ... Update enemy status
    task_actv_tbl_0[0x08] = 1; // f_2916 ... Launches the attack formations
    task_actv_tbl_0[0x0A] = 1; // f_2A90 ... left/right movement of collective while attack waves coming

    stg_bombr_setparms();

    // initialize 8-byte array
    for (B = 0; B < (sizeof(plyr_actv.bmbr_boss_scode) / 2); B++)
    {
        plyr_actv.bmbr_boss_scode[B * 2 + 0] = 0x01;
        plyr_actv.bmbr_boss_scode[B * 2 + 1] = 0xB5;
    }

    // if ( !RackAdvance )
    return;

//;  else handle rack advance operation
//       ld   c,#0x0B
//       ld   hl,#m_tile_ram + 0x03A0 + 0x10
//       call c_string_out                          ; erase "stage X" text"
//
//       jp   stg_init_splash                   ; start over again

}

/*=============================================================================
;; jp_Task_man()
;;  Description:
;;   handler for rst $38
;;   Updates star control registers.
;;   Executes the Scheduler.
;;   Sets IO chip for control input.
;;   The task enable table is composed of 1-byte entries corresponding to each
;;   of $20 tasks. Each cycle starts at task[0] and advances an index for each
;;   entry in the table. The increment value is actually obtained from the
;;   task_enable table entry itself, which is normally 1, but other values are
;;   also used, such as $20. The "while" logic exits at >$20, so this is used
;;   to exit the task loop without iterating through all $20 entries. The
;;   possible enable values are:
;;     $00 - disables task
;;     $01 - enables task_man
;;     $0A -
;;     $1F -   1F + 0A = $29     (where else could $0A be used?)
;;     $20 - exit current task man step after the currently executed task.
;; IN:
;;  ...
;; OUT:
;;  ...
-----------------------------------------------------------------------------*/
void cpu0_rst38(void)
{
    uint8 C = 0;

    while (C < SZ_TASK_TBL) // 32
    {
        // loop until non-zero: assumes we will find a valid entry in the table!
        while (0 == task_actv_tbl_0[C])
        {
            C++;
        }

        d_cpu0_task_table[C]();

        C += task_actv_tbl_0[C];
    }
}


/*=============================================================================*/
//  "20000" (reversed)
static uint8 d_str20000[] =
{
    0x00, 0x00, 0x00, 0x00, 0x02, 0x24
};
//  "SCORE" (reversed)
static uint8 d_strSCORE[] =
{
    0x17, 0x0A, 0x16, 0x0C, 0x18
};

/*=============================================================================
;; RESET()
;;  Description:
;;   jp here from z80 reset vector
;; IN:
;;  ...
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
void cpu0_init(void)
{
//       ld   hl,#ds10_99E0_mchn_data               ; clear $10 bytes

//       jp   jp_RAM_test (post)

}
