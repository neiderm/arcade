;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; gg1-2_fx.s:
;;  gg1-2.3m, 'maincpu' (Z80)
;;
;;  step function execution from gg1-2
;;  ship movement, control inputs, flying bugs, flying bombs
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.module ga0
;.area ROM (ABS,OVR)

.include "sfrs.inc"
.include "exvars.inc"
.include "exfuncs.inc"
.include "structs.inc"

;       .org  0x1700
.area CSEG17


;;=============================================================================
;; f_1700()
;;  Description:
;;   Ship-update in training/demo mode.
;;   Called once-per-frame (not in ready or game mode).
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
f_1700:
; labels for "case" blocks in _1713
; switch( *pdb_demo_state_params >> 5) & 0x07 )
       ld   de,(pdb_demo_state_params)            ; cases for switch
       ld   a,(de)
       rlca
       rlca
       rlca
       and  #0x07
       ld   hl,#d_1713                            ; &table
       rst  0x08                                  ; HL += 2A
       ld   a,(hl)
       inc  hl
       ld   h,(hl)
       ld   l,a
       jp   (hl)

d_1713:
       .dw case_1766
       .dw case_1766
       .dw case_171F
       .dw case_1766
       .dw case_1734
       .dw case_172D

case_171F:
       ld   a,(ds3_92A0_frame_cts + 0)
       and  #0x0F
       ret  nz

       ld   hl,#ds_9200_glbls + 0x07              ; training mode, far-right boss turned blue
       dec  (hl)
       ret  nz
       jp   case_1766                             ; training mode, far-right boss exploding

case_172D:
       call c_1F0F                                ; appearance of first attack wave in GameOver Demo-Mode
       ld   de,(pdb_demo_state_params)

case_1734:
       ld   a,(de)                                ; initial appearance of ship in training-mode
       ld   hl,#ds_plyr_actv +_b_2ship
       ld   e,(hl)                                ; setup E for c_1F92
       bit  0,a
       jr   nz,l_1741
       and  #0x0A
       jr   l_1755
l_1741:
       ld   a,(ds_9200_glbls + 0x09)              ; position of attacking object
       ld   l,a
       ld   h,#>ds_sprite_posn
       ld   a,(ds_sprite_posn + 0x62)             ; ship (1) position
       sub  (hl)
       ld   a,#0x0A
       jr   z,l_1755
       ld   a,#0x08
       jr   c,l_1755
       ld   a,#2                                  ; when is jr not taken?
l_1755:
       call c_1F92
       ld   a,(ds3_92A0_frame_cts + 0)
       and  #0x03
       ret  nz
       ld   hl,#ds_9200_glbls + 0x07              ; training mode, far-right boss exploding
       dec  (hl)
       ret  nz
       call c_1F0F                                ; training mode, ship about to shoot?

case_1766:
       ld   de,(pdb_demo_state_params)
       ld   a,(de)
       and  #0xC0
       cp   #0x80
       jr   nz,l_1772
       inc  de                                    ; when is jr not taken?
l_1772:
       inc  de

       ld   a,(de)
       ld   (pdb_demo_state_params),de            ; += 1
; A = (*pdb_demo_state_params >> 5) & 0x07;
       rlca
       rlca
       rlca
       and  #0x07
; switch(...)
       ld   hl,#d_1786
       rst  0x08                                  ; HL += 2A (pointer from index)
       ld   a,(hl)
       inc  hl
       ld   h,(hl)
       ld   l,a
       jp   (hl)

d_1786:
       .dw case_1794
       .dw case_1794
       .dw case_17A1
       .dw case_17A8
       .dw case_17AE
       .dw case_17AE
       .dw case_179C

; prior to bosses and reds appearing
case_1794:
; ds_9200_glbls[0x09] = *pdb_demo_state_params << 1 & 0x7E
       ld   a,(de)
       rlca
       and  #0x7E                                 ; note, mask makes shift into <:0> through Cy irrelevant
       ld   (ds_9200_glbls + 0x09),a
       ret

; after shot-and-hit far-left boss in training mode
case_179C:
       xor  a
       ld   (ds_cpu0_task_actv + 0x03),a          ; 0 ... f_1700
       ret

; shoot-and-hit far-right and far-left boss in training mode
case_17A1:
       ld   a,(de)
       and  #0x1F
l_17A4:
       ld   (ds_9200_glbls + 0x07),a
       ret
;
case_17A8:                                        ; when?
       ld   a,(de)
       and  #0x1F
       ld   c,a
       rst  0x30                                  ; string_out_pe
       ret

; fighter has appeared in training mode
case_17AE:
       inc  de
       ld   a,(de)
       jr   l_17A4

;;=============================================================================
;; f_17B2()
;;  Description:
;;   Frame-update work in training/demo mode.
;;   Called once/frame not in ready or game mode.
;;
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
f_17B2:
; if ( game_state != ATTRACT_MODE ) return
       ld   a,(b8_9201_game_state)
       dec  a
       ret  nz

; switch( demo_idx )
       ld   a,(ds_9200_glbls + 0x03)              ; b_9200_glbls.demo_idx
       ld   hl,#d_17C3_jptbl                      ; table_base
       rst  0x08                                  ; HL += 2A
       ld   e,(hl)
       inc  hl
       ld   d,(hl)
       ex   de,hl
       jp   (hl)

d_17C3_jptbl:
       .dw case_1940   ; 0x00
       .dw case_1948   ; 0x01
       .dw case_1984   ; 0x02
       .dw case_18D9   ; 0x03
       .dw case_18D1   ; 0x04
       .dw case_18AC   ; 0x05
       .dw case_1940   ; 0x06
       .dw case_17F5   ; 0x07
       .dw case_1852   ; 0x08
       .dw case_18D1   ; 0x09
       .dw case_1808   ; 0x0A
       .dw case_18D1   ; 0x0B
       .dw case_1840   ; 0x0C
       .dw case_1940   ; 0x0D
       .dw case_17E1   ; 0x0E

; demo or GALACTIC HERO screen
case_17E1:
; if ( game_timers[3] == 0 ) ...
       ld   a,(ds4_game_tmrs + 3)                 ; if 0, display hi-score tbl
       and  a
       jr   z,l_17EC
; else if ( game_timers[3] == 1 ) break,  else return
       dec  a
       jp   z,l_19A7_end_switch
       ret
l_17EC:
       call c_mach_hiscore_show
       ld   a,#0x0A
       ld   (ds4_game_tmrs + 3),a                 ; $0A ... after displ hi-score tbl
       ret

; just cleared the screen from training mode... wait the delay then shows "game over"
case_17F5:
; if ( ( ds3_92A0_frame_cts[0] & 0x1F ) != 0x1F )  return
       ld   a,(ds3_92A0_frame_cts + 0)
       and  #0x1F
       cp   #0x1F
       ret  nz
; else ...
       ld   a,#1
       ld   (ds_cpu0_task_actv + 0x05),a          ; 1 ... f_0857
       ld   c,#2                                  ; index of string
       rst  0x30                                  ; string_out_pe ("GAME OVER")
       jp   l_19A7_end_switch

; boss with captured-ship has just rejoined fleet in demo
case_1808:
       call c_133A

       ld   hl,#d_181F
       ld   (pdb_demo_state_params),hl            ; &d_181F[0]

       ld   a,#1
       ld   (ds_cpu0_task_actv + 0x03),a          ; 1  (f_1700 ... Ship-update in training/demo mode)
       ld   (ds_cpu0_task_actv + 0x15),a          ; 1  (f_1F04 ...fire button input))
       ld   (ds_cpu1_task_actv + 0x05),a          ; 1  (cpu1:f_05EE ...Manage ship collision detection)
       jp   l_19A7_end_switch

d_181F:
       .db 0x08,0x18,0x8A,0x08,0x88,0x06,0x81,0x28,0x81,0x05,0x54,0x1A,0x88,0x12,0x81,0x0F
       .db 0xA2,0x16,0xAA,0x14,0x88,0x18,0x88,0x10,0x43,0x82,0x10,0x88,0x06,0xA2,0x20,0x56,0xC0

; one time at end of demo, just before "HEROES" displayed, ship has been
; erased from screen but remaining bugs may not have been erased yet.
case_1840:
       rst  0x28                                  ; memset(_9100_game_data,0,$F0)
       call c_1230_init_taskman_structs
       xor  a
       ld   (ds_cpu0_task_actv + 0x10),a          ; 0 (f_1B65 ... Manage flying-bug-attack )
       ld   (ds_9200_glbls + 0x0B),a              ; 0 ... end of demo
       inc  a
       ld   (ds_cpu0_task_actv + 0x02),a          ; 1 ... f_17B2
       jp   l_19A7_end_switch

; one time init for demo (following training mode): just cleared the screen with "GAME OVER" shown
case_1852:
       xor  a
       ld   (ds_plyr_actv +_b_cboss_dive_start),a ; 0
       inc  a
       ld   (b_9AA0 + 0x17),a                     ; 1 ... sound_mgr_reset: non-zero causes re-initialization of sound mgr
       ld   (ds_plyr_actv +_b_stgctr),a           ; 1
       ld   (ds_cpu0_task_actv + 0x03),a          ; 1  (f_1700... Ship-update in training/demo mode)
       ld   (ds_cpu0_task_actv + 0x15),a          ; 1  (f_1F04 ...fire button input))
       ld   (ds_plyr_actv +_b_not_chllg_stg),a    ; 1  (0 if challenge stage...see c_new_stg_game_only)

       ld   hl,#d_1887
       ld   (pdb_demo_state_params),hl            ; &d_1887[0]
       call c_01C5_new_stg_game_or_demo
       call c_133A                                ; apparently erases some stuff from screen?
       ld   a,#1
       ld   (ds_9200_glbls + 0x0B),a              ; 1 ... one time init for demo
       ld   (ds_plyr_actv +_b_atk_wv_enbl),a      ; 1 ... 0 when respawning player ship
       ld   (ds_plyr_actv +_b_cboss_enbl),a       ; 1 ... for demo, force the first diving boss boss into capture mode
       inc  a
       ld   (ds_new_stage_parms + 0x04),a         ; 2
       ld   (ds_new_stage_parms + 0x05),a         ; 2
       jp   l_19A7_end_switch

; offsets
d_1887:
       .db 0x02,0x8A,0x04,0x82,0x07,0xAA,0x28,0x88,0x10,0xAA,0x38,0x82,0x12,0xAA,0x20,0x88
       .db 0x14,0xAA,0x20,0x82,0x06,0xA8,0x0E,0xA2,0x17,0x88,0x12,0xA2,0x14,0x18,0x88,0x1B
       .db 0x81,0x2A,0x5F,0x4C,0xC0

; 0x05 training mode, last (far-left) boss shot first time start of explosion
case_18AC:
       ld   a,(ds4_game_tmrs + 2)
       and  a
       jr   z,l_18BB
       dec  a                                     ; a little bit more of that explosion
       jp   z,l_19A7_end_switch
       cp   #5
       jr   z,l_18C6
       ret
l_18BB:
       ld   a,#0x34
       ld   (b_9200_obj_collsn_notif + 0x34),a    ; $34
       ld   a,#9
       ld   (ds4_game_tmrs + 2),a                 ; 9
       ret
l_18C6:
       xor  a                                     ; near end of training-mode
       ld   (ds_sprite_posn + 0x62),a             ; 0 ... ship (1) is removed from screen
       ld   c,#0x13
       rst  0x30                                  ; string_out_pe ("(C) 1981 NAMCO LTD.")
       ld   c,#0x14
       rst  0x30                                  ; string_out_pe ("NAMCO" - 6 tiles)
       ret

; 0x04 ship just appeared in training mode (state active until f_1700 disables itself)
case_18D1:
       ld   a,(ds_cpu0_task_actv + 0x03)          ; if !0, return
       and  a
       jp   z,l_19A7_end_switch
       ret

; (0x03) one time init for 7 bugs in training mode
case_18D9:
       ld   b,#7                                  ; 4 bosses + 3 moths
l_18DB_while:
; note: pointer to _attrmode_sptiles[n] is a function "parameter", but it is updated inside the function
       call c_sprite_tiles_displ
       djnz l_18DB_while

       xor  a
       ld   (ds_plyr_actv +_b_nships),a           ; 0
       ld   (ds_cpu0_task_actv + 0x05),a          ; 0 ... f_0857
       call c_133A                                ; show_ship

       ld   hl,#0xFF0D
       ld   (b_92C0 + 0x05),hl
       ld   (b_92C0 + 0x04),hl
       ld   (b_92C0 + 0x01),hl
       ld   (b_92C0 + 0x00),hl

       ld   hl,#d_1928
       ld   (pdb_demo_state_params),hl            ; &d_1928[0]

; memset($92ca,$00,$10)
       xor  a
       ld   b,#0x10
       ld   hl,#b_92C0 + 0x0A                     ; memset( ... , 0, $10 )
       rst  0x18                                  ; memset((HL), A=fill, B=ct)

       ld   (ds_plyr_actv +_b_2ship),a            ; 0: not 2 ship
       ld   (ds_9200_glbls + 0x0B),a              ; 0: flying_bug_attck_condtn
       inc  a
       ld   (ds_plyr_actv +_b_cboss_dive_start),a ; 1 ...force this for training mode
       ld   (ds_cpu0_task_actv + 0x10),a          ; 1: f_1B65 ... Manage flying-bug-attack
       ld   (ds_cpu0_task_actv + 0x0B),a          ; 1: f_1DB3 ... Checks enemy status at 9200
       ld   (ds_cpu0_task_actv + 0x03),a          ; 1: f_1700 ... Ship-update in training/demo mode

       ld   a,(_sfr_dsw4)                         ; DSWA ... SOUND IN ATTRACT MODE: b_9AA0[0x17]
       rrca
       and  #0x01
       ld   (b_9AA0 + 0x17),a                     ; from DSWA "sound in attract mode"

       call c_game_or_demo_init
       jp   l_19A7_end_switch

d_1928:
       .db 0x08,0x1B,0x81,0x3D,0x81,0x0A,0x42,0x19,0x81,0x28,0x81,0x08
       .db 0x18,0x81,0x2E,0x81,0x03,0x1A,0x81,0x11,0x81,0x05,0x42,0xC0

; init demo
case_1940:
       call c_sctrl_playfld_clr
       call c_sctrl_sprite_ram_clr
       jr   l_19A7_end_switch

case_1948:
       ld   hl,#d_attrmode_sptiles                ; setup index into sprite data table
       ld   (p_attrmode_sptiles),hl               ; parameter to _sprite_tiles_displ

       xor  a
       ld   (ds_9200_glbls + 0x05),a              ; 0 ... demo_scrn_txt_indx
       ld   (w_bug_flying_hit_cnt),a              ; 0

       ld   a,#2
       ld   (ds4_game_tmrs + 2),a                 ; 2
       jr   l_19A7_end_switch

;; parameters for sprite tiles used in attract mode, 4-bytes each:
;;  0: offset/index of object to use
;;  1: color/code
;;      ccode<3:6>==code
;;      ccode<0:2,7>==color
;;  2: X coordinate
;;  3: Y coordinate
;;
d_attrmode_sptiles:
       .db 0x08,0x1B,0x44,0x3A  ; code $18 (bee)
       .db 0x0A,0x12,0x44,0x42  ; code $10 (moth)
       .db 0x0C,0x08,0x7C,0x50  ; code $08 (boss)
;d_attrmode_sptiles_7 ; label not needed, residual value of the pointer is used
       .db 0x34,0x08,0x34,0x5C  ; code $08
       .db 0x30,0x08,0x64,0x5C  ; code $08
       .db 0x32,0x08,0x94,0x5C  ; code $08
       .db 0x4A,0x12,0xA4,0x64  ; code $10
       .db 0x36,0x08,0xC4,0x5C  ; code $08
       .db 0x58,0x12,0xB4,0x64  ; code $10
       .db 0x52,0x12,0xD4,0x64  ; code $10

case_1984: ; 0x02
;  if ( game_tmrs[2] != 0 ) return
       ld   a,(ds4_game_tmrs + 2)
       and  a
       ret  nz

       ld   a,#2
       ld   (ds4_game_tmrs + 2),a                 ; 2 (1 second)

       ld   a,(ds_9200_glbls + 0x05)              ; if 5 ... demo_scrn_txt_indx
       cp   #5
       jr   z,l_19A7_end_switch

       inc  a
       ld   (ds_9200_glbls + 0x05),a              ; demo_scrn_txt_indx++
       add  a,#0x0D                               ; s_14EE - d_cstring_tbl - 1
       ld   c,a                                   ; C = 0x0D + A ... string index
       rst  0x30                                  ; string_out_pe ("GALAGA", "--SCORE--", etc)

; if ( index < 3 ) return
       ld   a,(ds_9200_glbls + 0x05)              ; if demo_scrn_txt_indx == 3 ... checks for a sprite to display with the text
       cp   #3
       ret  c

       call c_sprite_tiles_displ                  ; note: advances the pointer to _attrmode_sptiles_3[]

       ret

l_19A7_end_switch:
; b_9200_glbls.demo_idx++;
       ld   hl,#ds_9200_glbls + 0x03
       inc  (hl)
; if ( b_9200_glbls.demo_idx != 0x0F )  return
       ld   a,(hl)
       cp   #0x0F
       ret  nz
; b_9200_glbls.demo_idx = 0
       ld   (hl),#0
       ret

;;=============================================================================
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
;;-----------------------------------------------------------------------------
f_19B2:
;  if ( flag  != 0 )  goto show_text
       ld   a,(ds5_928A_captr_status + 0x04)      ; == 1 when boss connects with ship (2318)
       and  a
       jr   nz,l_19D2_fighter_captured

;  else if ( game_tmrs[1] | 0 == 0 )  goto erase_text
;   ... with A already 0, we use OR to check Z flag for zero count... which efficently loads our count to A at the same time!
       ld   hl,#ds4_game_tmrs + 1
       or   (hl)
       jr   z,l_1A01_erase_text

;  else if ( game_tmrs[1] != 4 ) goto 19c7
       cp   #4
       jr   nz,l_19C7

;  timer--   .....decrement timer at 4. ... why? the count is set to 6 (19D7)
       dec  a
       ld   (hl),a
       ld   (b_9AA0 + 0x09),a                     ; game_tmrs[1] ... sound-fx count/enable registers
l_19C7:
       ld   a,(ds_plyr_actv +_b_cboss_slot)       ; bug_flite_que[ plyr.cboss_slot ].b0D = 4
       add  a,#0x0D
       ld   l,a
       ld   h,#>ds_bug_motion_que                 ; bug_flite_que[ plyr.cboss_slot ].b0D = 4
       ld   (hl),#4
       ret

l_19D2_fighter_captured:
; sets up a captured-fighter as an enemy object
       ld   c,#0x0A                               ; index of string
       rst  0x30                                  ; string_out_pe "FIGHTER CAPTURED"
       ld   a,#6                                  ; set time of countdown
       ld   (ds4_game_tmrs + 1),a                 ; 6 ...time to show fighter-captured-text
       ld   hl,#ds_sprite_posn + 0x62             ; ship (1) position
       ld   a,(ds_plyr_actv +_b_cboss_obj)
       and  #7                                    ; captured ships are in same order as bosses, from 8800-8807
       ld   e,a
       ld   d,h
       ld   a,(hl)                                ; get column of ship object e.g. ... A := *(9362)
       ld   (de),a                                ; get column of captured ship object e.g. (DE == 9302)
       ld   (hl),#0
; set row offset of captured ship object
       inc  l
       inc  e
       ld   a,(hl)
       ld   (de),a
; odd byte of sprite ctrl...
       ld   h,#>ds_sprite_ctrl
       ld   d,h
       ld   a,(hl)
       ld   (de),a

       ld   h,#>ds_sprite_code
       ld   l,e
       ld   (hl),#7                               ; sprite code 7 is the vertical ship "wing closed" used for captured ship
       dec  l
       ld   (hl),#7                               ; sprite color ... red
       xor  a
       ld   (ds5_928A_captr_status + 0x01),a      ; 0
       ld   (ds5_928A_captr_status + 0x04),a      ; 0 .... erase fighter-captured text
       ret

l_1A01_erase_text:
; check if text has been cleared yet?
;  if ( *82d1 == $24 ) goto $1a10
       ld   a,(m_tile_ram + 0x02C0 + 0x11)        ; 'I' of fighter captured
       cp   #0x24
       jr   z,l_1A10
;  clear "fighter captured" text
       ld   c,#0x0B                               ; index into string table
       ld   hl,#m_tile_ram + 0x03A0 + 0x11        ; "leftmost" column of row where "fighter captured" is displayed
       call c_string_out                          ; erase fighter capture text
l_1A10:
       ld   a,(ds_plyr_actv +_b_cboss_obj)
       ld   l,a
       and  #0x07                                 ; ships are in same order as bosses, from 8800-8807
       ld   e,a
       ld   h,#>b_8800
       ld   a,(b_9215_flip_screen)
       ld   c,a
       ld   a,(hl)                                ; e.g. HL==8832
       cp   #0x09                                 ; check if object status "flying"
       jr   nz,l_1A3F_join_ship_to_group          ; status changes to 2 (rotating) when boss reaches home positn
       ld   h,#>ds_sprite_posn
       ld   d,h                                   ; DE == captd ship sprite posn
       ld   a,(hl)                                ; HL == boss posn, horizontal
       ld   (de),a
       inc  l
       inc  e
       ld   a,#0x10                               ; offset captured-ship vertically from flying boss
;  if ( !flip_screen ) goto 1a31
       bit  0,c                                   ; C == _flip_screen
       jr   z,l_1A31
       neg                                        ; offset negated for inverted screen.
l_1A31:
       ld   b,a                                   ; A == vertical offset of ship from boss
       add  a,(hl)                                ; HL == boss in sprite posn regs (odds...vertical posn)
       ld   (de),a                                ; ... DE == boss_posn + $10
       rra
       xor  b
       rlca
       and  #0x01
       ld   h,#>ds_sprite_ctrl                    ; .b1
       ld   d,h
       xor  (hl)
       ld   (de),a                                ; update ship sprite ctrl (e.g. 9B03)
       ret

; ...boss status e.g. 8830[n] == $02  (rotating into position)
l_1A3F_join_ship_to_group:
; if ( couonter > 0 ) goto 1A4B
       ld   hl,#ds5_928A_captr_status + 0x01      ; counter while captured ship is joined with the collective
       ld   a,(hl)                                ; a=0
       and  a
       jr   nz,l_1A4B_test_positioning_timer
; else initialize_ship_sprite
       ld   d,#>ds_sprite_code
       ld   a,#6                                  ; ship sprite code
       ld   (de),a
l_1A4B_test_positioning_timer:
       inc  (hl)                                  ; *( ds5_928A_captr_status + 1 )++
       cp   #0x24
       jr   z,l_1A6A_ship_in_position

; set position increment +1 for inverted screen, otherwise -1
       ld   b,#1
       bit  0,c                                   ; C == flip_screen
       jr   nz,l_1A58
       dec  b
       dec  b
l_1A58:
       ld   l,e
       inc  l                                     ; set vertical position (odd-byte)
       ld   h,#>ds_sprite_posn
       ld   a,b
       add  a,(hl)
       ld   (hl),a
       rra
       xor  b
       rlca
       ret  nc
       ld   h,#>ds_sprite_ctrl
       ld   a,(hl)
       xor  #0x01
       ld   (hl),a
       ret

l_1A6A_ship_in_position:
       xor  a
       ld   (ds_cpu0_task_actv + 0x11),a          ; 0 (this task)
       ld   (b_9AA0 + 0x09),a                     ; 0 ... sound-fx count/enable registers
       ld   d,#>b_8800
       inc  a
       ld   (de),a                                ; b_8800[n] = 1 ... resting status
       ld   (ds_plyr_actv +_b_cboss_obj),a        ; 1  .... e.g. was $32  i.e. object locator of capturing boss
       ld   (ds_99B9_star_ctrl + 0x00),a          ; 1  (when ship on screen)
       inc  a
       ld   (ds_9200_glbls + 0x13),a              ; 2 ...fighter captured, set restart-stage flag.
       ret

;;=============================================================================
;; f_1A80()
;;  Description:
;;   "Bonus-bee" manager.
;;   Not active until stage-4 or higher because the parameter is 0.
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
f_1A80:
; check parameter for condition to enable the bonus-bee feature.
; if ( num_bugs > num_bugs_for_bonus_bee ) then return
       ld   a,(ds_new_stage_parms + 0x0A)         ; bonus-bee when bug count reaches this
       ld   c,a
       ld   a,(b_bugs_actv_nbr)
       cp   c
       ret  nc

; if ( activated_one_already ) goto 1AD5
       ld   a,(ds_plyr_actv +_b_bbee_tmr)
       and  a
       jr   nz,l_1AD5_in_one_already
; else ... find_available
       ld   hl,#b_8800 + 0x07                     ; first object of bee group (minus 1)
       ld   bc,#20 * 256 + 0xFF                   ; 20 of these pests (we don't care about C)
       ld   a,#1                                  ; 1 == resting
l_1A97:
       inc  l                                     ; increment to next even offset
       cpi                                        ; A-(HL), HL <- HL+1, BC <- BC-1
       jr   z,l_1AAB_found_one
       djnz l_1A97

; iterate through moth group and find one that is resting
       ld   hl,#b_8800 + 0x40 - 1                 ; offset into moth group
       ld   b,#0x10                               ; 16 of the vermin
l_1AA3:
       inc  l                                     ; increment to next even offset
       cpi
       jr   z,l_1AAB_found_one
       djnz l_1AA3

       ret

l_1AAB_found_one:
       ld   a,#0xC0
       ld   (ds_plyr_actv +_b_bbee_tmr),a         ; $C0 ... delay count until bonus-bee launch
       dec  l
       ld   e,l
       ld   d,#>ds_sprite_code
       inc  e
       ld   a,(de)
       dec  e
       ld   c,a
       ld   a,(ds_plyr_actv +_b_stgctr)           ; "Bonus-bee" manager
       srl  a
       srl  a
       ld   l,a
       ld   h,#0
       ld   a,#3
       call c_divmod                              ; HL=HL/3
       add  a,#4
       ld   hl,#ds_plyr_actv +_b_bbee_obj
       ld   (hl),e
       inc  l
       ld   (hl),c
       inc  l
       ld   (hl),a
       ld   (b_9AA0 + 0x12),a                     ; sound-fx count/enable registers, bonus-bee sound
       ret

l_1AD5_in_one_already:
       inc  a                                     ; A == delay count until bonus-bee launch
       jr   z,l_1AF4_ready_go
       ld   (ds_plyr_actv +_b_bbee_tmr),a         ; A<0 (delay count until bonus-bee launch)
       ex   af,af'                                ; stash the counter
       ld   hl,#ds_plyr_actv +_b_bbee_obj
       ld   e,(hl)
       ld   d,#>b_8800
       ld   a,(de)
; if ( object_status != 1 ) exit  ... (killed the little fucker before he could launch)
       dec  a
       jp   nz,l_1B54_getout
; else
       ld   d,#>ds_sprite_code
       inc  l                                     ; HL:=982E   ... color 'A'
       ex   af,af'                                ; recover the counter
       bit  4,a                                   ; check for %$10 (alternate color every 1/4 second)
       jr   z,l_1AF0_alternating_colors
       inc  l                                     ; HL:=982F   ... color 'B'
l_1AF0_alternating_colors:
       ld   a,(hl)
       inc  e                                     ; point to color register (odd-byte offset)
       ld   (de),a
       ret

l_1AF4_ready_go:
       ld   a,(ds_cpu0_task_actv + 0x15)          ; f_1F04: fire button input ...  a "bonus-bee" has started
       and  a
       jr   nz,l_1B00
       ld   a,#0xE0
       ld   (ds_plyr_actv +_b_bbee_tmr),a         ; $E0
       ret

l_1B00:
       ld   a,(ds_plyr_actv +_b_bbee_obj)
       ld   l,a
       ld   h,#>b_8800
       ld   a,(hl)
       dec  a
       jr   nz,l_1B54_getout                      ; make sure he's not dead
       ld   h,#>b_9200_obj_collsn_notif
       ld   a,(hl)
       bit  7,a
       jr   nz,l_1B54_getout                      ; make sure he's not dead
       ld   a,(ds_plyr_actv +_b_bbee_clr_b)
       sub  #4                                    ; convert color 4,5,or 6 to index from 0
       ld   hl,#d_1B59
       rst  0x08                                  ; HL += 2A
       ld   de,#ds3_99B0_X3attackcfg              ; setup X3 attacker, write 3 bytes...
                                                  ; [0]:=3
                                                  ; [1] [2] word loaded from 1B59[ 2 * ( actv_plyr_state + 0x0F ) ]
       ld   a,#3
       ld   (de),a                                ; (99B0):=3
       inc  e
       ldi
       ldi
       ld   a,(ds_plyr_actv +_b_bbee_clr_b)
       sub  #4                                    ; convert color 4,5,or 6 to index from 0
       and  #0x0F                                 ; hmmmm.... we didn't do this before.. oh well
       ld   c,a
       ld   hl,#d_1B5F                            ; setup to load pointers into DE
       rst  0x08                                  ; HL += 2A
       ld   e,(hl)
       inc  hl
       ld   d,(hl)
; setup HL pointer to object in sprite code registers
       ld   h,#>ds_sprite_code
       ld   a,(ds_plyr_actv +_b_bbee_obj)
       ld   l,a

       ld   a,c                                   ; grab "color B" again
       rlca
       rlca
       rlca
       add  a,#0x56
       ld   c,(hl)
       ld   (hl),a
       ld   a,c                                   ; grab "color B" again
       and  #0xF8                                 ; ?
       ld   c,a
       ld   a,(ds_plyr_actv +_b_bbee_clr_a)
       and  #0x07
       or   c
       ld   (ds_plyr_actv +_b_bbee_clr_a),a
       ld   h,#>b_8800
       call c_1083
l_1B54_getout:
       xor  a
       ld   (ds_cpu0_task_actv + 0x04),a          ; 0: f_1A80 ... this task

       ret

;;=============================================================================
; bonus-bee configuration parameters
d_1B59:
       .db 0x1E,0xBD
       .db 0x0A,0xB8
       .db 0x14,0xBC
d_1B5F:
       .dw 0x04EA
       .dw 0x0473
       .dw 0x04AB

;;=============================================================================
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
;;-----------------------------------------------------------------------------
f_1B65:
; if ( flag == zero ) skip the condition check
       ld   a,(ds_9200_glbls + 0x0B)              ; flying_bug_attck_condtn
       and  a
       jr   z,l_1B75

; if ((0 == ds_cpu0_task_actv[0x15]) && (0 != ds_cpu0_task_actv + 0x1D)) return
       ld   a,(ds_cpu0_task_actv + 0x15)          ; f_1F04 (fire button input)
       ld   c,a
       ld   a,(ds_cpu0_task_actv + 0x1D)          ; f_2000 (destroyed boss that captured ship)
       cpl
       and  c
       ret  z

l_1B75:
       ld   b,#4
       ld   hl,#b_92C0 + 0x0A                     ; check 3 groups of 4 bytes
l_1B7A:
       ld   a,(hl)                                ; byte 0/4 is object index/offset
       inc  a                                     ; 0 when b_92C0_0A[n*4].b0 is $ff
       jr   nz,l_1B8B
       inc  l
       inc  l
       inc  l
       djnz l_1B7A

       ld   a,(ds3_92A0_frame_cts + 0)
       and  #0x0F
       jr   z,l_1BA8
       ret

; moth or bee sortie is ended upon return to base-position, or when destroyed
; A == *HL + 1
l_1B8B:
       ld   (hl),#0xFF                            ; 92CA[ n + 0* 4 ] = $ff
       dec  a                                     ; undo increment of b_92C0_A[L]
       ld   d,#>b_8800
       ld   e,a                                   ; e.g. E=$30 (boss)   8834 (boss already has a captured ship)
       res  7,e
       ex   af,af'                                ; stash A
; if  1 != obj_status[E].b0 then return ... resting/inactive
       ld   a,(de)
       dec  a
       ret  nz                                    ; exit if not available (demo)

       inc  l
       ld   e,(hl)                                ; e.g. 92CA[].b1, lsb of pointer to data
       inc  l
       ld   d,(hl)                                ; e.g. 92CA[].b1, msb of pointer to data
       ex   af,af'                                ; restore A (byte-0 of b_92C0_A[L + n*3] ) ...
       ld   l,a                                   ; ... object index/offset
       ld   h,#>b_8800                            ; e.g. b_8800[$30]
       call c_1079
       ld   a,#1
       ld   (b_9AA0 + 0x13),a                     ; 1 ... sound-fx count/enable registers, bug dive attack sound
       ret

l_1BA8:
       ld   hl,#b_92C0 + 0x00                     ; 3 bytes
       ld   b,#3
l_1BAD:
       dec  (hl)
       jr   z,l_1BB4
       inc  l
       djnz l_1BAD

       ret

l_1BB4:
; if (bugs_flying_nbr > max_flying_bugs_this_rnd) then b_92C0[L] && ret
       ld   a,(ds_new_stage_parms + 0x04)         ; max_flying_bugs_this_round
       ld   c,a
       ld   a,(b_bugs_flying_nbr)
       cp   c
       jr   c,l_1BC0
; maximum nbr of bugs already flying
       inc  (hl)
       ret

; launch another flying bug
l_1BC0:
       set  2,l                                   ; HL == $92C1 etc.
       ld   a,(hl)                                ; HL == $92C5 etc.
       res  2,l
       ld   (hl),a

       ld   a,b
       dec  a

; switch(A)
       ld   hl,#d_1BD1
       rst  0x08                                  ; HL += 2A
       ld   a,(hl)
       inc  hl
       ld   h,(hl)
       ld   l,a
       jp   (hl)
d_1BD1:
       .dw case_1BD7
       .dw case_1BF7
       .dw case_1C01

; set bee launch params
case_1BD7:
       ld   b,#20                                 ; number of yellow aliens
       ld   hl,#b_8800 + 0x08                     ; $08-$2E
       ld   de,#dbx034F

; this section common to both bee and moth launcher, check for next one, skip if already active
l_1BDF:
       ld   a,(ds_plyr_actv +_b_bbee_obj)         ; load bonus-bee parameter
       ld   c,a
l_1BE3:
; if ( 1 == bug_state ) && ... 1 == resting
       ld   a,(hl)                                ; obj_status[L].state
       dec  a
       jr   nz,l_1BEB_next
; ... ( L != bonus_bee_index ) then l_1BF0_found_one
       ld   a,c                                   ; C==offset_to_bonus_bee
       cp   l
       jr   nz,l_1BF0_found_one
l_1BEB_next:
       inc  l
       inc  l
       djnz l_1BE3

       ret

l_1BF0_found_one:
       ld   (b_9AA0 + 0x13),a                     ; from C, !0 ... sound-fx count/enable registers, bug dive attack sound
       call c_1083
       ret

; set red moth launch params
case_1BF7:
       ld   b,#16                                 ; number of red aliens
       ld   hl,#b_8800 + 0x40                     ; red moths $40-$5E
       ld   de,#dbx03A9
       jr   l_1BDF

; boss launcher... we only enable capture-mode for every other one ( %2 )
case_1C01:
; if (boss is diving/capturing ) then goto 1C30
       ld   a,(ds_plyr_actv +_b_cboss_dive_start) ; 1 if capture-mode is active
       and  a
       jr   nz,l_1C30
; if ( boss_capture_mode_toggle % 2 ) then goto 1C30
       ld   hl,#ds_plyr_actv +_b_cboss_enbl       ; a capture boss can start every other cycle
       inc  (hl)
       bit  0,(hl)
       jr   nz,l_1C30

       ld   ixl,2
       ld   iy,#0x0454
       ld   de,#b_8800 + 0x30                     ; bosses start at $30
       ld   b,#0x04                               ; there are 4 of these evil creatures
; for each boss, find first one that status==resting ... he beomes capture-boss
l_1C1B:
       ld   a,(de)
       dec  a                                     ; if resting ... status == 1
       jr   z,l_1C24_boss_capture_enable
       inc  e                                     ; status bytes, evens ... i.e. 8830, 32, etc.
       inc  e
       djnz l_1C1B
       ret

l_1C24_boss_capture_enable:
       ld   a,#1
       ld   (ds_plyr_actv +_b_cboss_dive_start),a ; 1 ... capturing boss activated
       ld   a,e
       ld   (ds_plyr_actv +_b_cboss_obj),a
       jp   j_1CAE

; boss is diving/capturing ... look for a wingman.
; Get a moth index from d_1D2C, check if already flagged by plyr_state[0x0D].
l_1C30:
       ld   hl,#d_1D2C_wingmen
       ld   d,#>b_8800
       ld   bc,#6 * 256 + 0                       ; check 6 objects
l_1C38:
       ld   e,(hl)
       inc  hl
       ld   a,(ds_plyr_actv +_b_bbee_obj)         ; check if bonus-bee
       cp   e
       jr   z,l_1C44
       ld   a,(de)
       dec  a
       sub  #1
l_1C44:
       rl   c                                     ; shifts in a bit from Cy if object status was 1 (00 - 01 = FF)
       djnz l_1C38

       ld   ixl,#0
       ld   b,#4
       ld   ixh,c
l_1C4F:
       ld   a,c
       and  #0x07
       cp   #4
       jr   z,l_1C5B
       cp   #3
       call nc,c_1C8D                             ; this may pop the stack and return
l_1C5B:
       rr   c
       djnz l_1C4F

       inc  ixl
       ld   c,ixh
       ld   b,#4
l_1C65:
       ld   a,c
       and  #0x07
       call nz,c_1C8D                             ; this may pop the stack and return
       rr   c
       djnz l_1C65

; got here by killing all the bosses
       inc  ixl
       ld   de,#b_8800 + 0x30                     ; boss objects are 30 34 36 32
       ld   b,#4
l_1C76:
       ld   a,(de)
       dec  a
       jr   z,l_1CA0
       inc  e
       inc  e
       djnz l_1C76

; shot all bosses.. checks status of captured ship objects (00, 02, 04, 06)
       ld   hl,#b_8800
       ld   b,#4
l_1C83:
       ld   a,(hl)
       dec  a
       jp   z,l_1D25
       inc  l
       inc  l
       djnz l_1C83

       ret

;;=============================================================================
;; c_1C8D()
;;  Description:
;;   for f_1B65
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_1C8D:
       ld   a,b
       bit  1,a
       jr   z,l_1C94
       xor  #0x01
l_1C94:
       and  #0x03
       sla  a
       add  a,#0x30                               ; boss objects are 30 34 36 32
       ld   e,a
       ld   a,(de)
       cp   #0x01                                 ; check for ready/available status
       ret  nz

       pop  hl
l_1CA0:
       ld   iy,#0x0411
       ld   a,(ds_9200_glbls + 0x0B)              ; if (0), iy=$00F1, else iy=$0411
       and  a
       jr   nz,j_1CAE
       ld   iy,#0x00F1

;;=============================================================================
;; from f_1B65 (l_1C24)... boss diving.
;; setup bonus scoring for this one
;;-----------------------------------------------------------------------------
j_1CAE:
       ld   a,e
       rrca
       rrca
       ld   a,e
       rla
       rrca
       ld   (b_92C0 + 0x0A),a                     ; boss diving
       ex   af,af'
       ld   (b_92C0 + 0x0A + 1),iy
       inc  b
       ld   a,e
       and  #0x07
       ld   hl,#ds_plyr_actv +_ds_bonus_codescore
       rst  0x10                                  ; HL += A
       ld   a,ixl
       ex   de,hl
       ld   hl,#d_1CFD
       rst  0x08                                  ; HL += 2A
       ld   a,(hl)
       ld   (de),a                                ; plyr_actv._bonus_codescore[E] = d_1CFD[2*A]
       inc  hl
       inc  e
       ld   a,(hl)
       ld   (de),a
       ld   a,ixl
       cp   #2
       jr   z,l_1CE3
       ld   de,#b_92C0 + 0x0A + 3                 ; 3 groups of 4 bytes
       dec  a
       jr   z,l_1CE0
       call c_1D03                                ; boss dives with wingman
l_1CE0:
       call c_1D03
l_1CE3:
       ld   a,(b_92C0 + 0x0A)                     ; boss diving
       and  #0x07
       ld   l,a
       ld   h,#>b_8800
       ld   a,(hl)
       dec  a
       ret  nz
       ld   c,l                                   ; 1CEE  destroyed moth "wingman" of flying boss...
       ld   hl,#b_92C0 + 0x0A                     ; boss diving
l_1CF2:
       inc  l
       inc  l
       inc  l
       ld   a,(hl)
       inc  a
       jr   nz,l_1CF2
       ex   af,af'
       ld   a,c
       jr   l_1D16

;;=============================================================================
;; data for c_1C8D:
;; override bonus/score attribute in ds_plyr_actv._ds_array8[] for 3 of 4 bosses
;; .b0 ... add to bug_collsn[$0F] (adjusted scoring increment)
;; .b1 -> obj_collsn_notif[L] ... sprite code + 0x80
d_1CFD:
       .db 16 - 3, 0x80 + 0x3A  ; 1600
       .db  8 - 3, 0x80 + 0x37  ; 800
       .db  4 - 3, 0x80 + 0x35  ; 400 (default)

;;=============================================================================
;; c_1D03()
;;  Description:
;;   for c_1C8D
;;   ...boss takes a sortie with one or two wingmen (red-moth) attached.
;; IN:
;;  ...de,#b_92C0 + 0x0A + 3
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_1D03:
       rrc  c
       jr   c,l_1D0D
       dec  b                                     ; after boss docked home with ship
       rrc  c
       jr   c,l_1D0D
       dec  b
l_1D0D:
       ld   a,b
       dec  b
       ld   hl,#d_1D2C_wingmen
       rst  0x10                                  ; HL += A
       ex   af,af'
       ld   a,(hl)
       ex   de,hl

;;=============================================================================
;; out of section at l_1CF2
;;-----------------------------------------------------------------------------
l_1D16:
       rla                                        ; from _1CFB
       rrca
       ld   (hl),a
       ex   af,af'
       inc  l
       ld   a,iyl
       ld   (hl),a
       inc  l
       ld   a,iyh
       ld   (hl),a
       inc  l
       ex   de,hl
       ret                                        ; back to _1CE0, end 'call _1D03'

;;=============================================================================
;; Movement of captured rogue ship... out of section at l_1C83
;;-----------------------------------------------------------------------------
l_1D25:
       ld   de,#dbx0444
       call c_1083
       ret

;;=============================================================================
;; data for f_1B65 (and c_1D03)
;; These are indices of the 6 moths that rest under the 4 bosses.
d_1D2C_wingmen:
       .db 0x4A,0x52,0x5A,0x58,0x50,0x48

;;=============================================================================
;; f_1D32()
;;  Description:
;;   Moves bug nest on and off the screen at player changeover.
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
f_1D32:
       ld   hl,#b8_99B4_bugnest_onoff_scrn_tmr    ; increment timer
       ld   a,(hl)
       and  #0x7F
       sub  #0x7E                                 ; 126 (frames?)
       jr   z,l_1D72                              ; A==0 ...

       ld   c,(hl)
       inc  (hl)                                  ; update timer

       ld   a,(b_9215_flip_screen)
       rlc  c
       xor  c
       rrca

       ld   a,#1                                  ; offset is +1
       jr   c,l_1D4B
       neg                                        ; offset is -1

l_1D4B:
       ld   c,a
       ld   hl,#ds_home_posn_org + (10 * 2)       ; + byte offset to row coordinates

       ld   b,#6                                  ; 6 row coordinates to update
l_1D51:
       ld   a,(hl)
       add  a,c                                   ; + or - 1
       ld   (hl),a                                ; _sprite_coords[ n ] ... LSB
       rra
       xor  c
       inc  l
       rlca
       jr   nc,l_1D5E
       ld   a,(hl)
       xor  #0x01
       ld   (hl),a                                ; add carry (if any) into MSB
l_1D5E:
       inc  l
       djnz l_1D51

; call MOB manager to get everything updated (each call updates half the mob)
; The call expects the frame count in A, but here it is overkill because the
; subroutine is only using bits 0-3 ("A % 4") and updates half of the objects
; on each odd count.
       ld   a,(ds3_92A0_frame_cts + 0)
       and  #0xFC                                 ; force A%4 == 0
       inc  a                                     ; force A%4 == 1
       push af
       call c_23E0
       pop  af
       add  a,#2                                  ; force A%4 = 3
       call c_23E0

       ret

l_1D72:
       ld   (ds_cpu0_task_actv + 0x0E),a          ; f_1D32
       ret

;;=============================================================================
;; f_1D76()
;;  Description:
;;   handles changes in star control status?
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
f_1D76:
       ld   a,(b_9215_flip_screen)
       ld   b,a
       ld   hl,#ds_99B9_star_ctrl + 0x00          ; 1 when ship on screen
       ld   a,(hl)
       inc  l
       and  a
       jr   z,l_1DA8

       ld   a,(hl)                                ; 99BA
       and  a
       ld   a,#0xFD
       jr   nz,l_1D9B                             ; if ( *(99BA) != 0 )
       inc  l
       ld   a,(hl)                                ; 99BB
       inc  l
       cp   (hl)                                  ; 99BC
       jr   z,l_1D8F
       inc  (hl)
l_1D8F:
       ld   a,(hl)
       inc  l
       add  a,(hl)                                ; 99BD
       ld   c,a
       and  #0x3F
       ld   (hl),a
       ld   a,c
       rlca
       rlca
       and  #0x03
l_1D9B:
       bit  0,b                                   ; 9215_flip_screen
       jr   nz,l_1DA1
       neg                                        ; two’s complement
l_1DA1:
       dec  a
       and  #0x07
l_1DA4:
       ld   (ds_99B9_star_ctrl + 0x05),a
       ret

l_1DA8:
       xor  a
       ld   (hl),a                                ; 0 ... 99BA?
       inc  l
       inc  l
       ld   (hl),a                                ; 0 ... 99BC?
       inc  l
       ld   (hl),a                                ; 0 ... 99BD?
       ld   a,#7                                  ; stops stars
       jr   l_1DA4                                ; set star ctrl state

;;=============================================================================
;; f_1DB3() ... 0x0B
;;  Description:
;;   Update enemy status.
;;
;;   only disabled when default task config is
;;   re-loaded from ROM (c_1230_init_taskman_structs) just prior to the Top5
;;   screen shown in attract-mode.
;;
;;   memory structure of enemy army:
;;
;;                         00 04 06 02            ; captured ships
;;                         30 34 36 32
;;                   40 48 50 58 5A 52 4A 42
;;                   44 4C 54 5C 5E 56 4E 46
;;                08 10 18 20 28 2A 22 1A 12 0A
;;                0C 14 1C 24 2C 2E 26 1E 16 0E
;;
;; IN:
;;   obj_collsn_notif[L] set by cpu1:_rocket_hit_detection to $81.
;;   detect and reset bit-7. $01 remains
;;
;; OUT:
;; _obj_status.b0: "activity" byte (see d_23FF_jp_tbl for codes)
;; _obj_status.b1: ($40...$45 if exploding)
;;
;;  mrw_sprite.cclr[ L ].color set to $0A for explosion
;;  obj_collsn_notif[L]  == $01
;;
;;-----------------------------------------------------------------------------
f_1DB3:
       ld   hl,#b_9200_obj_collsn_notif           ; $30 bytes ... test bit-7
       ld   b,#0x30
l_1DB8:
       bit  7,(hl)                                ; bit-7 set ($81) by cpu1 (l_07DB) if the orc has been hit
       jr   nz,l_1DC1_make_him_dead
       inc  l
l_1DBD:
       inc  l
       djnz l_1DB8

       ret

l_1DC1_make_him_dead:
       res  7,(hl)                                ; b_9200_obj_collsn_notif[n] for rckt_hit_hdlr
       ld   h,#>b_8800                            ; disposition = 4 (dying/exploding)
       ld   (hl),#4
       inc  l
       ld   (hl),#0x40                            ; start value for the explosion (40...45)
       ld   h,#>ds_sprite_code
       ld   (hl),#0x0A                            ; update color for inactive/dead sprite
       ld   h,#>b_9200_obj_collsn_notif           ; reload ptr
       jr   l_1DBD
; end 1DB3

;;=============================================================================
;; f_1DD2()
;;  Description:
;;   Updates array of 4 timers at 2Hz rate.
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
f_1DD2:
;  if ( frame_cts[2] & 0x01 ) return ... divides the 4 Hz timer by 2 ... why not just use frame_cts[1]
       ld   a,(ds3_92A0_frame_cts + 2)            ; [2]: 4 Hz timer
       and  #0x01
       ret  nz

       ld   hl,#ds4_game_tmrs + 0                 ; decrement each of the 4 game timers
       ld   b,#4
;  for ( b = 0 ; b < 4 ; b++ ) {
;    if ( game_tmrs[b] > 0 )   game_tmrs[b]--
l_1DDD:
       ld   a,(hl)
       and  a
       jr   z,l_1DE2
       dec  (hl)
l_1DE2:
       inc  l
       djnz l_1DDD
;  }
       ret

;;=============================================================================
;; f_1DE6()
;;  Description:
;;   Provides pulsating movement of the collective.
;;   Enabled by f_2A90 once the initial formation waves have completed.
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
f_1DE6:
;  if ( frame_count % 4 != 0 ) return
       ld  a,(ds3_92A0_frame_cts + 0)             ; frame_ct%4 ... ... (provides 15Hz timer)
       and  #0x03
       ret  nz

       ld   hl,#ds_9200_glbls + 0x0F              ; nest_direction counter for expand/contract motion.
       ld   a,(hl)
       ld   e,a                                   ; PREVIOUS_nest_direction counter
       ld   d,#-1
       bit  7,a
       jr   nz,l_1DFC_contracting

; expanding
       inc  d
       inc  d                                     ; D==1
       inc  (hl)                                  ; nest_direction++
       jr   l_1DFD

l_1DFC_contracting:
       ; D==-1
       dec  (hl)                                  ; nest_direction--

l_1DFD:
       cp   #0x1F                                 ; counting up from $00 to $1F
       jr   nz,l_1E03
       set  7,(hl)                                ; count |= $80 ... = $A0
l_1E03:
       cp   #0x81                                 ; counting down from $A0 to $81 (-$60 to -$7F)
       jr   nz,l_1E09
       res  7,(hl)                                ; count &= ~$80 ... = $00

; Now we have updated the counter, and have D==1 if expanding, D==-1 if contracting.
; Every 8*4 (32) frames, we change the bitmap which determines the positions that are
; updated. This happens to correspond with the "flapping" animation... ~1/2 second per flap.
l_1E09:
       ld   c,(hl)                                ; grab nest_direction while we still have the pointer
       and  #0x07                                 ; modulus 8 ... (A== PREVIOUS counter)
       ld   a,d                                   ; current increment (1 or -1 )
       ld   (ds_9200_glbls + 0x11),a              ; formatn_mv_signage, cpu2 cp with b_9A80 + 0x00

       ld   a,e                                   ; previous_nest_direction counter

; if ( previous_counter % 8 == 0 ) then update_bitmap
       jr   nz,l_1E23

       ld   hl,#d_1E64_bitmap_tables
       ld   a,c                                   ; A = updated_counter
       and  #0x18                                 ; subtracts MOD 8, i.e.  0, 8, 16, 24
       rst  0x08                                  ; HL += 2A   .... table entries are $10 bytes long
       ld   a,e                                   ; A = previous_counter ... restored
       ld   de,#ds10_9920                         ; $10 bytes copied from 1E64+2*A
       ld   bc,#0x0010
       ldir

l_1E23:
; A ^= (HL) ... set Cy determines which parameter is taken. Bit-7 XOR'd with
; flip_screen-bit... done efficiently by rotating bit-7 into bit-0 and back.
       ld   hl,#b_9215_flip_screen
       rlca                                       ; A == previous_counter
       xor  (hl)
       rrca                                       ; Cy now indicates state of bit-7

; Setup parameters for first function call. The first call does just the
; left-most 5 columns. The second call does the rightmost 5 columns and the
; 6 row coordinates, which incidentally will have the same sign! So we stash
; the parameter for the second call in C, at the same time that B is set.

       ld   hl,#ds10_9920                         ; 16 bytes copied from _bitmap_tables+2*A
       ld   de,#ds_home_posn_rel                  ; hl==ds10_9920

       jr   nc,l_1E36

       ld   bc,#0x01FF                            ; B==1, C==-1 (contracting group, non-inverted)
       jr   l_1E39

l_1E36:
       ld   bc,#0xFF01                            ; B==-1, C==1 (expanding group, non-inverted)

l_1E39:
       ld   ixl,#5                                ; 5 leftmost columns
       call c_1E43

; setup parameters for second function call
       ld   b,c                                   ; load second parameter
       ld   ixl,0x0b                              ; 5 right columns + 6 rows

       ; 1E43()

;;=============================================================================
;; c_1E43()
;;  Description:
;;   Updates the row/col coordinate locations for the alien formation.
;;   The selected bitmap table determines whether any given coordinate
;;   dimension is incremented at this update.
;; IN:
;;    HL == saved pointer into working copy of selected bitmap table ($10 bytes)
;;    DE == saved pointer into ds_home_posn_loc
;;        ... object positioning (even: relative offsets .... odd: defaults/origin)
;;    B == +/- 1 increment.
;;    IXL == $05  (repeat count for 5 leftmost columns)
;;    IXL == $0B  (repeat count, for 5 rightmost columns + 6 rows which have the same sign)
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_1E43:
j_1E43:
; check if updating this one
       rrc  (hl)
       jr   nc,l_1E5C_update_ptrs

; obj_pos_rel[ n ] += B
       ld   a,(de)                                ; even-bytes: relative offset
       add  a,b                                   ; +/- 1
       ld   (de),a

; _home_posn_org[ n ] += B ... 10 column coordinates, 6 row coordinates, 16-bits per coordinate
       ld   d,#>ds_home_posn_org
       ld   a,(de)
       add  a,b                                   ; +/- 1
       ld   (de),a

; check for carry
       rra
       xor  b
       rlca
       jr   nc,l_1E5A
; handle carry
       inc  e
       ld   a,(de)                                ; MSB
       xor  #0x01
       ld   (de),a
       dec  e                                     ; LSB again

l_1E5A:
       ld   d,#>ds_home_posn_rel                  ; reset pointer

l_1E5C_update_ptrs:
       inc  e
       inc  e
       inc  l
       dec  ixl
       jr   nz,j_1E43

       ret

;;=============================================================================
;; d_1E64_bitmap_tables
;;  Description:
;;   bitmaps determine at which intervals the corresponding coordinate will
;;   be incremented... allows outmost and lowest coordinates to expand faster.
;;
;;      |<-------------- COLUMNS --------------------->|<---------- ROWS ---------->|
;;
;;-----------------------------------------------------------------------------
d_1E64_bitmap_tables:

  .db 0xFF,0x77,0x55,0x14,0x10,0x10,0x14,0x55,0x77,0xFF,0x00,0x10,0x14,0x55,0x77,0xFF
  .db 0xFF,0x77,0x55,0x51,0x10,0x10,0x51,0x55,0x77,0xFF,0x00,0x10,0x51,0x55,0x77,0xFF
  .db 0xFF,0x77,0x57,0x15,0x10,0x10,0x15,0x57,0x77,0xFF,0x00,0x10,0x15,0x57,0x77,0xFF
  .db 0xFF,0xF7,0xD5,0x91,0x10,0x10,0x91,0xD5,0xF7,0xFF,0x00,0x10,0x91,0xD5,0xF7,0xFF

;;=============================================================================
;; f_1EA4()
;;  Description:
;;    Bomb position updater... this task is not disabled.
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
f_1EA4:
; Determine y-increment: each frame alternates 2 or 3 pixels-per-frame
; increment to provide the average Y velocity, and negated for inverted screen.
       ld   a,(ds3_92A0_frame_cts + 0)
       and  #0x01
       add  a,#2
       ld   b,a
       ld   a,(b_9215_flip_screen)
       and  a
       ld   a,b
       jr   z,l_1EB5
       neg

l_1EB5:
       ld   ixh,a
       ld   l,#0x68                               ; offset into object group for missiles
       ld   de,#b_92B0 + 0x00
       ld   ixl,0x08
l_1EBF:
       ld   h,#>ds_sprite_code
       ld   a,(hl)
       cp   #0x30                                 ; missile sprite codes don't show up until some new-game inits are done
       jr   nz,l_1EFF
; we don't need to do anything until a shot is actually fired
       ld   h,#>ds_sprite_posn
       ld   a,(hl)
       and  a
       jr   z,l_1EFF
; Fun fixed point math: X rate in 92B0[ even ] has a scale factor of
; 32-counts -> 1 pixel-per-frame. Each frame, the (unchanging) dividend
; is loaded from 92B0, the previous MOD32 is added, the new MOD32 is stashed
; in 92B1, and the quotient becomes the new X-offset. Eventually those
; remainders add up to another whole divisor which will add an extra pixel
; to the offset every nth frame. Easy peasy!
; BTW there really is odd values in 92B0, but we just seem to not care about it i.e. mask 7E.
       ex   de,hl
       ld   b,(hl)
       ld   a,b                                   ; A = B = 92B0[even]
       and  #0x7E                                 ; Bit-7 for negative.. and we don't want the 1 ???
       inc  l
       add  a,(hl)
       ld   c,a                                   ; C = A = A + 92B0[odd] ... accumulated division remainder
       and  #0x1F                                 ; MOD 32
       ld   (hl),a
       inc  l
; upper 3 bits rotated into lower, (divide-by-32)
       ld   a,c
       rlca
       rlca
       rlca
       and  #0x07

; need a negative offset of X coordinate if bomb path is to the left
       bit  7,b
       jr   z,l_1EE4
       neg

l_1EE4:
       ex   de,hl
; update X
       add  a,(hl)
       ld   (hl),a    ; 9868[ even ] += A
; update Y, and handle Cy for value > $ff. But wtf does the XOR accomplish since we don't ever use the result in A?
       inc  l
       ld   a,(hl)
       add  a,ixh
       ld   (hl),a                                ; 9868[ odd ] += ixh
       rra                                        ; shifts CY into bit-7 if we overflowed the addition
       xor  ixh
       rlca                                       ; ... and again we have the Cy on overflow... but wtf about the xor?
       jr   nc,l_1EF9
; update "bit-8" of Y coordinate ... should only overflow the Y coordinate once.
       ld   h,#>ds_sprite_ctrl                    ; Y-coordinate, bit-8 at odd indices
       rrc  (hl)                                  ; bit-0 into Cy (should be 0, right?)
       ccf                                        ; from 0 to 1...
       rl   (hl)                                  ; ... and rotate back into bit-0
l_1EF9:
       inc  l
       dec  ixl
       jr   nz,l_1EBF

       ret

l_1EFF:
       inc  l
       inc  e
       inc  e
       jr   l_1EF9

;;=============================================================================
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
;;-----------------------------------------------------------------------------
f_1F04:
; select the input port depending upon whether screen is flipped.
       ld   a,(b_9215_flip_screen)
       add  a,#<ds3_99B5_io_input + 0x01          ; add lsb
       ld   l,a
       ld   h,#>ds3_99B5_io_input                 ; msb
       bit  4,(hl)
       ret  nz                                    ; active low input
; else
       ; call c_1F0F

;;=============================================================================
;; c_1F0F()
;;  Description:
;;   Intialize sprite objects for rockets.
;;   rocket sprite.cclr[n].b0 is initialized by c_game_or_demo_init
;;   Updates game shots fired count.
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_1F0F:
; if ( 0 == sprite.posn[ RCKT0 ].b0 ) goto l_1F1E
       ld   hl,#ds_sprite_posn + 0x64             ; offsetof( RCKT_0 )
       ld   de,#b_92A0 + 0x04                     ; rocket "attribute"
       xor  a
       cp   (hl)                                  ; if (0)
       jr   z,l_1F1E

; else if ( sprite.posn[ RCKT1 ].b0 ) return
       ld   l,#<ds_sprite_posn + 0x66             ; offsetof( RCKT_1 )
       inc  e                                     ; rocket "attribute"
       cp   (hl)                                  ; if (0)
       ret  nz

l_1F1E:
; save pointer to attribute, and stash 'offsetof( RCKT_X )' in E

       push de                                    ; save pointer to rocket "attribute"
       ex   de,hl                                 ; E = 'offsetof( RCKT_X )'.b0

       ld   hl,#ds_sprite_ctrl + 0x62 + 1         ; sprite.ctrl[SHIP].b1
       ld   d,h                                   ; sprite.ctrl[0] ... E == 'offsetof( RCKT_X )'
       inc  e                                     ; 'offsetof( RCKT_X )'.b1

       bit  2,(hl)                                ; no idea
       jr   z,l_1F2B

       pop  de
       ret

l_1F2B:
; sprite.ctrl[RCKT+n].b1 = sprite.ctrl[SHIP].b1 ... ship.sY, bit-8
       ldd                                        ; e.g. *(9B65--) = *(9B63--)

       ld   h,#>ds_sprite_posn
       ld   d,h
; sprite.posn[RCKT+n].b0 = sprite.posn[SPR_IDX_SHIP].b0  ... ship.sX
       ldi                                        ; e.g. *(9B64++) = *(9B62++)
; sprite.posn[RCKT+n].b1 = sprite.posn[SPR_IDX_SHIP].b1  ... ship.sY, bit 0-7
       ldd                                        ; e.g. *(9B65--) = *(9B63--)


; B = sprite.ctrl[SHIP].b0
       ld   h,#>ds_sprite_ctrl
       ld   d,h
       ld   b,(hl)                                ; normally 0 (not doubled or flipped)

       ex   de,hl                                 ; DE = sprite.ctrl[SHIP].b0, HL = sprite.ctrl[RCKT].b0

; sprite.ctrl[RCKT].b0.dblw = (two_ship << 3 )
       ld   a,(ds_plyr_actv +_b_2ship)
       and  #0x01                                 ; make sure its only bit-0 I guess ?
       rlca
       rlca
       rlca                                       ; in bit3 now fpr dblw attribute

; sprite.ctrl[SHIP].b0 ... typically 0, unless ship is spinning
       or   b                                     ; A |= sprite.ctrl[SHIP].b0
       ld   (hl),a

; determine rocket sprite code based on ship sprite code, which ranges from 6 (upright orientation)
; down to the 90 degree rotation. Rocket code can be 30, 31, or 33 (360, 315, or 90 degree).
; rocket sprite 32 is also 360 or 0 degree but not used ? (unless its the 2nd rocket, which is done by sprite doubling).
       ld   d,#>ds_sprite_code
       ld   a,(de)
       ld   h,d
       and  #0x07                                 ; ship sprite should not be > 7 ?

       ld   c,#0x30                               ; code $30 ... 360 degree default orientation
; if ( A >= 5 ) then  ... code = $30
       cp   #5
       jr   nc,l_1F56_set_rocket_sprite_code
; else ( A >= 2 ) then .. code = $31
       inc  c                                     ; code $31 ... 45 degree rotation
       cp   #2
       jr   nc,l_1F56_set_rocket_sprite_code
; else  ... code = $33
       inc  c                                     ; code $32 is skipped (also 360)
       inc  c                                     ; code $33 ... 90 degree rotation
l_1F56_set_rocket_sprite_code:
       ld   (hl),c


; Displacement in both X and Y axis must be computed in order to launch rockets
; from the spinning ship. The "primary" axis of travel is whichever one the
; ship is more closely aligned with and is assigned the maximum displacement
; value of 6.
;
; If the code is 4 thru 6, sY is the primary axis of motion (norm
; for non-rotated ship), indicated by setting the orientation bit (+ $40).
;
; dX in the secondary axis is determined by the sprite rotation (code)
; as shown in the table below, where the displacement ranges from 0 (ship
; rotated 90 * n) to a maximum amount of 3 as the ship approaches a rotation
; of primary+45.
;
; See c_0704_update_rockets in cpu1.
;
;   code= 6     dS=0      $40     ... 7 - (6+1)
;   code= 5     dS=1      $40     ... 7 - (5+1)
;   code= 4     dS=2      $40     ... 7 - (4+1)
;   code= 3     dS=3      $00
;   code= 2     dS=2      $00
;   code= 1     dS=1      $00
;   code= 0     dS=0      $00

; if ( A < 4 ) ...
       cp   #4                                    ; A == sprite.cclr[SHIP].b0;
       jr   c,l_1F5E

; ... dS := 7 - ( code + 1 ) + 0x40
       cpl
       add  a,#0x40 + 7
; else ... no orientation swap needed, use sprite code for dS

l_1F5E:
       sla  a                                     ; "orientation" bit into bit-7 ...
       ld   c,a                                   ; ... and displacement << 1  into bits 1:2

; sprite.ctrl bits ...  flipx into bit:5, flipy into bit:6
       ld   a,b                                   ; B == sprite.ctrl[SHIP].b0
       rrca
       rrca
       rrca
       and  #0x60                                 ; mask of rotated SPRCTRL[0]:0 and SPRCTRL[0]:1 bits
       ld   b,a

       ld   a,(b_9215_flip_screen)
       and  a
       ld   a,b                                   ; flipx/flipy bits (0x60)
       jr   nz,l_1F71
       xor  #0x60                                 ; screen not flipped so invert those bits
l_1F71:
       or   c                                     ; bit7=orientation, bit6=flipY, bit5=flipX, 1:2=displacement
       pop  de                                    ; pointer to rocket attribute
       ld   (de),a

       ld   h,#>b_8800                            ; code = 6 ... active rocket object
       ld   (hl),#6                               ; L == offsetof(rocket)

       ld   a,#1
       ld   (b_9AA0 + 0x0F),a                     ; 1 ... sound-fx count/enable registers, shot-sound

       ld   hl,(ds_plyr_actv +_w_shot_ct)
       inc  hl
       ld   (ds_plyr_actv +_w_shot_ct),hl         ; game shots fired count ++

       ret
; end 1F04

;;=============================================================================
;; f_1F85()
;;  Description:
;;   Handle changes in controller IO Input bits, update ship movement.
;;   (Called continuously in game-play, but also toward end of demo starting
;;   when the two ships are joined.)
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
f_1F85:
       ld   a,(ds_plyr_actv +_b_2ship)
       ld   e,a

; read from io_input[1] or io_input[2] depending whether screen is flipped.
       ld   a,(b_9215_flip_screen)
       add  a,#<ds3_99B5_io_input + 1             ; LSB
       ld   l,a
       ld   h,#>ds3_99B5_io_input                 ; MSB
       ld   a,(hl)

;      call c_1F92

;;=============================================================================
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
;;        2 ---> R
;;        8 ---> L
;;   E == actv_plyr_state[7]  .... double ship flag
;;
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_1F92:
; if ( ( A & 0x0A ) == $0A ... inputs are active low, neither left or right active
       and  #0x0A
       cp   #0x0A
       jr   z,l_1FCF_no_input

; invert the input bits if screen flipped (swap L/R direction)
       ld   hl,#b_9215_flip_screen
       bit  0,(hl)
       jr   z,l_1FA1_set_ship_dx
       xor  #0x0A                                 ; screen is flipped

; set ship.dX (1 or 2)
l_1FA1_set_ship_dx:
       ld   hl,#b_92A0 + 0x03                     ; ship_dX_flag
       ld   b,a                                   ; stash the control input bits
       ld   c,#1                                  ; ship_dX = 1
; toggle ship_dX_flag
       ld   a,(hl)
       xor  #0x01
       ld   (hl),a                                ; dX.flag ^= 1

; if (0 == ship_dX_flag) ship_dX++
       jr   nz,l_1FAE_handle_input_bits
       inc  c

l_1FAE_handle_input_bits:
; if ( ship.posn.x == 0 ) return
       ld   hl,#ds_sprite_posn + 0x62             ; "main" ship (single) position
       ld   a,(hl)
       and  a
       ret  z

; if ( ! input.Right ) ... test left limit
       bit  1,b                                   ; if ( ! input bits.right ) ... inverted
       jr   nz,l_1FC7_test_llmt

; ... else ...

; if ( ship.posn.x > 0xD1) ... moving right: check right limit for double-ship
       ld   a,(hl)
       cp   #0xD1                                 ; right limit, double-ship
       jr   c,l_1FC0_test_rlmt_single
; else if ( double_ship ) return
       bit  0,e                                   ; if ( is_double_ship & 0x01 )
       ret  nz                                    ; at right limit of double-ship

l_1FC0_test_rlmt_single:
; else if ( ship.posn.x >= 0xE1 ) return
       cp   #0xE1                                 ; right limit, single-ship
       ret  nc
; else ... add dX for right direction
       add  a,c
       ld   (hl),a
       jr   l_1FD4_update_two_ship

; ... test left limit
l_1FC7_test_llmt:
; if ( ship.posn.x < 0x12 ) return
       ld   a,(hl)
       cp   #0x12                                 ; left limit
       ret  c
; else
       sub  c                                     ; subtract dX
       ld   (hl),a
       jr   l_1FD4_update_two_ship

l_1FCF_no_input:
       xor  a
       ld   (b_92A0 + 0x03),a                     ; ship_dX_flag = 0
       ret


l_1FD4_update_two_ship:
; if ( ! two_ship_plyr )  return
       bit  0,e
       ret  z
; else ... ship2.posn.x = ship1.posn.x + $0F
       add  a,#0x0F                               ; +single ship position
       ld   (ds_sprite_posn + 0x60), a            ; double ship position
       ret

; end 1F85


; _l_1FDD:

;;=============================================================================

;       .ds  0x23                                  ; pad

;;=============================================================================

;           00002000  f_2000

;;
