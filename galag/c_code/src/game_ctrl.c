/*******************************************************************************
 **  galag: precise re-implementation of a popular space shoot-em-up
 **  game_ctrl.s (gg1-1.3p)
 **    Manage high-level game control.
 **
 **  j_Game_init:
 **      One time entry from power-up routines.
 **  j_Game_start:
 **      Initializes game state. Starts with Title Screen, or "Press Start"
 **      screen if credit available.
 **  j_060F_new_stage:
 **      Sets up each new stage.
 **  jp_045E_While_Game_Running:
 **      Continous loop once the game is started, until gameover.
 **
 **  The possible modes of operation are:
 **    ATTRACT, READY-TO-PLAY, PLAY, HIGH SCORE INITIAL, and SELF-TEST."
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

// 9200, 00-5F: even-bytes, used for object-collision notification to f_1DB3 from cpu1:c_076A
// odd-bytes are ... whatever, so a separate structure is created to try to
// clear things up. is there a compelling reason to pull them together into a
// struct? I don't know. $80 bytes are 0'd at game start, but it wouldn't be
// absolutely necessary to 0 the object-collsn-structs as they are 0'd at each
// start of round or demo. but $80 is way overkill...?
tstruct_b9200 glbls9200;

// Another motley set of globals at 9280. question of whether or not
// they should be collected into a struct.


/*
 ** static external definitions in this file
 */
// variables

//static uint8 sfr_A000[6]; // galaga_starcontrol
static uint8 sfr_A007; // flip_screen_port=0 (not_flipped) ... (unimplemented in MAME?)
static uint8 sfr_6820; //galaga_interrupt_enable_1_w
static uint8 two_plyr_game;
static uint8 ds30_susp_plyr_obj_data[0x30]; // c_player_active_switch
static uint8 credit_cnt;

// forward declarations
static const uint8 d_attrmode_sptiles_ships[];
static const uint8 d_0495[];
static const uint8 str_1UP[];
static const uint8 str_2UP[];
static const uint8 str_0974[];
static const uint8 d_07FB[];
static const uint8 d_0909[];

// function prototypes
static void c_game_init(void);
static void c_game_init_putc(uint8 const *HL, uint16 DE);
static void j_060F_new_stage(void);
static void c_game_bonus_info_show_line(uint8, uint8, uint8 const *);
static void j_0612_plyr_setup(void);
static void j_061E_plyr_respawn(void);
static void c_093C(uint8 CA);
static void round_start_or_restart(void);
static void c_095F(uint8 const *, uint16, uint8);
static void c_0728_score_and_bonus_mgr(void);
static void c_07D8(uint16, uint8);
static void c_080B_monitor_stage_start_or_restart_conditions();
static void j_0650_handle_end_challeng_stg(void);
static uint8 c_08BE(uint8, uint8, uint8 const *);


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

    memset((uint8 *) b8800_obj_status, 0x80, sizeof (struct_obj_status) * 0x80);
}

/*=============================================================================
;; j_Game_init()
;;  Description:
;;   One time Game startup after machine initialization.
;;   Falls through to Game_start.
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------*/

void j_Game_init(void)
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
    c_textout_1uphighscore_onetime();

    c_1230_init_taskman_structs();

    // data structures for 12 objects
    memset(ds_bug_motion_que, 0, sizeof (t_bug_flying_status) * 0x0C /* 0xF0 */);

    /*
    ; Not sure here...
    ; this would have the effect of disabling/skipping the task at 0x1F (f_0977)
    ; which happens to relate to updating the credit count (although, there is no
    ; RST 38 to actually trigger the task from now until setting this to 0 below.)
     */
    task_actv_tbl_0[0x1E] = 0x20;

    credit_cnt = io_input[0];

    task_actv_tbl_0[0x1E] = 0; // just wrote $20 here see above

    cpu1_task_en[0] = 0; // disables f_05BE in CPU-sub1 (empty task)
}

/*=============================================================================
;; j_Game_start()
;;  Description:
;;    Performs initialization, and does a one-time check for credits
;;    (monitoring credit count and updating "GameState" is otherwise handled
;;    by a 16mS task). If credits available at startup, it updates "GameState"
;;    and skips directly to "Ready" state, otherwise it
;;    stays in Attract mode state.
;;
;;    When all ships are destroyed, execution jumps back to Game_start.
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------*/
int j_Game_start(void)
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
    memset(ds_bug_motion_que, 0, sizeof (t_bug_flying_status) * 0x0C /* 0xF0 */);

    c_sctrl_sprite_ram_clr();
    c_1230_init_taskman_structs();


    if (credit_cnt == 0) glbls9200.game_state = ATTRACT_MODE;
    else glbls9200.game_state = READY_TO_PLAY_MODE;


    if (glbls9200.game_state == READY_TO_PLAY_MODE)
    {
        /* jr   nz,l_game_state_ready */ // do game start stuff
    }
    else // do attract mode stuff
    {
        glbls9200.demo_idx = 0;

        task_actv_tbl_0[2] = 1; // f_17B2 (control demo mode)

        // l_038D_While_Attract_Mode
        while (glbls9200.game_state == ATTRACT_MODE)
        {
            if (0 != _updatescreen(1)) // 1 == blocking wait for vblank
                return 1; // goto getout;
        }

        // GameState == Ready ... reinitialize everything
        c_1230_init_taskman_structs();
        c_sctrl_playfld_clr();
        memset(ds_bug_motion_que, 0, sizeof (t_bug_flying_status) * 0x0C /* 0xF0 */);
        c_sctrl_sprite_ram_clr();
    }

    // jp   j_060F_new_stage ... does not return, jp's to Game Loop
    return 0;
}


/*=============================================================================
;;  game_state_ready
;;  Description:
;;    l_game_state_ready
;;
;;-----------------------------------------------------------------------------*/
int game_state_ready(void)
{
    uint8 A;

    glbls9200.flying_bug_attck_condtn = 0; // 1 at demo mode, 3 at game start, and now 0

    j_string_out_pe(1, -1, 0x13); // "(c) 1981 NAMCO LTD"
    j_string_out_pe(1, -1, 1); // "PUSH START BUTTON"

    A = mchn_cfg.bonus[0];

    if (0xFF != A) // ... else l_While_Ready
    {
        // ld   (p_attrmode_sptiles),hl ... not necessary to keep persistent pointer for function paramter

        // E=bonus score digit, C=string_out_pe_index
        c_game_bonus_info_show_line(A, 0x1B, d_attrmode_sptiles_ships + 0 * 4);

        A = mchn_cfg.bonus[1];
        if (0xFF != A) // ... else l_While_Ready
        {
            A &= 0x7F;

            c_game_bonus_info_show_line(A, 0x1C, d_attrmode_sptiles_ships + 1 * 4);
            A = mchn_cfg.bonus[1];

            // if bit 7 is set, the third bonus award does not apply
            if (0 == (0x80 & A)) // goto l_While_Ready
            {
                A &= 0x7F;
                c_game_bonus_info_show_line(A, 0x1D, d_attrmode_sptiles_ships + 2 * 4);
            }
        }
    }

    // l_While_Ready:
    while (READY_TO_PLAY_MODE == glbls9200.game_state)
    {
        if (0 != _updatescreen(1)) // 1 == blocking wait for vblank
            return 1; // goto getout;
    }
    return 0;
}


/*=============================================================================
;;  game_mode_start
;;  Description:
;;    start button was hit
;;
;;-----------------------------------------------------------------------------*/
int game_mode_start(void)
{
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

    b_9AA0[ 0x0B ] = 1; // sound-fx count/enable, start of game theme

    task_actv_tbl_0[0x12] = 1; // f_1D76, star ctrl
    task_actv_tbl_0[0x12] = 1; // f_1D76, star ctrl

    // do one-time inits
    c_game_init(); // setup number of lives and scores
    c_game_or_demo_init();

    j_string_out_pe(1, -1, 4); //  "PLAYER 1" (always starts with P1 no matter what!)

    // busy loop -leaves "Player 1" text showing while some of the opening theme music plays out
    ds4_game_tmrs[3] = 8;
    while (ds4_game_tmrs[3] > 0)
    {
        if (0 != _updatescreen(1)) // 1 == blocking wait for vblank
            return 1; // goto getout;
    }

    memset(ds_bug_collsn, 0, 0x10);
    memset(ds30_susp_plyr_obj_data, 0, 0x30);

    c_string_out(0x03B0, 0x0B); // erase PLAYER 1 text

    plyr_state_susp.p1or2 = 1; // 1==plyr2
    plyr_state_actv.mcfg_bonus0 = mchn_cfg.bonus[0];
    plyr_state_susp.mcfg_bonus0 = mchn_cfg.bonus[0];

    // jp   j_060F_new_stage

    return 0;
}


/*=============================================================================
 c_game_bonus_info_show_line()
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
static void c_game_bonus_info_show_line(uint8 E, uint8 C, uint8 const *pHL)
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

    sprite_tiles_display(pHL); // show the fighter sprite

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
static const uint8 d_attrmode_sptiles_ships[] =
{
    0x00, 0x81, 0x19, 0x56,
    0x02, 0x81, 0x19, 0x62,
    0x04, 0x81, 0x19, 0x6E
};

/*=============================================================================
;; While_Game_Running()
;;  Description:
;;   Everything runs out of this loop once the game is started.
;; IN:
;;  ...
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
void While_Game_Running(void)
{
    while (1) // jr   l_045E_while_play_game
    {
        c_0728_score_and_bonus_mgr();
        c_080B_monitor_stage_start_or_restart_conditions();

        // I don't remember what actually causes the game to recycle, but
        // here we  allow an escape from the superloop
        if (0 != _updatescreen(1)) // 1 == blocking wait for vblank
            break; // goto getout;
    }
}

/*=============================================================================
;; c_game_init()
;;  Description:
;;   New game, 00 scores for player 1 (and player 2 if needed). "2UP" redrawn later.
;; IN:
;;  ...
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
static void c_game_init(void)
{
    uint8 const *HL;
    uint16 DE;
    uint8 A;

    // get nbr of ships from machine config
    A = 3; // tmp ...    ld   a,(b8_mchn_cfg_nships)
    plyr_state_actv.num_ships = A;
    plyr_state_susp.num_ships = A;

    DE = 0x03E0 + 0x18; // player 1 score, right tile of "00"
    HL = &d_0495[0];
    c_game_init_putc(HL, DE);

    DE = 0x03E0 + 0x03; // player 2 score
    HL = &d_0495[0];

    if (!two_plyr_game)
    {
        // advance src pointer past "00" to erase player 2 score (start of spaces)
        HL += 2;
    }

    c_game_init_putc(HL, DE);

    return;
}

/*=============================================================================
;; c_game_init_putc
;;  Description:
;;   we saved 4 bytes of code space by factoring out the part that copies 7
;;   characters. Then we wasted about 50 uSec by repeating the erase 2UP
;; IN:
;;  HL: src tbl pointer ... either 0495 or 0497
;;  DE: dest pointer (offset)
;; OUT:
;;
;;---------------------------------------------------------------------------*/
static void c_game_init_putc(uint8 const *HL, uint16 DE)
{
    uint8 const *tmpHL = HL;
    uint16 tmpDE = DE;
    uint8 C;

    C = 7;

    while (C-- > 0)
    {
        m_tile_ram[ tmpDE++ ] = *(tmpHL++);
    }

    tmpHL = &d_0495[2]; // ld   hl,#d_0497
    tmpDE = 0x03C0 + 3;
    C = 4;

    while (C-- > 0)
    {
        m_tile_ram[ tmpDE++ ] = *(tmpHL++);
    }

    return;
}


/*===========================================================================*/
// "00" and space characters for initial score display
static const uint8 d_0495[] =
{
    0x00, 0x00,
    0x24, 0x24, 0x24, 0x24, 0x24, 0x24, 0x24
};
/*---------------------------------------------------------------------------*/

/*=============================================================================
;;  game_runner
;;  Description:
;;   NOT a legacy function, this is glue logic to help cleanup the spaghetti
;;   mess of jp's in the original code.
;;
;;-----------------------------------------------------------------------------*/
int game_runner(void)
{
    // jp   j_060F_new_stage   ; does not return, jp's to Game Loop
    j_060F_new_stage();

    j_0612_plyr_setup();

    round_start_or_restart();

    While_Game_Running();

    return 0;
}


/*=============================================================================
;;
;; jp (ret) to jp_045E_While_Game_Running
;; jp (ret) j_0632_round_start_or_restart
;;    j_0632_round_start_or_restart
;;       jp_045E_While_Game_Running
;;===========================================================================*/
void jp_049E_handle_stage_start_or_restart(void)
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

    c_0728_score_and_bonus_mgr();

    plyr_state_actv.b_nbugs = b_bugs_actv_nbr;

    // check for "not (normal) end of stage conditions":

    // if ( restart stage flag || bugs_actv_nbr>0 ) {{
    //   jr   nz,l_04E2_terminate_or_gameover
    if ( 0 == plyr_state_actv.not_chllng_stg )
    {
        // jp's back to 04DC_new_stage_setup
        j_0650_handle_end_challeng_stg();
    }

    //j_04DC_new_stage_setup

    // end of stage ... "normal"
    c_new_stg_game_only();

    // jp   j_0632_round_start_or_restart         ; jp   jp_045E_While_Game_Running
    round_start_or_restart();
    // jp   jp_045E_While_Game_Running
}


/*=============================================================================
;;  j_060F_new_stage
;;  Description:
;;   New stage setup for player changeover, or at start of new game loop.
;;   If on a new game, PLAYER 1 text has been erased.
;;
;;--------------------------------------------------------------------------- */
static void j_060F_new_stage(void)
{
    c_new_stg_game_only(); // shows "STAGE X" and does setup

    // j_0612_plyr_setup
}

/*=============================================================================
;;  j_0612_plyr_setup:
;;  Description:
;;   Setup a new player... every time the player is changed on a 2P game or once
;;   at first ship of new 1P game. Shows Player 1 (2) text on stage restart.
;;
;;----------------------------------------------------------------------------*/
static void j_0612_plyr_setup(void)
{
    // P1 text is index 4, P2 is index 5
    c_string_out(0x0260 + 0x0E, plyr_state_actv.p1or2 + 4); // PLAYER X ("1" or "2") .

    // jr   j_061E_plyr_respawn
    j_061E_plyr_respawn();

    return;
}

/*=============================================================================
;;  j_061E_plyr_respawn
;;  Description:
;;
;;----------------------------------------------------------------------------*/
static void j_061E_plyr_respawn(void)
{
    uint8 A;

    // "credit X" is wiped and reserve ships appear on lower left of screen
    c_player_respawn(); // there is only one reference to this so it could be inlined.

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
    // j_0632_round_start_or_restart:
}

/*=============================================================================
;;  j_0632_round_start_or_restart
;;  Description:
;;
;;----------------------------------------------------------------------------*/
static void round_start_or_restart(void)
{
    task_actv_tbl_0[0x15] = 1; // f_1F04 ...fire button input
    //ds_cpu1_task_en[0x05] = 1;  // (enable cpu1:f_05EE)

    // attack_wave_enable
    plyr_state_actv.b_atk_wv_enbl = 1; // 0 when respawning player ship

    c_string_out(0x03B0, 0x0B); // erase "READY" or "STAGE X"

    c_string_out(0x03A0 + 0x0E, 0x0B); // erase "PLAYER 1"

    // jp   jp_045E_While_Game_Running  ; return to Game Runner Loop
}


/*=============================================================================
;; j_0650_handle_end_challeng_stg()
;;  Description:
;;
;; IN:
;;  ...
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
static void j_0650_handle_end_challeng_stg(void)
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

            if ( 0 != (0x01 & B))
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
        while(--B > 0); // djnz l_069B_while_b

        j_string_out_pe(1, -1, 0x0D); // "SPECIAL BONUS 10000 PTS"

        A = 100;
    }

    // l_06BA:
    ds_bug_collsn[0x0F] += A;
    c_0728_score_and_bonus_mgr();
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
;;  c_0728_score_and_bonus_mgr
;;  Description:
;;    Red == 50
;;    Yellow == 80
;;    (x2 if flying)
;;----------------------------------------------------------------------------*/
static void c_0728_score_and_bonus_mgr(void)
{
    reg16 AF;
    uint8 A, B, C, E, L, IXL;

    IXL = 0xF9;
    if ( 0 != plyr_state_actv.p1or2 )
    {
        IXL = 0xE4;
    }

    // l_0732:

    B = 0x10; // ld   b,#0x10
    L = 0; // ld   hl,#ds_bug_collsn + 0x00

    // l_0739_while_B
    while ( B > 0 )
    {
        // ex   de,hl ... stash HL

        C = d_07FB[ B - 1 ]; // ld   hl,#d_07FB - 1

        // l_0740
        while ( 0 != ds_bug_collsn[L] ) // jr   z,l_0762
        {
            //if ( 0 != ds_bug_collsn[L] )
            ds_bug_collsn[L] -= 1; // dec  (hl)

            A = C & 0x0F; // and  #0x0F
            c_07D8(0x0300 + IXL, A);

            A = (C >> 4) & 0x0F; // rlca * 4
            c_07D8(0x0300 + IXL + 1, A);

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
    while ( B > 0)
    {
        A = m_tile_ram[ 0x0300 + E ]; // ld   a,(de)
        A -= m_tile_ram[ 0x03E0 + L ]; // sub  (hl)
        A += 9;

        if ( A < 0xE5 ) // jr   nc,l_0788
        {
            A -= 0x0A;

            if ( A >= 9 ) // jr   c,l_0788
            {
                // inc  a
                if ( -1 == A)
                {
                    L -= 1; // dec  l
                    E -= 1; // dec  e
                    // djnz l_0771
                }
                else  break; // jr   nz,l_078E
            }
            else
            {
                // l_0788: tick away the remaining counts on B
                while( B > 0 )
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
            while( B > 0 )
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

    if ( 0x24 == AF.pair.b0 )  AF.word = 0; // xor  a

    // l_0799:
    AF.word &= 0x3F;
    AF.word <<= 1; // rlca
    C = AF.pair.b0;
    AF.word <<= 2; // rlca * 2
    AF.pair.b0 += C;
    C = AF.pair.b0;
    L -= 1;
    AF.word = m_tile_ram[0x0300 + L];

    if ( 0x24 == AF.pair.b0 )  AF.word = 0; // xor  a

    // l_07A8:
    // check if a bonus fighter to be awarded
    return; // tmp:  ... ret  nz
}


/*=============================================================================
;; c_07D8()
;;  Description:
;;   handle score inrement (c_0728_score_and_bonus_mgr)
;; IN:
;;  A == d_07FB[B-1]
;;        twice on 1 update, 1st is low nibble, 2nd is high nibble
;;  HL== index into tile_ram
;; OUT:
;;  HL=
;;---------------------------------------------------------------------------*/
static void c_07D8(uint16 hl, uint8 a)
{
    if ( 0 == a )
        return;

    a += m_tile_ram[hl];

    if ( a >= 0x24 ) // jr   c,l_07E1
    {
        a -= 0x24; // > 'Z' so subtract 'Z'
    }

    // l_07E1:
    if ( a < 0x0A ) // jr   nc,l_07E7
    {
        m_tile_ram[hl] = a;
        return;
    }

    // l_07E7:
    a -= 0x0A;

    // l_07E9_while_1:
    while(1) // ... you gotta love while 1's
    {
        m_tile_ram[hl] = a;

        hl += 1; // inc  l
        a = m_tile_ram[hl];

        if ( 0x24 == a ) // 'Z'
        {
            a = 0; // xor  a ... set to 0 in case it breaks (if A == 9 )
        }

        // l_07F1:
        if ( 0x09 != a )
        {
            m_tile_ram[hl] = a + 1; // inc  a
            return;
        }
        a = 0; // xor  a
    } // // jr   l_07E9_while

    return; // shouldn't be here
}


//=============================================================================
// data for _073A
static const uint8 d_07FB[] =
{
    0x10,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
    0x50,0x08,0x08,0x08,0x05,0x08,0x15,0x00
};


/*=============================================================================
;; f_0827()
;;  Description:
;;   empty task
;; IN:
;;  ...
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
static void c_080B_monitor_stage_start_or_restart_conditions(void)
{
    // f_2916 (supervises attack waves)
    if ( 0 == task_actv_tbl_0[0x08] && 0 == b_bugs_actv_nbr )
    {
        // cleared the round
        b_9AA0[0x00] = 0; // sound-fx count/enable registers, pulsing formation sound effect
    }
    else
    {
        if ( 0 == glbls9200.restart_stage ) // 0x13, restart stage flag
        {
            return;
        }
    }
    plyr_state_actv.b_atk_wv_enbl = 0;
    jp_049E_handle_stage_start_or_restart();
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
    if ( ds4_game_tmrs[2] < 0x3C )
    {
        ds_new_stage_parms[4] = ds_new_stage_parms[5];
    }

    // l_0865: bomb drop enable flags
    // A==new_stage_parms[0], HL==d_0909, C==num_bugs_on_scrn
    A = c_08BE(ds_new_stage_parms[0], b_bugs_actv_nbr, d_0909);
    b_92C0_0[0x08] = A;

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
;; c_08BE()
;;  Description:
;;   for f_0857
;; IN:
;;  A == new_stage_parms[0]
;;  C == num_bugs_on_scrn
;;  HL == data pointer
;; OUT:
;;  A==(hl)
;;---------------------------------------------------------------------------*/
static uint8 c_08BE(uint8 A, uint8 C, uint8 const *pHL)
{
    uint16 HL = 0;
    reg16 rHL;
    A <<= 1; // sla  a
    rHL.word = HL + 2 * A; // rst  0x08 .. HL += 2A
    //ex   de,hl
    rHL.pair.b1 = C; //ld   h,c
    //ld   a,#0x0A
    rHL.word = rHL.word / 10; // call c_divmod ... HL=HL/10
    //ex   de,hl ... 8-bit quotient into d
    //ld   a,d
    //rst  0x10 ... HL += A
    //ld   a,(hl)

    return (pHL[rHL.pair.b0]);
}

/*---------------------------------------------------------------------------*/
static const uint8 d_0909[] =
{
    0x03,0x03,0x01,0x01,0x03,0x03,0x03,0x01,0x07,0x03,0x03,0x01,0x07,0x03,0x03,0x03,
    0x07,0x07,0x03,0x03,0x0F,0x07,0x03,0x03,0x0F,0x07,0x07,0x03,0x0F,0x07,0x07,0x07
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
    c_093C(A);
}


/*=============================================================================
;; c_093C()
;;  Description:
;;   Blink 1UP/2UP
;; IN:
;;   A==0 ... called by game_halt()
;;   A==frame_cnts/16 ...continued from f_0935()
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
static void c_093C(uint8 CA)
{
    uint8 A, B, C;

    C = CA; // stash counter in C

    if (IN_GAME_MODE != glbls9200.game_state) return;

    B = plyr_state_actv.p1or2;

    A = ~B & C; // cpl

    c_095F(str_1UP, 0x03C0 + 0x19, A); // 'P' of 1UP

    if (!two_plyr_game) return;

    A = B & C; // 1 if 2UP

    c_095F(str_2UP, 0x03C0 + 0x04, A); // 'P' of 2UP

    return;
}

/*=============================================================================
;; c_095F()
;;  Description:
;;   draw 3 characters (preserves BC)
;; IN:
;;  A==1 ...  wipe text
;;  A==0 ...  show text at HL
;;  HL == pointer to xUP text
;; OUT:
;; PRESERVES:
;;  BC
;;---------------------------------------------------------------------------*/
static void c_095F(uint8 const *_HL, uint16 DE, uint8 A)
{
    uint16 BC;
    uint8 const *HL;

    HL = _HL;

    BC = 3;

    if ((A & 1) != 0)
    {
        HL = str_0974;
    }

    while (BC-- > 0)
    {
        m_tile_ram[DE++] = *HL++;
    }
}

//=============================================================================
static const uint8 str_1UP[] =
{
    0x19, 0x1E, 0x01
};
static const uint8 str_2UP[] =
{
    0x19, 0x1E, 0x02
};
static const uint8 str_0974[] =
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

        if (credit_cnt == 0xA0) // goto puts_freeplay ...  i.e. > 99 (BCD)
        {
            ; // jr   z,l_09D9_puts_freeplay                ; skip credits status
        }
        else if (credit_cnt < 0xA0) // do credit update display
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
    B = credit_cnt; // stash the previous credit count

    if (io_input[0] == credit_cnt)
        return; // return if no change of game state

    else if (io_input[0] > credit_cnt)
    {
        // jr   c,l_0A1A_update_credit_ct             ; Cy is set (credit_hw > credit_ct)
    }
    else if (io_input[0] < credit_cnt)
    {
        // two_plyr_game = credits_used - 1;
        two_plyr_game = credit_cnt - io_input[0] - 1;

        credit_cnt = io_input[0];
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
    credit_cnt = io_input[0];

    // no coin_in sound for free-play
    if (credit_cnt == 0xA0)
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
