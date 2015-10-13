;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; int.s:
;;  gg1-1.3p 'maincpu' (Z80)
;;
;;  Z80 interrupt vectors, maincpu.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.module int0
.area INTVEC (ABS,OVR)

.include "int.dep"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

       .org  0x0000

;;=============================================================================
;; RST_00()
;;  Description:
;;   Z80 reset
;;   Reset/clear the chip command state and jump to the reset handler ($10).
;;   NMI is disabled when  IO_CMD & $0F == 0
;; IN:
;;
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
       ld   a,#0x10
       ld   (0x7100),a                            ; IO cmd ($10 -> reset/clr chip command state)
       jp   CPU0_RESET


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

       .org 0x0008

;;=============================================================================
;; RST_08()
;;  Description:
;;   HL += 2A
;; IN:
;;
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
       add  a,a
       jr   nc,rst_HLplusA
       inc  h                                     ; add carry into H
       jp   rst_HLplusA


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

       .org 0x0010

;;=============================================================================
;; RST_10()
;;  Description:
;;   HL += A
;; IN:
;;   HL
;;   A
;; OUT:
;;   HL
;;   A = L + A
;;-----------------------------------------------------------------------------
rst_HLplusA:
       add  a,l
       ld   l,a
       ret  nc
       inc  h                                     ; add carry into H
       ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

       .org 0x0018

;;=============================================================================
;; RST_18()
;;  Description:
;;   memset((HL), A, B)
;; IN:
;;   HL: pointer
;;   A: fill character
;;   B: count
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
l_0018:
       ld   (hl),a
       inc  hl
       djnz l_0018                                ; while (B--)
       ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

       .org 0x0020

;;=============================================================================
;; RST_20()
;;  Description:
;;   Quick calculation of DE-=$20
;;   Useful for advancing the "cursor" one character cell to the right on the screen.
;;   Normally called via RST, but in one instance is call'd (jp'd)
;; IN:
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
rst_DEminus20:
       ld   a,e
       sub  #0x20
       ld   e,a                                   ; result in E
       ret  nc
       dec  d                                     ; D gets the carry
       ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

       .org 0x0028

;;=============================================================================
;; RST_28()
;;  Description:
;;   memset(tbl, 0, $F0)
;; IN:
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
       ld   hl,#ds_bug_motion_que                 ; memset(..., 0, $F0)
       ld   b,#0xF0
       xor  a                                     ; A==00
       rst  0x18                                  ; memset((HL), A=fill, B=ct)
       ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

       .org 0x0030

;;=============================================================================
;; RST_30()
;;  Description:
;;   Entry point to display string function at _139A
;; IN:
;;   If set Cy flag, indicates to _139A to expect a position encoded string
;; OUT:
;;  HL == final offset in video ram (some code actually uses this!)
;;-----------------------------------------------------------------------------
       scf
       ex   af,af'
       jp   j_string_out_pe


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

       .org 0x0038

;;=============================================================================
;;  Description:
;;   RST $38 handler.
;;   jp to the task manager
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
       jp   jp_Task_man


;;=============================================================================
;; c_task_switcher()
;;  Description: returns from the jp'd task.
;; IN:
;;  ...
;; OUT:
;;  ...
;; PRESERVES:
;;  BC
;;-----------------------------------------------------------------------------
c_task_switcher:
       jp   (hl)


;;=============================================================================
;; c_sctrl_sprite_ram_clr()
;;  Description:
;;   Initialize screen control registers.
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_sctrl_sprite_ram_clr:
; memset($9300, 0, $80)
       ld   hl,#ds_sprite_posn
       ld   b,#0x80
       xor  a
       rst  0x18                                  ; memset((HL), A=fill, B=ct)
; memset($9b00, 0, $80)
       ld   hl,#ds_sprite_ctrl
       ld   b,#0x80
       rst  0x18                                  ; memset((HL), A=fill, B=ct)
; memset($8800, $80, $80)
       ld   hl,#b_8800                            ; $80 byte with sprite data buffer blocks
       ld   a,#0x80
       ld   b,#0x80
       rst  0x18                                  ; memset((HL), A=fill, B=ct)

       ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

       .org 0x0066

;;=============================================================================
;; NMI
;;  Description:
;;   NMI
;; IN:
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
       exx                                        ; Load function params from aux regs
       ldi                                        ; each nmi will move one byte, so BC--, DE++, HL++

;  if ( BC > 0 )  { goto l_008F } ... exit if still copying data
       jp   pe,l_008F                             ; !P/V when BC==0

       push af                                    ; save AF, it's not part of the exx exchange

; Signal the chip that the parameter transfer is finished.
       ld   hl,#0x7100                            ; $10 - command params complete.
       ld   (hl),#0x10                            ; IO_CMD_DONE

;  if ( !player_hit )
       ld   a,(b_9AA0 + 0x19)                     ; sound-fx count/enable registers, ship hit
       and  a                                     ; A!=0 or maybe 02 when you get hit
       jr   z,l_plyr_ok
; else
       xor  a
       ld   (b_9AA0 + 0x19),a                     ; 0 ... sound-fx count/enable registers, ship hit

       ld   hl,#d_IO_ChipParms
       ld   de,#0x7000                            ; IO data xfer (write)
       ld   bc,#0x0004
       exx

       ld   a,#0xA8
       ld   (0x7100),a                            ; IO cmd ($A8 -> trigger bang sound)
       pop  af
       retn
l_plyr_ok:
       pop  af
l_008F:
       exx                                        ; restore regs for the main "thread"
       retn                                       ; end 'NMI'

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; data for NMI sub
;;
d_IO_ChipParms:
       .db 0x10,0x10,0x20,0x20


_l_0096:
;            00000096  d_OS_TaskTable                     task_man

;;
