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
.include "structs.inc"
.include "gg1-2_fx.dep"

;       .org  0x1700
.area CSEG17


;;=============================================================================
;; f_1700()
;;  Description:
;;   Fighter control, only called in training/demo mode.
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
f_1700:
; labels for "case" blocks in _1713
; switch( *_demo_fghtrvctrs >> 5) & 0x07 )
       ld   de,(pdb_demo_fghtrvctrs)              ; cases for switch
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

; boss+wingmen nearly to fighter
case_171F:  ; 0x02
       ld   a,(ds3_92A0_frame_cts + 0)
       and  #0x0F
       ret  nz

       ld   hl,#ds_9200_glbls + 0x07              ; timer, training mode, far-right boss turned blue
       dec  (hl)
       ret  nz
       jp   case_1766                             ; training mode, far-right boss exploding

; appearance of first enemy formation in Demo
case_172D:  ; 0x05
       call c_1F0F                                ; init sprite objects for rockets
       ld   de,(pdb_demo_fghtrvctrs)              ; trampled DE so reload it

; drives the simulated inputs to the fighter in training mode
case_1734:  ; 0x04
       ld   a,(de)                                ; *pdb_demo_fghtrvctrs

       ld   hl,#ds_plyr_actv +_b_2ship
       ld   e,(hl)                                ; setup E for c_1F92

       bit  0,a
       jr   nz,l_1741
       and  #0x0A
       jr   l_1755

l_1741:
       ld   a,(ds_9200_glbls + 0x09)              ; object/index of targeted alien
       ld   l,a
       ld   h,#>ds_sprite_posn

       ld   a,(ds_sprite_posn + 0x62)             ; ship (1) position
       sub  (hl)
       ld   a,#0x0A
       jr   z,l_1755
       ld   a,#0x08                               ; right
       jr   c,l_1755
       ld   a,#2                                  ; left
l_1755:
       call c_1F92
       ld   a,(ds3_92A0_frame_cts + 0)
       and  #0x03
       ret  nz
       ld   hl,#ds_9200_glbls + 0x07              ; timer, training mode, far-right boss exploding
       dec  (hl)
       ret  nz
       call c_1F0F                                ; init sprite objects for rockets ...training mode, ship about to shoot?

case_1766:  ; 0x00, 0x01, 0x03
       ld   de,(pdb_demo_fghtrvctrs)
       ld   a,(de)
       and  #0xC0                                 ; 0x80 fires shot ... 0xC0 is end of sequence
       cp   #0x80
       jr   nz,l_1772
       inc  de                                    ; firing shot ... advance to next token
l_1772:
       inc  de

       ld   a,(de)
       ld   (pdb_demo_fghtrvctrs),de              ; += 1
; A = (*_demo_fghtrvctrs >> 5) & 0x07;
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
       jp   (hl)                                  ; 1784

d_1786:
       .dw case_1794  ; 0
       .dw case_1794  ; 1 -> $2x
       .dw case_17A1  ; 2 -> $4x
       .dw case_17A8  ; 3
       .dw case_17AE  ; 4 -> $8x
       .dw case_17AE  ; 5
       .dw case_179C  ; 6 -> $Cx

; load index/position of target alien
case_1794:
; ds_9200_glbls[0x09] = *_demo_fghtrvctrs << 1 & 0x7E
       ld   a,(de)
       rlca                                       ; rotate bits<6:1> into place
       and  #0x7E                                 ; mask out Cy rlca'd into <:0>
       ld   (ds_9200_glbls + 0x09),a              ; index/position of of target alien
       ret

; $C0: last token, shot-and-hit far-left boss in training mode (second hit)
case_179C:
       xor  a
       ld   (ds_cpu0_task_actv + 0x03),a          ; 0 ... f_1700() end of fighter control sequence
       ret

; $4x: shoot-and-hit far-right or far-left boss (once) in training mode
case_17A1:
       ld   a,(de)
       and  #0x1F
l_17A4:
       ld   (ds_9200_glbls + 0x07),a              ; demo timer
       ret

; when?
case_17A8:
       ld   a,(de)
       and  #0x1F
       ld   c,a
       rst  0x30                                  ; string_out_pe
       ret

; $8x: prior to each fighter shot in training mode?
case_17AE:
       inc  de
       ld   a,(de)
       jr   l_17A4

;;=============================================================================
;; f_17B2()
;;  Description:
;;   Manage attract mode, control sequence for training and demo screens.
;;   The state progression is always the same, ordered by the state-index
;;   (switch variable).
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
       ld   a,(ds_9200_glbls + 0x03)              ; demo state variable (jp to "switch-case")
       ld   hl,#d_17C3_jptbl                      ; table_base
       rst  0x08                                  ; HL += 2A
       ld   e,(hl)
       inc  hl
       ld   d,(hl)
       ex   de,hl
       jp   (hl)

d_17C3_jptbl:
       .dw case_1940   ; 0x00 . clear tile and sprite ram
       .dw case_1948   ; 0x01   setup info-screen: sprite tbl index, text index, preload tmr[2]==2
       .dw case_1984   ; 0x02   tmr[2]=2,  sequence info-text and sprite tiles indices 1 sec intervals
       .dw case_18D9   ; 0x03   task[F_demo_fghter_ctrl]==1  init 7 aliens for training mode
       .dw case_18D1   ; 0x04 ~ wait for task[F_demo_fghter_ctrl]==0 training-mode runs before advance state
       .dw case_18AC   ; 0x05   synchronize copyright text with completion of explosion of last boss
       .dw case_1940   ; 0x06 . clear tile and sprite ram
       .dw case_17F5   ; 0x07   delay ~1 sec before puts("GAME OVER")
       .dw case_1852   ; 0x08   init demo   task[F_demo_fghter_ctrl]==1
       .dw case_18D1   ; 0x09 ~ wait for task[F_demo_fghter_ctrl]==0 demo-mode runs before advance state
       .dw case_1808   ; 0x0A   task[F_demo_fghter_ctrl]==1
       .dw case_18D1   ; 0x0B ~ wait for task[F_demo_fghter_ctrl]==0 boss-capture before advance state
       .dw case_1840   ; 0x0C   end of Demo - init taskman, disable flying_bug_ctrl(), global enemy ct 0,
       .dw case_1940   ; 0x0D . clear tile and sprite ram
       .dw case_17E1   ; 0x0E   end of Demo ... delay, then show GALACTIC HERO screen

; 0E: end of Demo ...  delay, then show GALACTIC HERO screen
case_17E1:
; if ( game_timers[3] == 0 ) then l_17EC
       ld   a,(ds4_game_tmrs + 3)                 ; if 0, display hi-score tbl
       and  a
       jr   z,l_17EC
; else if ( game_timers[3] == 1 )  advance state
       dec  a
       jp   z,l_attmode_state_step
; else break
       ret
l_17EC:
       call c_mach_hiscore_show
       ld   a,#0x0A
       ld   (ds4_game_tmrs + 3),a                 ; $0A ... after displ hi-score tbl
       ret

; 07: just cleared screen from training mode, delay ~1 sec before puts("game over")
case_17F5:
; if ( ( ds3_92A0_frame_cts[0] & 0x1F ) == 0x1F )
       ld   a,(ds3_92A0_frame_cts + 0)
       and  #0x1F
       cp   #0x1F
       ret  nz
; then ...
       ld   a,#1
       ld   (ds_cpu0_task_actv + 0x05),a          ; 1 ... f_0857
       ld   c,#2                                  ; index of string
       rst  0x30                                  ; string_out_pe ("GAME OVER")
       jp   l_attmode_state_step

; 10: enable fighter control demo
case_1808:
       call c_133A

       ld   hl,#d_181F
       ld   (pdb_demo_fghtrvctrs),hl              ; &d_181F[0]

       ld   a,#1
       ld   (ds_cpu0_task_actv + 0x03),a          ; 1  (f_1700 ... fighter control in training/demo mode)
       ld   (ds_cpu0_task_actv + 0x15),a          ; 1  (f_1F04 ... fire button input))
       ld   (ds_cpu1_task_actv + 0x05),a          ; 1  (cpu1:f_05EE ... fighter collision detection)
       jp   l_attmode_state_step

; demo fighter vectors demo level after capture
d_181F:
       .db 0x08,0x18,0x8A,0x08,0x88,0x06,0x81,0x28,0x81,0x05,0x54,0x1A,0x88,0x12,0x81,0x0F
       .db 0xA2,0x16,0xAA,0x14,0x88,0x18,0x88,0x10,0x43,0x82,0x10,0x88,0x06,0xA2,0x20,0x56,0xC0

; 12: end of Demo, fighter has been erased but remaining enemies may not have been erased yet
case_1840:
       rst  0x28                                  ; memset(mctl_mpool,0,$$14 * 12)
       call c_1230_init_taskman_structs

       xor  a
       ld   (ds_cpu0_task_actv + 0x10),a          ; 0 (f_1B65 ... manage bomber attack )
       ld   (ds_9200_glbls + 0x0B),a              ; 0 ... glbl_enemy_enbl, end of demo

; have to re-set enable bit for this flag after init_structs
       inc  a
       ld   (ds_cpu0_task_actv + 0x02),a          ; 1 ... f_17B2 (attract-mode control)

       jp   l_attmode_state_step

; 08: init demo (following training mode) ... "GAME OVER" showing
case_1852:
       xor  a
       ld   (ds_plyr_actv +_b_bmbr_boss_cflag),a  ; 0 ... enable capture-mode selection
       inc  a
       ld   (b_9AA0 + 0x17),a                     ; 1 ... sound_mgr_reset: non-zero causes re-initialization of sound mgr
       ld   (ds_plyr_actv +_b_stgctr),a           ; 1
       ld   (ds_cpu0_task_actv + 0x03),a          ; 1  (f_1700 ... fighter control in training/demo mode)
       ld   (ds_cpu0_task_actv + 0x15),a          ; 1  (f_1F04 ... fire button input)
       ld   (ds_plyr_actv +_b_not_chllg_stg),a    ; 1  (0 if challenge stage ...see new_stg_game_only)

       ld   hl,#d_1887
       ld   (pdb_demo_fghtrvctrs),hl              ; &d_1887[0]
       call stg_init_env
       call c_133A                                ; apparently erases some stuff from screen?

       ld   a,#1
       ld   (ds_9200_glbls + 0x0B),a              ; 1 ... glbl_enemy_enbl, one time init for demo
       ld   (ds_plyr_actv +_b_atk_wv_enbl),a      ; 1 ... 0 when respawning player ship
       ld   (ds_plyr_actv +_b_bmbr_boss_wingm),a  ; 1 ... for demo, force the bomber-boss into wingman-mode
       inc  a
       ld   (ds_new_stage_parms + 0x04),a         ; 2 ... max_bombers (demo)
       ld   (ds_new_stage_parms + 0x05),a         ; 2 ... increases max bombers in certain conditions (demo)
       jp   l_attmode_state_step

; demo fighter vectors demo level before capture
d_1887:
       .db 0x02,0x8A,0x04,0x82,0x07,0xAA,0x28,0x88,0x10,0xAA,0x38,0x82,0x12,0xAA,0x20,0x88
       .db 0x14,0xAA,0x20,0x82,0x06,0xA8,0x0E,0xA2,0x17,0x88,0x12,0xA2,0x14,0x18,0x88,0x1B
       .db 0x81,0x2A,0x5F,0x4C,0xC0

; 05: synchronize copyright text with completion of explosion of last boss
case_18AC:
; tmr[2] always 0 at transition to this case (was reloaded at last of 5 texts in case_1984)
; if (0 == tmr[2])  collsn_notif && tmr[2]=9 && break
       ld   a,(ds4_game_tmrs + 2)                 ; always 0 here at entry to case_18AC
       and  a
       jr   z,l_18BB
; else  if (1 == tmr[2])  state++ ; break
       dec  a
       jp   z,l_attmode_state_step
; else  if (6 == tmr)  copyright_info ; break
       cp   #5
       jr   z,l_18C6
; else  break
       ret

l_18BB:
; tmr == 0 ... put 4.5 seconds on the clock (but transitions to next case at tmr==1, so delay actually 4 secs)
       ld   a,#0x34
       ld   (b_9200_obj_collsn_notif + 0x34),a    ; $34
       ld   a,#9
       ld   (ds4_game_tmrs + 2),a                 ; 9
       ret
l_18C6:
; tmr == 5, explosion complete ... '150' score on display
       xor  a
       ld   (ds_sprite_posn + 0x62),a             ; 0 ... fighter (1) is removed from screen
       ld   c,#0x13
       rst  0x30                                  ; string_out_pe ("(C) 1981 NAMCO LTD.")
       ld   c,#0x14
       rst  0x30                                  ; string_out_pe ("NAMCO" - 6 tiles)
       ret

; 04, 09, 11: wait for fighter control task to disable itself
case_18D1:
; if (0 == task_actv_tbl_0[0x03])  attmode_state_step()
       ld   a,(ds_cpu0_task_actv + 0x03)          ; wait for task[f_1700 fighter ctrl ]==0 before advance state
       and  a
       jp   z,l_attmode_state_step
       ret

; 03: one time init for 7 enemies in training mode
case_18D9:
       ld   b,#7                                  ; 4 bosses + 3 moths
l_18DB_while:
       call c_sprite_tiles_displ                  ; updates offset of pointer to _attrmode_sptiles[0]
       djnz l_18DB_while

       xor  a
       ld   (ds_plyr_actv +_b_nships),a           ; 0
       ld   (ds_cpu0_task_actv + 0x05),a          ; 0 ... f_0857 uses tmr[2]
       call c_133A                                ; fghtr_onscreen()

; set inits and override defaults of bomber timers (note f_0857 disabled above)
       ld   hl,#0xFF0D
       ; tmrs_init[0x06] = 0xFF
       ld   (b_92C0 + 0x05),hl                    ; demo ... timrs[0x06] = $FF
       ld   (b_92C0 + 0x04),hl                    ; demo ... timrs
       ; tmrs[0x02] = 0xFF
       ld   (b_92C0 + 0x01),hl                    ; demo ... timrs_ini[0x06] = $FF
       ld   (b_92C0 + 0x00),hl                    ; demo ... timrs_ini

       ld   hl,#d_1928                            ; demo fighter vectors
       ld   (pdb_demo_fghtrvctrs),hl              ; &d_1928[0] ... demo fighter vectors

; memset($92ca,$00,$10)
       xor  a
       ld   b,#0x10
       ld   hl,#bmbr_boss_pool                    ; memset( ... , 0, $10 )
       rst  0x18                                  ; memset((HL), A=fill, B=ct)

       ld   (ds_plyr_actv +_b_2ship),a            ; 0: not double fighter
       ld   (ds_9200_glbls + 0x0B),a              ; 0: glbl_enemy_enbl (demo)
       inc  a
       ld   (ds_plyr_actv +_b_bmbr_boss_cflag),a  ; 1 ... force bomber-boss wingman for training mode
       ld   (ds_cpu0_task_actv + 0x10),a          ; 1: f_1B65 ... manage bomber attack
       ld   (ds_cpu0_task_actv + 0x0B),a          ; 1: f_1DB3 ... check enemy status at 9200
       ld   (ds_cpu0_task_actv + 0x03),a          ; 1: f_1700 ... fighter control in training/demo mode

       ld   a,(_sfr_dsw4)                         ; DSWA ... SOUND IN ATTRACT MODE: _fx[0x17]
       rrca
       and  #0x01
       ld   (b_9AA0 + 0x17),a                     ; from DSWA "sound in attract mode" ... 0 == enable CPU-sub2 process

       call c_game_or_demo_init

       jp   l_attmode_state_step

; demo fighter vectors training mode
d_1928:
       .db 0x08,0x1B,0x81,0x3D,0x81,0x0A,0x42,0x19,0x81,0x28,0x81,0x08
       .db 0x18,0x81,0x2E,0x81,0x03,0x1A,0x81,0x11,0x81,0x05,0x42,0xC0

; 00, 06, 13: clear tile and sprite ram
case_1940:
       call c_sctrl_playfld_clr
       call c_sctrl_sprite_ram_clr
       jr   l_attmode_state_step

; 01: setup info-screen: sprite tbl index, text index, timer[2]
case_1948:
       ld   hl,#d_attrmode_sptiles                ; setup index into sprite data table
       ld   (p_attrmode_sptiles),hl               ; parameter to _sprite_tiles_displ

       xor  a
       ld   (ds_9200_glbls + 0x05),a              ; 0 ... demo_scrn_txt_indx
       ld   (w_bug_flying_hit_cnt),a              ; 0

       ld   a,#2
       ld   (ds4_game_tmrs + 2),a                 ; 2 (1 sec)
       jr   l_attmode_state_step

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

; 02: info-screen sequencer, advance text and sprite tiles indices
case_1984:
;  if ( 0 == game_tmrs[2] ) ... (2 on the clock from case_1948)
       ld   a,(ds4_game_tmrs + 2)
       and  a
       ret  nz
; then ...
; . game_tmrs[2] = 2; // 1 second
       ld   a,#2
       ld   (ds4_game_tmrs + 2),a                 ; info-screen: 2counts (1 second) between text

; . if (index == 5) then  state++ ; break
       ld   a,(ds_9200_glbls + 0x05)              ; if 5 ... demo_scrn_txt_indx
       cp   #5
       jr   z,l_attmode_state_step
; . else
; .. txt_index++ ; show text
       inc  a
       ld   (ds_9200_glbls + 0x05),a              ; demo_scrn_txt_indx++
       add  a,#0x0D                               ; s_14EE - d_cstring_tbl - 1
       ld   c,a                                   ; C = 0x0D + A ... string index
       rst  0x30                                  ; string_out_pe ("GALAGA", "--SCORE--", etc)

; .. [index >= 3] && sprite_tiles_displ() && break
       ld   a,(ds_9200_glbls + 0x05)              ; [demo_scrn_txt_indx >= 3] ... sprite tile display
       cp   #3
       ret  c
       call c_sprite_tiles_displ                  ; advances pointer to sptiles_3[]

       ret

l_attmode_state_step:
; .demo_idx++
       ld   hl,#ds_9200_glbls + 0x03              ; advance state variable
       inc  (hl)
; if ( .demo_idx == 0x0F )  then demo_idx = 0
       ld   a,(hl)
       cp   #0x0F
       ret  nz
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
       ld   a,(ds_plyr_actv +_b_bmbr_boss_cobj)
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
       ld   a,(ds_plyr_actv +_b_bmbr_boss_cobj)
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
       ld   (ds_cpu0_task_actv + 0x11),a          ; 0: this task
       ld   (b_9AA0 + 0x09),a                     ; 0: sound-fx count/enable registers
       ld   d,#>b_8800
       inc  a
       ld   (de),a                                ; 1: b_8800[n] (stand-by position)
       ld   (ds_plyr_actv +_b_bmbr_boss_cobj),a   ; 1: invalidate the capture boss object (e.g. was $32)
       ld   (ds_99B9_star_ctrl + 0x00),a          ; 1: when fighter on screen
       inc  a
       ld   (ds_9200_glbls + 0x13),a              ; 2: restart-stage flag (fighter captured)
       ret

;;=============================================================================
;; f_1A80()
;;  Description:
;;   "clone-attack" manager.
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
; setup vector argument to c_1083
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
       call c_1083                                ; bomber setup, clone-attack mgr
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
       .dw db_04EA
       .dw db_0473
       .dw db_04AB

;;=============================================================================
;; f_1B65()
;;  Description:
;;   Manage bomber attacks, enabled during demo in fighter-movement phase, as
;;   well as in training mode. Disabled at start of each round until all
;;   enemies are in home position, then enabled for the duration of the round.
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
f_1B65:
; if ( flag == zero ) skip the condition check
       ld   a,(ds_9200_glbls + 0x0B)              ; glbl_enemy_enbl
       and  a
       jr   z,l_1B75

; if ((0 == ds_cpu0_task_actv[0x15]) || (0 != ds_cpu0_task_actv + 0x1D))  return
       ld   a,(ds_cpu0_task_actv + 0x15)          ; f_1F04 (fire button input)
       ld   c,a
       ld   a,(ds_cpu0_task_actv + 0x1D)          ; f_2000 (destroyed capture-boss)
       cpl
       and  c
       ret  z

; check the queue for boss+wing mission ... parameters are queue'd by case boss launcher
l_1B75:
       ld   b,#4
       ld   hl,#bmbr_boss_pool                    ; check 4 groups of 3 bytes
l_1B7A:
       ld   a,(hl)                                ; .b0: valid object index if slot active, otherwise $FF
       inc  a                                     ; 0 if boss_wing_slots[n*4].b0 == $ff
       jr   nz,l_1B8B                             ; if slot active, go launch it
       inc  l
       inc  l
       inc  l
       djnz l_1B7A

       ; insert a 1/4 sec delay before trying next bomber
       ld   a,(ds3_92A0_frame_cts + 0)
       and  #0x0F
       jr   z,l_1BA8
       ret

; launching element of boss+wing mission
; A == bmbr_boss_pool[L].obj_idx + 1
l_1B8B:
       ld   (hl),#0xFF                            ; bmbr_boss_pool[ n * 3 + 0 ] = $ff
       dec  a                                     ; undo increment of boss_wing_slots[n].idx
       ld   d,#>b_8800
       ld   e,a                                   ; e.g. E=$30 (boss)   8834 (boss already has a captured ship)
       res  7,e                                   ; bit-7 was used to indicate negated rotation angle to (ix)0x0C

; stash A ... object/index from boss_wing_slots[n] (with bit-7 possibly set for negating rotation angle)
       ex   af,af'

; if (STAND_BY != obj_status[E].state) return ... disposition resting/inactivez
       ld   a,(de)                                ; 92CA[].b0
       dec  a
       ret  nz                                    ; exit if not available (demo)

; pointer to object data (in cpu-sub1 code space)
       inc  l
       ld   e,(hl)                                ; e.g. 92CA[].b1, lsb of pointer to data
       inc  l
       ld   d,(hl)                                ; e.g. 92CA[].b2, msb of pointer to data

; reload A
       ex   af,af'
       ld   l,a                                   ; byte-0 of boss_wing_slots[n*3] ... object index/offset
       ld   h,#>b_8800                            ; e.g. b_8800[$30]
       call c_1079                                ; DE, HL, and bit-7 of HL for negation of rotation angle if set

       ld   a,#1
       ld   (b_9AA0 + 0x13),a                     ; 1 ... sound-fx count/enable registers, bug dive attack sound
       ret

l_1BA8:
; check each bomber type for ready status i.e. yellow, red, boss
       ld   hl,#b_92C0 + 0x00                     ; 3 bytes, 1 byte for each slot, enumerates selection of red, yellow, or boss
       ld   b,#3
l_1BAD:
       dec  (hl)                                  ; check if this one timed out
       jr   z,l_1BB4                              ; b used below argument to "switch" to select type of alien launched?
       inc  l
       djnz l_1BAD

       ret                                        ; none are ready

l_1BB4:
; if (bugs_flying_nbr >= max_flying_bugs_this_rnd) then ...
       ld   a,(ds_new_stage_parms + 0x04)         ; max_bombers
       ld   c,a

       ld   a,(b_bugs_flying_nbr)
       cp   c
       jr   c,l_1BC0
; maximum nbr of bugs already flying set slot-counter back to 1 since it can't be processed right now
       inc  (hl)
       ret

; else ... launch another bombing excursion
l_1BC0:
; b_92C0_0[n] =  b_92C0_0[n + 4] ... set next timeout for this bomber type
       set  2,l                                   ; offset += 4
       ld   a,(hl)                                ; $92C0[n+4]
       res  2,l
       ld   (hl),a

       ld   a,b                                   ; ... b from loop l_1bad above decremented from 3
       dec  a                                     ; offset for 0 based indexing of "switch"

; switch(A)
       ld   hl,#d_1BD1
       rst  0x08                                  ; HL += 2A
       ld   a,(hl)
       inc  hl
       ld   h,(hl)
       ld   l,a
       jp   (hl)
d_1BD1:
; jp table in order of bomber launch timers
       .dw case_bmbr_yellow
       .dw case_bmbr_red
       .dw case_bmbr_boss

; set bee launch params
case_bmbr_yellow:
       ld   b,#20                                 ; number of yellow aliens
       ld   hl,#b_8800 + 0x08                     ; $08-$2E
       ld   de,#db_flv_atk_yllw

; this section common to both bee and moth launcher, check for next one, skip if already active
l_1BDF:
       ld   a,(ds_plyr_actv +_b_bbee_obj)         ; load bonus-bee parameter
       ld   c,a                                   ; stash A
l_1BE3_while:
; if ( disposition == STAND_BY ) && ...
       ld   a,(hl)                                ; obj_status[L].state
       dec  a
       jr   nz,l_1BEB_next
; ... ( L != bonus_bee_index ) then l_1BF0_found_one
       ld   a,c                                   ; unstash A ... offset_to_bonus_bee
       cp   l
       jr   nz,l_1BF0_found_one
l_1BEB_next:
       inc  l
       inc  l
       djnz l_1BE3_while

       ret

l_1BF0_found_one:
       ld   (b_9AA0 + 0x13),a                     ; from C, !0 ... sound-fx count/enable registers, bug dive attack sound
       call c_1083                                ; bomber setup, red or yellow alien
       ret

; set red moth launch params
case_bmbr_red:
       ld   b,#16                                 ; number of red aliens
       ld   hl,#b_8800 + 0x40                     ; red moths $40-$5E
       ld   de,#db_flv_atk_red
       jr   l_1BDF                                ; common to red and yellow alien

; boss launcher... only enable capture-mode for every other one ( %2 )
case_bmbr_boss:
; if (boss is diving/capturing ) then goto 1C30
       ld   a,(ds_plyr_actv +_b_bmbr_boss_cflag)  ; 1 if capture-mode is active / capture-mode selection suppressed
       and  a
       jr   nz,l_1C30
; if ( plyr.cboss_enable_toggle % 2 ) then goto 1C30
       ld   hl,#ds_plyr_actv +_b_bmbr_boss_wingm  ; toggle bomber boss wingman-enable
       inc  (hl)
       bit  0,(hl)
       jr   nz,l_1C30

; capture-mode select: for each boss, first one that status==standby beomes capture-boss
       ld   ixl,2
       ld   iy,#db_0454
       ld   de,#b_8800 + 0x30                     ; bosses start at $30 ... object/index of bomber to _1CAE
       ld   b,#0x04                               ; there are 4 of these evil creatures

l_1C1B_while:
       ld   a,(de)                                ; sprt_mctl_objs[de].state
       dec  a                                     ; if disposition STAND_BY,  1->0
       jr   z,l_1C24_is_standby
       inc  e                                     ; status bytes, evens ... i.e. 8830, 32, etc.
       inc  e
       djnz l_1C1B_while

       ret

l_1C24_is_standby:
       ld   a,#1
       ld   (ds_plyr_actv +_b_bmbr_boss_cflag),a  ; 1 ... force next bomber-boss to wingman mode (suppress capture-boss select)
       ld   a,e
       ld   (ds_plyr_actv +_b_bmbr_boss_cobj),a   ; object/index of bomber to _1CAE ... bosses start at $30
       jp   j_1CAE                                ; _boss_activate(e, ixl, b, iy) ... C?

; alredy in capture-mode, or capture-mode select is suppressed this time ... look for a wingman
; get red alien index, check if already flagged by plyr_state.clone_attkr_en
l_1C30:
; escort object/IDs order in data right->left so bit will shift out left->right
       ld   hl,#d_1D2C_wingmen
       ld   d,#>b_8800
       ld   bc,#6 * 256 + 0                       ; check 6 objects (B) and clear C
l_1C38_while:
       ld   e,(hl)
       inc  hl
; if "special attacker" skip test object_status STAND_BY
       ld   a,(ds_plyr_actv +_b_bbee_obj)         ; check if wingman is already special-bomber
       cp   e
       jr   z,l_1C44
; test if object_status = STAND_BY
       ld   a,(de)
       dec  a                                     ; one byte opcode ...
       sub  #1                                    ; ... two bytes opcode, but sets Cy if A==0
l_1C44:
       rl   c                                     ; shifts in a bit from Cy if object status was 1 (00 - 01 = FF)
       djnz l_1C38_while

       ld   ixl,#0                                ; flag for 1st and 2nd loop?
       ld   b,#4
       ld   ixh,c                                 ; stash C ... bits set for each boss available in standby state

; first pass: look for 2 adjoining escorts available occuring in 3 adjacent spaces
l_1C4F_while:
       ld   a,c
       and  #0x07
; if (a==3 || a==5 || a==6) ...
       cp   #4                                     ; (a ! 4) ...
       jr   z,l_1C5B
       cp   #3                                     ; && (a>=3)
       ; d == #>b_8800, e don't care
       call nc,c_1C8D                             ; _boss_activate(0xFF, 0, b, 0xFFFF)
l_1C5B:
       rr   c
       djnz l_1C4F_while

; second pass: look for 1 available escort
       inc  ixl                                   ; 1
       ld   c,ixh                                 ; restore previous C
       ld   b,#4

l_1C65_while:
       ld   a,c
       and  #0x07
       call nz,c_1C8D                             ; _boss_activate(0xFF, 1, b, 0xFFFF)
       rr   c
       djnz l_1C65_while

; third pass: take any available boss
       inc  ixl                                   ; 2
       ld   de,#b_8800 + 0x30                     ; boss objects are 30 34 36 32
       ld   b,#4
l_1C76_while:
       ld   a,(de)
       dec  a
       jr   z,j_1CA0                              ; _boss_activate(e, 2, b, 0xFFFF) ... status==STANDBY, skip index selection
       inc  e
       inc  e
       djnz l_1C76_while

; last pass: no boss available ... check for available rogue fighter (objects 00, 02, 04, 06)
       ld   hl,#b_8800
       ld   b,#4
l_1C83_while:
       ld   a,(hl)
       dec  a
       jp   z,l_1D25
       inc  l
       inc  l
       djnz l_1C83_while

       ret

;;=============================================================================
;; bmbr_boss_activate()
;;  Description:
;;   select bomber-boss object/index, select movement control vector
;; IN:
;;  B: 4,3,2,1 to select object/index of bomber
;;  C: flags for escorts available (pass-thru)
;;  D: pre-loaded with msb of pointer to objects array (for convenience as it was just used a few instructions ago)
;;  E: object/index of bomber-boss candidate (from const array) if jp 1CA0 taken
;;  IXL: 0 -> 2 escorts, 1 -> 1 escort (2 is for capture-boss so it doesn't apply)
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_1C8D:
; convert ordinal in B (i.e. 4,3,2,1) to object/index in home-position order (left to right)
; the ordinal (B) will be used later to index d_escort_ids[] which are ordered
; right->left, i.e. ordinal 4 indexes to an ID located leftmost and so on.
;  4 -> 4 -> 0 -> 0
;  3 -> 2 -> 2 -> 4
;  2 -> 3 -> 3 -> 6
;  1 -> 1 -> 1 -> 2
       ld   a,b
       bit  1,a
       jr   z,l_1C94
       xor  #0x01
l_1C94:
       and  #0x03
       sla  a
       add  a,#0x30                               ; boss objects are 30 34 36 32
       ld   e,a                                   ; object/index of bomber to _1CAE
       ld   a,(de)                                ; d == #>b_8800
       cp   #0x01                                 ; check for ready/available status
       ret  nz

       pop  hl                                    ; will return to task manager eventually

j_1CA0:
       ld   iy,#db_flv_0411
       ld   a,(ds_9200_glbls + 0x0B)              ; enemy enable, select data ptr boss launch: if (0), iy=$00F1, else iy=$0411
       and  a
       jr   nz,l_1CAE
       ld   iy,#db_flv_00f1                       ; training-mode

l_1CAE:

;;-----------------------------------------------------------------------------
;; setup bomber-boss, _boss_pool[0], bonus scoring, etc.
;; if capture boss (jp $1CAE), paremeters same as above except:
;; IN:
;;    b, c: not used when escort selection skipped (ixl == 2)
;;    ixl:  2==solo/capture boss is valid and will skip escort selection ...
;;            ... in addition to 0 -> 2 escorts, 1 -> 1 escort
;;-----------------------------------------------------------------------------
j_1CAE:

; objects 32 & 36 are on right side (bit-1 set): set flag in bit-7 to indicate negative rotation
       ld   a,e                                   ; object/index of bomber
       rrca
       rrca                                       ; flag from A<1> into Cy
       ld   a,e
       rla                                        ; Cy into bit-0
       rrca                                       ; flag in Cy and in bit-7
       ld   (bmbr_boss_pool + 0),a                ; object/index of bomber boss
       ex   af,af'                                ; stash Cy for rotation flag
       ld   (bmbr_boss_pool + 1),iy               ; flight vector of bomber boss

       inc  b                                     ; `dec b` in c_1D03

; plyr_actv.bmbr_boss_scode[]
       ld   a,e                                   ; object/index of bomber
       and  #0x07
       ld   hl,#ds_plyr_actv +_ds_bmbr_boss_scode
       rst  0x10                                  ; HL += A
; d_1CFD[ixl]
       ld   a,ixl
       ex   de,hl                                 ; stash hl (&plyr_actv.code)
       ld   hl,#d_1CFD
       rst  0x08                                  ; HL += 2A
       ld   a,(hl)
       ld   (de),a                                ; plyr_actv._bonus_codescore[E] = d_1CFD[2*A]
       inc  hl
       inc  e
       ld   a,(hl)
       ld   (de),a

; if (2 == ixl) then skip launching wingmen ... capture-boss situation
       ld   a,ixl
       cp   #2
       jr   z,l_1CE3

       ld   de,#bmbr_boss_pool + 1 * 3 + 0        ; 4 groups of 3 bytes
; if (1 == ixl) ... setup 1 escort, else setup 2 escorts
       dec  a
       jr   z,l_1CE0
       call c_1D03                                ; DE==&boss_pool[1] ... boss dives with wingman
l_1CE0:
       call c_1D03                                ; DE==&boss_pool[2] ... boss dives with wingman

; if rogue fighter for this boss !STAND_BY then return
l_1CE3:
       ld   a,(bmbr_boss_pool + 0 * 3 + 0)        ; obj/index (setup from function arguments above)
       and  #0x07                                 ; object/index of captured fighter i.e. 00 04 06 02
       ld   l,a
; check for 0
       ld   h,#>b_8800
       ld   a,(hl)
       dec  a
       ret  nz                                    ; return to task manager

       ld   c,l                                   ; object/index of rogue-fighter e.g. $00, $02, $04, $06

; find available slot (don't know how many are occupied by wingmen?)
       ld   hl,#bmbr_boss_pool + 0 * 3 + 0        ; reset pointer, search for obj_idx==$FF
l_1CF2_while:
       inc  l
       inc  l
       inc  l
       ld   a,(hl)
       inc  a
       jr   nz,l_1CF2_while

; setup A and Cy' parameters (HL, IY already loaded)
;  HL == &_boss_pool[n] ... n = { 3, 6, 9 }
;  IY == pointer to flight vector data
       ex   af,af'                                ; unstash rotation flag
       ld   a,c                                   ; object/index of captured ship
       jr   l_1D16                                ; ... jp past setup section of function

;;=============================================================================
;; data for c_1C8D:
;; ixl selects bonus-score to override in ds_plyr_actv._ds_array8[]
;; .b0 ... add to bug_collsn[$0F] (adjusted scoring increment)
;; .b1 -> obj_collsn_notif[L] ... sprite code + 0x80
d_1CFD:
       .db 16 - 3, 0x80 + 0x3A  ; 1600
       .db  8 - 3, 0x80 + 0x37  ; 800
       .db  4 - 3, 0x80 + 0x35  ; 400 (default)

;;=============================================================================
;; c_1D03()
;;  Description:
;;   bmbr_boss_escort_sel
;;   ...boss takes a sortie with one or two wingmen attached.
;; IN:
;;  B
;;  C: flags for escorts available
;;  DE: &_boss_pool[n]
;;  IY: pointer to flight vector data
;;  Cy': rotation flag, to be OR'd into pool_slot[n].idx<7>
;; OUT:
;;  B: index of next escort to be selected from const array
;;  C: flags for escorts available
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

; setup parameters (IY, pointer to flight vector data, already loaded)
       ex   af,af'                                ; unstash rotation flag
       ld   a,(hl)                                ; d_escorts[a] ... object/index
       ex   de,hl                                 ; &boss_wing_slots[n] to HL

;;=============================================================================
;; skipping the setup section (rogue fighter)
;; IN:
;;  A  - object/index of red bomber wingman, captured ship etc.
;;  HL - index to bmbr_boss_pool[]
;;  IY - pointer to flight vector data
;;  Cy - rotation flag
;; OUT:
;;  DE: &_boss_pool[n] ... pointer advanced in case of second call
;;-----------------------------------------------------------------------------
l_1D16:
; load boss_wing_slots[n + 0], rotation flag from Cy to bit-7 of object/index
       rla                                        ; object/index
       rrca                                       ; rotate out of a<0> thru Cy into a<7>
       ld   (hl),a                                ; &boss_wing_slots[n + 0]

; re-stash Cy (rotation flag)
       ex   af,af'

       inc  l
       ld   a,iyl
       ld   (hl),a
       inc  l
       ld   a,iyh
       ld   (hl),a
       inc  l
       ex   de,hl                                 ; &boss_wing_slots[n] ... update pointer in DE for second subroutine call
       ret

;;=============================================================================
;; Movement of captured rogue ship... out of section at l_1C83
;;-----------------------------------------------------------------------------
l_1D25:
       ld   de,#db_fltv_rogefgter
       call c_1083                                ; rogue fighter
       ret

;;=============================================================================
;; 6 escort aliens (right to left under the 4 bosses )
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

; rotate _scrn_tmr<7> into Cy for testing
       rlc  c
       xor  c
       rrca

       ld   a,#1                                  ; offset is +1
       jr   c,l_1D4B
       neg                                        ; offset is -1

l_1D4B:
       ld   c,a
       ld   hl,#ds_hpos_spcoords + (10 * 2)       ; + byte offset to row coordinates

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
; use obj_status[].mctl_q_index for explosion counter (que object should already have been released at l_081E_hdl_flyng_bug
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
       inc  d
       inc  (hl)                                  ; nest_direction = 1
       jr   l_1DFD
l_1DFC_contracting:
       dec  (hl)                                  ; nest_direction = -1

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

       and  #0x07                                 ; previous_cntr % 8

       ld   a,d                                   ; direction counter increment (+1 or -1)
       ld   (ds_9200_glbls + 0x11),a              ; formatn_mv_signage, cpu2 cp with b_9A80 + 0x00

       ld   a,e                                   ; reload previous_nest_direction counter

; if ( previous_counter % 8 == 0 ) then update_bitmap i.e. even multiple of 8
       jr   nz,l_1E23

       ld   hl,#d_1E64_bitmap_tables

; count * 2 i.e. count / 8 * 16 ... index into table row
       ld   a,c                                   ; A = updated_counter
       and  #0x18                                 ; make it even multiple of 8
       rst  0x08                                  ; HL += 2A   .... table entries are $10 bytes long

       ld   a,e                                   ; reload previous_nest_direction counter

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
       ld   de,#ds_hpos_loc_offs                  ; hl==ds10_9920

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
;;   Compute row/col coordinates of formation in expand/contract movement.
;;   The selected bitmap table determines whether any given coordinate
;;   dimension is incremented at this update.
;; IN:
;;    HL == saved pointer into working copy of selected bitmap table ($10 bytes)
;;    DE == saved pointer into home_posn_loc[]
;;        ... object positioning (even: relative offsets .... odd: defaults/origin)
;;    B == +/- 1 increment.
;;    IXL == 5  (repeat count for 5 leftmost columns)
;;    IXL == 11 (repeat count, for 5 rightmost columns + 6 rows which have the same sign)
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
       ld   d,#>ds_hpos_spcoords
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
       ld   d,#>ds_hpos_loc_offs                  ; reset pointer

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
       ld   de,#b_92B0 + 0x00                     ; bomb h-rate array ( 8 * 2 )
       ld   ixl,0x08

l_1EBF_while:
; if sprite[bomb + n].code == $30 ...
       ld   h,#>ds_sprite_code
       ld   a,(hl)
       cp   #0x30                                 ; bomb sprite codes don't show up until some new-game inits are done
       jr   nz,l_1EFF
; ... sprite[bomb + n].posn.x != 0
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

       ex   de,hl                                 ; stash &sprite_posn[n].b0 in DE
       ld   b,(hl)                                ; bomb_rate[n].b0
       ld   a,b
       and  #0x7E                                 ; Bit-7 for negative ... and we don't want the 1 ???
       inc  l
       add  a,(hl)
       ld   c,a                                   ; C = A = A + 92B0[odd] ... accumulated division remainder
       and  #0x1F                                 ; MOD 32
       ld   (hl),a                                ; bomb_rate[n].b1
       inc  l
; a >>= 5 (divide-by-32)
       ld   a,c
       rlca
       rlca
       rlca
       and  #0x07

; use negative offset of X coordinate if bomb path is to the left
       bit  7,b
       jr   z,l_1EE4
       neg

l_1EE4:
       ex   de,hl                                 ; &sprite_posn[n].b0 from DE
; update X
       add  a,(hl)
       ld   (hl),a                                ; 9868[ even ] += A

; update Y, and handle Cy for value > $ff
       inc  l
       ld   a,(hl)
       add  a,ixh
       ld   (hl),a                                ; sprite[n].y<7:0> += ixh

       rra                                        ; shifts CY into bit-7 on overflow from addition
       xor  ixh
       rlca                                       ; Cy xor'd with ixh<7> ... to Cy
       jr   nc,l_1EF9

; update "bit-8" of Y coordinate ... should only overflow the Y coordinate once.
       ld   h,#>ds_sprite_ctrl                    ; sY<8>
       rrc  (hl)                                  ; sY<8> into Cy
       ccf
       rl   (hl)                                  ; sY<8>

l_1EF9:
       inc  l
       dec  ixl
       jr   nz,l_1EBF_while

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
       ld   h,#>ds3_99B5_io_input + 0x00          ; msb
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
; if ( 0 != sprite[ RCKT0 ].sX ) ...
       ld   hl,#ds_sprite_posn + 0x64             ; ROCKET_0
       ld   de,#b_92A0 + 0x04                     ; rockt_attribute[0]
       xor  a
       cp   (hl)                                  ; if (0)
       jr   z,l_1F1E

; ... then ... if ( 0 != sprite[ RCKT1 ].sX )  return
       ld   l,#<ds_sprite_posn + 0x66             ; ROCKET_1
       inc  e                                     ; rockt_attribute[1]
       cp   (hl)                                  ; if (0 != sprite[RCKT1].sX)  ret
       ret  nz

l_1F1E:
; save pointer to attribute, and stash 'offsetof( RCKT_X )' in E

       push de                                    ; &rockt_attribute[n].posn.b0
       ex   de,hl

       ld   hl,#ds_sprite_ctrl + 0x62 + 1         ; sprite.ctrl[FIGHTR].b1
       ld   d,h
       inc  e                                     ; sprite[RCKT_X].ctrl.b1

       bit  2,(hl)                                ; sprite.ctrl[FIGHTR].b1<2> ... ?
       jr   z,l_1F2B

       pop  de
       ret


l_1F2B:
; sprite.ctrl[RCKT+n].b1 = sprite.ctrl[SHIP].b1 ... ship.sY, bit-8
       ldd                                        ; e.g. *(9B65--) = *(9B63--)

       ld   h,#>ds_sprite_posn
       ld   d,h                                   ; stash it
; sprite.posn[RCKT+n].b0 = sprite.posn[SPR_IDX_SHIP].b0  ... ship.sX
       ldi                                        ; e.g. *(9B64++) = *(9B62++)
; sprite.posn[RCKT+n].b1 = sprite.posn[SPR_IDX_SHIP].b1  ... ship.sY, bit 0-7
       ldd                                        ; e.g. *(9B65--) = *(9B63--)


; B = sprite.ctrl[SHIP].b0
       ld   h,#>ds_sprite_ctrl
       ld   d,h
       ld   b,(hl)                                ; sprite.ctrl[FGHTR].b0: normally 0 (not doubled or flipped)
                                                  ; stash in B ... see l_1F5E below
       ex   de,hl                                 ; HL := sprite.ctrl[RCKT].b0

; sprite.ctrl[RCKT].b0.dblw = (two_ship << 3 )
       ld   a,(ds_plyr_actv +_b_2ship)
       and  #0x01                                 ; make sure its only bit-0 I guess ?
       rlca
       rlca
       rlca                                       ; in bit3 now fpr dblw attribute

; sprite.ctrl[SHIP].b0 ... typically 0, unless ship is spinning
       or   b                                     ; .ctrl[RCKT].b0 |= .ctrl[SHIP].b0
       ld   (hl),a

; determine rocket sprite code based on ship sprite code, which ranges from 6 (upright orientation)
; down to the 90 degree rotation. Rocket code can be 30, 31, or 33 (360, 315, or 90 degree).
; rocket sprite 32 is also 360 or 0 degree but not used ? (unless its the 2nd rocket, which is done by sprite doubling).
       ld   d,#>ds_sprite_code
       ld   a,(de)
       ld   h,d
       and  #0x07                                 ; fighter sprite codes are $00...$07

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

; if ( A >= 4 ) ...
       cp   #4                                    ; A == sprite.cclr[SHIP].b0;
       jr   c,l_1F5E

; ... dS = 7 - ( code + 1 ) + 0x40
       cpl
       add  a,#0x40 + 7
; else ... no orientation swap needed, use sprite code for dS

l_1F5E:
       sla  a                                     ; "orientation" bit into bit-7 ...
       ld   c,a                                   ; ... and displacement << 1  into bits 1:2

; sprite.ctrl bits ...  flipx into bit:5, flipy into bit:6
       ld   a,b                                   ; sprite.ctrl[SHIP].b0
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

       ld   h,#>b_8800                            ; disposition = 6 ... active rocket object
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
       add  a,#<ds3_99B5_io_input + 0x01          ; LSB
       ld   l,a
       ld   h,#>ds3_99B5_io_input + 0x00          ; MSB
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

; if ( input.Right ) ...
       bit  1,b                                   ; if ( ! input bits.right ) ... inverted
       jr   nz,l_1FC7_test_llmt

; if ( ship.posn.x > 0xD1) ... moving right: check right limit for double-ship
       ld   a,(hl)
       cp   #0xD1                                 ; right limit, double-ship
       jr   c,l_1FC0_test_rlmt_single
; else if ( double_ship ) return
       bit  0,e                                   ; if ( is_double_ship & 0x01 )
       ret  nz                                    ; at right limit of double-ship

l_1FC0_test_rlmt_single:
; if ( ship.posn.x >= 0xE1 ) return
       cp   #0xE1                                 ; right limit, single-ship
       ret  nc
; add dX for right direction
       add  a,c                                   ; fighter dX
       ld   (hl),a
       jr   l_1FD4_update_two_ship

; ... else ... test left limit
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
