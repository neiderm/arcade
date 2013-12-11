/*******************************************************************************
;;  galag: precise re-implementation of a popular space shoot-em-up
;;  gg1-3.s (gg1-3.2m)
;;    Manages formation, attack convoys, boss/capture.
;;
 *******************************************************************************/
/*
 ** header file includes
 */
#include <string.h> // malloc
#include "galag.h"

/*
 ** defines and typedefs
 */

// data type for _2A3C ... pointer to flight pattern tables in bug flying queue
typedef struct struct_flite_ptn_cfg
{
    uint16 p_tbl; // pointer to data tables for flying pattern control.
    uint8 idx; // bits 13:15 - selection index into lut 2A6C.
} t_flite_ptn_cfg;

/*
 ** extern declarations of variables defined in other files
 */

/*
 ** non-static external definitions this file or others
 */
// array of object movement structures, also temp variables and such.
//  00-07 writes to 92E0, see _2636
//  08-09 ptr to data in cpu-sub-1:4B
//  0D + *(ds_9820_actv_plyr_state + 0x09)
//  10 index/offset of object .... i.e. 8800 etc.
//  11 + offset
//  13 + offset
t_bug_flying_status ds_bug_motion_que[ 0x0C ];

uint8 stg_chllg_rnd_attrib[2];
uint8 b_92E2_stg_parm[2]; // bomb-drop control and counter ... TODO: in gg1-5.c
uint8 b_bugs_actv_nbr;

/*
 ** static external definitions in this file
 */

// variables
static uint8 ds_8920_atk_wv_obj_tbl [0x60]; // attack wave object setup tables
static uint8 bugs_actv_cnt;
static const uint8 d_stage_chllg_rnd_attrib[];
static const uint8 d_2908[];
static const uint8 d_290E[];
static const uint8 db_attk_wav_IDs[];
static const uint8 db_combat_stg_dat_idx[4][17];
static const uint8 db_challg_stg_data_idx[];
static const uint8 db_combat_stg_dat[];
static const uint8 db_challg_stg_dat[];
static const t_flite_ptn_cfg db_2A3C[];
static const uint8 db_2A6C[];

// function prototypes
static void c_23E0(uint8);
static void c_28E9(uint8 *, uint8 *, uint8, uint8);


/*=============================================================================
;; f_2000()
;;  Description:
;;    activated when the boss is destroyed that has captured the ship
;; IN:
;;  ...
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
void f_2000(void)
{

}

/*=============================================================================
;; f_20F2()
;;  Description:
;;   handles the sequence where the tractor beam captures the ship.
;; IN:
;;  ...
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
void f_20F2(void)
{

}

/*=============================================================================
;; f_21CB()
;;  Description:
;;   Active when a boss diving down to capture the ship. Ends when the boss
;;   takes position to start the beam.
;; IN:
;;  ...
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
void f_21CB(void)
{

}

/*=============================================================================
;; f_2222()
;;  Description:
;;   Boss starts tractor beam
;;   Activated by f_21CB (capture boss dives down)
;; IN:
;;  ...
;; OUT:
;;  ...
;;
;;---------------------------------------------------------------------------*/
void f_2222(void)
{

}

/*=============================================================================
;; rckt_hit_hdlr()
;;  Description:
;;   animates bug explosion animation on rocket hit ... downsized f_23DD()
;; IN:
;;  E: object index
;; OUT:
;;  ...
;;
;;---------------------------------------------------------------------------*/
static void rckt_hit_hdlr(uint8 E)
{
    reg16 AF;
    uint8 A, C, L;
    L = E;

    // inc  e  (.b1)

    // explosion count, see f_1DB3
    A = b8800_obj_status[ E ].obj_idx;

    if (0x45 != A) // jr   z,l_24E6_i_am_at_45
    {
        A++; // inc  a
        b8800_obj_status[ E ].obj_idx = A; // ld   (de),a

        // dec  e

        if (0x45 == A)
        {
            A += 3; // add  a,#3 ... end of explosion
        }

        // l_24C2:
        if (0x44 == A) // jr   nz,l_24E0
        {
            reg16 tmpAA; // need A and Cy

            // ex   af,af'
            mrw_sprite.posn[ L ].b0 -= 8; // sX ... sub  #8

            //        inc  l

            // subtract only in bits<0:7> then flip b9 on Cy
            tmpAA.word = mrw_sprite.posn[ L ].b1; // sY ... sub  #8
            tmpAA.word -= 8;
            mrw_sprite.posn[ L ].b1 = tmpAA.pair.b0;

            // jr   nc,l_24DA
            if (0 != tmpAA.pair.b1) // test "Cy"
            {
                mrw_sprite.ctrl[ L ].b1 ^= 0x01; // b9
            }

            // l_24DA:
            // dec  l  (.b0)
            // ld   h,#>ds_sprite_ctrl
            mrw_sprite.ctrl[ L ].b0 = 0x0C; // ld   (hl),#0x0C
            // ex   af,af'  ... un-stash A (explosion count)
        }

        //l_24E0:
        //ld   h,#>ds_sprite_code
        //ld   (hl),a
        mrw_sprite.cclr[ L ].b0 = A; // code

        //jp   case_2416
        return; // and break
    }

    // l_24E6_i_am_at_45:
    // dec  e

    A = b_9200_obj_collsn_notif[ L ];

    if (1 == A) // jr   nz,l_24FD
    {
        mrw_sprite.posn[ L ].b0 = 0;
        mrw_sprite.ctrl[ L ].b0 = 0;
        b8800_obj_status[ L ].state = 0x80;

        //jp   case_2416
        return; // break
    }
    // else ... jr   nz,l_24FD

    /*
     l_24FD:
     Show sprite with small score text for shots that award bonus points
    */
    mrw_sprite.cclr[ L ].b0 = A; // code

    if (mrw_sprite.cclr[ L ].b0 >= 0x37) // jr   c,l_250E
    {
        C = 0x0D;
        if (mrw_sprite.cclr[ L ].b0 >= 0x3A) // jr   c,l_250C
        {
            C += 1; // inc  c
        }
        // l_250C:
        mrw_sprite.cclr[ L ].b1 = C; // color
    }

    // l_250E:
    C = 8;

    if (mrw_sprite.cclr[ L ].b0 < 0x3B)
    {
        C = 0;
        mrw_sprite.posn[ L ].b0 += 8;
    }

    // l_251C:
    AF.word = mrw_sprite.posn[ L ].b1;
    AF.word += 8;
    mrw_sprite.posn[ L ].b1 = AF.pair.b0;

    // mrw_sprite.ctrl[ L ].b1 ^= (0 != AF.pair.b1);
    if (0 != AF.pair.b1)
    {
        mrw_sprite.ctrl[ L ].b1 ^= 1;
    }

    // l_2529:
    mrw_sprite.ctrl[ L ].b0 = C;
    b8800_obj_status[ L ].state = 5;
    b8800_obj_status[ L ].obj_idx = 0x13; // counter for score bitmap

    //jp   case_2416
    return; // break
}

/*=============================================================================
;; f_23DD()
;;  Description:
;;   This task is never disabled.
;;   Updates each object in the table at 8800. Iterating through the table at
;;   b8800, it develops a cumulative count of active bugs.
;;   Call here for f_1D32, but normally this is a periodic task called 60Hz.
;;   Effectively, the entire update is done 15Hz. It updates each half of the
;;   objects on alternate odd frames. On one even frame it simply exits and on
;;   the other it updates the global bug count and resets the cumulative count.
;; IN:
;;  ...
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
void f_23DD(void)
{
    c_23E0(ds3_92A0_frame_cts[0]);
}

/*=============================================================================
;; c_23E0()
;;  Description:
;;   allows frame count to be passed directly to f_23DD() for update at player
;;   changeover.
;; IN:
;;  A==_frame_counter
;; OUT:
;;  ...
;;----------------------------------------------------------------------------*/
void c_23E0(uint8 frame_ct)
{
    if (0 != (0x01 & frame_ct))
    {
        uint8 A, B, C, E, L;

        // set initial offset of +0 or +2 (alternates 0,4,8.. or 2,6,10... )
        E = frame_ct & 0x02;

        B = 0; // size of object set

        // l_23EF:
        do
        {
            switch (b8800_obj_status[ E ].state)
            {
                // test for $80 (inactive status)
            case 0x80:
                // _2416
                E += 4;
                break;

                // _2422: after getting to the loop spot, or anytime on a diving attack.
            case 0x09:
                L = E;
                C = db_obj_home_posn_RC[L + 0]; // row position index
                L = db_obj_home_posn_RC[L + 1]; // column position index
                A = ds_home_posn_loc[L].rel; // X coordinate offset
                C = ds_home_posn_loc[C].rel; // Y coordinate offset

                ds_bug_motion_que[ b8800_obj_status[ E ].obj_idx ].b11 = A;
                ds_bug_motion_que[ b8800_obj_status[ E ].obj_idx ].b12 = C;

                // jp   l_2413 ... reset index to .b0 and continue
                bugs_actv_cnt += 1; // 2414
                E += 4; // 2416
                break;

                // _243C: shot my damn ship (DE==8862 ... 8863 counts down from $0F for all steps of explosion)
            case 0x08:
                break;

                // _245F: rotating back into position in the collective
            case 0x02:
                L = E;

                if (0 == (0x01 & mrw_sprite.ctrl[L].b0))
                {
                    A = mrw_sprite.cclr[L].b0 & 0x07;
                    if (0x06 != A)
                    {
                        mrw_sprite.cclr[L].b0++; // inc  (hl)
                        // jr   l_249B
                    }
                    else
                    {
                        // jr   z,l_2483
                        // ld   a,#1  ; disposition = 1: home
                        b8800_obj_status[ E ].state = 1; // ld   (de),a
                        // jr   l_249B
                    }
                }
                else
                {
                    // jr   nz,l_2473
                    A = mrw_sprite.cclr[L].b0 & 0x07;
                    if (0 == A)
                    {
                        // jr   z,l_2483
                        mrw_sprite.ctrl[L].b0 &= ~0x01; // res  0,(hl)
                        // ld   h,#>ds_sprite_code
                        // jr   l_249B
                    }
                    else
                    {
                        // jr   nz,l_2480
                        mrw_sprite.cclr[L].b0--; // dec  (hl)
                        // jr   l_249B
                    }
                }

                // l_249B:
                C = db_obj_home_posn_RC[ L + 0 ]; // row position index
                L = db_obj_home_posn_RC[ L + 1 ]; // column position index

                mrw_sprite.posn[ E ].b0 = ds_home_posn_org[ L ].pair.b0;
                mrw_sprite.posn[ E ].b1 = ds_home_posn_org[ C ].pair.b0;
                mrw_sprite.ctrl[ E ].b1 = ds_home_posn_org[ C ].pair.b1;

                // jp   l_2413 ...  reset index to .b0 and continue
                bugs_actv_cnt += 1; // 2414
                E += 4; // 2416
                break;

                // _2488: assimilated into the collective.
            case 0x01:
                L = E;

                // use bit-1 of 4 Hz timer to toggle bug flap every 1/2
                // second (selects tile code/offset 6 or 7)
                mrw_sprite.cclr[L].b0 &= ~0x01;
                mrw_sprite.cclr[L].b0 |=
                    0 != (ds3_92A0_frame_cts[2] & 0x02);

                // if 0, then skip the rest but count object
                if (0 != glbls9200.flying_bug_attck_condtn)
                {
                    // l_249B:
                    C = db_obj_home_posn_RC[ L + 0 ]; // row position index
                    L = db_obj_home_posn_RC[ L + 1 ]; // column position index

                    mrw_sprite.posn[ E ].b0 = ds_home_posn_org[ L ].pair.b0;
                    mrw_sprite.posn[ E ].b1 = ds_home_posn_org[ C ].pair.b0;
                    mrw_sprite.ctrl[ E ].b1 = ds_home_posn_org[ C ].pair.b1;

                    // jp   l_2413 ...  reset index to .b0 and continue
                    // dec  e  ; reset index/pointer to b0

                    // l_2414_inc_active:
                    //bugs_actv_cnt++;
                }
                // l_2414_inc_active:
                bugs_actv_cnt += 1; // 2414
                E += 4; // 2416
                break;

                // _24B2: nearly fatally shot
            case 0x04:
                rckt_hit_hdlr(E);
                // _2416
                E += 4;
                break;

                // _2535: showing a score bitmap for a bonus hit
            case 0x05:
                b8800_obj_status[ E ].obj_idx -= 1;
                // nz,case_2416
                if (0 == b8800_obj_status[ E ].obj_idx)
                {
                    b8800_obj_status[ E ].state = 0x80;
                    mrw_sprite.posn[ E ].b0 = 0;
                    mrw_sprite.ctrl[ E ].b0 = 0;
                }
                // _2416
                E += 4;
                break;

                // terminate cylons or bombs that have gone past the sides or bottom of screen
            case 0x03: // _254D ; state progression ... 7's to 3's, and then 9's, 2's, and finally 1's
            case 0x06: // _254D ; disable this one and the borg runs out of nukes
                if ( mrw_sprite.posn[ E ].b0 < 0xF4 )
                {
                    reg16 tmpA;
                    tmpA.pair.b1 = mrw_sprite.ctrl[ E ].b1; // sy<8>
                    tmpA.pair.b0 = mrw_sprite.posn[ E ].b1; // sy<0:7>
                    tmpA.word >>= 1; // rra

                    if ( tmpA.word >= 0x0B && tmpA.word < 0xA5 )
                    {
                        // in range
                        if ( 6 != b8800_obj_status[ E ].state )
                        {
                            // l_2414_inc_active:
                            bugs_actv_cnt += 1;
                        }
                        // l_2416
                        E += 4;
                        break;
                    }
                }

                // l_2571:
                if ( 3 == b8800_obj_status[ E ].state  )
                {
                    // l_2582_kill_bug_q_slot:
                    uint8 A;
                    A = b8800_obj_status[ E ].obj_idx;
                    ds_bug_motion_que[A].b13 = 0;
                }
                // l_2578_mk_obj_inactive:
                b8800_obj_status[ E ].state = 0x80;
                mrw_sprite.posn[ E ].b0 = 0;
                break;

                // _2590: once for each spawning orc (new stage)
            case 0x07:
                b8800_obj_status[ E ].state = 3; // disposition = 3 ... from 7 (spawning)
                bugs_actv_cnt += 1;
                E += 4;
                break;

            default:
                break;
            }
        }
        while (B++ < 32); // half of object set
    }
    else
    {
        // l_2596_even_frame
        if (0 != (0x02 & frame_ct))
        {
            b_bugs_actv_nbr = bugs_actv_cnt;
            bugs_actv_cnt = 0;
        }
    }
    return;
}

/*=============================================================================
;; c_25A2()
;;  Description:
;;   Setup the mob to do its evil work. Builds up 5 tables at
;;   b_8920 which organizes the mob objects into the flying waves.
;;   These are formed into the attack wave queue structures by f_2916().
;;   The format is oriented toward having two flights of 4 creatures in each
;;   wave, so they are configured in pairs and I refer to as "lefty" and "righty"
;;   in each pair, although it is an arbitrary designation. In waves that fly
;;   in a single trailing formation, they are still treated as pairs, but the
;;   timing has to be managed to maintain uniform spacing. so there is
;;   an additional flag in the control data byte of the lefty that causes a
;;   delay before the entry of each righty.
;; IN:
;;  ...
;; OUT:
;;  ...
;;----------------------------------------------------------------------------*/
void c_25A2(void)
{
    uint8 const * pdb_attk_wav_IDs;
    uint8 const * pHL_db_stg_dat;
    uint8 *pDE_ds_8920_atk_wv_obj_t;
    uint8 A, B;

    pdb_attk_wav_IDs = db_attk_wav_IDs;

    // if past the highest stage ($17) we can only keep playing the last 4 levels

    A = plyr_state_actv.stage_ctr; // adjusted level

    while (A > 0x17) A -= 4;

    B = A; // adjusted level
    A += 1;

    if (A & 0x03) // if ! challenge_stage
    {
        // offset into _stage_data_idx, @row ... adjusts index since every 4th stage is a challenge stage
        A = B - (B / 4) - 1; // srl  b etc.

        // select the row, @rank
        A = db_combat_stg_dat_idx[ mchn_cfg.rank ][ A ];

        // &stage_dat[row][0]
        pHL_db_stg_dat = &db_combat_stg_dat[A];
    }
    else /* challenge stage */
    {
        A = (plyr_state_actv.stage_ctr >> 2) & 0x07; // divide by 4

        A = db_challg_stg_data_idx[A];

        // &stage_dat[row][0]
        pHL_db_stg_dat = &db_challg_stg_dat[A];
    }

    /*
     First, load bomb-control params from the 2 byte header (once per stage).
     */
    b_92E2_stg_parm[0] = *pHL_db_stg_dat++; // [0]
    b_92E2_stg_parm[1] = *pHL_db_stg_dat++; // [1]

    /*
     Initialize table of attack-wave structs with start token of 1st group
     */
    pDE_ds_8920_atk_wv_obj_t = ds_8920_atk_wv_obj_tbl; // de = &b_8920[0]
    *pDE_ds_8920_atk_wv_obj_t++ = 0x7E; // inc e ... start token of each group

    /*
     The 2-byte header is followed by a series of 8 structs of 3-bytes each
     which establish the parameters of each attack wave. The first of 3-bytes
     determines the presence of "transients" in the attack wave (and is
     the control variable for the following while() block)
     */
    while (0xFF != *pHL_db_stg_dat++) // stg_dat[n] ... check for end of record in stage flite data table
    {
        uint8 obj_ID_tmpb_9100[0x16];
        uint8 *pbHL_obj_ID_tmpb;
        uint8 C, L;

        /*
         setup temp array of next attack wave: consisting of 0 to X transients
         (if any) and always 8 "non-transient" attackers
         */
        // pbHL_obj_ID_tmpb = ds_bug_motion_que; // test side effect of memset ds_9100 $FF (debugging f_08D3)
        pbHL_obj_ID_tmpb = &obj_ID_tmpb_9100[0];

        memset(pbHL_obj_ID_tmpb, 0xFF, 16);


        if (0 != (*pHL_db_stg_dat & 0x0F)) // A == _stg_dat[ 2 + 3 * n + 0 ]
        {
            // setup transients
        }

        // Insert 8 "non-transient" bugs into temp buffer (object IDs of bugs
        // that have final home positions). The object ID list looks like e.g.
        //   0x58, 0x5A, 0x5C, 0x5E, 0x28, 0x2A, 0x2C, 0x2E
        // ... from which the attack wave temp buffer will be populated in the
        // format "LLLLxxxxRRRRxxxx" where 'x' is unused slots.
        // l_2636:

        L = 0; // ld   hl,#ds_atk_wav_tmp_buf
        B = 8;

        while (B > 0) // 8
        {
            // j_263F_skip_until_ff ... check for unused slot in tmp buffer
            while (0xFF != pbHL_obj_ID_tmpb[ L ])
            {
                L++;
            }

            // l_2647_is_ff
            pbHL_obj_ID_tmpb[L++] = *pdb_attk_wav_IDs++;

            if (B == 5)
                L = 8;

            // l_2652:
            B--; // djnz l_263F
        }

        /*
         load the 2nd & 3rd bytes of the attack wave parameters (one "pair" of
         attacking enemy fighters will be replicated from 4 to 8 times depending
         upon number of "transients")
         */
        B = *pHL_db_stg_dat++;
        C = *pHL_db_stg_dat++;

        /*
         The following loop spawns one additional "pair" from the temp array:
         remember the tmp buffer looks like this ... UUUUxxxxVVVVxxxx ...
         e.g. '58 5a 5c 5e ff ff ff ff|28 2a 2c 2e ff ff ff ff'
         where 'x' == 'unused', and each "pair" of attacking enemy fighers
         is formed by queueing up alternating U and V elements.
         U and V are IDs loaded from db_attk_wav_IDs (UUUUVVVV)
         Each iteration of the loop inserts a U-V pair i.e. " bb uu cc vv"
         ... where B and C are used to select the bug motion depending whether he is a "lefty" or a "righty".
         */
        L = 0; // ld   hl,#ds_atk_wav_tmp_buf

        // l_2662_read_until_ff
        while (0xFF != pbHL_obj_ID_tmpb[L + 0])
        {
            *pDE_ds_8920_atk_wv_obj_t++ = B; // L parameter

            *pDE_ds_8920_atk_wv_obj_t++ = pbHL_obj_ID_tmpb[L + 0]; // L object ID

            *pDE_ds_8920_atk_wv_obj_t++ = C; // R parameter

            *pDE_ds_8920_atk_wv_obj_t++ = pbHL_obj_ID_tmpb[L + 8]; // R object ID

            L++;
        }
        *pDE_ds_8920_atk_wv_obj_t++ = 0x7E; // marks the start of each group
    }

    // l_2681_end_of_table:

    // pointer is already advanced, so decrement it so we overwrite the 7E with 7F
    pDE_ds_8920_atk_wv_obj_t--;

    // check capture-mode and two-ship status

    // l_26A4_done:
    *pDE_ds_8920_atk_wv_obj_t = 0x7F;

    return;
}


/*=============================================================================
;; stage config data
;; Selection indices are pre-computed multiples of 18 (row length of data).
;;
;;----------------------------------------------------------------------------*/

/*
 Selection indices for stage data ... pre-computed multiples of 18 for row offsets.

 combat levels, e.g. 1,2,5,6,7,9 etc.
 4 sets... 1 for each rank "B", "C", "D", or "A"
 In each set, one element per stage, i.e. 17 distinct stage configurations (see l_25AC)
 Indices are pre-multiplied (multiples of 0x12, i.e. row length of combat__stg_data)
 */

static const uint8 db_combat_stg_dat_idx[4][17] =
{
    {0x00, 0x12, 0x24, 0x36, 0x00, 0x48, 0x6C, 0x5A, 0x48, 0x6C, 0x00, 0x7E, 0xA2, 0x90, 0xB4, 0xD8, 0xC6},
    {0x00, 0x12, 0x48, 0x6C, 0x5A, 0x7E, 0xA2, 0x00, 0x7E, 0xD8, 0xC6, 0xB4, 0xD8, 0xC6, 0xB4, 0xD8, 0xC6},
    {0x00, 0x12, 0x7E, 0xA2, 0x90, 0x7E, 0xD8, 0xC6, 0xB4, 0xD8, 0xC6, 0xB4, 0xD8, 0xC6, 0xB4, 0xD8, 0xC6},
    {0x00, 0x12, 0x48, 0x36, 0x24, 0x48, 0x6C, 0x00, 0x7E, 0xA2, 0x90, 0xB4, 0xD8, 0x00, 0xB4, 0xD8, 0xC6}
};

// challenge stage e.g. 3,8,10 etc. 8 unique challenge stages... no variation for rank.
static const uint8 db_challg_stg_data_idx[] =
{
    0x00, 0x12, 0x24, 0x36, 0x48, 0x5A, 0x6C, 0x7E
};

/*
  Stage data: each row is 1 level ... 5 waves of bug formations per level

  2 byte header: bomb-control params loaded once per stage

  one triplet of bytes for each of the 5 waves:
  byte 0:
    c_25A2, controls loading of transients into attack wave table
  byte 1 & 2
    bit  7    byte-2 only ... if clear, 2nd bug of pair is delayed for trailing formation
    bit  6    if set selects second set of 3-bytes in db_2A6C[]
    bits 5:0  index of word in LUT at db_2A3C ( $18 entries)
    bit  0    also, if set, ix($0E) = $44 ... bomb delay set-count (finalize_object)
 */

// combat stage data
static const uint8 db_combat_stg_dat[] =
{
    0x14,0x00, 0x00,0x00,0xC0, 0x00,0x01,0x01, 0x00,0x41,0x41, 0x00,0x40,0x40, 0x00,0x00,0x00, 0xFF,
    0x14,0x01, 0x00,0x42,0x82, 0x00,0x03,0x85, 0x00,0x43,0xC5, 0x00,0x42,0xC4, 0x00,0x02,0x84, 0xFF,
    0x14,0x01, 0x82,0x00,0xC0, 0x00,0x01,0x01, 0x00,0x41,0x41, 0x02,0x40,0x40, 0x02,0x00,0x00, 0xFF,
    0x14,0x01, 0x82,0x02,0xC2, 0x00,0x03,0x85, 0x00,0x43,0xC5, 0x02,0x42,0xC4, 0x02,0x02,0x84, 0xFF,
    0x14,0x01, 0x82,0x00,0xC0, 0x00,0x01,0xC1, 0x00,0x41,0x81, 0x02,0x40,0x80, 0x02,0x40,0x80, 0xFF,
    0x14,0x01, 0x82,0x00,0xC0, 0x42,0x01,0x01, 0xF2,0x41,0x41, 0x02,0x40,0x40, 0x02,0x00,0x00, 0xFF,
    0x14,0x01, 0xA4,0x02,0xC2, 0x52,0x03,0x85, 0xF2,0x43,0xC5, 0x02,0x42,0xC4, 0x02,0x02,0x84, 0xFF,
    0x14,0x01, 0x82,0x00,0xC0, 0x52,0x01,0xC1, 0xF2,0x41,0x81, 0x02,0x40,0x80, 0x02,0x40,0x80, 0xFF,
    0x14,0x01, 0xA4,0x00,0xC0, 0x42,0x01,0x01, 0xF4,0x41,0x41, 0x04,0x40,0x40, 0x04,0x00,0x00, 0xFF,
    0x14,0x01, 0xA4,0x02,0xC2, 0x52,0x03,0x85, 0xF4,0x43,0xC5, 0x04,0x42,0xC4, 0x04,0x02,0x84, 0xFF,
    0x14,0x03, 0xA4,0x00,0xC0, 0x54,0x01,0xC1, 0xF4,0x41,0x81, 0x04,0x40,0x80, 0x04,0x40,0x80, 0xFF,
    0x14,0x03, 0xA4,0x00,0xC0, 0x54,0x01,0x01, 0xF4,0x41,0x41, 0x04,0x40,0x40, 0x04,0x00,0x00, 0xFF,
    0x14,0x03, 0xA4,0x02,0xC2, 0x54,0x03,0x85, 0xF4,0x43,0xC5, 0x04,0x42,0xC4, 0x04,0x02,0x84, 0xFF
};

// challenge stage data
static const uint8 db_challg_stg_dat[] =
{
    0xFF,0x00, 0x00,0x06,0xC6, 0x00,0x07,0x07, 0x00,0x47,0x47, 0x00,0x46,0x46, 0x00,0x06,0x06, 0xFF, //  3
    0xFF,0x00, 0x00,0x08,0xC8, 0x00,0x09,0xC9, 0x00,0x09,0xC9, 0x00,0x48,0x48, 0x00,0x08,0x08, 0xFF, //  7
    0xFF,0x00, 0x00,0x0A,0x4A, 0x00,0x0B,0xCB, 0x00,0x0B,0xCB, 0x00,0x0A,0x4A, 0x00,0x16,0x56, 0xFF, // 11
    0xFF,0x00, 0x00,0x0C,0xCC, 0x00,0x0D,0x0D, 0x00,0x4D,0x4D, 0x00,0x0C,0xCC, 0x00,0x17,0xD7, 0xFF, // 15
    0xFF,0x00, 0x00,0x0E,0x0E, 0x00,0x0F,0x0F, 0x00,0x4F,0x4F, 0x00,0x0E,0x0E, 0x00,0x4E,0x4E, 0xFF, // 19
    0xFF,0x00, 0x00,0x10,0x10, 0x00,0x11,0xD1, 0x00,0x11,0xD1, 0x00,0x50,0x50, 0x00,0x10,0x10, 0xFF, // 23
    0xFF,0x00, 0x00,0x12,0x12, 0x00,0x13,0x13, 0x00,0x53,0x53, 0x00,0x52,0x52, 0x00,0x12,0x12, 0xFF, // 27
    0xFF,0x00, 0x00,0x14,0xD4, 0x00,0x15,0x15, 0x00,0x55,0x55, 0x00,0x14,0xD4, 0x00,0x14,0xD4, 0xFF  // 31
};

// This is a table of object IDs which organizes the mob into the series of 5 waves.
static const uint8 db_attk_wav_IDs[] =
{
    0x58, 0x5A, 0x5C, 0x5E, 0x28, 0x2A, 0x2C, 0x2E,
    0x30, 0x34, 0x36, 0x32, 0x50, 0x52, 0x54, 0x56,
    0x42, 0x46, 0x40, 0x44, 0x4A, 0x4E, 0x48, 0x4C,
    0x1A, 0x1E, 0x20, 0x24, 0x22, 0x26, 0x18, 0x1C,
    0x08, 0x0C, 0x12, 0x16, 0x10, 0x14, 0x0A, 0x0E
};

/*=============================================================================
;; c_2896()
;;  Description:
;;   c_01C5_new_stg_game_or_demo
;;   Called at beginning of each stage, including challenge stages and demo.
;;   Initializes mrw_sprite[n].cclr.b0 for 3 sets of creatures. Color code is
;;   packed into b<0:2>, and bomb-drop parameter packed into b<7>
;;   Called before c_25A2.
;; IN:
;;  ...
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
void c_2896(void)
{
    uint8 HL, IXL, A, B, C, D, E;

    // once per stage, set the player's private pointer to attack wave object setup tables
#ifndef HELP_ME_DEBUG
    plyr_state_actv.p_atkwav_tbl = &ds_8920_atk_wv_obj_tbl[0];
#else
    plyr_state_actv.p_atkwav_tbl = &ds_8920_atk_wv_obj_tbl[ 0 + 0x11 ];
#endif

    if (0 == plyr_state_actv.not_chllng_stg)
    {
        A = plyr_state_actv.stage_ctr >> 2; // rrca * 2
        C = A;
        A >>= 1; // rrca
        B = A;
        A &= 0x1C;
        A = B;
        if ( 0 != A )  A = 3;

        // l_28B5:
        A &= 0x03;

        stg_chllg_rnd_attrib[0] = d_stage_chllg_rnd_attrib[A + 0];
        stg_chllg_rnd_attrib[1] = d_stage_chllg_rnd_attrib[A + 1];

        A = C & 0x07;
        D = d_290E[A];
        E = D;

        // jr   l_28D0
    }
    else
    {
        // l_28CD_not_challenge_stage:
        D = 0x36; // bee parameter
        E = 0x24; // moth parameter
    }

    // l_28D0:
    HL = 0x08; // offsetof first bee in the group
    IXL = 1; // start count for bit shifting

    c_28E9(&IXL, &HL, 0x14, D); // 20 bees ... $08-$2E
    c_28E9(&IXL, &HL, 0x08, 0x10); // bosses and bonus-bees ... $30-$$3E
    c_28E9(&IXL, &HL, 0x10, E); // 16 moths ... $40
}

/*=============================================================================
;; c_28E9()
;;  Description:
;;    Initialize a class of creatures.
;; IN:
;;  B == number of creatures in this class
;;  HL == sprite_code_bufl[ $08 + ? ]
;;  IXL == every 8 counts, C == IY[ n++ ]
;;  IXH == $36 or $10 or $24
;; OUT:
;;  ...
;; First time, IXL==1, forcing C to be loaded.
;; After that, reload C every 8 times.
;; Each time, C is RL'd into Cy, and Cy RR'd into A.
;;----------------------------------------------------------------------------*/
void c_28E9(uint8 *pIXL, uint8 *pHL, uint8 B, uint8 IXH)
{
    static reg16 C; // make it 16 so we can shift out of bit-7
    static uint8 IY; // tmp index into d_2908[]
    uint8 A;

    while (B > 0)
    {
        (*pIXL)--;

        if (0 == *pIXL)
        {
            C.word = d_2908[ IY++ ];
            *pIXL = 8;
        }

        // l_28F5:
        C.word <<= 1;
        A = IXH >> 1;
        A |= (C.pair.b1 & 0x01) << 7;
        mrw_sprite.cclr[ *pHL ].b0 = A;

        (*pHL)++; // inc  l
        (*pHL)++; // inc  l

        B--; // djnz l_28E9
    }
}

/*===========================================================================
;; setup challenge stage bonus attributes at l_28B5 (b_9280 + 0x04)
;; .b0: add to bug_collsn[$0F]
;; .b1: obj_collsn_notif[] ... hit-flag + sprite-code for score tile
;; (base-score multiples are * 10 thanks to d_scoreman_inc_lut[0])
*/
static const uint8 d_stage_chllg_rnd_attrib[] =
{
    10, 0x80 + 0x38,
    15, 0x80 + 0x39,
    20, 0x80 + 0x3C,
    30, 0x80 + 0x3D
};
static const uint8 d_2908[] =
{
    0xA5, 0x5A, 0xA9, 0x0F, 0x0A, 0x50
};
static const uint8 d_290E[] =
{
    0x36, 0x24, 0xD4, 0xBA, 0xE4, 0xCC, 0xA8, 0xF4
};

/*=============================================================================
;; f_2916()
;;  Description:
;;   Inserts creature objects from the attack wave table into the movement
;;   queue. The table of attack wave structures is built in c_25A2.
;;   Each struct starts with $7E, and the end of table marker is $7F.
;;   This task will be enabled by c_01C5_new_stg_game_or_demo... after the
;;   creature classes and formation tables are initialized.
;; IN:
;;  ...
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
void f_2916(void)
{
    // check for end of table
    if (0x7F == *plyr_state_actv.p_atkwav_tbl)
    {
        // goto l_2A29_attack_waves_complete;

        // l_2A29_attack_waves_complete:
        if (0 == b_bugs_flying_nbr)
        {
            // the last one has found its position in the collective.
            task_actv_tbl_0[0x08] = 0; // f_2916 ... end of attack waves
            task_actv_tbl_0[0x04] = 1; // f_1A80 ... bonus-bee manager
            task_actv_tbl_0[0x10] = 1; // f_1B65 ... Manage flying-bug-attack

            plyr_state_actv.nest_lr_flag = 1; // inhibit nest left/right movement
        }
        return;
    }

    if (0x7E == *plyr_state_actv.p_atkwav_tbl)
    {
        if (0 == plyr_state_actv.b_atk_wv_enbl)
        {
            // 0 if restarting the stage (respawning player ship)
            return;
        }

        if (0 != b_bugs_flying_nbr)
        {
            // l_294D_set_tmr0
            ds4_game_tmrs[0] = 2;
            return;
        }

        if (0 == plyr_state_actv.not_chllng_stg)
        {
            if (1 == ds4_game_tmrs[0])
            {
                w_bug_flying_hit_cnt = 8;
                return;
            }

            // l_2942_chk_tmr0
            if (0 != ds4_game_tmrs[0])
            {
                return;
            }
        }

        // Finally... sending out next wave of creatures. We are on start token
        // ($7E) so do nothing on this time step.
        // l_2944_attack_wave_start:
        plyr_state_actv.p_atkwav_tbl++;
        plyr_state_actv.b_attkwv_ctr++;
        return;
    }
    else // ! 0x7E
    {
        uint8 IX; // used as index into bug_motion_que[], not as a byte-pointer
        uint8 A, B, C, L;
        uint8 token_b0; // holds the lsb of the token-pair until needed
        uint8 HL; // not a pointer, offset into db_2A6C

        // Process next object ... if frame_ct is multiple of 8, or bit 7 set.

        // l_2953_next_pair:
        // bit-7 is set if this toaster is a wing-man or a split waves, and therefore no delay,
        // otherwise it is clear for trailing formation i.e. delay before launching.
        if (0 == (*plyr_state_actv.p_atkwav_tbl & 0x80))
        {
            if (ds3_92A0_frame_cts[0] & 0x07) return;
        }

        // ready to insert another entry into the queue

        // make byte offset into lut at db_2A3C  (_finalize_object) ... also we're done with bit-7
        token_b0 = *plyr_state_actv.p_atkwav_tbl << 1; // sla  c

        // find a slot in the queue
        IX = 0;
        while (IX < 0x0C)
        {
            if (0 == (ds_bug_motion_que[IX].b13 & 0x01))
                break;

            IX++;
        }

        if (0x0C == IX)
        {
            // can't find one ... bummer
            return;
        }


        // l_2974_got_slot:
        plyr_state_actv.p_atkwav_tbl += 1; // inc  hl
        A = *plyr_state_actv.p_atkwav_tbl; // tbl[n].pair.h ... object ID/offset, e.g. 58

        if (0x78 == (A & 0x78)) //  [ object >= $78  &&  object < $80 ]
            A &= ~40; // res  6,a .. what object is > $78?

        // l_2980
        ds_bug_motion_que[IX].b10 = A; // ld   0x10(ix),a ... object index

        // advance to next token-pair e.g. HL:=8923
        plyr_state_actv.p_atkwav_tbl++; // inc  hl

        // use even object offsets of L to maintain consistency of indexing with z80
        L = A; // ld   h,#>b_8800 ... ld   l,a

        b8800_obj_status[ L ].state = 7; // 8800[L].l ... disposition = "spawning" ... i.e. case_2590

        // store the slot index for this object
        //       inc  l
        //       ld   e,ixl
        //       ld   (hl),e            ; 8800[L].h ... offset of slot (n*$14)
        b8800_obj_status[ L ].obj_idx = IX;


        if (0x38 != (A & 0x38)) //  if ( object >= $38 && object < $40 ) then goto _setup_transients
        {
            // Init routine c_2896 has populated the sprite code buffer such that each even
            // byte consists of the "primary" code (multiple of 8), AND'd with the color.
            uint8 D;

            D = mrw_sprite.cclr[ L ].b0; // use even object offsets of L

            A = D & 0x78;
            mrw_sprite.cclr[ L ].b0 = A;

            A = D & 0x07; // color table in bits<0:2>
            mrw_sprite.cclr[ L ].b1 = A;

            if (0 == (D & 0x80)) // bit  7,d
            {
                ds_bug_motion_que[IX].b0F = 0;
            }
            else
            {
                // l_29AE: bomb drop enable flags
                ds_bug_motion_que[IX].b0F = b_92E2_stg_parm[1];
            }
            // jr   l_29D1_finalize_object_setup
        }
        else
        {
            // handle the additional "transient" buggers that fly-in but don't join ... Stage 4 or higher.
            // l_29B3_setup_transients:
            // ld   h,#>_mrw_sprite_posn_base
        }

        // l_29D1_finalize_object_setup

        // first byte of token-pair, left-shifted 1 (byte-1 of _stg_dat triplet)
        C = token_b0 & ~0x80; // res  7,c

        // setup the bomb-drop counter
        B = 8;
        if (C & 0x02) // bit  1,c
            B = 0x44;

        ds_bug_motion_que[IX].b0E = B;

        // have to re-adjust C since the lut is implemented as a table of structs, not bytes.
        ds_bug_motion_que[IX].p08.word = db_2A3C[ C / 2 ].p_tbl;

        // In z80, these bits were in <7:5> of db_2A3C[].b1, but here they are already shifted into <2:0>
        A = db_2A3C[ C / 2 ].idx; // have to re-adjust C to use as an index into table of structs.

        // use byte offset as index into the lut
        // ld   hl,#db_2A6C
        // rst  0x10  ; HL += A
        HL = (A << 1) + A; // multiply x3 ... sneaky!

        // check the flag in b0 of byte-pair (left shifted 1, so in _stg_dat it is 0x40)
        // If set, take the second set of 3-bytes from the lut.
        if (token_b0 & 0x80)
        {
            HL += 3;
        }

        ds_bug_motion_que[IX].b01 = db_2A6C[HL + 0];
        ds_bug_motion_que[IX].b03 = db_2A6C[HL + 1];
        ds_bug_motion_que[IX].b05 = db_2A6C[HL + 2];

        ds_bug_motion_que[IX].b00 = 0;
        ds_bug_motion_que[IX].b02 = 0;
        ds_bug_motion_que[IX].b04 = 0;

        ds_bug_motion_que[IX].b0D = 1;
        A = token_b0 | 1;
        ds_bug_motion_que[IX].b13 = A & 0x81;
    }
    // l_2A29_attack_waves_complete: ... (above)
}


/*============================================================================
 * The original format of this data was packed into a 16-bit, as follows:
 * bits 0:12  - pointer to data tables for flying pattern control.
 * bits 13:15 - selection index into lut 2A6C.

 * I have reformatted to an array of structs with separate elements for the
 * pointer and lut index.
 * Indices into this table are placed into bits 0:5 of stage data tables.
 *===========================================================================*/
static const t_flite_ptn_cfg db_2A3C[] =
{
    {_flv_d_001d, 0x00},          // 0: stage 1
    {_flv_d_0067, 0x02},          // 1: stage 1
    {_flv_d_009f, 0x04},          // 2: stage 2
    {_flv_d_00d4, 0x02},          // 3: stage 2
    {_flv_d_017b, 0x00},          // 4: stage 2
    {_flv_d_01b0, 0x06},          // 5: stage 2
    {_flv_d_01e8, 0x00},          // 6: challenge stage (3)
    {_flv_d_01f5, 0x02},          // 7: challenge stage (3)
    {_flv_d_020b, 0x00},          // 8: challenge stage (7)
    {_flv_d_021b, 0x02},          // 9: challenge stage (7)
    {_flv_d_022b, 0x08},          // A: challenge stage (11)
    {_flv_d_0241, 0x02},          // B: challenge stage (11)
    {_flv_d_025d, 0x08},          // C: challenge stage (15)
    {_flv_d_0279, 0x02},          // D: challenge stage (15)
    {_flv_d_029e, 0x00},          // E: challenge stage (19)
    {_flv_d_02ba, 0x02},          // F: challenge stage (19)
{_flv_d_02d9, 0x00},          //     {0, 0x00},//      {_flv_i_02D9, 0x00},          // 10: challenge stage (23)
{_flv_d_02fb, 0x02},          //     {0, 0x02},//      {_flv_i_02FB, 0x02},          // 11: challenge stage (23)
{_flv_d_031d, 0x00},          //     {0, 0x00},//      {_flv_i_031D, 0x00},          // 12: challenge stage (27)
{_flv_d_0333, 0x02},          //     {0, 0x02},//      {_flv_i_0333, 0x02},          // 13: challenge stage (27)
    {_flv_d_0fda, 0x00},          // 14: challenge stage (31)
    {_flv_d_0ff0, 0x02},          // 15: challenge stage (31)
    {_flv_d_022b, 0x0A},          // 16: challenge stage (11)
    {_flv_d_025d, 0x0A},          // 17: challenge stage (15)
};

/*
 ** bits 13:15 from above provide selection index into the lut.
 ** bit-6 of _stg_dat selects the second set of 3-bytes.
 */
static const uint8 db_2A6C[] =
{
    // 0x01(ix) 0x03(ix) 0x05(ix)
    0x9B, 0x34, 0x03, // 0
    0x9B, 0x44, 0x03,
    0x23, 0x00, 0x00, // 2
    0x23, 0x78, 0x02,
    0x9B, 0x2C, 0x03, // 4
    0x9B, 0x4C, 0x03,
    0x2B, 0x00, 0x00, // 6
    0x2B, 0x78, 0x02,
    0x9B, 0x34, 0x03, // 8
    0x9B, 0x34, 0x03,
    0x9B, 0x44, 0x03, // A
    0x9B, 0x44, 0x03
};

/*=============================================================================
;; f_2A90()
;;  Description:
;;   left/right movement of collective while attack waves coming in at
;;   start of round.
;; IN:
;;  ...
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
void f_2A90(void)
{
    uint8 B, C, L;


    if (((ds3_92A0_frame_cts[0] - 1) & 0x03) != 0) // why -1 ?
        return;

    // check for exit condition
    if (0 == b_bugs_actv_nbr &&
            0 == task_actv_tbl_0[0x08]) // f_2916 ... end of attack waves
    {
        // l_2AE9_done: last bug of challenge is gone or killed
        task_actv_tbl_0[0x0A] = 0; // f_2A90 (this task)
        return;
    }

    C = 1; // left
    if (0 != glbls9200.bug_nest_direction_lr)
    {
        C = -1; // right
    }

    // l_2AAB: update the table
    L = 0;
    B = 10;

    while (B-- > 0)
    {
        ds_home_posn_loc[ L ].rel += C;
        ds_home_posn_org[ L ].pair.b0 += C;
        L += 2;
    }

    if (0 == plyr_state_actv.nest_lr_flag ||
            0 != ds_home_posn_loc[ 0 ].rel)
    {
        if (32 == ds_home_posn_loc[ 0 ].rel)
        {
            glbls9200.bug_nest_direction_lr = 1;
        }
        if (-32 == (sint8) ds_home_posn_loc[ 0 ].rel) // TODO: signed data type?
        {
            glbls9200.bug_nest_direction_lr = 0;
        }
        return;
    }

    // the formation is complete... diving attacks shall commence
    // l_2ADA_done:
    glbls9200.bug_nest_direction_lr = 0;
    task_actv_tbl_0[0x0A] = 0; // f_2A90 (this task)
    b_9AA0[0x00] = 1;          // sound mgr
    task_actv_tbl_0[0x09] = 1; // f_1DE6 ... collective bug movement
    return;
}
