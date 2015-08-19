/*******************************************************************************
 **  galag: precise re-implementation of a popular space shoot-em-up
 **  gg1-4.s (gg1-4.2l)
 **
 **  Hi-score dialog, power-on memory tests, and service-mode menu functions
 **
 *******************************************************************************/

/*
 ** header file includes
 */
#include <string.h> // memset
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
mchn_cfg_t mchn_cfg;

/*
 ** static external definitions in this file
 */

// variables
static str_pe_t hiscore_scrn_txt[];
static str_pe_t hiscore_initials_txt[];

struct best5_t best5[] =
{
    {
        { 0x06, 0x05, 0x04, 0x03, 0x02, 0x01 },
        { 'N', 'N', 'N' }
    },
    {
        { 0x06, 0x05, 0x04, 0x03, 0x02, 0x00 },
        { 'A', 'A', 'A' },
    },
    {
        { 0x00, 0x00, 0x00, 0x00, 0x02, 0x00 },
        { 'D', 'E', 'F' },
    },
    {
        { 0x06, 0x05, 0x04, 0x03, 0x00, 0x00 },
        { 'G', 'H', 'I' },
    },
    {
        { 0x06, 0x05, 0x04, 0x00, 0x00, 0x00 },
        { 'J', 'K', 'L' },
    },
};

// declarations

// function prototypes
static uint8 hiscore_chkrank(uint8, uint16 );
static void insert_score(uint8, uint16 );
static void text_out(str_pe_t);
static void text_out_ce(str_pe_t);

/*=============================================================================
;; _top5_dlg_proc()
;;  Description:
;;   Enter Your Initials / Top 5 screen
;;   Checks players score for ranking in the Best 5. Scores are 6 characters
;;   BCD format, stored highest digit (100000's) at highest address of array.
;;   Player enters initials for high score.
;;   This is called from game_ctrl (background task) and is blocking on the
;;   game-timers.
;;   Scores stored such that 5th is lowest in memory.
;; IN:
;;  ...
;; OUT:
;;  ...
;; Note: 83ED-83F2 is high score in tile RAM.
;;---------------------------------------------------------------------------*/
void hiscore_enterinitials(void)
{
    uint16 p_plyr_score;
    uint8 index, place;

b_9AA0[0x10] = 1; // HELP_ME_DEBUG
#if 0
uint8 *junk = &m_tile_ram[0x03E0 + 0x1D - 5];
m_tile_ram[0x03E0 + 0x1D - 5  + 5] = 0x01; // get on the board
m_tile_ram[0x03E0 + 0x1D - 5  + 4] = 0x00; // get on the board
m_tile_ram[0x03E0 + 0x1D - 5  + 3] = 0x00; // get on the board
#endif
///*
    p_plyr_score = 0x03E0 + 0x1D;

    if (0 != plyr_actv.plyr_nbr)
    {
        p_plyr_score = 0x03E0 + 0x08;
    }
//*/
    place = 5;

    if (0 == hiscore_chkrank(place--, p_plyr_score))
    {
        return; // ret  nc
    }
    else if (0 == hiscore_chkrank(place--, p_plyr_score))
    {
        b_9AA0[0x10] = 1; // sound-fx count/enable registers
    }
    else if (0 == hiscore_chkrank(place--, p_plyr_score))
    {
        b_9AA0[0x10] = 1; // sound-fx count/enable registers
    }
    else if (0 == hiscore_chkrank(place--, p_plyr_score))
    {
        b_9AA0[0x10] = 1; // sound-fx count/enable registers
    }
    else if (0 == hiscore_chkrank(place--, p_plyr_score))
    {
        b_9AA0[0x10] = 1; // sound-fx count/enable registers
    }
    else
    {
        b_9AA0[0x0C] = 0xFF; // sound-fx count/enable registers, special tune for 1st place
        place = 1;
    }

    insert_score(place, p_plyr_score);

    for (index = 0; index < 5 - place; index++)
    {
//        memcpy(best5.name_tbl[place + 1 + index], 3, best5.name_tbl[place + 0 + index]);
    }
    memset(best5[place].name_tbl, 0x24, 3);

    text_out_ce(hiscore_initials_txt[0]) ; // "ENTER YOUR INITIALS !"
    text_out(hiscore_initials_txt[1])    ; // "SCORE  NAME"
    text_out_ce(hiscore_initials_txt[2]) ; // "TOP 5"

//  puts_AAA (default initials of new score entry) below NAME
/*
       call c_puts_top5scores
       call c_plyr_initials_entry_hilite_line
*/
}

/*=============================================================================
;; hiscore_chkrank()
;;  Description:
;;  called by _top5_dlg_proc, once for each of 5th place score, 4th place etc.
;;
;; IN:
;;  DE == pointer to 100000's digit (highest address) of score table entry.
;;  p_tile == pointer to 100000's digit (highest address) of either plyr1
;;           or plyr2 score (6 characters in tile-ram).
;; OUT:
;;  If Player Score > Table Entry, then Cy is set, i.e.  { *(DE) - *( *p8A00 ) }
;;---------------------------------------------------------------------------*/
static uint8 hiscore_chkrank(uint8 place, uint16 p_tile)
{
    uint16 p_plyr_score; // set an index into tile ram
    uint8 b = 0;

    p_plyr_score = 0x03E0 + 0x1D;

    if (0 != plyr_actv.plyr_nbr)
    {
        p_plyr_score = 0x03E0 + 0x08;
    }

    // use place to setup "de"
    while (b < 6)
    {
uint8 *junk = &m_tile_ram[p_plyr_score]; // 00 06 07 01 24 24 (001765)
// what if best5[place - 1].score_tbl[5 - b] == 0x24?

        if (m_tile_ram[p_plyr_score - b] > best5[place - 1].score_tbl[5 - b])
        {
            if (0x24 != m_tile_ram[p_plyr_score - b])  return 1;
        }

        if (0x24 == m_tile_ram[p_plyr_score - b])
        {
            if (0x24 == best5[place - 1].score_tbl[5 - b])
                ; // both spaces, keep going
            else if ((m_tile_ram[p_plyr_score - b]) > 0)
                return 1;
        }
        else if (0x24 == best5[place - 1].score_tbl[5 - b])
        {
            return 0; // score digit is not $24, so it is greater
        }

        b += 1;
    }

    return 0;
}

/*=============================================================================
;; hiscore_scrn
;;  Description:
;;  display hi-score screen (Galactic Heroes) in attract mode
;; IN:
;;  ...
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
void hiscore_heroes(void)
{
    text_out_ce(hiscore_scrn_txt[0]);  // "THE GALACTIC HEROES"
    text_out_ce(hiscore_scrn_txt[1]);  // "-- BEST 5 --"  '-' == $26

    hiscore_scrn();
}

/*=============================================================================
;; hiscore_scrn
;;  Description:
;;  display hi-score screen (common sub)
;;  Caller will setup title text for a) Top 5 (hiscore entry) or b) Galactic
;;  Heroes (in attract-mode)
;; IN:
;;  ...
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
void hiscore_scrn(void)
{
/*
       ld   hl,#s_32B4_score_name
       call c_text_out                            ; puts 'SCORE     NAME' below 'TOP 5'
*/
       text_out(hiscore_initials_txt[1])    ; // "SCORE  NAME"
/*
       ld   b,#1                                  ; starting index for c_3231
       call c_3231                                ; '1ST............'
       call c_3231                                ; '2ND............'
       call c_3231                                ; '3RD............'
       call c_3231                                ; '4RD............'
                                                  ; continue to '5TH' ...
*/
}

/*
 * support sub for _enterinitials()
 */
static void insert_score(uint8 place, uint16 plyr_score)
{
    uint8 index = 5 - place + 1;

    while(index-- > 0)
    {
//        memcpy(best5.score_tbl[index + 0], 6, best5.score_tbl[index + 1]);
    }

    // copy to score_tbl[place -1];
//    memcpy(best5.score_tbl[index + 1], 6, plyr_score);
}



/*=============================================================================
;;  Description:
;;   High score table strings.
;;---------------------------------------------------------------------------*/
static str_pe_t hiscore_initials_txt[] = {
    {
        // $01
        0x0320 + 0x04,
        0x04,
        "ENTER YOUR INITIALS !"
    },
    {
        0x02E0 + 0x07, // _dea(r, c)
        0xFF, // no color-encode
        "SCORE       NAME"
    },
    {
        0x0240 + 0x10, // _dea(r, c)
        0x04,
        "TOP 5"
    },
    {
        0x0280 + 0x12, // _dea(r, c)
        0xFF, // no color-encode
        "SCORE     NAME" // c_puts_top5scores
    },
};


/*=============================================================================
;; text_out()
;;  Description:
;;  Text out, color attribute not encoded. Text blocks are length-encoded.
;;
;;  Z80 source does NOT deal in ASCII.
;;  C source to use ASCII, but need special sauce for code translation.
;;
;; IN:
;;  n = index into array of string table
;; OUT:
;;
;;---------------------------------------------------------------------------*/
static void text_out(str_pe_t n)
{
    int l; // loop index count
    int b = strlen(n.chars); // byte count of string
    uint16 de = n.posn;

    for (l = 0; l < b; l++)
    {
        uint8 ch = n.chars[l];

        if (ch == 32) ch = 0x24; // convert from ASCII space character
        else if (ch < '0') ch += 11; // convert from ASCII symbols (! == $2C), ASCII $21
        else if (ch <= '9') ch -= '0'; // convert from ASCII digits
        else if (ch <= 'Z') ch = ch - 'A' + 10; // convert from ASCII upper-case letter

        m_tile_ram[de] = ch;
        //m_color_ram[de] = clr;
        de -= 0x20;
    }
}

/*=============================================================================
;; c_text_out_ce()
;;  Description:
;;   Text out, color attribute encoded. Text blocks are length-encoded.
;;
;;  Z80 source does NOT deal in ASCII.
;;  C source to use ASCII, but need special sauce for code translation.
;;
;; IN:
;;  n = index into array of string table
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
static void text_out_ce(str_pe_t n)
{
    int l; // loop index count
    int b = strlen(n.chars); // byte count of string
    uint16 de = n.posn;
    uint8 clr = n.color;

    for (l = 0; l < b; l++)
    {
        uint8 ch = n.chars[l];

        if (ch == 32) ch = 0x24; // convert from ASCII space character
        else if (ch == '-') ch = 0x26; // convert from ASCII '-' character
        else if (ch < '0') ch += 11; // convert from ASCII symbols (! == $2C), ASCII $21
        else if (ch <= '9') ch -= '0'; // convert from ASCII digits
        else if (ch <= 'Z') ch = ch - 'A' + 10; // convert from ASCII upper-case letter

        m_tile_ram[de] = ch;
        m_color_ram[de] = clr;
        de -= 0x20;
    }
}

/*=============================================================================
;; strings for mach_hiscore_show
;;===========================================================================*/
static str_pe_t hiscore_scrn_txt[] = {
    {
        0x0320 + 0x05,
        0x02,
        "THE GALACTIC HEROES"
    },
    {
        0x02C0 + 0x0C,
        0x04,
        "-- BEST 5 --"
    },
};

/*=============================================================================
;;  Description: machine power-on/self-test
;;   RAM and ROM tests (do not know if graphic patterns will be too fast to see?).
;;   'RAM OK' and 'ROM OK' actually shown right side up, but flip screen gets
;;   set because of the check that is done on the IO input value.
;;   Service-mode menus not implemented and also video-ram test pattern is
;;   shoved in here as well.
;;
;;   In C code, the following must be broken out of cpu0_init if it depends
;;   on cpu1_init  and/or cpu2_init.
;; IN:
;;  ...
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
uint8 cpu0_post(void)
{
    uint16 HL, DE, BC;

// jp_RAM_test:

    // a few variables may have residual values from RAM tests, put them here
    ds_new_stage_parms[4] = 0xEA;
    ds_new_stage_parms[5] = 0xEA;

    // enable f_05BE in CPU-sub1 (empty task) ... disabled in game_ctrl start
    cpu1_task_en[0] = 0x07; // skips to f_05BE in CPU-sub task-table

//jp   j_romtest_mgr

//j_Test_menu_init:

// call c_svc_updt_dsply

    // goes in c_svc_updt_dsply()
    mchn_cfg.bonus[0] = 0x02;
    mchn_cfg.bonus[1] = 0x06;


    // Initialize scheduler table before interrupts are enabled (otherwise
    // task scheduler could infinite loop!)
    task_actv_tbl_0[0] = 0x20; // only task 0 (empty task) can be called


    // wait 02 frames to verify that CPU-sub1 is alive and updating the frame counter
    ds3_92A0_frame_cts[0] = 0;
    while (ds3_92A0_frame_cts[0] < 2)
    {
        _updatescreen(1); // verify that CPU-sub1 is alive
    }


    //  setup IO command params for bang sound
    //        ld   (0x7100),a    ; IO cmd ($A8 -> bang sound)
    c_io_cmd_wait();

    // setup interrupt mode and toggle the latch
    irq_acknowledge_enable_cpu0 = 1; // enable cpu0_rst38 (_post)


    // wait 8 frames (while test sound??)



    // j_36BA_Machine_init:


    // wait 8 frame counts


    // jp   nc,j_Test_menu_proc

    // synchronize with next frame transition.
    //  while ( frame_cts[0] == prev_frame_cts[0] )

    // dips would be read here
    mchn_cfg.rank = 3; // default to 3->easy


    // j_36BA_Machine_init:

    HL = 0;

    // drawing the cross hatch pattern - tile ram layout is pretty clumsy!
    BC = 0x10;
    while (BC-- > 0)
    {
        *(m_tile_ram + HL) = 0x28;
        HL++;
        *(m_tile_ram + HL) = 0x27;
        HL++;
    }

    BC = 0x10;
    while (BC-- > 0)
    {
        *(m_tile_ram + HL) = 0x2D;
        HL++;
        *(m_tile_ram + HL) = 0x2B;
        HL++;
    }

    BC = 0x10;
    while (BC-- > 0)
    {
        *(m_tile_ram + HL) = 0x28;
        HL++;
        *(m_tile_ram + HL) = 0x2D;
        HL++;
    }

    BC = 0x10;
    while (BC-- > 0)
    {
        *(m_tile_ram + HL) = 0x27;
        HL++;
        *(m_tile_ram + HL) = 0x2B;
        HL++;
    }

    // remainder of cross hatch pattern is drawn by copy.
    DE = HL;
    HL = 0x0040;
    BC = 0x0340;
    while (BC-- > 0)
    {
        *(m_tile_ram + DE) = *(m_tile_ram + HL);
        DE++;
        HL++;
    }

    HL = 0; // #m_tile_ram
    BC = 0x0040;
    while (BC-- > 0)
    {
        *(m_tile_ram + DE) = *(m_tile_ram + HL);
        DE++;
        HL++;
    }


    // wait about two seconds before checking Test-switch.
    ds3_92A0_frame_cts[0] = 0;
    while (ds3_92A0_frame_cts[0] < 0x80)
    {
        BC = _updatescreen(1); // before checking Test-switch.
        if (0 != BC)
        {
            return BC;
        }
    }
    return 0; //        jp   j_Game_init ... g_init
}

