;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; gg1-4.s
;;  gg1-4.2l 'maincpu' (Z80)
;;
;;  Hi-score dialog, power-on memory tests, and service-mode menu functions
;;  combined into gg1-4 and removed files reset.s and svc_mode.s
;;  from branch "sdasz80_03172012".
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.module game_over

.include "sfrs.inc"
.include "structs.inc"
.include "gg1-4.dep"

;.area ROM (ABS,OVR)
;       .org 0x2FFF
;       .db 0x74                                   ; checksum
.area CSEG30


;;=============================================================================
;; _top5_dlg_proc()
;;  Description:
;;   Checks players score for ranking in the Best 5. Scores are 6 characters
;;   BCD format, stored highest digit (100000's) at highest address of array.
;;   This is called from game_ctrl (background task) and is blocking on the
;;   game-timers.
;;   Returns from 317F
;; IN:
;;  ...
;; OUT:
;;  ...
;; Note: 83ED-83F2 is high score in tile RAM.
;;-----------------------------------------------------------------------------
c_top5_dlg_proc:
       ld   hl,#m_tile_ram + 0x03E0 + 0x1D        ; 100000's digit of plyr1 score (83F8-FD)
       ld   a,(ds_plyr_actv +_b_plyr_nbr)         ; 0==plyr1, 1==plyr2
       and  a
       jr   z,l_300C
       ld   hl,#m_tile_ram + 0x03E0 + 0x08        ; 100000's digit of plyr2 score (83E3-E8)

l_300C:
; setup pointer to active player score in HL. Offset 5 advances pointer to 100000's place character.
       ld   (b_8A00 + 0x00),hl                    ; ptr to plyr1 score or plyr2 score on screen.

       ld   de,#b_best5_score5 + 0x05
       call c_31F7_chk_score_rank                 ; score > 5th place?
       ret  nc

       ld   de,#b_best5_score4 + 0x05
       call c_31F7_chk_score_rank                 ; score > 4th place?
       ld   a,#5
       jr   nc,l_3047

       ld   de,#b_best5_score3 + 0x05
       call c_31F7_chk_score_rank                 ; score > 4th place?
       ld   a,#4
       jr   nc,l_3047

       ld   de,#b_best5_score2 + 0x05
       call c_31F7_chk_score_rank                 ; score > 3th place?
       ld   a,#3
       jr   nc,l_3047

       ld   de,#b_best5_score1 + 0x05
       call c_31F7_chk_score_rank                 ; score > 2th place?
       ld   a,#2
       jr   nc,l_3047

       ld   a,#0xFF
       ld   (0x9AA0 + 0x0C),a                     ; special tune for 1st place
       ld   a,#1
       jr   l_304A
l_3047:
       ld   (0x9AA0 + 0x10),a                     ; select the tune

l_304A:
; set the jp address for the subroutine.
       ld   (b_8A00 + 0x11),a                     ; 1==1ST place etc.
       ld   hl,#d_31A6                            ; jp table address
       dec  a
       rst  0x08                                  ; HL += 2A
       call c_3118_insert_top5_score

; insert new player name in table.
; data: 0,3,6,9,12 (12 for first place)
; the table gives repetition count for ldir below ( 5 - X * 3 ) where X is 1st through 5th place.
       ld   a,(b_8A00 + 0x11)                     ; 1==1ST place etc. ... d_31A1 [ A - 1 ]
       ld   hl,#d_31A1                            ; ld the table address
       dec  a
       rst  0x10                                  ; HL += A
       ld   a,(hl)
       ld   hl,#b_best5_name4 + 0x02              ; 3rd letter of 4th place name
       ld   de,#b_best5_name5 + 0x02              ; 3rd letter of 5th place name
       and  a
       jr   z,l_306C
       ld   c,a
       ld   b,#0
       lddr
; note, HL now == &newname[0] - 1
l_306C:
       ld   b,#3
       ld   a,#0x24                               ; clear the old name out (3 space characters)
       ld   (b_8A00 + 0x04),hl                    ; pointer to new name in table... address would be  &newname[0] - 1
l_3073:
       inc  l                                     ; pre-increment since we start at ( &newname[0] - 1 )
       ld   (hl),a
       djnz l_3073

       ld   a,#0x49
       ld   (b_8A00 + 0x10),a                     ; $49 ... lower address byte of first character of name entry in tile-ram

       ld   hl,#s_327F_enter_your_initials
       call c_text_out_ce                         ; "ENTER YOUR INITIALS !"
       call c_text_out                            ; "SCORE  NAME"          HL==3298
       call c_text_out_ce                         ; "TOP 5"                HL==32AB

       ld   de,#m_tile_ram + 0x0300 + 0x09
       ld   hl,(b_8A00 + 0x00)                    ; ptr to plyr1 score or plyr2 score on screen.
       call c_3275                                ; puts players score below "SCORE"

; puts_AAA (default initials of new score entry) below NAME
       ld   hl,#m_tile_ram + 0x0140 + 0x09        ; row below 'A' in "NAME"
       ld   de,#-32                               ; offset 1 column right
       ld   (hl),#0x0A
       add  hl,de
       ld   (hl),#0x0A
       add  hl,de
       ld   (hl),#0x0A

       call c_puts_top5scores
       call c_plyr_initials_entry_hilite_line

; wait 2 seconds
       ld   a,#4
       ld   (ds4_game_tmrs + 2),a
l_30AA:
       ld   a,(ds4_game_tmrs + 2)
       and  a
       jr   nz,l_30AA

       ld   a,#40                                 ; 20 seconds
       ld   (ds4_game_tmrs + 2),a                 ; :=$28

; jp here from section _314C
l_30B5_next_char_selectn:
       call c_puts_top5scores
       call c_plyr_initials_entry_hilite_line

; get time 0 from frame counter
       ld   a,(ds3_92A0_frame_cts + 0)
       ld   c,a

; jp here to return from section _stick_right
l_30BF_dlg_proc:
l_30BF_frame_sync:
       call c_32ED_top5_dlg_endproc               ; checks coin-in once per frame
       ld   a,(ds3_92A0_frame_cts + 0)
       cp   c
       jr   z,l_30BF_frame_sync

       ld   c,a
       and  #0x0F                                 ; 15 frames
       call z,c_3141_xor_char_color               ; alternate color 4 times/second

; read IO port: setup for second player control panel if needed for tabletop
       ld   hl,#ds3_99B5_io_input + 0x01          ; plyr 1 input register
       ld   a,(b_9215_flip_screen)
       and  a
       jr   z,l_30D8_chk_button
       inc  hl                                    ; HL := &io_input[2]
l_30D8_chk_button:
       bit  4,(hl)                                ; check for button (active low)
       jp   z,j_314C_select_char                  ; jp l_30B5 on 1st or 2nd letter selection...
                                                  ; ... ret from _top5_dlg_proc after 3rd letter selection
       ld   a,(hl)
       and  #0x0A
       ld   hl,#b_8A00 + 0x02                     ; L==2, R==8 X=A   previous controller state
       ld   de,#b_8A00 + 0x03                     ; character selection counter/timer
       cp   (hl)
       jr   z,l_30ED
       ld   (hl),a                                ; the controller state has changed... save previous state
; reset the counter/timer
       ld   a,#0xFD                               ; (first timeout at next frame)
       ld   (de),a                                ; (8A03) := $FD
; increment the counter/timer and check for 16 frames elapsed
l_30ED:
       ld   a,(de)                                ; DE==$8A03
       inc  a
       ld   (de),a                                ; *($8A03)++
       and  #0x0F
       jr   nz,l_30BF_dlg_proc                    ; done with this frame

; update letter selection every 1/4 second based on stick input.
       ld   a,(hl)                                ; get control stick value L==2, R==8 X==A
       cp   #8
       jr   z,l_311D_stick_right                  ; returns by  jp l_30BF
       cp   #2
       jr   nz,l_30BF_dlg_proc                    ; stick not left (or right)
       ld   a,#40                                 ; 20 seconds
       ld   (ds4_game_tmrs + 2),a                 ; reset timer

       ld   a,(b_8A00 + 0x10)                     ; lower byte of first character's address in v-ram
       ld   l,a
       ld   h,#>m_tile_ram + >0x0100
       ld   a,(hl)
       dec  a
       cp   #9                                    ; check for if wrap around bottom-to-top
       call z,c_3138_lda2A                        ; A:=$2A  (allow the '.' character)
       cp   #0x29
       call z,c_313B_lda24                        ; A:=$24  (24 is "space", 23 is 'Z')
       ld   (hl),a
       jp   l_30BF_dlg_proc

;;=============================================================================
;; c_3118_insert_top5_score()
;;  Description:
;;   Inserts the new Top 5 score in the table.
;; IN:
;;  HL== jp table address from d_31A6, i.e:
;;    case_31B0
;;    case_31B4
;;    case_31B8
;;    case_31CE
;;    case_31D9
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_3118_insert_top5_score:
       ld   a,(hl)
       inc  hl
       ld   h,(hl)
       ld   l,a
       jp   (hl)
; returns from jp'd section

;;=============================================================================
;; l_311D_stick_right()
;;  Description:
;;   Update current character selection and reset the keep alive timer. Handles
;;   wrap-around top-to-bottom
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
l_311D_stick_right:
; get lower byte of current character's address in v-ram
       ld   a,(b_8A00 + 0x10)                     ; HL = $8000 + $0100 + b_8A00[ 0x10 ]
       ld   l,a
       ld   h,#>m_tile_ram + >0x0100
       ld   a,#40                                 ; 20 seconds
       ld   (ds4_game_tmrs + 2),a                 ; reset timer
       ld   a,(hl)
       inc  a
       cp   #0x2B                                 ; 2A is '.' character which is allowed
       call z,c_313E_lda0A
       cp   #0x25                                 ; 2A is ' ' character which is allowed
       call z,c_3138_lda2A
       ld   (hl),a
       jp   l_30BF_dlg_proc

;;=============================================================================
;; c_3138_lda2A()
;;  Description:
;;   Refactoring gone mad...
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_3138_lda2A:
       ld   a,#0x2A
       ret

;;=============================================================================
;; c_313B_lda24()
;;  Description:
;    This seems somewhat inefficient.
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_313B_lda24:
       ld   a,#0x24
       ret

;;=============================================================================
;; c_313E_lda0A()
;;  Description:
;;   Really?
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_313E_lda0A:
       ld   a,#0x0A
       ret

;;=============================================================================
;; c_3141_xor_char_color()
;;  Description:
;;    Invert current color code of selected character.
;;    0 Cyan -> 5 Yellow
;; IN:
;;  *(b_8A00 + 0x10) == lower byte of selected character's address in v-ram
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_3141_xor_char_color:
; lower byte of selected character's address in v-ram
       ld   a,(b_8A00 + 0x10)                     ; HL = $8400 + $0100 + b_8A00[ 0x10) ]
       ld   l,a
       ld   h,#>m_color_ram + >0x0100
       ld   a,(hl)
       xor  #0x05
       ld   (hl),a
       ret

;;=============================================================================
;; j_314C_select_char()
;;  Description:
;;    'enter your intiials', handle fire button input.
;;    Returns from _top5_dlg_proc after 3rd initial entered.
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
j_314C_select_char:
; get the selected character from the 1st,2nd,or 3rd slot.
; get lower byte of current character's address in v-ram
       ld   a,(b_8A00 + 0x10)                     ; HL = $8400 + $0100 + b_8A00[ 0x10 ]
       ld   l,a
       ld   h,#>m_color_ram + >0x0100
       ld   (hl),#0                               ; set color to Cyan
       ld   h,#>m_tile_ram + >0x0100
       ld   c,(hl)                                ; copy the character from the input entry position in tile-ram
       ld   a,#40                                 ; 20 seconds
       ld   (ds4_game_tmrs + 2),a                 ; :=$28

; get the pointer to the new name entry in the table, and increment since it is actually ( &name[0] -1 )
       ld   hl,(b_8A00 + 0x04)
       inc  hl

       ld   (hl),c                                ; copy the character to the table
       ld   (b_8A00 + 0x04),hl                    ; save the updated pointer

       ld   hl,#b_8A00 + 0x10                     ; get lower byte of current input character's address in v-ram
       ld   a,(hl)
       sub  #0x20                                 ; offset one position (column) to the right
       ld   (hl),a

; the characters are entered at xx49, xx29, xx09.
; so at the 3rd character, the sub $20 would result in a Cy.
       jp   nc,l_30B5_next_char_selectn

; after 3rd character has been accepted, update the display and wait for the music to time out.
       call c_puts_top5scores                     ; selected character appears in the name under TOP 5
       call c_plyr_initials_entry_hilite_line

       ld   a,#76
       ld   (ds3_92A0_frame_cts + 0),a            ; :=$4C
l_3179:
       ld   a,(ds3_92A0_frame_cts + 0)
       and  a
       jr   nz,l_3179
       ret

;;=============================================================================
;; c_plyr_initials_entry_hilite_line()
;;  Description:
;;   Hi-lite the row in yellow text corresponding to the player's score
;;   ranking on the "Enter your initials" dialog screen.
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_plyr_initials_entry_hilite_line:
       ld   a,(b_8A00 + 0x11)                     ; 1==1ST place etc.
       ld   hl,#d_3197_hiscore_line_ptrs
       dec  a
       rst  0x08                                  ; HL += 2A (determine index into table of word ptrs)
       ld   a,(hl)
       inc  hl
       ld   h,(hl)
       ld   l,a
       ld   b,#0x16                               ; number of characters to modify
       ld   de,#-0x20                             ; advance 1 cell column to the right
l_3191:
       ld   (hl),#5                               ; set character attribute byte to hi-lite color.
       add  hl,de
       djnz l_3191
       ret

;;=============================================================================
;; Table of pointers to each line of on-screen Top 5 table. Reminider that each
;; additional 2 byte increment offsets the pointer down 1 row (due to how v-ram
;; is organized).
;;
d_3197_hiscore_line_ptrs:
       .dw m_color_ram + 0x0374
       .dw m_color_ram + 0x0376
       .dw m_color_ram + 0x0378
       .dw m_color_ram + 0x037A
       .dw m_color_ram + 0x037C

;;=============================================================================
d_31A1:
       .db 0x0C,0x09,0x06,0x03,0x00


;;=============================================================================
;;  Description:
;;   pointers for c_3118_insert_top5_score
;;-----------------------------------------------------------------------------
d_31A6:
       .dw case_31B0
       .dw case_31B4
       .dw case_31B8
       .dw case_31CE
       .dw case_31D9

case_31B0:
       ld   a,#0x12
       jr   l_31BA
case_31B4:
       ld   a,#0x0C
       jr   l_31BA
case_31B8:
       ld   a,#0x06
l_31BA:
       ld   hl,#b_best5_score4 + 0x05
       ld   de,#b_best5_score5 + 0x05
       ld   bc,#0x0006
       lddr
       ld   de,#b_best5_score4 + 0x05
       ld   c,a
       lddr
       jp   case_31D9

case_31CE:
       ld   de,#b_best5_score5 + 0x05
       ld   hl,#b_best5_score4 + 0x05
       ld   bc,#0x0006
       lddr

case_31D9:
       ld   a,(b_8A00 + 0x11)                     ; 1==1ST place etc. ... index into hi-score table ... d_31ED[ 2 * (A - 1) ]
       dec  a
       ld   hl,#d_31ED_hi_score_tbl               ; array of addresses of score table elements
       rst  0x08                                  ; HL += 2A
       ld   e,(hl)
       inc  hl
       ld   d,(hl)
       ld   hl,(b_8A00 + 0x00)                    ; ptr to plyr1 score or plyr2 score on screen.
       ld   bc,#0x0006
       lddr
       ret

;;=============================================================================
;; pointers to individual score strings of Top 5 table (documented elsewhere)
;; scores only, complete table structure in s_32C5
d_31ED_hi_score_tbl:
       .dw b_best5_score1 + 0x05
       .dw b_best5_score2 + 0x05
       .dw b_best5_score3 + 0x05
       .dw b_best5_score4 + 0x05
       .dw b_best5_score5 + 0x05

;;=============================================================================
;; c_31F7_chk_score_rank()
;;  Description:
;;  called by _top5_dlg_proc, once for each of 5th place score, 4th place etc.
;;
;; IN:
;;  DE == pointer to 100000's digit (highest address) of score table entry.
;;  $8A00 == pointer to 100000's digit (highest address) of either plyr1
;;           or plyr2 score (6 characters in tile-ram).
;; OUT:
;;  Cy (Player Score > Table Entry)
;;-----------------------------------------------------------------------------
c_31F7_chk_score_rank:
       ld   hl,(b_8A00 + 0x00)                    ; ptr to plyr1 score or plyr2 score on screen.
       ld   b,#6
l_31FC:
       ld   a,(de)                                ; score digit

; skip "spaces" (only the 100000 place of table entry could be "space" character)
       cp   #0x24
       jr   z,l_320E

; ... and since table entries are all at least 20000, then any space in the player score will not place.
       ld   a,(hl)                                ; ptr to plyr1 score or plyr2 score on screen
       cp   #0x24
       ret  z

       ld   a,(de)
l_3206:
; sets Cy if score digit > table digit
       cp   (hl)                                  ; ptr to plyr1 score or plyr2 score on screen
       ret  nz
l_3208:
       dec  l
       dec  e
       djnz l_31FC

       xor  a
       ret

l_320E:
; table digit == $24
       cp   (hl)                                  ; ptr to plyr1 score or plyr2 score on screen
       jr   z,l_3208                              ; if both spaces, jp to next
; score digit != $24 ...
       xor  a                                     ; "table digit"
       jr   l_3206

;;=============================================================================
;; hiscore_heroes()
;;  Description:
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_mach_hiscore_show:
       ld   hl,#str_3345                          ; 'GALACTIC HEROES'
       call c_text_out_ce
       call c_text_out_ce                         ; 'BEST 5'  hl==335c

;;=============================================================================
;; hiscore_scrn()
;;  Description:
;;   Common sub for Enter Initials and Galactic Heroes - display each score
;;   entry under "TOP 5".
;;
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_puts_top5scores:
       ld   hl,#s_32B4_score_name
       call c_text_out                            ; puts 'SCORE     NAME' below 'TOP 5'
       ld   b,#1                                  ; starting index for c_3231
       call c_3231                                ; '1ST............'
       call c_3231                                ; '2ND............'
       call c_3231                                ; '3RD............'
       call c_3231                                ; '4RD............'
                                                  ; continue to '5TH' ...
;;=============================================================================
;; c_3231()
;;  Description:
;;   Setting lines for hi-score table. 1st,2nd,3rd,and 4th are by calling the
;;   function. 5th is by allowing execution to fall through from c_puts_top5scores.
;;   Each call to 3270 offsets DE for the next column (-$20) and advanced HL.
;; IN:
;;  B=rank (1 to 5)
;; OUT:
;;  B+=1
;;-----------------------------------------------------------------------------
c_3231:
       ld   a,b                                   ; B=rank (1 to 5)
       dec  a
       add  a,a
       add  a,a
       add  a,a                                   ; A=offset into table ... (B-1)*8
       ld   hl,#s_32C5                            ; score placement characters: 'ST', 'ND', 'RD' etc.
       rst  0x10                                  ; HL += A
       ld   e,(hl)                                ; destination lo-byte
       inc  hl
       ld   d,(hl)                                ; destination hi-byte
       inc  hl
       ld   a,b                                   ; B=numerical score placement
       ld   (de),a                                ; putc '5' of '5TH' on screen.
       call c_3273                                ; DE:-=$20
       call c_3270                                ; putc 'T' of '5TH' on screen.
       call c_3270                                ; putc 'H' of '5TH' on screen.
       call c_3273                                ; DE:-=$20
       call c_3273                                ; DE:-=$20
       ld   a,(hl)                                ; const ptr to score (lo-byte)
       inc  hl
       ld   c,(hl)                                ; const ptr to score (lo-byte)
       inc  hl
       push hl                                    ; save const ptr to player initials.
       ld   h,c
       ld   l,a                                   ; HL=ptr to 6-bytes score text
       call c_3275                                ; puts 'XXXXX' of 5th place on screen.
       ld   a,e
       sub  #0x20 * 6                             ; advance column ptr right 6 characters.
       ld   e,a
       jr   nc,l_3260
       dec  d                                     ; when not jr?
l_3260:
       pop  hl
       ld   a,(hl)
       inc  hl
       ld   h,(hl)
       ld   l,a
       call c_3270                                ; putc 1st initial
       call c_3270                                ; putc 2nd initial
       call c_3270                                ; putc 3rd initial
       inc  b
       ret

;;=============================================================================
;; c_3270()
;;  Description:
;; IN:
;;  HL=character to "putc".
;;  DE=destination position.
;; OUT:
;;  Increments HL (useful for multi-character strings)
;;-----------------------------------------------------------------------------
c_3270:
       ld   a,(hl)
       ld   (de),a
       inc  hl

;;=============================================================================
;; c_3273()
;;  Description:
;;   Use with "puts" routines to advance one character to right in tile memory.
;;   This is continuation of 3270 above, but also is called explicitly.
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_3273:
       rst  0x20                                  ; DE-=$20
       ret
; end 'call _3270'

;;=============================================================================
;; c_3275()
;;  Description:
;;  Copies a 6 byte string.
;;  The format for '12345' is: "0x05 0x04 0x03 0x02 0x01 0x24" (24 is space)
;; IN:
;;  HL=pointer to source string (last character i.e. the "space")
;;  DE="puts" destination address.
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_3275:
       ld   c,#6
l_3277:
       ld   a,(hl)
       ld   (de),a
       dec  hl
       rst  0x20                                  ; DE-=$20
       dec  c
       jr   nz,l_3277
       ret                                        ; end 'call _3275'

;;=============================================================================
;;  Description:
;;   High score table strings.
;;-----------------------------------------------------------------------------
s_327F_enter_your_initials:
; "ENTER YOUR INITIALS !"
       .dw m_tile_ram + 0x0320 + 0x04
       .db 0x15
       .db 0x04                                   ; color code (c_text_out_ce)
       .db 0x0E,0x17,0x1D,0x0E,0x1B,0x24,0x22,0x18,0x1E,0x1B,0x24,0x12,0x17,0x12,0x1D,0x12,0x0A,0x15,0x1C,0x24,0x2C
; "SCORE       NAME" (after l_3073, in cyan ... not color encoded)
       .dw m_tile_ram + 0x02E0 + 0x07
       .db 0x10
       .db 0x1C,0x0C,0x18,0x1B,0x0E,0x24,0x24,0x24,0x24,0x24,0x24,0x24,0x17,0x0A,0x16,0x0E
; "TOP 5" (32AB)
       .dw m_tile_ram + 0x0240 + 0x10
       .db 0x05
       .db 0x04                                   ; color code (c_text_out_ce)
       .db 0x1D,0x18,0x19,0x24,0x05
s_32B4_score_name:
; "SCORE     NAME" (c_puts_top5scores)
       .dw m_tile_ram + 0x0280 + 0x12
       .db 0x0E
       .db 0x1C,0x0C,0x18,0x1B,0x0E,0x24,0x24,0x24,0x24,0x24,0x17,0x0A,0x16,0x0E

; formatting for score table list at _3236
;  struct{
;   byte *position_address
;   char2[] text
;   byte *score_bcd    ( e.g. "123456" encoded as "06 05 04 03 02 01" and ptr=&"01")
;   byte *initials
s_32C5:
       .dw m_tile_ram + 0x0340 + 0x14
       .db 0x1C,0x1D  ;; "ST"
       .dw b_best5_score1 + 0x05
       .dw b_best5_name1
       ;
       .dw m_tile_ram + 0x0340 + 0x16
       .db 0x17,0x0D  ;; "ND"
       .dw b_best5_score2 + 0x05
       .dw b_best5_name2
       ;
       .dw m_tile_ram + 0x0340 + 0x18
       .db 0x1B,0x0D  ;; "RD"
       .dw b_best5_score3 + 0x05
       .dw b_best5_name3
       ;
       .dw m_tile_ram + 0x0340 + 0x1A
       .db 0x1D,0x11  ;; "TH"
       .dw b_best5_score4 + 0x05
       .dw b_best5_name4
       ;
       .dw m_tile_ram + 0x0340 + 0x1C
       .db 0x1D,0x11  ;; "TH"
       .dw b_best5_score5 + 0x05
       .dw b_best5_name5

;;=============================================================================
;; c_32ED_top5_dlg_endproc()
;;  Description:
;;   Closes the 'enter your initials' process.
;;   checks credits available and exits early if credits are available.
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_32ED_top5_dlg_endproc:
; if (free-play)
       ld   a,(ds3_99B5_io_input + 0x00)          ; io_input[credit_count]
       cp   #0xA0
       jr   z,l_32FB_check_for_timeout
; else if ( hw credit cnt > current credit count ) goto finish
       ld   b,a
       ld   a,(b8_99B8_credit_cnt)
       cp   b
       jr   c,l_3300_finish

l_32FB_check_for_timeout:
       ld   a,(ds4_game_tmrs + 2)
       and  a
       ret  nz

; Time up. Copy available characters from input to Top 5 score name table.

; The pop forces 1 stack frame to be skipped (returns to caller of _top5_dlg_proc)
l_3300_finish:
       pop  hl

; Setup HL and DE as pointers for copy from input characters to new Top5 table name entry.
       ld   h,#>m_tile_ram + >0x0100
       ld   a,(b_8A00 + 0x10)                     ; lower byte of current character's address in v-ram
       ld   l,a
       ld   de,(b_8A00 + 0x04)                    ; pointer to next name character to store in Top 5 table...
       inc  de                                    ; ... actually it points to ( next_character - 1 )

; When the time runs out, 1, 2, or 3 characters may have already been selected
; by the player. Rather than keeping count, it simply checks that the column
; pointer from the input is off past the right limit. The rightmost input
; character is $8109 and will underflow when subtracting $20. Since the
; subtraction is done by addition (-21h == $DF), the inverse of the Cy flag can
; be used to detect the equivalent of the underflow of the subtraction.
l_330C:
       ldi
       ld   a,#-0x21                              ; subtract $21 since the LDI added 1 to HL
       dec  h
       add  a,l
       jr   nc,l_3315
       inc  h                                     ; L is 9, 29, or 49 so Cy is set, and we restor the  H...
l_3315:
       ld   l,a
       bit  0,h                                   ; if the Cy was set, then bit 0 should be set.
       jr   nz,l_330C
       ret

;;=============================================================================
;; c_text_out()
;;  Description:
;;  Text out, color attribute not encoded. Text blocks are length-encoded.
;; IN:
;;  HL=start address of string
;; OUT:
;;  HL=start address at next string
;;-----------------------------------------------------------------------------
c_text_out:
; destination address
       ld   e,(hl)                                ; LSB
       inc  hl
       ld   d,(hl)                                ; MSB
       inc  hl
; byte count of string
       ld   b,(hl)
       inc  hl

l_3321:
       ld   a,(hl)                                ; character code
       ld   (de),a                                ; putc
       inc  hl                                    ; src++
       rst  0x20                                  ; DE-=$20
       djnz l_3321

       ret

;;=============================================================================
;; c_text_out_ce()
;;  Description:
;;   Text out, color attribute encoded. Text blocks are length-encoded.
;;   Used by game_over.
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_text_out_ce:
       ld   e,(hl)                                ; LSB
       inc  hl
       ld   d,(hl)                                ; MSB
       inc  hl
       ld   b,(hl)                                ; strlen
       inc  hl
       ld   c,(hl)                                ; color
       inc  hl
       ex   de,hl
l_3331:
       ld   a,(de)                                ; data address
       ld   (hl),a
       set  2,h                                   ; dest+=$0400 (tile color regs)
       ld   (hl),c
       res  2,h
       inc  de
       ld   a,#-0x20
       dec  h
       add  a,l
       jr   nc,l_3340
       inc  h
l_3340:
       ld   l,a
       djnz l_3331

       ex   de,hl
       ret

;;=============================================================================
;; strings for mach_hiscore_show
;;=============================================================================
str_3345:
; "THE GALACTIC HEROES"
       .dw m_tile_ram + 0x0320 + 0x05
       .db 0x13
       .db 0x02
       .db 0x1D,0x11,0x0E,0x24,0x10,0x0A,0x15,0x0A,0x0C,0x1D,0x12,0x0C,0x24,0x11,0x0E,0x1B,0x18,0x0E,0x1C
;_335C:
; "-- BEST 5 --"
       .dw m_tile_ram + 0x02C0 + 0x0C
       .db 0x0C
       .db 0x04
       .db 0x26,0x26,0x24,0x0B,0x0E,0x1C,0x1D,0x24,0x05,0x24,0x26,0x26


;;=============================================================================
;; jp_RAM_test()
;;  Description:
;;   RAM test at powerup (from machine reset at 2c4) or Service-switch reset.
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
jp_RAM_test:
       xor  a
       ld   (0x6823),a                            ; 0 ...halt CPU #2 and #3
       inc  a
       ld   (_sfr_6822),a                         ; 1 ...cpu #3 nmi acknowledge/enable (Z80_IGNORE_INT)
       di                                         ; disable interrupts
       ld   (_sfr_watchdog),a
;  while ( tileramtestloopcount < $0a ){
       ld   b,#0x0A                               ; loop counter
_tileram_test_loop:
       exx                                        ; save outer loop count

       ld   de,#m_tile_ram
       ld   hl,#0x0000
       ld   bc,#0x0400
_wr_zero_loop:
       ld   a,l                                   ; a:=0
       xor  h
       cpl
       add  a,a
       add  a,a
       adc  hl,hl
       ld   a,l
       ld   (_sfr_watchdog),a
       ld   (de),a                                ; a==1, de==tile_ram
       inc  de
       dec  bc
       ld   a,b
       or   c
       jr   nz,_wr_zero_loop

       ld   de,#m_tile_ram
       ld   hl,#0x0000
       ld   bc,#0x0400
_rd_zero_loop:
       ld   a,l                                   ; a:=0
       xor  h
       cpl
       add  a,a
       add  a,a
       adc  hl,hl
       ld   a,(de)
       xor  l
       jp   nz,j_ramtest_ng
       inc  de
       ld   (_sfr_watchdog),a
       dec  bc
       ld   a,b
       or   c
       jr   nz,_rd_zero_loop

       ld   de,#m_tile_ram
       ld   hl,#0x5555
       ld   bc,#0x0400
_wr_5555_loop:
       ld   a,l
       xor  h
       cpl
       add  a,a
       add  a,a
       adc  hl,hl
       ld   a,l
       ld   (_sfr_watchdog),a
       ld   (de),a
       inc  de
       dec  bc
       ld   a,b
       or   c
       jr   nz,_wr_5555_loop

       ld   de,#m_tile_ram
       ld   hl,#0x5555
       ld   bc,#0x0400
_rd_5555_loop:
       ld   a,l
       xor  h
       cpl
       add  a,a
       add  a,a
       adc  hl,hl
       ld   a,(de)
       xor  l
       jp   nz,j_ramtest_ng
       inc  de
       ld   (_sfr_watchdog),a
       dec  bc
       ld   a,b
       or   c
       jr   nz,_rd_5555_loop

       ld   de,#m_tile_ram
       ld   hl,#0xAAAA
       ld   bc,#0x0400
_wr_aaaa_loop:
       ld   a,l
       xor  h
       cpl
       add  a,a
       add  a,a
       adc  hl,hl
       ld   a,l
       ld   (_sfr_watchdog),a
       ld   (de),a
       inc  de
       dec  bc
       ld   a,b
       or   c
       jr   nz,_wr_aaaa_loop

       ld   de,#m_tile_ram
       ld   hl,#0xAAAA
       ld   bc,#0x0400
_rd_aaaa_loop:
       ld   a,l
       xor  h
       cpl
       add  a,a
       add  a,a
       adc  hl,hl
       ld   a,(de)
       xor  l
       jp   nz,j_ramtest_ng
       inc  de
       ld   (_sfr_watchdog),a
       dec  bc
       ld   a,b
       or   c
       jr   nz,_rd_aaaa_loop

       exx                                        ; load outer loop count
       dec  b                                     ; giant_loop_counter--
       jp   nz,_tileram_test_loop
;  } // end while tile ram test loop

;  color RAM, tile RAM, and data RAM tests.
       ld   sp,#m_tile_ram + 0x0400               ; tmp stack for function calls

       ld   de,#m_color_ram
       call c_ram_test_block

       ld   de,#ds_8800_RAM0                      ; $0400 bytes
       call c_ram_test_block

       ld   de,#ds_9000_RAM1                      ; $0400 bytes
       call c_ram_test_block

       ld   hl,#ds20_99E0                         ; reset 00's to 9000 task tbl ($20 bytes)
       ld   de,#ds_cpu0_task_actv                 ; reset 00's from 99E0_mchn_data ($20 bytes)
       ld   bc,#0x0020
       ldir

       ld   de,#ds_9800_RAM2                      ; $0400 bytes
       call c_ram_test_block

       ld   hl,#ds_cpu0_task_actv                 ; reset 00's to 99E0_mchn_data ($20 bytes)
       ld   de,#ds20_99E0                         ; reset 00's from 9000 task tbl ($20 bytes)
       ld   bc,#0x0020
       ldir

       ld   sp,#ds_8800_RAM0 + 0x0300             ; tmp stack for function calls
       ld   de,#m_tile_ram                        ; 8000-83ff Video RAM
       call c_ram_test_block

       call c_tileram_regs_clr

       ld   hl,#str_3B7E                          ; load start address of src string "RAM  OK"
       call c_text_out                            ; display "RAM  OK"

       ld   (_sfr_watchdog),a
       call c_svc_clr_snd_regs                    ; $9AA0, $40 bytes

; enable f_05BE in CPU-sub1 (empty task) ... disabled in game_ctrl start
       ld   a,#7
       ld   (ds_cpu1_task_actv + 0x00),a          ; 7 ... skips to f_05BE in CPU-sub task-table

       call c_spriteposn_regs_init
       jp   j_romtest_mgr                         ; should jr back to Test_menu_init

;;=============================================================================
;; c_ram_test_block()
;;  Description:
;;   call ram_test_single repeatedly.
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_ram_test_block:
       ld   b,#0x1E                               ; count
       ld   hl,#0x0000
l_3484:
       push bc
       call c_ram_test_single
       pop  bc
       djnz l_3484
       ret
; end

;;=============================================================================
;; c_ram_test_single()
;;  Description:
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_ram_test_single:
       push de
       push hl
       ld   bc,#0x0400
l_3491:
       ld   a,l
       xor  h
       cpl
       add  a,a
       add  a,a
       adc  hl,hl
       ld   a,l
       ld   (_sfr_watchdog),a
       ld   (de),a
       inc  de
       dec  bc
       ld   a,b
       or   c
       jr   nz,l_3491
       pop  hl
       pop  de
       push de
       ld   bc,#0x0400
l_34A9:
       ld   a,l
       xor  h
       cpl
       add  a,a
       add  a,a
       adc  hl,hl
       ld   a,(de)
       xor  l
       jp   nz,j_ramtest_ng
       inc  de
       ld   (_sfr_watchdog),a
       dec  bc
       ld   a,b
       or   c
       jr   nz,l_34A9
       pop  de
       ret

;;=============================================================================
;; j_ramtest_ng()
;;  Description:
;;   Handle no-good ram test, do diagnostics and loop forever.
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
j_ramtest_ng:
       ld   b,a
       ld   a,d
       rra
       rra
       and  #0x07
       cp   #4
       jr   c,l_34CB
       dec  a
l_34CB:
       cp   #5
       jr   c,l_34D0
       dec  a
l_34D0:
       ld   e,a
       ld   a,b
       ld   d,#0x15
       and  #0x0F
       jr   nz,l_34DA
       ld   d,#0x11
l_34DA:
       ld   (_sfr_watchdog),a
       exx
       ld   hl,#m_tile_ram
       ld   de,#m_tile_ram + 0x01
       ld   bc,#0x0400
       ld   (hl),#0x24
       ldir
       ld   (hl),#0x00
       ld   bc,#0x03FF
       ldir
       ld   (_sfr_watchdog),a
       exx
       ld   hl,#m_tile_ram + 0x02E0 + 0x02
       ld   (hl),#0x1B
       ld   a,#0xE0
       dec  h
       rst  0x10                                  ; HL += A
       ld   (hl),#0x0A
       ld   a,#0xE0
       dec  h
       rst  0x10                                  ; HL += A
       ld   (hl),#0x16
       ld   a,#0xA0
       dec  h
       rst  0x10                                  ; HL += A
       ld   (hl),e
       ld   a,#0xE0
       dec  h
       rst  0x10                                  ; HL += A
       ld   (hl),d

; same as spriteposn_vregs_init
       ld   hl,#sfr_sprite_posn                   ; $80 bytes
       ld   b,#0x80
l_3516:
       ld   (hl),#0xF1                            ; init value
       inc  hl
       djnz l_3516

l_ramtest_ng_4ever:
       ld   (_sfr_watchdog),a
       jp   l_ramtest_ng_4ever

;;=============================================================================
;; c_rom_test_csum_calc()
;;  Description:
;;   C is set to $00 by the caller, indicating the expected checksum
;;   result. Adding the last byte of each rom section results in a 0 checksum.
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_rom_test_csum_calc:
       push hl
       ex   de,hl                                 ; Swap the starting address from DE to HL.
       ld   d,#0x10                               ; Set the MSB of the number of bytes to be summed ($1000)
       xor  a                                     ; A==$00
       ld   b,a                                   ; B==$00, so we now have BC==00. The first dec will roll
                                                  ; thru to $FF, giving an effective count of $100.
l_3527:
       add  a,(hl)                                ; Begin the checksum loop, with start address now in HL
       ld   (_sfr_watchdog),a
       inc  hl
       djnz l_3527                                ; CPU 1 & CPU 2 kick in around the time this is first called
       dec  d
       jr   nz,l_3527                             ; The MSB of the repeat count is the outer loop count.
       ex   de,hl
       pop  hl
       cp   c                                     ; final sum must be $00
       ret  z                                     ; end 'call c_rom_test_csum_calc'

;;=============================================================================
;; j_romtest_ng()
;;  Description:
;;   Loops for ever if any rom checksum is failed.
;;   this code segment also used for CPU1 or CPU2 failed checksum
;;
;;  ROM test status flags:
;;  $9100 = 0  CPU-sub rom test status, pause/resume (and returns test result)
;;  $9101 = 0  CPU-sub2 rom test status, pause/resume (and returns test result)
;;  $9102      CPU0 test state: 1->$0000, 2->$1000 ... 4->$3000 $FF->CPU0 ROM test complete
;;             Error code, failed ROM test (either sub CPU), passed as parameter to subroutine.
;;
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
j_romtest_ng:
       ld   hl,#str_3B88
       call c_text_out
       ld   de,#m_tile_ram + 0x0240 + 0x04
       ld   hl,#ds_rom_test_status + 0x02         ; load error code
       xor  a
       rld                                        ; rld  (hl)
       ld   (de),a
       rst  0x20                                  ; DE-=$20
       xor  a
       rld                                        ; rld  (hl)
       ld   (de),a
l_romtest_ng_4ever:
       ld   (_sfr_watchdog),a
       jp   l_romtest_ng_4ever

;;=============================================================================
;; j_romtest_mgr()
;;  Description:
;;   Coordinate ROM tests between multiple CPUs.
;;   jp here following end of RAM tests.
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
j_romtest_mgr:
       ld   hl,#ds_rom_test_status                ; initialize 3 bytes

       ld   (hl),#0x00                            ; (9101) = 0 ... resume CPUsub1
       inc  hl
       ld   (hl),#0x00                            ; (9101) = 0 ... resume CPUsub2
       inc  hl
       ld   (hl),#0x01                            ; (9102) = 1 ... checking CPU0-region $0000

       xor  a
       ld   (b_svc_test_snd_slctn),a              ; 0 (init the test-mode sound-selection variable.)
       inc  a
       ld   (0x6823),a                            ; 1 (enable sub CPUs)

       ld   de,#0x0000                            ; start address of test ($1000 bytes are checked per call)
       ld   c,#0
       call c_rom_test_csum_calc
       inc  (hl)                                  ; ($9102) = 2 (checking CPU0-region $1000)
       ld   c,#0
       call c_rom_test_csum_calc
       inc  (hl)                                  ; ($9102) = 3 (checking CPU0-region $2000)
       ld   c,#0
       call c_rom_test_csum_calc
       inc  (hl)                                  ; ($9102) = 4 (checking CPU0-region $3000)
       ld   c,#0
       call c_rom_test_csum_calc

       ld   (hl),#0xFF                            ; ($9102) = $FF (CPU0 complete)

l_CPU1_rom_test:
       ld   a,(ds_rom_test_status + 0x00)         ; check for CPU1 test result
       ld   (_sfr_watchdog),a
       and  a
       jr   z,l_CPU1_rom_test                     ; wait for result (non-zero)

       inc  a                                     ; $FF+1=0
       jr   z,l_CPU2_rom_test
       dec  a
       ld   (ds_rom_test_status + 0x02),a         ; grab error code...
       jp   j_romtest_ng                          ; ...ends in infinite loop

l_CPU2_rom_test:
       ld   a,(ds_rom_test_status + 0x01)         ; check for CPU1 test result
       ld   (_sfr_watchdog),a
       and  a
       jr   z,l_CPU2_rom_test                     ; wait for result (non-zero)

       inc  a                                     ; $FF+1=0
       jr   z,j_Test_menu_init                    ; DONE... JP to SVC MODE!

       dec  a
       ld   (ds_rom_test_status + 0x02),a         ; grab error code...
       jp   j_romtest_ng                          ; ...ends in infinite loop

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
d_params_switch_mode:
       .db 0x05,0x05,0x05,0x05
d_params_snd_test:
       .db 0x30,0x40,0x00,0x02,0xDF
       .db 0x40,0x30,0x30,0x03,0xDF
       .db 0x10,0x20

;;=============================================================================
;; j_Test_menu_init()
;;  Description:
;;   jr here from completion of ROM tests.
;;   'RAM OK' and 'ROM OK' actually shown right side up, but then in ShowCfg the
;;   flip screen gets set because of the check that is done on the IO input value.
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
j_Test_menu_init:
       ld   hl,#str_3B88                          ; ld src address of string "ROM  OK"
       call c_text_out                            ; display "ROM OK"
       call c_svc_updt_dsply                      ; prints remaining dsw configured options (upside down)

; memset( rom_test_status,0,3)
       ld   hl,#ds_rom_test_status                ; memset(...,0,3)...allows sub CPUs to resume.
       ld   b,#3
l_35C3:
       ld   (hl),#0
       inc  hl
       djnz l_35C3

; Initialize scheduler table before interrupts are enabled (otherwise task scheduler could infinite loop!)
       ld   a,#0x20
       ld   (ds_cpu0_task_actv + 0),a             ; $20 ... only task 0 (empty task) can be called

; set IO controller state - $05 (go in "switch" mode)
       ld   hl,#d_params_switch_mode              ; IO data (05,05,05,05)
       ld   de,#0x7000                            ; IO data xfer (write)
       ld   bc,#0x0004                            ; num IO params
       exx                                        ; swap args to shadow regs
       ld   a,#0xA1
       ld   (0x7100),a                            ; IO cmd ( $A1 -> go into switch mode)
       ld   (_sfr_watchdog),a
       call c_io_cmd_wait

       xor  a
       ld   (_sfr_watchdog),a

; wait 02 frames to verify that CPU-sub1 is alive and updating the frame counter
       ld   (ds3_92A0_frame_cts + 0),a            ; 0
;  while ( frame_cnt != 2 )
l_35E9:
       ld   a,(ds3_92A0_frame_cts + 0)
       cp   #2
       jr   nz,l_35E9

; setup IO command params
       ld   hl,#d_params_snd_test
       ld   de,#0x7000                            ; IO data xfer (write)
       ld   bc,#0x000C                            ; num IO params
       exx
       ld   a,#0xA8
       ld   (0x7100),a                            ; IO cmd ($A8 -> bang sound)

       ld   (_sfr_watchdog),a
       call c_io_cmd_wait

; setup interrupt mode and toggle the latch (enable cpu0_rst38)
       ld   (_sfr_watchdog),a
       im   1
       ld   hl,#_sfr_6820                         ; maincpu irq acknowledge/enable
       ld   (hl),#0
       ld   (hl),#1                               ; enable IRQ1
       ei

       call c_svc_test_sound_sel

; wait 8 frames (while test sound??)
       xor  a
       ld   (ds3_92A0_frame_cts + 0),a            ; 0
; while ( frame_cnt != 8 )
l_3619:
       ld   a,(ds3_92A0_frame_cts + 0)
       and  #0x08
       jr   z,l_3619


;;=============================================================================
;; j_Test_menu_proc()
;;  Description:
;;   Process runner for test menu selection.
;;   If the svc switch is NOT set, it simply continues to Machine Init.
;; IN:
;;  ...
;; OUT:
;;  ...
;; TODO: put the PORT defintions from MAME in here somewhere as reference
;; e.g.
;;   PORT_SERVICE( 0x08, IP_ACTIVE_LOW )
;;
;; IO Input Registers for "switch" mode
;;   [0] test switch & credits in
;;       $7D fire 2
;;       $7E fire 1
;;       $7B 1 start
;;       $77 2 start
;;       $6F coin 1
;;       $5F coin 2
;;       $3F 'service 1' (99999999)
;;   [1] control panel 1
;;       $F7 (L)
;;       $FD (R)
;;   [2] control panel 2 (table-top cabinet cfg)
;;       $7F (L)
;;       $DF (R)
;;
;;-----------------------------------------------------------------------------
j_Test_menu_proc:

; synchronize with next frame transition.

; prev_frame_cts[0] = frame_cts[0]
       ld   a,(ds3_92A0_frame_cts + 0)            ; Get t0.
       ld   c,a

;  while ( frame_cts[0] == prev_frame_cts[0] )
l_3624:
       ld   a,(ds3_92A0_frame_cts + 0)            ; Get t1.
       cp   c
       jr   z,l_3624

; 9110-9116 used as temp array to capture/debounce successive input states.
       ld   hl,#(b_svc_test_inp_buf + 0x06)
       ld   de,#(b_svc_test_inp_buf + 0x07)
       ld   bc,#0x0007
       lddr                                       ; (9117):=(9116) etc. etc.
                                                  ; HL==910F, DE==9110
       ex   de,hl                                 ; HL:=9110  ( debounce[0] )
; (3636)
;  if ( IN0H_8 == INACTIVE ) goto Machine_init
       ld   de,#(ds3_99B5_io_input + 0x00)
       ld   a,(de)
       bit  7,a                                   ; ACTIVE_LOW i.e. if bit_7==1 switch is off
       jp   nz,j_36BA_Machine_init

; Read IN0 (button conditions) into B
       ld   (hl),a                                ; save new input value to debounce[0]
       inc  hl
       or   (hl)                                  ; Trigger on input received now t(0) or t(-1) ...
       inc  hl
       cpl                                        ; A:=~A (1's compl.)
       and  (hl)                                  ; Input stimulus is new if not active at t(-2)
       inc  hl
       and  (hl)                                  ; Checking against saved condition of last frame...
       ld   (hl),a                                ; ... and save the input condition this frame.
       ld   b,a                                   ; stash the button condition in B for now...

; Read IN1 (stick conditions) into B
       inc  hl                                    ; HL:=9114
       inc  de                                    ; DE:=99b6  (stick input from IN1)
       ld   a,(de)
       ld   (hl),a                                ; save new input value to debounce[4]
       inc  hl
       or   (hl)                                  ; or t(-1) value
       inc  hl
       cpl
       and  (hl)                                  ; not t(-2)
       inc  hl
       and  (hl)                                  ; and t(-1) condition
       ld   (hl),a                                ; ... and save the input condition this frame.
       ld   l,a                                   ; grab the stick condition

       ld   h,b                                   ; grab button condition from B

; active low input states are now inverted in HL.
; Successive left shifts (into Cy) with the countdown in B indicate the active input.
       ld   b,#0x10                               ; counter...
l_3659:
;  for ( B==16; B>0; B-- ) { if (bit_set) call input_hdlr }
       add  hl,hl                                 ; does left shift (into Cy)
       call c,c_svc_test_input_hdlr
       djnz l_3659

       call c_svc_updt_dsply                      ; this also flips the screen back to "normal"

; Check timer to erase Machine Totals info.
; First time here, timer register contains stray data from tests and is
; not specifically initialized. Resulting countdown time about 14 minutes...
; Timer is reset to 15 seconds after data is displayed the first time..
;  if ( 15sec_tmr == 0 ) goto 3672
       ld   hl,(w_svc_15sec_tmr)                  ; lsb first)
       ld   a,h
       or   l
       jr   z,l_3672

;  else if ( --15sec_tmr == 0 ) clr_999999()
       dec  hl
       ld   (w_svc_15sec_tmr),hl                ; timer--
       ld   a,h
       or   l
       call z,c_svc_machine_ttls_erase

l_3672:
       ld   a,(b_svc_test_inp_buf + 0x00)         ; check fire button... (non-debounced)
       rra                                        ; right-rotate IN0L_0 (into Cy) ...
       jr   nc,l_367F                             ; active_low, Cy==0 if active (start new sound)
       xor  a
       ld   (b_svc_eastregg_keyprs_cnt),a         ; 0 (reset count)
       jp   j_Test_menu_proc

; Fire Button hit... start new sound (kills last one)
l_367F:
       ld   a,(b_svc_test_inp_buf + 0x07)         ; check stick input conditions for left/right
       and  #0x0F                                 ; f7=left, fd=right (active low) (i.e. conditions are 8 left, 2 right)
       jp   z,j_Test_menu_proc

       ld   c,a                                   ; holding Fire button DOWN then pushing stick left or right. (pc=3687)
       ld   hl,#d_easteregg_trigger
       ld   de,#b_svc_eastregg_keyprs_cnt
       ld   a,(de)                                ; always 0 ...?
       rst  0x10                                  ; HL += A
       ld   a,(hl)                                ; d_easteregg_trigger[0]
       cp   c
       jr   z,l_3699
       xor  a                                     ; pushed stick left (always a==02 from table[0])
       ld   (de),a                                ; keyprs_cnt = 0
       jp   j_Test_menu_proc

l_3699:
       ex   de,hl                                 ; pushed stick right
       inc  (hl)                                  ; (9271):=1
       inc  de                                    ; 3783
       ld   a,(de)                                ; A = 2
       inc  a                                     ; A = 3
       jp   nz,j_Test_menu_proc

; easter egg time: get here and it will put c1981 NAMCO LTD. in huge characters!
       call c_tileram_regs_clr
       call c_spriteposn_regs_init

       ld   de,#d_easteregg_data
       ld   hl,#m_tile_ram + 0x0040 + 0x02

       ld   b,#0x1C                               ; each count is 1 column (28)
;  while ( b-- != 0 ) call EasterEgg
l_36AF:
       call c_svc_easteregg_hdlr
       djnz l_36AF

; easter egg screen... checking IO input...
;  while( test_switch_on ) {}
l_36B4:
       ld   a,(ds3_99B5_io_input + 0x00)          ; check for test switch
       add  a,a                                   ; active low... $80+$80 sets carry if off.
       jr   nc,l_36B4

; fall through to machine_init

;;=============================================================================
;; j_36BA_Machine_init()
;;  Description:
;;   Waits a short delay by the frame counter, re-checks Test-switch prior to
;;   display of the cross hatch test pattern before "normal" startup.
;;
;;     Per Bally Manual "If you wish to keep this test pattern on the monitor screen
;;     for futher use, slide Self-Test switch back to the "ON" position after the
;;     cross hatch appears and before it disappears."
;;
;;   Once the Test-switch is turned Off, proceeds to set the IO controller to "credit"
;;   mode and waits for input data to start (IO data requests are being done in the
;;   "Task manager" periodic process.
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
j_36BA_Machine_init:
; wait 8 frame counts
       xor  a
       ld   (ds3_92A0_frame_cts + 0),a            ; 0
;  while ( vtimer < 0x08 ) {}
l_36BE:
       ld   a,(ds3_92A0_frame_cts + 0)
       cp   #8
       jr   c,l_36BE

;  Make sure Test-switch is Off before proceeding? (not sure how it could get
;  out of Self-test mode if it were on.... ???)
;  if ( test_switch_on ) { goto test_menu }
       ld   a,(ds3_99B5_io_input + 0x00)          ; check for test switch
       add  a,a                                   ; active low... $80+$80 sets carry if off.
       jp   nc,j_Test_menu_proc

       call c_spriteposn_regs_init

; drawing the cross hatch pattern - tile ram layout is pretty clumsy!
       ld   hl,#m_tile_ram

       ld   b,#0x10
l_36D4:
       ld   (hl),#0x28
       inc  hl
       ld   (hl),#0x27
       inc  hl
       djnz l_36D4

       ld   b,#0x10
l_36DE:
       ld   (hl),#0x2D
       inc  hl
       ld   (hl),#0x2B
       inc  hl
       djnz l_36DE

       ld   b,#0x10
l_36E8:
       ld   (hl),#0x28
       inc  hl
       ld   (hl),#0x2D
       inc  hl
       djnz l_36E8

       ld   b,#0x10
l_36F2:
       ld   (hl),#0x27
       inc  hl
       ld   (hl),#0x2B
       inc  hl
       djnz l_36F2

; remainder of cross hatch pattern is copied, i.e.  *(m_tile_ram + DE) = *(m_tile_ram + HL)
       ex   de,hl

       ld   hl,#m_tile_ram + 0x0040               ; DE==$8080
       ld   bc,#0x0340
       ldir

       ld   hl,#m_tile_ram                        ; DE==$83C0
       ld   bc,#0x0040
       ldir

; wait about two seconds before checking Test-switch.
       xor  a
       ld   (ds3_92A0_frame_cts + 0),a            ; :=0
;  while ( vtimer < 0x80 ) {}
l_370F:
       ld   a,(ds3_92A0_frame_cts + 0)
       add  a,a                                   ; count $80
       jr   nc,l_370F

; if you wish to keep this test pattern on the monitor ...slide switch back to ON
;  while( test_switch_on ) {}
l_3715:
       ld   a,(ds3_99B5_io_input + 0x00)          ; check for test switch
       add  a,a                                   ; active low... $80+$80 sets carry if off.
       jr   nc,l_3715

       di
       call c_io_cmd_wait

;  timer = -2...  while ( timer != 0 ) {}
       ld   a,#-2
       ld   (ds3_92A0_frame_cts + 0),a            ; :=$FE) (-2)
l_3724:
       ld   a,(ds3_92A0_frame_cts + 0)
       and  a
       jr   nz,l_3724

       ld   (_sfr_watchdog),a

;  do {
l_372D:
; setup for IO cmd $E1 - typical values might be:
;        01 01 01 01 01 02 03 00 .....Mame interprets as follows:
; 01 + 4 arguments: set coinage
; 02: go in "credit" mode and enable start buttons
; 03: disable joystick remapping (Galaga needs only L/R joy indications)
; 00: nop
       ld   hl,#ds8_9280_tmp_IO_parms             ; writing default IO params for credit-mode (8 bytes)
       ld   de,#0x7000                            ; IO data xfer (write)
       ld   bc,#0x0008
       exx
       ld   a,#0xE1
       ld   (0x7100),a                            ; IO cmd ($E1 -> go into credit mode)
       call c_io_cmd_wait

; Wait for valid status from IO controller?
; Setup for IO cmd $B1 ...read 3 bytes (num credits, plyr 1, plyr 2)
       ld   hl,#0x7000                            ; IO data xfer (read)
       ld   de,#ds3_9288_tmp_IO_data
       ld   bc,#0x0003
       exx
       ld   a,#0xB1                               ; IO command "only issued after $E1" (go into credit mode)
       ld   (0x7100),a                            ; IO cmd ($B1 -> reading/polling data)
       call c_io_cmd_wait

;  } while ( a > $a0 || ( a & $0f > $09 ) )
       ld   a,(ds3_9288_tmp_IO_data)              ; $FF if in test-mode when test switch off...
       cp   #0xA1                                 ; $A0 (100d) may be valid for credit mode? so compare to $A1
       jr   nc,l_372D                             ; generate a Cy if A<$A1
       and  #0x0F
       cp   #0x0A                                 ; in credit mode bcd digits should be less than 9
       jr   nc,l_372D

; svc switch off... let'er rip!
       ei
       xor  a
       ld   (m_tile_ram + 0x0200 + 0x10),a        ; 0 in middle of screen
       jp   j_Game_init


;;=============================================================================
;; c_svc_easteregg_hdlr()
;;  Description:
;;   Easter Egg screen!
;; IN:`
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_svc_easteregg_hdlr:
       call c_3774
       call c_3774
       call c_3774
       ld   a,#0x05
       jp   rst_HLplusA                           ; returns to caller from HLplusA

;;=============================================================================
;; c_3774()
;;  Description:
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_3774:
       ld   a,(de)
       ld   c,#8
l_3777:
       add  a,a
       jr   nc,l_377B
       inc  (hl)
l_377B:
       inc  hl
       dec  c
       jr   nz,l_3777
       inc  de
       inc  hl
       ret

;;=============================================================================
; control input sequence to trigger Easter Egg.
; ... 5R 6L 3R 7L
d_easteregg_trigger:
     .db 0x02,0x02,0x02,0x02,0x02
     .db 0x08,0x08,0x08,0x08,0x08,0x08
     .db 0x02,0x02,0x02
     .db 0x08,0x08,0x08,0x08,0x08,0x08,0x08
     .db 0xFF

; easter egg screen data
d_easteregg_data:
     .db 0x01,0x3E,0x00,0x7F,0x41,0x00,0x21,0x41,0x00,0x00
     .db 0x41,0x00,0x36,0x3E,0x00,0x49,0x00,0x03,0x49,0x22,0x03,0x49,0x41,0x00,0x36,0x41
     .db 0x3E,0x00,0x3E,0x41,0x3E,0x00,0x41,0x49,0x7F,0x41,0x49,0x20,0x7F,0x49,0x18,0x00
     .db 0x32,0x20,0x40,0x00,0x7F,0x40,0x01,0x00,0x7F,0x7F,0x3F,0x40,0x21,0x44,0x40,0x00
     .db 0x44,0x00,0x3C,0x44,0x01,0x42,0x3F,0x01,0x81,0x00,0x01,0xA5,0x7F,0x01,0xA5,0x04
     .db 0x7F,0x99,0x08,0x00,0x42,0x10,0x00,0x3C,0x7F,0x00

;;=============================================================================
;; c_io_cmd_wait()
;;  Description:
;;   wait for IO_ACKRDY "command executed" ($10) read from IO chip status sfr.
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_io_cmd_wait:
while_io_cmd_wait:
       ld   a,(0x7100)                            ; read IO status
       cp   #0x10
       ret  z
       jr   while_io_cmd_wait


_l_37F4:



;;=============================================================================
;; c_svc_updt_dsply()
;;  Description:
;;   Displays dip switch configuration in test screen.
;; IN:
;;  ...
;; OUT:
;;  ...
;;   Switches are active low, i.e. OFF -> 1, ON -> 0
;;   Bally machine apparently does not have a config switch for the cab type.
;;   DSWA is not the same as NAMCO.
;;   Notes from Mame136 galaga.c:
;;   The Cabinet Type "dip switch" actually comes from the edge connector, but is mapped
;;   in memory in place of dip switch #8. dip switch #8 selects single/dual coin counters
;;   and is entirely handled by hardware.
;;
;;   DSWA -> sfr_dsw_X:1 (6J)
;;                         SW#8 SW#7 SW#6 SW#5 SW#4 SW#3 SW#2 SW#1
;;            DIFFICULTY      -    -    -    -    -    -    X    X
;;               UNKNOWN      -    -    -    -    -    X    -    -  (@ f_0ECA)
;; SOUND IN ATTRACT MODE      -    -    -    -    X    -    -    -
;;          FREEZE VIDEO      -    -    -    X    -    -    -    -
;;          CABINET TYPE      X    -    -    -    -    -    -    -
;;
;;  DSWB -> sfr_dsw_X:0 (6K)
;;                      SW#8 SW#7 SW#6 SW#5 SW#4 SW#3 SW#2 SW#1
;;   COINS PER CREDIT      -    -    -    -    -    X    X    X
;;  BONUS SHIPS AWARD      -    -    X    X    X    -    -    -
;;    NBR OF FIGHTERS      X    X    -    -    -    -    -    -
;;
;;
;;-----------------------------------------------------------------------------
c_svc_updt_dsply:

; CABINET TYPE (DSWA)
; 0x80 -> UPRIGHT
; 0x00 -> TABLE

       ld   a,(_sfr_dsw8)                         ; cabinet type
       rra                                        ; get DSWA#8 (sfr_dsw8:1)
; inverting the bit provides the index
       inc  a                                     ; invert bit in bit-0
       and  #0x01
       ld   (b_mchn_cfg_cab_type),a
;  svc_cab_type( a )
       ld   hl,#str_3ACC                          ; 0-"UPRIGHT", 1-"TABLE"
       rst  0x08                                  ; HL += 2A
       call c_svc_cab_type

; By pushing the "1 PLAYER" and the "2 PLAYER" buttons at the same time, the
; picture will turn updside down and stay that way until you release the buttons.
; If the buttons are not pushed, the picture stays inverted momentarily until
; a 0 is read from the IO chip (due to residual non-zero value left from memory test).
       ld   a,(ds3_99B5_io_input + 0x00)
       ld   c,#0
       and  #0x0C                                 ; 08->2plyr_start, 04->1plyr_start
       jr   nz,l_380F
       inc  c                                     ; c:=1  (flips the screen)
l_380F:
       ld   a,c
       ld   (0xA007),a                            ; flip screen control

; DIFFICULTY LEVEL SETTING (DSWA)
;    0x00  = 0 -> A (MEDIUM)
;    0x01  = 1 -> C (HARD)
;    0x02  = 2 -> D (HARDEST)
;    0x03  = 3 -> A (EASY)

       ld   hl,#_sfr_dsw1                         ; difficulty level
       ld   a,(hl)
       rra                                        ; get DSWA#1 (sfr_dsw1:1)
       and  #0x01
       ld   c,a

       inc  hl
       ld   a,(hl)
       and  #0x02                                 ; get DSWA#2 (sfr_dsw2:1)
       or   c                                     ; lo-bit in C
       ld   (b_mchn_cfg_rank),a

       ld   hl,#str_3A68                          ; base_address of rank-characters (B/C/D/A)
       rst  0x10                                  ; HL += A
       ld   de,#m_tile_ram + 0x0220 + 0x0C        ; rank-character ("B", "C", "D", or "A")
       ldi                                        ; (DE)<-(HL) ..."X" of "RANK X" displayed
       ld   hl,#str_3AE4                          ; "RANK"
       call c_text_out                            ; display "RANK"


; NUMBER OF FIGHTERS (DSWB)
;     0x00 -> 2
;     0x40 -> 4
;     0x80 -> 3
;     0xC0 -> 5

; configuration setting is "number of fighters - 1"
       ld   hl,#_sfr_dsw7                         ; get DSWB#7 (sfr_dsw7:0)
       ld   a,(hl)                                ; hi-bit
       inc  hl                                    ; get DSWB#8 (sfr_dsw8:0)
       ld   c,(hl)                                ; lo-bit
       rr   c                                     ; "right-shift" lo-bit into Cy flag.
       adc  a,a                                   ; "left-shift" the hi-bit and add the lo-bit from Cy flag.
       and  #0x03
       inc  a                                     ; this gives "cfg = nbr_of_ships - 1"
       ld   (b_mchn_cfg_nships),a

;  m_tile_ram[$02EA] = mchn_cfg_nships + 1
       inc  a
       ld   (m_tile_ram + 0x02E0 + 0x0A),a        ; "X" of "X SHIPS" displayed
;  text_out($3AEB)
       ld   hl,#str_3AEB                          ; "SHIPS"
       call c_text_out


; load default IO params (sets up credit-mode and joystick remapping - see _372D)
; 4 arguments to "set coinage" command (9281-4) will be updated below to capture
; dip switch changes for credit-mode.
       ld   hl,#d_3AC4
       ld   de,#ds8_9280_tmp_IO_parms             ; default IO params for credit-mode (8 bytes)
       ld   bc,#0x0008
       ldir

; COINS PER CREDIT (DSWB)
;  Mask   SW#1 SW#2 SW#3
;  0x00   ON   ON   ON  - free play
;  0x04   ON   ON   OFF - 4-coin/1-credit
;  0x02   ON   OFF  ON  - 3-coin/1-credit
;  0x06   ON   OFF  OFF - 2-coin/1-credit
;  0x01   OFF  ON   ON  - 2-coin/3-credit
;  0x05   OFF  ON   OFF - 1-coin/3-credit
;  0x03   OFF  OFF  ON  - 1-coin/2-credit
;  0x07   OFF  OFF  OFF - 1-coin/1-credit

       ld   hl,#_sfr_dsw1                         ; coins per credit
       ld   b,#3                                  ; 3 bits
       xor  a
l_385C:
       ld   c,(hl)
       rr   c                                     ; "right-shift" lo-bit into Cy flag.
       adc  a,a                                   ; "left-shift" the hi-bit and add the lo-bit from Cy flag.
       inc  hl
       djnz l_385C

       and  #0x07                                 ; 3-bits only please

; if ( free_play )
       jr   z,l_389B
; else  TableOffset=(Index-1)*8 ... resulting offsets are $00,$08,$10,$18,$20,$28,$30)
       dec  a
       add  a,a
       add  a,a
       add  a,a

; Update 4 arguments to "set coinage" command from the table.
       ld   hl,#str_3A6C
       rst  0x10                                  ; HL += A
       ld   de,#ds8_9280_tmp_IO_parms + 1
       ld   bc,#0x0004
       ldir
; the next four bytes are the text characters
       ld   de,#m_tile_ram + 0x02E0 + 0x08
       ldi                                        ; show digit for number of coins
       ld   de,#m_tile_ram + 0x0220 + 0x08
       ldi                                        ; show " " or "S"
       ld   de,#m_tile_ram + 0x01E0 + 0x08
       ldi                                        ; show digit for number of credits
       ld   de,#m_tile_ram + 0x00E0 + 0x08
       ldi                                        ; show " " or "S"

       ld   a,#0x24
       ld   (m_tile_ram + 0x0200 + 0x08),a        ; shows a space after "COIN(S)"
       ld   hl,#str_3AF3                          ; " COIN"
       call c_text_out
       call c_text_out                            ; "CREDIT" of "X CREDIT"
       jr   l_38AB

; Update 4 arguments to "set coinage" command from the table for free-play mode
l_389B:
       ld   hl,#ds8_9280_tmp_IO_parms + 1         ; 4 bytes (arguments to "set coinage" command)
       ld   b,#4
l_38A0:
       ld   (hl),#0
       inc  hl
       djnz l_38A0

       ld   hl,#str_3B04
       call c_text_out                            ; "FREE PLAY"

; Bonus Ships Awarded (DSWB)
; Mask  Selection    S#4 S#5 S#6    Index into table 3AA4
; 0x20  20-60-60     ON  ON  OFF    1
; 0x10  20-70-70     ON  OFF ON     2
; 0x30  20-80-80     ON  OFF OFF    3
; 0x08  30-100-100   OFF ON  ON     4
; 0x28  30-120-120   OFF ON  OFF    5
; 0x18  20-60        OFF OFF ON     6
; 0x38  30-80        OFF OFF OFF    7
; 0x00  None         ON  ON  ON     0
; Bonus config displayed in following format:
; 1ST BONUS  X0000 PTS
; 2ND BONUS XX0000 PTS
; AND EVERY XX0000 PTS

l_38AB:
       ld   hl,#_sfr_dsw4                         ; bonus levels

       ld   b,#3                                  ; 3 positions to read
       xor  a
l_38B1:
       ld   c,(hl)
       rr   c                                     ; "right-shift" lo-bit into Cy flag.
       adc  a,a                                   ; "left-shift" the hi-bit and add the lo-bit from Cy flag.
       inc  hl
       djnz l_38B1

;  if ( 0 == switch_selection ) goto 392D  // display "BONUS NOTHING", ret to 35be
       and  #0x07
       jp   z,l_392D

       ld   c,a
       ld   a,(b_mchn_cfg_nships)                 ; Bonus levels depend upon number of fighters starting.
       and  #0x04                                 ; note: num_ships = mchn_cfg_nships + 1
       add  a,a
       add  a,c                                   ; add dsw value
       add  a,a                                   ; a:=a*2 ... use as offset into table
       ld   hl,#str_3AA4                          ; bonus config data
       rst  0x10                                  ; HL += A...A==2,C,4,6,E,8,A
       ld   de,#w_mchn_cfg_bonus                  ; ld two-bytes (str_3AA4)
       ldi
       ldi
       dec  hl                                    ; point to second byte of two-byte Table entry
       ld   c,#1                                  ; flag tells 38DA that it was 'called' i.e. get out by return
       call c_38DA                                ; display 'second and every' bonus settings
       dec  hl                                    ; point to first byte of two-byte table entry
       ld   c,#0                                  ; flag allows 3904 ret to occur

;;=============================================================================
;; c_38DA()
;;  Description:
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_38DA:
       ld   a,(hl)                                ; ld one byte from the two-byte table entry
       inc  a                                     ; setup test for $FF in the bonus-none parameters
       jp   z,l_393B                              ; if 'bonus none', skip the 'second and every' display (when?)
       ld   a,c                                   ; first-pass (second-and-every) indicated by 1, second-pass indicated by 0..
       add  a,a                                   ; ...so A==2 or A==0  (offset from 3B1A to string address loaded into HL)
       push hl                                    ; save address of table-entry
       ld   hl,#str_3B1A                          ; i.e., 1E 3B "1ST BONUS ", 36 3B "2ND BONUS"
       rst  0x10                                  ; HL += A                                  ; HL += A
       ld   a,(hl)                                ; get LSB of src address
       inc  hl
       ld   h,(hl)                                ; get MSB of src address
       ld   l,a                                   ; ld LSB to L
       push bc                                    ; C holds the so-called 'first-bonus/second-bonus' flag, save it!
       call c_text_out                            ; display "2ND BONUS" or "1ST BONUS"
       call c_text_out                            ; display "0000 PTS" of "??? BONUS XX0000 PTS"...
                                                  ; HL==$3B2B or HL==$3B42, as there are two copies of "0000 PTS"
                                                  ; DE==$80B2, that value will be used later......?
       pop  bc                                    ; get back the first-pass-second-pass flag
       pop  hl                                    ; get back the address of the table-entry
       ld   a,(hl)                                ; ld the table-entry...
       and  #0x7F                                 ; ... and mask out bit-7 which indicates there is no 'and-every' setting
       ex   de,hl                                 ; save address of table-entry in HL... DE==$80B2 (address of ' ' in "PTS ")
       ld   hl,#m_tile_ram + 0x01E0 + 0x10
       ld   b,c                                   ; the first time through here, C==1...
       djnz l_38FF                                ; ... so the second time, when the Flag is 0 we skip next two lines
       inc  hl
       inc  hl                                    ; ...now down 2 rows from $81F0 i.e. address of 'X' in "2ND BONUS X 0000 PTS"
l_38FF:
       call c_391E                                ; display "X" of "??? BONUS XX0000 PTS"
       ex   de,hl                                 ; HL:= to second-or-first-table-entry again
       dec  c                                     ; C:=$00 at end of first-pass...
       ret  nz                                    ; ...after second-pass, ret to _35BE, end 'call _37F4' (displaying dsw menu)
       ex   de,hl                                 ; save the current bonus-parameter-table-entry into DE
       ld   a,(de)                                ; A:=$86 for 20-60 setting, the second of the two byte-parameters
       bit  7,a                                   ; if (bit-7)...
       jp   nz,l_3949                             ; ... then jp (bit test is Z flag... bit-7 set if no 'and-every' bonus)
       ld   hl,#m_tile_ram + 0x01E0 + 0x14        ; address of character X in "AND EVERY X 0000 PTS"
       call c_391E                                ; display XX of "AND EVERY XX0000 PTS"
       push de
       ld   hl,#str_3B4D                          ; "AND EVERY"
       call c_text_out
       call c_text_out                            ; display "0000 PTS" of "AND EVERY XX0000 PTS"  ( HL expected to be $3B59)
       pop  hl
       ret
; end 'call 38DA', ret to _38D7

;;=============================================================================
;; c_391E()
;;  Description:
;;   converts bonus levels to decimal and display on screen
;;   on entry, HL==address_to_write_to
;               A==value from bonus-parameter-table
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_391E:
       cp   #0x0A                                 ; check if value if > 10
       ld   b,#0x24                               ; start with a ' ' (space) character in B
       jr   c,l_3928                              ; if Cy, it means that A<$0A, so jr past the display of the 10's place digit
       ld   b,#1                                  ; value is 10 or greater...
       sub  #0x0A                                 ; ...so subtract off the value of 10...
l_3928:
       ld   (hl),b                                ; ...and write a "1" to screen for the "10's" place
       res  5,l                                   ; i.e.  HL:-=$20, which will offset 1 column to the right on the screen
       ld   (hl),a                                ; write the "one's" place to the screen
       ret                                        ; end 'call _391E'
; jp here from 38BA
l_392D:
       ld   hl,#str_3B64                          ; "BONUS NOTHING"
       call c_text_out
       ld   hl,#w_mchn_cfg_bonus
       ld   (hl),#0xFF
       inc  hl
       ld   (hl),#0xFF
; put space characters on the line where "2ND BONUS ?????? PTS" goes ( jp here from $38DC??? )
l_393B:
       ex   de,hl                                 ; save HL
       ld   hl,#m_tile_ram + 0x0320 + 0x12
       ld   b,#0x16                               ; writing out $16 characters
; while ( b > 0 )
l_3941:
       ld   (hl),#0x24                            ; space ' '
       ld   a,#0xE0
       dec  h                                     ; effectively, HL:-=$100
       rst  0x10                                  ; HL += A, which adds back $E0, effectively we've done HL:-=$20
       djnz l_3941

; jp here from $3909... putting space character on the line where "AND EVERY ?????? PTS" goes
l_3949:
       ld   hl,#m_tile_ram + 0x0320 + 0x14
       ld   b,#0x16
l_394E:
       ld   (hl),#0x24
       ld   a,#0xE0
       dec  h
       rst  0x10                                  ; HL += A
       djnz l_394E
       ex   de,hl                                 ; see 393b
       ret                                        ; if jp'd to _392D, ret to _35BE... end 'call _37F4' (displaying dsw options)
                                                  ; if jp'd to _393B,l_3949 end 'call 38DA', ret to _35BE

;;=============================================================================
;; c_tileram_regs_clr()
;;  Description:
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_tileram_regs_clr:
       ld   hl,#m_tile_ram
       ld   de,#m_tile_ram + 0x01
       ld   bc,#0x0400
       ld   (hl),#0x24
       ldir
       ld   (hl),#3                               ; now filling in at $8400 (color ram)...
       ld   bc,#0x03FF
       ldir
       ld   a,#7                                  ; star ctrl default param
       ld   (ds_99B9_star_ctrl + 0x05),a          ; :=7
       ret
; end call

;;=============================================================================
;; c_spriteposn_regs_init()
;;  Description:
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_spriteposn_regs_init:
       ld   hl,##sfr_sprite_posn                  ; $80 bytes
       ld   b,#0x80                               ; length of sprite position regs
l_3977:
       ld   (hl),#0xF1
       inc  hl
       djnz l_3977
       ret                                        ; extra garbage on screen gone with RAM OK showing
; end call

;;=============================================================================
;; c_svc_machine_totals()
;;  Description:
;;   Show "remaining" counts of Games Played and Points Scored, in this format:
;;   'XX.XYYY.YYYY.ZZZZ.ZAAA.'
;;   The indicators are subtracted from their maximum...
;;    i.e. 999-UUU=XXX or 9999999-UUUUUUU=YYYYYYY
;;
;;   XXX:     b16_99E0_ttl_plays_bcd  (lower 3 BCD nibbles only i.e. 0-999)
;;
;;   YYYYYYY: b32_99E2_sum_score_bcd  (lower 3 BCD nibbles only i.e. 0-999)
;;
;;   ZZZZZ:   b32_99E6_gametime_secs_bcd (5 BCD digits of seconds count ...
;;            ... omit the 1/60th count)
;;   AAA:     b16_99EA_bonus_ct_bcd  (lower 3 BCD nibbles only i.e. 0-999)
;; IN:
;;  ...
;; OUT:
;;  ...
;; NOTE: the game time and bonus count would only be non-zero if the machine is
;;       warm reset during a running game. MAME (136) doesn't seem to handle
;;       warm reset properly and it hangs at "RAM OK".
;;-----------------------------------------------------------------------------
c_svc_machine_totals:
       ld   hl,#b16_99E0_ttl_plays_bcd
       ld   de,#m_tile_ram + 0x0340 + 0x1E        ; at lower left of screen

; the first set has 2 digits, followed by the '.'
       ld   c,#2

       ld   b,#1
       call c_3997                                ; XX.X

       ld   b,#3
       call c_3997                                ; ____YYY.YYYY

       ld   b,#2
       call c_3997                                ; HL=99E6

       inc  hl                                    ; skip 1/60th part of timer.

       ld   b,#1

; 3997 again ("inline")... do the bonus-count portion ("AAA")

;;=============================================================================
;; c_3997()
;;  Description:
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_3997:
       call c_39AA
l_399A:
       call c_39A0                                ; does 39AA also
       djnz l_399A
       ret

;;=============================================================================
;; c_39A0()
;;  Description:
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_39A0:
       ld   a,#0x99
       sub  (hl)
       rra
       rra
       rra
       rra
       call c_39AE

; optimization: fall-through to c_39AA

;;=============================================================================
;; c_39AA()
;;  Description:
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_39AA:
       ld   a,#0x99
       sub  (hl)
       inc  hl

; optimization: fall through to call c_39AE

;;=============================================================================
;; c_39AE()
;;  Description:
;;   Put Digit.
;;   The running count in C is checked... when ==0,  put the '.'
;;   Updates tile position to right (-$20) for each character shown.
;; IN:
;;  A=character code to display.
;;  C=remaining count of digits in the sequence
;; OUT:
;;  C=remaining count of digits in the sequence
;;  DE= next tile position.
;;-----------------------------------------------------------------------------
c_39AE:
       and  #0x0F
       ld   (de),a
       rst  0x20                                  ; DE-=$20
       dec  c
       ret  nz
       ld   a,#0x2A                               ; '.' character
       ld   c,#4
       ld   (de),a
       rst  0x20                                  ; DE-=$20
       ret

;;=============================================================================
;; c_svc_machine_ttls_erase()
;;  Description:
;;   Erases Machine Totals
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_svc_machine_ttls_erase:
       ld   hl,#m_tile_ram + 0x0340 + 0x1E

       ld   b,#0x17                               ; nr of characters to fill
       ld   de,#-0x20
l_39C3:
       ld   (hl),#0x24
       add  hl,de
       djnz l_39C3

       ret

;;=============================================================================
;; c_svc_test_input_hdlr()
;;  Description:
;;   Handle inputs during Self-Test Mode.
;;   Moving the controller left or right, and pressing any game button or
;;   activating the coin switches results in the selection and activation of
;;   the various game sounds.
;;   There is also an additional mode, undocumented in the Bally Manual, which
;;   displays the Machine Information if a "Service Switch" is activated.
;;   This switch is not documented in the Bally manual.
;;   MAME does however have a defintion of the switch, i.e.
;;   	PORT_BIT( 0x04, IP_ACTIVE_LOW, IPT_SERVICE1 )
;; IN:
;;  B=countdown from $10 representing active input state in terms of
;;     bit-position in HL.
;; OUT:
;;  saves BC, HL
;;-----------------------------------------------------------------------------

; c_svc_test_input_hdlr : entry point is below...

l_39C9_call397D:
       push hl
       call c_svc_machine_totals

;  reset Machine Totals timer
       ld   hl,#(15 * 60)
       ld   (w_svc_15sec_tmr),hl                  ; init timer (15*60)

       pop  hl
       pop  bc
       ret

c_svc_test_input_hdlr:
       push bc
       ld   a,b                                   ; b==$10?  (_3657)
       cp   #0x10 - 1                             ; IPT_SERVICE1 (MAME key_9)
       jr   z,l_39C9_call397D
       cp   #0x10 - 0x0E                          ; If stick pushed right...
       jr   z,l_39F5                              ; ... then....
       cp   #0x10 - 0x0C                          ; else if stick pushed left...
       jr   nz,l_3A21                             ; ...else
       ld   a,(b_svc_test_snd_slctn)              ; ... then load the current sound selection...
       sub  #0x01                                 ; ... and decrement.
       jr   nc,l_39ED                             ; If no carry (negative wrap-around)...
       ld   a,#0x11                               ; else wrap around to highest sound #17...
l_39ED:
       ld   (b_svc_test_snd_slctn),a
       jr   j_39FC

;;=============================================================================
;; c_svc_test_sound_sel()
;;  Description:
;;   sound check
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_svc_test_sound_sel:
       push bc
       jr   j_39FC

l_39F5:
       ld   a,(b_svc_test_snd_slctn)              ; stick was pushed right...
       inc a                                      ; ... go to next higher sound selection.
       ld   (b_svc_test_snd_slctn),a              ; (save update sound selection)

j_39FC:
       ld   a,(b_svc_test_snd_slctn)              ; ... and get sound selection (in case jp'd here from decrement case).
       cp   #0x12                                 ; if incremented sound selection != $17...
       jr   c,#l_3A04                             ; ... then ...
       xor  a                                     ; else let sound selection equal 0...
l_3A04:
       ld   (b_svc_test_snd_slctn),a
       push hl
       ld   c,#0                                  ; character "0"
       cp   #0x0A
       jr   c,#l_3A11
       inc  c                                     ; when is that jr taken?
       sub  #0x0A
l_3A11:
       ld   hl,#m_tile_ram + 0x0220 + 0x0E        ; dest address of "0"
       ld   (hl),c                                ; displayed "0" of "SOUND 00"
       ld   l,#0x0E
       ld   (hl),a                                ; displayed (2nd) "0" of "SOUND 00"
       ld   hl,#str_3A47
       call c_text_out                            ; display "SOUND" of "SOUND 00"
       pop  hl
       pop  bc
       ret                                        ; end 'call _39F2' (sound check)
l_3A21:                                           ; ... else (stick not left or right)
       ld   a,(b_svc_test_snd_slctn)
       cp   #0x12
       jr   c,l_3A29
       xor  a                                     ; (selection is never >$11 so the jr is always taken)
l_3A29:
       ld   (b_svc_test_snd_slctn),a
       ex   de,hl
       call c_svc_clr_snd_regs
       ld   hl,#d_3A4F                            ; d_3A4F[ test_snd_slctn ]
       rst  0x10                                  ; HL += A
       ld   l,(hl)
       ld   h,#>b_9A00                            ; sound_fx_status[ d_3A4F[ test_snd_slctn ] ] = 1
       ld   (hl),#1
       ex   de,hl
       pop  bc
       ret

;;=============================================================================
;; c_svc_clr_snd_regs()
;;  Description:
;;   Initialize data structures for sound manager.
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_svc_clr_snd_regs:
       ld   hl,#ds_9AA0                           ; sound mgr SFRs, clear $40 bytes
       ld   b,#0x40                               ; length to fill
l_3A41:
       ld   (hl),#0                               ; fill with 0
       inc  hl
       djnz l_3A41
       ret

;;-----------------------------------------------------------------------------
str_3A47:
       .dw m_tile_ram + 0x02E0 + 0x0E
       .db 0x05
       .db 0x1C,0x18,0x1E,0x17,0x0D ;; "SOUND"

; offsets to $9AA0 count/enable for individual sound effects for sound-test selection
d_3A4F:
       .db <b_9AA0 + 0x01  ; 00
       .db <b_9AA0 + 0x02  ; 01
       .db <b_9AA0 + 0x03  ; 02
       .db <b_9AA0 + 0x04  ; 03
       .db <b_9AA0 + 0x07  ; 04
       .db <b_9AA0 + 0x0A  ; 05
       .db <b_9AA0 + 0x0B  ; 06
       .db <b_9AA0 + 0x0C  ; 07
       .db <b_9AA0 + 0x0D  ; 08
       .db <b_9AA0 + 0x0E  ; 09
       .db <b_9AA0 + 0x0F  ; 10
       .db <b_9AA0 + 0x10  ; 11
       .db <b_9AA0 + 0x12  ; 12
       .db <b_9AA0 + 0x13  ; 13
       .db <b_9AA0 + 0x14  ; 14
       .db <b_9AA0 + 0x15  ; 15
       .db <b_9AA0 + 0x16  ; 16
       .db <b_9AA0 + 0x19  ; 17

;;=============================================================================
;; c_svc_cab_type()
;;  Description:
;;   wrapper for c_text_out (dereferences the pointer passed in HL)
;;   (caller is displaying the cab-type)
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_svc_cab_type:
       ld   a,(hl)                                ; LSB
       inc  hl
       ld   h,(hl)                                ; MSB
       ld   l,a                                   ; LSB
       jp   c_text_out                            ; jp instead of calling so we only have to ret once
; (returns from subroutine at $331B)


;;=============================================================================
;;
;; Text strings and other data
;;
;;-----------------------------------------------------------------------------

; text-characters for difficulty settings-MEDIUM,HARD,HARDEST,EASY respectively
str_3A68:
       .db 0x0B,0x0C,0x0D,0x0A

; format characters for COIN/CREDIT display
str_3A6C:
       .db 0x04,0x01,0x04,0x01,0x04,0x1C,0x01,0x24  ;; 4-coin(s)/1-credit( )
       .db 0x03,0x01,0x03,0x01,0x03,0x1C,0x01,0x24  ;; 3-coin(s)/1-credit( )
       .db 0x02,0x01,0x02,0x01,0x02,0x1C,0x01,0x24  ;; 2-coin(s)/1-credit( )
       .db 0x02,0x03,0x02,0x03,0x02,0x1C,0x03,0x1C  ;; 2-coin(s)/3-credit(s)
       .db 0x01,0x03,0x01,0x03,0x01,0x24,0x03,0x1C  ;; 1-coin( )/3-credit(s)
       .db 0x01,0x02,0x01,0x02,0x01,0x24,0x02,0x1C  ;; 1-coin( )/2-credit(s)
       .db 0x01,0x01,0x01,0x01,0x01,0x24,0x01,0x24  ;; 1-coin( )/1-credit( )

; bonus-setting parameters...e.g. $02,$06 -> "20000-60000-60000"
str_3AA4:
       .db 0xFF,0xFF        ;; NO BONUS SHIPS GIVEN WITH THIS SETTING
       .db 0x02,0x06
       .db 0x02,0x07
       .db 0x02,0x08
       .db 0x03,0x0A
       .db 0x03,0x0C
       .db 0x02,0x06 + 0x80 ;; bit-7 means there's no 'and-every' bonus
       .db 0x03,0x08 + 0x80 ;; bit-7 means there's no 'and-every' bonus

; ???????????
str_3AB4:
       .db 0xFF,0xFF,0x03,0x0A,0x03,0x0C,0x03,0x0F,0x03,0x8A,0x03,0x8C,0x03,0x8F,0x03,0xFF

; default params for IO test
d_3AC4:
       .db 0x01,0x01,0x01,0x01,0x01,0x02,0x03,0x00

; pointers to cabinet-types strings.
str_3ACC:
       .dw str_3AD0                               ; pointer to "UPRIGHT" text
       .dw str_3ADA                               ; pointer to "TABLE" text
str_3AD0:
       .dw m_tile_ram + 0x02E0 + 0x06
       .db 0x07
       .db 0x1E,0x19,0x1B,0x12,0x10,0x11,0x1D ;; "UPRIGHT"
str_3ADA:
       .dw m_tile_ram + 0x02E0 + 0x06
       .db 0x07
       .db 0x1D,0x0A,0x0B,0x15,0x0E,0x24,0x24 ;; "TABLE  "
str_3AE4:
       .dw m_tile_ram + 0x02E0 + 0x0C
       .db 0x04
       .db 0x1B,0x0A,0x17,0x14 ;; "RANK",
str_3AEB:
       .dw m_tile_ram + 0x02A0 + 0x0A
       .db 0x05
       .db 0x1C,0x11,0x12,0x19,0x1C ;; "SHIPS",
str_3AF3:
       .dw m_tile_ram + 0x02C0 + 0x08
       .db 0x05
       .db 0x24,0x0C,0x18,0x12,0x17 ;; " COIN",
str_3AFB:
       .dw m_tile_ram + 0x01A0 + 0x08
       .db 0x06
       .db 0x0C,0x1B,0x0E,0x0D,0x12,0x1D ;; "CREDIT"
str_3B04:
       .dw m_tile_ram + 0x02E0 + 0x08
       .db 0x12
       .db 0x0F,0x1B,0x0E,0x0E,0x24,0x19,0x15,0x0A,0x22 ;; "FREE PLAY"
       .db 0x24,0x24,0x24,0x24,0x24,0x24,0x24,0x24,0x24
       .db 0x24 ;; extra space character?
str_3B1A:
       .dw str_1ST_BONUS
       .dw str_2ND_BONUS
str_1ST_BONUS:
       .dw m_tile_ram + 0x0330
       .db 0x0A
       .db 0x01,0x1C,0x1D,0x24,0x0B,0x18,0x17,0x1E,0x1C,0x24 ;; "1ST BONUS "
str_3B2B:
       .dw m_tile_ram + 0x01B0
       .db 0x08
       .db 0x00,0x00,0x00,0x00,0x24,0x19,0x1D,0x1C ;; "0000 PTS"
str_2ND_BONUS:
       .dw m_tile_ram + 0x0320 + 0x12
       .db 0x09
       .db 0x02,0x17,0x0D,0x24,0x0B,0x18,0x17,0x1E,0x1C ;; "2ND BONUS"
str_3B42:
       .dw m_tile_ram + 0x01B0 + 0x02
       .db 0x08
       .db 0x00,0x00,0x00,0x00,0x24,0x19,0x1D,0x1C ;; "0000 PTS"
str_3B4D:
       .dw m_tile_ram + 0x0320 + 0x14
       .db 0x09
       .db 0x0A,0x17,0x0D,0x24,0x0E,0x1F,0x0E,0x1B,0x22 ;; "AND EVERY"
str_3B59:
       .dw m_tile_ram + 0x01A0 + 0x14
       .db 0x08
       .db 0x00,0x00,0x00,0x00,0x24,0x19,0x1D,0x1C ;; "0000 PTS"
str_3B64:
       .dw m_tile_ram + 0x0320 + 0x10
       .db 0x16
       .db 0x0B,0x18,0x17,0x1E,0x1C,0x24,0x17,0x18,0x1D,0x11,0x12,0x17,0x10 ;; "BONUS NOTHING"
       .db 0x24,0x24,0x24,0x24,0x24,0x24,0x24,0x24,0x24
       .db 0x24 ;; this seems to be extra character
str_3B7E:
       .dw m_tile_ram + 0x02E0 + 0x02
       .db 0x07
       .db 0x1B,0x0A,0x16,0x24,0x24,0x18,0x14 ;; "RAM  OK"
str_3B88:
       .dw m_tile_ram + 0x02E0 + 0x04
       .db 0x07
       .db 0x1B,0x18,0x16,0x24,0x24,0x18,0x14 ;; "ROM  OK"


_l_3B92:

;       .org 0x3FFF
;       .db 0x2E                                   ; checksum

;;
