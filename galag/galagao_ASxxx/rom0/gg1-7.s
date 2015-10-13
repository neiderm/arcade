;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; gg1-7.s
;;  gg1-7.2c, CPU 'sub2' (Z80)
;;
.module cpu_sub2

.include "sfrs.inc"
.include "gg1-7.dep"

.BANK cpu_sub2 (BASE=0x000000, FSFX=_sub2)
.area ROM2 (ABS,OVR,BANK=cpu_sub2)

.org 0x0000

;;=============================================================================
;; RST_00()
;;  Description:
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
       ld   sp,#_stack_cpu_sub2 + 0x20
       jp   RESET

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
       inc  h
       jr   _RST_10

      .org 0x0010

;;=============================================================================
;; RST_10()
;;  Description:
;;   HL = HL + A
;; IN:
;;
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
_RST_10:
       add  a,l
       ld   l,a
       ret  nc
       inc  h
       ret

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
_RST_18:
       ld   (hl),a
       inc  hl
       djnz _RST_18
       ret

      .org  0x0066

;;=============================================================================
;; RST_66()
;;  Description:
;;   NMI
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
       ld   a,#1
       ld   (_sfr_6822),a                         ; 1 ...cpu #2 nmi acknowledge/enable
       xor  a
       ld   (_sfr_6822),a                         ; 0 ...cpu #2 nmi acknowledge/enable
       call c_nmi_proc
       ret

;;=============================================================================
;; RESET
;;  Description:
;;   entry point from RST 00
;;   Tests the ROM space (length $1000)
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
RESET:
       ld   a,#1
       ld   (_sfr_6822),a                         ; 1 ...cpu #2 nmi acknowledge/enable

       ld   de,#ds_rom_test_status + 0x01         ; pause/resume flag

; wait for master CPU to acknowledge/resume (0)
l_007B:
       ld   a,(de)
       and  a
       jr   nz,l_007B

; compute ROM checksum
       ld   h,a
       ld   l,a
       ld   bc,#0x0010                            ; Sets B as inner loop count ($100) and C as outer ($10)
l_0084:
       add  a,(hl)
       inc  hl
       djnz l_0084

       dec  c
       jr   nz,l_0084

       cp   #0xFF
       jr   z,l_0091
       ld   a,#0x11                               ; set error code

l_0091:
       ld   (de),a                                ; copy checksum result to the global variable

; wait for master to acknowledge/resume (0)
l_0092:
       ld   a,(de)
       and  a
       jr   nz,l_0092

       xor  a
       ld   (_sfr_6822),a                         ; 0 ...cpu #2 nmi acknowledge/enable (Z80_NMI_INT)

; clear all registers
       ld   hl,#b_9A00                            ; memset(b_9A00, 0, $0100)
       ld   (hl),#0
       ld   de,#b_9A00 + 0x01                     ; memset(b_9A00, 0, $0100)
       ld   bc,#0x00FF
       ldir

l_00A7:
       jr   l_00A7                                ; loop forever

;;=============================================================================
;; c_nmi_proc()
;;  Description:
;;    Handler for NMI
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_nmi_proc:
       ld   a,(b_9AA0 + 0x18)                     ; sound-fx count/enable registers, unused?
       and  a
       jp   nz,l_067A_reset_sfrs                  ; doesn't appear that it is ever called

; memset( b_freq_vol_sfr_bufr, 0, $10 )
       ld   hl,#b_9A60 + 0x00                     ; clear frequency and volume SFRs
       ld   (hl),#0
       ld   de,#b_9A60 + 0x01
       ld   bc,#0x000F
       ldir

; if ( sound_mgr_reset )  ...
       ld   a,(b_9AA0 + 0x17)                     ; 0 ... enable sound mgr process
       and  a
       jp   nz,l_033D_clear_all
; ... then ...

; credit-in sound is triggered for all credits counted

; if ( 0 != snd_add_credit_cnt )
       ld   a,(b_9A70 + 0x09)                     ; count of credits-in since last update
       and  a
       jr   z,l_00D3
; then ...
;  _fx[$08] += snd_add_credit_cnt
       ld   hl,#b_9AA0 + 0x08                     ; += b_9A70[9] ... sound-fx count/enable registers, credit-in sound
       add  a,(hl)
       ld   (hl),a
;  snd_add_credit_cnt = 0
       xor  a
       ld   (b_9A70 + 0x09),a                     ; 0 ... additional credit-in count
; ...

l_00D3:
; if ( 0 != register )  ...  count/enable register
       ld   a,(b_9AA0 + 0x00)                     ; sound-fx count/enable registers, pulsing formation sound effect
       and  a
       jr   z,l_0148
; ... then ...
       ld   a,(ds_9200_glbls + 0x11)              ; formatn_mv_signage ... cp with cpu2<b_9A80 + 0x00>
       ld   hl,#b_9A80 + 0x00
       cp   (hl)
       jr   z,l_0102

       ld   (b_9A80 + 0x00),a                     ; = ds_9200_glbls [0x11] ... formatn_mv_signage
       inc  a
       jr   z,l_00F4

; expanding formation
       ld   hl,#d_06C3
       ld   (b_9A80 + 0x02),hl                    ; ptmp = &d_06C3[0]

       xor  a
       ld   (b_9A00 + 0x00),a                     ; 0 .. sound_fx_status
       jr   l_00FD

; contracting formation
l_00F4:
       ; A == 0
       ld   hl,#d_06C3 + 8 * 2                    ; offset 8 words
       ld   (b_9A80 + 0x02),hl                    ; ptmp = &d_06D3[0]
       ld   (b_9A00 + 0x00),a                     ; 0 ... sound_fx_status
l_00FD:
       ; A == 0
       ld   (b_9A80 + 0x01),a                     ; A == 0  or  A != 0 (only gets updated when b_9A80_00 == formatn_mv_signage
       jr   l_0114

l_0102:
       ld   hl,#b_9A00 + 0x00                     ; sound_fx_status[0]++ (check for limit of 34)
       inc  (hl)
       ld   a,(hl)

       cp   #0x22
       jr   nz,l_0129
       ld   (hl),#0                               ; sound_fx_status[0] = 0
       ld   a,(b_9A80 + 0x01)                     ; b_9A80[1]++
       inc  a
       ld   (b_9A80 + 0x01),a                     ; b_9A80[1]++

l_0114:
       ld   hl,(b_9A80 + 0x02)                    ; ptmp ... d_06C3 or d_06D3
       rst  0x08                                  ; HL += 2A
       ld   e,(hl)
       inc  hl
       ld   d,(hl)
       ld   (b_9A80 + 0x04),de
       ld   a,#0x1F                               ; $20 - $01 (1-byte increment to next word already done)
       rst  0x10                                  ; HL += A
       ld   e,(hl)
       inc  hl
       ld   d,(hl)
       ld   (b_9A80 + 0x06),de
l_0129:
       ld   hl,(b_9A80 + 0x06)                    ; b_9A80[6] += b_9A80[4]
       ld   de,(b_9A80 + 0x04)
       add  hl,de
       ld   (b_9A80 + 0x06),hl

       ld   a,h
       ld   (b_9A60 + 0x01),a                     ; freq 0
       rrca
       rrca
       rrca
       rrca
       ld   (b_9A60 + 0x01 + 1),a
       ld   a,#0x0A
       ld   (b_9A60 + 0x05),a                     ; $0A ... voice 0 volume
       xor  a
       ld   (b_9A70 + 0x00 + 0),a                 ; 0 ... voice 0 wave select

; bug dive attack sound
l_0148:
       ld   hl,#b_9A70 + 0x04                     ; $13 ... bug dive attack sound
       ld   (hl),#0x13
       ld   a,(b_9AA0 + 0x13)                     ; sound-fx count/enable registers, bug dive attack sound
       and  a
       jr   z,l_015C
       xor  a
       ld   (b_9AA0 + 0x13),a                     ; 0 ... sound-fx count/enable registers, bug dive attack sound
       call c_03F4                                ; initialize the sound
       jr   l_0165
l_015C:
       ld   a,(b_9AC0 + 0x13)                     ; check if sound is active
       and  a
       jr   z,l_0165
       call c_044A                                ; update the sound

; shot sound
l_0165:
       ld   hl,#b_9A70 + 0x04                     ; $0F
       ld   (hl),#0x0F
       ld   a,(b_9AA0 + 0x0F)                     ; sound-fx count/enable registers, shot sound
       and  a
       jr   z,l_0179
       xor  a
       ld   (b_9AA0 + 0x0F),a                     ; 0 ... sound-fx count/enable registers, shot sound
       call c_03F4
       jr   l_0182
l_0179:
       ld   a,(b_9AC0 + 0x0F)
       and  a
       jr   z,l_0182
       call c_044A

; yellow bug hit sound
l_0182:
       ld   hl,#b_9A70 + 0x04                     ; $03
       ld   (hl),#3
       ld   a,(b_9AA0 + 0x03)                     ; sound-fx count/enable registers, yellow bug hit sound
       and  a
       jr   z,l_0196
       xor  a
       ld   (b_9AA0 + 0x03),a                     ; 0 ... sound-fx count/enable registers, yellow bug hit sound
       call c_03F4
       jr   l_019F
l_0196:
       ld   a,(b_9AC0 + 0x03)
       and  a
       jr   z,l_019F
       call c_044A

; red bug hit sound
l_019F:
       ld   hl,#b_9A70 + 0x04                     ; $02
       ld   (hl),#2
       ld   a,(b_9AA0 + 0x02)                     ; sound-fx count/enable registers, red bug hit sound
       and  a
       jr   z,l_01B3
       xor  a
       ld   (b_9AA0 + 0x02),a                     ; 0 ... sound-fx count/enable registers, red bug hit sound
       call c_03F4
       jr   l_01BC
l_01B3:
       ld   a,(b_9AC0 + 0x02)
       and  a
       jr   z,l_01BC
       call c_044A

; hit_green_boss
l_01BC:
       ld   hl,#b_9A70 + 0x04                     ; $04
       ld   (hl),#4
       ld   a,(b_9AA0 + 0x04)                     ; sound-fx count/enable registers, hit_green_boss
       and  a
       jr   z,l_01D0
       xor  a
       ld   (b_9AA0 + 0x04),a                     ; 0 ... sound-fx count/enable registers, hit_green_boss
       call c_03F4
       jr   l_01D9
l_01D0:
       ld   a,(b_9AC0 + 0x04)
       and  a
       jr   z,l_01D9
       call c_044A

; hit_blue_boss
l_01D9:
       ld   hl,#b_9A70 + 0x04                     ; $01
       ld   (hl),#1
       ld   a,(b_9AA0 + 0x01)                     ; sound-fx count/enable registers, blue-boss hit sound
       and  a
       jr   z,l_01ED
       xor  a
       ld   (b_9AA0 + 0x01),a                     ; 0 ... sound-fx count/enable registers, blue-boss hit sound
       call c_03F4
       jr   l_01F6
l_01ED:
       ld   a,(b_9AC0 + 0x01)
       and  a
       jr   z,l_01F6
       call c_044A

; bonus-bee sound
l_01F6:
       ld   a,(b_9AA0 + 0x12)                     ; sound-fx count/enable registers, bonus-bee sound
       and  a
       jr   z,l_0204
       ld   hl,#b_9A70 + 0x04                     ; $12
       ld   (hl),#0x12
       call c_04A2


; sound mgr capture beam
l_0204:
; if ( !_fx[$05] )  {  }  else { goto l_0236 }
       ld   a,(b_9AA0 + 0x05)                     ; sound-fx count/enable registers, capture beam active uno
       and  a
       jr   z,l_0236

       ld   hl,#b_9A70 + 0x04                     ; $05 ... capture beam
       ld   (hl),#5
       call c_0375

;  if ( ++b_9A70[0x0E] >= 6 )  { }  else  { goto l_022E }
       ld   hl,#b_9A70 + 0x0E
       inc  (hl)
       ld   a,(b_9A70 + 0x0E)
       cp   #6
       jr   c,l_022E

       ld   (hl),#0

;  if ( b_9A70[0x0C] < 4 )  b_9A70[0x0C] = 0x0C  else  b_9A70[0x0C]--
       ld   a,(b_9A70 + 0x0C)
       cp   #4
       jr   c,l_0229
       dec  a
       jr   l_022B
l_0229:
       ld   a,#0x0C
l_022B:
       ld   (b_9A70 + 0x0C),a

l_022E:
       ld   a,(b_9A70 + 0x0C)                     ; ->voice 2 volume
       ld   (b_9A60 + 0x0F),a                     ; voice 2 volume
       jr   j_0239

l_0236:
       ld   (b_9AC0 + 0x05),a                     ; 0 ... capture beam count/enable uno == 0, so clear the active flag

j_0239:
; if ( sound_active )  { }  else  _fx[$06] = 0
       ld   a,(b_9AA0 + 0x06)                     ; sound-fx count/enable registers, capture beam active deux
       and  a
       jr   z,l_0263

       ld   hl,#b_9A70 + 0x04                     ; $06
       ld   (hl),#6
       call c_0375

; if ( ++b_9A70[0x0F] == $1C )  b_9A70[0x0F] = 0, b_9A70[0x0D]++
       ld   hl,#b_9A70 + 0x0F
       inc  (hl)
       ld   a,(hl)
       cp   #0x1C
       jr   nz,l_025B

       xor  a
       ld   (b_9A70 + 0x0F),a                     ; 0
       ld   a,(b_9A70 + 0x0D)
       inc  a
       ld   (b_9A70 + 0x0D),a                     ; ++

l_025B:
       ld   a,(b_9A70 + 0x0D)
       ld   (b_9A70 + 0x00 + 2),a                 ; 0 ... voice 2 wave select
       jr   l_0266

l_0263:
       ld   (b_9AC0 + 0x06),a                     ; 0 ... deactivate capture beam part deux


; $9 .. $7
l_0266:
       ld   a,(b_9AA0 + 0x09)                     ; sound-fx count/enable registers
       and  a
       jr   z,l_0276
       ld   hl,#b_9A70 + 0x04                     ; $09
       ld   (hl),#9
       call c_0375
       jr   l_0279
l_0276:
       ld   (b_9AC0 + 0x09),a                     ; 0 ... clear the active flag

; shot your ship!
l_0279:
       ld   a,(b_9AA0 + 0x07)                     ; sound-fx count/enable registers, shot your ship!
       and  a
       jr   z,l_0287
       ld   hl,#b_9A70 + 0x04                     ; $07
       ld   (hl),#7
       call c_04A2

; "rescued ship" theme
l_0287:
       ld   a,(b_9AA0 + 0x11)                     ; sound-fx count/enable registers, "rescued ship" theme
       and  a
       jr   z,l_0297
       ld   hl,#b_9A70 + 0x04                     ; $11
       ld   (hl),#0x11
       call c_0375
       jr   l_029A
l_0297:
       ld   (b_9AC0 + 0x11),a                     ; clear the active flag

; challenge stage intro music
l_029A:
       ld   a,(b_9AA0 + 0x0D)                     ; sound-fx count/enable registers, start challenge stage music
       and  a
       jr   z,l_02A8
       ld   hl,#b_9A70 + 0x04                     ; $0D
       ld   (hl),#0x0D
       call c_04A2

; challenge stage default melody
l_02A8:
       ld   a,(b_9AA0 + 0x0E)                     ; sound-fx count/enable registers, challenge stage default melody
       and  a
       jr   z,l_02B6                              ; well this seems like a waste of time
       ld   hl,#b_9A70 + 0x04                     ; $0E
       ld   (hl),#0x0E
       call c_04A2

; challenge stage default melody
l_02B6:
       ld   a,(b_9AA0 + 0x0E)                     ; sound-fx count/enable registers, challenge stage default melody
       and  a
       jr   z,l_02C6
       ld   a,#9
       ld   (b_9A60 + 0x0A),a                     ; 9 ... voice 1 volume
       ld   a,#6
       ld   (b_9A60 + 0x0F),a                     ; 6 ... voice 2 volume

; challenge stage perfect melody
l_02C6:
       ld   a,(b_9AA0 + 0x14)                     ; sound-fx count/enable registers, challenge stage perfect melody
       and  a
       jr   z,l_02D4
       ld   hl,#b_9A70 + 0x04                     ; $14
       ld   (hl),#0x14
       call c_04A2

; stage tokens "clicks"
l_02D4:
       ld   a,(b_9AA0 + 0x15)                     ; sound-fx count/enable registers, stage tokens "clicks"
       and  a
       jr   z,l_02E2
       ld   hl,#b_9A70 + 0x04                     ; $15
       ld   (hl),#0x15
       call c_04A2

; new spare ship added
l_02E2:
       ld   a,(b_9AA0 + 0x0A)                     ; sound-fx count/enable registers, new spare ship added
       and  a
       jr   z,l_02F0
       ld   hl,#b_9A70 + 0x04                     ; $0A
       ld   (hl),#0x0A
       call c_04A2

; start of game theme
l_02F0:
       ld   a,(b_9AA0 + 0x0B)                     ; sound-fx count/enable registers, start of game theme
       and  a
       jr   z,l_02FE
       ld   hl,#b_9A70 + 0x04                     ; $0B
       ld   (hl),#0x0B
       call c_04A2

; $10
l_02FE:
       ld   a,(b_9AA0 + 0x10)                     ; sound-fx count/enable registers, hi-score dialog?
       and  a
       jr   z,l_030E
       ld   hl,#b_9A70 + 0x04                     ; $10
       ld   (hl),#0x10
       call c_0375
       jr   l_0311
l_030E:
       ld   (b_9AC0 + 0x10),a                     ; clear the active flag

; hi-score dialog?
l_0311:
       ld   a,(b_9AA0 + 0x0C)                     ; sound-fx count/enable registers, hi-score dialog?
       and  a
       jr   z,l_031F
       ld   hl,#b_9A70 + 0x04                     ; $0C
       ld   (hl),#0x0C
       call c_04A2

; hi-score dialog?
l_031F:
       ld   a,(b_9AA0 + 0x16)                     ; sound-fx count/enable registers, hi-score dialog?
       and  a
       jr   z,l_032D
       ld   hl,#b_9A70 + 0x04                     ; $16
       ld   (hl),#0x16
       call c_04A2

; coin sound
l_032D:
       ld   a,(b_9AA0 + 0x08)                     ; sound-fx count/enable registers, coin sound
       and  a
       jr   z,l_033B
       ld   hl,#b_9A70 + 0x04                     ; actv_snd_idx = $08
       ld   (hl),#0x08                            ; actv_snd_idx
       call c_04A2                                ; _fx[$08] will be decremented

l_033B:
       jr   j_0357_set_SFRs

l_033D_clear_all:
; memset( snd_cnt_enable, 0, $16 ) .. don't clear [$16], [$17], [$18]
       ld   hl,#b_9AA0 + 0x00                     ; sound-fx count/enable registers ... $16 bytes 0
       ld   (hl),#0
       ld   de,#b_9AA0 + 0x01                     ; sound-fx count/enable registers ... $16 bytes 0
       ld   bc,#0x0015
       ldir

; memset( snd_active_flag, 0, $17 ) ...  [$16] should be highest one used
       ld   hl,#b_9AC0 + 0x00                     ; $17 bytes 0
       ld   (hl),#0
       ld   de,#b_9AC0 + 0x01
       ld   bc,#0x0016
       ldir

j_0357_set_SFRs:
       ld   hl,#b_9A60                            ; memcpy(&sfr_6810[0], buf, $10)
       ld   de,#_sfr_6810                         ; base pointer to frequency and volume SFRs
       ld   bc,#0x0010
       ldir

; set the sound voice waveforms
       ld   a,(b_9A70 + 0x00 + 0)
       ld   (_sfr_6805),a                         ; voice 0 wave
       ld   a,(b_9A70 + 0x00 + 1)
       ld   (_sfr_680A),a                         ; voice 1 wave
       ld   a,(b_9A70 + 0x00 + 2)
       ld   (_sfr_680F),a                         ; voice 2 wave
       ret

;;=============================================================================
;; c_0375()
;;  Description:
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_0375:
       ld   hl,#b_9A70 + 0x04                     ; d_0703[ actv_snd_idx * 3 ]
       ld   a,(hl)
       add  a,a
       add  a,(hl)
       ld   hl,#d_0703_snd_parms
       rst  0x10                                  ; HL += A
       ld   de,#b_9A70 + 0x05                     ; memcpy( snd_parms_set, d_0703[ actv_snd_idx * 3 ], 3 )
       ld   bc,#0x0003
       ldir

; if challenge stage default melody
       ld   a,(b_9A70 + 0x04)                     ; if ( actv_snd_idx == $0E ) ...
       cp   #0x0E
       jr   nz,l_03A6
; if 0 == data_index
       ld   a,(b_9A30 + 0x1C)
       and  a
       jr   z,l_03A1
; else if 1 == data_index
       dec  a
       jr   z,l_039D
; or if
       ld   a,(b_9A30 + 0x1D)
       and  a
       jr   nz,l_03A6
l_039D:
       ld   a,#2
       jr   l_03A3
l_03A1:
       ld   a,#1
l_03A3:
       ld   (b_9A70 + 0x05 + 1),a                 ; 1 or 2 .. count: number of data pairs

; now we are checking active flags for some reason,,,,
l_03A6:
       ld   hl,#b_9AC0                            ; if ( 0 == b_9AC0[ actv_snd_idx ] )  b_9AC0[ actv_snd_idx ] = 1
       ld   a,(b_9A70 + 0x04)                     ; b_9AC0[ actv_snd_idx ]
       add  a,l
       ld   l,a
       ld   a,(hl)
       and  a
       jr   nz,j_03CD

       inc  (hl)

       ld   hl,#b_9A70 + 0x05 + 1                 ; snd_parms_set.count
       ld   b,(hl)

; memset( &snd_fx_dat_idx[ snd_parms_set.idx ], 0, snd_parms_set.count )
       ld   c,b
       ld   hl,#b_9A30                            ; snd_fx_dat_idx[ snd_parms_set.idx ]
       ld   a,(b_9A70 + 0x05 + 0)                 ; snd_parms_set.idx
       add  a,l
       ld   l,a
       xor  a
       rst  0x18                                  ; memset((HL), A=fill, B=ct)

; memset( &sound_fx_status[ snd_parms_set.idx ], 0, snd_parms_set.count )
       ld   b,c
       ld   hl,#b_9A00                            ; sound_fx_status[ snd_parms_set.idx ]
       ld   a,(b_9A70 + 0x05 + 0)                 ; snd_parms_set.idx
       add  a,l
       ld   l,a
       xor  a
       rst  0x18                                  ; memset((HL), A=fill, B=ct)

j_03CD:
l_03CD_while:
       call c_0550

; while ( snd_parms_set.count > 0 ) ...
       ld   hl,#b_9A70 + 0x05 + 1                 ; if ( snd_parms_set.count-- > 0 ) ...
       dec  (hl)
       jr   z,l_03E0

       ld   hl,#b_9A70 + 0x05 + 0                 ; snd_parms_set.idx++
       inc  (hl)
       ld   hl,#b_9A70 + 0x05 + 2                 ; voice_select++
       inc  (hl)
       jr l_03CD_while

l_03E0:
       ld   a,(b_9A70 + 0x08)                     ; ret z
       and  a
       ret  z

       xor  a
       ld   (b_9A70 + 0x08),a                     ; 0

; clear the sound_active flag for this one
       ld   hl,#b_9AC0                            ; b_9AC0[ actv_snd_idx ] = 0
       ld   a,(b_9A70 + 0x04)                     ; b_9AC0[ actv_snd_idx ]
       add  a,l
       ld   l,a
       ld   (hl),#0

; exactly the same as c_04A2 until here
       ret
; end 'call _0375'

;;=============================================================================
;; c_03F4()
;;  Description:
;;   Initialize a sound effect. After this one is called once, then c_044A is
;;   called to update the sound on subsequent frame updates.
;; IN:
;;   b_9A70[4]: index of sound to play
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_03F4:
; on this one we increment the Active flag
       ld   hl,#b_9AC0                            ; b_9AC0[ actv_snd_idx ]++
       ld   a,(b_9A70 + 0x04)                     ; b_9AC0[ actv_snd_idx ]
       add  a,l
       ld   l,a
       inc  (hl)

; same as c_04A2 here
       ld   hl,#b_9A70 + 0x04                     ; d_0703[ actv_snd_idx * 3 ]
       ld   a,(hl)
       add  a,a
       add  a,(hl)
       ld   hl,#d_0703_snd_parms
       rst  0x10                                  ; HL += A
       ld   de,#b_9A70 + 0x05                     ; memcpy( snd_parms_set, d_0703[ actv_snd_idx * 3 ], 3 )
       ld   bc,#0x0003
       ldir

; if challenge stage default melody
       ld   a,(b_9A70 + 0x04)                     ; if (actv_snd_idx == $0E) ...
       cp   #0x0E
       jr   nz,l_042E
; if 0 == data_index
       ld   a,(b_9A30 + 0x1C)                     ; data_index, SOUND 09
       and  a
       jr   z,l_0429
; else if 1 == data_index
       dec  a
       jr   z,l_0425
; or if
       ld   a,(b_9A30 + 0x1D)                     ; SOUND 09
       and  a
       jr   nz,l_042E
l_0425:
       ld   a,#2
       jr   l_042B

l_0429:
       ld   a,#0x01
l_042B:
       ld   (b_9A70 + 0x05 + 1),a                 ; snd_parms_set.count = 1

; here we don't check the flags...

l_042E:
       ld   hl,#b_9A70 + 0x05 + 1                 ; snd_parms_set.count
       ld   b,(hl)

; memset( &snd_fx_dat_idx[ snd_parms_set.idx ], 0, snd_parms_set.count )
       ld   c,b
       ld   hl,#b_9A30                            ; snd_fx_dat_idx[ snd_parms_set.idx ]
       ld   a,(b_9A70 + 0x05 + 0)                 ; snd_parms_set.idx
       add  a,l
       ld   l,a
       xor  a
       rst  0x18                                  ; memset((HL), A=fill, B=ct)

; memset( &sound_fx_status[ snd_parms_set.idx ], 0, snd_parms_set.count )
       ld   b,c
       ld   hl,#b_9A00                            ; sound_fx_status[ snd_parms_set.idx ]
       ld   a,(b_9A70 + 0x05 + 0)                 ; snd_parms_set.idx
       add  a,l
       ld   l,a
       xor  a
       rst  0x18                                  ; memset((HL), A=fill, B=ct)

; here is where c_0550 is called....
       jr   j_047B

;;=============================================================================
;; c_044A()
;;  Description:
;;   After c_03F4 is called once to initialize the sound, then on subsequent
;;   frame updates this one is called.
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_044A:
       ld   hl,#b_9A70 + 0x04                     ; d_0703[ actv_snd_idx * 3 ]
       ld   a,(hl)
       add  a,a
       add  a,(hl)
       ld   hl,#d_0703_snd_parms
       rst  0x10                                  ; HL += A
       ld   de,#b_9A70 + 0x05                     ; memcpy( snd_parms_set, d_0703[ actv_snd_idx * 3 ], 3 )
       ld   bc,#0x0003
       ldir

; if challenge stage default melody
       ld   a,(b_9A70 + 0x04)                     ; if (actv_snd_idx == $0E) ...
       cp   #0x0E
       jr   nz,j_047B
; if 0 == data_index
       ld   a,(b_9A30 + 0x1C)
       and  a
       jr   z,l_0476
; else if 1 == data_index
       dec  a
       jr   z,l_0472
; or if
       ld   a,(b_9A30 + 0x1D)
       and  a
       jr   nz,j_047B
l_0472:
       ld   a,#2
       jr   l_0478

l_0476:
       ld   a,#1
l_0478:
       ld   (b_9A70 + 0x05 + 1),a                 ; snd_parms_set.count

; doesn't do the other stuff here here....

j_047B:
l_047B:
       call c_0550
       ld   hl,#b_9A70 + 0x05 + 1                 ; if ( snd_parms_set.count-- > 0 ) ...
       dec  (hl)
       jr   z,l_048E

       ld   hl,#b_9A70 + 0x05 + 0                 ; snd_parms_set.idx++
       inc  (hl)
       ld   hl,#b_9A70 + 0x05 + 2                 ; voice_select++
       inc  (hl)
       jr   l_047B

l_048E:
       ld   a,(b_9A70 + 0x08)                     ; ret z
       and  a
       ret  z

       xor  a
       ld   (b_9A70 + 0x08),a                     ; 0

; clear the sound_active flag for this one
       ld   hl,#b_9AC0                            ; b_9AC0[ actv_snd_idx ] = 0
       ld   a,(b_9A70 + 0x04)                     ; b_9AC0[ actv_snd_idx ]
       add  a,l
       ld   l,a
       ld   (hl),#0

       ret
; 'end 'call _03F4, call _044A?'

;;=============================================================================
;; c_04A2()
;;  Description:
;; IN:
;;  b_9A70[4] == index of sound
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_04A2:
       ld   hl,#b_9A70 + 0x04                     ; d_0703[ actv_snd_idx * 3 ]
       ld   a,(hl)
       add  a,a
       add  a,(hl)
       ld   hl,#d_0703_snd_parms
       rst  0x10                                  ; HL += A
       ld   de,#b_9A70 + 0x05                     ; memcpy( snd_parms_set, d_0703[ actv_snd_idx * 3 ], 3 )
       ld   bc,#0x0003
       ldir

; if challenge stage default melody
       ld   a,(b_9A70 + 0x04)                     ; if (actv_snd_idx == $0E) ...
       cp   #0x0E
       jr   nz,l_04D3
; if 0 == data_index
       ld   a,(b_9A30 + 0x1C)                     ; data_index, SOUND 09
       and  a
       jr   z,l_04CE
; else if 1 == data_index
       dec  a
       jr   z,l_04CA
; or if
       ld   a,(b_9A30 + 0x1D)                     ; SOUND 09
       and  a
       jr   nz,l_04D3
l_04CA:
       ld   a,#2
       jr   l_04D0

l_04CE:
       ld   a,#1
l_04D0:
       ld   (b_9A70 + 0x05 + 1),a                 ; snd_parms_set.count

; now we are checking active flags for some reason,,,,
l_04D3:
       ld   hl,#b_9AC0                            ; b_9AC0[ actv_snd_idx ]
       ld   a,(b_9A70 + 0x04)                     ; b_9AC0[ actv_snd_idx ]
       add  a,l
       ld   l,a
       ld   a,(hl)
       and  a
       jr   nz,j_04FA

       inc  (hl)

       ld   hl,#b_9A70 + 0x05 + 1                 ; snd_parms_set.count
       ld   b,(hl)

; memset( &snd_fx_dat_idx[ snd_parms_set.idx ], 0, snd_parms_set.count )
       ld   c,b
       ld   hl,#b_9A30                            ; snd_fx_dat_idx[ snd_parms_set.idx ]
       ld   a,(b_9A70 + 0x05 + 0)                 ; snd_parms_set.idx
       add  a,l
       ld   l,a
       xor  a
       rst  0x18                                  ; memset((HL), A=fill, B=ct)

; memset( &sound_fx_status[ snd_parms_set.idx ], 0, snd_parms_set.count )
       ld   b,c
       ld   hl,#b_9A00                            ; sound_fx_status[ snd_parms_set.idx ]
       ld   a,(b_9A70 + 0x05 + 0)                 ; snd_parms_set.idx
       add  a,l
       ld   l,a
       xor  a
       rst  0x18                                  ; memset((HL), A=fill, B=ct)

j_04FA:
l_04FA_while:
       call c_0550

; while ( snd_parms_set.count > 0 ) ...
       ld   hl,#b_9A70 + 0x05 + 1                 ; snd_parms_set.count--
       dec  (hl)
       jr   z,l_050D

       ld   hl,#b_9A70 + 0x05 + 0                 ; snd_parms_set.idx++
       inc  (hl)
       ld   hl,#b_9A70 + 0x05 + 2                 ; snd_parms_set.voice_select++
       inc  (hl)
       jr   l_04FA_while

l_050D:
       ld   a,(b_9A70 + 0x08)                     ; ret z
       and  a
       ret  z

       xor  a
       ld   (b_9A70 + 0x08),a                     ; 0

; clear the sound_active flag for this one
       ld   hl,#b_9AC0                            ; b_9AC0[ actv_snd_idx ] = 0
       ld   a,(b_9A70 + 0x04)                     ; _fx[actv_snd_idx ]
       add  a,l
       ld   l,a
       ld   (hl),#0

; exactly the same as c_0375 until here ...  update the count/enable register for certain sound-effects

       ld   hl,#ds_9AA0                           ; _fx[ actv_snd_idx ] ... count/enable register
       ld   a,(b_9A70 + 0x04)                     ; _fx[actv_snd_idx ]
       add  a,l
       ld   l,a

; switch( actv_snd_idx )
; case $08:
       ld   a,(b_9A70 + 0x04)                     ; if (actv_snd_idx == $08) ... count/enable register, coin sound
       cp   #8
       jr   z,l_053A_idx_8
; case $0C:
       cp   #0x0C                                 ; ... && if ( actv_snd_idx != $0C )
       jr   z,l_053C_idx_C
; case $14:
       cp   #0x14                                 ; ... && if ( actv_snd_idx != $14 )  { b_9AA0[ actv_snd_idx ] = 0 ; return }
       jr   z,l_0548_idx_14
; default:
       ld   (hl),#0
       ret

l_053A_idx_8:
       dec  (hl)                                  ; _fx[idx]--
       ret

l_053C_idx_C:
; _fx[$0C] used as timer ... enable snd[$16] when 0 is reached
; caller would not have called this with _9AA0[$0C] == 0 ?
       dec  (hl)
       jr   z,l_0542_enable_16
       bit  0,(hl)                                ; not sure significance of checking <:0>
       ret  z
l_0542_enable_16:
       ld   a,#0x01
       ld   (b_9AA0 + 0x16),a                     ; 1 ... sound-fx count/enable registers, hi-score dialog?
       ret

l_0548_idx_14:
       ld   (hl),#0                               ; _fx[ actv_snd_idx ] ... count/enable register
       ld   hl,#b_9AA0 + 0x13                     ; 1 ... sound-fx count/enable registers, bug dive attack sound
       ld   (hl),#1
       ret
; end 'call _04A2'

;;=============================================================================
;; c_0550()
;;  Description:
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_0550:
       ld   hl,#b_9A00                            ; sound_fx_status[ snd_parms_set.idx ]++
       ld   a,(b_9A70 + 0x05 + 0)                 ; snd_parms_set.idx
       add  a,l
       ld   l,a
       inc  (hl)

; get a pointer to the sound effect data structure from the table
       ld   a,(b_9A70 + 0x05 + 0)                 ; p_snd_fx[ 2 * snd_parms_set.idx ]
       ld   hl,#d_0748_p_snd_fx
       rst  0x08                                  ; HL += 2A
       ld   e,(hl)
       inc  hl
       ld   d,(hl)
       ex   de,hl
; copy first 3 bytes from the sound effect data structure (header info)
       ld   de,#b_9A80 + 0x08                     ; memcpy( sound_effect_hdr[0], p_sndfx_data[ idx ], 3 )
       ld   bc,#0x0003
       ldir

; 9A30[snd_parms_set.idx] holds the data offset i.e. snd_fx_data[ 3 + n ]
       ex   de,hl                                 ; DE = &snd_fx_data[ 3 ]

       ld   hl,#b_9A30                            ; snd_fx_dat_idx[ snd_parms_set.idx ]
       ld   a,(b_9A70 + 0x05 + 0)                 ; snd_parms_set.idx
       add  a,l
       ld   l,a
       ld   a,(hl)
       ex   de,hl                                 ; HL = &snd_fx_data[ 3 ]
       rst  0x10                                  ; HL += A
       ld   (b_9A70 + 0x0A),hl                    ; save the pointer ... &snd_fx_data[ 3 + n ]

; if ( $FF == *p_snd_fx_data )  ... close voice && exit
       ld   a,(hl)
       inc  a
       jp   z,j_068B_close_voice_and_exit

; tmp_ptr = *( b_9A70[ $0A ] )
; d_06A9_ndat[  *( tmp_ptr ) & 0x0F  * 2 ]  ... lo-nibble of sound-effect data is index into note-data
       ld   de,#d_06A9_ndat
       ld   hl,(b_9A70 + 0x0A)                    ; reload the current pointer to sound-effect data
       ld   a,(hl)
       and  #0x0F
       ex   de,hl
       rst  0x08                                  ; HL += 2A ... word pointer into note-data
       ld   c,(hl)
       inc  hl
       ld   b,(hl)

; use the hi-nibble of sound-effect data ....
       ex   de,hl
       ld   a,(hl)
       rrca
       rrca
       rrca
       rrca
       and  #0x0F

; ... raised to power-of-two as divisor if non-zero:
; while ( 0 != A ) ...
       jr   z,l_059F
l_0598:
       srl  b
       rr   c
       dec  a
       jr   nz,l_0598

l_059F:
; switch( voice_select )
       ld   a,(b_9A70 + 0x05 + 2)                 ; snd_parms_set.voice_select
       and  a
       jr   z,l_05B2
       dec  a
       jr   z,l_05AD

       ld   hl,#b_9A60 + 0x0B                     ; freq 2
       jr   l_05B5
l_05AD:
       ld   hl,#b_9A60 + 0x06                     ; freq 1
       jr   l_05B5
l_05B2:
       ld   hl,#b_9A60 + 0x01                     ; freq 0

; shift out 4 nibbles from lsn to msn (only low 4-bits of each register)
l_05B5:
       ld   (hl),c                                ; lo-byte of dw_06A9_ndat divided by hi-nibble of sound-effect ^ 2
       ld   a,(hl)                                ; why not ld from C?
       rrca
       rrca
       rrca
       rrca
       inc  hl
       ld   (hl),a
       inc  hl
       ld   (hl),b                                ; hi-byte of dw_06A9_ndat divided by hi-nibble of sound-effect ^ 2
       ld   a,(hl)                                ; why not ld from B?
       rrca
       rrca
       rrca
       rrca
       inc  hl
       ld   (hl),a

; switch( voice_select )
       ld   a,(b_9A70 + 0x05 + 2)                 ; snd_parms_set.voice_select
       and  a
       jr   z,l_05D9
       dec  a
       jr   z,l_05D4

       ld   de,#b_9A60 + 0x0F                     ; vol 2
       jr   l_05DC
l_05D4:
       ld   de,#b_9A60 + 0x0A                     ; vol 1
       jr   l_05DC
l_05D9:
       ld   de,#b_9A60 + 0x05                     ; vol 0

l_05DC:
; if ( $0C != *p_snd_fx_data ) ...
       ld   hl,(b_9A70 + 0x0A)                    ; reload the pointer ... p_snd_fx_data = b_9A70[ $0A ]
       ld   a,(hl)
       sub  #0x0C
       jr   z,l_0628

       ld   a,(b_9A80 + 0x08 + 0)                 ; if ( sound_effect_hdr[0] == 0 ) .. else  if ( sound_effect_hdr[0] == 1 )
       and  a
       jr   z,l_060D
       dec  a
       jr   z,l_05FD_
; 05ED
       ld   hl,#b_9A00                            ; if ( sound_fx_status[ snd_parms_set.idx ] >= 6 )
       ld   a,(b_9A70 + 0x05 + 0)                 ; snd_parms_set.idx
       add  a,l
       ld   l,a
       ld   a,(hl)
       cp   #6
       jr   nc,l_060D
       cpl
       jr   l_062D

l_05FD_:
       ld   hl,#b_9A00                            ; if ( sound_fx_status[ snd_parms_set.idx ] >= 6 )
       ld   a,(b_9A70 + 0x05 + 0)                 ; snd_parms_set.idx
       add  a,l
       ld   l,a
       ld   a,(hl)
       cp   #6
       jr   nc,l_060D
       add  a,a                                   ; this is the only difference to the previous section!
       jr   l_062D

l_060D:
       ld   a,(b_9A80 + 0x08 + 1)                 ; sound_effect_hdr[1]
       and  a
       jr   z,l_062B

       ld   b,a                                   ; b_9A80_8[ 1 ]
       ld   hl,#b_9A00                            ; sound_fx_status[ snd_parms_set.idx ]
       ld   a,(b_9A70 + 0x05 + 0)                 ; snd_parms_set.idx
       add  a,l
       ld   l,a
       ld   a,(hl)
       sub  b
       jr   c,l_062B
       sub  #0x0A
       jr   nc,l_0628
       neg
       jr   l_062D

l_0628:
       xor  a
       jr   l_062D

l_062B:
       ld   a,#0x0A


l_062D:
       ld   (de),a                                ; volume ... (9A65 etc)

       ld   hl,#b_9A70                            ; b_9A70_wave_select[ voice_select ] = b_9A80_sound_effect_parms.wave
       ld   a,(b_9A70 + 0x05 + 2)                 ; snd_parms_set.voice_select
       add  a,l
       ld   l,a
       ld   a,(b_9A80 + 0x08 + 2)                 ; sound_effect_hdr.wave
       ld   (hl),a

 ; get base multiplier
       ld   hl,#d_07A6                            ; base_multipliers[ actv_snd_idx  ]
       ld   a,(b_9A70 + 0x04)                     ; A = d_07A6[ actv_snd_idx ]
       rst  0x10                                  ; HL += A
       ld   a,(hl)

; Multiplier = second byte of sound fx data pair
       ld   hl,(b_9A70 + 0x0A)                    ; b_9A70[ $0A  ] + 1 ... reload pointer and increment
       inc  hl
       ld   e,(hl)
       ld   d,#0
       ld   hl,#0x0000

; Multiply by weighting each bit of the base by the multiplier in E and adding.
       ld   b,#8
l_064E_do_while:
       srl  a
       jr   nc,l_0653
       add  hl,de
l_0653:
       sla  e
       rl   d
       djnz l_064E_do_while

       ld   b,l

; return if count is elapsed
       ld   hl,#b_9A00                            ; sound_fx_status[ snd_parms_set.idx ]
       ld   a,(b_9A70 + 0x05 + 0)                 ; snd_parms_set.idx
       add  a,l
       ld   l,a
       ld   a,b
       cp   (hl)
       ret  nz

; update the data pointer and count registers
       ld   hl,#b_9A30                            ; snd_fx_dat_idx[ snd_parms_set.idx ] += 2
       ld   a,(b_9A70 + 0x05 + 0)                 ; snd_parms_set.idx
       add  a,l
       ld   l,a
       inc  (hl)
       inc  (hl)

       ld   hl,#b_9A00                            ; sound_fx_status[ snd_parms_set.idx ] = 0
       ld   a,(b_9A70 + 0x05 + 0)                 ; snd_parms_set.idx
       add  a,l
       ld   l,a
       ld   (hl),#0

       ret

;;=============================================================================
;; This is just sort of stuck here. It is called by the handler for NMI
;; Clears the special function registers for cpu-sub2.
;; It doesn't appear that it is ever called.
;;-----------------------------------------------------------------------------
l_067A_reset_sfrs:
       ld   hl,#b_9A00 + 0x00                     ; memset(b_9A00, 0, $0100)
       ld   (hl),#0
       ld   de,#b_9A00 + 0x01                     ; memset(b_9A00, 0, $0100)
       ld   bc,#0x00FF
       ldir
       ld   sp,#_stack_cpu_sub2 + 0x20
       ret

;;=============================================================================
;;
;; set the selected voice volume to 0
;;
j_068B_close_voice_and_exit:

; switch( b_voice_select )
       ld   a,(b_9A70 + 0x05 + 2)                 ; snd_parms_set.voice_select
       and  a
       jr   z,l_069E
       dec  a
       jr   z,l_0699
; case 2
       ld   hl,#b_9A60 + 0x0F                     ; vol 2
       jr   l_06A1
; case 1
l_0699:
       ld   hl,#b_9A60 + 0x0A                     ; vol 1
       jr   l_06A1
; case 0
l_069E:
       ld   hl,#b_9A60 + 0x05                     ; vol 0
l_06A1:
       ld   (hl),#0

       ld   a,#1
       ld   (b_9A70 + 0x08),a                     ; 1 ... sound is finished

       ret


;;=============================================================================
; Note frequency data:
; Base frequency values are indexed by lower-nibble of sound effect data. The
; hi-nibble of sound effect data gives the number of octaves below the base at
; which the final frequency occurs.
d_06A9_ndat:
        .dw 0x8150  ; $00
        .dw 0x8900  ; $01
        .dw 0x9126  ; $02
        .dw 0x99C8  ; $03
        .dw 0xA2EC  ; $04
        .dw 0xAC9D  ; $05
        .dw 0xB6E0  ; $06
        .dw 0xC1C0  ; $07
        .dw 0xCD45  ; $08
        .dw 0xD97A  ; $09
        .dw 0xE669  ; $0A
        .dw 0xF41C  ; $0B
        .dw 0x0000  ; $0C


d_06C3:
        .dw 0x0130, 0x0168, 0x0136, 0x01A8
        .dw 0x0168, 0x0200, 0x01AC, 0x0208
;d_06D3:
        .dw 0xFE00, 0xFE58, 0xFE08, 0xFE98
        .dw 0xFE58, 0xFED0, 0xFE98, 0xFED6

        .dw 0x5B00, 0x6C00, 0x5B00, 0x7E00
        .dw 0x6C00, 0x9700, 0x8100, 0x9900
        .dw 0xD900, 0xB600, 0xD900, 0x9700
        .dw 0xB600, 0x7E00, 0x9900, 0x8100

; snd_parms_dat[] : sound parameters
;     [0] ptr_idx ... offset in words to data ptr in p_snd_fx[], and also b_9A00[], b_9A00[$30]
;     [1] ... number of data pointers used by the sound effect data group (number of simultaneous voices) in that time slice
;     [2] voice_select
d_0703_snd_parms:
        .db 0x00,0x01,0x00
        .db 0x01,0x01,0x01
        .db 0x02,0x01,0x01
        .db 0x03,0x01,0x01
        .db 0x04,0x01,0x01
        .db 0x05,0x01,0x00
        .db 0x06,0x01,0x00
        .db 0x20,0x03,0x00
        .db 0x0A,0x03,0x00
        .db 0x0D,0x03,0x00
        .db 0x07,0x03,0x00
        .db 0x13,0x03,0x00
        .db 0x16,0x03,0x00
        .db 0x19,0x03,0x00
        .db 0x1C,0x03,0x00
        .db 0x1F,0x01,0x02
        .db 0x2C,0x03,0x00
        .db 0x10,0x03,0x00
        .db 0x23,0x01,0x00
        .db 0x24,0x01,0x00                        ; $13
        .db 0x25,0x03,0x00
        .db 0x28,0x01,0x00
        .db 0x29,0x03,0x00

; Pointers into sound effect data tables (d_07BD and beyond) loaded by c_0550
; Pointer selection by b_9A70[5] ... snd_parms_set.idx
; Ordering of these elements is used also to index byte tables at 9A00 and 9A30.
d_0748_p_snd_fx:
        .dw d_07BD  ; 0
        .dw d_0814  ; 1
        .dw d_07F2  ; 2
        .dw d_07BE  ; 3
        .dw d_085E  ; 4
        .dw d_0878  ; 5
        .dw d_088C  ; 6
        .dw d_09D2  ; 7
        .dw d_09E2  ; 8
        .dw d_09F2  ; 9
        .dw d_099C  ; 10
        .dw d_09AE  ; 11
        .dw d_09C0  ; 12
        .dw d_0A02  ; 13
        .dw d_0A46  ; 14
        .dw d_0A8A  ; 15
        .dw d_0AB6  ; 16
        .dw d_0AFA  ; 17
        .dw d_0B3E  ; 18
        .dw d_08A0  ; 19
        .dw d_08EC  ; 20
        .dw d_0936  ; 21
        .dw d_0C5C  ; 22
        .dw d_0CEA  ; 23
        .dw d_0D38  ; 24
        .dw d_0966  ; 25
        .dw d_0978  ; 26
        .dw d_098A  ; 27
        .dw d_08A0  ; 28
        .dw d_08A0  ; 29
        .dw d_08A0  ; 30
        .dw d_0C08  ; 31
        .dw d_0B6A  ; 32
        .dw d_0BA0  ; 33
        .dw d_0BD6  ; 34
        .dw d_0BF4  ; 35
        .dw d_0C08  ; 36
        .dw d_0D6C  ; 37
        .dw d_0DE0  ; 38
        .dw d_0E5C  ; 39
        .dw d_0D5E  ; 40
        .dw d_0CE0  ; 41
        .dw d_0D2E  ; 42
        .dw d_0D54  ; 43
        .dw d_0E9E  ; 44
        .dw d_0EDA  ; 45
        .dw d_0F16  ; 46

; indexed by active sound index, multiply by second byte of sound data pair
d_07A6:
        .db 0x04,0x02,0x02,0x02,0x02,0x04,0x04,0x0A,0x07,0x0C,0x0B,0x04,0x0A,0x0D,0x04,0x01
        .db 0x04,0x0C,0x02,0x06,0x05,0x02,0x0A


; sound effect data:
;  header-info, stored at 9A80_8[]
;        [0]
;        [1]
;        [2]: wave table index
;  byte_pairs * n
;        [0]: lo-nibble is index into frequency tbl
;             hi-nibble^2 = divisor to note frequency
;        [1]
;        [n] 0xFF

d_07BD:
        .db 0xFF

d_07BE:
        .db 0x00,0x00,0x06
        .db 0x71,0x01,0x72,0x01,0x73,0x01,0x75,0x01
        .db 0x74,0x01,0x73,0x01,0x72,0x01,0x71,0x01,0x70,0x01,0x8B,0x01,0x8A,0x01,0x0C,0x04
        .db 0x86,0x01,0x87,0x01,0x88,0x01,0x89,0x01,0x8A,0x01,0x89,0x01,0x88,0x01,0x87,0x01
        .db 0x86,0x01,0x85,0x01,0x84,0x01,0x83,0x01,0xFF
d_07F2:
        .db 0x00,0x00,0x04,0x88,0x01,0x8A,0x01,0x70,0x01,0x71,0x01,0x73,0x01,0x75,0x01,0x77
        .db 0x01,0x78,0x01,0x0C,0x06,0x74,0x01,0x73,0x01,0x72,0x01,0x71,0x01,0x70,0x01,0x8B
        .db 0x01,0xFF
d_0814:
        .db 0x00,0x00,0x07,0x89,0x01,0x8A,0x01,0x8B,0x01,0x0C,0x01,0x70,0x01,0x71,0x01,0x72,0x01,0x0C,0x01,0x73,0x01
        .db 0x74,0x01,0x75,0x01,0x0C,0x03,0x8B,0x01,0x70,0x01,0x71,0x01,0x0C,0x01,0x72,0x01
        .db 0x73,0x01,0x74,0x01,0x0C,0x01,0x75,0x01,0x76,0x01,0x77,0x01,0x0C,0x03,0x71,0x01
        .db 0x72,0x01,0x73,0x01,0x0C,0x01,0x74,0x01,0x75,0x01,0x76,0x01,0x0C,0x01,0x77,0x01
        .db 0x78,0x01,0x79,0x01,0xFF
d_085E: ; 03
        .db 0x00,0x00,0x05,0x71,0x01,0x72,0x01,0x73,0x01,0x0C,0x01
        .db 0x74,0x01,0x75,0x01,0x76,0x01,0x0C,0x01,0x77,0x01,0x78,0x01,0x79,0x01,0xFF
d_0878:
        .db 0x00,0x00,0x04,0x61,0x01,0x7A,0x01,0x60,0x01,0x78,0x01,0x7A,0x01,0x76,0x01,0x78
        .db 0x01,0x75,0x01,0xFF
d_088C:
        .db 0x00,0x00,0x00,0x76,0x01,0x79,0x01,0x60,0x01,0x63,0x01,0x66,0x01
        .db 0x63,0x01,0x60,0x01,0x79,0x01,0xFF
d_08A0:
        .db 0x00,0x00,0x07,0x81,0x08,0x81,0x01,0x86,0x03
        .db 0x88,0x09,0x8B,0x03,0x8A,0x09,0x86,0x03,0x88,0x09,0x73,0x03,0x71,0x09,0x86,0x03
        .db 0x88,0x09,0x8B,0x03,0x8A,0x09,0x86,0x03,0x71,0x09,0x75,0x03,0x76,0x09,0x74,0x03
        .db 0x72,0x09,0x71,0x03,0x8B,0x09,0x89,0x03,0x88,0x09,0x84,0x03,0x74,0x09,0x76,0x03
        .db 0x74,0x09,0x71,0x03,0x73,0x04,0x8B,0x04,0x88,0x04,0x71,0x04,0x8A,0x04,0x88,0x04
        .db 0x0C,0x10,0xFF
d_08EC:
        .db 0x00,0x00,0x06,0x8A,0x09,0x81,0x03,0x88,0x09,0x83,0x03,0x86,0x09
        .db 0x81,0x03,0x83,0x09,0x85,0x03,0x8A,0x09,0x81,0x03,0x88,0x09,0x83,0x03,0x86,0x09
        .db 0x81,0x03,0x88,0x09,0x71,0x03,0x72,0x09,0x71,0x03,0x8B,0x09,0x89,0x03,0x88,0x09
        .db 0x86,0x03,0x84,0x09,0x88,0x03,0x89,0x09,0x8B,0x03,0x89,0x09,0x86,0x03,0x8B,0x04
        .db 0x88,0x04,0x83,0x04,0x88,0x04,0x85,0x04,0x83,0x04,0x0C,0x10,0xFF
d_0936:
        .db 0x00,0x00,0x07,0x81,0x0C,0x83,0x09,0x86,0x03,0x85,0x0C,0x81,0x0C,0x86,0x0C,0x88,0x09,0x8B,0x03
        .db 0x8A,0x0C,0x88,0x0C,0x89,0x0C,0x88,0x09,0x86,0x03,0x84,0x0C,0x89,0x0C,0x74,0x0C
        .db 0x71,0x09,0x89,0x03,0x88,0x0C,0x71,0x09,0x8A,0x03,0x0C,0x10,0xFF
d_0966:
        .db 0x02,0x00,0x03
        .db 0x78,0x02,0x0C,0x01,0x78,0x01,0x79,0x01,0x7B,0x01,0x61,0x03,0x0C,0x03,0xFF
d_0978:
        .db 0x02,0x00,0x03,0x73,0x02,0x0C,0x01,0x73,0x01,0x74,0x01,0x76,0x01,0x78,0x03,0x0C,0x02
        .db 0xFF
d_098A:
        .db 0x02,0x00,0x03,0x70,0x02,0x0C,0x01,0x70,0x01,0x71,0x01,0x73,0x01,0x75,0x03,0x0C,0x02,0xFF
d_099C:
        .db 0x01,0x00,0x04,0x78,0x01,0x7A,0x01,0x63,0x01,0x78,0x01,0x7A,0x01,0x63,0x01,0x65,0x03,0xFF
d_09AE:
        .db 0x01,0x00,0x05,0x73,0x01,0x78,0x01,0x7A,0x01,0x73,0x01,0x78,0x01,0x7A,0x01,0x60,0x03,0xFF
d_09C0:
        .db 0x01,0x00,0x07,0x8A,0x01,0x73,0x01,0x78,0x01,0x8A,0x01,0x73,0x01,0x78,0x01,0x7A,0x03,0xFF
d_09D2: ; 05
        .db 0x01,0x06,0x04,0x7A,0x01,0x78,0x01,0x7A,0x01,0x61,0x01,0x65,0x01,0x68,0x03,0xFF
d_09E2:
        .db 0x01,0x06,0x04,0x78,0x01,0x75,0x01,0x78,0x01,0x7A,0x01,0x61,0x01,0x65,0x03,0xFF
d_09F2:
        .db 0x01,0x06,0x04,0x75,0x01,0x71,0x01,0x75,0x01,0x78,0x01,0x7A,0x01,0x60,0x03,0xFF
d_0A02:
        .db 0x02,0x04,0x03,0x7A,0x01,0x76,0x01,0x78,0x01,0x75,0x01,0x76,0x01,0x73,0x01,0x75,0x01,0x72,0x01,0x73,0x01,0x8A,0x01
        .db 0x8B,0x01,0x88,0x01,0x86,0x01,0x85,0x01,0x83,0x01,0x82,0x01,0x83,0x01,0x86,0x01
        .db 0x85,0x01,0x88,0x01,0x86,0x01,0x8A,0x01,0x88,0x01,0x8B,0x01,0x8A,0x01,0x73,0x01
        .db 0x72,0x01,0x73,0x01,0x75,0x01,0x8A,0x01,0x70,0x01,0x72,0x01,0xFF
d_0A46:
        .db 0x02,0x04,0x03,0x76,0x01,0x73,0x01,0x75,0x01,0x72,0x01,0x73,0x01,0x70,0x01,0x72,0x01,0x8A,0x01
        .db 0x8B,0x01,0x86,0x01,0x88,0x01,0x85,0x01,0x83,0x01,0x82,0x01,0x80,0x01,0x9A,0x01
        .db 0x9A,0x01,0x83,0x01,0x82,0x01,0x85,0x01,0x83,0x01,0x86,0x01,0x85,0x01,0x88,0x01
        .db 0x86,0x01,0x8A,0x01,0x88,0x01,0x8B,0x01,0x8A,0x01,0x88,0x01,0x86,0x01,0x85,0x01
        .db 0xFF
d_0A8A:
        .db 0x02,0x10,0x03,0x93,0x02,0x9A,0x02,0x83,0x03,0x9A,0x01,0x98,0x01,0x96,0x01
        .db 0x95,0x01,0x93,0x02,0x95,0x03,0x96,0x02,0x98,0x02,0x9A,0x02,0x9B,0x02,0x9A,0x02
        .db 0x98,0x01,0x96,0x01,0x95,0x01,0x92,0x01,0x93,0x01,0x95,0x01,0xFF
d_0AB6:
        .db 0x02,0x04,0x03,0x7A,0x01,0x77,0x01,0x78,0x01,0x75,0x01,0x77,0x01,0x73,0x01,0x75,0x01,0x72,0x01
        .db 0x73,0x01,0x8A,0x01,0x80,0x01,0x88,0x01,0x87,0x01,0x85,0x01,0x83,0x01,0x82,0x01
        .db 0x83,0x01,0x87,0x01,0x85,0x01,0x88,0x01,0x87,0x01,0x8A,0x01,0x88,0x01,0x80,0x01
        .db 0x8A,0x01,0x73,0x01,0x72,0x01,0x73,0x01,0x75,0x01,0x8A,0x01,0x70,0x01,0x72,0x01
        .db 0xFF
d_0AFA:
        .db 0x02,0x04,0x03,0x77,0x01,0x73,0x01,0x75,0x01,0x72,0x01,0x73,0x01,0x70,0x01
        .db 0x72,0x01,0x8A,0x01,0x80,0x01,0x87,0x01,0x88,0x01,0x85,0x01,0x83,0x01,0x82,0x01
        .db 0x80,0x01,0x9A,0x01,0x9A,0x01,0x83,0x01,0x82,0x01,0x85,0x01,0x83,0x01,0x87,0x01
        .db 0x85,0x01,0x88,0x01,0x87,0x01,0x8A,0x01,0x88,0x01,0x80,0x01,0x8A,0x01,0x88,0x01
        .db 0x87,0x01,0x85,0x01,0xFF
d_0B3E:
        .db 0x02,0x10,0x03,0x93,0x02,0x9A,0x02,0x83,0x03,0x9A,0x01
        .db 0x98,0x01,0x97,0x01,0x95,0x01,0x93,0x02,0x95,0x03,0x97,0x02,0x98,0x02,0x9A,0x02
        .db 0x90,0x02,0x9A,0x02,0x98,0x01,0x97,0x01,0x95,0x01,0x92,0x01,0x93,0x01,0x95,0x01
        .db 0xFF
d_0B6A:
        .db 0x02,0x04,0x03,0x7A,0x01,0x76,0x01,0x78,0x01,0x75,0x01,0x76,0x01,0x73,0x01
        .db 0x75,0x01,0x72,0x01,0x73,0x01,0x8A,0x01,0x8A,0x01,0x88,0x01,0x86,0x01,0x85,0x01
        .db 0x83,0x01,0x82,0x01,0x83,0x01,0x85,0x01,0x86,0x01,0x88,0x01,0x86,0x01,0x8A,0x01
        .db 0x70,0x01,0x72,0x01,0x73,0x04,0xFF
d_0BA0:
        .db 0x02,0x04,0x03,0x76,0x01,0x73,0x01,0x75,0x01
        .db 0x72,0x01,0x73,0x01,0x70,0x01,0x72,0x01,0x8A,0x01,0x8A,0x01,0x86,0x01,0x86,0x01
        .db 0x85,0x01,0x83,0x01,0x82,0x01,0x80,0x01,0x9A,0x01,0x9A,0x01,0x8B,0x01,0x80,0x01
        .db 0x82,0x01,0x83,0x01,0x85,0x01,0x86,0x01,0x88,0x01,0x8A,0x04,0xFF
d_0BD6:
        .db 0x02,0x10,0x03,0x73,0x02,0x75,0x02,0x76,0x02,0x75,0x02,0x73,0x02,0x72,0x02,0x70,0x02,0x72,0x02
        .db 0x73,0x02,0x8B,0x02,0x8A,0x02,0x86,0x02,0x83,0x04,0xFF
d_0BF4:
        .db 0x00,0x00,0x04,0x71,0x04,0x73,0x04,0x71,0x04,0x73,0x04,0x76,0x04,0x78,0x04,0x76,0x04,0x78,0x04,0xFF
d_0C08:
        .db 0x00,0x00,0x06,0x56,0x01,0x55,0x01,0x54,0x01,0x53,0x01,0x52,0x01,0x51,0x01,0x50,0x01
        .db 0x6B,0x01,0x6A,0x01,0x69,0x01,0x68,0x01,0x67,0x01,0x66,0x01,0x65,0x01,0x64,0x01
        .db 0x63,0x01,0x62,0x01,0x61,0x01,0x60,0x01,0x7B,0x01,0x7A,0x01,0x79,0x01,0x78,0x01
        .db 0x77,0x01,0x76,0x01,0x75,0x01,0x74,0x01,0x73,0x01,0x72,0x01,0x71,0x01,0x70,0x01
        .db 0x8B,0x01,0x8A,0x01,0x89,0x01,0x88,0x01,0x87,0x01,0x86,0x01,0x85,0x01,0x84,0x01
        .db 0x83,0x01,0xFF
d_0C5C:
        .db 0x02,0x04,0x05,0x60,0x01,0x78,0x01,0x75,0x01,0x71,0x01,0x60,0x01
        .db 0x78,0x01,0x75,0x01,0x71,0x01,0x60,0x01,0x78,0x01,0x75,0x01,0x71,0x01,0x60,0x01
        .db 0x78,0x01,0x75,0x01,0x71,0x01,0x60,0x01,0x78,0x01,0x75,0x01,0x71,0x01,0x60,0x01
        .db 0x78,0x01,0x75,0x01,0x71,0x01,0x60,0x01,0x0C,0x01,0x78,0x01,0x7A,0x01,0x75,0x01
        .db 0x78,0x01,0x73,0x01,0x75,0x01,0x61,0x01,0x7A,0x01,0x76,0x01,0x73,0x01,0x61,0x01
        .db 0x7A,0x01,0x76,0x01,0x73,0x01,0x61,0x01,0x7A,0x01,0x76,0x01,0x73,0x01,0x61,0x01
        .db 0x7A,0x01,0x76,0x01,0x73,0x01,0x61,0x01,0x79,0x01,0x76,0x01,0x73,0x01,0x61,0x01
        .db 0x79,0x01,0x76,0x01,0x73,0x01,0x61,0x01,0x0C,0x01,0x79,0x01,0x61,0x01,0x78,0x01
        .db 0x79,0x01,0x75,0x01,0x78,0x01,0xFF
d_0CE0:
        .db 0x02,0x02,0x05,0x60,0x01,0x60,0x01,0x60,0x01,0xFF
d_0CEA:
        .db 0x02,0x04,0x05,0x61,0x02,0x78,0x02,0x78,0x02,0x61,0x02,0x78,0x02,0x78,0x02
        .db 0x61,0x02,0x78,0x02,0x78,0x02,0x61,0x02,0x78,0x02,0x78,0x02,0x61,0x02,0x78,0x02
        .db 0x7A,0x02,0x75,0x02,0x63,0x02,0x7A,0x02,0x7A,0x02,0x63,0x02,0x7A,0x02,0x7A,0x02
        .db 0x63,0x02,0x7A,0x02,0x79,0x02,0x63,0x02,0x79,0x02,0x79,0x02,0x63,0x02,0x79,0x02
        .db 0x76,0x02,0x73,0x02,0xFF
d_0D2E:
        .db 0x02,0x02,0x05,0x78,0x01,0x78,0x01,0x78,0x01,0xFF
d_0D38:
        .db 0x02,0x10,0x05,0x85,0x06,0x85,0x06,0x85,0x06,0x85,0x06,0x85,0x04,0x85,0x04,0x86,0x06
        .db 0x86,0x06,0x86,0x06,0x86,0x06,0x86,0x04,0x86,0x04,0xFF
d_0D54:
        .db 0x02,0x04,0x05,0x81,0x01,0x81,0x01,0x81,0x01,0xFF
d_0D5E: ; 15
        .db 0x02,0x00,0x07,0x65,0x01,0x0C,0x01,0x61,0x01,0x0C,0x01,0x63,0x01,0xFF
d_0D6C:
        .db 0x02,0x00,0x05,0x7A,0x05,0x0C,0x01,0x7A,0x01,0x0C,0x01,0x7A,0x03
        .db 0x0C,0x01,0x78,0x07,0x0C,0x01,0x78,0x07,0x0C,0x01,0x78,0x03,0x0C,0x01,0x7B,0x05
        .db 0x0C,0x01,0x7B,0x01,0x0C,0x01,0x7B,0x03,0x0C,0x01,0x7A,0x07,0x0C,0x01,0x7A,0x07
        .db 0x0C,0x01,0x7A,0x03,0x0C,0x01,0x7B,0x01,0x0C,0x01,0x7B,0x01,0x0C,0x03,0x7B,0x01
        .db 0x0C,0x01,0x7B,0x03,0x0C,0x01,0x61,0x01,0x0C,0x01,0x61,0x01,0x0C,0x03,0x61,0x01
        .db 0x0C,0x01,0x61,0x03,0x0C,0x01,0x61,0x03,0x0C,0x01,0x61,0x03,0x0C,0x01,0x63,0x01
        .db 0x0C,0x01,0x63,0x01,0x0C,0x03,0x63,0x01,0x0C,0x01,0x63,0x03,0x0C,0x01,0x63,0x03
        .db 0x0C,0x01,0x63,0x03,0x0C,0x01,0xFF
d_0DE0:
        .db 0x02,0x00,0x03,0x86,0x02,0x8A,0x02,0x71,0x02
        .db 0x76,0x02,0x86,0x02,0x8A,0x02,0x71,0x02,0x76,0x02,0x86,0x02,0x8A,0x02,0x71,0x02
        .db 0x76,0x02,0x86,0x02,0x8A,0x02,0x71,0x02,0x76,0x02,0x86,0x02,0x8A,0x02,0x71,0x02
        .db 0x76,0x02,0x86,0x02,0x8A,0x02,0x71,0x02,0x76,0x02,0x86,0x02,0x8A,0x02,0x71,0x02
        .db 0x76,0x02,0x86,0x02,0x8A,0x02,0x71,0x02,0x76,0x02,0x77,0x01,0x0C,0x01,0x77,0x01
        .db 0x0C,0x03,0x77,0x01,0x0C,0x01,0x77,0x03,0x0C,0x01,0x69,0x01,0x0C,0x01,0x69,0x01
        .db 0x0C,0x03,0x69,0x01,0x0C,0x01,0x69,0x03,0x0C,0x01,0x69,0x03,0x0C,0x01,0x69,0x03
        .db 0x0C,0x01,0x8B,0x02,0x73,0x02,0x76,0x02,0x7B,0x02,0x7B,0x02,0x76,0x02,0x73,0x02
        .db 0x8B,0x02,0xFF
d_0E5C:
        .db 0x00,0x00,0x02,0x86,0x08,0x81,0x08,0x86,0x08,0x81,0x08,0x86,0x08
        .db 0x81,0x08,0x86,0x08,0x81,0x08,0x82,0x01,0x0C,0x01,0x82,0x01,0x0C,0x03,0x82,0x01
        .db 0x0C,0x01,0x82,0x03,0x0C,0x01,0x84,0x01,0x0C,0x01,0x84,0x01,0x0C,0x03,0x84,0x01
        .db 0x0C,0x01,0x84,0x03,0x0C,0x01,0x84,0x03,0x0C,0x01,0x84,0x03,0x0C,0x01,0x7B,0x08
        .db 0x76,0x04,0x8B,0x04,0xFF
d_0E9E:
        .db 0x00,0x0C,0x05,0x75,0x0C,0x71,0x0C,0x8A,0x0C,0x86,0x0C
        .db 0x0C,0x09,0x75,0x03,0x71,0x09,0x8A,0x03,0x86,0x04,0x8A,0x04,0x71,0x04,0x89,0x04
        .db 0x70,0x04,0x73,0x04,0x8B,0x0C,0x73,0x0C,0x76,0x0C,0x78,0x0C,0x0C,0x09,0x79,0x03
        .db 0x76,0x09,0x72,0x03,0x8B,0x04,0x89,0x04,0x86,0x04,0x72,0x04,0x89,0x04,0x76,0x04,0xFF
d_0EDA:
        .db 0x00,0x0C,0x05,0x71,0x0C,0x8A,0x0C,0x86,0x0C,0x85,0x0C,0x0C,0x09,0x81,0x03
        .db 0x8A,0x09,0x86,0x03,0x85,0x04,0x86,0x04,0x8A,0x04,0x86,0x04,0x89,0x04,0x8B,0x04
        .db 0x88,0x0C,0x8B,0x0C,0x73,0x0C,0x76,0x0C,0x0C,0x09,0x76,0x03,0x72,0x09,0x8B,0x03
        .db 0x8A,0x04,0x86,0x04,0x82,0x04,0x8B,0x04,0x89,0x04,0x82,0x04,0xFF
d_0F16:
        .db 0x00,0x00,0x03,0x75,0x18,0x75,0x18,0x75,0x18,0x71,0x0C,0x75,0x0C,0x73,0x18,0x73,0x18,0x72,0x18
        .db 0x76,0x0C,0x78,0x0C,0xFF

; not sure this one
        .db 0xFA

;       .org 0x0FFF
;       .db 0xFF
; end of ROM
