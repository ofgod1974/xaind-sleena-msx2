; Four sprite bitplanes reproduce the SCREEN 5 player palette exactly.
; A raster split gives HUD and playfield separate 32-entry sprite tables.
player_old_keyi EQU $c3a0
player_raster_phase EQU $c3a5
player_last_pose EQU $c3a6
player_scroll_reg EQU $c3a7
player_raster_enabled EQU $c3a8
player_line_count EQU $c3a9
player_base_x EQU $c3aa
player_base_y EQU $c3ab
player_wide EQU $c3ac
player_pose EQU $c3ad
player_display_page EQU $c3ae
player_sat EQU $cb00

player_sprite_init:
    DI
    LD A,(back)
    PUSH AF
    LD A,3
    LD (back),A
    CALL blankcmd
    LD HL,256
    LD (cmd+8),HL
    LD HL,24
    LD (cmd+10),HL
    LD A,$c0
    LD (cmd+14),A
    CALL docmd
    CALL blankcmd
    LD A,184
    LD (cmd+6),A
    LD HL,256
    LD (cmd+8),HL
    LD HL,8
    LD (cmd+10),HL
    LD A,$c0
    LD (cmd+14),A
    CALL docmd
    CALL waitvdp
    POP AF
    LD (back),A
    LD A,31
    LD (player_display_page),A
    LD A,(mapper_bank)
    PUSH AF
    LD A,112
    CALL select_bank
    LD HL,player_color_data
    LD DE,$2000
    LD BC,512
    CALL hud_upload
    POP AF
    CALL select_bank
    LD HL,player_sat
    LD DE,player_sat+1
    LD BC,127
    LD (HL),0
    LDIR
    LD A,216
    LD (player_sat),A
    LD HL,player_sat
    LD DE,$2200
    LD BC,128
    CALL hud_upload
    DI
    LD HL,$e000
    LD DE,$e001
    LD BC,256
    LD (HL),$e2
    LDIR
    LD A,$c3
    LD ($e2e2),A
    LD HL,player_line_irq
    LD ($e2e3),HL
    LD A,$e0
    LD I,A
    IM 2
    XOR A
    LD (player_raster_phase),A
    LD (player_scroll_reg),A
    LD (player_line_count),A
    LD A,255
    LD (player_last_pose),A
    LD A,1
    LD (player_raster_enabled),A
    CALL player_raster_vblank
    LD A,($f3df)
    OR $10
    LD ($f3df),A
    OUT ($99),A
    LD A,$80
    OUT ($99),A
    EI
    RET

player_line_irq:
    PUSH AF
    PUSH BC
    LD A,1
    OUT ($99),A
    LD A,$8f
    OUT ($99),A
    IN A,($99)
    LD B,A
    XOR A
    OUT ($99),A
    LD A,$8f
    OUT ($99),A
    BIT 0,B
    JR Z,.bios
    LD A,(player_line_count)
    INC A
    LD (player_line_count),A
    LD A,(player_raster_phase)
    OR A
    JR NZ,.footer
    INC A
    LD (player_raster_phase),A
    LD A,(player_display_page)
    OUT ($99),A
    LD A,$82
    OUT ($99),A
    LD A,$47
    OUT ($99),A
    LD A,$85
    OUT ($99),A
    LD A,(player_scroll_reg)
    OUT ($99),A
    LD A,$97
    OUT ($99),A
    LD A,(player_scroll_reg)
    ADD A,181
    JR .line
.footer:
    XOR A
    LD (player_raster_phase),A
    LD A,$7f
    OUT ($99),A
    LD A,$82
    OUT ($99),A
    LD A,$57
    OUT ($99),A
    LD A,$85
    OUT ($99),A
    XOR A
    OUT ($99),A
    LD A,$97
    OUT ($99),A
    LD A,21
.line:
    OUT ($99),A
    LD A,$93
    OUT ($99),A
.done:
    POP BC
    POP AF
    EI
    RETI
.bios:
    POP BC
    POP AF
    JP $0038

player_raster_vblank:
    LD A,(player_raster_enabled)
    OR A
    RET Z
    LD A,$7f
    OUT ($99),A
    LD A,$82
    OUT ($99),A
    LD A,$57
    OUT ($99),A
    LD A,$85
    OUT ($99),A
    XOR A
    OUT ($99),A
    LD A,$97
    OUT ($99),A
    XOR A
    LD (player_raster_phase),A
    LD A,21
    OUT ($99),A
    LD A,$93
    OUT ($99),A
    RET
player_raster_scroll:
    LD A,(scroll_y)
    NEG
    LD (player_scroll_reg),A
    JP player_raster_vblank

player_sprite_update:
    LD A,(stance)
    CP 2
    LD A,12
    JR Z,.facing
    LD A,(stance)
    OR A
    LD A,10
    JR NZ,.facing
    LD A,(shoot_pose)
    OR A
    LD A,8
    JR NZ,.facing
    LD A,(walking)
    OR A
    JR Z,.walkface
    LD A,(ticks)
    RRCA
    RRCA
    AND 3
.walkface:
    LD B,A
    LD A,(face)
    OR A
    LD A,B
    JR Z,.pose
    ADD A,4
    JR .pose
.facing:
    LD B,A
    LD A,(face)
    OR A
    LD A,B
    JR Z,.pose
    INC A
.pose:
    LD (player_pose),A
    CP 12
    LD A,0
    JR C,.narrow
    INC A
.narrow:
    LD (player_wide),A
.position:
    LD A,(player_wide)
    OR A
    LD A,(px)
    JR Z,.x
    SUB 8
.x:
    CALL compensate_x
    LD (player_base_x),A
    LD A,(py)
    LD B,A
    LD A,(player_wide)
    OR A
    LD A,B
    JR Z,.y
    ADD A,16
.y:
    DEC A
    CP 216
    JR Z,.avoid_end
    LD B,A
    LD A,(player_wide)
    OR A
    LD A,B
    JR NZ,.base_y
    CP 200
    JR NZ,.base_y
.avoid_end:
    INC A
.base_y:
    LD (player_base_y),A
    LD A,(shield)
    OR A
    JR Z,.show
    LD A,(ticks)
    AND 4
    JR NZ,.hide
.show:
    LD IX,player_sat
    LD B,8
    LD C,44
.each:
    LD A,(player_base_y)
    LD (IX+0),A
    LD A,(player_base_x)
    LD (IX+1),A
    LD A,B
    CP 5
    JR NC,.first
    LD A,(player_wide)
    OR A
    JR NZ,.right
    LD A,(IX+0)
    ADD A,16
    LD (IX+0),A
    JR .first
.right:
    LD A,(IX+1)
    ADD A,16
    LD (IX+1),A
.first:
    LD (IX+2),C
    LD (IX+3),0
    LD A,C
    ADD A,4
    LD C,A
    LD DE,4
    ADD IX,DE
    DJNZ .each
    JR .masks
.hide:
    LD IX,player_sat
    LD A,(scroll_y)
    LD B,A
    LD A,208
    SUB B
    LD B,8
.hidden:
    LD (IX+0),A
    LD DE,4
    ADD IX,DE
    DJNZ .hidden
.masks:
    LD HL,sat+44
    LD DE,player_sat+32
    LD BC,80
    LDIR
    LD IX,player_sat+32
    LD B,20
    LD A,(scroll_y)
    LD C,A
.edge_y:
    LD A,(IX+0)
    SUB C
    CP 216
    JR NZ,.edge_store
    INC A
.edge_store:
    LD (IX+0),A
    LD DE,4
    ADD IX,DE
    DJNZ .edge_y
    LD A,216
    LD (player_sat+112),A
    RET

player_sprite_upload:
    LD A,(player_pose)
    LD B,A
    LD A,(player_last_pose)
    CP B
    JR Z,.attributes
    LD A,(mapper_bank)
    PUSH AF
    LD A,112
    CALL select_bank
    LD A,(player_pose)
    ADD A,$80
    LD H,A
    LD L,0
    LD DE,$3160
    LD BC,256
    CALL hud_upload
    POP AF
    CALL select_bank
    LD A,(player_pose)
    LD (player_last_pose),A
.attributes:
    LD HL,player_sat
    LD DE,$2200
    LD BC,113
    JP hud_upload
