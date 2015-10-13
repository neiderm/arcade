;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; game_ctrl.s:
;;  gg1-1.3p 'maincpu' (Z80)
;;
;;  Manage high-level game control.
;;
;;  j_Game_init:
;;      One time entry from power-up routines.
;;  g_main:
;;      Initializes game state. Starts with Title Screen, or "Press Start"
;;      screen if credit available.
;;  plyr_respawn_splsh:
;;      Sets up each new stage.
;;  jp_045E_While_Game_Run:
;;      Continous loop once the game is started, until gameover.
;;
;;  The possible modes of operation are (from the Bally Manual):
;;    ATTRACT, READY-TO-PLAY, PLAY, HIGH SCORE INITIAL, and SELF-TEST."
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.module game_ctrl

.include "sfrs.inc"
.include "structs.inc"
.include "game_ctrl.dep"

;.area ROM (ABS,OVR)
;      .org 0x02D3
.area CSEG00


;;=============================================================================
;; por_inits()
;;  Description:
;;   Once per poweron/reset (following hardware inits) do inits for screen and
;;   etc. prior to invoking "main".
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
j_Game_init:
       ld   sp,#ds_stk_cpu0_init

;  memset(ds4_game_tmrs,0,4)
       xor  a
       ld   hl,#ds4_game_tmrs + 0                 ; memset(...,0,4)
       ld   b,#4
       rst  0x18                                  ; memset((HL), A=fill, B=ct)

;  memset($9aa0,0,$20)
       ld   hl,#ds_9AA0                           ; memset(...,0,$20) ... count/enable registers for sound effects
       ld   b,#0x20
       rst  0x18                                  ; memset((HL), A=fill, B=ct)

       ld   (0xA007),a                            ; 0 (not_flipped)
       ld   (b_9215_flip_screen),a                ; 0 (not_flipped)
       ld   (ds_99B9_star_ctrl + 0),a             ; 0 ...1 when ship on screen

; memset($92ca,$ff,$10) ... bmbr_boss_slots[] is only 12 bytes, so this initialization would
; include b_CPU1_in_progress + b_CPU2_in_progress + 2 unused bytes
       dec  a                                     ; = $FF
       ld   hl,#bmbr_boss_pool                    ; memset( ... , $FF, $10 )
       ld   b,#0x10
       rst  0x18                                  ; memset((HL), A=fill, B=ct)

; galaga_interrupt_enable_1_w  seems to already be set, but we make sure anyway.
       ld   a,#1
       ld   (_sfr_6820),a                         ; 1 ,,,enable IRQ1

; The test grid is now cleared from screen. Due to odd organization of tile ram
; it is done in 3 steps. 1 grid row is cleared from top and bottom (each grid
; row is 2 tile rows). Then, there is a utility function to clear the actual
; playfield area.

;  memset($83c0,$24,$40)
       ld   hl,#m_tile_ram + 0x03C0               ; clear top 2 tile rows ($40 bytes)
       ld   b,#0x40
       ld   a,#0x24                               ; "space" character
       rst  0x18                                  ; memset((HL), A=fill, B=ct)

;  memset($8000,$24,$40)
       ld   h,#>m_tile_ram                        ; clear bottom 2 tile rows ($40 bytes)
       ld   b,#0x40
       rst  0x18                                  ; memset((HL), A=fill, B=ct)

;  memset($8400,$03,$40)
       ld   hl,#m_color_ram                       ; $40 bytes (code 03)
       ld   b,#0x40
       ld   a,#0x03
       rst  0x18                                  ; memset((HL), A=fill, B=ct)

       call c_sctrl_playfld_clr                   ; clear remainder of grid pattern from the playfield tiles (14x16)
; all tile ram is now wiped

; Sets up "Heroes" screen
       ld   de,#b_best5_score                     ; 1st score (100000's)
       ld   a,#5
       ld   b,#0
l_0317:
       ld   hl,#d_str20000                        ; "00002 " (20000 reversed)
       ld   c,#0x06
       ldir
       dec  a
       jr   nz,l_0317

       ld   hl,#d_strScore                        ; "SCORE" (reversed)
       ld   a,#0x2A                               ; period character '.'
       ld   b,#0x05
       ld   c,#0xFF
; de==8a3e
l_032A:
       ldi
       dec  hl
       ld   (de),a
       inc  e
       ldi
       djnz l_032A

; initialize game state
       ld   a,#0x01
       ld   (b8_9201_game_state),a                ; 1 == ATTRACT_MODE

       ld   hl,#0xA005                            ; star_ctrl_port_bit6 -> 0, then 1
       ld   (hl),#0
       ld   (hl),a

       call c_sctrl_sprite_ram_clr

; display 1UP HIGH SCORE 20000 (1 time only after boot)
       call c_textout_1uphighscore_onetime

       call c_1230_init_taskman_structs

; data structures for 12 objects
       rst  0x28                                  ; memset(mctl_mpool,0,$$14 * 12)

; Not sure here...
; this would have the effect of disabling/skipping the task at 0x1F (f_0977)
; which happens to relate to updating the credit count (although, there is no
; RST 38 to actually trigger the task from now until setting this to 0 below.)

; cpu0_task_activ[0x1E] = 0x20
       ld   a,#0x20
       ld   (ds_cpu0_task_actv + 0x1E),a          ; $20

; credit_cnt = io_input[0]
       ld   a,(ds3_99B5_io_input + 0x00)          ; credit_count
       ld   (b8_99B8_credit_cnt),a                ; credit_cnt = io_input[credit_count]

; cpu0_task_activ[0x1E] = 0
       xor  a
       ld   (ds_cpu0_task_actv + 0x1E),a          ; 0 ... just wrote $20 here see above
       ld   (ds_cpu1_task_actv + 0x00),a          ; 0 ... CPU1:f_05BE (empty task)


;;=============================================================================
;; g_main()
;;  Description:
;;    Performs initialization, and does a one-time check for credits
;;    (monitoring credit count and updating "GameState" is otherwise handled
;;    by a 16mS task). If credits available at startup, it updates "GameState"
;;    and skips directly to "Ready" state, otherwise it
;;    stays in Attract mode state.
;;
;;    Resumes here following completion of a game.
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
g_main:
       xor  a
       ld   (0xA007),a                            ; 0 (not_flipped)
       ld   (b_9215_flip_screen),a                ; 0 (not_flipped)

; disable f_1D76 - star control ... why? ... should be taken care of by init_taskman_structs ...below
; task_activ_tbl[0x12] = 0
       ld   (ds_cpu0_task_actv + 0x12),a          ; 0 ... f_1D76

; The object-collision notification structures are cleared
; at every beginning of round (and demo), so I am guessing the intent here is to
; clear the globals that share the $80 byte block

; memset($9200,0,$80) ... object-collision notification  and other
       ld   b,#0x80
       ld   hl,#ds_9200                           ; memset(...,0,$80)
       rst  0x18                                  ; memset((HL), A=fill, B=ct)

; star_ctrl_param=6
       ld   a,#6
       ld   (ds_99B9_star_ctrl + 0x05),a          ; 6

; array of object movement structures etc.
       rst  0x28                                  ; memset(mctl_mpool,0,$$14 * 12)
       call c_sctrl_sprite_ram_clr                ; clear sprite mem etc.
       call c_1230_init_taskman_structs

; allow attract-mode festivities to be skipped if credit available
; if ( credit_cnt == 0 )  game_state = ATTRACT_MODE
       ld   a,(b8_99B8_credit_cnt)
       and  a
       ld   a,#1                                  ; 1 == ATTRACT_MODE
       jr   z,l_0380
; else  game_state = READY_TO_PLAY_MODE
       ld   a,#2                                  ; 2 == READY_TO_PLAY_MODE
l_0380:
       ld   (b8_9201_game_state),a                ; = (credit_cnt==0 ? ATTRACT : READY) ... (m/c start, game_state init)

; if ( credit_cnt == 0 ) ...
       jr   nz,l_game_state_ready

; ... do attract mode stuff
       xor  a
       ld   (ds_9200_glbls + 0x03),a              ; demo_idx = 0

; task_activ_tbl[F_ATTRMODECTRL] = 1
       inc  a
       ld   (ds_cpu0_task_actv + 0x02),a         ; 1 ... f_17B2 (attract-mode control)

; while (game_state == ATTRACT_MODE) { ; }
l_038D_while:
       ld   a,(b8_9201_game_state)                ; while (ATTRACT_MODE)
       dec  a
       jr   z,l_038D_while

; GameState == Ready ... reinitialize everthing
       call c_1230_init_taskman_structs
       call c_sctrl_playfld_clr
       rst  0x28                                  ; memset(mctl_mpool,0,$$14 * 12)
       call c_sctrl_sprite_ram_clr

; game_state == READY

l_game_state_ready:
       xor  a
       ld   (ds_9200_glbls + 0x0B),a              ; 0 ... glbl_enemy_enbl: cleared in case demo was running
       ld   c,#0x13                               ; C = string_out_pe_index
       rst  0x30                                  ; string_out_pe "(c) 1981 NAMCO LTD"
       ld   c,#1                                  ; C = string_out_pe_index
       rst  0x30                                  ; string_out_pe "PUSH START BUTTON"

       ld   hl,#d_attrmode_sptiles_ships
       ld   (p_attrmode_sptiles),hl             ; &_attrmode_sptiles[0] ... parameter to _sprite_tiles_displ()

; if ( 0xFF == mchn_cfg_bonus[0] ) goto l_While_Ready
       ld   a,(w_mchn_cfg_bonus + 0)
       cp   #0xFF
       jr   z,j_0003D8_wrdy

       ld   e,a                                   ; E=bonus score digit
       ld   c,#0x1B                               ; C=string_out_pe_index
       call c_game_bonus_info_show_line

; if ( 0xFF == mchn_cfg_bonus[1] ) goto l_While_Ready
       ld   a,(w_mchn_cfg_bonus + 1)
       cp   #0xFF
       jr   z,j_0003D8_wrdy

       and  #0x7F
       ld   e,a                                   ; E=bonus score digit
       ld   c,#0x1C                               ; C=string_out_pe_index
       call c_game_bonus_info_show_line           ; bugs from demo mode have disappeared!

; if bit 7 is set, the third bonus award does not apply
       ld   a,(w_mchn_cfg_bonus + 1)
       bit  7,a
       jr   nz,j_0003D8_wrdy
       and  #0x7F
       ld   e,a                                   ; E=bonus score digit
       ld   c,#0x1D                               ; C=string_out_pe_index
       call c_game_bonus_info_show_line

; while (game_state == READY_TO_PLAY_MODE)
j_0003D8_wrdy:
l_0003D8:
       ld   a,(b8_9201_game_state)                ; while (READY)
       cp   #2                                    ; READY_TO_PLAY_MODE
       jr   z,l_0003D8

; /****  start button was hit ******************/

       ld   (b_9AA0 + 0x17),a                     ; sound_mgr_reset: non-zero causes re-initialization of sound mgr process

; clear sprite mem etc.
       call c_sctrl_playfld_clr
       call c_sctrl_sprite_ram_clr

; stars paused
       ld   hl,#0xA005                            ; star_ctrl_port_bit6 -> 0, then 1
       ld   (hl),#0
       ld   (hl),#1

; Not sure about the intent of clearing $A0 bytes.. player data and resv data are only $80 bytes.
; The structure at 98B0 is $30 bytes so it would not all be cleared (only $10 bytes)
;  memset( player_data, 0, $a0 )
       ld   hl,#ds_plyr_data                      ; memset( ..., 0, $a0 )
       xor  a
       ld   b,#0xA0
       rst  0x18                                  ; memset((HL), A=fill, B=ct)

;ld hl, ds_plyr_actv +_b_stgctr   ; HELP_ME_DEBUG
;ld (hl), #6

       ld   (b_9AA0 + 0x17),a                     ; 0 ... do not reset sound mgr process?

       ld   (ds_99B9_star_ctrl + 0x00),a          ; 0 ... star ctrl stop (1 when ship on screen)

       inc  a
       ld   (b_9AA0 + 0x0B),a                     ; 1 ... sound-fx count/enable registers, start of game theme

       ld   (ds_cpu0_task_actv + 0x12),a          ; 1 ... f_1D76, star ctrl
       ld   (ds_cpu0_task_resrv + 0x12),a         ; 1 ... f_1D76, star ctrl

; do one-time inits
       call gctl_game_init                        ; setup number of lives and show player score(s) '00'
       call c_game_or_demo_init

       ld   c,#4                                  ; C=string_out_pe_index
       rst  0x30                                  ; string_out_pe "PLAYER 1" (always starts with P1 no matter what!)

; busy loop -leaves "Player 1" text showing while some of the opening theme music plays out
; game_tmr_3 = 8;
       ld   hl,#ds4_game_tmrs + 3                 ; = 8 ... while ! 0
       ld   (hl),#8
l_0414_while_tmr_3:
       ld   a,(hl)
       and  a
       jr   nz,l_0414_while_tmr_3

; memset($9290,$10,0)
       ld   hl,#ds_bug_collsn_hit_mult            ; memset(...,$10,0)
       ld   b,#0x10
       rst  0x18                                  ; memset((HL), A=fill, B=ct)

; memset($98B0,$30,0)
       ld   b,#0x30
       ld   hl,#ds_susp_plyr_obj_data             ; memset(...,$30,0)
       rst  0x18                                  ; memset((HL), A=fill, B=ct)

; settext($0b, $83b0)
       ld   hl,#m_tile_ram + 0x03B0
       ld   c,#0x0B                               ; index into string table
       call c_string_out                          ; erase PLAYER 1 text

       ld   a,#1
       ld   (ds_plyr_susp +_b_plyr_nbr),a         ; 1==plyr2

       ld   a,(w_mchn_cfg_bonus)
       ld   (ds_plyr_actv +_b_mcfg_bonus),a
       ld   (ds_plyr_susp +_b_mcfg_bonus),a

       jp   plyr_respawn_splsh              ; does not return, jp's to _game_runner

; end

;;=============================================================================
;; c_game_bonus_info_show_line()
;;  Description:
;;   coinup... displays each line of "1st BONUS, 2ND BONUS, AND FOR EVERY".
;;   Successive calls to this are made depending upon machine config, e.g.
;;  'XXX BONUS FOR XXXXXX PTS'
;;  'AND FOR EVERY XXXXXX PTS'
;; IN:
;;  C = string_out_pe_index
;;  E = first digit of score i.e. X of Xxxxx.
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_game_bonus_info_show_line:

       rst  0x30                                  ; string_out_pe ('XXX BONUS FOR   ', 'AND FOR EVERY   ' )

; set next position to append 'X0000 PTS'
       ex   de,hl                                 ; get position of final character from string_out (digit now in L)
       ld   a,e
       add  a,#0x40                               ; Offset position by 2 characters to the left.
       ld   e,a

       ld   h,#0
       call c_text_out_i_to_d                     ; HL contains number to display, returns updated destination in DE

       ex   de,hl
       ld   c,#0x1E
       call c_string_out                          ; DE=dest, C=string_out_pe_index

       call c_sprite_tiles_displ

       ret


;;=============================================================================
;;  attributes for ship-sprites in bonus info screen ... 4-bytes each:
;;  0: offset/index of object to use
;;  1: color/code
;;      ccode<3:6>==code
;;      ccode<0:2,7>==color
;;  2: X coordinate
;;  3: Y coordinate
;;
d_attrmode_sptiles_ships:
       .db 0x00, 0x81, 0x19, 0x56
       .db 0x02, 0x81, 0x19, 0x62
       .db 0x04, 0x81, 0x19, 0x6E


;;=============================================================================
;; gctl_game_runner()
;;  Description:
;;   background super-loop following game-start
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
gctl_game_runner:
l_045E_while:
       call gctl_supv_score
       call gctl_supv_stage
       jr   l_045E_while


;;=============================================================================
;; _plyr_init()
;;  Description:
;;   One-time setup for new game cycle.
;;   Reset score displays etc. for 1 player and/or 2 player.
;; IN:
;;  ...
;; OUT:
;;  ...
;;
;;-----------------------------------------------------------------------------
gctl_game_init:
;  get nbr of fighters from machine config
       ld   a,(b_mchn_cfg_nships)
       ld   (ds_plyr_actv +_b_nships),a           ; mchn_cfg_nships
       ld   (ds_plyr_susp +_b_nships),a           ; mchn_cfg_nships

;  tiles drawn right to left ... top row layout:
;     2 bytes |                                     | 2 bytes (not visible)
;    ----------------------------------------------------
;    .3DF     .3DD                              .3C2  .3C0     <- Row 0
;    .3FF     .3FD                              .3E2  .3E0     <- Row 1

; Two 0's + 4 spaces + 1 non-visible space on the left
       ld   de,#m_tile_ram + 0x03E0 + 0x18        ; player 1 score, rightmost of "00"
       ld   hl,#d_0495                            ; "00"
       call gctl_init_puts

       ld   de,#m_tile_ram + 0x03E0 + 0x03        ; player 2 score (rightmost column is .3C2)
       ld   hl,#d_0495                            ; "00"

; if ( two_plyr_game )  _putc ... draw 2 0's and 5 spaces in plyr 2 score
       ld   a,(b8_99B3_two_plyr_game)
       and  a
       jr   nz,gctl_init_puts
; else  hl+=2  ... advance src pointer past "00", draw 7 spaces and erase player 2 score
       inc  hl
       inc  hl

;;=============================================================================
;; _score_init
;;  Description:
;;   we saved 4 bytes of code space by factoring out the part that copies 7
;;   characters. Then we wasted about 50 uSec by repeating the erase 2UP!
;; IN:
;;  HL: src tbl pointer ... either 0495 or 0497
;;  DE: dest pointer (offset)
;; OUT:
;;
;;-----------------------------------------------------------------------------
gctl_init_puts:

; erase score
       ld   c,#7                                  ; doesn't initialize B but maybe it should!
       ldir

; erase "2UP" ...start at '_' of '2UP_'  (gets re-drawn momentarily)
       ld   hl,#d_0495 + 2
       ld   de,#m_tile_ram + 0x03C0 + 3           ; rightmost column is .3C2
       ld   c,#4
       ldir

       ret

;=============================================================================
d_0495:
; "00" characters for initial score display
       .db 0x00,0x00
; "space" characters
       .db 0x24,0x24,0x24,0x24,0x24,0x24,0x24


;;=============================================================================
;; gctl_stg_restart_hdlr()
;;  Description:
;;   Starting a new round or re-starting a round due to one of the following events:
;;   - single ship destroyed
;;   - second ship of duo destroyed
;;   - ship captured
;;   - cleared the level.
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
gctl_stg_restart_hdlr:

; return is by jp ... pop the push'd return address of call c_080B_monitor_stage_start_
       pop  hl

       ld   hl,#ds4_game_tmrs + 3                 ; = 4 (set a time to wait while ship exploding)
       ld   (hl),#4

; wait for ship explosion or bug explosion or for a landing captured ship
l_04A4_wait:

;  if ( captured_ship_landing_task_en ) ...
       ld   a,(ds_cpu0_task_actv + 0x1D)         ; f_2000 (destroyed boss that captured ship)
       and  a
       jr   z,l_04C1_while
;  ... then ...
;      ship in play is destroyed, but the "landing" ship remains in play.
       xor  a
       ld   (ds_9200_glbls + 0x13),a              ; 0 ... restart stage flag
       inc  a
       ld   (ds_cpu1_task_actv + 0x05),a          ; 1  (f_05EE: fighter collision detection task)

;    if ( num_bugs > 0 ) return
       ld   a,(b_bugs_actv_nbr)
       and  a
       jp   nz,gctl_game_runner                   ; continue round w/ second (docked) ship... return to Game Runner Loop

;      bug_ct == 0... last bug destroyed by collision w active ship
;      ... wait for captured ship to land before starting new stage

l_04B9_while:
; while ( task active )
       ld   a,(ds_cpu0_task_actv + 0x1D)         ; f_2000 (destroyed boss that captured ship)
       and  a
       jr   nz,l_04B9_while

       jr   l_04DC_break

l_04C1_while:
;  if ( timer_3 > 0 )
       ld   a,(hl)                                ; hl==_game_tmr_3? waiting on 4 count delay time for explosion
       and  a
       jr   nz,l_04A4_wait

       call gctl_supv_score

; plyr_state_actv.b_nbugs = b_bugs_actv_nbr
       ld   a,(b_bugs_actv_nbr)
       ld   (ds_plyr_actv +_b_enmy_ct_actv),a

; check for "not (normal) end of stage conditions":

; if ( restart stage flag || bugs_actv_nbr>0 )
       ld   c,a                                   ; remaining enemies, could be 0 if fighter hit last one
       ld   a,(ds_9200_glbls + 0x13)              ; restart stage flag (could not be here if nbr_bugs > 0 && flag==0 )
       or   c
       jr   nz,gctl_plyr_terminate

       ld   a,(ds_plyr_actv +_b_not_chllg_stg)    ; 0 if challenge stage
       and  a
       jp   z,gctl_chllng_stg_end                 ; jp's back to 04DC_

l_04DC_break:

; end of stage ... "normal"
       call stg_init_splash
       jp   plyr_respawn_rdy


;;=============================================================================
;; gctl_plyr_terminate()
;;  Description:
;;   Handle terminated player
;;   Bramch off to GameOver or TerminateActivePlayer and change player.
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
gctl_plyr_terminate:
; if ( active_plyr_state.num_resv_ships-- == 0 )
       ld   hl,#ds_plyr_actv +_b_nships
       ld   a,(hl)
       dec  (hl)
       and  a
       jp   nz,j_0579_terminate                   ; active ship terminated but not game over
;  if  ( two_plyr_game ) ...
       ld   a,(b8_99B3_two_plyr_game)
       and  a
       jr   z,l_04FD_end_of_game
;  then ... adjust message text for two player game-over
       ld   hl,#m_tile_ram + 0x0240 + 0x0E
       ld   a,(ds_plyr_actv +_b_plyr_nbr)         ; 0==plyr1, 1==plyr2
       add  a,#4
       ld   c,a                                   ; string index
       call c_string_out                          ; "PLAYER X" (for "PLAYER X GAME OVER")

l_04FD_end_of_game:
       ld   c,#0x02                               ; string index
       rst  0x30                                  ; string_out_pe "GAME OVER"

       call c_tdelay_3
       call c_tdelay_3

;  while (0 != task_actv_tbl_0[0x18]){;} ... block if tractor beam completing
       ld   hl,#ds_cpu0_task_actv + 0x18         ; f_2222 (Boss starts tractor beam) wait for task inactive
l_0509_while:
       ld   a,(hl)
       and  a
       jr   nz,l_0509_while

       rst  0x28                                  ; memset(mctl_mpool,0,$$14 * 12)

       call c_sctrl_sprite_ram_clr
       call c_sctrl_playfld_clr

       ld   c,#0x15                               ; string index
       rst  0x30                                  ; string_out_pe ("-RESULTS-")
       ld   c,#0x16                               ; string index
       rst  0x30                                  ; string_out_pe ("SHOTS FIRED")

       ld   de,#m_tile_ram + 0x0120 + 0x12
       ld   hl,(ds_plyr_actv +_w_shot_ct)         ; puts game shots fired count
       call c_text_out_i_to_d                     ; puts game shots fired count

       ld   c,#0x18                               ; string index
       rst  0x30                                  ; string_out_pe ("NUMBER OF HITS")

       ld   de,#m_tile_ram + 0x0120 + 0x15
       ld   hl,(ds_plyr_actv +_w_hit_ct)          ; puts game number of hits
       call c_text_out_i_to_d                     ; puts game number of hits

       ld   c,#0x19                               ; string index
       rst  0x30                                  ; string_out_pe ("HIT-MISS RATIO")

       call c_0A72_puts_hitmiss_ratio

       ex   de,hl                                 ; HL becomes c_string_out<IN:position in tile RAM>
       ld   c,#0x1A                               ; string index
       call c_string_out                          ; "%" after hit-miss number

       ; wait for the timer
       ld   hl,#ds4_game_tmrs + 2
       ld   (hl),#0x0E
l_0540_while:
       ld   a,(hl)
       and  a
       jr   nz,l_0540_while

       call c_sctrl_playfld_clr
       call c_top5_dlg_proc                       ; returns immediately if not in top-5

       xor  a
       ld   (b_9AA0 + 0x10),a                     ; 0 ... sound-fx count/enable registers, hi-score dialog?

; while (_fx[0x0C] || _fx[0x16]) ... (finished when both 0)
       ld   hl,#b_9AA0 + 0x0C                     ; sound-fx count/enable registers, hi-score dialog
       ld   de,#b_9AA0 + 0x16                     ; sound-fx count/enable registers, hi-score dialog
l_0554_while:
       ld   a,(de)                                ; sound_fx[0x16] ... probably 0
       ld   b,(hl)                                ; sound_fx[0x0C] ... probably still running
       or   b
       jr   z,l_0562
; if (0 != _fx[0x0C]) then _fx[0x0C] = 1 ... snd[$0C] used as timer, enable snd[$16] when 0 is reached
       inc  b
       dec  b
       jr   z,l_055F
       ld   (hl),#1
l_055F:
; On halt, processor wakes at maskable or nonmaskable interrupt providing
; something like a busy-wait with sleep(n) where n is the interrupt period.
       halt                                       ; hi-score, finished name entry (wait for music to stop)
       jr   l_0554_while

l_0562:
       call c_sctrl_playfld_clr                   ; clear screen at end of game

; done game over stuff for active player, so if 1P game or
; plyr_susp.resv_fghtrs exhausted then halt

; if ( !two_plyr_game || -1 == plyr_susp.resv_fghtrs ) then halt
       ld   a,(b8_99B3_two_plyr_game)
       and  a
       jp   z,g_halt                              ; jp   g_main
       ld   a,(ds_plyr_susp +_b_nships)           ; -1 if no resv ships remain
       inc  a
       jp   z,g_halt                              ; jp   g_main

; else if ( stage_rst_flag != 1 ) ... _plyr_chg()
;   indicates fighter-capture event
       ld   a,(ds_9200_glbls + 0x13)              ; restart stage flag
       dec  a
       jr   nz,j_058E_plyr_chg

j_0579_terminate:
; if ( !two_plyr_game ) {
       ld   a,(b8_99B3_two_plyr_game)
       and  a
       jp   z,plyr_respawn_1up                    ; plyr_respawn_1P < plyr_respawn_wait < fghtr_rdy < game_runner

; } else if ( plyr_susp.resv_fghtrs == -1  || stage_rst_flag != 0 )
       ld   a,(ds_plyr_susp +_b_nships)           ; -1 when .resv_fghtrs exhausted
       inc  a
       jp   z,plyr_respawn_plyrup                 ; allow actv plyr respawn if susp plyr out of ships
; note: stage_rst_flag == 0 would also test true but that would make no sense here
       ld   a,(ds_9200_glbls + 0x13)              ; restart_stage
       dec  a
       jp   nz,plyr_respawn_plyrup                ; allows active plyr to respawn on capture ship event
; }
; else { do player change }


;;=============================================================================

j_058E_plyr_chg:
; if ( nr of bugs == 0 ) {{
       ld   a,(b_bugs_actv_nbr)
       and  a
       jr   z,l_059A_prep
; }} else {{
;    while ( nbr_flying_bugs > 0 ) {
l_0594:
       ld   a,(b_bugs_flying_nbr)                 ; check if !=0 (ship destroyed, wait for bugs return to nest)
       and  a
       jr   nz,l_0594
;    }
; }}

; set up for active player nest to retreat
l_059A_prep:
       xor  a
       ld   (b8_99B4_bugnest_onoff_scrn_tmr),a    ; 0 ( timer/counter while nest retreating)
       inc  a
       ld   hl,#ds_cpu0_task_actv + 0x0E          ; 1 ... f_1D32
       ld   (hl),a

; wait for formation to exit ... completion of f_1D32 (status actv_task_tbl[$0E])
l_05A3_while:
       ld   a,(hl)
       and  a
       jr   nz,l_05A3_while

; exchange player data
       ld   a,(b_9AA0 + 0x00)                     ; plyr_actv.b_sndflag
       ld   (ds_plyr_actv +_b_sndflag),a          ; _fx[0] ... enable for pulsing_sound
       ld   a,(ds4_game_tmrs + 2)
       ld   (ds_plyr_actv +_b_plyr_swap_tmr),a    ; game_tmr[2]
       call c_player_active_switch
       call c_2C00                                ; new stage setup
       ld   a,(ds_plyr_actv +_b_plyr_swap_tmr)    ; game_tmr[2]
       ld   (ds4_game_tmrs + 2),a                 ; actv_plyr_state[0x1F]
       ld   a,(ds_plyr_actv +_b_sndflag)          ; _fx[0] ... enable for pulsing_sound
       ld   (b_9AA0 + 0x00),a                     ; enable for pulsing_sound
       call draw_resv_ships

; if ( _enmy_ct_actv != 0 ) ...
       ld   a,(ds_plyr_actv +_b_enmy_ct_actv)
       and  a
       jr   z,l_05D1
; ... then ... player was previously destroyed by collision with last enemy in the round
       call c_25A2                                ; gctl_stg_new_atk_wavs_init()

; setting up a new screen (changing players)
l_05D1:
;  screen_is_flipped = (cab_type==Table & Plyr2up )
       ld   a,(ds_plyr_actv +_b_plyr_nbr)         ; 0==plyr1, 1==plyr2
       ld   c,a
       ld   a,(b_mchn_cfg_cab_type)               ; 0==UPRIGHT, 1==TABLE
       and  c
       ld   (0xA007),a                            ; sfr_flip_screen
       ld   (b_9215_flip_screen),a

; gctl_stg_fmtn_hpos_init
       ld   a,#0x3F
       call c_12C3                                ; A==$3F ... set MOB coordinates, player changeover

; set Cy to disable sound clicks for level tokens on player change (value of A is irrelevant)
       scf
       ex   af,af'
       call c_new_level_tokens                    ; Cy' == 1, A == don't care

; if ( _enmy_ct_actv == 0 )  ... then _stg_init ... player was previously destroyed by collision with last enemy in the round
       ld   a,(ds_plyr_actv +_b_enmy_ct_actv)
       and  a
       jr   z,plyr_respawn_splsh            ; _plyr_startup > _new_stg_ <-  _plyr_startup

; else ...
       ld   c,#3                                  ; C=string_out_pe_index
       rst  0x30                                  ; string_out_pe "READY"

; set wait-time for bug nest retreat. The count is masked with $7F in f_1D32, so I
; don't see why it starts at $80 here instead of 0. Shouldn't make any difference tho'...
       ld   a,#0x80
       ld   (b8_99B4_bugnest_onoff_scrn_tmr),a    ; $80

; wait for bug nest to reappear.
       ld   hl,#ds_cpu0_task_actv + 0x0E          ; 1 ... f_1D32
       ld   a,#1
       ld   (hl),a

; while ( cpu0_task_actv[$0E] ) ... wait for the task to timeout
l_05FD:
       ld   a,(hl)
       and  a
       jr   nz,l_05FD

       jp   plyr_respawn_plyrup                     ; reloaded suspended plyr, bug nest reloaded... ready!


;;=============================================================================
; "respawn" for 1 player game.
; If fighter terminated by last enemy of the stage, then init new stage.
; Only reference is from _terminate() so it should be "inlined" there.
plyr_respawn_1up:
; if (0 == plyr_state_actv.b_nbugs) ...
       ld   a,(ds_plyr_actv +_b_enmy_ct_actv)
       and  a
       jr   nz,gctl_plyr_respawn_wait
; ... then ...
       call stg_init_splash                       ; new stage setup, shows "STAGE X"

       jr   gctl_plyr_respawn_wait


;;=============================================================================
; Player respawn with stage setup (i.e. when plyr.enemys = 0, i.e. player
; change, or at start of new game loop.
; If on a new game, PLAYER 1 text has been erased.
plyr_respawn_splsh:
       call stg_init_splash                       ; shows "STAGE X" and does setup

       ;; plyr_respawn_plyrup()

;;-----------------------------------------------------------------------------
; Setup a new player... every time the player is changed on a 2P game or once
; at first fighter of new 1P game. Player X text shown, stage restart.
plyr_respawn_plyrup:
       ld   a,(ds_plyr_actv +_b_plyr_nbr)         ; 0==plyr1, 1==plyr2
       add  a,#4                                  ; P1 text is index 4, P2 is index 5
       ld   c,a                                   ; index into string table
       ld   hl,#m_tile_ram + 0x0260 + 0x0E        ; not position encoded, this one is 1C left and 2R up
       call c_string_out                          ; puts PLAYER X ("1" or "2") .

;;-----------------------------------------------------------------------------
;; _fghtr_rdy + wait ... 1 player skips previous stuff
gctl_plyr_respawn_wait:
       call c_player_respawn                      ; "credit X" is wiped and reserve ships appear on lower left of screen

; ds4_game_tmrs[2] was set to 120 by new_stg_game_or_demo

; if tmr > $5A then reset to $78
       ld   a,(ds4_game_tmrs + 2)
       add  a,#0x1E
       cp   #0x78
       jr   c,l_062C
       ld   a,#0x78
l_062C:
       ld   (ds4_game_tmrs + 2),a                 ; $78

; new ship appears on screen and stars start moving ... should about take care of the music
       call c_tdelay_3

;;-----------------------------------------------------------------------------
; new round starting or round re-starting after active player switch.
plyr_respawn_rdy:
       ld   a,#1
       ld   (ds_cpu0_task_actv + 0x15),a          ; 1 ... f_1F04 (fire button input)
       ld   (ds_cpu1_task_actv + 0x05),a          ; 1 ... cpu1:f_05EE (hit-detection)
       ld   (ds_plyr_actv +_b_atk_wv_enbl),a      ; 1  (0 when respawning player ship)

       ld   c,#0x0B                               ; index into string table
       ld   hl,#m_tile_ram + 0x03B0
       call c_string_out                          ; erase "READY" or "STAGE X"

       ld   c,#0x0B                               ; index into string table
       ld   hl,#m_tile_ram + 0x03A0 + 0x0E
       call c_string_out                          ; erase "PLAYER 1"

       jp   gctl_game_runner                      ; resume background super loop


;;=============================================================================
;; gctl_chllng_stg_end()
;;  Description:
;;    Handle challenge stage book-keeping prior to doing the "normal"
;;    new_stage_setup.
;;    Entry and Exit are both by jp.
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
gctl_chllng_stg_end:

       ld   a,(b_bug_flyng_hits_p_round)
       ld   e,a

       ld   hl,#b_9AA0 + 0x0E                     ; sound-fx count/enable registers, default melody for challenge stage
       cp   #40                                   ; nbr of bugs in challenge round
       jr   nz,l_065E
       ld   hl,#b_9AA0 + 0x14                     ; sound effect count/enable registers, "perfect!" melody, challenge stg
l_065E:
       ld   (hl),#1

       call c_tdelay_3

       ld   c,#0x08
       rst  0x30                                  ; string_out_pe ("NUMBER OF HITS")

       call c_tdelay_3

; DE = adjusted offset into tile ram on return
       ld   l,e                                   ; E==nbr of flying bugs hit this round
       ld   h,#0
       ld   de,#m_tile_ram + 0x0100 + 0x10
       call c_text_out_i_to_d                     ; HL contains number to display (number of hits)

       call c_tdelay_3

; if (0x40 != b_bug_flyng_hits_p_round) ...
       ld   a,(b_bug_flyng_hits_p_round)          ; if 40
       cp   #40
       jr   z,l_0699_special_bonus
; then ...
       ld   c,#9
       rst  0x30                                  ; string_out_pe ("BONUS")

       call c_tdelay_3

       ex   de,hl                                 ; DE = HL

; if (0 != b_bug_flyng_hits_p_round) ...
       ld   a,(b_bug_flyng_hits_p_round)          ; if !0
       and  a
       jr   z,l_0693_put_ones
; then ...
       ld   l,a
       ld   h,#0
       call c_text_out_i_to_d                     ; HL contains number to display (1000's,100's place of bonus pts awarded)
       xor  a
       ld   (de),a                                ; putc(0) ... 10's place of bonus pts awarded
       rst  0x20                                  ; DE-=$20
       xor  a

l_0693_put_ones:
       ld   (de),a                                ; putc(0) ... 1's place of bonus pts awarded
       ld   a,(b_bug_flyng_hits_p_round)
       jr   l_06BA

l_0699_special_bonus:
; blink the "PERFECT !" text
       ld   b,#7
l_069B_while_b:
l_069B_while_fcnt:
       ld   a,(ds3_92A0_frame_cts + 0)
       and  #0x0F
       jr   nz,l_069B_while_fcnt

       ld   c,#0x0B                               ; index into string table (27 spaces)
       bit  0,b
       jr   z,l_06A9
       inc  c                                     ; C = 0x0C; // index into string table "PERFECT !"
l_06A9:
       push bc
       rst  0x30                                  ; string_out_pe ( C == $0B or C == $0C ... "PERFECT !" or spaces)
       pop  bc

l_06AC_while_fcnt:
       ld   a,(ds3_92A0_frame_cts + 0)
       and  #0x0F
       jr   z,l_06AC_while_fcnt

       djnz l_069B_while_b

       ld   c,#0x0D                               ; index into string table
       rst  0x30                                  ; string_out_pe ("SPECIAL BONUS 10000 PTS")

       ld   a,#100                                ; 100 * 10 ... special bonus (d_scoreman_inc_lut[0] == $10)
l_06BA:
       ld   hl,#ds_bug_collsn_hit_mult + 0x0F     ; challenge bonus score += 10000
       add  a,(hl)
       ld   (hl),a
       call gctl_supv_score                       ; add bonus to player score
       call c_tdelay_3
       call c_tdelay_3

       ld   hl,#m_tile_ram + 0x03A0 + 0x10
       ld   c,#0x0B                               ; index into string table
       call c_string_out                          ; erase "Number of hits XX" (line below Perfect)

       ld   hl,#m_tile_ram + 0x03A0 + 0x13
       ld   c,#0x0B                               ; index into string table
       call c_string_out                          ; erase "Special Bonus 10000 Pts" (or Bonus xxxx)

       ld   c,#0x0B                               ; index into string table
       rst  0x30                                  ; string_out_pe (erase "PERFECT !")

       jp   l_04DC_break


;;=============================================================================
;; g_halt()
;;  Description:
;;    Restarts machine when one (or both) players exhausted supply of fighters.
;;    Resumes at g_main.
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
g_halt:
       halt                                       ; screen is now cleared at end of game
       di

l_06E0_while_wait_io_ackrdy:
       ld   a,(0x7100)                            ; read IO status
       cp   #0x10                                 ; if (IO_ACKRDY) ... "command executed"
       jr   nz,l_06E0_while_wait_io_ackrdy

       ld   hl,#d_0725                            ; set data src ($02,$02,$02)
       ld   de,#0x7000                            ; IO data xfer (write)
       ld   bc,#0x0003
       exx

       ld   a,#0x61                               ; Reset IO chip? (not in Mame36 - check newer).
       ld   (0x7100),a                            ; IO cmd ($61 -> disable IO chip?)
       halt                                       ; stops until interrupt

; allow blinking of Player2 text to be inhibited on the intro screen when the
; game recycles (Player1 text shown anyway)
       xor  a
       call c_093C                                ; A == 0 ... blinking off

       ei

;  memset($9AA0,0,$20)
       xor  a
       ld   b,#0x20
       ld   hl,#ds_9AA0                           ; count/enable registers for sound effects, $20 bytes cleared
       rst  0x18                                  ; memset((HL), A=fill, B=ct)

       ld   de,#m_tile_ram + 0x03E0 + 0x19        ; 83f9 is 10's place score digit, below P of '1UP'
       call c_mach_info_add_score
       ld   de,#m_tile_ram + 0x03E0 + 0x04        ; 83e4 is 10's place score digit, below P of '2UP'
       call c_mach_info_add_score

;  Update total plays (up to 9999 bcd)
;  total_plays_bcd = (two_plyr_game==1) + 1  ... 0 for 1P, 1 for 2P
       ld   a,(b8_99B3_two_plyr_game)
       inc  a
       ld   hl,#b16_99E0_ttl_plays_bcd + 1        ; get lsb (1s,10s place)
       add  a,(hl)
       daa
       ld   (hl),a
       jp   nc,g_main                             ; finished update total_plays_bcd
       dec  hl                                    ; w_total_plays_bcd (get msb ...100s,1000s place)
       ld   a,(hl)
       add  a,#0x01
       daa
       ld   (hl),a
       jp   g_main                                ; from g_halt

;;=============================================================================
;; const data for g_halt()
d_0725:
       .db 0x02,0x02,0x02

;;=============================================================================
;; gctl_supv_score()
;;  Description:
;;
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
gctl_supv_score:
;  if ( activ_plyr_state.plyr_1or2 == plyr1 )
       ld   a,(ds_plyr_actv +_b_plyr_nbr)         ; 0==plyr1, 1==plyr2
       and  a
;    tmp = $f9
       ld   a,#0xF9                               ; offset to 10's place from _tile_ram + 0x0300 (plyr 1)
       jr   z,l_0732
;  else tmp = $E4
       ld   a,#0xE4                               ; offset to 10's place from _tile_ram + 0x0300 (plyr 2)

l_0732:
       ld   ixl,a                                 ; parameter to c_scoreman_incr_add (tile ram offset)

       ld   b,#0x10                               ; sizeof scoreman_inc_lut[]
       ld   hl,#ds_bug_collsn_hit_mult + 0x00
l_0739_while_B:
       ex   de,hl                                 ; DE := &bug_collsn[hl]
       ld   hl,#d_scoreman_inc_lut - 1            ; effective start index is $10 - 1
       ld   a,b
       rst  0x10                                  ; HL += A
       ld   c,(hl)                                ; scoreman_inc_lut[B-1]
; bug_collsn[hl] * scoreman_inc_lut[B-1]
l_0740:
       ex   de,hl
       ld   a,(hl)                                ; bug_collsn[hl]
       and  a
       jr   z,l_0762                              ; while ( 0 != bug_collsn[HL] )

       dec  (hl)                                  ; bug_collsn[HL] decrement accumulated hit count
       ex   de,hl                                 ; DE := &bug_collsn[0x00]

       ld   h,#>(m_tile_ram + 0x0300)             ; tile rows 32-35:  $83C0 - 83FF
       ld   a,ixl                                 ; offset to 10's place in tile ram
       ld   l,a
       ld   a,c                                   ; scoreman_inc_lut[B-1]
       and  #0x0F
       call c_scoreman_incr_add                   ; add to 10's

       ld   a,ixl                                 ; increment offset to 10's place in tile ram
       inc  a
       ld   l,a
       ld   a,c                                   ; scoreman_inc_lut[B-1]
       rlca                                       ; upper nibble of "score increment"
       rlca
       rlca
       rlca
       and  #0x0F
       call c_scoreman_incr_add                   ; add to 100's
       jr   l_0740

l_0762:
       inc  l                                     ; index of bug_collsn[]
       djnz l_0739_while_B


       ld   a,ixl
       add  a,#4
       ld   e,a
       ld   hl,#m_tile_ram + 0x03E0 + 0x12        ; 100000's digit of HIGH SCORE (83ED-83F2)
       ld   d,#>(m_tile_ram + 0x0300)

       ld   b,#6
l_0771:
       ld   a,(de)
       sub  (hl)
       add  a,#9
       cp   #0xE5
       jr   nc,l_0788
       sub  #0x0A
       cp   #9
       jr   c,l_0788
       inc  a
       jr   nz,l_078E
       dec  l
       dec  e
       djnz l_0771
; else ... break
       jr   l_078E

l_0788:
       ld   a,(de)                                ; hi score
       ld   (hl),a
       dec  l
       dec  e
       djnz l_0788

l_078E:
       ld   a,ixl
       add  a,#4
       ld   l,a
       ld   a,(hl)
       cp   #0x24
       jr   nz,l_0799
       xor  a
l_0799:
       and  #0x3F
       rlca
       ld   c,a
       rlca
       rlca
       add  a,c
       ld   c,a
       dec  l
       ld   a,(hl)
       cp   #0x24
       jr   nz,l_07A8
       xor  a
l_07A8:
       add  a,c
       ld   hl,#ds_plyr_actv +_b_mcfg_bonus       ; &actv_plyr_state[0x1E] ... load at game start from $9980
       cp   (hl)
       ret  nz
       ld   a,(w_mchn_cfg_bonus + 0x01)           ; looks like a bonus may be awarded.
       ld   b,a
       and  #0x7F
       ld   c,a
       ld   a,(hl)                                ; &actv_plyr_state[0x1E]
       cp   c
       jr   nc,l_07BC
       ld   a,c
       jr   l_07BD

l_07BC:
       add  a,b                                   ; actv_plyr_state[0x1E] += mchn_cfg_bonus[1]
l_07BD:
       ld   (hl),a
       ld   (b_9AA0 + 0x0A),a                     ; sound-fx count/enable registers, bonus ship awarded sound (set non-zero)
       ld   hl,#ds_plyr_actv +_b_nships
       inc  (hl)
       call draw_resv_ships                       ; new spare ship added
       ld   hl,#b16_99EA_bonus_ct_bcd + 1
       ld   a,(hl)
       add  a,#1
       daa
       ld   (hl),a
       ret  nc
       dec  l
       ld   a,(hl)
       add  a,#1
       daa
       ld   (hl),a
       ret
; end call $0728

;;=============================================================================
;; c_scoreman_incr_add()
;;  Description:
;;   Handle score increment (score manager)
;;   Score is not stored other than in character ram, so this function is
;;   specific to the layout of decimal digits in the character map.
;; IN:
;;  A == scoreman_inc_lut[B-1]
;;  HL== destination address ... _tile_ram + 0x0300
;; OUT:
;;
;; PRESERVES:
;;  HL
;;-----------------------------------------------------------------------------
c_scoreman_incr_add:
       and  a
       ret  z

       add  a,(hl)                                ; a += _tile_ram[hl]
       cp   #0x24                                 ; $23=='Z', $24==' '
       jr   c,l_07E1
       sub  #0x24                                 ; when is jr not taken?

l_07E1:
       cp   #0x0A                                 ; $0A='A'
       jr   nc,l_07E7
       ld   (hl),a
       ret

l_07E7:
       sub  #0x0A

l_07E9_while_1:
       ld   (hl),a                                ; m_tile_ram[hl] = a

       inc  l
       ld   a,(hl)                                ; a = m_tile_ram[hl + 1]
       cp   #0x24                                 ; $24==' '
       jr   nz,l_07F1
       xor  a

l_07F1:
       cp   #0x09
       jr   z,l_07F8_while

       inc  a
       ld   (hl),a                                ; m_tile_ram[hl] = a
       ret                                        ; end call 07d8

l_07F8_while:
       xor  a
       jr   l_07E9_while_1

;;=============================================================================
;; Base-factors of points awareded for enemy hits, applied to multiples
;; reported via _bug_collsn[]. Values are BCD-encoded, and ordered by object
;; color group, i.e. as per _bug_collsn.
;; Indexing is reversed, probably to take advantage of djnz.
;; Index $00 is a base factor of 10 for challenge-stage bonuses to which a
;; variable bonus-multiplier is applied (_bug_collsn[$0F]).
d_scoreman_inc_lut:
       .db 0x10,0x00,0x00,0x00,0x00,0x00,0x00,0x00
       .db 0x50,0x08,0x08,0x08,0x05,0x08,0x15,0x00

;;=============================================================================
;; gctl_supv_stage()
;;  Description:
;;   from _0461 game runner inf loop.
;;   Checks for conditions indicating start of new stage or restart of
;;   stage-in-progress.
;;   0 bugs remaining indicates that a new-stage start is in order. (also 9008?)
;;   Otherwise, the "restart_stage_flag" may indicate that the players active
;;   ship has been terminated or captured requiring a stage re-start.
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
gctl_supv_stage:

;  if ( num_bugs == 0  &&  !f_2916 active ) ...
       ld   a,(ds_cpu0_task_actv + 0x08)          ; f_2916 (supervises attack waves)
       ld   b,a
       ld   a,(b_bugs_actv_nbr)
       or   b
       jr   nz,l_081B
; then ...
       ld   (b_9AA0 + 0x00),a                     ; 0 ... sound-fx count/enable registers, pulsing formation sound effect

       jp   gctl_stg_restart_hdlr                 ; cleared the round ... num_bugs_on_screen ==0 || !f_2916_active

l_081B:
; else if ( rst_stage_flag ) ...
       ld   a,(ds_9200_glbls + 0x13)              ; restart stage flag
       and  a
       ret  z                                     ; not the end of the stage, and not restart_stage event
; then ...
       xor  a
       ld   (ds_plyr_actv +_b_atk_wv_enbl),a      ; 0 ... restart_stage_flag has been set

       jp   gctl_stg_restart_hdlr                 ; restart_stage_flag has been set


;;=============================================================================
;; f_0827()
;;  Description:
;;   empty task
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
f_0827:
       ret

;;=============================================================================
;; f_0828()
;;  Description:
;;   Copies from sprite "buffer" to sprite RAM...
;;   works in conjunction with CPU-sub1:_05BF to update sprite RAM
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
f_0828:
       ld   a,#1
       ld   (b_CPU1_in_progress),a                ; 1
       ld   hl,#mrw_sprite_code + 0x40
       ld   de,#sfr_sprite_code + 0x40
       ld   bc,#0x0040
       ldir
       ld   hl,#mrw_sprite_posn + 0x40
       ld   de,#sfr_sprite_posn + 0x40
       ld   c,#0x40
       ldir
       ld   hl,#mrw_sprite_ctrl + 0x40
       ld   de,#sfr_sprite_ctrl + 0x40
       ld   c,#0x40
       ldir
       xor  a
       ld   (b_CPU1_in_progress),a                ; 0
l_0850:
       ld   a,(b_CPU2_in_progress)                ; check status of other CPU... while (b_CPU2_in_progress) == $01 ...
       dec  a
       jr   z,l_0850                              ; wait
       ret
; end task $0828

;;=============================================================================
;; f_0857()
;;  Description:
;;    triggers various parts of gameplay based on parameters
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
f_0857:
       ld   a,(ds4_game_tmrs + 2)
       ld   b,a                                   ; parameter to c_08AD
       cp   #0x3C
       jr   nc,l_0865
; increases allowable max_bombers after a time
       ld   a,(ds_new_stage_parms + 0x05)
       ld   (ds_new_stage_parms + 0x04),a         ; new_stage_parms[4] = new_stage_parms[5] ... max bombers

; set bomb drop enable flags
l_0865:
       ld   a,(b_bugs_actv_nbr)
       ld   c,a                                   ; parameter to c_08BE
       ld   a,(ds_new_stage_parms + 0x00)         ; set bomb drop enable flags
       ld   hl,#d_0909 + 0 * 4
       call c_08BE                                ; A==new_stage_parms[0], HL==d_0909, C==num_bugs_on_scrn
       ld   (b_92C0 + 0x08),a                     ; = c_08BE() ... bomb drop enable flags

; flag indicates number of flying aliens is less than new_stage_parm[7]
; if flag is set by sub-CPU tasking kernel ...
       ld   a,(b_92A0 + 0x0A)                     ; continuous bombing when flag set
       and  a
       jr   z,l_0888

; then ... set default start values for bomber launch timers in continuous bombing state
; this will also happen momentarily at start of round until bugs_actv_nbr exceeds ds_new_stage_parms[0x07]
       ld   hl,#b_92C0 + 0x04                     ; memset( b_92C0_4, 2, 3 )
       ld   a,#2
       ld   b,#3
       rst  0x18                                  ; memset((HL), A=fill, B=ct)

       xor  a
       ld   (b_9AA0 + 0x00),a                     ; 0 ... sound-fx count/enable registers, kill pulsing sound effect (free-fly)
       ret

l_0888:
; ... else after bugs_actv_nbr exceeds parameter_7 until continous bombing begins
       ld   a,(ds_new_stage_parms + 0x01)
       ld   hl,#d_0909 + 8 * 4                    ; offset the data pointer
       call c_08BE                                ; A==new_stage_parms[1], HL==d_0929, C==num_bugs_on_scrn
       ld   (b_92C0 + 0x04),a                     ; c_08BE() ... boss alien default bomber timer

       ld   a,(ds_new_stage_parms + 0x02)
       ld   hl,#d_08CD
       call c_08AD                                ; A==new_stage_parms[2], HL==d_08CD
       ld   (b_92C0 + 0x05),a                     ; c_08AD() ... red alien default bomber timer

       ld   a,(ds_new_stage_parms + 0x03)
       ld   hl,#d_08EB
       call c_08AD                                ; A==new_stage_parms[3], HL==d_08EB
       ld   (b_92C0 + 0x06),a                     ; c_08AD() ... yellow alien default bomber timer

       ret

;;=============================================================================
;; c_08AD()
;;  Description:
;;  for f_0857
;; IN:
;;  A == ds_new_stage_parms[2] or [3]
;;  B == ds4_game_tmrs[2]
;;  HL == d_08CD or d_08EB
;; OUT:
;;  A == (hl)
;;-----------------------------------------------------------------------------
c_08AD:
; HL += 3 * A ... index into groups of 3 bytes
       ld   e,a
       sla  a
       add  a,e
       rst  0x10                                  ; HL += A

       ld   a,b                                   ; ds4_game_tmrs[2] from f_0857
       cp   #0x28
       jr   nc,l_08B8
       inc  hl
l_08B8:
       and  a
       jr   nz,l_08BC
       inc  hl
l_08BC:
       ld   a,(hl)
       ret
; end 'call _08AD'

;;=============================================================================
;; c_08BE()
;;  Description:
;;   for f_0857
;; IN:
;;  A==ds_new_stage_parms + 0x00 or ds_new_stage_parms + 0x01
;;  C==bugs_actv_nbr
;;  HL== pointer _0909, _0929
;; OUT:
;;  A==(hl)
;;-----------------------------------------------------------------------------
c_08BE:
; A used as index into sets of 4
; 16-bit division not needed here, but slightly more efficient to load the
; dividend into upper byte of HL and take quotient from H
; the quotient is ranged 0-4, so in the case the A max out at 7 and number
; of creatures is 40, the selected byte would be at $0929, so d_0909 and
; d_0929 should be one contiguous table.
       sla  a
       rst  0x08                                  ; HL += 2A
       ex   de,hl
       ld   h,c
       ld   a,#0x0A
       call c_divmod                              ; HL=HL/10
       ex   de,hl                                 ; 8-bit quotient into d ...
       ld   a,d                                   ; ... quotient into a
       rst  0x10                                  ; HL += A
       ld   a,(hl)
       ret

;;=============================================================================
; sets of 3 bytes indexed by stage parameters 2 and 3 (max value 9)
d_08CD:
       .db 0x09,0x07,0x05
       .db 0x08,0x06,0x04
       .db 0x07,0x05,0x04
       .db 0x06,0x04,0x03
       .db 0x05,0x03,0x03
       .db 0x04,0x03,0x03
       .db 0x04,0x02,0x02
       .db 0x03,0x03,0x02
       .db 0x03,0x02,0x02
       .db 0x02,0x02,0x02
d_08EB:
       .db 0x06,0x05,0x04
       .db 0x05,0x04,0x03
       .db 0x05,0x03,0x03
       .db 0x04,0x03,0x02
       .db 0x04,0x02,0x02
       .db 0x03,0x03,0x02
       .db 0x03,0x02,0x01
       .db 0x02,0x02,0x01
       .db 0x02,0x01,0x01
       .db 0x01,0x01,0x01

; sets of 4 bytes indexed by stage parameters 0 and 1 (max value 7)
d_0909:
       .db 0x03,0x03,0x01,0x01
       .db 0x03,0x03,0x03,0x01
       .db 0x07,0x03,0x03,0x01
       .db 0x07,0x03,0x03,0x03
       .db 0x07,0x07,0x03,0x03
       .db 0x0F,0x07,0x03,0x03
       .db 0x0F,0x07,0x07,0x03
       .db 0x0F,0x07,0x07,0x07
;d_0929:
       .db 0x06,0x0A,0x0F,0x0F
       .db 0x04,0x08,0x0D,0x0D
       .db 0x04,0x06,0x0A,0x0A

;;=============================================================================
;; f_0935()
;;  Description:
;;    handle "blink" of Player1/Player2 texts.
;;    Toggles the "UP" text on multiples of 16 frame counts.
;;    With frame counter being about 60hz, we should get a blink of
;;    about twice per second.
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
f_0935:
;  A = ds3_92A0_frame_cts[0] / 16
       ld   a,(ds3_92A0_frame_cts + 0)
       rlca
       rlca
       rlca
       rlca

;;=============================================================================
;; gctl_1up2up_displ()
;;  Description:
;;   Blink 1UP/2UP
;; IN:
;;   A==0 ... called by game_halt()
;;   A==frame_cnts/16 ...continued from f_0935()
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_093C:
       ld   c,a                                   ; stash counter in C

; if ( game_state != IN_GAME_MODE )  return
       ld   a,(b8_9201_game_state)                ; if ( ! IN_GAME )
       cp   #3
       ret  nz

; B = ds_plyr_actv.p1or2
; (9820[] has not cleared yet so plyr_state.p1or2 may be invalid at first game start after powerup.)
       ld   a,(ds_plyr_actv +_b_plyr_nbr)         ; 0==plyr1, 1==plyr2
       ld   b,a                                   ; stash it in B

; do 1UP
       cpl                                        ; toggle to 1 if 1UP

       and  c                                     ; C == 1 if wipe
       ld   hl,#str_1UP
       ld   de,#m_tile_ram + 0x03C0 + 0x19        ; 'P' of 1UP
       call c_095F                                ; wipe if A != 0

; if ( two_plyr_game ) then ...
       ld   a,(b8_99B3_two_plyr_game)
       and  a
       ret  z

; ... do 2UP
       ld   a,b                                   ; 1 if 2UP
       and  c                                     ; C == 1 if wipe
       ld   hl,#str_2UP
       ld   de,#m_tile_ram + 0x03C0 + 0x04        ; 'P' of 2UP
;       call c_095F

;;=============================================================================
;; c_095F()
;;  Description:
;;   draw 3 characters
;; IN:
;;  A==1 ...  wipe text
;;  A==0 ...  show text at HL
;;  HL == src pointer, xUP text
;;  DL == dest pointer
;; OUT:
;; PRESERVES:
;;  BC
;;-----------------------------------------------------------------------------
c_095F:
       push bc

       and  #0x01
       jr   z,l_0967
       ld   hl,#str_0974                          ; wipe
l_0967:
       ld   bc,#0x0003
       ldir

       pop  bc
       ret

;;=============================================================================
str_1UP:
       .db 0x19,0x1E,0x01                          ; "PU1"
str_2UP:
       .db 0x19,0x1E,0x02                          ; "PU2"
str_0974:
       .db 0x24,0x24,0x24                         ; "spaces"

;;=============================================================================
;; f_0977()
;;  Description:
;;   Polls the test switch, updates game-time counter, updates credit count.
;;   Handles coinage and changes in game-state.
;;
;;    If credit > 0, change _game_state to Push_start ($02)
;;     (causes 38d loop to transition out of the Attract Mode, if it's not already in PUSH_START mode)
;;
;;    Check Service Switch - in "credit mode", the 51xx is apparently programmed
;;      to set io_buffer[0]=$bb to indicate "Self-Test switch ON position" .
;;      So, ignore the credit count and jump back to the init.
;;      Bally manual states that "may begin a Self-Test at any time by sliding the
;;      ... switch to the "ON" position...the game will react as follow: ... there is
;;     an explosion sound...upside down test display which lasts for about 1/2 second"
;;    However MAME may not handle this correctly - after the jump to Machine_init, the
;;    system hangs up on the info screen, all that is shown is "RAM OK". (This is
;;    true even if the switch is turned off again prior to that point).
;;
;;    Note mapping of character cells on bottom (and top) rows differs from
;;    that of the rest of the screen;
;;      801D-<<<<<<<<<<<<<<<<<<<<<<<<<<<<-8002
;;      803d-<CREDIT __<<<<<<<<<<<<<<<<<<-8022
;;
;;    99E6-9 implements a count in seconds of total accumulated game-playing time.
;;    counter (low digit increments 1/60th of second)
;;
;;    Credits available count (from HW IO) is transferred to the IO input
;;    buffer (in BCD) in the NMI, and represent actual credits awarded (not
;;    coin-in count). The HW count is decremented by the HW. The game logic
;;    then must keep its own count to compare to the HW to determine if the
;;    HW count has been added or decremented and thus determine game-start
;;    condition and number of player credits debited from the HW count.
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
f_0977:
; if ( io_input[0] == $bb )
       ld   a,(ds3_99B5_io_input + 0x00)          ; check for bb ... Service Switch On indication in credit mode
       cp   #0xBB
       jp   z,jp_RAM_test

; if ( game_state != IN_GAME_MODE )  // goto update freeplay_or_credit
       ld   a,(b8_9201_game_state)                ; if ( IN_GAME )
       cp   #3                                    ; game_state==IN_GAME
       jr   nz,l_099F_update_freeplay_or_credit

; else // update timer
       ld   hl,#b32_99E6_gametime_secs_bcd + 3    ; least-sig. digit increments 1/60th of second
       ld   a,(hl)
       add  a,#1
       daa
       ; if ( ct == $60 ) ct=0
       cp   #0x60                                 ; if A==60, Cy is not set...
       jr   nz,l_0992_update_counter
       xor  a

      ; update 4 bytes of the timer (BCD count 0 - 99.99.99.60)
l_0992_update_counter:
       ld   b,#4
       ccf                                        ; ... compliment Cy (provides Cy into 1's place if A==60...
l_0995:
       ld   (hl),a                                ; Update 60'ths digit.
       dec  l
       ld   a,(hl)                                ; note, last iteration, reads from 99e5, but then exits the loop.
       adc  a,#0                                  ; ...carry into 1's, 10's, or 100's place.
       daa
       djnz l_0995

       jr  l_09E1_update_game_state               ; skip display of "CREDIT" when in Game Mode

l_099F_update_freeplay_or_credit:

       ld   a,(b8_99B8_credit_cnt)                ; if free-play == $A0  i.e. > 99 (BCD)
       cp   #0xA0

       ld   de,#m_tile_ram + 0x0000 + 0x3C        ; dest of "C" of "CREDIT"

; if (credit_cnt == 0xA0 )  // goto puts_freeplay ...  i.e. > 99 (BCD)
       jr   z,l_09D9_puts_freeplay                ; skip credits status

; else if (credit_cnt < 0xA0 )  // do credit update display
       ld   a,(ds3_99B5_io_input + 0x00)          ; io_input[credit_count]

       ; puts "credit"
       ld   hl,#str_09CA + 6 - 1                  ; source of 'C' in reversed string
       ld   bc,#0x0006                            ; strlen(strCredit)
       lddr
       ; leave the "space" following the 'T'
       dec  e                                     ; de-- advances one cell to the right (note: bottom row, so not de-20!)

       ; if bcd_credit_ct > 9, then rotate "10's" nibble into lower nibble and display it.
       ld   c,a                                   ; save temp hw credit count
       rlca
       rlca
       rlca
       rlca
       and  #0x0F                                 ; only upper digit of BCD credit cnt
       jr   z,l_09C0_putc_ones_place_digit

       ld   (de),a                                ; putc 10's place digit.
       dec  e                                     ; next character position to the right ... 1's place digit

l_09C0_putc_ones_place_digit:
       ld   a,c                                   ; reload saved hw count
       and  #0x0F                                 ; only lower digit of BCD credit cnt
       ld   (de),a                                ; putc 1's place digit.
       ; one more space to be sure two cells are covered.
       dec  e
       ld   a,#0x24
       ld   (de),a

       jr   l_09E1_update_game_state

;;=============================================================================

str_09CA:
; "CREDIT" (reversed)
       .db 0x1D,0x12,0x0D,0x0E,0x1B,0x0C
str_09D0:
; "FREE PLAY" (reversed)
       .db 0x22,0x0A,0x15,0x19,0x24,0x0E,0x0E,0x1B,0x0F


l_09D9_puts_freeplay:
       ld   hl,#str_09D0 + 9 - 1                  ; load src (last byte) of string "FREE PLAY"
       ld   bc,#0x0009
       lddr

l_09E1_update_game_state:

; if ( game_state == GAME_ENDED ) return
       ld   a,(b8_9201_game_state)                ; if Game Ended
       and  a
       ret  z                                     ; 0==GAME_ENDED

; else if ( game_state == ATTRACT_MODE && io_input[credit_count] > 0 )
       dec  a                                     ; ATTRACT_MODE - 1 ==0
       jr   nz,l_09FF_check_credits_used          ; if (!ATTRACT_MODE)

       ld   a,(ds3_99B5_io_input + 0x00)          ; io_input[credit_count]
       and  a
       jr   z,l_09FF_check_credits_used           ; if io_credit_count == 0

; then {
;   game_state = READY_TO_PLAY_MODE
       ld   a,#2
       ld   (b8_9201_game_state),a                ; READY_TO_PLAY ...push start to begin!

       ; memset($9AA0,0,8)
       xor  a
       ld   hl,#ds_9AA0 + 0x00                    ; clear sound-fx count/enable registers (9AA0...9AA7)
       ld   b,#8
       rst  0x18                                  ; memset((HL), A=fill, B=ct)
       ; memset($9AA0+8+1,0,15)
       inc  l                                     ; hl = $9AA0+9, sound-fx cnt/enable regs, 15 bytes, skipped 9AA0[8] (coin-in)
       ld   b,#0x0F
       rst  0x18                                  ; memset((HL), A=fill, B=ct)
; }

l_09FF_check_credits_used:

; A = credits_counted - io_input[credit_count]  ... credits_used
; if ( A == 0 )  return
       ld   a,(ds3_99B5_io_input + 0x00)          ; io_input[credit_count] ... in BCD!
       ld   c,a
       ld   a,(b8_99B8_credit_cnt)                ; BCD
       ld   b,a                                   ; stash the previous credit count
       sub  c
       ret  z                                     ; return if no change of game state

; else  if (io_input[credit_count] > credit_cnt)  goto _update_credit_ct ...
       jr   c,l_0A1A_update_credit_ct             ; Cy is set (credit_hw > credit_ct)

; else  ... if (io_input[credit_count] < credit_cnt) {

;   two_plyr_game = credits_used - 1
       daa                                        ; A == credits_used ... corrected for arithmentic with BCD operands
       dec  a
       ld   (b8_99B3_two_plyr_game),a             ; 0 for 1P, 1 for 2P

;   credit_cnt = io_input[credit_count]
       ld   a,c
       ld   (b8_99B8_credit_cnt),a                ; io_input[credit_count]

;   game_state = IN_GAME_MODE
       ld   a,#3
       ld   (b8_9201_game_state),a                ; 3 (IN_GAME)

       ret
; }

; ...  credits_countd_hw > credit_count_sw
l_0A1A_update_credit_ct:
; credit_cnt = io_input[credit_count]
       ld   a,c                                   ; C==credits_countd_hw (from above)
       ld   (b8_99B8_credit_cnt),a                ; credits_countd_hw

; no coin_in sound for free-play
; if ( credit_cnt == $A0 )  return
       cp   #0xA0
       ret  z
; else ... set global credit count for sound-manager
       sub  b                                     ; B==credit_ct_previous (from above)
       daa
       ld   (b_9A70 + 0x09),a                     ; sndmgr, count of credits-in since last update (triggering coin-in sound)
       ret


;;=============================================================================
;; c_mach_info_add_score()
;;  Description:
;;   Add player score(s) to total at end of game (called once for each player).
;; IN:
;;  DE = ptr to 10's place digit of score in tile RAM.
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_mach_info_add_score:
;  first part packs the 5 digits of the score into BCD using 4 bytes (ones omitted)
       ld   hl,#ds_9100_tmp + 0x03                ; 3 bytes, workspace for converting score to BCD (temporary)
       ld   b,#5
l_0A2C:
       ld   a,(de)
       inc  e
;  if ( char != $24 ) goto 0a33  // if space, then a:=0
       cp   #0x24                                 ; space character
       jr   nz,l_0A33
       xor  a
l_0A33:
       rrd
       bit  0,b
       jr   nz,l_0A3A
       dec  l
l_0A3A:
       djnz l_0A2C

       xor  a
       rrd                                        ; one more rrd to fix the last digit
       dec  l
       ld   (hl),#0                               ; *9100:=0 (score is now "00054321")
       ld   l,#3                                  ; HL:=9103
       ld   de,#b32_99E2_sum_score_bcd + 3
       ld   b,#0x04
       and  a                                     ; clear the carry flag?
l_0A4A:
       ld   a,(de)
       adc  a,(hl)
       daa
       ld   (de),a
       dec  e
       dec  l
       djnz l_0A4A

       ret

;;=============================================================================
;; c_text_out_i_to_d()
;;  Description:
;;   Display an integer value as decimal.
;; IN:
;;   HL: input value (max $FFFF)
;;   DE: points to destination.
;; OUT:
;;   DE: points to (destination - count * 0x40)
;;-----------------------------------------------------------------------------
c_text_out_i_to_d:
       ld   b,#1                                  ; there is at least 1 digit ... (but maybe more)
l_0A55:
; check HL > 10 ... but we can only cp 8 bits in A, so we have to break HL into 2 bytes.
; while ( ( H > 0 )  ...
       dec  h
       inc  h
       jr   nz,l_0A5E
; ... || ( L > $0A ) )
       ld   a,l
       cp   #0x0A                                 ; CY is set if A < $0A

       jr   c,l_0A68

; do: Convert next digit to the "left" (next higher power of 10).
l_0A5E:
       ld   a,#0x0A
       call c_divmod                              ; A=HL%10 (gets a "printable" decimal digit)
       push af                                    ; converted digit returned in A and stacked.
       inc  b                                     ; count of digits in converted decimal number.
       jr   l_0A55

; while ( b > 0 ) ... show digits from left to right
l_0A67:
       pop  af

l_0A68:
; display the value in A as a single decimal digit .. each DE-=$20 advances 1 character to the right
       call c_0A6E
       djnz l_0A67

       ret

c_0A6E:
       ld   (de),a
       jp   rst_DEminus20                         ; it will 'ret' from the jp.
; end 0a53

;;=============================================================================
;; hit_ratio()
;;  Description:
;;   Calculate and display hit/shot ratio.
;; IN:
;;  ...
;; OUT:
;;  DE == resultant pointer to screen ram to be used by caller
;;-----------------------------------------------------------------------------
c_0A72_puts_hitmiss_ratio:

       ld   hl,(ds_plyr_actv +_w_hit_ct)

; if ( shots fired  == 0 )
       ld   de,(ds_plyr_actv +_w_shot_ct)
       ld   a,d
       or   e
       jr   nz,l_0A82
; then
       ld   de,#0x0000                            ; uhh...isn't DE already 0?
       jr   l_0AD3
; else
;   determine ratio: first, use left-shifts to up-scale the dividend and divisor
l_0A82:
l_0A82_while:
; while !(0x80 & d) && !(0x80 & h) de <<= 1, hl <<= 1
       bit  7,d
       jr   nz,l_0A90
       bit  7,h
       jr   nz,l_0A90
       add  hl,hl
       ex   de,hl
       add  hl,hl
       ex   de,hl
       jr   l_0A82_while

; do the actual division with resultant quotient scaled up by factor of 0x0100 to keep precision
l_0A90:
; HL = hl_adjusted_hits / (de_adjusted_shots / 0x0100)
       ld   a,d                                   ; divisor in A
       call c_divmod                              ; HL=HL/A (preserves DE)
       push hl

; HL = modulus / (de_adjusted_shots / 0x0100)
       ld   h,a                                   ; result of HL%A
       ld   l,#0
       ld   a,d                                   ; divisor in A
       call c_divmod                              ; HL=HL/A (preserves DE)

; SP points to lsb of 1st quotient (msb)
       ex   (sp),hl                               ; restore msw (1st quotient) into HL, lsw (2nd quotient) to (SP), (SP+1)
       ld   de,#b16_99B0_tmp                      ; pointer to hit-miss ratio calc.
       ld   b,#4                                  ; loop counter to calculate percentage to 2 decimal places
       ld   a,h                                   ; msb of msw (first quotient), only low 4 bits significant (would be 0 or 1)
       ld   h,#0                                  ; done with this byte
l_0AA5_while:
       ex   de,hl                                 ; pointer->HL, lsb of HL+A -> DE
; 4-bit leftward rotation of the 12-bit number whose 4 most signigifcant bits
; are the 4 least significant bits of A, and its 8 least significant bits are at (HL)
       rld                                        ; rld (hl) ... 1st product msb + sum msb in A
; advance the byte pointer when b==3 (case of b==1 not significant)
       bit  0,b
       jr   z,l_0AAD
       inc  l
l_0AAD:
       ex   de,hl                                 ; lsb of HL+A -> HL, pointer to DE
       call c_0B06                                ; HL *= 10 ... MSB->A
       ex   af,af'                                ; stash 1st product msb

       ex   (sp),hl                               ; 2nd product to HL, 1st product to (SP)
       call c_0B06                                ; HL *= 10 ... MSB->A
       ex   (sp),hl                               ; 1st product to HL, 2nd product to (SP)
       rst  0x10                                  ; HL += A ... 1st product + 2nd product (msb)
       ex   af,af'                                ; 1st product msb -> A, stash sum lsb
       add  a,h                                   ; 1st product msb + sum msb
       ld   h,#0                                  ; done with this byte
       djnz l_0AA5_while

       pop  de                                    ; restore SP

; if (A >= 5)
       cp   #5
       jr   c,l_0AD7
; then
       ld   de,(b16_99B0_tmp)                     ; temp register for hit-miss ratio calc.
       ld   a,d                                   ; msb (99B1) ... but its really LSB
       add  a,#1
       daa
       ld   d,a
;  if
       jr   nc,l_0AD3
;  then
       ld   a,e
       add  a,#1
       daa
       ld   e,a
;  fi

l_0AD3:
       ld   (b16_99B0_tmp),de                     ; tmp computed hit-miss ratio (BCD)
; setup for display of computed ratio
l_0AD7:
       ld   b,#4
       ld   c,#0                                  ; use <:1> as flag
       ld   hl,#b16_99B0_tmp                      ; &hitratio.b0 (BCD)
       ld   de,#m_tile_ram + 0x0120 + 0x18

; loop to putc 4 characters (XXX.X)
l_0AE1_while:
; if ( b==1 ) then ...
       dec  b
       jr   nz,l_0AE8
; ... show dot character left of to 10ths place
       ld   a,#0x2A                               ; '.' (dot) character.
       ld   (de),a
       rst  0x20                                  ; DE-=$20 (next column)

l_0AE8:
       inc  b                                     ; restore B from test at l_0AE1

       xor  a                                     ; clear A before rotating H<7:4> into it
       rld                                        ; rld (hl) ... (HL<7:4>) to A<3:0> ... HL used as pointer

; if (b == 3 || b==1) advance pointer to .b1  ... b==1 irrelevant
       bit  0,b                                   ; even count of b
       jr   z,l_0AF1
       inc  l                                     ; HL++

l_0AF1:
; line up the shots/hits/ratio on the left - once we have A!=0, latch the
; state and keep going
; if ( A != 0 )
       and  a
       jr   nz,l_0AF8
; || (0 != C & 0x01) ...
       bit  0,c                                   ; check flag
       jr   z,l_0AFC
; ... then
l_0AF8:
       set  0,c                                   ; set flag
       ld   (de),a
       rst  0x20                                  ; DE-=$20 (next column)

l_0AFC:
; b==3 is first digit left of decimal (10's place) so it has to start here regardless
; if ( B != 3 )
       ld   a,b
       cp   #3
       jr   nz,l_0B03
; else
       set  0,c
l_0B03:
       djnz l_0AE1_while

       ret

;;=============================================================================
;; c_0B06()
;;  Description:
;;   multiply by 10
;; IN:
;;   HL = 16-bit factor
;;   A  = 8-bit factor
;; OUT:
;;   HL = (HL * $0A) & 0x00FF
;;    A = (HL * $0A) >> 8 ... MSB
;;
;;-----------------------------------------------------------------------------
c_0B06:
       ld   a,#0x0A
       call c_104E_mul_16_8                       ; HL = HL * A
       ld   a,h
       ld   h,#0x00                               ; %256
       ret


_l_0B0F:
;          1000  c_1000

;;
