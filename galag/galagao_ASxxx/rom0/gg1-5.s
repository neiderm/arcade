;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; gg1-5.s
;;  gg1-5.3f, CPU 'sub' (Z80)
;;
.module cpu_sub

.include "sfrs.inc"
.include "structs.inc"
.include "gg1-5.dep"

.BANK cpu_sub (BASE=0x000000, FSFX=_sub)
.area ROM (ABS,OVR,BANK=cpu_sub)


;.org 0x0000

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


;;-----------------------------------------------------------------------------

db_flv_001d:
       .db  0x23,0x06,0x16,0x23,0x00,0x19,0xF7
       .dw  p_flv_004b
       .db  0x23,0xF0,0x02,0xF0
       .dw  p_flv_005e
       .db  0x23,0xF0,0x24,0xFB,0x23,0x00,0xFF,0xFF

;.org 0x0034

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


;.org 0x003b

;;=============================================================================
; Function pointers for periodic tasks on this CPU (ds_cpu1_task_actvbl)
; The following bytes are copied from (d_05B7) to ds_cpu1_task_actvbl[1]
;   0x01,0x01,0x00,0x01,0x01,0x00,0x0A
d_003B_task_table:
       .dw f_05BE  ; null-task (only slot with a "null" task enabled)
       .dw f_05BF  ; [1]: update sprite RAM
       .dw f_08D3  ; [2]: bug motion runner
       .dw f_05BE  ; null-task
       .dw f_06F5  ; [4]: rocket hit-detection
       .dw f_05EE  ; [5]: hit-detection
       .dw f_05BE  ; null-task
       .dw f_0ECA  ; [7] ... ?


;;=============================================================================
 p_flv_004b:
       .db 0x23,0xf0,0x26,0x23,0x14,0x13,0xfe
       .db 0x0d,0x0b,0x0a,0x08,0x06,0x04,0x03,0x01,0x23,0xff
       .db 0xff,0xff
 p_flv_005e:
       .db 0x44,0xe4,0x18,0xfb,0x44,0x00,0xff,0xff
       .db 0xc9 ; junk ?

db_flv_0067:
       .db 0x23,0x08,0x08,0x23,0x03,0x1b,0x23,0x08,0x0f,0x23,0x16,0x15,0xf7
       .dw p_flv_0084
       .db 0x23,0x16,0x03,0xf0
       .dw p_flv_0097
       .db 0x23,0x16,0x19,0xfb,0x23,0x00,0xff,0xff
 p_flv_0084:
       .db 0x23,0x16,0x01,0xfe
       .db 0x0d,0x0c,0x0a,0x08,0x06,0x04,0x03,0x01,0x23,0xfc
       .db 0x30,0x23,0x00,0xff
       .db 0xff
 p_flv_0097:
       .db 0x44,0x27,0x0e,0xfb,0x44,0x00,0xff,0xff

db_flv_009f:
       .db 0x33,0x06,0x18,0x23,0x00,0x18,0xf7
       .dw p_flv_00b6
       .db 0x23,0xf0,0x08,0xf0
       .dw p_flv_00cc
       .db 0x23,0xf0,0x20,0xfb,0x23,0x00,0xff,0xff
 p_flv_00b6:
       .db 0x23,0xf0,0x20,0x23,0x10,0x0d,0xfe
       .db 0x1a,0x18,0x15,0x10,0x0c,0x08,0x05,0x03,0x23,0xfe
       .db 0x30,0x23,0x00,0xff
       .db 0xff
 p_flv_00cc:
       .db 0x33,0xe0,0x10,0xfb,0x44,0x00,0xff,0xff

db_flv_00d4:
       .db 0x23,0x03,0x18,0x33,0x04,0x10,0x23,0x08,0x0a,0x44,0x16,0x12,0xf7
       .dw p_flv_0160
       .db 0x44,0x16,0x03,0xf0
       .dw p_flv_0173 ; stg 13
       .db 0x44,0x16,0x1d,0xfb,0x23,0x00,0xff,0xff

db_flv_00f1:
       .db 0x12,0x18,0x17,0x12,0x00,0x80,0xff
; this is probably fill
       .ds 8

; Copy of home position LUT from task_man
sprt_fmtn_hpos:
  .db 0x14,0x06,0x14,0x0c,0x14,0x08,0x14,0x0a,0x1c,0x00,0x1c,0x12,0x1e,0x00,0x1e,0x12
  .db 0x1c,0x02,0x1c,0x10,0x1e,0x02,0x1e,0x10,0x1c,0x04,0x1c,0x0e,0x1e,0x04,0x1e,0x0e
  .db 0x1c,0x06,0x1c,0x0c,0x1e,0x06,0x1e,0x0c,0x1c,0x08,0x1c,0x0a,0x1e,0x08,0x1e,0x0a
  .db 0x16,0x06,0x16,0x0c,0x16,0x08,0x16,0x0a,0x18,0x00,0x18,0x12,0x1a,0x00,0x1a,0x12
  .db 0x18,0x02,0x18,0x10,0x1a,0x02,0x1a,0x10,0x18,0x04,0x18,0x0e,0x1a,0x04,0x1a,0x0e
  .db 0x18,0x06,0x18,0x0c,0x1a,0x06,0x1a,0x0c,0x18,0x08,0x18,0x0a,0x1a,0x08,0x1a,0x0a

 p_flv_0160:
  .db 0x44,0x16,0x06,0xfe
  .db 0x0c,0x0b,0x0a,0x08,0x06,0x04,0x02,0x01,0x23,0xfe
  .db 0x30,0x23,0x00,0xff
  .db 0xff
 p_flv_0173:
  .db 0x66,0x20,0x14,0xfb,0x44,0x00,0xff,0xff

db_flv_017b:
  .db 0x23,0x06,0x18,0x23,0x00,0x18,0xf7
  .dw p_flv_0192
  .db 0x44,0xf0,0x08,0xf0
  .dw p_flv_01a8
  .db 0x44,0xf0,0x20,0xfb,0x23,0x00,0xff,0xff
 p_flv_0192:
  .db 0x44,0xf0,0x26,0x23,0x10,0x0b,0xfe
  .db 0x22,0x20,0x1e,0x1b,0x18,0x15,0x12,0x10,0x23,0xfe
  .db 0x30,0x23,0x00,0xff
  .db 0xff
 p_flv_01a8:
  .db 0x66,0xe0,0x10,0xfb,0x44,0x00,0xff,0xff

db_flv_01b0:
  .db 0x23,0x03,0x20,0x23,0x08,0x0f,0x23,0x16,0x12,0xf7
  .dw p_flv_01ca
  .db 0x23,0x16,0x03,0xf0
  .dw p_flv_01e0
  .db 0x23,0x16,0x1d,0xfb,0x23,0x00,0xff,0xff
 p_flv_01ca:
  .db 0x23,0x16,0x01,0xfe
  .db 0x0d,0x0c,0x0b,0x09,0x07,0x05,0x03,0x02,0x23,0x02,0x20,0x23,0xfc
  .db 0x12,0x23,0x00,0xff
  .db 0xff
 p_flv_01e0:
  .db 0x44,0x20,0x14,0xfb,0x44,0x00,0xff,0xff

db_flv_01e8:
  .db 0x23,0x00,0x10,0x23,0x01,0x40,0x22,0x0c,0x37,0x23,0x00,0xff,0xff

db_flv_01f5:
  .db 0x23,0x02,0x3a,0x23,0x10,0x09,0x23,0x00,0x18,0x23,0x20,0x10
  .db 0x23,0x00,0x18,0x23,0x20,0x0d,0x23,0x00,0xff,0xff

db_flv_020b:
  .db 0x23,0x00,0x10,0x23,0x01,0x30,0x00,0x40,0x08,0x23,0xff,0x30,0x23,0x00,0xff,0xff

db_flv_021b:
  .db 0x23,0x00,0x30,0x23,0x05,0x80,0x23,0x05,0x4c,0x23,0x04,0x01,0x23,0x00,0x50,0xff

db_flv_022b:
  .db 0x23,0x00,0x28,0x23,0x06,0x1d,0x23,0x00,0x11,0x00,0x40,0x08,0x23,0x00,0x11
  .db 0x23,0xfa,0x1d,0x23,0x00,0x50,0xff

db_flv_0241:
  .db 0x23,0x00,0x21,0x00,0x20,0x10,0x23,0xf8,0x20,0x23,0xff,0x20,0x23,0xf8,0x1b
  .db 0x23,0xe8,0x0b,0x23,0x00,0x21,0x00,0x20,0x08,0x23,0x00,0x42,0xff

db_flv_025d:
  .db 0x23,0x00,0x08,0x00,0x20,0x08,0x23,0xf0,0x20,0x23,0x10,0x20,0x23,0xf0,0x40
  .db 0x23,0x10,0x20,0x23,0xf0,0x20,0x00,0x20,0x08,0x23,0x00,0x30,0xff

db_flv_0279:
  .db 0x23,0x10,0x0c,0x23,0x00,0x20,0x23,0xe8,0x10
  .db 0x23,0xf4,0x10,0x23,0xe8,0x10,0x23,0xf4,0x32,0x23,0xe8,0x10,0x23,0xf4,0x32
  .db 0x23,0xe8,0x10,0x23,0xf4,0x10,0x23,0xe8,0x0e,0x23,0x02,0x30,0xff

db_flv_029e:
  .db 0x23,0xf1,0x08,0x23,0x00,0x10,0x23,0x05,0x3c,0x23,0x07,0x42,0x23,0x0a,0x40
  .db 0x23,0x10,0x2d,0x23,0x20,0x19,0x00,0xfc,0x14,0x23,0x02,0x4a,0xff

db_flv_02ba:
  .db 0x23,0x04,0x20,0x23,0x00,0x16,0x23,0xf0,0x30,0x23,0x00,0x12,0x23,0x10,0x30
  .db 0x23,0x00,0x12,0x23,0x10,0x30,0x23,0x00,0x16,0x23,0x04,0x20,0x23,0x00,0x10,0xff

db_flv_02d9:
  .db 0x23,0x00,0x15,0x00,0x20,0x08,0x23,0x00,0x11
  .db 0x00,0xe0,0x08,0x23,0x00,0x18,0x00,0x20,0x08,0x23,0x00,0x13
  .db 0x00,0xe0,0x08,0x23,0x00,0x1f,0x00,0x20,0x08,0x23,0x00,0x30,0xff

db_flv_02fb:
  .db 0x23,0x02,0x0e,0x23,0x00,0x34
  .db 0x23,0x12,0x19,0x23,0x00,0x20,0x23,0xe0,0x0e,0x23,0x00,0x12,0x23,0x20,0x0e
  .db 0x23,0x00,0x0c,0x23,0xe0,0x0e,0x23,0x1b,0x08,0x23,0x00,0x10,0xff

db_flv_031d:
  .db 0x23,0x00,0x0d,0x00,0xc0,0x04,0x23,0x00,0x21,0x00,0x40,0x06,0x23,0x00,0x51
  .db 0x00,0xc0,0x06,0x23,0x00,0x73,0xff

db_flv_0333:
  .db 0x23,0x08,0x20,0x23,0x00,0x16,0x23,0xe0,0x0c,0x23,0x02,0x0b
  .db 0x23,0x11,0x0c,0x23,0x02,0x0b,0x23,0xe0,0x0c,0x23,0x00,0x16,0x23,0x08,0x20,0xff

db_flv_atk_yllw:
  .db 0x12,0x18,0x1e
 p_flv_0352:
  .db 0x12,0x00,0x34,0x12,0xfb,0x26
 p_flv_0358:
  .db 0x12,0x00,0x02,0xfc
  .db 0x2e,0x12,0xfa,0x3c,0xfa
  .dw p_flv_039e
 p_flv_0363:
  .db 0x12,0xf8,0x10,0x12,0xfa,0x5c,0x12,0x00,0x23
 p_flv_036c:
  .db 0xf8,0xf9,0xef
  .dw p_flv_037c
  .db 0xf6,0xab
  .db 0x12,0x01,0x28,0x12,0x0a,0x18,0xfd
  .dw p_flv_0352
 p_flv_037c:
  .db 0xf6,0xb0
  .db 0x23,0x08,0x1e,0x23,0x00,0x19,0x23,0xf8,0x16,0x23,0x00,0x02,0xfc
  .db 0x30,0x23,0xf7,0x26,0xfa
  .dw p_flv_039e
  .db 0x23,0xf0,0x0a,0x23,0xf5,0x31,0x23,0x00,0x10,0xfd
  .dw p_flv_036c ; oops shot captured fighter
 p_flv_039e:
  .db 0x12,0xf8,0x10,0x12,0x00,0x40,0xfb,0x12,0x00,0xff,0xff

db_flv_atk_red:
  .db 0x12,0x18,0x1d
 p_flv_03ac:
  .db 0x12,0x00,0x28,0x12,0xfa,0x02,0xf3
  ; $03B3
  .db 0x3f,0x3b,0x36,0x32,0x28,0x26,0x24,0x22
  ; $03BB
  .db 0x12,0x04,0x30,0x12,0xfc,0x30,0x12,0x00,0x18,0xf8,0xf9,0xfa
  .dw p_flv_040c
  .db 0xef
  .dw p_flv_03d7
 p_flv_03cc:
  .db 0xf6,0xb0
  .db 0x12,0x01,0x28,0x12,0x0a,0x15,0xfd
  .dw p_flv_03ac
 p_flv_03d7:
  .db 0xf6,0xc0
  .db 0x23,0x08,0x10,0x23,0x00,0x23,0x23,0xf8,0x0f,0x23,0x00,0x48,0xf8,0xf9,0xfa
  .dw p_flv_040c
  .db 0xf6,0xb0
  .db 0x23,0x08,0x20,0x23,0x00,0x08,0x23,0xf8,0x02,0xf3
  .db 0x34,0x31,0x2d,0x29,0x22,0x26,0x1f,0x18
  .db 0x23,0x08,0x18,0x23,0xf8,0x18,0x23,0x00,0x10,0xf8,0xf9,0xfd
  .dw p_flv_03cc
 p_flv_040c:
  .db 0xfb
  .db 0x12,0x00,0xff,0xff
db_flv_0411:
  .db 0x12,0x18,0x14
 p_flv_0414:
  .db 0x12,0x03,0x2a,0x12,0x10,0x40,0x12,0x01,0x20,0x12,0xfe,0x71
 p_flv_0420:
  .db 0xf9,0xf1,0xfa
  .dw p_flv_040c
 p_flv_0425:
  .db 0xef
  .dw p_flv_0430
  .db 0xf6,0xab
  .db 0x12,0x02,0x20,0xfd
  .dw p_flv_0414
 p_flv_0430:
  .db 0xf6,0xb0
  .db 0x23,0x04,0x1a,0x23,0x03,0x1d,0x23,0x1a,0x25,0x23,0x03,0x10,0x23,0xfd,0x48,0xfd
  .dw p_flv_0420

db_fltv_rogefgter:
  .db 0x12,0x18,0x14,0x12,0x03,0x2a,0x12,0x10,0x40,0x12,0x01,0x20,0x12,0xfe,0x78,0xff

db_0454: ; capture mode boss
  .db 0x12,0x18,0x14,0xf4
  .db 0x12,0x00,0x04,0xfc
  .db 0x48,0x00,0xfc,0xff
  .db 0x23,0x00,0x30,0xf8,0xf9,0xfa
  .dw p_flv_040c
  .db 0xfd
  .dw p_flv_0425
db_flv_cboss:
  .db 0x12,0x18,0x14,0xfb
  .db 0x12,0x00,0xff,0xff
db_0473:
  .db 0x12,0x18,0x1e,0x12,0x00,0x08,0xf2
  .dw p_flv_0499
  .db 0x00,0x00,0x0a,0xf2
  .dw p_flv_0499
  .db 0x00,0x00,0x0a
  .db 0x12,0x00,0x2c,0x12,0xfb,0x26,0x12,0x00,0x02,0xfc
  .db 0x2e
  .db 0x12,0xfa,0x3c,0xfa
  .dw p_flv_039e
  .db 0xfd
  .dw p_flv_0363
 p_flv_0499:
  .db 0x12,0x00,0x2c,0x12,0xfb,0x26,0x12,0x00,0x02,0xfc
  .db 0x2e
  .db 0x12,0xfa,0x18,0x12,0x00,0x10,0xff
db_04AB:
  .db 0x12,0x18,0x13,0xf2
  .dw p_flv_04c6
  .db 0x00,0x00,0x08,0xf2
  .dw p_flv_04cf
  .db 0x00,0x00,0x08,0x12,0x18,0x0b,0x12,0x00,0x34,0x12,0xfb,0x26,0xfd
  .dw p_flv_0358

db_flv_04c6:
 p_flv_04c6:
  .db 0x12,0x00,0x10,0x12,0x18,0x0b,0xfd
  .dw p_flv_04d8

db_flv_04cf:
 p_flv_04cf:
  .db 0x12,0x00,0x08,0x12,0x18,0x0b,0x12,0x00,0x06

db_flv_04d8:
 p_flv_04d8:
  .db 0x12,0x00,0x22,0x12,0xfb,0x26,0x12,0x00,0x02,0xfc
  .db 0x2e
  .db 0x12,0xfa,0x18,0x12,0x00,0x20,0xff
db_04EA:
  .db 0x12,0x18,0x1e,0x12,0x00,0x14,0xf2
  .dw p_flv_0502
  .db 0x12,0x00,0x08,0xf2
  .dw p_flv_0502
  .db 0x12,0x00,0x18,0x12,0xfb,0x26,0xfd
  .dw p_flv_0358

db_flv_0502:
 p_flv_0502:
  .db 0x12,0xe2,0x01,0xf3
  .db 0x08,0x07,0x06,0x05,0x04,0x03,0x02,0x01,0xf5
  .db 0x23,0x00,0x48,0xff

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

; flag = ( num_bugs < param07 ) && ds_cpu0_task_actv[0x15]
       ld   a,(ds_new_stage_parms + 0x07)         ; number of aliens left when continous bombing can start
       ld   e,a
       ld   a,(b_bugs_actv_nbr)
       cp   e
       rl   b                                     ; Cy set if E > A ... shift into B ... clever.
       ld   a,(ds_cpu0_task_actv + 0x15)          ; cpu0:f_1F04 (reads fire button input)
       and  b
       and  #0x01                                 ; mask off bit-0
       ld   (b_92A0 + 0x0A),a                     ; continuous bombing flag (set here by tasking kernel)

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

       ld   (ds_9200_glbls + 0x17),a              ; 1 ... no_restart_stg

; if ( plyr_is_two_ship ) ...
       ld   a,(ds_plyr_actv +_b_2ship)
       and  a
       jr   z,l_0613

; ... handle 2-ship configuration
       ld   hl,#ds_sprite_posn + 0x60             ; fighter2 position
       ld   a,(hl)
       and  a
       jr   z,l_0613

       call hitd_fghtr_notif                      ; HL == &sprite_posn_base[0x60]  ...ship2 position
       ld   a,(b8_ship_collsn_detectd_status)     ; fighter hit notif (2)
       and  a
       jr   z,l_0613

       call hitd_fghtr_hit                        ; fighter2 collision
       xor  a
       ld   (ds_plyr_actv +_b_bmbr_boss_cflag),a  ; 0 ... enable capture-mode selection

l_0613:
; if ( ship position == 0 ) return
       ld   hl,#ds_sprite_posn + 0x62             ; fighter1 position
       ld   a,(hl)
       and  a
       ret  z

       call hitd_fghtr_notif                      ; HL == sprite_posn_base + 0x62 ... fighter (1) position (only L significant)
       ; L passed to c_0681_ship_collisn_detect preserved in E
       ld   a,(b8_ship_collsn_detectd_status)     ; fighter hit notif (1)
       and  a
       ret  z

; 621 bug or bomb collided with ship
       ld   a,(ds_plyr_actv +_b_2ship)
       and  a
       jr   z,l_0639_not_two_ship

       xor  a
       ld   (ds_plyr_actv +_b_bmbr_boss_cflag),a  ; 0 ... enable capture-mode selection
       ld   a,(ds_sprite_posn + 0x60)             ; get ship 2 position
       ld   (ds_sprite_posn + 0x62),a             ; ship_1_position = ship_2_position
       ld   a,(sfr_sprite_posn + 0x62)
       ld   hl,#sfr_sprite_posn + 0x60
       jr   l_064F                                ; handle ship collision

l_0639_not_two_ship:
       xor  a
       ld   (ds_cpu0_task_actv + 0x14),a          ; 0 ... f_1F85 (input and fighter movement)
       ld   (ds_cpu0_task_actv + 0x15),a          ; 0 ... f_1F04 (fire button input)
       ld   (ds_cpu1_task_actv + 0x05),a          ; 0 ... f_05EE (this task, fighter hit-detection)
       ld   (ds_99B9_star_ctrl + 0x00),a          ; 0 ... 1 when fighter on screen
       ld   (ds_9200_glbls + 0x17),a              ; 0 ... no_restart_stg (not docked fighters)

; hitd_fghtr_hit(tmpSx, SPR_IDX_SHIP + 0, 0)

;;=============================================================================
;; hitd_fghtr_hit()
;;  Description:
;;   handle a collision detected on fighter
;; IN:
;;   HL == &sprite_posn_base[0x60]  ... ship2 position (if call hitd_fghtr_hit)
;;   HL == &sprite_posn_sfr[0x60] ... (if jp  l_064F)

;;   E == object/index of fighter1 or fighter2 .b0
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
hitd_fghtr_hit:
       ex   de,hl
       ld   h,#>ds_sprite_posn                    ; read directly from SFRs (not buffer RAM) ... already 0'd by hitd_dspchr
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
       ld   (hl),#0x0B                            ; color
       dec  l
       ld   (hl),#0x20                            ; explosion tile
       ld   h,#>b_8800
       ld   (hl),#8                               ; .state, disposition from $80 to "exploding"
       inc  l
       ld   (hl),#0x0F                            ; mctrl_q index used for explosion counter
       dec  l
       ld   h,#>ds_sprite_ctrl
       ld   (hl),#0x08 | 0x04                     ; dblh, dblw
       xor  a
       ld   (ds_plyr_actv +_b_2ship),a            ; 0

       ld   a,(b8_9201_game_state)
       dec  a
       ld   (b_9AA0 + 0x19),a                     ; sound-fx count/enable registers, "bang" sound (not in Attract Mode)

; if no_restart_stg  ret ...
       ld   a,(ds_9200_glbls + 0x17)              ; no_restart_stg is set if docked fighters
       and  a
       ret  nz
; ... else  set restart_stg_flag
       inc  a
       ld   (ds_9200_glbls + 0x13),a              ; 1  ... restart stage flag (ship-input-movement flag not active )
       ret

;;=============================================================================
;; hitd_fghtr_notif()
;;  Description:
;;   hit notification for fighter
;; IN:
;;  L == sprite_posn_base[] ... offset (FIGHTER1 or FIGHTER2)
;; OUT:
;;  E == preserved offset passed as argument in L
;;-----------------------------------------------------------------------------
hitd_fghtr_notif:
       xor  a
       ld   (b8_ship_collsn_detectd_status),a     ; 0 ... fighter hit notif

       ld   h,#>b_8800
       ld   a,(hl)
       ld   h,#>ds_sprite_posn
       cp   #8                                    ; fighter disposition 08 if already dooomed ...
       ret  z                                     ; ... so gtf out!

       ld   a,(hl)                                ; sprite.pos.x
       ld   ixl,a
       inc  l
       ld   b,(hl)                                ; get row bits 0:7
       ld   h,#>ds_sprite_ctrl                    ; get row bit-8
       ld   a,(hl)
       rrca                                       ; y<8> -> Cy
       rr   b                                     ; Cy -> b<7>
       ld   ixh,b                                 ; y<15:8> of fixed-point
       dec  l
       ld   e,l                                   ; preserved object/index of fighter passed as argument in L

; if ( cpu0:f_2916  active ) ...
       ld   a,(ds_cpu0_task_actv + 0x08)          ; cpu0:f_2916 ...supervises attack waves
       and  a
       jr   z,l_06A8
; ... then ...
       ; only transients can do collision in attack wave
       ld   l,#0x38                               ; transients
       ld   b,#0x04
       jr   l_06AC_

; ... else ...not attack wave, set parameters to check all
l_06A8:
       ld   l,#0x00                               ; check objects $00 - $5E
       ld   b,#0x30

l_06AC_:
       call hitd_det_fghtr

       ld   l,#0x68                               ; bombs
       ld   b,#0x08
       call hitd_det_fghtr

       ret

;;=============================================================================
;; hitd_det_fghtr()
;;  Description:
;;   Do ship collision detection.
;; IN:
;;  L==starting object/index of alien or bomb
;;  B==repeat count ($08 or $30)
;;  ixl == fighter x<7:0>
;;  ixh == fighter y<15:8> of fixed-point
;; OUT:
;;  b8_ship_collsn_detectd_status
;;-----------------------------------------------------------------------------
hitd_det_fghtr:
while_06B7:
       ld   h,#>b_9200_obj_collsn_notif           ; sprt_hit_notif
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

       sub  ixl                                   ; x<7:0>
       sub  #7
       add  a,#13
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
       ld   (b8_ship_collsn_detectd_status),a     ; 1 ... fighter hit notif

       or   a                                     ; nz if fighter hit
       ex   af,af'
       jp   hitd_dspchr                           ; return to 'call hitd_det_fghtr'
l_06F0:
       inc  l
       inc  l
       djnz while_06B7

       ret

;;=============================================================================
;; f_06F5()
;;  Description:
;;    rocket motion and hit-detection manager
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
f_06F5:
       ld   de,#b_92A0 + 0x04 + 0                 ; rocket "attribute"
       ld   hl,#ds_sprite_posn + 0x64             ; rocket
       call rckt_man

       ld   de,#b_92A0 + 0x04 + 1                 ; rocket "attribute"
       ld   hl,#ds_sprite_posn + 0x66             ; rocket
       ; call rckt_man

;;=============================================================================
;; rckt_man()
;;  Description:
;;    rocket motion and hit-detection manager
;; IN:
;;   DE == pointer to rocket "attribute", e.g. &b_92A0_4[0], &b_92A0_4[1]
;;         Value is E0 if the ship is oriented normally, not rotated.
;;         bit7=orientation, bit6=flipY, bit5=flipX, 1:2=displacement
;;   HL == pointer to rocket sprite 0 or 1 ... sprite_posn[$64], sprite_posn[$66]
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
rckt_man:
; if (0 == rocket.posn[hl].x<7:0>) return
       ld   a,(hl)
       and  a
       ret  z

; else ...
       ld   a,(de)                                ; rocket "attribute"
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
; add new dX
       add  a,(hl)                                ; dX is 0 unless the ship is spinning/captured
       ld   (hl),a

; if (mrw_sprite.posn[hl].b0 >= 240) ... one test for X limits ($F0) or < 0 ($FF)
       cp   #0xF0
       jr   nc,l_0763_disable_rocket

; rocket.sX passed to hitd_det_rckt
       ld   ixl,a


; NOW onto sY...............

       inc  l                                     ; offset[1] ... sprite_posn.sy
; get the stashed dY
       ex   af,af'
; if ( ! flipX ) then  dY = -dY
       bit  5,b                                   ; inverted flipX
       jr   z,l_0729
       neg                                        ; negate dY if NOT flipX (2's comp)
l_0729:
       ld   c,a                                   ; stash the dY

; add new dY to .sY<7:0>
       add  a,(hl)
       ld   (hl),a                                ; sprite.posn[hl].b1

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

; rocket.sy<8:1>, passed to hitd_det_rckt in IXH
l_0738:
       ld   c,(hl)                                ; rocket.sy<8>
       ld   h,#>ds_sprite_posn
       ld   a,(hl)                                ; rocket.sy<7:0>
       rrc  c                                     ; rotate bit-8 into Cy
       rra                                        ; rotate bit-8 from Cy into A
       ld   ixh,a                                 ; stash sy<8:1> for hit-detection parameter

; if ( rocket.sY < 40 || rocket.sY >= 312 ) then _disable_rocket
       cp   #0x28 >> 1                            ; 0x14
       jr   c,l_0760_disable_rocket_wposn         ; L is offset to sY, so first L--
       cp   #0x138 >> 1                           ; 0x9C
       jr   nc,l_0760_disable_rocket_wposn        ; L is offset to sY, so first L--

; index of rocket object/sprite passed through to hitd_dspchr (odd, i.e. b1)
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
       call hitd_det_rckt
       ret

; terminate out of bounds rockets
l_0760_disable_rocket_wposn:
       dec  l                                     ; .b0 (sX)
       ld   h,#>ds_sprite_posn                    ; x

; when testing X limits, &sprite_posn[0] already in H so skip loading it
l_0763_disable_rocket:
       ld   (hl),#0                               ; x
       ld   h,#>ds_sprite_ctrl
       ld   (hl),#0                               ; attribute bits

       ret

;;=============================================================================
;; hitd_det_rckt()
;;  Description:
;;   rocket hit detection
;; IN:
;;  E == LSB of pointer to object/sprite passed through to
;;       hitd_dspchr (odd, i.e. offset to b1)
;;  HL == pointer to sprite.posn[], starting object object to test ... 0, or
;;        +8 skips 4 objects... see explanation at l_0757.
;;  B == count ... $30, or ($30 - 4) as per explanation above.
;;  IXL == rocket.sx
;;  IXH == rocket.sy<8:1>
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
hitd_det_rckt:

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

; if EXPLODING or SCORE_BITM then next object
       ld   a,(hl)
       ld   c,a
       and  #0xFE                                 ; tests for SCORE_BITM (5) also
       cp   #4                                    ; disposition EXPLODING
       jr   z,l_07B4_next_object

; test dX and dY for within +/- 3 pixels, using the addition
; offset with "Cy" so only 1 test needed for (d>-3 && d<+3 )

; check Y coordinate ... sY<8:1> in A
       inc  l
       ld   h,#>ds_sprite_ctrl                    ; sprite.sy<8>
       ld   d,(hl)
       ld   h,#>ds_sprite_posn                    ; sprite.sy<7:0>
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
       ex   af,af'                                ; object status to hitd_dspchr

       ld   a,(ds_plyr_actv +_b_2ship)
       and  a

       ld   a,(hl)                                ; sprite.sX

       jr   nz,l_07A4                             ; and  a

       sub  ixl                                   ; sprite.sX -= rocket.sX
       sub  #6
       add  a,#11
       jr   c,hitd_dspchr_rckt
       jr   l_07B4_next_object

l_07A4:
       sub  ixl                                   ; sprite.sX -= rocket.sX
       sub  #20
       add  a,#11
       jr   c,hitd_dspchr_rckt
       add  a,#4
       jr   c,l_07B4_next_object
       add  a,#11
       jr   c,hitd_dspchr_rckt

l_07B4_next_object:
       inc  l
       inc  l
       djnz l_076A_while_object

       ret

;;=============================================================================
;; hitd_dspchr()
;;  Description:
;;   Detect collisions from the reference of the rocket ... update hit count
;;   and call common subroutine.
;; IN:
;;   L == offset/index of destroyed enemy/bomb sprite[n].b1
;;   E == offset/index of sprite[rocket.n].b1
;;   A' == object status
;; OUT:
;;  ...
;; RETURN:
;;   1 on jp   l_07B4_next_object
;;   0
;;-----------------------------------------------------------------------------
hitd_dspchr_rckt:

       ld   a,l                                   ; stash L, use HL for 16-bits math
       ld   hl,(ds_plyr_actv +_w_hit_ct)
       inc  hl
       ld   (ds_plyr_actv +_w_hit_ct),hl
       ld   l,a                                   ; restore L

; hitd_dspchr

;;=============================================================================
;; hitd_dspchr()
;;  Description:
;;   collisions are detected from the reference of the rocket or fighter - this
;;   function is common to both rocket and fighter hit detection, and
;;   dispatches the target appropriately.
;; IN:
;;   L == offset/index of destroyed enemy/bomb sprite[n].b1
;;   E == offset/index of rocket[n].b1 ... sprite.posn[RCKTn].y must
;;        be set to zero as required for correct handling in rckt_sprite_init
;;   E == offset/index of fighter[n].b0 ... sprite.ctrl[FGHTRn].b0 is set to 0 ... does it matter?
;;   A' == object status
;; OUT:
;;  ...
;; RETURN:
;;  ...
;;-----------------------------------------------------------------------------
hitd_dspchr:
       ld   d,#>ds_sprite_posn                    ; _sprite_posn[E].b0 = 0 ... sX
       xor  a
       ld   (de),a
       ld   d,#>ds_sprite_ctrl                    ; _sprite_ctrl[E].b0 = 0 ... attributes
       ld   (de),a

       inc  l
       ld   h,#>ds_sprite_code                    ; sprite.cclr.b1 ...
       ld   a,(hl)
       ld   c,a                                   ; ... for later ....
       and  a
       jp   z,l_08CA_hit_green_boss               ; color map 0 is the "green" boss
       dec  l
       cp   #0x0B                                 ; color map $B is for "bombs"
       jr   z,l_0815_bomb_hit

; if rocket or ship collided with bug
       ex   af,af'                                ; un-stash parameter ... 1 if moving bug (hit by rocket or fighter)
       jr   nz,l_081E_hdl_flyng_bug               ; will come back to $07DB or l_07DF

; else if rocket hit stationary bug
       ex   af,af'                                ; re-stash parameter

l_07DB:
; set it up for elimination
       ld   h,#>b_9200_obj_collsn_notif           ; = $81
       ld   (hl),#0x81

l_07DF:
; if capture boss ...
       ld   a,(ds_plyr_actv +_b_bmbr_boss_cobj)
       sub  l
       jr   nz,l_07EC
; ... then ...
       ld   (ds_plyr_actv +_b_bmbr_boss_cflag),a  ; 0: shot the boss that was starting the capture beam
       inc  a
       ld   (ds_plyr_actv +_b_bmbr_boss_cobj),a   ; 1: invalidate the capture boss object

l_07EC:
; use the sprite color to get index to sound
       push hl                                    ; &obj_collsn_notif[L]

; if sprite color == 7 ... (check for red captured ship)
       ld   a,c                                   ; .... sprite.cclr.b1
       cp   #0x07
       jr   nz,l_07F5
       dec  a
       jr   l_07F8_
; ... else ...
l_07F5:
       dec  a
       and  #0x03

l_07F8_:
       ld   hl,#b_9AA0 + 0x01                     ; b_9AA0[1 + A] = 1 ... sound-fx count/enable registers
       rst  0x10                                  ; HL += A
       ld   (hl),#1

; if sprite color == 7
       ld   a,c                                   ; .... sprite.cclr.b1
       cp   #0x07
       jr   nz,l_0808
       ld   hl,#ds_plyr_actv +_b_bmbr_boss_cflag  ; 0 ... enable capture-mode selection
       ld   (hl),#0

l_0808:
; _bug_collsn[ color ] += 1
       ld   hl,#ds_bug_collsn_hit_mult + 0x00     ; rocket/bug or ship/bug collision
       rst  0x10                                  ; HL += A ... _collsn_hit_mult[sprite.cclr.b1]
       inc  (hl)

       ex   af,af'                                ; un-stash parameter/flag
       jr   z,l_0811
       inc  (hl)                                  ; shot blue boss
l_0811:
       pop  hl
       jp   l_07B4_next_object

; this invalidates the bomb object... but what about the ship?
l_0815_bomb_hit:
       ld   h,#>ds_sprite_posn                    ; sprite[L].sx = 0 ... bomb colliding with fighter
       ld   (hl),#0
       ld   h,#>b_8800                            ; sprt_mctl_objs[L].state
       ld   (hl),#0x80                            ; disposition = INACTIVE

       ret

; Handle flying bug collision (bullet or ship). Not stationary bugs.
l_081E_hdl_flyng_bug:
       ld   h,#>b_8800
       push hl
       ex   af,af'                                ; re-stash parameter
       inc  l
       ld   a,(hl)                                ; sprt_mctl_objs[L].mctl_idx

       ld   h,#>ds_bug_motion_que                 ; bug_motion_que[A].b13 = 0 (release this slot)
       add  a,#0x13
       ld   l,a
       ld   (hl),#0

       ld   hl,#b_bug_flyng_hits_p_round          ; +=1
       inc  (hl)

;; bug_flying_hit_cnt is probably only meaningful in challenge rounds. In other
;; rounds it is simply intiialized to 0 at start of round.
       ld   hl,#w_bug_flying_hit_cnt              ; hit_cnt -= 1 ... reset 8 each challenge_wave
       dec  (hl)
       pop  hl                                    ; &sprt_mctl_objs[L].mctl_idx

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
       ld   a,c                                   ; .... sprite.cclr.b1
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
       ld   a,c                                   ; .... sprite.cclr.b1
       cp   #0x01                                 ; color map 1 ... blue boss hit once
       jp   nz,l_07DB

; ... else ... handle blue boss
; check for captured-fighter
       push de                                    ; &ds_sprite_ctrl[E]
       ld   a,l
       and  #0x07                                 ; mask off to reference the captured ship
       ld   e,a
       ld   d,#>b_8800
       ld   a,(de)
       cp   #9                                    ; is this a valid capture ship status ...i.e. diving? ...status may still...
       jr   nz,l_0899                             ; ...be $80 meaning I have killed the boss before he pulls the ship all in!
; captured ship is diving
       push hl                                    ; stash the boss object locator e.g. b_8830
       ex   de,hl                                 ; HL := &sprt_mctl_objs[ ].b0
       inc  l
       ld   a,(hl)                                ; sprt_mctl_objs[ HL ].mctl_idx
       add  a,#0x13                               ; mctl_mpool[n].b13
       ld   e,a
       ld   d,#>ds_bug_motion_que                 ; mctl_mpool[n].b13 == 0 ... make slot inactive
       xor  a
       ld   (de),a
       ld   h,#>ds_sprite_code
       ld   (hl),#9                               ; color map 9 for white ship
       dec  l
       ld   a,l
       ld   (ds_plyr_actv +_b_bmbr_boss_cobj),a   ; updated object locator token of rescued ship   (token was 1)
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
       push hl                                    ; sprt_mctl_objs[L] (boss) e.g. b_8830
       ld   a,#6
       ld   (ds4_game_tmrs + 1),a                 ; 6 ... captured ship timer
       ld   a,l
       and  #7                                    ; gets offset of object from $30
       ld   hl,#ds_plyr_actv +_ds_bmbr_boss_scode ; bonus code/scoring attributes for 1 of 4 flying bosses
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
       ld   (b_bug_que_idx),a                     ; 12 ... nbr of queue structures

       ld   hl,#b_bugs_flying_cnt                 ; capture the (previous) count and zero the current count
       ld   a,(hl)
       ld   (hl),#0
       inc  hl                                    ; b_bugs_flying_nbr
       ld   (hl),a                                ; = bugs_flying_cnt

; traverse the object-motion queue
for__pool_idx:
       bit  0,0x13(ix)                            ; check for activated state
       jp   z,next__pool_idx

       ld   hl,#b_bugs_flying_cnt                 ; +=1
       inc  (hl)

       ld   l,0x10(ix)                            ; object identifier...8800[L]
       ld   h,#>b_8800

; 9 is diving, 7 is spawning, 3 (and 6) bomb?
; if (!(A == 3 || A == 7 || A == 9)) ...
       ld   a,(hl)
       cp   #3                                    ; status 3 is what?
       jr   z,mctl_fltpn_dspchr
       cp   #9                                    ; if 8800[L]==9 ... flying into formation or diving out.
       jr   z,mctl_fltpn_dspchr
       cp   #7                                    ; if 8800[L]==7 ... spawning (new stage)
; ... then ...
; status==4 ... shot a non-flying capturing boss (ship will soon go rogue and launch out)
; HL==8830, *HL==04, 8831==40
       jp   nz,case_0E49_make_object_inactive     ; sets object state to $80


mctl_fltpn_dspchr:
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
; if (token < 0xEF) ... then skip processing of jp-table
       cp   #0xEF
       jp   c,l_0BDC_flite_pth_load               ; if token < $ef, continue to flight-path handler

; else ...
;  complimented token indexes into jp-tbl for selection of next state

; the current data pointer could be copied from HL into 92FA,92FB or loaded directly from ix($08)ix($09) by handler
;
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
case_0942:  ; $0A
       ld   e,0x10(ix)                            ; offset of object ...8800[E]
       ld   d,#>b_8800
       ld   a,#0x03                               ; set to state 3
       ld   (de),a
       inc  hl                                    ; ptr to data table
       jp   j_090E_flite_path_init

; continuous-bombing mode
case_094E:  ; $10 (0xEF)
       ld   a,(ds_new_stage_parms + 0x09)         ; jumps the pointer on/after stage 8
       and  a
       jp   l_0959

; attack wave
case_0955:  ; $0F
       ld   a,(ds_new_stage_parms + 0x08)         ; jumps the pointer on/after stage 8
       and  a

l_0959:
       jr   z,l_0963

; not until stage 8 ... load a pointer from data tbl into .p08 (09)
       inc  hl                                    ; ptr to data table
       ld   a,(hl)
       inc  hl
       ld   h,(hl)
       ld   l,a
       jp   l_0B8C                                ; skips inc hl ($0B8C), update $08, $09, $0D, break

l_0963:
; skip loading new address
       inc  hl                                    ; ptr to data table
       inc  hl                                    ; ptr to data table
       jp   l_0B8B                                ; inc hl and finalize

; diving attacks stop and bugs go home
case_0968:  ; $0E
       ld   e,0x10(ix)                            ; home_posn_rc[ obj_id ]
       ld   d,#>sprt_fmtn_hpos                    ; home_posn_rc[ ix($10) ]
       ld   a,(de)                                ; row position index
       ld   e,a
       ld   d,#>ds_hpos_loc_orig                  ; b1: copy of origin data
       inc  e
       ld   a,(de)                                ; copy of origin data
       add  a,#0x20
       ld   0x01(ix),a                            ; sY<8:1>
       jp   l_0B8B                                ; inc hl and finalize

; yellow alien special attack leader started dive ready to replicate
case_097B:  ; $0D
       push hl                                    ; ptr to data table
       ld   e,0x10(ix)                            ; object offset of bee that is to be split
; find an inactive ($80) yellow alien or getout.
       ld   hl,#b_8800 + 0x38
       ld   b,#4
l_0984:
       ld   a,(hl)
       rlca                                       ; test bit 7 (0x80 if disposition == inactive)
       jr   c,l_098F_do_split_off_bonus_bee
       inc  l
       inc  l
       djnz l_0984
       jp   l_09FA_bonusbee_creat_fail

l_098F_do_split_off_bonus_bee:
       ld   h,#>ds_sprite_code
       ld   d,h
       ld   a,(de)                                ; _sprite_code[index attack leader]
       ld   (hl),a
       inc  l                                     ; .b1
       inc  e                                     ; .b1
       ld   a,(de)                                ; _sprite_cclr[index attack leader]
       ld   (hl),a
       dec  l                                     ; .b0
       ld   a,l
       ex   af,af'                                ; stash index of spawning yellow alien

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
       ld   a,0x00(ix)                            ; coordinate of parent alien
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

; load new data pointer from data and store in flite q object
       pop  hl                                    ; special attack, pushes hl right away
       inc  hl
       ld   a,(hl)
       ld   0x08(iy),a
       inc  hl
       ld   a,(hl)
       ld   0x09(iy),a

       ld   0x0A(iy),#0x01
       ld   0x0B(iy),#0x02
       ld   0x0D(iy),#0x01
       ex   af,af'                                ; index of spawning yellow alien
       ld   0x10(iy),a
       ld   e,a
       ld   d,#>b_8800
       ld   a,#9                                  ; 09: diving -> 8800[i]
       ld   (de),a
       inc  e
       ld   a,iyl
       ld   (de),a
       inc  hl                                    ; new ptr loaded to b08/b09, but HL is advanced, still in same data series
       jp   j_090E_flite_path_init

l_09FA_bonusbee_creat_fail:
; skip two bytes of 16-bit address and inc hl to next data
       pop  hl                                    ; ptr to data table
       inc  hl
       inc  hl
       inc  hl
       jp   j_090E_flite_path_init

; Red alien element has left formation - use deltaX to fighter to select flight
; plan. This occurs when approximately mid-screen, after initial jump from
; formation.
case_0A01:  ; $0C
; stash 2 copies of hl
       push hl                                    ; ptr to data table
       ex   de,hl

       ld   a,(b_9215_flip_screen)
       ld   c,a

; setup horizontal limits for targetting
       ld   a,(ds_sprite_posn + 0x62)             ; ship_1_position
       cp   #0x1E
       jr   nc,l_0A10
       ld   a,#0x1E
l_0A10:
       cp   #0xD1
       jr   c,l_0A16
       ld   a,#0xD1

l_0A16:
       bit  0,c
       jr   z,l_0A1E
       add  a,#0x0E
       neg

; (fighterX - alienX) / 4 ... 9.7 fixed point math
l_0A1E:
       srl  a
       sub  0x03(ix)
       rra                                        ; divide again by 2 ... Cy from sub into b7
       bit  7,0x13(ix)                            ; if !z  then  a=-a
       jr   z,l_0A2C_
; negative (clockwise) rotation ... approach to waypoint is from right to left
       neg

l_0A2C_:
; test if offset'ed result still out of range negative (overflow if addition to negative delta is greater than 0)
       add  a,#0x30>>1                            ; offset to positive range for selection of index
       jp   p,l_0A32
       xor  a                                     ; result still negative (S is set )
l_0A32:
       cp   #0x30
       jr   c,l_0A38
       ld   a,#0x2F                               ; set upper limit
l_0A38:
       ld   h,a
       ld   a,#6
       call c_0EAA                                ; HL = HL / A
       ld   a,h
       inc  a
       ex   de,hl                                 ; restore hl
       rst  0x10                                  ; HL += A
       ld   a,(hl)
       ld   0x0D(ix),a

       pop  hl                                    ; restore hl again
       ld   a,#9
       rst  0x10                                  ; HL += A
; don't actually need to load from l and h here ;)
       ld   0x08(ix),l                            ; pointer.b0
       ld   0x09(ix),h                            ; pointer.b1
       jp   l_0BFF_flite_pth_skip_load            ; save pointer and goto _flite_pth_cont

; capturing boss starts dive
case_0A53:  ; $0B
       push hl
       ld   a,(b_9215_flip_screen)
       ld   c,a
       ld   a,(ds_sprite_posn + 0x62)             ; ship_1_position
       add  a,#3
       and  #0xF8
       inc  a
       cp   #82 >> 1                              ; $29
       jr   nc,l_0A66
       ld   a,#0x29
l_0A66:
       cp   #404 >> 1                             ; $CA
       jr   c,l_0A6C
       ld   a,#402 >> 1                           ; $C9
l_0A6C:
       bit  0,c                                   ; check flip screen
       jr   z,l_0A73
       add  a,#13                                 ; flipped
       cpl
l_0A73:
       ld   (ds5_928A_captr_status + 0x00),a
       srl  a
       ld   e,a
       ld   d,#0x48
       ld   h,0x01(ix)
       ld   l,0x03(ix)
       call c_0E5B                                ; HL = c_0E5B(DE, H, L) ... determine rotation angle
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
case_0AA0:  ; $04
       push hl                                    ; ptr to data table

       ld   l,0x10(ix)                            ; update object disposition ... i.e. 8800[L]
       ld   h,#>b_8800
       ld   (hl),#9                               ; disposition = 9: diving/homing (currently 3)

       ld   h,#>sprt_fmtn_hpos                    ; home_posn_rc[ ix($10) ]
       ld   c,(hl)                                ; row index
       inc  l
       ld   l,(hl)                                ; column index

       ld   h,#>ds_hpos_loc_t
       ld   b,(hl)                                ; x offset
       inc  l
       ld   e,(hl)                                ; x coordinate (ds_hpos_loc_orig)

       ld   l,c                                   ; row position index
       ld   c,(hl)                                ; y offset
       inc  l
       ld   d,(hl)                                ; y coordinate (ds_hpos_loc_orig)

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
       ld   h,0x01(ix)                            ; .b01 ... sY<8:1>
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
       ld   l,h                                   ; x, .b01 (bits<8:1> of integer portion)
       ld   h,e                                   ; y, .b01 (bits<8:1> of integer portion)

       ld   c,d                                   ; C is not used?

       pop  de                                    ; abs row pix coord & abs col pix coord >> 1

       call c_0E5B                                ; HL = mctl_rotn_hp(DE, H, L)
       srl  h
       rr   l
       ld   0x04(ix),l
       ld   0x05(ix),h
       ld   0x06(ix),d                            ; origin home position y (bits 15:8) ... from hpos_loc_orig.x
       ld   0x07(ix),e                            ; origin home position x (bits 15:8) ... from hpos_loc_orig.y
       set  6,0x13(ix)                            ; if set, flite path handler checks for home

       pop  hl                                    ; ptr to data table
       inc  hl
       jp   j_090E_flite_path_init

; attack elements that break formation to attack ship (level 3+)
case_0B16:  ; $01
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
       call c_0EAA                                ; HL = HL / A
       ld   a,h
       ex   de,hl
       rst  0x10                                  ; HL += A
       ld   a,(hl)
       ld   0x0D(ix),a

       pop  hl
       ld   a,#9
       rst  0x10                                  ; HL += A
       jp   l_0BFF_flite_pth_skip_load            ; save pointer and goto _flite_pth_cont

; creatures that are returning to base: moths or bosses from top of screen,
; bees from bottom of loop-around, and "transients"
case_0B46: ; $02
l_0B46:
; ld new data ptr into de and ex into hl ... resultant de not used
       inc  hl                                    ; ptr to data table
       ld   e,(hl)
       inc  hl
       ld   d,(hl)
       ex   de,hl                                 ; new pointer to HL
       jp   j_090E_flite_path_init

; bee dive and starting loopback, or boss left position and starting dive down
case_0B4E:  ; $03
       inc  hl                                    ; ptr to data table
       ld   e,(hl)
       inc  hl
       ld   0x06(ix),e                            ; origin home position y (bits 15:8)
       ld   0x07(ix),#0                           ; origin home position x (bits 15:8)
       set  5,0x13(ix)                            ; bee or boss dive
       jp   l_0BFF_flite_pth_skip_load            ; save pointer and goto _flite_pth_cont

; red alien flew through bottom of screen to top, heading for home
; yellow alien flew under bottom of screen and now turns for home
case_0B5F:  ; $06
       ld   a,(b_9215_flip_screen)
       ld   c,a

       ld   e,0x10(ix)                            ; home_posn_rc[ obj_id + 1 ]
       inc  e
       ld   d,#>sprt_fmtn_hpos                    ; home_posn_rc[ ix($10) + 1 ] ... column position index
       ld   a,(de)
       ld   e,a
       ld   d,#>ds_hpos_spcoords                  ; col pix coordinate, lsb only
       ld   a,(de)
       bit  0,c                                   ; check if flip-screen
       jr   z,l_0B76
       add  a,#0x0E
       neg
l_0B76:
       srl  a
       ld   0x03(ix),a                            ; .cx.pair.b1

       ld   a,(b_92A0 + 0x0A)                     ; if continuous bombing flag is set, trigger dive attack sound b_9AA0[0x13]
       and  a
       jp   z,l_0B8B                              ; inc hl and finalize

       ld   (b_9AA0 + 0x13),a                     ; ~0 ... sound-fx count/enable registers, bug dive attack sound
       jr   l_0B8B                                ; inc hl and finalize

; red alien flew through bottom of screen to top, heading for home
; yellow alien flew under bottom of screen and now turns for home
case_0B87:  ; $07
       ld   0x01(ix),#0x0138>>1                   ; sY<15:8> ... $0138==312 ... $0138/2=$9C
l_0B8B:
       inc  hl                                    ; data pointer
l_0B8C:
       ld   0x08(ix),l                            ; .b00
       ld   0x09(ix),h                            ; .b01
       inc  0x0D(ix)

       jp   next__pool_idx

; in an attack convoy ... changing direction
case_0B98:  ; $08
; if (0x38 != (0x38 & ds_bug_motion_que[b_bug_que_idx].b10))  hl += 3 ...
       ld   a,0x10(ix)                            ; offset of object ...8800[L]
       and  #0x38
       cp   #0x38                                 ; "transient"? ($38, $3A, $3C, $3E)

; from case_0BD1 ... if (1 == cont_bmb_flag && 0 == task_actv[0x1D]) then ... HL += 3
l_0B9F:
       jp   z,l_0B46                              ; load next ptr ... _flite_path_init
; ptr to data table inc 3x ... (2 incs to skip address in table e.g. $0024?)
       inc  hl
       inc  hl
       inc  hl
       jp   j_090E_flite_path_init

; one red moth left in "free flight mode"
case_0BA8:  ; $09
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
       ld   a,(b_92C0 + 0x08)                     ; bomb drop enable flags
       ld   0x0F(ix),a                            ; b_92C0[$08] ... bomb drop enable flags
       jp   l_0B8B                                ; inc hl and finalize

; homing, red transit to top, yellow from off-screen at bottom or skip if in continuous mode
case_0BD1:  ; $05
; if (1 == cont_bmb_flag && 0 == task_actv[0x1D]) then pD += 3 else pD = *(pHL)
       ld   a,(b_92A0 + 0x0A)                     ; continuous bombing flag, test for reload data pointer
       ld   c,a
       ld   a,(ds_cpu0_task_actv + 0x1D)          ; f_2000 (destroyed boss that captured ship) test for reload data pointer
       dec  a
       and  c
       jr   l_0B9F                                ; load next ptr or skip


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

l_0BFF_flite_pth_skip_load:
       ld   0x08(ix),l                            ; pointer.b0
       ld   0x09(ix),h                            ; pointer.b1


; process this time-step of flite path, continue processing on this data-set
; check home positions
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
       ld   a,0x03(ix)                            ; detection of homespot... (ix)0x03-(ix)0x07 == 0
       sub  0x07(ix)                              ; detection of homespot... (ix)0x03-(ix)0x07 == 0
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
       sub  0x06(ix)                              ; origin home position y (bits 15:8)
       jr   z,l_0C3E
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

; load DE with local copy of rotation value and go ahead and update pool slot
l_0C46:
       ld   b,0x0C(ix)                            ; add to (ix)0x04
       ld   a,0x04(ix)
       ld   e,a                                   ; need this later ...
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
       ld   a,e                                   ; from previous (ix)0x04
       ld   c,d                                   ; from previous (ix)0x05 ... need this later ...
       bit  0,c
       jr   z,l_0C6D
       cpl                                        ; invert bits 7:0 in quadrant 1 and 3 ...
l_0C6D:
; ... select vertical tile if within 15 degrees of 90 or 270
       add  a,#21                                 ; 1024 / ( 6 * 4 ) == 42
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
       and  #0x03                                 ; <0> flip up/down  <1> flip l/r, double-x/double-y bits not used
       ld   (hl),a                                ; mrw_sprite[L].ctrl.b0 = A & 0x03

; choose x or y displacement vector to apply on this update
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

; compute increment and update selected coordinate
       push hl                                    ; &mrw_sprite[L].ctrl.b0
       push ix
       pop  hl                                    ; &bug_motion_que[n].b00

       ld   b,a                                   ; (ix)0x0A or (ix)0x0B

       ld   a,d                                   ; saved from (ix)0x05  ( from C46 )
       and  #0x03
       ld   d,a

;         90          - angle in degrees
;       1  | 0        - quadrant derived from 10-bit angle
;    180 --+-- 0      - each tile rotation is 15 degrees (6 tiles per quadrant)
;       2  | 3
;         270
; xor bit-7 with bit-8 ... test for orientation near 0 or 180
; i.e. < xx80 in quadrant 0 & 2, and >= xx80 in quadrant 1 & 3
       rlc  e                                     ; e saved from (ix)0x04   ( from C46 )
       rl   d
       push de                                    ; adjusted rotation angle, restores to HL below .....
       xor  d
       rrca                                       ; xor result in A<0>
       jr   c,l_0CBF                              ; check for Cy shifted into bit7 from rrca
       inc  l
       inc  l                                     ; L == offset to b02 ... update the pointer for horizontal travel

l_0CBF:
; .b04+.b05 is angle in 10-bits. bits<9:7> together give the quadrant and fraction of 90
; degrees, indicating whether the "primary" component of the magnitude should be negative.
; 0 1  1 - 3   Any of these would result in d<2> set after the "inc d".
; 1 0  0 - 4   Remembering they have been <<1, it means the lowest bit was
; 1 0  1 - 5   .b04<7> (degree 0-89) and the upper 2 bits were .b05<1:0> (quadrant)
; 1 1  0 - 6   Taking the quadrant and angle together, the range is 135-304 degrees.
       inc  d
       bit  2,d
       ld   a,b                                   ; ... restore A: 0x0A(ix) or 0x0B(ix)
       jr   z,l_0CC7
       neg                                        ; negate primary component for 135-305 degrees
l_0CC7:
; A is actually bits<15:7> of addend (.b00/.b02 in fixed point, 9.7)
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
       jr   nc,l_0CE3                             ; bit<0> into Cy (which was actually bit<7>
       ld   a,l
       xor  #0x7F                                 ; compliment bits<6:0>
       ld   l,a
l_0CE3:
       ld   a,b                                   ; ... restore A: 0x0A(ix) or 0x0B(ix)
       ld   b,h                                   ; msb of adjusted angle
       ld   h,#0
       call c_0E97                                ; HL = L * A

;             . 90          - angle in degrees
;             1  | 0        - quadrant derived from 10-bit angle
;          180 --+-- 0      - each tile rotation is 15 degrees (6 tiles per quadrant)
;           . 2  | 3 .
;             . 270
;      b9 b8  b7
;     q 0  0   0  -> 010 -> 001
;       0  0   1  -> 011 -> 010
;     q 0  1   0  -> 000 -> 111  x  .
;       0  1   1  -> 001 -> 000
;     q 1  0   0  -> 110 -> 101  x  .
;       1  0   1  -> 111 -> 110  x  .
;     q 1  1   0  -> 100 -> 011
;       1  1   1  -> 101 -> 100  x  .

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

       pop  hl                                    ; &mrw_sprite.ctrl[L].b1

; almost done ... update the sprite x/y positions
l_0D03_flite_pth_posn_set:
       ld   a,(b_9215_flip_screen)
       ld   c,a

; extract x-coord and adjust for homing if needed
; fixed point 9.7 in .b02.b03 - left shift integer portion into A ... carry in to <0> from .b02<7>
       ld   h,#>ds_sprite_posn
       ld   d,0x03(ix)                            ; bits<1:6> of x pixel ... could load directly to A
; set Cy from .b02<7>
       ld   a,#0x7F
       cp   0x02(ix)

       ld   a,d                                   ; (ix)0x03
       rla                                        ; rotate Cy into A<0> (.b02<7>)

       bit  0,c                                   ; test flip screen
       jr   z,l_0D1A
       add  a,#0x0D                               ; flipped
       cpl
l_0D1A:
       bit  6,0x13(ix)                            ; if !z, add  a,(ix)0x11 ... relative offset
       jr   z,l_0D23
       add  a,0x11(ix)                            ; heading home (add x-offset ... already bits<7:0>)
l_0D23:
       ld   (hl),a                                ; &sprite[n].posn.x

; extract y-coord and adjust for homing if needed
       inc  l                                     ; sprite[n].posn.sy<0:7>
       ld   b,0x01(ix)
; set Cy from .b00<7>
       ld   a,#0x7F
       cp   0x00(ix)

       rl   e                                     ; rotate Cy into E<0>
       ld   a,b                                   ; (ix)0x01

       bit  0,c                                   ; test flip screen
       jr   nz,l_0D38
       add  a,#(<(-0x0160 - 0x02))>>1             ; not flipped ... lsb of result, right-shift 1
       cpl
       dec  e                                     ; compliment bit-0 of 9-bit integer portion

l_0D38:
; E<0> <- Cy <- 7 6 5 4 3 2 1 0 <- Cy <- E<0>
       rr   e                                     ; bit-0 of 9-bit integer portion into Cy
       rla                                        ; Cy (bit0) into lsb, bit8 into Cy
       rl   e                                     ; bit8 from Cy into E<0> (bit8 of sprite_y)

       bit  6,0x13(ix)                            ; if !z, add  a,(ix)0x12
       jr   z,l_0D50
; r16.word += mctl_mpool[mpidx].b12
       add  a,0x12(ix)                            ; heading home (step y coord)
       ld   d,a                                   ; stash bits<7:0> of sum
       rra                                        ; somehow the rest of this propogates bit9 of the sum into E<0>
       xor  0x12(ix)
       rlca
       ld   a,d
       jr   nc,l_0D50
       inc  e

l_0D50:
       ld   (hl),a                                ; sprite[n].posn.sy<7:0>
       ld   h,#>ds_sprite_ctrl                    ; sprite[n].posn.sy<8>
       rrc  (hl)
       rrc  e
       rl   (hl)                                  ; sprite[n].posn.sy<8>


; Once the timer in $0E is reached, then check conditions to enable bomb drop.
; If bomb is disabled for any reason, the timer is restarted.
       dec  0x0E(ix)                              ; countdown to enable a bomb
       jp   nz,next__pool_idx

       srl  0x0F(ix)                              ; these bits enable bombing
       jp   nc,l_0DF5_next_superloop_and_reload_0E

       ld   a,0x01(ix)                            ; if .cy.pair.b1 > $4C
       cp   #152>>1                               ; 0x4C
       jp   c,l_0DF5_next_superloop_and_reload_0E

       ld   a,(ds_cpu0_task_actv + 0x15)          ; f_1F04 ...fire button input
       and  a
       jp   z,l_0DF5_next_superloop_and_reload_0E

       ld   a,(ds4_game_tmrs + 1)
       and  a
       jp   nz,l_0DF5_next_superloop_and_reload_0E

; check for available bomb ... bombs are rendered inactive at l_0815
       ex   de,hl                                 ; &sprite.ctrl[bmbr].b1 to DE ...
       ld   hl,#b_8800 + 0x68                     ; bomb0 object/index
       ld   b,#8                                  ; check 8 positions
l_0D82:
       ld   a,(hl)                                ; _objs[BOMB0].state
       cp   #0x80                                 ; INACTIVE
       jr   z,l_0D8D_got_a_bullet
       inc  l
       inc  l
       djnz l_0D82

       jr   l_0DF5_next_superloop_and_reload_0E

l_0D8D_got_a_bullet:
       ld   (hl),#6                               ; _objs[BOMB0].state = BOMB
       push hl                                    ; &_objs[BOMB0 + n]
       ld   h,#>ds_sprite_posn
       ld   d,h
       dec  e                                     ; ... E from &sprite.ctrl[L].b1
; sprite.posn[BOMB0 + n].b0 = sprite.posn[e].b0
       ld   a,(de)                                ; bomber.x
       ld   c,a
       ld   (hl),a                                ; bomb.x
; sprite.posn[BOMB0 + n].b1 = sprite.posn[e].b1 // y<7:0>
       inc  e
       inc  l
       ld   a,(de)                                ; bomber.y<7:0>
       ld   b,a
       ld   (hl),a                                ; bomb.y<7:0>
; sprite.ctrl[BOMB0 + n].b1 = sprite.ctrl[e].b1
       ld   h,#>ds_sprite_ctrl
       ld   d,h
       ld   a,(de)                                ; bomber.y<8> (in :0 ... ctrl in :1)
       rrc  (hl)                                  ; bomb.ctrl.b1<0> to Cy
       rrca                                       ; bomber.y<8> from A<0> to Cy
       rl   (hl)                                  ; sY<8> from Cy to bomb.ctrl.b1<0>
       rlca                                       ; restore A with sY<8> left in Cy
       rr   b                                     ; bomber.y<8:1>
; if (mrw_sprite.posn[bomber_idx].b0 > sprite.posn[FGHTR].b0)
       ld   a,(ds_sprite_posn + 0x62)             ; fighter.x
       sub  c                                     ; bomb.x
       push af                                    ; stash fighter.x - bomber.x
       jr   nc,l_0DB1                             ; if bomber.x > fighter.x ...
       neg                                        ; ... then dX = -dX
l_0DB1:
; dX passed to c_0EAA()in hl16 ... lsb of &bomb.ctrl.b1 remaining in L is insignificant
       ld   h,a

       ld   a,(b_9215_flip_screen)
       and  a
       ld   a,#298 >> 1                           ; 0x95 ... 354-56
       jr   z,l_0DBC
       ld   a,#56 >> 1                            ; 0x1C ... inverted
l_0DBC:
       sub  b                                     ; bomber.y<8:1>
       jr   nc,l_0DC1                             ; if bomber.y > fighter.y ...
       neg
l_0DC1:
       call c_0EAA                                ; HL = HL / A
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

       pop  af                                    ; Cy from (fighter.x - bomber.x)
       rr   b
       pop  hl                                    ; sprt_mctl_objs[bomb]
       ld   a,l
       add  a,#8                                  ; IDX_BOMB will be index 0 thanks to and $0F
       and  #0x0F
       ld   hl,#b_92B0 + 0x00                     ; bomb x-coordinate structure ( 8 * 2 )
       add  a,l
       ld   l,a
       ld   (hl),b
       inc  hl
       ld   (hl),#0

l_0DF5_next_superloop_and_reload_0E:
       ld   a,(b_92E2 + 0x00)                     ; to $0E(ix) e.g. A==14 (set for each round ... bomb drop counter)
       ld   0x0E(ix),a                            ; b_92E2[0] ... bomb drop counter

next__pool_idx:
       ld   hl,#b_bug_que_idx                     ; -= 1 ... counts backwards
       dec  (hl)
       ret  z
; mctl_pool_idx += 1
       ld   de,#0x0014                            ; size of object-movement structure
       add  ix,de

       jp   for__pool_idx

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
       ld   a,0x06(ix)                            ; ->(ix)0x01 ... origin home position y (bits 15:8)
       ld   0x01(ix),a                            ; (ix)0x06
       ld   a,0x07(ix)                            ; ->(ix)0x03
       ld   0x03(ix),a                            ; (ix)0x07

       jp   l_0D03_flite_pth_posn_set

; training mode, make previous diving boss disabled
; a bonus bee (e.g. 883A) flying off screen. Sprite-Code 5B (scorpion), color 05, object status==9
; also, if status==4 (capturing boss shot while in home-position, freeing a rogue ship)
case_0E49_make_object_inactive: ; 0x0
       ld   h,#>b_8800
       ld   l,0x10(ix)                            ; object offset ...8800[L]
       ld   (hl),#0x80                            ; make inactive
       ld   h,#>ds_sprite_posn
       ld   (hl),#0
       ld   0x13(ix),#0x00                        ; make inactive

       jp   next__pool_idx
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
       call c_0EAA                                ; HL = HL / A

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
;;  A
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
;;   from code space locations beyond the $1000.
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

; additional challenge stage data (see db_2A3C)
db_flv_0fda:
       .db 0x23,0x00,0x1B,0x23,0xF0,0x40,0x23,0x00,0x09,0x23,0x05,0x11
       .db 0x23,0x00,0x10,0x23,0x10,0x40,0x23,0x04,0x30,0xFF
db_flv_0ff0:
       .db 0x23,0x02,0x35,0x23,0x08,0x10
       .db 0x23,0x10,0x3C,0x23,0x00,0xFF,0xFF

       .db 0x32 ; junk ??

;; end of ROM

