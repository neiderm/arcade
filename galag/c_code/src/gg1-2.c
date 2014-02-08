/*******************************************************************************
 **  galag: precise re-implementation of a popular space shoot-em-up
 **  gg1-2.s
 **    Utility functions, player and stage setup, text display.
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
fmtn_hpos_t fmtn_hpos; // formation standby positioning
const uint8 fmtn_hpos_orig[];

/*
 ** static external definitions in this file
 */
// variables
static const uint8 task_enable_tbl_def[32];

// function prototypes
static void c_build_token_1(uint8 *, uint16 *, uint8);
static void c_build_token_2(uint8 *, uint16 *);
static void draw_resv_ships(void);
static void draw_resv_ship_tile(uint16, uint8 *, uint8);
static void bmbr_setup_fltq(uint8, uint16, uint8);


/*=============================================================================
;; bmbr_setup_fltq_boss()
;;  Description:
;;   setup bombing attackers in flite control queue, boss + 1 or 2 wingmen.
;; IN:
;;   HL == &b_8800[n] ... bits 0:6
;;         bit-7 if set then negate rotation angle to (ix)0x0C
;;         (creature originating on right side)
;;   DE == pointer to object data (in cpu-sub1 code space)
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
void bmbr_setup_fltq_boss(uint8 L, uint16 pDE)
{
    uint8 rotn_flag, obj_idx;
    rotn_flag = L & 0x80;
    obj_idx = L & 0x7F; // res  7,l
    bmbr_setup_fltq(obj_idx, pDE, rotn_flag);
}


/*=============================================================================
;; bmbr_setup_fltq_drone()
;;  Description:
;;   setup bombing attackers in flite control queue - drones (red alien,
;;   yellow alien, clone-attacker) and also rogue fighter.
;; IN:
;;   HL == &b_8800[n]
;;   DE == pointer to object data (in cpu-sub1 code space)
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
void bmbr_setup_fltq_drone(uint8 obj_idx, uint16 pDE)
{
    uint8 rotn_flag;
    // rotation-flag determined by presence of bit-1, passed in obj_idx bit-7
    rotn_flag = (obj_idx & 0x02) ? 0x80 : 0x00;
    bmbr_setup_fltq(obj_idx, pDE, rotn_flag);
}


/*=============================================================================
;; bmbr_setup_fltq()
;;  Description:
;;   setup bombing attackers in flite control queue, common to boss, drone
;; IN:
;;   obj_idx  == &b_8800[n]
;;   p_dat    == pointer to table in cpu-sub1 code space
;;   rot_flag ==
;;        bit-0: fltq[0x13]<0> activates the q-element, but will be set below
;;        bit-7: fltq[0x13]<7> sets negative rotation angle
;; OUT:
;;
;;---------------------------------------------------------------------------*/
static void bmbr_setup_fltq(uint8 obj_idx, uint16 p_dat, uint8 rotn_flag)
{
    r16_t tmpA;
    uint8 IX;

    // find an available data structure or quit
    for (IX = 0; IX < 0x0C; IX++)
    {
        if (0 == (mctl_mpool[IX].b13 & 0x01)) // check for activated state
        {
            break; // jr   z,l_10A0_got_one
        }
    } // djnz l_1094

    // check for quit condition
    if (0x0C == IX) return;

    // l_10A0_got_one:
    mctl_mpool[IX].p08.word = p_dat;
    mctl_mpool[IX].b0D = 1;
    mctl_mpool[IX].ang.word = 0x0100;
    mctl_mpool[IX].b10 = obj_idx; // index of object, sprite etc.

    //  ex   af,af'     function parameter from A'
    //  ld   d,a        to 0x13(ix)

    sprt_mctl_objs[obj_idx].state = HOMING; // diving attack
    sprt_mctl_objs[obj_idx].mctl_idx = IX;

    // insert sprite Y coord into pool structure
    tmpA.pair.b0 = mrw_sprite.posn[obj_idx].b1; // sprite_y<7:0>
    tmpA.pair.b1 = mrw_sprite.ctrl[obj_idx].b1 & 0x01; // sprite_y<8>

    if ( 0 == glbls9200.flip_screen) // jr   nz,l_10DC
    {
        // add  a,#0x00A0/2 etc.
        tmpA.word = 0x0160 - tmpA.word + 0x01; // how bout just use 16-bits!
    }
    mctl_mpool[IX].cy.word = tmpA.word << 7; // make fixed-point

    // l_10DC ... insert sprite X coord into pool structure
    if ( 0 == glbls9200.flip_screen)
    {
        tmpA.word = mrw_sprite.posn[obj_idx].b0; // ld   a,c ... sprite_x
    }
    else
    {
        tmpA.word = 0xF0 - mrw_sprite.posn[obj_idx].b0 + 0x02;
    }
    mctl_mpool[IX].cx.word = (tmpA.word << 7) & 0xFF80; // make fixed-point

    mctl_mpool[IX].b13 = rotn_flag | 0x01; // d
    mctl_mpool[IX].b0E = 0x1E; // bomb drop counter

    if (0 == glbls9200.flying_bug_attck_condtn)
    {
        mctl_mpool[IX].b0F = 0; // bomb_drop_enbl_flags
    }
    else
    {
        mctl_mpool[IX].b0F = b_92C0_0[0x08]; // bomb_drop_enbl_flags
    }
}


/*=============================================================================
;; c_new_level_tokens()
;;  Description:
;;   new stage setup
;;     from c_new_stage, sound disable flag is set if challenge stage
;;     from plyr_changeover, sound disable flag is set
;; IN:
;;  A': non-zero if sound-clicks for stage tokens (passed to sound manager)
;;  Cy': set if inhibit sound-clicks for stage tokens
;;
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------*/
void c_new_level_tokens(uint8 sound_disable_flag)
{
    uint16 tmpBCdiv10result, tmpBCmod10result;
    uint16 tmp16;
    uint16 DE;
    uint16 HL;
    uint8 A, B, C;

    memset(m_tile_ram + 2, 0x24, 0x12); // second row from bottom at right

    memset(m_tile_ram + 0x22, 0x24, 0x12); // bottom row at right

    A = plyr_state_actv.stage_ctr;
    B = 0; // tmp_quotient 50

    HL = 1; // offset into tileram ($8001)

    // stage_ctr/50 and stage_ctr%50 (by brute force!)
    while (A >= 50)
    {
        A -= 50; // tmp_modulus
        B++; // tmp_quotient
        HL += 2; // offset tileram ptr 2 columns to the left... *50 icons are 2 tiles wide
    }

    DE = HL; // stash the tileram offset in DE

    HL = (uint16) A; // stage_ctr % 50
    A = HL % 10;
    HL = HL / 10;

    // push hl ... stack the quotient and mod10 result
    tmpBCdiv10result = HL;
    tmpBCmod10result = A;

    // ex   de,hl
    tmp16 = DE;
    DE = HL; // div10result
    HL = tmp16; // tileram offset

    /*
     now HL == tile_ram address  and  DE == div10 and mod10 result
     Offset base pointer in HL by the nbr of additional tile columns needed.
     */
    if (A >= 5) // tmpBCmod10result
    {
        A -= 4; // adjust the column count to account for the 5 marker
    }

    C = A; // nbr of columns for 5's and 1's (not including 50's)

    /*
     Add up the total additional columns needed for 10, 10, 20, 30, 40 in A.
     The div10 result does the right thing for 20, and 40 (noteing the 40 needs
     4 columns)... and also for 0!
     'bit 0' catches the odd div10 result (i.e. 10s and 30s) and forces A=2.
     */
    A = tmpBCdiv10result;

    if (A & 0x01) A = 2;
    A += C; // nbr of additional tile columns
    HL += A; // add to HL which already has nbr of columns for 50's.

    // B == count of 50's markers, if any
    while (B-- > 0)
    {
        uint8 D = 0x36 + 4 * 4; // offset to 50's tiles group

        c_build_token_1(&D, &HL, sound_disable_flag);
        c_build_token_2(&D, &HL);
    }

    // handle 40's separately
    if (tmpBCdiv10result == 4)
    {
        // offset to 30's tiles group
        uint8 D = 0x36 + 4 * 3;
        //  l_11F0_do_40s:
        c_build_token_1(&D, &HL, sound_disable_flag);
        c_build_token_2(&D, &HL);

        // offset to 10's tiles group
        D = 0x36 + 4;
        // l_11FA_show_10s_20s_30s_50s:
        c_build_token_1(&D, &HL, sound_disable_flag);
        c_build_token_2(&D, &HL);
    }
    else if (tmpBCdiv10result != 0)
    {
        // offset to 10's, 20's, and 30's tile group
        uint8 D = 0x36 + tmpBCdiv10result * 4;
        // l_11FA_show_10s_20s_30s_50s:
        c_build_token_1(&D, &HL, sound_disable_flag);
        c_build_token_2(&D, &HL);
    }

    if (tmpBCmod10result >= 5)
    {
        tmpBCmod10result -= 5;

        uint8 D = 0x36 + 2; // offset to '5' tile group
        c_build_token_1(&D, &HL, sound_disable_flag); // show the 5 token
    }

    while (tmpBCmod10result-- > 0)
    {
        uint8 D = 0x36; // offset to '1' tile group
        c_build_token_1(&D, &HL, sound_disable_flag); // show the 1's token(s)
    }
}

/*=============================================================================
;; c_build_token_1()
;;  Description:
;;   wrapper for c_build_token_2 that handles timing and sound-effect
;; IN:
;;   D = offset of start of tile group for the token to display
;;   HL = base address in tileram
;;   sound_disable_flag (Cy') ... set to inhibit sound "clicks" on stage-tokens
;;   A' = plyr_state_actv.not_chllng_stg, non-zero to enable sound manager
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------*/
static void c_build_token_1(uint8 *pD, uint16 *pHL, uint8 sound_disable_flag)
{
    int usres;
    uint8 A;

    // check sound enable parameter ... ex   af,af'
    if (0 == sound_disable_flag)
    {
        A = ds3_92A0_frame_cts[0] + 8;

        while (A != ds3_92A0_frame_cts[0])
        {
            if (0 != (usres = _updatescreen(0))) // 1=blocking
            {
                /* goto getout; */ // 1=blocking
            }
        }

        // (b_9AA0 + 0x15),a ... this was passed as a "parameter" i.e. A'
        b_9AA0[0x15] = plyr_state_actv.not_chllng_stg;

        // l_1215_restore_A_and_continue:
    }

    c_build_token_2(pD, pHL);
}

/*=============================================================================
;; c_build_token()
;;  Description:
;;   wrapper for c_build_token that handles timing and sound-byte
;; IN:
;;   D = offset of start of tile group for the token to display
;;   HL = base address in tileram
;; OUT:
;;   HL -= 1
;;-----------------------------------------------------------------------------*/
static void c_build_token_2(uint8 *D, uint16 *HL)
{
    uint8 A;
    /*
           ld   (hl),d
           inc  d                                     ; next tile
           set  5,l                                   ; +=32 ... advance one row down
           ld   (hl),d
     */
    *(m_tile_ram + *HL) = *D;
    (*D)++;

    *(m_tile_ram + *HL + 0x20) = *D;
    (*D)++; // second increment for color group test
    /*
           inc  d
           set  2,h                                   ; +=$0400 ... colorram

    ; if ( D & $0C  > 8 ) { A = 2  else A = 1 }
           ld   a,d
           and  #0x0C
           cp   #8
           ld   a,#1
           jr   z,l_1228
           inc  a
     */
    A = *D & 0x0C;

    if (A == 8) A = 1;
    else A = 2;

    /*
    ; set the color codes, resetting the bits and updating HL as we go
    l_1228:
           ld   (hl),a
           res  5,l
           ld   (hl),a
           res  2,h
           dec  l
     */
    *(m_color_ram + *HL + 0x20) = A;
    *(m_color_ram + *HL) = A;

    (*HL)--; // advance tileram pointer 1 column to the right
}

/*=============================================================================
;; c_1230_init_taskman_structs()
;;  Description:
;;   Initialize active player and reserve player kernel tables from defaults:
;;   - At reset
;;   - Immediately following end of "demo game (just prior to "heroes" shown)
;;   - After "results" or "HIGH SCORE INITIAL"
;;   - New game (credit==0 -> credit==1)
;; IN:
;;  ...
;; OUT:
;;  ...
-----------------------------------------------------------------------------*/
void c_1230_init_taskman_structs(void)
{
    uint8 bc;

    // memcpy(task_en_actv, task_enable_tbl_def, 0x20)
    for (bc = 0; bc < sizeof(task_enable_tbl_def); bc++)
    {
        task_actv_tbl_0[bc] = task_enable_tbl_def[bc];
    }

    // memcpy(task_resv_tbl_0, task_enable_tbl_def, 0x20);
    for (bc = 0; bc < sizeof(task_enable_tbl_def); bc++)
    {
        task_resv_tbl_0[bc] = task_enable_tbl_def[bc];
    }

    // kill the idle task at [0]
    task_actv_tbl_0[0] = 0;
}


/*=============================================================================*/
// sizeof must == SZ_TASK_TBL
static const uint8 task_enable_tbl_def[32] =
{

    0x1F, //  f_0827
    0x01, //  f_0828 ... Copies from sprite "buffer" to sprite RAM
    0x00, //  f_17B2
    0x00, //  f_1700
    0x00, //  f_1A80
    0x01, //  f_0857 ... sprite coordinates for demo
    0x00, //  f_0827
    0x00, //  f_0827

    0x00, //  f_2916
    0x00, //  f_1DE6
    0x00, //  f_2A90
    0x00, //  f_1DB3
    0x01, //  f_23DD ... Updates each object in the table at 8800
    0x01, //  f_1EA4 ... Bomb position updater
    0x00, //  f_1D32
    0x01, //  f_0935 ... handle "blink" of Player1/Player2 texts

    0x00, //  f_1B65
    0x00, //  f_19B2
    0x00, //  f_1D76 ... star control
    0x00, //  f_0827
    0x00, //  f_1F85
    0x00, //  f_1F04
    0x00, //  f_0827
    0x01, //  f_1DD2 ... Updates array of 4 timers

    0x00, //  f_2222
    0x00, //  f_21CB
    0x00, //  f_0827
    0x00, //  f_0827
    0x00, //  f_20F2
    0x00, //  f_2000
    0x00, //  f_0827
    0x0A, //  f_0977 ... Handles coinage and changes in game-state
};

/*=============================================================================
;; c_game_or_demo_init()
;;  Description:
;;   For game or "demo-mode" (f_17B2) setup
;; IN:
;;  ...
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
void c_game_or_demo_init(void)
{
    uint8 B, C, D, E, L;

    L = SPR_IDX_RCKT;
    D = 9;
    E = 0x30;
    C = 0;
    B = 10;

    while (B > 0)
    {
        mrw_sprite.cclr[L].b0 = E;
        mrw_sprite.posn[L].b0 = 0;
        mrw_sprite.ctrl[L].b0 = C;
        mrw_sprite.cclr[L].b1 = D;

        L++;

        if (B == 9)
        {
            C = 1;
            D = 0x0B;
        }
        B--;
    }
    return;
}

/*=============================================================================
 sprite_tiles_display()
  Description:
   Display sprite tiles in specific arrangements loaded from table data.
   This is for demo or game-start (bonus-info ) screen but not gameplay.
 IN:
  pointer to sprite data to display
 OUT:

-----------------------------------------------------------------------------*/
void sprite_tiles_display(uint8 const *p_sptiles_displ)
{
    uint8 A, L;

    // index of object
    L = p_sptiles_displ[0];

    // bits 3-6 ...sprite code, i.e. offset of sprite tile
    // 6th tile in each set is the "upright" orientation, "un-contracted", like a bug with wing's spread
    A = p_sptiles_displ[1] & 0x78;
    mrw_sprite.cclr[ L ].b0 = A + 0x06;

    // get color bits from original color/code value
    A = p_sptiles_displ[1] & 0x07;

    // Apparently bit-7 of the color/code provides color bit-3
    if (p_sptiles_displ[1] & 0x80)
    {
        A |= 0x08;
    }

    // l_12A6:
    mrw_sprite.cclr[ L ].b1 = A;

    sprt_mctl_objs[ L ].state = STAND_BY; // sprite tiles display

    mrw_sprite.posn[ L ].b0 = p_sptiles_displ[2]; // posn.X

    // Y coordinate: the table value is actually sprite.posn.Y<8..1> and
    // the sla causes the Cy flag to pick up sprite.posn<8> ...
    A = p_sptiles_displ[3] << 1; // sla  a
    mrw_sprite.posn[ L ].b1 = A; // posn.y<0..7>

    // ... sprite.posn<8>
    // ld   a,#0
    // rla
    A = (p_sptiles_displ[3] >> 7) & 0x01;
    mrw_sprite.ctrl[ L ].b1 = A;

    return;
}

/*=============================================================================
;; gctl_fmtn_hpos_init()
;;  Description:
;;   Initial values of row and column for formation home positions at player
;;   start.
;;   Note that z80 must make a const copy of init data in shared RAM (odd bytes
;;   of ds_hpos_loc_t) since the data would not be accessible in CPU1 program
;;   space. The C-code can access the data directly (case 0x04: // _0AA0) so
;;   the RAM copy is not needed.
;;
;; IN:
;;   offset ... 0 on new-screen, $3F on player changeover
;;   IXL: TODO
;; OUT:
;;  ...
;;----------------------------------------------------------------------------*/
void gctl_stg_new_fmtn_hpos_init(uint8 IXL)
{
    uint8 B;

    // note: size/indices of fmtn_hpos arrays are doubled keep consistent with
    // byte-indices in z80

    for (B = 0; B < 16; B++)
    {
        fmtn_hpos.offs[B * 2] = 0; // even-byte/msb

        // don't bother loading const data to lsb ... see "case 0x04: // _0AA0"
    }

    // X coordinates at origin (10 columns) 8-bits integer, adjusted for
    // flip-screen
    B = 0;
    while (B < 10)
    {
        if (0 == glbls9200.flip_screen) // bit 0,C
        {
            fmtn_hpos.spcoords[B * 2].word = fmtn_hpos_orig[B];
        }
        else
        {
            fmtn_hpos.spcoords[B * 2].word = 0xF0 - fmtn_hpos_orig[B] + 0x02;
        }

        B++;
    }

    // Y coordinates at origin (6 columns), the byte-data provides bits <8:1>
    //B = 10; ... ASSERT(B==10)
    while (B < 16)
    {
        uint16 tmp16 = fmtn_hpos_orig[B] << 1;

        // TODO: add  a,ixl

        if (0 == glbls9200.flip_screen) // bit 0,C
        {
            // does not add 1 to $0160-n result ... only bits <8:1> are significant
            fmtn_hpos.spcoords[B * 2].word = (0x0160 - tmp16) & 0x01FE;
        }
        else
        {
            // flipped
            fmtn_hpos.spcoords[B * 2].word = tmp16; // make 9-bit integer
        }

        B++;
    }

    glbls9200.bug_nest_direction_lr = glbls9200.flip_screen;
}


/*=============================================================================
;; Initial home-position formation ordinates in pixels.
;; 8-bits integer for column data (x).
;; 8-bits row data provides bits <8:1> of sprite-sY, stored for some reason in
;; "flipped-screen" format.
;; Diagram below shows how row/column ordinates are stored in
;; sprt_fmtn_hpos_ord_lut byte indices, doubled since there are two-bytes for
;; each ordinate in fmtn_hpos.spcoords[]
;; |<-------------- COLUMNS ----------------------->|<---------- ROWS ---------->|
;;
;;  00   02   04   06   08   0A   0C   0E   10   12   14   16   18   1A   1C   1E
;;
;;----------------------------------------------------------------------------*/
const uint8 fmtn_hpos_orig[] =
{
    /*<-------------- COLUMNS -------------------------------->|<---------- ROWS --------------->*/
    0x31, 0x41, 0x51, 0x61, 0x71, 0x81, 0x91, 0xA1, 0xB1, 0xC1, 0x92, 0x8A, 0x82, 0x7C, 0x76, 0x70
};

/*=============================================================================
;; c_tdelay_3()
;;  Description:
;;   Delay 3 count on .5 second timer.
;;   Used only in game_ctrl... could put it in there as a static function.
;; IN:
;;  ...
;; OUT:
;;  ...
;; PRESERVES:
;;  HL
;;----------------------------------------------------------------------------*/
void c_tdelay_3(void)
{
    ds4_game_tmrs[3] = 3;

    while (ds4_game_tmrs[3] > 0)
    {
        // if (0 != _updatescreen(1)) // 1=blocking
        //    return 1; // goto getout;
        _updatescreen(1);
    }
}

/*=============================================================================
;; gctl_plyr_respawn_fghtr()
;;  Description:
;;    Single player, shows "player 1", then overwrite w/ "stage 1" and show "player 1" above
;;
;;                            |       PLAYER 1
;;               PLAYER 1     |       STAGE 1
;;
;;                                    PLAYER 1
;;                                    STAGE 1     (S @ 8270)
;;
;;                                    PLAYER 1
;;                                    READY       (R @ 8270)
;;
;;    Get READY to start a new ship, after destroying or capturing the one in play.
;;    ("Player X" text already is shown).
;;    Format is different one plyr vs two.
;;    One Plyr:
;;     Updates "Ready" game message text (except for on new stage...
;;     ..."STAGE X" already shown in that position).
;;    Two Plyr:
;;      Next players nest has already descended onto screen w/ "PLAYER X" text shown.
;;     "Ready" is already shown from somewhere else (05f1).
;;
;;    Removes one ship from reserve. (p_136c)
;;    (used in game_ctrl)
;; IN:
;;  ...
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
void gctl_plyr_respawn_fghtr(void)
{
    task_actv_tbl_0[ 0x14 ] = 1; // f_1F85 ... control stick input

    // check if "STAGE X" text shown and if so skip showing "READY"
    if (0x24 == m_tile_ram[0x0260 + 0x10])
    {
        // string_out_pe "READY" (at 8270)
        j_string_out_pe(1, -1, 0x03);
    }
    c_133A_show_ship();
    return;
}

/*=============================================================================
;; c_133A_show_ship()
;;  Description:
;;   Continues gctl_plyr_respawn_fghtr
;;   The call label is for demo mode (f_17B2)
;;   while (bug/bee flys home) ...ship hit, waiting for flying bug to re-nest
;; IN:
;;  ...
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
void c_133A_show_ship(void)
{
    while (0 != b_bugs_flying_nbr)
    {
    }

    draw_resv_ships();

    // put the ship out there
    mrw_sprite.cclr[SPR_IDX_SHIP].b0 = 0x06; // code
    mrw_sprite.cclr[SPR_IDX_SHIP].b1 = 0x09; // color

    // if ( !_flip_screen )  A = $29,  C = 1
    // else  A = $37,  C = 0
    //   add  a,#0x0E                               ; screen is flipped in demo?????
    //   dec  c
    // l_135A:
    mrw_sprite.posn[SPR_IDX_SHIP].b0 = 0x7A; // sx
    mrw_sprite.posn[SPR_IDX_SHIP].b1 = 0x29; // sy<0:7>

    mrw_sprite.ctrl[SPR_IDX_SHIP].b1 = 0x01; // sy<8>
    mrw_sprite.ctrl[SPR_IDX_SHIP].b0 = 0x00; // no flip/double attribute

    glbls9200.restart_stage = 0;
    ds_99B9_star_ctrl[0] = 1; // 1 ... when ship on screen

    return;
}

/*=============================================================================
;; draw_resv_ships()
;;  Description:
;;   Draws up to 6 reserve ships in the status area of the screen, calling
;;   the subroutine 4 times to build the ship icons from 4 tiles.
;; IN:
;;  ...
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
static void draw_resv_ships(void)
{
    uint16 HL;
    uint8 E, D;

    E = ~plyr_state_actv.num_ships + 6; // cpl, add  a,#6 ... max nr of icons

    D = 0x49; // starting tile number

    HL = 0x0000 + 0x1D; // offset into tile ram
    draw_resv_ship_tile(HL, &D, E);

    HL--; // advance 1 column right
    draw_resv_ship_tile(HL, &D, E);

    HL += 32; // down 1 row
    HL += 1; // 1 column to the left
    draw_resv_ship_tile(HL, &D, E);

    HL -= 1; // advance 1 column right
    draw_resv_ship_tile(HL, &D, E);

    return;
}

/*=============================================================================
;; draw_resv_ship_tile()
;;  Description:
;;   Each ship is composed of 4 tiles. This is called once for each tile.
;;   Each tile is replicated at the correct screen offset, allowing up to 6
;;   reserve ship indicators to be shown. Unused locations are filled with
;;   the "space" character tile.
;; IN:
;;   HL== offset in tile ram
;;    D== tile character
;;    E== nr of reserve ships
;; OUT:
;;    HL: current offset in tile ram
;;     D: tile character (increment)
;;
;;---------------------------------------------------------------------------*/
static void draw_resv_ship_tile(uint16 offset, uint8 *tilechr, uint8 nbr)
{
    uint16 tmpHL;
    uint8 A, B;

    tmpHL = offset;

    (*tilechr)++; // inc D

    B = *tilechr;

    A = 6 - 1;

    // l_138B
    while (A > 0)
    {
        if (nbr == A)  B = 0x24;

        // l_1390
        m_tile_ram[tmpHL] = B;

        tmpHL -= 2;
        A--;
    }
}
