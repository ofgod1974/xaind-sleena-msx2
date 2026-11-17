; Xain MSX2: first playable conversion study.
; Assemble with sjasmplus --raw=../xain-msx2.rom game.asm
; SCREEN 8 / V9938, 128K VRAM, standard Z80, 1 MiB ASCII16 cartridge.
    ORG $4000
    DB "AB"
    DW start,0,0,0,0,0,0
audio_config: DB 0,6
gameplay_config: DB 0 ; optional weapon test, normal weapon in the distributed ROM

level_source_x EQU $c080
vertical_coarse EQU $c083
vertical_old EQU $c084
vertical_delta EQU $c085
vertical_source_y EQU $c086
render_camera EQU $c088
render_target EQU $c08a
level_pair_phase EQU $c082

px EQU $c000
py EQU $c001
vy EQU $c002
air EQU $c003
ticks EQU $c004
camera EQU $c005
back EQU $c007
ex EQU $c008
enemy EQU $c009
bx EQU $c00a
bullet EQU $c00b
cool EQU $c00c
hp EQU $c00d
shield EQU $c00e
score EQU $c00f
state EQU $c010
joy EQU $c011
ebx EQU $c012
eb EQU $c013
face EQU $c014
bface EQU $c015
walking EQU $c016
snd EQU $c017
fire EQU $c018
by EQU $c019
lastcamera EQU $c01a
laststate EQU $c01b
headerdirty EQU $c01c
footerdirty EQU $c01d
oldhp EQU $c01e
oldscore EQU $c01f
restartarmed EQU $c020
jumpheld EQU $c021
jumpcount EQU $c022
streambank EQU $c030
finephase EQU $c031
lastphase EQU $c032
worldbase EQU $c033
preparedphase EQU $c034
engineinit EQU $c035
cpusrcx EQU $c036
rowy EQU $c037
rowcount EQU $c038
firstcount EQU $c039
secondcount EQU $c03a
savedx EQU $c03c
savedwidth EQU $c03e
previous_player EQU $c040
previous_enemy EQU $c044
previous_bullet EQU $c048
previous_eb EQU $c04c
sat EQU $c200
cmd EQU $c100

start:
    DI
    LD SP,$f380
    ; Map cartridge's page-1 slot into page 2 too, including expanded slots.
    CALL $0138
    RRCA
    RRCA
    AND 3
    LD C,A
    LD B,0
    LD HL,$fcc1
    ADD HL,BC
    LD A,(HL)
    AND $80
    OR C
    LD C,A
    INC HL
    INC HL
    INC HL
    INC HL
    LD A,(HL)
    AND $0c
    OR C
    LD ($c3f0),A
    LD H,$80
    CALL $0024
    XOR A
    LD ($f3ea),A
    LD ($f3eb),A
    LD A,15
    LD ($f3e9),A
    LD A,8
    CALL $005f
    DI
    ; SCREEN 8, 192 lines, bitmap actors with the original arcade palettes.
    LD A,($ffe8)
    AND 2
    OUT ($99),A
    LD A,$89
    OUT ($99),A
    LD A,40 ; R#8: TP + VR (64K DRAM organization) preserved
    OUT ($99),A
    LD A,$88
    OUT ($99),A
    LD A,$62
    OUT ($99),A
    LD A,$81
    OUT ($99),A
    XOR A
    OUT ($99),A
    LD A,$90
    OUT ($99),A
    LD HL,palette
    LD BC,$209a
    OTIR
    XOR A
    LD ($6000),A
    LD A,1
    CALL select_bank
    LD (streambank),A
    LD HL,$8000
    LD A,4
    CALL upload
    LD A,7
    CALL upload
    LD A,26
    OUT ($99),A
    LD A,$86
    OUT ($99),A
    LD A,$97
    OUT ($99),A
    LD A,$85
    OUT ($99),A
    LD HL,hud_patterns
    LD DE,$1000
    LD BC,hud_patterns_end-hud_patterns
    CALL hud_upload
    LD HL,hud_colors
    LD DE,$0800
    LD BC,512
    CALL hud_upload
    XOR A
    LD (vertical_coarse),A
    LD (render_camera),A
    LD (render_camera+1),A
    XOR A
    LD ($c942),A
    LD ($c943),A
    LD ($c949),A
    LD (score_cache_valid),A
    CALL reset
    CALL audio_init
    CALL front_end
main:
    EI
    LD A,(ticks)
    INC A
    LD (ticks),A
    CALL audio_poll
    CALL trainer_poll
    CALL c_input
    LD A,(state)
    OR A
    JR Z,.playing
    LD A,(fire)
    OR A
    JR NZ,.checkcool
    LD A,1
    LD (restartarmed),A
.checkcool:
    LD A,(cool)
    OR A
    JR Z,.canrestart
    DEC A
    LD (cool),A
    JR .draw
.canrestart:
    LD A,(restartarmed)
    OR A
    JR Z,.draw
    LD A,(fire)
    OR A
    CALL NZ,reset
    JR .draw
.playing:
    CALL update
    LD A,(ticks)
    INC A
    LD (ticks),A
    CALL update
.draw:
    CALL render
    JP main

reset:
    CALL gameplay_init
    XOR A
    LD (jumpheld),A
    LD (jumpcount),A
    LD (engineinit),A
    LD (restartarmed),A
    LD HL,previous_player
    LD DE,previous_player+1
    LD BC,15
    LD (HL),0
    LDIR
    LD HL,px
    LD DE,px+1
    LD BC,31
    LD (HL),0
    LDIR
    LD A,32
    LD (px),A
    LD A,128
    LD (py),A
    LD A,16
    LD (hp),A
    LD A,224
    LD (ex),A
    LD A,1
    LD (enemy),A
    XOR A
    LD (back),A
    DEC A
    LD (lastcamera),A
    LD (laststate),A
    LD (oldhp),A
    LD (oldscore),A
    LD A,1
    LD (headerdirty),A
    LD (footerdirty),A
    LD HL,$8006
    JP c_call

update:
    LD HL,$8003
    JR c_call
c_input:
    LD HL,$8000
c_call:
    LD A,(mapper_bank)
    PUSH AF
    LD A,3
    CALL select_bank
    CALL .invoke
    POP AF
    JP select_bank
.invoke:
    JP (HL)
c_sfx:
    LD A,($c900)
    JP audio_sfx

; Upload RLE (count,value) terminated by count=0 to a 16 KiB-aligned VRAM address.
upload:
    DI
    OUT ($99),A
    LD A,$8e
    OUT ($99),A
    XOR A
    OUT ($99),A
    LD A,$40
    OUT ($99),A
    EI
.next:
    CALL streambyte
    LD B,A
    LD A,B
    OR A
    RET Z
    CALL streambyte
.run:
    OUT ($98),A
    NOP
    DJNZ .run
    JR .next

streambyte:
    LD A,(HL)
    INC HL
    PUSH AF
    LD A,H
    CP $c0
    JR NZ,.ok
    LD HL,$8000
    LD A,(streambank)
    INC A
    LD (streambank),A
    CALL select_bank
.ok:
    POP AF
    RET

read_status2:
    DI
    LD A,2
    OUT ($99),A
    LD A,$8f
    OUT ($99),A
    IN A,($99)
    PUSH AF
    XOR A
    OUT ($99),A
    LD A,$8f
    OUT ($99),A
    POP AF
    EI
    RET
waitvdp:
    CALL read_status2
    AND 1
    JR NZ,waitvdp
    RET

docmd:
    PUSH AF
    PUSH BC
    PUSH DE
    PUSH HL
    CALL waitvdp
    DI
    LD A,32
    OUT ($99),A
    LD A,$91
    OUT ($99),A
    LD HL,cmd
    LD BC,$0f9b
    OTIR
    EI
    POP HL
    POP DE
    POP BC
    POP AF
    RET

blankcmd:
    LD HL,cmd
    LD DE,cmd+1
    LD BC,14
    LD (HL),0
    LDIR
    LD A,(back)
    LD (cmd+7),A
    LD A,$d0
    LD (cmd+14),A
    RET

; V9938 horizontal scrolling: 16 fine phases, fifteen 16x160 slices per coarse step.
; SCREEN 8 pages 0/1 alternate. A 240-pixel backing field and fixed sprite masks
; yield a stable 224-pixel viewport; the eight-pixel VRAM gutters remain black.
render:
    CALL waitvdp
    LD A,(engineinit)
    OR A
    CALL Z,scroll_init
    LD A,(back)
    LD (render_old_back),A
    CALL scroll_pipeline
    LD A,(camera)
    LD B,A
    LD A,(render_camera)
    LD C,A
    LD A,B
    SUB C
    LD (finephase),A
    LD (lastphase),A
    LD A,(render_old_back)
    LD B,A
    LD A,(back)
    CP B
    CALL Z,restore_actors
    CALL update_hud
    CALL bitmap_actors
    CALL status_overlay
    ; Present all registers at the start of a fresh VBlank.
    CALL sync_scroll
    LD A,(back)
    RRCA
    RRCA
    RRCA
    OR 31
    OUT ($99),A
    LD A,$82
    OUT ($99),A
    LD A,(finephase)
    ADD A,8
    AND 15
    OUT ($99),A
    LD A,$92
    OUT ($99),A
    LD A,(scroll_y)
    LD B,A
    LD A,(vertical_coarse)
    SUB B
    OUT ($99),A
    LD A,$97
    OUT ($99),A
    RET
status_overlay:
    LD A,(state)
    OR A
    RET Z
    LD HL,status_clear
    CP 2
    JR NZ,.image
    LD HL,status_gameover
.image:
    LD A,80
    LD (rowy),A
    LD A,8
    LD (rowcount),A
.row:
    DI
    LD A,(rowy)
    RLCA
    RLCA
    AND 3
    LD B,A
    LD A,(back)
    RLCA
    RLCA
    OR B
    OUT ($99),A
    LD A,$8e
    OUT ($99),A
    LD A,72
    CALL compensate_x
    OUT ($99),A
    LD A,(rowy)
    AND 63
    OR $40
    OUT ($99),A
    LD BC,$6898
    EI
    OTIR
    LD A,(rowy)
    INC A
    LD (rowy),A
    LD A,(rowcount)
    DEC A
    LD (rowcount),A
    JR NZ,.row
    RET
status_clear: INCBIN "status-clear.bin"
status_gameover: INCBIN "status-gameover.bin"

scroll_init:
    XOR A
    LD (vertical_coarse),A
    LD A,1
    CALL select_bank
    LD (streambank),A
    LD HL,$8000
    LD A,4
    CALL upload
    XOR A
    LD (back),A
    LD (worldbase),A
    LD (finephase),A
    DEC A
    LD (lastphase),A
    LD (preparedphase),A
    LD (level_pair_phase),A
    CALL blankcmd
    LD A,216
    LD (cmd+6),A
    LD HL,256
    LD (cmd+8),HL
    LD HL,40
    LD (cmd+10),HL
    LD A,$c0
    LD (cmd+14),A
    CALL docmd
    CALL waitvdp
    CALL blankcmd
    LD A,1
    LD (cmd+3),A
    LD HL,256
    LD (cmd+8),HL
    LD HL,192
    LD (cmd+10),HL
    CALL docmd
    CALL waitvdp
    LD HL,(camera)
    LD A,L
    AND $f0
    LD L,A
    LD (render_camera),HL
    LD A,($c941)
    AND $f8
    LD (vertical_coarse),A
    LD HL,(camera)
    LD A,H
    OR L
    LD B,A
    LD A,($c941)
    OR B
    CALL NZ,checkpoint_bitmap
    LD A,(camera)
    AND 15
    LD (finephase),A
    XOR A
    LD (build_active),A
    LD (build_group),A
    LD A,($c941)
    LD (scroll_y),A
    LD A,1
    LD (engineinit),A
    RET

sync_render_scroll:
    CALL read_status2
    BIT 6,A
    JR Z,sync_render_scroll
    DI
    IN A,($99)
    RET

sync_scroll:
.active:
    CALL read_status2
    BIT 6,A
    JR NZ,.active
.blank:
    CALL read_status2
    BIT 6,A
    JR Z,.blank
    DI
    IN A,($99)
    RET

slice_hits_actors:
    LD A,(finephase)
    CP 15
    RET Z
    RLCA
    RLCA
    RLCA
    RLCA
    ADD A,24
    CP 248
    JR C,.sourceok
    SUB 240
.sourceok:
    LD ($c03d),A
    LD A,(px)
    CALL .hit
    RET C
    LD A,(enemy)
    OR A
    JR Z,.bullet
    LD A,(ex)
    CALL .hit
    RET C
.bullet:
    LD A,(bullet)
    OR A
    JR Z,.enemybullet
    LD A,(bx)
    CALL .hit
    RET C
.enemybullet:
    LD A,(eb)
    OR A
    RET Z
    LD A,(ebx)
    JP .hit
.hit:
    CALL compensate_x
    LD B,A
    LD A,($c03d)
    SUB B
    ADD A,15
    CP 31
    RET

; One-pixel phases. Stream only 10 hidden rows per frame instead of a
; 160-row burst every eighth update. No upload is made to the visible page.
prepare_level_slices:
    LD A,(finephase)
    LD B,A
    LD A,(level_pair_phase)
    CP B
    RET Z
    LD A,B
    LD (level_pair_phase),A
    CALL prepare_slice
    JP level_incoming_rows

prepare_slice:
    LD A,(finephase)
    LD B,A
    LD A,(preparedphase)
    CP B
    RET Z
    LD A,B
    LD (preparedphase),A
    CP 14
    RET NC
    RLCA
    RLCA
    RLCA
    RLCA
    ADD A,8
    PUSH AF
    CALL blankcmd
    POP AF
    LD (cmd+4),A
    ADD A,16
    CP 248
    JR C,.sourceok
    SUB 240
.sourceok:
    LD (cmd),A
    LD A,(back)
    LD (cmd+3),A
    XOR 1
    LD (cmd+7),A
    LD A,24
    LD (cmd+2),A
    LD (cmd+6),A
    LD A,160
    LD (cmd+10),A
    LD A,16
    LD (cmd+8),A
    JP docmd


restore_actors:
    LD IX,previous_player
    CALL restore_player
    LD IX,previous_enemy
    CALL restore_rect
    LD IX,previous_bullet
    CALL restore_rect
    LD IX,previous_eb
    CALL restore_rect
    JP restore_weapons

previous_player_source EQU $c0b3
; Keep an unchanged idle actor intact while the hardware camera moves.
restore_player:
    LD A,(air)
    LD B,A
    LD A,(shield)
    OR B
    LD B,A
    LD A,(stance)
    OR B
    LD B,A
    LD A,(walking)
    OR B
    LD B,A
    LD A,(shoot_pose)
    OR B
    JP NZ,restore_rect
    LD A,(IX+2)
    CP 16
    JP NZ,restore_rect
    LD A,(IX+3)
    CP 32
    JP NZ,restore_rect
    LD A,(face)
    RRCA
    LD B,A
    LD A,(previous_player_source)
    CP B
    JP NZ,restore_rect
    LD A,(px)
    CALL compensate_x
    CP (IX+0)
    JP NZ,restore_rect
    LD A,(vertical_coarse)
    LD B,A
    LD A,(py)
    ADD A,B
    CP (IX+1)
    JP NZ,restore_rect
    RET

; Restore the real level pixels, not a repeated 240-pixel canonical picture.
restore_rect:
    LD A,(IX+2)
    OR A
    RET Z
    LD (savedwidth),A
    LD A,(IX+0)
    LD (savedx),A
    SUB 8
    LD E,A
    LD D,0
    LD HL,(render_camera)
    ADD HL,DE
    LD (level_source_x),HL
    LD A,(IX+1)
    LD (rowy),A
    LD A,(IX+3)
    LD (rowcount),A
    JP level_copy_rect

; CPU-to-VRAM rectangular copy from a 4096-pixel-wide ROM raster.
; Four rows per 16 KiB ASCII16 bank. IRQ safely restores this bank.
level_copy_rect:
.row:
    DI
    LD A,(rowy)
    LD B,A
    LD A,(vertical_coarse)
    LD C,A
    LD A,B
    SUB C
    LD (vertical_source_y),A
    CP 24
    JR C,.blackrow
    CP 184
    JR NC,.blackrow
    RRCA
    RRCA
    AND 63
    ADD A,64
    CALL select_bank
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
    LD HL,(level_source_x)
    LD A,(vertical_source_y)
    AND 3
    RLCA
    RLCA
    RLCA
    RLCA
    OR H
    OR $80
    LD H,A
    LD A,(savedwidth)
    LD B,A
    LD C,$98
    EI
    OTIR
    JR .nextrow
.blackrow:
    CALL vertical_black_row
.nextrow:
    LD A,(rowy)
    INC A
    LD (rowy),A
    LD A,(rowcount)
    DEC A
    LD (rowcount),A
    JR NZ,.row
    RET

level_incoming_rows:
    CALL waitvdp
    LD A,(finephase)
    LD B,A
    ADD A,A
    ADD A,A
    ADD A,B
    ADD A,A
    ADD A,24
    LD (rowy),A
    LD A,10
    LD (rowcount),A
    JR level_incoming_common

; Full-column entry is used by the isolated transfer test, not the frame loop.
level_incoming_column:
    CALL waitvdp
    LD A,24
    LD (rowy),A
    LD A,160
    LD (rowcount),A
level_incoming_common:
    LD HL,(camera)
    LD A,L
    AND $f0
    LD L,A
    LD DE,240
    ADD HL,DE
    LD (level_source_x),HL
    LD A,232
    LD (savedx),A
    LD A,16
    LD (savedwidth),A
    LD A,(back)
    XOR 1
    LD (back),A
    CALL level_copy_rect
    LD A,(back)
    XOR 1
    LD (back),A
    RET

compensate_x:
    LD C,A
    LD A,(finephase)
    ADD A,C
    SUB 8
    RET

update_hud:
    LD HL,hud_positions
    LD IX,sat
    LD B,11
.sprite:
    LD A,(HL)
    INC HL
    LD (IX+0),A
    LD A,(HL)
    INC HL
    PUSH BC
    CALL compensate_x
    POP BC
    LD (IX+1),A
    LD A,(HL)
    INC HL
    LD (IX+2),A
    LD (IX+3),0
    LD DE,4
    ADD IX,DE
    DJNZ .sprite
    LD A,($c942)
    OR A
    LD A,58
    JR NZ,.lifetrainer
    LD A,(lives)
    ADD A,40
.lifetrainer:
    RLCA
    RLCA
    LD (sat+2),A
    LD A,(weapon)
    ADD A,50
    RLCA
    RLCA
    LD (sat+6),A
    LD A,(hp)
    INC A
    SRL A
    ADD A,A
    ADD A,22
    RLCA
    RLCA
    LD (sat+22),A
    ADD A,4
    LD (sat+26),A
    CALL upload_score
    LD IX,sat+44
    LD B,10
    LD D,23
.mask:
    LD (IX+0),D
    LD (IX+4),D
    LD A,(finephase)
    ADD A,24
    LD (IX+1),A
    LD A,(finephase)
    ADD A,232
    LD (IX+5),A
    LD (IX+2),84
    LD (IX+6),84
    LD (IX+3),0
    LD (IX+7),0
    LD DE,8
    ADD IX,DE
    LD A,(IX-8)
    ADD A,16
    LD D,A
    DJNZ .mask
    LD A,216
    LD (sat+124),A
    LD HL,sat
    LD DE,$0a00
    LD BC,125
    JP hud_upload

hud_upload:
    DI
    LD A,3
    OUT ($99),A
    LD A,$8e
    OUT ($99),A
    LD A,E
    OUT ($99),A
    LD A,D
    OR $40
    OUT ($99),A
    LD D,B
    LD E,C
    LD C,$98
    EI
    LD A,D
    OR A
    JR Z,.tail
.blocks:
    LD B,0
    OTIR
    DEC D
    JR NZ,.blocks
.tail:
    LD A,E
    OR A
    RET Z
    LD B,A
    OTIR
    RET

hud_positions:
    DB 7,16,0, 7,40,4, 7,104,8, 7,120,12, 7,136,16
    DB 5,148,20, 5,164,24, 183,174,220, 183,190,224
    DB 183,206,228, 209,222,44


bitmap_actors:
    XOR A
    LD (previous_player+2),A
    LD (previous_enemy+2),A
    LD (previous_bullet+2),A
    LD (previous_eb+2),A
    LD A,(enemy)
    OR A
    JR Z,.player
    CP 2
    JR Z,.smoke
    CALL actorcmd
    LD A,(ticks)
    AND 8
    RLCA
    ADD A,128
    LD (cmd),A
    JR .enemydest
.smoke:
    CALL actorcmd
    LD A,12
    LD B,A
    LD A,($c904)
    LD C,A
    LD A,B
    SUB C
    SRL A
    SRL A
    CP 3
    JR C,.smokeframe
    LD A,2
.smokeframe:
    RLCA
    RLCA
    RLCA
    RLCA
    LD (cmd),A
    LD A,240
    LD (cmd+2),A
    LD HL,8
    LD (cmd+10),HL
.enemydest:
    LD A,(ex)
    CALL compensate_x
    LD (cmd+4),A
    LD A,($c902)
    LD B,A
    LD A,(enemy)
    CP 2
    LD A,B
    JR NZ,.enemyy
    ADD A,10
.enemyy:
    LD (cmd+6),A
    CALL clip_actor
    JR C,.player
    CALL docmd
    LD HL,previous_enemy
    CALL remember_actor
.player:
    LD A,(shield)
    OR A
    JR Z,.drawplayer
    LD A,(ticks)
    AND 4
    JR NZ,draw_player_bullets
.drawplayer:
    CALL actorcmd
    LD A,(stance)
    CP 2
    JP Z,draw_prone
    CP 1
    JR NZ,.standing
    LD A,224
    JP draw_pose
.standing:
    LD A,(shoot_pose)
    OR A
    JR Z,.walkpose
    LD A,192
    JP draw_pose
.walkpose:
    LD A,(walking)
    OR A
    JR Z,.frame
    LD A,(ticks)
    RRCA
    RRCA
    AND 3
.frame:
    RLCA
    RLCA
    RLCA
    RLCA
    LD B,A
    LD A,(face)
    OR A
    LD A,B
    JR Z,.faceok
    ADD A,64
.faceok:
    LD (cmd),A
player_destination:
    LD A,(px)
    CALL compensate_x
    LD (cmd+4),A
    LD A,(py)
    LD (cmd+6),A
    CALL clip_actor
    JR C,draw_player_bullets
    CALL docmd
    LD HL,previous_player
    CALL remember_actor
draw_player_bullets:
    CALL draw_weapons
.enemybullet:
    LD A,(eb)
    OR A
    JR Z,.done
    CALL bulletcmd
    LD A,(ebx)
    CALL compensate_x
    LD (cmd+4),A
    LD A,($c903)
    LD (cmd+6),A
    CALL clip_actor
    JR C,.done
    CALL docmd
    LD HL,previous_eb
    CALL remember_actor
.done:
    JP waitvdp
remember_actor:
    LD A,(cmd+4)
    LD (HL),A
    INC HL
    LD A,(cmd+6)
    LD (HL),A
    INC HL
    LD A,(cmd+8)
    LD (HL),A
    INC HL
    LD A,(cmd+10)
    LD (HL),A
    RET
clip_actor:
    LD A,(cmd+6)
    LD B,A
    LD A,(vertical_coarse)
    ADD A,B
    LD (cmd+6),A
    ; Wrapped negative positions crop against the physical playing-field.
    CP 192
    JR NC,.above
    CP 24
    JR NC,.bottom
.above:
    LD B,A
    LD A,24
    SUB B
    LD B,A
    LD A,(cmd+10)
    SUB B
    JR C,.outside
    JR Z,.outside
    LD (cmd+10),A
    LD A,(cmd+2)
    ADD A,B
    LD (cmd+2),A
    LD A,24
    LD (cmd+6),A
.bottom:
    LD A,(cmd+6)
    LD B,A
    CP 184
    JR NC,.outside
    LD A,(cmd+10)
    ADD A,B
    CP 185
    JR C,.horizontal
    LD A,184
    SUB B
    LD (cmd+10),A
.horizontal:
    LD A,(cmd+4)
    CP 16
    JR C,.outside
    CP 240
    JR NC,.outside
    LD B,A
    LD A,(cmd+8)
    ADD A,B
    JR C,.outside
    CP 241
    CCF
    RET
.outside:
    SCF
    RET
actorcmd:
    CALL blankcmd
    LD A,1
    LD (cmd+3),A
    LD A,200
    LD (cmd+2),A
    LD HL,16
    LD (cmd+8),HL
    LD HL,32
    LD (cmd+10),HL
    LD A,$98
    LD (cmd+14),A
    RET
bulletcmd:
    CALL actorcmd
    XOR A
    LD (cmd),A
    LD A,232
    LD (cmd+2),A
    LD HL,11
    LD (cmd+8),HL
    LD HL,1
    LD (cmd+10),HL
    RET


zap:
    PUSH AF
    LD A,1
    CALL audio_sfx
    POP AF
    RET

draw_pose:
    LD B,A
    LD A,(face)
    OR A
    LD A,B
    JR Z,.right
    ADD A,16
.right:
    LD (cmd),A
    JP player_destination
draw_prone:
    LD A,128
    LD B,A
    LD A,(face)
    OR A
    LD A,B
    JR Z,.right
    ADD A,32
.right:
    LD (cmd),A
    LD A,224
    LD (cmd+2),A
    LD HL,32
    LD (cmd+8),HL
    LD HL,16
    LD (cmd+10),HL
    LD A,(px)
    SUB 8
    CALL compensate_x
    LD (cmd+4),A
    LD A,(py)
    ADD A,16
    LD (cmd+6),A
    CALL clip_actor
    JP C,draw_player_bullets
    CALL docmd
    LD HL,previous_player
    CALL remember_actor
    JP draw_player_bullets

    INCLUDE "frontend.asm"
    INCLUDE "weapons.asm"
    INCLUDE "trainer.asm"
    INCLUDE "pipeline.asm"
    INCLUDE "vertical.asm"
    INCLUDE "audio/player.asm"

hud_patterns: INCBIN "hud-patterns.bin"
    INCBIN "trainer-pattern.bin"
hud_patterns_end:
hud_colors: INCBIN "hud-colors.bin"
palette: INCBIN "palette.bin"
    ASSERT $ <= $8000
    DS $8000-$,$ff
    ORG $8000
background: INCBIN "background.rle"
atlas: INCBIN "atlas.rle"
    ASSERT $ <= $10000
    DS $10000-$,$ff
    ; Append the unused fourth 16 KiB bank without overflowing the assembler address space.
    ORG 0 ; fileorg-ok: append the fourth cartridge bank, not a RAM address gap.
    INCBIN "c/core.bin"
    DS $4000-($),$ff

    ORG 0 ; fileorg-ok: append canonical background banks 4..6.
    INCBIN "background.raw"
    INCBIN "audio/pcm-tables.bin"
    DS $4000-3840,$ff
    INCLUDE "audio/banks.asm"



    ORG 0 ; fileorg-ok: world bank 64
    INCBIN "levels/cleemalt.pixels.bin",0,16384
    ORG 0 ; fileorg-ok: world bank 65
    INCBIN "levels/cleemalt.pixels.bin",16384,16384
    ORG 0 ; fileorg-ok: world bank 66
    INCBIN "levels/cleemalt.pixels.bin",32768,16384
    ORG 0 ; fileorg-ok: world bank 67
    INCBIN "levels/cleemalt.pixels.bin",49152,16384
    ORG 0 ; fileorg-ok: world bank 68
    INCBIN "levels/cleemalt.pixels.bin",65536,16384
    ORG 0 ; fileorg-ok: world bank 69
    INCBIN "levels/cleemalt.pixels.bin",81920,16384
    ORG 0 ; fileorg-ok: world bank 70
    INCBIN "levels/cleemalt.pixels.bin",98304,16384
    ORG 0 ; fileorg-ok: world bank 71
    INCBIN "levels/cleemalt.pixels.bin",114688,16384
    ORG 0 ; fileorg-ok: world bank 72
    INCBIN "levels/cleemalt.pixels.bin",131072,16384
    ORG 0 ; fileorg-ok: world bank 73
    INCBIN "levels/cleemalt.pixels.bin",147456,16384
    ORG 0 ; fileorg-ok: world bank 74
    INCBIN "levels/cleemalt.pixels.bin",163840,16384
    ORG 0 ; fileorg-ok: world bank 75
    INCBIN "levels/cleemalt.pixels.bin",180224,16384
    ORG 0 ; fileorg-ok: world bank 76
    INCBIN "levels/cleemalt.pixels.bin",196608,16384
    ORG 0 ; fileorg-ok: world bank 77
    INCBIN "levels/cleemalt.pixels.bin",212992,16384
    ORG 0 ; fileorg-ok: world bank 78
    INCBIN "levels/cleemalt.pixels.bin",229376,16384
    ORG 0 ; fileorg-ok: world bank 79
    INCBIN "levels/cleemalt.pixels.bin",245760,16384
    ORG 0 ; fileorg-ok: world bank 80
    INCBIN "levels/cleemalt.pixels.bin",262144,16384
    ORG 0 ; fileorg-ok: world bank 81
    INCBIN "levels/cleemalt.pixels.bin",278528,16384
    ORG 0 ; fileorg-ok: world bank 82
    INCBIN "levels/cleemalt.pixels.bin",294912,16384
    ORG 0 ; fileorg-ok: world bank 83
    INCBIN "levels/cleemalt.pixels.bin",311296,16384
    ORG 0 ; fileorg-ok: world bank 84
    INCBIN "levels/cleemalt.pixels.bin",327680,16384
    ORG 0 ; fileorg-ok: world bank 85
    INCBIN "levels/cleemalt.pixels.bin",344064,16384
    ORG 0 ; fileorg-ok: world bank 86
    INCBIN "levels/cleemalt.pixels.bin",360448,16384
    ORG 0 ; fileorg-ok: world bank 87
    INCBIN "levels/cleemalt.pixels.bin",376832,16384
    ORG 0 ; fileorg-ok: world bank 88
    INCBIN "levels/cleemalt.pixels.bin",393216,16384
    ORG 0 ; fileorg-ok: world bank 89
    INCBIN "levels/cleemalt.pixels.bin",409600,16384
    ORG 0 ; fileorg-ok: world bank 90
    INCBIN "levels/cleemalt.pixels.bin",425984,16384
    ORG 0 ; fileorg-ok: world bank 91
    INCBIN "levels/cleemalt.pixels.bin",442368,16384
    ORG 0 ; fileorg-ok: world bank 92
    INCBIN "levels/cleemalt.pixels.bin",458752,16384
    ORG 0 ; fileorg-ok: world bank 93
    INCBIN "levels/cleemalt.pixels.bin",475136,16384
    ORG 0 ; fileorg-ok: world bank 94
    INCBIN "levels/cleemalt.pixels.bin",491520,16384
    ORG 0 ; fileorg-ok: world bank 95
    INCBIN "levels/cleemalt.pixels.bin",507904,16384
    ORG 0 ; fileorg-ok: world bank 96
    INCBIN "levels/cleemalt.pixels.bin",524288,16384
    ORG 0 ; fileorg-ok: world bank 97
    INCBIN "levels/cleemalt.pixels.bin",540672,16384
    ORG 0 ; fileorg-ok: world bank 98
    INCBIN "levels/cleemalt.pixels.bin",557056,16384
    ORG 0 ; fileorg-ok: world bank 99
    INCBIN "levels/cleemalt.pixels.bin",573440,16384
    ORG 0 ; fileorg-ok: world bank 100
    INCBIN "levels/cleemalt.pixels.bin",589824,16384
    ORG 0 ; fileorg-ok: world bank 101
    INCBIN "levels/cleemalt.pixels.bin",606208,16384
    ORG 0 ; fileorg-ok: world bank 102
    INCBIN "levels/cleemalt.pixels.bin",622592,16384
    ORG 0 ; fileorg-ok: world bank 103
    INCBIN "levels/cleemalt.pixels.bin",638976,16384
    ORG 0 ; fileorg-ok: world bank 104
    INCBIN "levels/cleemalt.pixels.bin",655360,16384
    ORG 0 ; fileorg-ok: world bank 105
    INCBIN "levels/cleemalt.pixels.bin",671744,16384
    ORG 0 ; fileorg-ok: world bank 106
    INCBIN "levels/cleemalt.pixels.bin",688128,16384
    ORG 0 ; fileorg-ok: world bank 107
    INCBIN "levels/cleemalt.pixels.bin",704512,16384
    ORG 0 ; fileorg-ok: world bank 108
    INCBIN "levels/cleemalt.pixels.bin",720896,16384
    ORG 0 ; fileorg-ok: world bank 109
    INCBIN "levels/cleemalt.pixels.bin",737280,16384
    ORG 0 ; fileorg-ok: world bank 110
    INCBIN "levels/cleemalt.pixels.bin",753664,16384
    ORG 0 ; fileorg-ok: world bank 111
    INCBIN "levels/cleemalt.pixels.bin",770048,16384
    ORG 0 ; fileorg-ok: padding bank
    DS $4000,$ff
    ORG 0 ; fileorg-ok: padding bank
    DS $4000,$ff
    ORG 0 ; fileorg-ok: padding bank
    DS $4000,$ff
    ORG 0 ; fileorg-ok: padding bank
    DS $4000,$ff
    ORG 0 ; fileorg-ok: padding bank
    DS $4000,$ff
    ORG 0 ; fileorg-ok: padding bank
    DS $4000,$ff
    ORG 0 ; fileorg-ok: padding bank
    DS $4000,$ff
    ORG 0 ; fileorg-ok: padding bank
    DS $4000,$ff
    ORG 0 ; fileorg-ok: padding bank
    DS $4000,$ff
    ORG 0 ; fileorg-ok: padding bank
    DS $4000,$ff
    ORG 0 ; fileorg-ok: padding bank
    DS $4000,$ff
    ORG 0 ; fileorg-ok: padding bank
    DS $4000,$ff
    ORG 0 ; fileorg-ok: padding bank
    DS $4000,$ff
    ORG 0 ; fileorg-ok: padding bank
    DS $4000,$ff
    ORG 0 ; fileorg-ok: padding bank
    DS $4000,$ff
    ORG 0 ; fileorg-ok: padding bank
    DS $4000,$ff
