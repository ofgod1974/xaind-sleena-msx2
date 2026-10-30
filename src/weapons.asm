; Arcade weapon IDs: normal=0, laser+grenade=1, photon=2, heavy=3, wide=4.
; Nine projectiles, each {active,kind,x,y,vx,vy,age,face}; dirty rectangles separate.
shots EQU $c400
shot_rects EQU $c600
weapon EQU $c500
stance EQU $c501
downheld EQU $c502
fireheld EQU $c503
lives EQU $c504
power_active EQU $c505
power_x EQU $c506
power_y EQU $c507
carrier EQU $c508
spawn_number EQU $c509
random_seed EQU $c50a
shot_kind EQU $c50b
shot_dy EQU $c50c
shot_offset EQU $c50d
shot_limit EQU $c50e
shot_count EQU $c50f
shot_index EQU $c510
shot_prev EQU $c512
power_rect EQU $c624
score_bcd EQU $c530
score_hundreds EQU $c534
extend_at EQU $c536
score_patterns EQU $c700
shoot_pose EQU $c538

gameplay_init:
    XOR A
    LD HL,$c400
    LD DE,$c401
    LD BC,$33f
    LD (HL),A
    LDIR
    LD A,3
    LD (lives),A
    LD A,(gameplay_config)
    CP 5
    JR C,.weaponok
    XOR A
.weaponok:
    LD (weapon),A
    LD A,16
    LD (hp),A
    LD A,$a7
    LD (random_seed),A
    LD HL,200
    LD (extend_at),HL
    RET

clear_shots:
    LD HL,shots
    LD DE,shots+1
    LD BC,71
    LD (HL),0
    LDIR
    XOR A
    LD (bullet),A
    RET

; Gameplay rules are compiled from c/weapons.c. Assembly below only renders.
restore_weapons:
    LD IX,shot_rects
    LD B,9
.each:
    PUSH BC
    CALL restore_rect
    LD DE,4
    ADD IX,DE
    POP BC
    DJNZ .each
    LD IX,power_rect
    JP restore_rect

clear_weapon_rects:
    LD HL,shot_rects
    LD DE,shot_rects+1
    LD BC,35
    LD (HL),0
    LDIR
    XOR A
    LD (power_rect+2),A
    RET

draw_weapons:
    LD IX,shots
    LD HL,shot_rects
    LD (shot_prev),HL
    LD A,9
    LD (shot_count),A
.each:
    LD HL,(shot_prev)
    INC HL
    INC HL
    LD (HL),0
    LD A,(IX+0)
    OR A
    JP Z,.next
    CALL actorcmd
    LD A,(IX+1)
    CP 3
    JR C,.index
    CP 5
    JR Z,.explosion
    LD A,(IX+1)
    CP 3
    LD A,3
    JR Z,.direction
    LD A,5
    LD B,A
    LD A,(IX+6)
    OR A
    LD A,B
    JR Z,.direction
    LD A,8
.direction:
    LD B,A
    LD A,(IX+7)
    OR A
    LD A,B
    JR Z,.index
    INC A
.index:
    ADD A,A
    ADD A,A
    LD E,A
    LD D,0
    LD HL,weapon_rectangles
    ADD HL,DE
    LD A,(HL)
    LD (cmd),A
    INC HL
    LD A,(HL)
    ADD A,192
    LD (cmd+2),A
    INC HL
    LD A,(HL)
    LD (cmd+8),A
    INC HL
    LD A,(HL)
    LD (cmd+10),A
    JR .destination
.explosion:
    LD A,(IX+6)
    RRCA
    AND 3
    CP 3
    JR C,.frameok
    XOR A
.frameok:
    RLCA
    RLCA
    RLCA
    RLCA
    ADD A,192
    LD (cmd),A
    LD A,224
    LD (cmd+2),A
    LD HL,16
    LD (cmd+8),HL
    LD (cmd+10),HL
.destination:
    LD A,(IX+2)
    CALL compensate_x
    LD (cmd+4),A
    LD A,(IX+3)
    LD (cmd+6),A
    CALL clip_actor
    JR C,.next
    PUSH IX
    CALL docmd
    LD HL,(shot_prev)
    CALL remember_actor
    POP IX
.next:
    LD DE,8
    ADD IX,DE
    LD HL,(shot_prev)
    LD DE,4
    ADD HL,DE
    LD (shot_prev),HL
    LD A,(shot_count)
    DEC A
    LD (shot_count),A
    JP NZ,.each
    LD A,(carrier)
    OR A
    JR Z,.power
    LD A,(enemy)
    OR A
    JR Z,.power
    LD A,(previous_enemy+2)
    OR A
    JR Z,.power
    CALL power_command
    LD A,(ex)
    INC A
    CALL compensate_x
    LD (cmd+4),A
    LD A,145
    LD (cmd+6),A
    CALL clip_actor
    CALL NC,docmd
.power:
    XOR A
    LD (power_rect+2),A
    LD A,(power_active)
    OR A
    RET Z
    CALL power_command
    LD A,(power_x)
    CALL compensate_x
    LD (cmd+4),A
    LD A,(power_y)
    LD (cmd+6),A
    CALL clip_actor
    RET C
    CALL docmd
    LD HL,power_rect
    JP remember_actor

power_command:
    CALL actorcmd
    LD A,112
    LD (cmd),A
    LD A,224
    LD (cmd+2),A
    LD HL,14
    LD (cmd+8),HL
    LD HL,11
    LD (cmd+10),HL
    RET

upload_score:
    LD IX,score_bcd+2
    LD DE,score_patterns
    LD B,3
.pair:
    PUSH BC
    LD A,(IX+0)
    RRCA
    RRCA
    RRCA
    RRCA
    AND 15
    CALL .digit
    LD A,(IX+0)
    AND 15
    CALL .digit
    DEC IX
    POP BC
    DJNZ .pair
    LD HL,score_patterns
    LD DE,$3800+55*32
    LD BC,96
    JP hud_upload
.digit:
    LD L,A
    LD H,0
    ADD HL,HL
    ADD HL,HL
    ADD HL,HL
    ADD HL,HL
    ADD HL,HL
    LD BC,hud_patterns+11*32
    ADD HL,BC
    LD BC,16
    LDIR
    RET

weapon_cooldowns: DB 4,6,5,10,4
weapon_limits: DB 3,2,6,1,9
weapon_speeds: DB 5,2,5,4,5
muzzle_heights: DB 5,10,22
projectile_top: DB 6,4,4,2,0
weapon_rectangles:
    INCLUDE "weapon-rects.asm"
