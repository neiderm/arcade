;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; gg1-3.s
;;  gg1-3.2m, 'maincpu' (Z80)
;;
;;  Manages formation, attack convoys, boss/capture.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.module mob_mgr

.include "structs.inc"
.include "gg1-3.dep"

;.area ROM (ABS,OVR)
;       .org 0x1FFF
;       .db  0xFF                                   ; checksum 0x8C
;       .org 0x2000
.area CSEG20


;;=============================================================================
;; f_2000()
;;  Description:
;;    activated when the boss is destroyed that has captured the ship
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
f_2000:
       ld   a,(ds_plyr_actv +_b_bmbr_boss_cobj)   ; object locator for captured ship
       ld   l,a
       ld   h,#>b_8800
       ld   a,(hl)
       and  a
       jp   nz,l_20BF                             ; no idea how it could be nz...
; if ( captr_status_1 == 0 )
       ld   a,(ds5_928A_captr_status + 0x01)
       and  a
       jp   z,l_20C7
; else if ( captr_status_1 == 1 )
       dec  a
       jp   z,l_20D1_update_ship_spin
; else ... status is 2 when stopped spinning and preparing for landing
       ld   h,#>ds_sprite_posn
       ld   a,(hl)
       cp   #0x80
       jr   z,l_2026
       jp   p,l_2023
       inc  (hl)
       jr   l_205E
l_2023:
       dec  (hl)
       jr   l_205E

l_2026:
       inc l
       ld   a,(b_9215_flip_screen)
       and  a
       jr   nz,l_204C
       ld   a,(hl)
       cp   #0x29
       jr   nz,l_2041
       ld   h,#>ds_sprite_ctrl
       ld   a,(hl)
       ld   h,#>ds_sprite_posn
       dec  a
       jr   nz,l_2041
l_203A:
       ld   a,#3
       ld   (ds5_928A_captr_status + 0x01),a      ; 3 (ships are joined now)
       jr   l_205E

l_2041:
       inc  (hl)
       jr   nz,l_205E
l_2044:
       ld   h,#>ds_sprite_ctrl                    ; rescued ship is "landing"
       ld   a,(hl)
       xor  #0x01
       ld   (hl),a
       jr   l_205E
l_204C:
       ld   a,(hl)                                ; when?
       cp   #0x37
       jr   nz,l_2059
       ld   h,#>ds_sprite_ctrl
       ld   a,(hl)
       ld   h,#>ds_sprite_posn
       and  a
       jr   z,l_203A
l_2059:
       dec  (hl)
       ld   a,(hl)
       inc  a
       jr   z,l_2044
l_205E:
       ld   hl,#ds_sprite_code + 0x62             ; ship (1) sprite code
       ld   a,(hl)
       sub  #6                                    ; glyphs 6 & 7 are both for upright ship... (7 is "wings closed" if captured)
       ld   c,a                                   ; ... so we have 0 or possibly 1 here.
       ld   h,#>ds_sprite_posn
       jr   nz,l_2075
       ld   a,(hl)
       cp   #0x71
       jr   z,l_2075
       jp   p,l_2073
       inc  (hl)                                  ; when?
       ret
l_2073:
       dec  (hl)
       ret

; the rescued ship has been moved horizontally to column adjacent to main-ship
l_2075:
       ld   a,(ds5_928A_captr_status + 0x01)      ; rescued ship is "landing" (becomes 3 when ships join)
       cp   #3
       ret  nz
 ; both ships are now joined
       ld   a,(ds_plyr_actv +_b_bmbr_boss_cobj)   ; object locator for the captured ship
       ld   l,a
       ld   (hl),#0                               ; 0 out the sprite position of the captured ship object e.g. 9300, 9302 etc.
       inc  l
       dec  c
       inc  c
       jr   z,l_208F

       ld   de,#ds_sprite_posn + 0x63             ; this is if ship (1) sprite code was 7
       xor  a
       ld   (ds_plyr_actv +_b_bmbr_boss_cflag),a  ; 0 ... enable capture-mode selection
       jr   l_2097

; ship sprite code was 6
l_208F:
       ld   a,#1
       ld   (ds_plyr_actv +_b_2ship),a
       ld   de,#ds_sprite_posn + 0x61

; capture ship rejoined with active ship
l_2097:
       ld   a,(hl)                                ; e.g. HL==9301 sprite_posn
       ld   (de),a                                ; e.g. DE==9363 sprite_posn
       ld   h,#>ds_sprite_ctrl
       ld   d,h
       ld   a,(hl)                                ; e.g. HL==9B01.. ctrl_2:bit0==enable and ctrl2_bit7==sx_bit8
       ld   (de),a
       dec  l
       ld   h,#>b_8800
       ld   (hl),#0x80                            ; set captured ship object state inactive
       ld   h,#>ds_sprite_code
       ld   l,e
       dec  l
       ld   (hl),#6                               ; sprite code 6
       inc  l
       ld   (hl),#9                               ; color map 9 for white ship
       dec  l
       ld   h,#>ds_sprite_posn
       ld   (hl),#0x80                            ; put in center
       ld   a,#1
       ld   (ds_cpu0_task_actv + 0x14),a          ; 1 (f_0827 ... empty task)
       ld   (ds_cpu0_task_actv + 0x15),a          ; 1 (f_1F04 ...fire button input))
       ld   (ds_cpu1_task_actv + 0x05),a          ; 1 (cpu1:f_05EE .. Manage ship collision detection)
       ld   (ds_99B9_star_ctrl + 0x00),a          ; 1 (when ship on screen
; capture ship rejoined with active ship
l_20BF:
       xor  a
       ld   (ds_cpu0_task_actv + 0x1D),a          ; 0 ... this task
       ld   (b_9AA0 + 0x11),a                     ; 0 ... sound-fx count/enable registers, stop "rescued ship" music
       ret

l_20C7:                                           ; *( ds5_928A_captr_status + 0x01 ) == 0
       inc  a
       ld   (ds5_928A_captr_status + 0x01),a      ; 1
       ld   a,#2
       ld   (ds4_game_tmrs + 1),a                 ; 2
       ret

l_20D1_update_ship_spin:
       ld   h,#>ds_sprite_ctrl                    ; base address for c_2188
       ld   a,(ds4_game_tmrs + 1)
       ld   e,a
       ld   a,(b_bugs_flying_nbr)
       or   e
       ld   (ds5_928A_captr_status + 0x03),a
       call c_2188_ship_spin                      ; Base address in HL, retval in B
       dec  b                                     ; what's in B?
       ret  nz
; rescued ship stopped spinning ... begin "landing"
       ld   (ds_cpu0_task_actv + 0x14),a          ; 0 (f_0827)
       ld   (ds_cpu0_task_actv + 0x15),a          ; 0 (f_1F04 ...fire button input))
       ld   (ds_cpu1_task_actv + 0x05),a          ; 0 (cpu1:f_05EE)
       ld   a,#2
       ld   (ds5_928A_captr_status + 0x01),a      ; 2
       ret
; end 2000?

;;=============================================================================
;; f_20F2()
;;  Description:
;;   handles the sequence where the tractor beam captures the ship.
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
f_20F2:
       ld   hl,#ds_sprite_ctrl + 0x62             ; ship (1) position ...base address for c_2188
       call c_2188_ship_spin                      ; Base address in HL, retval in B
       bit  0,b
       jr   nz,l_2151
       ld   a,(ds5_928A_captr_status + 0x01)      ; check bit 7
       bit  7,a
       jr   nz,l_215D
       ld   a,(ds5_928A_captr_status + 0x03)
       and  a
       ret  z
       ld   h,#>ds_sprite_posn
       ld   a,(ds_plyr_actv +_b_bmbr_boss_cobj)   ; object index of capturing boss i.e. 30 34 36 32
       ld   e,a
       ld   d,h
       ld   a,(de)                                ; get capturing boss column position position
       cp   (hl)                                  ; compare to ship position
       jr   z,l_211A_move_ship_row                ; if equal
       jp   p,l_2119_handle_ship_left
       dec  (hl)                                  ; move ship left one step
       jr   l_211A_move_ship_row

l_2119_handle_ship_left:
       inc  (hl)                                  ; move ship right one step
l_211A_move_ship_row:
       inc  l
       ld   a,(b_9215_flip_screen)
       and  a
       jr   z,l_212C_not_flipped_screen
; handle flipped screen
       inc  (hl)
       ld   a,(hl)
       cp   #0x7A
       jr   z,l_214C_disable_firepower
       cp   #0x80
       jr   z,l_2141_connected
       ret

l_212C_not_flipped_screen:
       dec  (hl)
       ld   a,(hl)
       inc  a
       jr   nz,l_2139
; handle overflow by toggling bit-0 (off)
       ld   h,#>ds_sprite_ctrl
       ld   a,(hl)
       xor  #0x01
       ld   (hl),a
       ld   h,#>ds_sprite_posn
l_2139:
       ld   a,(hl)
       cp   #0xE6
       jr   z,l_214C_disable_firepower
       cp   #0xE0
       ret  nz
l_2141_connected:
       xor  a
       ld   (ds5_928A_captr_status + 0x03),a      ; 0
       inc  a                                     ; huh?
       ld   a,#7                                  ; color map of redship
       ld   (ds_sprite_code + 0x63),a
       ret

; disables your rockets when the boss has finally connected.
l_214C_disable_firepower:
       xor  a
       ld   (ds_cpu0_task_actv + 0x15),a          ; 0 ... f_1F04 (fire button input)
       ret

 ; either the boss made final connection with ship, or the boss was shot while beaming the ship
l_2151:
; if ( firepower_enabled )...
       ld   a,(ds_cpu0_task_actv + 0x15)          ; f_1F04
       and  a
       jr   nz,l_215D
; else ...
       inc  a
       ld   (ds_9200_glbls + 0x0D),a              ; 1 ... boss connected with ship and firepower has been disabled
       jr   l_217F_finished

; the ship is in the beam but then shoots the boss
l_215D:
       ld   h,#>ds_sprite_posn
       inc  l
       ld   a,(b_9215_flip_screen)
       and  a
       jr   z,l_216D
       ld   a,(hl)
       cp   #0x37
       jr   z,l_217D
       dec  (hl)
       ret

l_216D:                                           ; when?
       ld   a,(hl)
       cp   #0x29
       jr   z,l_217D
       inc  (hl)
       ret  nz
       ld   h,#>ds_sprite_ctrl
       ld   a,(hl)
       xor  #0x01
       ld   (hl),a
       ld   h,#>ds_sprite_posn
       ret
l_217D:
       dec  b
       ret  nz
l_217F_finished:
       xor  a
       ld   (ds_cpu0_task_actv + 0x1C),a          ; 0: f_20F2 ... this task
       inc  a
       ld   (ds_cpu1_task_actv + 0x05),a          ; 1: cpu1:f_05EE ... Manage ship collision detection
       ret
; end 20F2

;;=============================================================================
;; c_2188_ship_spin()
;;  Description:
;;   Spins the ship, either when being captured, or being released.
;; IN:
;;   Base address in HL
;; OUT:
;;   B==
;;-----------------------------------------------------------------------------
c_2188_ship_spin:
       ld   a,(hl)
       ld   c,a
       srl  a
       xor  c
       ld   c,a
       ld   h,#>ds_sprite_code
       ld   b,#0
       ld   a,(hl)
       and  #0x07
       cp   #6
       jr   nz,l_21A7                             ; iterated up and down between 0 and 6 as ship rotates in the beam
       dec  c
       inc  c
       jr   nz,l_21A7
       ex   af,af'                                ; ship rotated around through 180 degrees
       ld   a,(ds5_928A_captr_status + 0x03)
       and  a
       jr   nz,l_21A6
       inc  b
       ret

l_21A6:
       ex   af,af'
l_21A7:
       bit  0,c
       jr   nz,l_21B2
       cp   #6
       jr   z,l_21B8
       inc  (hl)
       jr   l_21C0
l_21B2:
       and  a
       jr   z,l_21B8
       dec  (hl)
       jr   l_21C0
l_21B8:
       dec  c
       jp   p,l_21A7
       ld   c,#3
       jr   l_21A7
l_21C0:
       ld   a,c
       bit  1,a
       jr   z,l_21C7
       xor  #0x01
l_21C7:
       ld   h,#>ds_sprite_ctrl
       ld   (hl),a
       ret
; end 2188

;;=============================================================================
;; f_21CB()
;;  Description:
;;   Active when a boss diving down to capture the ship. Ends when the boss
;;   takes position to start the beam.
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
f_21CB:
; if ( HOMING == b_8800[ plyr_actv.captr_boss_id ] )
       ld   hl,#ds_plyr_actv +_b_bmbr_boss_cobj
       ld   e,(hl)
       ld   d,#>b_8800
       ld   a,(de)
       cp   #9
       jr   nz,l_221A                             ; exit
; ... then ...

; get the element of the bug_motion_que being used by this object. The byte-
; offset of the element is stored by plyr_actv.b09
       inc  l                                     ; _b09_cboss_slot ... set by cpu-b as capturing boss starts dive
       ld   a,(hl)
       ld   ixl,a
       ld   ixh,>ds_bug_motion_que

       ld   a,0x0A(ix)                            ; while !0, capture boss is diving
       and  a
       ret  nz

       ld   a,#0x0C
       bit  0,0x05(ix)                            ; if set, negate (ix)0x0C ... capture boss nearly in position
       jr   z,l_21EC
       neg
l_21EC:
       ld   0x0C(ix),a                            ; 12 or -12 if (ix)0x05:0 set

       ld   a,0x05(ix)
       rrca
       ld   a,0x04(ix)
       rra
       sub  #0x78
       cp   #0x10
       ret  nc

; in position
       ld   a,(ds_new_stage_parms + 0x06)         ; plyr_state_actv[0x0A] ... ship capture status
       ld   (ds_plyr_actv +_b_captr_flag),a       ; new_stage_parms[ 6 ]
       xor  a
       ld   0x0C(ix),a                            ; 0
       ld   (ds_cpu0_task_actv + 0x19),a          ; 0 (f_21CB)
       ld   (ds5_928A_captr_status + 0x01),a      ; 0
       ld   (ds_9200_glbls + 0x0D),a              ; 0
       inc  a
       ld   (ds_cpu0_task_actv + 0x18),a          ; 1 (f_2222 ... Boss starts tractor beam)
       ld   (ds5_928A_captr_status + 0x02),a      ; 1
       ld   (ds5_928A_captr_status + 0x03),a      ; 1
       ret
l_221A:
       xor  a
       ld   (ds_cpu0_task_actv + 0x19),a          ; 0 (f_21CB)
       ld   (ds_plyr_actv +_b_bmbr_boss_cflag),a  ; 0 ... enable capture-mode selection
       ret
; end 21CB

;;=============================================================================
;; f_2222()
;;  Description:
;;   Boss starts tractor beam
;;   Activated by f_21CB (capture boss dives down)
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
f_2222:
;  if ( frame_count % 4 != 0 ) goto 2257
       ld   a,(ds3_92A0_frame_cts + 0)             ; frame_ct%4 ... (provides 15Hz timer)
       ld   c,a
       and  #0x03
       jr   nz,l_2257
;  else
       ld   a,(ds5_928A_captr_status + 0x00)      ; beam started
       neg
       sub  #0x18
       ld   h,#0x21
       rlca
       rl   h
       rlca
       rl   h
       and  #0xE0
       add  a,#0x15
       ld   l,a
       ld   a,c
       rrca
       rrca
       and  #0x03
       jr   nz,l_2246
       inc  a
l_2246:
       add  a,#0x17
       ld   de,#0x0016
       ld   c,#6
l_224D:
       ld   b,#0x0A
l_224F:
       ld   (hl),a
       inc  l
       djnz l_224F

       add  hl,de
       dec  c
       jr   nz,l_224D

l_2257:
       ld   hl,#ds5_928A_captr_status + 0x01      ; check bit 7
       bit  7,(hl)
       jr   nz,l_226A
       ld   a,(ds_plyr_actv +_b_bmbr_boss_cobj)
       ld   e,a
       ld   d,#>b_8800
       ld   a,(de)
       cp   #0x09                                 ; 09 ... in a diving attack
       jp   nz,l_2327_shot_boss_while_capturing
l_226A:
; if  ( ( *( ds5_928A_captr_status + 0x02 )-- ) > 0 ) goto 233D
       ld   hl,#ds5_928A_captr_status + 0x02      ; -=1
       dec  (hl)
       jp   nz,l_233D
; else
       ld   a,(ds_plyr_actv +_b_captr_flag)       ; *( ds5_928A_captr_status + 0x02 )
       ld   (hl),a
; if ( *(_captr_status + 0x01) & $80 ) goto 22AB
       ld   hl,#ds5_928A_captr_status + 0x01      ; check bit 7
       bit  7,(hl)
       jr   nz,l_22AB
; else
       ld   (b_9AA0 + 0x05),a                     ; sound-fx count/enable registers, trigger capture beam sound

       ld   a,(ds_plyr_actv +_b_cboss_slot)       ; bug_flite_que[ plyr.cboss_slot ].b0D = $FF
       add  a,#0x0D
       ld   e,a
       ld   d,#>ds_bug_motion_que                 ; bug_flite_que[ plyr.cboss_slot ].b0D = $FF
       ld   a,#0xFF
       ld   (de),a

       inc  (hl)
       ld   a,(hl)
       and  #0x0F
       cp   #0x0B
       jr   z,l_22D2
       bit  6,(hl)
       jr   nz,l_22C1
       push af
       ld   c,a
       rlca
       add  a,c
       ld   hl,#d_23A1 - 6                        ; get data src, getting ready to shoot the tractor beam
       rst  0x08                                  ; HL += 2A
       pop  af
       call c_238A

       ld   b,#6
l_22A4:
       ld   a,(hl)
       ld   (de),a
       inc  hl
       rst  0x20                                  ; DE-=$20
       djnz l_22A4
       ret

l_22AB:
       inc  (hl)
       ld   a,(hl)
       and  #0x0F
       cp   #0x0B
       jr   nz,l_22C5
       xor  a
       ld   (ds_cpu0_task_actv + 0x18),a          ; 0 (f_2222 ... this one)
       ld   (b_9AA0 + 0x05),a                     ; 0 ... sound-fx count/enable registers, capture beam sound active uno
       ld   (b_9AA0 + 0x06),a                     ; 0 ... sound-fx count/enable registers, capture beam sound active deux
       ld   (ds_plyr_actv +_b_bmbr_boss_cflag),a  ; 0 ... enable capture-mode selection
       ret

l_22C1:
       neg                                        ; from 2294, boss almost ready to attach to the ship
       add  a,#0x0B
l_22C5:
       call c_238A

       ld   b,#6
       ld   c,#0x24
l_22CC:
       ld   a,c
       ld   (de),a
       rst  0x20                                  ; DE-=$20
       djnz l_22CC

       ret

l_22D2:
       bit  6,(hl)                                ; got the ship, ship is red, beam gone
       jr   z,l_231C
       ld   a,(ds_9200_glbls + 0x0D)              ; if 1, boss has connected with ship and firepower disabled
       and  a
       jr   z,l_22E3
       bit  5,(hl)
       jr   nz,l_22E3
       ld   (hl),#0x68
       ret

; capture beam has stopped (whether or not ship is captured or got destroyed by a bomb)
l_22E3:
       xor  a
       ld   (ds_cpu0_task_actv + 0x18),a          ; 0 (disable f_2222 ... this one)
       ld   (b_9AA0 + 0x05),a                     ; 0 ... sound-fx count/enable registers, capture beam sound active uno
       ld   (b_9AA0 + 0x06),a                     ; 0 ... sound-fx count/enable registers, capture beam sound active deux
       ld   a,(ds_9200_glbls + 0x0D)              ; if 1, boss has connected with ship and firepower disabled
       and  a
       ld   a,(ds_plyr_actv +_b_cboss_slot)       ; bug_flite_que[ plyr.cboss_slot + $nn ] ... nn -> b0D or b08
       jr   nz,l_2305
; if  0 == b_9200[$0D] ...
       add  a,#0x0D
       ld   e,a
       ld   d,#>ds_bug_motion_que                 ; bug_flite_que[plyr.boss_slot].b0D = 1 ... token expiration on next step
       xor  a
       ld   (ds_plyr_actv +_b_bmbr_boss_cflag),a  ; 0 ... enable capture-mode selection
       inc  a
       ld   (ds_plyr_actv +_b_bmbr_boss_cobj),a   ; 1 ... why 1?
       ld   (de),a                                ; bug_flite_que[plyr.cboss_slot].b0D = 1 ... token expiration on next step
       ret

; ... else ... (connected with ship)
l_2305:
       add  a,#8
       ld   l,a
       ld   h,#>ds_bug_motion_que                 ; bug_flite_que[plyr.cboss_slot].p08 = &db_046B[0] ... pointer to flite data
       ld   de,#db_flv_cboss
       ld   (hl),e
       inc  l
       ld   (hl),d

       xor  a
       ld   (ds_99B9_star_ctrl + 0x01),a          ; 0
       inc  a
       ld   (ds_cpu0_task_actv + 0x11),a          ; 1 (enable f_19B2 ... fighter captured)
       ld   (ds5_928A_captr_status + 0x04),a      ; 1 ... (fighter captured)
       ret

l_231C:
       ld   a,#0x40                               ; beam nearly got ship
       ld   (ds5_928A_captr_status + 0x02),a      ; 928C=928b=$40
       ld   a,#0x40                               ; well this is inefficient ...!
       ld   (ds5_928A_captr_status + 0x01),a      ; 928C=928b=$40
       ret

l_2327_shot_boss_while_capturing:
       ld   a,#3
       ld   (ds_plyr_actv +_b_captr_flag),a       ; 3 (shot_boss_while_capturing)
       ld   (hl),#0x80                            ; HL == ds5_928A_captr_status + 0x01
       xor  a
       ld   (ds5_928A_captr_status + 0x03),a      ; 0
       ld   (ds_99B9_star_ctrl + 0x01),a          ; 0
       inc  a
       ld   (ds5_928A_captr_status + 0x02),a      ; 1 ... shot_boss_while_capturing
       ld   (ds_cpu0_task_actv + 0x14),a          ; 1  (f_1F85 ... control stick input)
       ret

l_233D:
       ld   a,(ds5_928A_captr_status + 0x01)      ; if !$40 see 2323  (from 226E... beam just started)
       cp   #0x40
       ret  nz
; beam just about to grab ship
       ld   a,(b_9215_flip_screen)
       ld   c,a
       ld   a,(ds_sprite_posn + 0x62)             ; ship (1) position
       bit  0,c
       jr   z,l_2352
       add  a,#0x0E
       neg
l_2352:
       ld   b,a
       ld   a,(ds5_928A_captr_status + 0x00)      ; beam is pulling the ship
       sub  b
       add  a,#0x1B
       cp   #0x36
       ret  nc
; if ( game_state == ATTRACT_MODE ) goto 236d
       ld   a,(b8_9201_game_state)                ;  == ATTRACT_MODE
       dec  a
       jr   z,l_236D
; else if (  !  ( task_enabled  &&  !restart_stage )  return
       ld   a,(ds_cpu0_task_actv + 0x14)          ; f_1D32 (Moves bug nest on and off the screen )
       ld   c,a
       ld   a,(ds_9200_glbls + 0x13)
       xor  #0x01
       and  c
       ret  z

l_236D:
       xor  a
       ld   (ds_cpu0_task_actv + 0x14),a          ; 0: f_1F85... control stick input
       ld   (b_9AA0 + 0x05),a                     ; 0: sound-fx count/enable registers, capture beam sound active uno
       ld   (ds_cpu1_task_actv + 0x05),a          ; 0 ... cpu1:f_05EE
       ld   (ds_9200_glbls + 0x13),a              ; 0
       inc  a
       ld   (ds_cpu0_task_actv + 0x1C),a          ; 1: f_20F2 ... tractor beam captures
       ld   (b_9AA0 + 0x06),a                     ; 1 ... sound-fx count/enable registers, tractor beam
       ld   (ds_99B9_star_ctrl + 0x01),a          ; 1
       ld   a,#0x0A
       ld   (ds_plyr_actv +_b_captr_flag),a       ; $0A ... tractor beam capturing ship
       ret

;;=============================================================================
;; c_238A()
;;  Description:
;;   for f_2222
;;   boss about to start tractor beam
;; IN:
;;   A==
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_238A:
       ld   c,a
       ld   a,(ds5_928A_captr_status + 0x00)      ; boss about to start tractor beam
       neg
       add  a,#0x10
       ld   d,#0x20
       rlca
       rl   d
       rlca
       rl   d
       and  #0xE0
       add  a,#0x14
       add  a,c
       ld   e,a
       ret
; end 238A

;;=============================================================================
;; data for f_2222
;; 6-bytes per entry, (table starts 6-bytes past the value ld'd to HL)
d_23A1:
       .db 0x24,0x4E,0x4F,0x50,0x51,0x24,0x24,0x52,0x53,0x54
       .db 0x55,0x24,0x24,0x56,0x57,0x58,0x59,0x24,0x24,0x5A,0x5B,0x5C,0x5D,0x24,0x24,0x5E
       .db 0x5F,0x60,0x61,0x24,0x62,0x63,0x64,0x65,0x66,0x67,0x68,0x69,0x6A,0x6B,0x6C,0x6D
       .db 0x6E,0x6F,0x70,0x71,0x72,0x73,0x74,0x75,0x76,0x77,0x78,0x79,0x7A,0x7B,0x7C,0x7D
       .db 0x7E,0x7F

;;=============================================================================
;; f_23DD()
;;  Description:
;;   This task is never disabled.
;;   Updates each object in obj_status[] and updates global count of active
;;   objects.
;;   Call here for f_1D32, but normally this is a periodic task called 60Hz.
;;   Using bits <1:0> of framecounter as the state variable, 1 cycle of this
;;   task is completed over four successive frames, i.e. the cycle is repeated
;;   at a rate of 15Hz. Half of the objects are updated at each alternating odd
;;   frame. On one even frame object count is updated.
;;   The function body is broken out to a separate subroutine allowing the
;;   frame count to be forced in A (needed for update at player changeover)
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
f_23DD:
       ld   a,(ds3_92A0_frame_cts + 0)

; c_23E0

;;=============================================================================
;; c_23E0()
;;  Description:
;;   Implementation of f_23DD()
;;   See comments for f_23DD() above.
;; IN:
;;  A==_frame_counter
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_23E0:
; check if even or odd frame
       bit  0,a
       jp   z,l_2596_even_frame

; frame count bit-1 provides start index/offset of obj_status[], i.e. 0,4,8,etc.
; on frame 1 and 2,6,10,etc. on frame 3
       and  #0x02
       ld   e,a                                   ; E==0 if frame 1, E==2 if frame 3

       ld   a,(b_bugs_actv_cnt)
       ld   ixl,a                                 ; use as "local" variable for object counter

       ld   b,#32                                 ; size of object set / 2
l_23EF:
       ld   d,#>b_8800
       ld   a,(de)
; test for $80 (inactive status)
       sla  a                                     ; test for bit-7
       jr   c,l_2416                              ; DE+=4

       ld   hl,#d_23FF_jp_tbl
       rst  0x10                                  ; HL += A
       ld   a,(hl)
       inc  hl
       ld   h,(hl)
       ld   l,a
       jp   (hl)

d_23FF_jp_tbl:
       .dw case_2416 ; 80: inactive object (already tested for 0x80 so this .db is a placeholder)
       .dw case_2488 ; 01: assimilated into the collective and resting peacefully.
       .dw case_245F ; 02: rotating back into position in the collective
       .dw case_254D ; 03: state progression ... 7's to 3's, and then 9's, 2's, and finally 1's
       .dw case_24B2 ; 04: nearly fatally shot
       .dw case_2535 ; 05: showing a score bitmap for a bonus hit
       .dw case_254D ; 06  disable this one and the borg runs out of nukes
       .dw case_2590 ; 07: once for each orc as he is spawning (new stage)
       .dw case_243C ; 08: shot my damn ship (DE==8862 ... 8863 counts down from $0F for all steps of explosion)
       .dw case_2422 ; 09: ... after getting to the loop spot, or anytime on a diving attack.

l_2413:
       dec  e                                     ; reset index/pointer to b0

l_2414_inc_active:
       inc  ixl                                   ; b_bugs_actv_cnt++

case_2416:
l_2416:
       ld   a,#4
       add  a,e
       ld   e,a                                   ; index += 4

       djnz l_23EF

       ld  a,ixl                                  ; b_bugs_actv_cnt
       ld  (b_bugs_actv_cnt),a
       ret

; 09: diving
case_2422:
       ld   l,e
       ld   h,#>db_obj_home_posn_rc
       ld   c,(hl)                                ; row position index
       inc  l
       ld   l,(hl)                                ; column position index
       ld   h,#>ds_hpos_loc_offs                  ; .b0
       ld   a,(hl)                                ; X coordinate offset
       ex   af,af'
       ld   l,c                                   ; row position index
       ld   c,(hl)                                ; Y coordinate offset

; get a pointer to corresponding element of bug_motion_que[] ... byte-offset (index) in 8800[n].b1
       inc  e
       ld   a,(de)
       add  a,#0x11                               ; 0x11(ix)
       ld   l,a
       ld   h,#>ds_bug_motion_que
       ex   af,af'
       ld   (hl),a                                ; X coordinate offset
       inc  l                                     ; 0x12(ix)
       ld   (hl),c                                ; y coordinate offset
       jp   l_2413                                ; reset index to .b0 and continue

; 08: destruction of the ship
case_243C:
       ld   h,#>ds_sprite_code
       ld   l,e
       inc  e
       ld   a,(de)                                ; obj_status[].mctl_q_index used for explosion counter
       dec  a
       jr   z,l_2451                              ; the counter (odd-byte) counts down to 0 (from $F) during explosion
       ld   (de),a
       dec  e
       and  #0x03
       jr   nz,l_2416
       ld   a,(hl)
       add  a,#4
       ld   (hl),a
       jp   l_2416

l_2451:
       ld   h,#>ds_sprite_posn
       xor  a
       ld   (hl),a
       ld   h,#>ds_sprite_ctrl
       ld   (hl),a
       dec  e
       ld   a,#0x80                               ; set inactive code
       ld   (de),a
       jp   l_2416

; 02: reached home and rotating into resting position
case_245F:
       ld   h,#>ds_sprite_ctrl
       ld   l,e
       ld   a,(hl)
       and  #0x01                                 ; test flip X
       ld   h,#>ds_sprite_code
       jr   nz,l_2473
       ld   a,(hl)
       and  #0x07
       cp   #6
       jr   z,l_2483
       inc  (hl)
       jr   l_249B

l_2473:
       ld   a,(hl)
       and  #0x07
       jr   nz,l_2480
       ld   h,#>ds_sprite_ctrl
       res  0,(hl)
       ld   h,#>ds_sprite_code                    ; not used
       jr   l_249B

l_2480:
       dec  (hl)
       jr   l_249B

l_2483:
       ld   a,#1                                  ; disposition = 1: home
       ld   (de),a
       jr   l_249B

; 01: assimilated into the collective
case_2488:
       ld   h,#>ds_sprite_code
       ld   l,e
; alternate between tile code 6 and 7 every 1/2 sec: rotate bit-1 of 4 Hz timer into Cy
; and then rl the Cy into bit-0 of sprite code
       ld   a,(ds3_92A0_frame_cts + 2)
       rrc  (hl)
       rrca
       rrca
       rl   (hl)
       ld   a,(ds_9200_glbls + 0x0B)              ; update stuff if enemy enable set
       and  a
       jp   z,l_2414_inc_active

l_249B:
       ld   h,#>db_obj_home_posn_rc
       ld   c,(hl)                                ; row position index
       inc  l
       ld   l,(hl)                                ; column position index
       ld   h,#>ds_hpos_spcoords                  ; L == offset to MSB
       ld   a,(hl)
       ld   d,#>ds_sprite_posn
       ld   (de),a                                ; X pix coordinate
       inc  e
       ld   l,c                                   ; row position index
       ld   a,(hl)
       ld   (de),a                                ; Y pix coordinate
       ld   d,#>ds_sprite_ctrl                    ; sprite.ctrl[n].sY (bit 8 into MSB)
       inc  l
       ld   a,(hl)
       ld   (de),a
       jp   l_2413                                ; reset index to .b0 and continue

; 04: rckt_hit_hdlr
case_24B2:
       ld   l,e
       inc  e                                     ; .b1
       ld   a,(de)                                ; b8800_obj_status[ E ].obj_idx (explosion count, see f_1DB3)
; if count == 45 then finish
       cp   #0x45
       jr   z,l_24E6_i_am_at_45                   ; set by f_1DB3
       inc  a
       ld   (de),a                                ; 8800[odd]++ ... (40 -> 41, 42, 43, 44, 45 ) explosion changing
       dec  e
; if count == 44 then code = count + 3
       cp   #0x45
       jr   nz,l_24C2
       add  a,#3                                  ; end of explosion
l_24C2:
; if count < 44 then code = count
       cp   #0x44
       jr   nz,l_24E0

; sprite.posn[ L ].b0 -= 8
       ld   h,#>ds_sprite_posn                    ; .b0
       ex   af,af'                                ; stash this till after the l_24DA
       ld   a,(hl)
       sub  #8
       ld   (hl),a

       inc  l                                     ; .b1
       ld   a,(hl)
; subtract only in bits<7:0> then flip b9 on Cy
       sub  #8
       ld   (hl),a
       jr   nc,l_24DA
       ld   h,#>ds_sprite_ctrl                    ; killed boss that had the ship in the demo (not in game?)
       ld   a,(hl)
       xor  #0x01
       ld   (hl),a

l_24DA:
       dec  l                                     ; .b0
       ld   h,#>ds_sprite_ctrl
       ld   (hl),#0x0C
       ex   af,af'                                ; unstash A which is the count
l_24E0:
       ld   h,#>ds_sprite_code
       ld   (hl),a
       jp   l_2416

l_24E6_i_am_at_45:
       dec  e                                     ; restore pointer to .b0
       ld   h,#>b_9200_obj_collsn_notif           ; 1?
       ld   a,(hl)                                ; .b0 ... stash the code for l_24FD
; if 1 ... (not special sprite code)
       cp   #0x01                                 ; hit-status register at 9200[i]==$01, unless it shows small score indicator
       jr   nz,l_24FD
; ... then ...
       ld   h,#>ds_sprite_posn
       ld   (hl),#0
       ld   h,#>ds_sprite_ctrl
       ld   (hl),#0
       ld   h,#>b_8800
       ld   (hl),#0x80                            ; $80 is code for inactive sprite
       jp   l_2416

; Show the sprite with the small score text for shots that award bonus points:
;  Boss .. $35 (400)  $37 (800)  $3A (1600)  ... see d_1CFD
;  all 8 on bonus round are destroyed ($38 ... 1000 pts)----
;  all 3 bonus-bee destroyed  ($38 ... 1000 pts)
;  flying rogue ship (9202)..($38 .. 1000 pts)
l_24FD:
; code set at l_08B0 determines bonus text sprite code
       ld   h,#>ds_sprite_code
       ld   (hl),a                                ; sprite_cclr[L].code = obj_collsn_notif[L]
       cp   #0x37                                 ; if code < 37, goto 250E
       jr   c,l_250E
       ld   c,#0x0D                               ; color
       inc  l
       cp   #0x3A
       jr   c,l_250C                              ; if code < 3A, goto 250C
       inc  c                                     ; color++

l_250C:
       ld   (hl),c                                ; sprite_cclr[L].clr=c
       dec  l
l_250E:
       ld   h,#>ds_sprite_posn
       ld   c,#8
       cp   #0x3B
       jr   nc,l_251C                             ; if code >= 3B, goto 251C
       ld   c,#0
       ld   a,(hl)
       add  a,#8
       ld   (hl),a
l_251C:
       inc  l
       ld   a,(hl)
       add  a,#0x08
       ld   (hl),a
       ld   h,#>ds_sprite_ctrl
; mrw_sprite.cclr[ L ].b1 ^= (0 != AF.pair.b1);
       jr   nc,l_2529
       ld   a,(hl)
       xor  #0x01
       ld   (hl),a
l_2529:
       dec  l
       ld   (hl),c
       ld   h,#>b_8800
       ld   (hl),#5                               ; state 05 (showing score bitmap)
       inc  l
       ld   (hl),#0x13                            ; down counter for score bitmap
       jp   l_2416

; 05: shot boss, showing the score bitmap
case_2535:
; pointer to b8800_obj_status[ L ] from DE
; b8800_obj_status[ L ].obj_idx-- ... count for score bitmap
       ld   l,e
       inc  l
       ld   h,d
       dec  (hl)                                  ; down counter for score bitmap
       jp   nz,l_2416

       dec  l
       ld   (hl),#0x80                            ; disposition = inactive
       ld   h,#>ds_sprite_posn
       ld   (hl),#0
       ld   h,#>ds_sprite_ctrl
       ld   (hl),#0
; hmmm seems like we already done this ...
       ld   a,#0x80
       ld   (de),a
       jp   l_2416

; 3 or 6: terminate cylons or bombs that have gone past the sides or bottom of screen
case_254D:
       ld   h,#>ds_sprite_posn                    ; read directly from SFRs (not buffer RAM)
       ld   l,e                                   ; object offset
       set  7,l                                   ; +=$80 ... set pointer to read directly from the SFR
       ld   a,(hl)
       cp   #0xF4
; if (posn.x > $F4) ... skip check Y
       jr   nc,l_2571
       inc  l
       ld   c,(hl)                                ; sprite_posn.y<0:7>
       ld   h,#>ds_sprite_ctrl
       ld   a,(hl)                                ; sprite_posn.y<8>
       dec  l
       rrca                                       ; sprite_posn.y<8> into Cy
       ld   a,c
       rra                                        ; sprite_posn.y<8:1> in A
       cp   #22 >> 1                              ; 0x0B
       jr   c,l_2571
       cp   #330 >> 1                             ; 0xA5
       jr   nc,l_2571

; in range ... if not a bomb then go increment count
       ld   a,(de)                                ; b_8800[e].obj_status
       cp   #6
       jp   nz,l_2414_inc_active                  ; if not a bomb
       jp   l_2416                                ; it's a bomb

l_2571:
       res  7,l
       ld   a,(de)
       cp   #3                                    ; check if flying bug object
       jr   z,l_2582_kill_bug_q_slot              ; if bug object

l_2578_mk_obj_inactive:
       ld   a,#0x80
       ld   (de),a
       ld   h,#>ds_sprite_posn
       ld   (hl),#0
       jp   l_2416

l_2582_kill_bug_q_slot:
       inc  e
       ld   a,(de)                                ; b_8800[e].motion_q_idx
       dec  e
       add  a,#0x13
       ld   l,a
       ld   h,#>ds_bug_motion_que
       ld   (hl),#0                               ; e.g. "0x13(ix)"
       ld   l,e
       jp   l_2578_mk_obj_inactive

; 07: once for each orc as he is spawning (new stage)
case_2590:
       ld   a,#3
       ld   (de),a                                ; disposition = 3 ... from 7 (spawning)
       jp   l_2414_inc_active

l_2596_even_frame:
; if ( framect & 0x02 ) ...
       bit  1,a                                   ; frame_count
       ret  z
; ... update object_count
       ld   hl,#b_bugs_actv_cnt                   ; store active_objects_nbr and clear the object count
       ld   a,(hl)
       ld   (hl),#0
       inc  l
       ld   (hl),a                                ; b_bugs_actv_nbr = bugs_actv_cnt

       ret

;;=============================================================================
;; void gctl_stg_new_atk_wavs_init()
;;  Description:
;;   Setup the mob to do its evil work. Builds up 5 configuration tables at
;;   b_8920 which organizes the mob objects into the flying waves.
;;   These are formed into the attack wave queue structures by f_2916().
;;   The format is oriented toward having two flights of 4 creatures in each
;;   wave, so they are configured in pairs and I refer to as "lefty" and "righty"
;;   in each pair, although it is an arbitrary designation. In waves that fly
;;   in a single trailing formation, they are still treated as pairs, but the
;;   timing has to be managed to maintain uniform spacing. so there is
;;   an additional flag in the control data byte of the lefty that causes a
;;   delay before the entry of each righty.
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_25A2:
       ld   hl,#db_attk_wav_IDs
       ld   (pb_attk_wav_IDs),hl

; calculate pointer into data table:
;  set A as offset into table using stage count,
;  set DE as base pointer to data, either combat data or challenge stage data

; if past the highest stage ($17) we can only keep playing the last 4 levels
       ld   a,(ds_plyr_actv +_b_stgctr)           ; stage build caravan tables
       ld   c,a                                   ; stash it for is_challg_stg

; while ( A > $17 ) ...
l_25AC_while:
       cp   #0x17                                 ; 23 - ( 23 % 4 ) - 1 == 17 ... nbr of level indices
       jr   c,l_25B4
; ... do ...
       sub  #4
       jr   l_25AC_while

; if ( ! challenge stage ) ...
l_25B4:
       ld   b,a                                   ; adjusted level
       inc  a
       and  #0x03
       jr   z,l_25D3_is_challg_stg

; ... then ...
; HL = &idx_tbl[ rank * 17 ][ 0 ] ... select index table row, by rank
       ld   a,(b_mchn_cfg_rank)
       ld   l,#17
       call c_104E_mul_16_8                       ; L = rank * 17
       ld   a,l
       ld   hl,#d_combat_stg_dat_idx
       rst  0x10                                  ; HL += A

       ld   de,#d_combat_stg_dat                  ; base data ptr

; set offset into index table @row ... index = level - ( level % 4 ) - 1
       ld   a,b                                   ; adjusted level
       srl  b                                     ; 2 shifts and the sub ... %4
       srl  b
       sub  b
       dec  a
       jr   l_25E0_set_data_ptr

; base ptr for challenge stg ... only 1 index table to work with (no rank selection) e.g.
;  ptr = d_idx[ stage / 4  &  $07 ]
l_25D3_is_challg_stg:
       ld   hl,#d_challg_stg_data_idx
       ld   a,c                                   ; stage_counter
       srl  a
       srl  a
       and  #0x07                                 ; 8 elements in index table
       ld   de,#d_challg_stg_dat                  ; base data ptr


l_25E0_set_data_ptr:

; HL == stg_data_idx + row * 17 ... where row is rank
; A  == offset into stg data idx
; DE == &_stg_dat[0]

; p_data_tabl_row = &data_tbl[ data_row_offset ]
       rst  0x10                                  ; HL += A
       ld   a,(hl)                                ; A = data_row_offset = idx_tbl[ A ]
       ex   de,hl                                 ; HL = _stg_dat[0]
       rst  0x10                                  ; HL += A

; First, load bomb-control params from the 2 byte header (once per stage).

; stg_parm_0E[ 0 ] = _stg_dat[row][0]
       ld   a,(hl)
       inc  hl
       ld   (b_92E2 + 0x00),a                     ; _stg_dat[0]
; stg_parm_0F[ 1 ] = _stg_dat[row][1]
       ld   a,(hl)
       inc  hl
       ld   (b_92E2 + 0x01),a                     ; _stg_dat[1] ... loaded to 0x0f(ix)

; Initialize table of attack-wave structs with start token of 1st group
       ld   de,#ds_8920                           ; attk_waves[n] = $7E
       ld   a,#0x7E                               ; start token of each group
       ld   (de),a
       inc  e

; The 2-byte header is followed by a series of 8 structs of 3-bytes each
; which establish the parameters of each attack wave. The first of 3-bytes
; determines the presence of "transients" in the attack wave (and is
; the control variable for the following while() block)

l_25F5_while_not_end_stg_dat:

; while ( 0xFF != _stg_dat[n] )
       ld   a,(hl)                                ; A = _stg_dat[ 2 + 3 * n ]
       inc  hl                                    ; HL = &_stg_dat + 2 + 3 * n + 1
       cp   #0xFF                                 ; check for end token, stage data
       jp   z,l_2681_end_of_table

       ld   c,a                                   ; A = _stg_dat[ 2 + 3 * n ]
       push de                                    ; DE == &ds_8920[e]
       push hl                                    ; HL == &_stg_dat[ 2 + 3 * n + 1 ]

; memset(tmp_buf, $ff, 16)
       ld   hl,#ds_atk_wav_tmp_buf                ; memset(..., $ff, $10) ...tmp array for assembling object IDs for each wave
       ld   a,#0xFF
       ld   b,#0x10
       rst  0x18                                  ; memset((HL), A=fill, B=ct)

; if ( 0 != ( _stg_dat[ 2 + 3 * n + 0 ] ) & 0x0F ) ...
       ld   a,c                                   ; A = _stg_dat[ 2 + 3 * n + 0 ]
       and  #0x0F
       jr   z,l_2636

; ... then ...
       ld   b,a                                   ; sets the loop count ... after first bonus-round
       srl  a
       add  a,#4
       ld   e,a
l_2612:
j_2612:
       call c_1000                                ; randomizer
       ld   l,a
       ld   h,#0
       ld   a,e
       call c_divmod                              ; HL=HL/E
       bit  0,b
       jr   z,l_2622
       set  3,a
l_2622:
       ld   h,#>ds_atk_wav_tmp_buf                ; tmp_buf[ A ]
       ld   l,a
       ld   a,(hl)
       inc  a
       jr   nz,j_2612
       ld   a,b
       rlca
       rlc  c
       jr   nc,l_2631
       or   #0x40
l_2631:
       or   #0x38
       ld   (hl),a
       djnz l_2612


; Insert the 8 non-transient bugs into the temporary attack wave (object IDs of
; bugs that have a final home positions).... $FFs remain in unused slots, e.g.
;   0x58,0x5A,0x5C,0x5E,0xFF,0xFF,0xFF,0xFF,0x28,0x2A,0x2C,0x2E,0xFF,0xFF,0xFF,0xFF,

l_2636:
       ld   hl,#ds_atk_wav_tmp_buf
       ld   de,(pb_attk_wav_IDs)
       ld   b,#8

l_263F_while_b:
j_263F_skip_until_ff:
       ld   a,(hl)
       cp   #0xFF                                 ; check for unused position in tmp buffer
       jr   z,l_2647_is_ff
       inc  hl                                    ; skip if not $ff
       jr   j_263F_skip_until_ff

l_2647_is_ff:
       ld   a,(de)                                ; attk_wav_IDs[e]
       ld   (hl),a                                ; atk_wav_tmp_buf[l] = attk_wav_IDs[e]
       inc  de
       inc  hl
       ld   a,b                                   ; loop count
       cp   #5
       jr   nz,l_2652                             ; if ct > 4 ... skip to atk_wav_tmp_buf[ l + 8 ]
       ld   l,#8                                  ; alignment to $0100 boundary!
l_2652:
       djnz l_263F_while_b

       ld   (pb_attk_wav_IDs),de                  ; &db_attk_wav_IDs[ 8 * n ]

       pop  hl                                    ; HL == &_stg_dat[ 2 + 3 * n + 1 ]
       pop  de                                    ; DE == &ds_8920[ $11 * n ]
       ld   b,(hl)
       inc  hl
       ld   c,(hl)                                ; HL == &_stg_dat[ 2 + 3 * n + 2 ]
       inc  hl
       push hl                                    ; HL == &_stg_dat[ 2 + 3 * n + 0 ] ... next n

; tmp buffer looks like this with transients inserted at 'x' ...  UUUUxxxxVVVVxxxx
; where U and V are IDs loaded from db_attk_wav_IDs (UUUUVVVV)
; Loop X times to copy each pair of "lefty" and "righty" object IDs i.e. " bb uu cc vv"
; ... where B and C are used to select the bug motion depending whether he is a "lefty" or a "righty".
       ld   hl,#ds_atk_wav_tmp_buf
l_2662_form_pair:
       ld   a,b                                   ; bb
       ld   (de),a
; read_until_ff
       ld   a,(hl)                                ; UU
       cp   #0xFF
       jr   z,l_2679_next_wave

       inc  e
       ld   (de),a
       inc  e
       ld   a,c                                   ; cc
       ld   (de),a
       inc  e
       set  3,l                                   ; HL += $08
       ld   a,(hl)                                ; VV
       ld   (de),a
       inc  e
       res  3,l                                   ; HL -= $08
       inc  hl
       jr   l_2662_form_pair

l_2679_next_wave:
       ld   a,#0x7E                               ; start token of each group (will overwrite with 7f if finished)
       ld   (de),a
       inc  e                                     ; DE = &ds_8920[ $11 * n + 1 ]
       pop  hl                                    ; &_stg_dat[ 2 + 3 * n + 0 ]
       jp   l_25F5_while_not_end_stg_dat


l_2681_end_of_table:
; pointer is already advanced, so decrement it so we overwrite the 7E with 7F
       dec  e

; check capture-mode and two-ship status
       ld   a,(ds_plyr_actv +_b_bmbr_boss_cflag)  ; 1 if capture-mode is active
       ld   b,a
       ld   a,(ds_plyr_actv +_b_2ship)
       dec  a
       and  b
       jr   z,l_26A4_done
; !capture-mode and !two-ship-status... we have a rogue fighter in the mob.
       ld   a,(ds_plyr_actv +_b_not_chllg_stg)    ; ==(stg_ctr+1)%4 ...i.e. 0 if challenge stage
       and  a
       jr   z,l_26A4_done                         ; doesn't matter on a challenge stage.

; HL = DE-4 ... e.g. 8975-4==8971
       ld   h,d
       ld   a,e
       sub  #4
       ld   l,a

       ld   a,(hl)
       ld   (de),a
       inc  e                                     ; e.g. DE = 8976
       ld   a,#4
       ld   (de),a
       inc  e
       ld   a,#0x80 + 0x07
       ld   (ds_sprite_code + 0x04),a             ; = $80 + $07

l_26A4_done:
       ld   a,#0x7F                               ; end token marker
       ld   (de),a                                ; ($8920 + $11*5)

       ret


;;=============================================================================
;; data for c_25A2
;;-----------------------------------------------------------------------------

; Selection indices for stage data ... pre-computed multiples of 18 for row offsets.

; combat levels, e.g. 1,2,5,6,7,9 etc.
; 4 sets... 1 for each rank "B", "C", "D", or "A"
; In each set, one element per stage, i.e. 17 distinct stage configurations (see l_25AC)
; Indices are pre-multiplied (multiples of 0x12, i.e. row length of combat__stg_data)

d_combat_stg_dat_idx:
  .db 0x00,0x12,0x24,0x36,0x00,0x48,0x6C,0x5A,0x48,0x6C,0x00,0x7E,0xA2,0x90,0xB4,0xD8,0xC6
  .db 0x00,0x12,0x48,0x6C,0x5A,0x7E,0xA2,0x00,0x7E,0xD8,0xC6,0xB4,0xD8,0xC6,0xB4,0xD8,0xC6
  .db 0x00,0x12,0x7E,0xA2,0x90,0x7E,0xD8,0xC6,0xB4,0xD8,0xC6,0xB4,0xD8,0xC6,0xB4,0xD8,0xC6
  .db 0x00,0x12,0x48,0x36,0x24,0x48,0x6C,0x00,0x7E,0xA2,0x90,0xB4,0xD8,0x00,0xB4,0xD8,0xC6

; challenge stage e.g. 3,8,10 etc. 8 unique challenge stages.
d_challg_stg_data_idx:
  .db 0x00,0x12,0x24,0x36,0x48,0x5A,0x6C,0x7E


; Stage data: each row is 1 level ... 5 waves of bug formations per level

; 2 byte header: ?
; one triplet of bytes for each of the 5 waves:
; byte 0:
;   c_25A2, controls loading of transients into attack wave table
; byte 1 & 2
;   bit 7     byte-2 only ... if clear, 2nd bug of pair is delayed for trailing formation
;   bit 6     if set selects second set of 3-bytes in db_2A6C[]
;   bits 0:5  index of word in LUT at db_2A3C ( 0x18 entries)
;   bit 0     also, if set,0e(ix) = 0x44 ... finalize_object

; combat stage data
d_combat_stg_dat:
  .db 0x14,0x00, 0x00,0x00,0x40+0x80, 0x00,0x01,0x01+0x00, 0x00,0x41,0x41+0x00, 0x00,0x40,0x40+0x00, 0x00,0x00,0x00+0x00, 0xFF
  .db 0x14,0x01, 0x00,0x42,0x02+0x80, 0x00,0x03,0x05+0x80, 0x00,0x43,0x45+0x80, 0x00,0x42,0x44+0x80, 0x00,0x02,0x04+0x80, 0xFF
  .db 0x14,0x01, 0x82,0x00,0x40+0x80, 0x00,0x01,0x01+0x00, 0x00,0x41,0x41+0x00, 0x02,0x40,0x40+0x00, 0x02,0x00,0x00+0x00, 0xFF
  .db 0x14,0x01, 0x82,0x02,0x42+0x80, 0x00,0x03,0x05+0x80, 0x00,0x43,0x45+0x80, 0x02,0x42,0x44+0x80, 0x02,0x02,0x04+0x80, 0xFF
  .db 0x14,0x01, 0x82,0x00,0x40+0x80, 0x00,0x01,0x41+0x80, 0x00,0x41,0x01+0x80, 0x02,0x40,0x00+0x80, 0x02,0x40,0x00+0x80, 0xFF
  .db 0x14,0x01, 0x82,0x00,0x40+0x80, 0x42,0x01,0x01+0x00, 0xF2,0x41,0x41+0x00, 0x02,0x40,0x40+0x00, 0x02,0x00,0x00+0x00, 0xFF
  .db 0x14,0x01, 0xA4,0x02,0x42+0x80, 0x52,0x03,0x05+0x80, 0xF2,0x43,0x45+0x80, 0x02,0x42,0x44+0x80, 0x02,0x02,0x04+0x80, 0xFF
  .db 0x14,0x01, 0x82,0x00,0x40+0x80, 0x52,0x01,0x41+0x80, 0xF2,0x41,0x01+0x80, 0x02,0x40,0x00+0x80, 0x02,0x40,0x00+0x80, 0xFF
  .db 0x14,0x01, 0xA4,0x00,0x40+0x80, 0x42,0x01,0x01+0x00, 0xF4,0x41,0x41+0x00, 0x04,0x40,0x40+0x00, 0x04,0x00,0x00+0x00, 0xFF
  .db 0x14,0x01, 0xA4,0x02,0x42+0x80, 0x52,0x03,0x05+0x80, 0xF4,0x43,0x45+0x80, 0x04,0x42,0x44+0x80, 0x04,0x02,0x04+0x80, 0xFF
  .db 0x14,0x03, 0xA4,0x00,0x40+0x80, 0x54,0x01,0x41+0x80, 0xF4,0x41,0x01+0x80, 0x04,0x40,0x00+0x80, 0x04,0x40,0x00+0x80, 0xFF
  .db 0x14,0x03, 0xA4,0x00,0x40+0x80, 0x54,0x01,0x01+0x00, 0xF4,0x41,0x41+0x00, 0x04,0x40,0x40+0x00, 0x04,0x00,0x00+0x00, 0xFF
  .db 0x14,0x03, 0xA4,0x02,0x42+0x80, 0x54,0x03,0x05+0x80, 0xF4,0x43,0x45+0x80, 0x04,0x42,0x44+0x80, 0x04,0x02,0x04+0x80, 0xFF

; challenge stage data
d_challg_stg_dat:
  .db 0xFF,0x00, 0x00,0x06,0x46+0x80, 0x00,0x07,0x07+0x00, 0x00,0x47,0x47+0x00, 0x00,0x46,0x46+0x00, 0x00,0x06,0x06+0x00, 0xFF
  .db 0xFF,0x00, 0x00,0x08,0x48+0x80, 0x00,0x09,0x49+0x80, 0x00,0x09,0x49+0x80, 0x00,0x48,0x48+0x00, 0x00,0x08,0x08+0x00, 0xFF
  .db 0xFF,0x00, 0x00,0x0A,0x4A+0x00, 0x00,0x0B,0x4B+0x80, 0x00,0x0B,0x4B+0x80, 0x00,0x0A,0x4A+0x00, 0x00,0x16,0x56+0x00, 0xFF
  .db 0xFF,0x00, 0x00,0x0C,0x4C+0x80, 0x00,0x0D,0x0D+0x00, 0x00,0x4D,0x4D+0x00, 0x00,0x0C,0x4C+0x80, 0x00,0x17,0x57+0x80, 0xFF
  .db 0xFF,0x00, 0x00,0x0E,0x0E+0x00, 0x00,0x0F,0x0F+0x00, 0x00,0x4F,0x4F+0x00, 0x00,0x0E,0x0E+0x00, 0x00,0x4E,0x4E+0x00, 0xFF
  .db 0xFF,0x00, 0x00,0x10,0x10+0x00, 0x00,0x11,0x51+0x80, 0x00,0x11,0x51+0x80, 0x00,0x50,0x50+0x00, 0x00,0x10,0x10+0x00, 0xFF
  .db 0xFF,0x00, 0x00,0x12,0x12+0x00, 0x00,0x13,0x13+0x00, 0x00,0x53,0x53+0x00, 0x00,0x52,0x52+0x00, 0x00,0x12,0x12+0x00, 0xFF
  .db 0xFF,0x00, 0x00,0x14,0x54+0x80, 0x00,0x15,0x15+0x00, 0x00,0x55,0x55+0x00, 0x00,0x14,0x54+0x80, 0x00,0x14,0x54+0x80, 0xFF


; This is a table of object IDs which organizes the mob into the series of 5 waves.
db_attk_wav_IDs:
  .db 0x58,0x5A,0x5C,0x5E,0x28,0x2A,0x2C,0x2E
  .db 0x30,0x34,0x36,0x32,0x50,0x52,0x54,0x56
  .db 0x42,0x46,0x40,0x44,0x4A,0x4E,0x48,0x4C
  .db 0x1A,0x1E,0x20,0x24,0x22,0x26,0x18,0x1C
  .db 0x08,0x0C,0x12,0x16,0x10,0x14,0x0A,0x0E


;;=============================================================================
;; c_2896()
;;  Description:
;;   stg_init_env
;;   Called at beginning of each stage, including challenge stages and demo.
;;   Initializes mrw_sprite[n].cclr.b0 for 3 sets of creatures. Color code is
;;   packed into b<0:2>, and bomb-drop parameter packed into b<7>
;;   Load attributes for challenge stage hit-8 bonus.
;;
;;   Default sprite code configuration:
;;
;;    00 00 00 00 00 00 00 00 18 00 18 00 18 00 18 00
;;    18 00 18 00 18 00 18 00 18 00 18 00 18 00 18 00
;;    18 00 18 00 18 00 18 00 18 00 18 00 18 00 18 00
;;    08 00 08 00 08 00 08 00 00 00 00 00 00 00 00 00
;;    10 00 10 00 10 00 10 00 10 00 10 00 10 00 10 00
;;    10 00 10 00 10 00 10 00 10 00 10 00 10 00 10 00
;;    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
;;    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
;;
;;   Called before c_25A2.
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
c_2896:

; once per stage, set the player's private pointer to attack wave object setup tables
       ld   hl,#ds_8920                           ; -> plyr_actv.p_atkwav_tbl

       ld   (ds_plyr_actv +_p_atkwav_tbl),hl      ; = &ds_8920[0] ... initialize it

; pointer to table of packed bits set in b<7>  ... see code leading up to _29AE
       ld   iy,#d_2908

; if ( 0 == not_chllng_stg ) ...
       ld   a,(ds_plyr_actv +_b_not_chllg_stg)    ; ==(stg_ctr+1)%4 ...i.e. 0 if challenge stage
       and  a
       jr   nz,l_28CD_not_challenge_stage
; ...
       ld   a,(ds_plyr_actv +_b_stgctr)           ; stage init sprite codes
       rrca
       rrca
       ld   c,a                                   ; table index (below)
       rrca
       ld   b,a
       and  #0xE0 >> 3                            ; 0x1C ... test if stage >= 32
       ld   a,b                                   ; .stage_ctr >> 3
       jr   z,l_28B5
       ld   a,#3                                  ; select index 3 if stage >= 32
l_28B5:
       and  #0x03                                 ; 4 entries in data (every 8 challenge stages the selection index is stepped)
       ld   hl,#d_stage_chllg_rnd_attrib
       rst  0x08                                  ; HL += 2A
       ld   de,#ds2_stg_chllg_rnd_attrib          ; challenge bonus attributes (2 bytes from 2900[])
       ld   a,c
       ldi                                        ; "LD (DE),(HL)", DE++, HL++, BC--
       ldi

       ld   hl,#d_290E                            ; 8 entries
       and  #0x07
       rst  0x10                                  ; HL += A
       ld   d,(hl)
       ld   e,d
       jr   l_28D0

l_28CD_not_challenge_stage:
 ; Initialization values are base-code + 2 bits of color table.
 ; 0x1B = 0x18 + 0x03
 ; 0x08 = 0x08 + 0x00
 ; 0x12 = 0x10 + 0x02
 ; left shift codes by 1 bit because the flag (bit-7) will be rra'd from Cy
 ; Results in 3-bits of color (multiple of 2)
       ld   de,#(0x18 + 3) * 2 * 0x0100  +  (0x10 + 2) * 2

l_28D0:
       ld   hl,#ds_sprite_code + 0x08             ; offsetof first bee in the group

       ld  ixl,#1                                 ; start count for bit shifting

       ld   b,#20                                 ; 20 bees ... $08-$2E
       ld   ixh,d                                 ; D == moth == $18 | $03
       call c_28E9

       ld   b,#8                                  ; 8 bosses and bonus-bees ... $30-$3E
       ld   ixh,#(0x08 + 0x0) * 2                 ; code      == $08 | $00
       call c_28E9

       ld   b,#16                                 ; 16 moths ... $40-$5E
       ld   ixh,e                                 ; E == bee  == $10 | $02
       ; call c_28E9

;;=============================================================================
;; c_28E9()
;;  Description:
;;    Initialize a class of creatures.
;; IN:
;;  B == number of creatures in this class
;;  HL == sprite_code_buf[ $08 + ? ]
;;  IY == &d_2908[0], etc.
;;  IXL == persistent count of bits shifted off of IY[ n++ ]
;;  IXH == $36 or $10 or $24
;; OUT:
;;  ...
;; First time, IXL==1, forcing C to be loaded.
;; After that, reload C every 8 times.
;; Each time, C is RL'd into Cy, and Cy RR'd into A.
;;-----------------------------------------------------------------------------
c_28E9:
l_28E9:
; if ( --IXL == 0 )
       dec  ixl
       jr   nz,l_28F5
; then ...  C = IY[ n++ ], IXL = 8
       ld   c,0x00(iy)
       inc  iy
       ld   ixl,#8

l_28F5:
       rlc  c
       ld   a,ixh                                 ; base sprite-code parameter
       rra
       ld   (hl),a
       inc  l
       inc  l
       djnz l_28E9

       ret


;;=============================================================================
;; setup challenge stage bonus attributes at l_28B5 (b_9280 + 0x04)
;; .b0: add to bug_collsn[$0F]
;; .b1: obj_collsn_notif[] ... hit-flag + sprite-code for score tile
;; (base-score multiples are * 10 thanks to d_scoreman_inc_lut[0])
d_stage_chllg_rnd_attrib:
       .db 10, 0x80 + 0x38
       .db 15, 0x80 + 0x39
       .db 20, 0x80 + 0x3C
       .db 30, 0x80 + 0x3D

d_2908:
       .db 0xA5,0x5A,0xA9,0x0F,0x0A,0x50 ; 44-bits used
d_290E:
       .db 0x36,0x24,0xD4,0xBA,0xE4,0xCC,0xA8,0xF4

;;=============================================================================
;; f_2916()
;;  Description:
;;   Inserts creature objects from the attack wave table into the movement
;;   queue. Essentially, it launches the attack formations swarming into the
;;   screen. The table of attack wave structures is built in c_25A2.
;;   Each struct starts with $7E, and the end of table marker is $7F.
;;   This task will be enabled by stg_init_env... after the
;;   creature classes and formation tables are initialized.
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
f_2916:

; check for end of table
; if ( 7f == current_token ) goto complete
       ld   hl,(ds_plyr_actv +_p_atkwav_tbl)      ; &ds_8920[n]
       ld   a,(hl)
       cp   #0x7F
       jp   z,l_2A29_attack_waves_complete

; check for start of table structure
; if ( 7e == token ) then .... else .... goto _next_pair
       cp   #0x7E
       jr   nz,l_2953_next_pair

; if ( ! _attack_wave_enable ) return
       ld   a,(ds_plyr_actv +_b_atk_wv_enbl)      ; 0 if restarting the stage (respawning player ship)
       and  a
       ret  z

; if ( 0 != bugs_flying_nbr ) goto _set_tmr0
       ld   a,(b_bugs_flying_nbr)
       and  a
       jr   nz,l_294D_set_tmr0

; if ( 0 == not_challenge_stg ) ...
       ld   a,(ds_plyr_actv +_b_not_chllg_stg)    ; ==(stg_ctr+1)%4 ...i.e. 0 if challenge stage
       ld   b,a                                   ; this does nothing ;)
       and  a
       jr   nz,l_2944_attack_wave_start
; ...
;  if ( 1 == game_tmrs[0] ) ..
       ld   a,(ds4_game_tmrs + 0)                 ; if tmr==1 ( on stage 3 ..challenge stage)
       cp   #1
       jr   nz,l_2942_chk_tmr0
;  ..
       ld   a,#8
       ld   (w_bug_flying_hit_cnt),a              ; 8 ... count down each flying bug hit
       ret
;  ..
; if ( 0 != game_tmrs[0] ) return
l_2942_chk_tmr0:
       and  a                                     ; game_tmr0
       ret  nz
; ...

; Finally... sending out next wave of creatures. We are on start token 7E so do nothing on this time step.
l_2944_attack_wave_start:
       inc  hl
       ld   (ds_plyr_actv +_p_atkwav_tbl),hl      ; +=1 (first element of byte-pair following the 7e)
       ld   hl,#ds_plyr_actv +_b_attkwv_ctr       ; +=1
       inc  (hl)
       ret

l_294D_set_tmr0:
       ld   a,#2
       ld   (ds4_game_tmrs + 0),a                 ; 2
       ret
; ....

; finally, next token-pair !
l_2953_next_pair:
       ld   c,a                                   ; *.p_atkwav_tbl ... stash for later
; bit-7 is set if this toaster is a wing-man or a split waves, and therefore no delay,
; otherwise it is clear for trailing formation i.e. delay before launching.
; if ( 0 == *.p_atkwav_tbl & 0x80 ) ...
       bit  7,a
       jr   nz,l_295E
; then ...
       ld   a,(ds3_92A0_frame_cts + 0)
       and  #0x07
       ret  nz

; ready to stick another bug in the flying queue
l_295E:
; make byte offset into lut at db_2A3C  (_finalize_object) ... also we're done with bit-7
       sla  c

; find a slot in the queue
       ld   b,#0x0C                               ; number of structures in array
       ld   de,#0x0014                            ; size of 1 data structure
       ld   ix,#ds_bug_motion_que
l_2969_while:
       bit  0,0x13(ix)
       jr   z,l_2974_got_slot
       add  ix,de                                 ; advance pointer
       djnz l_2969_while

       ret                                        ; can't find a slot... bummer

; each time is another bug of a new wave formation getting ready to appear
l_2974_got_slot:
       inc  hl
       ld   a,(hl)                                ; atkwav_tbl[n].pair.h ... object ID/offset, e.g. 58
       ld   b,a                                   ; stash it

; if object >= $78  &&  object < $80 ) ...
       and  #0x78
       cp   #0x78
       ld   a,b
       jr   nz,l_2980
; ...  then ...
       res  6,a                                   ; what object is > $78?
l_2980:
       ld   0x10(ix),a                            ; object index

       inc  hl
       ld   (ds_plyr_actv +_p_atkwav_tbl),hl      ; advance to next token-pair e.g. HL:=8923

       ld   h,#>b_8800
       ld   l,a
       ld   (hl),#7                               ; 8800[L].l ... disposition = "spawning" ... i.e. case_2590

; store the slot index (offset) for this object
       inc  l
       ld   e,ixl
       ld   (hl),e                                ; 8800[L].h ... offset of slot (n*$14)

       ld   h,#>ds_sprite_posn

; if ( object >= $38 && object < $40 ) then goto _setup_transients
       and  #0x38
       cp   #0x38
       jr   z,l_29B3_setup_transients
; else ...
; Init routine c_2896 has populated the sprite code buffer such that each even
; byte consists of the "primary" code (multiple of 8), AND'd with the color.
       dec  l                                     ; e.g. HL=9358
       ld   h,#>ds_sprite_code                    ; sprite[L].code.b0 &= 0x78
       ld   a,(hl)
       ld   d,a                                   ; stash it
       and  #0x78                                 ; base sprite code for this object (multiple of 8)
       ld   (hl),a                                ; sprite[n].cclr.b0
       inc  l                                     ; .b1
       ld   a,d
       and  #0x07                                 ; color table in bits <0:2>
       bit  7,d
       ld   (hl),a                                ; sprite[n].cclr.b1

; if ( ! code_bit_7 )
       ld   a,#0
       jr   z,l_29AE
; else
       ld   a,(b_92E2 + 0x01)                     ; to 0x0F(ix) ... _stg_dat[1] ... bomb drop enable flags

l_29AE:
       ld   0x0F(ix),a                            ; 0, or b_92E2[1] ... bomb drop enable flags
       jr   l_29D1_finalize_object_setup

; handle the additional "transient" buggers that fly-in but don't join ... Stage 4 or higher.
l_29B3_setup_transients:
       ld   de,#0x02 * 256 + 0x0010               ; redmoth, color 02, 270-deg rotation
       bit  6,b
       jr   nz,l_29C7
       ld   de,#0x03 * 256 + 0x0018               ; yellowbee, color 03, 270-deg rotation
       ld   a,(ds_plyr_actv +_b_attkwv_ctr)
       cp   #0x02
       jr   nz,l_29C7
       ld   de,#0x0000 + 0x0008                   ; boss, color 00, 270-deg rotation (>=stage 9)
l_29C7:
       ld   h,#>ds_sprite_code
       ld   (hl),d                                ; color, e.g. 8B3B=$03
       dec  l
       ld   (hl),e                                ; color, e.g. 8B3A=$18
       inc  l
       ld   0x0F(ix),#0                           ; setup transients ... bomb drop enable flags

l_29D1_finalize_object_setup:
       ld   d,c                                   ; first byte of token-pair, left-shifted 1 (byte-1 of _stg_dat triplet)
       res  7,c
       ld   b,#8                                  ; critters that enter at the top
; if ( C & 0x02 ) ...
       bit  1,c
       jr   z,l_29DC
; then ...
       ld   b,#0x44                               ; critters that enter on the sides
l_29DC:
       ld   0x0E(ix),b                            ; $08 or $44 ... bomb drop counter

; ds_bug_move_queue[IX].b08 = db_2A3C[C] ... LSB of data pointer
       ld   b,#0
       ld   hl,#db_2A3C
       add  hl,bc                                 ; only C is significant
       ld   a,(hl)
       inc  hl
       ld   0x08(ix),a                            ; lo-byte of pointer e.g. cpu-sub1:001D

; get upper nibble of word at db_2A3C[w] (bits 5:7 will be masked by 0x0E below)
; rld (hl): Performs a 4-bit leftward rotation of the 12-bit number whose
; 4 most signigifcant bits are the 4 least significant bits of A
       xor  a
       rld
       ld   b,a

; ds_bug_move_queue[IX].b09  = db_2A3C[C + 1] & 0x1F ... MSB of data pointer
       ld   a,(hl)
       and  #0x1F
       ld   0x09(ix),a                            ; hi-byte of pointer e.g. cpu-sub1:001D

; ... get upper 4-bits of word at db_2A3C[w] which were rld'd into A: these
; are $2 thru $A even, and this is multiplied by 3 by the expression A*2+A
       ld   a,b
       and  #0x0E                                 ; bits 5:7 of db_2A3C[].b1
       ld   b,a
       rlca
       add  a,b
       ld   hl,#db_2A6C
       rst  0x10                                  ; HL += A

; D is b0 of byte-pair (left shifted 1, so in _stg_dat it is 0x40)
; if ( D & 0x80 )
       bit  7,d                                   ; 29FE
       jr   z,l_2A05
; ... then ... HL += 3 ... selects the second set of 3 bytes
       inc  hl
       inc  hl
       inc  hl

l_2A05:
       ld   a,(hl)
       inc  hl
       ld   0x01(ix),a                            ; db_2A6C[L].b0
       ld   a,(hl)
       inc  hl
       ld   0x03(ix),a                            ; db_2A6C[L].b1
       ld   a,(hl)
       inc  hl
       ld   0x05(ix),a                            ; db_2A6C[L].b2

       xor  a
       ld   0x00(ix),a                            ; 0
       ld   0x02(ix),a                            ; 0
       ld   0x04(ix),a                            ; 0
       inc  a
       ld   0x0D(ix),a                            ; 1 ... expiration counter
       or   d                                     ; 1st byte of current byte-pair (left shifted 1, so in _stg_dat it is 0x40)
       and  #0x81                                 ; .b13<7> negates rotation angle
       ld   0x13(ix),a                            ; A &= $81 ... .b13<0> makes object slot active
       ret

; all 8 of the last wave of bees are on screen now... waiting for them to get in position.
; if (nbr_flying bugs > 0 ) return
l_2A29_attack_waves_complete:
       ld   a,(b_bugs_flying_nbr)
       and  a
       ret  nz

; the last one has found its position in the collective.
       ld   (ds_cpu0_task_actv + 0x08),a          ; 0  (f_2916 ... end of attack waves)
       inc  a
       ld   (ds_cpu0_task_actv + 0x04),a          ; 1  (f_1A80 ... bonus-bee manager)
       ld   (ds_cpu0_task_actv + 0x10),a          ; 1  (f_1B65 ... manage bomber attack )
       ld   (ds_plyr_actv +_b_nestlr_inh),a       ; 1  ... inhibit nest left/right movement

       ret


;;=============================================================================

; bits 0:12  - pointer to data tables for flying pattern control.
; bits 13:15 - selection index into lut 2A6C.
db_2A3C:
  .dw db_flv_001d + 0x0000, db_flv_0067 + 0x2000, db_flv_009f + 0x4000, db_flv_00d4 + 0x2000
  .dw db_flv_017b + 0x0000, db_flv_01b0 + 0x6000, db_flv_01e8 + 0x0000, db_flv_01f5 + 0x2000
  .dw db_flv_020b + 0x0000, db_flv_021b + 0x2000, db_flv_022b + 0x8000, db_flv_0241 + 0x2000
  .dw db_flv_025d + 0x8000, db_flv_0279 + 0x2000, db_flv_029e + 0x0000, db_flv_02ba + 0x2000
  .dw db_flv_02d9 + 0x0000, db_flv_02fb + 0x2000, db_flv_031d + 0x0000, db_flv_0333 + 0x2000
  .dw db_flv_0fda + 0x0000, db_flv_0ff0 + 0x2000, db_flv_022b + 0xA000, db_flv_025d + 0xA000

; bits 13:15 from above provide bits<1:3> of the index
; bit-6 of _stg_dat provide bits<1> of the index (second set of 3-bytes in each pair)
db_2A6C:
; (ix)0x01 (ix)0x03 (ix)0x05
       .db 0x9B,0x34,0x03 ; 0
       .db 0x9B,0x44,0x03
       .db 0x23,0x00,0x00 ; 2
       .db 0x23,0x78,0x02
       .db 0x9B,0x2C,0x03 ; 4
       .db 0x9B,0x4C,0x03
       .db 0x2B,0x00,0x00 ; 6
       .db 0x2B,0x78,0x02
       .db 0x9B,0x34,0x03 ; 8
       .db 0x9B,0x34,0x03
       .db 0x9B,0x44,0x03 ; A
       .db 0x9B,0x44,0x03


;;=============================================================================
;; f_2A90()
;;  Description:
;;   left/right movement of collective while attack waves coming in at
;;   start of round.
;; IN:
;;  ...
;; OUT:
;;  ...
;;-----------------------------------------------------------------------------
f_2A90:

;  if ( frame_cnt % 4 != 0 ) return
       ld   a,(ds3_92A0_frame_cts + 0)
       dec  a                                     ; why -1 ?
       and  #0x03
       ret  nz

; check for exit condition
;  if  ! ( num_bugs != 0  ||  f_2916_active )  then ...
       ld   a,(b_bugs_actv_nbr)
       ld   b,a
       ld   a,(ds_cpu0_task_actv + 0x08)         ; f_2916 supervises attack waves
       or   b
       jr   z,l_2AE9_done

; if ( 0 == nest_dir_lr ) then C = 1,  else C = -1
       ld   a,(ds_9200_glbls + 0x0F)              ; nest direction... 1==left, 0==right
       and  a
       ld   c,#1
       jr   z,l_2AAB
       dec  c
       dec  c                                     ; C = -1

; initialize index and loop counter, update the table
l_2AAB:
       ld   l,#0                                  ; index into table
       ld   b,#10                                 ; nbr of column positions
l_2AAF:
; increment the relative position
       ld   h,#>ds_hpos_loc_offs                  ; even-bytes, relative offset, all 0's, then all 1's, etc. etc.
       ld   a,(hl)
       add  a,c                                   ; +1 or -1
       ld   (hl),a
; increment sprite position LSB
       ld   h,#>ds_hpos_spcoords
       ld   a,(hl)
       add  a,c
       ld   (hl),a
; HL+=2
       inc  l
       inc  l
       djnz l_2AAF

; if ( 0 == nestlr_inh  ||  0 != obj_pos_rel[0] )  ...
       ld   a,(ds_plyr_actv +_b_nestlr_inh)
       and  a
       ld   a,(ds_hpos_loc_offs + 0x00)           ; check for 0 i.e. returned to center
       jr   z,l_2AC9
       and  a
       jr   z,l_2ADA_done
l_2AC9:
; ... then ...
; if ( 32 == obj_pos_rel[0] )  then nest_dir_lr = 1
       cp   #32
       jr   nz,l_2AD3

       ld   a,#1
       ld   (ds_9200_glbls + 0x0F),a              ; 1 ... nest direction... right limit reached
       ret

l_2AD3:
; if ( -32 == obj_pos_rel[0] ) then nest_dir_lr = 0
       sub  #0xE0                                 ; -$20
       ret  nz

       ld   (ds_9200_glbls + 0x0F),a              ; 0 ... nest direction... left limit reached
       ret

; the formation is complete... diving attacks shall commence
l_2ADA_done:
       xor  a
       ld   (ds_9200_glbls + 0x0F),a              ; 0 ... nest direction
       ld   (ds_cpu0_task_actv + 0x0A),a          ; 0 ... disable this task (f_2A90)
       inc  a
       ld   (b_9AA0 + 0x00),a                     ; 1 ... sound-fx count/enable register, pulsing formation sound effect
       ld   (ds_cpu0_task_actv + 0x09),a          ; 1 ... enable f_1DE6 ... collective bug movement
       ret

; last bug of challenge is gone or killed
l_2AE9_done:
       ld   (ds_cpu0_task_actv + 0x0A),a          ; 0 ... disable this task (f_2A90)
       ret


;;=============================================================================
;;
;; Place 2C00 in its own segment so the pad is not needed.
;;
;l_2AED:
;       .ds 0x0113                                 ; pad

;;=============================================================================

