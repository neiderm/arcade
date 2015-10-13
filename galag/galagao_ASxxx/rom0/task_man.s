;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; task_man.s
;;  gg1-1.3p 'maincpu' (Z80)
;;
;;  The "task manager" is triggered by the v-blank interrupt (RST 38)
;;  thus the base execution rate is 60Hz. Some tasks will implement
;;  their own sub-rates (e.g. 1 Hz, 4 Hz etc) by checking a global timer.
;;
;;  ds_cpu0_task_actv ($20 bytes) is indexed by order of the
;;  function pointers in d_cpu0_task_table. Periodic tasks can be prioritized,
;;  enabled and disabled by changing the appropriate index in the table.
;;  The task enable table is accessed globally allowing one task to enable or
;;  disable another task. At startup, actv_task_tbl ($20 bytes) is loaded with
;;  a default configuration from ROM.
;;
;;  In ds_cpu0_task_actv the following values are used:
;;   $00 - will skip first entry ($0873) but continue with second
;;   $01
;;   $1f - execute first then skip to last? (but it sets to $00 again?)
;;   $20 - will execute $0873 (empty task) then immediately exit scheduler
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.module task_man

.include "sfrs.inc"
.include "structs.inc"
.include "task_man.dep"

;           00000096  _l_0096                            int0
;.area ROM (ABS,OVR)
;       .org 0x0096
.area CSEG00


;;=============================================================================
;; d_cpu0_task_table
;;  Description:
;;   Function pointers to periodic tasks (dispatch table for scheduler)
;;   void (* const d_cpu0_task_table[32])(void)
;;-----------------------------------------------------------------------------
d_cpu0_task_table:
  .dw f_0827
  .dw f_0828
  .dw f_17B2
  .dw f_1700
  .dw f_1A80
  .dw f_0857
  .dw f_0827
  .dw f_0827

  .dw f_2916
  .dw f_1DE6
  .dw f_2A90
  .dw f_1DB3
  .dw f_23DD
  .dw f_1EA4
  .dw f_1D32
  .dw f_0935

  .dw f_1B65
  .dw f_19B2
  .dw f_1D76
  .dw f_0827
  .dw f_1F85
  .dw f_1F04
  .dw f_0827
  .dw f_1DD2

  .dw f_2222
  .dw f_21CB
  .dw f_0827
  .dw f_0827
  .dw f_20F2
  .dw f_2000
  .dw f_0827
  .dw f_0977

;;=============================================================================
;; c_textout_1uphighscore_onetime()
;;  Description:
;;   display score text top of screen (1 time only after boot)
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_textout_1uphighscore_onetime:
       ld   de,#m_tile_ram + 0x03E0 + 0x0D
       ld   hl,#d_str20000                        ; source of string "20000" (stored backwards)
       ld   bc,#0x0005                            ; strlen
       ldir
       ld   e,#<<0x03C0 + 0x0B                    ; $83CB
       ld   hl,#d_TxtScore                        ; source of string "1UP    HIGH SCORE"
       ld   c,#0x11                               ; strlen
       ldir
       ret

;;=============================================================================
; string "1UP    HIGH SCORE"  (reversed)
d_TxtScore:
       .db 0x0E,0x1B,0x18,0x0C,0x1C,0x24,0x11,0x10,0x12,0x11,0x24,0x24,0x24,0x24,0x19,0x1E,0x01


;;=============================================================================

       .ds 0x04                                   ; pad

;;=============================================================================
;; Home positions of objects in the cylon fleet. Replicated in gg1-5.s
;; Refer to diagram:
;;
;; object[] {
;;  location.row    ...index to row pixel LUTs
;;  location.column ...index to col pixel LUTs
;; }
;;                  00 02 04 06 08 0A 0C 0E 10 12
;;
;;     14                    00 04 06 02            ; captured vipers
;;     16                    30 34 36 32            ; base stars
;;     18              40 48 50 58 5A 52 4A 42      ; raiders
;;     1A              44 4C 54 5C 5E 56 4E 46
;;     1C           08 10 18 20 28 2A 22 1A 12 0A
;;     1E           0C 14 1C 24 2C 2E 26 1E 16 0E
;;
;;  organization of row and column pixel position LUTs (fmtn_hpos):
;;
;;      |<-------------- COLUMNS --------------------->|<---------- ROWS ---------->|
;;
;;      00   02   04   06   08   0A   0C   0E   10   12   14   16   18   1A   1C   1E
;;
;;-----------------------------------------------------------------------------
db_obj_home_posn_rc:
  .db 0x14,0x06,0x14,0x0C,0x14,0x08,0x14,0x0A,0x1C,0x00,0x1C,0x12,0x1E,0x00,0x1E,0x12
  .db 0x1C,0x02,0x1C,0x10,0x1E,0x02,0x1E,0x10,0x1C,0x04,0x1C,0x0E,0x1E,0x04,0x1E,0x0E
  .db 0x1C,0x06,0x1C,0x0C,0x1E,0x06,0x1E,0x0C,0x1C,0x08,0x1C,0x0A,0x1E,0x08,0x1E,0x0A
  .db 0x16,0x06,0x16,0x0C,0x16,0x08,0x16,0x0A,0x18,0x00,0x18,0x12,0x1A,0x00,0x1A,0x12
  .db 0x18,0x02,0x18,0x10,0x1A,0x02,0x1A,0x10,0x18,0x04,0x18,0x0E,0x1A,0x04,0x1A,0x0E
  .db 0x18,0x06,0x18,0x0C,0x1A,0x06,0x1A,0x0C,0x18,0x08,0x18,0x0A,0x1A,0x08,0x1A,0x0A


;;=============================================================================
;; c_sctrl_playfld_clr()
;;  Description:
;;    clears playfield tileram (not the score and credit texts at top & bottom).
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_sctrl_playfld_clr:
       ld   hl,#m_tile_ram + 0x0040
       ld   de,#m_tile_ram + 0x0041
       ld   bc,#0x037F
       ld   (hl),#0x24                            ; clear Tile RAM with $24 (space)
       ldir
       ld   hl,#m_color_ram + 0x0040              ; clear Color RAM with $00
       ld   de,#m_color_ram + 0x0041
       ld   bc,#0x037F
       ld   (hl),#0
       ldir

; HL==87bf
; Set the color (red) of the topmost row: let the pointer in HL wrap
; around to the top row fom where it left off from the loop above.
       ld   a,#0x04
       ld   b,#0x20
       rst  0x18                                  ; memset((HL), A=fill, B=ct)

; HL==87df
; Set color of 2nd row from top, again retaining pointer value from.
; previous loop. Why $4E? I don't know but it ends up white.
       ld   a,#0x4E
       ld   b,#0x20
       rst  0x18                                  ; memset((HL), A=fill, B=ct)

       ret
; end

;;=============================================================================
;; stg_splash_scrn()
;;  Description:
;;   clears a stage (on two-player game, runs at the first turn of each player)
;;   Increments stage_ctr (and dedicated challenge stage %4 indicator)
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
stg_init_splash:

; plyr_state_active.stage_ctr++
       ld   hl,#ds_plyr_actv +_b_stgctr           ; ++
       inc  (hl)

; plyr_state_active.not_chllng_stg = *HL & 0x03  ... gives 0 for challenge stage
       ld   a,(hl)
       inc  a
       and  #0x03
       ld   (ds_plyr_actv +_b_not_chllg_stg),a    ; ==(stg_ctr+1)%4 ...i.e. 0 if challenge stage

;  if ( 0 != plyr_state_active.not_chllng_stg ) ...
       jr   z,l_01A2_set_challeng_stg
; then {
       ld   c,#0x06                               ; C=string_out_pe_index
       rst  0x30                                  ; string_out_pe "STAGE "
; HL == $81B0 ... "X" of STAGE X.
       ex   de,hl                                 ; DE now 81B0 (points to X in "STAGE X")
       ld   a,(ds_plyr_actv +_b_stgctr)           ; show score
       ld   l,a
       ld   h,#0
       call c_text_out_i_to_d                     ; Print "X" of STAGE X.
       xor  a                                     ; 0 ... start value for wave_bonus_ctr (irrelevant if !challenge)
       jr   l_01AC
; } else {
l_01A2_set_challeng_stg:
       ld   c,#0x07                               ; C=string_out_pe_index
       rst  0x30                                  ; string_out_pe "CHALLENGING STAGE"
       ld   a,#1
       ld   (b_9AA0 + 0x0D),a                     ; 1 ... sound-fx count/enable registers, start challenge stage
       ld   a,#8                                  ; start value for wave_bonus_ctr (decremented by cpu-b when bug destroyed)
; }

l_01AC:
       ld   (w_bug_flying_hit_cnt),a              ; 8 for challenge stage (else 0 i.e. don't care)

; set the timer to synchronize finish of c_new_level_tokens
       ld   a,#3
       ld   (ds4_game_tmrs + 2),a                 ; 3

       ld   (ds_9200_glbls + 0x0B),a              ; 3: enemy_enable, begin round, needs to be !0 (use 3 for optimization)

; if ( 0 != plyr_actv.b_not_chllg_stg ) Cy' = 0 ... set Cy to inhibit sound clicks for level tokens at challenge stage (1211)
       ld   a,(ds_plyr_actv +_b_not_chllg_stg)    ; parameter to sound manager passed through to c_build_token_1
       and  a                                     ; clear Cy if A != 0
       ex   af,af'
       call c_new_level_tokens                    ; A' == 0 if challenge stg, else non-zero (stage_ct + 1)

; while ( game_tmrs[2] ){}
l_01BF:
       ld   a,(ds4_game_tmrs + 2)
       and  a
       jr   nz,l_01BF

; _init_env();

;;=============================================================================
;; stg_init_env()
;;  Description:
;;   Initialize new stage environment and handle rack-advance if enabled.
;;   This section is broken out so that splash screen can be skipped in demo.
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
stg_init_env:
       ld   a,#120
       ld   (ds4_game_tmrs + 2),a                 ; load the timer ($78 - new stage)
       call c_2896                                ; Initializes each creature by position
       call c_25A2                                ; mob setup

; set game_tmrs[0] (attack formation timing)
       ld   a,#2
       ld   (ds4_game_tmrs + 0),a                 ; 2

       xor  a
       call c_12C3                                ; A == 0 .... set MOB coordinates, new stage

; initialize array (even-bytes)
       xor  a
       ld   b,#0x30
       ld   hl,#b_9200_obj_collsn_notif           ; 00-5F, even-bytes = 0
l_01DF:
       ld   (hl),a
       inc  l
       inc  l
       djnz l_01DF

       ld   (ds_cpu0_task_actv + 0x09),a          ; 0  (f_1DE6 ... collective bug movement)
       ld   (ds_cpu0_task_actv + 0x10),a          ; 0  (f_1B65 ... manage bomber attack )
       ld   (ds_cpu0_task_actv + 0x04),a          ; 0  (f_1A80 ... bonus-bee manager)

       ld   (b_bug_flyng_hits_p_round),a          ; 0

       ld   (ds_plyr_actv +_b_bmbr_boss_wingm),a  ; 0: bomber boss wingman-enable will toggle to 1 on first boss-bomber launch
       ld   (ds_plyr_actv +_b_bbee_tmr),a         ; 0: bonus bee launch timer
       ld   (ds_plyr_actv +_b_atk_wv_enbl),a      ; 0: attack_wave_enable
       ld   (ds_plyr_actv +_b_attkwv_ctr),a       ; 0: atack_wave_ctr

       ld   (b8_99B0_X3attackcfg_ct),a            ; 0
       ld   (ds_plyr_actv +_b_nestlr_inh),a       ; 0: nest_lr_flag
       inc  a
       ld   (ds_plyr_actv +_b_bbee_obj),a         ; 1: bonus_bee_obj_offs
       ld   (ds_plyr_susp +_b_bbee_obj),a         ; 1
       ld   (ds_plyr_actv +_b_bmbr_boss_cobj),a   ; 1: invalidate the capture boss object

       ld   (ds_cpu0_task_actv + 0x0B),a          ; 1: f_1DB3 ... Update enemy status.
       ld   (ds_cpu0_task_actv + 0x08),a          ; 1: f_2916 ... Launches the attack formations
       ld   (ds_cpu0_task_actv + 0x0A),a          ; 1: f_2A90 ... left/right movement of collective while attack waves coming
       call c_2C00                                ; new stage setup

       ld   hl,#ds_plyr_actv +_ds_bmbr_boss_scode ; set 8 bytes "01B501B501B501B5"
       ld   de,#0x0100 + 0x80 + 0x35              ; 400 sprite (d = $04 - $03)
       ld   b,#4
l_0220:
       ld   (hl),d
       inc  l
       ld   (hl),e
       inc  l
       djnz l_0220

;  if ( !RackAdvance ) return (active low)
       ld   a,(_sfr_dsw6)                         ; DSWA rack advance operation
       bit  1,a
       ret  nz                                    ; _plyr_startup
;  else handle rack advance operation
       ld   c,#0x0B
       ld   hl,#m_tile_ram + 0x03A0 + 0x10
       call c_string_out                          ; erase "stage X" text"

       jp   stg_init_splash                       ; start over again


;;=============================================================================
;; jp_Task_man()
;;  Description:
;;   handler for rst $38
;;   Updates star control registers.
;;   Executes the Scheduler.
;;   Sets IO chip for control input.
;;   The task enable table is composed of 1-byte entries corresponding to each
;;   of $20 tasks. Each cycle starts at task[0] and advances an index for each
;;   entry in the table. The increment value is actually obtained from the
;;   task_enable table entry itself, which is normally 1, but other values are
;;   also used, such as $20. The "while" logic exits at >$20, so this is used
;;   to exit the task loop without iterating through all $20 entries. Tthe
;;   possible enable values are:
;;     $00 - disables task
;;     $01 - enables task_man
;;     $0A -
;;     $1F -   1F + 0A = $29     (where else could $0A be used?)
;;     $20 - exit current task man step after the currently executed task.
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
jp_Task_man:
       push af
       ex   af,af'
       push af
       push bc
       push de
       push hl
       push ix
       push iy

; determine star_ctrl param bits based on some modulus of frame timer?
; $A000-$A005 starfield scroll speed (only bit 0 is significant)
       ld   a,(_sfr_dsw5)                         ; DSWA: freeze video
       ld   d,a
       ld   a,(ds3_92A0_frame_cts + 0)
       and  #0x1C                                 ; 0000XXX0
       ld   c,a
       rrca                                       ; 00000XXX
       xor  c                                     ; A ^ C
       and  #0x18                                 ; 000XX000
       ld   c,a

;  if ( ! freezed_dsw set )
       ld   a,(ds_99B9_star_ctrl + 0x05)
       bit  1,d                                   ; freeze_ctrl_dsw
       jr   nz,l_0259
;  else
       ld   a,#7                                  ; 7==star_ctrl_bits=freezed

l_0259:
       and  #0x07
       or   c

       ld   b,#5
       ld   hl,#0xA000                            ; star_ctrl_port

l_0261:
       ld   (hl),a                                ; A==star_ctrl_bits
       inc  l
       rrca                                       ; star_ctrl_bits >>= 1
       djnz l_0261

       ld   (_sfr_watchdog),a

       xor  a
       ld   (_sfr_6820),a                         ; 0 ... disable IRQ1

;  if ( freezed )  exit
       bit  1,d
       jp   z,l_02A8_pop_regs_and_exit

;
; Execute the Scheduler
;
       ld   c,a                                   ; A == 0 ... initialize index into Task Enable Table

l_while_index:
l_while_zero:
; while ( 0 == A = *(task_activ_tbl + C) )  C++   ... loop until non-zero: assumes we will find a valid entry in the table!
       ld   hl,#ds_cpu0_task_actv
       ld   a,c
       add  a,l
       ld   l,a
       ld   a,(hl)                                ; task_activ_tbl[index]
       and  a
       jr   nz,l_0280_nonzero_tbl_entry
       inc  c
       jr   l_while_zero

l_0280_nonzero_tbl_entry:
; save the table entry for later...
       ld   b,a                                   ; *(task_activ_tbl + C)
; multiply index 'C' by 2 to form a 16-bit function pointer
; p_taskfn = d_cpu0_task_table[C]
       ld   hl,#d_cpu0_task_table
       ld   a,c                                   ; index
       sla  a                                     ; <<=2 ... sizeof 16-bit function pointer
       add  a,l
       ld   l,a
       ld   e,(hl)                                ; lo-byte of pointer
       inc  hl
       ld   d,(hl)                                ; hi-byte of pointer
       ex   de,hl                                 ; jp address in HL

       push bc
       call c_task_switcher                       ; p_taskfn()
       pop  bc

;    index+=task_activ_tbl[index]
       ld   a,b                                   ; *(task_activ_tbl + C)
       add  a,c                                   ; +=index
       ld   c,a

; while (index < $20)
       and  #0xE0                                 ; control values are $00, $01, $20, $1f
       jr   z,l_while_index

; setup regs for input from IO chip
       ld   hl,#0x7000                            ; IO data xfer (read)
       ld   de,#ds3_99B5_io_input + 0x00          ; read 3 bytes
       ld   bc,#0x0003
       exx

; send command to IO chip
       ld   a,#0x71                               ; cmd==read ctrl inputs
       ld   (0x7100),a                            ; IO cmd ($71 -> enable NMI to trigger when data is available)

l_02A8_pop_regs_and_exit:
       ld   a,#1
       ld   (_sfr_6820),a                         ; 1 ... enable IRQ1

       pop  iy
       pop  ix
       pop  hl
       pop  de
       pop  bc
       pop  af
       ex   af,af'
       pop  af
       ei
       ret
; } end 'rst  $0038' handler

;;=============================================================================
d_str20000:
      .db 0x00,0x00,0x00,0x00,0x02,0x24  ;; "20000" (reversed)
d_strScore:
      .db 0x17,0x0A,0x16,0x0C,0x18       ;; "SCORE" (reversed)

;;=============================================================================
;; RESET()
;;  Description:
;;   jp here from z80 reset vector
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
CPU0_RESET:
; set interrupt mode
       im   1

; memset(mchn_data,0,$10)
       xor  a
       ld   hl,#ds10_99E0_mchn_data               ; clear $10 bytes
       ld   b,#0x10
l_02CC:
       ld   (hl),a
       inc  hl
       djnz l_02CC

; let the fun begin!
       jp   jp_RAM_test


_l_02D3:
;           000002D3  j_Game_init                        game_ctrl

;;
