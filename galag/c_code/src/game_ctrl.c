/*******************************************************************************
 **  galag: precise re-implementation of a popular space shoot-em-up
 **  game_ctrl.s (gg1-1.3p)
 **    Startup functions for game following low-level inits.
 **    Entry into "main" and background task (superloop)
 **
 *******************************************************************************/

/*
 ** header file includes
 */
#include <string.h> // malloc
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
uint8 ds_bug_collsn[0x10];

uint8 b_bug_flyng_hits_p_round; // _handle_end_challeng_stg
uint8 ds_99B9_star_ctrl[6]; // 1 when ship on screen

uint8 io_input[3]; // TODO: owned by galag.c

tstruct_b9200 glbls9200;



/*
 ** static external definitions in this file
 */
// variables

//static uint8 sfr_A000[6]; // galaga_starcontrol
static uint8 sfr_A007; // flip_screen_port=0 (not_flipped) ... (unimplemented in MAME?)
static uint8 sfr_6820; //galaga_interrupt_enable_1_w
static uint8 gctl_two_plyr_game;
static uint8 gctl_credit_cnt;
//static uint8 ds30_susp_plyr_obj_data[0x30]; // c_player_active_switch

// forward declarations
static const uint8 gctl_bonus_fightr_tiles[][4];
static const uint8 gctl_score_initd[];
static const uint8 gctl_str_1up[];
static const uint8 gctl_str_2up[];
static const uint8 gctl_str_000[];
static const uint8 gctl_point_fctrs[];
static const uint8 gctl_bmbr_enbl_tmrdat[][4];

// function prototypes
static void gctl_plyr_init(void);
static void gctl_score_init(uint8, uint16);
static void gctl_bonus_info_line_disp(uint8, uint8, uint8);
static void gctl_plyr_respawn_wait(void);
static void gctl_1up2up_displ(uint8);
static void gctl_fghtr_rdy(void);
static void gctl_1up2up_blink(uint8 const *, uint16, uint8);
static void gctl_score_upd(void);
static void gctl_score_digit_incr(uint16, uint8);
static void gctl_bg_stg_restart_supv();
static void gctl_chllng_stg_end(void);
static uint8 gctl_bmbr_enbl_tmrs_set(uint8, uint8, uint8);


/*=============================================================================
;; c_sctrl_sprite_ram_clr()
;;  Description:
;;   Initialize screen control registers.
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------*/
void c_sctrl_sprite_ram_clr(void)
{
    // arrays use only even indexed elements in order to keep the indexing
    // consistent with z80.

    memset((uint8 *) mrw_sprite.posn, 0, 0x80 * sizeof (t_bpair));
    memset((uint8 *) mrw_sprite.ctrl, 0, 0x80 * sizeof (t_bpair));

    memset((uint8 *) sprt_mctl_objs, 0x80, sizeof (sprt_mctl_obj_t) * 0x80);
}

/*=============================================================================
;; gctl_runtime_init()
;;  Description:
;;   Once per machine-reset following hardware initialization.
;;   Put screen and other significant memory structures into known state prior
;;   to executing into "main function".
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------*/
void gctl_runtime_init(void)
{
    // ld   sp,#stk_cpu0_init

    memset(ds4_game_tmrs, 0, 4);

    // count/enable registers for sound effects
    memset(b_9AA0, 0, 0x20);

    sfr_A007 = 0; // flip_screen_port (not_flipped) ...unimplemented in MAME?
    glbls9200.flip_screen = 0; // not_flipped

    ds_99B9_star_ctrl[0] = 0; // 1 when ship on screen

    // queue for boss+wing mission is only $0C bytes, so this initialization
    // would include b_CPU1_in_progress + b_CPU2_in_progress + 2 unused bytes
    memset(b_92C0_A, 0xff, 0x10);

    // galaga_interrupt_enable_1_w  seems to already be set, but we make sure anyway.
    sfr_6820 = 1; // (enable IRQ1)

    /*
     The test grid is now cleared from screen. Due to odd organization of tile ram
     it is done in 3 steps. 1 grid row is cleared from top and bottom (each grid
     row is 2 tile rows). Then, there is a utility function to clear the actual
     playfield area.
     */
    memset(m_tile_ram + 0x03c0, 0x24, 0x40); // clear top 2 tile rows ($40 bytes)

    memset(m_tile_ram + 0x0000, 0x24, 0x40); // clear bottom 2 tile rows ($40 bytes)

    memset(m_color_ram + 0x0000, 0x03, 0x40);

    // clear remainder of grid pattern from the playfield tiles (14x16)
    c_sctrl_playfld_clr();

    // all tile ram is now wiped


    // Sets up "Heroes" screen


    glbls9200.game_state = ATTRACT_MODE; // initialize game state

    // star_ctrl_port_bit6 -> 0, then 1
    sfr_A000_starctl[5] = 0;
    sfr_A000_starctl[5] = 1;

    c_sctrl_sprite_ram_clr();

    // display 1UP HIGH SCORE 20000 (1 time only after boot)
    gctl_1uphiscore_displ();

    c_1230_init_taskman_structs();

    // data structures for 12 objects
    memset(mctl_mpool, 0, sizeof (mctl_pool_t) * 0x0C);

    /*
    ; Not sure here...
    ; this would have the effect of disabling/skipping the task at 0x1F (f_0977)
    ; which happens to relate to updating the credit count (although, there is no
    ; RST 38 to actually trigger the task from now until setting this to 0 below.)
     */
    task_actv_tbl_0[0x1E] = 0x20;

    gctl_credit_cnt = io_input[0];

    task_actv_tbl_0[0x1E] = 0; // just wrote $20 here see above

    cpu1_task_en[0] = 0; // disables f_05BE in CPU-sub1 (empty task)
}

/*=============================================================================
;; gctl_main()
;;  Description:
;;    Initialization, and one-time check for credits (monitoring credit count
;;    and updating "GameState" is otherwise handled by a 16mS task). If credits
;;    available at startup, updates "GameState" and skips directly to Ready
;;    mode, otherwise stays in Attract mode.
;;
;;    When all fighters are destroyed, jp's back to gctl_main.
;;
;;    A bug in z80 code, credit count remains on-screen for a short time after
;;    P1/P2 start button hit ... count is updated but displayed credit not refreshed.
;;
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------*/
int gctl_main(void)
{
    sfr_A007 = 0; // flip_screen_port (not_flipped) ...unimplemented in MAME?
    glbls9200.flip_screen = 0; // not_flipped

    // disable f_1D76 - star control ... why? ... should be taken care of by init_taskman_structs ...below
    task_actv_tbl_0[0x12] = 0; // disable f_1D76

    // glbls9200? the object-collision notification structures are cleared
    // at every beginning of round, so I am guessing the intent here is to
    // clear the globals that share the $80 byte block ... it is implemented as
    // a struct so use a union of byte?
    //memset(b_9200, 0, 0x80);

    ds_99B9_star_ctrl[5] = 6; // ?

    // array of object movement structures, also temp variables and such.
    memset(mctl_mpool, 0, sizeof (mctl_pool_t) * 0x0C /* 0xF0 */);

    c_sctrl_sprite_ram_clr();
    c_1230_init_taskman_structs();

    // allow attract-mode festivities to be skipped if credit available
    if (gctl_credit_cnt == 0)
    {
        glbls9200.game_state = ATTRACT_MODE;

        // do attract mode stuff
        glbls9200.demo_idx = 0;
        task_actv_tbl_0[2] = 1; // f_17B2 (control demo mode)

        // l_038D_While_Attract_Mode
        while (glbls9200.game_state == ATTRACT_MODE)
        {
            if (0 != _updatescreen(1)) // 1 == blocking wait for vblank
            {
                return 1;
            }
        }

        // GameState == Ready ... reinitialize everything
        c_1230_init_taskman_structs();
        c_sctrl_playfld_clr();
        memset(mctl_mpool, 0, sizeof (mctl_pool_t) * 0x0C /* 0xF0 */);
        c_sctrl_sprite_ram_clr();

        // game_state == READY
    }
    else
    {
        glbls9200.game_state = READY_TO_PLAY_MODE;
    }

    // l_game_state_ready:

    glbls9200.flying_bug_attck_condtn = 0; // 1 at demo mode, 3 at game start, and now 0

    j_string_out_pe(1, -1, 0x13); // "(c) 1981 NAMCO LTD"
    j_string_out_pe(1, -1, 1); // "PUSH START BUTTON"

    if (0xFF != mchn_cfg.bonus[0]) // ... else l_While_Ready
    {
        // ld   (p_attrmode_sptiles),hl ... not necessary to keep persistent pointer for function paramter

        // E=bonus score digit, C=string_out_pe_index
        gctl_bonus_info_line_disp(mchn_cfg.bonus[0], 0x1B, 0);

        if (0xFF != mchn_cfg.bonus[1]) // ... else l_While_Ready
        {
            gctl_bonus_info_line_disp(mchn_cfg.bonus[1] & 0x7F, 0x1C, 1);

            // if bit 7 is set, the third bonus award does not apply
            if (0 == (0x80 & mchn_cfg.bonus[1])) // goto l_While_Ready
            {
                gctl_bonus_info_line_disp(mchn_cfg.bonus[1] & 0x7F, 0x1D, 2);
            }
        }
    }

    // l_While_Ready:
    while (READY_TO_PLAY_MODE == glbls9200.game_state)
    {
        if (0 != _updatescreen(1)) // 1 == blocking wait for vblank
        {
            return 1;
        }
    }

    // start button was hit

    // sound_mgr_reset: non-zero causes re-initialization of CPU-sub2 process
    b_9AA0[0x17] = glbls9200.game_state;

    // clear sprite mem etc.
    c_sctrl_playfld_clr();
    c_sctrl_sprite_ram_clr();

    // stars paused
    sfr_A000_starctl[5] = 0; // doesn't do anything ;)
    sfr_A000_starctl[5] = 1;

    // Not sure about the intent of clearing $A0 bytes.. player data and resv data are only $80 bytes.
    // The structure at 98B0 is $30 bytes so it would not all be cleared (only $10 bytes)

    // memset( player_data, 0, $a0 )

    b_9AA0[0x17] = 0; // enable CPU-sub2 process
    ds_99B9_star_ctrl[0] = 0; // star ctrl stop (1 when ship on screen)
    b_9AA0[0x0B] = 1; // sound-fx count/enable, start of game theme
    task_actv_tbl_0[0x12] = 1; // f_1D76, star ctrl
    task_resv_tbl_0[0x12] = 1; // f_1D76, star ctrl

    // do one-time inits
    gctl_plyr_init(); // setup number of lives and scores
    c_game_or_demo_init();

    j_string_out_pe(1, -1, 4); //  "PLAYER 1" (always starts with P1 no matter what!)

    // busy loop -leaves "Player 1" text showing while some of the opening theme music plays out
    ds4_game_tmrs[3] = 8;
    while (ds4_game_tmrs[3] > 0)
    {
        if (0 != _updatescreen(1)) // 1 == blocking wait for vblank
        {
            return 1;
        }
    }

    memset(ds_bug_collsn, 0, 0x10);
    //memset(ds30_susp_plyr_obj_data, 0, 0x30);

    c_string_out(0x03B0, 0x0B); // erase PLAYER 1 text

    plyr_state_susp.p1or2 = 1; // 1==plyr2
    plyr_state_actv.mcfg_bonus0 = mchn_cfg.bonus[0];
    plyr_state_susp.mcfg_bonus0 = mchn_cfg.bonus[0];

    // jp   gctl_plyr_start_stg_init

    return 0;
}

/*=============================================================================
 gctl_bonus_info_line_disp()
  Description:
   coinup... displays each line of "1st BONUS, 2ND BONUS, AND FOR EVERY".
   Successive calls to this are made depending upon machine config, e.g.
  'XXX BONUS FOR XXXXXX PTS'
  'AND FOR EVERY XXXXXX PTS'
 IN:
  C = string_out_pe_index
  E = first digit of score i.e. X of Xxxxx.
  pHL = pointer to sprite data to display
 OUT:
  ...
-----------------------------------------------------------------------------*/
static void gctl_bonus_info_line_disp(uint8 E, uint8 C, uint8 idx)
{
    uint16 HL;
    uint16 DE;

    // note: tile RAM address would be 8XXX but this only returns the offset.
    HL = j_string_out_pe(1, 0, C);

    // set next position to append 'X0000 PTS'
    DE = HL + 0x40;

    // HL contains number to display, returns updated destination in DE
    HL = c_text_out_i_to_d(E, DE);

    c_string_out(HL, 0x1E); // draw 0's

    sprite_tiles_display(&gctl_bonus_fightr_tiles[idx][0]); // show the fighter sprite
    return;
}


/*=============================================================================
;;  attributes for ship-sprites in bonus info screen ... 4-bytes each:
;;  0: offset/index of object to use
;;  1: color/code
;;      ccode<3:6>==code
;;      ccode<0:2,7>==color
;;  2: X coordinate
;;  3: Y coordinate
 */
static const uint8 gctl_bonus_fightr_tiles[][4] =
{
    {0x00, 0x81, 0x19, 0x56},
    {0x02, 0x81, 0x19, 0x62},
    {0x04, 0x81, 0x19, 0x6E}
};

/*=============================================================================
;; gctl_game_runner()
;;  Description:
;;   background superloop following game-start
;; IN:
;;  ...
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
void gctl_game_runner(void)
{
    while (1) // jr   l_045E_while_play_game
    {
        gctl_score_upd();
        gctl_bg_stg_restart_supv();

        // I don't remember what actually causes the game to recycle, but
        // here we  allow an escape from the superloop
        if (0 != _updatescreen(1)) // 1 == blocking wait for vblank
        {
            break;
        }
    }
}

/*=============================================================================
;; gctl_plyr_init()
;;  Description:
;;   Initialize player score and nbr fighters after start button hit.
;;   "2UP" redrawn later.
;; IN:
;;  ...
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
static void gctl_plyr_init(void)
{
    uint8 A, HL;
    uint16 DE;

    // get nbr of ships from machine config
    A = 3; // tmp ...    ld   a,(b8_mchn_cfg_nships)
    plyr_state_actv.num_ships = A;
    plyr_state_susp.num_ships = A;

    DE = 0x03E0 + 0x18; // player 1 score, right tile of "00"
    HL = 0;
    gctl_score_init(HL, DE);

    DE = 0x03E0 + 0x03; // player 2 score
    HL = 0;

    if (!gctl_two_plyr_game)
    {
        // advance src pointer past "00" to erase player 2 score (start of spaces)
        HL = 2;
    }

    gctl_score_init(HL, DE);

    return;
}

/*=============================================================================
;; gctl_score_init
;;  Description:
;;   we saved 4 bytes of code space by factoring out the part that copies 7
;;   characters. Then we wasted about 50 uSec by repeating the erase 2UP
;; IN:
;;  HL: initial offset 0 or 2 into gctl_score_initd[]
;;  DE: dest pointer (offset)
;; OUT:
;;
;;---------------------------------------------------------------------------*/
static void gctl_score_init(uint8 HL, uint16 DE)
{
    uint8 C;

    for (C = 0; C < 7; C++)
    {
        m_tile_ram[DE + C] = gctl_score_initd[HL + C];
    }

    for (C = 0; C < 4; C++)
    {
        m_tile_ram[0x03C0 + 3 + C] = gctl_score_initd[2 + C];
    }

    return;
}


/*===========================================================================*/
// init data for score display ... "00" and space characters
static const uint8 gctl_score_initd[] =
{
    0x00, 0x00,
    0x24, 0x24, 0x24, 0x24, 0x24, 0x24, 0x24
};
/*---------------------------------------------------------------------------*/


/*=============================================================================
;;
;; jp (ret) to jp_045E_gctl_game_runner
;; jp (ret) j_0632_gctl_fghtr_rdy
;;    j_0632_gctl_fghtr_rdy
;;       jp_045E_gctl_game_runner
;;===========================================================================*/
void gctl_stg_restart_hdlr(void)
{
    // set a time to wait while ship exploding
    ds4_game_tmrs[3] = 4;

    // l_04A4_do_wait_explosion_tmr:
    do
    {
        // if ( captured_ship_landing ) ...

        _updatescreen(1); // todo: check retval for ESC key

        // l_04C1_while_wait_explosion_tmr:
    }
    while (ds4_game_tmrs[3] > 0);

    gctl_score_upd();

    // count of remaining aggressors according to object state dispatcher
    plyr_state_actv.b_nbugs = b_bugs_actv_nbr;

    // check for "not (normal) end of stage conditions":

    // if ( restart stage flag || bugs_actv_nbr>0 ) {{
    //   jr   nz,l_04E2_terminate_or_gameover
    if (0 == plyr_state_actv.not_chllng_stg)
    {
        // jp's back to 04DC_new_stage_setup
        gctl_chllng_stg_end();
    }

    //j_04DC_new_stage_setup

    // end of stage ... "normal"
    gctl_stg_splash_scrn();

    // jp   j_0632_gctl_fghtr_rdy         ; jp   jp_045E_gctl_game_runner
    gctl_fghtr_rdy();
    // jp   jp_045E_gctl_game_runner
}

/*=============================================================================
; Prepare "respawn" for 1 player game.
; If the terminated ship was crashed by the last bug of the stage, then new
; stage setup needs done.
; Out of term_actv_plyr (if not 2p game)
;;--------------------------------------------------------------------------- */
void gctl_plyr_respawn_1P(void)
{
    if (0 == plyr_state_actv.b_nbugs ) gctl_stg_splash_scrn();

    gctl_plyr_respawn_wait();
}

/*=============================================================================
;;  gctl_plyr_start_stg_init
;;  Description:
;;   Player entry/changeover with new stage setup, e.g. beginning of game for
;;   for P1 (or P2 on multiplayer game) ... multiplayer game introduces the
;;   possibility of either player re-entering the game with 0 enemy count due
;;   to termination of last enemy of a stage by destruction of the fighter.
;;   If on a new game, PLAYER 1 text has been erased.
;;
;;--------------------------------------------------------------------------- */
void gctl_plyr_start_stg_init(void)
{
    gctl_stg_splash_scrn(); // shows "STAGE X" and does setup

    // gctl_plyr_startup
}

/*=============================================================================
;;  gctl_plyr_startup:
;;  Description:
;;   Setup a new player... every time the player is changed on a 2P game or once
;;   at first ship of new 1P game. Shows Player 1 (2) text on stage restart.
;;   Out of "new_stage" or "plyr_changeover"
;;
;;----------------------------------------------------------------------------*/
void gctl_plyr_startup(void)
{
    // P1 text is index 4, P2 is index 5
    c_string_out(0x0260 + 0x0E, plyr_state_actv.p1or2 + 4); // PLAYER X ("1" or "2") .

    // respawn always followed by fghtr_rdy
    gctl_plyr_respawn_wait();
    gctl_fghtr_rdy();

    return;
}

/*=============================================================================
;;  gctl_plyr_respawn_wait
;;  Description:
;;   Player respawn with timing
;;
;;----------------------------------------------------------------------------*/
static void gctl_plyr_respawn_wait(void)
{
    uint8 A;

    // "credit X" is wiped and reserve ships appear on lower left of screen
    gctl_plyr_respawn_fghtr(); // there is only one reference to this so it could be inlined.

    // ds4_game_tmrs[2] was set to 120 by new_stg_game_or_demo

    A = ds4_game_tmrs[2] + 0x1E;

    // if tmr > $5A then reset to $78
    if (A >= 120)
    {
        A = 120;
    }
    ds4_game_tmrs[2] = A;

    c_tdelay_3();

    return;
    // j_0632_gctl_fghtr_rdy:
}

/*=============================================================================
;;  j_0632_gctl_fghtr_rdy
;;  Description:
;;   Out of stg_restart_hdlr or plyr_respawn
;;   Readies fighter operation active by enabling rockets and hit-detection
;;
;;----------------------------------------------------------------------------*/
static void gctl_fghtr_rdy(void)
{
    task_actv_tbl_0[0x15] = 1; // f_1F04 ...fire button input
    //ds_cpu1_task_en[0x05] = 1;  // (enable cpu1:f_05EE ... fighter hit detection)

    // attack_wave_enable
    plyr_state_actv.b_atk_wv_enbl = 1; // 0 when respawning player ship

    c_string_out(0x03B0, 0x0B); // erase "READY" or "STAGE X"

    c_string_out(0x03A0 + 0x0E, 0x0B); // erase "PLAYER 1"

    // jp   jp_045E_gctl_game_runner  ; return to Game Runner Loop
}

/*=============================================================================
;; gctl_chllng_stg_end()
;;  Description:
;;
;; IN:
;;  ...
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
static void gctl_chllng_stg_end(void)
{
    uint16 DE;
    uint8 A;

    if (40 == b_bug_flyng_hits_p_round)
    {
        // sound-fx count/enable registers, default melody for challenge stage
        b_9AA0[0x14] = 1; // ld   (hl),#1
    }
    else
    {
        // sound effect count/enable registers, "perfect!" melody, challenge stg
        b_9AA0[0x0E] = 1; // ld   (hl),#1
    }

    c_tdelay_3();

    j_string_out_pe(1, -1, 8); // "NUMBER OF HITS"

    // DE = adjusted offset into tile ram on return
    DE = c_text_out_i_to_d(b_bug_flyng_hits_p_round, 0x0100 + 0x10);

    c_tdelay_3();

    if (40 != b_bug_flyng_hits_p_round) // jr   z,l_0699_hit_all
    {
        DE = j_string_out_pe(1, -1, 9); // BONUS"

        c_tdelay_3();

        if (0 != b_bug_flyng_hits_p_round) // jr   z,l_0693_put_ones
        {
            DE = c_text_out_i_to_d(b_bug_flyng_hits_p_round, DE);
            m_tile_ram[DE] = 0; // putc(0) ... 10's place of bonus pts awarded
            DE -= 32;
        }
        // l_0693_put_ones:
        m_tile_ram[DE] = 0; // putc(0) ... 1's place of bonus pts awarded
        A = b_bug_flyng_hits_p_round; // parameter to l_06BA

        // jr   l_06BA
    }
    else
    {
        //l_0699_hit_all:
        uint8 B, C;

        B = 7;

        // blink the "PERFECT !" text
        do
        {
            while (0 != (0x0F & ds3_92A0_frame_cts[0]))
            {
                _updatescreen(1); // todo: check retval for ESC key
            }

            C = 0x0B; // index into string table (27 spaces)

            if (0 != (0x01 & B))
            {
                C = 0x0C; // index into string table "PERFECT !"
            }
            // l_06A9:
            j_string_out_pe(1, -1, C);

            while (0 == (0x0F & ds3_92A0_frame_cts[0]))
            {
                _updatescreen(1); // todo: check retval for ESC key
            }
        }
        while (--B > 0); // djnz l_069B_while_b

        j_string_out_pe(1, -1, 0x0D); // "SPECIAL BONUS 10000 PTS"

        A = 100;
    }

    // l_06BA:
    ds_bug_collsn[0x0F] += A;
    gctl_score_upd();
    c_tdelay_3();
    c_tdelay_3();

    // erase "Number of hits XX" (line below Perfect)
    c_string_out(0x03A0 + 0x10, 0x0B);

    // erase "Special Bonus 10000 Pts" (or Bonus xxxx)
    c_string_out(0x03A0 + 0x13, 0x0B);

    j_string_out_pe(1, -1, 0x0B); // erase "PERFECT !")

    // j_04DC_new_stage_setup
}

/*=============================================================================
;;  gctl_score_upd
;;  Description:
;;    Update score
;;    Red == 50
;;    Yellow == 80
;;    (x2 if flying)
;;----------------------------------------------------------------------------*/
static void gctl_score_upd(void)
{
    reg16 AF;
    uint8 A, B, C, E, L, IXL;

    IXL = 0xF9;
    if (0 != plyr_state_actv.p1or2)
    {
        IXL = 0xE4;
    }

    // l_0732:

    B = 16; // ld   b,#0x10 ... sizeof(gctl_point_fctrs)
    L = 0; // ld   hl,#ds_bug_collsn + 0x00

    // l_0739_while_B
    while (B > 0)
    {
        // ex   de,hl ... stash HL

        C = gctl_point_fctrs[ B - 1 ]; // ld   hl,#gctl_point_fctrs - 1

        // l_0740
        while (0 != ds_bug_collsn[L]) // jr   z,l_0762
        {
            //if ( 0 != ds_bug_collsn[L] )
            ds_bug_collsn[L] -= 1; // dec  (hl)

            A = C & 0x0F; // and  #0x0F
            gctl_score_digit_incr(0x0300 + IXL, A);

            A = (C >> 4) & 0x0F; // rlca * 4
            gctl_score_digit_incr(0x0300 + IXL + 1, A);

            // jr   l_0740
        }

        // l_0762:
        L += 1; //inc  l
        B -= 1; // djnz l_0739_while_B
    }

    // not sure what happens after this

    // l_078E:
    E = IXL + 4;

    // ld   hl,#m_tile_ram + 0x03E0 + 0x12        ; 100000's digit of HIGH SCORE (83ED-83F2)
    L = 0x12;
    // ld   d,#>(m_tile_ram + 0x0300)
    E = 0;
    B = 6;
    // l_0771:
    while (B > 0)
    {
        A = m_tile_ram[ 0x0300 + E ]; // ld   a,(de)
        A -= m_tile_ram[ 0x03E0 + L ]; // sub  (hl)
        A += 9;

        if (A < 0xE5) // jr   nc,l_0788
        {
            A -= 0x0A;

            if (A >= 9) // jr   c,l_0788
            {
                // inc  a
                if (-1 == A)
                {
                    L -= 1; // dec  l
                    E -= 1; // dec  e
                    // djnz l_0771
                }
                else break; // jr   nz,l_078E
            }
            else
            {
                // l_0788: tick away the remaining counts on B
                while (B > 0)
                {
                    A -= m_tile_ram[ 0x03E0 + L ] = m_tile_ram[ 0x0300 + E ];
                    L -= 1; // dec  l
                    E -= 1; // dec  e
                    B -= 1; // djnz l_0788
                } // l_078E:
                break; // don't do B-- again
            }
        }
        // l_0788: tick away the remaining counts on B
        else
        {
            while (B > 0)
            {
                A -= m_tile_ram[ 0x03E0 + L ] = m_tile_ram[ 0x0300 + E ];
                L -= 1; // dec  l
                E -= 1; // dec  e
                B -= 1; // djnz l_0788
            } // l_078E:
            break; // don't do B-- again
        }

        // djnz l_0771
        B -= 1; // yes we do it here because of 0788
    }
    // jr   l_078E

    // l_078E:
    L = IXL + 4;
    AF.word = m_tile_ram[0x0300 + L];

    if (0x24 == AF.pair.b0) AF.word = 0; // xor  a

    // l_0799:
    AF.word &= 0x3F;
    AF.word <<= 1; // rlca
    C = AF.pair.b0;
    AF.word <<= 2; // rlca * 2
    AF.pair.b0 += C;
    C = AF.pair.b0;
    L -= 1;
    AF.word = m_tile_ram[0x0300 + L];

    if (0x24 == AF.pair.b0) AF.word = 0; // xor  a

    // l_07A8:
    // check if a bonus fighter to be awarded
    return; // tmp:  ... ret  nz
}

/*=============================================================================
;; gctl_score_digit_incr()
;;  Description:
;;   handle score inrement (gctl_score_upd)
;; IN:
;;  A == gctl_point_fctrs[B-1]
;;        twice on 1 update, 1st is low nibble, 2nd is high nibble
;;  HL== index into tile_ram
;; OUT:
;;  HL=
;;---------------------------------------------------------------------------*/
static void gctl_score_digit_incr(uint16 hl, uint8 a)
{
    if (0 == a)
        return;

    a += m_tile_ram[hl];

    if (a >= 0x24) // jr   c,l_07E1
    {
        a -= 0x24; // > 'Z' so subtract 'Z'
    }

    // l_07E1:
    if (a < 0x0A) // jr   nc,l_07E7
    {
        m_tile_ram[hl] = a;
        return;
    }

    // l_07E7:
    a -= 0x0A;

    // l_07E9_while_1:
    while (1) // ... you gotta love while 1's
    {
        m_tile_ram[hl] = a;

        hl += 1; // inc  l
        a = m_tile_ram[hl];

        if (0x24 == a) // 'Z'
        {
            a = 0; // xor  a ... set to 0 in case it breaks (if A == 9 )
        }

        // l_07F1:
        if (0x09 != a)
        {
            m_tile_ram[hl] = a + 1; // inc  a
            return;
        }
        a = 0; // xor  a
    } // // jr   l_07E9_while

    return; // shouldn't be here
}


/*=============================================================================
;; Base-factors of points awareded for enemy hits, applied to multiples
;; reported via _bug_collsn[]. Values are BCD-encoded, and ordered by object
;; color group, i.e. as per _bug_collsn.
;; Indexing is reversed, probably to take advantage of djnz.
;; Index $00 is a base factor of 10 for challenge-stage bonuses to which a
;; variable bonus-multiplier is applied (_bug_collsn[$0F]).
;;---------------------------------------------------------------------------*/
static const uint8 gctl_point_fctrs[] =
{
    0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x50, 0x08, 0x08, 0x08, 0x05, 0x08, 0x15, 0x00
};

/*=============================================================================
;; c_080B_monitor_stage_start_or_re()
;;  Description:
;;   supervises stage restart condition.
;;   0 enemies remaining indicates condition for new-stage start.
;;   Otherwise, 'restart_stage_flag" may indicate that the active
;;   fighter has been destroyed or captured requiring a stage re-start.
;; IN:
;;  ...
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
static void gctl_bg_stg_restart_supv(void)
{
    // f_2916 (supervises attack waves)
    if (0 == task_actv_tbl_0[0x08] && 0 == b_bugs_actv_nbr) // count of remaining aggressors according to object state dispatcher
    {
        // jr   nz,l_081B

        // cleared the round
        b_9AA0[0x00] = 0; // sound-fx count/enable registers, pulsing formation sound effect

        // jp   jp_049E_handle_stage_start_
    }
    else
    {
        // fighter destroyed or captured?
        if (0 == glbls9200.restart_stage) // 0x13, restart stage flag
        {
            return;
        }
        // probably a stage-restart is pending
        plyr_state_actv.b_atk_wv_enbl = 0;
    }

    gctl_stg_restart_hdlr();
}

/*=============================================================================
;; f_0827()
;;  Description:
;;   empty task
;; IN:
;;  ...
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
void f_0827()
{
}

/*=============================================================================
;; f_0828()
;;  Description:
;;   Copies from sprite "buffer" to sprite RAM...
;;   works in conjunction with CPU-sub1:_05BF to update sprite RAM
;;   (the entire update is done here and CPU-sub1:_05BF is not implemented)
;; IN:
;;  ...
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
void f_0828(void)
{
    uint8 B;

    for (B = 0; B < 0x80; B += 2)
    {
        *(spriteram + B + 0) = mrw_sprite.cclr[B].b0;
        *(spriteram + B + 1) = mrw_sprite.cclr[B].b1;
        *(spriteram_2 + B + 0) = mrw_sprite.posn[B].b0;
        *(spriteram_2 + B + 1) = mrw_sprite.posn[B].b1;
        *(spriteram_3 + B + 0) = mrw_sprite.ctrl[B].b0;
        *(spriteram_3 + B + 1) = mrw_sprite.ctrl[B].b1;
    }
}

/*=============================================================================
;; f_0857()
;;  Description:
;;    enable after just cleared the screen from training mode
;;    see case 0x07: // l_17F5
;; IN:
;;  ...
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
void f_0857(void)
{
    uint8 A;
    // increases allowable max_flying_bugs_this_round after a time
    if (ds4_game_tmrs[2] < 0x3C)
    {
        ds_new_stage_parms[4] = ds_new_stage_parms[5];
    }

    // l_0865: bomb drop enable flags
    // A==new_stage_parms[0], HL==gctl_bmbr_enbl_tmrdat, C==num_bugs_on_scrn
    A = gctl_bmbr_enbl_tmrs_set(ds_new_stage_parms[0], b_bugs_actv_nbr, 0);
    b_92C0_0[0x08] = A; // bomb drop enable timer loaded to bombers (0x0F)ix

    if (1) //  if (0 != b_92AA_cont_bombing_flag)
    {
        // default inits for bomber activation timers
        b_92C0_0[0x04] = 2;
        b_92C0_0[0x05] = 2;
        b_92C0_0[0x06] = 2;

        // sound-fx count/enable registers, kill pulsing sound effect
        b_9AA0[0x00] = 0;
        return;
    }

//l_0888:
A = ds_new_stage_parms[0x01];
}

/*=============================================================================
;; gctl_bmbr_enbl_tmrs_set()
;;  Description:
;;   set bomber enable timers (for f_0857)
;; IN:
;;  A == new_stage_parms[0] or [1]: selects set of 4 (indexes 0 thru 7)
;;  C == num_bugs_on_scrn
;;  L == index into gctl_bmbr_enbl_tmrdat
;; OUT:
;;  A==(hl)
;;---------------------------------------------------------------------------*/
static uint8 gctl_bmbr_enbl_tmrs_set(uint8 A, uint8 C, uint8 L)
{
    uint8 rv, idx, sel;

    idx = A * 4;
    sel = C / 10; // call c_divmod
    rv = gctl_bmbr_enbl_tmrdat[L][idx + sel];
    return rv;
}

/*---------------------------------------------------------------------------*/
static const uint8 gctl_bmbr_enbl_tmrdat[][4] ={
    { 0x03, 0x03, 0x01, 0x01},
    { 0x03, 0x03, 0x03, 0x01},
    { 0x07, 0x03, 0x03, 0x01},
    { 0x07, 0x03, 0x03, 0x03},
    { 0x07, 0x07, 0x03, 0x03},
    { 0x0F, 0x07, 0x03, 0x03},
    { 0x0F, 0x07, 0x07, 0x03},
    { 0x0F, 0x07, 0x07, 0x07},
//d_0929:
    { 0x06, 0x0A, 0x0F, 0x0F},
    { 0x04, 0x08, 0x0D, 0x0D},
    { 0x04, 0x06, 0x0A, 0x0A}
};

/*=============================================================================
;; f_0935()
;;  Description:
;;    handle "blink" of Player1/Player2 texts.
;;    Toggles the "UP" text on multiples of 16 frame counts.
;;    With frame counter being about 60hz, we should get a blink of
;;    about twice per second.
;; IN:
;;  ...
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
void f_0935()
{
    uint8 A;

    A = ds3_92A0_frame_cts[0] >> 4;
    gctl_1up2up_displ(A);
}

/*=============================================================================
;; gctl_1up2up_displ()
;;  Description:
;;   Blink 1UP/2UP
;; IN:
;;   A==0 ... called by game_halt()
;;   A==frame_cnts/16 ...continued from f_0935()
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
static void gctl_1up2up_displ(uint8 C)
{
    uint8 A;

    if (IN_GAME_MODE != glbls9200.game_state) return;

    A = ~plyr_state_actv.p1or2 & C; // cpl

    gctl_1up2up_blink(gctl_str_1up, 0x03C0 + 0x19, A); // 'P' of 1UP

    if (!gctl_two_plyr_game) return;

    A = plyr_state_actv.p1or2 & C; // 1 if 2UP

    gctl_1up2up_blink(gctl_str_2up, 0x03C0 + 0x04, A); // 'P' of 2UP

    return;
}

/*=============================================================================
;; gctl_1up2up_blink()
;;  Description:
;;   draw 3 characters (preserves BC)
;; IN:
;;  A==1 ...  wipe text
;;  A==0 ...  show text at HL
;;  HL == pointer to gctl_str_1up text or gctl_str_2up text
;; OUT:
;; PRESERVES:
;;  BC
;;---------------------------------------------------------------------------*/
static void gctl_1up2up_blink(uint8 const *HL, uint16 DE, uint8 A)
{
    uint8 B;

    for (B = 0; B < 3; B++)
    {
        if ((A & 1) != 0)
        {
            m_tile_ram[DE + B] = *(gctl_str_000 + B);
        }
        else
        {
            m_tile_ram[DE + B] = *(HL + B);
        }
    }
}

//=============================================================================
static const uint8 gctl_str_1up[] =
{
    0x19, 0x1E, 0x01 // "1 UP"
};
static const uint8 gctl_str_2up[] =
{
    0x19, 0x1E, 0x02 // "2 UP"
};
static const uint8 gctl_str_000[] =
{
    0x24, 0x24, 0x24 // "spaces"
};
//-----------------------------------------------------------------------------

// "CREDIT" (reversed)
const uint8 str_09CA[] = {0x1D, 0x12, 0x0D, 0x0E, 0x1B, 0x0C};

// "FREE PLAY" (reversed)
const uint8 str_09D0[] = {0x22, 0x0A, 0x15, 0x19, 0x24, 0x0E, 0x0E, 0x1B, 0x0F};

//-----------------------------------------------------------------------------
#ifdef HELP_ME_DEBUG
extern uint16 dbg_step_cnt;
#endif

/*=============================================================================
;; f_0977()
;;  Description:
;;   Polls the test switch, updates game-time counter, updates credit count.
;;   Handles coinage and changes in game-state.
;;
;;    If credit > 0, change game_state to Push_start ($02)
;;     (causes 38d loop to transition out of the Attract Mode, if it's not already in PUSH_START mode)
;;
;;    Check Service Switch - in "credit mode", the 51xx is apparently programmed
;;      to set io_buffer[0]=$bb to indicate "Self-Test switch ON position" .
;;      So, ignore the credit count and jump back to the init.
;;      Bally manual states "may begin a Self-Test at any time by sliding the
;;      ... switch to the "ON" position ...the game will react as follows: ... there is
;;     an explosion sound...upside down test display which lasts for about 1/2 second"
;;    However MAME may not handle this correctly - after the jump to Machine_init, the
;;    system hangs up on the info screen, all that is shown is "RAM OK". (This is
;;    true even if the switch is turned off again prior to that point).
;;
;;    Note mapping of character cells on bottom (and top) rows differs from
;;    that of the rest of the screen;
;;      801D-<<<<<<<<<<<<<<<<<<<<<<<<<<<<-8002
;;      803d-<CREDIT __<<<<<<<<<<<<<<<<<<-8022
;;
;;    99E6-9 implements a count in seconds of total accumulated game-playing time.
;;    counter (low digit increments 1/60th of second)
;;
;;    Credits available count (from HW IO) is transferred to the IO input
;;    buffer (in BCD) during the NMI, and represents actual credits awarded (not
;;    coin-in count). The HW count is decremented by the HW. The game logic
;;    then must keep its own count to compare to the HW to determine if the
;;    HW count has been added or decremented and thus determine game-start
;;    condition and number of player credits debited from the HW count.
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------*/
void f_0977(void)
{
    uint8 B;

    // check for bb ... Service Switch On indication in credit mode
    // if ( io_input[0] == $bb )
    //   jp   z,jp_RAM_test

    if (glbls9200.game_state != IN_GAME_MODE) // goto update freeplay_or_credit
    {
        // l_099F_update_freeplay_or_credit:
        uint16 DE = 0x0000 + 0x003C; // dest of "C" of "CREDIT"

        if (gctl_credit_cnt == 0xA0) // goto puts_freeplay ...  i.e. > 99 (BCD)
        {
            ; // jr   z,l_09D9_puts_freeplay                ; skip credits status
        }
        else if (gctl_credit_cnt < 0xA0) // do credit update display
        {
            // puts "credit"
            uint8 BC = sizeof (str_09CA);
            while (BC-- > 0)
            {
                // on Z80, this is done with lddr, so src pointer in HL originates
                // at "str_09CA + 6 - 1", but here we just use BC to index the src
                m_tile_ram[ DE-- ] = str_09CA[ BC ];
            }

            // leave the "space" following the 'T'
            DE--; // advances one cell to the right (note: bottom row, so not de-20!)

            // only upper digit of BCD credit cnt
            if (io_input[0] > 9) // then rotate "10's" nibble into lower nibble and display it.
            {
                // putc 10's place digit...
                // help ... BCD!
            }

            // putc_ones_place_digit

            // and  #0x0F;  // only lower digit of BCD credit cnt

            m_tile_ram[ DE-- ] = io_input[0]; // putc 1's place digit.

            DE--; // one more space to be sure two cells are covered.

            m_tile_ram[ DE-- ] = 0x24;
        }
        //  jr   l_09E1_update_game_state
    }
    else
    {
        // update timer
        // l_0992_update_counter:
        //  jr  l_09E1_update_game_state
        ;
    }

    // l_09E1_update_game_state:

    if (glbls9200.game_state == GAME_ENDED) return;

    else if (glbls9200.game_state == ATTRACT_MODE && io_input[0] > 0) // credit_count
    {
        glbls9200.game_state = READY_TO_PLAY_MODE;

        memset(b_9AA0, 0, 8); // sound-fx count/enable registers)
        memset(b_9AA0 + 8 + 1, 0, 15); // sound-fx count/enable registers ... skipped 9AA0[8] (coin-in)
    }

    // l_09FF_check_credits_used:
    B = gctl_credit_cnt; // stash the previous credit count

    if (io_input[0] == gctl_credit_cnt)
        return; // return if no change of game state

    else if (io_input[0] > gctl_credit_cnt)
    {
        // jr   c,l_0A1A_update_credit_ct             ; Cy is set (credit_hw > credit_ct)
    }
    else if (io_input[0] < gctl_credit_cnt)
    {
        // gctl_two_plyr_game = credits_used - 1;
        gctl_two_plyr_game = gctl_credit_cnt - io_input[0] - 1;

        gctl_credit_cnt = io_input[0];
        glbls9200.game_state = IN_GAME_MODE;

#ifdef HELP_ME_DEBUG
 dbg_step_cnt = 0;
 ds3_92A0_frame_cts[0] = 0x01;
 ds3_92A0_frame_cts[1] = 0x01;
 ds3_92A0_frame_cts[2] = 0x01; // must be odd, see f_1DD2
#endif
        return;
    }

    // l_0A1A_update_credit_ct
    gctl_credit_cnt = io_input[0];

    // no coin_in sound for free-play
    if (gctl_credit_cnt == 0xA0)
        return;
    else
    {
        // notify CPU2 of new credits count
        // count of additional credits-in since last update (triggering coin-in sound)
        b_9A70[0x09] = io_input[0] - B; // B==credit_ct_previous (from above)
    }
}

/*=============================================================================
;; c_text_out_i_to_d()
;;  Description:
;;   Display an integer value as decimal.
;; IN:
;;   HL: input value (max $FFFF)
;;   DE: destination ... offset into tileram, which is different than Z80 version
;;   which used the entire 16-bit address into tile memory.
;; OUT:
;;  DE: points to (destination - count * 0x40)
;;-----------------------------------------------------------------------------*/
uint16 c_text_out_i_to_d(uint16 HL, uint16 DE)
{
    char tmpstr[5]; // tmp "stack" for 5 digits
    uint8 A, B;

    B = 0; // there is at least 1 digit ... (but maybe more) ...index into the string still ordered from 0 though.

    do
    {
        A = HL % 10;
        HL /= 10;

        tmpstr[B] = A;
        B++;
    }
    while (HL > 0);

    // Convert next digit to the "left" (next higher power of 10).
    while (B-- > 0)
    {
        *(m_tile_ram + DE) = tmpstr[B];
        DE -= 0x20;
    }

    return DE;
}
