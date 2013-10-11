;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; gg1-5.s
;;  gg1-5.3f, CPU 'sub' (Z80)
;;
.module cpu_sub

.include "sfrs.inc"
.include "exvars.inc"
.include "structs.inc"

.BANK cpu_sub (BASE=0x000000, FSFX=_sub)
.area ROM (ABS,OVR,BANK=cpu_sub)


.org 0x0000

;;=============================================================================
;; RST_00()
;;  Description:
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
       ld   sp,#ds_stk_cpu1_init
       jp   CPU1_RESET

.org 0x0008

;;=============================================================================
;; RST_08()
;;  Description:
;;
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
       add  a,a
       jr   nc,_RST_10
       inc  h                                     ; when?
       jp   _RST_10

      .org 0x0010

;;=============================================================================
;; RST_10()
;;  Description:
;;   HL += A
;; IN:
;;
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
_RST_10:
       add  a,l
       ld   l,a
       ret  nc
       inc  h                                     ; when?
       ret

.org 0x0018

;;=============================================================================
;; RST_18()
;;  Description:
;;   Is not referenced by rst (when does this get used? - same as sub2 ROM)
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
_RST_18:
       ld   (hl),a
       inc  hl
       djnz _RST_18
       ret


; confirmed that 0032 is read.
dbx001D:
       .db  0x23,0x06,0x16,0x23,0x00,0x19,0xF7,0x4B,0x00,0x23,0xF0
       .db  0x02,0xF0,0x5E,0x00,0x23,0xF0,0x24,0xFB,0x23,0x00,0xFF

; pad (0033)
;      .ds 1

.org 0x0034

;;=============================================================================
;; RST_34()
;;  Description:
;;   Wrapper function to allow normal call/return for task invocation (can't
;;   call to a reference).
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_0034:
       jp   (hl)


.org 0x0038

;;=============================================================================
;; RST_38()
;;  Description:
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
       jp   jp_0513_rst38


.org 0x003B

;;=============================================================================
; Function pointers for periodic tasks on this CPU (ds_cpu1_task_actvbl)
; The following bytes are copied from (d_05B7) to ds_cpu1_task_actvbl[1]
;   0x01,0x01,0x00,0x01,0x01,0x00,0x0A
d_003B_task_table:
       .dw f_05BE  ; null-task (this is the only slot with a "null" task that is enabled.
       .dw f_05BF  ; [1]
       .dw f_08D3  ; [2]
       .dw f_05BE  ; null-task
       .dw f_06F5  ; [4]
       .dw f_05EE  ; [5] ... hit-detection: change to f_05BE for invincibility
       .dw f_05BE  ; null-task
       .dw f_0ECA  ; [7] ... ?


;;=============================================================================
;   2-byte entries, second-byte is an offset into table at $9900
;dbx004B:
       .db 0x23,0xF0,0x26,0x23,0x14
       .db 0x13,0xFE,0x0D,0x0B,0x0A,0x08,0x06,0x04,0x03,0x01,0x23
       .db 0xFF,0xFF,0xFF,0x44,0xE4
       .db 0x18,0xFB,0x44,0x00,0xFF,0xFF,0xC9
dbx0067:
       .db 0x23,0x08,0x08,0x23
       .db 0x03,0x1B,0x23,0x08,0x0F,0x23,0x16,0x15,0xF7,0x84,0x00,0x23,0x16,0x03,0xF0,0x97
       .db 0x00,0x23,0x16,0x19,0xFB,0x23,0x00,0xFF,0xFF,0x23,0x16,0x01,0xFE,0x0D,0x0C,0x0A
       .db 0x08,0x06,0x04,0x03,0x01,0x23,0xFC,0x30,0x23,0x00,0xFF,0xFF,0x44,0x27,0x0E,0xFB
       .db 0x44,0x00,0xFF,0xFF
dbx009F:
       .db 0x33,0x06,0x18,0x23,0x00,0x18,0xF7,0xB6,0x00,0x23,0xF0,0x08
       .db 0xF0,0xCC,0x00,0x23,0xF0,0x20,0xFB,0x23,0x00,0xFF,0xFF,0x23,0xF0,0x20,0x23,0x10
       .db 0x0D,0xFE,0x1A,0x18,0x15,0x10,0x0C,0x08,0x05,0x03,0x23,0xFE,0x30,0x23,0x00,0xFF
       .db 0xFF,0x33,0xE0,0x10,0xFB,0x44,0x00,0xFF,0xFF
dbx00D4:
       .db 0x23,0x03,0x18,0x33,0x04,0x10,0x23
       .db 0x08,0x0A,0x44,0x16,0x12,0xF7,0x60,0x01,0x44,0x16,0x03,0xF0,0x73,0x01,0x44,0x16
       .db 0x1D,0xFB,0x23,0x00,0xFF,0xFF,0x12,0x18,0x17,0x12,0x00,0x80,0xFF,0xFF,0xFF,0xFF
       .db 0xFF,0xFF,0xFF,0xFF,0xFF

; TODO: offsets need to be found...
; 034F: bee
; 03A9: moth
; 0444:
; 046b:  d_cpu1_046B
; 0473: bonus-bee
; 0444: captured rogue ship
; 04AB: bonus-bee
; 04EA: bonus-bee

; Copy of home position LUT from task_man.
db_obj_home_posn_RC:
  .db 0x14,0x06,0x14,0x0c,0x14,0x08,0x14,0x0a,0x1c,0x00,0x1c,0x12,0x1e,0x00,0x1e,0x12
  .db 0x1c,0x02,0x1c,0x10,0x1e,0x02,0x1e,0x10,0x1c,0x04,0x1c,0x0e,0x1e,0x04,0x1e,0x0e
  .db 0x1c,0x06,0x1c,0x0c,0x1e,0x06,0x1e,0x0c,0x1c,0x08,0x1c,0x0a,0x1e,0x08,0x1e,0x0a
  .db 0x16,0x06,0x16,0x0c,0x16,0x08,0x16,0x0a,0x18,0x00,0x18,0x12,0x1a,0x00,0x1a,0x12
  .db 0x18,0x02,0x18,0x10,0x1a,0x02,0x1a,0x10,0x18,0x04,0x18,0x0e,0x1a,0x04,0x1a,0x0e
  .db 0x18,0x06,0x18,0x0c,0x1a,0x06,0x1a,0x0c,0x18,0x08,0x18,0x0a,0x1a,0x08,0x1a,0x0a

; d_0160
  .db 0x44,0x16,0x06,0xfe,0x0c,0x0b,0x0a,0x08,0x06,0x04,0x02,0x01,0x23,0xfe,0x30,0x23
  .db 0x00,0xff,0xff,0x66,0x20,0x14,0xfb,0x44,0x00,0xff,0xff
dbx017B:
  .db 0x23,0x06,0x18,0x23,0x00
  .db 0x18,0xf7,0x92,0x01,0x44,0xf0,0x08,0xf0,0xa8,0x01,0x44,0xf0,0x20,0xfb,0x23,0x00
  .db 0xff,0xff,0x44,0xf0,0x26,0x23,0x10,0x0b,0xfe,0x22,0x20,0x1e,0x1b,0x18,0x15,0x12
  .db 0x10,0x23,0xfe,0x30,0x23,0x00,0xff,0xff,0x66,0xe0,0x10,0xfb,0x44,0x00,0xff,0xff
dbx01B0:
  .db 0x23,0x03,0x20,0x23,0x08,0x0f,0x23,0x16,0x12,0xf7,0xca,0x01,0x23,0x16,0x03,0xf0
  .db 0xe0,0x01,0x23,0x16,0x1d,0xfb,0x23,0x00,0xff,0xff
  .db 0x23,0x16,0x01,0xfe,0x0d,0x0c,0x0b,0x09,0x07,0x05,0x03,0x02,0x23,0x02,0x20,0x23
  .db 0xfc,0x12,0x23,0x00,0xff,0xff,0x44,0x20,0x14,0xfb,0x44,0x00,0xff,0xff
dbx01E8:
  .db 0x23,0x00,0x10,0x23,0x01,0x40,0x22,0x0c,0x37,0x23,0x00,0xff,0xff
dbx01F5:
  .db 0x23,0x02,0x3a,0x23,0x10,0x09,0x23,0x00,0x18,0x23,0x20
  .db 0x10,0x23,0x00,0x18,0x23,0x20,0x0d,0x23,0x00,0xff,0xff
dbx020B:
  .db 0x23,0x00,0x10,0x23,0x01,0x30,0x00,0x40,0x08,0x23,0xff,0x30,0x23,0x00,0xff,0xff
dbx021B:
  .db 0x23,0x00,0x30,0x23,0x05,0x80,0x23,0x05,0x4c,0x23,0x04,0x01,0x23,0x00,0x50,0xff
dbx022B:
  .db 0x23,0x00,0x28,0x23,0x06,0x1d,0x23,0x00,0x11,0x00,0x40,0x08,0x23,0x00,0x11,0x23
  .db 0xfa,0x1d,0x23,0x00,0x50,0xff
dbx0241:
  .db 0x23,0x00,0x21,0x00,0x20,0x10,0x23,0xf8,0x20,0x23,0xff,0x20,0x23,0xf8,0x1b
  .db 0x23,0xe8,0x0b,0x23,0x00,0x21,0x00,0x20,0x08,0x23,0x00,0x42,0xff
dbx025D:
  .db 0x23,0x00,0x08,0x00,0x20,0x08,0x23,0xf0,0x20,0x23,0x10,0x20,0x23,0xf0,0x40,0x23
  .db 0x10,0x20,0x23,0xf0,0x20,0x00,0x20,0x08,0x23,0x00,0x30,0xff
dbx0279:
  .db 0x23,0x10,0x0c,0x23,0x00,0x20,0x23
  .db 0xe8,0x10,0x23,0xf4,0x10,0x23,0xe8,0x10,0x23,0xf4,0x32,0x23,0xe8,0x10,0x23,0xf4
  .db 0x32,0x23,0xe8,0x10,0x23,0xf4,0x10,0x23,0xe8,0x0e,0x23,0x02,0x30,0xff
dbx029E:
  .db 0x23,0xf1,0x08,0x23,0x00,0x10,0x23,0x05,0x3c,0x23,0x07,0x42,0x23,0x0a,0x40,0x23
  .db 0x10,0x2d,0x23,0x20,0x19,0x00,0xfc,0x14,0x23,0x02,0x4a,0xff
dbx02BA:
  .db 0x23,0x04,0x20,0x23,0x00,0x16,0x23,0xf0,0x30,0x23,0x00,0x12,0x23,0x10,0x30,0x23
  .db 0x00,0x12,0x23,0x10,0x30,0x23,0x00,0x16,0x23,0x04,0x20,0x23,0x00,0x10,0xff
dbx02D9:
  .db 0x23,0x00,0x15,0x00,0x20,0x08,0x23
  .db 0x00,0x11,0x00,0xe0,0x08,0x23,0x00,0x18,0x00,0x20,0x08,0x23,0x00,0x13,0x00,0xe0
  .db 0x08,0x23,0x00,0x1f,0x00,0x20,0x08,0x23,0x00,0x30,0xff
dbx02FB:
  .db 0x23,0x02,0x0e,0x23,0x00
  .db 0x34,0x23,0x12,0x19,0x23,0x00,0x20,0x23,0xe0,0x0e,0x23,0x00,0x12,0x23,0x20,0x0e
  .db 0x23,0x00,0x0c,0x23,0xe0,0x0e,0x23,0x1b,0x08,0x23,0x00,0x10,0xff
dbx031D:
  .db 0x23,0x00,0x0d,0x00,0xc0,0x04,0x23,0x00,0x21,0x00,0x40,0x06,0x23,0x00,0x51,0x00
  .db 0xc0,0x06,0x23,0x00,0x73,0xff
dbx0333:
  .db 0x23,0x08,0x20,0x23,0x00,0x16,0x23,0xe0,0x0c,0x23,0x02,0x0b,0x23
  .db 0x11,0x0c,0x23,0x02,0x0b,0x23,0xe0,0x0c,0x23,0x00,0x16,0x23,0x08,0x20,0xff
dbx034F:
  .db 0x12
  .db 0x18,0x1e,0x12,0x00,0x34,0x12,0xfb,0x26,0x12,0x00,0x02,0xfc,0x2e,0x12,0xfa,0x3c
  .db 0xfa,0x9e,0x03,0x12,0xf8,0x10,0x12,0xfa,0x5c,0x12,0x00,0x23,0xf8,0xf9,0xef,0x7c
  .db 0x03,0xf6,0xab,0x12,0x01,0x28,0x12,0x0a,0x18,0xfd,0x52,0x03,0xf6,0xb0,0x23,0x08
  .db 0x1e,0x23,0x00,0x19,0x23,0xf8,0x16,0x23,0x00,0x02,0xfc,0x30,0x23,0xf7,0x26,0xfa
  .db 0x9e,0x03,0x23,0xf0,0x0a,0x23,0xf5,0x31,0x23,0x00,0x10,0xfd,0x6c,0x03,0x12,0xf8
  .db 0x10,0x12,0x00,0x40,0xfb,0x12,0x00,0xff,0xff
dbx03A9:
  .db 0x12,0x18,0x1d,0x12,0x00,0x28,0x12
  .db 0xfa,0x02,0xf3,0x3f,0x3b,0x36,0x32,0x28,0x26,0x24,0x22,0x12,0x04,0x30,0x12,0xfc
  .db 0x30,0x12,0x00,0x18,0xf8,0xf9,0xfa,0x0c,0x04,0xef,0xd7,0x03,0xf6,0xb0,0x12,0x01
  .db 0x28,0x12,0x0a,0x15,0xfd,0xac,0x03,0xf6,0xc0,0x23,0x08,0x10,0x23,0x00,0x23,0x23
  .db 0xf8,0x0f,0x23,0x00,0x48,0xf8,0xf9,0xfa,0x0c,0x04,0xf6,0xb0,0x23,0x08,0x20,0x23
  .db 0x00,0x08,0x23,0xf8,0x02,0xf3,0x34,0x31,0x2d,0x29,0x22,0x26,0x1f,0x18,0x23,0x08
  .db 0x18,0x23,0xf8,0x18,0x23,0x00,0x10,0xf8,0xf9,0xfd,0xcc,0x03,0xfb,0x12,0x00,0xff
  .db 0xff,0x12,0x18,0x14,0x12,0x03,0x2a,0x12,0x10,0x40,0x12,0x01,0x20,0x12,0xfe,0x71
  .db 0xf9,0xf1,0xfa,0x0c,0x04,0xef,0x30,0x04,0xf6,0xab,0x12,0x02,0x20,0xfd,0x14,0x04
  .db 0xf6,0xb0,0x23,0x04,0x1a,0x23,0x03,0x1d,0x23,0x1a,0x25,0x23,0x03,0x10,0x23,0xfd
  .db 0x48,0xfd,0x20,0x04
dbx0444:
  .db 0x12,0x18,0x14,0x12,0x03,0x2a,0x12,0x10,0x40,0x12,0x01,0x20
  .db 0x12,0xfe,0x78,0xff,0x12,0x18,0x14,0xf4,0x12,0x00,0x04,0xfc,0x48,0x00,0xfc,0xff
  .db 0x23,0x00,0x30,0xf8,0xf9,0xfa,0x0c,0x04,0xfd,0x25,0x04
dbx046B:
  .db 0x12,0x18,0x14,0xfb,0x12
  .db 0x00,0xff,0xff,0x12,0x18,0x1e,0x12,0x00,0x08,0xf2,0x99,0x04,0x00,0x00,0x0a,0xf2
  .db 0x99,0x04,0x00,0x00,0x0a,0x12,0x00,0x2c,0x12,0xfb,0x26,0x12,0x00,0x02,0xfc,0x2e
  .db 0x12,0xfa,0x3c,0xfa,0x9e,0x03,0xfd,0x63,0x03,0x12,0x00,0x2c,0x12,0xfb,0x26,0x12
  .db 0x00,0x02,0xfc,0x2e,0x12,0xfa,0x18,0x12,0x00,0x10,0xff,0x12,0x18,0x13,0xf2,0xc6
  .db 0x04,0x00,0x00,0x08,0xf2,0xcf,0x04,0x00,0x00,0x08,0x12,0x18,0x0b,0x12,0x00,0x34
  .db 0x12,0xfb,0x26,0xfd,0x58,0x03,0x12,0x00,0x10,0x12,0x18,0x0b,0xfd,0xd8,0x04,0x12
  .db 0x00,0x08,0x12,0x18,0x0b,0x12,0x00,0x06,0x12,0x00,0x22,0x12,0xfb,0x26,0x12,0x00
  .db 0x02,0xfc,0x2e,0x12,0xfa,0x18,0x12,0x00,0x20,0xff,0x12,0x18,0x1e,0x12,0x00,0x14
  .db 0xf2,0x02,0x05,0x12,0x00,0x08,0xf2,0x02,0x05,0x12,0x00,0x18,0x12,0xfb,0x26,0xfd
  .db 0x58,0x03,0x12,0xe2,0x01,0xf3,0x08,0x07,0x06,0x05,0x04,0x03,0x02,0x01,0xf5,0x23
  .db 0x00,0x48

; pad
  .db 0xFF

;;=============================================================================
;; jp_0513_rst38()
;;  Description:
;;    RST $0038 handler.
;;    The first part uses vsync signal to develop clock references.
;;      ds3_92A0_frame_cts[0]: 60Hz (base rate)
;;      ds3_92A0_frame_cts[1]:  2Hz (div 32)
;;      ds3_92A0_frame_cts[2]:  4Hz (div 16)
;;    The counters are not reset in the course of the game operation.
;;
;;    For efficiency, bit masking is used instead of division so the real base
;;    period is 64 which is close enough to 60Hz.
;;
;;    Note: frame_cts[2] is used as baserate to 4 Game Timers in CPU0:f_1DD2
;;   (rescaled to develop a 2Hz clock)

;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
jp_0513_rst38:
       xor  a
       ld   (_sfr_6821),a                         ; 0 ...CPU-sub1 IRQ acknowledge/enable
       ld   a,(_sfr_dsw5)                         ; DSWA: freeze video
       and  #0x02                                 ; freeze_ctrl_dsw (6j)
       jp   z,l_0575                              ; if paused, goto 0575 // done

; frame_cntr++
       ld   a,(ds3_92A0_frame_cts + 0)
       inc  a
       ld   (ds3_92A0_frame_cts + 0),a            ; +=1

; L==t[1], H==t[2]
       ld   hl,(ds3_92A0_frame_cts + 1)           ; load 16-bits

; if ( cnt % 20 == 1 ) ... update 4Hz (H) only
       and  #0x1F                                 ; MOD $20
       dec  a
       jr   z,l_0536

; else  if ( cnt % 20 == 0 ) ...
       inc  a                                     ; restores original value and allows test for 0
       jr   nz,l_0537                             ; A!=0 && A!=1 .... do nothing (why reload from HL?)
; ...
; Before incrementing 4Hz, assert that 4Hz is ODD on frame where _92A0[0] increments to 0.
       ld   a,h                                   ; t[2] ... MSB
       or   #0x01
       ld   h,a

; update both 4Hz and 2Hz
       inc  l                                     ; t[1] = L++ ... 2Hz
l_0536:
       inc  h                                     ; t[2] = H++ ... 4Hz
l_0537:
       ld   (ds3_92A0_frame_cts + 1),hl           ; [1]: 32-frame ... ~2Hz timer
                                                  ; [2]: 16-frame ... ~4Hz timer

; flag = ( num_bugs < param07 ) & ds_cpu0_task_actv[0x15]
       ld   a,(ds_new_stage_parms + 0x07)         ; 2C30
       ld   e,a
       ld   a,(b_bugs_actv_nbr)
       cp   e
       rl   b                                     ; Cy set if E > A ... shift into B ... clever.
       ld   a,(ds_cpu0_task_actv + 0x15)          ; cpu0:f_1F04 (reads fire button input)
       and  b
       and  #0x01                                 ; mask off bit-0
; then ...
       ld   (b_92A0 + 0x0A),a

; find the first ready task.. may run more than one.
       ld   c,#0
l_054F_while:
       ld   hl,#ds_cpu1_task_actv
       ld   a,c
       add  a,l
       ld   l,a
       ld   a,(hl)
       and  a
       jr   nz,l_055C
       inc  c
       jr   l_054F_while

l_055C:
       ld   b,a                                   ; A == task status
       ld   hl,#d_003B_task_table
       ld   a,c                                   ; C == task index
       sla  a                                     ; *=2 ... (sizeof pointer)
       add  a,l
       ld   l,a
       ld   e,(hl)
       inc  hl
       ld   d,(hl)
       ex   de,hl
       push bc

       call c_0034
       pop  bc
       ld   a,b                                   ; "status" actually adds to index
       add  a,c
       ld   c,a
       and  #0xF8                                 ; if index < 8 then repeat loop
       jr   z,l_054F_while

l_0575:
       ld   a,#1
       ld   (_sfr_6821),a                         ; 1 ...CPU-sub1 IRQ acknowledge/enable
       ei
       ret

;;=============================================================================
;; RESET()
;;  Description:
;;   entry point from RST 00
;;   Tests the ROM space (length $1000)
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
CPU1_RESET:
       ld   de,#ds_rom_test_status + 0x00         ; pause/resume flag

; wait for master CPU to acknowledge/resume (0)
l_057F:
       ld   a,(de)
       and  a
       jr   nz,l_057F

; compute ROM checksum
       ld   h,a
       ld   l,a
       ld   bc,#0x0010                            ; Sets B as inner loop count ($100) and C as outer ($10)
l_0588:
       add  a,(hl)
       inc  hl
       djnz l_0588
       dec  c
       jr   nz,l_0588
       cp   #0xFF
       jr   z,l_0595
       ld   a,#0x11                               ; set error code

l_0595:
       ld   (de),a                                ; copy checksum result to the global variable

; wait for master to acknowledge/resume (0)
l_0596:
       ld   a,(de)
       and  a
       jr   nz,l_0596

       im   1

       xor  a
       ld   (ds_89E0),a                           ; 0

; set task-enable defaults
       ld   hl,#d_05B7
       ld   de,#ds_cpu1_task_actv + 1             ; cp $07 bytes (d_05B7)
       ld   bc,#0x0007
       ldir

       ld   a,#1
       ld   (_sfr_6821),a                         ; 1 ... IRQ acknowledge/enable
       ei

l_05B1:
       ld   sp,#ds_stk_cpu1_init
       jp   l_05B1                                ; loop forever

;;=============================================================================
; init data for (ds_cpu1_task_actvbl + 0x01)
d_05B7:
       .db 0x01,0x01,0x00,0x01,0x01,0x00,0x0A

;;=============================================================================
;; f_05BE()
;;  Description:
;;   null task
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
f_05BE:
       ret

;;=============================================================================
;; f_05BF()
;;  Description:
;;   works in conjunction with f_0828 of main CPU to update sprite RAM
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
f_05BF:
       ld   a,#1
       ld   (b_CPU2_in_progress),a                ; 1

       ld   hl,#mrw_sprite_code
       ld   de,#sfr_sprite_code
       ld   bc,#0x0040
       ldir
       ld   hl,#mrw_sprite_posn
       ld   de,#sfr_sprite_posn
       ld   c,#0x40
       ldir
       ld   hl,#mrw_sprite_ctrl
       ld   de,#sfr_sprite_ctrl
       ld   c,#0x40
       ldir

       xor  a
       ld   (b_CPU2_in_progress),a                ; 0

l_05E7_while_wait_for_main_CPU:
       ld   a,(b_CPU1_in_progress)
       dec  a
       jr   z,l_05E7_while_wait_for_main_CPU

       ret

;;=============================================================================
;; f_05EE()
;;  Description:
;;    Manage ship collision detection
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
f_05EE:
; if ( task_state == inactive ) return
       ld   a,(ds_cpu0_task_actv + 0x14)          ; f_1F85 (input and ship movement)
       and  a
       ret  z

       ld   (ds_9200_glbls + 0x17),a              ; :=1  (flag ...ship-input-movement active, and we are doing collisn detect)

; if ( ! plyr_is_two_ship )
       ld   a,(ds_plyr_actv +_b_2ship)
       and  a
       jr   z,l_0613

; else ... Handle 2-ship configuration
       ld   hl,#ds_sprite_posn + 0x60             ; ship2 position
       ld   a,(hl)
       and  a
       jr   z,l_0613

       call c_0681_ship_collisn_detectn_runner    ; HL == &sprite_posn_base[0x60]  ...ship2 position
       ld   a,(b8_ship_collsn_detectd_status)     ; collision detected (ship 2)
       and  a
       jr   z,l_0613
;60c
       call c_0649                                ; handle ship 2 collision
       xor  a
       ld   (ds_plyr_actv +_b_cboss_dive_start),a ; 0

l_0613:
; if ( ship position == 0 ) return
       ld   hl,#ds_sprite_posn + 0x62             ; ship (1) position
       ld   a,(hl)
       and  a
       ret  z

       call c_0681_ship_collisn_detectn_runner    ; HL == sprite_posn_base + 0x62 ... ship (1) position
       ld   a,(b8_ship_collsn_detectd_status)     ; collision detected (ship 1)
       and  a
       ret  z

; 621 bug or bomb collided with ship
       ld   a,(ds_plyr_actv +_b_2ship)
       and  a
       jr   z,l_0639_not_two_ship

       xor  a
       ld   (ds_plyr_actv +_b_cboss_dive_start),a ; 0
       ld   a,(ds_sprite_posn + 0x60)             ; get ship 2 position
       ld   (ds_sprite_posn + 0x62),a             ; ship_1_position = ship_2_position
       ld   a,(sfr_sprite_posn + 0x62)
       ld   hl,#sfr_sprite_posn + 0x60
       jr   l_064F                                ; handle ship collision

l_0639_not_two_ship:
       xor  a
       ld   (ds_cpu0_task_actv + 0x14),a          ; 0
       ld   (ds_cpu0_task_actv + 0x15),a          ; 0
       ld   (ds_cpu1_task_actv + 0x05),a          ; 0  (cpu1:f_05EE)
       ld   (ds_99B9_star_ctrl + 0x00),a          ; 0  (1 when ship on screen)
       ld   (ds_9200_glbls + 0x17),a              ; 0

; handle ship collision (single-ship player)
; HL == &sprite_posn_base[0x62] ... ship (1) position

;;=============================================================================
;; c_0649()
;;  Description:
;;   called from f_05EE to handle Ship 2 collision.
;;   continues from f_05EE to handle ship 1 collision
;; IN:
;;   HL == &sprite_posn_base[0x60]  ...ship2 position (if call c_0649)
;;   HL == &sprite_posn_sfr[0x60] ... (if jp  l_064F)
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_0649:
       ex   de,hl
       ld   h,#>ds_sprite_posn
       set  7,l
       ld   a,(hl)

l_064F:
       sub  #8
       res  7,l
       ld   (hl),a
       inc  l
       ld   a,(hl)
       sub  #8
       ld   (hl),a
       ld   h,#>ds_sprite_code
       ld   (hl),#0x0B
       dec  l
       ld   (hl),#0x20
       ld   h,#>b_8800
       ld   (hl),#8
       inc  l
       ld   (hl),#0x0F
       dec  l
       ld   h,#>ds_sprite_ctrl
       ld   (hl),#0x0C
       xor  a
       ld   (ds_plyr_actv +_b_2ship),a            ; 0

       ld   a,(b8_9201_game_state)
       dec  a
       ld   (b_9AA0 + 0x19),a                     ; sound-fx count/enable registers, "bang" sound (not in Attract Mode)

; if ship-input-movement is active
       ld   a,(ds_9200_glbls + 0x17)              ; flag ... ship-input-movement is active
       and  a
       ret  nz
; else
       inc  a
       ld   (ds_9200_glbls + 0x13),a              ; 1  ...restart stage flag (because ship-input-movement flag not active )
       ret

;;=============================================================================
;; c_0681_ship_collisn_detectn_runner()
;;  Description:
;;   Sets up collision detection.
;; IN:
;;  HL == &sprite_posn_base[offset]
;;        ...where offset is either SHIP1 (or SHIP2)
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_0681_ship_collisn_detectn_runner:
       xor  a
       ld   (b8_ship_collsn_detectd_status),a     ; :=0 ... initialize flag

       ld   h,#>b_8800
       ld   a,(hl)
       ld   h,#>ds_sprite_posn
       cp   #8                                    ; ship is in status 08 if it is already terminally ill...
       ret  z                                     ; ... so gtf out!

       ld   a,(hl)
       ld   ixl,a
       inc  l
       ld   b,(hl)                                ; get row bits 0:7
       ld   h,#>ds_sprite_ctrl                    ; get row bit-8
       ld   a,(hl)
       rrca
       rr   b
       ld   ixh,b
       dec  l
       ld   e,l

; if ( cpu0:f_2916 ! active ) {
       ld   a,(ds_cpu0_task_actv + 0x08)          ; cpu0:f_2916 ...supervises attack waves
       and  a
       jr   z,l_06A8
; } else {
;      attack wave active, set these parameters...
       ld   l,#0x38                               ; clone (bonus) bees and transients
       ld   b,#0x04                               ; 4 of them
       jr   l_06AC_
; }
l_06A8:
;      attack wave NOT active, set these parameters...
       ld   l,#0x00                               ; bugs
       ld   b,#0x30                               ; $30 of them
l_06AC_:
       call c_06B7_ship_collsn_detecn

       ld   l,#0x68                               ; bombs
       ld   b,#0x08                               ; 8 of them
       call c_06B7_ship_collsn_detecn

       ret

;;=============================================================================
;; c_06B7_ship_collsn_detecn()
;;  Description:
;;   Do ship collision detection.
;; IN:
;;  L==starting offset from 9200 in HL
;;  B==repeat count ($08 or $30)
;;  IX==
;; OUT:
;;  b8_ship_collsn_detectd_status
;;-----------------------------------------------------------------------------
c_06B7_ship_collsn_detecn:
while_06B7:
       ld   h,#>b_9200_obj_collsn_notif
       ld   a,(hl)
       ld   h,#>b_8800
       or   (hl)
       rlca
       jr   c,l_06F0
       ld   a,(hl)
       and  #0xFE
       cp   #4
       jr   z,l_06F0
       ld   h,#>ds_sprite_posn
       ld   a,(hl)
       and  a
       jr   z,l_06F0
       sub  ixl
       sub  #7
       add  a,#0x0D
       jr   nc,l_06F0
       inc  l
       ld   a,(hl)
       ld   h,#>ds_sprite_ctrl
       ld   c,(hl)
       dec  l
       rrc  c
       rra
       sub  ixh
       sub  #4
       add  a,#7
       jr   nc,l_06F0

       ld   a,#1
       ld   (b8_ship_collsn_detectd_status),a     ; 1 ... ship collision occured

       or   a                                     ; clears H and C flags?
       ex   af,af'
       jp   j_07C2                                ; handle collision
l_06F0:
       inc  l
       inc  l
       djnz while_06B7

       ret
; end '_06B7',

;;=============================================================================
;; f_06F5()
;;  Description:
;;    Manage motion of rockets fired from ship(s) and checks them for
;;    hit-detection.
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
f_06F5:
       ld   de,#b_92A0 + 0x04 + 0                 ; rocket "attribute"
       ld   hl,#ds_sprite_posn + 0x64             ; rocket
       call c_0704_update_rockets

       ld   de,#b_92A0 + 0x04 + 1                 ; rocket "attribute"
       ld   hl,#ds_sprite_posn + 0x66             ; rocket
       ; call c_0704_update_rockets

;;=============================================================================
;; c_0704_update_rockets()
;;  Description:
;;   subroutine for f_06F5
;; IN:
;;   DE == pointer to rocket "attribute", e.g. &b_92A0_4[0], &b_92A0_4[1]
;;         Value is E0 if the ship is oriented normally, not rotated.
;;         bit7=orientation, bit6=flipY, bit5=flipX, 1:2=displacement
;;   HL == pointer to rocket sprite 0 or 1 ... sprite_posn[$64], sprite_posn[$66]
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_0704_update_rockets:
; if (0 == mrw_sprite.posn[hl].b0) return
       ld   a,(hl)
       and  a
       ret  z

; else ... this one is active, stash the parameter in B.
       ld   a,(de)
       ld   b,a

; if horizontal orientation, dY = A' ... dY is variable ...
       and  #0x07                                 ; I thought it was only bits 1:2 ?
       ex   af,af'

; ... and dX == A ... maximum displacement in X
       ld   a,#6

; if ( vertical orientation ) ...
       bit  7,b                                   ; from l_1F71, bit set if vertical orientation
       jr   z,l_0713

; ... swap, i.e. dY = A' = 6 ... dY is maximum, and dX = A ... variable
       ex   af,af'

l_0713:
; if ( ! flipY ) then  dX = ~A
       bit  6,b                                   ; flipY: inverted...
       jr   z,l_0719
       neg                                        ; .. NOT flipY...negate X offset (non-flipped sprite is leftfacing)

l_0719:
; add new sX increment
       add  a,(hl)                                ; dX is 0 unless the ship is spinning/captured
       ld   (hl),a

; left/right out of bounds... one test for right extent ($F0) or < 0 ($FF)
; if ( coordinate > $F0 ) then goto _disable_rocket
       cp   #0xF0
       jr   nc,l_0763_disable_rocket

; stash sX for hit-detection parameter
       ld   ixl,a


; NOW onto sY...............

       inc  l                                     ; offset[1] ... sprite_posn.sy
; get the stashed dY
; if ( ! flipX ) then  dY = -dY
       ex   af,af'
       bit  5,b                                   ; inverted flipX
       jr   z,l_0729
       neg                                        ; negate dY if NOT flipX (2's comp)
l_0729:
       ld   c,a                                   ; stash the dY

; add new sY increment ... lower 8-bits to register
       add  a,(hl)
       ld   (hl),a

; determines the sign, toggle position.sy:8 on overflow/carry. simple idea, complicated explanation.
       rra                                        ; Cy from the addition rotated into b7
       xor  c                                     ; sign bit of addend/subtrahend
       ld   h,#>ds_sprite_ctrl                    ; sy.bit-8 (SPR[n].CTRL.b1:0)
       rlca
       jr   nc,l_0738
; compliment sy:8  (handles both overflow and underflow situation)
       rrc  (hl)
       ccf
       rl   (hl)

; setup rocket_position.sy<1:8> in A (use scale factor of 2 to keep in 8-bits)
l_0738:
       ld   c,(hl)                                ; bit-8 from sprite_control.offset[1]
       ld   h,#>ds_sprite_posn
       ld   a,(hl)                                ; get sy bits 0:7
       rrc  c                                     ; rotate bit-8 into Cy
       rra                                        ; rotate bit-8 from Cy into A
       ld   ixh,a                                 ; stash sy<1:8> for hit-detection parameter

; if ( sprite.sY < 40 || sprite.sY > 312 ) then _disable_rocket_wposn
       cp   #0x28 >> 1                            ; 0x14
       jr   c,l_0760_disable_rocket_wposn         ; L is offset to sY, so first L--
       cp   #0x138 >> 1                           ; 0x9C
       jr   nc,l_0760_disable_rocket_wposn        ; L is offset to sY, so first L--

; index of object/sprite passed through to j_07C2 (odd, i.e. b1)
       ld   e,l

; if ( task_active ) then ... else _call_hit_detection_all
       ld   a,(ds_cpu0_task_actv + 0x1D)          ; cpu0:f_2000 (capturing boss destroyed, rescued ship spinning)
       and  a
       jr   z,l_0757_call_hit_detection_all

; else
; ...the capturing boss is destroyed and the rescued ship is up there spinning,
; and for a precious couple of seconds we get to keep firing rockets at our
; bitter foes... so we need to make sure to ignore the rescued ship objects
; ( $00, thru $06 ) ... in a moment, rockets will be disabled while the
; the rescued ship is landing.

       ld   hl,#ds_sprite_posn + 0x08             ; skip first 4 objects...
       ld   b,#0x30 - 4

       jr   l_075C_call_hit_detection

l_0757_call_hit_detection_all:
; reset HL and count to check $30 objects
       ld   hl,#ds_sprite_posn + 0x00
       ld   b,#0x30

l_075C_call_hit_detection:
       call c_076A_rocket_hit_detection
       ret

; terminate out of bounds sideways rockets
; L is offset to sY, so first L-- ... may not need to reset H?
l_0760_disable_rocket_wposn:
       dec  l                                     ; should be at offset 1, and now 0.
       ld   h,#>ds_sprite_posn                    ; x
l_0763_disable_rocket:
       ld   (hl),#0
       ld   h,#>ds_sprite_ctrl
       ld   (hl),#0

       ret

;;=============================================================================
;; c_076A_rocket_hit_detection()
;;  Description:
;;   collision detection... rocket fired from ship.
;; IN:
;;  E == LSB of pointer to object/sprite passed through to
;;       j_07C2 (odd, i.e. offset to b1)
;;  HL == pointer to sprite.posn[], starting object object to test ... 0, or
;;        +8 skips 4 objects... see explanation at l_0757.
;;  B == count ... $30, or ($30 - 4) as per explanation above.
;;  IXL == rocket.sx
;;  IXH == rocket.sy (scale factor 2 in order to get it in 8-bits)
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_076A_rocket_hit_detection:

l_076A_while_object:

; obj_status[L].state<7> ... $80 == inactive object
; obj_collsn_notif[L].b0 ... $81 = hit notification already in progress

; if (0x80 != ( obj_status[L].state & _obj_collsn_notif[L] ))
       ld   h,#>b_9200_obj_collsn_notif           ; is hit notification already in progress
       ld   a,(hl)
       ld   h,#>b_8800
       or   (hl)
       rlca
       jr   c,l_07B4_next_object

; check if object status 04 (already exploding) or 05 (bonus bitmap)
       ld   a,(hl)
       ld   c,a
       and  #0xFE                                 ; tests for 5 also
       cp   #4
       jr   z,l_07B4_next_object

; test dX and dY for within +/- 3 pixels, using the addition
; offset with "Cy" so only 1 test needed for (d>-3 && d<+3 )

; check Y coordinate

       ; set .sY<1:8> in A
       inc  l
       ld   h,#>ds_sprite_ctrl                    ; sprite.sy<8>
       ld   d,(hl)
       ld   h,#>ds_sprite_posn                    ; sprite.sy<0:7>
       ld   a,(hl)
       rrc  d
       rra
       dec  l

       sub  ixh                                   ; sprite.sy<1:8> -= rocket.sy<1:8>
       sub  #3                                    ; tolerance for hit-check (divided by 2 to account for scaling)
       add  a,#6
       jr   nc,l_07B4_next_object

; check X coordinate
       ld   a,c                                   ; reload object status e.g. 8800[L]
       dec  a
       and  #0xFE
       ex   af,af'                                ; object status to j_07C2
       ld   a,(ds_plyr_actv +_b_2ship)
       and  a
       ld   a,(hl)                                ; sprite.sX

       jr   nz,l_07A4                             ; and  a
       sub  ixl                                   ; sprite.sX -= rocket.sX
       sub  #6
       add  a,#0x0B
       jr   c,l_07B9_pre_hdl_collsn
       jr   l_07B4_next_object

l_07A4:
       sub  ixl                                   ; sprite.sX -= rocket.sX
       sub  #0x14
       add  a,#0x0B
       jr   c,l_07B9_pre_hdl_collsn
       add  a,#4
       jr   c,l_07B4_next_object
       add  a,#0x0B
       jr   c,l_07B9_pre_hdl_collsn

l_07B4_next_object:
       inc  l
       inc  l
       djnz l_076A_while_object

       ret

l_07B9_pre_hdl_collsn:
       ld   a,l                                   ; stash the object key while we use HL to ld 16-bits
       ld   hl,(ds_plyr_actv +_w_hit_ct)
       inc  hl
       ld   (ds_plyr_actv +_w_hit_ct),hl
       ld   l,a

; j_07C2

;;=============================================================================
;; j_07C2()
;;  Description:
;;   handle collision.
;;   label for jp from c_06B7 for handling ship+bug collision
;; IN:
;;   L == offset/index of destroyed bug, or a bomb
;;   E == offset/index of rocket sprite + 1
;;   E == object key + 0, e.g. 9B62 (the fighter ship)
;;   A' == object status
;; OUT:
;;  ...
;; RETURN:
;;  get out by l_07B4_next_object or ret
;;-----------------------------------------------------------------------------
j_07C2:
       ld   d,#>ds_sprite_posn                    ; _sprite_posn[L] = 0
       xor  a
       ld   (de),a                                ; e.g. 9365 = 0
       ld   d,#>ds_sprite_ctrl                    ; _sprite_ctrl[L] = 0
       ld   (de),a

       inc  l
       ld   h,#>ds_sprite_code
       ld   a,(hl)                                ; grab sprite color...
       ld   c,a                                   ; ... for later
       and  a
       jp   z,l_08CA_hit_green_boss               ; color map 0 is the "green" boss
       dec  l
       cp   #0x0B                                 ; color map $B is for "bombs" ... (b for bomb!)
       jr   z,l_0815_bomb_hit_ship

; if rocket or ship collided with bug
       ex   af,af'                                ; un-stash parameter (1 if moving bug)
       jr   nz,l_081E_hdl_flyng_bug               ; will come back to $07DB or l_07DF

; else if rocket hit stationary bug
       ex   af,af'                                ; re-stash parameter

l_07DB:
; set it up for elimination
       ld   h,#>b_9200_obj_collsn_notif           ; = $81
       ld   (hl),#0x81

l_07DF:
; if capture boss ...
       ld   a,(ds_plyr_actv +_b_cboss_obj)
       sub  l
       jr   nz,l_07EC
; ... then ...
       ld   (ds_plyr_actv +_b_cboss_dive_start),a ; 0  ... shot the boss that was starting the capture beam
       inc  a
       ld   (ds_plyr_actv +_b_cboss_obj),a        ; 1  ... invalidate the capture boss object key

l_07EC:
; use the sprite color to get index to sound
       push hl                                    ; stash index/offset of object

; if sprite color == 7 ... (check for red captured ship)
       ld   a,c                                   ; sprite color
       cp   #7
       jr   nz,l_07F5
       dec  a
       jr   l_07F8_
; ... else ...
l_07F5:
       dec  a
       and  #0x03

l_07F8_:
       ld   hl,#b_9AA0 + 0x01                     ; b_9AA0[1 + A] ... sound-fx count/enable registers
       rst  0x10                                  ; HL += A
       ld   (hl),#1

; if sprite color == 7
       ld   a,c                                   ; sprite color
       cp   #7
       jr   nz,l_0808
       ld   hl,#ds_plyr_actv +_b_cboss_dive_start ; 0
       ld   (hl),#0

l_0808:
; _bug_collsn[ color ] += 1
       ld   hl,#ds_bug_collsn_hit_mult + 0x00     ; rocket/bug or ship/bug collision
       rst  0x10                                  ; HL += A
       inc  (hl)

       ex   af,af'                                ; un-stash parameter
       jr   z,l_0811
       inc  (hl)                                  ; shot blue boss
l_0811:
       pop  hl
       jp   l_07B4_next_object

; this invalidates the bomb object... but what about the ship?
l_0815_bomb_hit_ship:
       ld   h,#>ds_sprite_posn                    ; bomb colliding with ship.
       ld   (hl),#0
       ld   h,#>b_8800
       ld   (hl),#0x80

; return!
       ret

; Handle flying bug collision (bullet or ship). Not stationary bugs.
l_081E_hdl_flyng_bug:
       ld   h,#>b_8800
       push hl
       ex   af,af'                                ; re-stash parameter
       inc  l
       ld   a,(hl)
       ld   h,#>ds_bug_motion_que                 ; bug_motion_que[A].b13
       add  a,#0x13
       ld   l,a
       ld   (hl),#0

       ld   hl,#b_bug_flyng_hits_p_round          ; +=1
       inc  (hl)

;; bug_flying_hit_cnt is probably only meaningful in challenge rounds. In other
;; rounds it is simply intiialized to 0 at start of round.
       ld   hl,#w_bug_flying_hit_cnt              ; count down each flying bug hit ... reset 8 each challenge_wave
       dec  (hl)
       pop  hl                                    ; b8800_obj_status

       jr   nz,l_0849

; award bonus points for destroying complete formation of 8 on challenge stage
       ld   h,#>b_9200_obj_collsn_notif           ; = b_9280[4 + 1]
       ld   a,(ds2_stg_chllg_rnd_attrib + 1)      ; sprite code + flag
       ld   (hl),a

       ld   a,(ds2_stg_chllg_rnd_attrib + 0)      ; add "score" to bug_collsn[$0F] (why add?)
       ld   h,a
       ld   a,(ds_bug_collsn_hit_mult + 0x0F)
       add  a,h
       ld   (ds_bug_collsn_hit_mult + 0x0F),a     ; += b_9280[4 + 0] ... "score"

       jr   l_07DF

l_0849:
; handle special cases of flying bugs, then jp   l_07DF

; if (hit == captured ship)
       ld   a,c                                   ; sprite color
       cp   #7                                    ; color map 7 ... red captured ship
       jr   nz,l_0852

       ld   d,#0xB8
       jr   l_08B0_set_bonus_sprite_code

; else if ( hit bonus-bee or clone bonus-bee )
l_0852:
       ld   a,(ds_plyr_actv +_b_bbee_obj)         ; get object of parent bonus-bee
       cp   l
       jp   z,l_08B6

       ld   a,l                                   ; check if this one is one of the clones ("transients" i.e.... $38 etc.)
       and  #0x38
       cp   #0x38
       jp   z,l_08B6

; else if ! blue-boss ... l_07DB
       ld   a,c                                   ; sprite color
       cp   #1                                    ; color map 1 ... blue boss hit once
       jp   nz,l_07DB

; ... else ... handle blue boss
; check for captured-fighter
       push de                                    ; ds_sprite_ctrl[n]
       ld   a,l
       and  #0x07                                 ; mask off to reference the captured ship
       ld   e,a
       ld   d,#>b_8800
       ld   a,(de)
       cp   #9                                    ; is this a valid capture ship status ...i.e. diving? ...status may still...
       jr   nz,l_0899                             ; ...be $80 meaning I have killed the boss before he pulls the ship all in!
; captured ship is diving
       push hl                                    ; stash the boss object locator e.g. b_8830
       ex   de,hl                                 ; DE==captured ship object locator e.g. b_8800
       inc  l
       ld   a,(hl)                                ; get the offset of the flying structure e.g. 9100+$14 etc.
       add  a,#0x13
       ld   e,a
       ld   d,#>ds_bug_motion_que                 ; e.g. sets b_9113 == 0, makes this flying structure inactive.
       xor  a
       ld   (de),a
       ld   h,#>ds_sprite_code
       ld   (hl),#9                               ; color map 9 for white ship
       dec  l
       ld   a,l
       ld   (ds_plyr_actv +_b_cboss_obj),a        ; updated object locator token of rescued ship   (token was 1)
       ld   h,#>b_8800                            ; the captured ship object becomes inactive (0)
       xor  a
       ld   (hl),a
       ld   (ds5_928A_captr_status + 0x01),a      ; 0
       inc  a
       ld   (ds_cpu0_task_actv + 0x1D),a          ; 1 ... shot the boss that captured the ship
       ld   (ds5_928A_captr_status + 0x03),a      ; 1
       ld   (b_9AA0 + 0x11),a                     ; 1 ... sound-fx count/enable registers, "rescued ship" music
       pop  hl                                    ; restore boss object locator e.g. b_883x

l_0899:
; lone blue boss killed, or boss killed before pulling the beam all in
       pop  de                                    ; ds_sprite_ctrl[n].b1
       push hl                                    ; obj_status[ HL ] (boss) e.g. b_8830
       ld   a,#6
       ld   (ds4_game_tmrs + 1),a                 ; 6 ... captured ship timer
       ld   a,l
       and  #7                                    ; gets offset of object from $30
       ld   hl,#ds_plyr_actv +_ds_bonus_codescore ; bonus code/scoring attributes for 1 of 4 flying bosses
       rst  0x10                                  ; HL += A
       ld   a,(hl)                                ; .b0 ... add to bug_collsn[$0F] (adjusted scoring increment)
       inc  l
       ld   d,(hl)                                ; .b1 -> obj_collsn_notif[L] ... sprite code + 0x80
l_08AA:
       ld   hl,#ds_bug_collsn_hit_mult + 0x0F     ; bonus score increment boss killed
       add  a,(hl)
       ld   (hl),a
       pop  hl

; jp here if shot the flying captured ship
l_08B0_set_bonus_sprite_code:
       ld   h,#>b_9200_obj_collsn_notif
       ld   (hl),d                                ; shot boss ... (9230):=BA B5. B7?   B8 if hit captured ship
       jp   l_07DF

l_08B6:
       push hl
       ld   hl,#b8_99B0_X3attackcfg_ct            ; decrement (HL) (counter for triple attack?)
       dec  (hl)
       pop  hl
       jp   nz,l_07DB
       ld   a,(b8_99B2_X3attackcfg_parm1)         ; 99B0==0 ... destroyed all 3 of triple-attack
       ld   d,a
       ld   a,(b8_99B1_X3attackcfg_parm0)
       push hl

       jp   l_08AA

l_08CA_hit_green_boss:
       inc  a
       ld   (hl),a
       ld   (b_9AA0 + 0x04),a                     ; sound-fx count/enable registers, hit_green_boss
       dec  l

       jp   l_07B4_next_object


;;=============================================================================
;; f_08D3()
;;  Description:
;;   bug motion runner
;;   The flying bugs are tracked by the queue (ds_bug_motion_que) which is
;;   populated by f_2916.
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
f_08D3:
       ld   ix,#ds_bug_motion_que

       ld   a,#0x0C
       ld   (b_bug_que_idx),a                     ; $0C ... nbr of iterations to run per frame (nbr of object structures)

       ld   hl,#b_bugs_flying_cnt                 ; =0
       ld   a,(hl)
       ld   (hl),#0
       inc  hl
       ld   (hl),a                                ; b_bugs_flying_nbr = bugs_flying_cnt

; traverse the object-motion queue
l_08E4_superloop:
       bit  0,0x13(ix)                            ; check for activated state
       jp   z,l_0DFB_next_superloop

       ld   hl,#b_bugs_flying_cnt                 ; +=1
       inc  (hl)

       ld   l,0x10(ix)                            ; object identifier...8800[L]
       ld   h,#>b_8800

; 9 is diving, 7 is spawning, 3 (and 6) bomb?
; if (!(A == 3 || A == 7 || A == 9)) ...
       ld   a,(hl)
       cp   #3                                    ; status 3 is what?
       jr   z,l_0902_ck_frm_ct
       cp   #9                                    ; if 8800[L]==9 ... flying into formation or diving out.
       jr   z,l_0902_ck_frm_ct
       cp   #7                                    ; if 8800[L]==7 ... spawning (new stage)
; ... then ...
; status==4 ... shot a non-flying capturing boss (ship will soon go rogue and launch out)
; HL==8830, *HL==04, 8831==40
       jp   nz,case_0E49_make_object_inactive     ; sets object state to $80

l_0902_ck_frm_ct:
; load a new flight segment if this one timed out, otherwise go directly to flite path handler and continue with same data-set
       dec  0x0D(ix)                              ; check for expiration of this data-set
       jp   nz,l_0C05_flite_pth_cont

; flight-path vector has expired... setup HL as pointer to next data token
       ld   l,0x08(ix)
       ld   h,0x09(ix)


; this label allows reading the next token after doing state-selection
j_090E_flite_path_init:
       ld   a,(hl)                                ; data_set[n + 0]

; get next token and check if ordinary data or state-selection
; if (token < 0xEF)
       cp   #0xEF
       jp   c,l_0BDC_flite_pth_load               ; if token < $ef, continue to flight-path handler

; else ...
;  Negated token indexes into jp-tbl for selection of next state.
       push hl                                    ; ptr to data table
       cpl
       ld   hl,#d_0920_jp_tbl
       rst  0x08                                  ; HL += 2A
       ld   a,(hl)
       inc  hl
       ld   h,(hl)
       ld   l,a
       ex   (sp),hl                               ; restore HL and goto stacked address in one-fell-swoop.. sneaky!
       ret

d_0920_jp_tbl:
      .dw case_0E49_make_object_inactive
      .dw case_0B16   ; attack elements that break formation to attack ship (level 3+)
      .dw case_0B46   ; returning to base: moths or bosses from top of screen, bees from bottom of loop-around.
      .dw case_0B4E   ; bee dive and starting loopback, or boss left position and starting dive down
      .dw case_0AA0   ; attack wave element hits turning point and heads to home
      .dw case_0BD1   ; bee has flown under bottom of screen and now turns for home
      .dw case_0B5F   ; bee has flown under bottom of screen and now turns for home
      .dw case_0B87   ; tractor beam reaches ship
      .dw case_0B98   ; attack wave
      .dw case_0BA8   ; one red moth left in "free flight mode"
      .dw case_0942   ; ?
      .dw case_0A53   ; capture boss diving
      .dw case_0A01   ; diving elements have left formation and fired
      .dw case_097B   ; bonus bee
      .dw case_0968   ; diving attacks stop and bugs go home
      .dw case_0955   ; attack wave
      .dw case_094E   ; one red moth left in "free flight mode"

; when ... no idea
case_0942:
       ld   e,0x10(ix)                            ; offset of object ...8800[E]
       ld   d,#>b_8800
       ld   a,#0x03                               ; set to state 3
       ld   (de),a
       inc  hl                                    ; ptr to data table
       jp   j_090E_flite_path_init

; one red moth left in "free flight mode"
case_094E:
       ld   a,(ds_new_stage_parms + 0x09)
       and  a
       jp   l_0959

; attack wave
case_0955:
       ld   a,(ds_new_stage_parms + 0x08)
       and  a
l_0959:
       jr   z,l_0963
; not until stage 8 ... load a pointer from data tbl into .p08 (09)
       inc  hl                                    ; ptr to data table
       ld   a,(hl)
       inc  hl
       ld   h,(hl)
       ld   l,a
       jp   l_0B8C
l_0963:
       inc  hl                                    ; ptr to data table
       inc  hl                                    ; ptr to data table
       jp   l_0B8B

; diving attacks stop and bugs go home
case_0968:
       ld   e,0x10(ix)                            ; home_posn_rc[ obj_id ]
       ld   d,#>db_obj_home_posn_RC               ; home_posn_rc[ ix($10) ]
       ld   a,(de)                                ; row position index
       ld   e,a
       ld   d,#>ds_home_posn_abs
       inc  e
       ld   a,(de)                                ; msb, absolute row pix coordinate
       add  a,#0x20
       ld   0x01(ix),a
       jp   l_0B8B

; the bonus-bee has started dive and sprite form is scorpion, but has not split yet, getting ready to
case_097B:
       push hl                                    ; ptr to data table
       ld   e,0x10(ix)                            ; object offset of bee that is to be split
; find an available inactive object ($80) or getout.
       ld   hl,#b_8800 + 0x38
       ld   b,#4
l_0984:
       ld   a,(hl)
       rlca
       jr   c,l_098F_do_split_off_bonus_bee
       inc  l
       inc  l
       djnz l_0984
       jp   l_09FA_bonusbee_creat_fail

l_098F_do_split_off_bonus_bee:
       ld   h,#>ds_sprite_code
       ld   d,h
       ld   a,(de)                                ; e.g. DE==8B10, HL==8B38
       ld   (hl),a
       inc  l
       inc  e
       ld   a,(de)
       ld   (hl),a
       dec  l
       ld   a,l
       ex   af,af'

; find available slot or getout
       ld   hl,#ds_bug_motion_que + 0xF0 - 1      ; start at end/top of segment
       ld   de,#-0x14                             ; sizeof array element
       ld   b,#0x0C                               ; nbr of object in the array
l_09A3:
       ld   a,(hl)
       and  #0x01                                 ; check if this slot available
       jr   z,l_09AE_doit
       add  hl,de
       djnz l_09A3

       jp   l_09FA_bonusbee_creat_fail

l_09AE_doit:
       add  hl,de
       inc  hl
       ld   a,0x00(ix)                            ; coordinate of parent bonus-bee
       ld   e,ixl
       ld   d,ixh
       ex   de,hl
       ld   iyl,e
       ld   iyh,d
       ld   bc,#0x0006
       ldir
       ld   c,#6
       add  hl,bc
       ex   de,hl
       add  hl,de
       ex   de,hl
       ld   c,#4
       ldir
       ld   a,0x13(ix)                            ; 0x13(iy)
       ld   0x13(iy),a
       pop  hl
       inc  hl
       ld   a,(hl)
       ld   0x08(iy),a
       inc  hl
       ld   a,(hl)
       ld   0x09(iy),a
       ld   0x0A(iy),#0x01
       ld   0x0B(iy),#0x02
       ld   0x0D(iy),#0x01
       ex   af,af'
       ld   0x10(iy),a
       ld   e,a
       ld   d,#>b_8800
       ld   a,#9                                  ; 09: diving -> 8800[i]
       ld   (de),a
       inc  e
       ld   a,iyl
       ld   (de),a
       inc  hl
       jp   j_090E_flite_path_init

l_09FA_bonusbee_creat_fail:
       pop  hl                                    ; ptr to data table
       inc  hl
       inc  hl
       inc  hl
       jp   j_090E_flite_path_init

; diving elements have left formation and fired
case_0A01:
       push hl                                    ; ptr to data table
       ex   de,hl
       ld   a,(b_9215_flip_screen)
       ld   c,a
       ld   a,(ds_sprite_posn + 0x62)             ; ship_1_position
       cp   #0x1E
       jr   nc,l_0A10
       ld   a,#0x1E                               ; when?
l_0A10:
       cp   #0xD1
       jr   c,l_0A16
       ld   a,#0xD1                               ; when?
l_0A16:
       bit  0,c
       jr   z,l_0A1E
       add  a,#0x0E                               ; when?
       neg
l_0A1E:
       srl  a
       sub  0x03(ix)
       rra
       bit  7,0x13(ix)                            ; if !z  then  a=-a
       jr   z,l_0A2C_
       neg
l_0A2C_:
       add  a,#0x18
       jp   p,l_0A32
       xor  a                                     ; when?
l_0A32:
       cp   #0x30
       jr   c,l_0A38
       ld   a,#0x2F                               ; when?
l_0A38:
       ld   h,a
       ld   a,#6
       call c_0EAA
       ld   a,h
       inc  a
       ex   de,hl
       rst  0x10                                  ; HL += A
       ld   a,(hl)
       ld   0x0D(ix),a
       pop  hl
       ld   a,#9
       rst  0x10                                  ; HL += A
       ld   0x08(ix),l                            ; pointer.b0
       ld   0x09(ix),h                            ; pointer.b1
       jp   l_0BFF

; capturing boss starts dive
case_0A53:
       push hl
       ld   a,(b_9215_flip_screen)
       ld   c,a
       ld   a,(ds_sprite_posn + 0x62)             ; ship_1_position
       add  a,#3
       and  #0xF8
       inc  a
       cp   #0x29
       jr   nc,l_0A66
       ld   a,#0x29                               ; when?
l_0A66:
       cp   #0xCA
       jr   c,l_0A6C
       ld   a,#0xC9                               ; when?
l_0A6C:
       bit  0,c                                   ; check flip screen
       jr   z,l_0A73
       add  a,#0x0D                               ; flipped
       cpl
l_0A73:
       ld   (ds5_928A_captr_status + 0x00),a
       srl  a
       ld   e,a
       ld   d,#0x48
       ld   h,0x01(ix)
       ld   l,0x03(ix)
       call c_0E5B                                ; HL = c_0E5B(DE, H, L)
       srl  h
       rr   l
       ld   0x04(ix),l
       ld   0x05(ix),h

       xor  a
       ld   (ds5_928A_captr_status + 0x01),a      ; 0
       inc  a
       ld   (ds_cpu0_task_actv + 0x19),a          ; 1: f_21CB ... boss diving to capture position
       ld   a,ixl
       ld   (ds_plyr_actv +_b_cboss_slot),a       ; ixl ... offset of slot used by capture boss, referenced by cpu0:f_21CB
       pop  hl                                    ; ptr to data table
       inc  hl
       jp   j_090E_flite_path_init

; attack wave element hits turning point and heads to home
case_0AA0:
       push hl                                    ; ptr to data table

       ld   l,0x10(ix)                            ; update object disposition ... i.e. 8800[L]
       ld   h,#>b_8800
       ld   (hl),#9                               ; disposition = 9: diving/homing (currently 3)

       ld   h,#>db_obj_home_posn_RC               ; home_posn_rc[ ix($10) ]
       ld   c,(hl)                                ; row index
       inc  l
       ld   l,(hl)                                ; column index

       ld   h,#>ds_home_posn_loc
       ld   b,(hl)                                ; x offset
       inc  l
       ld   e,(hl)                                ; x coordinate

       ld   l,c                                   ; row position index
       ld   c,(hl)                                ; y offset
       inc  l
       ld   d,(hl)                                ; y coordinate

       srl  e                                     ; x coordinate
       push de                                    ; y coord, x coord >> 1

       ld   0x11(ix),b                            ; step x coord (x offset)
       ld   0x12(ix),c                            ; step y coord (y offset)

       ld   a,(b_9215_flip_screen)
       and  a
       jr   z,l_0ACD
; flipped ... negate the steps
       ld   a,b
       neg
       ld   b,a
       ld   a,c
       neg
       ld   c,a
l_0ACD:
; add y-offset to .b00/.b01 (sra/rr -> 9.7 fixed-point scaling)
       ld   l,0x00(ix)                            ; .b00
       ld   h,0x01(ix)                            ; .b01
       ld   d,c                                   ; step y coord, y offset
       ld   e,#0
       sra  d
       rr   e
       add  hl,de
       ld   0x00(ix),l                            ; .b00
       ld   0x01(ix),h                            ; .b01
       ld   e,h                                   ; y, .b01 (bits<1:8> of integer portion)

; add x-offset to .b02/.b03 (sra/rr -> 9.7 fixed-point scaling)
       ld   l,0x02(ix)                            ; .b00
       ld   h,0x03(ix)                            ; .b01
       ld   c,#0
       sra  b                                     ; step x coord, x offset
       rr   c
       sbc  hl,bc
       ld   0x02(ix),l                            ; .b00
       ld   0x03(ix),h                            ; .b01
       ld   l,h                                   ; x, .b01 (bits<1:8> of integer portion)
       ld   h,e                                   ; y, .b01 (bits<1:8> of integer portion)

       ld   c,d                                   ; C is not used?

       pop  de                                    ; abs row pix coord & abs col pix coord >> 1

       call c_0E5B                                ; HL = c_0E5B(DE, H, L)
       srl  h
       rr   l
       ld   0x04(ix),l
       ld   0x05(ix),h
       ld   0x06(ix),d                            ; attention: .b06 <- D
       ld   0x07(ix),e
       set  6,0x13(ix)                            ; if set, flite path handler checks for home

       pop  hl                                    ; ptr to data table
       inc  hl
       jp   j_090E_flite_path_init

; attack elements that break formation to attack ship (level 3+)
case_0B16:
       push hl                                    ; ptr to data table
       ex   de,hl
       ld   a,(b_9215_flip_screen)
       rrca
       ld   b,0x13(ix)                            ; xor
       xor  b
       rlca
       ld   a,(sfr_sprite_posn + 0x62)            ; ship1
       inc  a
       dec  a
       jr   nz,l_0B2A
       ld   a,#0x80
l_0B2A:
       jr   c,l_0B30
       neg
       add  a,#0xF2
l_0B30:
       add  a,#0x0E
       ld   h,a
       ld   a,#0x1E
       call c_0EAA
       ld   a,h
       ex   de,hl
       rst  0x10                                  ; HL += A
       ld   a,(hl)
       ld   0x0D(ix),a
       pop  hl
       ld   a,#9
       rst  0x10                                  ; HL += A
       jp   l_0BFF

; creatures that are returning to base: moths or bosses from top of screen,
; bees from bottom of loop-around, and "transients"
case_0B46:
l_0B46:
       inc  hl                                    ; ptr to data table
       ld   e,(hl)
       inc  hl
       ld   d,(hl)
       ex   de,hl
       jp   j_090E_flite_path_init

; bee dive and starting loopback, or boss left position and starting dive down
case_0B4E:
       inc  hl                                    ; ptr to data table
       ld   e,(hl)
       inc  hl
       ld   0x06(ix),e
       ld   0x07(ix),#0
       set  5,0x13(ix)                            ; bee or boss dive
       jp   l_0BFF

; bee has flown under bottom of screen and now turns for home
; hmm.... well no, this is working on moth $40 that is nested. The bee is at the bottom though.
; or maybe a boss
case_0B5F:
       ld   a,(b_9215_flip_screen)
       ld   c,a
       ld   e,0x10(ix)                            ; home_posn_rc[ obj_id + 1 ]
       inc  e
       ld   d,#>db_obj_home_posn_RC               ; home_posn_rc[ ix($10) + 1 ] ... column position index
       ld   a,(de)
       ld   e,a
       ld   d,#>ds_home_posn_org                  ; col pix coordinate, lsb only
       ld   a,(de)
       bit  0,c                                   ; check if flip-screen
       jr   z,l_0B76
       add  a,#0x0E
       neg
l_0B76:
       srl  a
       ld   0x03(ix),a
       ld   a,(b_92A0 + 0x0A)                     ; if flag is set, then b_9AA0[0x13] = 1
       and  a
       jp   z,l_0B8B
       ld   (b_9AA0 + 0x13),a                     ; ~0 ... sound-fx count/enable registers, bug dive attack sound

       jr   l_0B8B

; tractor beam reaches ship
case_0B87:
       ld   0x01(ix),#0x9C
l_0B8B:
       inc  hl                                    ; e.g. HL==$03C5
l_0B8C:
       ld   0x08(ix),l                            ; .b00
       ld   0x09(ix),h                            ; .b01
       inc  0x0D(ix)

       jp   l_0DFB_next_superloop

; change direction of attack wave bug
case_0B98:
; if (0x38 != (0x38 & ds_bug_motion_que[b_bug_que_idx].b10))  hl += 3 ...
       ld   a,0x10(ix)                            ; offset of object ...8800[L]
       and  #0x38
       cp   #0x38                                 ; "transient"? ($38, $3A, $3C, $3E)
l_0B9F:
       jp   z,l_0B46
       inc  hl                                    ; ptr to data table
       inc  hl
       inc  hl
       jp   j_090E_flite_path_init

; one red moth left in "free flight mode"
case_0BA8:
       inc  hl                                    ; ptr to data table
       ld   a,(hl)
       bit  7,0x13(ix)
       jr   z,l_0BB4
       add  a,#0x80
       neg
l_0BB4:
       ld   c,#0                                  ; stage 4 ...
       sla  a
       rl   c
       sla  a
       rl   c
       ld   0x04(ix),a
       ld   0x05(ix),c
       ld   0x0E(ix),#0x1E                        ; bomb drop counter
       ld   a,(b_92C0 + 0x08)
       ld   0x0F(ix),a                            ; b_92C0[$08] ... bomb drop enable flags
       jp   l_0B8B

; bee has flown under bottom of screen and now turns for home
case_0BD1:
       ld   a,(b_92A0 + 0x0A)                     ; unknown flag
       ld   c,a
       ld   a,(ds_cpu0_task_actv + 0x1D)          ; f_2000 (destroyed boss that captured ship)
       dec  a
       and  c
       jr   l_0B9F


; Continue in the same state, but a new data set needs to be
; initialized before continuing on to flight-path handler.
l_0BDC_flite_pth_load:

; HL == ds_flying_queue[loop_cnt].pdat
; A == *ds_flying_queue[loop_cnt].pdat
; A < $EF (current token)
       ld   c,a                                   ; data[ n + 0 ]
       and  #0x0F
       ld   0x0A(ix),a                            ; lo-nibble
       ld   a,c
       rlca
       rlca
       rlca
       rlca
       and  #0x0F

       inc  hl
       ld   0x0B(ix),a                            ; hi-nibble (right shifted into bits<0:3>
       ld   a,(hl)                                ; data[ n + 1 ] ... to (ix)0x0C

       inc  hl
       bit  7,0x13(ix)                            ; if set then negate data to (ix)0x0C
       jr   z,l_0BF7
       neg
l_0BF7:
       ld   0x0C(ix),a

       ld   a,(hl)                                ; data[ n + 2 ] ... to (ix)0x0D

       inc  hl
       ld   0x0D(ix),a                            ; expiration counter from data[ n + 2 ]

l_0BFF:
       ld   0x08(ix),l                            ; pointer.b0
       ld   0x09(ix),h                            ; pointer.b1

; process this time-step of flite path, continue processing on this data-set
l_0C05_flite_pth_cont:
       bit  6,0x13(ix)                            ; if set, check if home
       jr   z,l_0C2D_flite_pth_step

; transitions to the next segment of the flight pattern
; if (    (b01==b06 || (b01-b06)==1 || (b06-b01)==1)
;      && (b03==b07 || (b03-b07)==1 || (b07-b03)==1) ) ...
       ld   a,0x01(ix)
       sub  0x06(ix)                              ; (ix)0x01 - (ix)0x06
       jr   z,l_0C1B
       jp   p,l_0C18                              ; check overflow
       neg                                        ; negate if overflow (gets absolute value)
l_0C18:
       dec  a
       jr   nz,l_0C2D_flite_pth_step
l_0C1B:
       ld   a,0x03(ix)                            ; detection of homespot... (ix)0x03-(ix)0x07 == 0 ?
       sub  0x07(ix)                              ; detection of homespot... (ix)0x03-(ix)0x07 == 0 ?
       jp   z,l_0E08_imhome
       jp   p,l_0C29                              ; check overflow
       neg                                        ; negate if overflow (gets absolute value)
l_0C29:
       dec  a
       jp   z,l_0E08_imhome


l_0C2D_flite_pth_step:
; if ( b13 & 0x20 && ( b01 == b06 || (b01 - b06) == 1  || (b06 - b01) == 1 ) ...
       bit  5,0x13(ix)                            ; check if bee or boss dive
       jr   z,l_0C46
       ld   a,0x01(ix)                            ; 0C33 boss: launched out of position, bee movement, 0x01(ix) counting down
       sub  0x06(ix)
       jr   z,l_0C3E                              ; (ix)0x01 counts down until equal to (ix)0x06
       inc  a
       jr   nz,l_0C46
; ... then ...
l_0C3E:
; set it up to expire on next step
       ld   0x0D(ix),#1                           ; bee dived down and begins loop around, boss reached position to start beam
       res  5,0x13(ix)                            ; (ix)0x0D == 1

; advance the rotation angle. Step-size in .b0C and 10-bit angle in .b04+.b05
;               90          - angle in degrees
;             1  | 0        - quadrant derived from 10-bit angle
;          180 --+-- 0      - each tile rotation is 15 degrees (6 tiles per quadrant)
;             2  | 3
;               270
l_0C46:
       ld   b,0x0C(ix)                            ; add to (ix)0x04
       ld   a,0x04(ix)
       ld   e,a                                   ; stash this for a while .....
       add  a,b                                   ; need this below for rra ...
       ld   0x04(ix),a                            ; .b04 += .b0C

       ld   d,0x05(ix)                            ; need this later ...

; sign of subtrahend determines signedness of carry
       ld   l,#1
       bit  7,b                                   ; (ix)0x0C
       jr   z,l_0C5C
       ld   l,#-1

l_0C5C:
; check for overflow out of LSB from addition (subtraction) result, sneaky ... xor sets S flag if bit-7 is toggled hi
       rra
       xor  b                                     ; b from (ix)0x0C
       ld   a,d                                   ; from (ix)0x05
       jp   p,l_0C63
       add  a,l
l_0C63:
       ld   0x05(ix),a                            ; bits <8:9>

; determine_sprite_code
       ld   a,e                                   ; from (ix)0x04
       ld   c,d                                   ; from (ix)0x05 previous ... need this later ...
       bit  0,c
       jr   z,l_0C6D
       cpl                                        ; invert bits 0:7 in quadrant 1 and 3 ...
l_0C6D:
; ... select vertical tile if within 15 degrees of 90 or 270
       add  a,#0x15                               ; 1024 / ( 6 * 4 ) == 42
       jr   nc,l_0C75
       ld   b,#6                                  ; vertical orientation, wings open (7 is wings closed)
       jr   l_0C81
l_0C75:
; divide by 42 ...42 counts per step of rotation (with 24 steps in the circle, 1 step is 15 degrees)
; Here's the math: A * ( 1/2 + 1/4 ) * ( 1/32 )
       srl  a
       ld   b,a
       srl  b
       add  a,b
       rlca                                       ; rlca * 3 ... 1/32
       rlca
       rlca
       and  #0x07
       ld   b,a

l_0C81:
       ld   h,#>ds_sprite_code
       ld   l,0x10(ix)                            ; mrw_sprite[L].cclr.b0
       ld   a,(hl)
       and  #0xF8                                 ; base sprite code (multiple of 8)
       or   b
       ld   (hl),a

; determine_sprite_ctrl( C )
; 0: flipx - flip about the X axis, i.e. "up/down"
; 1: flipy - flip about the Y axis, i.e. "left/right"
       ld   h,#>ds_sprite_ctrl
       ld   a,c                                   ; d saved from (ix)0x05 above
       rrc  c
       xor  c                                     ; bit0 xor with bit1 ...
       inc  a                                     ; ... add 1 ... now have bit1
       rrc  c                                     ; bit <1> ...
       rla                                        ; ... into <0>
       and  #0x03                                 ; <0> flip up/down  <1> flip l/r
       ld   (hl),a                                ; mrw_sprite[L].ctrl.b0 = A & 0x03

; choose 0x0A or 0x0B
       ld   a,(ds3_92A0_frame_cts + 0)
       and  #0x01
       jr   z,l_0CA4
       ld   a,0x0A(ix)
       jr   l_0CA7
l_0CA4:
       ld   a,0x0B(ix)
l_0CA7:
       and  a                                     ; if zero, start of tractor beam and we can skip this crap
       jp   z,l_0D03_flite_pth_posn_set           ; 2 "parameters": HL, and E (e saved from (ix)0x04)

; flite_pth_exec ... into the soup ...
       push hl                                    ; &mrw_sprite[L].ctrl.b0
       push ix
       pop  hl                                    ; &bug_motion_que[n].b00

       ld   b,a                                   ; (ix)0x0A or (ix)0x0B

       ld   a,d                                   ; d saved from (ix)0x05  ( from C46 )
       and  #0x03
       ld   d,a                                   ; &= 0x03

;               90          - angle in degrees
;             1  | 0        - quadrant derived from 10-bit angle
;          180 --+-- 0      - each tile rotation is 15 degrees (6 tiles per quadrant)
;             2  | 3
;               270
; checking bit-7 against bit-8, looking for orientation near 90 or 270.
; must be > xx80 in quadrant 0 & 2, and < xx80 in quadrant 1 & 3
       rlc  e                                     ; e saved from (ix)0x04   ( from C46 )
       rl   d
       push de                                    ; adjusted rotation angle, restores to HL below .....
       xor  d
       rrca                                       ; xor result in A:0
       jr   c,l_0CBF                              ; check for Cy shifted into bit7 from rrca
       inc  l
       inc  l                                     ; L == offset to b02 ... update the pointer for horizontal travel
l_0CBF:
; .b04+.b05 is angle in 16-bits. bits<7:9> together give the quadrant and fraction of 90
; degrees, indicating whether the "primary" component of the magnitude should be negative.
; 0 1  1 - 3   Any of these would result in d<2> set after the "inc d".
; 1 0  0 - 4   Remembering they have been <<1, it means the lowest bit was
; 1 0  1 - 5   .b04L<7> (degree 0-89) and the upper 2 bits were .b05<0:1> (quadrant)
; 1 1  0 - 6   Taking the quadrant and angle together, the range is 135-304 degrees.
       inc  d
       bit  2,d
       ld   a,b                                   ; ... restore A: 0x0A(ix) or 0x0B(ix)
       jr   z,l_0CC7
       neg                                        ; negate primary componet for 135-305 degrees
l_0CC7:
; A is actually bits<7:15> of addend (.b00/.b02 in fixed point, 9.7)
       ld   c,a                                   ; from 0x0A(ix) or 0x0B(ix)
       sra  c                                     ; sign extend, "bit-8" into Cy
       jr   nc,l_0CD0
       ld   a,(hl)                                ; b00 or b02, depends on "jr   c,l_0CBF"
       add  a,#0x80                               ; add carry-out from sra
       ld   (hl),a
l_0CD0:
       inc  l
       ld   a,(hl)                                ; b01 or b03, depends on "jr   c,l_0CBF"
       adc  a,c                                   ; add with carry-out from addition into lsb
       ld   (hl),a

; stash the pointer to .b0/.b2 in DE (previous DE into HL but no longer used)
       dec  l
       ex   de,hl
       ld   a,e
       xor  #0x02                                 ; toggle x/y pointer, .b00 or .b02
       ld   e,a

; test L<0> (pushed/popped from left-shifted DE above .. but this would be .b04<7> before left-shift?)
       pop  hl                                    ; ..... adjusted rotation angle from push DE above
       srl  l                                     ; revert to unshifted, but did not retain bit-7
       jr   nc,l_0CE3
       ld   a,l
       xor  #0x7F                                 ; negated bits<0:6> ?
       ld   l,a
l_0CE3:
       ld   a,b                                   ; ... restore A: 0x0A(ix) or 0x0B(ix)
       ld   b,h                                   ; msb of adjusted angle
       ld   h,#0
       call c_0E97                                ; HL = L * A

; let's look at this again...
;               90          - angle in degrees
;             1  | 0        - quadrant derived from 10-bit angle
;          180 --+-- 0      - each tile rotation is 15 degrees (6 tiles per quadrant)
;             2  | 3
;               270
;
; 0 0 1  0  ->   0 0 0  0    range should be 305 - 135
; 0 1 0  1  ->   0 1 1  1
; 0 1 0  0  ->   0 1 1  0
; 0 1 1  1  ->   0 1 0  1

       ld   a,b                                   ; msb of adjusted angle
       xor  #0x02
       dec  a
       bit  2,a
       jr   z,l_0CFA
       ld   b,h
       ld   c,l
       ld   hl,#0x0000
       and  a                                     ; ????
       sbc  hl,bc                                 ; negate BC ... can't use "neg" since it is 16-bit
l_0CFA:
       ex   de,hl                                 ; reload the pointer from DE
; *HL += *DE
       ld   a,e                                   ; lsb of mul result
       add  a,(hl)
       ld   (hl),a                                ;  .b00 or .b02
       inc  l
       ld   a,d                                   ; msb of mul result
       adc  a,(hl)                                ;  .b01 or .b03
       ld   (hl),a

       pop  hl                                    ; &mrw_sprite.ctrl[L].b0

; almost done ... update the sprite x/y positions
l_0D03_flite_pth_posn_set:
       ld   a,(b_9215_flip_screen)
       ld   c,a

; fixed point 9.7 in .b02.b03 - left shift integer portion into A ... carry in to <0> from .b02<7>
       ld   h,#>ds_sprite_posn                    ; &sprite[n].posn.x
       ld   d,0x03(ix)                            ; bits<1:6> of x pixel ... does not need to be in D
       ld   a,#0x7F
       cp   0x02(ix)                              ; set carry-in from .b02<7>
       ld   a,d                                   ; (ix)0x03
       rla                                        ; shift in .b02<7> (Cy from cp)

       bit  0,c                                   ; test flip screen
       jr   z,l_0D1A
       add  a,#0x0D                               ; flipped
       cpl
l_0D1A:
       bit  6,0x13(ix)                            ; if !z, add  a,(ix)0x11 ... relative offset
       jr   z,l_0D23
       add  a,0x11(ix)                            ; heading home (step x coord)
l_0D23:
       ld   (hl),a                                ; &sprite[n].posn.x

       inc  l                                     ; sprite[n].posn.sy<0:7>
       ld   b,0x01(ix)
       ld   a,#0x7F
       cp   0x00(ix)                              ; set carry-in from .b00<7>
       rl   e                                     ; shift in .b00<7> (Cy from cp) ... I hope only E<0> is significant
       ld   a,b                                   ; (ix)0x01

       bit  0,c                                   ; test flip screen
       jr   nz,l_0D38
       add  a,#0x4F                               ; not flipped
       cpl
       dec  e                                     ; invert bit-0
l_0D38:
       rr   e
       rla                                        ; carry flag rotated into msb, bit-8 rotated into Cy
       rl   e                                     ; carry-in from rla, bit-8 of sprite_y into e<0>

       bit  6,0x13(ix)                            ; if !z, add  a,(ix)0x12
       jr   z,l_0D50

       add  a,0x12(ix)                            ; heading home (step y coord)
       ld   d,a                                   ; stash it
       rra
       xor  0x12(ix)
       rlca
       ld   a,d
       jr   nc,l_0D50
       inc  e
l_0D50:
       ld   (hl),a                                ; sprite[n].posn.sy<0:7>
       ld   h,#>ds_sprite_ctrl                    ; sprite[n].posn.sy<8>
       rrc  (hl)
       rrc  e
       rl   (hl)                                  ; sprite[n].posn.sy<8>

; grab the object index and write to 92FF which we'll trap in MAME.
; if we stashed ixl also, then we could get the flite-q info for this object too.
; ld a,l ;
; dec a ; we want the even offset
; ld (#0x92FF),a ;

; Once the timer in $0E is reached, then check conditions to enable bomb drop.
; If bomb is disabled for any reason, the timer is restarted.
       dec  0x0E(ix)                              ; countdown to enable a bomb
       jp   nz,l_0DFB_next_superloop

       srl  0x0F(ix)                              ; these bits enable bombing
       jp   nc,l_0DF5_next_superloop_and_reload_0E

       ld   a,0x01(ix)                            ; if > $4C
       cp   #0x4C
       jp   c,l_0DF5_next_superloop_and_reload_0E

       ld   a,(ds_cpu0_task_actv + 0x15)          ; f_1F04 ...fire button input
       and  a
       jp   z,l_0DF5_next_superloop_and_reload_0E

       ld   a,(ds4_game_tmrs + 1)
       and  a
       jp   nz,l_0DF5_next_superloop_and_reload_0E

; check for available bomb-slot
       ex   de,hl
       ld   hl,#b_8800 + 0x68                     ; offset into object group for bombs
       ld   b,#8                                  ; check 8 shot-slots
l_0D82:
       ld   a,(hl)
       cp   #0x80
       jr   z,l_0D8D_got_a_bullet
       inc  l
       inc  l
       djnz l_0D82
       jr   l_0DF5_next_superloop_and_reload_0E

l_0D8D_got_a_bullet:
       ld   (hl),#6                               ; disposition "active" (bomb)
       push hl
       ld   h,#>ds_sprite_posn
       ld   d,h
       dec  e
       ld   a,(de)
       ld   c,a
       ld   (hl),a
       inc  e
       inc  l
       ld   a,(de)
       ld   b,a
       ld   (hl),a
       ld   h,#>ds_sprite_ctrl
       ld   d,h
       ld   a,(de)
       rrc  (hl)
       rrca
       rl   (hl)
       rlca
       rr   b
       ld   a,(ds_sprite_posn + 0x62)             ; ship_1_position ... crap they're shootin right at us
       sub  c
       push af
       jr   nc,l_0DB1
       neg
l_0DB1:
       ld   h,a
       ld   a,(b_9215_flip_screen)
       and  a
       ld   a,#0x95
       jr   z,l_0DBC
       ld   a,#0x1C                               ; inverted
l_0DBC:
       sub  b
       jr   nc,l_0DC1
       neg
l_0DC1:
       call c_0EAA
       ld   b,h
       ld   c,l
       srl  h
       rr   l
       srl  h
       rr   l
       add  hl,bc
       srl  h
       rr   l
       srl  h
       rr   l
       ld   a,h
       and  a
       jr   nz,l_0DE0
       ld   a,l
       cp   #0x60
       jr   c,l_0DE2
l_0DE0:
       ld   a,#0x60
l_0DE2:
       ld   b,a
       pop  af
       rr   b
       pop  hl
       ld   a,l
       add  a,#8
       and  #0x0F
       ld   hl,#b_92B0 + 0x00                     ; bullet x-coordinate structure ( 8 * 2 )
       add  a,l
       ld   l,a
       ld   (hl),b
       inc  hl
       ld   (hl),#0

l_0DF5_next_superloop_and_reload_0E:
       ld   a,(b_92E2 + 0x00)                     ; to $0E(ix) e.g. A==14 (set for each round ... bomb drop counter)
       ld   0x0E(ix),a                            ; b_92E2[0] ... bomb drop counter

l_0DFB_next_superloop:
;ret
       ld   hl,#b_bug_que_idx                     ; cnt-- ... nbr of iterations to run per frame
       dec  (hl)
       ret  z
       ld   de,#0x0014                            ; size of object-movement structure
       add  ix,de

       jp   l_08E4_superloop

; creature gets to home-spot
l_0E08_imhome:
       xor  a
       res  0,0x13(ix)                            ; mark the flying structure as inactive
       ld   0x00(ix),a                            ; 0
       ld   0x02(ix),a                            ; 0
       ld   h,#>b_8800
       ld   l,0x10(ix)                            ; offset of object ...8800[L]
       ld   (hl),#2                               ; disposition = 02: rotating back into position in the collective
       ld   h,#>ds_sprite_code
       inc  l
       ld   a,(hl)                                ; sprite color code
       dec  l
       inc  a
       and  #0x07
       cp   #5
       jr   c,l_0E3A

; A > 5 ... remaining bonus-bee returns to collective
       ld   a,(ds_plyr_actv +_b_bbee_clr_a)
       ld   c,a
       and  #0xF8
       add  a,#6
       ld   (hl),a
       inc  l
       ld   a,c
       and  #0x07
       ld   (hl),a
       dec  l
       ld   a,#1
       ld   (ds_plyr_actv +_b_bbee_obj),a         ; 1 ... offset of object that spawns the bonus bee.

l_0E3A:
; these could be off by one if not already equal
       ld   a,0x06(ix)                            ; ->(ix)0x01
       ld   0x01(ix),a                            ; (ix)0x06
       ld   a,0x07(ix)                            ; ->(ix)0x03
       ld   0x03(ix),a                            ; (ix)0x07

       jp   l_0D03_flite_pth_posn_set

; a bonus bee (e.g. 883A) flying off screen. Sprite-Code 5B (scorpion), color 05, object status==9
; also, if status==4 (capturing boss shot while in home-position, freeing a rogue ship)
case_0E49_make_object_inactive:
       ld   h,#>b_8800
       ld   l,0x10(ix)                            ; object offset ...8800[L]
       ld   (hl),#0x80                            ; make inactive
       ld   h,#>ds_sprite_posn
       ld   (hl),#0
       ld   0x13(ix),#0x00                        ; make inactive

       jp   l_0DFB_next_superloop
; end f_08D3

;;=============================================================================
;; c_0E5B()
;;  Description:
;;    Determine rotation angle ... (ix)0x04, (ix)0x05
;;    Parameters are all bits<1:8> of the integer portion (upper-byte)
;; IN:
;;  D - abs row pix coord
;;  E - abs col pix coord
;;  H - y, (ix)0x01
;;  L - x, (ix)0x03
;; OUT:
;;  HL
;; PRESERVES:
;;  BC, DE
;;-----------------------------------------------------------------------------
c_0E5B:
       push bc
       push de

; dx
       ld   a,e
       sub  l
       ld   b,#0
       jr   nc,l_0E67
       set  0,b
       neg
l_0E67:
       ld   c,a

; dy
       ld   a,d
       sub  h
       jr   nc,l_0E76
       ld   d,a
       ld   a,b                                   ; 1 if carried
       xor  #0x01
       or   #0x02
       ld   b,a
       ld   a,d
       neg

l_0E76:
       cp   c
       push af
       rla
       xor  b
       rra
       ccf                                        ; complement Cy
       rl   b
       pop  af
       jr   nc,l_0E84
       ld   d,c
       ld   c,a
       ld   a,d

l_0E84:
       ld   h,c
       ld   l,#0

; HL = HL / A
       call c_0EAA                                ; c_0EAA(A, HL)

       ld   a,h
       xor  b
       and  #0x01
       jr   z,l_0E93
       ld   a,l
       cpl
       ld   l,a

l_0E93:
       ld   h,b

       pop  de
       pop  bc

       ret

;;=============================================================================
;; c_0E97()
;;  Description:
;;    for f_08D3
;;    HL = HL * A
;; IN:
;;  HL (only L is significant)
;; OUT:
;;  H
;;  L
;; PRESERVES:
;;  DE
;;-----------------------------------------------------------------------------
c_0E97:
       push de
       ex   de,hl
       ld   hl,#0x0000

l_0E9C:
       srl  a
       jr   nc,l_0EA1
       add  hl,de
l_0EA1:
       sla  e
       rl   d
       and  a
       jr   nz,l_0E9C

       pop  de
       ret

;;=============================================================================
;; c_0EAA()
;;  Description:
;;   HL = HL / A
;; IN:
;;  A, HL
;; OUT:
;;  HL
;; PRESERVES:
;;  BC
;;-----------------------------------------------------------------------------
c_0EAA:
       push bc
       ld   c,a
       xor  a                                     ; clears Cy
       ld   b,#0x11
l_0EAF:
       adc  a,a
       jr   c,l_0EBD
       cp   c
       jr   c,l_0EB6
       sub  c
l_0EB6:
; flip the Cy: i.e. set it if the "sub c" was done, otherwise clear it.
       ccf
l_0EB7:
       adc  hl,hl
       djnz l_0EAF
       pop  bc
       ret
l_0EBD:
       sub  c
       scf
       jp   l_0EB7


.ds 0x08    ; no code at 0EC0.

;;=============================================================================
;; f_0ECA()
;;  Description:
;;   Reads dsw3 which is doesn't seem to have any function (MAME list as unused).
;;   If the switch were active (0) then the section of code would be reading
;;   from code space locations beyond the $1000. Also odd is the conditional
;;   rst  $00. Maybe a remnant of a piece of code reused from one of the games
;;   on one of the similar NAMCO Z80 platforms (digdig, bosconian etc).
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
f_0ECA:
       ld   a,(_sfr_dsw3)                         ; DSWA ( 0x04, 0x04, "SW1:3" ) /* Listed as "Unused" */
       and  #0x02
       ret  nz

       ld   hl,#0x10FF
       ld   a,(hl)
       ld   l,#0xDF                               ; $10DF
       ld   c,(hl)
       ld   a,(hl)
       xor  c
       bit  4,a
       jr   nz,l_0EDE
       rst  0x00

l_0EDE:
       ld   de,#ds_89E0 + 0x16 + 0x01
       ld   hl,#ds_89E0 + 0x16                    ; implements a $14 byte FIFO
       ld   bc,#0x0013
       lddr
       ld   ix,#d_0FD5
       ld   e,#0xE0
       ld   bc,#0x0500 + 0x0004                   ; B = loop ct (5 bytes)
l_0EF2:
       ld   a,0x00(ix)
       inc  ix
       ld   l,a
       ld   h,#0x10
       ld   a,(hl)
       ld   a,e                                   ; huh?
       add  a,c
       ld   e,a
       ld   a,(hl)
       ld   (de),a
       djnz l_0EF2

       ld   b,#5
       ld   hl,#ds_89E0 + 0x04
l_0F07:
       ld   a,(hl)
       inc  l
       or   (hl)
       inc  l
       cpl
       and  (hl)
       inc  l
       and  (hl)
       inc  l
       and  #0x0F
       jr   nz,l_0F18
       djnz l_0F07

       jr   l_0F58
l_0F18:
       dec  b
       jr   z,l_0F6A
       dec  b
       sla  b
       sla  b
l_0F20:
       rrca
       jr   c,l_0F26
       inc  b
       jr   l_0F20
l_0F26:
       ld   a,(ds_89E0)
       srl  a
       ld   e,a
       rl   c
       add  a,#0xE1
       ld   l,a
       ld   h,#>ds_89E0
       ld   a,(hl)
       bit  0,c
       jr   z,l_0F3C
       rlca
       rlca
       rlca
       rlca
l_0F3C:
       and  #0xF0
       or   b
       bit  0,c
       jr   z,l_0F47
       rlca
       rlca
       rlca
       rlca
l_0F47:
       ld   (hl),a
       ld   a,(ds_89E0)
       and  a
       jr   nz,l_0F50
       ld   a,#2
l_0F50:
       dec  a
       ld   (ds_89E0),a
       ld   a,e
       and  a
       jr   z,l_0F61
l_0F58:
       ld   hl,(ds_89E0 + 0x02)
       ld   a,(hl)
       ld   (ds_89E0 + 0x01),a
       jr   l_0FA3
l_0F61:
       ld   hl,(ds_89E0 + 0x02)
       ld   a,(ds_89E0 + 0x01)
       ld   (hl),a
       jr   l_0FA3
l_0F6A:
       ld   c,a
       ld   hl,#ds_89E0
       bit  0,c
       jr   nz,l_0F9F
       ld   a,(hl)
       srl  a
       jr   z,l_0F8A
       bit  3,c
       jr   nz,l_0F87
       ld   a,(hl)
       cp   #5
       jr   nc,l_0F83
       inc  (hl)
       jr   l_0F58
l_0F83:
       ld   (hl),#0x05
       jr   l_0F58
l_0F87:
       dec  (hl)
       jr   l_0F58
l_0F8A:
       ld   hl,(ds_89E0 + 0x02)
       bit  3,c
       jr   nz,l_0F94
       dec  hl
       jr   l_0F95
l_0F94:
       inc  hl
l_0F95:
       ld   (ds_89E0 + 0x02),hl
       ld   a,#0x01
       ld   (ds_89E0),a
       jr   l_0F58
l_0F9F:
       ld   (hl),#0x05
       jr   l_0F58
l_0FA3:
       ld   hl,#m_tile_ram + 0x03C0 + 0x0A
       ld   de,#ds_89E0 + 0x01
       ld   b,#3
l_0FAB:
       ld   a,(de)
       inc  e
       call c_0FC6
       djnz l_0FAB

       ld   hl,#m_color_ram + 0x03CA
       ld   a,(ds_89E0)
       ld   b,#6
l_0FBA:
       and  a
       ld   c,a
       jr   z,l_0FC0
       ld   c,#1
l_0FC0:
       ld   (hl),c
       inc  l
       dec  a
       djnz l_0FBA

       ret

;;=============================================================================
;; c_0FC6()
;;  Description:
;;    Called by f_0ECA
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_0FC6:
       ld   c,a
       and  #0x0F
       ld   (hl),a
       inc  l
       ld   a,c
       rlca
       rlca
       rlca
       rlca
       and  #0x0F
       ld   (hl),a
       inc  l
       ret

;;=============================================================================
;; data for f_0ECA
d_0FD5:
       .db 0xFD,0xFB,0xF7,0xEF,0xFE

; additional stage data (see db_2A3C)
dbx0FDA:
       .db 0x23,0x00,0x1B,0x23,0xF0,0x40,0x23,0x00,0x09,0x23,0x05
       .db 0x11,0x23,0x00,0x10,0x23,0x10,0x40,0x23,0x04,0x30,0xFF
dbx0FF0:
       .db 0x23,0x02,0x35,0x23,0x08
       .db 0x10,0x23,0x10,0x3C,0x23,0x00,0xFF,0xFF,0x32,0xFF

;       .db 0xFF

;; end of ROM

