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
t_mrw_sprite mrw_sprite;

uint8 b_92A4_rockt_attribute[2]; // ref'd in gg1-5.c
uint8 b_92C0_0[0x0A]; // idfk ...  (size <= 10)
uint8 b_92C0_A[0x10]; // machine cfg params?


/*
 ** static external definitions in this file
 */
// variables
static uint8 d_1E64_bitmap_tables[];
static uint8 ds10_9920[16];
static uint8 b8_demo_scrn_txt_indx;
static uint8 const *pdb_demo_state_params;
static uint8 ship_dX_flag;

// function prototypes
static void c_1E43(uint8, uint8, uint8);
static void c_1F92(uint8);


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
static const uint8 d_1928_demo_state_params[] =
{
    0x08, 0x1B, 0x81, 0x3D, 0x81, 0x0A, 0x42, 0x19, 0x81, 0x28, 0x81, 0x08,
    0x18, 0x81, 0x2E, 0x81, 0x03, 0x1A, 0x81, 0x11, 0x81, 0x05, 0x42, 0xC0
};


/*=============================================================================
;; f_1700()
;;  Description:
;;   Ship-update in training/demo mode, enabled in main (one time init) for
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
    uint8 A, E;

    // A not needed here, but it's easier to digest
    A = (*pdb_demo_state_params >> 5) & 0x07; // rlca * 3

    switch(A)
    {
    case 0x02: // 171F:
        if ( 0 == (ds3_92A0_frame_cts[0] & 0x0F))
        {
            glbls9200.training_mode_flag_07 -= 1;
            if ( 0 != glbls9200.training_mode_flag_07)
            {
                return;
            }
        }
        // else ret  nz

        // jp   case_1766
        // (break)

    case 0x00: // 1766:
    case 0x01: // 1766:
    case 0x03: // 1766:
    {
        if ( 0x80 == (0xC0 & *pdb_demo_state_params))
        {
            pdb_demo_state_params += 1; // inc  de
        }
        //l_1772:
        pdb_demo_state_params += 1; // inc  de

        // A not needed, but easier to chew that way
        A = (*pdb_demo_state_params >> 5) & 0x07;

        switch(A)
        {
        case 0:  // case_1794
        case 1:  // case_1794
            // rlca ... note, mask makes shift into <:0> through Cy irrelevant
            A = *pdb_demo_state_params << 1;
            glbls9200.training_mode_flag_09 = A & 0x7E;
            break; // ret

            // done!
        case 6:  // case_179C
            task_actv_tbl_0[0x03] = 0; // this task
            break; // ret

        case 2:  // case_17A1
            // A not needed but help makes it obvious
            A = *pdb_demo_state_params & 0x1F;
            //l_17A4:
            glbls9200.training_mode_flag_07 = A;
            break; // ret

        case 3:  // case_17A8
            // A not needed but help makes it easy to understand for nooobz
            A = *pdb_demo_state_params & 0x1F;
//       ld   c,a
//       rst  0x30                                  ; string_out_pe
            break; // ret

            // fighter has appeared in training mode
        case 4:  // case_17AE
        case 5:  // case_17AE
            // A not needed but help makes it obvious
            A = *(pdb_demo_state_params + 1); //

            //jr   l_17A4
            //l_17A4:
            glbls9200.training_mode_flag_07 = A;
            break; // ret

        default:
            break;
        }
        break;
    }

    case 0x05: // 172D:
        break;

    case 0x04: // 1734:
        A = *pdb_demo_state_params;
        E = plyr_state_actv.plyr_is_2ship; // setup E for c_1F92

        if ( 0 == (A & 0x01)) // bit  0,a
        {
            A &= 0x0A;
            //jr   l_1755
        }
        else // jr   nz,l_1741
        {
            uint8 L;
            L = glbls9200.training_mode_flag_09;

            A = 0x0A;
            if (mrw_sprite.posn[SPR_IDX_SHIP].b0 != mrw_sprite.posn[L].b0) // sub  (hl)
            {
                A = 8;
            }
            else if (mrw_sprite.posn[SPR_IDX_SHIP].b0 > mrw_sprite.posn[L].b0)
            {
                A = 2;
            }
        }
        // l_1755:
        //c_1F92();
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
                j_string_out_pe(1, -1, 2); // string_out_pe ("GAME OVER")
            }
            break;

        case 0x0A: // l_1808
            // boss with captured-ship has just rejoined fleet in demo
            break;

        case 0x0C: // l_1840
            // one time at end of demo, just before "HEROES" displayed, ship has been
            // erased from screen but remaining bugs may not have been erased yet.
            break;

        case 0x08: // l_1852
            // one time init for demo (followinig training mode): just cleared the screen with "GAME OVER" shown
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
                b_9200_obj_collsn_notif[0x34] = 0x34;
                ds4_game_tmrs[2] = 9;
                return;
            }

            break;

            // ship just appeared in training mode (state active until f_1700 disables itself)
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
            // one time init for 7 bugs in training mode
            B = 0;
            while (B < 7)
            {
                sprite_tiles_display(d_attrmode_sptiles_7 + B * 4);
                B += 1;
            }

            plyr_state_actv.num_ships = 0;
            task_actv_tbl_0[0x05] = 0; // f_0857
            c_133A_show_ship();

            b_92C0_0[0x05] = 0xFF; // idfk
            b_92C0_0[0x04] = 0x0D; // idfk
            b_92C0_0[0x01] = 0xFF; // idfk
            b_92C0_0[0x00] = 0x0D; // idfk

            pdb_demo_state_params = d_1928_demo_state_params;

            memset(b_92C0_A, 0, 0x10);

            plyr_state_actv.plyr_is_2ship = 0; // not 2 ship
            glbls9200.flying_bug_attck_condtn = 0;
            plyr_state_actv.captur_boss_dive_flag = 1;

//            task_actv_tbl_0[0x10] = 1; //  f_1B65 ... manage flying-bug-attack
            task_actv_tbl_0[0x0B] = 1; //  f_1DB3 ... checks enemy status at 9200
            task_actv_tbl_0[0x03] = 1; //  f_1700 ... ship-update in training/demo mode

            //from DSWA "sound in attract mode"
            b_9AA0[0x17] = 1; // (_sfr_dsw4 >> 1) & 0x01;

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
            b8_demo_scrn_txt_indx = 0;
            w_bug_flying_hit_cnt = 0;
            ds4_game_tmrs[2] = 2; // 1 second
            break; // jr   l_19A7_end_switch

        case 0x02: // l_1984
            if (0 == ds4_game_tmrs[2])
            {
                ds4_game_tmrs[2] = 2; // 1 second

                if (5 != b8_demo_scrn_txt_indx)
                {
                    b8_demo_scrn_txt_indx += 1; // _glbls[0x05]

                    // "GALAGA", "--SCORE--", etc
                    j_string_out_pe(1, -1, b8_demo_scrn_txt_indx + 0x0D);

                    // checks for a sprite to display with the text
                    if (b8_demo_scrn_txt_indx >= 3)
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

// pdb_demo_state_params
// _1928 ...training mode
const uint8 d_181F[] =
{
    0x08,0x18,0x8A,0x08,0x88,0x06,0x81,0x28,0x81,0x05,0x54,0x1A,0x88,0x12,0x81,0x0F,
    0xA2,0x16,0xAA,0x14,0x88,0x18,0x88,0x10,0x43,0x82,0x10,0x88,0x06,0xA2,0x20,0x56,0xC0
};

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
;;   Manage flying-bug-attack
;;   In the demo, the task is first enabled as the 7 goblins appear in the
;;   training mode screen. At that time, the 920B flag is 0.
;;   The task starts again for diving attacks in the demo, the flag is then 1.
;;
;;   This is enabled at the end of f_2916 when the new-stage attack waves are complete.
;; IN:
;;  ...
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
void f_1B65(void)
{
    uint8 const* pDE;
    uint8 A, B, L;

    if ( 0 != glbls9200.flying_bug_attck_condtn
            &&
            (0 == task_actv_tbl_0[0x15]) // f_1F04 (fire button input)
            &&
            (0 != task_actv_tbl_0 + 0x1D)) // f_2000 (destroyed boss that captured ship)
    {
        return;
    }

    // l_1B75: check 4 bytes in groups of 3
    B = 0; // ld   b,#4
    L = 0; // ld   hl,#b_92C0 + 0x0A
    // l_1B7A:
    while ( B < 4 )
    {
        A = b_92C0_A[L];
        if (0xFF == A) // jr   nz,l_1B8B
        {
            L += 3;
            B += 1;
        }
        else
        {
            // for both moth and bee, a sortie is ended when returned to base-position, or destroyed
            // l_1B8B:
            b_92C0_A[L] = 0xFF;
            b8800_obj_status[A].state &= ~0x80; // res  7,e
            if ( 1 != b8800_obj_status[A].state)
            {
                return; // ret  nz
            }
            L += 1;

            //ld   e,(hl)
            //inc  l
            //ld   d,(hl)                                ; e.g. DE==0411
            //ex   af,af'                                ; restore A (byte-0 of b_92C0_A[L + n*3] )
            //ld   l,a
            //ld   h,#>b_8800                            ; e.g. b_8800[$30]
            c_1079(L, pDE); // L object index/offset, pDE is pointer to data
            b_9AA0[0x13] = 1; //  sound-fx count/enable registers, bug dive attack sound
            return;
        }
    } // end while

    if (0 != (ds3_92A0_frame_cts[0] & 0x0F))
    {
        return;
    }


    // l_1BA8:
    B = 3; // ld   hl,#b_92C0 + 0x00
    while ( B > 0)
    {
        L = 3 - B;
        b_92C0_0[L] -= 1;
        if (0 == b_92C0_0[L])
            break; // jr   z,l_1BB4
        B -= 1; // djnz l_1BAD
    }
    if (0 == B)
        return;

    // l_1BB4:
if ( b_bugs_flying_nbr > 0 ) // tmp: only 1 alien (red) because the yellow one goes in the weeds
//    if ( b_bugs_flying_nbr > ds_new_stage_parms[4] ) // max_flying_bugs_this_rnd
    {
        // maximum nbr of bugs already flying
        b_92C0_0[L] += 1; // inc  (hl)
        return;
    }

    // launch another flying bug
    b_92C0_0[L] =  b_92C0_0[L + 4]; // set  2,l etc.

    A = B - 1; // dec  a

    switch(A)
    {
    case 0:
    case 1:
        if (A == 0)
        {
            // set bee launch params
            //l_1BD7:
            B = 20; // number of yellow aliens
            L = 0x08; // first object offset
            pDE = dbx034F;
        }
        else // if (A = 1)
        {
            // set red moth launch params
            B = 0x10; // number of red aliens
            L = 0x40; // first object offset
            pDE = dbx03A9;
            // jr   l_1BDF
        }

        // this section common to both bee and moth launcher, check for next one, skip if already active
        //l_1BDF:
        while ( B > 0 )
        {
            // load bonus-bee parameter

            // test bonus-bee parameter && object_status
            //jr   nz,l_1BEB_next
            if ( 1 == b8800_obj_status[L].state /* && L != bonus_bee_index */ ) // // 1 == resting
            {
                // ld   a,c ... C==offset_to_bonus_bee
                // l_1BF0_found_one:
                b_9AA0[0x13] = 1; // A (from C) !0 ... sound-fx count/enable registers, bug dive attack sound
                c_1083(L, pDE); // offset, data ptr
                return;
            }
            // l_1BEB_next:
            L += 2;
            B -= 1; // djnz l_1BE3
        };
        // djnz l_1BE3
        break;

        // boss launcher... we only enable capture-mode for every other one ( %2 )
    case 2:
    default:
        break;
    }

}

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
;;   Update enemy status.
;;   When orcs are destroyed, their flag at 9200[i] is set by cpu1:c_076A to
;;   $81. Here we detect and reset bit-7.
;;
;;   The only time this one is disabled is when the default task config is
;;   re-loaded from ROM (c_1230_init_taskman_structs) just prior to the Top5
;;   screen shown in attract-mode.
;;
;;   Here's a diagram showing the memory structure of the evil orc army at 9200:
;;
;;                         00 04 06 02            ; captured ships
;;                         30 34 36 32
;;                   40 48 50 58 5A 52 4A 42
;;                   44 4C 54 5C 5E 56 4E 46
;;                08 10 18 20 28 2A 22 1A 12 0A
;;                0C 14 1C 24 2C 2E 26 1E 16 0E
;;
;;
;; for 9200 evens, $81 is hit notification by cpu1:c_076A , and $01 is hit
;;  acknowledge by f_1DB3.
;;
;; at 8800, same structure, however data values are different.
;; Evens: "activity" byte (see d_23FF_jp_tbl for codes)
;; Odds: ? (40...45 if exploding)
;;
;; for sprite code/color 8B00, evens are sprite code and odds are sprite color
;; IN:
;;  ...
;; OUT:
;;
;;---------------------------------------------------------------------------*/
void f_1DB3(void)
{
    uint8 L = 0;

    while (L < 0x60)
    {
        // bit  7,(hl) ... bit-7 set by cpu1:c_076A if the orc has been hit
        if (0 != (0x80 & b_9200_obj_collsn_notif[ L ]))
        {
            // jr   nz,l_1DC1_make_him_dead
            b_9200_obj_collsn_notif[ L ] &= ~0x80; // res  7,(hl)

            // L*2 to maintain z80 indexing in array

            b8800_obj_status[ L ].state = 4; // disposition = dying

            // explosion count
            b8800_obj_status[ L ].obj_idx = 0x40; // ld   (hl),#0x40

            // update color for inactive/dead sprite
            mrw_sprite.cclr[ L ].b1 = 0x0A; // "glowing" prior to explosion
        } // jr   l_1DBD
        L += 2;
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

    if (ds4_game_tmrs[0] > 0) ds4_game_tmrs[0]--;
    if (ds4_game_tmrs[1] > 0) ds4_game_tmrs[1]--;
    if (ds4_game_tmrs[2] > 0) ds4_game_tmrs[2]--;
    if (ds4_game_tmrs[3] > 0) ds4_game_tmrs[3]--;
}

/*=============================================================================
;; f_1DE6()
;;  Description:
;;   Provides pulsating movement of the collective.
;;   Enabled by f_2A90 once the initial formation waves have completed.
;; IN:
;;  ...
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
void f_1DE6(void)
{
    uint8 A, D, E, Cy;

    // only performed every 1/4th frame (15hz)
    if ((ds3_92A0_frame_cts[0] % 4) != 0)
        return;

    E = A = glbls9200.bug_nest_direction_lr; // PREVIOUS_nest_direction counter

    D = -1;

    if (0 == (glbls9200.bug_nest_direction_lr & 0x80)) // bit  7,a
    {
        // expanding
        D += 2; // D==1
        glbls9200.bug_nest_direction_lr++; // inc  (hl)
    }
    else
    {
        // l_1DFC_contracting:
        // D==-1
        glbls9200.bug_nest_direction_lr--; // dec  (hl)
    }

    // l_1DFD:
    if (A == 0x1F)
        // counting up from $00 to $1F
        glbls9200.bug_nest_direction_lr |= 0x80; // set  7,(hl) ... = $A0

    if (A == 0x81)
        // counting down from $A0 to $81 (-$60 to -$7F)
        glbls9200.bug_nest_direction_lr &= ~0x80; // res  7,(hl) ... = $00

    // Now we have updated the counter, and have D==1 if expanding, D==-1 if contracting.
    // Every 8*4 (32) frames, we change the bitmap which determines the positions that are
    // updated. This happens to correspond with the "flapping" animation... ~1/2 second per flap.

    // l_1E09:

    glbls9200.formatn_mv_signage = D; // b_9200[0x11] .. current increment (1 or -1 )

    // ld   a,e  ; previous_nest_direction counter (do it after if() )

    if (0 == (A & 0x07))
    {
        uint8 B;

        A = glbls9200.bug_nest_direction_lr & 0x18; // ld   a,c ...

        // HL += 2A ... table entries are $10 bytes long
        A <<= 1;

        // ld   a,e  ; previous_nest_direction counter

        //   ldir
        B = 0;
        while (B < 16)
        {
            ds10_9920[B] = d_1E64_bitmap_tables[ A + B ];
            B++;
        }
    }

    A = E; // ld   a,e ... previous_nest_direction counter (see above)

    // l_1E23: determines which parameter is taken. Bit-7 XOR'd with flip_screen-bit
    Cy = (0 != (A & 0x80)) ^ glbls9200.flip_screen;

    if (0 != Cy)
    {
        // BC = 0x01FF, contracting
        c_1E43(1, 0, 0x05); // left-most 5 columns
        c_1E43(-1, 5, 0x0B); // rightmost 5 columns and the 6 row coordinates
    }
    else // l_1E36
    {
        // BC = 0xFF01, expanding
        c_1E43(-1, 0, 0x05); // left-most 5 columns
        c_1E43(1, 5, 0x0B); // rightmost 5 columns and the 6 row coordinates
    }
}

/*=============================================================================
;; c_1E43()
;;  Description:
;;   Updates the row/col coordinate locations for the alien formation.
;;   The selected bitmap table determines whether any given coordinate
;;   dimension is incremented at this update.
;;   Offset and counts used instead of pointers since the location structures
;;   are not simple arrays
;; IN:
;;    B   == +/- 1 increment.
;;    offs: either 0 or 5
;;    cnt: either 5 or 11
;;    ds10_9920[]: working copy of selected bitmap table ($10 bytes)
;;    ds_home_posn_loc[].rel:
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
void c_1E43(uint8 B, uint8 offs, uint8 cnt)
{
    uint8 Cy;
    uint8 HL = offs;
    uint8 IXL = 0;

    // j_1E43
    while (IXL < cnt)
    {
        // rrc  (hl)
        Cy = ds10_9920[HL + IXL];
        Cy &= 0x01;
        ds10_9920[HL + IXL] >>= 1;
        ds10_9920[HL + IXL] |= (Cy << 7);

        // jr   nc,l_1E5C_update_ptrs
        if (Cy)
        {
            ds_home_posn_loc[(HL + IXL) * 2 ].rel += B;

            // 10 column coordinates, 6 row coordinates, 16-bits per coordinate
            ds_home_posn_org[ (HL + IXL) * 2 ].word += B;
            ds_home_posn_org[ (HL + IXL) * 2 ].pair.b1 = 0; //for now, MSB not needed for non-inverted screen
        } // if

        // l_1E5C_update_ptrs
        IXL++;

    } // while
}


/*=============================================================================
;; d_1E64_bitmap_tables
;;  Description:
;;   bitmaps determine at which intervals the corresponding coordinate will
;;   be incremented... allows outmost and lowest coordinates to expand faster.
;;
;;      |<-------------- COLUMNS --------------------->|<---------- ROWS ---------->|
;;
;;---------------------------------------------------------------------------*/
static uint8 d_1E64_bitmap_tables[] =
{
    0xFF, 0x77, 0x55, 0x14, 0x10, 0x10, 0x14, 0x55, 0x77, 0xFF, 0x00, 0x10, 0x14, 0x55, 0x77, 0xFF,
    0xFF, 0x77, 0x55, 0x51, 0x10, 0x10, 0x51, 0x55, 0x77, 0xFF, 0x00, 0x10, 0x51, 0x55, 0x77, 0xFF,
    0xFF, 0x77, 0x57, 0x15, 0x10, 0x10, 0x15, 0x57, 0x77, 0xFF, 0x00, 0x10, 0x15, 0x57, 0x77, 0xFF,
    0xFF, 0xF7, 0xD5, 0x91, 0x10, 0x10, 0x91, 0xD5, 0xF7, 0xFF, 0x00, 0x10, 0x91, 0xD5, 0xF7, 0xFF
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

}


void c_1F0F(void);

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
        return;

    c_1F0F();
}

/*=============================================================================
;; c_1F0F()
;;  Description:
;;   Intialize sprite objects for rockets.
;;   rocket sprite.cclr[n].b0 is initialized by c_game_or_demo_init
;;   Updates game shots fired count.
;; IN:
;;  ...
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
void c_1F0F(void)
{
    uint8 *pushDE;
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

    // if ( ! flip_screen )
    {
        // screen not flipped so invert those bits
        A = B ^ 0x60;
    }
    // l_1F71:
    // pointer to rocket attribute
    *pushDE = A | C; // bit7=orientation, bit6=flipY, bit5=flipX, 1:2=displacement

    b8800_obj_status[E].state = 6; // active rocket object

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

    c_1F92(A);
}

/*=============================================================================
;; c_1F92()
;;  Description:
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
;;   A == IO input control bits
;;        8 ---> R
;;        2 ---> L
;;   E == actv_plyr_state[7]  .... double ship flag
;;
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
static void c_1F92(uint8 A)
{
    uint8 ship_dX;
    uint8 B;

    if ((A & 0x0A) == 0x0A) // inputs are active low, neither left or right active
    {
        // l_1FCF_no_input:
        ship_dX_flag = 0;
        return;
    }

    // invert the input bits if screen flipped (swap L/R direction)

    // set ship.dX (1 or 2)
    // l_1FA1_set_ship_dx:
    ship_dX = 1;

    // toggle ship_dX_flag
    ship_dX_flag ^= 1;

    if (0 == ship_dX_flag) ship_dX++;

    // stash the control input bits
    B = A;

    // l_1FAE_handle_input_bits:
    if (0 == mrw_sprite.posn[SPR_IDX_SHIP].b0) return;

    if (B & 0x02) // if ! input.right (inverted)
    {
        // jr   nz,l_1FC7_test_llmt
        // test left limit
        if (mrw_sprite.posn[SPR_IDX_SHIP].b0 < 0x12) // "main" ship (single) position
            return;

        else
        {
            mrw_sprite.posn[SPR_IDX_SHIP].b0 -= ship_dX;

            // jr   l_1FD4_update_two_ship
        }
    }
    else
    {
        if (mrw_sprite.posn[SPR_IDX_SHIP].b0 > 0xD1)
        {
            // moving right: check right limit for double-ship

            // if double ship, return
            if (0 != plyr_state_actv.plyr_is_2ship)
                return;

            // l_1FC0_test_rlmt_single:
            if (mrw_sprite.posn[SPR_IDX_SHIP].b0 >= 0xE1)
                return;
        }
        // add dX for right direction
        mrw_sprite.posn[SPR_IDX_SHIP].b0 += ship_dX;
    }

    // l_1FD4_update_two_ship:
    if (0 == plyr_state_actv.plyr_is_2ship)
        return;
    else
        mrw_sprite.posn[SPR_IDX_SHIP].b0 += 0x0F;
    return;
}

