; ===========================================================================
;  ASCENSION VECTOR - C64 port   (64tass, 100% 6502 machine code)
;  PAL, VIC bank 3: screen $c000, bitmap screen $c400, charset $c800,
;  sprites $d000 (under I/O), multicolour bitmap $e000
; ===========================================================================
SCREEN  = $c000
BMSCR   = $c400
CHARSET = $c800
SPRMEM  = $d000
BITMAP  = $e000

; ---- zero page ----------------------------------------------------------
frameflag = $02
beatflag  = $03
framecnt  = $04
seed      = $05
zt1       = $06
zt2       = $07
ztmp      = $08
zv1       = $09     ; 2
zv2       = $0b     ; 2
zpal      = $0d
zp0       = $0e     ; 2 general pointer
zp1       = $10     ; 2
zp2       = $12     ; 2
; music
m_frame   = $20
m_step    = $21
m_bar     = $22
m_beat    = $23
m_beatcnt = $24
m_fl      = $25
m_ch      = $26
m_roll    = $27
m_fc      = $28
v1mode    = $29
v1t       = $2a
v1gate    = $2b
v2gate    = $2c
v3gate    = $2d
arpidx    = $2e
v3note    = $2f
v3vib     = $30
pwlo      = $31
pwhi      = $32
digi_on   = $33
nib       = $34
v2wave    = $35
; scene
scene     = $40
sc_f      = $41
s1        = $42
s2        = $43
boost     = $44
rmode     = $45      ; 0 none 1 single 2 dual
spmode    = $46      ; 0 none 1 particles 2 object 3 eyes 4 eyetri
pmode     = $47      ; particle kind
fldon     = $48
scron     = $49
vm11      = $4a
vm16      = $4b
vm18      = $4c
vbg       = $4d
fldn      = $4e
fldc      = $4f
scrx      = $50
scrp      = $51      ; 2
lookx     = $53
looky     = $54
tx        = $55
ty        = $56
snap      = $57
blink_e   = $58
blink_c   = $59
eyen      = $5a
bigeye    = $5b
objf      = $5c
objsel    = $5d
fract     = $5e
msgp      = $5f
msgg      = $60
lastmsg   = $61
lastword  = $62
eyelr     = $63
eyerow    = $64
eyecol    = $65
eyew      = $66
eyeh      = $67
tmp1      = $68
tmp2      = $69
tmp3      = $6a
spd       = $6b
indrop    = $6c
msgdata   = $6d     ; 2

        * = $0801
        .word (+), 2026
        .null $9e, format("%d", start)
+       .word 0

start
        sei
        lda #$35
        sta $01
        lda #$7f
        sta $dc0d
        sta $dd0d
        lda $dc0d
        lda $dd0d
        lda #0
        sta $d020
        sta $d021
        sta $d015
        ; copy sprites into RAM under I/O
        lda #$34
        sta $01
        ldx #0
-       lda SPRDATA,x
        sta SPRMEM,x
        lda SPRDATA+$100,x
        sta SPRMEM+$100,x
        inx
        bne -
        lda #$35
        sta $01
        ; VIC bank 3
        lda $dd02
        ora #3
        sta $dd02
        lda $dd00
        and #$fc
        sta $dd00
        ; clear zero page vars
        ldx #$02
        lda #0
-       sta $00,x
        inx
        cpx #$90
        bne -
        ; clear screen
        ldx #0
        lda #32
-       sta SCREEN,x
        sta SCREEN+$100,x
        sta SCREEN+$200,x
        sta SCREEN+$2e8,x
        inx
        bne -
        lda $d012
        eor $dc04
        ora #1
        sta seed
        jsr sid_init
        lda #<SCROLLTXT
        sta scrp
        lda #>SCROLLTXT
        sta scrp+1
        lda #$ff
        sta lastmsg
        lda #7
        sta scrx
        ; vectors
        lda #<irq_top
        sta $fffe
        lda #>irq_top
        sta $ffff
        lda #<nmi
        sta $fffa
        lda #>nmi
        sta $fffb
        lda #$1b
        sta $d011
        lda #$08
        sta $d012
        lda #1
        sta $d01a
        lda $d019
        sta $d019
        lda #S_GALAXY
        jsr scene_init
        cli

mainloop
-       lda frameflag
        beq -
        lda #0
        sta frameflag
        lda beatflag
        beq +
        lda #0
        sta beatflag
        jsr on_beat
+       jsr scene_frame
        jmp mainloop

; ===========================================================================
;  IRQs
; ===========================================================================
irq_top
        pha
        txa
        pha
        tya
        pha
        lda #$ff
        sta $d019
        lda vm11
        sta $d011
        lda vm16
        sta $d016
        lda vm18
        sta $d018
        lda vbg
        sta $d021
        lda #0
        sta $d020
        ; sprites
        ldx #0
        ldy #0
-       lda spx,x
        sta $d000,y
        lda spy,x
        sta $d001,y
        lda spcol,x
        sta $d027,x
        lda spptr,x
        sta SCREEN+$3f8,x
        sta BMSCR+$3f8,x
        iny
        iny
        inx
        cpx #8
        bne -
        lda spmsb
        sta $d010
        lda spen
        sta $d015
        lda spmc
        sta $d01c
        lda spxe
        sta $d01d
        lda spye
        sta $d017
        lda spmc1
        sta $d025
        lda spmc2
        sta $d026
        ; next irq
        lda fldon
        beq +
        lda #$2e
        sta $d012
        lda #<irq_fld
        sta $fffe
        lda #>irq_fld
        sta $ffff
        jmp _music
+       lda #$f0
        sta $d012
        lda #<irq_split
        sta $fffe
        lda #>irq_split
        sta $ffff
_music
        jsr play
        jsr scroller
        inc framecnt
        inc frameflag
        jmp irq_exit

irq_fld
        pha
        txa
        pha
        tya
        pha
        lda #$ff
        sta $d019
        ldy fldc
        ldx fldn
        beq _done
_l      lda $d012
-       cmp $d012
        beq -
        lda $d011
        clc
        adc #1
        and #7
        ora #$18
        sta $d011
        lda BARCOL,y
        sta $d020
        sta $d021
        iny
        tya
        and #63
        tay
        dex
        bne _l
_done   lda #0
        sta $d020
        lda vbg
        sta $d021
        jmp irq_settop

irq_split
        pha
        txa
        pha
        tya
        pha
        lda #$ff
        sta $d019
        lda scron
        beq irq_settop
        lda #$1b
        sta $d011
        lda #$02
        sta $d018
        lda scrx
        sta $d016
        lda #0
        sta $d021
irq_settop
        lda #$08
        sta $d012
        lda #<irq_top
        sta $fffe
        lda #>irq_top
        sta $ffff
irq_exit
        pla
        tay
        pla
        tax
        pla
        rti

; ---- 4-bit digi on NMI (CIA2 timer A, 7.8 kHz) ----------------------------
nmi
        pha
        lda $dd0d
        lda nib
        eor #1
        sta nib
        beq nlo
nsrc1   lda SAMPLE
        lsr
        lsr
        lsr
        lsr
        sta $d418
        pla
        rti
nlo
nsrc2   lda SAMPLE
        and #$0f
        sta $d418
        inc nsrc1+1
        inc nsrc2+1
        bne nout
        inc nsrc1+2
        inc nsrc2+2
        lda nsrc1+2
        cmp #>SAMPLE_END
        bne nout
        lda #$7f
        sta $dd0d
        lda #0
        sta $dd0e
        sta digi_on
        lda #$61
        sta $d417
        lda #$1f
        sta $d418
nout    pla
        rti

digi_start
        lda #0
        sta $d404
        sta $d40b
        sta $d412
        sta $d417
        sta nib
        lda #8
        sta $d418
        lda #<SAMPLE
        sta nsrc1+1
        sta nsrc2+1
        lda #>SAMPLE
        sta nsrc1+2
        sta nsrc2+2
        lda #125
        sta $dd04
        lda #0
        sta $dd05
        lda #1
        sta digi_on
        lda $dd0d
        lda #$81
        sta $dd0d
        lda #$11
        sta $dd0e
        rts

; ---- scroller (bottom row, hardware fine scroll) ---------------------------
scroller
        lda scrx
        sec
        sbc #2
        bpl _ok
        and #7
        sta scrx
        ldx #0
-       lda SCREEN+961,x
        sta SCREEN+960,x
        inx
        cpx #39
        bne -
        ldy #0
        lda (scrp),y
        cmp #$ff
        bne +
        lda #<SCROLLTXT
        sta scrp
        lda #>SCROLLTXT
        sta scrp+1
        lda #32
+       sta SCREEN+999
        inc scrp
        bne +
        inc scrp+1
+       jmp _col
_ok     sta scrx
_col    lda framecnt
        lsr
        sta tmp3
        ldx #39
-       txa
        lsr
        lsr
        clc
        adc tmp3
        and #15
        tay
        lda SCRPAL,y
        sta $d800+960,x
        dex
        bpl -
        rts

; ===========================================================================
;  SID player (148 BPM: beats of 20/20/21/20 frames, 16th steps of 5-6)
; ===========================================================================
FL_KICK=1
FL_BASS=2
FL_HATS=4
FL_ROLL=8
FL_ARP=16
FL_MEL=32
FL_TONE=64
FL_DIGI=128

sid_init
        ldx #$18
        lda #0
-       sta $d400,x
        dex
        bpl -
        lda #$61
        sta $d417
        lda #$1f
        sta $d418
        lda #$00
        sta $d413
        lda #$a6
        sta $d414
        lda #1
        sta m_frame
        lda #15
        sta m_step
        lda #SONGLEN-1
        sta m_bar
        rts

play
        dec m_frame
        beq _step
        jmp fx
_step   inc m_step
        lda m_step
        and #15
        sta m_step
        bne _nobar
        inc m_bar
        lda m_bar
        cmp #SONGLEN
        bcc +
        lda #0
        sta m_bar
+       ldx m_bar
        lda SONG_FL,x
        sta m_fl
        lda SONG_CH,x
        sta m_ch
        lda SONG_ROLL,x
        sta m_roll
        lda SONG_FC,x
        sta m_fc
        lda m_fl
        and #FL_BASS
        sta indrop
_nobar  lda #5
        sta m_frame
        lda m_step
        and #3
        cmp #3
        bne +
        lda m_beatcnt
        and #3
        cmp #1
        bne +
        inc m_frame
+       lda m_step
        and #3
        bne +
        inc m_beatcnt
        lda m_step
        lsr
        lsr
        sta m_beat
        inc beatflag
+       lda m_step
        bne +
        lda m_fl
        and #FL_DIGI
        beq +
        jsr digi_start
+       lda digi_on
        beq _trig
        rts
_trig
        ; ---- voice 1: kick + rolling bass
        lda m_step
        and #3
        bne _bass
        lda m_fl
        and #FL_KICK
        beq _v1done
        lda #0
        sta v1t
        lda #1
        sta v1mode
        lda #$08
        sta $d405
        lda #$00
        sta $d406
        jmp _v1done
_bass   lda m_fl
        and #FL_BASS
        beq _v1done
        ldx m_ch
        lda CH_BASS,x
        tax
        lda FREQLO,x
        sta $d400
        lda FREQHI,x
        sta $d401
        lda #$05
        sta $d405
        lda #$40
        sta $d406
        lda #$21
        sta $d404
        lda #3
        sta v1gate
        lda #2
        sta v1mode
_v1done
        ; ---- voice 2: snare roll / hats / 963 Hz tone
        lda m_fl
        and #FL_ROLL
        beq _hats
        lda m_roll
        sec
        sbc #1
        and m_step
        bne _v2done
        lda #$1c
        sta $d408
        lda #$07
        sta $d40c
        lda #$00
        sta $d40d
        lda #$80
        sta v2wave
        lda #$81
        sta $d40b
        lda #2
        sta v2gate
        jmp _v2done
_hats   lda m_fl
        and #FL_HATS
        beq _tone
        lda m_step
        and #3
        cmp #2
        bne _tone
        lda #$f0
        sta $d408
        lda #$04
        sta $d40c
        lda #$00
        sta $d40d
        lda #$80
        sta v2wave
        lda #$81
        sta $d40b
        lda #1
        sta v2gate
        jmp _v2done
_tone   lda m_fl
        and #FL_TONE
        beq _v2done
        lda m_step
        bne _v2done
        lda #$0e
        sta $d407
        lda #$40
        sta $d408
        lda #$a0
        sta $d40c
        lda #$a9
        sta $d40d
        lda #$10
        sta v2wave
        lda #$11
        sta $d40b
        lda #60
        sta v2gate
_v2done
        ; ---- voice 3: arp / melody
        lda m_fl
        and #FL_ARP
        beq _mel
        ldx m_step
        lda ARPRHY,x
        beq _v3done
        lda #$00
        sta $d413
        lda #$a4
        sta $d414
        lda #$40
        sta $d412
        lda #$41
        sta $d412
        lda #3
        sta v3gate
        jmp _v3done
_mel    lda m_fl
        and #FL_MEL
        beq _v3done
        lda m_bar
        and #1
        asl
        asl
        asl
        asl
        ora m_step
        tax
        lda MELODY,x
        cmp #$fe
        beq _v3done
        cmp #$ff
        bne +
        lda #$40
        sta $d412
        jmp _v3done
+       sta v3note
        lda #0
        sta v3vib
        lda #$28
        sta $d413
        lda #$a6
        sta $d414
        lda #$40
        sta $d412
        lda #$41
        sta $d412
_v3done
fx
        lda digi_on
        beq +
        rts
+       ; kick sweep
        lda v1mode
        cmp #1
        bne _bg
        ldx v1t
        lda KICKF,x
        sta $d401
        lda KICKW,x
        sta $d404
        inc v1t
        lda v1t
        cmp #6
        bcc _v1x
        lda #0
        sta v1mode
        beq _v1x
_bg     cmp #2
        bne _v1x
        dec v1gate
        bne _v1x
        lda #$20
        sta $d404
        lda #0
        sta v1mode
_v1x    ; voice 2 gate
        lda v2gate
        beq _v2x
        dec v2gate
        bne _v2x
        lda v2wave
        sta $d40b
_v2x    ; voice 3
        lda m_fl
        and #FL_ARP
        beq _mfx
        inc arpidx
        lda arpidx
        cmp #3
        bcc +
        lda #0
        sta arpidx
+       lda m_ch
        asl
        adc m_ch
        adc arpidx
        tax
        lda CH_ARP,x
        tax
        lda FREQLO,x
        sta $d40e
        lda FREQHI,x
        sta $d40f
        lda pwlo
        clc
        adc #$30
        sta pwlo
        sta $d410
        lda pwhi
        adc #0
        and #$0f
        ora #$02
        sta pwhi
        sta $d411
        lda v3gate
        beq _filt
        dec v3gate
        bne _filt
        lda #$40
        sta $d412
        jmp _filt
_mfx    lda m_fl
        and #FL_MEL
        beq _filt
        lda #$08
        sta $d411
        inc v3vib
        ldx v3note
        lda v3vib
        cmp #12
        bcc _novib
        lsr
        and #7
        tay
        lda FREQLO,x
        clc
        adc VIB,y
        sta $d40e
        lda FREQHI,x
        adc #0
        sta $d40f
        jmp _filt
_novib  lda FREQLO,x
        sta $d40e
        lda FREQHI,x
        sta $d40f
_filt   lda m_step
        asl
        clc
        adc m_fc
        sta $d416
        rts

; ===========================================================================
;  scene management
; ===========================================================================
rnd     lda seed
        asl
        bcc +
        eor #$1d
+       sta seed
        rts

on_beat
        lda m_beat
        asl
        tay
        lda TLPTR,y
        sta zp0
        lda TLPTR+1,y
        sta zp0+1
        ldy m_bar
        lda (zp0),y
        cmp #$ff
        beq +
        jsr scene_init
+       lda #10
        sta boost
        lda indrop
        beq +
        lda #12
        sta snap
+       rts

TLPTR   .word TL0, TL1, TL2, TL3

scene_init
        sta scene
        lda #0
        sta sc_f
        sta rmode
        sta spmode
        sta fldon
        sta spen
        sta spmc
        sta spxe
        sta spye
        sta spmsb
        sta vbg
        sta lookx
        sta looky
        sta tx
        sta ty
        sta blink_c
        lda #1
        sta scron
        sta s1
        sta s2
        lda #$1b
        sta vm11
        lda #$c8
        sta vm16
        lda #$02
        sta vm18
        lda scene
        asl
        tax
        lda SINIT,x
        sta zp0
        lda SINIT+1,x
        sta zp0+1
        jmp (zp0)

SINIT   .word in_galaxy, in_title, in_planet, in_tunnel, in_hyper, in_watch, in_bigeye, in_fract
        .word in_plasma, in_geom, in_penta, in_eyetri, in_metat, in_msg, in_flash, in_cube, in_credits, in_ring

; ---- helpers ----
; copy 960 chars from (zp1) to screen
copy_chars
        lda #<SCREEN
        sta zp2
        lda #>SCREEN
        sta zp2+1
        ldx #3
_pg     ldy #0
-       lda (zp1),y
        sta (zp2),y
        iny
        bne -
        inc zp1+1
        inc zp2+1
        dex
        bne _pg
        ldy #0
-       lda (zp1),y
        sta (zp2),y
        iny
        cpy #192
        bne -
        rts
; fill 960 chars with A
fill_chars
        ldx #0
-       sta SCREEN,x
        sta SCREEN+$100,x
        sta SCREEN+$200,x
        inx
        bne -
        ldx #191
-       sta SCREEN+$300,x
        dex
        cpx #$ff
        bne -
        rts
fill_cols
        ldx #0
-       sta $d800,x
        sta $d900,x
        sta $da00,x
        inx
        bne -
        ldx #191
-       sta $db00,x
        dex
        cpx #$ff
        bne -
        rts
; colour from char via CMAP
cmap_cols
        ldx #0
-       ldy SCREEN,x
        lda CMAP,y
        sta $d800,x
        ldy SCREEN+$100,x
        lda CMAP,y
        sta $d900,x
        ldy SCREEN+$200,x
        lda CMAP,y
        sta $da00,x
        inx
        bne -
        ldx #0
-       ldy SCREEN+$300,x
        lda CMAP,y
        sta $db00,x
        inx
        cpx #192
        bne -
        rts
; A = palette index -> zpal
setpal  clc
        adc #>PALS
        sta zpal
        rts
; choose random from table at (zp0) with length X -> A
rndpick stx tmp1
-       jsr rnd
        and #15
        cmp tmp1
        bcs -
        tay
        lda (zp0),y
        rts
setv1   sta zv1
        stx zv1+1
        rts
setv2   sta zv2
        stx zv2+1
        rts
render_on_single
        jsr set_render
        lda #1
        sta rmode
        rts
render_on_dual
        jsr set_render
        lda #2
        sta rmode
        rts

; ---- scene inits ----
in_galaxy
        lda #<C_GALAXY
        sta zp1
        lda #>C_GALAXY
        sta zp1+1
        jsr copy_chars
        lda #<T_SPIRAL
        ldx #>T_SPIRAL
        jsr setv1
        lda #P_GALAXY
        jsr setpal
        lda #2
        sta s1
        lda #1
        sta pmode
        jsr particles_init
        jmp render_on_single

in_title
        lda #<C_TITLE
        sta zp1
        lda #>C_TITLE
        sta zp1+1
title_common
        jsr copy_chars
        lda #<T_XGRAD
        ldx #>T_XGRAD
        jsr setv1
        lda #P_GOLD
        jsr setpal
        lda #3
        sta s1
        lda #1
        sta fldon
        lda #0
        sta scron
        lda #32
        ldx #39
-       sta SCREEN+960,x
        dex
        bpl -
        jmp render_on_single
in_credits
        lda #<C_CREDITS
        sta zp1
        lda #>C_CREDITS
        sta zp1+1
        jsr title_common
        lda #P_CYAN
        jmp setpal

in_planet
        lda #$3b
        sta vm11
        lda #$d8
        sta vm16
        lda #$18
        sta vm18
        ldx #0
-       lda PLANET_COL,x
        sta $d800,x
        lda PLANET_COL+$100,x
        sta $d900,x
        lda PLANET_COL+$200,x
        sta $da00,x
        inx
        bne -
        ldx #191
-       lda PLANET_COL+$300,x
        sta $db00,x
        dex
        cpx #$ff
        bne -
        lda #2
        sta pmode
        jmp particles_init

in_tunnel
        lda #<C_TUNNEL
        sta zp1
        lda #>C_TUNNEL
        sta zp1+1
        jsr copy_chars
        lda #<T_TUND
        ldx #>T_TUND
        jsr setv1
        lda #<T_TUNA
        ldx #>T_TUNA
        jsr setv2
        lda #<TUNPALS
        sta zp0
        lda #>TUNPALS
        sta zp0+1
        ldx #4
        jsr rndpick
        jsr setpal
        lda #5
        sta s1
        lda #1
        sta s2
        jmp render_on_dual
TUNPALS .byte P_TUNNEL, P_CYAN, P_FIRE, P_TUNNEL

in_hyper
        lda #32
        jsr fill_chars
        ldx #NSTAR-1
-       jsr rnd
        and #31
        sta st_d,x
        jsr rnd
        and #15
        sta st_z,x
        lda #$ff
        sta st_oh,x
        dex
        bpl -
        rts

in_watch
        lda #<C_WATCH
        sta zp1
        lda #>C_WATCH
        sta zp1+1
        jsr copy_chars
        jsr cmap_cols
        lda #6
        sta vbg
        lda #EW_N
        sta eyen
        lda #0
        sta bigeye
        ldx #EW_N-1
-       lda #66
        sta spptr,x
        lda EYECOL,x
        sta spcol,x
        dex
        bpl -
        lda #%01111111
        sta spen
        sta spmc
        jmp eyes_common
in_bigeye
        lda #<C_BIGEYE
        sta zp1
        lda #>C_BIGEYE
        sta zp1+1
        jsr copy_chars
        jsr cmap_cols
        lda #1
        sta eyen
        sta bigeye
        ldx #3
-       txa
        clc
        adc #67
        sta spptr,x
        lda #3
        sta spcol,x
        dex
        bpl -
        lda #%00001111
        sta spen
        sta spmc
        sta spxe
        sta spye
eyes_common
        lda #0
        sta spmc1
        lda #1
        sta spmc2
        lda #3
        sta spmode
        lda #40
        sta blink_e
        rts

in_fract
        lda #160
        jsr fill_chars
        lda #<T_FRACT
        ldx #>T_FRACT
        jsr setv1
        lda #0
        sta fract
        lda #<FRPALS
        sta zp0
        lda #>FRPALS
        sta zp0+1
        ldx #4
        jsr rndpick
        jsr setpal
        lda #3
        sta s1
        jmp render_on_single
FRPALS  .byte P_BLUE, P_FIRE, P_NEON, P_PURPLE

in_plasma
        jsr rnd_char
        jsr fill_chars
        jsr rnd
        and #1
        tax
        lda PLT_L,x
        pha
        lda PLT_H,x
        tax
        pla
        jsr setv1
        lda #<T_PLASMA2
        ldx #>T_PLASMA2
        jsr setv2
        jsr rnd_pal
        lda #3
        sta s1
        lda #2
        sta s2
        jsr rnd
        bmi +
        jmp render_on_single
+       jmp render_on_dual
PLT_L   .byte <T_PLASMA1, <T_PLASMA2
PLT_H   .byte >T_PLASMA1, >T_PLASMA2

rnd_char
        lda #<CHARS
        sta zp0
        lda #>CHARS
        sta zp0+1
        ldx #5
        jmp rndpick
CHARS   .byte 160, 147, 148, 160, 150
rnd_pal lda #<ALLPALS
        sta zp0
        lda #>ALLPALS
        sta zp0+1
        ldx #10
        jsr rndpick
        jmp setpal
ALLPALS .byte P_BLUE,P_CYAN,P_GOLD,P_PURPLE,P_GREEN,P_FIRE,P_NEON,P_GALAXY,P_MONO,P_TUNNEL

geom_tables
        jsr rnd
        and #7
        tax
        lda GT_L,x
        pha
        lda GT_H,x
        tax
        pla
        jsr setv1
        jsr rnd
        and #7
        tax
        lda GT_L,x
        pha
        lda GT_H,x
        tax
        pla
        jmp setv2
GT_L    .byte <T_XORP,<T_DIAMOND,<T_XGRAD,<T_RINGS,<T_SPIRAL,<T_PLASMA1,<T_TUNA,<T_DIAMOND
GT_H    .byte >T_XORP,>T_DIAMOND,>T_XGRAD,>T_RINGS,>T_SPIRAL,>T_PLASMA1,>T_TUNA,>T_DIAMOND

in_geom
        jsr rnd_char
        jsr fill_chars
        jsr geom_tables
        jsr rnd_pal
        jsr rnd
        and #3
        clc
        adc #2
        sta s1
        lda #1
        sta s2
        jmp render_on_dual

in_cube
        lda #0
        sta objsel
        jmp obj_common
in_ring
        lda #1
        sta objsel
obj_common
        lda #148
        jsr fill_chars
        jsr geom_tables
        lda #P_MONO
        jsr setpal
        lda #2
        sta s1
        ldx #7
-       lda #65
        sta spptr,x
        lda EYECOL,x
        sta spcol,x
        dex
        bpl -
        lda #$ff
        sta spen
        sta spmc
        lda #6
        sta spmc1
        lda #1
        sta spmc2
        lda #2
        sta spmode
        jmp render_on_dual

sym_common
        jsr copy_chars
        lda #<T_RINGS
        ldx #>T_RINGS
        jsr setv1
        lda #<SYMPALS
        sta zp0
        lda #>SYMPALS
        sta zp0+1
        ldx #4
        jsr rndpick
        jsr setpal
        lda #4
        sta s1
        jmp render_on_single
SYMPALS .byte P_GOLD, P_PURPLE, P_CYAN, P_GOLD
in_penta
        lda #<C_PENTA
        sta zp1
        lda #>C_PENTA
        sta zp1+1
        jmp sym_common
in_metat
        lda #<C_METAT
        sta zp1
        lda #>C_METAT
        sta zp1+1
        jmp sym_common
in_eyetri
        lda #<C_EYETRI
        sta zp1
        lda #>C_EYETRI
        sta zp1+1
        jsr sym_common
        lda #P_GOLD
        jsr setpal
        jsr set_render
        lda #66
        sta spptr
        lda #3
        sta spcol
        lda #1
        sta spen
        sta spmc
        sta spxe
        sta spye
        lda #0
        sta spmc1
        lda #1
        sta spmc2
        lda #4
        sta spmode
        rts

in_flash
        lda #32
        jsr fill_chars
-       jsr rnd
        and #31
        cmp #WORD_N
        bcs -
        cmp lastword
        beq -
        sta lastword
        tax
        lda WORD_OFF,x
        tax
        lda WORDS,x
        sta tmp1            ; length
        inx
        stx tmp2            ; index of first char
        ; start col = (40 - len*4)/2 = 20 - len*2
        lda tmp1
        asl
        sta tmp3
        lda #20
        sec
        sbc tmp3
        clc
        adc #<(SCREEN+400)
        sta zp2
        lda #>(SCREEN+400)
        adc #0
        sta zp2+1
_ch     ldx tmp2
        lda WORDS,x
        ; tile ptr = BIGFONT + c*16
        sta tmp3
        lsr
        lsr
        lsr
        lsr
        clc
        adc #>BIGFONT
        sta zp1+1
        lda tmp3
        asl
        asl
        asl
        asl
        clc
        adc #<BIGFONT
        sta zp1
        bcc +
        inc zp1+1
+       ldx #0          ; tile byte index
        lda #0
        sta tmp3        ; row
_row    ldy tmp3
        lda ROWOFF,y
        sta ztmp
        ldy #0
-       sty eyecol
        txa
        tay
        lda (zp1),y
        pha
        lda ztmp
        clc
        adc eyecol
        tay
        pla
        sta (zp2),y
        inx
        ldy eyecol
        iny
        cpy #4
        bne -
        inc tmp3
        lda tmp3
        cmp #4
        bne _row
        lda zp2
        clc
        adc #4
        sta zp2
        bcc +
        inc zp2+1
+       inc tmp2
        dec tmp1
        bne _ch
        lda #<T_XGRAD
        ldx #>T_XGRAD
        jsr setv1
        jsr rnd
        and #1
        tax
        lda FLPALS,x
        jsr setpal
        lda #6
        sta s1
        jmp render_on_single
ROWOFF  .byte 0,40,80,120
FLPALS  .byte P_GOLD, P_NEON

in_msg
        lda #32
        jsr fill_chars
-       jsr rnd
        and #63
        cmp #MSG_N
        bcs -
        cmp lastmsg
        beq -
        sta lastmsg
        tax
        lda MSG_LO,x
        clc
        adc #<MSGS
        sta msgdata
        lda MSG_HI,x
        adc #>MSGS
        sta msgdata+1
        lda #0
        sta msgp
        lda #3
        sta pmode
        jmp particles_init

; ===========================================================================
;  per-frame
; ===========================================================================
scene_frame
        inc sc_f
        lda boost
        beq +
        dec boost
+       lda zt1
        clc
        adc s1
        adc boost
        sta zt1
        lda zt2
        clc
        adc s2
        sta zt2
        ; per-scene extras
        lda scene
        cmp #S_FRACT
        bne +
        jsr fr_frame
+       lda scene
        cmp #S_TITLE
        beq _fld
        cmp #S_CREDITS
        bne +
_fld    jsr fld_frame
+       lda scene
        cmp #S_HYPER
        bne +
        jsr hyper_frame
+       lda scene
        cmp #S_MSG
        bne +
        jsr msg_frame
+       ; sprites
        lda spmode
        cmp #1
        bne +
        jsr particles_frame
+       lda spmode
        cmp #2
        bne +
        jsr obj_frame
+       lda spmode
        cmp #3
        bne +
        jsr eyes_frame
+       lda spmode
        cmp #4
        bne +
        jsr eyetri_frame
+       lda scene
        cmp #S_MSG
        beq _p
        cmp #S_GALAXY
        beq _p
        cmp #S_PLANET
        bne +
_p      jsr particles_frame
+       ; colour render
        lda rmode
        cmp #1
        bne +
        jmp render_single
+       cmp #2
        bne +
        jmp render_dual
+       rts

fld_frame
        lda sc_f
        asl
        asl
        tax
        lda SINE,x
        lsr
        lsr
        clc
        adc #4
        adc boost
        sta fldn
        lda sc_f
        and #63
        eor #63
        sta fldc
        rts

fr_frame
        lda sc_f
        and #15
        bne +
        lda boost
        bne +
        inc fract
+       lda boost
        cmp #10
        bne +
        inc fract
+       lda fract
        cmp #6
        bcc +
        lda #0
        sta fract
+       ; zv1 = T_FRACT + fract*960
        ldx fract
        lda FRL,x
        sta zv1
        lda FRH,x
        sta zv1+1
        jmp set_render
FRL     .byte <(T_FRACT+range(6)*960)
FRH     .byte >(T_FRACT+range(6)*960)

; ---- starfield ------------------------------------------------------------
NSTAR = 40
hyper_frame
        lda boost
        lsr
        lsr
        clc
        adc #1
        sta spd
        ldx #NSTAR-1
_st     lda st_oh,x
        cmp #$ff
        beq _move
        sta zp2+1
        lda st_ol,x
        sta zp2
        lda zp2+1
        clc
        adc #>SCREEN
        sta zp2+1
        ldy #0
        lda #32
        sta (zp2),y
_move   lda st_z,x
        clc
        adc spd
        cmp #32
        bcc +
        jsr respawn
        jmp _next
+       sta st_z,x
        ; traj index: page = d>>3, y = (d&7)*32+z
        lda st_d,x
        lsr
        lsr
        lsr
        sta tmp1
        lda st_d,x
        and #7
        asl
        asl
        asl
        asl
        asl
        ora st_z,x
        tay
        lda tmp1
        clc
        adc #>TRAJ_H
        sta zp1+1
        lda #<TRAJ_H
        sta zp1
        lda (zp1),y
        cmp #$ff
        bne +
        jsr respawn
        jmp _next
+       sta st_oh,x
        lda tmp1
        clc
        adc #>TRAJ_L
        sta zp1+1
        lda (zp1),y
        sta st_ol,x
        sta zp2
        sta zp1
        lda st_oh,x
        clc
        adc #>SCREEN
        sta zp2+1
        lda st_oh,x
        clc
        adc #$d8
        sta zp1+1
        ldy st_z,x
        lda STCOL,y
        pha
        lda STCHR,y
        ldy #0
        sta (zp2),y
        pla
        sta (zp1),y
_next   dex
        bpl _st
        rts
respawn jsr rnd
        and #31
        sta st_d,x
        jsr rnd
        and #3
        sta st_z,x
        lda #$ff
        sta st_oh,x
        rts

; ---- particles (sprites 0-7) -----------------------------------------------
particles_init
        ldx #7
-       jsr pspawn
        jsr rnd
        sta pxl,x          ; scatter initial x
        lda #0
        sta pxh,x
        jsr rnd
        and #127
        adc #60
        sta spy,x
        dex
        bpl -
        lda #$ff
        sta spen
        lda #0
        sta spmc
        rts
pspawn  lda pmode
        cmp #3
        beq _msg
        cmp #2
        beq _pl
        ; galaxy: from centre outwards
        lda #172
        sta pxl,x
        lda #0
        sta pxh,x
        lda #140
        sta spy,x
-       jsr rnd
        and #7
        sec
        sbc #4
        sta pvx,x
        jsr rnd
        and #3
        sec
        sbc #2
        sta pvy,x
        ora pvx,x
        beq -
        lda #64
        sta spptr,x
        txa
        and #3
        tay
        lda GALCOL,y
        sta spcol,x
        rts
_pl     lda #64
        sta pxl,x
        lda #1
        sta pxh,x
        jsr rnd
        and #127
        adc #50
        sta spy,x
        lda #$ff
        sta pvx,x
        lda #0
        sta pvy,x
        lda #64
        sta spptr,x
        lda #15
        sta spcol,x
        rts
_msg    jsr rnd
        sta pxl,x
        lda #0
        sta pxh,x
        lda #230
        sta spy,x
        jsr rnd
        and #1
        clc
        adc #$fe
        sta pvy,x
        lda #0
        sta pvx,x
        lda #71
        sta spptr,x
        txa
        and #3
        tay
        lda MSGCOL,y
        sta spcol,x
        rts
GALCOL  .byte 1,14,4,15
MSGCOL  .byte 7,3,1,10

particles_frame
        ldx #7
_p      lda pvx,x
        bmi _neg
        clc
        adc pxl,x
        sta pxl,x
        lda pxh,x
        adc #0
        sta pxh,x
        jmp _y
_neg    clc
        adc pxl,x
        sta pxl,x
        lda pxh,x
        adc #$ff
        sta pxh,x
_y      lda spy,x
        clc
        adc pvy,x
        sta spy,x
        ; bounds
        lda pxh,x
        bmi _re
        beq _ylim
        lda pxl,x
        cmp #80
        bcs _re
_ylim   lda spy,x
        cmp #40
        bcc _re
        cmp #236
        bcs _re
        lda pxh,x
        bne _ok
        lda pxl,x
        cmp #20
        bcs _ok
_re     jsr pspawn
_ok     dex
        bpl _p
        ; copy to shadow x + msb
        lda #0
        sta tmp1
        ldx #7
-       lda pxl,x
        sta spx,x
        lda pxh,x
        lsr
        rol tmp1
        dex
        bpl -
        ; tmp1 bits are reversed (sprite0 ends in bit0)
        lda tmp1
        sta spmsb
        rts

; ---- rotating dot objects ------------------------------------------------
obj_frame
        lda boost
        lsr
        lsr
        sec
        adc objf
        and #63
        sta objf
        asl
        asl
        asl
        tay
        ldx #0
        lda objsel
        bne _ring
-       lda O_CUBE_X,y
        sta spx,x
        lda O_CUBE_Y,y
        sta spy,x
        iny
        inx
        cpx #8
        bne -
        ldy objf
        lda O_CUBE_M,y
        sta spmsb
        rts
_ring
-       lda O_RING_X,y
        sta spx,x
        lda O_RING_Y,y
        sta spy,x
        iny
        inx
        cpx #8
        bne -
        ldy objf
        lda O_RING_M,y
        sta spmsb
        rts

; ---- eyes -----------------------------------------------------------------
eyes_frame
        ; choose look target
        lda sc_f
        and #31
        bne +
        jsr rnd
        and #15
        sec
        sbc #8
        sta tx
        jsr rnd
        and #7
        sec
        sbc #4
        sta ty
+       lda snap
        beq +
        dec snap
        lda #0
        sta lookx
        sta looky
        jmp _pos
+       ldx #2            ; ease speed
-       lda lookx
        cmp tx
        beq +
        bmi _inc
        dec lookx
        jmp +
_inc    inc lookx
+       dex
        bne -
        lda looky
        cmp ty
        beq _pos
        bmi +
        dec looky
        jmp _pos
+       inc looky
_pos    lda bigeye
        bne _big
        ldx #0
        lda #0
        sta tmp1
-       lda EW_SXL,x
        clc
        adc lookx
        sta spx,x
        lda EW_SXH,x
        ldy lookx
        bpl +
        adc #$ff
        jmp ++
+       adc #0
+       beq +
        lda BIT,x
        ora tmp1
        sta tmp1
+       lda EW_SY,x
        clc
        adc looky
        sta spy,x
        inx
        cpx #EW_N
        bne -
        lda tmp1
        sta spmsb
        jmp blink
_big    ; 4 sprites in 2x2, look range doubled
        lda lookx
        asl
        asl
        clc
        adc EB_SXL
        sta tmp1
        lda #0
        sta tmp2
        lda looky
        asl
        clc
        adc EB_SY
        sta tmp3
        ldx #0
-       lda tmp1
        clc
        adc QX,x
        sta spx,x
        lda #0
        adc #0
        beq +
        lda BIT,x
        ora tmp2
        sta tmp2
+       lda tmp3
        clc
        adc QY,x
        sta spy,x
        inx
        cpx #4
        bne -
        lda tmp2
        sta spmsb
blink   lda blink_c
        bne _active
        dec blink_e
        bne _rts
        jsr rnd
        and #63
        adc #20
        sta blink_e
        lda #7
        sta blink_c
-       jsr rnd
        and #7
        cmp eyen
        bcs -
        sta eyelr
        jsr eye_rect
        jsr lid_close
        rts
_active dec blink_c
        bne _rts
        jsr eye_rect
        jsr lid_open
_rts    rts
QX      .byte 0,48,0,48
QY      .byte 0,0,42,42
BIT     .byte 1,2,4,8,16,32,64,128

; set eyerow/eyecol/eyew/eyeh from eyelr (bigeye uses EB_*)
eye_rect
        ldx eyelr
        lda bigeye
        bne +
        lda EW_ROW,x
        sta eyerow
        lda EW_COL,x
        sta eyecol
        lda EW_W,x
        sta eyew
        lda EW_H,x
        sta eyeh
        rts
+       lda EB_ROW
        sta eyerow
        lda EB_COL
        sta eyecol
        lda EB_W
        sta eyew
        lda EB_H
        sta eyeh
        rts
; zp2 = screen ptr, zp1 = colour ptr, zp0 = layout ptr for row eyerow+tmp1
rowptrs ldy eyerow
        lda MUL40L,y
        clc
        adc eyecol
        sta zp2
        sta zp1
        sta zp0
        lda MUL40H,y
        adc #0
        pha
        clc
        adc #>SCREEN
        sta zp2+1
        pla
        pha
        clc
        adc #$d8
        sta zp1+1
        pla
        ldx bigeye
        clc
        adc LAYH,x
        sta zp0+1
        lda zp0
        clc
        adc LAYL,x
        sta zp0
        bcc +
        inc zp0+1
+       rts
LAYL    .byte <C_WATCH, <C_BIGEYE
LAYH    .byte >C_WATCH, >C_BIGEYE

lid_close
        ; hide sprites
        lda bigeye
        beq +
        lda #0
        sta spen
        jmp ++
+       ldx eyelr
        lda BIT,x
        eor #$ff
        and spen
        sta spen
+       lda eyeh
        lsr
        sta tmp2          ; middle row
        lda #0
        sta tmp1
_r      jsr rowptrs
        ldy #0
-       lda (zp0),y
        cmp #32
        beq _nx
        lda tmp1
        cmp tmp2
        bne _lid
        lda #64
        sta (zp2),y
        lda #1
        sta (zp1),y
        jmp _nx
_lid    lda #160
        sta (zp2),y
        lda #4
        sta (zp1),y
_nx     iny
        cpy eyew
        bne -
        inc eyerow
        inc tmp1
        lda tmp1
        cmp eyeh
        bne _r
        rts

lid_open
        lda #0
        sta tmp1
_r      jsr rowptrs
        ldy #0
-       lda (zp0),y
        sta (zp2),y
        tax
        lda CMAP,x
        sta (zp1),y
        iny
        cpy eyew
        bne -
        inc eyerow
        inc tmp1
        lda tmp1
        cmp eyeh
        bne _r
        lda bigeye
        beq +
        lda #$0f
        sta spen
        rts
+       ldx eyelr
        lda BIT,x
        ora spen
        sta spen
        rts

eyetri_frame
        lda sc_f
        asl
        tax
        lda SINE,x
        lsr
        lsr
        lsr
        lsr
        clc
        adc #152
        sta spx
        lda #0
        sta spmsb
        lda snap
        beq +
        lda #160
        sta spx
+       lda #129
        sta spy
        rts

; ---- message decode -------------------------------------------------------
msg_frame
        inc msgp
        lda #0
        sta msgg
        lda msgdata
        sta zp0
        lda msgdata+1
        sta zp0+1
_line   ldy #0
        lda (zp0),y
        beq _done
        sta tmp1          ; length
        iny
        lda (zp0),y
        sta zp2
        sta zp1
        iny
        lda (zp0),y
        pha
        clc
        adc #>SCREEN
        sta zp2+1
        pla
        clc
        adc #$d8
        sta zp1+1
        ; advance zp0 to chars
        lda zp0
        clc
        adc #3
        sta zp0
        bcc +
        inc zp0+1
+       ldy #0
_c      lda msgg
        cmp msgp
        bcs _undec
        ; decoded
        lda (zp0),y
        sta (zp2),y
        lda msgp
        sec
        sbc msgg
        cmp #4
        lda #1
        bcc +
        lda #7
+       sta (zp1),y
        jmp _nc
_undec  sec
        sbc msgp
        cmp #10
        bcs _blank
        jsr rnd
        and #63
        cmp #32
        bne +
        lda #156
+       sta (zp2),y
        lda #3
        sta (zp1),y
        jmp _nc
_blank  lda #32
        sta (zp2),y
_nc     inc msgg
        iny
        cpy tmp1
        bne _c
        tya
        clc
        adc zp0
        sta zp0
        bcc _line
        inc zp0+1
        jmp _line
_done   rts

; ===========================================================================
        .include "../build/render.s"
        .include "../build/song.s"

; ---- variables --------------------------------------------------------------
spx     .fill 8,0
spy     .fill 8,0
spcol   .fill 8,1
spptr   .fill 8,64
spmsb   .byte 0
spen    .byte 0
spmc    .byte 0
spxe    .byte 0
spye    .byte 0
spmc1   .byte 0
spmc2   .byte 1
pxl     .fill 8,0
pxh     .fill 8,0
pvx     .fill 8,0
pvy     .fill 8,0
st_d    .fill NSTAR,0
st_z    .fill NSTAR,0
st_ol   .fill NSTAR,0
st_oh   .fill NSTAR,$ff

SPRDATA .binary "../build/sprites.bin"
        .align $100
TRAJ_L  .binary "../build/traj_l.bin"
TRAJ_H  .binary "../build/traj_h.bin"
        .include "../build/data.s"
DATA_END
        .cerror DATA_END > $c000, "out of memory: ", DATA_END

        * = BMSCR
        .binary "../build/planet_scr.bin"
        * = CHARSET
        .binary "../build/charset.bin"
        * = BITMAP
        .binary "../build/planet_bm.bin"
