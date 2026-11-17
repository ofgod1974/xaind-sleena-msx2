; Coarse vertical camera: move both 240x160 backing fields in VRAM.
; Fine displacement uses R#23, 0..7 lines. Atlas stays at page 1 y192.
vertical_update:
    LD A,($c941)
    AND $f8
    LD B,A
    LD A,(vertical_coarse)
    CP B
    RET Z
    LD (vertical_old),A
    LD A,B
    LD (vertical_coarse),A
    LD A,(back)
    PUSH AF
    XOR A
    LD (back),A
    CALL .page
    LD A,1
    LD (back),A
    CALL .page
    POP AF
    LD (back),A
    RET
.page:
    CALL blankcmd
    LD A,(back)
    LD (cmd+3),A
    LD (cmd+7),A
    LD A,8
    LD (cmd),A
    LD (cmd+4),A
    LD HL,240
    LD (cmd+8),HL
    LD A,(vertical_old)
    LD B,A
    LD A,(vertical_coarse)
    SUB B
    JR C,.up
    LD (vertical_delta),A
    LD B,A
    LD A,160
    SUB B
    LD (cmd+10),A
    LD A,183
    LD (cmd+6),A
    SUB B
    LD (cmd+2),A
    LD A,8
    LD (cmd+13),A
    LD A,24
    JR .strip
.up:
    NEG
    LD (vertical_delta),A
    LD B,A
    LD A,160
    SUB B
    LD (cmd+10),A
    LD A,24
    LD (cmd+6),A
    ADD A,B
    LD (cmd+2),A
    LD A,184
    SUB B
.strip:
    PUSH AF
    CALL docmd
    CALL waitvdp
    POP AF
    LD (rowy),A
    LD A,(vertical_delta)
    LD (rowcount),A
    LD A,8
    LD (savedx),A
    LD A,240
    LD (savedwidth),A
    LD HL,(camera)
    LD A,L
    AND $f0
    LD L,A
    LD A,(back)
    LD B,A
    LD A,(render_target) ; visible page is the current back after x preparation
    LD A,(back)
    ; Caller saved visible page on stack; use render-visible latch instead.
    LD A,(vertical_visible)
    CP B
    JR Z,.world
    LD DE,16
    ADD HL,DE
.world:
    LD (level_source_x),HL
    JP level_copy_rect

vertical_black_row:
    LD A,(rowy)
    RLCA
    RLCA
    AND 3
    LD E,A
    LD A,(back)
    RLCA
    RLCA
    OR E
    OUT ($99),A
    LD A,$8e
    OUT ($99),A
    LD A,(savedx)
    OUT ($99),A
    LD A,(rowy)
    AND 63
    OR $40
    OUT ($99),A
    LD A,(savedwidth)
    LD B,A
    XOR A
    EI
.zero:
    OUT ($98),A
    NOP
    DJNZ .zero
    RET
vertical_visible EQU $c08c
