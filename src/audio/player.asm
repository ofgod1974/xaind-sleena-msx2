; Original YM2203 FM score transcription, interrupt-clocked on MSX2.
; Backends: PSG, SCC, YM2413 (MSX-MUSIC/FM-PAC), Y8950, OPL4 PCM/YRW801.
audio_mode EQU $c300
audio_dirty EQU $c301
music_bank EQU $c302
music_ptr EQU $c304
music_wait EQU $c306
music_start_bank EQU $c307
music_acc EQU $c308
music_step EQU $c30a
music_flags EQU $c30c
music_start_ptr EQU $c30d
music_notes EQU $c310
music_volumes EQU $c318
music_previous EQU $c320
music_prevvol EQU $c328
audio_channel EQU $c32f
fx_type EQU $c330
fx_life EQU $c331
audio_irq_count EQU $c334
cart_slot EQU $c338
scc_slot EQU $c339
scan_primary EQU $c33a
scan_slot EQU $c33b
audio_saved_bank EQU $c33c
mapper_bank EQU $c33d
audio_keys EQU $c33f
music_song EQU $c340
audio_note EQU $c344
audio_volume EQU $c345
audio_high EQU $c346
audio_low EQU $c347
audio_mapped_channel EQU $c348
audio_retrigger EQU $c349
scan_sub EQU $c34a
scan_value EQU $c34b
scan_bank_value EQU $c34c
audio_caps EQU $c34d
music_oldhook EQU $c350
pcm_lastwave EQU $c360

select_bank:
    LD (mapper_bank),A
    LD ($7000),A
    RET

audio_init:
    DI
    LD HL,audio_mode
    LD DE,audio_mode+1
    LD BC,127
    LD (HL),0
    LDIR
    LD A,($c3f0)
    LD (cart_slot),A
    LD A,1
    LD (audio_caps),A
    LD A,$ff
    LD (scc_slot),A
    LD (audio_keys),A
    CALL audio_detect
    LD A,7
    CALL select_bank
    LD HL,$8000
    LD DE,$d000
    LD BC,3840
    LDIR
    LD HL,980
    LD A,($ffe8)
    AND 2
    JR Z,.ntsc
    LD HL,1176
.ntsc:
    LD (music_step),HL
    LD A,(audio_config+1)
    CALL audio_song
    LD A,(audio_config)
    CALL audio_select
    LD HL,$fd9f
    LD DE,music_oldhook
    LD BC,5
    LDIR
    LD A,$c3
    LD ($fd9f),A
    LD HL,audio_irq
    LD ($fda0),HL
    XOR A
    LD ($f3db),A
    EI
    RET

audio_song:
    OR A
    JR NZ,.nonzero
    LD A,6
.nonzero:
    CP 30
    RET NC
    LD (music_song),A
    DEC A
    LD L,A
    LD H,0
    LD E,L
    LD D,H
    ADD HL,HL
    ADD HL,DE
    LD DE,music_index
    ADD HL,DE
    LD A,(HL)
    LD (music_bank),A
    LD (music_start_bank),A
    INC HL
    LD E,(HL)
    INC HL
    LD D,(HL)
    LD (music_ptr),DE
    LD (music_start_ptr),DE
    XOR A
    LD (music_wait),A
    LD (music_acc),A
    LD (music_acc+1),A
    RET

audio_irq:
    PUSH AF
    PUSH BC
    PUSH DE
    PUSH HL
    PUSH IX
    PUSH IY
    LD A,(mapper_bank)
    LD (audio_saved_bank),A
    LD HL,(audio_irq_count)
    INC HL
    LD (audio_irq_count),HL
    CALL audio_fx_tick
    LD HL,(music_acc)
    LD DE,(music_step)
    ADD HL,DE
.clock:
    LD A,H
    CP 4
    JR C,.doneclock
    LD DE,1024
    OR A
    SBC HL,DE
    PUSH HL
    CALL music_frame
    POP HL
    JR .clock
.doneclock:
    LD (music_acc),HL
    LD A,(audio_dirty)
    OR A
    CALL NZ,audio_output
    LD A,(audio_saved_bank)
    CALL select_bank
    CALL music_oldhook
    POP IY
    POP IX
    POP HL
    POP DE
    POP BC
    POP AF
    RET

music_frame:
    LD A,(music_wait)
    OR A
    JR Z,.event
    DEC A
    LD (music_wait),A
    RET
.event:
    LD A,(music_bank)
    CALL select_bank
    LD HL,(music_ptr)
    CALL music_byte
    OR A
    JR NZ,.record
    LD A,(music_start_bank)
    LD (music_bank),A
    CALL select_bank
    LD HL,(music_start_ptr)
    CALL music_byte
.record:
    DEC A
    LD (music_wait),A
    LD DE,music_notes
    LD B,6
.notes:
    CALL music_byte
    LD (DE),A
    INC DE
    DJNZ .notes
    LD DE,music_volumes
    LD B,6
.volumes:
    CALL music_byte
    LD (DE),A
    INC DE
    DJNZ .volumes
    CALL music_byte
    LD (music_flags),A
    LD (music_ptr),HL
    LD A,1
    LD (audio_dirty),A
    RET
music_byte:
    LD A,(HL)
    INC HL
    PUSH AF
    LD A,H
    CP $c0
    JR NZ,.ok
    LD HL,$8000
    LD A,(music_bank)
    INC A
    LD (music_bank),A
    CALL select_bank
.ok:
    POP AF
    RET

audio_output:
    XOR A
    LD (audio_dirty),A
    LD (audio_channel),A
    LD A,(audio_mode)
    CP 1
    CALL Z,audio_map_scc
.voice:
    LD A,(audio_channel)
    LD E,A
    LD D,0
    LD HL,music_notes
    ADD HL,DE
    LD A,(HL)
    LD (audio_note),A
    LD HL,music_volumes
    ADD HL,DE
    LD A,(HL)
    LD (audio_volume),A
    LD A,(audio_note)
    OR A
    JR NZ,.hasnote
    LD (audio_volume),A
.hasnote:
    LD HL,music_previous
    ADD HL,DE
    LD A,(audio_note)
    CP (HL)
    JR NZ,.newnote
    LD HL,bit_masks
    ADD HL,DE
    LD A,(music_flags)
    AND (HL)
    JR NZ,.newnote
    XOR A
    LD (audio_retrigger),A
    LD HL,music_prevvol
    ADD HL,DE
    LD A,(audio_volume)
    CP (HL)
    JR Z,.next
    JR .write
.newnote:
    LD A,1
    LD (audio_retrigger),A
.write:
    LD HL,music_previous
    ADD HL,DE
    LD A,(audio_note)
    LD (HL),A
    LD HL,music_prevvol
    ADD HL,DE
    LD A,(audio_volume)
    LD (HL),A
    LD A,(audio_mode)
    OR A
    JR Z,.psg
    DEC A
    JR Z,.scc
    DEC A
    JR Z,.opll
    DEC A
    JR Z,.opl
    CALL note_pcm
    JR .next
.psg:
    CALL note_psg
    JR .next
.scc:
    CALL note_scc
    JR .next
.opll:
    CALL note_opll
    JR .next
.opl:
    CALL note_opl
.next:
    LD A,(audio_channel)
    INC A
    LD (audio_channel),A
    CP 6
    JP C,.voice
    LD A,(audio_mode)
    CP 1
    CALL Z,audio_map_cart
    XOR A
    LD (music_flags),A
    RET

get_pitch:
    LD A,(audio_note)
    LD E,A
    LD D,0
    SLA E
    RL D
    ADD HL,DE
    LD A,(HL)
    LD (audio_low),A
    INC HL
    LD A,(HL)
    LD (audio_high),A
    RET
note_psg:
    LD A,(audio_channel)
    CP 3
    RET NC
    LD HL,psg_channel_map
    LD E,A
    LD D,0
    ADD HL,DE
    LD A,(HL)
    LD (audio_mapped_channel),A
    OR A
    JR NZ,.free
    LD A,(fx_life)
    OR A
    RET NZ
.free:
    LD HL,psg_period
    CALL get_pitch
    LD A,(audio_mapped_channel)
    ADD A,A
    LD D,A
    LD A,(audio_low)
    LD E,A
    LD A,D
    CALL psg_write
    INC D
    LD A,(audio_high)
    LD E,A
    LD A,D
    CALL psg_write
    LD A,(audio_volume)
    LD E,A
    LD A,(audio_mapped_channel)
    ADD A,8
    JP psg_write
note_scc:
    LD A,(audio_channel)
    CP 5
    RET NC
    LD HL,scc_period
    CALL get_pitch
    LD A,(audio_channel)
    ADD A,A
    ADD A,$80
    LD L,A
    LD H,$98
    LD A,(audio_low)
    LD (HL),A
    INC HL
    LD A,(audio_high)
    LD (HL),A
    LD A,(audio_channel)
    ADD A,$8a
    LD L,A
    LD A,(audio_volume)
    LD (HL),A
    RET
note_opll:
    LD A,(audio_channel)
    LD E,A
    LD D,0
    LD HL,opll_instruments
    ADD HL,DE
    LD A,(HL)
    LD B,A
    LD A,(audio_volume)
    XOR 15
    OR B
    LD E,A
    LD A,(audio_channel)
    ADD A,$30
    CALL opll_write
    LD A,(audio_retrigger)
    OR A
    RET Z
    LD E,0
    LD A,(audio_channel)
    ADD A,$20
    CALL opll_write
    LD A,(audio_note)
    OR A
    RET Z
    LD HL,opll_pitch
    CALL get_pitch
    LD A,(audio_low)
    LD E,A
    LD A,(audio_channel)
    ADD A,$10
    CALL opll_write
    LD A,(audio_high)
    LD E,A
    LD A,(audio_channel)
    ADD A,$20
    JP opll_write
note_opl:
    LD A,(audio_channel)
    LD E,A
    LD D,0
    LD HL,opl_slots
    ADD HL,DE
    LD A,(HL)
    ADD A,$43
    LD D,A
    LD A,(audio_volume)
    XOR 15
    LD E,A
    ADD A,A
    ADD A,E
    ADD A,8
    LD E,A
    LD A,D
    CALL opl_write
    LD A,(audio_retrigger)
    OR A
    RET Z
    LD E,0
    LD A,(audio_channel)
    ADD A,$b0
    CALL opl_write
    LD A,(audio_note)
    OR A
    RET Z
    LD HL,opl_pitch
    CALL get_pitch
    LD A,(audio_low)
    LD E,A
    LD A,(audio_channel)
    ADD A,$a0
    CALL opl_write
    LD A,(audio_high)
    LD E,A
    LD A,(audio_channel)
    ADD A,$b0
    JP opl_write

note_pcm:
    LD A,(audio_retrigger)
    OR A
    JP Z,.level
    LD E,0
    LD A,(audio_channel)
    ADD A,$68
    CALL pcm_write
    LD A,(audio_note)
    OR A
    RET Z
    LD L,A
    LD H,0
    ADD HL,HL
    PUSH HL
    ADD HL,HL
    ADD HL,HL
    POP DE
    ADD HL,DE
    PUSH HL
    LD A,(audio_channel)
    ADD A,A
    LD E,A
    LD D,0
    LD HL,pcm_table_addresses
    ADD HL,DE
    LD E,(HL)
    INC HL
    LD D,(HL)
    POP HL
    ADD HL,DE
    PUSH HL
    POP IY
    LD E,(IY+1)
    LD A,(audio_channel)
    ADD A,$20
    CALL pcm_write
    LD A,(audio_channel)
    LD E,A
    LD D,0
    LD HL,pcm_lastwave
    ADD HL,DE
    LD A,(IY+0)
    CP (HL)
    JR Z,.samewave
    LD (HL),A
    LD E,A
    LD A,(audio_channel)
    ADD A,8
    CALL pcm_write
.load:
    IN A,($c4)
    AND 2
    JR NZ,.load
.samewave:
    LD E,(IY+2)
    LD A,(audio_channel)
    ADD A,$38
    CALL pcm_write
    LD E,(IY+3)
    LD A,(audio_channel)
    ADD A,$98
    CALL pcm_write
    LD E,(IY+4)
    LD A,(audio_channel)
    ADD A,$b0
    CALL pcm_write
    LD E,(IY+5)
    LD A,(audio_channel)
    ADD A,$c8
    CALL pcm_write
    LD E,(IY+6)
    LD A,(audio_channel)
    ADD A,$e0
    CALL pcm_write
    LD E,(IY+7)
    LD A,(audio_channel)
    ADD A,$80
    CALL pcm_write
.level:
    LD A,(audio_volume)
    XOR 15
    ADD A,A
    ADD A,A
    ADD A,24
    ADD A,A
    OR 1
    LD E,A
    LD A,(audio_channel)
    ADD A,$50
    CALL pcm_write
    LD A,(audio_retrigger)
    OR A
    RET Z
    LD E,$80
    LD A,(audio_channel)
    ADD A,$68
    JP pcm_write

psg_write:
    PUSH AF
    OUT ($a0),A
    LD A,E
    OUT ($a1),A
    POP AF
    RET
opll_write:
    PUSH AF
    PUSH BC
    OUT ($7c),A
    NOP
    NOP
    LD A,E
    OUT ($7d),A
    LD B,8
.delay:
    DJNZ .delay
    POP BC
    POP AF
    RET
opl_write:
    PUSH AF
    PUSH BC
    OUT ($c0),A
    LD B,8
.addr:
    DJNZ .addr
    LD A,E
    OUT ($c1),A
    LD B,8
.data:
    DJNZ .data
    POP BC
    POP AF
    RET
pcm_write:
    PUSH AF
    PUSH BC
    PUSH DE
    LD D,A
.ready:
    IN A,($c4)
    AND 1
    JR NZ,.ready
    LD A,D
    OUT ($7e),A
    NOP
    NOP
    LD A,E
    OUT ($7f),A
    POP DE
    POP BC
    POP AF
    RET

audio_select:
    CP 5
    RET NC
    PUSH AF
    CALL audio_silence
    POP AF
    LD B,A
    LD E,A
    LD D,0
    LD HL,bit_masks
    ADD HL,DE
    LD A,(audio_caps)
    AND (HL)
    LD A,B
    JR NZ,.available
    XOR A
.available:
    LD (audio_mode),A
    OR A
    JR Z,.psg
    DEC A
    JR Z,.scc
    DEC A
    JR Z,.opll
    DEC A
    JR Z,.opl
    LD A,5
    OUT ($c6),A
    LD A,3
    OUT ($c7),A
    LD A,2
    LD E,0
    CALL pcm_write
    LD A,$f9
    LD E,0
    CALL pcm_write
    JR .force
.opl:
    CALL audio_init_opl
    JR .force
.opll:
    LD B,6
    LD D,$20
.muteopll:
    LD A,D
    LD E,0
    CALL opll_write
    INC D
    DJNZ .muteopll
    JR .force
.scc:
    CALL audio_map_scc
    LD A,63
    LD ($9000),A
    LD HL,scc_waves
    LD DE,$9800
    LD BC,128
    LDIR
    LD A,31
    LD ($988f),A
    CALL audio_map_cart
.psg:
    LD A,7
    LD E,$b8
    CALL psg_write
.force:
    LD HL,music_previous
    LD DE,music_previous+1
    LD BC,15
    LD (HL),$ff
    LDIR
    LD HL,pcm_lastwave
    LD DE,pcm_lastwave+1
    LD BC,5
    LD (HL),$ff
    LDIR
    LD A,1
    LD (audio_dirty),A
    RET

audio_silence:
    LD A,8
    LD E,0
    CALL psg_write
    INC A
    CALL psg_write
    INC A
    CALL psg_write
    LD A,(audio_mode)
    OR A
    RET Z
    CP 1
    JR Z,.scc
    LD B,6
    LD D,0
.voice:
    LD A,(audio_mode)
    CP 2
    JR Z,.opll
    CP 3
    JR Z,.opl
    LD A,D
    ADD A,$68
    LD E,$40
    PUSH DE
    CALL pcm_write
    POP DE
    JR .next
.opll:
    LD A,D
    ADD A,$20
    LD E,0
    CALL opll_write
    JR .next
.opl:
    LD A,D
    ADD A,$b0
    LD E,0
    CALL opl_write
.next:
    INC D
    DJNZ .voice
    RET
.scc:
    CALL audio_map_scc
    XOR A
    LD ($988f),A
    JP audio_map_cart

audio_init_opl:
    LD B,6
    LD IX,opl_slots
    LD C,0
.voice:
    LD D,(IX+0)
    LD A,D
    ADD A,$20
    LD E,$21
    CALL opl_write
    LD A,D
    ADD A,$40
    LD E,32
    CALL opl_write
    LD A,D
    ADD A,$60
    LD E,$f2
    CALL opl_write
    LD A,D
    ADD A,$80
    LD E,$24
    CALL opl_write
    LD A,D
    ADD A,$23
    LD E,$21
    CALL opl_write
    LD A,D
    ADD A,$43
    LD E,63
    CALL opl_write
    LD A,D
    ADD A,$63
    LD E,$f2
    CALL opl_write
    LD A,D
    ADD A,$83
    LD E,$14
    CALL opl_write
    LD A,C
    ADD A,$c0
    LD E,0
    CALL opl_write
    INC IX
    INC C
    DJNZ .voice
    RET

audio_map_scc:
    LD A,(scc_slot)
    LD H,$80
    CALL $0024
    DI
    RET
audio_map_cart:
    LD A,(cart_slot)
    LD H,$80
    CALL $0024
    DI
    RET

audio_detect:
    XOR A
    LD (scan_primary),A
.primary:
    XOR A
    LD (scan_sub),A
.slot:
    LD A,(scan_primary)
    LD E,A
    LD D,0
    LD HL,$fcc1
    ADD HL,DE
    LD A,(HL)
    AND $80
    LD B,A
    LD A,(scan_sub)
    RLCA
    RLCA
    OR B
    OR E
    LD (scan_slot),A
    LD H,$80
    CALL $0024
    DI
    LD A,($9000)
    LD (scan_bank_value),A
    LD A,($9800)
    LD (scan_value),A
    LD A,63
    LD ($9000),A
    LD A,$55
    LD ($9800),A
    LD A,($9900)
    CP $55
    JR NZ,.not_scc
    LD A,$aa
    LD ($9800),A
    LD A,($9900)
    CP $aa
    JR NZ,.not_scc
    LD A,(scan_slot)
    LD (scc_slot),A
    LD A,(audio_caps)
    OR 2
    LD (audio_caps),A
.not_scc:
    LD A,(scan_value)
    LD ($9800),A
    LD A,(scan_bank_value)
    LD ($9000),A
    CALL audio_map_cart
    LD HL,$401c
    LD IX,opll_signature
    LD B,4
.signature:
    LD A,(scan_slot)
    PUSH BC
    CALL $000c
    DI
    POP BC
    CP (IX+0)
    JR NZ,.nextslot
    INC HL
    INC IX
    DJNZ .signature
    LD A,(scan_slot)
    LD HL,$7ff6
    LD E,1
    CALL $0014
    DI
    LD A,(audio_caps)
    OR 4
    LD (audio_caps),A
.nextslot:
    LD A,(scan_primary)
    LD E,A
    LD D,0
    LD HL,$fcc1
    ADD HL,DE
    BIT 7,(HL)
    JR Z,.nextprimary
    LD A,(scan_sub)
    INC A
    LD (scan_sub),A
    CP 4
    JP C,.slot
.nextprimary:
    LD A,(scan_primary)
    INC A
    LD (scan_primary),A
    CP 4
    JP C,.primary
    IN A,($c0)
    AND $f9
    JR NZ,.opl4
    LD A,7
    LD E,$80
    CALL opl_write
    IN A,($c0)
    AND $f9
    LD B,A
    LD A,7
    LD E,0
    CALL opl_write
    LD A,B
    CP 1
    JR NZ,.opl4
    LD A,(audio_caps)
    OR 8
    LD (audio_caps),A
.opl4:
    LD A,2
    OUT ($7e),A
    NOP
    NOP
    IN A,($7f)
    AND $e0
    CP $20
    JR NZ,.end
    LD A,(audio_caps)
    OR 16
    LD (audio_caps),A
.end:
    RET

audio_poll:
    LD A,6
    CALL $0141
    CPL
    AND $e0
    LD B,A
    LD A,7
    PUSH BC
    CALL $0141
    POP BC
    CPL
    AND 3
    OR B
    LD C,A
    LD A,(audio_keys)
    CP C
    RET Z
    LD A,C
    LD (audio_keys),A
    OR A
    RET Z
    BIT 5,A
    LD A,0
    JR NZ,.choose
    LD A,C
    BIT 6,A
    LD A,1
    JR NZ,.choose
    LD A,C
    BIT 7,A
    LD A,2
    JR NZ,.choose
    LD A,C
    BIT 0,A
    LD A,3
    JR NZ,.choose
    LD A,4
.choose:
    DI
    CALL audio_select
    EI
    RET

audio_sfx:
    LD (fx_type),A
    LD A,10
    LD (fx_life),A
    RET
audio_fx_tick:
    LD A,(fx_life)
    OR A
    RET Z
    DEC A
    LD (fx_life),A
    JR NZ,.play
    LD E,0
    LD A,8
    CALL psg_write
    LD A,7
    LD E,$b8
    CALL psg_write
    LD A,1
    LD (audio_dirty),A
    LD A,$ff
    LD (music_previous+2),A
    RET
.play:
    LD B,A
    LD A,(fx_type)
    CP 1
    JR NZ,.noise
    LD A,B
    CPL
    ADD A,160
    LD E,A
    XOR A
    CALL psg_write
    LD A,1
    LD E,0
    CALL psg_write
    LD A,7
    LD E,$b8
    CALL psg_write
    JR .volume
.noise:
    LD A,B
    ADD A,10
    LD E,A
    LD A,6
    CALL psg_write
    LD A,7
    LD E,$b1
    CALL psg_write
.volume:
    LD E,B
    LD A,8
    JP psg_write

bit_masks: DB 1,2,4,8,16,32
psg_channel_map: DB 1,2,0
opll_instruments: DB $70,$e0,$40,$70,$80,$d0
opl_slots: DB 0,1,2,8,9,10
opll_signature: DB "OPLL"
pcm_table_addresses: DW $d000,$d500,$da00,$d000,$d500,$da00
scc_waves: INCBIN "audio/scc-waves.bin"
    INCLUDE "audio/tables.asm"
