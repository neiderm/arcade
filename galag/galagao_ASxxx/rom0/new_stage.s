;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; new_stage.s:
;;  gg1-3.2m, 'maincpu' (Z80)
;;
;;  table data management for the game stages
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.module new_stage

.include "structs.inc"
.include "exvars.inc"
.include "exfuncs.inc"

;.area ROM (ABS,OVR)
; .org 0x2C00
.area CSEG2C

;;=============================================================================
;; c_2C00()
;;  Description:
;;   new stage setup
;;   selects data table based on level and difficulty setting
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_2C00:

       ld   a,(ds_plyr_actv +_b_stgctr)           ; new stage setup
l_2C03:
; while (A > 0x1B)  A -= 4
       cp   #0x1B
       jr   c,l_2C0B                              ; goto 2C0B
       sub  #4
       jr   l_2C03

; E = ( adj_stg_cnt - 1 ) + adj_stg_cnt * 4  ... multiply by 5
l_2C0B:
       dec  a
       ld   l,a
       rlca
       rlca
       add  a,l
       ld   e,a

; pTbl = flt_dat_atk_ptns_lut[mchn_cfg.rank]
       ld   a,(b_mchn_cfg_rank)
       ld   hl,#flt_dat_atk_ptns_lut              ; ld the table of ptrs
       rst  0x08                                  ; HL += 2A
       ld   a,(hl)
       inc  hl
       ld   h,(hl)
       ld   l,a

; pTbl[E];
       ld   a,e
       rst  0x10                                  ; HL += A

       ld   de,#ds_new_stage_parms + 0x00
       ld   b,#5
l_2C23:
       ld   a,(hl)
       ld   c,a                                   ; stash data byte
; new_stage_parms[L * 2 + 0] = upper nibble
       rlca
       rlca
       rlca
       rlca
       and  #0x0F
       ld   (de),a
; new_stage_parms[L * 2 + 1] = lower nibble
       inc  e
       ld   a,c                                   ; retrieve data byte
       and  #0x0F
       ld   (de),a
; increment pointers
       inc  e
       inc  hl
       djnz l_2C23

; set ds_new_stage_parms[0x05]
       ld   a,(ds_plyr_actv +_b_stgctr)           ; new stage setup
; if ( stage_ctr < 3 )  A = 0 ...
       cp   #3
       jr   nc,l_2C3F
; ... then
       xor  a
       jr   l_2C46
l_2C3F:
; else if 0xFF == (plyr_state_actv.stage_ctr | 0x0FC)
       or   #0xFC                                 ; challenge stages numbered so that bit_0 + bit_1 == 11b
       inc  a
       jr   z,l_2C46
; ... then
       ld   a,#0x0A                               ; non-challenge stage

l_2C46:
       ld   (de),a                                ; ds_new_stage_parms[5 * 2] ... 99CA

; 16 02 02
       ld   bc,#0x0216
       ld   (b_92C0 + 0x01),bc                    ; = $0216
       ld   (b_92C0 + 0x00),bc                    ; = $0216

; adjust star speed

;  A = (stage_ctr < $10) : stage_ctr ? $10
       ld   a,(ds_plyr_actv +_b_stgctr)           ; limit is 10
       cp   #0x10
       jr   c,l_2C5B
       ld   a,#0x10
l_2C5B:
       rlca
       rlca
       and  #0x70
       add  a,#0x40
       ld   (ds_99B9_star_ctrl + 0x02),a

       ret

;;=============================================================================
; selected table is by difficulty (rank) configured by dip switch setting
;;-----------------------------------------------------------------------------
flt_dat_atk_ptns_lut:
;  .dw db_2CEF,db_2D71,db_2DF3,db_2C6D
  .dw db_2C6D + 0x82 * 1
  .dw db_2C6D + 0x82 * 2
  .dw db_2C6D + 0x82 * 3
  .dw db_2C6D + 0x82 * 0

; each of these table entries if $82 (130) bytes
; $1A unique stages, 5 bytes per entry, 1 parameter per nibble
db_2C6D:
  .db 0x00,0x00,0x22,0xC6,0x00,0x00,0x11,0x23,0xC7,0x00,0x00,0x00,0x00
  .db 0xC0,0x00,0x11,0x12,0x23,0x97,0x00,0x11,0x23,0x23,0x98,0x00,0x21
  .db 0x24,0x33,0x98,0x00,0x00,0x00,0x00,0x90,0x00,0x22,0x25,0x33,0x99
  .db 0x10,0x22,0x36,0x34,0x69,0x10,0x10,0x11,0x23,0x97,0x00,0x00,0x00
  .db 0x00,0x60,0x00,0x32,0x46,0x34,0x67,0x11,0x32,0x67,0x44,0x68,0x11
  .db 0x32,0x67,0x45,0x68,0x11,0x00,0x00,0x00,0x60,0x00,0x42,0x78,0x45
  .db 0x69,0x11,0x42,0x78,0x45,0x69,0x11,0x11,0x22,0x23,0x97,0x11,0x00
  .db 0x00,0x00,0x60,0x00,0x52,0x88,0x46,0x3A,0x11,0x52,0x88,0x56,0x3A
  .db 0x11,0x52,0x88,0x56,0x3C,0x11,0x00,0x00,0x00,0x30,0x00,0x62,0x89
  .db 0x57,0x3C,0x11,0x62,0x99,0x57,0x3C,0x11,0x62,0x99,0x57,0x3C,0x11

;db_2CEF:
  .db 0x00,0x00,0x12,0xC6,0x00,0x00,0x11,0x22,0xC6,0x00,0x00,0x00,0x00
  .db 0xC0,0x00,0x11,0x12,0x23,0x97,0x00,0x11,0x12,0x23,0x97,0x00,0x00
  .db 0x11,0x23,0xC7,0x00,0x00,0x00,0x00,0x90,0x00,0x21,0x23,0x33,0x98
  .db 0x10,0x21,0x24,0x33,0x98,0x10,0x21,0x25,0x34,0x98,0x10,0x00,0x00
  .db 0x00,0x60,0x00,0x22,0x25,0x34,0x68,0x11,0x32,0x36,0x44,0x68,0x11
  .db 0x11,0x11,0x23,0x67,0x01,0x00,0x00,0x00,0x60,0x00,0x32,0x36,0x45
  .db 0x68,0x11,0x32,0x46,0x45,0x69,0x11,0x32,0x67,0x45,0x69,0x11,0x00
  .db 0x00,0x00,0x60,0x00,0x42,0x67,0x46,0x3A,0x11,0x42,0x78,0x56,0x3A
  .db 0x11,0x52,0x78,0x56,0x3A,0x11,0x00,0x00,0x00,0x30,0x00,0x52,0x88
  .db 0x56,0x3C,0x11,0x62,0x99,0x57,0x3C,0x11,0x62,0x99,0x57,0x3C,0x11

;db_2D71:
  .db 0x00,0x00,0x23,0xC6,0x00,0x10,0x11,0x23,0x97,0x00,0x00,0x00,0x00
  .db 0xC0,0x00,0x11,0x12,0x33,0x98,0x00,0x21,0x23,0x34,0x68,0x00,0x21
  .db 0x24,0x34,0x68,0x00,0x00,0x00,0x00,0x90,0x00,0x32,0x36,0x34,0x67
  .db 0x10,0x32,0x46,0x44,0x68,0x10,0x11,0x11,0x23,0x97,0x10,0x00,0x00
  .db 0x00,0x60,0x00,0x42,0x67,0x45,0x68,0x11,0x42,0x67,0x45,0x69,0x11
  .db 0x42,0x78,0x46,0x69,0x11,0x00,0x00,0x00,0x60,0x00,0x52,0x78,0x46
  .db 0x3A,0x11,0x52,0x88,0x56,0x3A,0x11,0x52,0x88,0x56,0x3A,0x11,0x00
  .db 0x00,0x00,0x60,0x00,0x62,0x88,0x56,0x3C,0x11,0x62,0x89,0x57,0x3C
  .db 0x11,0x62,0x89,0x57,0x3E,0x11,0x00,0x00,0x00,0x30,0x00,0x72,0x99
  .db 0x57,0x3E,0x11,0x72,0x99,0x68,0x3E,0x11,0x72,0x99,0x68,0x3E,0x11

;db_2DF3:
  .db 0x00,0x00,0x23,0xC6,0x00,0x10,0x11,0x23,0x97,0x00,0x00,0x00,0x00
  .db 0xC0,0x00,0x11,0x12,0x34,0x98,0x00,0x21,0x23,0x34,0x68,0x00,0x21
  .db 0x24,0x34,0x68,0x00,0x00,0x00,0x00,0x90,0x00,0x32,0x36,0x45,0x67
  .db 0x11,0x32,0x46,0x46,0x68,0x11,0x32,0x56,0x46,0x69,0x11,0x00,0x00
  .db 0x00,0x60,0x00,0x42,0x67,0x56,0x6A,0x11,0x42,0x67,0x56,0x6A,0x11
  .db 0x42,0x78,0x57,0x6A,0x11,0x00,0x00,0x00,0x60,0x00,0x52,0x78,0x57
  .db 0x3A,0x11,0x52,0x88,0x57,0x3A,0x11,0x52,0x88,0x68,0x3C,0x11,0x00
  .db 0x00,0x00,0x60,0x00,0x62,0x88,0x68,0x3C,0x11,0x62,0x89,0x68,0x3C
  .db 0x11,0x62,0x89,0x68,0x3E,0x11,0x00,0x00,0x00,0x30,0x00,0x72,0x99
  .db 0x68,0x3E,0x11,0x72,0x99,0x68,0x3E,0x11,0x72,0x99,0x68,0x3E,0x11


_l_2E75:
;           00003000  c_top5_dlg_proc

;;
