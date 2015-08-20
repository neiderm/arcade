;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Hardware defintiions for Galaga (1981 NAMCO) arcade board.
; From MAME source code.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; SFRs (special function registers) are mapped as memory locations but are 
; treated here as simple equates rather than as variables.

; 6805      sound voice 1 waveform (nibble)
; 680a      sound voice 2 waveform (nibble)
; 680f      sound voice 3 waveform (nibble)

; There are 5-nibbles for frequency, but only voice 0 actually has a register to set the lowest frequency nibble.
; 6810-6814 sound voice 1 frequency (nibble)
; 6815      sound voice 1 volume (nibble)
; 6816-6819 sound voice 2 frequency (nibble)
; 681a      sound voice 2 volume (nibble)
; 681b-681e sound voice 3 frequency (nibble)
; 681f      sound voice 3 volume (nibble)

; SFR locations
_sfr_dsw1 = $$6800
_sfr_dsw2 = $$6801
_sfr_dsw3 = $$6802
_sfr_dsw4 = $$6803
_sfr_dsw5 = $$6804
_sfr_dsw6 = $$6805  ; TODO: how can this be on same address as sound voice 0 wave?
_sfr_dsw7 = $$6806
_sfr_dsw8 = $$6807

_sfr_6805 = $$6805  ; sound voice 0 wave
_sfr_680A = $$680A  ; sound voice 1 wave
_sfr_680F = $$680F  ; sound voice 2 wave
_sfr_6810 = $$6810  ; $10 bytes, CPU-sub2, frequency & volume SFRs
          ; 6811-6814 f0 ... 9A61
          ; 6815      v0 ... 9A65
          ; 6816-6819 f1 ... 9A66
          ; 681a      v1 ... 9A6A
          ; 681b-681e f2 ... 9A6B
          ; 681f      v2 ... 9A6F

_sfr_6820 = $$6820  ; maincpu IRQ acknowledge/enable
_sfr_6821 = $$6821  ; CPU-sub1 IRQ acknowledge/enable)
_sfr_6822 = $$6822  ; CPU-sub2 nmi acknowledge/enable
_sfr_6823 = $$6823  ; 0:halt 1:enable CPU-sub1 and CPU-sub2

_sfr_watchdog = $$6830

m_tile_ram           = $$8000
m_color_ram          = $$8400

; base address of sprite register banks could argueably belong in here as well.
