; Xain MSX2: first playable conversion study.
; Assemble with sjasmplus --raw=../xain-msx2.rom game.asm
; SCREEN 8 / V9938, 128K VRAM, standard Z80, 1 MiB ASCII16 cartridge.
    ORG $4000
    DB "AB"
    DW start,0,0,0,0,0,0
audio_config: DB 0,6
gameplay_config: DB 0 ; optional weapon test, normal weapon in the distributed ROM

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
    LD A,32
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
    LD A,31
    OUT ($99),A
    LD A,$86
    OUT ($99),A
    LD A,$ef
    OUT ($99),A
    LD A,$85
    OUT ($99),A
    LD HL,hud_patterns
    LD DE,$3800
    LD BC,hud_patterns_end-hud_patterns
    CALL hud_upload
    LD HL,hud_colors
    LD DE,$3400
    LD BC,512
    CALL hud_upload
    CALL reset
    CALL audio_init
    CALL front_end
main:
    EI
    LD A,(ticks)
    INC A
    LD (ticks),A
    CALL audio_poll
    XOR A
    CALL $00d5
    LD (joy),A
    OR A
    JR NZ,.gotjoy
    LD A,1
    CALL $00d5
    LD (joy),A
.gotjoy:
    XOR A
    CALL $00d8
    LD C,A
    LD A,1
    PUSH BC
    CALL $00d8
    POP BC
    OR C
    LD (fire),A
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
    RET

update:
    XOR A
    LD (walking),A
    LD A,(cool)
    OR A
    JR Z,.nocool
    DEC A
    LD (cool),A
.nocool:
    LD A,(shield)
    OR A
    JR Z,.noshield
    DEC A
    LD (shield),A
.noshield:
    CALL stance_update
    LD A,(stance)
    OR A
    JP NZ,.jump
    LD A,(joy)
    CP 2
    JR Z,.right
    CP 3
    JR Z,.right
    CP 4
    JR Z,.right
    CP 6
    JR Z,.left
    CP 7
    JR Z,.left
    CP 8
    JR Z,.left
    JR .jump
.right:
    XOR A
    LD (face),A
    INC A
    LD (walking),A
    LD A,(px)
    CP 112
    JR NC,.scroll
    ADD A,2
    LD (px),A
    JR .jump
.scroll:
    LD HL,(camera)
    LD DE,1
    ADD HL,DE
    LD (camera),HL
    LD A,(ex)
    SUB 1
    LD (ex),A
    LD A,(power_active)
    OR A
    JR Z,.noscrollpower
    LD A,(power_x)
    DEC A
    LD (power_x),A
    CP 8
    JR NC,.noscrollpower
    XOR A
    LD (power_active),A
.noscrollpower:
    LD A,H
    CP 4
    JR C,.jump
    LD A,1
    LD (state),A
    XOR A
    LD (restartarmed),A
    LD A,50
    LD (cool),A
    JR .jump
.left:
    LD A,1
    LD (walking),A
    LD A,128
    LD (face),A
    LD A,(px)
    CP 26
    JR C,.jump
    SUB 2
    LD (px),A
.jump:
    LD A,(joy)
    CP 1
    JR Z,.jumppressed
    CP 2
    JR Z,.jumppressed
    CP 8
    JR Z,.jumppressed
    LD A,3
    CALL $00d8
    OR A
    JR NZ,.jumppressed
    LD (jumpheld),A
    JR .physics
.jumppressed:
    LD A,(jumpheld)
    OR A
    JR NZ,.physics
    INC A
    LD (jumpheld),A
    LD A,(jumpcount)
    CP 2
    JR NC,.physics
    INC A
    LD (jumpcount),A
.takeoff:
    XOR A
    LD (stance),A
    LD A,1
    LD (air),A
    LD A,-7
    LD (vy),A
.physics:
    LD A,(air)
    OR A
    JR Z,.shoot
    LD A,(vy)
    LD B,A
    LD A,(py)
    ADD A,B
    CP 192
    JR NC,.ceiling
    CP 24
    JR NC,.positionok
.ceiling:
    LD A,24
    LD (py),A
    XOR A
    LD (vy),A
    JR .gravitydone
.positionok:
    LD (py),A
    LD A,(ticks)
    AND 1
    JR NZ,.gravitydone
    LD A,(vy)
    INC A
    LD (vy),A
.gravitydone:
    LD A,(vy)
    BIT 7,A
    JR NZ,.shoot
    LD A,(py)
    CP 128
    JR C,.shoot
    LD A,128
    LD (py),A
    XOR A
    LD (air),A
    LD (vy),A
    LD (jumpcount),A
.shoot:
    CALL weapons_update
.enemymove:
    LD A,(enemy)
    OR A
    JR NZ,.enemywalk
    LD A,(ticks)
    AND 31
    JR NZ,.enemyshot
    LD A,1
    LD (enemy),A
    LD A,(spawn_number)
    INC A
    LD (spawn_number),A
    AND 3
    CP 1
    LD A,0
    JR NZ,.notcarrier
    INC A
.notcarrier:
    LD (carrier),A
    LD A,240
    LD (ex),A
.enemywalk:
    LD A,(carrier)
    OR A
    JR Z,.soldierwalk
    LD A,(px)
    LD B,A
    LD A,(ex)
    SUB B
    CP 80
    JR NC,.enemyshot
    LD A,(ex)
    ADD A,2
    CP 239
    JR C,.fleeing
    LD A,238
.fleeing:
    LD (ex),A
    JR .enemyshot
.soldierwalk:
    LD A,(ticks)
    AND 1
    JR NZ,.enemybounds
    LD A,(ex)
    DEC A
    LD (ex),A
.enemybounds:
    LD A,(ex)
    CP 6
    JR NC,.enemyshot
    XOR A
    LD (enemy),A
.enemyshot:
    LD A,(carrier)
    OR A
    JR NZ,.ebmove
    LD A,(ticks)
    AND 63
    JR NZ,.ebmove
    LD A,(enemy)
    OR A
    JR Z,.ebmove
    LD A,(eb)
    OR A
    JR NZ,.ebmove
    INC A
    LD (eb),A
    LD A,(ex)
    LD (ebx),A
.ebmove:
    LD A,(eb)
    OR A
    JR Z,.collisions
    LD A,(ebx)
    SUB 4
    LD (ebx),A
    JR NC,.collisions
    XOR A
    LD (eb),A
.collisions:
.touch:
    LD A,(shield)
    OR A
    RET NZ
    LD A,(py)
    CP 106
    RET C
    LD A,(px)
    LD B,A
    LD A,(enemy)
    OR A
    JR Z,.ebhit
    LD A,(ex)
    SUB B
    ADD A,12
    CP 24
    JR NC,.ebhit
    LD A,8
    JR .damage
.ebhit:
    LD A,(eb)
    OR A
    RET Z
    LD A,(ebx)
    SUB B
    ADD A,4
    CP 20
    RET NC
    XOR A
    LD (eb),A
    LD A,(stance)
    CP 2
    RET Z
    LD A,1
.damage:
    LD B,A
    LD A,60
    LD (shield),A
    LD A,(hp)
    SUB B
    JR C,.fatal
    JR Z,.fatal
    LD (hp),A
    LD A,2
    JP audio_sfx
.fatal:
    XOR A
    LD (hp),A
    JP lose_life

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
    DI
    CALL waitvdp
    LD A,(engineinit)
    OR A
    CALL Z,scroll_init
    CALL sync_scroll
    LD A,(camera)
    AND 15
    LD (finephase),A
    OR A
    JR NZ,.commit
    LD A,(lastphase)
    CP 15
    JR NZ,.commit
    LD A,(back)
    XOR 1
    LD (back),A
    LD A,(worldbase)
    ADD A,16
    CP 240
    JR C,.worldok
    XOR A
.worldok:
    LD (worldbase),A
    XOR A
    LD (previous_player+2),A
    LD (previous_enemy+2),A
    LD (previous_bullet+2),A
    LD (previous_eb+2),A
    CALL clear_weapon_rects
    DEC A
    LD (preparedphase),A
.commit:
    ; The previous command has completed. Main entered through VBlank before update.
    LD A,(back)
    RRCA
    RRCA
    RRCA
    OR 31
    OUT ($99),A
    LD A,$82
    OUT ($99),A
    LD A,(finephase)
    LD (lastphase),A
    ADD A,8
    AND 15
    OUT ($99),A
    LD A,$92
    OUT ($99),A
    CALL update_hud
    CALL restore_actors
    CALL prepare_slice
    CALL bitmap_actors
    JP status_overlay
status_overlay:
    LD A,(state)
    OR A
    RET Z
    CALL actorcmd
    LD A,248
    LD (cmd+2),A
    LD A,72
    CALL compensate_x
    LD (cmd+4),A
    LD A,80
    LD (cmd+6),A
    LD HL,104
    LD (cmd+8),HL
    LD HL,8
    LD (cmd+10),HL
    LD A,$d0
    LD (cmd+14),A
    LD A,(state)
    CP 2
    JR NZ,.status
    LD A,128
    LD (cmd),A
.status:
    CALL docmd
    JP waitvdp

scroll_init:
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
    CALL blankcmd
    LD A,1
    LD (cmd+3),A
    LD HL,256
    LD (cmd+8),HL
    LD HL,192
    LD (cmd+10),HL
    CALL docmd
    CALL waitvdp
    LD A,1
    LD (engineinit),A
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

prepare_slice:
    LD A,(finephase)
    LD B,A
    LD A,(preparedphase)
    CP B
    RET Z
    LD A,B
    LD (preparedphase),A
    CP 15
    RET Z
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
    CALL restore_rect
    LD IX,previous_enemy
    CALL restore_rect
    LD IX,previous_bullet
    CALL restore_rect
    LD IX,previous_eb
    CALL restore_rect
    JP restore_weapons

; Restore dirty rectangles from the uncompressed canonical image in ASCII16 banks 4..6.
; No clean full-screen VRAM master is needed, freeing both pages for double buffering.
restore_rect:
    LD A,(IX+2)
    OR A
    RET Z
    LD (savedwidth),A
    LD A,(IX+0)
    LD (savedx),A
    SUB 8
    LD L,A
    LD H,0
    LD A,(worldbase)
    LD E,A
    LD D,0
    ADD HL,DE
    LD DE,240
    OR A
    SBC HL,DE
    JR NC,.worldok
    ADD HL,DE
.worldok:
    LD A,L
    ADD A,8
    LD (cpusrcx),A
    LD B,A
    LD A,248
    SUB B
    LD B,A
    LD A,(savedwidth)
    CP B
    JR C,.firstok
    LD A,B
.firstok:
    LD (firstcount),A
    LD B,A
    LD A,(savedwidth)
    SUB B
    LD (secondcount),A
    LD A,(IX+1)
    LD (rowy),A
    LD A,(IX+3)
    LD (rowcount),A
.row:
    DI
    LD A,(rowy)
    RLCA
    RLCA
    AND 3
    LD E,A
    ADD A,4
    CALL select_bank
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
    LD H,A
    OR $40
    OUT ($99),A
    LD A,H
    OR $80
    LD H,A
    LD A,(cpusrcx)
    LD L,A
    LD A,(firstcount)
    LD B,A
    LD C,$98
    EI
    OTIR
    LD A,(secondcount)
    OR A
    JR Z,.nextrow
    LD B,A
    LD A,(rowy)
    AND 63
    OR $80
    LD H,A
    LD L,8
    OTIR
.nextrow:
    LD A,(rowy)
    INC A
    LD (rowy),A
    LD A,(rowcount)
    DEC A
    LD (rowcount),A
    JR NZ,.row
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
    LD A,(lives)
    ADD A,40
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
    LD DE,$3600
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
    EI
.copy:
    LD A,(HL)
    OUT ($98),A
    INC HL
    DEC BC
    LD A,B
    OR C
    JR NZ,.copy
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
    CALL actorcmd
    LD A,(ticks)
    AND 8
    RLCA
    ADD A,128
    LD (cmd),A
    LD A,(ex)
    CALL compensate_x
    LD (cmd+4),A
    LD A,128
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
    LD A,141
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
    LD A,192
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
    LD A,224
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
    INCLUDE "audio/player.asm"

hud_patterns: INCBIN "hud-patterns.bin"
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
    DS $4000,$ff

    ORG 0 ; fileorg-ok: append canonical background banks 4..6.
    INCBIN "background.raw"
    INCBIN "audio/pcm-tables.bin"
    DS $4000-3840,$ff
    INCLUDE "audio/banks.asm"


