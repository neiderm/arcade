;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; mrw.s:
;;  defines variables in "read-write" memory.
;;
;;  This project provides information about the design of the software
;;  programming of the original Galaga arcade game, (c) 1981 NAMCO LTD.
;;  All files associated with this project are an original documentation
;;  work, copyright 2012 by Glenn A. Neidermeier.
;;
;; Permission is granted to anyone to use the information provided here for
;; any non-commerial purpose with the following restrictions:
;;
;; 1) You are responsible for any legal issues arising from your use of this
;;    information.
;; 2) If any changes are made to any files in this project, they should be
;;    identified as having been modified and by whom.
;;
;;
;;  The build requires the axXXXX assembler (asez80 variant which includes
;;  support for some undocumented opcodes). Code for all 3 Z80 CPUs is
;;  generated from one build by making use of the bank-switching capability of
;;  asXXXX. The linker also allows most of the .org directives to be
;;  eliminated, and instead module placement is controlled by .area directive
;;  and located at link time.
;;
;;  The ROM checksums are also left as commented .db directives, but are
;;  actually generated completely at link time by the remarkable srec_cat tool.
;;
;;
;;  What follows is a catch-all for any additional information...
;;
;;
;;  Sprite hardware SFRs ... I got this information a long long time ago from
;;  MAME version 21.5 or something like that which had the first Galaga driver:
;;
;;   SPRCODE: sprite code/color
;;   8b00-8b7f buffer  8b80-8bff
;;    offset[0]: tile code
;;    offset[1]: color map code
;;
;;   SPRPOSN: sprite position
;;   9300-937f buffer  9380-93ff
;;    offset[0]: sx
;;    offset[1]: sy<0:7>
;;
;;   SPRCTRL: sprite control
;;   9b00-9b7f buffer  9b80-9bff
;;    offset[0]
;;     0: flipx - flip about the X axis, i.e. "up/down"
;;     1: flipy - flip about the Y axis, i.e. "left/right"
;;     2: dblh - MAME may not do dblh unless dblw is also set... (this may not be true)
;;     3: dblw
;;    offset[1]
;;     0: sy<8>
;;     1: enable
;;
;;     Doubling effects seem to copy/mirror the sprite image .. but not always?
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Tile RAM & color RAM layout.
;    Tile rows  0-1:   $8300 - 803F
;    Playfield area:   $8040 - 83BF
;    Tile rows 32-35:  $83C0 - 83FF
;
;    In Tile rows 0,1,32,35, the length is $20 bytes, but 2 bytes at each end
;    are not visible, but it simplifies the math!
;
;    2 bytes |                                     | 2 bytes (not visible)
;   ----------------------------------------------------
;   .3DF     .3DD                              .3C2  .3C0     <- Row 2
;   .3FF     .3FD                              .3E2  .3E0     <- Row 3
;            .3A0-------------------------.060 .040
;              |                             |   |
;            .3BF-------------------------.07F .05F
;   .01F     .01D                              .002  .000     <- Row 0
;   .03F     .03D                              .022  .020     <- Row 1
;

;;=============================================================================
;;  This module implements all the memory read-write blocks, which exist in
;;  a single data address space common to all 3 Z80 CPUs.
;;  The approach taken is that anything here could be moved if the code were
;;  ported to a different platform.
;;  There is a separate file "sfrs.inc" which provides equates for the
;;  addresses of speqcial function registers which are specific to the hardware.
;;  It could be argued that the sprite register blocks should be
;;  handled as simple equates as well.
;;
;;  3 separate .areas are defined here for each of the shared RAM banks located at
;;  $8800, $9000, and $9800 ($0400 bytes each).
;;  Those areas could be located at link time by '-b' arguments to the linker
;;  but relocatable symbols and absolute symbols can't be used in expressions together.
;;-----------------------------------------------------------------------------

.module RAM


;;=============================================================================
;; RAM0
;; Description:
;;   $$0400 bytes, $$8800
;;-----------------------------------------------------------------------------
.area RAM0
;.area MRW (abs,ovr)
;.org $$8800


ds_8800_RAM0:

; Object status structure... 2 bytes per element (indexed same as sprite registers).
;  [ 0 + n ] : object state
;  [ 1 + n ] : byte-offset (index) into bug_motion_que[]

b_8800:
         .ds     $$40 * 2   ; $40 elements

         .ds     $$80       ; unused
; 8900
         .ds     $$20       ; unused

; Space for 5 attack wave setup tables. Each table can vary in size, because
; in each wave there are a varying number of "transients" bug (have no home
; and simply fly off the screen) so each wave has slots for up to 16
; bugs. There are always 8 bugs in each wave that fly "home".
; Each player has a private pointer initialized to offset 0 of this table at
; beginning of each new stage ... actv_plyr_state[0x02]
; Since the table size can vary, the end-of-table is indicated  by $7F.
ds_8920:
         .ds     $$C0       ; $56 bytes used

ds_89E0:
         .ds     $$20       ; data for CPU sub-1 f_0ECA (the unused mystery task)


; Temp vars for _top5_dlg_proc ... gg1-4
b_8A00:
         .ds     $$02       ; ptr to plyr1 score or plyr2 score on screen.
         .ds     $$01       ; L==2, R==8 X=A   previous controller state
         .ds     $$01       ; character selection counter/timer
         .ds     $$02       ; pointer to new name in table
         .ds     $$0A       ; unused
;b_8A10:
         .ds     $$01       ; lower byte of current input character's address in v-ram
         .ds     $$01       ; 1==1ST place etc.
         .ds     $$0E       ; unused

; Top5 Table scores
b_best5_score:

b_best5_score1:
         .ds     $$06
b_best5_score2:
         .ds     $$06
b_best5_score3:
         .ds     $$06
b_best5_score4:
         .ds     $$06
b_best5_score5:
         .ds     $$06

; Top5 Table names
b_best5_name1:
         .ds     $$03       ; 1st score initials
b_best5_name2:
         .ds     $$03       ; 2st score initials
b_best5_name3:
         .ds     $$03       ; 3st score initials
b_best5_name4:
         .ds     $$03       ; 4st score initials
b_best5_name5:
         .ds     $$03       ; 5st score initials

         .ds     $$03       ; unused (8A4D)
         .ds     $$B0       ; unused (8A50)


; origin base of sprite data block
ds_sprite_code:

mrw_sprite_code:
         .ds     $$0040     ; sprite code/color l (buffer)
         .ds     $$0040     ; sprite code/color h (buffer)
sfr_sprite_code:
         .ds     $$0040     ; sprite code/color l ("video" registers)
         .ds     $$0040     ; sprite code/color h ("video" registers)


;;=============================================================================
;; RAM1
;; Description:
;;   $$0400 bytes, $$9000
;;-----------------------------------------------------------------------------
.area RAM1
;.area MRW (abs,ovr)
;.org $$9000


ds_9000_RAM1:

ds_cpu0_task_actv:
         .ds     $$20

ds_cpu1_task_actv:
         .ds     $$08

         .ds     $$08       ; unused

         .ds     $$70       ; stack_cpu_0 (about $30 bytes max)
ds_stk_cpu0_init:
         .ds     $$60       ; stack_cpu_1 (about %18 bytes max)
ds_stk_cpu1_init:


; temp variables that are generally outside the scope of the game proper.
ds_9100:

; temp variables for romtest mgr
ds_rom_test_status:

ds_9100_tmp:

ds_atk_wav_tmp_buf:
         .ds     $$10       ; temp array for c_25A2 ($0100 boundary)

; temp array for Test_menu_proc
b_svc_test_inp_buf:

; roll back the counter
. = ds_9100

; Object movement structures... cpu_sub_1:IX
; Assumes alignment on $0100 boundary.
;  00-07 writes to 92E0, see _2636
;  08-09 ptr to data in cpu-sub-1:4B
;  0D    counter
;  10    index/offset of object .... i.e. 8800 etc.
;  11
;  13
ds_bug_motion_que:
         .ds     $$14 * 12  ; 12 object data structures (total size $F0)

         .ds     $$10       ; 91F0 unused


;;-----------------------------------------------------------------------------
; generic symbol is appropriate for a few references, and unused space clearly
; shown
;;-----------------------------------------------------------------------------
ds_9200:
         .ds     $$60
         .ds     $$10       ; unused

. = ds_9200 ; roll back the PC

;;-----------------------------------------------------------------------------
;; The following motley collection of global variables are situated at
;; odd addresses, apparently becuase the the clever designers didn't want to
;; waste the odd-bytes at 0x9200. At the end of these globals, the instruction
;; counter will be rollled-back and a new label created to define the array of
;; $30 bytes and allow it to be treated as a separate structure.
;;-----------------------------------------------------------------------------
ds_9200_glbls:
         .ds     $$01
b8_9201_game_state:
         .ds     $$01       ; game states (1, 2, 3, 4 from the manual)
                            ; 0==Game Ended   (not described in manual)
                            ; 1==ATTRACT_MODE, 2==READY_TO_PLAY_MODE, 3==PLAY_MODE
                            ; ??==SELF_TEST_MODE  (doesn't have a corresponding enumeration value)
         .ds     $$01
;_b_9203
         .ds     $$01       ; jp table index demo mode
         .ds     $$01
;_b_9205
         .ds     $$01       ; index for text strings, demo
         .ds     $$01
;_b_9207
         .ds     $$01       ; counter, demo
         .ds     $$01
;                           ; state, once near beginning of round (demo or play) $81->$1

;_b_9209                    ; demo only
;                           ; 07DD(sub-1)
         .ds     $$01
         .ds     $$01
;_b_920B
         .ds     $$01       ; conditions for doing flying bug attack
         .ds     $$01       ; 1 at demo mode, 3 at game start (after intro),
                            ; 0 at HEROES screen, 0 when ship appear on training mode, 0 when coin-in,
;_b_920D
         .ds     $$01
         .ds     $$01
;_b_920F
         .ds     $$01       ; flag, bug nest movement left/right
         .ds     $$01       ; 07DD, 1DC1 in game
;_b_9211
         .ds     $$01       ; cp with (b_9A80 + 0x00) in cpu2
         .ds     $$01
;_b_9213
         .ds     $$01       ; restart_stage "end of attack" (all attackers go home)
         .ds     $$01       ; 07DD, 1DC1
b_9215_flip_screen:
         .ds     $$01
         .ds     $$01
;_b_9217
         .ds     $$01

. = ds_9200 ; roll back the PC

;;-----------------------------------------------------------------------------
; Object-collision notification to f_1DB3 from cpu1:c_076A (even-bytes)
;;-----------------------------------------------------------------------------
b_9200_obj_collsn_notif:
         .ds     $$60       ; even bytes ($30 elements)

         .ds     $$10       ; unused


b_svc_test_snd_slctn:
         .ds     $$01
b_svc_eastregg_keyprs_cnt:
         .ds     $$01
w_svc_15sec_tmr:
         .ds     $$02

         .ds     $$0C       ; unused


b_9280:

;;-----------------------------------------------------------------------------
; first take care of temp variables

ds8_9280_tmp_IO_parms:
         .ds     $$08       ; unused
ds3_9288_tmp_IO_data:
         .ds     $$01

;;-----------------------------------------------------------------------------

; roll back the instruction counter
. = b_9280

;;-----------------------------------------------------------------------------
p_attrmode_sptiles:
         .ds     $$02       ; persistent pointer to static sprite tile data for demo (parameter to _sprite_tiles_displ)
pdb_demo_fghtrvctrs:
         .ds     $$02       ; f_1700, tracks state of demo mode by setting an offset to the data table
ds2_stg_chllg_rnd_attrib:   ; attributes selected for hit all 8 bonus on challenge round convoy i.e. score, sprite tile
         .ds     $$01       ; hit-count, add to collsn_hit_mult[0x0F]
         .ds     $$01       ; sprite code and collision flag, ld to obj_collsn_notif[L]
b_bugs_flying_cnt:
         .ds     $$01       ; count of flying pests in flite-q (current frame)
b_bugs_flying_nbr:
         .ds     $$01       ; nbr of flying pests in flite-q (previous frame)

b_bug_flyng_hits_p_round:
         .ds     $$01
b_bug_que_idx:
         .ds     $$01       ; cpu1:f_08D3 local loop counter

ds5_928A_captr_status:
         .ds     $$05       ; [0] status of tractor beam
                            ; [1] status of rescued ship (counter while ship is positioned into collective)
                            ; [2] status of rescued ship
                            ; [3] status of boss that captured ship
                            ; [4] if 1 fighter is captured (show fighter captured text)
         .ds     $$01       ; unused

ds_bug_collsn_hit_mult:
         .ds     $$10       ; hit-count/multiplier from collision manager, see d_scoreman_inc_lut

b_92A0:

ds3_92A0_frame_cts:
         .ds     $$03       ; 3 bytes .... sub1:l_0537
; b8_92A3:
         .ds     $$01       ; ship.dX_flag
; b16_92A4
         .ds     $$02       ; each byte tracks a shot from the ship

; this group all related to tracking number of attackers during a stage
b_bugs_actv_cnt:
         .ds     $$01       ; counts number of active bugs at each frame update (c_23E0)
b_bugs_actv_nbr:
         .ds     $$01       ; total number of active bugs (global)
w_bug_flying_hit_cnt:
         .ds     $$02       ; count down each flying bug hit (only relevant on challenge stg) only the lsb is used.
; b16_92AA
         .ds     $$01       ; flag determines continuous bombing

         .ds     $$01       ; unnused


; global game timer array
ds4_game_tmrs:
         .ds     $$04

b_92B0:
         .ds     $$02 * 8   ; bomb X-rate
                            ; accumulator for division remainder (f_1EA4)

b_92C0:
; bomber activation timers (3 bytes) and init values (3 bytes)
         .ds     $$03
         .ds     $$01  ; unused (force even alignment of following member)
         .ds     $$03
         .ds     $$01  ; unused
         .ds     $$01
         .ds     $$01  ; ?

bmbr_boss_pool:
; 12 bytes in 4 groups of 3 ... slots for boss+wing missions
         .ds     $$0C

b_CPU1_in_progress:
         .ds     $$01
b_CPU2_in_progress:
         .ds     $$01

         .ds     $$08       ; unused

pb_attk_wav_IDs:
         .ds     $$02       ; tmp ptr in c_25A2
b_92E2:
         .ds     $$01       ; _stg_dat[0] e.g. *(26F4) ... c_25A2
         .ds     $$01       ; _stg_dat[1] e.g. *(26F5) ... c_25A2, ld to 0x0f(ix)

         .ds     $$1C       ; unused


; sprite position buffer and SFRs
ds_sprite_posn:

mrw_sprite_posn:
         .ds     $$40       ; sprite position l (buffer)
         .ds     $$40       ; sprite position h (buffer)
sfr_sprite_posn:
         .ds     $$40       ; sprite position l ("video" registers)
         .ds     $$40       ; sprite position h ("video" registers)


;;=============================================================================
;; RAM2
;; Description:
;;   $$0400 bytes, $$9800
;;-----------------------------------------------------------------------------
.area RAM2
;.area MRW (abs,ovr)
;.org $$9800

ds_9800_RAM2:


; Pixel coordinates for object origin positions in the cylon fleet.
ds_hpos_spcoords:

; 10 column coordinates, 6 row coordinates, 16-bits per coordinate.
         .ds     $$20


; see definitions in structs.inc
ds_plyr_data:

ds_plyr_actv:
         .ds     $$40
ds_plyr_susp:
         .ds     $$40

         .ds     $$10       ; unused

ds_susp_plyr_obj_data:
         .ds     $$30       ; resv player game object status tokens (copied from 8800)

ds_cpu0_task_resrv:
         .ds     $$20


; home position locations for objects in the cylon fleet.
; 10 column coordinates, 6 row coordinates, 2-bytes per coordinate.

; even-bytes: offset of home-position coordinate relative to origin
ds_hpos_loc_offs:

; odd-bytes: copy of origin data for access in CPU1 address space (i.e. bits <8:1> of precision coordinate)
ds_hpos_loc_orig:

; struct for home position locations
ds_hpos_loc_t:
         .ds     $$20


; bitmaps for setting up expand/contract motion of group (from defaults at 1E64)
ds10_9920:
         .ds     $$10

         .ds     $$50       ; unused

ds_mchn_cfg:

w_mchn_cfg_bonus:
         .ds     $$02
b_mchn_cfg_nships:
         .ds     $$01
b_mchn_cfg_cab_type:
         .ds     $$01
b_mchn_cfg_rank:
         .ds     $$01

         .ds     $$2B       ; 9985-8F unused
                            ; 9990-AF unused

; 2 bytes temp in hit-miss ratio calc
b16_99B0_tmp:

ds3_99B0_X3attackcfg:

b8_99B0_X3attackcfg_ct:
         .ds     1          ; 3 count for X3 attacker
b8_99B1_X3attackcfg_parm0:
         .ds     1
b8_99B2_X3attackcfg_parm1:
         .ds     1
b8_99B3_two_plyr_game:
         .ds     1          ; 0 for 1P, 1 for 2P
b8_99B4_bugnest_onoff_scrn_tmr:
         .ds     1
ds3_99B5_io_input:
         .ds     3          ; see info in j_Test_menu_proc

b8_99B8_credit_cnt:
         .ds     1

ds_99B9_star_ctrl:
; 99B9: scroll_enable (1 when ship on screen, 0 if stop_scroll)
;_b_99BA
;_b_99BB

; 99BE: star_ctrl_state : value that gets passed to the h/w
         .ds     6

b8_ship_collsn_detectd_status:
         .ds     1

ds_new_stage_parms:
         .ds     $$0A       ; each byte stores 1 nibble of bytes $0 thru $A of table dw_2C65[] (new stage)
         .ds     $$01       ; bonus-bee when bug count reaches $0A (0 for challenge stage)

         .ds     $$15       ; unused

ds20_99E0:
ds10_99E0_mchn_data:
b16_99E0_ttl_plays_bcd:
         .ds     $$02       ; ttl plays bcd
b32_99E2_sum_score_bcd:
         .ds     $$04
b32_99E6_gametime_secs_bcd:
         .ds     $$04
b16_99EA_bonus_ct_bcd:
         .ds     $$02
         .ds     $$14       ; unused


; cpu sub2 memory block ($100 bytes)

; one byte for every sound-effect structure ... sound_fx_status or count?
b_9A00:
         .ds     $$30
; one byte for every sound-effect structure... saves the current data index: sound_fx_idx
b_9A30:
         .ds     $$30
; tmp buffer for copy out values to sound hardware SFRs, frequency and volume SFRs
b_9A60:
         .ds     $$10       ; $10 bytes copied to 6810 (frequency & volume SFRs)
b_9A70:
         .ds     $$03       ; 00: voice 0 wave select
                            ; 01: voice 1 wave select
                            ; 02: voice 2 wave select
         .ds     $$01
         .ds     $$01       ; 04: actv_snd_idx... index of sound currently being processed

         .ds     $$03       ; 05: snd_parms_set[] ... current set of sound parameters copied from snd_parms_dat
                            ;     [0] idx: sound effect index i.e. b_9A00[], b_9A00[$30] and selects pointer to p_snd_fx[] etc
                            ;     [1] count: number of data pairs used by the sound effect data group in this time slice
                            ;     [2] voice_select:
         .ds     $$01       ; 08:
         .ds     $$01       ; 09: global copy of count of additional credits-in since last update for triggering coiin-in sound
         .ds     $$02       ; 0A: tmp pointer to sound-effect data in c_0550
         .ds     $$01       ; 0C: voice 2 volume for capture beam
         .ds     $$01       ; 0D: counter for wave-select (tractor beam)
         .ds     $$01       ; 0E: counter, tracks voice 2 volume change ... capture beam
         .ds     $$01       ; 0F: counter for wave-select (tractor beam)
b_9A80:
         .ds     $$01       ; 00:
         .ds     $$01       ; 01:
         .ds     $$02       ; 02:
         .ds     $$02       ; 04:
         .ds     $$02       ; 06:
         .ds     $$03       ; 08: sound_effect_parms ... 3 bytes from p_snd_fx[ 2 * snd_parms_set.idx ]
                            ;  [0]:
                            ;  [1]:
                            ;  [2]: wave
         .ds     $$05       ; unused
         .ds     $$10       ; unused

ds_9AA0: ; label for pointer+index operations
b_9AA0:
; Most of these registers function as a count/enable for individual sound effects
         .ds     $$01       ; 00:  diving-attacks sound effects
         .ds     $$01       ; 01:  blue-boss hit sound
         .ds     $$01       ; 02:
         .ds     $$01       ; 03:
         .ds     $$01       ; 04:
         .ds     $$01       ; 05:  capture beam sound active uno
         .ds     $$01       ; 06:  capture beam sound active deux
         .ds     $$01       ; 07:
         .ds     $$01       ; 08:  count/enable register ... coin sound
         .ds     $$01       ; 09:  ?
         .ds     $$01       ; 0A:
         .ds     $$01       ; 0B:
         .ds     $$01       ; 0C:
         .ds     $$01       ; 0D:
         .ds     $$01       ; 0R:
         .ds     $$01       ; 0F:
         .ds     $$01       ; 10:
         .ds     $$01       ; 11:  count/enable register ... rescued ship theme
         .ds     $$01       ; 12:
         .ds     $$01       ; 13:
         .ds     $$01       ; 14:
         .ds     $$01       ; 15: clicks for stage tokens
         .ds     $$01       ; 16: sound mgr, hi-score dialog
         .ds     $$01       ; 17: 0 ... enable CPU-sub2 process
         .ds     $$01       ; 18: 1 ... skips CPUsub2 NMI if set (test variable?)
         .ds     $$01       ; 19: !0 ... trigger "bang" sound
         .ds     $$06       ; unused

; Many of these will correspond to _9AA0[] ... indicating if a particular sound is in process.
b_9AC0:
         .ds     $$20       ; Active flags of each sound effect


_stack_cpu_sub2:
         .ds     $$20       ; 9AE0
;_stack_cpu_sub2_init:


; sprite control buffer and SFRs
ds_sprite_ctrl:

mrw_sprite_ctrl:
         .ds     $$40       ; sprite control l (buffer)
         .ds     $$40       ; sprite control h (buffer)
sfr_sprite_ctrl:
         .ds     $$40       ; sprite control l ("video" registers)
         .ds     $$40       ; sprite control h ("video" registers)
;;

