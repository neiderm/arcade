;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; structs.inc
;;  Definitions of macros and other symbols to emulate C-style data structures.
;;


; This bit of macro non-sense autumatically takes care of computing the offset
; to each element using the size argument specified in bytes.
; The base of the structure is defined using a label and the '.ds' directive
; to allocate the storage e.g.
;
;  ld a, (ds_plyr_actv+_nships)
;

.macro _STRUCT
  _offset_ = 0
.endm

.macro _DS _element, _size
   _element = _offset_
   _offset_ = _offset_ + _size
.endm


_STRUCT  ; plyr_state
  _DS  _b_nships             1   ; 0x00  = mchn_cfg_nships
  _DS  _b_stgctr             1   ; 0x01
  _DS  _p_atkwav_tbl         2   ; 0x02  player's private pointer to attack wave object setup tables
  _DS  _b_nestlr_inh         1   ; 0x04  1 or 0 .. flag to f_2A90, if 1 signifies nest left/right movement should stop
  _DS  _b_not_chllg_stg      1   ; 0x05  stg_ctr+1%4 (1 if not challenge stage)
  _DS  _b_attkwv_ctr         1   ; 0x06  atack_wave_ctr++
  _DS  _b_2ship              1   ; 0x07  1 ...player is two-ship

  _DS  _b_bmbr_boss_cobj     1   ; 0x08  object/index of active capturing boss
  _DS  _b_cboss_slot         1   ; 0x09  offset of slot used by capture boss, referenced by cpu0:f_21CB
  _DS  _b_captr_flag         1   ; 0x0A  related to ship-capture status
  _DS  _b_bmbr_boss_cflag    1   ; 0x0B  1 as capturing boss initiates his dive
  _DS  _b_bmbr_boss_wingm    1   ; 0x0C  bomber boss wingman-enable toggled to select boss-bomber mode i.e. capture or wingman

  _DS  _b_bbee_obj           1   ; 0x0D  offset of object that spawns special bonus convoys
  _DS  _b_bbee_clr_a         1   ; 0x0E  flashing color 'A' for special bonus convoys
  _DS  _b_bbee_clr_b         1   ; 0x0F  flashing color 'B' for special bonus convoys

  _DS  _ds_bmbr_boss_scode   8   ; 0x10  bonus code/score attributes e.g. "01B501B501B501B5"
  _DS  _unused               6   ; 0x18-0x1D ?
  _DS  _b_mcfg_bonus         1   ; 0x1E  load at game start from w_mchn_cfg_bonus ... $9980
  _DS  _b_plyr_swap_tmr      1   ; 0x1F  game_tmr_2, player1/2 switch
  _DS  _b_plyr_nbr           1   ; 0x20  0==plyr1, 1==plyr2
  _DS  _b_bbee_tmr           1   ; 0x21  bonus bee launch timer
  _DS  _b_atk_wv_enbl        1   ; 0x22  attack_wave_enable (0 when respawning player ship)
  _DS  _b_enmy_ct_actv       1   ; 0x23  bugs_actv_nbr
  _DS  _w_hit_ct             2   ; 0x24  game number of hits
  _DS  _w_shot_ct            2   ; 0x26  game shots fired count
  _DS  _b_sndflag            1   ; 0x28  enable "pulsing_sound" (_fx[0])

