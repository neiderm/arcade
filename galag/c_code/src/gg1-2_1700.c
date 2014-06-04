/*******************************************************************************
 **  galag: precise re-implementation of a popular space shoot-em-up
 **  gg1-2_1700.s (gg1-2.3m)
 **    ship movement, control inputs, flying bugs, flying bombs.
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
// this has to be somewhere, so why not here but there are actually
// more references to this in gg1-2.c than anywhere else
sprt_regs_t mrw_sprite;

uint8 b_92A4_rockt_attribute[2]; // ref'd in gg1-5.c
uint8 b_92C0_0[0x0A]; // bmbr_timer_flags
bmbr_boss_slot_t bmbr_boss_pool[4]; // index and movement vector

/*
 ** static external definitions in this file
 */
// variables

static uint8 fmtn_expcon_cinc_curr[16]; // current set of working bitmaps for expand/contract motion
static uint8 demo_txt_idx;              // index of text string displayed in demo (z80 addr. $9205)
static uint8 demo_state_tmr;            // timer of demo states (z80 addr. $9207)
static uint8 demo_idx_tgt_obj;          // position/index of targetted alien from data (z80 addr. $9209)
static uint8 const *demo_p_fghtr_mvecs; // pointer to current set of movement vectors for fighter in demo
static uint8 fghtr_ctrl_dxflag;         // selection flag for dx increment of fighter movement

// declarations
static const uint8 demo_fghtr_mvecs_ac[]; // fighter movement vectors, demo, after capture
static const uint8 demo_fghtr_mvecs_bc[]; // fighter movement vectors, demo, before capture
static uint8 fmtn_expcon_cinc_bits[][16]; // bitmap table for formation expand/contract movement
static const uint8 d_bmbr_boss_wingm_idcs[];
static const uint8 d_1CFD[];

// function prototypes
static void fmtn_expcon_comp(uint8, uint8, uint8); // compute formation expand/contract movement
static void fghtr_ctrl_inp(uint8);
static void rckt_sprite_init(void);
static uint8 bmbr_boss_activate(uint8, uint8, uint8, uint8, uint16);
static void bmbr_boss_escort_sel(uint16, uint8, uint8 *, r16_t *, uint8);


/*============================================================================
;; data source for sprite tiles used in attract mode
;;  0: offset/index of object to use
;;  1: color/code
;;      ccode<3:6>==code
;;      ccode<0:2,7>==color
;;  2: X coordinate
;;  3: Y coordinate
;; */

// 7 sprites for small demo (6 diving and 1 stationary)
static const uint8 d_attrmode_sptiles_7[] =
{
    0x34, 0x08, 0x34, 0x5C,
    0x30, 0x08, 0x64, 0x5C,
    0x32, 0x08, 0x94, 0x5C,
    0x4A, 0x12, 0xA4, 0x64,
    0x36, 0x08, 0xC4, 0x5C,
    0x58, 0x12, 0xB4, 0x64,
    0x52, 0x12, 0xD4, 0x64
};

// 3 stationary sprites
static const uint8 d_attrmode_sptiles_3[] =
{
    0x08, 0x1B, 0x44, 0x3A, // yellow alien (50/100 points)
    0x0A, 0x12, 0x44, 0x42, // red alien (80/160 points)
    0x0C, 0x08, 0x7C, 0x50  // green boss
};

// provides a persistent index across calls into state-machine
static uint8 idx_attrmode_sptiles_3;


/*----------------------------------------------------------------------------*/

// demo_p_fghtr_mvecs, fighter vectors demo level after boss capture
static const uint8 demo_fghtr_mvecs_ac[] = // d_181F:
{
    0x08, 0x18, 0x8A, 0x08, 0x88, 0x06, 0x81, 0x28, 0x81, 0x05, 0x54, 0x1A, 0x88, 0x12, 0x81, 0x0F,
    0xA2, 0x16, 0xAA, 0x14, 0x88, 0x18, 0x88, 0x10, 0x43, 0x82, 0x10, 0x88, 0x06, 0xA2, 0x20, 0x56, 0xC0
};
// demo_p_fghtr_mvecs, fighter vectors demo level before boss capture
static const uint8 demo_fghtr_mvecs_bc[] = // d_1887:
{
    0x02, 0x8A, 0x04, 0x82, 0x07, 0xAA, 0x28, 0x88, 0x10, 0xAA, 0x38, 0x82, 0x12, 0xAA, 0x20, 0x88,
    0x14, 0xAA, 0x20, 0x82, 0x06, 0xA8, 0x0E, 0xA2, 0x17, 0x88, 0x12, 0xA2, 0x14, 0x18, 0x88, 0x1B,
    0x81, 0x2A, 0x5F, 0x4C, 0xC0
};
// fighter vectors training level
static const uint8 demo_fghtr_mvecs_tl[] = // d_1928:
{
    0x08, 0x1B, 0x81, 0x3D, 0x81, 0x0A, 0x42, 0x19, 0x81, 0x28, 0x81, 0x08,
    0x18, 0x81, 0x2E, 0x81, 0x03, 0x1A, 0x81, 0x11, 0x81, 0x05, 0x42, 0xC0
};


/*=============================================================================
;; f_1700()
;;  Description:
;;   Ship-runner in training/demo mode, enabled in main (one time init) for
;;   training mode (not called in ready or game mode).
;;   This one is basically an extension of f_17B2:case 0x04 until disabled
;;   below.
;; IN:
;;  ...
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
void f_1700(void)
{
    uint8 A;

    switch (*demo_p_fghtr_mvecs & 0xE0) // don't bother with rlca
    {
    // appearance of first attack wave in GameOver Demo-Mode
    case 0xA0: // 172D:
        rckt_sprite_init(); //  init sprite objects for rockets
        // ld   de,(pdb_demo_fghtrvctrs) ... don't need it
        // no break!

    // 1734: drives the simulated inputs to the fighter in training mode
    case 0x80:

        // ld   hl,#ds_plyr_actv +_b_2ship
        // ld   e,(hl) ... double ship flag referenced directly in fghtr_ctrl_inp

        // not till demo round
        A = *demo_p_fghtr_mvecs & 0x0A; // 0x08 | 0x02
        //jr   l_1755

        if (0 != (*demo_p_fghtr_mvecs & 0x01)) // bit  0,a
        {
            // move fighter in direction of targeted alien
            uint8 L = demo_idx_tgt_obj; // object/index of targeted alien

            A = 0x0A; // 0x08 | 0x02
            if (mrw_sprite.posn[L].b0 != mrw_sprite.posn[SPR_IDX_SHIP].b0) // sub  (hl)
            {
                A = 8; // R
                if (mrw_sprite.posn[L].b0 <= mrw_sprite.posn[SPR_IDX_SHIP].b0)
                {
                    A = 2; // L
                }
            }
        }
        // l_1755:
        fghtr_ctrl_inp(A); // input control bits

        // do nothing until frame count even multiple of 4
        if (0 != (ds3_92A0_frame_cts[0] & 0x03))
        {
            return; // ret  nz
        }

        demo_state_tmr -= 1; // dec  (hl)

        if (0 != demo_state_tmr)
        {
            return; // ret  nz
        }

        rckt_sprite_init(); //  training mode ... nukes are loaded

        // no break

    case 0x00: // 1766:
    case 0x20: // 1766:
    case 0x60: // 1766:
    case 0x40: // 171F: delay for targetting diving boss+wingmen

        if (0x40 == (*demo_p_fghtr_mvecs & 0xE0))
        {
            if (0 != (ds3_92A0_frame_cts[0] & 0x0F))
            {
                return; // ret  nz
            }
            demo_state_tmr -= 1;

            if (0 != demo_state_tmr)
            {
                return; // ret  nz
            }
        }

        // d<7> && !d<6> ... ordinance deployed!
        if (0x80 == (0xC0 & *demo_p_fghtr_mvecs))
        {
printf("... fish in the water\n");
            demo_p_fghtr_mvecs += 1; // inc  de ... right-most boss+2wingmen dive
        }
        //l_1772:
        demo_p_fghtr_mvecs += 1; // inc  de

        A = *demo_p_fghtr_mvecs & 0xE0; // don't bother with rlca

        // case_1794: load index/position of target alien
        if (0x00 == A || 0x20 == A)
        {
            demo_idx_tgt_obj = (*demo_p_fghtr_mvecs << 1) & 0x7E; // mask out Cy rlca'd into <:0>
        }
        // case_179C: last token
        else if (0xC0 == A)
        {
            task_actv_tbl_0[0x03] = 0; // this task
        }
        // case_17A1: wait for target in sights
        else if (0x40 == A)
        {
            // ld   a,(de) ... and  #0x1F

            //l_17A4:
            demo_state_tmr = *demo_p_fghtr_mvecs & 0x1F;
        }
        // case_17A8: no idea when
        else if (0x60 == A)
        {
            //A = *demo_p_fghtr_mvecs & 0x1F;
            //       ld   c,a
            //       rst  0x30 ... string_out_pe
        }
        // case_17AE: wait timer, firing rocket training level ... demo ?
        else if (0x80 == A || 0xA0 == A)
        {
            //ld   a,(de) ... jr   l_17A4

            //l_17A4:
            demo_state_tmr = *(demo_p_fghtr_mvecs + 1); // inc  de;
        }

        break;

    default:
        break;
    }
}

/*=============================================================================
;; f_17B2()
;;  Description:
;;   Frame-update work in training/demo mode.
;;   Called once/frame not in ready or game mode.
;;
;; IN:
;;  ...
;; OUT:
;;  ...
-----------------------------------------------------------------------------*/
void f_17B2()
{
    uint8 B;

    if (ATTRACT_MODE == glbls9200.game_state)
    {
        switch (glbls9200.demo_idx)
        {
        case 0x0E: // l_17E1
            // demo or GALACTIC HERO screen
            if (ds4_game_tmrs[3] == 0)
            {
                // c_mach_hiscore_show();
                ds4_game_tmrs[3] = 0x0A; // after displ hi-score tbl
                return;
            }
            else if (1 == ds4_game_tmrs[3]) break;
            else return;
            break;

        case 0x07: // l_17F5
            // just cleared the screen from training mode... wait the delay then
            // shows "game over"
            if ((ds3_92A0_frame_cts[0] & 0x1F) != 0x1F) return;
            else
            {
                task_actv_tbl_0[0x05] = 1; // f_0857
                j_string_out_pe(1, -1, 0x02); // string_out_pe ("GAME OVER")
            }
            break;

        case 0x0A: // l_1808
            // boss with captured-ship has just rejoined fleet in demo
            // load fighter vectors for demo level (after capture)
            // call c_133A
            demo_p_fghtr_mvecs = demo_fghtr_mvecs_ac; // d_181F
            break;

        case 0x0C: // l_1840
            // one time at end of demo, just before "HEROES" displayed, ship has been
            // erased from screen but remaining bugs may not have been erased yet.
            glbls9200.glbl_enemy_enbl = 0;
            break;

        case 0x08: // l_1852
            // load fighter vectors for demo level (before capture)
            demo_p_fghtr_mvecs = demo_fghtr_mvecs_bc;

            glbls9200.glbl_enemy_enbl = 1;
            break;

        // in demo, as the last boss shot second time
        case 0x05: // l_18AC
            if (0 != ds4_game_tmrs[2])
            {
                if (1 != ds4_game_tmrs[2])
                {
                    if (5 == ds4_game_tmrs[2])
                    {
                        //l_18C6:
                        mrw_sprite.posn[0x62].b0 = 0;
                        j_string_out_pe(1, -1, 0x13); // "(C) 1981 NAMCO LTD."
                        j_string_out_pe(1, -1, 0x14); // "NAMCO" - 6 tiles
                    }
                    return;
                } // else ... jp   z,l_19A7_end_switch
            }
            else // jr   z,l_18BB
            {
                sprt_hit_notif[0x34] = 0x34;
                ds4_game_tmrs[2] = 9;
                return;
            }
            break;

        // fighter just appeared in training mode (state active until f_1700 disables itself)
        case 0x04: // l_18D1
        case 0x09: // l_18D1
        case 0x0B: // l_18D1
            if (0 != task_actv_tbl_0[0x03])
            {
                return; // get out, no update state-machine index
            }
            // jp   z,l_19A7_end_switch
            break;

        case 0x03: // l_18D9
            // one time init for training mode ... 7 bugs etc.
            for (B = 0; B < 7; B++)
            {
                sprite_tiles_display(d_attrmode_sptiles_7 + B * 4);
            }

            plyr_state_actv.num_ships = 0;
            task_actv_tbl_0[0x05] = 0; // f_0857
            c_133A_show_ship();

            // set inits and override defaults of bomber timers (note f_0857 disabled above)
            b_92C0_0[0x06] = 0xFF; // yellow alien default bomber timer
            b_92C0_0[0x05] = 0xFF; // red alien default bomber timer
            b_92C0_0[0x04] = 0x0D; // boss alien default bomber timer
            b_92C0_0[0x02] = 0xFF; // bmbr timer yellow alien
            b_92C0_0[0x01] = 0xFF; // bmbr timer red alien
            b_92C0_0[0x00] = 0x0D; // bmbr timer boss

            demo_p_fghtr_mvecs = demo_fghtr_mvecs_tl; // fighter vectors for training level

            // bmbr_boss_slots[] is only 12 bytes, so this initialization would
            // include b_CPU1_in_progress + b_CPU2_in_progress + 2 unused bytes
            memset(bmbr_boss_pool, 0, sizeof(bmbr_boss_slot_t) * 4);

            plyr_state_actv.plyr_is_2ship = 0; // not 2 ship
            glbls9200.glbl_enemy_enbl = 0;
            plyr_state_actv.bmbr_boss_cflag = 1;

            task_actv_tbl_0[0x10] = 1; //  f_1B65 ... manage flying-bug-attack
            task_actv_tbl_0[0x0B] = 1; //  f_1DB3 ... checks enemy status at 9200
            task_actv_tbl_0[0x03] = 1; //  f_1700 ... ship-update in training/demo mode

            //from DSWA "sound in attract mode"
            b_9AA0[0x17] = 0; // (_sfr_dsw4 >> 1) & 0x01;

            c_game_or_demo_init();
            break;

        case 0x00: // l_1940
        case 0x06: // l_1940
        case 0x0D: // l_1940
            // used during "CREDIT 0"
            c_sctrl_playfld_clr();
            c_sctrl_sprite_ram_clr();
            break;

        // init demo
        case 0x01: // l_1948
            idx_attrmode_sptiles_3 = 0; // setup index into sprite data table
            demo_txt_idx = 0;
            w_bug_flying_hit_cnt = 0;
            ds4_game_tmrs[2] = 2; // 1 second
            break; // jr   l_19A7_end_switch

        case 0x02: // l_1984
            if (0 == ds4_game_tmrs[2])
            {
                ds4_game_tmrs[2] = 2; // 1 second

                if (5 != demo_txt_idx)
                {
                    demo_txt_idx += 1; // _glbls[0x05]

                    // "GALAGA", "--SCORE--", etc
                    j_string_out_pe(1, -1, demo_txt_idx + 0x0D);

                    // checks for a sprite to display with the text
                    if (demo_txt_idx >= 3)
                    {
                        sprite_tiles_display(d_attrmode_sptiles_3 + 4 * idx_attrmode_sptiles_3);

                        idx_attrmode_sptiles_3++; // advance pointer to _attrmode_sptiles_3[n]
                    }
                    return;
                } // jr   z,l_19A7_end_switch
            }
            else
            {
                return; // ret  nz
            }
            break;

        default:
            break;
        } // l_19A7_end_switch:

        glbls9200.demo_idx++;
        if (glbls9200.demo_idx == 0x0F)
        {
            glbls9200.demo_idx = 0;
        }
    } // if (ATTRACT_MODE

    return;
}

/*=============================================================================
;; f_19B2()
;;  Description:
;;   Manage ship movement during capturing phase. There are two segments - in
;;   the first, the  ship movement simply tracks that of the capturing boss.
;;   Second, once the boss reaches position in the collective, the ship is
;;   moved vertically an additional 24 steps toward the top of the screen so
;;   that the final position is above the boss.
;;   Enabled by f_2222 tractor beam task when it terminates with the ship captured.
;;   When first called 928E==1 (show text flag), which will show the text and
;;   clear the flag.
;;   Noticed that once the ship is positioned in the collective, it may
;;   experience an additional small horizontal offset once its position begins
;;   to be managed by the collective positioning manager.
;; IN:
;;  ...
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
void f_19B2(void)
{

}

/*=============================================================================
;; f_1A80()
;;  Description:
;;   "Bonus-bee" manager.
;;   Not active until stage-4 or higher because the parameter is 0.
;; IN:
;;  ...
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
void f_1A80(void)
{

}

/*=============================================================================
;; f_1B65()
;;  Description:
;;   Manage bomber attacks, enabled during demo in ship-movement phase, as well
;;   as in training mode. Disabled at start of each round until all enemies are
;;   are in home position, then enabled for the duration of the round.
;; IN:
;;  ...
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
void f_1B65(void)
{
    uint8 A, B, L;

    // this task would not be enabled during times that the global enable is
    // 0 ... however if it WERE 0, it wouldn't be necessary to check if
    // fighter-rescue is progressing ...

    if (0 != glbls9200.glbl_enemy_enbl)
    {
        if (0 == (task_actv_tbl_0[0x15]) // f_1F04 (fire button input)
                ||
                (0 != task_actv_tbl_0[0x1D])) // f_2000 (destroyed boss that captured ship)
        {
            return; // ret  z
        }
    }

    // l_1B75: check the queue for boss+wing mission (4 groups of 3 bytes) ...
    // parameters are queue'd by 'case boss launcher'
    B = 4; // ld   b,#4
    L = 0; // ld   hl,#b_92C0 + 0x0A
    // l_1B7A:
    while (B > 0)
    {
        uint8 a, e;
        a = bmbr_boss_pool[L].obj_idx; // valid object index if slot active, otherwise $FF

        if (0xFF != a) // jr   nz,l_1B8B
        {
            // l_1B8B: launching element of boss+wing mission

            bmbr_boss_pool[L].obj_idx = 0xFF; // $FF disables the slot

            // bmbr_boss_pool[L].obj_idx
            e = a & ~0x80; // res  7,e ... if set then negate rotation angle to (ix)0x0C

            if (STAND_BY != sprt_mctl_objs[e].state) // disposition resting/inactive
            {
                return; // ret  nz
            }

            bmbr_setup_fltq_boss(a, bmbr_boss_pool[L].vectr); // L object index/offset, pDE is pointer to data

            b_9AA0[0x13] = 1; //  sound-fx count/enable registers, bug dive attack sound

            return;
        }
        else
        {
            L += 1; // inc  l  x3
            B -= 1;
        }
    } // end while ... djnz l_1B7A

    // insert a 1/4 sec delay before trying next bomber
    if (0 != (ds3_92A0_frame_cts[0] & 0x0F))
    {
        return;
    }
    // else ... jr   z,l_1BA8

    // l_1BA8: check each bomber type for ready status i.e. boss, red, yellow, red
    L = 0; // ld   hl,#b_92C0 + 0x00 ... boss is slot 0
    B = 3; // ld   b,#3 ... boss is case 3-1=2
    while (B > 0)
    {
        b_92C0_0[L] -= 1; // dec  (hl)

        if (0 == b_92C0_0[L]) break; // jr   z,l_1BB4

        L += 1; // inc  l
        B -= 1; // djnz l_1BAD ... argument to "switch" to select type of alien launched?
    }

    if (0 == B) return; // all through loop and none are ready

    // l_1BB4:
    if (b_bugs_flying_nbr >= ds_new_stage_parms[4]) // jr   c,l_1BC0
    {
        // maximum nbr of bombers reached, set slot-counter back to 1 since
        // it can't be processed right now and return
        b_92C0_0[L] = 1; // inc  (hl)
        return;
    }

    // l_1BC0: launch another bombing excursion
    b_92C0_0[L] = b_92C0_0[L + 4]; // set  2,l ... reset counter

    // B from loop l_1bad above decremented from 3
    A = B - 1; // dec  a ... offset for 0 based indexing of switch

    switch (A)
    {
    case 0:
    case 1:
    {
        uint16 pDEflv;
        if (A == 0) // _1BD7
        {
            // set yellow launch params
            //l_1BD7:
            B = 20; // number of yellow aliens
            L = 0x08; // first object offset
            pDEflv = _flv_d_atk_yllw;
        }
        else // if (A == 1) ... _1BF7
        {
            // set red launch params
            B = 16; // number of red aliens
            L = 0x40; // first object offset
            pDEflv = _flv_d_atk_red;
            // jr   l_1BDF
        }

        // l_1BDF: check for next red or yellow ready, skip if already active
        while (B > 0)
        {
            // test clone-attack parameter && object_status
            //jr   nz,l_1BEB_next

            if (STAND_BY == sprt_mctl_objs[L].state /* && L != bonus_bee_index */) // disposition == resting
            {
                // ld   a,c ; unstash A ... offset_to_bonus_bee
                // l_1BF0_found_one:
                b_9AA0[0x13] = 1; // A (from C) !0 ... sound-fx count/enable registers, bug dive attack sound
                bmbr_setup_fltq_drone(L, pDEflv); // offset, data ptr
                return;
            }
            // l_1BEB_next:
            L += 2;
            B -= 1; // djnz l_1BE3
        };
        break;
    }

    // _1C01: boss launcher ... only enable capture-mode for every other one ( %2 )
    case 2:
    {
        uint8 b, c, hl, de, ixh;

        // check capture-mode is active / capture-mode selection suppressed
        if (0 == plyr_state_actv.bmbr_boss_cflag)
        {
            // toggle bit-0 and check if capture mode should be enabled
            plyr_state_actv.cboss_enable += 1; // inc  (hl)
            if (0 == (0x01 & plyr_state_actv.cboss_enable)) // bit  0,(hl)
            {
                uint8 b;

                // object/index and parameters for capture-boss
                // ixl = 2
                // iy = db_0454
                de = 0x30; // bosses start at $30 ... object/index of bomber to _1CAE

                for (b = 0; b < 4; b++)
                {
                    if (STAND_BY == sprt_mctl_objs[de].state)
                    {
                        break; // jr   z,l_1C24_is_standby
                    }
                    de += 2; // increment pointer/offset
                } // djnz l_1C1B_while

                if ( b < 4 )
                {
                    //l_1C24_is_standby
                    plyr_state_actv.bmbr_boss_cflag = 1;
                    plyr_state_actv.bmbr_boss_cobj = de; // 0x30 + 2 * b
return; //HELP_ME_DEBUG
                    // b, c: only matters for escort selection (ixl != 2)
                    bmbr_boss_activate(de, 2, 0xFF, 0xFF, _flv_d_0454); // jp   j_1CAE ... capture boss
                }
                return;
            }
        }

//l_1C30
// already in capture-mode, or capture-mode select is suppressed this time ... look for a wingman
// get index of escort from d_1D2C, check if already flagged for "special" bomber plyr_state[0x0D].
        c = 0; // ld   bc,#6 * 256 + 0

        for (hl = 0; hl < 6; hl++)
        {
            de = d_bmbr_boss_wingm_idcs[hl];
            c <<= 1; // rl   c
            if (plyr_state_actv.bonus_bee_obj_offs != de) // jr   z,l_1C44
            {
                c |= (sprt_mctl_objs[de].state == STAND_BY);
            }
            // else l_1C44
        } // djnz l_1C38_while

        ixh = c; // ld   ixh,c

        // ld   ixl,#0 ... first pass: look for 2 adjoining red wingmen available
        for (b = 0; b < 4; b++)
        {
            uint8 a = c & 0x07; // groups of 3
            // if (a==3 || a==5 || a==6)
            if (4 != a && a >= 3) // if (a==3 || a==5 || a==6)  ... jr   z,l_1C5B
            {
                uint8 rv;
                rv = bmbr_boss_activate(0xFF, 0, 4 - b, c, 0xFFFF);  // this may pop the stack and return
                if (rv) return; // check ret and find a way to exit
            }
            // l_1C5B:
            c >>= 1; //rr   c
        } // djnz l_1C4F_while

        c = ixh; // ld   c,ixh

        // second pass: inc  ixl, look for 1 available wingman
        for (b = 0; b < 4; b++)
        {
            uint8 rv, a;
            a = c & 0x07;
            if (0 != a) // call nz,c_1C8D
            {
                rv = bmbr_boss_activate(0xFF, 1, 4 - b, c, 0xFFFF); // this may pop the stack and return
                if (rv) return; // check ret and find a way to exit
            }
            c >>= 1; //rr   c
        } // djnz l_1C65_while

        // third pass: inc  ixl, take any available boss
        for (b = 0; b < 4; b++)
        {
            uint8 rv, e;

            e = 0x30 + b * 2;

            if (STAND_BY == sprt_mctl_objs[e].state ) // jr   z,j_1CA0
            {
                rv = bmbr_boss_activate(e, 2, 4 - b, 0, 0xFFFF); // jr   z,j_1CA0 ... skip index selection
                if (rv) return; // check ret and find a way to exit
            }
        } // djnz l_1C76_while

        // last pass: no boss available ... check for available captured fighter (objects 00, 02, 04, 06)
        for (b = 0; b < 4; b++)
        {
            uint8 rv;

            if (STAND_BY == sprt_mctl_objs[0x00 + b * 2].state ) // jr   z,j_1CA0
            {
//                rv = c_1D25(2, b); // this may pop the stack and return
                if (rv) return; // check ret and find a way to exit
            }
        } // djnz l_1C76_while

        break;
    }
    default:
        break;
    }

    return;
}

/*=============================================================================
;; c_1C8D()
;;  Description:
;;   Attempt to activate bomber-boss and selects wingman if available.
;;   Instead of creating a separate function for l_1CA0, E is used with a
;;   sentinel value (0xFF - invalid object/index) to force escort selection
;;   (logic is to avoid duplication of C code does not exist in z80).
;; IN:
;;  B: 4,3,2,1 to select object/index of bomber
;;  C: flags for escorts available (only for pass-thru to _boss_wingm_go, if doing wingman setup)
;;  D: pre-loaded with lsb of pointer to objects array
;;  E: object/index of bomber-boss candidate if jp 1CA0 taken, 0xFF triggers wingman selection
;;  IXL: 2==capture_boss, 0==2_wingmen, 1==1_wingman
;;  flv: use $ffff to trigger vector selection
;; OUT:
;;  ...
;; RETURN:
;;  0 call failed to select escort and caller should continue selection process
;;  1 simulates stack and jp tricks in z80 to expediently end the periodic task
;;
;;---------------------------------------------------------------------------*/
static uint8 bmbr_boss_activate(uint8 e, uint8 ixl, uint8 b, uint8 c, uint16 flv)
{
    uint16 iy;
    uint8 Cy, hl;

    iy = flv;

    if (0xFFFF == flv)
    {
        if (0xFF == e)
        {
            uint8 a;
            /*
              convert ordinal in B (i.e. 4,3,2,1) to object/index ... in home-position order (left to right)
               3 -> 2 -> 2 -> $34
               2 -> 3 -> 3 -> $36
               1 -> 1 -> 1 -> $32
               0 -> 0 -> 0 -> $30
            */
            a = b;
            if (a & 0x02) // bit  1,a ... jr   z,l_1C94
            {
                a ^= 0x01; // xor  #0x01
            }
            //l_1C94:
            a &= 0x03;
            e = (a << 1) + 0x30; // object/index of bomber

            if (STAND_BY != sprt_mctl_objs[e].state) // cp   #0x01
            {
                return 0; // ret  nz
            }
        }
        // l_1CA0:
        if (0 != glbls9200.glbl_enemy_enbl)
        {
            iy = _flv_d_0411;
        }
        else
        {
            iy = _flv_d_00f1; // training-mode
        }
    }

    // j_1CAE:

    Cy = (0 != (e & 0x02)); // ex   af,af' ... stash Cy for rotation flag

    // objects 32 & 36 are on right side (bit-1 set): set flag in bit-7 to
    // indicate negative rotation (flag in Cy)
    bmbr_boss_pool[0].obj_idx = (Cy  << 7) | (e & 0x7F);

    bmbr_boss_pool[0].vectr = iy;

    // inc  b

// plyr_actv.bmbr_boss_scode[(e & 0x07) + 0] = d_1CFD[ixl*2+0];
// plyr_actv.bmbr_boss_scode[(e & 0x07) + 1] = d_1CFD[ixl*2+1];


    if (2 != ixl)
    {
        r16_t flags;
        uint8 idx;

        flags.word = 0;
        flags.pair.b1 = c;
        idx = b + 1; // inc  b

        // setup 1 or 2 escorts
        bmbr_boss_escort_sel(iy, 1, &idx, &flags, Cy);

        if (1 != ixl) bmbr_boss_escort_sel(iy, 2, &idx, &flags, Cy);
    }

    //l_1CE3:  if rogue fighter for this boss !STAND_BY then return
    hl = bmbr_boss_pool[0].obj_idx & 0x07;

    if (STAND_BY == sprt_mctl_objs[hl].mctl_idx)
    {
        // find available slot (don't know how many are occupied by escorts)
        for (hl = 1; hl < 4; hl++) // z80 doesn't bother with this bounds check
        {
            if (0xFF == bmbr_boss_pool[hl].obj_idx)  break;
        } // jr   nz,l_1CF2_while

        if (hl >= 4)  return 1;

        // setup A and Cy' parameters (HL, IY already loaded)
        //  A  - object/index of captured fighter
        //  HL - &_boss_pool[n] ... n = { 3, 6, 9  }
        //  IY - pointer to flight vector data

        // l_1D16:
        bmbr_boss_pool[hl].obj_idx = (Cy  << 7) | (bmbr_boss_pool[0].obj_idx & 0x07);
        bmbr_boss_pool[hl].vectr = iy;
    }

    return 1;
}

/*=============================================================================
;; data for c_1C8D (could be scoped locally to subroutine):
;; override bonus/score attribute in ds_plyr_actv._ds_array8[] for 3 of 4 bosses
;; .b0 ... add to bug_collsn[$0F] (adjusted scoring increment)
;; .b1 -> obj_collsn_notif[L] ... sprite code + 0x80
;;---------------------------------------------------------------------------*/
static const uint8 d_1CFD[] =
{
    16 - 3, 0x80 + 0x3A,  // 1600
     8 - 3, 0x80 + 0x37,  // 800
     4 - 3, 0x80 + 0x35   // 400 (default)
};

/*=============================================================================
;; bmbr_boss_escort_sel()
;;  Description:
;;   c_1D03 - select next escort in the queue
;;   duplicates section at l_1D16 for simplicity
;;   would be cleaner if incorporated logic for 1/2 spawned to avoid pointers
;; IN:
;;  B:   index to const array of escort object/id
;;  C:   flags for escorts available
;;  IY:  pointer to flight vector data
;;  DE:  index to _boss_pool[n] ... n = {1, 2}
;;  Cy': rotation flag, to be OR'd into pool_slot[n].idx<7>
;; OUT:
;;
;;---------------------------------------------------------------------------*/
static void bmbr_boss_escort_sel(uint16 iy, uint8 de, uint8 *b, r16_t *c, uint8 Cy)
{
    uint8 a = 0;

    c->word >>= 1; // rrc  c

    if (0 == (0x80 & c->pair.b0)) // jr   c,l_1D0D
    {
        *b -= 1; // dec  b
        c->word >>= 1; // rrc  c

        if (0 == (0x80 & c->pair.b0)) // jr   c,l_1D0D
        {
            *b -= 1; // dec  b
        }
    }

    a = d_bmbr_boss_wingm_idcs[*b]; // ld   a,b
    *b -= 1; // dec  b

    // l_1D16:
    bmbr_boss_pool[de].obj_idx = (Cy  << 7) | (a & 0x7F);
    bmbr_boss_pool[de].vectr = iy;
}

/*=============================================================================
;;  indices of 6 red aliens that rest under the 4 bosses for wingmen selection

 demo layout:
      0x34         0x30         0x32         0x36
                                    0x4A 0x58    0x52
;;---------------------------------------------------------------------------*/
static const uint8 d_bmbr_boss_wingm_idcs[] =
{
    0x4A,0x52,0x5A,0x58,0x50,0x48
};

/*=============================================================================
;; f_1D32()
;;  Description:
;;   Moves bug nest on and off the screen at player changeover.
;; IN:
;;  ...
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
void f_1D32(void)
{

}

/*=============================================================================
;; f_1D76()
;;  Description:
;;   handles changes in star control status?
;; IN:
;;  ...
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
void f_1D76(void)
{

}

/*=============================================================================
;; f_1DB3() ... 0x0B
;;  Description:
;;   monitor sprite object hit-notification registers
;;   collision detection is flagged in c_076A by setting the value to $81
;;
;;   this task is disabled only when the default task config is
;;   re-loaded from ROM (g_init_taskman_defs) just prior to the Top5
;;   screen shown in attract-mode.
;;
;; IN:
;;  ...
;; OUT:
;;
;;---------------------------------------------------------------------------*/
void f_1DB3(void)
{
    uint8 L = 0;

    // L*2 to maintain z80 indexing in array
    for(L = 0; L < 0x60; L += 2)
    {
        // bit  7,(hl) ... bit-7 set by cpu1:c_076A if the orc has been hit
        if (0 != (0x80 & sprt_hit_notif[ L ]))
        {
            sprt_hit_notif[ L ] &= ~0x80; // res  7,(hl)

            sprt_mctl_objs[ L ].state = EXPLODING; // procdess hit-notification

            // explosion count
            sprt_mctl_objs[ L ].mctl_idx = 0x40; // ld   (hl),#0x40

            // update color for inactive/dead sprite
            mrw_sprite.cclr[ L ].b1 = 0x0A; // "glowing" prior to explosion
        } // jr   l_1DBD
    }
}

/*=============================================================================
;; f_1DD2()
;;  Description:
;;   Updates array of 4 timers at 2Hz rate.
;; IN:
;;  ...
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
void f_1DD2(void)
{
    // divides the 4 Hz timer by 2 ... why not just use frame_cts[1]?
    if (0 != (ds3_92A0_frame_cts[2] & 0x01)) return;

    if (ds4_game_tmrs[0] > 0) ds4_game_tmrs[0] -= 1;
    if (ds4_game_tmrs[1] > 0) ds4_game_tmrs[1] -= 1;
    if (ds4_game_tmrs[2] > 0) ds4_game_tmrs[2] -= 1;
    if (ds4_game_tmrs[3] > 0) ds4_game_tmrs[3] -= 1;
}

/*=============================================================================
;; f_1DE6()
;;  Description:
;;   Provides pulsating movement of the formation.
;;   Enabled by f_2A90 once the initial attack waves have completed.
;; IN:
;;  ...
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
void f_1DE6(void)
{
    uint8 A, Cy;

    // only performed every 1/4th frame (15hz)
    if ((ds3_92A0_frame_cts[0] % 4) != 0)
    {
        return;
    }

    A = glbls9200.bug_nest_direction_lr; // prev formation direction counter

    if (0 == (glbls9200.bug_nest_direction_lr & 0x80)) // bit  7,a
    {
        glbls9200.formatn_mv_signage = 1; // expanding
    }
    else
    {
        glbls9200.formatn_mv_signage = -1; // contracting
    }

    glbls9200.bug_nest_direction_lr += glbls9200.formatn_mv_signage;

    // l_1DFD:
    if (A == 0x1F)
    {
        // counting up from $00 to $1F
        glbls9200.bug_nest_direction_lr |= 0x80; // set  7,(hl) ... = $A0
    }
    if (A == 0x81)
    {
        // counting down from $A0 to $81 (-$60 to -$7F)
        glbls9200.bug_nest_direction_lr &= ~0x80; // res  7,(hl) ... = $00
    }

    // Every 8*4 (32) frames, select the bitmap to determines positions to be
    // updated ... corresponds with "flapping" animation... ~1/2 second per flap.

    if (0 == (A & 0x07)) // and  #0x07
    {
        uint8 B, iA;

        // divide by 8 to provide an index of 0:3 to the 2D table
        iA = (glbls9200.bug_nest_direction_lr & 0x18) / 8; // ld   a,c ...

        //   ldir
        for (B = 0; B < 16; B++)
        {
            fmtn_expcon_cinc_curr[B] = fmtn_expcon_cinc_bits[iA][B];
        }
    }

    // l_1E23: determines which parameter is taken. Bit-7 XOR'd with flip_screen-bit
    Cy = (0 != (A & 0x80)) ^ glbls9200.flip_screen;

    if (0 != Cy)
    {
        // BC = 0x01FF, contracting
        fmtn_expcon_comp(1, 0, 0x05); // left-most 5 columns
        fmtn_expcon_comp(-1, 5, 0x0B); // rightmost 5 columns and the 6 row coordinates
    }
    else // l_1E36
    {
        // BC = 0xFF01, expanding
        fmtn_expcon_comp(-1, 0, 0x05); // left-most 5 columns
        fmtn_expcon_comp(1, 5, 0x0B); // rightmost 5 columns and the 6 row coordinates
    }
}

/*=============================================================================
;; fmtn_expcon_comp()
;;  Description:
;;   Compute row/col coordinates of formation in expand/contract movement.
;;   The selected bitmap table determines whether any given coordinate
;;   dimension is incremented at this update.
;; IN:
;;    B ==  +/- 1 increment
;;    offs: offset into bitmap table, i.e. either 0 or 5
;;    cnt:
;;        5 if negative increment i.e. left 5 columns
;;        11 if positive increment i.e. right 5 columns and 6 rows
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
void fmtn_expcon_comp(uint8 B, uint8 offs, uint8 cnt)
{
    uint8 IXL = 0;

    // j_1E43
    for (IXL = 0; IXL < cnt; IXL++)
    {
        uint8 Cy;

        // rrc  (hl)
        Cy = fmtn_expcon_cinc_curr[offs + IXL];
        Cy &= 0x01;
        fmtn_expcon_cinc_curr[offs + IXL] >>= 1;
        fmtn_expcon_cinc_curr[offs + IXL] |= (Cy << 7);

        // jr   nc,l_1E5C_update_ptrs
        if (Cy)
        {
            fmtn_hpos.offs[(offs + IXL) * 2 ] += B;

            // 10 column coordinates, 6 row coordinates, 16-bits per coordinate
            fmtn_hpos.spcoords[ (offs + IXL) * 2 ].word += B;
            fmtn_hpos.spcoords[ (offs + IXL) * 2 ].pair.b1 = 0; //for now, MSB not needed for non-inverted screen
        }
    }
}

/*=============================================================================
;; fmtn_expcon_cinc_bits
;;  Description:
;;   bitmaps determine at which intervals the corresponding coordinate will
;;   be incremented... allows outmost and lowest coordinates to expand faster.
;;
;;   |<-------------- COLUMNS --------------------->|<---------- ROWS ---------->|
;;
;;---------------------------------------------------------------------------*/
static uint8 fmtn_expcon_cinc_bits[][16] =
{
    {
        0xFF, 0x77, 0x55, 0x14, 0x10, 0x10, 0x14, 0x55, 0x77, 0xFF, 0x00, 0x10, 0x14, 0x55, 0x77, 0xFF
    },
    {
        0xFF, 0x77, 0x55, 0x51, 0x10, 0x10, 0x51, 0x55, 0x77, 0xFF, 0x00, 0x10, 0x51, 0x55, 0x77, 0xFF
    },
    {
        0xFF, 0x77, 0x57, 0x15, 0x10, 0x10, 0x15, 0x57, 0x77, 0xFF, 0x00, 0x10, 0x15, 0x57, 0x77, 0xFF
    },
    {
        0xFF, 0xF7, 0xD5, 0x91, 0x10, 0x10, 0x91, 0xD5, 0xF7, 0xFF, 0x00, 0x10, 0x91, 0xD5, 0xF7, 0xFF
    }
};

/*=============================================================================
;; f_1EA4()
;;  Description:
;;    Bomb position updater... this task is not disabled.
;; IN:
;;  ...
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
void f_1EA4(void)
{
    uint8 ixh, ixl, hl;

    ixh = (ds3_92A0_frame_cts[0] & 0x01) + 2;

    if (0 != glbls9200.flip_screen)
    {
        ixh = -((ds3_92A0_frame_cts[0] & 0x01) + 2); // neg
    }
    ixl = 8; // loop ct
    hl = 0;

    //bomb_xcoords[a].
    while(ixl > 0)
    {
        if (0x30 == mrw_sprite.cclr[SPR_IDX_BOMB0 + hl * 2].b0
                && 0x00 != mrw_sprite.posn[SPR_IDX_BOMB0 + hl * 2].b0)
        {
            r16_t tmp16;
            uint8 a, c;

            c = bomb_hrates[hl * 2].pair.b1 + (bomb_hrates[hl * 2].pair.b0 & 0x7E);
            bomb_hrates[hl * 2].pair.b1 = c & 0x1F;
            a = c >> 5;

            if (0 != (0x80 & bomb_hrates[hl * 2].pair.b0)) // bit  7,b
            {
                // use negative offset of X coordinate if bomb path is to the left
                a = -a; // neg
            }

            // update X
            mrw_sprite.posn[SPR_IDX_BOMB0 + hl * 2].b0 += a; // add  a,(hl)

            // update Y
            tmp16.word = mrw_sprite.posn[SPR_IDX_BOMB0 + hl * 2].b1; // Y<7:0>
            tmp16.pair.b1 = mrw_sprite.ctrl[SPR_IDX_BOMB0 + hl * 2].b1 & 0x01;
            tmp16.word += ixh;
            mrw_sprite.posn[SPR_IDX_BOMB0 + hl * 2].b1 = tmp16.pair.b0;
            mrw_sprite.ctrl[SPR_IDX_BOMB0 + hl * 2].b1 |= tmp16.pair.b1 & 0x01;
        }
        hl += 1;
        ixl -= 1; // dec  ixl
    }
}

/*=============================================================================
;; f_1F04()
;;  Description:
;;   Read fire button input.
;;   The IO port is determined according to whether or not the screen is flipped.
;;   The button state is read from bit-4. Based on observation in the MAME
;;   debugger, it appears that the IO control chip initially places the value
;;   $1F on the port (bit-5 pulled low), and then some time following that bit-4
;;   is pulled low ($0F). Presumably this is provide a debounce feature. If
;;   there is no activity on either the button or the left-right control, then
;;   the value read from the port is $3F.
;; IN:
;;  ...
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
void f_1F04(void)
{
    if (0 != (io_input[0x01] & 0x10))
    {
        return;
    }
    rckt_sprite_init();
}

/*=============================================================================
;; rckt_sprite_init()
;;  Description:
;;   Intialize sprite objects for rockets.
;;   rocket sprite.cclr[n].b0 is initialized by c_game_or_demo_init
;;   Updates game shots fired count.
;; IN:
;;  ...
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
static void rckt_sprite_init(void)
{
    uint8 *pushDE; // pointer to rocket attribute fighter 1 or 2
    uint8 A, B, C, E;

    if (0 == mrw_sprite.posn[SPR_IDX_RCKT0].b0)
    {
        // object != active
        pushDE = &b_92A4_rockt_attribute[0];
        E = SPR_IDX_RCKT0;

        // jr   z,l_1F1E
    }
    else if (0 == mrw_sprite.posn[SPR_IDX_RCKT1].b0)
    {
        // object != active
        pushDE = &b_92A4_rockt_attribute[1];
        E = SPR_IDX_RCKT1; // inc  e
    }
    else
        return; // ret  nz ... no rocket available

    // l_1F1E:

    // bit  2,(hl)                                ; no idea
    // jr   z,l_1F2B

    mrw_sprite.ctrl[E].b1 = mrw_sprite.ctrl[SPR_IDX_SHIP].b1; // ship.sy, bit-8

    mrw_sprite.posn[E].b0 = mrw_sprite.posn[SPR_IDX_SHIP].b0; // ship.sX
    mrw_sprite.posn[E].b1 = mrw_sprite.posn[SPR_IDX_SHIP].b1; // ship.sY, bit 0-7

    // rocket[n].ctrl.b0 = (two_ship << 3 ) | ship.code.b0
    mrw_sprite.ctrl[E].b0 = 0;

    // determine rocket sprite code based on ship sprite code
    A = mrw_sprite.cclr[SPR_IDX_SHIP].b0;
    A &= 0x07; // ship sprite should not be > 7 ?

    if (A >= 5)
    {
        // set_rocket_sprite_code:
        mrw_sprite.cclr[E].b0 = 0x30; // 360 degree default orientation
    }
    else if (A >= 2)
    {
        // set_rocket_sprite_code:
        mrw_sprite.cclr[E].b0 = 0x31; // 45 degree rotation
    }
    else
    {
        // set_rocket_sprite_code:
        mrw_sprite.cclr[E].b0 = 0x33; // 90 degree rotation (code $32 is skipped ... also 360)
    }

    // Displacement in both X and Y axis must be computed in order to launch rockets
    //    code= 6     dS=0      $40     ... 7 - (6+1)
    if (A >= 4)
    {
        // add orientation bit (bit-6)
        A = 7 - (A + 1) + 0x40;
    }
    // else ... no orientation swap needed, use sprite code for dS

    C = A << 1; // "orientation" bit into bit-7 ...

    // sprite.ctrl bits ...  flipx into bit:5, flipy into bit:6
    B = (mrw_sprite.ctrl[SPR_IDX_SHIP].b0 << 5) & 0x60;

    if (0 == glbls9200.flip_screen)
    {
        // screen not flipped so invert those bits
        A = B ^ 0x60;
    }
    // l_1F71:
    // pointer to rocket attribute
    *pushDE = A | C; // bit7=orientation, bit6=flipY, bit5=flipX, 1:2=displacement

    sprt_mctl_objs[E].state = BOMB; // disposition: active rocket object

    b_9AA0[0x0F] = 1; // sound-fx count/enable, shot-sound

    // game shots fired count+=1 (2 bytes) ... ds_9820_actv_plyr_state[0x26]
}

/*=============================================================================
;; f_1F85()
;;  Description:
;;   Handle changes in controller IO Input bits, update ship movement.
;;   (Called continuously in game-play, but also toward end of demo starting
;;   when the two ships are joined.)
;; IN:
;;  ...
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
void f_1F85(void)
{
    uint8 A;

    /*
           ld   a,(ds_9820_actv_plyr_state + 0x07)    ; actv_plyr_is_two_ship
           ld   e,a

    ; read from io_input[1] or io_input[2] depending whether screen is flipped.
           ld   a,(b8_9215_flip_screen)
           add  a,#<ds3_99B5_io_input + 1             ; set LSB of pointer
           ld   l,a
           ld   h,#>ds3_99B5_io_input                 ; set the MSB
           ld   a,(hl)
     */
    A = io_input[1];

    fghtr_ctrl_inp(A);
}

/*=============================================================================
;; fghtr_ctrl_inp()
;;  Description:
;;   fighter control input
;;   Skip real IO input in the demo.
;;
;;   The dX.flag determines the movement step (dX): when the ship movement
;;   direction is changed, dX is 1 pixel increment for 1 frame and then 2 pixel
;;   step thereafter as long as the control stick is held continously to the
;;   direction. If the stick input is neutral, dX.flag (b_92A0[3]) is cleared.
;;
;;   In a two-ship configuration, the position is handled with respect to the
;;   left ship... the right limit gets special handling accordingly.
;;
;; IN:
;;   inbits == IO input control bits
;;        8 ---> R
;;        2 ---> L
;;   E == actv_plyr_state[7]  ... double ship flag
;;
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
static void fghtr_ctrl_inp(uint8 inbits)
{
    uint8 dxinc; // move increment

    if ((inbits & 0x0A) == 0x0A) // inputs are active low, neither left or right active
    {
        // l_1FCF_no_input:
        fghtr_ctrl_dxflag = 0;
        return;
    }

    // invert the input bits if screen flipped (swap L/R direction)

    // set ship.dX (1 or 2)
    // l_1FA1_set_ship_dx:
    dxinc = 1; // ld   c,#1

    // toggle fghtr_ctrl_dxflag
    fghtr_ctrl_dxflag ^= 1;

    if (0 == fghtr_ctrl_dxflag) dxinc += 1;

    // l_1FAE_handle_input_bits:
    if (0 == mrw_sprite.posn[SPR_IDX_SHIP].b0) return;

    if (0 == (inbits & 0x02)) // input.right, else ... jr   nz,l_1FC7_test_l
    {
        if (mrw_sprite.posn[SPR_IDX_SHIP].b0 >= 0xD1) // jr   c,l_1FC0_test_r
        {
            // moving right: check right limit for double-ship

            // if double ship, return
            if (0 != plyr_state_actv.plyr_is_2ship) // bit  0,e
            {
                return;
            }
        }
        // l_1FC0_test_rlmt_single:
        if (mrw_sprite.posn[SPR_IDX_SHIP].b0 >= 0xE1) // cp   #0xE1
        {
            return;
        }
        // add dX for right direction
        mrw_sprite.posn[SPR_IDX_SHIP].b0 += dxinc; // add  a,c

        // jr   l_1FD4_update_two
    }
    else // test left limit
    {
        if (mrw_sprite.posn[SPR_IDX_SHIP].b0 < 0x12) // "main" fighter (single) position
        {
            return;
        }
        mrw_sprite.posn[SPR_IDX_SHIP].b0 -= dxinc; // sub  c

        // jr   l_1FD4_update_two_
    }

    // l_1FD4_update_two_:
    if (0 == plyr_state_actv.plyr_is_2ship)  return;

    mrw_sprite.posn[SPR_IDX_SHIP].b0 += 0x0F; // add  a,#0x0F
}
