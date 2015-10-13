;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; gg1-2.s
;;  gg1-2.3m, 'maincpu' (Z80)
;;
;;  Utility functions, player and stage setup, text display.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.module borg

.include "sfrs.inc"
.include "structs.inc"
.include "gg1-2.dep"

;.area ROM (ABS,OVR)
;       .org 0x0FFF
;       .db 0x93                                   ; checksum
;       .org 0x1000
.area CSEG10


;;=============================================================================
;; c_1000()
;;  Description:
;;   for c_25A2
;;   R register used as a randomizer?
;; IN:
;;  ...
;; OUT:
;;   A==random value
;; PRESERVES:
;;   HL
;;-----------------------------------------------------------------------------
c_1000:
       push hl
       ld   a,r
       ld   h,a
       ld   a,(ds3_92A0_frame_cts + 0)
       add  a,h
       ld   l,a
       ld   h,#>db_obj_home_posn_rc
       ld   a,(hl)
       ld   h,a
       ld   a,r
       add  a,h
       pop  hl
       ret

;;=============================================================================
;; dead_code
;;  Description:
;;   Assuming this is dead code. There are no references to this anywhere as
;;   either code or data.
;;-----------------------------------------------------------------------------
; _1012
        push bc
        push de
        ld   a,e
        sub  l
        ld   b,#0
        jr   nc,l_101E
        set  0,b
        neg
l_101E:
        ld   c,a
        ld   a,d
        sub  h
        jr   nc,l_102D
        ld   d,a
        ld   a,b
        xor  #0x01
        or   #0x02
        ld   b,a
        ld   a,d
        neg
l_102D:
        cp   c
        push af
        rla
        xor  b
        rra
        ccf
        rl   b
        pop  af
        jr   nc,l_103B
        ld   d,c
        ld   c,a
        ld   a,d
l_103B:
        ld   h,c
        ld   l,#0
        call c_divmod                             ; HL=HL/D
        ld   a,h
        xor  b
        and  #0x01
        jr   z,l_104A
        ld   a,l
        cpl
        ld   l,a
l_104A:
        ld   h,b
        pop  de
        pop  bc
        ret

;;=============================================================================
;; c_104E_mul_16_8()
;;  Description:
;;   HL := b16 * b8
;; IN:
;;   HL==16 bit factor
;;   A==8 bit factor
;; OUT:
;;   HL=16 bit product
;; SAVES:
;;   DE
;;-----------------------------------------------------------------------------
c_104E_mul_16_8:
       push de
       ex   de,hl
       ld   hl,#0x0000
l_1053:
       srl  a
       jr   nc,l_1058
       add  hl,de
l_1058:
       sla  e
       rl   d
       and  a
       jr   nz,l_1053
       pop  de
       ret

;;=============================================================================
;; c_1061()
;;  Description:
;;   Integer division and modulus operation. NOTE input value is NOT preserved.
;;   HL = HL / A
;;    A = HL % A
;;   Uses ADC to sort of left-rotate the Dividend bitwise, linking through Cy
;;   Flag into A and from A through Cy back into HL.
;; IN:
;;  A = Divisor
;;  HL = Dividend
;; OUT:
;;  HL = Quotient
;;  A =  Modulus
;; PRESERVES: BC, DE
;;-----------------------------------------------------------------------------
c_divmod:
        push bc
        ld   c,a                                  ; keep the divisor in C
        xor  a
        ld   b,#16 + 1                            ; bit shift counter (pre-increment for djnz)
l_1066:
        adc  a,a                                  ; "left shift" the modulus portion and pick up any overflow from HL.
        jr   c,l_1074
        cp   c                                    ; hint: this does a-c
        jr   c,l_106D                             ; if (a<c )then goto ccf ... (Cy is set and the ccf will clear it)
        sub  c                                    ; else subtract_divisor ... (Cy is not set, the ccf will set it)
l_106D:
        ccf                                       ; Compliment Cy Flag ... if set then the modulus result has overflowed...
l_106E:
        adc  hl,hl                                ; ... and overflow out of modulus result is added to quotient.
        djnz l_1066

        pop  bc
        ret

l_1074:                                           ; handle overflow out of A
        sub  c
        scf                                       ; need to explicitly set Cy so overflow of A will be summed with result in HL
        jp   l_106E

;;=============================================================================
;; c_1079()
;;  Description:
;;   Called once for each of boss + 1 or 2 wingmen.
;; IN:
;;   HL == &b_8800[n] ... bits 0:6 ... loaded at l_1B8B from boss_wing_slots[n + 0]
;;         if bit-7 set then negate rotation angle to (ix)0x0C
;;         (creature originating on right side)
;;   DE == pointer to object data (in cpu-sub1 code space)
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_1079:
        ld   a,l

        and  #0x80                                ; if set then negate rotation angle to (ix)0x0C
        inc  a                                    ; set bit-0, .b13<0> makes object slot active
        ex   af,af'

        res  7,l
        jp   j_108A

;;=============================================================================
;; c_1083()
;;  Description:
;;   Diving movement of red alien, yellow alien, clone-attacker, and rogue fighter.
;; IN:
;;   HL == &b_8800[n]
;;   DE == pointer to object data (in cpu-sub1 code space)
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_1083:
; set A:bit-7 if L:bit-1 != 0 ... creature originating on right side
        ld   a,l

        rrca
        rrca

        and  #0x80                                ; if set then negate rotation angle to (ix)0x0C
        inc  a                                    ; set bit-0, .b13<0> makes object slot active
        ex   af,af'

;;=============================================================================
;; j_108A()
;;  Description:
;;   Setup motion for diving attackers.
;; IN:
;;   HL == &b_8800[n]
;;   DE == pointer to table in cpu-sub1 code space
;;   A' ==
;;        bit-0: set by c_1083 and c_1079
;;        bit-7: flag set for negative rotation angle
;; OUT:
;;
;;-----------------------------------------------------------------------------
j_108A:
        push de

; find an available data structure or quit
        ld   de,#0x0014                           ; size of 1 data structure
        ld   b,#0x0C                              ; number of structures in array
        ld   ix,#ds_bug_motion_que
l_1094:
        bit  0,0x13(ix)                           ; check for activated state
        jr   z,l_10A0_got_one
        add  ix,de
        djnz l_1094

        pop  de
        ret

l_10A0_got_one:
        pop  de                                   ; pointer to table

        ld   0x08(ix),e                           ; data pointer lsb
        ld   0x09(ix),d                           ; data pointer msb
        ld   0x0D(ix),#1                          ; expiration counter
        ld   0x04(ix),#<0x0100                    ; msb, 0x0100 (90 degrees)
        ld   0x05(ix),#>0x0100                    ; lsb
        ld   c,l                                  ; stash index to obj_status[], sprite etc.
        ld   0x10(ix),c                           ; index of object, sprite etc.

        ex   af,af'
        ld   d,a                                  ; function parameter from A' to 0x13(ix)

        ld   (hl),#9                              ; obj_status[l].state ... disposition = diving attack
        ld   a,ixl
        inc  l
        ld   (hl),a                               ; obj_status[L].idx ... index into flying que

        ld   a,(b_9215_flip_screen)
        ld   e,a

; insert sprite Y coord into pool structure
        ld   l,c                                  ; restore index to obj_status[], sprite etc. (dec l just as good, no?)
        ld   h,#>ds_sprite_posn
        ld   c,(hl)                               ; sprite_x
        inc  l
        ld   b,(hl)                               ; sprite_y<7:0>
        ld   h,#>ds_sprite_ctrl
        ld   a,(hl)                               ; sprite_y<8>
        rrca                                      ; sY<8> into Cy
        rr   b                                    ; sY<8> from Cy to b<7> and sY<0> to Cy

        bit  0,e                                  ; test flipped screen
        jr   nz,l_10DC
; not flipped screen
; 160 - sprite_y + 1 ... backwards math since sY<8:1> already loaded in B, and this is only for flipped screen
        ex   af,af'                               ; stash Cy ... sY<:0>
        ld   a,b
        add  a,#<(-0x0160 >> 1)                   ; adjust addend for scale factor 2
        neg
        ld   b,a
        ex   af,af'                               ; un-stash Cy
        ccf                                       ; sY<:0> = Cy ^ 1

; insert sprite X coord into pool structure
l_10DC:
; resacale sY<8:0> to fixed-point 9.7
        ld   0x01(ix),b                           ; sY<8:1> ... fixed point 9.7
; sY<:0> from Cy into A<7> ... fixed point 9.7 (LSB)
        rra
        and  #0x80
        ld   0x00(ix),a                           ; sY<0> ... fixed point 9.7

        ld   a,c                                  ; sprite_x
        bit  0,e                                  ; test flipped screen
        jr   z,l_10ED
; flipped screen
        add  a,#0x0D                              ; if flipped screen
        cpl

l_10ED:
        srl  a
        ld   0x03(ix),a                           ; sX<8:1>
        rra                                       ; Cy into A<8:>
        and  #0x80
        ld   0x02(ix),a                           ; sX<:0> ... now scaled fixed point 9.7
        ld   0x13(ix),d                           ; function argument (A') sets bit-0 and bit-7
        ld   0x0E(ix),#0x1E                       ; bomb drop counter

; if (flying_bug_attck_condtn)  bug_motion_que[n].b0F = bomb_drop_enbl_flags
        ld   a,(ds_9200_glbls + 0x0B)             ; if ( !0 ), load  b_92C0[0x08] ... bomb drop enable flags
        and  a
        jr   z,l_1108
        ld   a,(b_92C0 + 0x08)                    ; bomb drop enable flags
; else bug_motion_que[n].b0F = 0
l_1108:
        ld   0x0F(ix),a                           ; 0 or b_92C0[$08] ... bomb drop enable flags

        ret

;;=============================================================================
;; c_player_active_switch()
;;  Description:
;;   End a player's turn and/or prep for next player.
;;   Called when bug nest has already retreated.
;;   Never on single player game and not at and of player 2's final ship.
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_player_active_switch:
;  active_plyr_task_tbl[0] = reserve_plyr_task_tbl[0] = $1F
       ld   a,#0x1F
       ld   (ds_cpu0_task_actv + 0),a             ; $1F
       ld   (ds_cpu0_task_resrv + 0),a            ; $1F

; swap active player and waiting player state data structures
       ld   hl,#ds_plyr_actv                      ; $40 bytes
       ld   de,#ds_plyr_susp                      ; $40 bytes
       ld   b,#0x40
l_111C:
       ld   c,(hl)
       ld   a,(de)
       ld   (hl),a
       ld   a,c
       ld   (de),a
       inc  l
       inc  e
       djnz l_111C

; swap active player and waiting player game object data
       ld   hl,#b_8800                            ; $30 bytes to 98B0
       ld   de,#ds_susp_plyr_obj_data
       ld   b,#0x30
l_112D:
       ld   a,(hl)                                ; &sprt_mctl_objs[n]
       ld   c,a
       ld   h,#>ds_sprite_code
       ld   a,(hl)
       and  #0x7F
       dec  c
       jr   nz,l_1142                             ; starts at $80?
       and  #0x78                                 ; sprite[n].cclr.code
       ld   c,a
       inc  l
       ld   a,(hl)                                ; sprite[n].cclr.colr
       dec  l
       and  #0x07
       or   c
       or   #0x80
l_1142:
       ex   de,hl                                 ; hl := &susp_plyr_obj_data[n]
       ld   c,(hl)                                ; hl==98b0, de==8b00
       ld   (hl),a
       ex   de,hl                                 ; hl := sprite[n].cclr.code
       bit  7,c
       jr   z,l_115A
       ld   a,c                                   ; 114a, player 2->plyr 1
       and  #0x78
       add  a,#6
       ld   (hl),a
       inc  l
       ld   a,c
       and  #0x07
       ld   (hl),a
       dec  l
       ld   a,#1
       jr   l_1161

l_115A:
       ld   (hl),c                                ; hl==8b00
       ld   h,#>ds_sprite_posn
       ld   (hl),#0                               ; hl==9300
       ld   a,#0x80

l_1161:
       ld   h,#>b_8800
       ld   (hl),a
       inc  de                                    ; de==98b0
       inc  l
       inc  l                                     ; hl==8800+n+2
       djnz l_112D

       ld   hl,#ds_cpu0_task_actv                 ; cp $20 bytes to reserve task tbl
       ld   de,#ds_cpu0_task_resrv                ; cp $20 bytes from active task tbl
       ld   b,#0x20
l_1171:
       ld   c,(hl)
       ld   a,(de)
       ld   (hl),a
       ld   a,c
       ld   (de),a
       inc  l
       inc  e
       djnz l_1171

       xor  a
       ld   (ds_cpu0_task_actv + 0),a             ; 0
       ret

;;=============================================================================
;; gctl_stg_tokens()
;;  Description:
;;   new stage setup (c_new_stage_, plyr_changeover)
;; IN:
;;  A': non-zero if sound-clicks for stage tokens (passed to sound manager)
;;  Cy': set if inhibit sound-clicks for stage tokens
;;
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_new_level_tokens:
;  memset($8002,$24,$12)
       ld   hl,#m_tile_ram + 2                    ; second row from bottom at right
       ld   b,#0x12
       ld   a,#0x24
       rst  0x18                                  ; memset((HL), A=fill, B=ct)
;  memset($8022,$24,$12)                          ; bottom row at right
       ld   l,#0x22
       ld   b,#0x12
       rst  0x18                                  ; memset((HL), A=fill, B=ct)

       ld   a,(ds_plyr_actv +_b_stgctr)           ; c_new_level_tokens
       ld   b,#0                                  ; tmp_quotient 50
       ld   hl,#m_tile_ram + 1                    ; offset into tile ram


; stage_ctr/50 and stage_ctr%50 (by brute force!)

;  while ( tmp_stage_ctr >= 50 ) {
l_1194_while:
       cp   #50
       jr   c,l_119F
       sub  #50                                   ; tmp_modulus
       inc  b                                     ; tmp_quotient
; offset tileram ptr 2 columns to the left... *50 icons are 2 tiles wide
       inc  l
       inc  l
       jr   l_1194_while

l_119F:
       ex   de,hl                                 ; stash the tileram offset in DE
       ld   l,a                                   ; stage_ctr % 50

       ld   h,#0
       ld   a,#10
       call c_divmod                              ; HL = HL / 10
       ld   h,a                                   ; A = HL % 10 ... (still have L==HL/10)

       push hl                                    ; stack the quotient and mod10 result
       ex   de,hl

; now HL == tile_ram address  and  DE == div10 and mod10 result

; offset base pointer in HL by the nbr of tile columns needed:

; if ( A >= 5 )  { C = A = A - 4 }  ... if mod10 > 5 then only 1 tile for the 5, plus nbr of 1's
       cp   #5
       jr   c,l_11B1_add_total
       sub  #4

l_11B1_add_total:
       ld   c,a                                   ; nbr of columns for 5's and 1's (not including 50's)

; Add up the total additional columns needed for 10, 10, 20, 30, 40 in A.
; 'bit 0' catches the odd div10 result and sets A=2. Noteing the 40 needs 4 columns,
; the div10 result does the right thing for 0, 20, and 40.
       ld   a,e                                   ; div10result
       bit  0,a                                   ; even or odd
       jr   z,l_11B9
       ld   a,#2
l_11B9:
       add  a,c                                   ; nbr of additional tile columns
       rst  0x10                                  ; HL += A

; B == count of 50's markers, if any
       inc  b                                     ; pre-increment for djnz ... B is at least 1

l_11BC_loop:
       djnz l_11DC_show_50s_tokens
       pop  bc                                    ; pop the quotient and mod10 result
       ld   a,c                                   ; div10 result
       call c_11E3_show_tokens_1

; if ( mod10result < 5 )
       ld   a,b                                   ; mod10 result
       cp   #5
       jr   c,l_11D0_do_1s_tokens
; else
       ld   d,#0x36 + 2                           ; tile nbr of top of '5' token ... bottom tile of token is next tile nbr
       call c_build_token_1                       ; show the 5 token

; do 1's ... mod10result -= 5
       ld   a,b
       sub  #5

l_11D0_do_1s_tokens:
       ld   b,a                                   ; nbr of 1's tokens
       inc  b                                     ; pre-increment for djnz

l_11D2_show_1s_loop:
       djnz l_11D5_while
       ret

l_11D5_while:
       ld   d,#0x36                               ; tile nbr of top of '1' token ... bottom tile of token is next tile nbr
       call c_build_token_1                       ; show the token
       jr   l_11D2_show_1s_loop

l_11DC_show_50s_tokens:
       ld   a,#4
       call c_11E9                                ; show the token
       jr   l_11BC_loop


;;=============================================================================
;; c_11E3_show_tokens_1()
;;  Description:
;;   Setup c_11E9 to display the 10's tokens.
;; IN:
;;   A = count of 10's tiles to show, i.e. stage % 50 / 10
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_11E3_show_tokens_1:

; branch off depending on div10result ... do nothing for 0
       and  a                                     ; A==div10 result
       ret  z
; handle 40's separately
       cp   #4
       jr   z,l_11F0_do_40s

c_11E9:
; get offset of of start of tiles for 10, 20, and 30 ... div10result * 4
       rlca
       rlca
       add  a,#0x36                               ; base offset of icon tiles
       ld   d,a
       jr   l_11FA_show_10s_20s_30s_50s

l_11F0_do_40s:
       ld   d,#0x36 + 4 * 3                       ; offset to 30's tiles group
       call c_build_token_1
       call c_build_token_2

       ld   d,#0x36 + 4                           ; offset to 10's tiles group

l_11FA_show_10s_20s_30s_50s:
       call c_build_token_1
       call c_build_token_2

       ret

;;=============================================================================
;; c_build_token()
;;  Description:
;;   wrapper for c_build_token_2 that handles timing and sound-effect
;; IN:
;;   D = offset of start of tile group for the token to display
;;   HL = base address in tileram
;; OUT:
;;   HL -= 1
;;-----------------------------------------------------------------------------
c_build_token_1:

; check sound_disable_flag
       ex   af,af'
       jr   c,l_1215_restore_A_and_continue
; put it back
       ex   af,af'
; set the delay count 8 ... preserve frame count
       ld   a,(ds3_92A0_frame_cts + 0)
       add  a,#8
       ld   e,a
l_120B:
       ld   a,(ds3_92A0_frame_cts + 0)
       sub  e
       jr   nz,l_120B

; actv_plyr_state[0x05]==0 for challenge stage ... 0 count/enable for stage tokens clicks
       ex   af,af'
       ld   (b_9AA0 + 0x15),a                     ; 2 ... sound-fx count/enable registers, clicks for stage tokens

l_1215_restore_A_and_continue:
       ex   af,af'

;;=============================================================================
;; c_build_token_2()
;;  Description:
;;   Display 2 tiles comprising a stage token icon.
;;
;;   Each call to this displays a top and bottom tile. 4 tile tokens require
;;   this function to be called twice. HL is decremented in order to leave the
;;   pointer at the next column to the left.
;;   Use color table 1 for 1's, 5's and 50's.
;;   These are situated in the tile order such that the $0C mask leaves the 8,
;;   thereby setting the Z flag.
;;   Use color table 2 for the others.
;;   This is a bit roundabout and slightly confusing, here is a table of the
;;   tile numbers to help visualize it:
;;
;;    1's   36 37         38 & 0C = 08
;;    5's   38 39         3A & 0C = 08
;;    10's  3A 3B 3C 3D   3C & 0C = 0C  ... 3E & 0C = 0C
;;    20's  3E 3F 40 41   40 & 0C = 00  ... 42 & 0C = 00
;;    30's  42 43 44 45   44 & 0C = 00  ... 46 & 0C = 00
;;    50's  46 47 48 49   48 & 0C = 08  ... 5A & 0C = 08
;;
;; IN:
;;   D = offset of start of tile group for the token to display
;;   HL = base address in tileram
;; OUT:
;;   HL -= 1
;;
;;-----------------------------------------------------------------------------
c_build_token_2:
       ld   (hl),d
       inc  d                                     ; next tile
       set  5,l                                   ; +=32 ... advance one row down
       ld   (hl),d

       inc  d
       set  2,h                                   ; +=$0400 ... colorram

; if ( D & $0C  > 8 ) { A = 2  else A = 1 }
       ld   a,d
       and  #0x0C
       cp   #8
       ld   a,#1
       jr   z,l_1228
       inc  a

; set the color codes, resetting the bits and updating HL as we go
l_1228:
       ld   (hl),a
       res  5,l
       ld   (hl),a
       res  2,h
       dec  l                                     ; offset tileram pointer 1 column to the right

       ret

;;=============================================================================
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
;;-----------------------------------------------------------------------------
c_1230_init_taskman_structs:
; memcpy(_task_activ, task_enable_tbl_def, 0x20)
       ld   hl,#task_enable_tbl_def
       ld   de,#ds_cpu0_task_actv                 ; $20 bytes copied from task_enable_tbl_def
       ld   bc,#0x0020
       push bc
       push hl
       ldir

; memcpy(_task_resrv, task_enable_tbl_def, 0x20);
;  for ( de = 98e0, hl = 1249; bc++ ; bc < 0$20 ) de[bc] = hl[bc];
       pop  hl
       pop  bc
       ld   de,#ds_cpu0_task_resrv                ; $20 bytes copied from task_enable_tbl_def
       ldir

; kill the idle task at [0]
;  task_tbl_9000[0] = 0
       xor  a
       ld   (ds_cpu0_task_actv),a                 ; 0

       ret


;;=============================================================================
;; kernel task-enable table defaults

task_enable_tbl_def:

  .db  0x1F ; f_0827
  .db  0x01 ; f_0828  ; Copies from sprite "buffer" to sprite RAM
  .db  0x00 ; f_17B2
  .db  0x00 ; f_1700  ; Ship-update in training/demo mode.
  .db  0x00 ; f_1A80
  .db  0x01 ; f_0857  ; triggers various parts of gameplay based on parameters
  .db  0x00 ; f_0827
  .db  0x00 ; f_0827

  .db  0x00 ; f_2916
  .db  0x00 ; f_1DE6
  .db  0x00 ; f_2A90
  .db  0x00 ; f_1DB3
  .db  0x01 ; f_23DD  ; Updates each object in the table at 8800
  .db  0x01 ; f_1EA4  ; Bomb position updater
  .db  0x00 ; f_1D32
  .db  0x01 ; f_0935  ; handle "blink" of Player1/Player2 texts

  .db  0x00 ; f_1B65
  .db  0x00 ; f_19B2
  .db  0x00 ; f_1D76  ; star control
  .db  0x00 ; f_0827
  .db  0x00 ; f_1F85
  .db  0x00 ; f_1F04
  .db  0x00 ; f_0827
  .db  0x01 ; f_1DD2  ; Updates array of 4 timers

  .db  0x00 ; f_2222
  .db  0x00 ; f_21CB
  .db  0x00 ; f_0827
  .db  0x00 ; f_0827
  .db  0x00 ; f_20F2
  .db  0x00 ; f_2000
  .db  0x00 ; f_0827
  .db  0x0A ; f_0977  ; Handles coinage and changes in game-state

;;=============================================================================
;; g_mssl_init()
;;  Description:
;;   For game or "demo-mode" (f_17B2) setup
;;   Initialize "missile" objects (bombs and/or rockets).
;;   One-time init for codes, colors and tiles.
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_game_or_demo_init:
       ld   hl,#ds_sprite_code + 0x64             ; rocket object
       ld   de,#0x0900 + 0x0030                   ; temp store two 8-bit values ... $30 is a rocket
       ld   c,#0
       ld   b,#10

l_1273_while:
       ld   (hl),e                                ; e.g. (8B64):=$30
       ld   h,#>ds_sprite_posn
       ld   (hl),#0
       ld   h,#>ds_sprite_ctrl
       ld   (hl),c
       ld   h,#>ds_sprite_code
       inc  l
       ld   (hl),d                                ; e.g. (8B65):=$09

       inc  l
; if ( B == 9 )
       ld   a,b
       cp   #9
       jr   nz,l_1289
       ld   c,#1
       ld   d,#0x0B                               ; bomb color code

l_1289:
       djnz l_1273_while                          ; B--

       ret

;;=============================================================================
;; sprite_tiles_display()
;;  Description:
;;   Display sprite tiles in specific arrangements loaded from table data.
;;   This is for demo or game-start (bonus-info ) screen but not gameplay.
;; IN:
;;  _attrmode_sptiles: ptr to sprite tiles data
;; OUT:
;;  _attrmode_sptiles: advanced to next data group
;;-----------------------------------------------------------------------------
c_sprite_tiles_displ:
       ld   h,#>ds_sprite_code

; L = p_sptiles_displ[idx*4 + 0] ... index/offset of object to use
       ld   de,(p_attrmode_sptiles)               ; load the persistent pointer (not always needed)
       ld   a,(de)                                ; _attrmode_sptiles[ E + 0 ]
       ld   l,a

; C = p_sptiles_displ[E+1] ... color/code
       inc  de                                    ; _attrmode_sptiles[DE].b01  ... color/code
       ld   a,(de)
       ld   c,a

; sprite_code<3:6>
; tile 0+6 in each set of 8 is the "upright" orientation (wings spread for bug)
       and  #0x78
       add  a,#6
       ld   (hl),a                                ; sprite_code_base[ object + 0 ] ... sprite tile code

; advance pointer, i.e. sprite_code_base[ index + 1 ] ... color code
       inc  l

; get color bits from original color/code value
       ld   a,c
       and  #0x07

; Apparently bit-7 of the color/code provides color bit-3
;     if (C & 0x80)  A |= 0x08
       bit  7,c
       jr   z,l_12A6
       or   #0x08
l_12A6:
       ld   (hl),a                                ; sprite_code_base

       inc  de                                    ; &table[ n + 2 ]  ... L/R offset

       dec  l                                     ; object_data[ n + 0 ] ... object state
       ld   h,#>b_8800
       ld   (hl),#1                               ; disposition = ACTIVE

       ld   h,#>ds_sprite_posn
       ld   a,(de)                                ; L/R offset
       ld   (hl),a                                ; sprite_posn.X

; Y coordinate: the table value is actually sprite.posn.Y<8..1> and the sla
; causes the Cy flag to pick up sprite.posn<8> ...
       inc  de                                    ; &table[ n + 3 ]  ... T/B offset
       inc  l                                     ; sprite_posn.Y<0..7>
       ld   a,(de)
       sla  a
       ld   (hl),a                                ; sprite_posn.Y

; and sprite.posn<8> is handled here, i.e. ctrl[n + 1]<0>
       ld   a,#0                                  ; set the sprite with no additional control attributes
       rla
       ld   h,#>ds_sprite_ctrl
       ld   (hl),a

; advance the pointer
       inc  de                                    ; e.g., DE:=$1960
       ld   (p_attrmode_sptiles),de               ; += 1

       ret

;;=============================================================================
;; gctl_stg_fmtn_hpos_init()
;;  Description:
;;   plyr_changeover or new_stg_setup, also for start of demo "stage"....after
;;   the rank icons are shown and the text is shown i.e. "game over" or "stage x"
;; IN:
;;   A == offset ... 0 on new-screen, $3F on player changeover
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_12C3:
       ld   ixl,a
       ld   a,(b_9215_flip_screen)
       ld   c,a

; init formation location tracking structure: relative (offset) initialize to 0
; and origin coordinate bits<8:1> from data (copy of origin coordinate from
; CPU0 data as it would be outside of address space of CPU1)
       ld   hl,#ds_hpos_loc_t                     ; init home_posn_loc[]
       ld   de,#db_fmtn_hpos_orig
       ld   b,#16                                 ; table size
l_12D1:
       ld   (hl),#0                               ; fmtn_hpos.offs[]
       inc  l
       ld   a,(de)
       inc  de
       ld   (hl),a                                ; pair.b1 i.e. ds_hpos_loc_orig ... copy data for reference in CPU1
       inc  l
       djnz l_12D1

; X coordinates at origin (10 bytes) to even offsets, adjusted for flip-screen.
       ld   hl,#ds_hpos_spcoords                  ; init origin x-coords (10 columns)
       ld   de,#db_fmtn_hpos_orig
       ld   b,#10
l_12E2:
       ld   a,(de)                                ; home_posn_ini[B]
       inc  de

       bit  0,c                                   ; test if flip_screen
       jr   z,l_12EB
       add  a,#0x0D                               ; flipped
       cpl

l_12EB:
       ld   (hl),a                                ; store lsb
       inc  l
       inc  l                                     ; no msb to store
       djnz l_12E2

; Y coordinates at origin (6 bytes) to even offsets. Offset argument (in ixl)
; is added and result adjusted for flip-screen. Only bits <8:1> are stored.
; For non-inverted screen, equivalent of "$0160 - n" is implemented.
       ld   b,#6
l_12F2:
       ld   a,(de)                                ; db_fmtn_hpos_orig[B]
       add  a,ixl
       inc  de

       bit  0,c                                   ; test if flip_screen
       jr   nz,l_12FD
       add  a,#0x4F                               ; add offset
       cpl                                        ; negate

l_12FD:
       sla  a                                     ; Cy now contains bit-8
       ld   (hl),a
       inc  l
       ld   a,#0
       rla                                        ; bit-8 from Cy into bit-0 of MSB
       ld   (hl),a
       inc  l
       djnz l_12F2

       ld   a,(b_9215_flip_screen)
       ld   (ds_9200_glbls + 0x0F),a              ; = _flip_screen (nest direction... 1:left, 0:right)
       ret

;;=============================================================================
;; Initial pixel coordinates of cylon attackers are copied to odd-offsets of home_posn_loc[].
;;
;;   |<-------------- COLUMNS ------------------------>|<---------- ROWS ----------->|
;;
;;     00   02   04   06   08   0A   0C   0E   10   12   14   16   18   1A   1C   1E
;;
;;-----------------------------------------------------------------------------
db_fmtn_hpos_orig:
  .db 0x31,0x41,0x51,0x61,0x71,0x81,0x91,0xA1,0xB1,0xC1, 0x92,0x8A,0x82,0x7C,0x76,0x70

;;=============================================================================
;; c_tdelay_3()
;;  Description:
;;   used in game_ctrl
;;   delay 3 count on .5 second timer used various places (in game_ctrl)
;; IN:
;;  ...
;; OUT:
;;  ...
;; PRESERVES:
;;  HL
;;-----------------------------------------------------------------------------
c_tdelay_3:
       push hl
;  game_tmrs[3] = 3
       ld   hl,#ds4_game_tmrs + 3                 ; =3 ... while ! 0
       ld   (hl),#3
;  while ( game_tmrs[3] != 0 ) {}
l_1325:
       ld   a,(hl)
       and  a
       jr   nz,l_1325

       pop  hl
       ret


;;=============================================================================
;; c_player_respawn()
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
;;-----------------------------------------------------------------------------
c_player_respawn:
       ld   a,#1
       ld   (ds_cpu0_task_actv + 0x14),a         ; 1  (f_1F85 ... control stick input)

; check if "STAGE X" text shown and if so skip showing "READY"
;  if ( *(8270) ) == ' ' ) ...
       ld   a,(m_tile_ram + 0x0260 + 0x10)
       cp   #0x24
       jr   nz,l_133A
; ... else
       ld   c,#3                                  ; string_out_pe  index
       rst  0x30                                  ; string_out_pe "READY" (at 8270)
l_133A:

;;=============================================================================
;; c_133A()
;;  Description:
;;   Demo mode (f_17B2) ...
;;   ...while (bug/bee flys home) ...ship hit, waiting for flying bug to re-nest
;;   Label provided for code reuse (jr from c_player_respawn)
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_133A:

l_133A_while:
       ld   a,(b_bugs_flying_nbr)
       and  a
       jr   nz,l_133A_while                       ; wait for all bugs to stop flying

       call draw_resv_ships                       ; updates reserve ships in lower left corner (wipes CREDIT X)

; put the ship out there
       ld   hl,#0x0900 + 0x0006                   ; two bytes, code 6, color 9
       ld   (ds_sprite_code + 0x62),hl            ; = $0906 ... ship-1 code 6, color 9 (load 16-bits)
       ld   hl,#ds_sprite_posn + 0x62             ; ship (1) position

;  if ( !_flip_screen )  A = $29,  C = 1
       ld   a,(b_9215_flip_screen)
       and  #1
       ld   a,#0x29
       ld   c,#1
       jr   z,l_135A
;  else  A = $37,  C = 0
       add  a,#0x0E                               ; screen is flipped in demo?????
       dec  c
l_135A:
       ld   (hl),#0x7A                            ; SPRPOSN.0[$62] ... sx
       inc  l
       ld   (hl),a                                ; SPRPOSN.1[$62] ... sy<0:7>
       ld   h,#>ds_sprite_ctrl
       ld   (hl),c                                ; SPRCTRL.1[n]:0 ... sy<8>
       dec  l
       xor  a
       ld   (hl),a                                ; 0 ... SPRCTRL.0[n] (no flip/double attribute)

       ld   (ds_9200_glbls + 0x13),a              ; 0 ... stage restart flag
       inc  a
       ld   (ds_99B9_star_ctrl + 0),a             ; 1 ... when ship on screen

       ret

;;=============================================================================
;; fghtr_resv_draw()
;;  Description:
;;   Draws up to 6 reserve ships in the status area of the screen, calling
;;   the subroutine 4 times to build the ship icons from 4 tiles.
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
draw_resv_ships:
       ld   a,(ds_plyr_actv +_b_nships)
       cpl
       add  a,#6                                  ; max nr of icons
       ld   e,a
       ld   d,#0x49                               ; $4A,$4B,$4C,$4D ... / \ [ ]
       ld   hl,#m_tile_ram + 0x0000 + 0x1D
       call draw_resv_ship_tile
       dec  l                                     ; advance 1 column right
       call draw_resv_ship_tile
       set  5,l                                   ; +=32 (down 1 row)
       inc  l                                     ; 1 column to the left
       call draw_resv_ship_tile
       dec  l                                     ; advance 1 column right
;       call draw_resv_ship_tile

;;=============================================================================
;; draw_resv_ship_tile()
;;  Description:
;;   Each ship is composed of 4 tiles. This is called once for each tile.
;;   Each tile is replicated at the correct screem offset, allowing up to 6
;;   reserve ship indicators to be shown. Unused locations are filled with
;;   the "space" character tile.
;; IN:
;;   HL: offset in tile ram
;;    D: tile character
;;    E: nr of reserve ships
;; OUT:
;;    D: tile character (increment)
;; PRESERVES:
;;    HL: current offset in tile ram
;;
;;-----------------------------------------------------------------------------
draw_resv_ship_tile:
       push hl
       inc  d
       ld   b,d
       ld   a,#6 - 1                              ; max nr of resv ship icon
l_138B:
       cp   e
       jr   nz,l_1390
       ld   b,#0x24                               ; space character tile
l_1390:
       ld   (hl),b
       dec  l
       dec  l
       dec  a
       jr   nz,l_138B

       pop  hl
       ret

;;=============================================================================
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
;;    CY: "set" if jumped to j_string_out_pe
;;  OUT:
;;    HL contains final string character display position.
;;
;;    PRESERVES :   DE
;;-----------------------------------------------------------------------------
c_string_out:
       and  a                                     ; clear CY flag.
       ex   af,af'                                ; save CY flag.

j_string_out_pe:
       push de                                    ; preserves DE
       ex   de,hl                                 ; DE := position in tile RAM

; Get address of string pointer using index in C ...
; p_sptr = ( ptr_tbl - sizeof(ptr) ) + sizeof(ptr) * index
       ld   a,c                                   ; C = index into table string pointers (d_cstring_tbl)
       ld   hl,#d_cstring_tbl - 2                 ; index is ordered from 1 !!
       rst  0x08                                  ; HL += 2A

; De-reference the string pointer
; sptr = *(p_sptr)
       ld   a,(hl)                                ; lsb
       inc  hl
       ld   h,(hl)                                ; msb
       ld   l,a                                   ; lsb

; Restore flags and check CY
       ex   af,af'

; if ( CY ) ...
       jr   nc,l_13AE
; ... do PE stuff: get position into DE ... HL-=2, DE:=*(HL)
       dec  hl
       dec  hl
       ld   e,(hl)                                ; LSB
       inc  hl
       ld   d,(hl)                                ; MSB
       inc  hl                                    ; HL now pointing to "color".

; now DE == position, so the rest is the same...
l_13AE:
       ld   c,(hl)                                ; C := color byte ($00 == "cyan")
       inc  hl                                    ; ptr++ (first byte of "text")
       ex   de,hl                                 ; position address in HL, src address in DE
l_13B1:
; if ( TERMINATION ) then exit
       ld   a,(de)
       cp   #0x2F                                 ; string terminator
       jr   z,l_13D4_out
       ;
; only a <space> character ($20) should be < $30
       sub  #0x30                                 ; e.g. ASCII "0" ... ($30 - $30 ) = 0, "1" ... ($31 - $30 ) = 1 ... etc.
       jr   nc,l_13BE
       ld   a,#0x24                               ; generate a <space> character.
       jr   l_13C4_putc
l_13BE:
; if ( A >= $11 )
       cp   #0x11                                 ; e.g. ASCII "A" ... ($41 - $30) = $11
       jr   c,l_13C4_putc
; then A-=7
       sub  #7                                    ; e.g. ASCII "A" ... ($41 - $30 - $07) = $0A
       ;
l_13C4_putc:
       ld   (hl),a                                ; display the character

       set  2,h                                   ; H |= $04  (HL:+=$0400)  offset HL into color RAM $8400-$87FF
       ld   (hl),c                                ; color code in C
       res  2,h                                   ; HL:-=$0400

       inc  de                                    ; psrc++

; HL-=$20 (advance destination position one tile to the "right")
       ld   a,l
       sub  #0x20
       ld   l,a
       jr   nc,l_13B1
       dec  h
       ;
       jr   l_13B1
l_13D4_out:
       pop  de
       ret

;;=============================================================================
; strings for c_string_out
d_cstring_tbl:
  ; 0x00
        .dw s_1414,s_1429,s_1436,s_1441,s_144B,s_1457,s_1461,s_1476,s_1488,s_1493
  ; 0x0A
        .dw s_14A7,s_14C6,s_14D3,s_14EE,s_14F8,s_1507,s_1514,s_1521,s_1525,s_153A
  ; 0x14
        .dw s_1545,s_1552,s_1569,s_1577,s_1590,s_15A7,s_15AD,s_15C1,s_15D5,s_15E7


; "Declare Effective Address" macro (idfk)
; Generates offsets in Playfield Tile RAM from given row/column ordinates. _R
; and _C are 0 based, and this is reflected in the additional "-1" term. The
; coordinate system applies only to the "Playfield" area and is independent of
; the top two rows and bottom two rows of tiles.
; (See tile RAM & color RAM layout ascii art diagram in mrw.s).
.macro  _dea  _R _C
  .dw    m_tile_ram + $$40 + ( $$1C - _C - 1 ) * $$20 + _R
.endm


; Terminated strings (2f). First byte is color-code (1-byte ), unless the string is
; position-encoded, in which case the address word will precede string label.

; $01
        _dea 11 6                                 ; 02EB
s_1414:
        .db 0x00
        .ascii "PUSH START BUTTON/"

; $02
        _dea 16 10                                ; 0270
s_1429:
        .db 0x00
        .ascii "GAME OVER/"

; $03
        _dea 16 10                                ; 0270
s_1436:
        .db 0x00
        .ascii "READY !/"                         ; '!' displays as <space>

; $04
        _dea 16 11                                ; 0250
s_1441:
        .db 0x00
        .ascii "PLAYER 1/"

; $05
s_144B:
        .db 0x00
        .ascii "PLAYER 2/"

; %06
        _dea 16 10                                ; 0270
s_1457:
        .db 0x00
        .ascii "STAGE /"

; $07
        _dea 16 5                                 ; 0310
s_1461:
        .db 0x00
        .ascii "CHALLENGING STAGE/"

; $08
        _dea 16 5                                 ; 0310
s_1476:
        .db 0x00
        .ascii "NUMBER OF HITS/"

; $09
        _dea 19 8                                 ; 02B3
s_1488:
        .db 0x00
        .ascii "BONUS  /"

; $0A
        _dea 17 6                                 ; 02F1
s_1493:
        .db 0x04
        .ascii "FIGHTER CAPTURED/"

; $0B
        _dea 13 0                                 ; 03AD
s_14A7:
        .db 0x00
        .ascii "                           /"     ; 27 spaces

; $0C
        _dea 13 10                                ; 026D
s_14C6:
        .db 0x04
        .ascii "PERFECT c/"

; $0D
        _dea 19 2                                 ; 0373
s_14D3:
        .db 0x05
        .ascii "SPECIAL BONUS 10000 PTS/"

; $0E
        _dea 2 11                                 ; 0242
s_14EE:
        .db 0x00
        .ascii "GALAGA/"

; $0F
        _dea 5 8                                  ; 02A5
s_14F8:
        .db 0x00
        .ascii "]] SCORE ]]/"

; $10
        _dea 8 12                                 ; 0228
s_1507:
        .db 0x00
        .ascii "50    100/"

; $11
        _dea 10 12                                ; 022A
s_1514:
        .db 0x00
        .ascii "80    160/"

; $12
        _dea 11 12                                ; 022B
s_1521:
        .db 0x00
        .ascii "/"

; $13
        _dea 27 6                                 ; 02FB
s_1525:
        .db 0x03                                  ; "(C) 1981 NAMCO LTD."
        .ascii "e 1981 NAMCO LTDa/"

; $14
        _dea 30 11                                ; 025E
s_153A:
        .db 0x04                                  ; "NAMCO" (in styled font)
        .db 0x66,0x67,0x68,0x69,0x6A,0x6B,0x6C,0x2F

; $15
        _dea 15 9                                 ; 028F
s_1545:
        .db 0x04
        .ascii "]RESULTS]/"

; $16
        _dea 18 4                                 ; 0332
s_1552:
        .db 0x05
        .ascii "SHOTS FIRED          /"

; $17
s_1569:
        .db 0x05
        .ascii "  MISSILES/"

; $18
        _dea 21 4                                 ; 0335
s_1577:
        .db 0x05
        .ascii "NUMBER OF HITS       /"

; $19
        _dea 24 4                                 ; 0338
s_1590:
        .db 0x03
        .ascii "HIT]MISS RATIO       /"

; $1A
s_15A7:
        .db 0x03
        .ascii "$`/"                              ; '`' displays as "%" ("$" displays as <space>)

; $1B
        _dea 15 4                                 ; 032F
s_15AD:
        .db 0x05
        .ascii "1ST BONUS FOR   /"

; $1C
        _dea 18 4                                 ; 0332
s_15C1:
        .db 0x05
        .ascii "2ND BONUS FOR   /"

; $1D
        _dea 21 4                                 ; 0335
s_15D5:
        .db 0x05
        .ascii "AND FOR EVERY   /"

; $1E
s_15E7:
        .db 0x05
        .ascii "0000 PTS/"


_l_15f1: ; end area
;           00001700  f_1700

;;
