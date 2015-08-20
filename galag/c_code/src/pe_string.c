/*******************************************************************************
**  galag: precise re-implementation of a popular space shoot-em-up
**  pe_string.c (gg1-2.3m)
**
**  Utility functions, player and stage setup, text display.
**
*******************************************************************************/

#include "galag.h"

/*
; "Declare Effective Address" macro (idfk)
; Generates offsets in Playfield Tile RAM from given row/column ordinates. _R
; and _C are 0 based, and this is reflected in the additional "-1" term. The
; coordinate system applies only to the "Playfield" area and is independent of
; the top two rows and bottom two rows of tiles.
; (See Tile RAM & color RAM layout ascii art diagram in mrw.s).
 */
#define  _dea( _R, _C ) \
  /* m_tile_ram + */ 0x40 + ( 0x1C - _C - 1 ) * 0x20 + _R


uint16 j_string_out_pe(uint8 pe, uint16 usepos, uint8 idx);


// this string doesn't correspond to ASCII, the rest are embedded directly into
// the struct definition
static const char d_cstr_mfrnm[] = { 0x66, 0x67, 0x68, 0x69, 0x6A, 0x6B, 0x6C, 0x2F };// "NAMCO" (in styled font)

static str_pe_t d_cstring_tbl[] = {
    // $00 (placeholder for indexing)
    {
        _dea(11, 6), // 02EB
        0x00, "PUSH START BUTTON/"
    },
    {
        // $01
        _dea(11, 6), // 02EB
        0x00, "PUSH START BUTTON/"
    },
    {
        // $02
        _dea(16, 10), // 0270
        0x00, "GAME OVER/"
    },
    {
        // $03
        _dea(16, 10), // 0270
        0x00, "READY !/" // '!' displays as <space>
    },
    {
        // $04
        _dea(16, 11), // 0250
        0x00, "PLAYER 1/"
    },
    {
        // $05
        0,
        0x00, "PLAYER 2/"
    },
    {
        // %06
        _dea(16, 10), // 0270
        0x00, "STAGE /"
    },
    {
        // $07
        _dea(16, 5), // 0310
        0x00, "CHALLENGING STAGE/"
    },
    {
        // $08
        _dea(16, 5), // 0310
        0x00, "NUMBER OF HITS/"
    },
    {
        // $09
        _dea(19, 8), // 02B3
        0x00, "BONUS  /"
    },
    {
        // $0A
        _dea(17, 6), // 02F1
        0x04, "FIGHTER CAPTURED/"
    },
    {
        // $0B
        _dea(13, 0), // 03AD
        0x00, "                           /" // 27 spaces
    },
    {
        // $0C
        _dea(13, 10), // 026D
        0x04, "PERFECT c/"
    },
    {
        // $0D
        _dea(19, 2), // 0373
        0x05, "SPECIAL BONUS 10000 PTS/"
    },
    {
        // $0E
        _dea(2, 11), // 0242
        0x00, "GALAGA/"
    },
    {
        // $0F
        _dea(5, 8), // 02A5
        0x00, "]] SCORE ]]/"
    },
    {
        // $10
        _dea(8, 12), // 0228
        0x00, "50    100/"
    },
    {
        // $11
        _dea(10, 12), // 022A
        0x00, "80    160/"
    },
    {
        // $12
        _dea(11, 12), // 022B
        0x00, "/"
    },
    {
        // $13
        _dea(27, 6), // 02FB
        0x03, "e 1981 NAMCO LTDa/"
    },
    {
        // $14
        _dea(30, 11), // 025E
        0x04, d_cstr_mfrnm // "NAMCO" (in styled font)
    },
    {
        // $15
        _dea(15, 9), // 028F
        0x04, "]RESULTS]/"
    },
    {
        // $16
        _dea(18, 4), // 0332
        0x05, "SHOTS FIRED          /"
    },
    {
        // $17
        0,
        0x05, "  MISSILES/"
    },
    {
        // $18
        _dea(21, 4), // 0335
        0x05, "NUMBER OF HITS       /"
    },
    {
        // $19
        _dea(24, 4), // 0338
        0x03, "HIT]MISS RATIO       /"
    },
    {
        // $1A
        0,
        0x03, "$`/" // '`' displays as "%" ("$" displays as <space>)
    },
    {
        // $1B
        _dea(15, 4), // 032F
        0x05, "1ST BONUS FOR   /"
    },
    {
        // $1C
        _dea(18, 4), // 0332
        0x05, "2ND BONUS FOR   /"
    },
    {
        // $1D
        _dea(21, 4), // 0335
        0x05, "AND FOR EVERY   /"
    },
    {
        // $1E
        0,
        0x05, "0000 PTS/"
    },

};

/*=============================================================================
;; c_string_out()
;;  Description:
;;    Copy a series of characters to tile-ram (see d_cstring_tbl).
;;    Converts characters strings from ASCII to corresponding character tiles.
;;    Machine character set:
;;     $00 - $09 : decimal digit characters.
;;     $0A - $23 : A-Z
;;     $24       : <space>
;;    String length is variant - the termination token is $2F (ascii "/").
;;    Can be called two ways:
;;    CALL:
;;      Destination position address is passed in HL and swapped into DE.
;;    RST $30:
;;      RST $30 sets the CY flag and JPs to string_out_pe.
;;      The string pointer is then offset (-2) i.e. sizeof(ptr) to get
;;      the destination position address, which winds up in DE.
;;      With the position address in DE, the rest of the routine is the same.
;;  IN:
;;    HL: position in tile RAM.
;;    C: index into table of string pointers (d_cstring_tbl)
;;    CY="set" if jumped to j_string_out_pe
;;  OUT:
;;    HL contains final string character display position.
;;
;;    PRESERVES :   DE
;;----------------------------------------------------------------------------*/
void c_string_out(uint16 pos, uint8 idx)
{
    uint8 Cy;
    // and  a       ; clear CY flag.
    // ex   af,af   ; save CY flag.
    Cy = 0;
    j_string_out_pe(Cy, pos, idx);
}

/**************************************************
 *      scf
 *      ex   af,af'
 *      jp   j_string_out_pe
 *
 *  IN:
 *    pe: 1 if position encoded string (Cy=set)
 *    pos: position argument is used if pe==0
 *    idx: index of string in table
 *
 ***************************************************/
uint16 j_string_out_pe(uint8 pe, uint16 pos, uint8 idx)
{
    str_pe_t *p_sptr = &d_cstring_tbl[idx];
    uint16 HL;
    const char *DE;
    uint8 C;

    C = p_sptr->color;
    DE = p_sptr->chars;

    if (0 == pe)
        HL = pos;
    else
        HL = p_sptr->posn;

    while ('/' != *DE) // if ( TERMINATION ) then exit
    {
        char A = *DE;

        A -= 0x30;

        // e.g. ASCII "A" ... ($41 - $30) = $11
        // e.g. ASCII "A" ... ($41 - $30 - $07) = $0A
        if (A < 0)
        {
            A = 0x24; // only a <space> character ($20) should be < $30
        }
        else if (A >= 0x11)
        {
            A -= 7;
        }

        *(m_tile_ram + HL) = A;
        *(m_color_ram + HL) = C;
        DE++; // psrc++

        HL -= 0x20; // advance destination position one tile to the "right"
    }
    return HL;
}
